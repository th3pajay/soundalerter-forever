local BarTexture = {}

local MEDIA = "Interface\\AddOns\\SoundAlerter\\Textures\\"
local TICK = 1 / 30
local TILE_ASPECT = 8
local WAVE_INTERVAL = 0.05
local WAVE_COLUMN_PIXELS = { 6, 5, 4 }
local WAVE_LAYER_ALPHA = { 0.35, 0.6, 1 }
local LOW_INTERVAL = 0.06
local GLINT_SPEED = 70
local GLINT_TRAIL = 6
local GLINT_STEP = 3
local PIXEL = "Interface\\Buttons\\WHITE8X8"
local QUALITIES = { low = true, normal = true, high = true }
local BEVEL_LIGHT = { 0.62, 0.86, 1, 0.85 }
local BEVEL_DARK = { 0.17, 0.44, 0.69, 0.85 }

local math_ceil, math_floor, math_min = math.ceil, math.floor, math.min

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

local BACKDROP_ALPHA = 0.8

local FLAT = {
	default = { label = "Default", path = BarTexture.STATUSBAR_PATH, alpha = 1 },
	solid = { label = "Solid", path = "Interface\\Buttons\\WHITE8X8", alpha = 1 },
	transparent = { label = "Transparent", path = "Interface\\AddOns\\SoundAlerter\\Textures\\bar_clear", alpha = 1, clear = true, fillAlpha = 0.28 },
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
			{ file = "bar_motes_1", rate = 0.028, alpha = 0.45 },
			{ file = "bar_motes_2", rate = 0.1, alpha = 0.7 },
			{ file = "bar_motes_3", rate = 0.27, alpha = 0.95 },
		},
	},
	liquid = {
		label = "Liquid",
		border = "liquid",
		layers = {
			{ file = "bar_liquid_1", rate = 0.03, alpha = 0.24 },
			{ file = "bar_liquid_2", rate = 0.1, alpha = 0.55 },
			{ file = "bar_liquid_3", rate = 0.02, rise = 0.45, alpha = 0.9 },
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

function BarTexture:NormalizeQuality(setting)
	if QUALITIES[setting] then
		return setting
	end
	return "normal"
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

local function effectiveLayers(style, quality)
	local layers = style.layers
	if quality ~= "low" or #layers < 3 then
		return layers
	end

	local reduced = {}
	for index = 2, #layers do
		reduced[#reduced + 1] = layers[index]
	end
	return reduced
end

local function applyStyle(state, style, fill, quality)
	state.style, state.quality = style, quality
	state.width, state.height, state.reverse, state.vertical = nil, nil, nil, nil

	if style.wave then
		state.layers = nil
		hideLayers(state)
		return
	end

	hideColumns(state, fill)

	state.layers = effectiveLayers(style, quality)
	for index, layer in ipairs(state.layers) do
		local texture = state.textures[index]
		if not texture then
			texture = state.clip:CreateTexture(nil, "ARTWORK", nil, index)
			texture:SetBlendMode("ADD")
			state.textures[index] = texture
		end
		texture:SetTexture(MEDIA .. layer.file, "REPEAT", layer.rise and "REPEAT" or "CLAMP")
		texture:SetVertexColor(1, 1, 1, layer.alpha)
		texture:Show()
		state.offsets[index] = 0
		state.rises[index] = 0
	end

	for index = #state.layers + 1, #state.textures do
		state.textures[index]:Hide()
	end
end

local function anchorLayers(state, bar, width, height, reverse, vertical)
	local point
	if vertical then
		point = reverse and "TOPLEFT" or "BOTTOMLEFT"
	else
		point = reverse and "TOPRIGHT" or "TOPLEFT"
	end

	for _, texture in ipairs(state.textures) do
		texture:ClearAllPoints()
		texture:SetPoint(point, bar, point)
		texture:SetSize(width, height)
	end
	state.width, state.height, state.reverse, state.vertical = width, height, reverse, vertical
end

local function updateLayers(bar, state, dt, width, height, vertical)
	local reverse = bar:GetReverseFill() and true or false
	if state.width ~= width or state.height ~= height or state.reverse ~= reverse or state.vertical ~= vertical then
		anchorLayers(state, bar, width, height, reverse, vertical)
	end

	local length, thickness = width, height
	if vertical then
		length, thickness = height, width
	end
	local span = length / (thickness * TILE_ASPECT)

	for index, layer in ipairs(state.layers) do
		local offset = (state.offsets[index] + layer.rate * dt) % 1
		state.offsets[index] = offset
		local left = reverse and offset or 1 - offset

		local top = 0
		if layer.rise then
			top = (state.rises[index] + layer.rise * dt) % 1
			state.rises[index] = top
		end

		local texture = state.textures[index]
		if vertical then
			if reverse then
				texture:SetTexCoord(left, top, left + span, top, left, top + 1, left + span, top + 1)
			else
				texture:SetTexCoord(left + span, top, left, top, left + span, top + 1, left, top + 1)
			end
		else
			texture:SetTexCoord(left, left + span, top, top + 1)
		end
	end
end

local function ensureBevel(bar, state)
	if state.bevel then return state.bevel end

	local bevel = {}
	for index = 1, 4 do
		local texture = state.overlay:CreateTexture(nil, "OVERLAY", nil, 1)
		texture:SetTexture(PIXEL)
		local color = index <= 2 and BEVEL_LIGHT or BEVEL_DARK
		texture:SetVertexColor(color[1], color[2], color[3], color[4])
		bevel[index] = texture
	end

	bevel[1]:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
	bevel[1]:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1, -1)
	bevel[1]:SetHeight(1)
	bevel[2]:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -2)
	bevel[2]:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 2)
	bevel[2]:SetWidth(1)
	bevel[3]:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 1)
	bevel[3]:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
	bevel[3]:SetHeight(1)
	bevel[4]:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1, -2)
	bevel[4]:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 2)
	bevel[4]:SetWidth(1)

	state.bevel = bevel
	return bevel
