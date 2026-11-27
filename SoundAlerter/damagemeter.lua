local SoundAlerter = SoundAlerter
local Model = SA_MeterModel
local Plain = SA_COMPAT.Plain

local DamageMeter = {}
DamageMeter.iconIds = {}

local FOLD_DELAY = 1
local RETRY_DELAY = 2
local CAST_WINDOW = 3
local NAME_CACHE = 300
local PARTY_UNITS = { "party1", "party2", "party3", "party4" }
local EVENTS = {
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET",
}

local names, nameCount = {}, 0
local dirty, listeners = {}, {}
local ids, queue, byID = {}, {}, {}
local KEYS = { own = {}, row = {} }
local liveCache = {}
local counts = { hits = Model.NewCounts(), avoid = Model.NewCounts(), casts = {}, pvp = false, castAt = 0 }

local function MeterType(name)
    return Enum and Enum.DamageMeterType and Enum.DamageMeterType[name]
end

local function CacheKey(kind, name)
    local list = KEYS[kind]
    local key = list[name]
    if not key then
        key = kind .. ":" .. name
        list[name] = key
    end
    return key
end

local function OwnSource(session)
    local sources = session and session.combatSources
    if type(sources) ~= "table" then return nil end
    for _, source in ipairs(sources) do
        if Plain(source.isLocalPlayer) == true then return source end
    end
    return nil
end

local function Available()
    if not (C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions and C_DamageMeter.GetCombatSessionFromID and MeterType("DamageDone")) then return false end
    if not C_DamageMeter.IsDamageMeterAvailable then return true end
    local ok, available = pcall(C_DamageMeter.IsDamageMeterAvailable)
    return ok and Plain(available) == true
end
DamageMeter.Available = Available

local function SpellName(id)
    local name = names[id]
    if name ~= nil then return name or nil end
    if nameCount >= NAME_CACHE then
        names, nameCount = {}, 0
    end
    local ok, value = pcall(C_Spell.GetSpellName, id)
    value = ok and Plain(value) or nil
    if type(value) ~= "string" or value == "" then value = nil end
    names[id] = value or false
    nameCount = nameCount + 1
    return value
end
DamageMeter.SpellName = SpellName

local function Number(value)
    value = Plain(value)
    if type(value) == "number" then return value end
    return nil
end

local function Text(value)
    value = Plain(value)
    if type(value) == "string" and value ~= "" then return value end
    return nil
end

local function ResetCounts()
    local hits, avoid = counts.hits, counts.avoid
    for i = 1, Model.SLOTS do hits[i], avoid[i] = 0, 0 end
    for name in pairs(counts.casts) do counts.casts[name] = nil end
    counts.pvp = false
end

local function TakeCounts(fight)
    local hits, avoid, casts = Model.NewCounts(), Model.NewCounts(), {}
    for i = 1, Model.SLOTS do hits[i], avoid[i] = counts.hits[i], counts.avoid[i] end
    for name, n in pairs(counts.casts) do casts[name] = n end
    fight.hits, fight.avoid, fight.casts = hits, avoid, casts
    if counts.pvp then fight.pvp = true end
    ResetCounts()
end

local function HostilePlayer(unit)
    return Plain(UnitIsPlayer(unit)) == true and Plain(UnitCanAttack("player", unit)) == true
end

local function PartyBusy()
    for i = 1, #PARTY_UNITS do
        local ok, busy = pcall(UnitAffectingCombat, PARTY_UNITS[i])
        if ok and Plain(busy) == true then return true end
    end
    return false
end

local function ReadSession(id, name)
    local meterType = MeterType(name)
    if not meterType then return nil end
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, id, meterType)
    if not ok or type(session) ~= "table" or type(Plain(session.combatSources)) ~= "table" then return nil end
    return session
end

local function OwnAmount(session)
    if not session then return 0 end
    for _, source in ipairs(session.combatSources) do
        if Plain(source.isLocalPlayer) == true then return Number(source.totalAmount) end
    end
    return 0
end

local function InGroup()
    return Plain(IsInGroup()) == true
end

