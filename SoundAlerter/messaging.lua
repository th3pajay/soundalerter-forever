do
SA_Messaging = {}
local M = SA_Messaging

local BREAKER_LIMIT = 5
local BREAKER_RETRY = 60
local OFFENSE_SPAN, INVALID_LIMIT, RATE_LIMIT = 60, 5, 3

M.MAX_FALLBACK = 3

function M.NewBudget()
    return { windowStart = 0, count = 0 }
end

function M.Allow(budget, now, perSecond)
    if now - budget.windowStart >= 1 then
        budget.windowStart = now
        budget.count = 0
    end
    if budget.count >= perSecond then return false end
    budget.count = budget.count + 1
    return true
end

function M.NewBreaker()
    return { failures = 0, openedAt = nil, trips = 0 }
end

function M.Record(breaker, success, now)
    if success then
        breaker.failures, breaker.openedAt = 0, nil
        return false
    end
    breaker.failures = breaker.failures + 1
    if breaker.failures < BREAKER_LIMIT then return false end
    breaker.openedAt = now or 0
    breaker.trips = breaker.trips + 1
    return breaker.failures == BREAKER_LIMIT
end

function M.Open(breaker, now)
    if breaker.failures < BREAKER_LIMIT then return false end
    return not (now and breaker.openedAt and now - breaker.openedAt >= BREAKER_RETRY)
end

function M.Succeeded(result, successValue)
    return result == nil or result == true or (successValue ~= nil and result == successValue)
end

function M.Throttled(result)
    local results = Enum and Enum.SendAddonMessageResult
    local throttle = results and results.AddonMessageThrottle
    return throttle ~= nil and result == throttle
end

function M.Api()
    local info = C_ChatInfo
    local register = info and info.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
    local send = info and info.SendAddonMessage or SendAddonMessage
    return register, send
end

function M.Supported()
    local register, send = M.Api()
    return register ~= nil and send ~= nil
end

function M.IsSelf(sender, playerName, secondName)
    if type(sender) ~= "string" or type(playerName) ~= "string" then return false end
    if sender:match("^[^-]*") == playerName then return true end
    return type(secondName) == "string" and secondName ~= "" and sender == playerName .. " " .. secondName
end

function M.MainName(sender)
    if type(sender) ~= "string" then return nil end
    return sender:match("^([^%s%-]+)")
end

function M.Offend(offenses, sender, kind, now)
    local entry = offenses[sender]
    if not entry or now - entry.start > OFFENSE_SPAN then
        entry = entry or {}
        entry.start, entry.invalid, entry.limited = now, 0, 0
        offenses[sender] = entry
    end
    entry[kind] = entry[kind] + 1
    if entry.invalid >= INVALID_LIMIT then return "invalid messages" end
    if entry.limited >= RATE_LIMIT then return "flooding" end
    return nil
end

function M.Oldest(stamps)
    local oldestKey, oldest
    for key, at in pairs(stamps) do
        if type(at) == "number" and (not oldest or at < oldest) then oldestKey, oldest = key, at end
    end
    return oldestKey
end

function M.ChannelName(faction, day, index)
    local name = "sags" .. (faction == "Horde" and "h" or "a") .. day
    if index and index > 0 then name = name .. string.char(96 + index) end
    return name
end

function M.IsChannelName(text)
    return type(text) == "string" and string.find(text:lower(), "^sags[ah]%d+%l?$") ~= nil
end

function M.SenderAllow(windows, sender, now, limit, span)
    local entry = windows[sender]
    if not entry then
        entry = { start = now, count = 0 }
        windows[sender] = entry
    elseif now - entry.start >= span then
        entry.start, entry.count = now, 0
    end
    if entry.count >= limit then return false end
    entry.count = entry.count + 1
    return true
end
end

do
local SoundAlerter = SoundAlerter
local M = SA_Messaging
local Plain = SA_COMPAT.Plain

