
local BarUtils = {}

local TEXTURE_STATUSBAR = "Interface\\TargetingFrame\\UI-StatusBar"
local TEXTURE_SOLID = "Interface\\Buttons\\WHITE8X8"
local TEXTURE_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local TEXTURE_BANTO = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"
local TEXTURE_HALCYONE = "Interface\\RaidFrame\\Raid-Bar-HP-Fill"

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

function BarUtils:LoadPosition(frame, db, prefix, defaultX, defaultY)
	if not frame or not db or not prefix then return end

	local screenWidth, screenHeight = UIParent:GetSize()
	local x = (db[prefix .. "PositionX"] or defaultX or 0) + (screenWidth / 2)
	local y = (db[prefix .. "PositionY"] or defaultY or 0) + (screenHeight / 2)

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
	elseif textureSetting == "banto" then
		texturePath = TEXTURE_BANTO
	elseif textureSetting == "halcyone" then
		texturePath = TEXTURE_HALCYONE
	end

	bar:SetStatusBarTexture(texturePath)
	bar:GetStatusBarTexture():SetHorizTile(false)

	if bar.bg then
		bar.bg:SetTexture(texturePath)
	end

	if textureSetting == "transparent" then
		bar:SetAlpha(0.7)
	else
		bar:SetAlpha(1.0)
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

	if #state.activeList > 0 then
		local oldest = state.activeList[1]
		if oldest then
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
