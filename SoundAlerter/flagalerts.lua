
local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
local FlagAlerts = SoundAlerter:NewModule("FlagAlerts", "AceEvent-3.0", "AceTimer-3.0")

SoundAlerter.FlagAlerts = FlagAlerts

local sadb
local GetLocale = GetLocale
local GetTime = GetTime
local PlaySoundFile = PlaySoundFile
local UnitExists = UnitExists
local UnitName = UnitName
local UnitClass = UnitClass
local GetNumRaidMembers = SA_COMPAT.GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers
local SendChatMessage = SendChatMessage
local debugprofilestop = debugprofilestop

local string_match = string.match
local string_gsub = string.gsub
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local math_max = math.max
local math_ceil = math.ceil
local math_huge = math.huge
local math_floor = math.floor
local math_sin = math.sin
local math_pi = math.pi
local tonumber = tonumber
local type = type
local pairs = pairs
local ipairs = ipairs

local bit_band = bit and bit.band or function(a, b) return a % (b*2) >= b and a % (b*2) - b or a % (b*2) end
local bit_rshift = bit and bit.rshift or function(a, b) return math.floor(a / (2^b)) end

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

local FLAG_CARRIER_AURAS = {
    [23333] = "ALLIANCE_TEAM",
    [23335] = "HORDE_TEAM",
}

local RELEVANT_COMBAT_EVENTS = {
    ["SWING_DAMAGE"] = true,
    ["RANGE_DAMAGE"] = true,
    ["SPELL_DAMAGE"] = true,
    ["SPELL_PERIODIC_DAMAGE"] = true,
    ["DAMAGE_SHIELD"] = true,
    ["DAMAGE_SPLIT"] = true,
    ["SPELL_HEAL"] = true,
    ["SPELL_PERIODIC_HEAL"] = true,
    ["SPELL_CAST_START"] = true,
    ["SPELL_CAST_SUCCESS"] = true,
    ["SPELL_AURA_APPLIED"] = true,
    ["SPELL_AURA_REMOVED"] = true,
}

local LOCALE_PATTERNS = {
    ["enUS"] = {
        { pattern = "^(.+) has taken the flag!$", action = "PICKUP" },
        { pattern = "^The ([Hh]orde) [Ff]lag was picked up by (.+)!$", action = "PICKUP", flagName = "Horde" },
        { pattern = "^The ([Aa]lliance) [Ff]lag was picked up by (.+)!$", action = "PICKUP", flagName = "Alliance" },
        { pattern = "^(.+) has dropped the flag!$", action = "DROP" },
        { pattern = "^The ([Hh]orde) [Ff]lag was dropped by (.+)!$", action = "DROP", flagName = "Horde" },
        { pattern = "^The ([Aa]lliance) [Ff]lag was dropped by (.+)!$", action = "DROP", flagName = "Alliance" },
        { pattern = "^(.+) captured the (.+) flag!$", action = "CAPTURE" },
        { pattern = "^The .+ [Ff]lag was captured by (.+)!$", action = "CAPTURE" },
    },
    ["enGB"] = {
        { pattern = "^(.+) has taken the flag!$", action = "PICKUP" },
        { pattern = "^The ([Hh]orde) [Ff]lag was picked up by (.+)!$", action = "PICKUP", flagName = "Horde" },
        { pattern = "^The ([Aa]lliance) [Ff]lag was picked up by (.+)!$", action = "PICKUP", flagName = "Alliance" },
        { pattern = "^(.+) has dropped the flag!$", action = "DROP" },
        { pattern = "^The ([Hh]orde) [Ff]lag was dropped by (.+)!$", action = "DROP", flagName = "Horde" },
        { pattern = "^The ([Aa]lliance) [Ff]lag was dropped by (.+)!$", action = "DROP", flagName = "Alliance" },
        { pattern = "^(.+) captured the (.+) flag!$", action = "CAPTURE" },
        { pattern = "^The .+ [Ff]lag was captured by (.+)!$", action = "CAPTURE" },
    },
}

function FlagAlerts:OnInitialize()
    sadb = SoundAlerter.db1.profile

    self.inCombat = false
    self.combatAwareOperations = 0

    self.nameToClassCache = {}
    self.cacheSize = 0
    self.audioQueue = {}
    self.audioInProgress = false

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
        auraPickups = 0,
        auraDrops = 0,
        chatPickups = 0,
        chatDrops = 0,
        chatCaptures = 0,
        dedupeBlocked = 0,

        eventsInCombat = 0,
        eventsOutOfCombat = 0,
        chatAlertsSuppressed = 0,
    }

    self.flagSecureToastPool = {}
    self.flagInsecureToastPool = {}
    self.activeFlagToasts = {}
    self.flagSwapInProgress = false
    self.flagInsecureSwapBuffer = {}

    self.flagSwapMetrics = {count = 0, totalTime = 0, maxTime = 0, histogram = {}}
    self.flagPoolState = {
        securePool = self.flagSecureToastPool,
        insecurePool = self.flagInsecureToastPool,
        activeList = self.activeFlagToasts,
        poolSize = MAX_FLAG_TOASTS,
        swapInProgress = false,
        swapBuffer = self.flagInsecureSwapBuffer,
        metrics = self.flagSwapMetrics,
        onLayoutChanged = function() self:UpdateFlagToastLayout() end,
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
    self.flagPatterns = LOCALE_PATTERNS[locale] or LOCALE_PATTERNS["enUS"]

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts] Initialized with locale: %s | Persistent cache: %d players",
            locale, self.persistentCacheSize))
    end
end

function FlagAlerts:OnEnable()
    self:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
    self:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
    self:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")

    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")

    self:InitializeFlagToastPools()

    self:ScheduleRepeatingTimer("CleanupPersistentCache", 300)

    if sadb.debugmode then
        SoundAlerter:Print("[FlagAlerts] Enabled and listening for battleground events")
        SoundAlerter:Print("[FlagAlerts] Primary detection: Flag carrier auras (23333, 23335)")
        SoundAlerter:Print("[FlagAlerts] Fallback detection: Chat messages")
        SoundAlerter:Print("[FlagAlerts] Combat-aware taint protection: Enabled")
    end
end

