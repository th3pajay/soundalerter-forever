
local CastingBars = {}
local UnitCastingInfo, UnitChannelInfo = SA_COMPAT.UnitCastingInfo, SA_COMPAT.UnitChannelInfo

local BAR_WIDTH = 280
local BAR_HEIGHT = 24
local TEXT_UPDATE_THROTTLE = 0.016
local BOUNCE_DURATION = 0.3

local CAST_BAR_UNITS = {
	player = { frameName = "SoundAlerterCastingBar_Player", titleText = "Player Cast", defaultY = -200 },
	target = { frameName = "SoundAlerterCastingBar_Target", titleText = "Target Cast", defaultY = -230 },
	focus = { frameName = "SoundAlerterCastingBar_Focus", titleText = "Focus Cast", defaultY = -260 },
}

function CastingBars:Initialize()
	if self.initialized then return end

	local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
	if not SoundAlerter then
		error("CastingBars:Initialize() called before addon is ready")
		return
	end

	self.addon = SoundAlerter
	self.db = self.addon.db1.profile.castingBars
	self.initialized = false

	self.lastUpdate = {
		player = 0,
		target = 0,
		focus = 0,
	}

	self.bounceState = {
		player = { active = false, startTime = 0 },
		target = { active = false, startTime = 0 },
		focus = { active = false, startTime = 0 },
	}

	self.castingState = {
		player = { casting = false, channeling = false, startTime = 0, endTime = 0, spellName = "" },
		target = { casting = false, channeling = false, startTime = 0, endTime = 0, spellName = "" },
		focus = { casting = false, channeling = false, startTime = 0, endTime = 0, spellName = "" },
	}

	self.textureApplied = false

	self.screenWidth, self.screenHeight = UIParent:GetSize()

	for unit, config in pairs(CAST_BAR_UNITS) do
		self:CreateCastBar(unit, config)
	end

	self:RegisterEvents()

	self:LoadSettings()

	self.initialized = true
end

function CastingBars:SaveBarPosition(unit)
	self.addon.BarUtils:SavePosition(self[unit .. "Frame"], self.addon.db1.profile.castingBars[unit], "")
end

function CastingBars:CreateCastBar(unit, config)
	local frame = self.addon.BarUtils:CreateContainerFrame(config.frameName, BAR_WIDTH + 20, BAR_HEIGHT + 30, config.defaultY, self.db, function()
		self:SaveBarPosition(unit)
	end)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("BOTTOM", frame, "TOP", 0, 2)
	title:SetText(config.titleText)
	title:SetTextColor(0.8, 0.8, 0.8, 1)

	local bar = self.addon.BarUtils:CreateStatusBarWidget(frame, BAR_WIDTH, BAR_HEIGHT, 0, 1)
	bar:SetValue(0)

	self.addon.BarUtils:CreateBackdrop(bar, 0.5, 0.5, 0.5, 1,
		"Interface\\DialogFrame\\UI-DialogBox-Background", 0, 0, 0, 0.8)

	local spellText = self.addon.BarUtils:CreateFontString(bar)
	spellText:SetPoint("CENTER", bar, "CENTER", 0, 0)
	spellText:SetText("")

	local timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	timeText:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
	timeText:SetText("")

	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetSize(BAR_HEIGHT, BAR_HEIGHT)
	icon:SetPoint("RIGHT", bar, "LEFT", -4, 0)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:Hide()

	local latency = bar:CreateTexture(nil, "BORDER")
	latency:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	latency:SetVertexColor(1, 0, 0, 0.6)
	latency:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
	latency:SetHeight(BAR_HEIGHT)
	latency:SetWidth(1)
	latency:Hide()

	self[unit .. "Frame"] = frame
	self[unit .. "Title"] = title
	self[unit .. "Bar"] = bar
	self[unit .. "SpellText"] = spellText
	self[unit .. "TimeText"] = timeText
	self[unit .. "Icon"] = icon
	self[unit .. "Latency"] = latency

	self:ApplyOrientation(unit)

	frame:Hide()
end

