
local CastingBars = {}
local UnitCastingInfo, UnitChannelInfo = SA_COMPAT.UnitCastingInfo, SA_COMPAT.UnitChannelInfo
local GetTime = GetTime
local ipairs = ipairs
local math_floor, math_max, math_min, math_sin, math_pi = math.floor, math.max, math.min, math.sin, math.pi
local string_format = string.format

local BAR_WIDTH = 280
local BAR_HEIGHT = 24
local BOUNCE_DURATION = 0.3
local ICON_GAP = 4
local TEXT_INSET = 5
local FRAME_PAD_X = 20
local FRAME_PAD_Y = 30

local FINISH_HOLD = 0.4
local FINISH_NEAR_END = 0.2

local FINISH_STYLES = {
	success = { duration = 0.25, r = 0.2, g = 0.9, b = 0.2 },
	interrupt = { duration = 0.5, r = 1, g = 0.2, b = 0.2 },
}

local UNIT_ORDER = { "player", "target", "focus" }

local CAST_BAR_UNITS = {
	player = { frameName = "SoundAlerterCastingBar_Player", titleText = "Player Cast", defaultY = -200 },
	target = { frameName = "SoundAlerterCastingBar_Target", titleText = "Target Cast", defaultY = -230 },
	focus = { frameName = "SoundAlerterCastingBar_Focus", titleText = "Focus Cast", defaultY = -260 },
}

local CASTING_BAR_GROUP_KEYS = {
	locked = true,
	barTexture = true,
	timeFormat = true,
	showSpellIcon = true,
	showLatency = true,
}

local CASTING_BAR_UNIT_KEYS = {
	enabled = true,
	width = true,
	height = true,
	orientation = true,
	fillDirection = true,
	PositionX = true,
	PositionY = true,
}

function CastingBars:GetSettings()
	return self.db
end

function CastingBars:SetSetting(key, value)
	local unit, field = key:match("^(%a+)%.(%a+)$")
	if unit then
		if not CAST_BAR_UNITS[unit] or not CASTING_BAR_UNIT_KEYS[field] then
			error("CastingBars:SetSetting - unknown setting key '"..tostring(key).."'", 2)
		end
		self.db[unit][field] = value
	else
		if not CASTING_BAR_GROUP_KEYS[key] then
			error("CastingBars:SetSetting - unknown setting key '"..tostring(key).."'", 2)
		end
		self.db[key] = value
	end
end

function CastingBars:ApplyPyramidLayout()
	self.db.player.PositionX = 0
	self.db.player.PositionY = -200
	self.db.target.PositionX = -160
	self.db.target.PositionY = -260
	self.db.focus.PositionX = 160
	self.db.focus.PositionY = -260
end

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
	self.updating = false
	self.textureApplied = false

	self.bars = {}
	self.barList = {}

	for _, unit in ipairs(UNIT_ORDER) do
		self:CreateCastBar(unit, CAST_BAR_UNITS[unit])
	end

	self:RegisterEvents()

	self:LoadSettings()

	self.initialized = true
end

function CastingBars:SaveBarPosition(unit)
	self.addon.BarUtils:SavePosition(self.bars[unit].frame, self.addon.db1.profile.castingBars[unit], "")
end