local REALM = "CHANNEL"
local REALM_PER_SECOND, REALM_BACKGROUND = 2, 1
local GROUP_PER_SECOND = 4
local THROTTLE_HOLD = 5
local JOIN_ATTEMPTS = 2
local JOIN_RETRY, JOIN_RETRY_LONG, JOIN_SETTLE = 10, 300, 15
local TICK = 1
local SWEEP = 30
local MAX_BAD, MAX_MUTED = 200, 200
local PAUSED_TEXT = {
    realm = "Global sightings paused after repeated send failures; they retry every minute.",
    group = "Party sharing paused after repeated send failures; it retries every minute.",
}

local frame = CreateFrame("Frame")
local playerName, playerSecondName = UnitName("player")
local specs, counters, registered = {}, {}, {}
local listening = false
local realm = { wanted = false, joined = false, name = nil, index = 0, day = nil, attempts = 0, nextJoin = 0, fallbacks = 0, filtered = false }
local chats = {
    realm = { budget = M.NewBudget(), breaker = M.NewBreaker(), holdUntil = 0 },
    group = { budget = M.NewBudget(), breaker = M.NewBreaker(), holdUntil = 0 },
}
local offenses, bad, badAt, badCount = {}, {}, {}, 0
local ticker, nextSweep = nil, 0

local function countersFor(prefix)
    local c = counters[prefix]
    if not c then
        c = { received = 0, accepted = 0, rejected = 0, overBudget = 0, overSender = 0, ignored = 0, combat = 0, sent = 0, failed = 0, throttled = 0 }
        counters[prefix] = c
    end
    return c
end

local function register(prefix)
    if registered[prefix] then return true end
    local reg = M.Api()
    if reg then registered[prefix] = pcall(reg, prefix) end
    return registered[prefix]
end

local function channelId(name)
    name = name or realm.name
    if not name then return nil end
    local ok, id = pcall(GetChannelName, name)
    id = ok and Plain(id)
    if type(id) == "number" and id > 0 then return id end
    return nil
end

local function hideChannel()
    if not ChatFrame_RemoveChannel then return end
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local chat = _G["ChatFrame" .. i]
        if chat then pcall(ChatFrame_RemoveChannel, chat, realm.name) end
    end
end

local function noticeFilter(_, _, _, _, _, channelName, _, _, _, _, channelBaseName)
    local base = Plain(channelBaseName) or Plain(channelName)
    if type(base) ~= "string" then return false end
    return M.IsChannelName(base:match("([^%s%.]+)$"))
end

local function setFilter(on)
    if on == realm.filtered or not ChatFrame_AddMessageEventFilter then return end
    local change = on and ChatFrame_AddMessageEventFilter or ChatFrame_RemoveMessageEventFilter
    if not change then return end
    for _, event in ipairs({ "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_CHANNEL" }) do
        change(event, noticeFilter)
    end
    realm.filtered = on
end

local function leave(name)
    if name and channelId(name) and LeaveChannelByName then pcall(LeaveChannelByName, name) end
end

local wantedName, wantedDay, wantedIndex, wantedFaction

local function wantedChannel()
    local day = math.floor(GetServerTime() / 86400)
    if day ~= realm.day then
        realm.day, realm.index, realm.attempts = day, 0, 0
    end
    local faction = Plain(UnitFactionGroup and UnitFactionGroup("player"))
    if day ~= wantedDay or realm.index ~= wantedIndex or faction ~= wantedFaction then
        wantedDay, wantedIndex, wantedFaction = day, realm.index, faction
        wantedName = M.ChannelName(faction, day, realm.index)
    end
    return wantedName
end

local function ensureChannel(now)
    local wanted = wantedChannel()
    if wanted ~= realm.name then
        if realm.name then
            leave(realm.name)
            realm.nextJoin = 0
        end
        realm.name, realm.joined, realm.attempts = wanted, false, 0
    end
    if channelId() then
        if not realm.joined then
            realm.joined = true
            realm.attempts = 0
            hideChannel()
        end
        return true
    end
    realm.joined = false
    if now < realm.nextJoin then return false end
    if realm.attempts >= JOIN_ATTEMPTS and realm.index < M.MAX_FALLBACK then
        realm.index = realm.index + 1
        realm.fallbacks = realm.fallbacks + 1
        realm.name, realm.attempts = wantedChannel(), 0
    end
    realm.attempts = realm.attempts + 1
    realm.nextJoin = now + (realm.attempts > JOIN_ATTEMPTS and JOIN_RETRY_LONG or JOIN_RETRY)
    local join = JoinTemporaryChannel or JoinChannelByName
    if join then pcall(join, realm.name) end
    return false
