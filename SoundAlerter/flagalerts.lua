
local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
local FlagAlerts = SoundAlerter:NewModule("FlagAlerts", "AceEvent-3.0", "AceTimer-3.0")
local engine

SoundAlerter.FlagAlerts = FlagAlerts

local sadb
local GetLocale = GetLocale
local GetTime = GetTime
local UnitExists = UnitExists
local UnitName = UnitName
local UnitClass = UnitClass
local Plain = SA_COMPAT.Plain
local GetNumRaidMembers = SA_COMPAT.GetNumRaidMembers
local GetNumPartyMembers = SA_COMPAT.GetNumPartyMembers
local debugprofilestop = debugprofilestop

local OBJECTIVE_AUDIO_DELAY = 0.8
local OBJECTIVE_GAP = 2.0
local QUEUE_CAPACITY = 4
local QUEUE_STALE = 5
local MEMO_LIMIT = 32
local BANG = 33
local BASE_DEDUPE_WINDOW = 2.0

local BASE_NAMES = { stables = 1, ["gold mine"] = 2, mine = 2, ["lumber mill"] = 3, blacksmith = 4, farm = 5 }
local BASE_VOICE = { "stables", "goldmine", "lumbermill", "blacksmith", "farm" }
local BASE_LABEL = { "Stables", "Gold Mine", "Lumber Mill", "Blacksmith", "Farm" }
local BASE_ACTION_INDEX = { ASSAULT = 1, TAKEN = 2, DEFEND = 3 }
local BASE_SETTING = { ASSAULT = "baseAssaultAudio", TAKEN = "baseTakenAudio", DEFEND = "baseDefendAudio" }
local BASE_GAP = { 1.0, 0.9, 0.95, 0.9, 0.65 }
local BASE_ACTION_VOICE = {
    ASSAULT = { friendly = "assaulted", enemy = "attacked" },
    TAKEN = { friendly = "captured", enemy = "lost" },
    DEFEND = { friendly = "defended", enemy = "retaken" },
}
local BASE_CHAT_OUTCOME = BASE_ACTION_VOICE
local BASE_TITLE = {}
for index, label in ipairs(BASE_LABEL) do
    local byAction = {}
    for action, words in pairs(BASE_ACTION_VOICE) do
        byAction[action] = { friendly = (label .. " " .. words.friendly):upper(), enemy = (label .. " " .. words.enemy):upper() }
    end
    BASE_TITLE[index] = byAction
end
local CLASS_NAMES = LOCALIZED_CLASS_NAMES_MALE or {}
local FLAG_CHAT_KEY = { PICKUP = "flagPickupChat", DROP = "flagDropChat", CAPTURE = "flagCaptureChat", RETURN = "flagReturnChat" }
local FLAG_ACTION_TEXT = { PICKUP = "picked up the flag", DROP = "dropped the flag", CAPTURE = "captured the flag", RETURN = "returned the flag" }
local BASE_CHAT_KEY = { ASSAULT = "baseAssaultChat", TAKEN = "baseTakenChat", DEFEND = "baseDefendChat" }
local chatValues = {}
local BASE_VERBS = {
    { "has assaulted the ", "^(.+) has assaulted the (.+)!$", "ASSAULT" },
    { "claims the ", "^(.+) claims the (.-)!", "ASSAULT" },
    { "has defended the ", "^(.+) has defended the (.+)!$", "DEFEND" },
    { "has taken the ", "^[Tt]he (%a+) has taken the (.+)!$", "TAKEN" },
}
local PATTERN_MODE_BY_MAP = { [489] = "flag", [2106] = "flag", [726] = "flag", [529] = "base", [2107] = "base", [1681] = "base", [2177] = "base" }
local TEAM_BY_WORD = { Alliance = "ALLIANCE_TEAM", Horde = "HORDE_TEAM", alliance = "ALLIANCE_TEAM", horde = "HORDE_TEAM" }

