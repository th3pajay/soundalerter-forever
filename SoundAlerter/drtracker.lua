local SoundAlerter = SoundAlerter
local DRTracker = {}

local Model = SA_DRModel
local Plain = SA_COMPAT.Plain
local GetTime = GetTime
local issecretvalue = issecretvalue or function() return false end

local UNITS = { "target", "focus" }
local SPOT_DEFAULTS = { target = { 0, -200 }, focus = { 0, -250 } }
local MAX_AURAS = 40
local TEST_TIME = 8
local EDGE_SIZE = 16
local INSET = 4
local TEXT_RATIO = 0.42
local TAG_HEIGHT = 0.3
local TAG_WIDTH = 0.55
local RESET_ALPHA = 0.7
local RESET_SHADE = 0.75
local RESET_SWIPE = 0.45
local CC_SWIPE = 0.65
local FONT = "Fonts\\FRIZQT__.TTF"
local BG_FILE = "Interface\\DialogFrame\\UI-DialogBox-Background"
local WHITE = { 1, 1, 1 }
local GREY = { 0.75, 0.78, 0.84 }

local SETTING_KEYS = {
    enabled = true, target = true, focus = true, size = true, spacing = true,
    numbers = true, tags = true, locked = true,
}

local byID, byName, notCC = {}, {}, {}
local records = {}
local watch = { target = { auras = {} }, focus = { auras = {} } }
local present = {}

local function BuildLookup()
    for category, ids in pairs(Model.SEEDS) do
        for _, id in ipairs(ids) do
            byID[id] = category
            local name = SA_COMPAT.GetSpellInfo(id)
            if name and not byName[name] then byName[name] = category end
        end
    end
end

function DRTracker:Category(aura)
    if type(aura) ~= "table" or issecretvalue(aura) then return nil end
    if Plain(aura.isHarmful) == false then return nil end
    local id = Plain(aura.spellId)
    local category = id and byID[id]
    if not category then
        if id and notCC[id] then return nil end
        local name = Plain(aura.name)
        category = name and byName[name]
        if id then
            if category then byID[id] = category else notCC[id] = true end
        end
    end
    if not category or not self.db.categories[category] then return nil end
    return category, id
end

local function Record(key, category)
    local list = records[key]
    if not list then
        list = {}
        records[key] = list
    end
    local record = list[category]
    if not record then
        record = Model.New()
        list[category] = record
    end
    return record
end

local function Timing(aura)
    local expires, duration = Plain(aura.expirationTime), Plain(aura.duration)
    if type(expires) ~= "number" or expires <= 0 or type(duration) ~= "number" or duration <= 0 then return nil, nil end
    return expires, duration
end

local function IconOf(aura, id)
    local icon = aura.icon
    if icon == nil and id and C_Spell and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(id) end
    return icon
end

function DRTracker:KeyFor(unit)
    if not UnitExists(unit) then return nil end
    if Plain(UnitCanAttack("player", unit)) == false then return nil end
    local guid = Plain(UnitGUID(unit))
    if type(guid) == "string" and guid ~= "" then return guid end
    return "unit:" .. unit
end

function DRTracker:Land(unit, aura, category, id)
    local state = watch[unit]
    local record = Record(state.key, category)
    local now = GetTime()
    local instance = Plain(aura.auraInstanceID)
    if instance then state.auras[instance] = category end
    record.unit, record.instance = unit, instance
    if record.appliedAt == now and Model.Up(record, now) then return end
    local expires, duration = Timing(aura)
    Model.Apply(record, now, IconOf(aura, id), expires, duration)
end

function DRTracker:Rescan(unit)
    local state = watch[unit]
    wipe(state.auras)
    if not state.key then return end
    for category in pairs(present) do present[category] = nil end
    local getAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if getAura then pcall(self.Scan, self, unit, state, getAura) end
    local list = records[state.key]
    if not list then return end
    local now = GetTime()
    for category, record in pairs(list) do
        if not present[category] and Model.Up(record, now) then Model.Fade(record, now, Model.RESET) end
    end
end