end

local function sweep(now)
    for sender, entry in pairs(offenses) do
        if now - entry.start > 120 then offenses[sender] = nil end
    end
    for _, spec in pairs(specs) do
        if spec.windows then
            for sender, entry in pairs(spec.windows) do
                if now - entry.start > math.max(10, spec.perSender.span) then spec.windows[sender] = nil end
            end
        end
    end
end

local function tick()
    local now = GetTime()
    if now >= nextSweep then
        nextSweep = now + SWEEP
        sweep(now)
    end
    if realm.wanted then ensureChannel(now) end
end

local EMPTY = {}

local function muted()
    local global = SoundAlerter.db1 and SoundAlerter.db1.global
    if not global then return EMPTY end
    local list = global.globalMuted
    if not list then
        list = {}
        global.globalMuted = list
    end
    return list
end

local function block(sender, reason, now)
    if bad[sender] then return end
    if badCount >= MAX_BAD then
        local oldest = M.Oldest(badAt)
        if not oldest then return end
        bad[oldest], badAt[oldest] = nil, nil
        badCount = badCount - 1
    end
    bad[sender], badAt[sender] = reason, now
    badCount = badCount + 1
end

local function dropped(sender)
    local list = muted()
    if badCount == 0 and next(list) == nil then return false end
    if bad[sender] or list[sender] then return true end
    local main = M.MainName(sender)
    return main ~= nil and (bad[main] ~= nil or list[main] ~= nil)
end

local function offend(sender, kind, now)
    local reason = M.Offend(offenses, sender, kind, now)
    if reason then block(sender, reason, now) end
end

local function isRealm(distribution, channelName)
    if distribution ~= REALM or not realm.wanted or not realm.name or type(channelName) ~= "string" then return false end
    return channelName == realm.name or channelName:lower() == realm.name
end

local function onMessage(prefix, text, distribution, sender, _, _, _, channelName)
    prefix = Plain(prefix)
    local spec = specs[prefix]
    if not spec then return end
    distribution, channelName = Plain(distribution), Plain(channelName)
    local onRealm = isRealm(distribution, channelName)
    if onRealm then
        if not spec.chats.realm then return end
    elseif distribution == REALM or not spec.chats[distribution] then
        return
    end
    text, sender = Plain(text), Plain(sender)
    if type(text) ~= "string" or type(sender) ~= "string" then return end
    if M.IsSelf(sender, playerName, playerSecondName) then return end
    local c = countersFor(prefix)
    c.received = c.received + 1
    if not spec.inCombat and InCombatLockdown() then
        c.combat = c.combat + 1
        return
    end
    if onRealm and dropped(sender) then
        c.ignored = c.ignored + 1
        return
    end
    local now = GetTime()
    if now >= nextSweep then
        nextSweep = now + SWEEP
        sweep(now)
    end
    local limit = spec.receive
    if type(limit) == "function" then limit = limit(text) end
    if not M.Allow(spec.budget, now, limit) then
        c.overBudget = c.overBudget + 1
        return
    end
    local per = spec.perSender
    if per and not M.SenderAllow(spec.windows, sender, now, per.limit, per.span) then
        c.overSender = c.overSender + 1
        if onRealm and per.offend then offend(sender, "limited", now) end
        return
    end
    if spec.handler(text, sender, onRealm and REALM or distribution, now) == false then
        c.rejected = c.rejected + 1
        if onRealm then offend(sender, "invalid", now) end
        return
    end
    c.accepted = c.accepted + 1
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        onMessage(...)
    elseif event == "PLAYER_ENTERING_WORLD" then
        realm.nextJoin = GetTime() + JOIN_SETTLE
        realm.joined = false
    end
