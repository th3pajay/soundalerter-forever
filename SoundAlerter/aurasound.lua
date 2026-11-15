local SoundAlerter = SoundAlerter

local Plain = SA_COMPAT.Plain

local registered = {}
local enemyUnits = { target = false, focus = false }
local ENEMY_TOKENS = { "target", "focus" }
local TEST_UNITS = { "player", "target", "focus", "nameplate1", "arena1", "party1", "mouseover" }
local TEST_SPELL = 2825
local PLAY_SECONDS = 30
local RETRY_SECONDS = 2
local BATTLE_THROTTLE = 2
local playIDs = {}

local BATTLE_UNITS = SA_AuraSound.BATTLE_UNITS
local battleRegistered = {}
for _, unit in ipairs(BATTLE_UNITS) do battleRegistered[unit] = {} end
local battleFiles = {}
local battleParams = { throttleSeconds = BATTLE_THROTTLE }
local battleState = { count = 0, failed = 0, lastError = nil, spells = 0 }

function SoundAlerter:EngineAuraSoundSupported()
    return C_UnitAuras and C_UnitAuras.AddAuraSound and C_UnitAuras.RemoveAuraSound
        and Enum and Enum.UnitAuraSoundTrigger and true or false
end

function SoundAlerter:HasEngineAuraSound(unit, trigger, spellID)
    if registered[SA_AuraSound.Key(unit, trigger, spellID)] then return true end
    if unit == "player" or unit == "target" or unit == "focus" then return false end
    local guid = Plain(UnitGUID(unit))
    if not guid then return false end
    for _, token in ipairs(ENEMY_TOKENS) do
        if registered[SA_AuraSound.Key(token, trigger, spellID)] and Plain(UnitGUID(token)) == guid then
            return true
        end
    end
    return false
end

local function SavedIDs(self)
    local global = self.db1.global
    global.auraSoundIDs = global.auraSoundIDs or {}
    return global.auraSoundIDs
end

function SoundAlerter:ClearStaleAuraSounds()
    local ids = SavedIDs(self)
    if C_UnitAuras and C_UnitAuras.RemoveAuraSound then
        for _, id in pairs(ids) do
            pcall(C_UnitAuras.RemoveAuraSound, id)
        end
    end
    wipe(ids)
end

local function BattleKey(unit, spellID)
    return "B:" .. SA_AuraSound.Key(unit, "Added", spellID)
end

local function DropBattleVoice(ids, unit, spellID, entry)
    pcall(C_UnitAuras.RemoveAuraSound, entry.id)
    battleRegistered[unit][spellID] = nil
    ids[BattleKey(unit, spellID)] = nil
    battleState.count = battleState.count - 1
end

function SoundAlerter:RemoveAllAuraSounds()
    if not self:EngineAuraSoundSupported() then return end
    self:StopAuraSoundPlay()
    local ids = SavedIDs(self)
    for key, entry in pairs(registered) do
        pcall(C_UnitAuras.RemoveAuraSound, entry.id)
        registered[key] = nil
        ids[key] = nil
    end
    for unit, map in pairs(battleRegistered) do
        for spellID, entry in pairs(map) do DropBattleVoice(ids, unit, spellID, entry) end
    end
    self.battleVoiceList = nil
end

function SoundAlerter:AuraSoundRegistrationBlocked()
    if InCombatLockdown() then return true end
    if Enum and Enum.AddOnRestrictionType and C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState then
        for _, restriction in pairs(Enum.AddOnRestrictionType) do
            local ok, state = pcall(C_RestrictedActions.GetAddOnRestrictionState, restriction)
            if ok and type(state) == "number" and state ~= 0 then return true end
        end
    end
    return false
end

function SoundAlerter:RetryAuraSoundSync()
    self.auraSoundRetryTimer = nil
    self:RunAuraSoundSync()
end