function DRTracker:Scan(unit, state, getAura)
    local now = GetTime()
    for index = 1, MAX_AURAS do
        local aura = getAura(unit, index, "HARMFUL")
        if aura == nil or issecretvalue(aura) then break end
        local category, id = self:Category(aura)
        if category then
            present[category] = aura
            local instance = Plain(aura.auraInstanceID)
            if instance then state.auras[instance] = category end
            local record = Record(state.key, category)
            record.unit, record.instance = unit, instance
            local expires, duration = Timing(aura)
            if Model.Expired(record, now) or (record.fadeAt and now >= record.fadeAt) then
                Model.Apply(record, now, IconOf(aura, id), expires, duration)
            else
                Model.Hold(record, expires, duration)
            end
        end
    end
end

function DRTracker:Lose(unit)
    local state = watch[unit]
    local key = state.key
    if not key then return end
    for _, other in ipairs(UNITS) do
        if other ~= unit and watch[other].key == key then return end
    end
    local list = records[key]
    if not list then return end
    local now = GetTime()
    for category, record in pairs(list) do
        Model.Lose(record, now, Model.RESET, Model.CATEGORIES[category].base)
    end
end

local rescanQueue = SA_Coalesce.New(function(flush) C_Timer.After(0, flush) end, function(unit)
    local state = watch[unit]
    if not state or not state.key then return end
    DRTracker:Rescan(unit)
    DRTracker:Refresh(state.key, unit)
end)

function DRTracker:Switch(unit)
    rescanQueue.Cancel(unit)
    self:Lose(unit)
    local state = watch[unit]
    wipe(state.auras)
    state.key = self.db[unit] and self:KeyFor(unit) or nil
    self:Rescan(unit)
    self:Refresh(state.key, unit)
end

function DRTracker:OnAura(unit, info)
    local state = watch[unit]
    if not state or not state.key then return end
    if type(info) ~= "table" or issecretvalue(info) then
        rescanQueue.Request(unit)
        return
    end
    local full, added, removed = info.isFullUpdate, info.addedAuras, info.removedAuraInstanceIDs
    if issecretvalue(full) or issecretvalue(added) or issecretvalue(removed) or full then
        rescanQueue.Request(unit)
        return
    end
    local changed = false
    if added then
        for _, aura in ipairs(added) do
            local category, id = self:Category(aura)
            if category then
                self:Land(unit, aura, category, id)
                changed = true
            end
        end
    end
    if removed then
        local now = GetTime()
        for _, instance in ipairs(removed) do
            local plain = Plain(instance)
            local category = plain and state.auras[plain]
            if category then
                state.auras[plain] = nil
                local list = records[state.key]
                local record = list and list[category]
                if record and record.instance == plain and Model.Fade(record, now, Model.RESET) then changed = true end
            end
        end
    end
    if changed then self:Refresh(state.key, unit) end
end

local function OnEvent(_, event, unit, info)
    if event == "UNIT_AURA" then
        DRTracker:OnAura(unit, info)
    elseif event == "PLAYER_TARGET_CHANGED" then
        DRTracker:Switch("target")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        DRTracker:Switch("focus")
    end
end

local function Watched(key)
    return watch.target.key == key or watch.focus.key == key
end

function DRTracker:Prune(now)
    for key, list in pairs(records) do
        local watched = Watched(key)
        for category, record in pairs(list) do
            if not watched then Model.Cap(record, now, Model.RESET, Model.CATEGORIES[category].base) end
            if Model.Expired(record, now) then list[category] = nil end
        end
        if next(list) == nil then records[key] = nil end
    end
end

local function OnTimer(token)
    if token ~= DRTracker.timerToken then return end
    DRTracker.timerToken = nil
    DRTracker:Refresh()
end

local function OnTicket()
    DRTracker.ticket = nil
    DRTracker.timerAt = nil
    DRTracker:Refresh()
end

