
local CastFeed = {}
local Row = {}
Row.__index = Row

local GetSpellInfo, Plain = SA_COMPAT.GetSpellInfo, SA_COMPAT.Plain
local UnitCastingInfo, UnitChannelInfo = SA_COMPAT.UnitCastingInfo, SA_COMPAT.UnitChannelInfo
local GetTime = GetTime
local setmetatable = setmetatable
local math_floor, math_max, math_min, math_ceil = math.floor, math.max, math.min, math.ceil
local table_remove = table.remove
local string_format = string.format
local ipairs, wipe = ipairs, wipe

local FRAME_PREFIX = "SoundAlerterCastFeed_"
local DEFAULT_Y = -150
local ENTRY_MULTIPLIER = 3
local MIN_CATCH_UP = 1.5
local INFO_CACHE_LIMIT = 512
local DUPLICATE_WINDOW = 0.25
local GAP_LABEL_PADDING = 2
local GAP_LABEL_GLYPHS = 5.5
local INSTANT_ICON = "Interface\\Icons\\Spell_Nature_Lightning"

local ROW_UNITS = { "player", "target", "focus", "party1", "party2", "party3", "party4" }

local ROW_LABELS = {
	player = "Player",
	target = "Target",
	focus = "Focus",
	party1 = "Party 1",
	party2 = "Party 2",
	party3 = "Party 3",
	party4 = "Party 4",
}

local ROW_SET = {}
for _, unit in ipairs(ROW_UNITS) do
	ROW_SET[unit] = true
end

local ROW_KEYS = {
	enabled = true,
	direction = true,
	scale = true,
	PositionX = true,
	PositionY = true,
}

local FEED_KEYS = {
	enabled = true,
	locked = true,
	iconSize = true,
	spacing = true,
	speed = true,
	catchUp = true,
	length = true,
	maxIcons = true,
	showInstants = true,
	showGaps = true,
	gapFontSize = true,
}

local DIRECTIONS = {
	left = { sign = -1, anchor = "RIGHT", horizontal = true, gapPoint = "RIGHT", gapRelative = "LEFT" },
	right = { sign = 1, anchor = "LEFT", horizontal = true, gapPoint = "LEFT", gapRelative = "RIGHT" },
	up = { sign = 1, anchor = "BOTTOM", horizontal = false, gapPoint = "BOTTOM", gapRelative = "TOP" },
	down = { sign = -1, anchor = "TOP", horizontal = false, gapPoint = "TOP", gapRelative = "BOTTOM" },
}

local EVENTS = {
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_SUCCEEDED",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_CHANNEL_STOP",
}

local STATUS_COLORS = {
	casting = { 1, 0.82, 0 },
	channeling = { 1, 0.82, 0 },
	success = { 0.2, 0.9, 0.2 },
	interrupted = { 1, 0.2, 0.2 },
	cancelled = { 0.5, 0.5, 0.5 },
}

local STATUS_LABELS = {
	casting = "Casting",
	channeling = "Channeling",
	success = "Cast",
	interrupted = "Interrupted",
	cancelled = "Cancelled",
}

local FINAL_STATUS = {
	success = true,
	interrupted = true,
	cancelled = true,
}

local TEST_SPELLS = { 133, 118, 2139, 1766, 5782, 8122, 586, 1953, 6770, 408, 853, 172 }
local TEST_STATUSES = { "success", "interrupted", "casting", "success", "cancelled", "channeling" }

local nameCache, iconCache, cacheCount = {}, {}, 0

local function SpellInfo(spellID)
	local name = nameCache[spellID]
	if name then
		return name, iconCache[spellID]
	end

	local infoName, _, icon = GetSpellInfo(spellID)
	if not infoName or not icon then
		return nil
	end

	if cacheCount >= INFO_CACHE_LIMIT then
		wipe(nameCache)
		wipe(iconCache)
		cacheCount = 0
	end

	nameCache[spellID] = infoName
	iconCache[spellID] = icon
	cacheCount = cacheCount + 1

	return infoName, icon
end

local function ResolveKey(unit, castGUID, spellID)
	if not spellID then
		return "hidden:" .. unit, true
	end

	if Plain(castGUID) ~= nil then
		return castGUID, false
	end

	local guid = Plain(UnitGUID(unit)) or unit
	return guid .. ":" .. spellID, true
end

function CastFeed:GetSettings()
	return self.db
end