local FIXED_TOKENS = { "target", "focus", "mouseover" }
local PARTY_TOKENS = {}
for index = 1, 4 do
    PARTY_TOKENS[#PARTY_TOKENS + 1] = "party" .. index
    PARTY_TOKENS[#PARTY_TOKENS + 1] = "party" .. index .. "target"
end
local RAID_TOKENS = {}
for index = 1, 40 do
    RAID_TOKENS[#RAID_TOKENS + 1] = "raid" .. index
    RAID_TOKENS[#RAID_TOKENS + 1] = "raid" .. index .. "target"
end

local string_find = string.find
local string_byte = string.byte
local string_match = string.match
local string_format = string.format
local table_insert = table.insert
local table_sort = table.sort
local math_max = math.max
local math_ceil = math.ceil
local math_huge = math.huge
local math_min = math.min
local pairs = pairs
local ipairs = ipairs

local CACHE_TTL = 60
local MAX_RAID_SCAN = 40

local function SanitizeMacroText(text)
    if not text then return "" end
    text = text:gsub("\n", ""):gsub("\r", ""):gsub("%z", "")
    return text
end

local CACHE_SIZE_SMALL = 30
local CACHE_SIZE_MEDIUM = 50
local CACHE_SIZE_LARGE = 120
local PERSISTENT_CACHE_SIZE_DEFAULT = 500
local MAX_FLAG_TOASTS = 3


local ENGLISH_PATTERNS = {
    { pattern = "^(.+) has taken the flag!$", action = "PICKUP" },
    { pattern = "^The [Hh]orde [Ff]lag was picked up by (.+)!$", action = "PICKUP", faction = "Horde" },
    { pattern = "^The [Aa]lliance [Ff]lag was picked up by (.+)!$", action = "PICKUP", faction = "Alliance" },
    { pattern = "^(.+) has dropped the flag!$", action = "DROP" },
    { pattern = "^The [Hh]orde [Ff]lag was dropped by (.+)!$", action = "DROP", faction = "Horde" },
    { pattern = "^The [Aa]lliance [Ff]lag was dropped by (.+)!$", action = "DROP", faction = "Alliance" },
    { pattern = "^(.+) captured the [Hh]orde [Ff]lag!$", action = "CAPTURE", faction = "Horde" },
    { pattern = "^(.+) captured the [Aa]lliance [Ff]lag!$", action = "CAPTURE", faction = "Alliance" },
    { pattern = "^(.+) captured the .+ flag!$", action = "CAPTURE" },
    { pattern = "^The [Hh]orde [Ff]lag was captured by (.+)!$", action = "CAPTURE", faction = "Horde" },
    { pattern = "^The [Aa]lliance [Ff]lag was captured by (.+)!$", action = "CAPTURE", faction = "Alliance" },
    { pattern = "^The .+ [Ff]lag was captured by (.+)!$", action = "CAPTURE" },
    { pattern = "^The [Hh]orde [Ff]lag was returned to its base by (.+)!$", action = "RETURN", faction = "Horde" },
    { pattern = "^The [Aa]lliance [Ff]lag was returned to its base by (.+)!$", action = "RETURN", faction = "Alliance" },
}
local LOCALE_PATTERNS = { enUS = ENGLISH_PATTERNS, enGB = ENGLISH_PATTERNS }
local TEAM_HOLDING_FLAG = { Horde = "ALLIANCE_TEAM", Alliance = "HORDE_TEAM" }
local TEAM_OWNING_FLAG = { Horde = "HORDE_TEAM", Alliance = "ALLIANCE_TEAM" }

function FlagAlerts.CarrierTeam(action, faction, eventTeam)
    local fromFlag = faction and (action == "RETURN" and TEAM_OWNING_FLAG or TEAM_HOLDING_FLAG)[faction] or nil
    if eventTeam then return eventTeam, fromFlag ~= nil and fromFlag ~= eventTeam end
    return fromFlag, false
end

function FlagAlerts.Side(team, myTeam)
    if team == nil or myTeam == nil then return "unknown" end
    return team == myTeam and "friendly" or "enemy"
end

local FLAT_SETTINGS = {
    "battlegroundAlertsEnabled", "flagToastsEnabled", "flagPickupAudio", "flagDropAudio", "flagCaptureAudio",
    "flagReturnAudio", "baseAssaultAudio", "baseTakenAudio", "baseDefendAudio", "flagTeamBackgroundColors",
    "flagEnemyRedBackground", "flagFriendlyGreenBackground", "flagEnemyTexture", "flagFriendlyTexture",
    "flagOnlyEnemyTeam", "flagOnlyFriendlyTeam", "flagAllActions", "flagChatEnabled", "flagPickupChat",
    "flagDropChat", "flagCaptureChat", "flagReturnChat", "baseAssaultChat", "baseTakenChat", "baseDefendChat",
    "persistentCacheEnabled", "persistentCacheMaxSize", "persistentCacheMaxAge", "flagToastsUseClassIcons",
    "flagToastDisplayDuration", "flagToasts",
}

function FlagAlerts:GetSettings()
    return sadb
end

function FlagAlerts:OnInitialize()
    sadb = SoundAlerter.db1.profile

    self.inCombat = InCombatLockdown() and true or false

    self.nameToClassCache = {}
    self.cacheSize = 0
    self.audioQueue = { slots = {}, head = 1, count = 0, free = {} }
    self.audioInProgress = false
    self.patternMode = "both"
    self.eventsRegistered = false
    self.baseLast = {}
    self.baseMemo = {}
    self.baseMemoCount = 0
    self.baseKeys = {}
    self.baseKeyCount = 0
    self.voicePaths = {}

    self.flagEventCache = {}
    self.FLAG_EVENT_DEDUPE_WINDOW = 2.0

    if not sadb.persistentClassCache then
        sadb.persistentClassCache = {}
    end
    self.persistentCache = sadb.persistentClassCache

    self.persistentCacheSize = 0
    for _ in pairs(self.persistentCache) do
        self.persistentCacheSize = self.persistentCacheSize + 1
    end

    self.performanceMetrics = {
        eventCount = 0,
        totalProcessingTime = 0,
        cacheHits = 0,
        cacheMisses = 0,
        persistentCacheHits = 0,
        maxProcessingTime = 0,
        processingTimes = {},
        processingTimesIndex = 1,
        cacheEvictions = 0,
        classesLearned = 0,
        teamFiltered = 0,
        teamFromEvent = 0,
        teamMismatch = 0,
        chatPickups = 0,
        chatDrops = 0,
        chatCaptures = 0,
        chatReturns = 0,
        dedupeBlocked = 0,

        eventsInCombat = 0,
        eventsOutOfCombat = 0,
        chatAlertsSuppressed = 0,
    }

    self.flagToastMetrics = {
        toastsShown = 0,
        toastsSwapped = 0,
        swapTime = 0,
        maxSwapTime = 0,
        poolExhaustions = 0,
        pickupToasts = 0,
        dropToasts = 0,
        captureToasts = 0,
        toastsInCombat = 0,
        toastsOutOfCombat = 0,
    }

    local locale = GetLocale()
    self.flagPatterns = LOCALE_PATTERNS[locale] or LOCALE_PATTERNS.enUS

end

local CHAT_EVENTS = { "CHAT_MSG_BG_SYSTEM_ALLIANCE", "CHAT_MSG_BG_SYSTEM_HORDE", "CHAT_MSG_BG_SYSTEM_NEUTRAL" }

function FlagAlerts:UpdateEventRegistration()
    local wanted = SA_ZoneKind.Kind() == "battleground" and sadb ~= nil and sadb.battlegroundAlertsEnabled and true or false
    if wanted == self.eventsRegistered then return end
    self.eventsRegistered = wanted
    for _, event in ipairs(CHAT_EVENTS) do
        if wanted then self:RegisterEvent(event) else self:UnregisterEvent(event) end
    end
end

function FlagAlerts:OnZoneChanged()
    self.myTeam = nil
    local mapID = SA_ZoneKind.Kind() == "battleground" and GetInstanceInfo and select(8, GetInstanceInfo()) or nil
    self.patternMode = PATTERN_MODE_BY_MAP[mapID] or "both"
    self:UpdateEventRegistration()
end

function FlagAlerts:OnEnable()
    self:OnZoneChanged()

    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")

    engine:Initialize()

    self:ScheduleRepeatingTimer("CleanupPersistentCache", 300)

end

function FlagAlerts:OnDisable()
    for _, event in ipairs(CHAT_EVENTS) do self:UnregisterEvent(event) end
    self.eventsRegistered = false
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:CancelAllTimers()

end

function FlagAlerts:Apply(changedKey)
    if changedKey == "battlegroundAlertsEnabled" then self:UpdateEventRegistration() end
end

local function SwitchProfile(module)
    sadb = SoundAlerter.db1.profile
    module.persistentCache = sadb.persistentClassCache
    module:UpdateEventRegistration()
end

local function StartedByAce()
end

function FlagAlerts:CHAT_MSG_BG_SYSTEM_ALLIANCE(event, message, ...)
    self:ProcessFlagEvent(message, "ALLIANCE_TEAM")
end

function FlagAlerts:CHAT_MSG_BG_SYSTEM_HORDE(event, message, ...)
    self:ProcessFlagEvent(message, "HORDE_TEAM")
end

function FlagAlerts:CHAT_MSG_BG_SYSTEM_NEUTRAL(event, message, ...)
    self:ProcessFlagEvent(message)
end

function FlagAlerts:PLAYER_REGEN_DISABLED()
    self.inCombat = true

    SoundAlerter:Debug("FlagAlerts", "Entered combat - chat alerts will be suppressed to prevent taint")
end

function FlagAlerts:PLAYER_REGEN_ENABLED()
    self.inCombat = false
    engine:FlushDeferred()
    engine:UpdateLayout()

    if sadb.flagToastsEnabled then
        if engine.secureCreationPending then
            engine:CreateSecurePool()
        end

        local swappedCount, elapsed = engine:SwapToSecure()
        local metrics = self.flagToastMetrics
        metrics.toastsSwapped = metrics.toastsSwapped + swappedCount
        metrics.swapTime = metrics.swapTime + elapsed
        metrics.maxSwapTime = math.max(metrics.maxSwapTime, elapsed)
    end

    SoundAlerter:Debug("FlagAlerts", "Left combat - all features restored")
end

function FlagAlerts:ShouldProcessFlagEvent(playerName, eventType)
    local currentTime = GetTime()

    if not self.flagEventCache[playerName] then
        self.flagEventCache[playerName] = {}
    end

    local eventKey = "last" .. eventType
    local lastTime = self.flagEventCache[playerName][eventKey] or 0

    if (currentTime - lastTime) < self.FLAG_EVENT_DEDUPE_WINDOW then
        self.performanceMetrics.dedupeBlocked = self.performanceMetrics.dedupeBlocked + 1
        return false
    end

    self.flagEventCache[playerName][eventKey] = currentTime
    return true
end

function FlagAlerts:PassesTeamFilter(playerName, side)
    if (side == "friendly" and sadb.flagOnlyEnemyTeam) or (side == "enemy" and sadb.flagOnlyFriendlyTeam) then
        self.performanceMetrics.teamFiltered = self.performanceMetrics.teamFiltered + 1
        SoundAlerter:Debug("FlagAlerts", "Filtered %s team event: %s", side, playerName)
        return false
    end
    return true
end

function FlagAlerts:BaseIndex(raw)
    local keys = self.baseKeys
    local index = keys[raw]
    if index == nil then
        if self.baseKeyCount >= MEMO_LIMIT then
            for key in pairs(keys) do keys[key] = nil end
            self.baseKeyCount = 0
        end
        index = BASE_NAMES[raw:lower()] or false
        keys[raw] = index
        self.baseKeyCount = self.baseKeyCount + 1
    end
    return index
end

function FlagAlerts:ParseBase(message)
    for index = 1, #BASE_VERBS do
        local verb = BASE_VERBS[index]
        if string_find(message, verb[1], 1, true) then
            local first, base = string_match(message, verb[2])
            if not first then return false end
            local baseIndex = self:BaseIndex(base)
            if not baseIndex then
                SoundAlerter:Debug("FlagAlerts", "Unknown base name: %s", base)
                return false
            end
            local action = verb[3]
            if action == "TAKEN" then
                return { action = action, base = baseIndex, team = TEAM_BY_WORD[first] }
            end
            return { action = action, base = baseIndex, player = first }
        end
    end
    return false
end

function FlagAlerts:ParsedBase(message)
    local memo = self.baseMemo
    local parsed = memo[message]
    if parsed == nil then
        if self.baseMemoCount >= MEMO_LIMIT then
            for key in pairs(memo) do memo[key] = nil end
            self.baseMemoCount = 0
        end
        parsed = self:ParseBase(message)
        memo[message] = parsed
        self.baseMemoCount = self.baseMemoCount + 1
    end
    return parsed
end

local voiceFiles = {}

local function VoiceFile(name)
    local file = voiceFiles[name]
    if not file then
        file = name .. ".mp3"
        voiceFiles[name] = file
    end
    return file
end

local function PlayFlagVoice(file, counted)
    local emitter = SoundAlerter.Emitter
    local context = emitter:Context("flag")
    context.sound, context.channel = file, "Master"
    if counted then context.category = "flagAlerts" end
    emitter:Emit(context)
end

function FlagAlerts:VoicePath(name)
    local root = sadb.sapath
    local paths = self.voicePaths
    if root ~= self.voiceRoot then
        self.voiceRoot = root
        for key in pairs(paths) do paths[key] = nil end
    end
    local path = paths[name]
    if not path then
        path = root .. name .. ".mp3"
        paths[name] = path
    end
    return path
end

function FlagAlerts:ProcessBaseEvent(parsed, eventTeam)
    local action = parsed.action
    local team = eventTeam or parsed.team
    local playerName = parsed.player
    local teamSide = FlagAlerts.Side(team, self:GetMyTeam())
    if not self:PassesTeamFilter(playerName or BASE_LABEL[parsed.base], teamSide) then return end
    if not sadb[BASE_SETTING[action]] then return end
    local now = GetTime()
    local slot = parsed.base * 4 + BASE_ACTION_INDEX[action]
    local last = self.baseLast[slot]
    if last and now - last < BASE_DEDUPE_WINDOW then
        self.performanceMetrics.dedupeBlocked = self.performanceMetrics.dedupeBlocked + 1
        return
    end
    self.baseLast[slot] = now
    local side = teamSide == "friendly" and "friendly" or "enemy"
    local label = BASE_LABEL[parsed.base]
    SoundAlerter:Debug("FlagAlerts", "Base %s %s by %s (%s)", label, action, tostring(playerName or team), side)
    self:QueueVoice(VoiceFile(BASE_VOICE[parsed.base]), VoiceFile(BASE_ACTION_VOICE[action][side]), parsed.base, BASE_GAP[parsed.base])
    local playerClass
    if playerName and sadb.flagToastsEnabled and sadb.flagToastsUseClassIcons ~= false then
        playerClass = self:GetPlayerClassByName(playerName)
    end
    if sadb.flagToastsEnabled then
        self:ShowFlagToast(playerName, playerClass, action, teamSide, BASE_TITLE[parsed.base][action][side], playerName or "")
    end
    if sadb.flagChatEnabled then
        self:SendBaseChatAlert(playerName, action, side, label)
    end
end

function FlagAlerts:ProcessFlagEvent(message, eventTeam)
    if not sadb.battlegroundAlertsEnabled then return end
    if type(message) ~= "string" then return end

    local startTime = debugprofilestop()

    SoundAlerter:Debug("FlagAlerts", "CHAT MESSAGE: %s", message)

    local mode = self.patternMode
    if mode ~= "flag" and string_byte(message, -1) == BANG then
        local parsed = self:ParsedBase(message)
        if parsed then
            self:ProcessBaseEvent(parsed, eventTeam)
            return
        end
    end
    if mode == "base" then
        SoundAlerter:Debug("FlagAlerts", "No pattern match - message ignored")
        return
    end

    local playerName, eventType, faction
    for _, entry in ipairs(self.flagPatterns) do
        local name = string_match(message, entry.pattern)
        if name then
            playerName, eventType, faction = name, entry.action, entry.faction
            break
        end
    end

    if not playerName or not eventType then
        SoundAlerter:Debug("FlagAlerts", "No pattern match - message ignored")
        return
    end

    local metrics = self.performanceMetrics
    local carrierTeam, mismatch = FlagAlerts.CarrierTeam(eventType, faction, eventTeam)
    if eventTeam then metrics.teamFromEvent = metrics.teamFromEvent + 1 end
    if mismatch then
        metrics.teamMismatch = metrics.teamMismatch + 1
        SoundAlerter:Debug("FlagAlerts", "Team mismatch: the %s flag and the %s chat event disagree, using the event: %s", faction, eventTeam, message)
    end
    local side = FlagAlerts.Side(carrierTeam, self:GetMyTeam())
    SoundAlerter:Debug("FlagAlerts", "CHAT PATTERN MATCHED - Player: %s | Event: %s | Flag: %s | Team: %s | Side: %s", playerName, eventType, faction or "N/A", carrierTeam or "UNKNOWN", side)

    if eventType == "PICKUP" and not sadb.flagPickupAudio then return end
    if eventType == "DROP" and not sadb.flagDropAudio then return end
    if eventType == "CAPTURE" and not sadb.flagCaptureAudio then return end
    if eventType == "RETURN" and not sadb.flagReturnAudio then return end

    if eventType ~= "CAPTURE" then
        if not self:ShouldProcessFlagEvent(playerName, eventType) then
            SoundAlerter:Debug("FlagAlerts", "Chat Dedupe: Ignoring duplicate %s for %s (aura already fired)", eventType, playerName)
            return
        end
    end

    if not self:PassesTeamFilter(playerName, side) then return end

    local playerClass = self:GetPlayerClassByName(playerName)

    if eventType == "PICKUP" then
        self.performanceMetrics.chatPickups = self.performanceMetrics.chatPickups + 1
    elseif eventType == "DROP" then
        self.performanceMetrics.chatDrops = self.performanceMetrics.chatDrops + 1
    elseif eventType == "CAPTURE" then
        self.performanceMetrics.chatCaptures = self.performanceMetrics.chatCaptures + 1
    elseif eventType == "RETURN" then
        self.performanceMetrics.chatReturns = self.performanceMetrics.chatReturns + 1
    end

    self:TriggerFlagAlert(playerName, playerClass, eventType, side)

    local elapsed = debugprofilestop() - startTime
    self.performanceMetrics.eventCount = self.performanceMetrics.eventCount + 1
    self.performanceMetrics.totalProcessingTime = self.performanceMetrics.totalProcessingTime + elapsed
    self.performanceMetrics.maxProcessingTime = math_max(self.performanceMetrics.maxProcessingTime, elapsed)

    if self.inCombat then
        self.performanceMetrics.eventsInCombat = self.performanceMetrics.eventsInCombat + 1
    else
        self.performanceMetrics.eventsOutOfCombat = self.performanceMetrics.eventsOutOfCombat + 1
    end

    local maxSamples = 100
    local times = self.performanceMetrics.processingTimes
    local idx = self.performanceMetrics.processingTimesIndex
    times[idx] = elapsed
    self.performanceMetrics.processingTimesIndex = (idx % maxSamples) + 1

    SoundAlerter:Debug("FlagAlerts", "%s %s (%s) processed in %.2fms%s", eventType, playerName, playerClass or "UNKNOWN", elapsed, self.inCombat and ", in combat" or "")
end

local function GetOptimalCacheSize()
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()

    if numRaid > 20 then
        return CACHE_SIZE_LARGE
    elseif numRaid > 0 then
        return CACHE_SIZE_MEDIUM
    elseif numParty > 0 then
        return CACHE_SIZE_SMALL
    else
        return CACHE_SIZE_SMALL
    end
end

local function LiveUnitLookup(unitToken)
    if not UnitExists(unitToken) then
        return nil, nil
    end
    local name, second = UnitName(unitToken)
    local _, class = UnitClass(unitToken)
    return Plain(name), Plain(class), Plain(second)
end

local function SameName(name, second, wanted, wantedMain)
    if type(name) ~= "string" then return false end
    local lowered = name:lower()
    if lowered == wanted or lowered == wantedMain then return true end
    return type(second) == "string" and second ~= "" and lowered .. " " .. second:lower() == wanted
end

local function ScanTokens(tokens, last, lookupFn, wanted, wantedMain)
    for index = 1, last do
        local name, unitClass, second = lookupFn(tokens[index])
        if SameName(name, second, wanted, wantedMain) then return unitClass, true end
    end
    return nil, false
end

local function ResolveClassFromUnits(playerName, numParty, numRaid, cache, cacheSize, maxCacheSize, lookupFn)
    local cached = cache[playerName]
    if cached then
        return cached.class, "hit"
    end

    local wanted = playerName:lower()
    local wantedMain = wanted:match("^[^%s%-]+") or wanted
    local class, found = ScanTokens(FIXED_TOKENS, #FIXED_TOKENS, lookupFn, wanted, wantedMain)
    if not found then class, found = ScanTokens(PARTY_TOKENS, math_min(numParty, 4) * 2, lookupFn, wanted, wantedMain) end
    if not found then class = ScanTokens(RAID_TOKENS, math_min(numRaid, MAX_RAID_SCAN) * 2, lookupFn, wanted, wantedMain) end

    local evictedName = nil
    if cacheSize >= maxCacheSize then
        local oldestName, oldestTime = nil, math_huge
        for name, data in pairs(cache) do
            if data.timestamp < oldestTime then
                oldestName, oldestTime = name, data.timestamp
            end
        end
        evictedName = oldestName
    end

    return class, "miss", evictedName
end

function FlagAlerts:GetPlayerClassByName(playerName)

    if sadb.persistentCacheEnabled and self.persistentCache[playerName] then
        local cached = self.persistentCache[playerName]
        cached.lastSeen = time()
        self.performanceMetrics.persistentCacheHits = self.performanceMetrics.persistentCacheHits + 1


        return cached.class
    end

    local scored = SA_Scoreboard.ClassFor(SoundAlerter.scoreboardClasses, playerName)
    if scored then return scored end

    self:CleanupCacheEntry(playerName)

    local class, outcome, evictedName = ResolveClassFromUnits(
        playerName,
        GetNumPartyMembers(),
        GetNumRaidMembers(),
        self.nameToClassCache,
        self.cacheSize,
        GetOptimalCacheSize(),
        LiveUnitLookup
    )

    if outcome == "hit" then
        self.nameToClassCache[playerName].timestamp = GetTime()
        self.performanceMetrics.cacheHits = self.performanceMetrics.cacheHits + 1
        return class
    end

    self.performanceMetrics.cacheMisses = self.performanceMetrics.cacheMisses + 1

    if evictedName then
        self.nameToClassCache[evictedName] = nil
        self.cacheSize = self.cacheSize - 1
        self.performanceMetrics.cacheEvictions = self.performanceMetrics.cacheEvictions + 1
    end

    self:CachePlayerClass(playerName, class or "UNKNOWN")
    return class
end

function FlagAlerts:CachePlayerClass(playerName, class)
    if not class then return end

    if class ~= "UNKNOWN" then
        self:SaveToPersistentCache(playerName, class)
    end

    if not self.nameToClassCache[playerName] then
        self.cacheSize = self.cacheSize + 1
    end

    self.nameToClassCache[playerName] = {
        class = class,
        timestamp = GetTime()
    }
end

function FlagAlerts:SaveToPersistentCache(playerName, class)
    if not sadb.persistentCacheEnabled then return end
    if not playerName or not class or class == "UNKNOWN" then return end

    local maxSize = sadb.persistentCacheMaxSize or PERSISTENT_CACHE_SIZE_DEFAULT

    if self.persistentCacheSize >= maxSize then
        local oldestName, oldestTime = nil, math_huge
        for name, data in pairs(self.persistentCache) do
            if data.lastSeen < oldestTime then
                oldestName, oldestTime = name, data.lastSeen
            end
        end
        if oldestName then
            self.persistentCache[oldestName] = nil
            self.persistentCacheSize = self.persistentCacheSize - 1
        end
    end

    if not self.persistentCache[playerName] then
        self.persistentCacheSize = self.persistentCacheSize + 1
    end
    self.persistentCache[playerName] = {
        class = class,
        lastSeen = time()
    }
end

function FlagAlerts:CleanupPersistentCache()
    SA_FlagCache.Prune(self.flagEventCache, GetTime(), self.FLAG_EVENT_DEDUPE_WINDOW)
    if not sadb.persistentCacheEnabled then return end

    local currentTime = time()
    local maxAge = sadb.persistentCacheMaxAge or 2592000

    local toDelete = {}
    for playerName, data in pairs(self.persistentCache) do
        data.lastSeen = SA_FlagCache.Normalize(data.lastSeen, currentTime)
        if currentTime - data.lastSeen > maxAge then
            table_insert(toDelete, playerName)
        end
    end

    for _, playerName in ipairs(toDelete) do
        self.persistentCache[playerName] = nil
        self.persistentCacheSize = self.persistentCacheSize - 1
    end

end

function FlagAlerts:GetPersistentCacheSize()
    return self.persistentCacheSize
end

function FlagAlerts:ClearPersistentCache()
    self.persistentCache = {}
    sadb.persistentClassCache = {}
    self.persistentCacheSize = 0
    SoundAlerter:Print("[FlagAlerts] Persistent class cache cleared")
end

function FlagAlerts:GetMyTeam()
    local team = self.myTeam
    if team then return team end
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then
        team = "ALLIANCE_TEAM"
    elseif faction == "Horde" then
        team = "HORDE_TEAM"
    end
    self.myTeam = team
    return team
end

function FlagAlerts:TriggerFlagAlert(playerName, playerClass, eventType, side)
    self:QueueAudio(playerClass, eventType, side)

    if sadb.flagToastsEnabled then
        self:ShowFlagToast(playerName, playerClass, eventType, side)
    end

    if sadb.flagChatEnabled then
        self:SendFlagChatAlert(playerName, playerClass, eventType)
    end

end

function FlagAlerts:QueueAudio(playerClass, eventType, side)
    local classAudioFile = playerClass and SoundAlerter.CLASS_AUDIO_MAP[playerClass]
    local lead
    if classAudioFile then
        lead = VoiceFile(classAudioFile)
    elseif side == "enemy" then
        lead = VoiceFile("Enemy")
    end
    self:QueueVoice(lead, VoiceFile(self:GetObjectiveAudioFile(eventType)), nil, OBJECTIVE_AUDIO_DELAY)
end

function FlagAlerts:QueueVoice(lead, objective, baseIndex, delay)
    local queue = self.audioQueue
    local slots = queue.slots
    local now = GetTime()
    if baseIndex then
        for offset = 0, queue.count - 1 do
            local item = slots[(queue.head + offset - 1) % QUEUE_CAPACITY + 1]
            if item.base == baseIndex then
                item.lead, item.objective, item.at, item.delay = lead, objective, now, delay
                return
            end
        end
    end
    if queue.count >= QUEUE_CAPACITY then
        local oldest = slots[queue.head]
        slots[queue.head] = nil
        queue.free[#queue.free + 1] = oldest
        queue.head = queue.head % QUEUE_CAPACITY + 1
        queue.count = queue.count - 1
    end
    local free = queue.free
    local item = free[#free]
    if item then free[#free] = nil else item = {} end
    item.lead, item.objective, item.base, item.at, item.delay = lead, objective, baseIndex, now, delay
    slots[(queue.head + queue.count - 1) % QUEUE_CAPACITY + 1] = item
    queue.count = queue.count + 1
    self:ProcessAudioQueue()
end

function FlagAlerts:ProcessAudioQueue()
    if self.audioInProgress then return end
    local queue = self.audioQueue
    local slots, free = queue.slots, queue.free
    local now = GetTime()
    local item
    while queue.count > 0 do
        local candidate = slots[queue.head]
        slots[queue.head] = nil
        queue.head = queue.head % QUEUE_CAPACITY + 1
        queue.count = queue.count - 1
        if now - candidate.at <= QUEUE_STALE then
            item = candidate
            break
        end
        free[#free + 1] = candidate
    end
    if not item then return end

    self.audioInProgress = true
    local lead, delay = item.lead, item.delay
    self.pendingObjective = item.objective
    item.lead, item.objective, item.base = nil, nil, nil
    free[#free + 1] = item

    if lead then
        PlayFlagVoice(lead, true)
        self.objectiveCounted = false
        self:ScheduleTimer("PlayObjective", delay or OBJECTIVE_AUDIO_DELAY)
    else
        self.objectiveCounted = true
        self:PlayObjective()
    end
end

function FlagAlerts:PlayObjective()
    local objective = self.pendingObjective
    self.pendingObjective = nil
    if objective then PlayFlagVoice(objective, self.objectiveCounted) end
    self.objectiveCounted = false
    self:ScheduleTimer("AdvanceQueue", OBJECTIVE_GAP)
end

function FlagAlerts:AdvanceQueue()
    self.audioInProgress = false
    self:ProcessAudioQueue()
end

local PREVIEW_SPACING = 3.5

function FlagAlerts:Preview(eventType, class)
    local classAudioFile = SoundAlerter.CLASS_AUDIO_MAP[class or "ROGUE"] or "Enemy"
    SoundAlerter:PlayVoice(sadb.sapath .. classAudioFile .. ".mp3", "Master")
    local objectiveFile = self:GetObjectiveAudioFile(eventType)
    self:ScheduleTimer(function()
        SoundAlerter:PlayVoice(sadb.sapath .. objectiveFile .. ".mp3", "Master")
    end, OBJECTIVE_AUDIO_DELAY)
end

function FlagAlerts:PreviewBase(action)
    SoundAlerter:PlayVoice(self:VoicePath(BASE_VOICE[1]), "Master")
    self.previewObjective = self:VoicePath(BASE_ACTION_VOICE[action].enemy)
    self:ScheduleTimer("PlayPreviewObjective", BASE_GAP[1])
end

function FlagAlerts:PlayPreviewObjective()
    if self.previewObjective then SoundAlerter:PlayVoice(self.previewObjective, "Master") end
    self.previewObjective = nil
end

function FlagAlerts:PreviewAll(class)
    for index, eventType in ipairs({ "PICKUP", "DROP", "CAPTURE", "RETURN" }) do
        if index == 1 then
            self:Preview(eventType, class)
        else
            self:ScheduleTimer(function() self:Preview(eventType, class) end, (index - 1) * PREVIEW_SPACING)
        end
    end
end

function FlagAlerts:GetObjectiveAudioFile(eventType)
    if eventType == "PICKUP" then return "FlagPickup" end
    if eventType == "DROP" then return "FlagDropped" end
    if eventType == "CAPTURE" then return "FlagCaptured" end
    if eventType == "RETURN" then return "FlagReturned" end
    return "FlagPickup"
end

function FlagAlerts:SendFlagChatAlert(playerName, playerClass, eventType)
    local key = FLAG_CHAT_KEY[eventType]
    local template = key and sadb[key]
    if not SA_AlertText.Ready(template, "battleground") then return end
    local values = chatValues
    values.class = playerClass and CLASS_NAMES[playerClass] or playerClass or ""
    values.player = SanitizeMacroText(playerName)
    values.action = FLAG_ACTION_TEXT[eventType]
    values.base, values.outcome = "", ""
    SA_AlertText.Say(template, values, "battleground", true)
end

function FlagAlerts:SendBaseChatAlert(playerName, action, side, label)
    local template = sadb[BASE_CHAT_KEY[action]]
    if not SA_AlertText.Ready(template, "battleground") then return end
    local values = chatValues
    values.class, values.action = "", ""
    values.player = SanitizeMacroText(playerName)
    values.base = label
    values.outcome = BASE_CHAT_OUTCOME[action][side]
    SA_AlertText.Say(template, values, "battleground", true)
end

function FlagAlerts:CleanupCacheEntry(playerName)
    local cached = self.nameToClassCache[playerName]
    if cached and (GetTime() - cached.timestamp > CACHE_TTL) then
        self.nameToClassCache[playerName] = nil
        self.cacheSize = self.cacheSize - 1
        return true
    end
    return false
end

local function CalculatePercentile(sortedArray, percentile)
    if #sortedArray == 0 then return 0 end
    local index = math_ceil(#sortedArray * percentile)
    return sortedArray[index]
end

function FlagAlerts:PrintMetrics()
    if self.performanceMetrics.eventCount == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700=== Battleground Alerts - Performance Metrics ===|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF6B6BNo events processed yet|r")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff808080Tip: Enable Battleground Alerts and join a battleground to collect metrics|r")
        return
    end

    local avgTime = self.performanceMetrics.totalProcessingTime / self.performanceMetrics.eventCount
    local totalLookups = self.performanceMetrics.cacheHits + self.performanceMetrics.cacheMisses
    local cacheHitRate = totalLookups > 0 and
        (self.performanceMetrics.cacheHits / totalLookups) * 100 or 0

    local times = {}
    for _, time in pairs(self.performanceMetrics.processingTimes) do
        table_insert(times, time)
    end
    table_sort(times)

    local p50 = CalculatePercentile(times, 0.50)
    local p95 = CalculatePercentile(times, 0.95)
    local p99 = CalculatePercentile(times, 0.99)

    local statusColor = "|cff00FF00"
    local statusText = "Excellent"
    if p99 > 10 then
        statusColor = "|cffFF6B6B"
        statusText = "Poor"
    elseif p99 > 5 then
        statusColor = "|cffFFAA00"
        statusText = "Fair"
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700=== Battleground Alerts - Performance Metrics ===|r")
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Event Processing]|r")
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Events Processed: |cffFFFFFF%d|r", self.performanceMetrics.eventCount))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Performance Status: %s%s|r", statusColor, statusText))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Processing Time]|r")
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Average: |cffFFFFFF%.2fms|r", avgTime))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  P50 (Median): |cffFFFFFF%.2fms|r", p50))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  P95: |cffFFFFFF%.2fms|r", p95))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  P99: |cffFFFFFF%.2fms|r", p99))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Max: |cffFFFFFF%.2fms|r", self.performanceMetrics.maxProcessingTime))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Temporary Cache (60s TTL)]|r")
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Cache Hits: |cff00FF00%d|r", self.performanceMetrics.cacheHits))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Cache Misses: |cffFFAA00%d|r", self.performanceMetrics.cacheMisses))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Hit Rate: |cffFFFFFF%.1f%%|r", cacheHitRate))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Evictions: |cffFFFFFF%d|r", self.performanceMetrics.cacheEvictions))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Current Size: |cffFFFFFF%d / %d|r entries (dynamic)", self:GetCacheSize(), GetOptimalCacheSize()))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Persistent Cache (Disk-Saved)]|r")
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Persistent Hits: |cff00FF00%d|r", self.performanceMetrics.persistentCacheHits))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Classes Learned: |cff00FF00%d|r (from combat)", self.performanceMetrics.classesLearned))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Total Cached Players: |cffFFFFFF%d / %d|r", self:GetPersistentCacheSize(), sadb.persistentCacheMaxSize or PERSISTENT_CACHE_SIZE_DEFAULT))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Status: %s", sadb.persistentCacheEnabled and "|cff00FF00Enabled|r" or "|cffFF6B6BDisabled|r"))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Team Assignment]|r")
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  My Team: %s", self:GetMyTeam() or "|cffFF6B6BUnknown|r"))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Events Filtered by Team: |cffFFAA00%d|r", self.performanceMetrics.teamFiltered))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Combat-Aware Taint Protection]|r")
    local combatStatus = self.inCombat and "|cffFF6B6BIn Combat|r" or "|cff00FF00Out of Combat|r"
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Current State: %s", combatStatus))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Events Processed (Combat): |cffFFAA00%d|r", self.performanceMetrics.eventsInCombat))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Events Processed (Non-Combat): |cff00FF00%d|r", self.performanceMetrics.eventsOutOfCombat))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Chat Alerts Suppressed: |cffFF6B6B%d|r (taint prevention)", self.performanceMetrics.chatAlertsSuppressed))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Detection Method Breakdown]|r")
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Pickups: |cffFFAA00%d|r", self.performanceMetrics.chatPickups))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Drops: |cffFFAA00%d|r", self.performanceMetrics.chatDrops))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Captures: |cff00FFFF%d|r", self.performanceMetrics.chatCaptures))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Deduped Events: |cff808080%d|r (prevented double alerts)", self.performanceMetrics.dedupeBlocked))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Team from the chat event: |cff00FF00%d|r", self.performanceMetrics.teamFromEvent))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Flag and event disagreed: |cffFF6B6B%d|r (the event wins; should stay 0)", self.performanceMetrics.teamMismatch))
end