function CastingBars:ApplyOrientation(unit)
	local frame, bar, icon, spellText, timeText, latency
	local unitDB = self.db and self.db[unit]

	if unit == "player" then
		frame, bar, icon, spellText, timeText, latency = self.playerFrame, self.playerBar, self.playerIcon, self.playerSpellText, self.playerTimeText, self.playerLatency
	elseif unit == "target" then
		frame, bar, icon, spellText, timeText, latency = self.targetFrame, self.targetBar, self.targetIcon, self.targetSpellText, self.targetTimeText, self.targetLatency
	elseif unit == "focus" then
		frame, bar, icon, spellText, timeText, latency = self.focusFrame, self.focusBar, self.focusIcon, self.focusSpellText, self.focusTimeText, self.focusLatency
	else
		return
	end

	if not bar or not unitDB then return end

	local orientation = unitDB.orientation or "horizontal"
	local fillDirection = unitDB.fillDirection or "right"

	if orientation == "vertical" then
		if fillDirection ~= "up" and fillDirection ~= "down" then
			fillDirection = "up"
		end
	else
		if fillDirection ~= "left" and fillDirection ~= "right" then
			fillDirection = "right"
		end
	end

	local length = unitDB.width or BAR_WIDTH
	local thickness = unitDB.height or BAR_HEIGHT
	local barWidth = orientation == "vertical" and thickness or length
	local barHeight = orientation == "vertical" and length or thickness

	bar:SetSize(barWidth, barHeight)
	frame:SetSize(barWidth + 20, barHeight + 30)

	bar:SetOrientation(orientation == "vertical" and "VERTICAL" or "HORIZONTAL")
	bar:SetReverseFill(fillDirection == "left" or fillDirection == "down")

	icon:ClearAllPoints()
	spellText:ClearAllPoints()
	timeText:ClearAllPoints()
	latency:ClearAllPoints()

	spellText:SetPoint("CENTER", bar, "CENTER", 0, 0)

	if orientation == "vertical" then
		local iconSize = bar:GetWidth()
		icon:SetSize(iconSize, iconSize)

		if fillDirection == "down" then
			icon:SetPoint("BOTTOM", bar, "TOP", 0, 4)
			timeText:SetPoint("BOTTOM", bar, "BOTTOM", 0, 5)
			latency:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
		else
			icon:SetPoint("TOP", bar, "BOTTOM", 0, -4)
			timeText:SetPoint("TOP", bar, "TOP", 0, -5)
			latency:SetPoint("TOP", bar, "TOP", 0, 0)
		end

		latency:SetWidth(bar:GetWidth())
	else
		local iconSize = bar:GetHeight()
		icon:SetSize(iconSize, iconSize)

		if fillDirection == "left" then
			icon:SetPoint("LEFT", bar, "RIGHT", 4, 0)
			timeText:SetPoint("LEFT", bar, "LEFT", 5, 0)
			latency:SetPoint("LEFT", bar, "LEFT", 0, 0)
		else
			icon:SetPoint("RIGHT", bar, "LEFT", -4, 0)
			timeText:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
			latency:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
		end

		latency:SetHeight(bar:GetHeight())
	end
end

function CastingBars:RegisterEvents()
	self.eventFrame = CreateFrame("Frame")

	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
	self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	self.eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")

	self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
		self:OnEvent(event, ...)
	end)

	self.eventFrame:SetScript("OnUpdate", function(frame, elapsed)
		self:OnUpdate(elapsed)
	end)
end

function CastingBars:OnEvent(event, unit, ...)
	if event == "PLAYER_TARGET_CHANGED" then
		self:OnTargetChanged()
		return
	elseif event == "PLAYER_FOCUS_CHANGED" then
		self:OnFocusChanged()
		return
	end

	if unit ~= "player" and unit ~= "target" and unit ~= "focus" then
		return
	end

	C_Timer.After(0, function()
		if event == "UNIT_SPELLCAST_START" then
			self:OnCastStart(unit)
		elseif event == "UNIT_SPELLCAST_STOP" then
			self:OnCastStop(unit)
		elseif event == "UNIT_SPELLCAST_FAILED" then
			self:OnCastStop(unit)
		elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
			self:OnCastStop(unit)
		elseif event == "UNIT_SPELLCAST_DELAYED" then
			self:OnCastDelay(unit)
		elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
			self:OnChannelStart(unit)
		elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
			self:OnCastStop(unit)
		elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
			self:OnChannelUpdate(unit)
		end
	end)
end