function CastFeed:SetSetting(key, value)
	local unit, field = key:match("^(%w+)%.(%w+)$")
	if unit then
		if not ROW_SET[unit] or not ROW_KEYS[field] then
			error("CastFeed:SetSetting - unknown setting key '"..tostring(key).."'", 2)
		end
		self.db.rows[unit][field] = value
	else
		if not FEED_KEYS[key] then
			error("CastFeed:SetSetting - unknown setting key '"..tostring(key).."'", 2)
		end
		self.db[key] = value
	end
end

local function ApplyStatus(button, status)
	local color = STATUS_COLORS[status]
	button:SetBackdropBorderColor(color[1], color[2], color[3], 1)
end

local function OnUpdate(frame)
	frame.row:Step()
end

local function OnEvent(frame, event, unit, castGUID, spellID)
	frame.row:OnCastEvent(event, unit, castGUID, spellID)
end

local function OnButtonEnter(button)
	button.row:Hover(button)
end

local function OnButtonLeave(button)
	button.row:Unhover(button)
end

function Row:Create(unit)
	local row = setmetatable({}, Row)

	row.unit = unit
	row.active = {}
	row.byKey = {}
	row.freeEntries = {}
	row.freeButtons = {}
	row.entryCount = 0
	row.buttonCount = 0
	row.feedTime = GetTime()
	row.lastTick = row.feedTime
	row.updating = false
	row.hovered = nil
	row.dir = DIRECTIONS.left
	row.scale = 1

	local frame = CastFeed.addon.BarUtils:CreateContainerFrame(FRAME_PREFIX .. unit, 400, 32, DEFAULT_Y, CastFeed.dragProxy, function()
		row:SavePosition()
	end, false)
	frame.row = row

	frame.bg = frame:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetAllPoints()
	frame.bg:SetColorTexture(0, 0, 0, 0.35)

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.title:SetPoint("BOTTOM", frame, "TOP", 0, 2)
	frame.title:SetText(ROW_LABELS[unit])
	frame.title:SetTextColor(0.8, 0.8, 0.8, 1)

	row.frame = frame

	row.eventFrame = CreateFrame("Frame")
	row.eventFrame.row = row
	row.eventFrame:SetScript("OnEvent", OnEvent)

	return row
end

function Row:SavePosition()
	CastFeed.addon.BarUtils:SavePosition(self.frame, self.settings, "")
end

function Row:ResetPosition()
	local defaults = dbDefaults.profile.castFeed.rows[self.unit]
	self.settings.PositionX = defaults.PositionX
	self.settings.PositionY = defaults.PositionY
	CastFeed.addon.BarUtils:LoadPosition(self.frame, self.settings, "", 0, DEFAULT_Y)
end

function Row:ApplyEvents(active)
	local eventFrame = self.eventFrame
	eventFrame:UnregisterAllEvents()

	if not active then return end

	for _, event in ipairs(EVENTS) do
		if eventFrame.RegisterUnitEvent then
			eventFrame:RegisterUnitEvent(event, self.unit)
		else
			eventFrame:RegisterEvent(event)
		end
	end
end

function Row:LoadSettings()
	local db = CastFeed.db
	local settings = db.rows[self.unit]
	self.settings = settings

	self:Clear()

	self.dir = DIRECTIONS[settings.direction] or DIRECTIONS.left
	self.scale = math_max(settings.scale, 0.25)

	self.gapExtent = 0
	if CastFeed.showGaps then
		if self.dir.horizontal then
			self.gapExtent = GAP_LABEL_GLYPHS * CastFeed.gapFontSize
		else
			self.gapExtent = CastFeed.gapExtent
		end
	end

	local long, short = CastFeed.length * self.scale, CastFeed.iconSize * self.scale
	if self.dir.horizontal then
		self.frame:SetSize(long, short)
	else
		self.frame:SetSize(short, long)
	end

	CastFeed.addon.BarUtils:LoadPosition(self.frame, settings, "", 0, DEFAULT_Y)

	local active = db.enabled and settings.enabled
	if active then
		self.frame:Show()
	else
		self.frame:Hide()
	end

	local unlocked = active and not db.locked
	CastFeed.addon.BarUtils:SetLocked(self.frame, not unlocked)
	self.frame.bg:SetShown(unlocked)
	self.frame.title:SetShown(unlocked)

	self:ApplyEvents(active)
end