function CastingBars:CreateCastBar(unit, config)
	local BarUtils = self.addon.BarUtils

	local frame = BarUtils:CreateContainerFrame(config.frameName, BAR_WIDTH + FRAME_PAD_X, BAR_HEIGHT + FRAME_PAD_Y, config.defaultY, self.db, function()
		self:SaveBarPosition(unit)
	end)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("BOTTOM", frame, "TOP", 0, 2)
	title:SetText(config.titleText)
	title:SetTextColor(0.8, 0.8, 0.8, 1)

	local bar = BarUtils:CreateStatusBarWidget(frame, BAR_WIDTH, BAR_HEIGHT, 0, 1)
	bar:SetValue(0)

	BarUtils:CreateBackdrop(bar, 0.5, 0.5, 0.5, 1,
		"Interface\\DialogFrame\\UI-DialogBox-Background", 0, 0, 0, 0.8)

	local spellText = BarUtils:CreateFontString(bar)
	spellText:SetPoint("CENTER", bar, "CENTER", 0, 0)
	spellText:SetText("")

	local timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	timeText:SetPoint("RIGHT", bar, "RIGHT", -TEXT_INSET, 0)
	timeText:SetText("")

	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetSize(BAR_HEIGHT, BAR_HEIGHT)
	icon:SetPoint("RIGHT", bar, "LEFT", -ICON_GAP, 0)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:Hide()

	local latency = bar:CreateTexture(nil, "BORDER")
	latency:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	latency:SetVertexColor(1, 0, 0, 0.6)
	latency:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
	latency:SetHeight(BAR_HEIGHT)
	latency:SetWidth(1)
	latency:Hide()

	local b = {
		unit = unit,
		defaultY = config.defaultY,
		frame = frame,
		title = title,
		bar = bar,
		spellText = spellText,
		timeText = timeText,
		icon = icon,
		latency = latency,
		casting = false,
		channeling = false,
		startTime = 0,
		endTime = 0,
		duration = 1,
		spellName = "",
		extent = BAR_WIDTH,
		lastFill = nil,
		lastTick = nil,
		bounceActive = false,
		bounceStart = 0,
	}

	self.bars[unit] = b
	self.barList[#self.barList + 1] = b

	self:ApplyOrientation(b)

	frame:Hide()
end

function CastingBars:ApplyOrientation(b)
	local unitDB = self.db and self.db[b.unit]
	if not unitDB then return end

	local BarUtils = self.addon.BarUtils
	local frame, bar, icon, spellText, timeText, latency = b.frame, b.bar, b.icon, b.spellText, b.timeText, b.latency

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

	local vertical = orientation == "vertical"
	local length = BarUtils:Snap(unitDB.width or BAR_WIDTH, bar)
	local thickness = BarUtils:Snap(unitDB.height or BAR_HEIGHT, bar)
	local barWidth = vertical and thickness or length
	local barHeight = vertical and length or thickness

	bar:SetSize(barWidth, barHeight)
	frame:SetSize(BarUtils:Snap(barWidth + FRAME_PAD_X, frame), BarUtils:Snap(barHeight + FRAME_PAD_Y, frame))

	bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
	bar:SetReverseFill(fillDirection == "left" or fillDirection == "down")

	b.vertical = vertical
	b.extent = math_max(1, math_floor((vertical and barHeight or barWidth) * BarUtils:PixelsPerUnit(bar) + 0.5))
	b.lastFill = nil

	local gap = BarUtils:Snap(ICON_GAP, bar)
	local inset = BarUtils:Snap(TEXT_INSET, bar)

	icon:ClearAllPoints()
	spellText:ClearAllPoints()
	timeText:ClearAllPoints()
	latency:ClearAllPoints()

	spellText:SetPoint("CENTER", bar, "CENTER", 0, 0)

	if vertical then
		icon:SetSize(barWidth, barWidth)

		if fillDirection == "down" then
			icon:SetPoint("BOTTOM", bar, "TOP", 0, gap)
			timeText:SetPoint("BOTTOM", bar, "BOTTOM", 0, inset)
			latency:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
		else
			icon:SetPoint("TOP", bar, "BOTTOM", 0, -gap)
			timeText:SetPoint("TOP", bar, "TOP", 0, -inset)
			latency:SetPoint("TOP", bar, "TOP", 0, 0)
		end

		latency:SetWidth(barWidth)
	else
		icon:SetSize(barHeight, barHeight)

		if fillDirection == "left" then
			icon:SetPoint("LEFT", bar, "RIGHT", gap, 0)
			timeText:SetPoint("LEFT", bar, "LEFT", inset, 0)
			latency:SetPoint("LEFT", bar, "LEFT", 0, 0)
		else
			icon:SetPoint("RIGHT", bar, "LEFT", -gap, 0)
			timeText:SetPoint("RIGHT", bar, "RIGHT", -inset, 0)
			latency:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
		end

		latency:SetHeight(barHeight)
	end
end

function CastingBars:Attach()
	if self.updating then return end

	self.updating = true
	self.eventFrame:SetScript("OnUpdate", function()
		self:OnUpdate()
	end)
end

function CastingBars:Detach()
	if not self.updating then return end

	self.updating = false
	self.eventFrame:SetScript("OnUpdate", nil)
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
	self.eventFrame:RegisterEvent("UI_SCALE_CHANGED")
	self.eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")

	self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
		self:OnEvent(event, ...)
	end)
