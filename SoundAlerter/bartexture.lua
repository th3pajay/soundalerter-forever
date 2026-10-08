local BarTexture = {}

local MEDIA = "Interface\\AddOns\\SoundAlerter\\Textures\\"
local TICK = 1 / 30
local TILE_ASPECT = 8
local WAVE_INTERVAL = 0.05
local WAVE_COLUMN_PIXELS = { 6, 5, 4 }
local WAVE_LAYER_ALPHA = { 0.35, 0.6, 1 }

local Wave = {}
Wave.__index = Wave

local MOMENTUM = 0.88
local RANDOMNESS = 0.4
local POINTS_ACROSS = 28
local BASE_STEP = 3

local WAVE_LAYERS = {
	{ ratio = 2.2, speed = 0.41, amplitude = 0.45 },
	{ ratio = 1.4, speed = 1.0, amplitude = 0.36 },
	{ ratio = 1.0, speed = 1.89, amplitude = 0.30 },
}

Wave.LAYER_COUNT = #WAVE_LAYERS

local function nextHeight(layer)
	local step = layer.step
	local carry = MOMENTUM ^ step
	layer.v = layer.v * carry + (layer.random() - 0.5) * RANDOMNESS * 0.5 * step
	layer.v = layer.v + (0.5 - layer.h) * 0.05 * step
	layer.h = layer.h + layer.v * step
	if layer.h > 1 then
		layer.h = 1
		layer.v = -math.abs(layer.v) * 0.5
	elseif layer.h < 0 then
		layer.h = 0
		layer.v = math.abs(layer.v) * 0.5
	end
	return layer.h
end

local function newWaveLayer(width, spec, random)
	local layer = {
		spacing = width / POINTS_ACROSS * spec.ratio,
		speed = spec.speed,
		amplitude = spec.amplitude,
		step = BASE_STEP * spec.ratio,
		random = random,
		points = {},
		scroll = 0,
		h = random(),
		v = 0,
	}
	local needed = math.ceil(width / layer.spacing) + 5
	for i = 1, needed do
		layer.points[i] = nextHeight(layer)
	end
	return layer
end

