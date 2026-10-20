local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
if not SoundAlerter then return end

local ResourceBar = {}
SoundAlerter.ResourceBar = ResourceBar

local math_sin = math.sin
local math_pi = math.pi
local math_floor = math.floor
local math_max = math.max
local GetTime = GetTime
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local GetComboPoints = GetComboPoints
local Plain = SA_COMPAT.Plain

local TARGET_SWITCH_WINDOW = 0.25

local POWER_TYPE_MANA = 0
local POWER_TYPE_RAGE = 1
local POWER_TYPE_ENERGY = 3

local BAR_WIDTH = 280
local BAR_HEIGHT = 20
local CP_CONTAINER_WIDTH = 280
local CP_HEIGHT = 30
local CP_TEXTURE_DIR = "Interface\\AddOns\\SoundAlerter\\Textures\\"
local CP_SHAPE_TEXTURES = {
	circle = CP_TEXTURE_DIR .. "circle",
	ring = CP_TEXTURE_DIR .. "cp_ring",
	pip = CP_TEXTURE_DIR .. "cp_pip",
	diamond = CP_TEXTURE_DIR .. "cp_diamond",
	hexagon = CP_TEXTURE_DIR .. "cp_hexagon",
	star = CP_TEXTURE_DIR .. "cp_star",
	shield = CP_TEXTURE_DIR .. "cp_shield",
	pill = CP_TEXTURE_DIR .. "cp_pill",
	triangle = CP_TEXTURE_DIR .. "cp_triangle",
	bar = CP_TEXTURE_DIR .. "cp_bar",
}
local CP_SPACING = 8

local VALUE_UPDATE_THROTTLE = 0.016
local ENERGY_UPDATE_THROTTLE = 0.01
local TWO_PI = math_pi * 2

local BAR_CONFIGS = {
	energy = {
		key = "energy",
		globalName = "SoundAlerterResourceBar_Energy",
		powerType = POWER_TYPE_ENERGY,
		defaultY = -120,
		powerToken = "ENERGY",
		updateFreq = ENERGY_UPDATE_THROTTLE,
		getValueFunc = function() return UnitPower("player", POWER_TYPE_ENERGY), UnitPowerMax("player", POWER_TYPE_ENERGY) end,
		shouldUpdate = function(self, current, lastValue) return current ~= lastValue end,
		events = {"UNIT_POWER_FREQUENT", "UNIT_MAXPOWER"}
	},
	rage = {
		key = "rage",
		globalName = "SoundAlerterResourceBar_Rage",
		powerType = POWER_TYPE_RAGE,
		defaultY = -120,
		powerToken = "RAGE",
		updateFreq = VALUE_UPDATE_THROTTLE,
		getValueFunc = function() return UnitPower("player", POWER_TYPE_RAGE), UnitPowerMax("player", POWER_TYPE_RAGE) end,
		shouldUpdate = function(self, current, lastValue) return current ~= lastValue end,
		events = {"UNIT_POWER_FREQUENT", "UNIT_MAXPOWER"}
	},
	health = {
		key = "health",
		globalName = "SoundAlerterResourceBar_Health",
		powerType = nil,
		defaultY = -140,
		updateFreq = VALUE_UPDATE_THROTTLE,
		getValueFunc = function() return UnitHealth("player"), UnitHealthMax("player") end,
		shouldUpdate = function(self, current, lastValue) return current ~= lastValue end,
		events = {"UNIT_HEALTH", "UNIT_MAXHEALTH"}
	},
	mana = {
		key = "mana",
		globalName = "SoundAlerterResourceBar_Mana",
		powerType = POWER_TYPE_MANA,
		defaultY = -100,
		powerToken = "MANA",
		updateFreq = VALUE_UPDATE_THROTTLE,
		getValueFunc = function() return UnitPower("player", POWER_TYPE_MANA), UnitPowerMax("player", POWER_TYPE_MANA) end,
		shouldUpdate = function(self, current, lastValue) return current ~= lastValue end,
		events = {"UNIT_POWER_FREQUENT", "UNIT_MAXPOWER"}
	}
}