function CastingBars:OnCastStart(unit)
	local spellName, _, _, texture, startTime, endTime = UnitCastingInfo(unit)

	if not spellName then return end
	if issecretvalue(startTime) or issecretvalue(endTime) then return end

	local state, frame, bar, spellText, timeText
	if unit == "player" and self.playerFrame then
		if not self.db.player.enabled then return end
		state = self.castingState.player
		frame = self.playerFrame
		bar = self.playerBar
		spellText = self.playerSpellText
		timeText = self.playerTimeText
	elseif unit == "target" and self.targetFrame then
		if not self.db.target.enabled then return end
		state = self.castingState.target
		frame = self.targetFrame
		bar = self.targetBar
		spellText = self.targetSpellText
		timeText = self.targetTimeText
	elseif unit == "focus" and self.focusFrame then
		if not self.db.focus.enabled then return end
		state = self.castingState.focus
		frame = self.focusFrame
		bar = self.focusBar
		spellText = self.focusSpellText
		timeText = self.focusTimeText
	else
		return
	end

	local startTimeSec = (startTime or 0) / 1000
	local endTimeSec = (endTime or 0) / 1000

	local now = GetTime()
	if startTimeSec <= 0 then startTimeSec = now end
	if endTimeSec <= startTimeSec then endTimeSec = now + 1 end

	state.casting = true
	state.channeling = false
	state.startTime = startTimeSec
	state.endTime = endTimeSec
	state.spellName = spellName

	bar:SetValue(0)
	bar:SetStatusBarColor(0.2, 0.5, 1.0, 1)

	spellText:SetText(spellName)

	local remaining = endTimeSec - now
	timeText:SetText(self:FormatTime(remaining))

	self:StartBounce(unit)

	local icon
	if unit == "player" then
		icon = self.playerIcon
	elseif unit == "target" then
		icon = self.targetIcon
	elseif unit == "focus" then
		icon = self.focusIcon
	end

	if icon and self.db.showSpellIcon and texture then
		icon:SetTexture(texture)
		icon:Show()
	elseif icon then
		icon:Hide()
	end

	if unit == "player" and self.playerLatency and self.db.showLatency then
		local _, _, _, lagWorld = GetNetStats()
		local latencyMS = lagWorld or 50
		local latencySeconds = latencyMS / 1000
		local castDuration = endTimeSec - startTimeSec

		if castDuration > 0 and latencyMS > 0 then
			local latencyPercent = latencySeconds / castDuration
			local isVertical = self.db.player.orientation == "vertical"
			local barExtent = isVertical and self.playerBar:GetHeight() or self.playerBar:GetWidth()
			local latencyExtent = barExtent * latencyPercent

			latencyExtent = math.max(10, math.min(latencyExtent, barExtent * 0.5))

			if isVertical then
				self.playerLatency:SetHeight(latencyExtent)
			else
				self.playerLatency:SetWidth(latencyExtent)
			end
			self.playerLatency:Show()
		else
			self.playerLatency:Hide()
		end
	elseif unit == "player" and self.playerLatency then
		self.playerLatency:Hide()
	end

	if self.addon.db1.profile.debugmode then
		self.addon:Print(string.format("[CastingBars] %s casting: %s", unit, spellName))
	end

	frame:Show()
end