function FlagAlerts:OnDisable()
    self:UnregisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
    self:UnregisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
    self:UnregisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:CancelAllTimers()

    if sadb.debugmode then
        SoundAlerter:Print("[FlagAlerts] Disabled")
    end
end

function FlagAlerts:OnProfileChanged()
    sadb = SoundAlerter.db1.profile

    self.persistentCache = sadb.persistentClassCache

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts] Profile changed - Battleground Alerts %s",
            sadb.battlegroundAlertsEnabled and "ENABLED" or "DISABLED"))
    end
end

function FlagAlerts:CHAT_MSG_BG_SYSTEM_ALLIANCE(event, message, ...)
    self:ProcessFlagEvent(message)
end

function FlagAlerts:CHAT_MSG_BG_SYSTEM_HORDE(event, message, ...)
    self:ProcessFlagEvent(message)
end

function FlagAlerts:CHAT_MSG_BG_SYSTEM_NEUTRAL(event, message, ...)
    self:ProcessFlagEvent(message)
end

function FlagAlerts:PLAYER_REGEN_DISABLED()
    self.inCombat = true

    if sadb.debugmode then
        SoundAlerter:Print("[FlagAlerts] Entered combat - chat alerts will be suppressed to prevent taint")
    end
end

function FlagAlerts:PLAYER_REGEN_ENABLED()
    self.inCombat = false

    if sadb.flagToastsEnabled then
        if self.flagSecureCreationPending then
            self:CreateSecureFlagToastPool()
        end

        self:SwapInsecureToSecureFlagFrames()
    end

    if sadb.debugmode then
        SoundAlerter:Print("[FlagAlerts] Left combat - all features restored")
    end
end

function FlagAlerts:COMBAT_LOG_EVENT_UNFILTERED()
    if not sadb.battlegroundAlertsEnabled then return end

    local _, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags = CombatLogGetCurrentEventInfo()

    if not RELEVANT_COMBAT_EVENTS[subevent] then
        return
    end

    if subevent == "SPELL_AURA_APPLIED" then
        local spellID = select(12, CombatLogGetCurrentEventInfo())

        if sadb.debugmode then
            SoundAlerter:Print(string_format("[FlagAlerts DEBUG] SPELL_AURA_APPLIED - SpellID: %d | Dest: %s | GUID: %s",
                spellID or 0, destName or "nil", destGUID or "nil"))
        end

        local carrierTeam = FLAG_CARRIER_AURAS[spellID]
        if carrierTeam and destName then
            if sadb.debugmode then
                SoundAlerter:Print(string_format("[FlagAlerts DEBUG] FLAG PICKUP DETECTED - SpellID: %d | Player: %s | Team: %s",
                    spellID, destName, carrierTeam))
            end
            local ok, err = pcall(self.HandleFlagPickup, self, destName, destGUID, carrierTeam)
            if not ok and sadb.debugmode then
                SoundAlerter:Print("[FlagAlerts] HandleFlagPickup error: "..tostring(err))
            end
            return
        end
    end

    if subevent == "SPELL_AURA_REMOVED" then
        local spellID = select(12, CombatLogGetCurrentEventInfo())

        if sadb.debugmode then
            SoundAlerter:Print(string_format("[FlagAlerts DEBUG] SPELL_AURA_REMOVED - SpellID: %d | Dest: %s | GUID: %s",
                spellID or 0, destName or "nil", destGUID or "nil"))
        end

        local carrierTeam = FLAG_CARRIER_AURAS[spellID]
        if carrierTeam and destName then
            if sadb.debugmode then
                SoundAlerter:Print(string_format("[FlagAlerts DEBUG] FLAG DROP DETECTED - SpellID: %d | Player: %s | Team: %s",
                    spellID, destName, carrierTeam))
            end
            local ok, err = pcall(self.HandleFlagDrop, self, destName, destGUID, carrierTeam)
            if not ok and sadb.debugmode then
                SoundAlerter:Print("[FlagAlerts] HandleFlagDrop error: "..tostring(err))
            end
            return
        end
    end

    if sourceName and sourceGUID then
        local isPlayer = bit_band(sourceFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
        if isPlayer then
            pcall(self.LearnPlayerClassFromGUID, self, sourceName, sourceGUID)
        end
    end

    if destName and destGUID then
        local isPlayer = bit_band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
        if isPlayer then
            pcall(self.LearnPlayerClassFromGUID, self, destName, destGUID)
        end
    end
end

function FlagAlerts:HandleFlagPickup(playerName, guid, carrierTeam)
    if not sadb.flagPickupAudio then return end

    if not self:ShouldProcessFlagEvent(playerName, "PICKUP") then
        if sadb.debugmode then
            SoundAlerter:Print(string_format("[FlagAlerts] Dedupe: Ignoring duplicate pickup for %s", playerName))
        end
        return
    end

    local playerClass = self:ExtractClassFromGUID(guid)

    if playerClass and playerClass ~= "UNKNOWN" then
        self:SaveToPersistentCache(playerName, playerClass)
    end

    if not self:PassesTeamFilter(playerName, carrierTeam) then return end

    self:TriggerFlagAlert(playerName, playerClass, "PICKUP", carrierTeam)

    self.performanceMetrics.auraPickups = self.performanceMetrics.auraPickups + 1

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts] Aura Detection: %s (%s, %s) picked up flag",
            playerName, playerClass or "UNKNOWN", carrierTeam or "UNKNOWN_TEAM"))
    end
end

function FlagAlerts:HandleFlagDrop(playerName, guid, carrierTeam)
    if not sadb.flagDropAudio then return end

    if not self:ShouldProcessFlagEvent(playerName, "DROP") then
        if sadb.debugmode then
            SoundAlerter:Print(string_format("[FlagAlerts] Dedupe: Ignoring duplicate drop for %s", playerName))
        end
        return
    end

    local playerClass = self:ExtractClassFromGUID(guid)

    if playerClass and playerClass ~= "UNKNOWN" then
        self:SaveToPersistentCache(playerName, playerClass)
    end

    if not self:PassesTeamFilter(playerName, carrierTeam) then return end

    self:TriggerFlagAlert(playerName, playerClass, "DROP", carrierTeam)

    self.performanceMetrics.auraDrops = self.performanceMetrics.auraDrops + 1

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts] Aura Detection: %s (%s, %s) dropped flag",
            playerName, playerClass or "UNKNOWN", carrierTeam or "UNKNOWN_TEAM"))
    end
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

