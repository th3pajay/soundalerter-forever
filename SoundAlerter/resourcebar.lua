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
local FADE_TIME = 0.3
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

local POISED = {
	ROGUE = { spellID = 1328825, level = 18 },
	DRUID = { spellID = 1328829, level = 32 },
}
local RUNE_SCALE = 1.2
local RUNE_GAP = 4
local RUNE_COLOR = { 1, 0.83, 0.42 }
local RUNE_DISC_ALPHA = 0.22
local RUNE_TEXTURES = {
	disc = CP_TEXTURE_DIR .. "poised_disc",
	ring = CP_TEXTURE_DIR .. "poised_ring",
	glyph = CP_TEXTURE_DIR .. "poised_p",
	glow = CP_TEXTURE_DIR .. "poised_p_glow",
	flash = CP_TEXTURE_DIR .. "cp_glow",
	sheen = CP_TEXTURE_DIR .. "cb_spark",
}
local RUNE_FADE_IN, RUNE_FADE_OUT = 0.26, 0.2
local RUNE_LEAVE, RUNE_LEAVE_QUICK = 0.48, 0.32
local RUNE_RING_TURN = 24
local RUNE_BREATH_LOW, RUNE_BREATH_TIME = 0.74, 1.5
local RUNE_MOTES = 3
local FLAT_TEXTURE = "Interface\\Buttons\\WHITE8X8"

local VALUE_UPDATE_THROTTLE = 0.016
local ENERGY_UPDATE_THROTTLE = 0.01
local TWO_PI = math_pi * 2
local Furor = SA_FurorModel
local ENERGY_SCALE = 100
local ESTIMATE_ALPHA = 0.45
local ESTIMATE_TICK = 0.25
local ESTIMATE_TEXT = "on shift"
local SHIFT_MARKS = 8
local SHIFT_FORM_IDS = { 768, 5487 }
local NOTCH_WIDTH, NOTCH_HEIGHT = 12, 7
local NOTCH_TEXTURE = CP_TEXTURE_DIR .. "cp_triangle"
local NOTCH_GLOW = CP_TEXTURE_DIR .. "cp_glow"
local NOTCH_GHOST = { 0.86, 0.91, 1, 0.22 }
local NOTCH_LIT = { 1, 0.81, 0.35, 1 }
local NOTCH_GLOW_COLOR = { 1, 0.81, 0.35, 0.55 }
local NOTCH_GLOW_SCALE = 2
local NOTCH_BREATH_LOW = 0.6
local NOTCH_BREATH_TIME = 1.3

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
		isActive = function() return UnitPowerType("player") == POWER_TYPE_ENERGY end,
		formEvent = "UNIT_DISPLAYPOWER",
		estimate = true,
		events = {"UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER"}
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
		isActive = function() return UnitPowerType("player") == POWER_TYPE_RAGE end,
		formEvent = "UNIT_DISPLAYPOWER",
		fadeKey = "rageFade",
		events = {"UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER"}
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

function ResourceBar:GetSettings()
	return self.db
end

function ResourceBar:Initialize()
	if self.initialized then return end
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
	self.idle = {}
	self.faded = {}
	self.fadeGroups = {}
	self.updaters = {}

	for barKey, config in pairs(BAR_CONFIGS) do
		self:CreateResourceBar(barKey, config)
	end

	self:CreateCPFrame()
	self:CreateCPTextFrame()
	self:RegisterEvents()

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

function ResourceBar:SetFaded(barKey, faded)
	local previous = self.faded[barKey]
	if previous == faded then return end
	local wasCurve = previous == "curve"

	local frame = self[barKey .. "Frame"]
	local group = self.fadeGroups[barKey]
	if not group then
		group = frame:CreateAnimationGroup()
		group.anim = group:CreateAnimation("Alpha")
		group.anim:SetDuration(FADE_TIME)
		group.anim:SetSmoothing("IN_OUT")
		group:SetScript("OnFinished", function(finished)
			frame:SetAlpha(finished.target)
		end)
		self.fadeGroups[barKey] = group
	end

	group:Stop()
	group.target = faded and 0 or 1
	if wasCurve then frame:SetAlpha(group.target) end
	group.anim:SetFromAlpha(wasCurve and group.target or (previous and 0 or 1))
	group.anim:SetToAlpha(group.target)
	group:Play()
	self.faded[barKey] = faded
end

function ResourceBar:ApplyFade(barKey, config, empty)
	if not config.fadeKey then return end
	self:SetFaded(barKey, (self.db[config.fadeKey] and self.db.locked and empty) and true or false)
end

function ResourceBar:EmptyCurve()
	if self.emptyCurve == nil then
		self.emptyCurve = false
		if C_CurveUtil and C_CurveUtil.CreateCurve and UnitPowerPercent and Enum and Enum.LuaCurveType then
			local ok, curve = pcall(C_CurveUtil.CreateCurve)
			if ok and curve then
				curve:SetType(Enum.LuaCurveType.Step)
				curve:AddPoint(0, 0)
				curve:AddPoint(0.000001, 1)
				self.emptyCurve = curve
			end
		end
	end
	return self.emptyCurve
end

