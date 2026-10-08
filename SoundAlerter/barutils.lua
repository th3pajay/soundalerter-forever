
local BarUtils = {}

local TEXTURE_STATUSBAR = "Interface\\TargetingFrame\\UI-StatusBar"
local TEXTURE_SOLID = "Interface\\Buttons\\WHITE8X8"
local TEXTURE_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

local WAVE_SETTING = "waves"
local WAVE_INTERVAL = 0.05
local WAVE_COLUMN_PIXELS = { 6, 5, 4 }
local WAVE_LAYER_ALPHA = { 0.35, 0.6, 1 }

local waveBars = {}
local waveDriver

BarUtils.TEXTURE_SETTINGS = {
	default = true,
	solid = true,
	transparent = true,
	waves = true,
}

BarUtils.BACKDROP_TEXTURES = {
	Solid = "Interface\\Tooltips\\UI-Tooltip-Background",
	DialogBox = "Interface\\DialogFrame\\UI-DialogBox-Background",
}

function BarUtils:SavePosition(frame, db, prefix)
	if not frame or not db or not prefix then return end

	local x, y = frame:GetCenter()
	if not x or not y then return end

	local screenWidth, screenHeight = UIParent:GetSize()
	db[prefix .. "PositionX"] = x - (screenWidth / 2)
	db[prefix .. "PositionY"] = y - (screenHeight / 2)
end

function BarUtils:PixelsPerUnit(frame)
	if not GetPhysicalScreenSize then return 1 end

	local _, physicalHeight = GetPhysicalScreenSize()
	local parentHeight = UIParent:GetHeight() * UIParent:GetEffectiveScale()
	if not physicalHeight or parentHeight <= 0 then return 1 end

	return physicalHeight / parentHeight * (frame or UIParent):GetEffectiveScale()
end

function BarUtils:Snap(value, frame)
	if not GetPhysicalScreenSize then return value end

	local ppu = self:PixelsPerUnit(frame)
	return math.floor(value * ppu + 0.5) / ppu
end

function BarUtils:LoadPosition(frame, db, prefix, defaultX, defaultY)
	if not frame or not db or not prefix then return end

	local screenWidth, screenHeight = UIParent:GetSize()
	local x = (db[prefix .. "PositionX"] or defaultX or 0) + (screenWidth / 2)
	local y = (db[prefix .. "PositionY"] or defaultY or 0) + (screenHeight / 2)

	local width, height = frame:GetSize()
	x = self:Snap(x - width / 2, frame) + width / 2
	y = self:Snap(y - height / 2, frame) + height / 2

	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

function BarUtils:MakeDraggable(frame, db, onStopCallback, enableMouseByDefault)
	if not frame or not db then return end

	frame:SetMovable(true)
	frame:EnableMouse(enableMouseByDefault == nil or enableMouseByDefault)
	frame:RegisterForDrag("LeftButton")

	frame:SetScript("OnDragStart", function(self)
		if not db.locked then
			self:StartMoving()
		end
	end)

	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if onStopCallback then
			onStopCallback()
		end
	end)
end

function BarUtils:CreateContainerFrame(name, width, height, defaultY, db, onDragStop, enableMouseByDefault)
	local frame = CreateFrame("Frame", name, UIParent)
	frame:SetSize(width, height)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(10)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, defaultY)

	self:MakeDraggable(frame, db, onDragStop, enableMouseByDefault)

	return frame
end

function BarUtils:CreateStatusBarWidget(parent, width, height, minVal, maxVal)
	local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
	bar:SetSize(width, height)
	bar:SetPoint("CENTER")
	bar:SetStatusBarTexture(TEXTURE_STATUSBAR)
	bar:GetStatusBarTexture():SetHorizTile(false)
	bar:SetMinMaxValues(minVal, maxVal)

	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.bg:SetTexture(TEXTURE_STATUSBAR)
	bar.bg:SetVertexColor(0.1, 0.1, 0.1, 0.5)

	return bar
end

function BarUtils:ApplyBarTexture(bar, textureSetting)
	if not bar then return end

	local texturePath = TEXTURE_STATUSBAR

	if textureSetting == "solid" then
		texturePath = TEXTURE_SOLID
	elseif textureSetting == "transparent" then
		texturePath = TEXTURE_SOLID
	end

	bar:SetStatusBarTexture(texturePath)
	bar:GetStatusBarTexture():SetHorizTile(false)

	if bar.bg then
		bar.bg:SetTexture(texturePath)
	end

	self:SetWavesEnabled(bar, textureSetting == WAVE_SETTING)

	if textureSetting == "transparent" then
		bar:SetAlpha(0.7)
	else
		bar:SetAlpha(1.0)
	end
end