local RESOURCE_BAR_KEYS = {
	energyColor = true,
	rageColor = true,
	healthColor = true,
	manaColor = true,
	comboActiveColor = true,
	comboMaxColor = true,
	comboInactiveColor = true,
	comboStyle = "circle",
	comboCelebration = true,
	comboAnimQuality = true,
	fullCPSound = true,
	barTexture = true,
	barTextureQuality = true,
	healthHeight = true,
	comboPositionX = true,
	comboPositionY = true,
	comboScale = true,
	comboTextPositionX = true,
	comboTextPositionY = true,
	locked = true,
	comboEnabled = true,
	comboTextEnabled = true,
	energyEnabled = true,
	energyScale = true,
	rageEnabled = true,
	rageScale = true,
	healthEnabled = true,
	healthScale = true,
	manaEnabled = true,
	manaScale = true,
}

function ResourceBar:GetSettings()
	return self.db
end

function ResourceBar:SetSetting(key, value)
	if not RESOURCE_BAR_KEYS[key] then
		error("ResourceBar:SetSetting - unknown setting key '"..tostring(key).."'", 2)
	end
	self.db[key] = value
end

function ResourceBar:Initialize()
	if self.initialized then return end
	self.db = SoundAlerter.db1.profile.resourceBar
	self.initialized = false

	self.cachedColors = {}

	self.lastValues = {
		energy = -1,
		rage = -1,
		health = -1,
		mana = -1,
		combo = -1
	}

	self.lastText = {
		energy = "",
		rage = "",
		health = "",
		mana = "",
		combo = ""
	}

	self.lastBarUpdate = {
		energy = nil,
		rage = nil,
		health = nil,
		mana = nil,
		combo = nil
	}

	self.comboStrings = {"0/5", "1/5", "2/5", "3/5", "4/5", "5/5"}

	self.cachedTime = 0

	self.extents = {}
	self.animating = {}
	self.updaters = {}

	for barKey, config in pairs(BAR_CONFIGS) do
		self:CreateResourceBar(barKey, config)
	end

	self:CreateCPFrame()
	self:CreateCPTextFrame()
	self:RegisterEvents()
	self:LoadSettings()
	self:ApplyBarTexture()
	self:CacheColors()
	self:UpdateVisibility()

	self.initialized = true
end

function ResourceBar:CacheColors()
	if not self.db then return end

	self.cachedColors.energy = self.db.energyColor
	self.cachedColors.rage = self.db.rageColor
	self.cachedColors.health = self.db.healthColor
	self.cachedColors.mana = self.db.manaColor
	self.cachedColors.comboActive = self.db.comboActiveColor
	self.cachedColors.comboMax = self.db.comboMaxColor
	self.cachedColors.comboInactive = self.db.comboInactiveColor
end

function ResourceBar:RefreshComboColors()
	self:PaintComboPoints(self.lastComboPoints or 0)
end

function ResourceBar:SaveComboPosition()
	SoundAlerter.BarUtils:SavePosition(self.comboFrame, SoundAlerter.db1.profile.resourceBar, "combo")
end

function ResourceBar:SaveComboTextPosition()
	SoundAlerter.BarUtils:SavePosition(self.comboTextFrame, SoundAlerter.db1.profile.resourceBar, "comboText")
end

function ResourceBar:SaveBarPosition(barKey)
	local frameName = barKey .. "Frame"
	SoundAlerter.BarUtils:SavePosition(self[frameName], SoundAlerter.db1.profile.resourceBar, barKey)
end

function ResourceBar:CreateResourceBar(barKey, config)
	local frameName = barKey .. "Frame"
	local barName = barKey .. "Bar"
	local textName = barKey .. "Text"

	self[frameName] = SoundAlerter.BarUtils:CreateContainerFrame(config.globalName, BAR_WIDTH + 20, BAR_HEIGHT + 20, config.defaultY, self.db, function()
		self:SaveBarPosition(barKey)
	end)

	self[barName] = SoundAlerter.BarUtils:CreateStatusBarWidget(self[frameName], BAR_WIDTH, BAR_HEIGHT, 0, 100)
	self[barName]:SetValue(config.textFormat == "percent" and 100 or 0)

	SoundAlerter.BarUtils:CreateBackdrop(self[barName], 0.5, 0.5, 0.5, 1,
		"Interface\\DialogFrame\\UI-DialogBox-Background", 0, 0, 0, 0.8)

	self[textName] = SoundAlerter.BarUtils:CreateFontString(self[barName])
	self[textName]:SetPoint("CENTER")
	local initialText = config.textFormat == "percent" and "100%" or "0"
	self[textName]:SetText(initialText)
	self.lastText[barKey] = initialText

	self[barName].glow = self[barName]:CreateTexture(nil, "BACKGROUND")
	self[barName].glow:SetAllPoints(self[frameName])
	self[barName].glow:SetTexture("Interface\\FullScreenTextures\\LowHealth")
	self[barName].glow:SetBlendMode("ADD")
	self[barName].glow:SetAlpha(0)

	self[frameName]:Hide()
