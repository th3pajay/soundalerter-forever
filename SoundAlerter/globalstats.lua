local SoundAlerter = SoundAlerter
local Model = SA_GlobalStatsModel
local Messaging = SA_Messaging
local Plain = SA_COMPAT.Plain

SA_GlobalStats = {}
local Stats = SA_GlobalStats

Stats.TICK = 30
Stats.FIRST_REPORT = 120
Stats.REPORT_GAP = 900
Stats.REPORT_JITTER = 60
Stats.REFRESH = 3600
Stats.RECEIVE_PER_SECOND = 2
Stats.SENDER_GAP = 240
Stats.MAX_PARTS = 2
Stats.PART_GAP = 1.2
Stats.SWEEP = 600
Stats.RECOMPUTE_GAP = 60

local active, ticker = false, nil
local ids, masks = {}, {}
local known = nil
local nextReport, lastSent, nextSweep = 0, 0, 0
local ownKey
local counters = {}
local cache = { version = -1 }

local function resetCounters()
    counters.merged = 0
end
resetCounters()

local function hash(text)
    return SA_UpdateCheck.Sha256(text)
end

local function buildKnown()
    if known then return end
    known = {}
    for _, list in pairs(SoundAlerterSpells or {}) do
        if type(list) == "table" then
            for id in pairs(list) do
                if type(id) == "number" and id > 0 and id == math.floor(id) then known[id] = true end
            end
        end
    end
end

function Stats.IsKnown(id)
    buildKnown()
    return known[id] == true
end

local function today()
    return SA_GlobalSight.Day(GetServerTime())
end

local cachedRealmKey, cachedRoot
local entryPool, entryPoolCount = {}, 0
local MAX_POOLED = 600

local function realmKey()
    if cachedRealmKey then return cachedRealmKey end
    local realm = Plain(GetRealmName and GetRealmName())
    local faction = Plain(UnitFactionGroup and UnitFactionGroup("player"))
    local key = (realm or "?") .. "|" .. (faction or "?")
    if realm and faction then cachedRealmKey = key end
    return key
end

local function root()
    local global = SoundAlerter.db1 and SoundAlerter.db1.global
    if not global then return nil end
    local data = global.globalStats
    if data ~= nil and data == cachedRoot then return data end
    if type(data) ~= "table" then
        data = {}
        global.globalStats = data
    end
    data.secret = nil
    data.realms = type(data.realms) == "table" and data.realms or {}
    data.mine = type(data.mine) == "table" and data.mine or {}
    data.lastExport = type(data.lastExport) == "table" and data.lastExport or {}
    cachedRoot = data
    return data
end

local senderKeys, senderKeyCount = {}, 0
local MAX_SENDER_KEYS = 2000

local function senderKey(sender)
    local key = senderKeys[sender]
    if key then return key end
    key = Model.SenderKey(hash, Messaging.MainName(sender) or sender)
    if not key then return nil end
    if senderKeyCount >= MAX_SENDER_KEYS then
        senderKeys, senderKeyCount = {}, 0
    end
    senderKeys[sender] = key
    senderKeyCount = senderKeyCount + 1
    return key
end

local function storeFor(data, key)
    local store = data.realms[key]
    if type(store) ~= "table" or type(store.senders) ~= "table" then
        store = Model.NewStore()
        data.realms[key] = store
    end
    return store
end

local function mineFor(data, key, day)
    local mine = data.mine[key]
    if type(mine) ~= "table" or mine.day ~= day or type(mine.e) ~= "table" then
        mine = { day = day, e = {}, dirty = false }
        data.mine[key] = mine
    end
    return mine
end

function Stats.Note(spellID, zoneType)
    if not active or type(spellID) ~= "number" then return end
    local bit = Model.ZONE_BITS[zoneType]
    if not bit or not Stats.IsKnown(spellID) then return end
    local data = root()
    if not data then return end
    local mine = mineFor(data, realmKey(), today())
    local pair = spellID * 8 + bit
    if not mine.e[pair] then
        mine.e[pair] = true
        mine.dirty = true
    end