function FlagAlerts:PassesTeamFilter(playerName, playerTeam)

    if sadb.flagOnlyEnemyTeam or sadb.flagOnlyFriendlyTeam then
        local myTeam = self:GetMyTeam()

        if playerTeam and myTeam then
            local isEnemy = (playerTeam ~= myTeam)
            local isFriendly = (playerTeam == myTeam)

            if sadb.flagOnlyEnemyTeam and isFriendly then
                self.performanceMetrics.teamFiltered = self.performanceMetrics.teamFiltered + 1
                if sadb.debugmode then
                    SoundAlerter:Print(string_format("[FlagAlerts] Filtered friendly team event: %s", playerName))
                end
                return false
            end

            if sadb.flagOnlyFriendlyTeam and isEnemy then
                self.performanceMetrics.teamFiltered = self.performanceMetrics.teamFiltered + 1
                if sadb.debugmode then
                    SoundAlerter:Print(string_format("[FlagAlerts] Filtered enemy team event: %s", playerName))
                end
                return false
            end
        end
    end

    return true
end

local CLASS_ID_TO_NAME = {
    [1] = "WARRIOR",
    [2] = "PALADIN",
    [3] = "HUNTER",
    [4] = "ROGUE",
    [5] = "PRIEST",
    [6] = "DEATHKNIGHT",
    [7] = "SHAMAN",
    [8] = "MAGE",
    [9] = "WARLOCK",
    [10] = "DRUID",
}

function FlagAlerts:ExtractClassFromGUID(guid)
    if not guid or type(guid) ~= "string" then return nil end

    local classIDHex = guid:sub(6, 7)
    local classID = tonumber(classIDHex, 16)

    if classID and CLASS_ID_TO_NAME[classID] then
        return CLASS_ID_TO_NAME[classID]
    end

    local guidNum = tonumber(guid:sub(3), 16)
    if guidNum then
        classID = bit_band(bit_rshift(guidNum, 40), 0xFF)
        return CLASS_ID_TO_NAME[classID]
    end

    return nil
end

function FlagAlerts:LearnPlayerClassFromGUID(playerName, guid)
    if not sadb.persistentCacheEnabled then return end
    if not playerName or not guid then return end

    local class = self:ExtractClassFromGUID(guid)
    if not class then return end

    if self.persistentCache[playerName] and self.persistentCache[playerName].class == class then
        self.persistentCache[playerName].lastSeen = GetTime()
        return
    end

    self:SaveToPersistentCache(playerName, class)

    self.performanceMetrics.classesLearned = self.performanceMetrics.classesLearned + 1

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts] Learned: %s = %s (from GUID)", playerName, class))
    end
end

function FlagAlerts:ProcessFlagEvent(message)
    if not sadb.battlegroundAlertsEnabled then return end

    local startTime = debugprofilestop()

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts DEBUG] CHAT MESSAGE: %s", message))
    end

    local playerName, eventType, flagName, carrierTeam
    for _, patternData in ipairs(self.flagPatterns) do
        local match1, match2 = string_match(message, patternData.pattern)
        if match1 then
            eventType = patternData.action

            if patternData.flagName and match2 then
                flagName = match1
                playerName = match2

                if flagName:lower():find("horde") then
                    carrierTeam = "ALLIANCE_TEAM"
                elseif flagName:lower():find("alliance") then
                    carrierTeam = "HORDE_TEAM"
                end
            else
                playerName = match1
            end

            break
        end
    end

    if not playerName or not eventType then
        if sadb.debugmode then
            SoundAlerter:Print("[FlagAlerts DEBUG] ✗ No pattern match - message ignored")
        end
        return
    end

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts DEBUG] CHAT PATTERN MATCHED - Player: %s | Event: %s | Flag: %s | Team: %s",
            playerName, eventType, flagName or "N/A", carrierTeam or "UNKNOWN"))
    end

    if eventType == "PICKUP" and not sadb.flagPickupAudio then return end
    if eventType == "DROP" and not sadb.flagDropAudio then return end
    if eventType == "CAPTURE" and not sadb.flagCaptureAudio then return end

    if eventType ~= "CAPTURE" then
        if not self:ShouldProcessFlagEvent(playerName, eventType) then
            if sadb.debugmode then
                SoundAlerter:Print(string_format("[FlagAlerts] Chat Dedupe: Ignoring duplicate %s for %s (aura already fired)",
                    eventType, playerName))
            end
            return
        end
    end

    if carrierTeam and sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts] Chat: Inferred %s is on %s (from flag name)", playerName, carrierTeam))
    end

    local playerClass = self:GetPlayerClassByName(playerName)

    if not self:PassesTeamFilter(playerName, carrierTeam) then return end

    if eventType == "PICKUP" then
        self.performanceMetrics.chatPickups = self.performanceMetrics.chatPickups + 1
    elseif eventType == "DROP" then
        self.performanceMetrics.chatDrops = self.performanceMetrics.chatDrops + 1
    elseif eventType == "CAPTURE" then
        self.performanceMetrics.chatCaptures = self.performanceMetrics.chatCaptures + 1
    end

    self:TriggerFlagAlert(playerName, playerClass, eventType, carrierTeam)

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

    if sadb.debugmode then
        local combatStatus = self.inCombat and " [COMBAT]" or ""
        SoundAlerter:Print(string_format("[FlagAlerts] Event processed in %.2fms: %s (%s) - %s%s",
            elapsed, playerName, playerClass or "UNKNOWN", eventType, combatStatus))
    end
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