function FlagAlerts:GetCacheSize()
    return self.cacheSize
end

function FlagAlerts:ResetMetrics()
    self.performanceMetrics = {
        eventCount = 0,
        totalProcessingTime = 0,
        cacheHits = 0,
        cacheMisses = 0,
        persistentCacheHits = 0,
        maxProcessingTime = 0,
        processingTimes = {},
        processingTimesIndex = 1,
        cacheEvictions = 0,
        classesLearned = 0,
        teamFiltered = 0,
        teamFromEvent = 0,
        teamMismatch = 0,
        chatPickups = 0,
        chatDrops = 0,
        chatCaptures = 0,
        chatReturns = 0,
        dedupeBlocked = 0,

        eventsInCombat = 0,
        eventsOutOfCombat = 0,
        chatAlertsSuppressed = 0,
    }
    SoundAlerter:Print("[FlagAlerts] Performance metrics reset")
end

local SA_DEBUG_GATE_NOTE = "Debug mode is off — enable it in /sa options to use developer/testing commands."

function SoundAlerter.FlagAlerts:HandleCommand(msg)
    if msg == "metrics" then
        self:PrintMetrics()
    elseif msg == "cache" then
        local tempSize = self:GetCacheSize()
        local persistSize = self:GetPersistentCacheSize()
        SoundAlerter:Print(string_format("[FlagAlerts] Temporary cache: %d entries | Persistent cache: %d players",
            tempSize, persistSize))
    elseif msg == "cache persist" then
        local persistSize = self:GetPersistentCacheSize()
        SoundAlerter:Print(string_format("[FlagAlerts] Persistent cache: %d players (saved to disk)",
            persistSize))
    elseif msg == "clearcache" then
        self:ClearPersistentCache()
    elseif msg == "myteam" then
        local myTeam = self:GetMyTeam()
        SoundAlerter:Print(string_format("[FlagAlerts] My team: %s", myTeam or "Unknown (not in a battleground)"))
    elseif msg == "test" then
        if not sadb.debugmode then
            SoundAlerter:Print(SA_DEBUG_GATE_NOTE)
            return
        end
        self:ProcessFlagEvent("Testplayer has taken the flag!")
        SoundAlerter:Print("[FlagAlerts] Test event triggered")
    elseif msg:match("^testtoast%s*(.*)") then
        if not sadb.debugmode then
            SoundAlerter:Print(SA_DEBUG_GATE_NOTE)
            return
        end
        local eventType = msg:match("^testtoast%s+(.+)") or "pickup"
        eventType = eventType:upper()

        if eventType ~= "PICKUP" and eventType ~= "DROP" and eventType ~= "CAPTURE" and eventType ~= "RETURN" then
            eventType = "PICKUP"
        end

        self:ShowFlagToast("TestPlayer", "ROGUE", eventType, "HORDE_TEAM")
        SoundAlerter:Print(string_format("[FlagAlerts] Test toast shown: %s", eventType))
    elseif msg == "toastmetrics" then
        local m = self.flagToastMetrics
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700=== Flag Toast Metrics ===|r")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Toast Activity]|r")
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Total Toasts: |cffFFFFFF%d|r", m.toastsShown))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Pickups: |cff00FF00%d|r", m.pickupToasts))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Drops: |cffFFAA00%d|r", m.dropToasts))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Captures: |cff00FFFF%d|r", m.captureToasts))
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Pool Utilization]|r")
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Active Toasts: |cffFFFFFF%d / %d|r", #engine.active, MAX_FLAG_TOASTS))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Pool Exhaustions: |cffFF6B6B%d|r", m.poolExhaustions))
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Combat State]|r")
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  In Combat: |cffFF6B6B%d|r (insecure pool)", m.toastsInCombat))
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Out of Combat: |cff00FF00%d|r (secure pool)", m.toastsOutOfCombat))
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Frame Swaps]|r")
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Swaps: |cffFFFFFF%d|r", m.toastsSwapped))
        if m.toastsSwapped > 0 then
            local avgSwap = m.swapTime / m.toastsSwapped
            DEFAULT_CHAT_FRAME:AddMessage(string_format("  Avg Time: |cffFFFFFF%.2fms|r", avgSwap))
            DEFAULT_CHAT_FRAME:AddMessage(string_format("  Max Time: |cffFFFFFF%.2fms|r", m.maxSwapTime))
        else
            DEFAULT_CHAT_FRAME:AddMessage("  No swaps yet")
        end
    elseif msg == "cleartoasts" then
        engine:ReleaseAll()
        SoundAlerter:Print("[FlagAlerts] All active flag toasts cleared")
    elseif msg == "reset" then
        if not sadb.debugmode then
            SoundAlerter:Print(SA_DEBUG_GATE_NOTE)
            return
        end
        self:ResetMetrics()
    else
        self:PrintHelp()
    end