function Row:CreateButton()
	local button = CreateFrame("Button", nil, self.frame, "BackdropTemplate")
	button:SetFrameLevel(self.frame:GetFrameLevel() + 1)
	button.row = self

	button.tex = button:CreateTexture(nil, "ARTWORK")
	button.tex:SetPoint("TOPLEFT", 2, -2)
	button.tex:SetPoint("BOTTOMRIGHT", -2, 2)
	button.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	CastFeed.addon.BarUtils:CreateBackdrop(button, 0.5, 0.5, 0.5, 1, nil, nil, nil, nil, nil, 8, 1)

	button.gap = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	button.gap:Hide()

	button:SetScript("OnEnter", OnButtonEnter)
	button:SetScript("OnLeave", OnButtonLeave)
	button:SetScript("OnHide", OnButtonLeave)

	self.buttonCount = self.buttonCount + 1

	return button
end

function Row:ApplyGap(button, entry)
	local gap = button.gap
	if not CastFeed.showGaps or not entry.gapText then
		gap:Hide()
		return
	end

	local dir = self.dir
	local path, _, flags = GameFontNormalSmall:GetFont()
	gap:SetFont(path, CastFeed.gapFontSize * self.scale, flags)
	gap:ClearAllPoints()
	gap:SetPoint(dir.gapPoint, button, dir.gapRelative, 0, 0)
	gap:SetText(entry.gapText)
	gap:Show()
end

function Row:AcquireButton(entry)
	local button = table_remove(self.freeButtons)
	if not button then
		if self.buttonCount >= CastFeed.buttonCap then return nil end
		button = self:CreateButton()
	end

	local size = CastFeed.iconSize * self.scale
	button:SetSize(size, size)
	button:ClearAllPoints()
	button.offset = nil
	if not pcall(button.tex.SetTexture, button.tex, entry.icon) then
		button.tex:SetTexture(134400)
	end
	button.entry = entry
	entry.button = button

	ApplyStatus(button, entry.status)
	self:ApplyGap(button, entry)
	button:Show()

	return button
end