function FlagAlerts:GetPlayerClassByName(playerName)

    if sadb.persistentCacheEnabled and self.persistentCache[playerName] then
        local cached = self.persistentCache[playerName]
        cached.lastSeen = GetTime()
        self.performanceMetrics.persistentCacheHits = self.performanceMetrics.persistentCacheHits + 1

        if sadb.debugmode then
            SoundAlerter:Print(string_format("[FlagAlerts] Persistent cache hit: %s = %s", playerName, cached.class))
        end

        return cached.class
    end

    if not self:CleanupCacheEntry(playerName) and self.nameToClassCache[playerName] then
        local cached = self.nameToClassCache[playerName]
        cached.timestamp = GetTime()
        self.performanceMetrics.cacheHits = self.performanceMetrics.cacheHits + 1
        return cached.class
    end

    self.performanceMetrics.cacheMisses = self.performanceMetrics.cacheMisses + 1

    if UnitExists("target") and UnitName("target") == playerName then
        local _, class = UnitClass("target")
        self:CachePlayerClass(playerName, class)
        return class
    end

    if UnitExists("focus") and UnitName("focus") == playerName then
        local _, class = UnitClass("focus")
        self:CachePlayerClass(playerName, class)
        return class
    end

    if UnitExists("mouseover") and UnitName("mouseover") == playerName then
        local _, class = UnitClass("mouseover")
        self:CachePlayerClass(playerName, class)
        return class
    end

    local numPartyMembers = GetNumPartyMembers()
    if numPartyMembers > 0 then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitName(unit) == playerName then
                local _, class = UnitClass(unit)
                self:CachePlayerClass(playerName, class)
                return class
            end

            local targetUnit = unit .. "target"
            if UnitExists(targetUnit) and UnitName(targetUnit) == playerName then
                local _, class = UnitClass(targetUnit)
                self:CachePlayerClass(playerName, class)
                return class
            end
        end
    end

    local numRaidMembers = GetNumRaidMembers()
    if numRaidMembers > 0 then
        local scanned = 0
        for i = 1, numRaidMembers do
            if scanned >= MAX_RAID_SCAN then
                break
            end
            scanned = scanned + 1

            local unit = "raid" .. i
            if UnitName(unit) == playerName then
                local _, class = UnitClass(unit)
                self:CachePlayerClass(playerName, class)
                return class
            end

            local targetUnit = unit .. "target"
            if UnitExists(targetUnit) and UnitName(targetUnit) == playerName then
                local _, class = UnitClass(targetUnit)
                self:CachePlayerClass(playerName, class)
                return class
            end
        end
    end

    self:CachePlayerClass(playerName, "UNKNOWN")
    return nil
end

function FlagAlerts:CachePlayerClass(playerName, class)
    if not class then return end

    if class ~= "UNKNOWN" then
        self:SaveToPersistentCache(playerName, class)
    end

    local maxCacheSize = GetOptimalCacheSize()
    if self.cacheSize >= maxCacheSize then
        local oldestName, oldestTime = nil, math_huge
        for name, data in pairs(self.nameToClassCache) do
            if data.timestamp < oldestTime then
                oldestName, oldestTime = name, data.timestamp
            end
        end
        if oldestName then
            self.nameToClassCache[oldestName] = nil
            self.cacheSize = self.cacheSize - 1
            self.performanceMetrics.cacheEvictions = self.performanceMetrics.cacheEvictions + 1
        end
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
        lastSeen = GetTime()
    }
end