function SoundAlerter:SyncAuraSounds()
    local profile = self.db1.profile
    if not self:EngineAuraSoundSupported() then return end
    if self:AuraSoundRegistrationBlocked() then
        if not self.auraSoundRetryTimer then
            self.auraSoundRetryTimer = self:ScheduleTimer("RetryAuraSoundSync", RETRY_SECONDS)
        end
        return
    end
    local ids = SavedIDs(self)
    local desired = SA_AuraSound.Desired(self.spellList, profile, enemyUnits, self:IsAlertZoneAllowed() and true or false)
    local add, remove = SA_AuraSound.Diff(registered, desired)
    for _, key in ipairs(remove) do
        pcall(C_UnitAuras.RemoveAuraSound, registered[key].id)
        registered[key] = nil
        ids[key] = nil
    end
    for _, key in ipairs(add) do
        local entry = desired[key]
        local ok, id = pcall(C_UnitAuras.AddAuraSound, Enum.UnitAuraSoundTrigger[entry.trigger], {
            unitToken = entry.unit,
            spellID = entry.spellID,
            soundFileName = entry.file,
            throttleSeconds = 1,
        })
        if ok and type(id) == "number" then
            registered[key] = { id = id, file = entry.file, unit = entry.unit, trigger = entry.trigger }
            ids[key] = id
        else
            self:Debug("AuraSound", "%s not registered: %s", key, tostring(id))
        end
    end
    if #add > 0 or #remove > 0 then
        self:Debug("AuraSound", "synced: %d added, %d removed", #add, #remove)
    end
end

function SoundAlerter:BattleVoiceZone()
    local instanceType = self.cachedInstanceType
    return (instanceType == "pvp" or instanceType == "arena") and self:IsAlertZoneAllowed() and true or false
end

function SoundAlerter:RetryBattleVoices()
    self.battleVoiceRetryTimer = nil
    self:SyncBattleVoices()
end

function SoundAlerter:SyncBattleVoices()
    if not self:EngineAuraSoundSupported() then return end
    local profile = self.db1.profile
    local active = profile.battleVoices and self:BattleVoiceZone()
    if not active and battleState.count == 0 then return end
    if self:AuraSoundRegistrationBlocked() then
        if not self.battleVoiceRetryTimer then
            self.battleVoiceRetryTimer = self:ScheduleTimer("RetryBattleVoices", RETRY_SECONDS)
        end
        return
    end
    local files = SA_AuraSound.BattleFiles(self.spellList.auraApplied, profile, active, battleFiles)
    local ids = SavedIDs(self)
    local before = battleState.count
    for unit, map in pairs(battleRegistered) do
        for spellID, entry in pairs(map) do
            if files[spellID] ~= entry.file then DropBattleVoice(ids, unit, spellID, entry) end
        end
    end
    local removed = before - battleState.count
    local addSound, trigger = C_UnitAuras.AddAuraSound, Enum.UnitAuraSoundTrigger.Added
    local added, failed, spells = 0, 0, 0
    battleParams.spellID, battleParams.unitToken, battleParams.soundFileName = nil, nil, nil
    for spellID, file in pairs(files) do
        spells = spells + 1
        battleParams.spellID, battleParams.soundFileName = spellID, file
        for index = 1, #BATTLE_UNITS do
            local unit = BATTLE_UNITS[index]
            local map = battleRegistered[unit]
            if not map[spellID] then
                battleParams.unitToken = unit
                local ok, id = pcall(addSound, trigger, battleParams)
                if ok and type(id) == "number" then
                    map[spellID] = { id = id, file = file }
                    ids[BattleKey(unit, spellID)] = id
                    added = added + 1
                else
                    failed = failed + 1
                    battleState.lastError = ok and "no id returned" or tostring(id)
                end
            end
        end
    end
    battleState.count = battleState.count + added
    battleState.failed = failed
    battleState.spells = spells
    self.battleVoiceList = battleState.count > 0 and self.spellList.auraApplied or nil
    if added > 0 or removed > 0 or failed > 0 then
        self:Debug("AuraSound", "battle voices: %d added, %d removed, %d failed, %d active", added, removed, failed, battleState.count)
    end
end

function SoundAlerter:BattleVoiceSummary()
    return battleState.count, battleState.spells, #BATTLE_UNITS, battleState.failed, battleState.lastError
end

function SoundAlerter:AuraSoundSummary()
    local counts = {}
    for _, entry in pairs(registered) do
        local label = entry.unit .. " " .. entry.trigger
        counts[label] = (counts[label] or 0) + 1
    end
    local labels = {}
    for label in pairs(counts) do labels[#labels + 1] = label end
    table.sort(labels)
    local parts = {}
    for index, label in ipairs(labels) do
        parts[index] = label .. " " .. counts[label]
    end
    return #parts > 0 and table.concat(parts, ", ") or "none",
        enemyUnits.target and true or false, enemyUnits.focus and true or false
end

function SoundAlerter:RefreshEnemyAuraUnits()
    local changed = false
    for _, unit in ipairs(ENEMY_TOKENS) do
        local profile = self.db1.profile
        local isEnemy = UnitExists(unit) and Plain(UnitIsEnemy("player", unit)) == true
            and (profile.debugmode or Plain(UnitIsPlayer(unit)) == true)
        if isEnemy ~= enemyUnits[unit] then
            enemyUnits[unit] = isEnemy
            changed = true
        end
    end
    if changed and self.db1.profile.engineAuraSounds then
        self:SyncAuraSounds()
    end
end

function SoundAlerter:RunAuraSoundSync()
    self.auraSoundSyncTimer = nil
    self:RefreshEnemyAuraUnits()
    self:SyncAuraSounds()
    self:SyncBattleVoices()
end

function SoundAlerter:OnConfigTableChange(event, appName)
    if appName ~= "SoundAlerter" or self.auraSoundSyncTimer then return end
    local profile = self.db1.profile
    if not profile.engineAuraSounds and next(registered) == nil
        and not (profile.battleVoices and self:BattleVoiceZone()) and battleState.count == 0 then
        return
    end
    self.auraSoundSyncTimer = self:ScheduleTimer("RunAuraSoundSync", 0.5)
end

function SoundAlerter:StartAuraSounds()
    self:ClearStaleAuraSounds()
    LibStub("AceConfigRegistry-3.0").RegisterCallback(self, "ConfigTableChange", "OnConfigTableChange")
    self:RefreshEnemyAuraUnits()
    self:SyncAuraSounds()
    self:SyncBattleVoices()
end

function SoundAlerter:StopAuraSoundPlay()
    if self.auraSoundPlayTimer then
        self:CancelTimer(self.auraSoundPlayTimer)
        self.auraSoundPlayTimer = nil
    end
    for index, id in ipairs(playIDs) do
        pcall(C_UnitAuras.RemoveAuraSound, id)
        playIDs[index] = nil
    end
end

function SoundAlerter:AuraSoundPlay(spellID, unit)
    if not self:EngineAuraSoundSupported() then
        self:Print("C_UnitAuras.AddAuraSound is not available on this client.")
        return
    end
    if not spellID then
        self:Print("Usage: /sa aurasound play <spellID> [unit]. Example: /sa aurasound play 1459 player, then gain that buff.")
        return
    end
    unit = unit or "player"
    self:StopAuraSoundPlay()
    local base = self.db1.profile.sapath
    local triggers = Enum.UnitAuraSoundTrigger
    local sounds = { { triggers.Added, "detected.mp3", "gained" }, { triggers.Removed, "lockout.mp3", "lost" } }
    for _, entry in ipairs(sounds) do
        local ok, id = pcall(C_UnitAuras.AddAuraSound, entry[1], {
            unitToken = unit,
            spellID = spellID,
            soundFileName = base .. entry[2],
            throttleSeconds = 0,
        })
        if ok and type(id) == "number" then
            playIDs[#playIDs + 1] = id
            self:Print(string.format("  %s %s: %s plays when the aura is %s", unit, spellID, entry[2], entry[3]))
        else
            self:Print(string.format("  %s %s: %s not registered (%s)", unit, spellID, entry[2], tostring(ok and "no id returned" or id)))
        end
    end
    if #playIDs > 0 then
        self.auraSoundPlayTimer = self:ScheduleTimer("StopAuraSoundPlay", PLAY_SECONDS)
        self:Print(string.format("Listening for %d seconds. Gain and lose the aura now.", PLAY_SECONDS))
    end
end

function SoundAlerter:AuraSoundCommand(rest)
    local action, spellText, unit = (rest or ""):match("^(%S*)%s*(%S*)%s*(%S*)$")
    if action == "play" then
        self:AuraSoundPlay(tonumber(spellText), unit ~= "" and unit or nil)
    else
        self:AuraSoundSelfTest()
    end
end

function SoundAlerter:AuraSoundSelfTest()
    if not self:EngineAuraSoundSupported() then
        self:Print("C_UnitAuras.AddAuraSound is not available on this client.")
        return
    end
    local file = self.db1.profile.sapath .. "detected.mp3"
    self:Print("|cffFFD700=== Engine aura sound test (registers and removes at once) ===|r")
    for _, unit in ipairs(TEST_UNITS) do
        local ok, id = pcall(C_UnitAuras.AddAuraSound, Enum.UnitAuraSoundTrigger.Added, {
            unitToken = unit,
            spellID = TEST_SPELL,
            soundFileName = file,
            throttleSeconds = 1,
        })
        if ok and type(id) == "number" then
            self:Print("  " .. unit .. ": accepted, id " .. id)
            pcall(C_UnitAuras.RemoveAuraSound, id)
        else
            self:Print("  " .. unit .. ": " .. (ok and "no id returned" or ("error: " .. tostring(id))))
        end
    end
end