local function hideWaveColumns(bar)
	local state = bar.waveState
	if not state then return end

	for layer = 1, #state.columns do
		for _, column in ipairs(state.columns[layer]) do
			column:Hide()
			column.visible = false
		end
	end

	local fill = bar:GetStatusBarTexture()
	if fill then
		fill:SetAlpha(1)
	end
end

local function waveColumn(bar, state, layer, index)
	local columns = state.columns[layer]
	local column = columns[index]
	if column then return column end

	column = state.clip:CreateTexture(nil, "ARTWORK", nil, layer)
	column:SetTexture(TEXTURE_STATUSBAR)
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

local function createWaveFrames(bar, state)
	if state.clip then return end

	state.clip = CreateFrame("Frame", nil, bar)
	state.clip:SetClipsChildren(true)
	state.clip:SetFrameLevel(bar:GetFrameLevel() + 1)

	state.overlay = CreateFrame("Frame", nil, bar)
	state.overlay:SetAllPoints(bar)
	state.overlay:SetFrameLevel(bar:GetFrameLevel() + 2)

	state.lifted = {}
end

local function liftBarText(bar, state)
	for _, region in ipairs({ bar:GetRegions() }) do
		if region:GetObjectType() == "FontString" then
			region:SetParent(state.overlay)
			state.lifted[#state.lifted + 1] = region
		end
	end
end

local function dropBarText(bar, state)
	for index = #state.lifted, 1, -1 do
		state.lifted[index]:SetParent(bar)
		state.lifted[index] = nil
	end
end

local function ensureWaveClip(state, fill)
	if state.clipFill == fill then return end

	state.clip:ClearAllPoints()
	state.clip:SetPoint("TOPLEFT", fill, "TOPLEFT")
	state.clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
	state.clipFill = fill
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

function BarUtils:UpdateWaveBar(bar, dt)
	local state = bar.waveState
	local width, height = bar:GetSize()

	if bar:GetOrientation() ~= "HORIZONTAL" or width <= 0 or height <= 0 then
		hideWaveColumns(bar)
		return
	end

	local fill = bar:GetStatusBarTexture()
	fill:SetAlpha(0)

	if not state.wave or state.wave.width ~= width then
		state.wave = SA_BarWave.New(width)
	end
	local wave = state.wave
	wave:Advance(dt)

	ensureWaveClip(state, fill)

	local fraction = readFillFraction(bar)
	local fillWidth = fraction and fraction * width or nil

	local reverse = bar:GetReverseFill() and true or false
	local ppu = self:PixelsPerUnit(bar)
	local r, g, b = bar:GetStatusBarColor()
	if state.r ~= r or state.g ~= g or state.b ~= b then
		state.r, state.g, state.b = r, g, b
		state.colorVersion = (state.colorVersion or 0) + 1
	end

	for layer = 1, SA_BarWave.LAYER_COUNT do
		local spacing = WAVE_COLUMN_PIXELS[layer]
		local count = math.ceil(width / spacing)
		local columns = state.columns[layer]

		for index = 1, count do
			local column = waveColumn(bar, state, layer, index)
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

local function ensureWaveDriver()
	if waveDriver then return waveDriver end

	waveDriver = CreateFrame("Frame")
	waveDriver.elapsed = 0
	waveDriver:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		if self.elapsed < WAVE_INTERVAL then return end

		local dt = self.elapsed
		self.elapsed = 0
		for bar in pairs(waveBars) do
			if bar:IsVisible() then
				BarUtils:UpdateWaveBar(bar, dt)
			end
		end
	end)
	return waveDriver
end

function BarUtils:SetWavesEnabled(bar, enabled)
	if enabled then
		if not bar.waveState then
			bar.waveState = { columns = { {}, {}, {} } }
		end
		local state = bar.waveState
		createWaveFrames(bar, state)
		liftBarText(bar, state)
		state.clip:Show()
		waveBars[bar] = true
		ensureWaveDriver():Show()
		return
	end

	if waveBars[bar] then
		waveBars[bar] = nil
		hideWaveColumns(bar)
		bar.waveState.clip:Hide()
		dropBarText(bar, bar.waveState)
	end
end

function BarUtils:CreateBackdrop(frame, r, g, b, a, bgFile, bgR, bgG, bgB, bgA, edgeSize, inset)
	if not frame then return end

	edgeSize = edgeSize or 12
	inset = inset or 2

	frame:SetBackdrop({
		bgFile = bgFile,
		edgeFile = TEXTURE_BORDER,
		tile = bgFile ~= nil,
		tileSize = bgFile and edgeSize or nil,
		edgeSize = edgeSize,
		insets = {left = inset, right = inset, top = inset, bottom = inset}
	})

	frame:SetBackdropBorderColor(r or 0.5, g or 0.5, b or 0.5, a or 1)

	if bgFile then
		frame:SetBackdropColor(bgR or 0, bgG or 0, bgB or 0, bgA or 0.8)
	end