end

function SoundAlerter.FlagAlerts:PrintHelp()
    SoundAlerter:Print("|cff00FFFF[Battleground Flags]|r")
    SoundAlerter:Print("  |cffFFFFFF/sa flag myteam|r - Show your current team assignment")
    SoundAlerter:Print("  |cffFFFFFF/sa flag metrics|r - Show performance metrics")
    SoundAlerter:Print("  |cffFFFFFF/sa flag toastmetrics|r - Show flag toast metrics")
    SoundAlerter:Print("  |cffFFFFFF/sa flag cache [persist]|r - Show cache sizes (both, or persistent only)")
    SoundAlerter:Print("  |cffFFFFFF/sa flag clearcache|r - Clear persistent cache")
    SoundAlerter:Print("  |cffFFFFFF/sa flag cleartoasts|r - Clear all active flag toasts")
    if sadb.debugmode then
        SoundAlerter:Print("  |cffFFFFFF/sa flag test|r - [debug] Test flag pickup event")
        SoundAlerter:Print("  |cffFFFFFF/sa flag testtoast [pickup|drop|capture]|r - [debug] Test flag toast")
        SoundAlerter:Print("  |cffFFFFFF/sa flag reset|r - [debug] Reset performance metrics")
    else
        SoundAlerter:Print("  |cffAAAAAA3 developer commands hidden — enable debug mode in /sa options to see them.|r")
    end