function CastingBars:OnChannelStart(unit)
	local spellName, _, _, texture, startTime, endTime = UnitChannelInfo(unit)

	if not spellName then return end
	if issecretvalue(startTime) or issecretvalue(endTime) then return end

	local state, frame, bar, spellText, timeText
	if unit == "player" and self.playerFrame then
		if not self.db.player.enabled then return end
		state = self.castingState.player
		frame = self.playerFrame
		bar = self.playerBar
		spellText = self.playerSpellText
		timeText = self.playerTimeText
	elseif unit == "target" and self.targetFrame then
		if not self.db.target.enabled then return end
		state = self.castingState.target
		frame = self.targetFrame
		bar = self.targetBar
		spellText = self.targetSpellText
		timeText = self.targetTimeText
	elseif unit == "focus" and self.focusFrame then
		if not self.db.focus.enabled then return end
		state = self.castingState.focus
		frame = self.focusFrame
		bar = self.focusBar
		spellText = self.focusSpellText
		timeText = self.focusTimeText
	else
		return
	end

	local startTimeSec = (startTime or 0) / 1000
	local endTimeSec = (endTime or 0) / 1000

	local now = GetTime()
	if startTimeSec <= 0 then startTimeSec = now end
	if endTimeSec <= startTimeSec then endTimeSec = now + 1 end

	state.casting = false
	state.channeling = true
	state.startTime = startTimeSec
	state.endTime = endTimeSec
	state.spellName = spellName

	bar:SetValue(1)
	bar:SetStatusBarColor(0.7, 0.3, 1.0, 1)

	spellText:SetText(spellName)

	local remaining = endTimeSec - now
	timeText:SetText(self:FormatTime(remaining))

	self:StartBounce(unit)

	local icon
	if unit == "player" then
		icon = self.playerIcon
	elseif unit == "target" then
		icon = self.targetIcon
	elseif unit == "focus" then
		icon = self.focusIcon
	end

	if icon and self.db.showSpellIcon and texture then
		icon:SetTexture(texture)
		icon:Show()
	elseif icon then
		icon:Hide()
	end

	if unit == "player" and self.playerLatency and self.db.showLatency then
		local _, _, _, lagWorld = GetNetStats()
		local latencyMS = lagWorld or 50
		local latencySeconds = latencyMS / 1000
		local castDuration = endTimeSec - startTimeSec

		if castDuration > 0 and latencyMS > 0 then

			local latencyPercent = latencySeconds / castDuration
			local isVertical = self.db.player.orientation == "vertical"
			local barExtent = isVertical and self.playerBar:GetHeight() or self.playerBar:GetWidth()
			local latencyExtent = barExtent * latencyPercent

			latencyExtent = math.max(10, math.min(latencyExtent, barExtent * 0.5))

			if isVertical then
				self.playerLatency:SetHeight(latencyExtent)
			else
				self.playerLatency:SetWidth(latencyExtent)
			end
			self.playerLatency:Show()
		else
			self.playerLatency:Hide()
		end
	elseif unit == "player" and self.playerLatency then
		self.playerLatency:Hide()
	end

	if self.addon.db1.profile.debugmode then
		self.addon:Print(string.format("[CastingBars] %s channeling: %s", unit, spellName))
	end

	frame:Show()
end

function CastingBars:OnCastStop(unit)
	local state, frame, bar, spellText, timeText
	if unit == "player" and self.playerFrame then
		state = self.castingState.player
		frame = self.playerFrame
		bar = self.playerBar
		spellText = self.playerSpellText
		timeText = self.playerTimeText
	elseif unit == "target" and self.targetFrame then
		state = self.castingState.target
		frame = self.targetFrame
		bar = self.targetBar
		spellText = self.targetSpellText
		timeText = self.targetTimeText
	elseif unit == "focus" and self.focusFrame then
		state = self.castingState.focus
		frame = self.focusFrame
		bar = self.focusBar
		spellText = self.focusSpellText
		timeText = self.focusTimeText
	else
		return
	end

	if (state.casting or state.channeling) and self.addon.db1.profile.debugmode then
		self.addon:Print(string.format("[CastingBars] %s stopped: %s", unit, state.spellName))
	end

	state.casting = false
	state.channeling = false
	state.startTime = 0
	state.endTime = 0
	state.spellName = ""

	bar:SetValue(0)

	if self.db.locked then
		frame:Hide()
		spellText:SetText("")
		timeText:SetText("")
	else
		spellText:SetText("Ready")
		timeText:SetText("")

	end
end

function CastingBars:OnCastDelay(unit)
	local spellName, _, _, _, startTime, endTime = UnitCastingInfo(unit)
	if not spellName then return end
	if issecretvalue(startTime) or issecretvalue(endTime) then return end

	local state
	if unit == "player" and self.playerFrame then
		state = self.castingState.player
	elseif unit == "target" and self.targetFrame then
		state = self.castingState.target
	elseif unit == "focus" and self.focusFrame then
		state = self.castingState.focus
	else
		return
	end

	if state.casting then
		state.startTime = (startTime or 0) / 1000
		state.endTime = (endTime or 0) / 1000
	end
end

function CastingBars:OnChannelUpdate(unit)
	local spellName, _, _, _, startTime, endTime = UnitChannelInfo(unit)
	if not spellName then return end
	if issecretvalue(startTime) or issecretvalue(endTime) then return end

	local state
	if unit == "player" and self.playerFrame then
		state = self.castingState.player
	elseif unit == "target" and self.targetFrame then
		state = self.castingState.target
	elseif unit == "focus" and self.focusFrame then
		state = self.castingState.focus
	else
		return
	end

	if state.channeling then
		state.startTime = (startTime or 0) / 1000
		state.endTime = (endTime or 0) / 1000
	end
end