end

function ResourceBar:ApplyLowPowerAnimation(bar, percent, color, time)
	if percent < 25 then
		local animTime = (time * 2) % TWO_PI
		local pulse = 0.7 + (math_sin(animTime) * 0.3)
		local vibrate = math_sin(time * 8) * 0.15

		if color then
			bar:SetStatusBarColor(color.r * pulse, color.g * pulse, color.b * pulse)
		end
		bar:SetBackdropBorderColor(0.8 + vibrate, 0.3 + vibrate, 0.3 + vibrate, 1)
	else
		if color then
			bar:SetStatusBarColor(color.r, color.g, color.b)
		end
		bar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	end
end

function ResourceBar:ApplyOvercapAnimation(bar, percent, color, time)
	if percent >= 95 then
		local animTime = (time * 0.5) % TWO_PI
		local glowPulse = math_sin(animTime) * 0.5 + 0.5
		if bar.glow and color then
			bar.glow:SetAlpha(glowPulse * 0.4)
			bar.glow:SetVertexColor(color.r, color.g, color.b, glowPulse * 0.4)
		end
	else
		if bar.glow then
			bar.glow:SetAlpha(0)
		end
	end
end

function ResourceBar:UpdateResourceBar(barKey, config)
	local barName = barKey .. "Bar"
	local textName = barKey .. "Text"
	local bar = self[barName]

	if not bar then return end

	local current, max = config.getValueFunc()
	if current == nil or max == nil then return end

	if issecretvalue(current) or issecretvalue(max) then
		local color = self.cachedColors[barKey]
		if color then
			bar:SetStatusBarColor(color.r, color.g, color.b)
		end
		pcall(bar.SetMinMaxValues, bar, 0, max)
		pcall(bar.SetValue, bar, current)
		pcall(self[textName].SetFormattedText, self[textName], "%d", current)

		self.lastValues[barKey] = nil
		self.lastText[barKey] = nil
		self:SetAnimating(barKey, false)
		return
	end

	if max == 0 then return end

	if config.shouldUpdate(self, current, self.lastValues[barKey]) then
		local extent = self.extents[barKey] or BAR_WIDTH
		bar:SetMinMaxValues(0, max)
		bar:SetValue(math_floor(current / max * extent + 0.5) / extent * max)

		local newText = tostring(current)

		if newText ~= self.lastText[barKey] then
			self[textName]:SetText(newText)
			self.lastText[barKey] = newText
		end

		self.lastValues[barKey] = current
	end

	local percent = (current / max) * 100
	local color = self.cachedColors[barKey]
	local time = GetTime()
	self.cachedTime = time

	self:ApplyLowPowerAnimation(bar, percent, color, time)
	self:ApplyOvercapAnimation(bar, percent, color, time)

	self:SetAnimating(barKey, percent < 25 or percent >= 95)
end

function ResourceBar:SetAnimating(barKey, on)
	local frame = self[barKey .. "Frame"]
	if not frame or self.animating[barKey] == on then return end

	self.animating[barKey] = on

	if not on then
		frame:SetScript("OnUpdate", nil)
		return
	end

	local updater = self.updaters[barKey]
	if not updater then
		local config = BAR_CONFIGS[barKey]
		updater = function()
			local shouldUpdate, now = SoundAlerter.BarUtils:ShouldUpdate(self.lastBarUpdate[barKey], config.updateFreq)
			if shouldUpdate then
				self.lastBarUpdate[barKey] = now
				self:UpdateResourceBar(barKey, config)
			end
		end
		self.updaters[barKey] = updater
	end

	frame:SetScript("OnUpdate", updater)
end

function ResourceBar:RefreshBar(barKey)
	local frame = self[barKey .. "Frame"]
	if frame and frame:IsShown() then
		self:UpdateResourceBar(barKey, BAR_CONFIGS[barKey])
	end
end