local function catmull(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

local function pointAt(points, last, n)
	if n < 0 then
		n = 0
	elseif n > last - 1 then
		n = last - 1
	end
	return points[n + 1]
end

function Wave.New(width, random)
	random = random or math.random
	local wave = setmetatable({ width = width, layers = {} }, Wave)
	for i, spec in ipairs(WAVE_LAYERS) do
		wave.layers[i] = newWaveLayer(width, spec, random)
	end
	return wave
end

function Wave:Advance(dt)
	for _, layer in ipairs(self.layers) do
		layer.scroll = layer.scroll + layer.speed * layer.spacing * dt
		while layer.scroll >= layer.spacing do
			layer.scroll = layer.scroll - layer.spacing
			table.insert(layer.points, 1, nextHeight(layer))
			table.remove(layer.points)
		end
	end
end

function Wave:Height(index, x, barHeight)
	local layer = self.layers[index]
	local points = layer.points
	local last = #points
	local position = (x - layer.scroll) / layer.spacing + 1
	local base = math.floor(position)
	local t = position - base

	local normalized = catmull(
		pointAt(points, last, base - 1),
		pointAt(points, last, base),
		pointAt(points, last, base + 1),
		pointAt(points, last, base + 2),
		t
	)
	if normalized < 0 then normalized = 0 elseif normalized > 1 then normalized = 1 end

	local amplitude = layer.amplitude * barHeight
	return barHeight - 2 * amplitude * (1 - normalized)
end

BarTexture.Wave = Wave
BarTexture.STATUSBAR_PATH = "Interface\\TargetingFrame\\UI-StatusBar"

local FLAT = {
	default = { label = "Default (WoW StatusBar)", path = BarTexture.STATUSBAR_PATH, alpha = 1 },
	solid = { label = "Solid (Clean Fill)", path = "Interface\\Buttons\\WHITE8X8", alpha = 1 },
	transparent = { label = "Transparent (Semi-Opaque)", path = "Interface\\Buttons\\WHITE8X8", alpha = 0.7 },
}

local ANIMATED = {
	waves = {
		label = "Waves",
		wave = true,
	},
	streaks = {
		label = "Streaks",
		layers = {
			{ file = "bar_streaks_1", rate = 0.069, alpha = 0.16 },
			{ file = "bar_streaks_2", rate = 0.194, alpha = 0.28 },
			{ file = "bar_streaks_3", rate = 0.469, alpha = 0.42 },
		},
	},
	motes = {
		label = "Motes",
		layers = {
			{ file = "bar_motes_1", rate = 0.031, alpha = 0.5 },
			{ file = "bar_motes_2", rate = 0.106, alpha = 0.75 },
			{ file = "bar_motes_3", rate = 0.288, alpha = 1 },
		},
	},
	fog = {
		label = "Fog",
		layers = {
			{ file = "bar_fog_1", rate = 0.025, alpha = 0.32 },
			{ file = "bar_fog_2", rate = 0.075, alpha = 0.46 },
			{ file = "bar_fog_3", rate = 0.1875, alpha = 0.6 },
		},
	},
}

local animatedBars = {}
local driver

function BarTexture:Normalize(setting)
	if FLAT[setting] or ANIMATED[setting] then
		return setting
	end
	return "default"
end

function BarTexture:Values()
	local values = {}
	for key, style in pairs(FLAT) do
		values[key] = style.label
	end
	for key, style in pairs(ANIMATED) do
		values[key] = style.label
	end
	return values
end

local function createFrames(bar, state)
	state.clip = CreateFrame("Frame", nil, bar)
	state.clip:SetClipsChildren(true)
	state.clip:SetFrameLevel(bar:GetFrameLevel() + 1)

	state.overlay = CreateFrame("Frame", nil, bar)
	state.overlay:SetAllPoints(bar)
	state.overlay:SetFrameLevel(bar:GetFrameLevel() + 2)
end

local function liftText(bar, state)
	if state.lifted then return end

	state.lifted = {}
	for _, region in ipairs({ bar:GetRegions() }) do
		if region:GetObjectType() == "FontString" then
			region:SetParent(state.overlay)
			state.lifted[#state.lifted + 1] = region
		end
	end
end

local function dropText(bar, state)
	if not state.lifted then return end

	for index = #state.lifted, 1, -1 do
		state.lifted[index]:SetParent(bar)
	end
	state.lifted = nil
end

local function anchorClip(state, fill)
	if state.clipFill == fill then return end

	state.clip:ClearAllPoints()
	state.clip:SetPoint("TOPLEFT", fill, "TOPLEFT")
	state.clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
	state.clipFill = fill
end

local function hideLayers(state)
	for _, texture in ipairs(state.textures) do
		texture:Hide()
	end
end

local function hideColumns(state, fill)
	for layer = 1, #state.columns do
		for _, column in ipairs(state.columns[layer]) do
			column:Hide()
			column.visible = false
		end
	end

	if fill then
		fill:SetAlpha(1)
	end
end

local function applyStyle(state, style, fill)
	state.style = style
	state.width, state.height, state.reverse = nil, nil, nil

	if style.wave then
		hideLayers(state)
		return
	end

	hideColumns(state, fill)

	for index, layer in ipairs(style.layers) do
		local texture = state.textures[index]
		if not texture then
			texture = state.clip:CreateTexture(nil, "ARTWORK", nil, index)
			texture:SetBlendMode("ADD")
			state.textures[index] = texture
		end
		texture:SetTexture(MEDIA .. layer.file, "REPEAT", "CLAMP")
		texture:SetVertexColor(1, 1, 1, layer.alpha)
		texture:Show()
		state.offsets[index] = 0
	end

	for index = #style.layers + 1, #state.textures do
		state.textures[index]:Hide()
	end
end

local function anchorLayers(state, bar, width, height, reverse)
	for _, texture in ipairs(state.textures) do
		texture:ClearAllPoints()
		if reverse then
			texture:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
		else
			texture:SetPoint("TOPLEFT", bar, "TOPLEFT")
		end
		texture:SetSize(width, height)
	end
	state.width, state.height, state.reverse = width, height, reverse
end

local function updateLayers(bar, state, dt, width, height)
	local reverse = bar:GetReverseFill() and true or false
	if state.width ~= width or state.height ~= height or state.reverse ~= reverse then
		anchorLayers(state, bar, width, height, reverse)
	end

	local span = width / (height * TILE_ASPECT)
	for index, layer in ipairs(state.style.layers) do
		local offset = (state.offsets[index] + layer.rate * dt) % 1
		state.offsets[index] = offset
		local left = reverse and offset or 1 - offset
		state.textures[index]:SetTexCoord(left, left + span, 0, 1)
	end
end

local function waveColumn(state, layer, index)
	local columns = state.columns[layer]
	local column = columns[index]
	if column then return column end

	column = state.clip:CreateTexture(nil, "ARTWORK", nil, layer)
	column:SetTexture(BarTexture.STATUSBAR_PATH)
	column.x = (index - 1) * WAVE_COLUMN_PIXELS[layer]
	column.anchoredReverse = nil
	column.visible = false
	column:Hide()
	columns[index] = column
	return column
end

local function readFillFraction(bar)
	local value = bar:GetValue()
	local minValue, maxValue = bar:GetMinMaxValues()
	if issecretvalue(value) or issecretvalue(minValue) or issecretvalue(maxValue) then
		return nil
	end
	if maxValue <= minValue then
		return nil
	end

	local fraction = (value - minValue) / (maxValue - minValue)
	if fraction < 0 then return 0 end
	if fraction > 1 then return 1 end
	return fraction
end

local function anchorWaveColumn(bar, column, reverse)
	if column.anchoredReverse == reverse then return end

	column:ClearAllPoints()
	if reverse then
		column:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -column.x, 0)
	else
		column:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", column.x, 0)
	end
	column.anchoredReverse = reverse
end

local function updateWaves(bar, state, dt, width, height, fill)
	state.accumulated = (state.accumulated or 0) + dt
	if state.accumulated < WAVE_INTERVAL then return end
	dt = state.accumulated
	state.accumulated = 0

	fill:SetAlpha(0)

	if not state.wave or state.wave.width ~= width then
		state.wave = Wave.New(width)
	end
	local wave = state.wave
	wave:Advance(dt)

	local fraction = readFillFraction(bar)
	local fillWidth = fraction and fraction * width or nil

	local reverse = bar:GetReverseFill() and true or false
	local ppu = SoundAlerter.BarUtils:PixelsPerUnit(bar)
	local r, g, b = bar:GetStatusBarColor()
	if state.r ~= r or state.g ~= g or state.b ~= b then
		state.r, state.g, state.b = r, g, b
		state.colorVersion = (state.colorVersion or 0) + 1
	end

	for layer = 1, Wave.LAYER_COUNT do
		local spacing = WAVE_COLUMN_PIXELS[layer]
		local count = math.ceil(width / spacing)
		local columns = state.columns[layer]

		for index = 1, count do
			local column = waveColumn(state, layer, index)
			local x = column.x
			local columnWidth = math.min(spacing, (fillWidth or width) - x)
			local top = columnWidth > 0 and wave:Height(layer, x + columnWidth / 2, height) or 0
			top = math.floor(top * ppu + 0.5) / ppu

			if columnWidth <= 0 or top < 1 / ppu then
				if column.visible then
					column:Hide()
					column.visible = false
				end
			else
				anchorWaveColumn(bar, column, reverse)
				if column.colorVersion ~= state.colorVersion then
					column:SetVertexColor(r, g, b, WAVE_LAYER_ALPHA[layer])
					column.colorVersion = state.colorVersion
				end
				if column.shownWidth ~= columnWidth then
					column:SetWidth(columnWidth)
					column.shownWidth = columnWidth
				end
				if column.shownHeight ~= top then
					column:SetHeight(top)
					column:SetTexCoord(0, 1, 1 - top / height, 1)
					column.shownHeight = top
				end
				if not column.visible then
					column:Show()
					column.visible = true
				end
			end
		end

		for index = count + 1, #columns do
			if columns[index].visible then
				columns[index]:Hide()
				columns[index].visible = false
			end
		end
	end
end

function BarTexture:Update(bar, dt)
	local state = bar.textureState
	local width, height = bar:GetSize()
	local fill = bar:GetStatusBarTexture()

	if bar:GetOrientation() ~= "HORIZONTAL" or width <= 0 or height <= 0 then
		state.clip:Hide()
		hideColumns(state, fill)
		return
	end

	state.clip:Show()
	anchorClip(state, fill)

	if state.style.wave then
		updateWaves(bar, state, dt, width, height, fill)
	else
		updateLayers(bar, state, dt, width, height)
	end
end

local function ensureDriver()
	if driver then return driver end

	driver = CreateFrame("Frame")
	driver.elapsed = 0
	driver:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		if self.elapsed < TICK then return end

		local dt = self.elapsed
		self.elapsed = 0
		for bar in pairs(animatedBars) do
			if bar:IsVisible() then
				BarTexture:Update(bar, dt)
			end
		end
	end)
	return driver