local function AddMembers(members, session, field)
    if not session then return end
    for _, source in ipairs(session.combatSources) do
        local name, amount = Text(source.name), Number(source.totalAmount)
        if name and amount then
            local m = members[name]
            if not m then
                m = { class = Text(source.classFilename), guid = Text(source.sourceGUID), me = Plain(source.isLocalPlayer) == true or nil }
                members[name] = m
            end
            m[field] = (m[field] or 0) + amount
        end
    end
end

function DamageMeter:PlayerGUID()
    if not self.guid then self.guid = Plain(UnitGUID("player")) end
    return self.guid
end

local function TakenName(id, entry)
    local spell = SpellName(id)
    local from = Text(entry.creatureName)
    if from and spell then return from .. ": " .. spell end
    return spell or from
end

function DamageMeter:OwnSpells(id, name, nameOf)
    local guid = self:PlayerGUID()
    if not guid then return nil end
    local ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromID, id, MeterType(name), guid)
    local spells = ok and type(source) == "table" and Plain(source.combatSpells)
    if type(spells) ~= "table" then return nil end
    local ids = self.iconIds
    for key in pairs(ids) do ids[key] = nil end
    local out = Model.GroupSpells(spells, nameOf, {}, ids)
    Model.NoteIcons(self:Store(), ids)
    return out
end

function DamageMeter:IconFor(name)
    local icons = name and self:Store().icons
    local id = icons and icons[name]
    if not id or not (C_Spell and C_Spell.GetSpellTexture) then return nil end
    return Plain(C_Spell.GetSpellTexture(id))
end

function DamageMeter:ReadFight(id, entry, place)
    local damageSession = ReadSession(id, "DamageDone")
    if not damageSession or Number(damageSession.totalAmount) == nil then return false end
    local healingSession, takenSession, deathSession = ReadSession(id, "HealingDone"), ReadSession(id, "DamageTaken"), ReadSession(id, "Deaths")
    local damage = OwnAmount(damageSession)
    local healing = OwnAmount(healingSession)
    local taken = OwnAmount(takenSession)
    local deaths = OwnAmount(deathSession)
    if damage == nil or healing == nil or taken == nil then return false end
    if damage == 0 and healing == 0 and taken == 0 then return nil end
    local seconds = Number(damageSession.durationSeconds) or Number(entry.durationSeconds) or 0
    local fight = { id = id, seconds = seconds, damage = damage, healing = healing, taken = taken, deaths = deaths or 0 }
    fight.name, fight.boss = Model.FightName(Plain(entry.name))
    fight.place, fight.instance = place.name, place.instance
    fight.spells = self:OwnSpells(id, "DamageDone", SpellName)
    if taken > 0 then fight.takenSpells = self:OwnSpells(id, "DamageTaken", TakenName) end
    if healing > 0 then fight.healSpells = self:OwnSpells(id, "HealingDone", SpellName) end
    local enemies = ReadSession(id, "EnemyDamageTaken")
    if enemies then
        local targets = {}
        for _, source in ipairs(enemies.combatSources) do
            local name, amount = Text(source.name), Number(source.totalAmount)
            if name and amount then targets[name] = (targets[name] or 0) + amount end
            if Text(source.classFilename) then fight.pvp = true end
        end
        fight.targets = targets
    end
    local members = {}
    AddMembers(members, damageSession, "damage")
    AddMembers(members, healingSession, "healing")
    AddMembers(members, takenSession, "taken")
    AddMembers(members, deathSession, "deaths")
    if InGroup() then
        AddMembers(members, ReadSession(id, "Interrupts"), "interrupts")
        AddMembers(members, ReadSession(id, "Dispels"), "dispels")
    end
    fight.members = members
    if place.zone == "instance" then
        local party = {}
        for _, source in ipairs(damageSession.combatSources) do
            local amount = Number(source.totalAmount)
            if amount and #party < Model.PARTY then
                party[#party + 1] = { name = Text(source.name) or "?", class = Text(source.classFilename), damage = amount }
            end
        end
        fight.party = party
    end
    return fight
end

function DamageMeter:MemberSpells(member, field)
    if self.inCombat or not member or not member.lastId or not member.guid then return nil end
    local name = ({ damage = "DamageDone", healing = "HealingDone", taken = "DamageTaken" })[field]
    local meterType = name and MeterType(name)
    if not meterType then return nil end
    local ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromID, member.lastId, meterType, member.guid)
    local spells = ok and type(source) == "table" and Plain(source.combatSpells)
    if type(spells) ~= "table" then return nil end
    local ids = self.iconIds
    for key in pairs(ids) do ids[key] = nil end
    local out = Model.GroupSpells(spells, field == "taken" and TakenName or SpellName, {}, ids)
    Model.NoteIcons(self:Store(), ids)
    return out