function ResourceBar:CreateCPFrame()
	self.comboFrame = CreateFrame("Frame", "SoundAlerterResourceBar_Combo", UIParent)
	self.comboFrame:SetSize(CP_CONTAINER_WIDTH + 20, CP_HEIGHT + 20)
	self.comboFrame:SetFrameStrata("MEDIUM")
	self.comboFrame:SetFrameLevel(10)
	self.comboFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -85)

	SoundAlerter.BarUtils:MakeDraggable(self.comboFrame, self.db, function()
		self:SaveComboPosition()
	end)

	self.comboPoints = {}

	for i = 1, 5 do
		local cpFrame = CreateFrame("Frame", nil, self.comboFrame)
		cpFrame:SetSize(CP_HEIGHT, CP_HEIGHT)

		cpFrame.texture = cpFrame:CreateTexture(nil, "ARTWORK")
		cpFrame.texture:SetAllPoints(cpFrame)
		cpFrame.texture:SetVertexColor(0.25, 0.25, 0.25, 1)

		if i == 1 then
			cpFrame:SetPoint("LEFT", self.comboFrame, "LEFT", 10, 0)
		else
			cpFrame:SetPoint("LEFT", self.comboPoints[i-1], "RIGHT", CP_SPACING, 0)
		end

		self.comboPoints[i] = cpFrame
	end

	self.celebration = SoundAlerter.CPCelebration:Create(self.comboFrame, self.comboPoints, CP_SPACING, self.cachedColors)

	self:ApplyCPStyle()
	self.comboFrame:Hide()
end

function ResourceBar:ApplyCPStyle()
	if not self.comboPoints or not self.db then return end

	local style = self.db.comboStyle
	if not CP_SHAPE_TEXTURES[style] and style ~= "square" then style = "circle" end
	local path = CP_SHAPE_TEXTURES[style]

	for i = 1, 5 do
		local cp = self.comboPoints[i]
		if cp and cp.texture then
			if path then
				cp.texture:SetTexture(path)
			else
				cp.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
			end
			cp.texture:SetTexCoord(0, 1, 0, 1)
		end
	end
end

function ResourceBar:CreateCPTextFrame()
	self.comboTextFrame = CreateFrame("Frame", "SoundAlerterResourceBar_ComboText", UIParent)
	self.comboTextFrame:SetSize(80, 30)
	self.comboTextFrame:SetFrameStrata("MEDIUM")
	self.comboTextFrame:SetFrameLevel(11)
	self.comboTextFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -50)

	SoundAlerter.BarUtils:MakeDraggable(self.comboTextFrame, self.db, function()
		self:SaveComboTextPosition()
	end)

	self.comboText = self.comboTextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	self.comboText:SetPoint("CENTER")
	self.comboText:SetText("0/5")
	self.comboText:SetTextColor(1, 1, 1, 1)

	self.comboTextFrame:Hide()
end

function ResourceBar:RegisterEvents()
	for barKey, config in pairs(BAR_CONFIGS) do
		local frame = self[barKey .. "Frame"]
		local powerToken = config.powerToken

		for _, event in ipairs(config.events) do
			frame:RegisterUnitEvent(event, "player")
		end

		frame:SetScript("OnEvent", function(_, _, unitId, powerType)
			if unitId ~= "player" then return end
			if powerToken and powerType ~= powerToken then return end
			self:RefreshBar(barKey)
		end)
	end

	self.comboFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
	self.comboFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	self.comboFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
	self.comboFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	self.comboFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.comboFrame:RegisterEvent("UI_SCALE_CHANGED")
	self.comboFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")

	self.comboFrame:SetScript("OnEvent", function(_, event, ...)
		if ResourceBar[event] then
			ResourceBar[event](ResourceBar, event, ...)
		end
	end)
end

function ResourceBar:UNIT_POWER_FREQUENT(event, unitId, powerType)
	if unitId ~= "player" then return end

	if powerType == "COMBO_POINTS" and self.comboFrame and self.comboFrame:IsShown() then
		self:UpdateComboPoints()
	end
end

function ResourceBar:UI_SCALE_CHANGED()
	self:LoadSettings()
end

function ResourceBar:DISPLAY_SIZE_CHANGED()
	self:LoadSettings()
end

function ResourceBar:UNIT_MAXPOWER(event, unitId, powerType)
	if unitId ~= "player" then return end
	self:UNIT_POWER_FREQUENT(event, unitId, powerType)
end

function ResourceBar:UNIT_POWER_UPDATE(event, unitId, powerType)
	if unitId ~= "player" then return end
	self:UNIT_POWER_FREQUENT(event, unitId, powerType)
end

function ResourceBar:PLAYER_TARGET_CHANGED()
	self.targetChangedAt = GetTime()
	if self.comboFrame and self.comboFrame:IsShown() then
		self:UpdateComboPoints()
	end
end