function ResourceBar:ApplyFadeSecret(barKey, config)
	if not config.fadeKey then return end
	local curve = (self.db[config.fadeKey] and self.db.locked) and self:EmptyCurve()
	local ok, alpha
	if curve then
		ok, alpha = pcall(UnitPowerPercent, "player", config.powerType, false, curve)
	end
	if not ok then
		self:SetFaded(barKey, false)
		return
	end
	local group = self.fadeGroups[barKey]
	if group then group:Stop() end
	self[barKey .. "Frame"]:SetAlpha(alpha)
	self.faded[barKey] = "curve"
end

function ResourceBar:ShowInactive(barKey, config)
	if not self.idle[barKey] then
		self.idle[barKey] = true
		local bar = self[barKey .. "Bar"]
		local color = self.cachedColors[barKey]
		self:SetAnimating(barKey, false)
		bar:SetValue(0)
		if color then
			bar:SetStatusBarColor(color.r, color.g, color.b)
		end
		bar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
		if bar.glow then bar.glow:SetAlpha(0) end
		self[barKey .. "Text"]:SetText("0")
		self.lastValues[barKey] = nil
		self.lastText[barKey] = "0"
	end
	self:ApplyFade(barKey, config, true)
end

local function KnownSpell(id)
	if not IsPlayerSpell then return false end
	local ok, known = pcall(IsPlayerSpell, id)
	return ok and Plain(known) == true
end

function ResourceBar:BuildEstimate(barKey)
	local bar = self[barKey .. "Bar"]
	local clip = CreateFrame("Frame", nil, bar)
	clip:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	clip:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	clip:SetWidth(1)
	if clip.SetClipsChildren then clip:SetClipsChildren(true) end
	local fill = CreateFrame("StatusBar", nil, clip)
	fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	fill:SetStatusBarTexture(FLAT_TEXTURE)
	local edge = fill:GetStatusBarTexture()
	local regen = fill:CreateTexture(nil, "ARTWORK")
	regen:SetTexture(FLAT_TEXTURE)
	regen:SetPoint("TOPLEFT", edge, "TOPRIGHT", 0, 0)
	regen:SetPoint("BOTTOMLEFT", edge, "BOTTOMRIGHT", 0, 0)
	regen:Hide()
	local holder = CreateFrame("Frame", nil, bar)
	holder:SetAllPoints(bar)
	holder:SetFrameLevel(clip:GetFrameLevel() + 2)
	self[barKey .. "Text"]:SetParent(holder)
	local estimate = { clip = clip, fill = fill, regen = regen }
	self.estimate = estimate
	return estimate
end

function ResourceBar:ShowEstimate(barKey)
	local now = GetTime()
	local clock = self.furorClock
	if not clock then
		clock = Furor.NewClock()
		self.furorClock = clock
	end
	if clock.form == nil or clock.form == "cat" then self.furorRank = Furor.Rank(KnownSpell) end
	Furor.Note(clock, UnitPowerType("player") == POWER_TYPE_RAGE and "bear" or "other", now)
	local rank = self.furorRank or 0
	local bar = self[barKey .. "Bar"]
	if not self.estimating then
		self.estimating = true
		self.idle[barKey] = true
		self:SetAnimating(barKey, false)
		bar:SetValue(0)
		bar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
		if bar.glow then bar.glow:SetAlpha(0) end
		local text = rank > 0 and ESTIMATE_TEXT or "0"
		self[barKey .. "Text"]:SetText(text)
		self.lastText[barKey] = text
		self.lastValues[barKey] = nil
		local estimate = self.estimate or self:BuildEstimate(barKey)
		if rank > 0 then
			local color = self.cachedColors[barKey]
			local r, g, b = 1, 1, 0
			if color then r, g, b = color.r, color.g, color.b end
			estimate.fill:SetStatusBarColor(r, g, b, ESTIMATE_ALPHA)
			estimate.regen:SetVertexColor(r, g, b, ESTIMATE_ALPHA)
			estimate.width = bar:GetWidth()
			estimate.clip:SetWidth(estimate.width * Furor.Cap(rank) / ENERGY_SCALE)
			estimate.fill:SetMinMaxValues(0, ENERGY_SCALE / Furor.Share(rank))
			pcall(estimate.fill.SetValue, estimate.fill, self.catEnergy or 0)
			estimate.shown = nil
			estimate.clip:Show()
		else
			estimate.clip:Hide()
		end
	end
	self:DrawEstimate(now)
end

function ResourceBar:DrawEstimate(now)
	local estimate = self.estimate
	local rank = self.furorRank or 0
	if not (estimate and self.estimating and rank > 0) then return end
	local clock = self.furorClock
	local width = math_floor(estimate.width * Furor.Regen(rank, Furor.Outside(clock, now)) / ENERGY_SCALE + 0.5)
	if width ~= estimate.shown then
		estimate.shown = width
		if width < 1 then
			estimate.regen:Hide()
		else
			estimate.regen:SetWidth(width)
			estimate.regen:Show()
		end
	end
	local growing = Furor.Growing(clock, rank, now)
	if growing and not self.estimateTicker then
		if not self.estimateTick then
			self.estimateTick = function()
				if not (self.energyFrame and self.energyFrame:IsShown()) then
					self.estimateTicker:Cancel()
					self.estimateTicker = nil
					return
				end
				self:DrawEstimate(GetTime())
			end
		end
		self.estimateTicker = C_Timer.NewTicker(ESTIMATE_TICK, self.estimateTick)
	elseif not growing and self.estimateTicker then
		self.estimateTicker:Cancel()
		self.estimateTicker = nil
	end
end