end

local EVENT_HANDLERS = {
	UNIT_SPELLCAST_START = function(self, unit)
		self:BeginCast(unit, false)
	end,
	UNIT_SPELLCAST_STOP = function(self, unit)
		if self.bars[unit].channeling then return end
		self:OnStopEvent(unit, false)
	end,
	UNIT_SPELLCAST_FAILED = function(self, unit)
		local b = self.bars[unit]
		if b.casting and not b.channeling then
			self:OnCastStop(unit)
		end
	end,
	UNIT_SPELLCAST_INTERRUPTED = function(self, unit)
		self:OnStopEvent(unit, true)
	end,
	UNIT_SPELLCAST_DELAYED = function(self, unit)
		self:Retime(unit, false)
	end,
	UNIT_SPELLCAST_CHANNEL_START = function(self, unit)
		self:BeginCast(unit, true)
	end,
	UNIT_SPELLCAST_CHANNEL_STOP = function(self, unit)
		self:OnStopEvent(unit, false)
	end,
	UNIT_SPELLCAST_CHANNEL_UPDATE = function(self, unit)
		self:Retime(unit, true)
	end,
}

function CastingBars:OnEvent(event, unit)
	if event == "PLAYER_TARGET_CHANGED" then
		self:RefreshUnit("target")
		return
	elseif event == "PLAYER_FOCUS_CHANGED" then
		self:RefreshUnit("focus")
		return
	elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
		self:LoadSettings()
		return
	end

	if not self.bars[unit] then return end

	local handler = EVENT_HANDLERS[event]
	C_Timer.After(0, function()
		handler(self, unit)
	end)
end

function CastingBars:SetTimes(b, startTime, endTime)
	local startSec = (startTime or 0) / 1000
	local endSec = (endTime or 0) / 1000

	local now = GetTime()
	if startSec <= 0 then startSec = now end
	if endSec <= startSec then endSec = now + 1 end

	b.startTime = startSec
	b.endTime = endSec
	b.duration = endSec - startSec

	return now
end

function CastingBars:UpdateLatency(b)
	local latency = b.latency

	if not self.db.showLatency then
		latency:Hide()
		return
	end

	local _, _, _, lagWorld = GetNetStats()
	local latencyMS = lagWorld or 50

	if b.duration <= 0 or latencyMS <= 0 then
		latency:Hide()
		return
	end

	local bar = b.bar
	local barExtent = b.vertical and bar:GetHeight() or bar:GetWidth()
	local latencyExtent = barExtent * (latencyMS / 1000 / b.duration)
	latencyExtent = self.addon.BarUtils:Snap(math_max(10, math_min(latencyExtent, barExtent * 0.5)), bar)

	if b.vertical then
		latency:SetHeight(latencyExtent)
	else
		latency:SetWidth(latencyExtent)
	end
	latency:Show()
end