function ResourceBar:PLAYER_ENTERING_WORLD()
	self:UpdateVisibility()
	self:UpdateEnergyBar()
	self:UpdateRageBar()
	self:UpdateHealthBar()
	self:UpdateManaBar()
	self:UpdateComboPoints()
end

function ResourceBar:UpdateEnergyBar()
	self:UpdateResourceBar("energy", BAR_CONFIGS.energy)
end

function ResourceBar:UpdateRageBar()
	self:UpdateResourceBar("rage", BAR_CONFIGS.rage)
end

function ResourceBar:UpdateHealthBar()
	self:UpdateResourceBar("health", BAR_CONFIGS.health)
end

function ResourceBar:UpdateManaBar()
	self:UpdateResourceBar("mana", BAR_CONFIGS.mana)
end

function ResourceBar:UpdateComboPoints()
	if not self.comboPoints or self.previewing then return end

	local cpRaw = GetComboPoints("player", "target")
	if issecretvalue(cpRaw) then return end
	self:SetComboPoints(cpRaw or 0)
end

function ResourceBar:PaintComboPoints(cp)
	local activeColor = (cp == 5) and self.cachedColors.comboMax or self.cachedColors.comboActive
	local inactiveColor = self.cachedColors.comboInactive

	for i = 1, 5 do
		local color = (i <= cp) and activeColor or inactiveColor
		if color then
			self.comboPoints[i].texture:SetVertexColor(color.r, color.g, color.b, 1)
		end
	end
end

function ResourceBar:ComboLossKind()
	if GetTime() - (self.targetChangedAt or 0) < TARGET_SWITCH_WINDOW then return "lost" end
	if Plain(UnitExists("target")) == false then return "lost" end
	if Plain(UnitIsDeadOrGhost("target")) == true then return "lost" end
	return "spent"
end

function ResourceBar:SetComboPoints(cp, forcedKind)
	local lastCP = self.lastComboPoints or 0
	if cp == lastCP then return end

	self:PaintComboPoints(cp)

	local kind
	if cp < lastCP then kind = forcedKind or self:ComboLossKind() end
	SoundAlerter.CPCelebration:Change(self.celebration, lastCP, cp, kind)
	if cp == 5 and self.db.fullCPSound then
		PlaySound(SOUNDKIT and SOUNDKIT.AUCTION_WINDOW_CLOSE or 5275)
	end

	self.lastComboPoints = cp

	if self.comboText then
		local newText = self.comboStrings[cp + 1]
		if newText ~= self.lastText.combo then
			self.comboText:SetText(newText)
			self.lastText.combo = newText
		end
	end
end

function ResourceBar:ApplyCelebration()
	local fx = self.celebration
	if not fx or not self.db then return end

	local Celebration = SoundAlerter.CPCelebration
	local cp = self.lastComboPoints or 0
	self.db.comboCelebration = Celebration:Normalize(self.db.comboCelebration)
	self.db.comboAnimQuality = Celebration:NormalizeQuality(self.db.comboAnimQuality)
	Celebration:Apply(fx, self.db.comboCelebration, cp, self.db.comboAnimQuality)
	self:PaintComboPoints(cp)
end

function ResourceBar:CancelAllCPAnimations()
	if self.celebration then
		SoundAlerter.CPCelebration:Reset(self.celebration)
	end
end

function ResourceBar:PreviewCelebration(kind)
	if not self.comboFrame or not self.comboFrame:IsShown() then return end

	self.previewToken = (self.previewToken or 0) + 1
	local token = self.previewToken
	self.previewing = true
	self:SetComboPoints(0, "lost")

	for step = 1, 5 do
		C_Timer.After(step * 0.45, function()
			if self.previewToken == token then self:SetComboPoints(step) end
		end)
	end
	C_Timer.After(5.6, function()
		if self.previewToken == token then self:SetComboPoints(0, kind) end
	end)
	C_Timer.After(7.6, function()
		if self.previewToken ~= token then return end
		self.previewing = false
		self:UpdateComboPoints()
	end)
end

function ResourceBar:ApplyBarTexture()
	if not self.db then return end

	local texture = SoundAlerter.BarTexture:Normalize(self.db.barTexture)
	self.db.barTexture = texture
	local quality = SoundAlerter.BarTexture:NormalizeQuality(self.db.barTextureQuality)

	for barKey in pairs(BAR_CONFIGS) do
		local barName = barKey .. "Bar"
		if self[barName] then
			SoundAlerter.BarTexture:Apply(self[barName], texture, quality)
		end
	end
end