end

local function setBevel(bar, state, shown)
	if shown then
		for _, texture in ipairs(ensureBevel(bar, state)) do
			texture:Show()
		end
	elseif state.bevel then
		for _, texture in ipairs(state.bevel) do
			texture:Hide()
		end
	end
end

local function perimeterPoint(width, height, distance)
	distance = distance % (2 * (width + height))
	if distance < width then return distance, 0 end
	distance = distance - width
	if distance < height then return width, distance end
	distance = distance - height
	if distance < width then return width - distance, height end
	return 0, height - (distance - width)
end

local function ensureGlint(state)
	if state.glint then return state.glint end

	local glint = {}
	for index = 1, GLINT_TRAIL do
		local texture = state.overlay:CreateTexture(nil, "OVERLAY", nil, 2)
		texture:SetTexture(PIXEL)
		texture:SetSize(2, 2)
		texture:SetVertexColor(1, 1, 1, 0.9 * (1 - (index - 1) / GLINT_TRAIL))
		glint[index] = texture
	end
	state.glint = glint
	state.glintAt = 0
	return glint
end

local function hideGlint(state)
	if not state.glintShown then return end

	for _, texture in ipairs(state.glint) do
		texture:Hide()
	end
	state.glintShown = false
end

local function updateGlint(bar, state, dt, width, height)
	if state.quality ~= "high" then
		hideGlint(state)
		return
	end

	local glint = ensureGlint(state)
	state.glintAt = (state.glintAt + GLINT_SPEED * dt) % (2 * (width + height))
	for index = 1, GLINT_TRAIL do
		local x, y = perimeterPoint(width, height, state.glintAt - (index - 1) * GLINT_STEP)
		local texture = glint[index]
		texture:ClearAllPoints()
		texture:SetPoint("CENTER", bar, "TOPLEFT", x, -y)
		texture:Show()
	end
	state.glintShown = true
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
	local minTop = 1 / ppu
	local r, g, b = bar:GetStatusBarColor()
	if state.r ~= r or state.g ~= g or state.b ~= b then
		state.r, state.g, state.b = r, g, b
		state.colorVersion = (state.colorVersion or 0) + 1
	end

	for layer = 1, Wave.LAYER_COUNT do
		local spacing = WAVE_COLUMN_PIXELS[layer]
		local count = math_ceil(width / spacing)
		local columns = state.columns[layer]
		local layerAlpha = WAVE_LAYER_ALPHA[layer]
		local limit = fillWidth or width

		for index = 1, count do
			local column = columns[index] or waveColumn(state, layer, index)
			local x = column.x
			local columnWidth = math_min(spacing, limit - x)
			local top = columnWidth > 0 and wave:Height(layer, x + columnWidth / 2, height) or 0
			top = math_floor(top * ppu + 0.5) / ppu

			if columnWidth <= 0 or top < minTop then
				if column.visible then
					column:Hide()
					column.visible = false
				end
			else
				anchorWaveColumn(bar, column, reverse)
				if column.colorVersion ~= state.colorVersion then
					column:SetVertexColor(r, g, b, layerAlpha)
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
	if state.style and state.style.wave then
		local accumulated = (state.accumulated or 0) + dt
		if accumulated < WAVE_INTERVAL then
			state.accumulated = accumulated
			return
		end
		dt = accumulated
		state.accumulated = 0
	end

	local width, height = bar:GetSize()
	local fill = bar:GetStatusBarTexture()

	if width > 0 and height > 0 then
		updateGlint(bar, state, dt, width, height)
	end

	local orientation = bar:GetOrientation()
	local vertical = orientation == "VERTICAL"
	if (orientation ~= "HORIZONTAL" and not vertical) or width <= 0 or height <= 0 or (vertical and state.style.wave) then
		state.clip:Hide()
		hideColumns(state, fill)
		return
	end

	state.clip:Show()
	anchorClip(state, fill)

	if state.style.wave then
		updateWaves(bar, state, dt, width, height, fill)
	else
		updateLayers(bar, state, dt, width, height, vertical)
	end