function FlagAlerts:CleanupPersistentCache()
    if not sadb.persistentCacheEnabled then return end

    local currentTime = GetTime()
    local maxAge = sadb.persistentCacheMaxAge or 2592000

    local toDelete = {}
    for playerName, data in pairs(self.persistentCache) do
        if currentTime - data.lastSeen > maxAge then
            table_insert(toDelete, playerName)
        end
    end

    for _, playerName in ipairs(toDelete) do
        self.persistentCache[playerName] = nil
        self.persistentCacheSize = self.persistentCacheSize - 1
    end

    if sadb.debugmode and #toDelete > 0 then
        SoundAlerter:Print(string_format("[FlagAlerts] Cleaned up %d expired persistent cache entries", #toDelete))
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
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then
        return "ALLIANCE_TEAM"
    elseif faction == "Horde" then
        return "HORDE_TEAM"
    end
    return nil
end

function FlagAlerts:TriggerFlagAlert(playerName, playerClass, eventType, carrierTeam)

    self:QueueAudio(playerClass, eventType)

    if sadb.flagToastsEnabled then
        self:ShowFlagToast(playerName, playerClass, eventType, carrierTeam)
    end

    if sadb.flagChatEnabled then
        self:SendFlagChatAlert(playerName, playerClass, eventType)
    end

    if sadb.debugmode then
        local cacheHitRate = (self.performanceMetrics.cacheHits /
            (self.performanceMetrics.cacheHits + self.performanceMetrics.cacheMisses)) * 100
        SoundAlerter:Print(string_format("[FlagAlerts] %s (%s) - %s | Cache Hit Rate: %.1f%%",
            playerName, playerClass or "Unknown", eventType, cacheHitRate))
    end
end

function FlagAlerts:QueueAudio(playerClass, eventType)
    table_insert(self.audioQueue, { class = playerClass, action = eventType })
    self:ProcessAudioQueue()
end

function FlagAlerts:ProcessAudioQueue()
    if self.audioInProgress then return end
    if #self.audioQueue == 0 then return end

    self.audioInProgress = true
    local audioEvent = table_remove(self.audioQueue, 1)

    local classAudioFile = audioEvent.class and SoundAlerter.CLASS_AUDIO_MAP[audioEvent.class]
    if classAudioFile then
        PlaySoundFile(sadb.sapath .. classAudioFile .. ".mp3", "Master")
    else
        PlaySoundFile(sadb.sapath .. "Enemy.mp3", "Master")
    end

    if sadb.statistics and sadb.statistics.enabled then
        local Statistics = SoundAlerter:GetModule("Statistics")
        if Statistics then
            Statistics:RecordAlert("flagAlerts")
        end
    end

    local delay = (audioEvent.class and audioEvent.class ~= "UNKNOWN") and 0.8 or 0.8
    local objectiveFile = self:GetObjectiveAudioFile(audioEvent.action)

    self:ScheduleTimer(function()
        PlaySoundFile(sadb.sapath .. objectiveFile .. ".mp3", "Master")

        self:ScheduleTimer(function()
            self.audioInProgress = false
            self:ProcessAudioQueue()
        end, 2.0)
    end, delay)
end

function FlagAlerts:GetObjectiveAudioFile(eventType)
    if eventType == "PICKUP" then return "FlagPickup" end
    if eventType == "DROP" then return "FlagDropped" end
    if eventType == "CAPTURE" then return "FlagCaptured" end
    return "FlagPickup"
end

function FlagAlerts:GetToastTitle(eventType)
    if eventType == "PICKUP" then return "FLAG CARRIER!" end
    if eventType == "DROP" then return "FLAG DROPPED!" end
    if eventType == "CAPTURE" then return "FLAG CAPTURED!" end
    return "OBJECTIVE ALERT!"
end

function FlagAlerts:SendFlagChatAlert(playerName, playerClass, eventType)

    if self.inCombat then
        self.performanceMetrics.chatAlertsSuppressed = self.performanceMetrics.chatAlertsSuppressed + 1

        if sadb.debugmode then
            SoundAlerter:Print(string_format("[FlagAlerts] Chat alert suppressed (combat taint protection): %s %s",
                playerName, eventType))
        end
        return
    end

    local template = sadb.flagChatText or "#class# has the flag!"

    local actionText
    if eventType == "PICKUP" then actionText = "picked up flag"
    elseif eventType == "DROP" then actionText = "dropped flag"
    elseif eventType == "CAPTURE" then actionText = "captured flag"
    end

    local safePlayerName = SanitizeMacroText(playerName)

    local message = string_gsub(template, "#class#", playerClass or "Enemy")
    message = string_gsub(message, "#player#", safePlayerName)
    message = string_gsub(message, "#action#", actionText or "flag event")

    local ok, err = pcall(SendChatMessage, message, sadb.flagChatChannel or "SAY")
    if not ok and sadb.debugmode then
        SoundAlerter:Print("[FlagAlerts] SendChatMessage error: "..tostring(err))
    end
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
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Pickups (Aura): |cff00FF00%d|r (primary)", self.performanceMetrics.auraPickups))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Pickups (Chat): |cffFFAA00%d|r (fallback)", self.performanceMetrics.chatPickups))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Drops (Aura): |cff00FF00%d|r (primary)", self.performanceMetrics.auraDrops))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Drops (Chat): |cffFFAA00%d|r (fallback)", self.performanceMetrics.chatDrops))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Captures (Chat): |cff00FFFF%d|r (only method)", self.performanceMetrics.chatCaptures))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Deduped Events: |cff808080%d|r (prevented double alerts)", self.performanceMetrics.dedupeBlocked))
    local totalPickups = self.performanceMetrics.auraPickups + self.performanceMetrics.chatPickups
    local auraReliability = totalPickups > 0 and (self.performanceMetrics.auraPickups / totalPickups * 100) or 0
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Aura Detection Rate: |cff00FF00%.1f%%|r", auraReliability))
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
        auraPickups = 0,
        auraDrops = 0,
        chatPickups = 0,
        chatDrops = 0,
        chatCaptures = 0,
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

        if eventType ~= "PICKUP" and eventType ~= "DROP" and eventType ~= "CAPTURE" then
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
        DEFAULT_CHAT_FRAME:AddMessage(string_format("  Active Toasts: |cffFFFFFF%d / %d|r", #self.activeFlagToasts, 3))
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
        for i = #self.activeFlagToasts, 1, -1 do
            self:ReleaseFlagToast(self.activeFlagToasts[i])
        end
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
local FLAG_FADE_IN_DURATION = 0.2
local FLAG_FADE_OUT_DURATION = 0.5
local FLAG_DISPLAY_DURATION = 5.0
local MAX_SEGMENTS = 30

local FLAG_ICONS = {
    ALLIANCE_FLAG = "Interface\\WorldStateFrame\\AllianceFlag",
    HORDE_FLAG = "Interface\\WorldStateFrame\\HordeFlag",
    NEUTRAL_FLAG = "Interface\\WorldStateFrame\\NeutralFlag",
}

local function GetRainbowColor(time)
    local frequency = math_pi * 2 / 6.0
    local r = math_sin(frequency * time + 0) * 0.5 + 0.5
    local g = math_sin(frequency * time + 2.0944) * 0.5 + 0.5
    local b = math_sin(frequency * time + 4.1888) * 0.5 + 0.5

    return r, g, b
end

local function UpdateFlagCountdownSegments(toast, displayElapsed)
    if not toast.countdownBar or not toast.cachedSegmentData then
        return
    end

    local duration = toast.cachedSegmentData.duration
    local secondsElapsed = math_floor(displayElapsed)
    local segmentProgress = (displayElapsed % 1)
    local currentSegmentIndex = secondsElapsed + 1

    if currentSegmentIndex <= duration and toast.countdownBar.segments[currentSegmentIndex] then
        toast.countdownBar.segments[currentSegmentIndex]:SetAlpha(1 - segmentProgress)
    end

    local lastHidden = toast.cachedSegmentData.lastHiddenSegment or 0
    for i = lastHidden + 1, secondsElapsed do
        if toast.countdownBar.segments[i] then
            toast.countdownBar.segments[i]:SetAlpha(0)
        end
    end
    toast.cachedSegmentData.lastHiddenSegment = secondsElapsed
end

function FlagAlerts:ResolveToastAppearance(carrierTeam)
    local sadb = SoundAlerter.db1.profile
    local textures = SoundAlerter.BarUtils.BACKDROP_TEXTURES
    local myTeam = self:GetMyTeam()
    local isEnemy = myTeam ~= nil and carrierTeam ~= nil and carrierTeam ~= myTeam
    local isFriendly = myTeam ~= nil and carrierTeam == myTeam

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
        end
    end

    local bgFile = textures[textureName] or textures.Solid
    return bgFile, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA
end

function FlagAlerts:CreateFlagToastFrame(index, isSecure)
    local frameName = isSecure and "SoundAlerterFlagSecureToast"..index or "SoundAlerterFlagInsecureToast"..index
    local toast = CreateFrame("Button", frameName, UIParent, "BackdropTemplate")
    toast:SetSize(FLAG_TOAST_WIDTH, FLAG_TOAST_HEIGHT)
    toast:SetFrameStrata("HIGH")
    toast:SetFrameLevel(100)
    toast:Hide()
    toast:SetAlpha(0)

    toast:SetBackdrop({
        bgFile = SoundAlerter.BarUtils.BACKDROP_TEXTURES.Solid,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    toast:SetBackdropColor(0, 0, 0, 0.85)
    toast:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)

    toast.icon = toast:CreateTexture(nil, "ARTWORK")
    toast.icon:SetSize(56, 56)
    toast.icon:SetPoint("LEFT", 8, 0)

    toast.titleText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    toast.titleText:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 10, -4)
    toast.titleText:SetPoint("RIGHT", -8, 0)
    toast.titleText:SetJustifyH("LEFT")
    toast.titleText:SetTextColor(1, 1, 1)

    toast.detailText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toast.detailText:SetPoint("TOPLEFT", toast.titleText, "BOTTOMLEFT", 0, -4)
    toast.detailText:SetPoint("RIGHT", -8, 0)
    toast.detailText:SetJustifyH("LEFT")
    toast.detailText:SetTextColor(0.8, 0.8, 0.8)

    toast.countdownBar = CreateFrame("Frame", nil, toast)
    toast.countdownBar:SetHeight(3)
    toast.countdownBar:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 4, 4)
    toast.countdownBar:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -4, 4)
    toast.countdownBar:SetFrameLevel(toast:GetFrameLevel() + 2)
    toast.countdownBar.segments = {}

    for i = 1, MAX_SEGMENTS do
        local segment = toast.countdownBar:CreateTexture(nil, "OVERLAY")
        segment:SetTexture("Interface\\Buttons\\WHITE8X8")
        segment:SetHeight(3)
        segment:SetVertexColor(0.8, 0.2, 0.2, 1)
        segment:Hide()
        toast.countdownBar.segments[i] = segment
    end

    toast.startTime = 0
    toast.displayDuration = 0
    toast.elapsedTime = 0
    toast.poolIndex = index
    toast.inUse = false
    toast.creationTime = 0

    toast.pauseState = {
        active = false,
        startTime = 0,
        totalTime = 0
    }

    toast.cachedSegmentData = nil

    toast.userData = {
        unitName = nil,
        className = nil,
        eventType = nil,
        carrierTeam = nil,
        timestamp = nil,
    }

    toast.isSecure = isSecure

    if isSecure then
        local secureButton = CreateFrame("Button", frameName.."SecureAction", UIParent, "SecureActionButtonTemplate")
        secureButton:SetAllPoints(toast)
        secureButton:SetFrameStrata("HIGH")
        secureButton:SetFrameLevel(101)
        secureButton:Hide()
        secureButton:RegisterForClicks("LeftButtonDown")
        secureButton:SetAttribute("type1", "macro")

        secureButton:SetScript("OnEnter", function(self)
            if not toast.inUse or toast.pendingDismiss then
                return
            end

            local elapsed = GetTime() - toast.startTime - toast.pauseState.totalTime
            if elapsed >= FLAG_FADE_IN_DURATION and elapsed < (FLAG_FADE_IN_DURATION + toast.displayDuration) then
                toast.pauseState.active = true
                toast.pauseState.startTime = GetTime()
            end
        end)

        secureButton:SetScript("OnLeave", function(self)
            if toast.pauseState.active then
                toast.pauseState.active = false
                local pauseDuration = GetTime() - toast.pauseState.startTime
                toast.pauseState.totalTime = toast.pauseState.totalTime + pauseDuration
                toast.pauseState.startTime = 0
            end
        end)

        toast.secureButton = secureButton
    end

    toast:EnableMouse(true)
    toast:RegisterForClicks("LeftButtonDown")
    toast:SetScript("OnClick", function(self, button)
        if self.isSecure then
            return
        end

        local sadb = SoundAlerter.db1.profile

        if not sadb.flagToastsEnabled then
            return
        end

        local targetName = self.userData and self.userData.unitName

        if not targetName then
            return
        end

        if SoundAlerter.ProximityToasts and SoundAlerter.ProximityToasts.TargetByNameCompat then
            local targetSuccess = SoundAlerter.ProximityToasts.TargetByNameCompat(targetName, nil)

            if not targetSuccess and sadb.debugmode then
                SoundAlerter:Print("[FlagAlerts] Failed to target " .. targetName .. " (unit not visible)")
            end
        end

        local dismissTime = GetTime() + 0.15
        self.pendingDismiss = true
        self.dismissTime = dismissTime

        self:SetScript("OnUpdate", function(frame, elapsed)
            if frame.pendingDismiss and GetTime() >= frame.dismissTime then
                frame.pendingDismiss = false
                frame:SetScript("OnUpdate", nil)
                FlagAlerts:ReleaseFlagToast(frame)
            end
        end)
    end)

    toast:SetScript("OnEnter", function(self)
        if not self.inUse or self.pendingDismiss then
            return
        end

        local elapsed = GetTime() - self.startTime - self.pauseState.totalTime
        if elapsed >= FLAG_FADE_IN_DURATION and elapsed < (FLAG_FADE_IN_DURATION + self.displayDuration) then
            self.pauseState.active = true
            self.pauseState.startTime = GetTime()
        end
    end)

    toast:SetScript("OnLeave", function(self)
        if self.pauseState.active then
            self.pauseState.active = false
            local pauseDuration = GetTime() - self.pauseState.startTime
            self.pauseState.totalTime = self.pauseState.totalTime + pauseDuration
            self.pauseState.startTime = 0
        end
    end)

    return toast