function CastingBars:BeginCast(unit, channeling)
	local b = self.bars[unit]
	if not b or not self.db[unit].enabled then return end

	local spellName, _, _, texture, startTime, endTime
	if channeling then
		spellName, _, _, texture, startTime, endTime = UnitChannelInfo(unit)
	else
		spellName, _, _, texture, startTime, endTime = UnitCastingInfo(unit)
	end

	if not spellName then return end
	if issecretvalue(startTime) or issecretvalue(endTime) then return end

	local now = self:SetTimes(b, startTime, endTime)

	b.casting = not channeling
	b.channeling = channeling
	b.spellName = spellName
	b.finishing = nil
	b.frame:SetAlpha(1)

	local bar = b.bar
	local initial = channeling and 1 or 0
	b.lastFill = initial
	b.lastTick = nil
	bar:SetValue(initial)
	if channeling then
		bar:SetStatusBarColor(0.7, 0.3, 1.0, 1)
	else
		bar:SetStatusBarColor(0.2, 0.5, 1.0, 1)
	end

	b.spellText:SetText(spellName)
	b.timeText:SetText(self:FormatTime(b.endTime - now))

	self:StartBounce(b)

	if self.db.showSpellIcon and texture then
		b.icon:SetTexture(texture)
		b.icon:Show()
	else
		b.icon:Hide()
	end

	if unit == "player" then
		self:UpdateLatency(b)
	end

	if self.addon.db1.profile.debugmode then
		self.addon:Print(string_format("[CastingBars] %s %s: %s", unit, channeling and "channeling" or "casting", spellName))
	end

	b.frame:Show()
	self:Attach()
end

function CastingBars:ResetState(b)
	b.casting = false
	b.channeling = false
	b.startTime = 0
	b.endTime = 0
	b.duration = 1
	b.spellName = ""
	b.lastFill = 0
	b.lastTick = nil
	b.bounceActive = false
	b.finishing = nil
	b.frame:SetAlpha(1)
	b.bar:SetValue(0)
	b.bar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
end

function CastingBars:Finish(b, kind)
	local style = FINISH_STYLES[kind]

	b.casting = false
	b.channeling = false
	b.bounceActive = false
	b.finishing = style
	b.finishStart = GetTime()

	b.bar:SetStatusBarColor(style.r, style.g, style.b, 1)
	b.bar:SetBackdropBorderColor(style.r, style.g, style.b, 1)
	b.timeText:SetText("")

	if kind == "success" then
		b.bar:SetValue(1)
		b.lastFill = 1
	else
		b.spellText:SetText("Interrupted")
	end

	self:Attach()
end

function CastingBars:UpdateFinish(b, now)
	local style = b.finishing
	local t = (now - b.finishStart) / style.duration

	if t >= 1 then
		self:OnCastStop(b.unit)
		return
	end

	if t <= FINISH_HOLD then
		b.frame:SetAlpha(1)
	else
		b.frame:SetAlpha(1 - (t - FINISH_HOLD) / (1 - FINISH_HOLD))
	end
end

function CastingBars:OnStopEvent(unit, interrupted)
	local b = self.bars[unit]
	if not b or not (b.casting or b.channeling) then return end

	if interrupted then
		self:Finish(b, "interrupt")
	elseif GetTime() >= b.endTime - FINISH_NEAR_END then
		self:Finish(b, "success")
	else
		self:OnCastStop(unit)
	end
end

function CastingBars:OnCastStop(unit)
	local b = self.bars[unit]
	if not b then return end

	if (b.casting or b.channeling) and self.addon.db1.profile.debugmode then
		self.addon:Print(string_format("[CastingBars] %s stopped: %s", unit, b.spellName))
	end

	self:ResetState(b)

	if self.db.locked then
		b.frame:Hide()
		b.spellText:SetText("")
		b.timeText:SetText("")
	else
		b.spellText:SetText("Ready")
		b.timeText:SetText("")
	end
end

function CastingBars:Retime(unit, channeling)
	local b = self.bars[unit]
	if not b then return end

	local spellName, startTime, endTime
	if channeling then
		spellName, _, _, _, startTime, endTime = UnitChannelInfo(unit)
	else
		spellName, _, _, _, startTime, endTime = UnitCastingInfo(unit)
	end

	if not spellName then return end
	if issecretvalue(startTime) or issecretvalue(endTime) then return end

	if (channeling and b.channeling) or (not channeling and b.casting) then
		self:SetTimes(b, startTime, endTime)
	end
end

function CastingBars:RefreshUnit(unit)
	if not self.db[unit].enabled then return end

	if not UnitExists(unit) then
		self:OnCastStop(unit)
		return
	end

	if UnitCastingInfo(unit) then
		self:BeginCast(unit, false)
		return
	end

	if UnitChannelInfo(unit) then
		self:BeginCast(unit, true)
		return
	end

	self:OnCastStop(unit)
