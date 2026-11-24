
SoundAlerter = LibStub("AceAddon-3.0"):NewAddon("SoundAlerter", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
local self, SoundAlerter = SoundAlerter, SoundAlerter

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SoundAlerter")
local GetSpellInfo, GetSpellLink = SA_COMPAT.GetSpellInfo, SA_COMPAT.GetSpellLink
local UnitAura = SA_COMPAT.UnitAura
local sadb

local playerName = UnitName("player")

local FILTER_TYPE_ANY = COMBATLOG_FILTER_EVERYTHING
local FILTER_TYPE_FRIENDLY = COMBATLOG_FILTER_FRIENDLY_UNITS
local FILTER_TYPE_HOSTILE_PLAYER = COMBATLOG_FILTER_HOSTILE_PLAYERS
local FILTER_TYPE_HOSTILE_UNIT = COMBATLOG_FILTER_HOSTILE_UNITS
local FILTER_TYPE_NEUTRAL = COMBATLOG_FILTER_NEUTRAL_UNITS
local FILTER_TYPE_ME = COMBATLOG_FILTER_ME
local FILTER_TYPE_MINE = COMBATLOG_FILTER_MINE
local FILTER_TYPE_MY_PET = COMBATLOG_FILTER_MY_PET

local Plain, SafeUnitName, SafeUnitClass = SA_COMPAT.Plain, SA_COMPAT.SafeUnitName, SA_COMPAT.SafeUnitClass

SoundAlerter.SafeUnitName = SafeUnitName

self.SA_LOCALEPATH = SA_LOCALEPATH
self.SA_LANGUAGE = {
    ["Interface\\Addons\\SoundAlerter\\Voice\\"] = "English",
}
self.SA_EVENT = {
    SPELL_CAST_SUCCESS = L["Instant spell was successfully casted"],
    SPELL_CAST_START = L["Spell is casting"],
    SPELL_AURA_APPLIED = L["Spell buff/debuff applied"],
    SPELL_AURA_REMOVED = L["Spell buff/debuff down"],
    SPELL_INTERRUPT = L["Spell is interrupted"],
    SPELL_SUMMON = L["Summoning spell"],
    SPELL_DAMAGE = L["Spell cast successfully damaged"]
}
self.SA_UNIT = {
    any = L["Any"],
    player = L["Player"],
    target = L["Target"],
    focus = L["Focus"],
    mouseover = L["Mouseover"],
    party = L["Party"],
    arena = L["Arena (enemy)"],
    custom = L["Custom"],
}
self.SA_TYPE = {
    [FILTER_TYPE_ANY] = L["Any"],
    [FILTER_TYPE_FRIENDLY] = L["Friendly"],
    [FILTER_TYPE_HOSTILE_PLAYER] = L["Hostile player"],
    [FILTER_TYPE_HOSTILE_UNIT] = L["Hostile non-player"],
    [FILTER_TYPE_NEUTRAL] = L["Neutral"],
    [FILTER_TYPE_ME] = L["Myself"],
    [FILTER_TYPE_MINE] = L["My non-unit object (totem)"],
    [FILTER_TYPE_MY_PET] = L["My pet"],
}
self.SA_TYPE_ORDER = {
    FILTER_TYPE_ANY, FILTER_TYPE_FRIENDLY, FILTER_TYPE_HOSTILE_PLAYER, FILTER_TYPE_HOSTILE_UNIT,
    FILTER_TYPE_NEUTRAL, FILTER_TYPE_ME, FILTER_TYPE_MINE, FILTER_TYPE_MY_PET,
}

function SoundAlerter:Debug(module, fmt, ...)
    if not (sadb and sadb.debugmode) then return end
    DEFAULT_CHAT_FRAME:AddMessage(SA_DebugLog.Format(GetTime(), module, fmt, ...))
end

function SoundAlerter:ChangeProfile()
	sadb = self.db1.profile
	SA_ChatAreas.Migrate(sadb)
	self:InvalidateTrackedAuraIDs()
	self:OnConfigTableChange(nil, "SoundAlerter")
	self:OnOptionsProfileChanged()

	SA_Modules.ApplyProfile(self.db1.profile)
end

local Core = {}
SoundAlerter.Core = Core

local function ApplyHiddenSpells()
	SA_Secret.SetEnabled(sadb.hiddenSpells)
	SA_Secret.Reset()
end

local function RefreshUpdateCheck()
	if SoundAlerter.UpdateCheck then SoundAlerter.UpdateCheck:Refresh() end
end

local CORE_SETTINGS = {
	"hiddenSpells", "scoreboardClassFallback", "showTotemPlates", "overrideNameplateRange", "nameplateRange",
	"shareAlertsSend", "shareAlertsReceive", "globalSightings", "globalQuality", "globalPanelZone",
	"globalPanelWorld", "globalMinimap", "globalMapMarkers", "updateNotice", "chatalerts", "all",
	"welcomeLine", "flatWindow", "menuAnimations", "spelldebug",
	"stealthAnyEnemy", "stealthOnSight", "stealthKeepWatch", "stealthWatchBand", "stealthWatchGap",
	"enemyTargetsYou", "enemyTargetsYouCooldown", "enemyCastingAtYou",
	"quietOnTaxi", "quietWhenDead", "quietOutsidePvPFlag", "snoozeMinutes",
	"watchlistEnabled", "watchNamesText", "watchGuildsText", "stealthenemy",
}

local CORE_APPLY = {
	hiddenSpells = ApplyHiddenSpells,
	scoreboardClassFallback = "UpdateScoreboardTracking",
	showTotemPlates = "ApplyTotemPlates",
	overrideNameplateRange = "ApplyNameplateRange",
	nameplateRange = "ApplyNameplateRange",
	shareAlertsSend = "UpdatePartyShare",
	shareAlertsReceive = "UpdatePartyShare",
	globalSightings = "UpdateGlobalSight",
	globalQuality = "UpdateGlobalSight",
	globalPanelZone = "UpdateGlobalMap",
	globalPanelWorld = "UpdateGlobalMap",
	globalMinimap = "UpdateGlobalMap",
	globalMapMarkers = "UpdateGlobalMap",
	updateNotice = RefreshUpdateCheck,
}

local CORE_START = {
	ApplyHiddenSpells, "UpdateScoreboardTracking", "ApplyTotemPlates", "ApplyNameplateRange",
	"UpdatePartyShare", "UpdateGlobalSight", RefreshUpdateCheck,
}

local function RunCoreStep(step)
	if type(step) == "string" then
		SoundAlerter[step](SoundAlerter)
	else
		step()
	end
end

function Core:Initialize()
end

function Core:Apply(changedKey)
	if changedKey == nil then
		for i = 1, #CORE_START do RunCoreStep(CORE_START[i]) end
		return
	end
	local step = CORE_APPLY[changedKey]
	if step then RunCoreStep(step) end
	if changedKey == "hiddenSpells" and SoundAlerter.AuraDisplay then SoundAlerter.AuraDisplay:Refresh() end
end

SA_Modules.Register({ key = "Core", module = Core, flat = CORE_SETTINGS, title = "Core" })

function SoundAlerter:OnProfileCopied(event, db, sourceProfileKey)

	self:ChangeProfile()

	if sadb.statistics then
		self:GetModule("Statistics"):ResetAllTime()

		self:Print("Statistics reset for copied profile (settings copied, but stats start fresh)")
	end
end

function SoundAlerter:AddOption(key, table)
	self.options.args[key] = table
end

local addonVersion

local function AddonVersion()
    if addonVersion == nil then
        local readMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
        addonVersion = readMeta and readMeta("SoundAlerter", "Version") or false
    end
    return addonVersion or nil
end

local rearmSeconds = {}

local CUSTOM_SOUNDS = "Interface\\Addons\\SoundAlerter\\CustomSounds\\"
local statistics

local function RecordAlert(category, spellID, guid, name, school, class)
    statistics = statistics or SoundAlerter:GetModule("Statistics", true)
    if statistics then statistics:RecordAlert(category, spellID, guid, name, school, class) end
end

local function PlayAlert(sound, custom, channel)
    local ok, willPlay
    if custom then
        ok, willPlay = SoundAlerter:PlayVoice(CUSTOM_SOUNDS .. sound, "Master")
    else
        ok, willPlay = SoundAlerter:PlayVoice(sadb.sapath .. sound, channel)
    end
    return ok and willPlay and true or false
end

local emitter = SA_AlertEmit.New({
    Play = PlayAlert,
    Record = RecordAlert,
    Debug = function(...) SoundAlerter:Debug(...) end,
}, {
    Now = GetTime,
    Plain = Plain,
    Setting = function(key) return sadb[key] end,
    ZoneAllowed = function() return SoundAlerter:IsAlertZoneAllowed() end,
    Quiet = function() return SoundAlerter:IsQuiet() end,
    RearmSeconds = function(key) return rearmSeconds[key] end,
    RearmByCaster = function(key) return SoundAlerterSpellRearmPerCaster and SoundAlerterSpellRearmPerCaster[key] end,
    Diag = function() return SoundAlerter.diag end,
})

SoundAlerter.Emitter = emitter


function SoundAlerter:OnInitialize()
    self.moduleInitErrors = {}
    rearmSeconds = SoundAlerterSpellRearm or rearmSeconds

    if SoundAlerterSpells then
        self.spellList = SoundAlerterSpells
    else
        self:Print("|cffff0000Error: SoundAlerterSpells table not found. Check spellist.lua.|r")
        self.spellList = {}
    end

    for _, v in pairs(self.spellList) do
        for _, spell in pairs(v) do
            if dbDefaults.profile[spell] == nil then dbDefaults.profile[spell] = true end
        end
    end

    local existingInstall = SoundAlerterDB ~= nil
    local defaultProfile = SA_ProfileModel.NewCharacterDefault(SoundAlerterDB) or "Default"
    self.db1 = LibStub("AceDB-3.0"):New("SoundAlerterDB", dbDefaults, defaultProfile)
    SA_ProfileCleanup.Run(SoundAlerterDB)
    SA_QuickStart.Seed(self.db1.global, existingInstall)
    SA_QuickStart.SeedSightingsNotice(self.db1.global, existingInstall)
    SA_QuickStart.SeedStatsNotice(self.db1.global, existingInstall)
    SA_QuickStart.SeedSightingsConsent(self.db1.global, existingInstall)
    sadb = self.db1.profile
    SA_ChatAreas.Migrate(sadb)
    self:InvalidateTrackedAuraIDs()

    self.db1.RegisterCallback(self, "OnProfileChanged", "ChangeProfile")
    self.db1.RegisterCallback(self, "OnProfileCopied", "OnProfileCopied")
    self.db1.RegisterCallback(self, "OnProfileReset", "ChangeProfile")

    self:RegisterChatCommand("SoundAlerter", "HandleCommand")
    self:RegisterChatCommand("SALERTER", "HandleCommand")
    self:RegisterChatCommand("sa", "HandleCommand")

    SoundAlerter.options = {
        name = "SoundAlerter",
        desc = "Voice prompts from enemy used spells",
        type = 'group',
        icon = [[Interface\Icons\Spell_Nature_ForceOfNature]],
        args = {},
    }
    local bliz_options = CopyTable(SoundAlerter.options)
    bliz_options.args.load = {
        name = "Load configuration",
        desc = "Load configuration options",
        type = 'execute',
        func = "ShowConfig",
        handler = SoundAlerter,
    }

    AceConfig:RegisterOptionsTable("SoundAlerter_bliz", bliz_options)

    local blizOptionsOk = pcall(AceConfigDialog.AddToBlizOptions, AceConfigDialog, "SoundAlerter_bliz", "SoundAlerter")
    if not blizOptionsOk then
        self:Debug("Init", "Blizzard Settings panel integration unavailable (outdated AceConfigDialog-3.0), use /sa instead")
    end

    local version = AddonVersion()
    local global = self.db1.global
    local _, welcome = SA_QuickStart.Welcome({ version = version, seen = global.welcomeVersion, existing = existingInstall, showLine = self.db1.profile.welcomeLine ~= false })
    if welcome then DEFAULT_CHAT_FRAME:AddMessage(welcome) end
    global.welcomeVersion = version
	self:CreateMinimapButton()
end

function SoundAlerter:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterEvent("ZONE_CHANGED")
    self:RegisterEvent("ZONE_CHANGED_INDOORS", "ZONE_CHANGED")
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:RegisterEvent("UNIT_NAME_UPDATE")
    self:RegisterEvent("UNIT_FACTION")
    self:RegisterEvent("PLAYER_UPDATE_RESTING")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("UNIT_TARGET")
    self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
    pcall(self.RegisterEvent, self, "LOSS_OF_CONTROL_ADDED")
    self:RegisterEvent("PLAYER_LOGOUT")

    self:RefreshZoneState()

    if not self.SA_LANGUAGE[sadb.path] then sadb.path = self.SA_LOCALEPATH.enUS end

    self.enemyOnYouAt = {}
    SA_Plates.Reset()
    self.stealthTimer = nil
    self:SubscribeCastEvents()
    self.enterWorldTime = 0

    self:ResetDiagnostics()

    SA_Modules.Start(self.db1.profile, self)
    self:CheckQuickStartSetup()

    self:StartAuraSounds()
end

function SoundAlerter:PlayTrinket(sourceGUID, sourceName)
    local context = emitter:Context("trinket")
    context.sound, context.category, context.guid, context.name = "Trinket.mp3", "trinketAlerts", sourceGUID, sourceName
    emitter:Emit(context)
end

local function IsChatBlocked()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        return C_ChatInfo.InChatMessagingLockdown() and true or false
    end
    return InCombatLockdown() and true or false
end

local function ResolveChatChannel(channel, inInstance)
    if channel == "BATTLEGROUND" then
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
        return nil, "not in an instance group"
    elseif channel == "SAY" or channel == "YELL" then
        if inInstance then return channel end
        return nil, "only allowed inside instances"
    elseif channel == "PARTY" then
        if IsInGroup() then return channel end
        return nil, "not in a group"
    elseif channel == "RAID" then
        if IsInRaid() then return channel end
        return nil, "not in a raid"
    end
    return channel
end

SoundAlerter.ResolveChatChannel = ResolveChatChannel

SoundAlerter.voiceFailures = 0

function SoundAlerter:PlayVoice(path, channel)
    local ok, willPlay = false, nil
    if PlaySoundFile then ok, willPlay = pcall(PlaySoundFile, path, channel) end
    if not ok then
        self.voiceFailures = self.voiceFailures + 1
        if self.voiceFailures == 1 then
            self:Print("Voice playback unavailable on this client.")
        end
        self:Debug("Sound", "playback failed (%d): %s", self.voiceFailures, tostring(path))
        return false
    end
    return ok, willPlay
end

local CHAT_INTERVAL = 1.5
local CHAT_BURST = 3
local chatTokens, chatRefillAt = CHAT_BURST, 0
local chatTargets = {}

local function TakeChatToken(now)
    if chatTokens < CHAT_BURST then
        local gained = math.floor((now - chatRefillAt) / CHAT_INTERVAL)
        if gained > 0 then
            chatTokens = math.min(CHAT_BURST, chatTokens + gained)
            chatRefillAt = chatRefillAt + gained * CHAT_INTERVAL
        end
    end
    if chatTokens <= 0 then return false end
    if chatTokens == CHAT_BURST then chatRefillAt = now end
    chatTokens = chatTokens - 1
    return true
end

function SoundAlerter:SendChat(message, channels)
    local diag = self.diag
    if IsChatBlocked() then
        if diag then diag.chatBlocked = diag.chatBlocked + 1 end
        self:Debug("Chat", "not sent, chat is locked down: %s", message)
        return false
    end
    if not TakeChatToken(GetTime()) then
        if diag then diag.chatThrottled = diag.chatThrottled + 1 end
        self:Debug("Chat", "not sent, too many chat lines: %s", message)
        return nil
    end
    local sent = false
    local inInstance = IsInInstance()
    for index = #chatTargets, 1, -1 do chatTargets[index] = nil end
    for _, channel in ipairs(channels) do
        local target, reason = ResolveChatChannel(channel, inInstance)
        if target then
            chatTargets[#chatTargets + 1] = target
        else
            self:Debug("Chat", "%s skipped, %s", channel, reason)
        end
    end
    for _, target in ipairs(SA_ChatTargets.Pick(chatTargets)) do
        if pcall(SendChatMessage, message, target, nil, nil) then
            sent = true
            self:Debug("Chat", "sent to %s: %s", target, message)
        else
            self:Debug("Chat", "%s send failed", target)
        end
    end
    if sent then
        if diag then diag.chatSent = diag.chatSent + 1 end
        RecordAlert("chatAlerts")
    end
    return sent
end

local LOCAL_PREFIX = "|cff33ff99SoundAlerter|r: "

local function SendPlain(message, area)
    return SoundAlerter:SendChat(message, SA_ChatAreas.Channels(sadb, area))
end

local function AddLocalLine(line)
    DEFAULT_CHAT_FRAME:AddMessage(LOCAL_PREFIX .. line)
    return true
end

local function PrintPlain(message)
    SoundAlerter:Debug("Chat", "no channel available, printed locally")
    SoundAlerter:Print(message)
end

SA_AlertText.Attach(SendPlain, AddLocalLine, PrintPlain, function() return sadb end)

local function LinkOrName(spellID)
    return spellID and (GetSpellLink(spellID) or GetSpellInfo(spellID)) or ""
end

local function JoinIcon(icon, link)
    return "|T" .. icon .. ":0|t" .. link
end

local function HiddenSpellIcon(hiddenSpellID)
    if not issecretvalue(hiddenSpellID) then return nil end
    local okIcon, icon = pcall(C_Spell.GetSpellTexture, hiddenSpellID)
    local okLink, link = pcall(C_Spell.GetSpellLink, hiddenSpellID)
    if not (okIcon and okLink) or not (issecretvalue(icon) or icon ~= nil) or not (issecretvalue(link) or link ~= nil) then return nil end
    local ok, piece = pcall(JoinIcon, icon, link)
    if not ok then return nil end
    return piece
end

SoundAlerter.scoreboardClasses = {}
local lastScoreboardRefresh = 0

local function ScoreboardRow(index)
    local ok, info = pcall(C_PvP.GetScoreInfo, index)
    if not ok or type(info) ~= "table" then return nil end
    return Plain(info.name), Plain(info.classToken)
end

function SoundAlerter:RefreshScoreboard()
    if not (C_PvP and C_PvP.GetScoreInfo) then return end
    local count = GetNumBattlefieldScores and GetNumBattlefieldScores() or 80
    local filled = SA_Scoreboard.Fill(self.scoreboardClasses, count, ScoreboardRow)
    self:Debug("Scoreboard", "%d of %d rows mapped to a class", filled, count)
end

function SoundAlerter:RequestScoreboard()
    if RequestBattlefieldScoreData then pcall(RequestBattlefieldScoreData) end
end

function SoundAlerter:UPDATE_BATTLEFIELD_SCORE()
    if not (sadb.scoreboardClassFallback and SA_ZoneKind.Kind() == "battleground") then return end
    local now = GetTime()
    if now - lastScoreboardRefresh < 5 then return end
    lastScoreboardRefresh = now
    self:RefreshScoreboard()
end

function SoundAlerter:UpdateScoreboardTracking()
    local active = sadb.scoreboardClassFallback and SA_ZoneKind.Kind() == "battleground"
    if active and not self.scoreboardTimer then
        self.scoreboardTimer = self:ScheduleRepeatingTimer("RequestScoreboard", 20)
        self:RequestScoreboard()
    elseif not active and self.scoreboardTimer then
        self:CancelTimer(self.scoreboardTimer)
        self.scoreboardTimer = nil
        SA_Scoreboard.Clear(self.scoreboardClasses)
    end
end

function SoundAlerter:RefreshZoneState()
    SA_ZoneKind.Refresh()
    self:ApplyZoneState()
end

function SoundAlerter:ApplyZoneState()
    if self.Proximity then self.Proximity:ZoneChanged() end
    self:UpdateScoreboardTracking()
    if sadb.engineAuraSounds then self:SyncAuraSounds() end
    self:SyncBattleVoices()
    local flags = self.FlagAlerts
    if flags and flags.audioQueue and flags:IsEnabled() then flags:OnZoneChanged() end

    local zoneName = GetRealZoneText() or GetZoneText() or "Unknown"
    local instanceType, pvpType = SA_ZoneKind.Reported()
    self.zonePvpTypeLog = self.zonePvpTypeLog or {}
    self.zonePvpTypeLog[zoneName] = { instanceType = instanceType, pvpType = pvpType }

    self:Debug("Zone", "%s: instanceType=%s pvpType=%s kind=%s", zoneName, tostring(instanceType), tostring(pvpType), SA_ZoneKind.Kind())
end

local TOTEM_CVARS = { "nameplateShowEnemyTotems", "nameplateShowFriendlyPlayerTotems" }

function SoundAlerter:RestoreTotemPlates()
    local global = self.db1.global
    local backup = global.totemCVarBackup
    if not backup or InCombatLockdown() then return end
    for name, value in pairs(backup) do
        pcall(SetCVar, name, value)
    end
    global.totemCVarBackup = nil
end

function SoundAlerter:ApplyTotemPlates()
    if InCombatLockdown() then
        self.totemPlatesPending = true
        return
    end
    if not sadb.showTotemPlates then
        self:RestoreTotemPlates()
        return
    end
    local global = self.db1.global
    global.totemCVarBackup = global.totemCVarBackup or {}
    for _, name in ipairs(TOTEM_CVARS) do
        local current = GetCVar(name)
        if current ~= nil then
            if global.totemCVarBackup[name] == nil then
                global.totemCVarBackup[name] = current
            end
            if current ~= "1" then
                pcall(SetCVar, name, "1")
            end
        end
    end
end

function SoundAlerter:PLAYER_REGEN_ENABLED()
    if self.auraSoundsAfterCombat then self:AuraSoundsAfterCombat() end
    if self.totemPlatesPending then
        self.totemPlatesPending = false
        self:ApplyTotemPlates()
    end
    if self.nameplateRangePending then
        self.nameplateRangePending = false
        self:ApplyNameplateRange()
    end
end

function SoundAlerter:ApplyNameplateRange()
    if InCombatLockdown() then
        self.nameplateRangePending = true
        return
    end
    local global = self.db1.global
    local value, backup = SA_NameplateRange.Plan(sadb.overrideNameplateRange, sadb.nameplateRange or 60,
        GetCVar("nameplateMaxDistance"), global.nameplateDistanceBackup)
    global.nameplateDistanceBackup = backup
    if value ~= nil then SetCVar("nameplateMaxDistance", value) end
end

local ALERT_ZONE_SETTING = { world = "field", battleground = "battleground", arena = "arena" }

function SoundAlerter:IsAlertZoneAllowed()
    local key = ALERT_ZONE_SETTING[SA_ZoneKind.Kind()]
    return (key and sadb[key] or sadb.all) and true or false
end

function SoundAlerter:PrintZoneLog()
    self:Print("|cffFFD700=== Zone PvP Type Log ===|r")
    local names = {}
    for zoneName in pairs(self.zonePvpTypeLog or {}) do
        names[#names + 1] = zoneName
    end
    table.sort(names)
    for _, zoneName in ipairs(names) do
        local entry = self.zonePvpTypeLog[zoneName]
        self:Print(zoneName..": instanceType="..tostring(entry.instanceType)..", pvpType="..tostring(entry.pvpType))
    end
    self:Print("|cffFFD700=== End Zone Log ("..#names.." zones visited) ===|r")
end

function SoundAlerter:BlizzardAudioAlertsEnabled()
    if not (C_CombatAudioAlert and C_CombatAudioAlert.IsEnabled) then return false end
    local ok, enabled = pcall(C_CombatAudioAlert.IsEnabled)
    return ok and Plain(enabled) == true
end

function SoundAlerter:PLAYER_ENTERING_WORLD(_, isInitialLogin, isReloadingUi)
    if CombatLogClearEntries then CombatLogClearEntries() end
    self:ClearAuraTracking()
    if self.MinimapTracking then
        self.MinimapTracking:OnEnterWorld()
    end
    if self.Footsteps then
        self.Footsteps:OnEnterWorld(isInitialLogin, isReloadingUi)
    end
    self.enterWorldTime = GetTime()
    self:RefreshZoneState()
    if self:BlizzardAudioAlertsEnabled() then
        self:Debug("Audio", "Blizzard combat audio alerts are on; spoken alerts may be doubled")
    end
end

function SoundAlerter:PLAYER_UPDATE_RESTING()
    if SA_ZoneKind.Refresh() then self:ApplyZoneState() end
end

function SoundAlerter:ZONE_CHANGED_NEW_AREA()
    self:RefreshZoneState()
end

function SoundAlerter:ZONE_CHANGED()
    if SA_ZoneKind.Refresh() then self:ApplyZoneState() end
end

function SoundAlerter:PLAYER_LOGOUT()
    self:RemoveAllAuraSounds()
    self:RestoreTotemPlates()
    if self.SaveGlobalExport then pcall(self.SaveGlobalExport, self) end

    if sadb.statistics and sadb.statistics.enabled then
        local Statistics = self:GetModule("Statistics")
        Statistics:SaveSessionHistory()
    end
end

function SoundAlerter:SecretsCommand()
    self:Print("|cffFFD700=== Hidden-spell display ===|r")
    for _, line in ipairs(SA_Secret.Report()) do
        self:Print("  " .. line)
    end
end

function SoundAlerter:HandleCommand(input)
    local command, rest = input:match("^(%S*)%s*(.-)$")
    command = command:lower()

    if command == "stats" then
        self:ShowPerformanceStats(rest:lower())
    elseif command == "speed" then
        if self.SpeedMeter and self.SpeedMeter.Probe and self.SpeedMeter.addon then
            self.SpeedMeter:Probe()
        else
            self:Print("|cffFF0000SpeedMeter module not loaded.|r")
        end
    elseif command == "fxstats" then
        self:ShowFxStats(rest:lower())
    elseif command == "setup" then
        self:ShowQuickStartSetup()
    elseif command == "whatsnew" then
        for _, line in ipairs(SA_QuickStart.WhatsNewLines(AddonVersion())) do
            DEFAULT_CHAT_FRAME:AddMessage(line)
        end
    elseif command == "help" then
        self:Print("|cffFFD700=== SoundAlerter Commands ===|r")
        self:Print("|cff00FFFF[General]|r")
        self:Print("  |cffFFFFFF/sa|r - Open options panel; |cffFFFFFF/sa setup|r runs the Quick Start setup; |cffFFFFFF/sa whatsnew|r lists what changed in this version")
        self:Print("  |cffFFFFFF/sa stats|r - Show alert diagnostics (duplicate alerts, aura resyncs); |cffFFFFFF/sa stats reset|r clears them")
        self:Print("  |cffFFFFFF/sa speed|r - Print the raw speed values and what the Speed Meter would show (stand in the water, then run it)")
        self:Print("  |cffFFFFFF/sa fxstats [reset]|r - Show how often the casting bars and spell tracker icons update at the current animation quality")
        self:Print("  |cffFFFFFF/sa probe|r - Print what the client lets the addon read (turn on Debug Mode first to record events)")
        self:Print("  |cffFFFFFF/sa meter|r - Check what the game's damage meter reports for match results")
        self:Print("  |cffFFFFFF/sa perf|r - Show how much frame time and memory SoundAlerter uses")
        self:Print("  |cffFFFFFF/sa procs|r - List the procs seen since login and which have a voice")
        self:Print("  |cffFFFFFF/sa debrief|r - Open the debrief of your last battleground")
        self:Print("  |cffFFFFFF/sa updates|r - Show what the update notice knows")
        self:Print("  |cffFFFFFF/sa global|r - Global sightings status: channel, messages, tracked enemies, ignored senders; |cffFFFFFF/sa global mute <name>|r or |cffFFFFFFunmute <name>|r (saved for all your characters)")
        self:Print("  |cffFFFFFF/sa snooze [minutes]|r / |cffFFFFFF/sa unsnooze|r - Silence proximity and enemy awareness alerts for a while")
        self:Print("  |cffFFFFFF/sa watch [guild] <name>|r / |cffFFFFFF/sa unwatch [guild] <name>|r / |cffFFFFFF/sa watchlist|r - Manage the watchlist; Ctrl-click a toast or Enemy Finder row to watch or unwatch")
        self:Print("  |cffFFFFFF/sa secrets|r - Show whether the hidden-spell display routes work on this client")
        self:Print("  |cffFFFFFF/sa aurasound|r - Test engine aura sounds; |cffFFFFFF/sa aurasound play <spellID> [unit]|r listens for 30 s")
        self:Print("  |cffFFFFFF/sa help|r - Show this command list")
        if self.ProximityToasts then
            self.ProximityToasts:PrintHelp()
        end
        if self.FlagAlerts then
            self.FlagAlerts:PrintHelp()
        end
        if self.Footsteps then
            self.Footsteps:PrintHelp()
        end
        if self.SpellTest then
            self.SpellTest:PrintHelp()
        end
        if self.Notices then
            self.Notices:PrintHelp()
        end
    elseif command == "toast" then
        if self.ProximityToasts then
            self.ProximityToasts:HandleCommand(rest)
        else
            self:Print("|cffFF0000ProximityToasts module not loaded.|r")
        end
    elseif command == "flag" then
        if self.FlagAlerts then
            self.FlagAlerts:HandleCommand(rest)
        else
            self:Print("|cffFF0000FlagAlerts module not loaded.|r")
        end
    elseif command == "footsteps" then
        if self.Footsteps then
            self.Footsteps:HandleCommand(rest)
        else
            self:Print("|cffFF0000Footsteps module not loaded.|r")
        end
    elseif command == "spelltest" then
        if self.SpellTest then
            self.SpellTest:HandleCommand(rest)
        else
            self:Print("|cffFF0000SpellTest module not loaded.|r")
        end
    elseif command == "notices" then
        if self.Notices then
            self.Notices:HandleCommand(rest)
        else
            self:Print("|cffFF0000Notices module not loaded.|r")
        end
    elseif command == "secrets" then
        self:SecretsCommand()
    elseif command == "apicheck" then
        self:RunApiCheck()
    elseif command == "zonelog" then
        self:PrintZoneLog()
    elseif command == "probe" then
        self:PrintProbeReport()
    elseif command == "meter" then
        if self.Statistics and self.Statistics.PrintMeter then self.Statistics:PrintMeter() end
    elseif command == "perf" then
        self:PerfReport()
    elseif command == "debrief" then
        self:ShowBGDebrief()
    elseif command == "procs" then
        self:ProcList()
    elseif command == "updates" then
        if self.UpdateCheck then self.UpdateCheck:Status() end
    elseif command == "watch" or command == "unwatch" or command == "watchlist" then
        self:HandleWatchCommand(command, rest)
    elseif command == "aurasound" then
        self:AuraSoundCommand(rest)
    elseif command == "global" then
        self:GlobalSightCommand(rest)
        if (rest or "") == "" and self.GlobalStatsStatus then self:Print(self:GlobalStatsStatus()) end
    elseif command == "snooze" then
        self:Snooze(tonumber(rest))
    elseif command == "unsnooze" then
        self:Unsnooze()
    else
        self:ShowConfig()
    end
end

local REQUIRED_APIS = {
    "PlaySoundFile",
    "C_Spell", "C_Spell.GetSpellInfo", "C_Spell.GetSpellLink",
    "C_Spell.GetSpellDescription", "C_Spell.GetSpellSubtext", "C_Spell.GetSpellCooldown",
    "C_Spell.RequestLoadSpellData",
    "C_PvP", "C_PvP.GetZonePVPInfo",
    "C_UnitAuras", "C_UnitAuras.GetAuraDataByIndex",
    "C_Timer", "C_Timer.After",
    "UnitCastingInfo", "UnitChannelInfo",
    "issecretvalue",
}

local RESTRICTED_PROBES = {
    "GetZonePVPInfo", "GetSpellInfo", "GetSpellLink", "GetSpellCooldown",
    "CombatLogGetCurrentEventInfo", "CombatLog_Object_IsA",
}

local SPELL_FINDER_CANDIDATES = {
    "C_Spell.GetSpellPowerCost", "C_Spell.GetSpellCharges", "C_Spell.IsSpellPassive",
    "C_Spell.GetSpellTexture", "C_Spell.GetSpellLossOfControlCooldown",
    "C_SpellBook", "C_SpellBook.IsSpellKnown", "C_SpellBook.IsSpellInSpellBook",
    "C_SpellBook.GetSpellBookItemInfo", "C_SpellBook.FindSpellBookSlotForSpell",
    "GetSpellPowerCost", "GetSpellCharges", "IsPassiveSpell", "IsSpellKnown",
}

local PVP_RANK_CANDIDATES = {
    "GetPVPLifetimeStats", "GetPVPRankProgress", "GetHonorCurrency",
    "UnitPVPRank", "GetPVPRankInfo", "GetPVPSessionStats", "GetPVPThisWeekStats", "GetPVPLastWeekStats",
    "GetPVPYesterdayStats", "UnitHonor", "UnitHonorMax", "UnitHonorLevel",
    "C_PvP.GetHonorRewardInfo", "C_CurrencyInfo", "C_CurrencyInfo.GetCurrencyInfo",
    "GetFactionInfoByID", "C_Reputation", "C_Reputation.GetFactionDataByID",
}

local function lookupPath(path)
    local value = _G
    for segment in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = value[segment]
    end
    return value
end

function SoundAlerter:RunApiCheck()
    self:Print("|cffFFD700=== SoundAlerter API Check ===|r")

    if not PlaySoundFile then
        self:Print("|cffFF0000Voice playback unavailable: PlaySoundFile is missing.|r")
    end

    local function report(paths, presentTag, absentTag)
        for _, path in ipairs(paths) do
            local value = lookupPath(path)
            if value ~= nil then
                self:Print(presentTag.." "..path.." ("..type(value)..")")
            else
                self:Print(absentTag.." "..path)
            end
        end
    end

    self:Print("|cffFFD700=== Required APIs ===|r")
    report(REQUIRED_APIS, "|cff00FF00[OK]|r", "|cffFF0000[MISSING]|r")

    self:Print("|cffFFD700=== Restricted or legacy probes (absent is expected) ===|r")
    report(RESTRICTED_PROBES, "|cffFFAA00[present]|r", "|cff888888[absent]|r")

    self:Print("|cffFFD700=== Spell Finder candidates (informational) ===|r")
    report(SPELL_FINDER_CANDIDATES, "|cff00FF00[present]|r", "|cff888888[absent]|r")

    self:Print("|cffFFD700=== PvP rank candidates (informational) ===|r")
    report(PVP_RANK_CANDIDATES, "|cff00FF00[present]|r", "|cff888888[absent]|r")

    self:Print("|cffFFD700=== Combat log ===|r")

    local restrictedCheck = lookupPath("C_CombatLog.IsCombatLogRestricted")
    if type(restrictedCheck) == "function" then
        local ok, restricted = pcall(restrictedCheck)
        self:Print("Combat log restricted right now: "..(ok and (restricted and "|cffFF0000yes|r" or "|cff00FF00no|r") or "|cff888888unknown|r"))
    end

    local blizzardHelpers = 0
    for key, value in pairs(_G) do
        if type(key) == "string" and type(value) == "function" and key:lower():find("combatlog") then
            blizzardHelpers = blizzardHelpers + 1
        end
    end
    self:Print("Global CombatLog helper functions: "..blizzardHelpers.." (Blizzard UI helpers, not event sources)")

    for key, value in pairs(_G) do
        if type(key) == "string" and key:sub(1, 2) == "C_" and type(value) == "table" then
            local isCombatLogNamespace = key:lower():find("combatlog") ~= nil
            for subKey, subValue in pairs(value) do
                if type(subKey) == "string" and type(subValue) == "function"
                   and (isCombatLogNamespace or subKey:lower():find("combatlog")) then
                    self:Print("|cff00FFFF[NAMESPACED]|r "..key.."."..subKey)
                end
            end
        end
    end

    self:Print("|cffFFD700=== End API Check ===|r")
end

function SoundAlerter:ResetDiagnostics()
    self.diag = {
        duplicateAlerts = 0,
        duplicateTokens = {},
        resyncFirstOrUnreadable = 0,
        resyncSecretAdded = 0,
        resyncProbes = 0,
        zoningSkips = 0,
        chatSent = 0,
        chatMerged = 0,
        chatThrottled = 0,
        chatBlocked = 0,
        nameKeyed = 0,
        levelHidden = 0,
        compareHidden = 0,
    }
end

function SoundAlerter:ShowPerformanceStats(argument)
    if argument == "reset" then
        self:ResetDiagnostics()
        self:Print("Alert diagnostics reset")
        return
    end

    local diag = self.diag
    self:Print("=== |cffFF7D0AAlert Diagnostics|r ===")

    self:Print("Same spell alerted twice within " .. SA_AlertEmit.DUPLICATE_WINDOW .. " s: |cffFFFFFF" .. diag.duplicateAlerts .. "|r")
    for pair, count in pairs(diag.duplicateTokens) do
        self:Print("  " .. pair .. ": |cffFFFFFF" .. count .. "|r")
    end

    self:Print("Aura resyncs: |cffFFFFFF" .. (diag.resyncFirstOrUnreadable + diag.resyncSecretAdded) .. "|r (first sight or unreadable update " ..
        diag.resyncFirstOrUnreadable .. ", hidden added auras " .. diag.resyncSecretAdded .. "), spell lookups |cffFFFFFF" .. diag.resyncProbes .. "|r")
    self:Print("Proximity checks skipped just after loading a zone: |cffFFFFFF" .. diag.zoningSkips .. "|r")
    self:Print("Proximity alerts by name (enemy ID hidden): |cffFFFFFF" .. diag.nameKeyed .. "|r, hidden levels |cffFFFFFF" .. diag.levelHidden .. "|r")
    self:Print("Enemy-on-you checks blocked (target compare hidden): |cffFFFFFF" .. diag.compareHidden .. "|r")
    self:Print("Chat lines: sent |cffFFFFFF" .. diag.chatSent .. "|r, merged sightings |cffFFFFFF" .. diag.chatMerged .. "|r, throttled |cffFFFFFF" .. diag.chatThrottled .. "|r, blocked by chat lockdown |cffFFFFFF" .. diag.chatBlocked .. "|r")

    self:Print("Use |cffFFFF00/sa stats reset|r to clear")
end

local DRINK_SPELL_ID = 430
local DRINK_SPELL
local spellAlerts
local auraProbeSeen = {}

function SoundAlerter:ClearAuraTracking(unit)
    spellAlerts:Forget(unit)
end

local interrupts = SA_Interrupt.New()
local interruptFacts = {}
local castStartedAt = {}

local function ClearCastState(unit)
    interrupts:Forget(unit)
    castStartedAt[unit] = nil
end

local function InterrupterIsPlayer(interruptedBy)
    if interruptedBy == nil or issecretvalue(interruptedBy) then return nil end
    return interruptedBy == UnitGUID("player")
end

function SoundAlerter:AnnounceEnemyInterrupt(announcement)
    local enemyName, interruptedSpellID, abilitySpellID = announcement.name, announcement.spell, announcement.ability
    local unit, hiddenSpellID = announcement.unit, announcement.hidden
    if sadb.debugmode then
        self:Debug("Interrupt", "paired: %s interrupted with spell %s (interrupted spell %s); sound=%s chat=%s emote=%s",
            enemyName, tostring(abilitySpellID), tostring(interruptedSpellID or "unknown"),
            tostring(not sadb.interrupt), tostring(not sadb.chatalerts and sadb.interruptenemy and true or false), tostring(sadb.interruptemote and true or false))
    end
    if sadb.interruptemote then
        pcall(DoEmote, "ROAR")
    end
    local context = emitter:Context("interrupt")
    context.category = "interruptAlerts"
    if not sadb.interrupt then context.sound = SA_Interrupt.EnemySound(unit, sadb) end
    emitter:Emit(context)
    if not SA_AlertText.Ready(sadb.interruptenemy, "spells") then return end
    local interrupted = interruptedSpellID and (GetSpellLink(interruptedSpellID) or GetSpellInfo(interruptedSpellID))
    if not interrupted then interrupted = SA_AlertText.Hidden(HiddenSpellIcon(hiddenSpellID), "spell") end
    SA_AlertText.Say(sadb.InterruptEnemyText, { enemy = enemyName, spell = LinkOrName(abilitySpellID), interruptedspellname = interrupted }, "spells")
end

function SoundAlerter:ScheduleInterruptReady(spellID)
    if self.interruptReadyTimer then
        self:CancelTimer(self.interruptReadyTimer)
        self.interruptReadyTimer = nil
    end
    if not sadb.interruptReadyVoice then return end
    local known = SA_Interrupt.Cooldown(spellID)
    local store = SA_CooldownLearn.Store(self.db1.char)
    SA_CooldownLearn.Start(spellID, store, known)
    local cooldown = SA_CooldownLearn.Expected(store, spellID, known)
    if not cooldown then return end
    self.interruptReadyTimer = self:ScheduleTimer("InterruptReady", cooldown)
end

function SoundAlerter:InterruptReady()
    self.interruptReadyTimer = nil
    if sadb.interruptReadyVoice and not sadb.interrupt and emitter:Open("interruptReady") then
        local context = emitter:Context("interruptReady")
        context.sound = "interruptready.mp3"
        emitter:Emit(context)
    end
end

function SoundAlerter:RecordPlayerInterrupt(spellID)
    if not SA_Interrupt.IsInterrupt(spellID) then return end
    self:ScheduleInterruptReady(spellID)
    local announcement = interrupts:Cast("you", spellID, GetTime())
    if announcement then self:AnnounceEnemyInterrupt(announcement) end
end

function SoundAlerter:AnnounceSelfInterrupted(announcement)
    local spellID, ability = announcement.spell, announcement.ability
    spellAlerts:Custom("SPELL_INTERRUPT", nil, "player", spellID)
    if not sadb.interrupt then
        local interruptKey = self.spellList.interruptFriend[ability]
        if not interruptKey or sadb[interruptKey] then
            local context = emitter:Context("lockout")
            context.sound = "lockout.mp3"
            emitter:Emit(context)
        end
    end
    if SA_AlertText.Ready(sadb.interruptself, "spells") then
        SA_AlertText.Say(sadb.InterruptSelfText, { spell = LinkOrName(ability), interruptedspellname = LinkOrName(spellID), enemy = announcement.name }, "spells")
    end
end

local unitKindCache = {}
local hostileCache = {}

local function ReadHostilePlayer(unit)
    return UnitExists(unit) and Plain(UnitIsPlayer(unit)) == true and Plain(UnitIsEnemy("player", unit)) == true or false
end

local function HostilePlayer(unit)
    local cached = hostileCache[unit]
    if cached ~= nil then return cached end
    return ReadHostilePlayer(unit)
end
SoundAlerter.HostilePlayer = HostilePlayer

local function HostilePet(unit)
    return Plain(UnitIsEnemy("player", unit)) == true and Plain(UnitPlayerControlled(unit)) == true and Plain(UnitIsPlayer(unit)) == false
end

local function UnitKind(unit)
    local kind = unitKindCache[unit]
    if kind == nil then
        if unit:match("^arena%d$") then
            kind = "arena"
        elseif unit:match("^nameplate%d+$") then
            kind = "nameplate"
        elseif unit:match("^party%d$") then
            kind = "party"
        else
            kind = false
        end
        unitKindCache[unit] = kind
    end
    return kind
end

function SoundAlerter:InvalidateTrackedAuraIDs()
    spellAlerts:Use(sadb, self.spellList, SoundAlerterPetAuras)
end

local function ReadableSourceUnit(aura)
    local sourceUnit = aura.sourceUnit
    if sourceUnit == nil or issecretvalue(sourceUnit) then return nil end
    return sourceUnit
end

local function DescribeField(value)
    if value == nil then return "nil" end
    if issecretvalue(value) then return "SECRET" end
    return "ok"
end

function SoundAlerter:ProbeAuraUpdate(unit, kind, updateInfo, path)
    local combat = InCombatLockdown() and "combat" or "idle"
    local key = kind .. ":" .. combat
    if auraProbeSeen[key] then return end
    auraProbeSeen[key] = true

    local info, full, added, removed, firstSpell = "nil", "n/a", "n/a", "n/a", "n/a"
    if updateInfo ~= nil then
        if issecretvalue(updateInfo) then
            info = "SECRET"
        else
            info = "ok"
            full = DescribeField(updateInfo.isFullUpdate)
            added = DescribeField(updateInfo.addedAuras)
            removed = DescribeField(updateInfo.removedAuraInstanceIDs)
            if added == "ok" and updateInfo.addedAuras[1] then
                firstSpell = DescribeField(updateInfo.addedAuras[1].spellId)
            end
        end
    end
    self:Debug("AuraProbe", "%s (%s, %s) -> %s: updateInfo=%s isFullUpdate=%s added=%s removed=%s addedSpellId=%s",
        unit, kind, combat, path or "?", info, full, added, removed, firstSpell)
end

local lossOfControlState = { lastSpoken = {} }

function SoundAlerter:LOSS_OF_CONTROL_ADDED(event, first, second)
    if not sadb.lossOfControlVoice then return end
    if not (C_LossOfControl and C_LossOfControl.GetActiveLossOfControlData) then return end
    local index = SA_LossOfControl.PlayerIndex(Plain(first), Plain(second))
    if not index then return end
    if not emitter:Open("lossOfControl") then return end
    local ok, data = pcall(C_LossOfControl.GetActiveLossOfControlData, index)
    if not ok or type(data) ~= "table" then return end
    local category = SA_LossOfControl.Category(Plain(data.locType))
    if not category then return end
    local now = GetTime()
    if not SA_LossOfControl.ShouldSpeak(sadb, lossOfControlState, category, now) then return end
    lossOfControlState.lastSpoken[category] = now
    self:Debug("LossOfControl", "%s (%s)", category, tostring(Plain(data.locType)))
    local context = emitter:Context("lossOfControl")
    context.sound, context.category = SA_LossOfControl.Voice(category), "lossOfControlAlerts"
    emitter:Emit(context)
end

local probeLog = SA_DebugLog.NewProbe(function(value) return issecretvalue(value) end)

function SoundAlerter:ProbeValue(tag, ...)
    if not (sadb and sadb.debugmode) then return end
    local zone = SA_ZoneKind.Kind()
    local combat = InCombatLockdown() and "combat" or "idle"
    local fresh, key = probeLog.Record(tag .. " [" .. zone .. "," .. combat .. "]", ...)
    if fresh then
        self:Debug("Probe", "%s", key)
    end
end

function SoundAlerter:ProbeNameplate(unit)
    local _, class = UnitClass(unit)
    self:ProbeValue("plate name/class/guid", UnitName(unit), class, UnitGUID(unit))
    if Plain(UnitIsPlayer(unit)) then
        self:ProbeValue("plate guild", (GetGuildInfo(unit)))
    else
        self:ProbeValue("plate npc name/creature type", UnitName(unit), UnitCreatureType(unit))
    end
    local ok, same = pcall(UnitIsUnit, unit .. "target", "player")
    if ok then
        self:ProbeValue("plate targets player", same)
    else
        self:ProbeValue("plate targets player (error)")
    end
end

function SoundAlerter:PrintProbeReport()
    local function describe(value)
        return SA_DebugLog.Describe(value, function(v) return issecretvalue(v) end)
    end
    local function line(label, ...)
        local parts = {}
        for index = 1, select("#", ...) do
            parts[index] = describe((select(index, ...)))
        end
        self:Print("  " .. label .. ": " .. table.concat(parts, " "))
    end

    self:Print("|cffFFD700=== SoundAlerter probe report ===|r")
    if not (sadb and sadb.debugmode) then
        self:Print("Debug mode is off: event probes record nothing until it is on. Snapshot below still works.")
    end
    line("zone", SA_ZoneKind.Kind(), SA_ZoneKind.Reported())
    line("combat lockdown", InCombatLockdown())

    if Enum and Enum.AddOnRestrictionType and C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState then
        for name, value in pairs(Enum.AddOnRestrictionType) do
            local ok, state = pcall(C_RestrictedActions.GetAddOnRestrictionState, value)
            line("restriction " .. name, ok and state or "error")
        end
    end

    if C_CombatAudioAlert and C_CombatAudioAlert.IsEnabled then
        line("Blizzard combat audio alerts", pcall(C_CombatAudioAlert.IsEnabled))
    else
        line("Blizzard combat audio alerts", nil)
    end

    if C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount then
        local ok, count = pcall(C_LossOfControl.GetActiveLossOfControlDataCount)
        line("loss of control active", ok and count or "error")
        if ok and type(count) == "number" and count > 0 and C_LossOfControl.GetActiveLossOfControlData then
            local okData, data = pcall(C_LossOfControl.GetActiveLossOfControlData, 1)
            if okData and type(data) == "table" then
                line("loss of control #1", data.locType, data.spellID, data.displayText, data.lockoutSchool, data.duration)
            end
        end
    end

    if C_PvP and C_PvP.GetScoreInfo then
        local ok, info = pcall(C_PvP.GetScoreInfo, 1)
        if ok and type(info) == "table" then
            line("scoreboard #1 name/class/guid", info.name, info.classToken, info.guid)
        else
            line("scoreboard #1", ok and info or "error")
        end
    end

    if self.AuraSoundSummary then
        local summary, enemyTarget, enemyFocus = self:AuraSoundSummary()
        line("engine aura sounds on", sadb and sadb.engineAuraSounds or false)
        line("engine registered", summary)
        line("engine enemy target/focus", enemyTarget, enemyFocus)
        local count, spells, units, failed, lastError = self:BattleVoiceSummary()
        line("battle voices on/zone", sadb and sadb.battleVoices or false, self:BattleVoiceZone())
        line("battle voices registered/spells/units/failed", count, spells, units, failed, lastError)
        local waiting, at, match, restriction = self:BattleVoiceStatus()
        line("battle voices state/last change/match then", waiting, at, match)
        line("now combat/restrictions/match", InCombatLockdown() and true or false, self:ActiveRestrictions(), self:MatchStateName())
        line("last restriction change", restriction)
    end

    if UnitExists("target") then
        local _, class = UnitClass("target")
        line("target name/class/guid", UnitName("target"), class, UnitGUID("target"))
        line("target guild", GetGuildInfo("target"))
        line("target spell target name/class", UnitSpellTargetName and UnitSpellTargetName("target"), UnitSpellTargetClass and UnitSpellTargetClass("target"))
        line("target distance squared/checked", UnitDistanceSquared and select(2, pcall(UnitDistanceSquared, "target")), UnitDistanceSquared and select(3, pcall(UnitDistanceSquared, "target")))
        line("target interact distance 4", pcall(CheckInteractDistance, "target", 4))
        if C_Secrets and C_Secrets.ShouldUnitComparisonBeSecret then
            line("comparison secret target/player", pcall(C_Secrets.ShouldUnitComparisonBeSecret, "target", "player"))
        end
    else
        self:Print("  No target: select an enemy player to include the target lines.")
    end

    local rows = probeLog.Report()
    self:Print(string.format("|cffFFD700=== Recorded event probes (%d) ===|r", #rows))
    for _, row in ipairs(rows) do
        self:Print("  " .. row)
    end
end

local WATCH_TOKENS = { "target", "focus" }

local STEALTH_LOG_CAP = 80

function SoundAlerter:StealthLog(fmt, ...)
    if not sadb.debugmode then return end
    self:Debug("Stealth", fmt, ...)
    local global = self.db1.global
    local log = global.stealthLog
    if not log then
        log = {}
        global.stealthLog = log
    end
    local ok, text = pcall(string.format, fmt, ...)
    log[#log + 1] = string.format("%.1f %s", GetTime(), ok and text or tostring(fmt))
    if #log > STEALTH_LOG_CAP then table.remove(log, 1) end
end

function SoundAlerter:AlertSharedStealth(guid, spellID, name)
    return spellAlerts:SharedStealth(guid, spellID, name)
end

local function FindWatchedUnit(guid)
    if sadb.myself then
        for _, token in ipairs(WATCH_TOKENS) do
            if UnitExists(token) and Plain(UnitGUID(token)) == guid then return token end
        end
    end
    if sadb.enemyinrange or sadb.stealthAnyEnemy then
        for unit, plateGUID in pairs(SA_Plates.Enemies()) do
            if plateGUID == guid then return unit end
        end
    end
    return nil
end

function SoundAlerter:StealthWatchTick()
    if spellAlerts:Tick() then return end
    self:CancelTimer(self.stealthTimer)
    self.stealthTimer = nil
end

function SoundAlerter:MatchesUidFilter(unit, filterKey, customName)
    if not filterKey or filterKey == "any" then return true end
    if filterKey == "custom" then
        if not unit then return false end
        local name = SafeUnitName(unit)
        return name ~= nil and name == customName
    end
    if not unit then return false end
    if filterKey == "party" then
        for i = 1, 4 do
            if UnitIsUnit(unit, "party"..i) then return true end
        end
        return false
    end
    if filterKey == "arena" then
        for i = 1, 5 do
            if UnitIsUnit(unit, "arena"..i) then return true end
        end
        return false
    end
    return UnitIsUnit(unit, filterKey)
end

function SoundAlerter:MatchesTypeFilter(unit, filterKey)
    if not filterKey or filterKey == FILTER_TYPE_ANY then return true end
    if not unit or not UnitExists(unit) then return false end
    if filterKey == FILTER_TYPE_ME then return UnitIsUnit(unit, "player") end
    if filterKey == FILTER_TYPE_HOSTILE_PLAYER then return HostilePlayer(unit) end
    if filterKey == FILTER_TYPE_FRIENDLY then return Plain(UnitIsEnemy("player", unit)) == false end
    if filterKey == FILTER_TYPE_HOSTILE_UNIT then return Plain(UnitIsEnemy("player", unit)) == true end
    return true
end

local resyncContexts = setmetatable({}, {
    __index = function(cache, unit)
        local context = {}
        cache[unit] = context
        return context
    end,
})

local resyncQueue = SA_Coalesce.New(function(flush) C_Timer.After(0, flush) end, function(unit, context)
    local secretAdded = context.secretAdded
    context.secretAdded = nil
    if not UnitExists(unit) then return end
    spellAlerts:Resync(unit, context.role, secretAdded)
end)

local function QueueResync(unit, role, secretAdded)
    local context = resyncContexts[unit]
    context.role = role
    if secretAdded then context.secretAdded = true end
    resyncQueue.Request(unit, context)
end

local PROBE_PATH = { first = "resync (first sight)", unreadable = "resync (payload unreadable)", delta = "delta" }

function SoundAlerter:UNIT_AURA(event, unit, updateInfo)
    if not unit then return end

    local isPlayer = unit == "player"
    local isTargetOrFocus = not isPlayer and (unit == "target" or unit == "focus")
    local kind = not isPlayer and not isTargetOrFocus and UnitKind(unit)
    local isArena = kind == "arena"
    local isNameplate = kind == "nameplate"
    local isAlly = kind == "party"

    if not (isPlayer or isTargetOrFocus or isArena or isNameplate or isAlly) then return end
    if isNameplate and not self:IsTrackedNameplate(unit) then return end
    if not UnitExists(unit) then return end

    if isArena then
        if SA_ZoneKind.Kind() == "arena" and sadb.drinking then
            if DRINK_SPELL == nil then
                DRINK_SPELL = GetSpellInfo(DRINK_SPELL_ID) or false
            end
            if DRINK_SPELL and UnitAura(unit, DRINK_SPELL) then
                local context = emitter:Context("drinking")
                context.sound = "drinking.mp3"
                emitter:Emit(context)
            end
        end
        return
    end

    local petOnly = false
    if not isPlayer and not isAlly and not HostilePlayer(unit) then
        if not (isTargetOrFocus and SoundAlerterPetAuras and HostilePet(unit)) then return end
        petOnly = true
    end
    if isAlly and (Plain(UnitIsPlayer(unit)) ~= true or Plain(UnitIsEnemy("player", unit)) ~= false) then return end
    if not emitter:Open("spell") then
        if isTargetOrFocus then self:StealthLog("%s aura update ignored: zone gate", unit) end
        return
    end

    local role = isPlayer and "player" or isAlly and "ally" or isTargetOrFocus and "watched" or "nearby"
    local path, resync = spellAlerts:Aura(unit, role, updateInfo, petOnly)
    if resync then QueueResync(unit, role, resync == "secret") end
    if sadb.debugmode then
        local probeKind = isPlayer and "player" or isTargetOrFocus and unit or isNameplate and "nameplate" or "party"
        self:ProbeAuraUpdate(unit, probeKind, updateInfo, PROBE_PATH[path])
    end
end

local CLASS_AUDIO_MAP = {
    ["WARRIOR"] = "Warrior",
    ["MAGE"] = "Mage",
    ["PRIEST"] = "Priest",
    ["ROGUE"] = "Rogue",
    ["HUNTER"] = "Hunter",
    ["DRUID"] = "druid",
    ["PALADIN"] = "Paladin",
    ["WARLOCK"] = "Warlock",
    ["SHAMAN"] = "Shaman",
    ["DEATHKNIGHT"] = "Deathknight"
}
SoundAlerter.CLASS_AUDIO_MAP = CLASS_AUDIO_MAP

spellAlerts = SA_SpellAlerts.New({
    Play = function(list, spellID, unit, guid, name) return emitter:Spell(list, spellID, unit, guid, name) end,
    Ready = SA_AlertText.Ready,
    Say = SA_AlertText.Say,
    Log = function(...) SoundAlerter:StealthLog(...) end,
    Debug = function(...) SoundAlerter:Debug(...) end,
    CustomSound = function(file)
        local context = emitter:Context("custom")
        context.sound, context.custom = file, true
        emitter:Emit(context)
    end,
    SelfDebuff = function() lossOfControlState.lastSelfDebuffAt = GetTime() end,
    TrapLanded = function(sourceUnit, spellID)
        local toasts = SoundAlerter.ProximityToasts
        if not toasts then return end
        local trapper = Plain(UnitGUID(sourceUnit))
        if trapper then toasts:OnTrapLanded(trapper, spellID) end
    end,
    Share = function(unit, guid, spellID, name)
        SoundAlerter:ShareAlert("S", guid, spellID, SafeUnitClass(unit), nil, name)
    end,
    Watch = function()
        if not SoundAlerter.stealthTimer then
            SoundAlerter.stealthTimer = SoundAlerter:ScheduleRepeatingTimer("StealthWatchTick", 1)
        end
    end,
    EnemyCast = function(spellID, name) interrupts:Cast("enemy", spellID, GetTime(), name) end,
    Trinket = function(unit, guid, name)
        local class = SafeUnitClass(unit)
        if class and sadb.class then
            local classAudioFile = CLASS_AUDIO_MAP[class]
            if classAudioFile then
                local context = emitter:Context("trinket")
                context.sound = classAudioFile .. ".mp3"
                emitter:Emit(context)
            end
            SoundAlerter:ScheduleTimer(function() SoundAlerter:PlayTrinket(guid, name) end, 0.4)
        else
            SoundAlerter:PlayTrinket(guid, name)
        end
    end,
    Probed = function(count, secretAdded)
        local diag = SoundAlerter.diag
        diag.resyncProbes = diag.resyncProbes + count
        if secretAdded then
            diag.resyncSecretAdded = diag.resyncSecretAdded + 1
        else
            diag.resyncFirstOrUnreadable = diag.resyncFirstOrUnreadable + 1
        end
    end,
}, {
    Name = SafeUnitName,
    GUID = function(unit) return Plain(UnitGUID(unit)) end,
    Link = function(spellID) return GetSpellLink(spellID) or GetSpellInfo(spellID) end,
    SpellName = function(spellID) return (GetSpellInfo(spellID)) end,
    Secret = issecretvalue,
    Now = GetTime,
    Engine = function(unit, trigger, spellID) return SoundAlerter:HasEngineAuraSound(unit, trigger, spellID) end,
    BattleVoices = function() return SoundAlerter.battleVoiceList ~= nil end,
    Range = function(unit) return SoundAlerter:GetApproxRange(unit) end,
    ZoneAllowed = function() return SoundAlerter:IsAlertZoneAllowed() end,
    FindWatched = FindWatchedUnit,
    MatchUnit = function(unit, filter, name) return SoundAlerter:MatchesUidFilter(unit, filter, name) end,
    MatchType = function(unit, filter) return SoundAlerter:MatchesTypeFilter(unit, filter) end,
    Aura = function(unit, spellID)
        local ok, data = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
        if not ok or data == nil or issecretvalue(data) then return false end
        local instance = data.auraInstanceID
        if instance ~= nil and issecretvalue(instance) then instance = nil end
        return true, instance, ReadableSourceUnit(data)
    end,
})

local MEDIUM_RANGE_ITEM = 18904

local function WithinMediumRange(unit)
    local check = (C_Item and C_Item.IsItemInRange) or IsItemInRange
    if not check then return false end
    local ok, inRange = pcall(check, MEDIUM_RANGE_ITEM, unit)
    return ok and Plain(inRange) == true
end

local function WithinInteractRange(unit, index)
    if InCombatLockdown() then return false end
    local ok, inRange = pcall(CheckInteractDistance, unit, index)
    return ok and Plain(inRange) == true
end

function SoundAlerter:GetApproxRange(unit)
    if not UnitExists(unit) then return nil end

    if WithinInteractRange(unit, 3) then
        return "Close"
    elseif WithinInteractRange(unit, 1) then
        return "Nearby"
    elseif WithinMediumRange(unit) then
        return "Medium"
    elseif UnitIsVisible(unit) then
        return "Detected"
    end

    return nil
end

local quietState = {}

function SoundAlerter:IsQuiet()
    quietState.onTaxi = UnitOnTaxi("player") and true or false
    quietState.dead = UnitIsDeadOrGhost("player") and true or false
    quietState.pvpFlagged = not UnitIsPVP or UnitIsPVP("player") or (UnitIsPVPFreeForAll and UnitIsPVPFreeForAll("player")) or false
    quietState.snoozeUntil = self.snoozeUntil
    return SA_QuietRules.Reason(sadb, quietState, GetTime()) ~= nil
end

function SoundAlerter:Snooze(minutes)
    self.snoozeUntil = SA_QuietRules.SnoozeUntil(GetTime(), minutes or sadb.snoozeMinutes)
    self:Print(string.format("Proximity and enemy awareness alerts snoozed for %d minutes. /sa unsnooze to cancel.", math.floor((self.snoozeUntil - GetTime()) / 60 + 0.5)))
end

function SoundAlerter:Unsnooze()
    self.snoozeUntil = nil
    self:Print("Snooze cancelled.")
end

local ENEMY_ON_YOU = {
    targeting = { setting = "enemyTargetsYou", voice = "targetingyou.mp3" },
    casting = { setting = "enemyCastingAtYou", voice = "castingonyou.mp3", spacing = 3 },
}

local function EnemyTargetsPlayer(unit)
    local token = SA_TargetToken[unit]
    local gate = C_Secrets and C_Secrets.ShouldUnitComparisonBeSecret
    if gate then
        local ok, secret = pcall(gate, token, "player")
        if not ok or secret then return nil end
    end
    local ok, same = pcall(UnitIsUnit, token, "player")
    if not ok then return nil end
    return Plain(same)
end

function SoundAlerter:AlertEnemyOnYou(unit, kind)
    local rule = ENEMY_ON_YOU[kind]
    if not sadb[rule.setting] then return end
    if not HostilePlayer(unit) then return end
    if not emitter:Open("enemyOnYou") then return end
    local guid = SA_Plates.UnitKey(unit)
    if not guid then return end
    local now = GetTime()
    if not SA_Spacing.Ready(self.enemyOnYouAt, kind, guid, now, rule.spacing or sadb.enemyTargetsYouCooldown or 8) then return end
    local targetsYou = EnemyTargetsPlayer(unit)
    if targetsYou == nil then self.diag.compareHidden = self.diag.compareHidden + 1 end
    if targetsYou ~= true then return end
    SA_Spacing.Mark(self.enemyOnYouAt, kind, guid, now)
    self:Debug("Targeting", "%s on you from %s", kind, unit)
    local context = emitter:Context("enemyOnYou")
    context.sound, context.category = rule.voice, "awarenessAlerts"
    emitter:Emit(context)
end

local groupUnitCache = {}

local function IsGroupUnit(unit)
    local is = groupUnitCache[unit]
    if is == nil then
        is = (unit:match("^party%d$") or unit:match("^raid%d+$")) and true or false
        groupUnitCache[unit] = is
    end
    return is
end

function SoundAlerter:CheckAllyVision(unit)
    local spotted = SA_TargetToken[unit]
    if sadb.debugmode then
        self:ProbeValue("ally target exists/visible/player/enemy", UnitExists(spotted), UnitIsVisible(spotted), UnitIsPlayer(spotted), UnitIsEnemy("player", spotted))
        local _, class = UnitClass(spotted)
        self:ProbeValue("ally target name/class/guid", UnitName(spotted), class, UnitGUID(spotted))
    end
    self.Proximity:Consider(spotted, true)
end

function SoundAlerter:UNIT_TARGET(event, unit)
    if IsGroupUnit(unit) and (sadb.proximityAllyVision or sadb.debugmode) then
        self:CheckAllyVision(unit)
        return
    end
    if not sadb.enemyTargetsYou then return end
    if UnitKind(unit) ~= "nameplate" then return end
    self:AlertEnemyOnYou(unit, "targeting")
end

function SoundAlerter:UNIT_NAME_UPDATE(event, unit)
    if not (sadb.proximityEnabled or sadb.watchlistEnabled) then return end
    if UnitKind(unit) ~= "nameplate" then return end
    self:CheckWatchlist(unit)
    self.Proximity:Consider(unit)
end

function SoundAlerter:UNIT_FACTION(event, unit)
    if unit == "target" or unit == "focus" then hostileCache[unit] = ReadHostilePlayer(unit) end
    self:UNIT_NAME_UPDATE(event, unit)
end

function SoundAlerter:PLAYER_TARGET_CHANGED()
    hostileCache.target = ReadHostilePlayer("target")
    ClearCastState("target")
    self:ClearAuraTracking("target")
    self:RefreshEnemyAuraUnits()
    self:CheckWatchlist("target")
    self.Proximity:Consider("target")
end

function SoundAlerter:PLAYER_FOCUS_CHANGED()
    hostileCache.focus = ReadHostilePlayer("focus")
    ClearCastState("focus")
    self:ClearAuraTracking("focus")
    self:RefreshEnemyAuraUnits()
end

function SoundAlerter:UPDATE_MOUSEOVER_UNIT()
    self:CheckWatchlist("mouseover")
    self.Proximity:Consider("mouseover")
end

function SoundAlerter:NAME_PLATE_UNIT_ADDED(event, unit)
    if sadb.debugmode then self:ProbeNameplate(unit) end
    SA_Plates.Remove(unit)
    if not HostilePlayer(unit) then return end

    local key = SA_Plates.UnitKey(unit)
    if not key then return end

    SA_Plates.Add(unit, key)

    self:CheckWatchlist(unit)
    self.Proximity:Consider(unit)
end

function SoundAlerter:NAME_PLATE_UNIT_REMOVED(event, unit)
    SA_Plates.Remove(unit)
    ClearCastState(unit)
    self:ClearAuraTracking(unit)
end

function SoundAlerter:IsTrackedNameplate(unit)
    return SA_Plates.IsEnemy(unit)
end

local ARENA_TARGET_UNITS = { "arena1target", "arena2target", "arena3target", "arena4target", "arena5target" }

local function IsRelevantCastUnit(unit)
    if unit == "target" or unit == "focus" then return true end
    local kind = UnitKind(unit)
    return kind == "nameplate" or kind == "arena"
end

local CAST_END_WINDOW = 12

function SoundAlerter:AlertInstantOnYou(unit)
    local started = castStartedAt[unit]
    if started then
        castStartedAt[unit] = nil
        if GetTime() - started <= CAST_END_WINDOW then return end
    end
    self:AlertEnemyOnYou(unit, "casting")
end

function SoundAlerter:RetryPendingIdentity(unit)
    local guid = SA_Plates.GUID(unit)
    if guid and SA_Plates.IsPending(guid) then
        self.Proximity:Consider(unit)
    end
end

function SoundAlerter:SubscribeCastEvents()
    local retry = function(unit) self:RetryPendingIdentity(unit) end
    SA_CastDispatch.Subscribe("pendingidentity", {
        UNIT_SPELLCAST_START = retry,
        UNIT_SPELLCAST_CHANNEL_START = retry,
        UNIT_SPELLCAST_SUCCEEDED = retry,
    })
    SA_CastDispatch.Subscribe("alerts", {
        UNIT_SPELLCAST_START = function(unit, castGUID, spellID)
            self:UNIT_SPELLCAST_START("UNIT_SPELLCAST_START", unit, castGUID, spellID)
        end,
        UNIT_SPELLCAST_SUCCEEDED = function(unit, castGUID, spellID)
            self:UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED", unit, castGUID, spellID)
        end,
        UNIT_SPELLCAST_INTERRUPTED = function(unit, castGUID, spellID, interruptedBy)
            self:UNIT_SPELLCAST_INTERRUPTED("UNIT_SPELLCAST_INTERRUPTED", unit, castGUID, spellID, interruptedBy)
        end,
    })
end

function SoundAlerter:UNIT_SPELLCAST_START(event, unit, castGUID, spellID)
    if unit == "target" or unit == "focus" or unit == "mouseover" then
        interrupts:CastStarted(unit, not issecretvalue(spellID) and spellID or nil, GetTime())
    end
    if not unit or not IsRelevantCastUnit(unit) then return end
    if not emitter:Open("spell") then return end
    if not HostilePlayer(unit) then return end
    castStartedAt[unit] = GetTime()
    self:AlertEnemyOnYou(unit, "casting")
    if issecretvalue(spellID) then return end

    local isTargetOrFocus = (unit == "target" or unit == "focus")
    local isTracked = not isTargetOrFocus and self:IsTrackedNameplate(unit)
    local isArenaEnemy = not isTargetOrFocus and not isTracked and UnitKind(unit) == "arena"

    if isArenaEnemy then
        if sadb.dArenaPartner then return end
        if SA_ZoneKind.Kind() ~= "arena" then return end
        for i = 1, #ARENA_TARGET_UNITS do
            if playerName == SafeUnitName(ARENA_TARGET_UNITS[i]) then return end
        end
        emitter:Spell(self.spellList.friendCCs, spellID, unit)
        return
    end

    if not (isTargetOrFocus or isTracked) then return end

    spellAlerts:Cast(unit, isTargetOrFocus and "watched" or "nearby", "start", spellID)
end

function SoundAlerter:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
    if unit == "player" or (unit == "pet" and sadb.interruptPets) then
        self:RecordPlayerInterrupt(spellID)
        return
    end
    if not unit or not IsRelevantCastUnit(unit) then return end
    if not emitter:Open("spell") then return end
    if not HostilePlayer(unit) then return end
    self:AlertInstantOnYou(unit)
    if issecretvalue(spellID) then return end

    local isTargetOrFocus = (unit == "target" or unit == "focus")
    local isTracked = not isTargetOrFocus and self:IsTrackedNameplate(unit)
    if not (isTargetOrFocus or isTracked) then return end
    spellAlerts:Cast(unit, isTargetOrFocus and "watched" or "nearby", "success", spellID)
end

function SoundAlerter:UNIT_SPELLCAST_INTERRUPTED(event, unit, castGUID, spellID, interruptedBy)
    if unit ~= "player" and unit ~= "target" and unit ~= "focus" and unit ~= "mouseover" then return end
    castStartedAt[unit] = nil
    if not emitter:Open("interrupt") then return end
    if sadb.debugmode then
        self:ProbeValue("interrupted " .. unit .. " spell/by", spellID, interruptedBy)
        if interruptedBy ~= nil and not issecretvalue(interruptedBy) then
            self:ProbeValue("interrupted " .. unit .. " by is player", interruptedBy == UnitGUID("player"))
        end
    end
    local now = GetTime()
    local facts = interruptFacts
    facts.unit = unit
    if issecretvalue(spellID) then
        if unit == "player" then return end
        facts.spellID, facts.hidden = nil, spellID
    else
        facts.spellID, facts.hidden = spellID, nil
    end
    if unit == "player" then
        facts.isEnemy, facts.name, facts.byPlayer = nil, nil, nil
        local announcement = interrupts:Interrupted(facts, now, sadb)
        if announcement then self:AnnounceSelfInterrupted(announcement) end
        return
    end
    facts.isEnemy = UnitExists(unit) and Plain(UnitIsEnemy("player", unit)) == true or false
    facts.name = SafeUnitName(unit)
    facts.byPlayer = InterrupterIsPlayer(interruptedBy)
    local announcement, readable, reason = interrupts:Interrupted(facts, now, sadb)
    facts.hidden = nil
    if readable then
        spellAlerts:Custom("SPELL_INTERRUPT", nil, unit, readable)
    end
    if announcement then
        self:AnnounceEnemyInterrupt(announcement)
    elseif reason and sadb.debugmode then
        self:Debug("Interrupt", "%s not announced: %s", unit, reason)
    end
end
