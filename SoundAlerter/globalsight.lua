do
SA_GlobalSight = {}

local VERSION = "1"
local MAX_LENGTH = 240
local FUTURE_LIMIT = 120
local PAST_LIMIT = 600
local SIGHT_FIELDS = 15
local PRESENCE_FIELDS = 5
local CONFIRM_DRIFT = 2

local CLASSES = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, DEATHKNIGHT = true, SHAMAN = true,
    MAGE = true, WARLOCK = true, MONK = true, DRUID = true, DEMONHUNTER = true, EVOKER = true,
}
local BANDS = { C = true, N = true, M = true, D = true }
local SOURCES = { P = true, T = true, F = true, A = true }

SA_GlobalSight.PREFIX = "SoundAlerterG"
SA_GlobalSight.SELF = "@self"
SA_GlobalSight.BAND_CODE = { Close = "C", Nearby = "N", Medium = "M", Detected = "D", Spotted = "D" }

local string_find, string_sub, string_byte, string_format = string.find, string.sub, string.byte, string.format
local math_floor, math_abs, tonumber, type = math.floor, math.abs, tonumber, type

local parts = {}
local buffer = {}

local function Split(text)
    local count, start = 0, 1
    while true do
        local stop = string_find(text, "|", start, true)
        count = count + 1
        if count > SIGHT_FIELDS then return count end
        if not stop then
            parts[count] = string_sub(text, start)
            return count
        end
        parts[count] = string_sub(text, start, stop - 1)
        start = stop + 1
    end
end

local function Int(text, low, high)
    if type(text) ~= "string" or text == "" or #text > 10 or string_find(text, "^%-?%d+$") == nil then return nil end
    local value = tonumber(text)
    if value < low or value > high then return nil end
    return value
end

local function IsInt(value, low, high)
    return type(value) == "number" and value == math_floor(value) and value >= low and value <= high
end

local function IsTag(tag)
    return type(tag) == "string" and #tag == 6 and string_find(tag, "^%x+$") ~= nil
end

local function TimeOk(t, now)
    return t <= now + FUTURE_LIMIT and t >= now - PAST_LIMIT
end

function SA_GlobalSight.Day(serverTime)
    return math_floor(serverTime / 86400)
end

function SA_GlobalSight.Confirmed(record)
    return record.selfSeen or (record.reporterCount or 0) >= 2
end

function SA_GlobalSight.NewTag()
    return string_format("%06x", math.random(0, 0xFFFFFF))
end

function SA_GlobalSight.Cell(value)
    if type(value) ~= "number" or value ~= value then return nil end
    local cell = math_floor(value * 100)
    if cell < 0 or cell > 99 then return nil end
    return cell
end

function SA_GlobalSight.EncodeSight(tag, guid, name, class, level, race, mapID, cx, cy, band, source, t)
    if not IsTag(tag) or not SA_PartyShare.IsGUID(guid) then return nil end
    name = SA_PartyShare.CleanName(name)
    if not name or not CLASSES[class] then return nil end
    level = level or -1
    if not IsInt(level, -1, 200) then return nil end
    if race ~= nil and not IsInt(race, 1, 255) then return nil end
    if not IsInt(mapID, 1, 9999999) or not IsInt(cx, 0, 99) or not IsInt(cy, 0, 99) then return nil end
    if not BANDS[band] or not SOURCES[source] or not IsInt(t, 1, 9999999999) then return nil end
    buffer[1], buffer[2], buffer[3], buffer[4], buffer[5] = VERSION, "G", tag, guid, name
    buffer[6], buffer[7], buffer[8], buffer[9], buffer[10] = class, level, race or "", mapID, cx
    buffer[11], buffer[12], buffer[13], buffer[14], buffer[15] = cy, band, source, t, ""
    local text = table.concat(buffer, "|", 1, SIGHT_FIELDS)
    if #text > MAX_LENGTH then return nil end
    return text
end

function SA_GlobalSight.EncodePresence(tag, mapID, t)
    if not IsTag(tag) or not IsInt(mapID, 1, 9999999) or not IsInt(t, 1, 9999999999) then return nil end
    return string_format("%s|H|%s|%d|%d", VERSION, tag, mapID, t)