end

function DamageMeter:PostTop(field, label)
    if InCombatLockdown() or self.inCombat then return "combat" end
    local session = self:CurrentSession()
    if not session then return "empty" end
    Model.Complete(session)
    local list, total = Model.RankMembers(session.members, field, 5, {})
    local line = Model.ChatLine(label, session.name, list, field, total)
    if not line then return "empty" end
    local addon = self.addon
    if InGroup() then
        local sent = addon:SendChat(line, { "BATTLEGROUND", "RAID", "PARTY" })
        if sent then return "sent" end
        if sent == nil then return "busy" end
    end
    addon:Print(line)
    return "solo"
end

function DamageMeter:Store()
    local char = self.addon.db1.char
    local store = char.damageMeter
    if type(store) ~= "table" or type(store.current) ~= "table" then
        store = Model.New()
        char.damageMeter = store
        self.fresh = true
    end
    return store
end

function DamageMeter:SessionList()
    local ok, list = pcall(C_DamageMeter.GetAvailableCombatSessions)
    list = ok and Plain(list)
    if type(list) ~= "table" then return nil end
    return list
end

local function Newest(list)
    local newest = 0
    for i = 1, #list do
        local id = Number(list[i].sessionID)
        if id and id > newest then newest = id end
    end
    return newest
end

function DamageMeter:Notify(reason, data)
    for _, fn in pairs(listeners) do fn(reason, data) end
end

function DamageMeter:CurrentSession(place)
    return Model.CurrentSession(self:Store(), (place or self:Place()).zone)
end

function DamageMeter:InCombat()
    return self.inCombat == true
end

function DamageMeter:Status()
    if not Available() then return "unavailable" end
    if self.inCombat then return "combat" end
    if self.saving or self.folding then return "saving" end
    return "ready"
end

function DamageMeter:ScheduleFold(delay)
    self.saving = true
    self.foldToken = (self.foldToken or 0) + 1
    local token = self.foldToken
    C_Timer.After(delay, function()
        if token == self.foldToken and self.attached then self:Fold() end
    end)
end

function DamageMeter:Fold()
    local waiting = self.saving
    self.saving = nil
    local list = not (self.inCombat or InCombatLockdown()) and Available() and self:SessionList()
    if not list then
        if waiting then self:Notify("saved") end
        return
    end
    local store = self:Store()
    local busy = PartyBusy()
    local newest = Newest(list)
    if newest > 0 and newest < store.last then store.last = 0 end
    Model.Foldable(list, store.last, busy, ids)
    for key in pairs(byID) do byID[key] = nil end
    for i = 1, #list do
        local id = Number(list[i].sessionID)
        if id then byID[id] = list[i] end
    end
    for i = #queue, 1, -1 do queue[i] = nil end
    for i = 1, #ids do queue[i] = ids[#ids - i + 1] end
    self.folding = { byID = byID, newest = newest, place = self.place or self:Place(), busy = busy }
    self:Step()
end

function DamageMeter:Step()
    local job = self.folding
    if not job or not self.attached then return end
    local id = table.remove(queue)
    if not id then
        self.folding = nil
        self:FlushFold()
        if job.busy then self:ScheduleFold(RETRY_DELAY) end
        return
    end
    local fight = self:ReadFight(id, job.byID[id], job.place)
    if fight == false then
        self.folding = nil
        self:FlushFold()
        self:ScheduleFold(RETRY_DELAY)
        return
    end
    local store = self:Store()
    if fight then
        if id == job.newest then TakeCounts(fight) end
        fight.kind = Model.KindOf(job.place.zone, fight.pvp)
        if fight.kind then
            local session, fresh = Model.Fold(store, fight, time())
            if session then
                self.lastFold = { fight = fight, session = session, kind = fight.kind, fresh = fresh }
                self.foldPending = true
            end
        else
            store.last = id
        end
    else
        store.last = id
    end
    C_Timer.After(0, self.stepFn)