end

function BarUtils:SetLocked(frame, locked)
	if not frame then return end

	frame:EnableMouse(not locked)
end

function BarUtils:UpdateVisibility(frame, db)
	if not frame or not db then return end

	if db.enabled then
		frame:Show()
		frame:EnableMouse(not db.locked)
	else
		frame:Hide()
	end
end

function BarUtils:CreateFontString(parent, fontSize, outline)
	if not parent then return nil end

	local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	fontString:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 14, outline or "OUTLINE")
	fontString:SetShadowOffset(1, -1)
	fontString:SetShadowColor(0, 0, 0, 1)

	return fontString
end

function BarUtils:ShouldUpdate(lastUpdate, throttle)
	local now = GetTime()

	if not lastUpdate then
		return true, now
	end

	if (now - lastUpdate) >= throttle then
		return true, now
	end

	return false, now
end

function BarUtils:AcquireToastFromPool(state, releaseFn, onExhausted)
	local pool = state.inCombat and state.insecurePool or state.securePool

	for i = 1, state.poolSize do
		local toast = pool[i]
		if toast and not toast.inUse then
			toast.inUse = true
			return toast
		end
	end

	local locked = InCombatLockdown()
	for i = 1, #state.activeList do
		local oldest = state.activeList[i]
		if oldest and not (locked and oldest.isSecure) then
			releaseFn(oldest)
			oldest.inUse = true
			if onExhausted then onExhausted(oldest) end
			return oldest
		end
	end

	return nil
end

function BarUtils:SwapInsecureToSecurePool(state, releaseFn, copyFn, addon, label, budgetMs)
	if InCombatLockdown() or state.swapInProgress then
		return 0, 0
	end

	state.swapInProgress = true
	local startTime = debugprofilestop()

	local insecureToasts = state.swapBuffer
	wipe(insecureToasts)
	for i = #state.activeList, 1, -1 do
		if state.activeList[i] and not state.activeList[i].isSecure then
			table.insert(insecureToasts, {index = i, frame = state.activeList[i]})
		end
	end

	if #insecureToasts == 0 then
		state.swapInProgress = false
		return 0, 0
	end

	local availableSecure = 0
	for i = 1, state.poolSize do
		if state.securePool[i] and not state.securePool[i].inUse then
			availableSecure = availableSecure + 1
		end
	end

	if availableSecure < #insecureToasts then
		local needed = #insecureToasts - availableSecure
		for i = 1, #state.activeList do
			if needed <= 0 then break end
			local toast = state.activeList[i]
			if toast and toast.isSecure then
				releaseFn(toast)
				availableSecure = availableSecure + 1
				needed = needed - 1
			end
		end
	end

	local swappedCount = 0
	for _, data in ipairs(insecureToasts) do
		local oldFrame = data.frame
		local newFrame = nil

		for i = 1, state.poolSize do
			if state.securePool[i] and not state.securePool[i].inUse then
				newFrame = state.securePool[i]
				newFrame.inUse = true
				break
			end
		end

		if not newFrame then
			if addon.db1.profile.debugmode then
				addon:Print(string.format("[%s SWAP] No secure frames available, aborting swap", label))
			end
			break
		end

		if copyFn(oldFrame, newFrame) then
			state.activeList[data.index] = newFrame
			newFrame:Show()
			releaseFn(oldFrame)
			swappedCount = swappedCount + 1
		end
	end

	if swappedCount > 0 and state.onLayoutChanged then
		state.onLayoutChanged()
	end

	local elapsed = debugprofilestop() - startTime
	state.metrics.count = state.metrics.count + 1
	state.metrics.totalTime = state.metrics.totalTime + elapsed
	state.metrics.maxTime = math.max(state.metrics.maxTime, elapsed)
	if state.metrics.histogram then
		state.metrics.histogram[swappedCount] = (state.metrics.histogram[swappedCount] or 0) + 1
	end

	if addon.db1.profile.debugmode then
		local avgTime = state.metrics.totalTime / state.metrics.count
		addon:Print(string.format("[%s SWAP] %d frames swapped in %.2fms (avg: %.2fms, max: %.2fms)",
			label, swappedCount, elapsed, avgTime, state.metrics.maxTime))
	end

	if elapsed > budgetMs then
		addon:Print(string.format("[%s SWAP WARNING] Frame swap took %.2fms (exceeds %.1fms budget)",
			label, elapsed, budgetMs))
	end

	state.swapInProgress = false
	return swappedCount, elapsed
end

SoundAlerter.BarUtils = BarUtils