end

local FLAG_TOAST_WIDTH = 300
local FLAG_TOAST_HEIGHT = 72
local FLAG_VERTICAL_SPACING = 8
local FLAG_DISPLAY_DURATION = 5.0

local FLAG_ICONS = {
    ALLIANCE_FLAG = "Interface\\WorldStateFrame\\AllianceFlag",
    HORDE_FLAG = "Interface\\WorldStateFrame\\HordeFlag",
    NEUTRAL_FLAG = "Interface\\WorldStateFrame\\NeutralFlag",
}

local OWN_FLAG = { ALLIANCE_TEAM = FLAG_ICONS.ALLIANCE_FLAG, HORDE_TEAM = FLAG_ICONS.HORDE_FLAG }
local OTHER_FLAG = { ALLIANCE_TEAM = FLAG_ICONS.HORDE_FLAG, HORDE_TEAM = FLAG_ICONS.ALLIANCE_FLAG }

function FlagAlerts:FlagIcon(eventType, side)
    local myTeam = self:GetMyTeam()
    if not myTeam or side == "unknown" then return FLAG_ICONS.NEUTRAL_FLAG end
    local returned = eventType == "RETURN"
    if (side == "friendly") ~= returned then return OTHER_FLAG[myTeam] end
    return OWN_FLAG[myTeam]