end

function SA_GlobalSight.Decode(text, now, out)
    if type(text) ~= "string" or #text > MAX_LENGTH or #text < 9 then return nil end
    if string_byte(text, 1) ~= 49 or string_byte(text, 2) ~= 124 or string_byte(text, 4) ~= 124 then return nil end
    local kind = string_sub(text, 3, 3)
    if kind ~= "G" and kind ~= "H" then return nil end
    local count = Split(text)
    if kind == "H" then
        if count ~= PRESENCE_FIELDS or not IsTag(parts[3]) then return nil end
        local mapID, t = Int(parts[4], 1, 9999999), Int(parts[5], 1, 9999999999)
        if not mapID or not t or not TimeOk(t, now) then return nil end
        out.kind, out.tag, out.mapID, out.t = "H", parts[3], mapID, t
        return out
    end
    if count ~= SIGHT_FIELDS or not IsTag(parts[3]) or not SA_PartyShare.IsGUID(parts[4]) then return nil end
    local class = parts[6]
    if not CLASSES[class] then return nil end
    local level = Int(parts[7], -1, 200)
    local race = parts[8] ~= "" and Int(parts[8], 1, 255) or nil
    if not level or (parts[8] ~= "" and not race) then return nil end
    local mapID, cx, cy = Int(parts[9], 1, 9999999), Int(parts[10], 0, 99), Int(parts[11], 0, 99)
    if not mapID or not cx or not cy then return nil end
    local band, source = parts[12], parts[13]
    if not BANDS[band] or not SOURCES[source] then return nil end
    local t = Int(parts[14], 1, 9999999999)
    if not t or not TimeOk(t, now) then return nil end
    if #parts[15] > 8 or string_find(parts[15], "[^%a]") then return nil end
    local name = SA_PartyShare.CleanName(parts[5])
    if not name then return nil end
    out.kind, out.tag, out.guid, out.name, out.class = "G", parts[3], parts[4], name, class
    out.level, out.race, out.mapID, out.cx, out.cy = level >= 0 and level or nil, race, mapID, cx, cy
    out.band, out.source, out.t = band, source, t
    return out
end

function SA_GlobalSight.NewStore(maxRecords, maxReporters, maxWatchers)
    return {
        records = {}, count = 0, pool = {}, max = maxRecords, maxReporters = maxReporters,
        watchers = {}, watcherCounts = {}, maxWatchers = maxWatchers, dirty = {}, freshAge = 120,
    }
end