end

function DamageMeter:FlushFold()
    if not self.foldPending then
        self:Notify("saved")
        return
    end
    self.foldPending = nil
    self:Notify("fold", self.lastFold)
end

function DamageMeter:Place()
    local name, _, _, _, _, _, _, instance = GetInstanceInfo()
    return { zone = SA_ZoneKind.Kind(), name = Text(name), instance = Number(instance) }
end

function DamageMeter:OnCombatStart()
    self.inCombat = true
    self:WatchCombat(true)
    for key in pairs(liveCache) do liveCache[key] = nil end
    if GetTime() - counts.castAt > CAST_WINDOW then
        for name in pairs(counts.casts) do counts.casts[name] = nil end
    end
    if HostilePlayer("target") then counts.pvp = true end
    if next(listeners) and not self.ticker then
        self.ticker = C_Timer.NewTicker(self.db.refresh, function() self:Tick() end)
    end
    self:Notify("start")
end

function DamageMeter:OnCombatEnd()
    self.inCombat = false
    self:WatchCombat(false)
    for key in pairs(liveCache) do liveCache[key] = nil end
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    self.place = self:Place()
    self:Notify("end")
    self:ScheduleFold(FOLD_DELAY)
end

function DamageMeter:Tick()
    if not next(dirty) then return end
    for key in pairs(liveCache) do liveCache[key] = nil end
    self:Notify("live", dirty)
    for key in pairs(dirty) do dirty[key] = nil end
end

function DamageMeter:OnUnitCombat(unit, action, flag)
    if not self.inCombat then return end
    local slot = Model.HitSlot(Plain(action), Plain(flag))
    if not slot then return end
    local list = unit == "player" and counts.avoid or counts.hits
    list[slot] = list[slot] + 1
end

function DamageMeter:OnCast(spellID)
    spellID = Number(spellID)
    if not spellID then return end
    local name = SpellName(spellID)
    if not name then return end
    counts.casts[name] = (counts.casts[name] or 0) + 1
    counts.castAt = GetTime()
end

local ON = {}

function ON.DAMAGE_METER_COMBAT_SESSION_UPDATED(_, meterType)
    meterType = Number(meterType)
    if meterType then dirty[meterType] = true end
end

function ON.UNIT_COMBAT(self, unit, action, flag)
    self:OnUnitCombat(unit, action, flag)
end

function ON.UNIT_SPELLCAST_SUCCEEDED(self, _, _, spellID)
    self:OnCast(spellID)
end

function ON.PLAYER_TARGET_CHANGED(self)
    if self.inCombat and HostilePlayer("target") then counts.pvp = true end
end

function ON.PLAYER_REGEN_DISABLED(self)
    self:OnCombatStart()
end

function ON.PLAYER_REGEN_ENABLED(self)
    self:OnCombatEnd()
end

function ON.DAMAGE_METER_RESET(self)
    self:Store().last = 0
end

function ON.DAMAGE_METER_CURRENT_SESSION_UPDATED()
    dirty.current = true
end

function ON.PLAYER_ENTERING_WORLD(self, isInitialLogin)
    if isInitialLogin == true then Model.OnLogin(self:Store(), time()) end
    self:ScheduleFold(FOLD_DELAY)
end

function DamageMeter:OnEvent(event, ...)
    local handler = ON[event]
    if handler then handler(self, ...) end
end

function DamageMeter:WatchCombat(on)
    local events = self.events
    if on then
        events:RegisterUnitEvent("UNIT_COMBAT", "player", "target")
        events:RegisterEvent("PLAYER_TARGET_CHANGED")
    else
        events:UnregisterEvent("UNIT_COMBAT")
        events:UnregisterEvent("PLAYER_TARGET_CHANGED")
    end
end

function DamageMeter:Subscribe(key, fn)
    listeners[key] = fn
    if self.inCombat and not self.ticker and self.attached then
        self.ticker = C_Timer.NewTicker(self.db.refresh, function() self:Tick() end)
    end
end

function DamageMeter:Unsubscribe(key)
    listeners[key] = nil
    if not next(listeners) and self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
end