function CastingBars:OnTargetChanged()
	if not self.db.target.enabled then return end

	if not UnitExists("target") then
		if self.targetFrame then
			self:OnCastStop("target")
		end
		return
	end

	local spellName = UnitCastingInfo("target")

	if spellName then
		self:OnCastStart("target")
		return
	end

	local chanSpellName = UnitChannelInfo("target")

	if chanSpellName then
		self:OnChannelStart("target")
		return
	end

	self:OnCastStop("target")
end

function CastingBars:OnFocusChanged()
	if not self.db.focus.enabled then return end

	if not UnitExists("focus") then
		if self.focusFrame then
			self:OnCastStop("focus")
		end
		return
	end

	local spellName = UnitCastingInfo("focus")

	if spellName then
		self:OnCastStart("focus")
		return
	end

	local chanSpellName = UnitChannelInfo("focus")

	if chanSpellName then
		self:OnChannelStart("focus")
		return
	end

	self:OnCastStop("focus")
end

function CastingBars:OnUpdate(elapsed)
	local now = GetTime()

	if self.playerFrame and self.db.player.enabled then
		local state = self.castingState.player
		if state.casting or state.channeling then
			self:UpdateBar("player", now)
			self:UpdateBounce("player", now)
		end
	end

	if self.targetFrame and self.db.target.enabled then
		local state = self.castingState.target
		if state.casting or state.channeling then
			self:UpdateBar("target", now)
			self:UpdateBounce("target", now)
		end
	end

	if self.focusFrame and self.db.focus.enabled then
		local state = self.castingState.focus
		if state.casting or state.channeling then
			self:UpdateBar("focus", now)
			self:UpdateBounce("focus", now)
		end
	end
end

function CastingBars:UpdateBar(unit, now)
	local state, bar, spellText, timeText

	if unit == "player" then
		state = self.castingState.player
		bar = self.playerBar
		spellText = self.playerSpellText
		timeText = self.playerTimeText
	elseif unit == "target" then
		state = self.castingState.target
		bar = self.targetBar
		spellText = self.targetSpellText
		timeText = self.targetTimeText
	elseif unit == "focus" then
		state = self.castingState.focus
		bar = self.focusBar
		spellText = self.focusSpellText
		timeText = self.focusTimeText
	else
		return
	end

	local duration = state.endTime - state.startTime
	if duration <= 0 then duration = 1 end

	local remaining = state.endTime - now
	local progress

	if state.channeling then
		progress = remaining / duration
		bar:SetValue(math.max(0, math.min(1, progress)))
	else
		local elapsed = now - state.startTime
		progress = elapsed / duration
		bar:SetValue(math.max(0, math.min(1, progress)))
	end

	if remaining <= 0 then
		self:OnCastStop(unit)
		return
	end

	local currentText = spellText:GetText()
	if currentText ~= state.spellName and state.spellName ~= "" then
		spellText:SetText(state.spellName)
	end

	local lastUpdate = self.lastUpdate[unit] or 0
	if (now - lastUpdate) >= TEXT_UPDATE_THROTTLE then
		timeText:SetText(self:FormatTime(remaining))
		self.lastUpdate[unit] = now
	end
end

function CastingBars:StartBounce(unit)
	if unit == "player" then
		self.bounceState.player.active = true
		self.bounceState.player.startTime = GetTime()
	elseif unit == "target" then
		self.bounceState.target.active = true
		self.bounceState.target.startTime = GetTime()
	elseif unit == "focus" then
		self.bounceState.focus.active = true
		self.bounceState.focus.startTime = GetTime()
	end
end

function CastingBars:UpdateBounce(unit, now)
	local bounceState, bar

	if unit == "player" then
		bounceState = self.bounceState.player
		bar = self.playerBar
	elseif unit == "target" then
		bounceState = self.bounceState.target
		bar = self.targetBar
	elseif unit == "focus" then
		bounceState = self.bounceState.focus
		bar = self.focusBar
	else
		return
	end

	if not bounceState.active or not bar then return end

	local elapsed = now - bounceState.startTime

	if elapsed >= BOUNCE_DURATION then
		bounceState.active = false
		bar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	else
		local progress = elapsed / BOUNCE_DURATION

		local intensity = math.sin(progress * math.pi)

		bar:SetBackdropBorderColor(
			0.5 + (0.5 * intensity),
			0.5 + (0.5 * intensity),
			1.0,
			1
		)
	end
end