function Row:ReleaseButton(entry)
	local button = entry.button
	if not button then return end

	button.entry = nil
	entry.button = nil
	button.gap:Hide()
	button:Hide()

	self.freeButtons[#self.freeButtons + 1] = button
end

function Row:SetStatus(entry, status)
	if entry.status == status then return end

	entry.status = status

	if entry.button then
		ApplyStatus(entry.button, status)
	end
end

function Row:RemoveAt(index)
	local entry = table_remove(self.active, index)
	if not entry then return end

	self:ReleaseButton(entry)

	if self.byKey[entry.key] == entry then
		self.byKey[entry.key] = nil
	end

	entry.key = nil
	entry.pos = nil

	self.freeEntries[#self.freeEntries + 1] = entry
end

function Row:Clear()
	self.hovered = nil
	self:Detach()

	local active = self.active
	for i = #active, 1, -1 do
		self:RemoveAt(i)
	end
end

function Row:Attach()
	if self.updating or self.hovered or #self.active == 0 then return end

	self.updating = true
	self.frame:SetScript("OnUpdate", OnUpdate)
end

function Row:Detach()
	if not self.updating then return end

	self.updating = false
	self.frame:SetScript("OnUpdate", nil)
end

function Row:Hover(button)
	local entry = button.entry
	if not entry then return end

	self.hovered = button
	self:Detach()

	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")

	local shown = self:SetTooltipBody(entry)
	if not shown then
		GameTooltip:SetText(entry.caster or "Unknown caster")
	end

	if shown and entry.caster then
		GameTooltip:AddLine(entry.caster .. " - " .. STATUS_LABELS[entry.status], 0.8, 0.8, 0.8)
	else
		GameTooltip:AddLine(STATUS_LABELS[entry.status], 0.8, 0.8, 0.8)
	end
	if entry.generic then
		GameTooltip:AddLine("Instant cast - spell hidden by the client", 0.6, 0.6, 0.6)
	end
	if entry.spellID then
		GameTooltip:AddLine("Spell ID: " .. entry.spellID, 1, 0.82, 0)
	end
	GameTooltip:Show()
end

function Row:SetTooltipBody(entry)
	if entry.spellID then
		GameTooltip:SetSpellByID(entry.spellID)
		return true
	end

	if entry.label ~= nil and pcall(GameTooltip.SetText, GameTooltip, entry.label) then
		return true
	end

	return false
end

function Row:Unhover(button)
	if self.hovered ~= button then return end

	self.hovered = nil

	if GameTooltip:IsOwned(button) then
		GameTooltip:Hide()
	end

	local now = GetTime()
	self.lastTick = now

	local oldest = now - CastFeed.length / CastFeed.speed
	if self.feedTime < oldest then
		self.feedTime = oldest
	end

	self:Attach()
end

function Row:DropOne()
	local active = self.active
	local feedTime, speed = self.feedTime, CastFeed.speed

	for i = 1, #active do
		if (feedTime - active[i].t) * speed < 0 then
			self:RemoveAt(i)
			return true
		end
	end

	if not self.hovered and #active > 0 then
		self:RemoveAt(1)
		return true
	end

	return false
end

function Row:Begin(key, spellID, status, isFallback, caster, secretID)
	local now = GetTime()

	local existing = self.byKey[key]
	if existing then
		local replace = isFallback and FINAL_STATUS[existing.status] and now - existing.t >= DUPLICATE_WINDOW
		if not replace then
			if status == "channeling" and existing.status == "success" then
				self:SetStatus(existing, status)
			end
			return
		end
	end

	local unit = self.unit
	local name, icon, label
	local generic = false
	if spellID then
		name, icon = SpellInfo(spellID)
		if not name then return end
	else
		local info = status == "channeling" and UnitChannelInfo or UnitCastingInfo
		local castName, _, _, castIcon = info(unit)
		label, icon = castName, castIcon
		if not issecretvalue(icon) and not icon and secretID ~= nil then
			local ok, texture = pcall(C_Spell.GetSpellTexture, secretID)
			if ok and (issecretvalue(texture) or texture) then
				icon = texture
			end
		end
		if not issecretvalue(icon) and not icon then
			if status ~= "success" then return end
			icon = INSTANT_ICON
			generic = secretID == nil
		end
	end

	local entry = self:Push(key, now)
	if not entry then return end

	entry.spellID = spellID
	entry.name = name
	entry.label = label
	entry.icon = icon
	entry.generic = generic
	entry.status = status
	entry.caster = caster or CastFeed.addon.SafeUnitName(unit)

	self:Attach()
end

function Row:Push(key, now)
	local entry = table_remove(self.freeEntries)
	if not entry then
		if self.entryCount >= CastFeed.entryCap then
			if not self:DropOne() then return nil end
			entry = table_remove(self.freeEntries)
		else
			self.entryCount = self.entryCount + 1
			entry = {}
		end
	end

	local active = self.active

	if #active == 0 then
		self.feedTime = now
		self.lastTick = now
	end

	wipe(entry)
	entry.key = key
	entry.t = now

	local previous = active[#active]
	if previous then
		local seconds = now - previous.t
		entry.gapText = string_format("%02d:%02d:%03d", math_floor(seconds / 60), math_floor(seconds % 60), math_floor(seconds * 1000) % 1000)
	end

	active[#active + 1] = entry
	self.byKey[key] = entry

	return entry
end

function Row:OnCastEvent(event, unit, castGUID, spellID)
	if unit ~= self.unit then return end

	local db = CastFeed.db
	if not db or not db.enabled or not self.settings.enabled then return end

	local secretID
	if spellID ~= nil and issecretvalue(spellID) then
		secretID = spellID
		spellID = nil
	end

	local key, isFallback = ResolveKey(unit, castGUID, spellID)
	if not key then return end

	local entry = self.byKey[key]

	if event == "UNIT_SPELLCAST_START" then
		self:Begin(key, spellID, "casting", isFallback, nil, secretID)
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		self:Begin(key, spellID, "channeling", isFallback, nil, secretID)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if entry and (entry.status == "casting" or entry.status == "cancelled") then
			self:SetStatus(entry, "success")
		elseif db.showInstants then
			self:Begin(key, spellID, "success", isFallback, nil, secretID)
		end
	elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
		if entry and entry.status ~= "success" then
			self:SetStatus(entry, "interrupted")
		end
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" then
		if entry and entry.status == "casting" then
			self:SetStatus(entry, "cancelled")
		end
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		if entry and entry.status == "channeling" then
			self:SetStatus(entry, "success")
		end
	end
end

function Row:Step()
	local now = GetTime()
	local dt = now - self.lastTick
	self.lastTick = now

	local feedTime = self.feedTime
	if feedTime < now then
		feedTime = math_min(now, feedTime + dt * CastFeed.catchUp)
		self.feedTime = feedTime
	end

	local active = self.active
	local size, speed, length = CastFeed.iconSize, CastFeed.speed, CastFeed.length
	local step = size + CastFeed.spacing + self.gapExtent

	local previous
	for i = #active, 1, -1 do
		local entry = active[i]
		local pos = (feedTime - entry.t) * speed
		if pos < 0 then
			entry.pos = nil
			if entry.button then
				self:ReleaseButton(entry)
			end
		else
			if previous and pos < previous + step then
				pos = previous + step
			end
			pos = math_floor(pos)
			entry.pos = pos
			previous = pos
		end
	end

	while active[1] and active[1].pos and active[1].pos - size > length do
		self:RemoveAt(1)
	end

	if #active == 0 then
		self:Detach()
		return
	end

	local dir, scale, frame = self.dir, self.scale, self.frame
	local anchor, sign, horizontal = dir.anchor, dir.sign, dir.horizontal

	for i = 1, #active do
		local entry = active[i]
		local pos = entry.pos
		if pos and pos > 0 then
			local button = entry.button or self:AcquireButton(entry)
			if button then
				local offset = sign * (pos - size) * scale
				if button.offset ~= offset then
					button.offset = offset
					if horizontal then
						button:SetPoint(anchor, frame, anchor, offset, 0)
					else
						button:SetPoint(anchor, frame, anchor, 0, offset)
					end
				end
			end
		end
	end
end

function CastFeed:Initialize()
	if self.initialized then return end

	local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
	if not SoundAlerter then
		error("CastFeed:Initialize() called before addon is ready")
		return
	end

	self.addon = SoundAlerter
	self.db = self.addon.db1.profile.castFeed
	self.testCounter = 0

	self.dragProxy = setmetatable({}, {
		__index = function(_, key)
			local db = CastFeed.db
			return db and db[key]
		end,
	})

	self.rows = {}
	for _, unit in ipairs(ROW_UNITS) do
		self.rows[#self.rows + 1] = Row:Create(unit)
	end

	self:LoadSettings()

	self.initialized = true
end

function CastFeed:LoadSettings()
	if not self.db then return end

	local db = self.db

	self.iconSize = math_max(db.iconSize, 8)
	self.spacing = math_max(db.spacing, 0)
	self.speed = math_max(db.speed, 1)
	self.catchUp = math_max(db.catchUp, MIN_CATCH_UP)
	self.length = math_max(db.length, self.iconSize)
	self.maxIcons = math_max(db.maxIcons, 1)
	self.showGaps = db.showGaps
	self.gapFontSize = math_min(math_max(db.gapFontSize, 8), 20)
	self.gapExtent = self.showGaps and (self.gapFontSize + GAP_LABEL_PADDING) or 0
	self.buttonCap = math_max(self.maxIcons, math_ceil(self.length / (self.iconSize + self.spacing + self.gapExtent)) + 2)
	self.entryCap = self.maxIcons * ENTRY_MULTIPLIER

	for _, row in ipairs(self.rows) do
		row:LoadSettings()
	end
end

function CastFeed:SetLocked(locked)
	if not self.db then return end

	self.db.locked = locked
	self:LoadSettings()
end

function CastFeed:ResetPositions()
	for _, row in ipairs(self.rows) do
		row:ResetPosition()
	end
end

function CastFeed:OnProfileChanged()
	local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
	if not SoundAlerter then return end

	self.addon = SoundAlerter
	self.db = self.addon.db1.profile.castFeed

	if self.initialized then
		self:LoadSettings()
	end
end

function CastFeed:RunTest()
	if not self.initialized or not self.db.enabled then
		self.addon:Print("Cast Feed is disabled - enable it first")
		return
	end

	local ids = {}
	for _, spellID in ipairs(TEST_SPELLS) do
		if SpellInfo(spellID) then
			ids[#ids + 1] = spellID
			if #ids == #TEST_STATUSES then break end
		end
	end

	for _, row in ipairs(self.rows) do
		if row.settings.enabled then
			for i, spellID in ipairs(ids) do
				self.testCounter = self.testCounter + 1
				local key = "test:" .. self.testCounter
				local status = TEST_STATUSES[i]
				C_Timer.After((i - 1) * 0.5, function()
					if self.db and self.db.enabled and row.settings.enabled then
						row:Begin(key, spellID, status, false, "Test")
					end
				end)
			end
		end
	end
end

SoundAlerter.CastFeed = CastFeed