end

function FlagAlerts:AcquireFlagToast()
    self.flagPoolState.inCombat = self.inCombat
    return SoundAlerter.BarUtils:AcquireToastFromPool(self.flagPoolState,
        function(toast) self:ReleaseFlagToast(toast) end,
        function()
            self.flagToastMetrics.poolExhaustions = self.flagToastMetrics.poolExhaustions + 1
            if sadb.debugmode then
                SoundAlerter:Print("[FlagAlerts] Pool exhausted, evicted oldest toast")
            end
        end)
end

function FlagAlerts:ReleaseFlagToast(toast)
    if not toast then return end

    toast:SetScript("OnUpdate", nil)

    toast:Hide()
    toast:SetAlpha(0)
    toast:SetScale(1.0)
    toast:EnableMouse(false)

    toast.titleText:SetText("")
    toast.detailText:SetText("")
    toast.icon:SetTexture(nil)

    toast:SetBackdropColor(0, 0, 0, 0.85)
    toast:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)

    if toast.countdownBar and toast.countdownBar.segments then
        for i = 1, MAX_SEGMENTS do
            if toast.countdownBar.segments[i] then
                toast.countdownBar.segments[i]:Hide()
                toast.countdownBar.segments[i]:SetAlpha(1)
            end
        end
    end

    if toast.secureButton and not InCombatLockdown() then
        toast.secureButton:Hide()
        toast.secureButton:EnableMouse(false)
        toast.secureButton:SetAttribute("macrotext1", nil)
        toast.secureButton:SetAttribute("macrotext", nil)
    elseif toast.secureButton then

        toast.secureButton:Hide()

    end

    toast.startTime = 0
    toast.displayDuration = 0
    toast.elapsedTime = 0
    toast.creationTime = 0

    toast.pauseState.active = false
    toast.pauseState.startTime = 0
    toast.pauseState.totalTime = 0

    toast.cachedSegmentData = nil

    toast.userData.unitName = nil
    toast.userData.className = nil
    toast.userData.eventType = nil
    toast.userData.carrierTeam = nil
    toast.userData.timestamp = nil

    toast.pendingDismiss = false
    toast.dismissTime = nil

    toast.inUse = false

    for i = #self.activeFlagToasts, 1, -1 do
        if self.activeFlagToasts[i] == toast then
            table.remove(self.activeFlagToasts, i)
            break
        end
    end

    self:UpdateFlagToastLayout()