function DRTracker:Schedule(now)
    local soonest
    for key, list in pairs(records) do
        local watched = Watched(key)
        for category, record in pairs(list) do
            local at = Model.NextChange(record, now)
            if not at and not watched then at = Model.Deadline(record, Model.CATEGORIES[category].base) end
            if at and (not soonest or at < soonest) then soonest = at end
        end
    end
    if self.testUntil and (not soonest or self.testUntil < soonest) then soonest = self.testUntil end
    if self.timerAt == soonest and (self.ticket or self.timerToken) then return end
    if self.ticket then
        self.ticket:Cancel()
        self.ticket = nil
    end
    self.timerToken, self.timerAt = nil, soonest
    if not soonest then return end
    local delay = math.max(0.05, soonest - now + 0.05)
    if C_Timer.NewTimer then
        self.ticket = C_Timer.NewTimer(delay, OnTicket)
    else
        local token = {}
        self.timerToken = token
        C_Timer.After(delay, function() OnTimer(token) end)
    end
end

local function Numbers(cooldown)
    for _, region in ipairs({ cooldown:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then return region end
    end
    return nil
end

function DRTracker:CreateIcon(holder)
    local icon = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    self.addon.BarUtils:CreateBackdrop(icon, 0.3, 0.3, 0.3, 1, BG_FILE, 0, 0, 0, 0.8, EDGE_SIZE, INSET)
    local texture = icon:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", icon, "TOPLEFT", INSET, -INSET)
    texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -INSET, INSET)
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon.texture = texture
    local cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    cooldown:SetAllPoints(texture)
    cooldown:SetReverse(true)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    icon.cooldown = cooldown
    icon.numbers = Numbers(cooldown)
    local tag = CreateFrame("Frame", nil, icon)
    tag:SetFrameLevel(cooldown:GetFrameLevel() + 2)
    tag.edge = tag:CreateTexture(nil, "BACKGROUND")
    tag.edge:SetPoint("TOPLEFT", tag, "TOPLEFT", -1, 1)
    tag.edge:SetPoint("BOTTOMRIGHT", tag, "BOTTOMRIGHT", 1, -1)
    tag.edge:SetColorTexture(0, 0, 0, 1)
    tag.fill = tag:CreateTexture(nil, "BORDER")
    tag.fill:SetAllPoints(tag)
    tag.text = tag:CreateFontString(nil, "OVERLAY")
    tag.text:SetPoint("CENTER", tag, "CENTER", 0, 0)
    icon.tag = tag
    icon.visible = false
    icon:Hide()
    return icon
end

function DRTracker:CreateRow(unit)
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(1, 1)
    holder:SetClampedToScreen(true)
    holder:SetMovable(true)
    holder:RegisterForDrag("LeftButton")
    holder:SetScript("OnDragStart", function(frame)
        if not DRTracker.db.locked then frame:StartMoving() end
    end)
    holder:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        DRTracker:SaveSpot(unit)
    end)
    holder.shade = holder:CreateTexture(nil, "BACKGROUND")
    holder.shade:SetAllPoints(holder)
    holder.shade:SetColorTexture(0, 0, 0, 0.35)
    holder.shade:Hide()
    holder.icons = {}
    holder.unit = unit
    holder:Hide()
    return holder
end

function DRTracker:SaveSpot(unit)
    local holder = self.rows[unit]
    local x, y = holder:GetCenter()
    local cx, cy = UIParent:GetCenter()
    if not (x and y and cx and cy) then return end
    self.db.spots[unit] = { x = x - cx, y = y - cy }
    self:Place(unit)
end

function DRTracker:Place(unit)
    local holder, db = self.rows[unit], self.db
    holder:ClearAllPoints()
    local spot = db.spots[unit]
    local default = SPOT_DEFAULTS[unit]
    holder:SetPoint("CENTER", UIParent, "CENTER", spot and spot.x or default[1], spot and spot.y or default[2])
    local unlocked = not db.locked
    holder:EnableMouse(unlocked)
    holder.shade:SetShown(unlocked)
    holder.count = nil
end

local function Size(icon, size, text)
    if icon.size == size then return end
    icon.size = size
    icon:SetSize(size, size)
    local tag = icon.tag
    tag:SetSize(math.floor(size * TAG_WIDTH + 0.5), math.floor(size * TAG_HEIGHT + 0.5))
    tag:ClearAllPoints()
    tag:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
    tag.text:SetFont(FONT, math.max(6, math.floor(size * TAG_HEIGHT * 0.8)), "")
    if icon.numbers then icon.numbers:SetFont(FONT, text, "OUTLINE") end
end