function ResourceBar:LoadSettings()
	if not self.db then return end

	local BarUtils = SoundAlerter.BarUtils

	for barKey, config in pairs(BAR_CONFIGS) do
		local frame = self[barKey .. "Frame"]
		local bar = self[barKey .. "Bar"]

		if frame then
			frame:SetScale(self.db[barKey .. "Scale"] or 1.0)

			local height = barKey == "health" and (self.db.healthHeight or BAR_HEIGHT) or BAR_HEIGHT
			local barWidth = BarUtils:Snap(BAR_WIDTH, frame)
			local barHeight = BarUtils:Snap(height, frame)

			bar:SetSize(barWidth, barHeight)
			frame:SetSize(BarUtils:Snap(BAR_WIDTH + 20, frame), BarUtils:Snap(height + 20, frame))

			self.extents[barKey] = math_max(1, math_floor(barWidth * BarUtils:PixelsPerUnit(bar) + 0.5))
			self.lastValues[barKey] = -1

			BarUtils:LoadPosition(frame, self.db, barKey, 0, config.defaultY)
			self:RefreshBar(barKey)
		end
	end

	if self.comboFrame then
		self.comboFrame:SetScale(self.db.comboScale or 1.0)
		self:ApplyComboLayout()
		BarUtils:LoadPosition(self.comboFrame, self.db, "combo", 0, -85)
	end

	if self.comboTextFrame then
		BarUtils:LoadPosition(self.comboTextFrame, self.db, "comboText", 0, -50)
	end
end

function ResourceBar:ApplyComboLayout()
	local BarUtils = SoundAlerter.BarUtils
	local frame = self.comboFrame

	local size = BarUtils:Snap(CP_HEIGHT, frame)
	local spacing = BarUtils:Snap(CP_SPACING, frame)
	local inset = BarUtils:Snap(10, frame)

	frame:SetSize(BarUtils:Snap(CP_CONTAINER_WIDTH + 20, frame), BarUtils:Snap(CP_HEIGHT + 20, frame))
	SoundAlerter.CPCelebration:SetInset(self.celebration, inset)

	for i = 1, 5 do
		local cp = self.comboPoints[i]
		cp:SetSize(size, size)
		cp:ClearAllPoints()
		if i == 1 then
			cp:SetPoint("LEFT", frame, "LEFT", inset, 0)
		else
			cp:SetPoint("LEFT", self.comboPoints[i - 1], "RIGHT", spacing, 0)
		end
	end
end

function ResourceBar:StopBarUpdates(barKey)
	self:SetAnimating(barKey, false)
	self.lastBarUpdate[barKey] = nil
end

function ResourceBar:StartComboUpdates()
	if not self.comboFrame then return end

end

function ResourceBar:StopComboUpdates()
	if not self.comboFrame then return end

	self:CancelAllCPAnimations()

	self.lastBarUpdate.combo = nil
end

function ResourceBar:UpdateVisibility()
	if not self.db then return end

	for barKey, config in pairs(BAR_CONFIGS) do
		local frameName = barKey .. "Frame"
		local frame = self[frameName]
		local enabledKey = barKey .. "Enabled"

		if frame then
			if self.db[enabledKey] then
				frame:Show()
				frame:EnableMouse(not self.db.locked)
				self:UpdateResourceBar(barKey, config)
			else
				frame:Hide()
				self:StopBarUpdates(barKey)
			end

		end
	end

	if self.comboFrame then
		if self.db.comboEnabled then
			local wasHidden = not self.comboFrame:IsShown()
			self.comboFrame:Show()
			self.comboFrame:EnableMouse(not self.db.locked)
			if wasHidden then self:ApplyCelebration() end
			self:UpdateComboPoints()
			self:StartComboUpdates()
		else
			self.comboFrame:Hide()
			self:StopComboUpdates()
		end
	end

	if self.comboTextFrame then
		if self.db.comboTextEnabled then
			self.comboTextFrame:Show()
			self.comboTextFrame:EnableMouse(not self.db.locked)
		else
			self.comboTextFrame:Hide()
		end
	end
end

function ResourceBar:SetLocked(locked)
	if not self.db then return end

	self.db.locked = locked
	self:UpdateVisibility()
end

function ResourceBar:OnProfileChanged()
	self.db = SoundAlerter.db1.profile.resourceBar
	self:CacheColors()
	self:LoadSettings()
	self:ApplyBarTexture()
	self:ApplyCelebration()
	self:UpdateVisibility()
end