end

local function ensureDriver()
	if driver then return driver end

	driver = CreateFrame("Frame")
	driver.elapsed = 0
	driver:SetScript("OnUpdate", function(self, elapsed)
		if next(animatedBars) == nil then
			self.elapsed = 0
			self:Hide()
			return
		end

		self.elapsed = self.elapsed + elapsed
		if self.elapsed < TICK then return end

		local dt = self.elapsed
		self.elapsed = 0
		for bar in pairs(animatedBars) do
			if bar:IsVisible() then
				local state = bar.textureState
				local step = dt
				if state.quality == "low" then
					step = (state.pending or 0) + dt
					if step < LOW_INTERVAL then
						state.pending = step
						step = nil
					else
						state.pending = 0
					end
				end
				if step then
					BarTexture:Update(bar, step)
				end
			end
		end
	end)
	return driver
end

function BarTexture:SetAnimation(bar, style, quality)
	if style then
		quality = self:NormalizeQuality(quality)
		local state = bar.textureState
		if not state then
			state = { textures = {}, offsets = {}, rises = {}, columns = { {}, {}, {} } }
			bar.textureState = state
			createFrames(bar, state)
		end
		liftText(bar, state)
		if state.style ~= style or state.quality ~= quality then
			applyStyle(state, style, bar:GetStatusBarTexture(), quality)
		end
		setBevel(bar, state, style.border == "liquid")
		animatedBars[bar] = true
		self:Update(bar, style.wave and WAVE_INTERVAL or 0)
		ensureDriver():Show()
		return
	end

	if animatedBars[bar] then
		local state = bar.textureState
		animatedBars[bar] = nil
		state.clip:Hide()
		state.style, state.quality = nil, nil
		hideColumns(state, bar:GetStatusBarTexture())
		setBevel(bar, state, false)
		hideGlint(state)
		dropText(bar, state)
	end
end

local function tintedFill(bar, r, g, b, a)
	bar:rawSetStatusBarColor(r, g, b, a)
	local ghost = bar.ghostFill
	if ghost then ghost:SetVertexColor(r, g, b, (a or 1) * (bar.fillAlpha or 1)) end
end

function BarTexture:Apply(bar, setting, quality)
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

	local fill = bar:GetStatusBarTexture()
	local clear = flat and flat.clear
	if bar.clearApplied and not clear then
		bar.clearApplied = nil
		bar.fillAlpha = nil
		bar.SetStatusBarColor = bar.rawSetStatusBarColor
		if bar.ghostFill then bar.ghostFill:Hide() end
		fill:SetAlpha(1)
		if bar.bg then bar.bg:Show() end
		if bar.SetBackdropColor then bar:SetBackdropColor(0, 0, 0, BACKDROP_ALPHA) end
	end

	self:SetAnimation(bar, ANIMATED[setting], quality)

	if clear then
		bar.clearApplied = true
		bar.fillAlpha = flat.fillAlpha
		if not bar.rawSetStatusBarColor then
			bar.rawSetStatusBarColor = bar.SetStatusBarColor
		end
		bar.SetStatusBarColor = tintedFill
		local ghost = bar.ghostFill
		if not ghost then
			ghost = bar:CreateTexture(nil, "ARTWORK")
			ghost:SetTexture("Interface\\Buttons\\WHITE8X8")
			bar.ghostFill = ghost
		end
		ghost:ClearAllPoints()
		ghost:SetAllPoints(fill)
		ghost:Show()
		local r, g, b = bar:GetStatusBarColor()
		bar:SetStatusBarColor(r, g, b, 1)
		if bar.bg then bar.bg:Hide() end
		if bar.SetBackdropColor then bar:SetBackdropColor(0, 0, 0, 0) end
	end
end

SoundAlerter.BarTexture = BarTexture