function DRTracker:Paint(icon, category, record, now)
    local up = Model.Up(record, now)
    local phase = up and "up" or "reset"
    if icon.record == record and icon.version == record.version and icon.phase == phase and icon.category == category then return end
    icon.record, icon.version, icon.phase, icon.category = record, record.version, phase, category

    local level = Model.Level(record.count)
    icon:SetBackdropBorderColor(level[1], level[2], level[3], 1)
    icon.texture:SetTexture(record.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local info = Model.CATEGORIES[category]
    icon.tag.fill:SetColorTexture(info.color[1], info.color[2], info.color[3], 1)
    icon.tag.text:SetText(info.tag)
    icon.tag.text:SetTextColor(0, 0, 0, 1)

    local cooldown = icon.cooldown
    local color = WHITE
    if up then
        icon.texture:SetDesaturated(false)
        icon.texture:SetVertexColor(1, 1, 1)
        icon:SetAlpha(1)
        cooldown:SetSwipeColor(0, 0, 0, CC_SWIPE)
        if record.expires and record.duration then
            cooldown:SetCooldown(record.expires - record.duration, record.duration)
        elseif record.fadeAt then
            cooldown:SetCooldown(record.appliedAt, record.fadeAt - record.appliedAt)
        else
            local object = record.instance and record.unit and C_UnitAuras.GetAuraDuration and C_UnitAuras.GetAuraDuration(record.unit, record.instance)
            if object and cooldown.SetCooldownFromDurationObject then
                cooldown:SetCooldownFromDurationObject(object, true)
            else
                cooldown:Clear()
            end
        end
    else
        icon.texture:SetDesaturated(true)
        icon.texture:SetVertexColor(RESET_SHADE, RESET_SHADE, RESET_SHADE)
        icon:SetAlpha(RESET_ALPHA)
        cooldown:SetSwipeColor(0, 0, 0, RESET_SWIPE)
        cooldown:SetCooldown(record.fadeAt, record.resetAt - record.fadeAt)
        color = GREY
    end
    if icon.numbers then icon.numbers:SetTextColor(color[1], color[2], color[3], 1) end
end

local TEST_COUNTS = { 1, 2, 3, 1 }

function DRTracker:TestRecords(now)
    local list = self.testRecords
    if not list then
        list = {}
        self.testRecords = list
    end
    local shown = 0
    for _, category in ipairs(Model.ORDER) do
        if self.db.categories[category] and shown < #TEST_COUNTS then
            shown = shown + 1
            local record = list[category] or Model.New()
            list[category] = record
            if record.testAt ~= self.testUntil then
                record.testAt = self.testUntil
                local id = Model.SEEDS[category][1]
                local _, _, icon = SA_COMPAT.GetSpellInfo(id)
                record.count = TEST_COUNTS[shown]
                record.icon = icon
                record.appliedAt = now
                record.expires, record.duration, record.estimate = nil, nil, false
                if shown % 2 == 1 then
                    record.fadeAt, record.resetAt = now + 4, now + 4 + Model.RESET
                else
                    record.fadeAt, record.resetAt = now, now + Model.RESET
                end
                record.version = record.version + 1
            end
        end
    end
    return list
end

function DRTracker:Render(unit, now)
    local holder, db = self.rows[unit], self.db
    local list
    if self.testUntil then
        list = self:TestRecords(now)
    elseif db.enabled and db[unit] and watch[unit].key then
        list = records[watch[unit].key]
    end
    local size, spacing = db.size, db.spacing
    local text = math.max(8, math.floor(size * TEXT_RATIO))
    local count = 0
    if list then
        for _, category in ipairs(Model.ORDER) do
            local record = list[category]
            if record and db.categories[category] and not Model.Expired(record, now) then
                count = count + 1
                local icon = holder.icons[count]
                if not icon then
                    icon = self:CreateIcon(holder)
                    holder.icons[count] = icon
                end
                Size(icon, size, text)
                self:Paint(icon, category, record, now)
                if icon.tags ~= db.tags then
                    icon.tags = db.tags
                    icon.tag:SetShown(db.tags)
                end
                if icon.digits ~= db.numbers then
                    icon.digits = db.numbers
                    icon.cooldown:SetHideCountdownNumbers(not db.numbers)
                end
                if not icon.visible then
                    icon.visible = true
                    icon:Show()
                end
            end
        end
    end
    for index = count + 1, #holder.icons do
        local icon = holder.icons[index]
        if icon.visible then
            icon.visible = false
            icon:Hide()
            icon.record = nil
        end
    end

    if holder.count ~= count or holder.size ~= size or holder.spacing ~= spacing then
        holder.count, holder.size, holder.spacing = count, size, spacing
        local step = size + spacing
        for index = 1, count do
            local icon = holder.icons[index]
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", holder, "LEFT", (index - 1) * step, 0)
        end
        holder:SetSize(math.max(size * 3, count * step - spacing), size)
    end
    holder:SetShown(count > 0 or (not db.locked and db.enabled and db[unit]))
end

function DRTracker:Refresh(key, unit)
    if not self.rows then return end
    local now = GetTime()
    if self.testUntil then
        if now >= self.testUntil then self.testUntil = nil end
        key, unit = nil, nil
    end
    self:Prune(now)
    for _, other in ipairs(UNITS) do
        if not unit or other == unit or (key and watch[other].key == key) then self:Render(other, now) end
    end
    self:Schedule(now)
end

function DRTracker:Listen(target, focus)
    local mode = (target and 1 or 0) + (focus and 2 or 0)
    if self.listening == mode then return end
    self.listening = mode
    local events = self.events
    events:UnregisterAllEvents()
    if target and focus then
        events:RegisterUnitEvent("UNIT_AURA", "target", "focus")
    elseif target or focus then
        events:RegisterUnitEvent("UNIT_AURA", target and "target" or "focus")
    end
    if target then events:RegisterEvent("PLAYER_TARGET_CHANGED") end
    if focus then events:RegisterEvent("PLAYER_FOCUS_CHANGED") end
end

function DRTracker:GetSettings()
    return self.db
end

function DRTracker:SetSetting(key, value)
    local category = type(key) == "string" and key:match("^categories%.(%w+)$")
    if category and Model.CATEGORIES[category] then
        self.db.categories[category] = value and true or false
    elseif SETTING_KEYS[key] then
        self.db[key] = value
    else
        error("DRTracker:SetSetting - unknown setting key '" .. tostring(key) .. "'", 2)
    end
    self:LoadSettings()
end

function DRTracker:LoadSettings()
    local db = self.db
    if not db or not self.rows then return end
    db.categories = db.categories or {}
    db.spots = db.spots or {}
    self:Listen(db.enabled and db.target, db.enabled and db.focus)
    if not db.enabled then
        wipe(records)
        for _, unit in ipairs(UNITS) do
            watch[unit].key = nil
            wipe(watch[unit].auras)
        end
    end
    for _, unit in ipairs(UNITS) do
        self:Place(unit)
        if db.enabled then
            local key = db[unit] and self:KeyFor(unit) or nil
            if key ~= watch[unit].key then
                self:Lose(unit)
                wipe(watch[unit].auras)
                watch[unit].key = key
                self:Rescan(unit)
            end
        end
    end
    self:Refresh()
end

function DRTracker:RunTest()
    if not self.rows then return end
    self.testUntil = GetTime() + TEST_TIME
    self:Refresh()
end

function DRTracker:ResetPositions()
    if not self.db then return end
    self.db.spots = {}
    self:LoadSettings()
end

function DRTracker:OnProfileChanged()
    local addon = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not addon then return end
    self.addon = addon
    self.db = addon.db1.profile.drTracker
    if self.initialized then
        wipe(records)
        self:LoadSettings()
    end
end

function DRTracker:Initialize()
    if self.initialized then return end
    local addon = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not addon then error("DRTracker:Initialize() called before addon is ready") end
    self.addon = addon
    self.db = addon.db1.profile.drTracker
    BuildLookup()
    self.events = CreateFrame("Frame")
    self.events:SetScript("OnEvent", OnEvent)
    self.rows = { target = self:CreateRow("target"), focus = self:CreateRow("focus") }
    self.initialized = true
    self:LoadSettings()
end

DRTracker.records = records
DRTracker.watch = watch
SoundAlerter.DRTracker = DRTracker