end)

local function refreshEvents()
    local want = next(specs) ~= nil
    if want and not listening then
        frame:RegisterEvent("CHAT_MSG_ADDON")
    elseif listening and not want then
        frame:UnregisterEvent("CHAT_MSG_ADDON")
    end
    listening = want
    if realm.wanted and not ticker then
        ticker = C_Timer.NewTicker(TICK, tick)
    elseif not realm.wanted and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

function M.Listen(prefix, spec)
    register(prefix)
    specs[prefix] = {
        chats = spec.chats or {},
        receive = spec.receive or 4,
        perSender = spec.perSender,
        windows = spec.perSender and {} or nil,
        inCombat = spec.inCombat and true or false,
        handler = spec.handler,
        budget = M.NewBudget(),
    }
    countersFor(prefix)
    refreshEvents()
end

function M.Stop(prefix)
    specs[prefix] = nil
    refreshEvents()
end

function M.Listening(prefix)
    return specs[prefix] ~= nil
end

local function send(chat, prefix, text, distribution, target, perSecond)
    local now = GetTime()
    local state = chats[chat]
    local c = countersFor(prefix)
    if now < state.holdUntil or M.Open(state.breaker, now) or not M.Allow(state.budget, now, perSecond) then
        c.failed = c.failed + 1
        return false
    end
    register(prefix)
    local _, sender = M.Api()
    if not sender then return false end
    local successValue = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success
    local ok, result = pcall(sender, prefix, text, distribution, target)
    local success = ok and M.Succeeded(result, successValue)
    if success then c.sent = c.sent + 1 else c.failed = c.failed + 1 end
    if ok and M.Throttled(result) then
        c.throttled = c.throttled + 1
        state.holdUntil = now + THROTTLE_HOLD
    elseif M.Record(state.breaker, success, now) and state.breaker.trips == 1 then
        SoundAlerter:Print(PAUSED_TEXT[chat])
    end
    return success
end

function M.SendRealm(prefix, text, urgent)
    local id = realm.wanted and realm.joined and channelId()
    if not id then return false end
    return send("realm", prefix, text, REALM, id, urgent and REALM_PER_SECOND or REALM_BACKGROUND)
end

function M.SendGroup(prefix, text, distribution)
    if distribution == REALM then return false end
    return send("group", prefix, text, distribution, nil, GROUP_PER_SECOND)
end

function M.SetRealmWanted(on)
    on = on and true or false
    if on == realm.wanted then return end
    realm.wanted = on
    if on then
        realm.nextJoin = GetTime() + JOIN_SETTLE
        setFilter(true)
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        leave(realm.name)
        realm.name, realm.joined, realm.attempts, realm.index = nil, false, 0, 0
        setFilter(false)
    end
    refreshEvents()
end

function M.RealmReady()
    if not (realm.wanted and realm.joined) then return false end
    local now = GetTime()
    return now >= chats.realm.holdUntil and not M.Open(chats.realm.breaker, now)
end

function M.RealmStatus()
    local now = GetTime()
    local state = chats.realm
    local sending = M.Open(state.breaker, now) and "paused after failures" or (now < state.holdUntil and "holding, throttled" or "ok")
    return { joined = realm.wanted and realm.joined or false, name = realm.name, fallback = realm.index, fallbacks = realm.fallbacks, sending = sending }
end

function M.Counters(prefix)
    return countersFor(prefix)
end

function M.Mute(name)
    local list = muted()
    if list[name] then return end
    local count = 0
    for _ in pairs(list) do count = count + 1 end
    if count >= MAX_MUTED then
        local oldest = M.Oldest(list)
        if oldest then list[oldest] = nil end
    end
    list[name] = GetServerTime()
end

function M.Unmute(name)
    local was = bad[name] ~= nil or muted()[name] ~= nil
    if bad[name] then
        bad[name], badAt[name] = nil, nil
        badCount = badCount - 1
    end
    muted()[name] = nil
    return was
end

function M.Muted()
    local names = {}
    for name in pairs(muted()) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function M.BadSenders()
    return bad, badCount
end
end