end

function CastingBars:OnUpdate()
	local now = GetTime()
	local busy = false

	local list = self.barList
	for i = 1, #list do
		local b = list[i]
		if b.finishing then
			self:UpdateFinish(b, now)
			busy = busy or b.finishing ~= nil
		elseif b.casting or b.channeling then
			self:UpdateBar(b, now)
			if b.casting or b.channeling or b.finishing then
				busy = true
				if b.bounceActive then
					self:UpdateBounce(b, now)
				end
			end
		end
	end

	if not busy then
		self:Detach()
	end
end

function CastingBars:UpdateBar(b, now)
	local remaining = b.endTime - now
	if remaining <= 0 then
		self:Finish(b, "success")
		return
	end

	local progress
	if b.channeling then
		progress = remaining / b.duration
	else
		progress = (now - b.startTime) / b.duration
	end
	progress = math_max(0, math_min(1, progress))

	local extent = b.extent
	local fill = math_floor(progress * extent + 0.5) / extent
	if fill ~= b.lastFill then
		b.lastFill = fill
		b.bar:SetValue(fill)
	end

	local rate = self.db.timeFormat == "centiseconds" and 100 or 1000
	local tick = math_floor(remaining * rate)
	if tick ~= b.lastTick then
		b.lastTick = tick
		b.timeText:SetText(self:FormatTime(remaining))
	end
end

function CastingBars:StartBounce(b)
	b.bounceActive = true
	b.bounceStart = GetTime()
end

function CastingBars:UpdateBounce(b, now)
	local elapsed = now - b.bounceStart

	if elapsed >= BOUNCE_DURATION then
		b.bounceActive = false
		b.bar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
		return
	end

	local intensity = math_sin(elapsed / BOUNCE_DURATION * math_pi)

	b.bar:SetBackdropBorderColor(
		0.5 + (0.5 * intensity),
		0.5 + (0.5 * intensity),
		1.0,
		1
	)
end

function CastingBars:FormatTime(seconds)
	local format = self.db and self.db.timeFormat

	if not seconds or type(seconds) ~= "number" or seconds ~= seconds then
		return format == "centiseconds" and "00.00" or "00.000"
	end

	if seconds < 0 then seconds = 0 end

	local wholeSecs = math_floor(seconds)

	if format == "centiseconds" then
		return string_format("%02d.%02d", wholeSecs, math_floor((seconds - wholeSecs) * 100))
	end

	return string_format("%02d.%03d", wholeSecs, math_floor((seconds - wholeSecs) * 1000))
end

function CastingBars:LoadSettings()
	if not self.db then return end

	local BarUtils = self.addon.BarUtils
	local locked = self.db.locked

	self.db.barTexture = self.addon.BarTexture:Normalize(self.db.barTexture)

	for _, b in ipairs(self.barList) do
		local unitDB = self.db[b.unit]

		self:ApplyOrientation(b)
		BarUtils:LoadPosition(b.frame, unitDB, "", 0, b.defaultY)

		if unitDB.enabled then
			b.frame:EnableMouse(not locked)
			b.title:SetShown(not locked)

			if not locked then
				b.frame:Show()
				b.spellText:SetText("Ready")
				b.timeText:SetText("")
				b.bar:SetValue(0)
				b.lastFill = 0
			elseif b.casting or b.channeling then
				b.frame:Show()
			else
				b.frame:Hide()
			end
		else
			self:ResetState(b)
			b.frame:Hide()
			b.title:Hide()
		end
	end

	if not self.textureApplied then
		self:ApplyBarTexture()
		self.textureApplied = true
	end
end

function CastingBars:ApplyBarTexture()
	if not self.db then return end

	local texture = self.addon.BarTexture:Normalize(self.db.barTexture)

	for _, b in ipairs(self.barList) do
		self.addon.BarTexture:Apply(b.bar, texture)
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