end

local function ownSenderKey()
    if not ownKey then
        local name = Plain(UnitName and UnitName("player"))
        ownKey = Model.SenderKey(hash, Messaging.MainName(name) or name)
    end
    return ownKey
end

local queue = { parts = {}, at = 1 }

local function sendPart()
    local part = queue.parts[queue.at]
    if not part then return false end
    if not active or InCombatLockdown() or not Messaging.SendRealm(Model.PREFIX, part.text, false) then
        queue.parts, queue.at = {}, 1
        if part.mine then part.mine.dirty = true end
        return false
    end
    if part.sender then
        for index, item in ipairs(part.slice) do ids[index], masks[index] = item.id, item.mask end
        Model.Merge(part.store, part.sender, part.day, ids, masks, #part.slice)
    end
    queue.at = queue.at + 1
    if queue.parts[queue.at] then C_Timer.After(Stats.PART_GAP, sendPart) end
    return true
end

local function report(now)
    if InCombatLockdown() or not Messaging.RealmReady() or queue.parts[queue.at] then return end
    local data = root()
    if not data then return end
    local key, day = realmKey(), today()
    local mine = mineFor(data, key, day)
    if not next(mine.e) then return end
    if not mine.dirty and now - lastSent < Stats.REFRESH then return end
    local spells = Model.Report(mine.e)
    local store, sender = storeFor(data, key), ownSenderKey()
    local parts = {}
    for part = 1, Stats.MAX_PARTS do
        local first = (part - 1) * Model.MAX_ENTRIES + 1
        if first > #spells then break end
        local slice = {}
        for index = first, math.min(#spells, first + Model.MAX_ENTRIES - 1) do slice[#slice + 1] = spells[index] end
        local text = Model.Encode(day, slice)
        if not text then break end
        parts[#parts + 1] = { text = text, slice = slice, store = store, sender = sender, day = day, mine = mine }
    end
    queue.parts, queue.at = parts, 1
    mine.dirty = false
    if sendPart() then
        lastSent = now
        nextReport = now + Stats.REPORT_GAP + math.random(0, Stats.REPORT_JITTER)
    end
end

local function sweep()
    local data = root()
    if not data then return end
    local day = today()
    for _, store in pairs(data.realms) do
        if type(store) == "table" and type(store.senders) == "table" then Model.Prune(store, day) end
    end
    for key, mine in pairs(data.mine) do
        if type(mine) ~= "table" or mine.day ~= day then data.mine[key] = nil end
    end
end

local function onMessage(text, sender)
    local day, count = Model.Decode(text, today(), Stats.IsKnown, ids, masks)
    if not day then return false end
    local key = senderKey(sender)
    local data = root()
    if not key or not data then return true end
    if Model.Merge(storeFor(data, realmKey()), key, day, ids, masks, count) then counters.merged = counters.merged + 1 end
    return true
end

local function tick()
    if not active then return end
    local now = GetTime()
    if now >= nextSweep then
        nextSweep = now + Stats.SWEEP
        sweep()
    end
    if now >= nextReport then report(now) end
end

local function start()
    if active then return end
    local now = GetTime()
    nextReport = now + Stats.FIRST_REPORT + math.random(0, Stats.REPORT_JITTER)
    nextSweep = now + 5
    lastSent = 0
    resetCounters()
    Messaging.Listen(Model.PREFIX, {
        chats = { realm = true },
        receive = Stats.RECEIVE_PER_SECOND,
        perSender = { limit = Stats.MAX_PARTS, span = Stats.SENDER_GAP },
        inCombat = false,
        handler = onMessage,
    })
    ticker = C_Timer.NewTicker(Stats.TICK, tick)
    active = true
end

local function stop()
    if not active then return end
    active = false
    queue.parts, queue.at = {}, 1
    Messaging.Stop(Model.PREFIX)
    if ticker then ticker:Cancel() end
    ticker = nil
end

function SoundAlerter:UpdateGlobalStats()
    local profile = self.db1 and self.db1.profile
    if profile and profile.globalSightings and Messaging.Supported() then start() else stop() end
    cache.version = -1
end

function SoundAlerter:GlobalStatsActive()
    return active
end

function SoundAlerter:GetGlobalVennData()
    local data = root()
    if not data then return nil, 0 end
    local store = storeFor(data, realmKey())
    local day = today()
    local now = GetTime()
    if cache.entries and cache.store == store and cache.day == day and cache.active == active then
        if cache.version == store.version then return cache.entries, cache.players end
        if InCombatLockdown() or now - cache.at < Stats.RECOMPUTE_GAP then return cache.entries, cache.players end
    end
    local spells, players = Model.Aggregate(store, day)
    local entries = {}
    local Venn, Statistics = SA_StatsVenn, SoundAlerter.Statistics
    for _, spell in ipairs(spells) do
        local id = spell.id
        local entry = entryPool[id]
        if not entry then
            local category = Statistics and Statistics.GetSpellCategory and Statistics:GetSpellCategory(id) or "Other"
            entry = { id = id, category = category, group = Venn.GroupOf(category) }
            entryPool[id] = entry
            entryPoolCount = entryPoolCount + 1
        end
        if not entry.named then
            local name = Plain((SA_COMPAT.GetSpellInfo(id)))
            entry.name, entry.named = name or ("Spell " .. id), name ~= nil
        end
        entry.total, entry.byZone, entry.mask = spell.total, spell.byZone, Venn.MaskOf(spell.byZone)
        entries[#entries + 1] = entry
    end
    if entryPoolCount > MAX_POOLED then
        local keep = {}
        for _, entry in ipairs(entries) do keep[entry.id] = entry end
        entryPool, entryPoolCount = keep, #entries
    end
    cache.store, cache.version, cache.day, cache.active, cache.entries, cache.players, cache.at = store, store.version, day, active, entries, players, now
    return entries, players
end

function SoundAlerter:GetGlobalExport()
    local entries, players = self:GetGlobalVennData()
    if not entries or #entries == 0 then return nil end
    local faction = Plain(UnitFactionGroup and UnitFactionGroup("player"))
    return Model.Export({ day = today(), players = players or 0, realm = Plain(GetRealmName and GetRealmName()) or "", faction = faction }, entries)
end

Stats.EXPORT_KEEP_DAYS = 30

function SoundAlerter:SaveGlobalExport()
    if not active then return false end
    local data = root()
    if not data then return false end
    local day = today()
    for key, saved in pairs(data.lastExport) do
        if type(saved) ~= "table" or type(saved.day) ~= "number" or day - saved.day > Stats.EXPORT_KEEP_DAYS then
            data.lastExport[key] = nil
        end
    end
    local entries, players = self:GetGlobalVennData()
    if not entries or #entries == 0 then return false end
    local faction = Plain(UnitFactionGroup and UnitFactionGroup("player"))
    local line = Model.Export({ day = day, players = players or 0, realm = Plain(GetRealmName and GetRealmName()) or "", faction = faction }, entries)
    local key = realmKey()
    local saved = data.lastExport[key]
    if saved and saved.line == line then return false end
    data.lastExport[key] = { line = line, day = day, players = players or 0, at = GetServerTime() }
    return true
end

function SoundAlerter:GlobalStatsStatus()
    local data = root()
    local store = data and storeFor(data, realmKey())
    local mine = data and data.mine[realmKey()]
    local own = 0
    if mine and type(mine.e) == "table" then for _ in pairs(mine.e) do own = own + 1 end end
    local c = Messaging.Counters(Model.PREFIX)
    return string.format("Global statistics: %s; %d players stored, %d of your spell and zone pairs today; received %d (merged %d, rejected %d, limited %d, in combat %d, ignored %d); sent %d, failed %d",
        active and "on" or "off", store and store.count or 0, own, c.received, counters.merged, c.rejected, c.overBudget + c.overSender, c.combat, c.ignored, c.sent, c.failed)
end