end

function FlagAlerts:CreateSecureFlagToastPool()
    for i = 1, MAX_FLAG_TOASTS do
        self.flagSecureToastPool[i] = self:CreateFlagToastFrame(i, true)
    end
    self.flagSecureCreationPending = false
end

function FlagAlerts:InitializeFlagToastPools()
    if self.toastPoolsInitialized then return end
    self.toastPoolsInitialized = true

    for i = 1, MAX_FLAG_TOASTS do
        self.flagInsecureToastPool[i] = self:CreateFlagToastFrame(i, false)
    end

    if InCombatLockdown() then
        self.flagSecureCreationPending = true
    else
        self:CreateSecureFlagToastPool()
    end

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts] Initialized dual pools (%d secure + %d insecure frames, ~24 KB)",
            MAX_FLAG_TOASTS, MAX_FLAG_TOASTS))
    end
end

function FlagAlerts:UpdateFlagToastLayout()
    local sadb = SoundAlerter.db1.profile

    local baseX = (sadb.flagToasts and sadb.flagToasts.positionX) or 0
    local baseY = (sadb.flagToasts and sadb.flagToasts.positionY) or -300

    table.sort(self.activeFlagToasts, function(a, b)
        return a.creationTime < b.creationTime
    end)

    for i, toast in ipairs(self.activeFlagToasts) do
        toast:ClearAllPoints()
        if i == 1 then
            toast:SetPoint("TOP", UIParent, "TOP", baseX, baseY)
        else
            toast:SetPoint("TOP", self.activeFlagToasts[i-1], "BOTTOM", 0, -FLAG_VERTICAL_SPACING)
        end
    end
end

function FlagAlerts:ShowFlagToast(playerName, playerClass, eventType, carrierTeam)
    local sadb = SoundAlerter.db1.profile

    local toast = self:AcquireFlagToast()
    if not toast then
        if sadb.debugmode then
            SoundAlerter:Print("[FlagAlerts] Failed to acquire toast frame")
        end
        return
    end

    local bgFile, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA = self:ResolveToastAppearance(carrierTeam)
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
        local flagIcon
        if carrierTeam == "ALLIANCE_TEAM" then
            flagIcon = FLAG_ICONS.HORDE_FLAG
        elseif carrierTeam == "HORDE_TEAM" then
            flagIcon = FLAG_ICONS.ALLIANCE_FLAG
        else
            flagIcon = FLAG_ICONS.NEUTRAL_FLAG
        end
        toast.icon:SetTexture(flagIcon)
    end
    toast.icon:Show()

    local titleText
    if eventType == "PICKUP" then
        titleText = "FLAG CARRIER!"
    elseif eventType == "DROP" then
        titleText = "FLAG DROPPED!"
    elseif eventType == "CAPTURE" then
        titleText = "FLAG CAPTURED!"
    else
        titleText = "FLAG EVENT"
    end
    toast.titleText:SetText(titleText)

    local detailText = playerName
    if playerClass and playerClass ~= "UNKNOWN" then
        detailText = playerClass .. " - " .. playerName
    end
    toast.detailText:SetText(detailText)

    toast.userData.unitName = playerName
    toast.userData.className = playerClass
    toast.userData.eventType = eventType
    toast.userData.carrierTeam = carrierTeam
    toast.userData.timestamp = GetTime()

    toast.creationTime = GetTime()
    toast.startTime = GetTime()
    toast.displayDuration = sadb.flagToastDisplayDuration or FLAG_DISPLAY_DURATION
    toast.elapsedTime = 0

    toast.pauseState.active = false
    toast.pauseState.startTime = 0
    toast.pauseState.totalTime = 0

    local duration = math.ceil(toast.displayDuration)
    local barWidth = toast.countdownBar:GetWidth()
    local segmentWidth = barWidth / duration

    toast.cachedSegmentData = {
        duration = duration,
        segmentWidth = segmentWidth,
        lastHiddenSegment = 0
    }

    for i = 1, duration do
        if i <= MAX_SEGMENTS and toast.countdownBar.segments[i] then
            local segment = toast.countdownBar.segments[i]
            segment:ClearAllPoints()
            segment:SetPoint("LEFT", toast.countdownBar, "LEFT", (i-1) * segmentWidth, 0)
            segment:SetWidth(segmentWidth - 2)
            segment:SetVertexColor(borderR, borderG, borderB, borderA)
            segment:SetAlpha(1)
            segment:Show()
        end
    end

    for i = duration + 1, MAX_SEGMENTS do
        if toast.countdownBar.segments[i] then
            toast.countdownBar.segments[i]:Hide()
        end
    end

    if toast.secureButton and not InCombatLockdown() then
        local macroText = "/target " .. playerName
        toast.secureButton:SetAttribute("macrotext1", macroText)
        toast.secureButton:SetAttribute("macrotext", macroText)
        toast.secureButton:Show()
    end

    toast:SetScript("OnUpdate", function(self, elapsed)
        if not self.inUse then
            self:SetScript("OnUpdate", nil)
            return
        end

        if self.pauseState.active then
            return
        end

        local currentTime = GetTime()
        local timeSinceStart = currentTime - self.startTime - self.pauseState.totalTime

        if sadb.proximityToasts and sadb.proximityToasts.rainbowBorder then
            local r, g, b = GetRainbowColor(currentTime)
            self:SetBackdropBorderColor(r, g, b, 1)
        end

        if timeSinceStart < FLAG_FADE_IN_DURATION then
            local progress = timeSinceStart / FLAG_FADE_IN_DURATION
            self:SetAlpha(progress)
            local scale = 1.15 - (0.15 * progress)
            self:SetScale(scale)

            if self.secureButton then
                self.secureButton:SetAlpha(progress)
            end

            return
        end

        if timeSinceStart < (FLAG_FADE_IN_DURATION + self.displayDuration) then
            self:SetAlpha(1)
            self:SetScale(1.0)

            if self.secureButton then
                self.secureButton:SetAlpha(1)
            end

            local displayElapsed = timeSinceStart - FLAG_FADE_IN_DURATION
            UpdateFlagCountdownSegments(self, displayElapsed)

            return
        end

        local fadeOutTime = timeSinceStart - (FLAG_FADE_IN_DURATION + self.displayDuration)
        if fadeOutTime < FLAG_FADE_OUT_DURATION then
            local fadeProgress = fadeOutTime / FLAG_FADE_OUT_DURATION
            self:SetAlpha(1 - fadeProgress)

            if self.secureButton then
                self.secureButton:SetAlpha(1 - fadeProgress)
            end

            if self.countdownBar and self.cachedSegmentData then
                local duration = self.cachedSegmentData.duration
                for i = 1, duration do
                    if self.countdownBar.segments[i] then
                        self.countdownBar.segments[i]:SetAlpha(0)
                    end
                end
            end

            return
        end

        self:SetScript("OnUpdate", nil)
        FlagAlerts:ReleaseFlagToast(self)
    end)

    toast:Show()
    toast:SetAlpha(0)
    toast:EnableMouse(true)

    if toast.secureButton and not InCombatLockdown() then
        toast.secureButton:EnableMouse(true)
    end

    table.insert(self.activeFlagToasts, toast)

    self:UpdateFlagToastLayout()

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

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts] Showed flag toast: %s (%s) - %s | Pool: %s | Active: %d/%d",
            playerName, playerClass or "Unknown", eventType,
            self.inCombat and "Insecure" or "Secure",
            #self.activeFlagToasts, MAX_FLAG_TOASTS))
    end