local function Release(store, guid, record)
    store.records[guid] = nil
    store.count = store.count - 1
    store.pool[#store.pool + 1] = record
end

local function EvictOldest(store)
    local oldestGuid, oldest
    for guid, record in pairs(store.records) do
        if not oldest or record.lastSeen < oldest.lastSeen then oldestGuid, oldest = guid, record end
    end
    if oldestGuid then Release(store, oldestGuid, oldest) end
end

local function Drifted(record, sight)
    return record.anchorMapID ~= sight.mapID or math_abs(record.anchorCx - sight.cx) > CONFIRM_DRIFT or math_abs(record.anchorCy - sight.cy) > CONFIRM_DRIFT
end

function SA_GlobalSight.Merge(store, sight, reporter, now, isSelf)
    local guid = sight.guid
    local record = store.records[guid]
    local moved = true
    if record then
        local mismatch = record.class ~= sight.class or record.name ~= sight.name
        if mismatch and not isSelf then return nil, false end
        if mismatch or Drifted(record, sight) then
            record.reporterCount, record.selfSeen = 0, false
            record.anchorMapID, record.anchorCx, record.anchorCy = sight.mapID, sight.cx, sight.cy
        end
        local changed = record.mapID ~= sight.mapID or record.cx ~= sight.cx or record.cy ~= sight.cy
        moved = changed or now - record.lastSeen > store.freshAge
        if changed then
            record.prevMapID, record.prevCx, record.prevCy = record.mapID, record.cx, record.cy
        end
        if record.mapID ~= sight.mapID then store.dirty[record.mapID] = true end
    else
        if store.count >= store.max then EvictOldest(store) end
        local pool = store.pool
        record = pool[#pool]
        if record then
            pool[#pool] = nil
        else
            record = { reporters = {} }
        end
        record.guid, record.firstSeen, record.reporterCount = guid, now, 0
        record.prevMapID, record.prevCx, record.prevCy = nil, nil, nil
        record.selfSeen = false
        record.anchorMapID, record.anchorCx, record.anchorCy = sight.mapID, sight.cx, sight.cy
        store.records[guid] = record
        store.count = store.count + 1
    end
    record.name, record.class, record.level, record.race = sight.name, sight.class, sight.level, sight.race
    record.mapID, record.cx, record.cy, record.band, record.source = sight.mapID, sight.cx, sight.cy, sight.band, sight.source
    record.lastSeen, record.reportedAt = now, sight.t
    if isSelf then record.selfSeen = true end
    local reporters, known = record.reporters, false
    for i = 1, record.reporterCount do
        if reporters[i] == reporter then known = true break end
    end
    if not known and record.reporterCount < store.maxReporters then
        record.reporterCount = record.reporterCount + 1
        reporters[record.reporterCount] = reporter
    end
    if moved then store.dirty[sight.mapID] = true end
    return record, moved
end

function SA_GlobalSight.Presence(store, reporter, mapID, now)
    local zone = store.watchers[mapID]
    if not zone then
        zone = {}
        store.watchers[mapID] = zone
        store.watcherCounts[mapID] = 0
    end
    if zone[reporter] == nil then
        if store.watcherCounts[mapID] >= store.maxWatchers then return false end
        store.watcherCounts[mapID] = store.watcherCounts[mapID] + 1
        store.dirty[mapID] = true
    end
    zone[reporter] = now
    return true
end

function SA_GlobalSight.Sweep(store, now, recordAge, watcherAge)
    local removed = 0
    for guid, record in pairs(store.records) do
        if now - record.lastSeen > recordAge then
            store.dirty[record.mapID] = true
            Release(store, guid, record)
            removed = removed + 1
        end
    end
    for mapID, zone in pairs(store.watchers) do
        for reporter, seen in pairs(zone) do
            if now - seen > watcherAge then
                zone[reporter] = nil
                store.watcherCounts[mapID] = store.watcherCounts[mapID] - 1
                store.dirty[mapID] = true
            end
        end
        if store.watcherCounts[mapID] <= 0 then
            store.watchers[mapID] = nil
            store.watcherCounts[mapID] = nil
        end
    end
    return removed
end

function SA_GlobalSight.ZoneStats(store, mapID, now, window, out)
    local classes = out.classes or {}
    for class in pairs(classes) do classes[class] = 0 end
    local enemies, lastSpotted = 0, nil
    for _, record in pairs(store.records) do
        if record.mapID == mapID and now - record.lastSeen <= window then
            enemies = enemies + 1
            classes[record.class] = (classes[record.class] or 0) + 1
            if not lastSpotted or record.lastSeen > lastSpotted then lastSpotted = record.lastSeen end
        end
    end
    out.classes, out.enemies, out.lastSpotted, out.watchers = classes, enemies, lastSpotted, store.watcherCounts[mapID] or 0
    return out
end

function SA_GlobalSight.Need(sent, mapID, cx, cy, now, refresh)
    if not sent then return 3 end
    if sent.mapID ~= mapID or sent.cx ~= cx or sent.cy ~= cy then return 2 end
    if now - sent.at >= refresh then return 1 end
    return 0
end

function SA_GlobalSight.NewBucket(size, rate)
    return { tokens = size, size = size, rate = rate, at = nil }
end

function SA_GlobalSight.Take(bucket, now)
    if bucket.at then
        bucket.tokens = math.min(bucket.size, bucket.tokens + (now - bucket.at) * bucket.rate)
    end
    bucket.at = now
    if bucket.tokens < 1 then return false end
    bucket.tokens = bucket.tokens - 1
    return true
end

end

do
local SoundAlerter = SoundAlerter
local G = SA_GlobalSight
local Messaging = SA_Messaging
local Plain = SA_COMPAT.Plain

local PREFIX = G.PREFIX
local TICK = 1
local RECORD_AGE = 600
local WATCHER_AGE = 120
local PRESENCE_INTERVAL = 60
local PRESENCE_JITTER = 5
local RESEND_AFTER = 90
local MAX_RECORDS = 500
local MAX_REPORTERS = 10
local MAX_WATCHERS = 50
local QUALITY = { low = { receive = 4, presence = 2, sweep = 60 }, normal = { receive = 8, presence = 4, sweep = 30 }, high = { receive = 8, presence = 4, sweep = 30 } }
local receivePerSecond, presencePerSecond, sweepInterval = QUALITY.normal.receive, QUALITY.normal.presence, QUALITY.normal.sweep
local PRESENCE_BYTE = string.byte("H")
local SENDER_LIMIT, SENDER_SPAN = 4, 2
local BUCKET_SIZE, BUCKET_RATE = 5, 0.5
local GROUP_TARGETS = {}
for i = 1, 4 do GROUP_TARGETS[#GROUP_TARGETS + 1] = "party" .. i .. "target" end
local RAID_TARGETS = {}
for i = 1, 40 do RAID_TARGETS[#RAID_TARGETS + 1] = "raid" .. i .. "target" end

local tag = G.NewTag()
local store, sentState, bucket
local active = false
local ticker
local nextSweep, nextPresence = 0, 0
local decoded, own, best = {}, {}, {}
local seen = {}
local counters = {}
local profilerClock = debugprofilestop

local function ResetCounters()
    counters.merged, counters.presence, counters.own, counters.conflicts = 0, 0, 0, 0
    counters.sent, counters.sentPresence, counters.swept = 0, 0, 0
    counters.decodeTotal, counters.decodeMax, counters.decodeCount = 0, 0, 0
end
ResetCounters()

local function Eligible()
    local resting = IsResting and IsResting()
    return SA_ZoneKind.Of(SoundAlerter.cachedInstanceType, SoundAlerter.cachedZonePvpType, Plain(resting)) == "world"
end

local function PlayerCell()
    local mapID = C_Map and C_Map.GetBestMapForUnit and Plain(C_Map.GetBestMapForUnit("player"))
    if not mapID then return nil end
    local ok, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not position then return nil end
    local x, y = position:GetXY()
    local cx, cy = G.Cell(Plain(x)), G.Cell(Plain(y))
    if not cx or not cy then return nil end
    return mapID, cx, cy
end

local tickResolved, tickMap, tickCx, tickCy = false, nil, nil, nil

local function TickCell()
    if not tickResolved then
        tickResolved = true
        tickMap, tickCx, tickCy = PlayerCell()
    end
    return tickMap, tickCx, tickCy
end

local function Observe(unit, source, now)
    if not UnitExists(unit) or not Plain(UnitIsPlayer(unit)) or not Plain(UnitIsEnemy("player", unit)) then return end
    local guid = Plain(UnitGUID(unit))
    if type(guid) ~= "string" or seen[guid] or not guid:find("^Player%-") then return end
    seen[guid] = true
    local mapID, cx, cy = TickCell()
    if not mapID then return end
    local name = SA_PartyShare.CleanName(Plain(UnitName(unit)))
    local _, class = UnitClass(unit)
    class = Plain(class)
    local level = Plain(UnitLevel(unit))
    if not name or not class or level == nil then return end
    local _, _, race = UnitRace(unit)
    race = Plain(race)
    own.guid, own.name, own.class, own.level, own.race = guid, name, class, level, race
    own.mapID, own.cx, own.cy, own.source, own.t = mapID, cx, cy, source, GetServerTime()
    local record = store.records[guid]
    own.band = record and record.band or "D"
    G.Merge(store, own, G.SELF, now, true)
    local priority = G.Need(sentState[guid], mapID, cx, cy, now, RESEND_AFTER)
    if priority > (best.priority or 0) then
        best.priority, best.unit, best.guid, best.name, best.class = priority, unit, guid, name, class
        best.level, best.race, best.source = level, race, source
    end
end

local function SendBest(now, mapID, cx, cy)
    if not best.priority or best.priority == 0 then return end
    if not G.Take(bucket, now) then return end
    local band = G.BAND_CODE[SoundAlerter:GetApproxRange(best.unit) or "Detected"] or "D"
    local record = store.records[best.guid]
    if record then record.band = band end
    local level = best.level
    if type(level) ~= "number" or level < 0 then level = -1 end
    local text = G.EncodeSight(tag, best.guid, best.name, best.class, level, best.race, mapID, cx, cy, band, best.source, GetServerTime())
    if not text or not Messaging.SendRealm(PREFIX, text, true) then return end
    counters.sent = counters.sent + 1
    local state = sentState[best.guid]
    if not state then
        state = {}
        sentState[best.guid] = state
    end
    state.mapID, state.cx, state.cy, state.at = mapID, cx, cy, now
end

local function SendPresence(now, mapID)
    if now < nextPresence or not G.Take(bucket, now) then return end
    nextPresence = now + PRESENCE_INTERVAL + math.random(-PRESENCE_JITTER, PRESENCE_JITTER)
    local text = G.EncodePresence(tag, mapID, GetServerTime())
    if text and Messaging.SendRealm(PREFIX, text, true) then
        counters.sentPresence = counters.sentPresence + 1
        G.Presence(store, G.SELF, mapID, now)
    end
end

local function Sweep(now)
    counters.swept = counters.swept + G.Sweep(store, now, RECORD_AGE, WATCHER_AGE)
    for guid, state in pairs(sentState) do
        if now - state.at > RECORD_AGE then sentState[guid] = nil end
    end
end

local function Tick()
    if not active then return end
    local now = GetTime()
    if now >= nextSweep then
        nextSweep = now + sweepInterval
        Sweep(now)
    end
    if not Messaging.RealmReady() or not Eligible() then return end
    tickResolved = false
    for guid in pairs(seen) do seen[guid] = nil end
    best.priority = 0
    Observe("target", "T", now)
    Observe("focus", "F", now)
    for unit in pairs(SA_Plates.Enemies()) do Observe(unit, "P", now) end
    if IsInRaid and IsInRaid() then
        for i = 1, #RAID_TARGETS do Observe(RAID_TARGETS[i], "A", now) end
    elseif IsInGroup and IsInGroup() then
        for i = 1, #GROUP_TARGETS do Observe(GROUP_TARGETS[i], "A", now) end
    end
    if best.priority > 0 then
        local mapID, cx, cy = TickCell()
        if mapID then SendBest(now, mapID, cx, cy) end
    end
    if now >= nextPresence then
        local mapID = TickCell()
        if mapID then SendPresence(now, mapID) end
    end
end

local function ReceiveLimit(text)
    return text:byte(3) == PRESENCE_BYTE and presencePerSecond or receivePerSecond
end

local function OnMessage(text, sender, _, now)
    local started = profilerClock and profilerClock()
    local message = G.Decode(text, GetServerTime(), decoded)
    if started then
        local spent = profilerClock() - started
        counters.decodeTotal = counters.decodeTotal + spent
        counters.decodeCount = counters.decodeCount + 1
        if spent > counters.decodeMax then counters.decodeMax = spent end
    end
    if not message then return false end
    if message.tag == tag then
        counters.own = counters.own + 1
        return true
    end
    if message.kind == "H" then
        if G.Presence(store, sender, message.mapID, now) then counters.presence = counters.presence + 1 end
        return true
    end
    if not G.Merge(store, message, sender, now, false) then
        counters.conflicts = counters.conflicts + 1
        return false
    end
    counters.merged = counters.merged + 1
    return true
end

local function Start()
    if active then return end
    store = G.NewStore(MAX_RECORDS, MAX_REPORTERS, MAX_WATCHERS)
    sentState = {}
    bucket = G.NewBucket(BUCKET_SIZE, BUCKET_RATE)
    nextSweep = GetTime() + sweepInterval
    nextPresence = GetTime() + math.random(5, 15)
    ResetCounters()
    Messaging.SetRealmWanted(true)
    Messaging.Listen(PREFIX, {
        chats = { realm = true },
        receive = ReceiveLimit,
        perSender = { limit = SENDER_LIMIT, span = SENDER_SPAN, offend = true },
        inCombat = true,
        handler = OnMessage,
    })
    ticker = C_Timer.NewTicker(TICK, Tick)
    active = true
end

local function Stop()
    if not active then return end
    active = false
    if ticker then ticker:Cancel() end
    ticker = nil
    Messaging.Stop(PREFIX)
    Messaging.SetRealmWanted(false)
    store, sentState, bucket = nil, nil, nil
    for guid in pairs(seen) do seen[guid] = nil end
end

function SoundAlerter:UpdateGlobalSight()
    local profile = self.db1 and self.db1.profile
    local quality = QUALITY[profile and profile.globalQuality] or QUALITY.normal
    receivePerSecond, presencePerSecond, sweepInterval = quality.receive, quality.presence, quality.sweep
    if profile and profile.globalSightings and Messaging.Supported() then Start() else Stop() end
    if self.UpdateGlobalMap then self:UpdateGlobalMap() end
    if self.UpdateGlobalStats then self:UpdateGlobalStats() end
end

function SoundAlerter:GlobalSightStore()
    return store
end

local TYPES = { { "sightings", PREFIX }, { "statistics", "SoundAlerterS" }, { "update notice", "SoundAlerterV" } }

function SoundAlerter:GlobalSightCommand(rest)
    local command, target = (rest or ""):match("^(%S*)%s*(.-)%s*$")
    command = command and command:lower() or ""
    if command == "mute" or command == "unmute" then
        if target == "" then
            self:Print("Usage: /sa global mute <name> or /sa global unmute <name>")
            return
        end
        if command == "mute" then
            Messaging.Mute(target)
            self:Print("Ignoring global sightings from " .. target .. " on all your characters until you unmute them.")
        elseif Messaging.Unmute(target) then
            self:Print("No longer ignoring " .. target .. ".")
        else
            self:Print(target .. " is not ignored.")
        end
        return
    end
    if not active then
        self:Print("Global sightings are off (Proximity Alerts, Global sightings).")
        return
    end
    local now = GetTime()
    local realm = Messaging.RealmStatus()
    local zoneMap = PlayerCell()
    local stats = zoneMap and G.ZoneStats(store, zoneMap, now, 300, {}) or nil
    local average = counters.decodeCount > 0 and counters.decodeTotal / counters.decodeCount or 0
    self:Print(string.format("Global sightings: channel %s (%s%s), zone %s, send %s", realm.joined and "joined" or "not joined", realm.name or "none", realm.fallback > 0 and ", fallback " .. realm.fallback or "", Eligible() and "open world" or "not eligible", realm.sending))
    for _, item in ipairs(TYPES) do
        local c = Messaging.Counters(item[2])
        self:Print(string.format("Messages, %s: received %d, accepted %d, rejected %d, over budget %d, over sender limit %d, ignored %d, in combat %d; sent %d, failed %d (%d throttled)", item[1], c.received, c.accepted, c.rejected, c.overBudget, c.overSender, c.ignored, c.combat, c.sent, c.failed, c.throttled))
    end
    self:Print(string.format("Sightings: merged %d, presence %d, own %d, conflicting %d; sent %d sightings, %d presence; tracked enemies %d (pool %d), swept %d", counters.merged, counters.presence, counters.own, counters.conflicts, counters.sent, counters.sentPresence, store.count, #store.pool, counters.swept))
    self:Print(string.format("Decode %.3f ms average, %.3f ms max", average, counters.decodeMax))
    if stats then
        self:Print(string.format("This zone, last 5 min: %d enemies, %d watchers", stats.enemies, stats.watchers))
    end
    local bad, badCount = Messaging.BadSenders()
    if badCount > 0 then
        local shown = 0
        for sender, reason in pairs(bad) do
            shown = shown + 1
            if shown > 10 then break end
            self:Print(string.format("Ignored: %s (%s)", sender, reason))
        end
        if badCount > 10 then self:Print(string.format("... and %d more", badCount - 10)) end
    end
    local names = Messaging.Muted()
    if #names > 0 then
        self:Print(string.format("Muted by you (%d): %s", #names, table.concat(names, ", ", 1, math.min(#names, 10)) .. (#names > 10 and ", ..." or "")))
    end
end
end