end

function FlagAlerts:ResolveToastAppearance(side)
    local sadb = SoundAlerter.db1.profile
    local textures = SoundAlerter.BarUtils.BACKDROP_TEXTURES
    local isEnemy, isFriendly = side == "enemy", side == "friendly"

    local bgR, bgG, bgB, bgA = 0, 0, 0, 0.85
    local borderR, borderG, borderB, borderA = 0.8, 0.2, 0.2, 1
    local textureName = "Solid"

    if sadb.flagTeamBackgroundColors then
        if isEnemy then
            if sadb.flagEnemyRedBackground then
                bgR, bgG, bgB, bgA = 0.4, 0.05, 0.05, 0.85
                borderR, borderG, borderB, borderA = 0.8, 0.1, 0.1, 1
            end
            textureName = sadb.flagEnemyTexture or "Solid"
        elseif isFriendly then
            if sadb.flagFriendlyGreenBackground then
                bgR, bgG, bgB, bgA = 0.05, 0.4, 0.05, 0.85
                borderR, borderG, borderB, borderA = 0.1, 0.8, 0.1, 1
            end
            textureName = sadb.flagFriendlyTexture or "Solid"
        else
            borderR, borderG, borderB = 0.55, 0.58, 0.64
        end
    end

    local bgFile = textures[textureName] or textures.Solid
    return bgFile, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA
end

local function ArmSecureButton(button, unitName)
    local macroText = SA_ToastClick.TargetMacro(unitName)
    button:SetAttribute("macrotext1", macroText)
    button:SetAttribute("macrotext", macroText)
    button:SetAlpha(1)
    button:Show()
end

local function CopyContent(oldFrame, newFrame)
    newFrame.icon:SetTexture(oldFrame.icon:GetTexture())
    newFrame.titleText:SetText(oldFrame.titleText:GetText() or "")
    newFrame.detailText:SetText(oldFrame.detailText:GetText() or "")

    newFrame:SetAlpha(oldFrame:GetAlpha())

    if newFrame.secureButton and not InCombatLockdown() then
        local unitName = newFrame.userData.unitName
        if unitName then
            ArmSecureButton(newFrame.secureButton, unitName)
            newFrame.secureButton:SetAlpha(newFrame:GetAlpha())
        end
    end
end

local function CurrentPosition()
    local flagToasts = SoundAlerter.db1.profile.flagToasts
    return (flagToasts and flagToasts.positionX) or 0, (flagToasts and flagToasts.positionY) or -300
end

local function CanDismissOnClick()
    return SoundAlerter.db1.profile.flagToastsEnabled
end

local function TickBorder(toast, now)
    if SoundAlerter.ProximityToasts and SoundAlerter.ProximityToasts:GetSettings().rainbowBorder then
        local r, g, b = SA_Toast.RainbowColor(now)
        toast:SetBackdropBorderColor(r, g, b, 1)
    end