end

function FlagAlerts:CopyFlagToastData(oldFrame, newFrame)
    if not oldFrame or not newFrame then return false end

    newFrame.userData.unitName = oldFrame.userData.unitName
    newFrame.userData.className = oldFrame.userData.className
    newFrame.userData.eventType = oldFrame.userData.eventType
    newFrame.userData.carrierTeam = oldFrame.userData.carrierTeam
    newFrame.userData.timestamp = oldFrame.userData.timestamp

    newFrame.startTime = oldFrame.startTime
    newFrame.displayDuration = oldFrame.displayDuration
    newFrame.elapsedTime = oldFrame.elapsedTime
    newFrame.creationTime = oldFrame.creationTime

    newFrame.pauseState.active = oldFrame.pauseState.active
    newFrame.pauseState.startTime = oldFrame.pauseState.active and GetTime() or 0
    newFrame.pauseState.totalTime = oldFrame.pauseState.totalTime

    if oldFrame.cachedSegmentData then
        newFrame.cachedSegmentData = {
            duration = oldFrame.cachedSegmentData.duration,
            segmentWidth = oldFrame.cachedSegmentData.segmentWidth,
            lastHiddenSegment = oldFrame.cachedSegmentData.lastHiddenSegment
        }

        for i = 1, oldFrame.cachedSegmentData.duration do
            if i <= MAX_SEGMENTS then
                local oldSegment = oldFrame.countdownBar.segments[i]
                local newSegment = newFrame.countdownBar.segments[i]
                if oldSegment and newSegment then
                    newSegment:ClearAllPoints()
                    newSegment:SetPoint("LEFT", newFrame.countdownBar, "LEFT",
                        (i-1) * newFrame.cachedSegmentData.segmentWidth, 0)
                    newSegment:SetWidth(newFrame.cachedSegmentData.segmentWidth - 2)

                    if oldSegment:IsShown() then
                        newSegment:Show()
                    else
                        newSegment:Hide()
                    end

                    local r, g, b, a = oldSegment:GetVertexColor()
                    newSegment:SetVertexColor(r, g, b, a)
                end
            end
        end
    end

    newFrame.icon:SetTexture(oldFrame.icon:GetTexture())
    newFrame.titleText:SetText(oldFrame.titleText:GetText() or "")
    newFrame.detailText:SetText(oldFrame.detailText:GetText() or "")

    local r, g, b, a = oldFrame:GetBackdropColor()
    newFrame:SetBackdropColor(r, g, b, a)

    r, g, b, a = oldFrame:GetBackdropBorderColor()
    newFrame:SetBackdropBorderColor(r, g, b, a)

    newFrame:SetAlpha(oldFrame:GetAlpha())

    if newFrame.secureButton and not InCombatLockdown() then
        local unitName = newFrame.userData.unitName
        if unitName then
            local macroText = "/target " .. unitName
            newFrame.secureButton:SetAttribute("macrotext1", macroText)
            newFrame.secureButton:SetAttribute("macrotext", macroText)
            newFrame.secureButton:Show()
            newFrame.secureButton:SetAlpha(newFrame:GetAlpha())
        end
    end

    newFrame.inUse = true

    newFrame:SetScript("OnUpdate", oldFrame:GetScript("OnUpdate"))

    return true
end

function FlagAlerts:SwapInsecureToSecureFlagFrames()
    local swappedCount, elapsed = SoundAlerter.BarUtils:SwapInsecureToSecurePool(
        self.flagPoolState,
        function(toast) self:ReleaseFlagToast(toast) end,
        function(old, new) return self:CopyFlagToastData(old, new) end,
        SoundAlerter, "FlagAlerts", 4.0
    )

    self.flagToastMetrics.toastsSwapped = self.flagToastMetrics.toastsSwapped + swappedCount
    self.flagToastMetrics.swapTime = self.flagToastMetrics.swapTime + elapsed
    self.flagToastMetrics.maxSwapTime = math.max(self.flagToastMetrics.maxSwapTime, elapsed)
end
