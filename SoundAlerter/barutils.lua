
local BarUtils = {}

local TEXTURE_STATUSBAR = SoundAlerter.BarTexture.STATUSBAR_PATH
local TEXTURE_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

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

SoundAlerter.BarUtils = BarUtils
