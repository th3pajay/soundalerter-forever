local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
if not SoundAlerter then return end

local ResourceBar = {}
SoundAlerter.ResourceBar = ResourceBar

local math_sin = math.sin
local math_pi = math.pi
local GetTime = GetTime
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local GetComboPoints = GetComboPoints

local POWER_TYPE_MANA = 0
local POWER_TYPE_RAGE = 1
local POWER_TYPE_ENERGY = 3

local BAR_WIDTH = 280
local BAR_HEIGHT = 20
local CP_CONTAINER_WIDTH = 280
local CP_HEIGHT = 30
local CP_SPACING = 8

local VALUE_UPDATE_THROTTLE = 0.016
local ENERGY_UPDATE_THROTTLE = 0.01
local TWO_PI = math_pi * 2

local CP_DEFAULT_SCALE = 1.0
local CP_BOUNCE_AMOUNT = 0.15
local CP_CELEBRATION_BOUNCE = 0.25
local CP_BOUNCE_DURATION = 0.2
local CP_CELEBRATION_DURATION = 0.6
local CP_CELEBRATION_WAVE_DELAY = 0.08
local CP_CELEBRATION_CP_DURATION = 0.4

local BAR_CONFIGS = {
	energy = {
		key = "energy",
		globalName = "SoundAlerterResourceBar_Energy",
		powerType = POWER_TYPE_ENERGY,
		defaultY = -120,
		updateFreq = ENERGY_UPDATE_THROTTLE,
		textFormat = "number",
		getValueFunc = function() return UnitPower("player", POWER_TYPE_ENERGY), UnitPowerMax("player", POWER_TYPE_ENERGY) end,
		shouldUpdate = function(self, current, lastValue) return current ~= lastValue end,
		continuousUpdate = true,
		events = {"UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "PLAYER_ENTERING_WORLD"}
	},
	rage = {
		key = "rage",
		globalName = "SoundAlerterResourceBar_Rage",
		powerType = POWER_TYPE_RAGE,
		defaultY = -120,
		updateFreq = VALUE_UPDATE_THROTTLE,
		textFormat = "number",
		getValueFunc = function() return UnitPower("player", POWER_TYPE_RAGE), UnitPowerMax("player", POWER_TYPE_RAGE) end,
		shouldUpdate = function(self, current, lastValue) return current ~= lastValue end,
		continuousUpdate = false,
		events = {"UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "PLAYER_ENTERING_WORLD"}
	},
	health = {
		key = "health",
		globalName = "SoundAlerterResourceBar_Health",
		powerType = nil,
		defaultY = -140,
		updateFreq = VALUE_UPDATE_THROTTLE,
		textFormat = "percent",
		getValueFunc = function() return UnitHealth("player"), UnitHealthMax("player") end,
		shouldUpdate = function(self, current, lastValue) return current ~= lastValue end,
		continuousUpdate = false,
		events = {"UNIT_HEALTH", "UNIT_MAXHEALTH", "PLAYER_ENTERING_WORLD"}
	},
	mana = {
		key = "mana",
		globalName = "SoundAlerterResourceBar_Mana",
		powerType = POWER_TYPE_MANA,
		defaultY = -100,
		updateFreq = VALUE_UPDATE_THROTTLE,
		textFormat = "percent",
		getValueFunc = function() return UnitPower("player", POWER_TYPE_MANA), UnitPowerMax("player", POWER_TYPE_MANA) end,
		shouldUpdate = function(self, current, lastValue) return current ~= lastValue end,
		continuousUpdate = false,
		events = {"UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "PLAYER_ENTERING_WORLD"}
	}
}

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

	self.cpAnimationState = {
		running = {},
		celebration = false
	}

	self.lastBarUpdate = {
		energy = nil,
		rage = nil,
		health = nil,
		mana = nil,
		combo = nil
	}

	self.comboStrings = {"0/5", "1/5", "2/5", "3/5", "4/5", "5/5"}

	self.percentStrings = {}
	for i = 0, 100 do
		self.percentStrings[i] = string.format("%.0f%%", i)
	end

	self.cachedTime = 0

	self.screenWidth, self.screenHeight = UIParent:GetSize()

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
	self.lastComboPoints = -1
	self:UpdateComboPoints()
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
		if SoundAlerter.db1.profile.debugmode and self.lastValues[barKey] ~= nil then
			SoundAlerter:Print(string.format("[ResourceBar] %s using secret-value fallback (current/max not readable by addon code)", barKey))
		end
		local color = self.cachedColors[barKey]
		if color then
			bar:SetStatusBarColor(color.r, color.g, color.b)
		end
		pcall(bar.SetMinMaxValues, bar, 0, max)
		pcall(bar.SetValue, bar, current)
		if self.lastText[barKey] ~= "" then
			self[textName]:SetText("")
			self.lastText[barKey] = ""
		end
		self.lastValues[barKey] = nil
		return
	end

	if max == 0 then return end

	local shouldUpdate = config.shouldUpdate(self, current, self.lastValues[barKey])

	if shouldUpdate or config.continuousUpdate then
		if shouldUpdate then
			bar:SetMinMaxValues(0, max)
			bar:SetValue(current)

			local newText
			if config.textFormat == "percent" then
				local percent = (current / max) * 100
				local percentInt = math.floor(percent + 0.5)
				newText = self.percentStrings[percentInt]
			else
				newText = tostring(current)
			end

			if newText ~= self.lastText[barKey] then
				self[textName]:SetText(newText)
				self.lastText[barKey] = newText
			end

			self.lastValues[barKey] = current
		elseif config.continuousUpdate then
			bar:SetValue(current)
		end
	end

	local percent = (current / max) * 100
	local color = self.cachedColors[barKey]
	local time = self.cachedTime

	self:ApplyLowPowerAnimation(bar, percent, color, time)
	self:ApplyOvercapAnimation(bar, percent, color, time)
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

		cpFrame.sparks = cpFrame:CreateTexture(nil, "OVERLAY")
		cpFrame.sparks:SetAllPoints(cpFrame)
		cpFrame.sparks:SetTexture("Interface\\FullScreenTextures\\LowHealth")
		cpFrame.sparks:SetBlendMode("ADD")
		cpFrame.sparks:SetAlpha(0)

		cpFrame.glow = cpFrame:CreateTexture(nil, "BACKGROUND")
		cpFrame.glow:SetPoint("CENTER")
		cpFrame.glow:SetSize(CP_HEIGHT * 1.5, CP_HEIGHT * 1.5)
		cpFrame.glow:SetTexture("Interface\\FullScreenTextures\\LowHealth")
		cpFrame.glow:SetBlendMode("ADD")
		cpFrame.glow:SetAlpha(0)

		cpFrame.particles = cpFrame:CreateTexture(nil, "OVERLAY")
		cpFrame.particles:SetPoint("CENTER")
		cpFrame.particles:SetSize(CP_HEIGHT * 2, CP_HEIGHT * 2)
		cpFrame.particles:SetTexture("Interface\\Cooldown\\star4")
		cpFrame.particles:SetBlendMode("ADD")
		cpFrame.particles:SetAlpha(0)

		if i == 1 then
			cpFrame:SetPoint("LEFT", self.comboFrame, "LEFT", 10, 0)
		else
			cpFrame:SetPoint("LEFT", self.comboPoints[i-1], "RIGHT", CP_SPACING, 0)
		end

		self.comboPoints[i] = cpFrame
	end

	self:ApplyCPStyle()
	self.comboFrame:Hide()
end

function ResourceBar:ApplyCPStyle()
	if not self.comboPoints or not self.db then return end

	local style = self.db.comboStyle or "circle"

	for i = 1, 5 do
		local cp = self.comboPoints[i]
		if cp and cp.texture then
			if style == "square" then
				cp.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
				cp.texture:SetTexCoord(0, 1, 0, 1)
			elseif style == "circle" then
				local success = cp.texture:SetTexture("Interface\\AddOns\\SoundAlerter\\Textures\\circle")
				if not success then
					success = cp.texture:SetTexture("Interface\\Minimap\\Ping\\ping5")
				end
				if not success then
					cp.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
				end
				cp.texture:SetTexCoord(0, 1, 0, 1)
			end
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
	self.energyFrame:RegisterEvent("UNIT_POWER_FREQUENT")
	self.energyFrame:RegisterEvent("UNIT_MAXPOWER")
	self.energyFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	self.rageFrame:RegisterEvent("UNIT_POWER_FREQUENT")
	self.rageFrame:RegisterEvent("UNIT_MAXPOWER")
	self.rageFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	self.healthFrame:RegisterEvent("UNIT_HEALTH")
	self.healthFrame:RegisterEvent("UNIT_MAXHEALTH")
	self.healthFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	self.manaFrame:RegisterEvent("UNIT_POWER_FREQUENT")
	self.manaFrame:RegisterEvent("UNIT_MAXPOWER")
	self.manaFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	self.comboFrame:RegisterEvent("UNIT_POWER_FREQUENT")
	self.comboFrame:RegisterEvent("UNIT_POWER_UPDATE")
	self.comboFrame:RegisterEvent("UNIT_MAXPOWER")
	self.comboFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	self.comboFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	local function HandleEvents(frame, event, ...)
		if ResourceBar[event] then
			ResourceBar[event](ResourceBar, event, ...)
		end
	end

	self.energyFrame:SetScript("OnEvent", HandleEvents)
	self.rageFrame:SetScript("OnEvent", HandleEvents)
	self.healthFrame:SetScript("OnEvent", HandleEvents)
	self.manaFrame:SetScript("OnEvent", HandleEvents)
	self.comboFrame:SetScript("OnEvent", HandleEvents)
end

function ResourceBar:UNIT_POWER_FREQUENT(event, unitId, powerType)
	if unitId ~= "player" then return end

	if self.energyFrame and self.energyFrame:IsShown() then
		self.lastBarUpdate.energy = nil
	end

	if self.rageFrame and self.rageFrame:IsShown() then
		self.lastBarUpdate.rage = nil
	end

	if self.manaFrame and self.manaFrame:IsShown() then
		self.lastBarUpdate.mana = nil
	end

	if powerType == "COMBO_POINTS" and self.comboFrame and self.comboFrame:IsShown() then
		self:UpdateComboPoints()
	end
end

function ResourceBar:UNIT_MAXPOWER(event, unitId, powerType)
	if unitId ~= "player" then return end
	self:UNIT_POWER_FREQUENT(event, unitId, powerType)
end

function ResourceBar:UNIT_POWER_UPDATE(event, unitId, powerType)
	if unitId ~= "player" then return end
	self:UNIT_POWER_FREQUENT(event, unitId, powerType)
end

function ResourceBar:UNIT_HEALTH(event, unitId)
	if unitId ~= "player" then return end
	if self.healthFrame and self.healthFrame:IsShown() then
		self.lastBarUpdate.health = nil
	end
end

function ResourceBar:UNIT_MAXHEALTH(event, unitId)
	if unitId ~= "player" then return end
	self:UNIT_HEALTH(event, unitId)
end

function ResourceBar:PLAYER_TARGET_CHANGED()
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
	if not self.comboPoints then return end

	local cpRaw = GetComboPoints("player", "target")
	if issecretvalue(cpRaw) then return end
	local cp = cpRaw or 0
	local lastCP = self.lastComboPoints or 0

	if cp < lastCP then
		self:CancelAllCPAnimations()
	end

	if cp ~= lastCP then
		local activeColor = (cp == 5) and self.cachedColors.comboMax or self.cachedColors.comboActive
		local inactiveColor = self.cachedColors.comboInactive

		for i = 1, 5 do
			if i <= cp then
				if activeColor then
					self.comboPoints[i].texture:SetVertexColor(activeColor.r, activeColor.g, activeColor.b, 1)
				end

				if i > lastCP and i == cp and not (cp == 5 and lastCP == 4) then
					self:AnimateCPGain(i)
				end
			else
				if inactiveColor then
					self.comboPoints[i].texture:SetVertexColor(inactiveColor.r, inactiveColor.g, inactiveColor.b, 1)
				end
			end
		end

		if cp == 5 and lastCP == 4 then
			self:Animate5CPCelebrationWave()
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
end

function ResourceBar:CancelCPAnimation(cpIndex)
	local cp = self.comboPoints[cpIndex]
	if not cp then return end

	cp:SetScript("OnUpdate", nil)

	cp.bounceTime = nil
	cp.bounceStart = nil

	cp:SetScale(CP_DEFAULT_SCALE)

	if cp.sparks then cp.sparks:SetAlpha(0) end
	if cp.glow then cp.glow:SetAlpha(0) end
	if cp.particles then cp.particles:SetAlpha(0) end

	if self.cpAnimationState then
		self.cpAnimationState.running[cpIndex] = false
	end
end

function ResourceBar:CancelAllCPAnimations()
	for i = 1, 5 do
		self:CancelCPAnimation(i)
	end

	if self.comboFrame then
		self.comboFrame:SetScript("OnUpdate", nil)
		self.comboFrame.celebrationTime = nil
	end

	if self.cpAnimationState then
		self.cpAnimationState.celebration = false
	end
end

function ResourceBar:AnimateCPGain(cpIndex)
	local cp = self.comboPoints[cpIndex]
	if not cp then return end

	self:CancelCPAnimation(cpIndex)

	if self.cpAnimationState then
		self.cpAnimationState.running[cpIndex] = true
	end

	cp:SetScript("OnUpdate", function(frame, elapsed)
		if not frame.bounceTime then
			frame.bounceTime = 0
		end

		frame.bounceTime = frame.bounceTime + elapsed
		local progress = frame.bounceTime / CP_BOUNCE_DURATION

		if progress >= 1 then
			frame:SetScale(CP_DEFAULT_SCALE)
			frame:SetScript("OnUpdate", nil)
			frame.bounceTime = nil

			if cp.sparks then cp.sparks:SetAlpha(0) end

			if self.cpAnimationState then
				self.cpAnimationState.running[cpIndex] = false
			end
		else
			local scale = CP_DEFAULT_SCALE + (math_sin(progress * math_pi) * CP_BOUNCE_AMOUNT)
			frame:SetScale(scale)

			if cp.sparks then
				local alpha = 0.8 * (1 - progress)
				cp.sparks:SetAlpha(alpha)
				cp.sparks:SetVertexColor(1, 0.9, 0.3, alpha)
			end
		end
	end)
end

function ResourceBar:Animate5CPCelebrationWave()
	if not self.comboFrame then return end

	if SoundAlerter.db1.profile.debugmode then
		SoundAlerter:Print("[ResourceBar] 5 combo point celebration triggered")
	end

	for i = 1, 5 do
		self:CancelCPAnimation(i)
	end

	if self.cpAnimationState then
		self.cpAnimationState.celebration = true
	end

	if self.db.fullCPSound then
		PlaySound("AuctionWindowClose")
	end

	self.comboFrame:SetScript("OnUpdate", function(frame, elapsed)
		if not frame.celebrationTime then
			frame.celebrationTime = 0
		end

		frame.celebrationTime = frame.celebrationTime + elapsed
		local progress = frame.celebrationTime / CP_CELEBRATION_DURATION

		if progress >= 1 then
			for i = 1, 5 do
				local cp = self.comboPoints[i]
				if cp then
					if cp.glow then
						cp.glow:SetAlpha(0)
					end
					if cp.particles then
						cp.particles:SetAlpha(0)
					end
					if cp.sparks then
						cp.sparks:SetAlpha(0)
					end

					cp:SetScale(CP_DEFAULT_SCALE)

					local color = self.cachedColors.comboMax
					if color and cp.texture then
						cp.texture:SetVertexColor(color.r, color.g, color.b, 1)
					end
				end
			end
			frame:SetScript("OnUpdate", nil)
			frame.celebrationTime = nil

			if self.cpAnimationState then
				self.cpAnimationState.celebration = false
			end
		else
			for i = 1, 5 do
				local cp = self.comboPoints[i]
				if cp then
					local waveDelay = (i - 1) * CP_CELEBRATION_WAVE_DELAY
					local cpProgress = (frame.celebrationTime - waveDelay) / CP_CELEBRATION_CP_DURATION

					if cpProgress > 0 and cpProgress < 1 then
						local scale = CP_DEFAULT_SCALE + (math_sin(cpProgress * math_pi) * CP_CELEBRATION_BOUNCE)
						cp:SetScale(scale)

						if cp.glow then
							local glowAlpha = 0.9 * math_sin(cpProgress * math_pi)
							cp.glow:SetAlpha(glowAlpha)
							cp.glow:SetVertexColor(1, 0.8, 0.2, glowAlpha)
						end

						if cp.particles then
							local particleAlpha = math_sin(cpProgress * math_pi)
							local particleScale = 1 + (cpProgress * 1.5)
							cp.particles:SetAlpha(particleAlpha)
							cp.particles:SetVertexColor(1, 0.9, 0.3, particleAlpha)
							cp.particles:SetSize(CP_HEIGHT * 2 * particleScale, CP_HEIGHT * 2 * particleScale)
						end

						if cp.sparks then
							local sparksAlpha = 0.8 * math_sin(cpProgress * math_pi)
							cp.sparks:SetAlpha(sparksAlpha)
							cp.sparks:SetVertexColor(1, 0.9, 0.3, sparksAlpha)
						end

						if cp.texture then
							local flashProgress = cpProgress * 2
							if flashProgress < 1 then
								local flashIntensity = math_sin(flashProgress * math_pi)
								cp.texture:SetVertexColor(
									0.8 + (0.2 * flashIntensity),
									0.6 + (0.3 * flashIntensity),
									1.0,
									1
								)
							else
								local color = self.cachedColors.comboMax
								if color then
									cp.texture:SetVertexColor(color.r, color.g, color.b, 1)
								end
							end
						end
					elseif cpProgress >= 1 then
						cp:SetScale(CP_DEFAULT_SCALE)
						if cp.glow then
							cp.glow:SetAlpha(0)
						end
						if cp.particles then
							cp.particles:SetAlpha(0)
						end
						if cp.sparks then
							cp.sparks:SetAlpha(0)
						end
						local color = self.cachedColors.comboMax
						if color and cp.texture then
							cp.texture:SetVertexColor(color.r, color.g, color.b, 1)
						end
					end
				end
			end
		end
	end)
end

function ResourceBar:ApplyBarTexture()
	if not self.db then return end

	local texture = self.db.barTexture or "default"

	for barKey in pairs(BAR_CONFIGS) do
		local barName = barKey .. "Bar"
		if self[barName] then
			SoundAlerter.BarUtils:ApplyBarTexture(self[barName], texture)
		end
	end
end

function ResourceBar:LoadSettings()
	if not self.db then return end

	self.screenWidth, self.screenHeight = UIParent:GetSize()

	for barKey, config in pairs(BAR_CONFIGS) do
		local frameName = barKey .. "Frame"
		local barName = barKey .. "Bar"
		local frame = self[frameName]

		if frame then
			local xKey = barKey .. "PositionX"
			local yKey = barKey .. "PositionY"
			local scaleKey = barKey .. "Scale"

			local x = (self.db[xKey] or 0) + (self.screenWidth / 2)
			local y = (self.db[yKey] or config.defaultY) + (self.screenHeight / 2)
			frame:ClearAllPoints()
			frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
			frame:SetScale(self.db[scaleKey] or 1.0)

			if barKey == "health" then
				local height = self.db.healthHeight or BAR_HEIGHT
				self[barName]:SetSize(BAR_WIDTH, height)
				frame:SetSize(BAR_WIDTH + 20, height + 20)
			end
		end
	end

	if self.comboFrame then
		local x = (self.db.comboPositionX or 0) + (self.screenWidth / 2)
		local y = (self.db.comboPositionY or -85) + (self.screenHeight / 2)
		self.comboFrame:ClearAllPoints()
		self.comboFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
		self.comboFrame:SetScale(self.db.comboScale or 1.0)
	end

	if self.comboTextFrame then
		local x = (self.db.comboTextPositionX or 0) + (self.screenWidth / 2)
		local y = (self.db.comboTextPositionY or -50) + (self.screenHeight / 2)
		self.comboTextFrame:ClearAllPoints()
		self.comboTextFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	end
end

function ResourceBar:StartBarUpdates(barKey, config)
	local frameName = barKey .. "Frame"
	local frame = self[frameName]
	if not frame then return end

	frame:SetScript("OnUpdate", function(f, elapsed)
		self.cachedTime = GetTime()
		local shouldUpdate, now = SoundAlerter.BarUtils:ShouldUpdate(self.lastBarUpdate[barKey], config.updateFreq)
		if shouldUpdate then
			self:UpdateResourceBar(barKey, config)
			self.lastBarUpdate[barKey] = now
		end
	end)
end

function ResourceBar:StopBarUpdates(barKey)
	local frameName = barKey .. "Frame"
	local frame = self[frameName]
	if not frame then return end

	frame:SetScript("OnUpdate", nil)
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
				self:StartBarUpdates(barKey, config)
			else
				frame:Hide()
				self:StopBarUpdates(barKey)
			end

			if SoundAlerter.db1.profile.debugmode then
				SoundAlerter:Print(string.format("[ResourceBar] %s bar %s", barKey, self.db[enabledKey] and "enabled" or "disabled"))
			end
		end
	end

	if self.comboFrame then
		if self.db.comboEnabled then
			self.comboFrame:Show()
			self.comboFrame:EnableMouse(not self.db.locked)
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
	self:UpdateVisibility()
end