function DamageMeter:Live(name)
    local cached = liveCache[name]
    if cached ~= nil then return cached or nil end
    local meterType = MeterType(name)
    if not meterType then return nil end
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, Enum.DamageMeterSessionType.Current, meterType)
    if not ok or type(session) ~= "table" then session = nil end
    if self.inCombat then liveCache[name] = session or false end
    return session
end

function DamageMeter:LiveOwn(name)
    local key = CacheKey("own", name)
    local cached = liveCache[key]
    if cached ~= nil then return cached or nil end
    local meterType, guid = MeterType(name), self:PlayerGUID()
    if not (meterType and guid) then return nil end
    local ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, Enum.DamageMeterSessionType.Current, meterType, guid)
    if not ok or type(source) ~= "table" then source = nil end
    if self.inCombat then liveCache[key] = source or false end
    return source
end

function DamageMeter:LiveOwnRow(name)
    local key = CacheKey("row", name)
    local cached = liveCache[key]
    if cached ~= nil then return cached or nil end
    local row = OwnSource(self:Live(name))
    if self.inCombat then liveCache[key] = row or false end
    return row
end

function DamageMeter:ToggleWindow()
    SoundAlerter.DamageMeterWindow:Toggle(self)
end

function DamageMeter:NewSession()
    local _, kind = self:CurrentSession()
    Model.Close(self:Store(), kind, time())
    self:Notify("fold")
end

function DamageMeter:Counts()
    return counts
end

function DamageMeter:Attach(skipOld)
    if self.attached then return end
    if not self.events then
        self.events = CreateFrame("Frame")
        self.events:SetScript("OnEvent", function(_, event, ...) DamageMeter:OnEvent(event, ...) end)
    end
    local events = self.events
    for i = 1, #EVENTS do pcall(events.RegisterEvent, events, EVENTS[i]) end
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    self.stepFn = self.stepFn or function() DamageMeter:Step() end
    self.attached = true
    local store = self:Store()
    if (skipOld or self.fresh) and Available() then
        local list = self:SessionList()
        if list then store.last = math.max(store.last, Newest(list)) end
    end
    self.fresh = nil
    self.inCombat = InCombatLockdown() and true or false
    if self.inCombat then self:WatchCombat(true) end
    ResetCounts()
end

function DamageMeter:Detach()
    if not self.attached then return end
    self.attached = false
    self.events:UnregisterAllEvents()
    self.foldToken = (self.foldToken or 0) + 1
    self.folding = nil
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
end

function DamageMeter:Initialize()
end

function DamageMeter:GetSettings()
    return self.db
end

local function OnStrip(reason, changed)
    local strip = SoundAlerter.DamageMeterStrip.Controller
    if reason == "live" or reason == "start" then
        strip:OnLive(reason == "live" and changed or nil)
    elseif reason == "end" then
        strip:OnCombatEnd()
    elseif reason == "fold" then
        strip:OnFold(changed)
    end
end

function DamageMeter:ResetPosition()
    local db = self.db
    if not db then return end
    db.PositionX, db.PositionY = 0, -230
    self:Apply("PositionY")
end

function DamageMeter:Apply(changedKey)
    local db = self.db
    if not db then return end
    local strip = SoundAlerter.DamageMeterStrip.Controller
    if db.enabled then
        self:Attach(changedKey == "enabled")
        if not strip.view then strip:Create(self) end
        self:Subscribe("strip", OnStrip)
        strip:Apply()
        local window = SoundAlerter.DamageMeterWindow
        if window:IsOpen() and changedKey == "windowScale" then window.frame:SetScale(db.windowScale) window:Fonts() end
    else
        self:Unsubscribe("strip")
        strip:Hide()
        SoundAlerter.DamageMeterWindow:Close()
        self:Detach()
    end
    if self.ticker and changedKey == "refresh" then
        self.ticker:Cancel()
        self.ticker = C_Timer.NewTicker(db.refresh, function() self:Tick() end)
    end
end

SoundAlerter.DamageMeter = DamageMeter
SA_Modules.Register({ key = "DamageMeter", module = DamageMeter, db = "damageMeter", title = "Damage meter", nav = { section = "Displays", order = 32 }, options = "BuildDamageMeterOptions", enabled = { "enabled" } })