end

local function CountPoolExhaustion()
    FlagAlerts.flagToastMetrics.poolExhaustions = FlagAlerts.flagToastMetrics.poolExhaustions + 1
    SoundAlerter:Debug("FlagAlerts", "Pool exhausted, evicted oldest toast")
end

engine = SA_Toast.New({
    label = "FlagAlerts",
    prefix = "SoundAlerterFlag",
    swapLabel = "FlagAlerts",
    swapBudgetMs = 4.0,
    maxToasts = MAX_FLAG_TOASTS,
    width = FLAG_TOAST_WIDTH,
    height = FLAG_TOAST_HEIGHT,
    spacing = FLAG_VERTICAL_SPACING,
    slide = false,
    manageMouse = true,
    mirrorSecureAlpha = true,
    secureAttributes = {"macrotext1", "macrotext"},
    userFields = {"unitName", "className", "eventType", "side", "timestamp"},
    backdropFile = function() return SoundAlerter.BarUtils.BACKDROP_TEXTURES.Solid end,
    segmentWidth = function(toast, duration) return toast.countdownBar:GetWidth() / duration end,
    position = CurrentPosition,
    canDismissOnClick = CanDismissOnClick,
    tickBorder = TickBorder,
    copyContent = CopyContent,
    onExhausted = CountPoolExhaustion,
})
FlagAlerts.engine = engine

function FlagAlerts:UpdateFlagToastLayout()
    engine:UpdateLayout()
end

function FlagAlerts:ShowFlagToast(playerName, playerClass, eventType, side, titleOverride, detailOverride)
    local sadb = SoundAlerter.db1.profile

    local toast = engine:Acquire(self.inCombat)
    if not toast then
        SoundAlerter:Debug("FlagAlerts", "Failed to acquire toast frame")
        return
    end

    local bgFile, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA = self:ResolveToastAppearance(side)
    toast:SetBackdrop({
        bgFile = bgFile,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    toast:SetBackdropColor(bgR, bgG, bgB, bgA)
    toast:SetBackdropBorderColor(borderR, borderG, borderB, borderA)

    local useClassIcons = sadb.flagToastsUseClassIcons ~= false
    if useClassIcons and playerClass then
        local classIconPath = "Interface\\Icons\\ClassIcon_" .. playerClass
        toast.icon:SetTexture(classIconPath)
    else
        toast.icon:SetTexture(titleOverride and FLAG_ICONS.NEUTRAL_FLAG or self:FlagIcon(eventType, side))
    end
    toast.icon:Show()

    local titleText
    if titleOverride then
        titleText = titleOverride
    elseif eventType == "PICKUP" then
        titleText = "FLAG CARRIER!"
    elseif eventType == "DROP" then
        titleText = "FLAG DROPPED!"
    elseif eventType == "CAPTURE" then
        titleText = "FLAG CAPTURED!"
    elseif eventType == "RETURN" then
        titleText = "FLAG RETURNED!"
    else
        titleText = "FLAG EVENT"
    end
    toast.titleText:SetText(titleText)

    local detailText = detailOverride or playerName
    if not detailOverride and playerClass and playerClass ~= "UNKNOWN" then
        detailText = playerClass .. " - " .. playerName
    end
    toast.detailText:SetText(detailText)

    toast.userData.unitName = playerName
    toast.userData.className = playerClass
    toast.userData.eventType = eventType
    toast.userData.side = side
    toast.userData.timestamp = GetTime()

    if toast.secureButton and playerName and not InCombatLockdown() then
        ArmSecureButton(toast.secureButton, playerName)
    end

    engine:Start(toast, sadb.flagToastDisplayDuration or FLAG_DISPLAY_DURATION, {borderR, borderG, borderB, borderA})

    self.flagToastMetrics.toastsShown = self.flagToastMetrics.toastsShown + 1

    if self.inCombat then
        self.flagToastMetrics.toastsInCombat = self.flagToastMetrics.toastsInCombat + 1
    else
        self.flagToastMetrics.toastsOutOfCombat = self.flagToastMetrics.toastsOutOfCombat + 1
    end

    if eventType == "PICKUP" then
        self.flagToastMetrics.pickupToasts = self.flagToastMetrics.pickupToasts + 1
    elseif eventType == "DROP" then
        self.flagToastMetrics.dropToasts = self.flagToastMetrics.dropToasts + 1
    elseif eventType == "CAPTURE" then
        self.flagToastMetrics.captureToasts = self.flagToastMetrics.captureToasts + 1
    end

    SoundAlerter:Debug("FlagAlerts", "toast shown: %s (%s) %s, %s pool, %d/%d active", playerName, playerClass or "Unknown", eventType, self.inCombat and "insecure" or "secure", #engine.active, MAX_FLAG_TOASTS)
end

SA_Modules.Register({ key = "FlagAlerts", module = FlagAlerts, flat = FLAT_SETTINGS, title = "Battlegrounds", enabled = { "battlegroundAlertsEnabled" }, start = StartedByAce, profile = SwitchProfile })