function ResourceBar:EndEstimate(barKey)
	self.estimating = nil
	if self.estimate then self.estimate.clip:Hide() end
	if self.estimateTicker then
		self.estimateTicker:Cancel()
		self.estimateTicker = nil
	end
	self.lastText[barKey] = nil
	self.lastValues[barKey] = nil
end

function ResourceBar:UpdateResourceBar(barKey, config)
	local barName = barKey .. "Bar"
	local textName = barKey .. "Text"
	local bar = self[barName]

	if not bar then return end

	if config.isActive and not config.isActive() then
		if config.estimate then
			self:ShowEstimate(barKey)
		else
			self:ShowInactive(barKey, config)
		end
		return
	end
	self.idle[barKey] = nil

	local current, max = config.getValueFunc()
	if config.estimate then
		self.catEnergy = current
		if self.estimating then self:EndEstimate(barKey) end
		local clock = self.furorClock
		if clock and clock.form ~= "cat" then Furor.Note(clock, "cat", GetTime()) end
	end
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
		self:ApplyFadeSecret(barKey, config)
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

	self:ApplyFade(barKey, config, current == 0)

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

local SHIFTERS = { DRUID = true }
local STEADY_EVENTS = { "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER" }

function ResourceBar:RegisterEvents()
	local _, playerClass = UnitClass("player")
	if not SHIFTERS[playerClass] then
		for _, config in pairs(BAR_CONFIGS) do
			if config.formEvent then
				config.isActive, config.formEvent, config.estimate = nil, nil, nil
				config.events = STEADY_EVENTS
			end
		end
	end
	for barKey, config in pairs(BAR_CONFIGS) do
		local frame = self[barKey .. "Frame"]
		local powerToken = config.powerToken

		for _, event in ipairs(config.events) do
			frame:RegisterUnitEvent(event, "player")
		end

		local formEvent = config.formEvent
		frame:SetScript("OnEvent", function(_, event, unitId, powerType)
			if unitId ~= "player" then return end
			if formEvent and event == formEvent then
				self.idle[barKey] = nil
				self:RefreshBar(barKey)
				return
			end
			if self.idle[barKey] then return end
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

	local _, class = UnitClass("player")
	self.poisedInfo = POISED[class]
	if self.poisedInfo then
		self.poisedClass = class
		self.poisedEvents = CreateFrame("Frame")
		self.poisedEvents:RegisterEvent("PLAYER_LEVEL_UP")
		self.poisedEvents:SetScript("OnEvent", function(_, event, arg1, arg2)
			self:OnPoisedEvent(event, arg1, arg2)
		end)
	end
end

local function Notch(parent, layer, anchor, top, color, width, height, texture)
	local notch = parent:CreateTexture(nil, layer)
	notch:SetTexture(texture or NOTCH_TEXTURE)
	notch:SetVertexColor(color[1], color[2], color[3], color[4])
	notch:SetSize(width, height)
	if top then
		notch:SetTexCoord(0, 1, 1, 0)
		notch:SetPoint("TOP", anchor, "TOPRIGHT", 0, 0)
	else
		notch:SetPoint("BOTTOM", anchor, "BOTTOMRIGHT", 0, 0)
	end
	return notch
end

function ResourceBar:CreateShiftMarks()
	local bar = self.manaBar
	local level = bar:GetFrameLevel()
	local BarUtils = SoundAlerter.BarUtils
	local anchors = CreateFrame("Frame", nil, bar)
	anchors:SetAllPoints(bar)
	local ghost = CreateFrame("Frame", nil, bar)
	ghost:SetAllPoints(bar)
	ghost:SetFrameLevel(level + 2)
	local clip = CreateFrame("Frame", nil, bar)
	clip:SetClipsChildren(true)
	clip:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	clip:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
	clip:SetFrameLevel(level + 3)
	local lit = CreateFrame("Frame", nil, clip)
	lit:SetAllPoints(bar)
	local width, height = BarUtils:Snap(NOTCH_WIDTH, bar), BarUtils:Snap(NOTCH_HEIGHT, bar)
	local marks = {}
	for index = 1, SHIFT_MARKS do
		local step = CreateFrame("StatusBar", nil, anchors)
		step:SetAllPoints(bar)
		step:SetStatusBarTexture(FLAT_TEXTURE)
		local edge = step:GetStatusBarTexture()
		edge:SetAlpha(0)
		marks[index] = {
			step = step,
			edge = edge,
			pieces = {
				Notch(ghost, "ARTWORK", edge, true, NOTCH_GHOST, width, height),
				Notch(ghost, "ARTWORK", edge, false, NOTCH_GHOST, width, height),
				Notch(lit, "OVERLAY", edge, true, NOTCH_LIT, width, height),
				Notch(lit, "OVERLAY", edge, false, NOTCH_LIT, width, height),
			},
		}
	end
	local breath = lit:CreateAnimationGroup()
	breath:SetLooping("BOUNCE")
	local fade = breath:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(NOTCH_BREATH_LOW)
	fade:SetDuration(NOTCH_BREATH_TIME)
	fade:SetSmoothing("IN_OUT")
	self.shiftGhost, self.shiftClip, self.shiftLit, self.shiftMarks, self.shiftBreath = ghost, clip, lit, marks, breath
	self.shiftSize = { width, height }
	self.shiftEvents = CreateFrame("Frame")
	self.shiftEvents:SetScript("OnEvent", function(_, event, _, powerType)
		if event == "UNIT_MAXPOWER" and powerType ~= "MANA" then return end
		self:DrawShiftMarks()
	end)
end

local function ManaCost(spellID)
	local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
	if not ok or type(costs) ~= "table" then return nil end
	for index = 1, #costs do
		local entry = costs[index]
		if type(entry) == "table" and Plain(entry.type) == POWER_TYPE_MANA then
			local cost = Plain(entry.cost)
			if type(cost) == "number" and cost > 0 then return cost end
		end
	end
	return nil
end

local function ShiftCost()
	if not (C_Spell and C_Spell.GetSpellPowerCost) then return nil end
	local cheapest
	for index = 1, #SHIFT_FORM_IDS do
		local cost = ManaCost(SHIFT_FORM_IDS[index])
		if cost and (not cheapest or cost < cheapest) then cheapest = cost end
	end
	return cheapest
end

function ResourceBar:HideShiftMarks()
	if not self.shiftMarks then return end
	self.shiftBreath:Stop()
	self.shiftGhost:Hide()
	self.shiftClip:Hide()
end

function ResourceBar:ApplyShiftQuality()
	local quality = self.db and self.db.comboAnimQuality
	local breath = self.shiftBreath
	if quality == "low" then
		breath:Stop()
		self.shiftLit:SetAlpha(1)
	elseif not breath:IsPlaying() then
		breath:Play()
	end
	local glow = quality == "high"
	for index = 1, SHIFT_MARKS do
		local mark = self.shiftMarks[index]
		if glow and not mark.glows then
			local width, height = self.shiftSize[1] * NOTCH_GLOW_SCALE, self.shiftSize[2] * NOTCH_GLOW_SCALE
			mark.glows = {
				Notch(self.shiftLit, "ARTWORK", mark.edge, true, NOTCH_GLOW_COLOR, width, height, NOTCH_GLOW),
				Notch(self.shiftLit, "ARTWORK", mark.edge, false, NOTCH_GLOW_COLOR, width, height, NOTCH_GLOW),
			}
			for _, piece in ipairs(mark.glows) do piece:SetBlendMode("ADD") end
		end
		if mark.glows then
			local shown = glow and mark.shown
			mark.glows[1]:SetShown(shown)
			mark.glows[2]:SetShown(shown)
		end
	end
end

function ResourceBar:DrawShiftMarks()
	local cost = ShiftCost()
	local okMax, maxMana = pcall(UnitPowerMax, "player", POWER_TYPE_MANA)
	if not cost or not okMax or maxMana == nil then
		self:HideShiftMarks()
		return
	end
	local plainMax = Plain(maxMana)
	for index = 1, SHIFT_MARKS do
		local mark = self.shiftMarks[index]
		local value = index * cost
		local shown = not (plainMax and value > plainMax)
		if shown then
			mark.step:SetMinMaxValues(0, maxMana)
			mark.step:SetValue(value)
		end
		if mark.shown ~= shown then
			mark.shown = shown
			mark.step:SetShown(shown)
			for _, piece in ipairs(mark.pieces) do piece:SetShown(shown) end
		end
	end
	self.shiftGhost:Show()
	self.shiftClip:Show()
	self:ApplyShiftQuality()
end

function ResourceBar:RefreshShiftMarks()
	if not self.db then return end
	local setting = self.db.manaShiftMarks
	if type(setting) == "string" then
		setting = setting ~= "off"
		self.db.manaShiftMarks = setting
	end
	local _, class = UnitClass("player")
	local want = SHIFTERS[class] and self.db.manaEnabled and setting == true
	if not want then
		if self.shiftEvents then
			self.shiftEvents:UnregisterEvent("UNIT_MAXPOWER")
			self.shiftEvents:UnregisterEvent("SPELLS_CHANGED")
			self:HideShiftMarks()
		end
		return
	end
	if not self.shiftMarks then self:CreateShiftMarks() end
	self.shiftEvents:RegisterUnitEvent("UNIT_MAXPOWER", "player")
	self.shiftEvents:RegisterEvent("SPELLS_CHANGED")
	self:DrawShiftMarks()
end

local function Step(group, kind, order, duration, smoothing)
	local step = group:CreateAnimation(kind)
	step:SetOrder(order)
	step:SetDuration(duration)
	if smoothing then step:SetSmoothing(smoothing) end
	return step
end

local function Fade(group, order, from, to, duration, smoothing)
	local step = Step(group, "Alpha", order, duration, smoothing)
	step:SetFromAlpha(from)
	step:SetToAlpha(to)
	return step
end

local function Grow(group, order, factor, duration, smoothing)
	local step = Step(group, "Scale", order, duration, smoothing)
	step:SetScale(factor, factor)
	return step
end

local function Shift(group, order, x, y, duration, smoothing)
	local step = Step(group, "Translation", order, duration, smoothing)
	step:SetOffset(x, y)
	return step
end

local function Turn(group, order, degrees, duration, smoothing)
	local step = Step(group, "Rotation", order, duration, smoothing)
	step:SetDegrees(degrees)
	return step
end

local function RuneTexture(parent, layer, path, size, alpha, blend)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexture(path)
	texture:SetVertexColor(RUNE_COLOR[1], RUNE_COLOR[2], RUNE_COLOR[3], 1)
	texture:SetSize(size, size)
	texture:SetPoint("CENTER", parent, "CENTER", 0, 0)
	texture:SetAlpha(alpha)
	if blend then texture:SetBlendMode(blend) end
	return texture
end

function ResourceBar:CreateRune()
	local bar = self.energyBar
	local BarUtils = SoundAlerter.BarUtils
	local size = BarUtils:Snap(BAR_HEIGHT * RUNE_SCALE, bar)
	local gate = CreateFrame("Frame", nil, bar)
	gate:SetSize(size, size)
	gate:SetPoint("LEFT", bar, "RIGHT", BarUtils:Snap(RUNE_GAP, bar), 0)
	gate:SetFrameLevel(bar:GetFrameLevel() + 4)
	local holder = CreateFrame("Frame", nil, gate)
	holder:SetAllPoints(gate)
	holder:Hide()
	local glyphFrame = CreateFrame("Frame", nil, holder)
	glyphFrame:SetAllPoints(holder)
	glyphFrame:SetFrameLevel(holder:GetFrameLevel() + 2)

	local rune = { gate = gate, holder = holder, glyphFrame = glyphFrame, size = size }
	rune.disc = RuneTexture(holder, "BACKGROUND", RUNE_TEXTURES.disc, size, RUNE_DISC_ALPHA)
	rune.ring = RuneTexture(holder, "ARTWORK", RUNE_TEXTURES.ring, size, 0.85)
	rune.flash = RuneTexture(holder, "OVERLAY", RUNE_TEXTURES.flash, size * 2, 0, "ADD")
	rune.glow = RuneTexture(glyphFrame, "BACKGROUND", RUNE_TEXTURES.glow, size, 0.6, "ADD")
	rune.glyph = RuneTexture(glyphFrame, "ARTWORK", RUNE_TEXTURES.glyph, size, 1)

	local ringIn = rune.ring:CreateAnimationGroup()
	Fade(ringIn, 1, 0, 0, 0.42)
	Grow(ringIn, 1, 0.9, 0.01)
	Fade(ringIn, 2, 0, 0.85, 0.15)
	Grow(ringIn, 2, 1.12 / 0.9, 0.15, "OUT")
	Grow(ringIn, 3, 1 / 1.12, 0.19, "IN_OUT")
	local discIn = rune.disc:CreateAnimationGroup()
	Fade(discIn, 1, 0, 0, 0.01)
	Grow(discIn, 1, 0.85, 0.01)
	Fade(discIn, 2, 0, RUNE_DISC_ALPHA, 0.3)
	Grow(discIn, 2, 1 / 0.85, 0.3, "OUT")
	local glyphIn = glyphFrame:CreateAnimationGroup()
	local drop = size * 0.3
	Fade(glyphIn, 1, 0, 0, 0.12)
	Grow(glyphIn, 1, 1.35, 0.01)
	Shift(glyphIn, 1, 0, drop, 0.01)
	Fade(glyphIn, 2, 0, 1, 0.32)
	Grow(glyphIn, 2, 0.94 / 1.35, 0.32, "OUT")
	Shift(glyphIn, 2, 0, -drop, 0.32, "OUT")
	Grow(glyphIn, 3, 1.03 / 0.94, 0.1, "OUT")
	Grow(glyphIn, 4, 1 / 1.03, 0.1, "IN_OUT")
	glyphIn:SetScript("OnFinished", function() self:StartRuneIdle() end)
	local flashIn = rune.flash:CreateAnimationGroup()
	Fade(flashIn, 1, 0, 0, 0.38)
	Grow(flashIn, 1, 0.7, 0.01)
	Fade(flashIn, 2, 0, 0.85, 0.11)
	Grow(flashIn, 2, 1 / 0.7, 0.11, "OUT")
	Fade(flashIn, 3, 0.85, 0, 0.27, "IN")
	Grow(flashIn, 3, 1.5, 0.27, "OUT")
	local fadeIn = holder:CreateAnimationGroup()
	Fade(fadeIn, 1, 0, 1, RUNE_FADE_IN, "OUT")
	fadeIn:SetScript("OnFinished", function() self:StartRuneIdle() end)
	rune.appear = { ringIn, discIn, glyphIn }
	rune.flashIn, rune.fadeIn = flashIn, fadeIn

	local ringIdle = rune.ring:CreateAnimationGroup()
	ringIdle:SetLooping("REPEAT")
	Turn(ringIdle, 1, -360, RUNE_RING_TURN)
	local breathe = glyphFrame:CreateAnimationGroup()
	breathe:SetLooping("BOUNCE")
	Fade(breathe, 1, 1, RUNE_BREATH_LOW, RUNE_BREATH_TIME, "IN_OUT")
	rune.idle = { ringIdle, breathe }

	local ringOut = rune.ring:CreateAnimationGroup()
	rune.ringTurn = Turn(ringOut, 1, -260, RUNE_LEAVE, "IN")
	rune.ringShrink = Grow(ringOut, 1, 0.1, RUNE_LEAVE, "IN")
	local discOut = rune.disc:CreateAnimationGroup()
	rune.discShrink = Grow(discOut, 1, 0.2, RUNE_LEAVE, "IN")
	rune.discFade = Fade(discOut, 1, RUNE_DISC_ALPHA, 0, RUNE_LEAVE, "IN")
	local glyphOut = glyphFrame:CreateAnimationGroup()
	rune.glyphSwell = Grow(glyphOut, 1, 1.1, RUNE_LEAVE * 0.2, "OUT")
	rune.glyphPull = Grow(glyphOut, 2, 0.05 / 1.1, RUNE_LEAVE * 0.8, "IN")
	local holderOut = holder:CreateAnimationGroup()
	rune.holdLit = Fade(holderOut, 1, 1, 1, RUNE_LEAVE * 0.8)
	rune.holdDrop = Fade(holderOut, 2, 1, 0, RUNE_LEAVE * 0.2)
	holderOut:SetScript("OnFinished", function() self:EndRuneLeave() end)
	local fadeOut = holder:CreateAnimationGroup()
	Fade(fadeOut, 1, 1, 0, RUNE_FADE_OUT, "IN")
	fadeOut:SetScript("OnFinished", function() self:EndRuneLeave() end)
	rune.leave = { ringOut, discOut, glyphOut, holderOut }
	rune.fadeOut = fadeOut
	rune.leaveTime = RUNE_LEAVE

	local timerFrame = CreateFrame("Frame", nil, UIParent)
	timerFrame:SetSize(1, 1)
	timerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -10, -10)
	timerFrame:SetAlpha(0)
	local overdue = timerFrame:CreateAnimationGroup()
	rune.overdueStep = Fade(overdue, 1, 0, 0, SA_RuneModel.Window(SA_RuneModel.GAP))
	overdue:SetScript("OnFinished", function() self:OnRuneOverdue() end)
	rune.overdue, rune.window = overdue, SA_RuneModel.Window(SA_RuneModel.GAP)

	rune.state, rune.gap = "off", SA_RuneModel.GAP
	self.rune = rune
	self:BuildRuneExtras()