end

function BarTexture:SetAnimation(bar, style)
	if style then
		local state = bar.textureState
		if not state then
			state = { textures = {}, offsets = {}, columns = { {}, {}, {} } }
			bar.textureState = state
			createFrames(bar, state)
		end
		liftText(bar, state)
		if state.style ~= style then
			applyStyle(state, style, bar:GetStatusBarTexture())
		end
		animatedBars[bar] = true
		self:Update(bar, style.wave and WAVE_INTERVAL or 0)
		ensureDriver():Show()
		return
	end

	if animatedBars[bar] then
		local state = bar.textureState
		animatedBars[bar] = nil
		state.clip:Hide()
		state.style = nil
		hideColumns(state, bar:GetStatusBarTexture())
		dropText(bar, state)
	end
end

function BarTexture:Apply(bar, setting)
	if not bar then return end

	setting = self:Normalize(setting)
	local flat = FLAT[setting]
	local path = flat and flat.path or self.STATUSBAR_PATH

	bar:SetStatusBarTexture(path)
	bar:GetStatusBarTexture():SetHorizTile(false)
	if bar.bg then
		bar.bg:SetTexture(path)
	end
	bar:SetAlpha(flat and flat.alpha or 1)

	self:SetAnimation(bar, ANIMATED[setting])
end

SoundAlerter.BarTexture = BarTexture
