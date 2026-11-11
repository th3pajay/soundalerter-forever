
SoundAlerter = LibStub("AceAddon-3.0"):NewAddon("SoundAlerter", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
local self, SoundAlerter = SoundAlerter, SoundAlerter

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SoundAlerter")
local GetSpellInfo, GetSpellLink = SA_COMPAT.GetSpellInfo, SA_COMPAT.GetSpellLink
local GetZonePVPInfo = SA_COMPAT.GetZonePVPInfo
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
local stealthState = SA_StealthWatch.New()

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
	SA_Secret.SetEnabled(sadb.hiddenSpells)
	SA_Secret.Reset()
	self:InvalidateTrackedAuraIDs()
	self:UpdateScoreboardTracking()
	self:ApplyTotemPlates()
	self:ApplyNameplateRange()
	self:UpdatePartyShare()
	self:UpdateGlobalSight()
	if self.UpdateCheck then self.UpdateCheck:Refresh() end
	self:OnOptionsProfileChanged()

	for _,v in SoundAlerter:IterateModules() do
		if type(v.ChangeProfile) == 'function' then
			v:ChangeProfile()
		end
	end

	if self.ProximityToasts then
		self.ProximityToasts:OnProfileChanged()
	end

	if self.ResourceBar then
		self.ResourceBar:OnProfileChanged()
	end

	if self.CastingBars then
		self.CastingBars:OnProfileChanged()
	end

	if self.SpellTracker then
		self.SpellTracker:OnProfileChanged()
	end

	if self.CastFeed then
		self.CastFeed:OnProfileChanged()
	end

	if self.AuraDisplay then
		self.AuraDisplay:Refresh(true)
	end

	if self.SpeedMeter then
		self.SpeedMeter:OnProfileChanged()
	end

	if self.TrinketMenu then
		self.TrinketMenu:OnProfileChanged()
	end

	if self.DRTracker then
		self.DRTracker:OnProfileChanged()
	end

	if self.FlagAlerts then
		self.FlagAlerts:OnProfileChanged()
	end

	if self.MinimapTracking then
		self.MinimapTracking:OnProfileChanged()
	end

	self:UpdateMinimapButtonIcon()

	if self.Footsteps then
		self.Footsteps:OnProfileChanged()
	end

	if self.Notices then
		self.Notices:OnProfileChanged()
	end

	if sadb.statistics and sadb.statistics.enabled then
		local Statistics = self:GetModule("Statistics")
		if Statistics then
			Statistics:InitializeStatistics()
		end
	end
end

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

local rearmSeconds, rearmAt = {}, {}

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
    sadb = self.db1.profile

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

function SoundAlerter:InitializeModule(moduleName)
    local module = self[moduleName]
    if not module then return end

    local ok, err = pcall(module.Initialize, module)
    if not ok then
        self:Print("|cffFF7D0ASoundAlerter|r: "..moduleName.." failed to initialize and has been disabled for this session — "..tostring(err))
        self.moduleInitErrors[moduleName] = tostring(err)
        self[moduleName] = nil
    end
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
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("UNIT_TARGET")
    self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
    pcall(self.RegisterEvent, self, "LOSS_OF_CONTROL_ADDED")
    self:RegisterEvent("PLAYER_LOGOUT")

    self:RefreshZoneState()

    if not self.SA_LANGUAGE[sadb.path] then sadb.path = self.SA_LOCALEPATH.enUS end

    self.proximityAlertCache = {}
    self.identityRetryAt = {}
    self.enemyOnYouAt = {}
    SA_Plates.Reset()
    SA_StealthWatch.Reset(stealthState)
    self.stealthTimer = nil
    SA_Secret.SetEnabled(sadb.hiddenSpells)
    self:SubscribeCastEvents()
    self.enterWorldTime = 0

    self:ApplyNameplateRange()
    self:ApplyTotemPlates()
    self:UpdatePartyShare()
    self:UpdateGlobalSight()
    if self.UpdateCheck then self.UpdateCheck:Refresh() end

    self:ResetDiagnostics()

    self:InitializeModule("ProximityToasts")
    self:InitializeModule("ResourceBar")
    self:InitializeModule("CastingBars")
    self:InitializeModule("SpellTracker")
    self:InitializeModule("CastFeed")
    self:InitializeModule("AuraDisplay")
    self:InitializeModule("SpeedMeter")
    self:InitializeModule("TrinketMenu")
    self:InitializeModule("DRTracker")
    self:InitializeModule("MinimapTracking")
    self:InitializeModule("Footsteps")
    self:InitializeModule("SpellTest")
    self:InitializeModule("Notices")
    self:CheckQuickStartSetup()

    local Statistics = self:GetModule("Statistics")
    if Statistics then
        local ok, err = pcall(Statistics.Enable, Statistics)
        if not ok then
            self:Print("|cffFF7D0ASoundAlerter|r: Statistics failed to initialize and has been disabled for this session — "..tostring(err))
            self.moduleInitErrors.Statistics = tostring(err)
        end
    end

    self:StartAuraSounds()

    self:ScheduleRepeatingTimer("CleanupProximityCaches", 30)
    self:ScheduleRepeatingTimer("RescanTrackedNameplates", 1)

end

function SoundAlerter:PlayTrinket(sourceGUID, sourceName)
    SoundAlerter:PlayVoice(sadb.sapath.."Trinket.mp3");

    if sadb.statistics and sadb.statistics.enabled then
        local Statistics = self:GetModule("Statistics")
        if Statistics then
            Statistics:RecordAlert("trinketAlerts", nil, sourceGUID, sourceName)
        end
    end
end

function SoundAlerter:Interrupted()
    SoundAlerter:PlayVoice(sadb.sapath.."Interrupted.mp3");
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
    local ok = PlaySoundFile and pcall(PlaySoundFile, path, channel)
    if not ok then
        self.voiceFailures = self.voiceFailures + 1
        if self.voiceFailures == 1 then
            self:Print("Voice playback unavailable on this client.")
        end
        self:Debug("Sound", "playback failed (%d): %s", self.voiceFailures, tostring(path))
    end
    return ok
end

function SoundAlerter:RecordStat(category)
    if not (sadb.statistics and sadb.statistics.enabled) then return end
    local statistics = self:GetModule("Statistics")
    if statistics then statistics:RecordAlert(category) end
end

function SoundAlerter:SendChat(message, channels)
    if IsChatBlocked() then
        self:Debug("Chat", "not sent, chat is locked down: %s", message)
        return false
    end
    local sent = false
    local inInstance = IsInInstance()
    local targets = {}
    for _, channel in ipairs(channels) do
        local target, reason = ResolveChatChannel(channel, inInstance)
        if target then
            targets[#targets + 1] = target
        else
            self:Debug("Chat", "%s skipped, %s", channel, reason)
        end
    end
    for _, target in ipairs(SA_ChatTargets.Pick(targets)) do
        if pcall(SendChatMessage, message, target, nil, nil) then
            sent = true
            self:Debug("Chat", "sent to %s: %s", target, message)
        else
            self:Debug("Chat", "%s send failed", target)
        end
    end
    if sent then self:RecordStat("chatAlerts") end
    return sent
end

local LOCAL_PREFIX = "|cff33ff99SoundAlerter|r: "
local DOWN_TEMPLATE = "#spell# down on #enemy#"

local chatChannels = {}

local function SendPlain(message)
    for i = #chatChannels, 1, -1 do chatChannels[i] = nil end
    for channel, enabled in pairs(sadb.chatgroups) do
        if enabled and channel ~= "NONE" then
            chatChannels[#chatChannels + 1] = channel
        end
    end
    return SoundAlerter:SendChat(message, chatChannels)
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

local function Link(spellID)
    return GetSpellLink(spellID) or ""
end

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

local statisticsModule

local DUPLICATE_ALERT_WINDOW = 0.3
local recentAlerts = {}

function SoundAlerter:PlaySpell(list, spellID, sourceGUID, sourceName)
    local key = list[spellID]
    if key then
        if not sadb[key] then return end
        local now = GetTime()
        local rearm = rearmSeconds[key]
        if rearm then
            local wait = SA_Rearm.Wait(rearmAt, key, rearm, now)
            if wait then
                self:Debug("Sound", "%s.mp3 held (re-arms in %.0f s)", key, wait)
                return
            end
        end
        local guid = Plain(sourceGUID)
        local last = recentAlerts[spellID]
        if last then
            if now - last.at < DUPLICATE_ALERT_WINDOW and last.guid == guid then
                local diag = self.diag
                diag.duplicateAlerts = diag.duplicateAlerts + 1
                local pair = last.unit .. " then " .. tostring(self.alertUnit)
                diag.duplicateTokens[pair] = (diag.duplicateTokens[pair] or 0) + 1
            end
        else
            last = {}
            recentAlerts[spellID] = last
        end
        last.at, last.guid, last.unit = now, guid, tostring(self.alertUnit)
        self:Debug("Sound", "%s.mp3 (spell %d, source %s)", list[spellID], spellID, tostring(sourceName or "?"))
        SoundAlerter:PlayVoice(sadb.sapath..list[spellID]..".mp3");

        if sadb.statistics and sadb.statistics.enabled then
            statisticsModule = statisticsModule or self:GetModule("Statistics")
            if statisticsModule then
                statisticsModule:RecordAlert("spellAlerts", spellID, sourceGUID, sourceName)
            end
        end
        return true
    end
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
    if not (sadb.scoreboardClassFallback and self.cachedInstanceType == "pvp") then return end
    local now = GetTime()
    if now - lastScoreboardRefresh < 5 then return end
    lastScoreboardRefresh = now
    self:RefreshScoreboard()
end

function SoundAlerter:UpdateScoreboardTracking()
    local active = sadb.scoreboardClassFallback and self.cachedInstanceType == "pvp"
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
    self.cachedInInstance, self.cachedInstanceType = IsInInstance()
    self.cachedZonePvpType = GetZonePVPInfo()
    self:UpdateScoreboardTracking()
    if sadb.engineAuraSounds then self:SyncAuraSounds() end

    local zoneName = GetRealZoneText() or GetZoneText() or "Unknown"
    self.zonePvpTypeLog = self.zonePvpTypeLog or {}
    self.zonePvpTypeLog[zoneName] = { instanceType = self.cachedInstanceType, pvpType = self.cachedZonePvpType }

    self:Debug("Zone", "%s: instanceType=%s pvpType=%s", zoneName, tostring(self.cachedInstanceType), tostring(self.cachedZonePvpType))
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

function SoundAlerter:IsAlertZoneAllowed()
    local currentZoneType = self.cachedInstanceType
    local pvpType = self.cachedZonePvpType

    return (pvpType == "contested" and sadb.field) or
           (pvpType == "hostile" and sadb.field) or
           (pvpType == "friendly" and sadb.field) or
           (currentZoneType == "pvp" and sadb.battleground) or
           (((currentZoneType == "arena") or (pvpType == "arena")) and sadb.arena) or
           sadb.all
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

function SoundAlerter:ZONE_CHANGED_NEW_AREA()
    self:RefreshZoneState()
end

function SoundAlerter:ZONE_CHANGED()
    if GetZonePVPInfo() ~= self.cachedZonePvpType then
        self:RefreshZoneState()
    end
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
        self:Print("  |cffFFFFFF/sa updates|r - Show what the update notice knows")
        self:Print("  |cffFFFFFF/sa global|r - Global sightings status: channel, messages, tracked enemies, ignored senders; |cffFFFFFF/sa global mute <name>|r or |cffFFFFFFunmute <name>|r (saved for all your characters)")
        self:Print("  |cffFFFFFF/sa snooze [minutes]|r / |cffFFFFFF/sa unsnooze|r - Silence proximity and enemy awareness alerts for a while")
        self:Print("  |cffFFFFFF/sa watch [guild] <name>|r / |cffFFFFFF/sa unwatch [guild] <name>|r / |cffFFFFFF/sa watchlist|r - Manage the watchlist")
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

    self:Print("Same spell alerted twice within " .. DUPLICATE_ALERT_WINDOW .. " s: |cffFFFFFF" .. diag.duplicateAlerts .. "|r")
    for pair, count in pairs(diag.duplicateTokens) do
        self:Print("  " .. pair .. ": |cffFFFFFF" .. count .. "|r")
    end

    self:Print("Aura resyncs: |cffFFFFFF" .. (diag.resyncFirstOrUnreadable + diag.resyncSecretAdded) .. "|r (first sight or unreadable update " ..
        diag.resyncFirstOrUnreadable .. ", hidden added auras " .. diag.resyncSecretAdded .. "), spell lookups |cffFFFFFF" .. diag.resyncProbes .. "|r")
    self:Print("Proximity checks skipped just after loading a zone: |cffFFFFFF" .. diag.zoningSkips .. "|r")

    self:Print("Use |cffFFFF00/sa stats reset|r to clear")
end

function SoundAlerter:CleanupProximityCaches()
    local currentTime = GetTime()
    local cooldown = sadb.proximityCooldown or 60

    for guid, timestamp in pairs(self.proximityAlertCache) do
        if currentTime - timestamp > cooldown then
            self.proximityAlertCache[guid] = nil
        end
    end

    for guid, timestamp in pairs(self.identityRetryAt) do
        if currentTime - timestamp > 60 then
            self.identityRetryAt[guid] = nil
        end
    end

    SA_Plates.PrunePending(currentTime - 60)

    SA_Spacing.Sweep(self.enemyOnYouAt, currentTime, 60)

    self:PruneWatchlist(currentTime)
    self:SweepPartyShare(currentTime)

end

local DRINK_SPELL_ID = 430
local DRINK_SPELL
local unitAuraMap = {}
local unitAuraCount = {}
local auraProbeSeen = {}

function SoundAlerter:ClearAuraTracking(unit)
    if unit then
        unitAuraMap[unit] = nil
        unitAuraCount[unit] = nil
    else
        wipe(unitAuraMap)
        wipe(unitAuraCount)
    end
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
    if sadb.statistics and sadb.statistics.enabled then
        local Statistics = self:GetModule("Statistics")
        if Statistics then
            Statistics:RecordAlert("interruptAlerts")
        end
    end
    if sadb.interruptemote then
        pcall(DoEmote, "ROAR")
    end
    if sadb.interrupt then return end
    SoundAlerter:PlayVoice(sadb.sapath .. SA_Interrupt.EnemySound(unit, sadb));
    if not SA_AlertText.Ready(sadb.interruptenemy) then return end
    local interrupted = interruptedSpellID and (GetSpellLink(interruptedSpellID) or GetSpellInfo(interruptedSpellID))
    if not interrupted then interrupted = SA_AlertText.Hidden(HiddenSpellIcon(hiddenSpellID), "spell") end
    SA_AlertText.Say(sadb.InterruptEnemyText, { enemy = enemyName, spell = LinkOrName(abilitySpellID), interruptedspellname = interrupted })
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
    if sadb.interruptReadyVoice and not sadb.interrupt and self:IsAlertZoneAllowed() then
        self:PlayVoice(sadb.sapath .. "interruptready.mp3")
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
    self:CheckCustomAlerts("SPELL_INTERRUPT", nil, "player", spellID)
    if sadb.interrupt then return end
    local interruptKey = self.spellList.interruptFriend[ability]
    if not interruptKey or sadb[interruptKey] then
        SoundAlerter:PlayVoice(sadb.sapath.."lockout.mp3");
    end
    if SA_AlertText.Ready(sadb.interruptself) then
        SA_AlertText.Say(sadb.InterruptSelfText, { spell = LinkOrName(ability), interruptedspellname = LinkOrName(spellID), enemy = announcement.name })
    end
end

local function CollectTrackedSpellIDs(ids, source)
    if not source then return end
    for spellID in pairs(source) do
        ids[spellID] = true
    end
end

local unitKindCache = {}

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

local trackedAuraIDs

function SoundAlerter:InvalidateTrackedAuraIDs()
    trackedAuraIDs = nil
end

local function GetTrackedAuraSpellIDs()
    if trackedAuraIDs then return trackedAuraIDs end
    local ids = {}
    CollectTrackedSpellIDs(ids, SoundAlerter.spellList and SoundAlerter.spellList.selfDebuff)
    CollectTrackedSpellIDs(ids, SoundAlerter.spellList and SoundAlerter.spellList.enemyDebuffs)
    CollectTrackedSpellIDs(ids, SoundAlerter.spellList and SoundAlerter.spellList.enemyDebuffdown)
    CollectTrackedSpellIDs(ids, SoundAlerter.spellList and SoundAlerter.spellList.friendCCenemy)
    CollectTrackedSpellIDs(ids, SoundAlerter.spellList and SoundAlerter.spellList.friendCCSuccess)
    CollectTrackedSpellIDs(ids, SoundAlerter.spellList and SoundAlerter.spellList.enemyDebuffdownAP)
    CollectTrackedSpellIDs(ids, SoundAlerter.spellList and SoundAlerter.spellList.auraApplied)
    CollectTrackedSpellIDs(ids, SoundAlerter.spellList and SoundAlerter.spellList.auraRemoved)
    CollectTrackedSpellIDs(ids, SA_CCChat.SPELLS)
    if sadb and sadb.custom then
        for _, css in pairs(sadb.custom) do
            if css.eventtype and (css.eventtype["SPELL_AURA_APPLIED"] or css.eventtype["SPELL_AURA_REMOVED"]) and css.spellid then
                local id = tonumber(css.spellid)
                if id then ids[id] = true end
            end
        end
    end
    trackedAuraIDs = ids
    return ids
end

local function TrackAura(unit, auraInstanceID, spellID)
    local map, count = unitAuraMap[unit], unitAuraCount[unit]
    if map[auraInstanceID] then return false end
    map[auraInstanceID] = spellID
    count[spellID] = (count[spellID] or 0) + 1
    return count[spellID] == 1
end

local function UntrackAura(unit, auraInstanceID)
    local map, count = unitAuraMap[unit], unitAuraCount[unit]
    local spellID = map[auraInstanceID]
    if not spellID then return nil end
    map[auraInstanceID] = nil
    count[spellID] = count[spellID] - 1
    if count[spellID] > 0 then return nil end
    count[spellID] = nil
    return spellID
end

local function ReadableSpellID(aura)
    local spellID = aura.spellId
    if spellID == nil or issecretvalue(spellID) then return nil end
    return spellID
end

local function ReadableSourceUnit(aura)
    local sourceUnit = aura.sourceUnit
    if sourceUnit == nil or issecretvalue(sourceUnit) then return nil end
    return sourceUnit
end

local resyncHadBefore = {}
local resyncSourceUnits = {}

function SoundAlerter:ResyncUnitAuras(unit, tracked, ctx, secretAdded)
    local hadBefore = resyncHadBefore
    local sourceUnits = resyncSourceUnits
    wipe(hadBefore)
    wipe(sourceUnits)

    local previous = unitAuraCount[unit]
    local firstSight = previous == nil
    if previous then
        for spellID in pairs(previous) do
            hadBefore[spellID] = true
        end
        wipe(previous)
        wipe(unitAuraMap[unit])
    else
        unitAuraMap[unit] = {}
        unitAuraCount[unit] = {}
    end

    local probed = 0
    for spellID in pairs(tracked) do
        probed = probed + 1
        local ok, data = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
        if ok and data ~= nil and not issecretvalue(data) then
            local instanceID = data.auraInstanceID
            if instanceID == nil or issecretvalue(instanceID) then
                instanceID = "spell" .. spellID
            end
            TrackAura(unit, instanceID, spellID)
            sourceUnits[spellID] = ReadableSourceUnit(data)
        end
    end

    local diag = self.diag
    diag.resyncProbes = diag.resyncProbes + probed
    if secretAdded then
        diag.resyncSecretAdded = diag.resyncSecretAdded + 1
    else
        diag.resyncFirstOrUnreadable = diag.resyncFirstOrUnreadable + 1
    end

    for spellID in pairs(unitAuraCount[unit]) do
        if not hadBefore[spellID] then
            self:HandleDebuffApplied(unit, spellID, ctx.isPlayer, ctx.isTargetOrFocus, ctx.isTracked, sourceUnits[spellID], ctx.isAlly, firstSight)
        end
    end
    for spellID in pairs(hadBefore) do
        if not unitAuraCount[unit][spellID] then
            self:HandleDebuffRemoved(unit, spellID, ctx.isTargetOrFocus, ctx.isAlly, ctx.isTracked)
        end
    end
end

local function IsSecret(value)
    return value ~= nil and issecretvalue(value)
end

local function ReadableDelta(updateInfo)
    if updateInfo == nil or IsSecret(updateInfo) then return false end
    local full, added, removed = updateInfo.isFullUpdate, updateInfo.addedAuras, updateInfo.removedAuraInstanceIDs
    if IsSecret(full) or IsSecret(added) or IsSecret(removed) then return false end
    if full then return false end
    return true, added, removed
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
    if not self:IsAlertZoneAllowed() then return end
    local ok, data = pcall(C_LossOfControl.GetActiveLossOfControlData, index)
    if not ok or type(data) ~= "table" then return end
    local category = SA_LossOfControl.Category(Plain(data.locType))
    if not category then return end
    local now = GetTime()
    if not SA_LossOfControl.ShouldSpeak(sadb, lossOfControlState, category, now) then return end
    lossOfControlState.lastSpoken[category] = now
    self:Debug("LossOfControl", "%s (%s)", category, tostring(Plain(data.locType)))
    self:PlayVoice(sadb.sapath .. SA_LossOfControl.Voice(category))
    self:RecordStat("lossOfControlAlerts")
end

local probeLog = SA_DebugLog.NewProbe(function(value) return issecretvalue(value) end)

function SoundAlerter:ProbeValue(tag, ...)
    if not (sadb and sadb.debugmode) then return end
    local zone = self.cachedInstanceType or "none"
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
    line("zone", self.cachedInstanceType, self.cachedZonePvpType)
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

local function StealthScopeAllows(isTargetOrFocus, isTracked)
    return (sadb.myself and isTargetOrFocus) or (sadb.enemyinrange and isTracked) or false
end

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

function SoundAlerter:AnnounceStealthChat(group, spellID, enemyName, isTargetOrFocus)
    local isVanish, isStealth, isProwl = group == "vanish", group == "stealth", group == "prowl"
    local wanted = ((sadb.vanishenemy and isVanish) or (sadb.stealthenemy and isStealth) or (sadb.prowlenemy and isProwl))
       and (isTargetOrFocus or ((sadb.vanishTF and isVanish) or (sadb.stealthTF and isStealth) or (sadb.prowlTF and isProwl)))
    if SA_AlertText.Ready(wanted) then
        SA_AlertText.Say(sadb.enemychat, { spell = Link(spellID), enemy = enemyName })
    end
end

function SoundAlerter:AlertStealth(unit, spellID, kind, source, isTargetOrFocus, isTracked, name, guid)
    if not StealthScopeAllows(isTargetOrFocus, isTracked) then
        self:StealthLog("%s %d %s dropped: scope (target and focus %s, enemies in range %s)", unit, spellID, kind, tostring(sadb.myself), tostring(sadb.enemyinrange))
        return
    end
    if (source == "castSuccess" and sadb.castSuccess) or (source == "auraApplied" and sadb.aruaApplied) then
        self:StealthLog("%s %d %s dropped: %s alerts are muted", unit, spellID, kind, source)
        return
    end
    local list = self.spellList[source]
    local band = sadb.stealthKeepWatch and self:GetApproxRange(unit) or nil
    if not SA_StealthWatch.Decide(stealthState, guid, kind, band, sadb, GetTime(), spellID, source) then
        self:StealthLog("%s %d %s dropped: already alerted, or first sight with on-sight off", unit, spellID, kind)
        return
    end
    local played = self:PlaySpell(list, spellID, guid, name)
    self:StealthLog("%s %d %s band %s: voice %s (%s)", unit, spellID, kind, tostring(band), played and "played" or "not played", tostring(list[spellID]))
    self:AnnounceStealthChat(list[spellID], spellID, name, isTargetOrFocus)
    if sadb.shareAlertsSend then self:ShareAlert("S", guid, spellID, SafeUnitClass(unit), nil, name) end
    if SA_StealthWatch.Watching(stealthState) > 0 and not self.stealthTimer then
        self.stealthTimer = self:ScheduleRepeatingTimer("StealthWatchTick", 1)
    end
end

function SoundAlerter:AlertSharedStealth(guid, spellID, name)
    local list = self.spellList.auraApplied
    if not SA_StealthWatch.IsGroup(list[spellID]) or sadb.aruaApplied or not self:IsAlertZoneAllowed() then return false end
    if not SA_StealthWatch.Decide(stealthState, guid, "added", nil, sadb, GetTime(), spellID, "auraApplied") then return false end
    local played = self:PlaySpell(list, spellID, guid, name)
    self:StealthLog("shared %d from the group: voice %s", spellID, played and "played" or "not played")
    return played and true or false
end

local function FindWatchedUnit(guid)
    if sadb.myself then
        for _, token in ipairs(WATCH_TOKENS) do
            if UnitExists(token) and Plain(UnitGUID(token)) == guid then return token end
        end
    end
    if sadb.enemyinrange then
        for unit, plateGUID in pairs(SA_Plates.Enemies()) do
            if plateGUID == guid then return unit end
        end
    end
    return nil
end

function SoundAlerter:StealthWatchTick()
    if not sadb.stealthKeepWatch then SA_StealthWatch.Reset(stealthState) end
    if SA_StealthWatch.Watching(stealthState) == 0 then
        self:CancelTimer(self.stealthTimer)
        self.stealthTimer = nil
        return
    end
    if not self:IsAlertZoneAllowed() then return end
    local now = GetTime()
    for guid, entry in SA_StealthWatch.NextWatching, stealthState, nil do
        local unit = FindWatchedUnit(guid)
        if unit and SA_StealthWatch.Decide(stealthState, guid, "tick", self:GetApproxRange(unit), sadb, now) then
            self.alertUnit = unit
            self:PlaySpell(self.spellList[entry.source], entry.spellID, guid, SafeUnitName(unit))
        end
    end
    SA_StealthWatch.Sweep(stealthState, now)
end

local TRAP_KEYS = { freezingtrap = true, frosttrap = true }

function SoundAlerter:HandleDebuffApplied(unit, spellID, isPlayer, isTargetOrFocus, isTracked, sourceUnit, isAlly, firstSight)
    self.alertUnit = unit
    self:CheckCustomAlerts("SPELL_AURA_APPLIED", sourceUnit, unit, spellID)

    if isAlly then
        if not sadb.dArenaPartner then
            self:PlaySpell(self.spellList.friendCCSuccess, spellID)
        end
        local kind = not firstSight and SA_CCChat.Kind(spellID, sadb)
        if kind and SA_AlertText.Ready(true) then
            local friend = SafeUnitName(unit) or "a friend"
            local enemy = sourceUnit and SafeUnitName(sourceUnit) or "An enemy"
            SA_AlertText.Say(kind == "sap" and sadb.sapfriendtext or sadb.friendchat, { spell = Link(spellID), friend = friend, enemy = enemy })
        end
        return
    end

    if isPlayer then
        if not sadb.dSelfDebuff then
            if self:HasEngineAuraSound("player", "Added", spellID) then
                lossOfControlState.lastSelfDebuffAt = GetTime()
            elseif self:PlaySpell(self.spellList.selfDebuff, spellID) then
                lossOfControlState.lastSelfDebuffAt = GetTime()
            end
        end
        if sourceUnit and TRAP_KEYS[self.spellList.selfDebuff[spellID]] and self.ProximityToasts then
            local trapper = Plain(UnitGUID(sourceUnit))
            if trapper then self.ProximityToasts:OnTrapLanded(trapper, spellID) end
        end
        local kind = SA_CCChat.Kind(spellID, sadb)
        if kind and SA_AlertText.Ready(true) then
            if kind == "cc" then
                SA_AlertText.Say(sadb.selfchat, { spell = Link(spellID), target = "me", enemy = sourceUnit and SafeUnitName(sourceUnit) or "An enemy" })
            elseif kind == "sap" then
                SA_AlertText.Say(sadb.sapselftext, { spell = Link(spellID) })
            end
        end
        return
    end

    if not (isTargetOrFocus or isTracked) then return end

    local name = SafeUnitName(unit)
    local guid = UnitGUID(unit)
    if not name or not Plain(guid) then return end

    if SA_StealthWatch.IsGroup(self.spellList.auraApplied[spellID]) then
        self:AlertStealth(unit, spellID, firstSight and "sight" or "added", "auraApplied", isTargetOrFocus, isTracked, name, guid)
        return
    end

    local isAllySource = sourceUnit ~= nil and UnitKind(sourceUnit) == "party"
    if isAllySource and not sadb.dArenaPartner then
        self:PlaySpell(self.spellList.friendCCenemy, spellID)
    elseif not sadb.dEnemyDebuff and not self:HasEngineAuraSound(unit, "Added", spellID) then
        self:PlaySpell(self.spellList.enemyDebuffs, spellID, guid, name)
    end

    if SA_AlertText.Ready(true) then
        if (((spellID == 6770 or spellID == 11297 or spellID == 2070) and sadb.sapenemy) or
            (spellID == 2094 and sadb.blindenemy) or
            (spellID == 450600 and sadb.hexenemy) or
            (spellID == 5782 and sadb.fearenemy)) then
            SA_AlertText.Say(sadb.enemychat, { spell = Link(spellID), enemy = name })
        end

        if sadb.bubbleenemy and spellID == 642 then
            SA_AlertText.Say(sadb.bubbleenemytext, { enemy = name })
        end
    end

    if ((sadb.myself and isTargetOrFocus) or (sadb.enemyinrange and isTracked)) and not sadb.aruaApplied then
        self:PlaySpell(self.spellList.auraApplied, spellID)
        if SA_AlertText.Ready(sadb.chatauraApplied and self.spellList.auraApplied[spellID]) then
            SA_AlertText.Say(sadb.enemybuffchat, { spell = Link(spellID), enemy = name })
        end
    end
end

function SoundAlerter:HandleDebuffRemoved(unit, spellID, isTargetOrFocus, isAlly, isTracked)
    self.alertUnit = unit
    self:CheckCustomAlerts("SPELL_AURA_REMOVED", nil, unit, spellID)

    if isAlly then
        if not sadb.dArenaPartner then
            self:PlaySpell(self.spellList.enemyDebuffdownAP, spellID)
        end
        return
    end

    if not (isTargetOrFocus or isTracked) then return end

    if SA_StealthWatch.IsGroup(self.spellList.auraApplied[spellID]) then
        SA_StealthWatch.Clear(stealthState, Plain(UnitGUID(unit)))
    end

    local name = SafeUnitName(unit)
    if not name then return end

    if not sadb.dEnemyDebuffDown and not self:HasEngineAuraSound(unit, "Removed", spellID) then
        self:PlaySpell(self.spellList.enemyDebuffdown, spellID)
    end

    if SA_AlertText.Ready(sadb.chatdownfriend) then
        if ((spellID == 450600 and sadb.hexenemy) or
            (spellID == 2094 and sadb.blindenemy) or
            ((spellID == 6770 or spellID == 11297 or spellID == 2070) and sadb.sapenemy) or
            ((spellID == 12826 or spellID == 118 or spellID == 28271 or spellID == 28272) and sadb.polyenemy) or
            ((spellID == 6215 or spellID == 5484 or spellID == 17928) and sadb.fearenemy)) then
            SA_AlertText.Say(DOWN_TEMPLATE, { spell = GetSpellLink(spellID) or GetSpellInfo(spellID) or "Unknown Spell", enemy = name })
        end
    end

    if not sadb.auraRemoved then
        self:PlaySpell(self.spellList.auraRemoved, spellID)
    end
    if SA_AlertText.Ready(sadb.chatauraRemoved and self.spellList.auraRemoved[spellID]) then
        SA_AlertText.Say(sadb.auraRemovedChat, { spell = Link(spellID), enemy = name })
    end
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
    if filterKey == FILTER_TYPE_HOSTILE_PLAYER then return UnitIsPlayer(unit) and UnitIsEnemy("player", unit) end
    if filterKey == FILTER_TYPE_FRIENDLY then return not UnitIsEnemy("player", unit) end
    if filterKey == FILTER_TYPE_HOSTILE_UNIT then return UnitIsEnemy("player", unit) end
    return true
end

function SoundAlerter:CheckCustomAlerts(eventName, sourceUnit, destUnit, spellID)
    if not next(sadb.custom) then return end
    if issecretvalue(spellID) then return end

    local spellName

    for _, css in pairs(sadb.custom) do
        if css.eventtype and css.eventtype[eventName] then
            local spellIdNum = css.spellidNum
            if spellIdNum == nil or css.spellidNumSrc ~= css.spellid then
                spellIdNum = tonumber(css.spellid)
                css.spellidNum = spellIdNum
                css.spellidNumSrc = css.spellid
            end

            local matched = spellID == spellIdNum
            if not matched and css.acceptSpellName then
                if spellName == nil then
                    spellName = GetSpellInfo(spellID) or false
                end
                matched = spellName and css.spellname == spellName
            end

            if matched then
                if self:MatchesUidFilter(destUnit, css.destuidfilter, css.destcustomname)
                    and self:MatchesUidFilter(sourceUnit, css.sourceuidfilter, css.sourcecustomname)
                    and self:MatchesTypeFilter(destUnit, css.desttypefilter)
                    and self:MatchesTypeFilter(sourceUnit, css.sourcetypefilter) then
                    local destName = destUnit and SafeUnitName(destUnit)
                    local sourceName = sourceUnit and SafeUnitName(sourceUnit)
                    self:Debug("CustomSound", "%s matched on %s (spell %s, source %s -> dest %s)", tostring(css.name), eventName, tostring(spellID), tostring(sourceName), tostring(destName))

                    if not css.chatAlert then
                        SoundAlerter:PlayVoice("Interface\\Addons\\SoundAlerter\\CustomSounds\\"..css.soundfilepath, "Master")
                    elseif SA_AlertText.Ready(true) then
                        local enemy = eventName == "SPELL_CAST_START" and "" or (destName or sourceName or "")
                        SA_AlertText.Say(css.chatalerttext, { spell = Link(spellID), enemy = enemy })
                    end
                end
            end
        end
    end
end

local auraContext = {}

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
    SoundAlerter:ResyncUnitAuras(unit, GetTrackedAuraSpellIDs(), context, secretAdded)
end)

local function QueueResync(unit, isPlayer, isTargetOrFocus, isTracked, isAlly, secretAdded)
    local context = resyncContexts[unit]
    context.isPlayer = isPlayer
    context.isTargetOrFocus = isTargetOrFocus
    context.isTracked = isTracked
    context.isAlly = isAlly
    if secretAdded then context.secretAdded = true end
    resyncQueue.Request(unit, context)
end

local function FillAuraContext(isPlayer, isTargetOrFocus, isTracked, isAlly)
    auraContext.isPlayer = isPlayer
    auraContext.isTargetOrFocus = isTargetOrFocus
    auraContext.isTracked = isTracked
    auraContext.isAlly = isAlly
    return auraContext
end

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
        local currentZoneType, pvpType = self.cachedInstanceType, self.cachedZonePvpType
        if ((currentZoneType == "arena") or (pvpType == "arena")) and sadb.drinking then
            if DRINK_SPELL == nil then
                DRINK_SPELL = GetSpellInfo(DRINK_SPELL_ID) or false
            end
            if DRINK_SPELL and UnitAura(unit, DRINK_SPELL) then
                SoundAlerter:PlayVoice(sadb.sapath.."drinking.mp3");
            end
        end
    end

    local isTracked = isNameplate
    if not (isPlayer or isTargetOrFocus or isTracked or isAlly) then return end
    if not isPlayer and not isAlly and (not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit)) then return end
    if isAlly and (not UnitIsPlayer(unit) or UnitIsEnemy("player", unit)) then return end
    if not self:IsAlertZoneAllowed() then
        if isTargetOrFocus then self:StealthLog("%s aura update ignored: zone gate", unit) end
        return
    end

    local tracked = GetTrackedAuraSpellIDs()
    local usable, added, removed = ReadableDelta(updateInfo)
    if sadb.debugmode then
        local probeKind = isPlayer and "player" or isTargetOrFocus and unit or isArena and "arena" or isNameplate and "nameplate" or "party"
        local path = (usable and unitAuraMap[unit]) and "delta" or (not unitAuraMap[unit] and "resync (first sight)" or "resync (payload unreadable)")
        self:ProbeAuraUpdate(unit, probeKind, updateInfo, path)
    end

    if not unitAuraMap[unit] then
        self:ResyncUnitAuras(unit, tracked, FillAuraContext(isPlayer, isTargetOrFocus, isTracked, isAlly))
        return
    end
    if not usable then
        QueueResync(unit, isPlayer, isTargetOrFocus, isTracked, isAlly)
        return
    end

    local needsResync = false

    if added then
        for _, aura in ipairs(added) do
            local spellID = ReadableSpellID(aura)
            local auraInstanceID = aura.auraInstanceID
            if spellID == nil or IsSecret(auraInstanceID) then
                needsResync = true
            elseif tracked[spellID] and TrackAura(unit, auraInstanceID, spellID) then
                if sadb.debugmode and SA_StealthWatch.IsGroup(self.spellList.auraApplied[spellID]) then
                    self:StealthLog("%s %d seen in a UNIT_AURA delta", unit, spellID)
                end
                self:HandleDebuffApplied(unit, spellID, isPlayer, isTargetOrFocus, isTracked, ReadableSourceUnit(aura), isAlly)
            end
        end
    end

    if removed then
        for _, auraInstanceID in ipairs(removed) do
            if IsSecret(auraInstanceID) then
                needsResync = true
            else
                local gone = UntrackAura(unit, auraInstanceID)
                if gone then
                    self:HandleDebuffRemoved(unit, gone, isTargetOrFocus, isAlly, isTracked)
                end
            end
        end
    end

    if needsResync then
        QueueResync(unit, isPlayer, isTargetOrFocus, isTracked, isAlly, true)
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

function SoundAlerter:RescanTrackedNameplates()
    if not (sadb.proximityEnabled and SA_Distance.IsRestricted(sadb.proximityMaxBand)) then return end
    local now = GetTime()
    local cooldown = sadb.proximityCooldown or 60
    local alerted = self.proximityAlertCache
    for unit, guid in pairs(SA_Plates.Enemies()) do
        local last = alerted[guid]
        if not last or now - last >= cooldown then
            self:CheckProximityAlert(unit)
        end
    end
end

local IDENTITY_RETRY_DELAY = 0.1
local IDENTITY_RETRY_SPACING = 5

function SoundAlerter:ScheduleIdentityRetry(unit, guid, allySpotted)
    local now = GetTime()
    local last = self.identityRetryAt[guid]
    if last and now - last < IDENTITY_RETRY_SPACING then return end
    self.identityRetryAt[guid] = now
    self:Debug("Proximity", "%s identity unreadable, retrying in %.1fs", unit, IDENTITY_RETRY_DELAY)
    C_Timer.After(IDENTITY_RETRY_DELAY, function()
        if Plain(UnitGUID(unit)) == guid then
            self:CheckProximityAlert(unit, allySpotted)
        end
    end)
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
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return end
    if not self:IsAlertZoneAllowed() or self:IsQuiet() then return end
    local guid = Plain(UnitGUID(unit))
    if not guid then return end
    local now = GetTime()
    if not SA_Spacing.Ready(self.enemyOnYouAt, kind, guid, now, rule.spacing or sadb.enemyTargetsYouCooldown or 8) then return end
    if EnemyTargetsPlayer(unit) ~= true then return end
    SA_Spacing.Mark(self.enemyOnYouAt, kind, guid, now)
    self:Debug("Targeting", "%s on you from %s", kind, unit)
    self:PlayVoice(sadb.sapath .. rule.voice)
    self:RecordStat("awarenessAlerts")
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
    if sadb.proximityEnabled and sadb.proximityAllyVision then
        self:CheckProximityAlert(spotted, true)
    end
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
    if sadb.proximityEnabled then
        self:CheckProximityAlert(unit)
    end
end

SoundAlerter.UNIT_FACTION = SoundAlerter.UNIT_NAME_UPDATE

function SoundAlerter:IsProximityZoneAllowed()
    local kind = SA_ZoneKind.Of(self.cachedInstanceType, self.cachedZonePvpType, IsResting and IsResting())
    if kind == "arena" then return sadb.proximityArena and true or false end
    if kind == "battleground" then return sadb.proximityBattleground and true or false end
    if kind == "world" then return sadb.proximityWorld and true or false end
    return sadb.proximitySanctuary and true or false
end

local function ProximityBandAllowed(band)
    return not SA_Distance.IsRestricted(sadb.proximityMaxBand) or SA_Distance.Allows(sadb.proximityMaxBand, band)
end

function SoundAlerter:FireProximityAlert(guid, unitName, unitClass, unitLevel, band, unitToken, nearbyCount, title, shared, secondName)
    if shared then
        SoundAlerter:PlayVoice(sadb.sapath .. "sharedintel.mp3", "Master")
    else
        local classAudioFile = CLASS_AUDIO_MAP[unitClass]
        if classAudioFile then
            SoundAlerter:PlayVoice(sadb.sapath .. classAudioFile .. ".mp3", "Master")
        end
        self:ScheduleTimer(function()
            SoundAlerter:PlayVoice(sadb.sapath .. "detected.mp3", "Master")
        end, 0.8)
    end

    do
        local Statistics = self:GetModule("Statistics")
        if Statistics and Statistics:GetSettings().enabled then
            Statistics:RecordAlert("proximityAlerts", nil, guid, unitName, nil, unitClass)
        end
    end

    if self.ProximityToasts and self.ProximityToasts:GetSettings().enabled then
        self.ProximityToasts:ShowToast(unitName, unitClass, band, guid, unitLevel, unitToken, title, nearbyCount, secondName)
    end
end

function SoundAlerter:AlertSharedProximity(guid, unitClass, unitName, unitLevel, sender)
    if not sadb.proximityEnabled or not ProximityBandAllowed("Spotted") then return false end
    local now = GetTime()
    if now - self.enterWorldTime < 10 then return false end
    local cached = self.proximityAlertCache[guid]
    if cached and now - cached < (sadb.proximityCooldown or 60) then return false end
    if not self:IsProximityZoneAllowed() or self:IsQuiet() then return false end
    self.proximityAlertCache[guid] = now
    SA_Plates.ClearPending(guid)
    self:FireProximityAlert(guid, unitName, unitClass, unitLevel or -1, "Spotted", nil, nil, "Spotted by " .. sender, true)
    return true
end

function SoundAlerter:CheckProximityAlert(unit, allySpotted)
    if not sadb.proximityEnabled then return end

    if not UnitExists(unit) then return end
    if not UnitIsPlayer(unit) then return end
    if not UnitIsEnemy("player", unit) then return end
    if not allySpotted and not UnitIsVisible(unit) then return end

    local guid = UnitGUID(unit)
    if not Plain(guid) then return end

    if not guid:find("^Player%-") then return end

    local currentTime = GetTime()
    local cooldown = sadb.proximityCooldown or 60
    if self.proximityAlertCache[guid] then
        local timeElapsed = currentTime - self.proximityAlertCache[guid]
        if timeElapsed < cooldown then return end
    end

    if currentTime - self.enterWorldTime < 10 then
        self.diag.zoningSkips = self.diag.zoningSkips + 1
        return
    end
    if self:IsQuiet() then return end

    if not self:IsProximityZoneAllowed() then return end

    local unitName, secondName = UnitName(unit)
    local _, unitClass = UnitClass(unit)
    local unitLevel = UnitLevel(unit)

    if not Plain(unitClass) and sadb.scoreboardClassFallback then
        local mapped = SA_Scoreboard.ClassFor(self.scoreboardClasses, Plain(unitName))
        if mapped then
            self:Debug("Scoreboard", "%s class taken from the scoreboard: %s", unit, mapped)
            unitClass = mapped
        end
    end

    if not (Plain(unitName) and Plain(unitClass)) then
        SA_Plates.MarkPending(guid, currentTime)
        self:ScheduleIdentityRetry(unit, guid, allySpotted)
        return
    end
    if issecretvalue(unitLevel) then return end

    local approxRange = self:GetApproxRange(unit) or (allySpotted and "Spotted" or nil)
    if not ProximityBandAllowed(approxRange) then return end

    self.proximityAlertCache[guid] = currentTime
    SA_Plates.ClearPending(guid)

    self:FireProximityAlert(guid, unitName, unitClass, unitLevel, approxRange, not allySpotted and unit or nil, SA_Plates.Count(), nil, nil, Plain(secondName))

    if SA_AlertText.Ready(sadb.proximityChat and sadb.proximityChatText) then
        SA_AlertText.Say(sadb.proximityChatText, { class = unitClass, player = unitName })
    end

    if not allySpotted then
        self:ShareAlert("P", guid, 0, unitClass, unitLevel, unitName)
    end
end

function SoundAlerter:PLAYER_TARGET_CHANGED()
    ClearCastState("target")
    self:ClearAuraTracking("target")
    self:RefreshEnemyAuraUnits()
    self:CheckWatchlist("target")
    self:CheckProximityAlert("target")
end

function SoundAlerter:PLAYER_FOCUS_CHANGED()
    ClearCastState("focus")
    self:ClearAuraTracking("focus")
    self:RefreshEnemyAuraUnits()
end

function SoundAlerter:UPDATE_MOUSEOVER_UNIT()
    self:CheckWatchlist("mouseover")
    self:CheckProximityAlert("mouseover")
end

function SoundAlerter:NAME_PLATE_UNIT_ADDED(event, unit)
    if sadb.debugmode then self:ProbeNameplate(unit) end
    SA_Plates.Remove(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return end

    local guid = UnitGUID(unit)
    if not Plain(guid) then return end

    SA_Plates.Add(unit, guid)

    self:CheckWatchlist(unit)
    self:CheckProximityAlert(unit)
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
    if guid and SA_Plates.IsPending(guid) and sadb.proximityEnabled then
        self:CheckProximityAlert(unit)
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
    self.alertUnit = unit
    if unit == "target" or unit == "focus" or unit == "mouseover" then
        interrupts:CastStarted(unit, not issecretvalue(spellID) and spellID or nil, GetTime())
    end
    if not unit or not IsRelevantCastUnit(unit) then return end
    if not self:IsAlertZoneAllowed() then return end
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return end
    castStartedAt[unit] = GetTime()
    self:AlertEnemyOnYou(unit, "casting")
    if issecretvalue(spellID) then return end

    local isTargetOrFocus = (unit == "target" or unit == "focus")
    local isTracked = not isTargetOrFocus and self:IsTrackedNameplate(unit)
    local isArenaEnemy = not isTargetOrFocus and not isTracked and UnitKind(unit) == "arena"

    if isArenaEnemy then
        if sadb.dArenaPartner then return end
        local currentZoneType, pvpType = self.cachedInstanceType, self.cachedZonePvpType
        if not ((currentZoneType == "arena") or (pvpType == "arena")) then return end
        for i = 1, #ARENA_TARGET_UNITS do
            if playerName == SafeUnitName(ARENA_TARGET_UNITS[i]) then return end
        end
        self:PlaySpell(self.spellList.friendCCs, spellID)
        return
    end

    if not (isTargetOrFocus or isTracked) then return end

    self:CheckCustomAlerts("SPELL_CAST_START", unit, nil, spellID)

    if not sadb.castStart and ((sadb.myself and isTargetOrFocus) or (sadb.enemyinrange and isTracked)) then
        local guid = UnitGUID(unit)
        local name = SafeUnitName(unit)
        if Plain(guid) and name then
            self:PlaySpell(self.spellList.castStart, spellID, guid, name)
            if SA_AlertText.Ready(sadb.chatcastStart and self.spellList.castStart[spellID]) then
                SA_AlertText.Say(sadb.castStartChat, { spell = Link(spellID), enemy = name })
            end
        end
    end
end

function SoundAlerter:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
    self.alertUnit = unit
    if unit == "player" or (unit == "pet" and sadb.interruptPets) then
        self:RecordPlayerInterrupt(spellID)
        return
    end
    if not unit or not IsRelevantCastUnit(unit) then return end
    if not self:IsAlertZoneAllowed() then return end
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return end
    self:AlertInstantOnYou(unit)
    if issecretvalue(spellID) then return end

    local isTargetOrFocus = (unit == "target" or unit == "focus")
    local isTracked = not isTargetOrFocus and self:IsTrackedNameplate(unit)
    if not (isTargetOrFocus or isTracked) then return end

    local guid = UnitGUID(unit)
    local name = SafeUnitName(unit)
    if not Plain(guid) or not name then return end

    interrupts:Cast("enemy", spellID, GetTime(), name)

    self:CheckCustomAlerts("SPELL_CAST_SUCCESS", unit, nil, spellID)

    if SA_AlertText.Ready(sadb.trinketalert and spellID == 1259718) then
        SA_AlertText.Say(sadb.trinketalerttext, { enemy = name })
    end

    if spellID == 1259718 and sadb.trinket then
        local class = SafeUnitClass(unit)
        if class and sadb.class then
            local classAudioFile = CLASS_AUDIO_MAP[class]
            if classAudioFile then
                SoundAlerter:PlayVoice(sadb.sapath..classAudioFile..".mp3");
            end
            self:ScheduleTimer(function() self:PlayTrinket(guid, name) end, 0.4);
        else
            self:PlayTrinket(guid, name)
        end
    elseif ((sadb.myself and isTargetOrFocus) or (sadb.enemyinrange and isTracked)) and not sadb.castSuccess then
        if SA_StealthWatch.IsGroup(self.spellList.castSuccess[spellID]) then
            self:AlertStealth(unit, spellID, "added", "castSuccess", isTargetOrFocus, isTracked, name, guid)
        elseif not ((sadb.enemyinrange and isTracked and not isTargetOrFocus) and spellID == 1245940) then
            self:PlaySpell(self.spellList.castSuccess, spellID, guid, name)
        end
    end
end

function SoundAlerter:UNIT_SPELLCAST_INTERRUPTED(event, unit, castGUID, spellID, interruptedBy)
    if unit ~= "player" and unit ~= "target" and unit ~= "focus" and unit ~= "mouseover" then return end
    castStartedAt[unit] = nil
    if not self:IsAlertZoneAllowed() then return end
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
    facts.isEnemy = UnitExists(unit) and UnitIsEnemy("player", unit) or false
    facts.name = SafeUnitName(unit)
    facts.byPlayer = InterrupterIsPlayer(interruptedBy)
    local announcement, readable, reason = interrupts:Interrupted(facts, now, sadb)
    facts.hidden = nil
    if readable then
        self:CheckCustomAlerts("SPELL_INTERRUPT", nil, unit, readable)
    end
    if announcement then
        self:AnnounceEnemyInterrupt(announcement)
    elseif reason and sadb.debugmode then
        self:Debug("Interrupt", "%s not announced: %s", unit, reason)
    end
end