end

function ResourceBar:BuildRuneExtras()
	local rune = self.rune
	if rune.motes or self.db.comboAnimQuality ~= "high" then return end
	local size = rune.size
	rune.motes = {}
	for index = 1, RUNE_MOTES do
		local mote = RuneTexture(rune.holder, "OVERLAY", RUNE_TEXTURES.flash, size * 0.16, 0, "ADD")
		mote:ClearAllPoints()
		mote:SetPoint("CENTER", rune.holder, "CENTER", (index - 2) * size * 0.22, -size * 0.18)
		local rise = mote:CreateAnimationGroup()
		rise:SetLooping("REPEAT")
		Fade(rise, 1, 0, 0, 0.05 + (index - 1) * 0.6)
		Fade(rise, 2, 0, 0.9, 0.45, "OUT")
		Shift(rise, 2, (index - 2) * size * 0.06, size * 0.45, 1.8, "OUT")
		Grow(rise, 2, 0.3, 1.8, "IN")
		Fade(rise, 3, 0.9, 0, 1.35, "IN")
		rune.motes[index] = rise
	end
	local sheen = rune.glyphFrame:CreateTexture(nil, "OVERLAY")
	sheen:SetTexture(RUNE_TEXTURES.sheen)
	sheen:SetBlendMode("ADD")
	sheen:SetVertexColor(1, 1, 1, 1)
	sheen:SetSize(size * 0.3, size)
	sheen:SetPoint("RIGHT", rune.glyphFrame, "LEFT", 0, 0)
	sheen:SetAlpha(0)
	local mask = rune.glyphFrame:CreateMaskTexture()
	mask:SetTexture(RUNE_TEXTURES.glyph, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(rune.glyph)
	sheen:AddMaskTexture(mask)
	local sweep = sheen:CreateAnimationGroup()
	sweep:SetLooping("REPEAT")
	Fade(sweep, 1, 0.85, 0.85, 1.2)
	Shift(sweep, 1, size * 1.3, 0, 1.2, "IN_OUT")
	Fade(sweep, 2, 0, 0, 2.2)
	rune.sweep = sweep
end

local function PlayAll(list)
	for index = 1, #list do list[index]:Play() end
end

local function StopAll(list)
	if not list then return end
	for index = 1, #list do list[index]:Stop() end
end

function ResourceBar:StopRuneMotion()
	local rune = self.rune
	StopAll(rune.appear)
	StopAll(rune.idle)
	StopAll(rune.leave)
	StopAll(rune.motes)
	rune.flashIn:Stop()
	rune.fadeIn:Stop()
	rune.fadeOut:Stop()
	if rune.sweep then rune.sweep:Stop() end
end

function ResourceBar:StartRuneIdle()
	local rune = self.rune
	if not rune or rune.state ~= "shown" then return end
	local quality = self.db.comboAnimQuality
	if quality == "low" then return end
	PlayAll(rune.idle)
	if quality == "high" then
		self:BuildRuneExtras()
		PlayAll(rune.motes)
		rune.sweep:Play()
	end
end

function ResourceBar:RuneCurve()
	if self.runeCurve == nil then
		self.runeCurve = false
		if C_CurveUtil and C_CurveUtil.CreateCurve and UnitPowerPercent and Enum and Enum.LuaCurveType then
			local ok, curve = pcall(C_CurveUtil.CreateCurve)
			if ok and curve then
				curve:SetType(Enum.LuaCurveType.Step)
				curve:AddPoint(0, 0)
				curve:AddPoint(1, 1)
				self.runeCurve = curve
			end
		end
	end
	return self.runeCurve
end

function ResourceBar:ApplyRuneGate()
	local rune = self.rune
	if rune.state == "leaving" then return end
	local curve = self:RuneCurve()
	if not curve then return end
	local ok, alpha = pcall(UnitPowerPercent, "player", POWER_TYPE_ENERGY, false, curve)
	if ok then rune.gate:SetAlpha(alpha) end
end

function ResourceBar:RestartRuneTimer()
	local rune = self.rune
	local window = SA_RuneModel.Window(rune.gap)
	if window ~= rune.window then
		rune.window = window
		rune.overdueStep:SetDuration(window)
	end
	rune.overdue:Stop()
	rune.overdue:Play()
end

function ResourceBar:ShowRune()
	local rune = self.rune
	rune.state = "shown"
	rune.doubt = false
	self:StopRuneMotion()
	self:ApplyRuneGate()
	rune.holder:SetAlpha(1)
	rune.holder:Show()
	if self.db.comboAnimQuality == "low" then
		rune.fadeIn:Play()
		return
	end
	PlayAll(rune.appear)
	if self.db.comboAnimQuality == "high" then rune.flashIn:Play() end
end

function ResourceBar:LeaveRune(quick)
	local rune = self.rune
	rune.state = "leaving"
	rune.doubt = false
	self:StopRuneMotion()
	rune.gate:SetAlpha(1)
	if self.db.comboAnimQuality == "low" then
		rune.fadeOut:Play()
		return
	end
	local time = quick and RUNE_LEAVE_QUICK or RUNE_LEAVE
	if time ~= rune.leaveTime then
		rune.leaveTime = time
		rune.ringTurn:SetDuration(time)
		rune.ringShrink:SetDuration(time)
		rune.discShrink:SetDuration(time)
		rune.discFade:SetDuration(time)
		rune.glyphSwell:SetDuration(time * 0.2)
		rune.glyphPull:SetDuration(time * 0.8)
		rune.holdLit:SetDuration(time * 0.8)
		rune.holdDrop:SetDuration(time * 0.2)
	end
	PlayAll(rune.leave)
end

function ResourceBar:EndRuneLeave()
	local rune = self.rune
	if rune.state ~= "leaving" then return end
	self:StopRuneMotion()
	rune.holder:Hide()
	rune.state = rune.armed and "armed" or "off"
	self:ApplyRuneGate()
end

function ResourceBar:OnRuneOverdue()
	local rune = self.rune
	if not (rune and rune.armed) then return end
	if rune.state == "armed" then
		self:ShowRune()
	elseif rune.state == "shown" then
		rune.doubt = false
	end
end

function ResourceBar:RuneEnergyForm()
	if self.poisedClass == "ROGUE" then return true end
	return Plain((UnitPowerType("player"))) == POWER_TYPE_ENERGY
end

function ResourceBar:RefreshRune(reason)
	local rune = self.rune
	if not rune then return end
	local armed = SA_RuneModel.Armed(rune.enabled, not InCombatLockdown(), self:RuneEnergyForm())
	if armed == rune.armed then return end
	rune.armed = armed
	local events = self.poisedEvents
	if armed then
		events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
		rune.last = nil
		if rune.state == "off" then rune.state = "armed" end
		self:ApplyRuneGate()
		self:RestartRuneTimer()
	else
		events:UnregisterEvent("UNIT_POWER_FREQUENT")
		rune.overdue:Stop()
		if rune.state == "shown" then
			self:LeaveRune(reason == "combat")
		elseif rune.state == "armed" then
			rune.state = "off"
		end
	end
end

function ResourceBar:OnRuneEnergy(powerType)
	if powerType ~= "ENERGY" then return end
	local rune = self.rune
	local now = GetTime()
	if rune.last then rune.gap = SA_RuneModel.Learn(rune.gap, now - rune.last) end
	rune.last = now
	if rune.state == "shown" and rune.doubt then
		self:DropRune()
	else
		rune.doubt = rune.state == "shown"
		self:ApplyRuneGate()
	end
	self:RestartRuneTimer()
end

function ResourceBar:DropRune()
	local rune = self.rune
	rune.doubt = false
	self:StopRuneMotion()
	rune.holder:Hide()
	rune.state = "armed"
	self:ApplyRuneGate()
end

function ResourceBar:OnPoisedEvent(event, arg1, arg2)
	if event == "UNIT_POWER_FREQUENT" then
		self:OnRuneEnergy(arg2)
	elseif event == "PLAYER_REGEN_DISABLED" then
		self:RefreshRune("combat")
	elseif event == "PLAYER_REGEN_ENABLED" or event == "UNIT_DISPLAYPOWER" then
		self:RefreshRune("form")
	elseif event == "PLAYER_LEVEL_UP" then
		self:UpdatePoisedTracking(arg1)
	end
end

function ResourceBar:ApplyPoisedQuality()
	local rune = self.rune
	if not rune or rune.state ~= "shown" then return end
	StopAll(rune.idle)
	StopAll(rune.motes)
	if rune.sweep then rune.sweep:Stop() end
	self:StartRuneIdle()
end

function ResourceBar:UpdatePoisedTracking(level)
	local info = self.poisedInfo
	if not info or not self.db then return end
	level = tonumber(level) or Plain(UnitLevel("player")) or 0
	local enabled = self.db.poisedGlow == true and self.db.energyEnabled == true and level >= info.level
	local events = self.poisedEvents
	if enabled then
		if not self.rune then self:CreateRune() end
		events:RegisterEvent("PLAYER_REGEN_DISABLED")
		events:RegisterEvent("PLAYER_REGEN_ENABLED")
		if self.poisedClass == "DRUID" then events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player") end
	else
		events:UnregisterEvent("PLAYER_REGEN_DISABLED")
		events:UnregisterEvent("PLAYER_REGEN_ENABLED")
		events:UnregisterEvent("UNIT_DISPLAYPOWER")
	end
	if not self.rune then return end
	self.rune.enabled = enabled
	self:RefreshRune("form")
end

function ResourceBar:UNIT_POWER_FREQUENT(event, unitId, powerType)
	if unitId ~= "player" then return end

	if powerType == "COMBO_POINTS" and self.comboFrame and self.comboFrame:IsShown() then
		self:UpdateComboPoints()
	end
end

function ResourceBar:UI_SCALE_CHANGED()
	self:Layout()
end

function ResourceBar:DISPLAY_SIZE_CHANGED()
	self:Layout()
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

function ResourceBar:RestoredOnCorpse(cp, lastCP)
	if cp <= lastCP then return false end
	if GetTime() - (self.targetChangedAt or 0) >= TARGET_SWITCH_WINDOW then return false end
	return Plain(UnitIsDeadOrGhost("target")) == true
end

function ResourceBar:SetComboPoints(cp, forcedKind)
	local lastCP = self.lastComboPoints or 0
	if cp == lastCP then return end

	self:PaintComboPoints(cp)

	if self:RestoredOnCorpse(cp, lastCP) then
		SoundAlerter.CPCelebration:Settle(self.celebration, cp)
	else
		local kind
		if cp < lastCP then kind = forcedKind or self:ComboLossKind() end
		SoundAlerter.CPCelebration:Change(self.celebration, lastCP, cp, kind)
		if cp == 5 and self.db.fullCPSound then
			PlaySound(SOUNDKIT and SOUNDKIT.AUCTION_WINDOW_CLOSE or 5275)
		end
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
	self.db.comboExit = Celebration:NormalizeExit(self.db.comboExit)
	Celebration:Apply(fx, self.db.comboCelebration, cp, self.db.comboAnimQuality)
	Celebration:SetExit(fx, self.db.comboExit)
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

local BAR_FRAMES = { energyScale = "energyFrame", rageScale = "rageFrame", healthScale = "healthFrame", manaScale = "manaFrame", comboScale = "comboFrame" }
local COLOR_UPDATES = { energyColor = "UpdateEnergyBar", rageColor = "UpdateRageBar", healthColor = "UpdateHealthBar", manaColor = "UpdateManaBar" }
local VISIBILITY = { locked = true, swingSpark = true, manaSweep = true, manaShiftMarks = true, energyEnabled = true, rageEnabled = true, rageFade = true, healthEnabled = true, manaEnabled = true, comboEnabled = true, comboTextEnabled = true }
local COMBO_COLORS = { comboActiveColor = true, comboMaxColor = true, comboInactiveColor = true }
local CELEBRATION_KEYS = { comboCelebration = true, comboAnimQuality = true, comboExit = true }

local function applyKey(bar, key)
	if key == "barTexture" or key == "barTextureQuality" then
		bar:ApplyBarTexture()
	elseif VISIBILITY[key] then
		bar:UpdateVisibility()
	elseif BAR_FRAMES[key] then
		local frame = bar[BAR_FRAMES[key]]
		if frame then frame:SetScale(bar.db[key]) end
	elseif COLOR_UPDATES[key] then
		bar:CacheColors()
		bar[COLOR_UPDATES[key]](bar)
	elseif CELEBRATION_KEYS[key] then
		bar:ApplyCelebration()
		if key == "comboAnimQuality" then
			bar:RefreshShiftMarks()
			bar:ApplyPoisedQuality()
		end
	elseif key == "poisedGlow" then
		bar:UpdatePoisedTracking()
	elseif key == "comboStyle" then
		bar:ApplyCPStyle()
	elseif COMBO_COLORS[key] then
		bar:CacheColors()
		bar:RefreshComboColors()
	end
end

function ResourceBar:Apply(changedKey)
	if not self.db then return end
	if changedKey ~= nil and changedKey ~= "healthHeight" then
		applyKey(self, changedKey)
		return
	end
	self:CacheColors()
	self:Layout()
	self:ApplyBarTexture()
	self:ApplyCelebration()
	self:UpdateVisibility()
end

function ResourceBar:Layout()
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

	self:UpdatePoisedTracking()
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

	if SoundAlerter.SwingSpark then SoundAlerter.SwingSpark:Refresh() end
	if SoundAlerter.ManaSweep then SoundAlerter.ManaSweep:Refresh() end
	self:RefreshShiftMarks()
	self:UpdatePoisedTracking()

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

function ResourceBar:ResetPositions()
	if not self.db then return end
	for barKey in pairs(BAR_CONFIGS) do
		self.db[barKey .. "PositionX"] = nil
		self.db[barKey .. "PositionY"] = nil
	end
	for _, prefix in ipairs({ "combo", "comboText" }) do
		self.db[prefix .. "PositionX"] = nil
		self.db[prefix .. "PositionY"] = nil
	end
	self:Layout()
end

function ResourceBar:SetLocked(locked)
	if not self.db then return end
	self:SetSetting("locked", locked)
end

SA_Modules.Register({ key = "ResourceBar", module = ResourceBar, db = "resourceBar", title = "Resource bars", nav = { section = "Displays", order = 21 }, options = "BuildResourceBarOptions", enabled = { "energyEnabled", "rageEnabled", "healthEnabled", "manaEnabled", "comboEnabled" } })