function CastingBars:FormatTime(seconds)
	if not seconds or type(seconds) ~= "number" or seconds ~= seconds then
		local format = self.addon and self.addon.db1 and self.addon.db1.profile.castingBars.timeFormat
		return format == "centiseconds" and "00.00" or "00.000"
	end

	if seconds < 0 then seconds = 0 end

	local wholeSecs = math.floor(seconds)
	local format = self.addon and self.addon.db1 and self.addon.db1.profile.castingBars.timeFormat

	if format == "centiseconds" then
		local centisecs = math.floor((seconds - wholeSecs) * 100)
		return string.format("%02d.%02d", wholeSecs, centisecs)
	else
		local millisecs = math.floor((seconds - wholeSecs) * 1000)
		return string.format("%02d.%03d", wholeSecs, millisecs)
	end
end

function CastingBars:LoadSettings()
	if not self.db then return end

	if self.playerFrame then
		local playerDB = self.db.player
		self.addon.BarUtils:LoadPosition(self.playerFrame, playerDB, "", 0, -200)

		self:ApplyOrientation("player")

		if playerDB.enabled then
			self.playerFrame:EnableMouse(not self.db.locked)

			if self.db.locked then
				self.playerTitle:Hide()
			else
				self.playerTitle:Show()
			end

			if not self.db.locked then
				self.playerFrame:Show()
				self.playerSpellText:SetText("Ready")
				self.playerTimeText:SetText("")
				self.playerBar:SetValue(0)
			else
				if self.castingState.player.casting or self.castingState.player.channeling then
					self.playerFrame:Show()
				else
					self.playerFrame:Hide()
				end
			end
		else
			self.playerFrame:Hide()
			self.playerTitle:Hide()
		end
	end

	if self.targetFrame then
		local targetDB = self.db.target
		self.addon.BarUtils:LoadPosition(self.targetFrame, targetDB, "", 0, -230)

		self:ApplyOrientation("target")

		if targetDB.enabled then
			self.targetFrame:EnableMouse(not self.db.locked)

			if self.db.locked then
				self.targetTitle:Hide()
			else
				self.targetTitle:Show()
			end

			if not self.db.locked then
				self.targetFrame:Show()
				self.targetSpellText:SetText("Ready")
				self.targetTimeText:SetText("")
				self.targetBar:SetValue(0)
			else
				if self.castingState.target.casting or self.castingState.target.channeling then
					self.targetFrame:Show()
				else
					self.targetFrame:Hide()
				end
			end
		else
			self.targetFrame:Hide()
			self.targetTitle:Hide()
		end
	end

	if self.focusFrame then
		local focusDB = self.db.focus
		self.addon.BarUtils:LoadPosition(self.focusFrame, focusDB, "", 0, -260)

		self:ApplyOrientation("focus")

		if focusDB.enabled then
			self.focusFrame:EnableMouse(not self.db.locked)

			if self.db.locked then
				self.focusTitle:Hide()
			else
				self.focusTitle:Show()
			end

			if not self.db.locked then
				self.focusFrame:Show()
				self.focusSpellText:SetText("Ready")
				self.focusTimeText:SetText("")
				self.focusBar:SetValue(0)
			else
				if self.castingState.focus.casting or self.castingState.focus.channeling then
					self.focusFrame:Show()
				else
					self.focusFrame:Hide()
				end
			end
		else
			self.focusFrame:Hide()
			self.focusTitle:Hide()
		end
	end

	if not self.textureApplied then
		self:ApplyBarTexture()
		self.textureApplied = true
	end
end

function CastingBars:ApplyBarTexture()
	if not self.db then return end

	local texture = self.db.barTexture or "default"

	if self.playerBar then
		self.addon.BarUtils:ApplyBarTexture(self.playerBar, texture)
	end

	if self.targetBar then
		self.addon.BarUtils:ApplyBarTexture(self.targetBar, texture)
	end

	if self.focusBar then
		self.addon.BarUtils:ApplyBarTexture(self.focusBar, texture)
	end
end

function CastingBars:UpdateTexture()
	self.textureApplied = false
	self:ApplyBarTexture()
	self.textureApplied = true
end

function CastingBars:SetLocked(locked)
	if not self.db then return end

	self.db.locked = locked

	self:LoadSettings()
end

function CastingBars:OnProfileChanged()
	local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
	if not SoundAlerter then return end

	self.addon = SoundAlerter
	self.db = self.addon.db1.profile.castingBars

	self.textureApplied = false

	if self.initialized then
		self:LoadSettings()
	end
end

SoundAlerter.CastingBars = CastingBars
