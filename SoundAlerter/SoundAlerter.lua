
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

SoundAlerter.SafeUnitName = SafeUnitName

self.SA_LOCALEPATH = SA_LOCALEPATH
self.SA_LANGUAGE = {
    ["Interface\\Addons\\SoundAlerter\\Voice\\"] = "English",
}
self.SA_CHATGROUP = {
    ["SAY"] = L["Say"],
    ["PARTY"] = L["Party"],
    ["RAID"] = L["Raid"],
    ["BATTLEGROUND"] = L["Battleground"],
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

local function log(msg) DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF22SA|r:"..msg) end

function SoundAlerter:Debug(module, fmt, ...)
    if not (sadb and sadb.debugmode) then return end
    DEFAULT_CHAT_FRAME:AddMessage(SA_DebugLog.Format(GetTime(), module, fmt, ...))
end

function SoundAlerter:ChangeProfile()
	sadb = self.db1.profile
	self:InvalidateTrackedAuraIDs()
	self:UpdateScoreboardTracking()
	self:ApplyTotemPlates()
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

	if self.CombatTimer then
		self.CombatTimer:OnProfileChanged()
	end

	if self.SpeedMeter then
		self.SpeedMeter:OnProfileChanged()
	end

	if self.FlagAlerts then
		self.FlagAlerts:OnProfileChanged()
	end

	if self.MinimapTracking then
		self.MinimapTracking:OnProfileChanged()
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

local SoundAlerterMinimapButton
local BUTTON_TEXTURE = "Interface\\ICONS\\ability_warrior_battleshout"

function SoundAlerter:CreateMinimapButton()
    local db = sadb
    local buttonSize = 24
    local iconSize = 24
    local initialX = 5
    local initialY = -5

    SoundAlerterMinimapButton = CreateFrame("Button", "SoundAlerterMinimapButton", Minimap)
    SoundAlerterMinimapButton:SetSize(buttonSize, buttonSize)
    SoundAlerterMinimapButton:SetFrameStrata("MEDIUM")
    SoundAlerterMinimapButton:SetMovable(true)
    SoundAlerterMinimapButton:EnableMouse(true)
    SoundAlerterMinimapButton:RegisterForDrag("LeftButton")

    local icon = SoundAlerterMinimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(BUTTON_TEXTURE)
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("CENTER", SoundAlerterMinimapButton, "CENTER", 0, 0)
    icon:SetVertexColor(0.5, 1.0, 1.0)
    SoundAlerterMinimapButton.icon = icon

    local border = SoundAlerterMinimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    border:SetSize(iconSize + 4, iconSize + 4)
    border:SetPoint("CENTER", SoundAlerterMinimapButton, "CENTER", 0, 0)
    border:SetVertexColor(0.5, 0.5, 0.5, 0.8)
    SoundAlerterMinimapButton.border = border

    local highlight = SoundAlerterMinimapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetSize(iconSize, iconSize)
    highlight:SetPoint("CENTER", SoundAlerterMinimapButton, "CENTER", 0, 0)
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(0.0, 0.8, 0.8)
    highlight:SetAlpha(0)
    SoundAlerterMinimapButton.highlight = highlight

    self:CreateMinimapButtonAnimations()

    SoundAlerterMinimapButton:SetScript("OnEnter", function(self)
        SoundAlerter:MinimapButton_OnEnter(self)
    end)

    SoundAlerterMinimapButton:SetScript("OnLeave", function(self)
        SoundAlerter:MinimapButton_OnLeave(self)
    end)

    SoundAlerterMinimapButton:SetScript("OnMouseDown", function(self, button)
        SoundAlerter:MinimapButton_OnMouseDown(self, button)
    end)

    SoundAlerterMinimapButton:SetScript("OnMouseUp", function(self, button)
        SoundAlerter:MinimapButton_OnMouseUp(self, button)
    end)

    SoundAlerterMinimapButton:SetScript("OnClick", function(self, button)
        SoundAlerter:MinimapButton_OnClick(self, button)
    end)

    SoundAlerterMinimapButton:SetScript("OnDragStart", function(self)
        SoundAlerter:MinimapButton_OnDragStart(self)
    end)

    SoundAlerterMinimapButton:SetScript("OnDragStop", function(self)
        SoundAlerter:MinimapButton_OnDragStop(self)
    end)

    if db.MinimapButtonPosition then
        SoundAlerterMinimapButton:ClearAllPoints()
        SoundAlerterMinimapButton:SetPoint("CENTER", Minimap, "CENTER",
            db.MinimapButtonPosition.x, db.MinimapButtonPosition.y)
    else
        SoundAlerterMinimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", initialX, initialY)
    end

    if db.MinimapButtonHidden then
        SoundAlerterMinimapButton:Hide()
    else
        SoundAlerterMinimapButton:Show()
    end

    self:UpdateMinimapButtonIcon()
end

function SoundAlerter:CreateMinimapButtonAnimations()
    local button = SoundAlerterMinimapButton
    if not button then return end

    button.hoverAnimGroup = button:CreateAnimationGroup()
    button.hoverAnimGroup:SetLooping("NONE")

    local hoverScale = button.hoverAnimGroup:CreateAnimation("Scale")
    hoverScale:SetScale(1.05, 1.05)
    hoverScale:SetDuration(0.15)
    hoverScale:SetSmoothing("OUT")

    button.unhoverAnimGroup = button:CreateAnimationGroup()
    button.unhoverAnimGroup:SetLooping("NONE")

    local unhoverScale = button.unhoverAnimGroup:CreateAnimation("Scale")
    unhoverScale:SetScale(0.952, 0.952)
    unhoverScale:SetDuration(0.15)
    unhoverScale:SetSmoothing("OUT")

    button.pressAnimGroup = button:CreateAnimationGroup()
    button.pressAnimGroup:SetLooping("NONE")

    local pressScale = button.pressAnimGroup:CreateAnimation("Scale")
    pressScale:SetScale(0.905, 0.905)
    pressScale:SetDuration(0.05)

    button.releaseAnimGroup = button:CreateAnimationGroup()
    button.releaseAnimGroup:SetLooping("NONE")

    local releaseScale = button.releaseAnimGroup:CreateAnimation("Scale")
    releaseScale:SetScale(1.105, 1.105)
    releaseScale:SetDuration(0.1)
    releaseScale:SetSmoothing("OUT")
end

function SoundAlerter:MinimapButton_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("SoundAlerter")
    GameTooltip:AddLine("Click: Options", 1, 1, 1)
    GameTooltip:AddLine("Shift+Click: Toggle Proximity", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Ctrl+Click: Toggle Battleground", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag to move", 0.6, 0.6, 0.6)
    GameTooltip:Show()

    if SoundAlerterMinimapButton.hoverAnimGroup then
        SoundAlerterMinimapButton.unhoverAnimGroup:Stop()
        SoundAlerterMinimapButton.hoverAnimGroup:Play()
    end

    if SoundAlerterMinimapButton.border then
        SoundAlerterMinimapButton.border:SetVertexColor(0.0, 0.8, 0.8, 1.0)
    end

    local highlight = SoundAlerterMinimapButton.highlight
    if highlight then
        UIFrameFadeIn(highlight, 0.15, highlight:GetAlpha(), 0.3)
    end
end

function SoundAlerter:MinimapButton_OnLeave(self)
    GameTooltip:Hide()

    if SoundAlerterMinimapButton.unhoverAnimGroup then
        SoundAlerterMinimapButton.hoverAnimGroup:Stop()
        SoundAlerterMinimapButton.unhoverAnimGroup:Play()
    end

    if SoundAlerterMinimapButton.border then
        SoundAlerterMinimapButton.border:SetVertexColor(0.5, 0.5, 0.5, 0.8)
    end

    local highlight = SoundAlerterMinimapButton.highlight
    if highlight then
        UIFrameFadeOut(highlight, 0.15, highlight:GetAlpha(), 0)
    end
end

function SoundAlerter:MinimapButton_OnMouseDown(self, button)
    if button ~= "LeftButton" and button ~= "RightButton" then
        return
    end

    SoundAlerterMinimapButton.pendingShift = IsShiftKeyDown()
    SoundAlerterMinimapButton.pendingCtrl = IsControlKeyDown()

    if SoundAlerterMinimapButton.pressAnimGroup then
        SoundAlerterMinimapButton.releaseAnimGroup:Stop()
        SoundAlerterMinimapButton.pressAnimGroup:Play()
    end

    if SoundAlerterMinimapButton.icon then
        SoundAlerterMinimapButton.icon:SetVertexColor(0.425, 0.85, 0.85)
    end

    if SoundAlerterMinimapButton.border then
        SoundAlerterMinimapButton.border:SetVertexColor(1.0, 1.0, 1.0, 1.0)
    end

    local point, relativeTo, relativePoint, xOfs, yOfs = SoundAlerterMinimapButton:GetPoint(1)
    SoundAlerterMinimapButton.originalOffset = {point, relativeTo, relativePoint, xOfs, yOfs}
    SoundAlerterMinimapButton:ClearAllPoints()
    SoundAlerterMinimapButton:SetPoint(point, relativeTo, relativePoint, xOfs + 1, yOfs - 1)
end

function SoundAlerter:MinimapButton_OnMouseUp(self, button)
    if button ~= "LeftButton" and button ~= "RightButton" then
        return
    end

    if SoundAlerterMinimapButton.releaseAnimGroup then
        SoundAlerterMinimapButton.pressAnimGroup:Stop()
        SoundAlerterMinimapButton.releaseAnimGroup:Play()
    end

    if SoundAlerterMinimapButton.icon then
        SoundAlerterMinimapButton.icon:SetVertexColor(0.5, 1.0, 1.0)
    end

    if SoundAlerterMinimapButton.border then
        local startTime = GetTime()
        local duration = 0.15
        local startR, startG, startB = 1.0, 1.0, 1.0
        local endR, endG, endB = 0.0, 0.8, 0.8

        SoundAlerterMinimapButton.borderFadeFrame = SoundAlerterMinimapButton.borderFadeFrame or CreateFrame("Frame")
        SoundAlerterMinimapButton.borderFadeFrame:SetScript("OnUpdate", function(fadeFrame, elapsed)
            local progress = (GetTime() - startTime) / duration
            if progress >= 1.0 then
                SoundAlerterMinimapButton.border:SetVertexColor(endR, endG, endB, 1.0)
                fadeFrame:SetScript("OnUpdate", nil)
            else
                local r = startR + (endR - startR) * progress
                local g = startG + (endG - startG) * progress
                local b = startB + (endB - startB) * progress
                SoundAlerterMinimapButton.border:SetVertexColor(r, g, b, 1.0)
            end
        end)
    end

    if SoundAlerterMinimapButton.originalOffset then
        local point, relativeTo, relativePoint, xOfs, yOfs = unpack(SoundAlerterMinimapButton.originalOffset)
        SoundAlerterMinimapButton:ClearAllPoints()
        SoundAlerterMinimapButton:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
        SoundAlerterMinimapButton.originalOffset = nil
    end
end

function SoundAlerter:UpdateMinimapButtonIcon()
    if not SoundAlerterMinimapButton or not SoundAlerterMinimapButton.icon then return end

    local proximityOn = sadb.proximityEnabled
    local battlegroundOn = sadb.battlegroundAlertsEnabled
    local icon = SoundAlerterMinimapButton.icon

    if proximityOn and battlegroundOn then

        icon:SetTexture("Interface\\ICONS\\Ability_Warrior_VictoryRush")
    elseif proximityOn and not battlegroundOn then

        icon:SetTexture("Interface\\ICONS\\Ability_Hunter_SniperShot")
    elseif not proximityOn and battlegroundOn then

        icon:SetTexture("Interface\\ICONS\\INV_Banner_02")
    else

        icon:SetTexture("Interface\\ICONS\\ability_warrior_battleshout")
    end

    icon:SetVertexColor(0.5, 1.0, 1.0)
end

function SoundAlerter:MinimapButton_OnClick(self, button)
    if button == "LeftButton" then
        local wasShift = SoundAlerterMinimapButton.pendingShift
        local wasCtrl = SoundAlerterMinimapButton.pendingCtrl

        SoundAlerterMinimapButton.pendingShift = false
        SoundAlerterMinimapButton.pendingCtrl = false

        if wasShift then
            sadb.proximityEnabled = not sadb.proximityEnabled
            if sadb.proximityEnabled then
                sadb.proximityWorld = true
            end
            local status = sadb.proximityEnabled and "|cff00FF00ON|r" or "|cffFF0000OFF|r"
            SoundAlerter:Print("Proximity Alerts: " .. status)
            SoundAlerter:ScheduleTimer("UpdateMinimapButtonIcon", 0.05)
        elseif wasCtrl then
            sadb.battlegroundAlertsEnabled = not sadb.battlegroundAlertsEnabled
            local status = sadb.battlegroundAlertsEnabled and "|cff00FF00ON|r" or "|cffFF0000OFF|r"
            SoundAlerter:Print("Battleground Alerts: " .. status)
            SoundAlerter:ScheduleTimer("UpdateMinimapButtonIcon", 0.05)
        else
            SoundAlerter:ShowConfig()
        end
    elseif button == "RightButton" then
        SoundAlerter:ShowConfig()
    end
end

function SoundAlerter:MinimapButton_OnDragStart(self)
    self:StartMoving()
end

function SoundAlerter:MinimapButton_OnDragStop(self)
    self:StopMovingOrSizing()
    local minimapX, minimapY = Minimap:GetCenter()
    local buttonX, buttonY = self:GetCenter()

    sadb.MinimapButtonPosition = {
        x = buttonX - minimapX,
        y = buttonY - minimapY,
    }
end

function SoundAlerter:OnInitialize()
    self.moduleInitErrors = {}

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

    self.db1 = LibStub("AceDB-3.0"):New("SoundAlerterDB", dbDefaults, "Default");
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

    self:Print("|cffFF7D0ASoundAlerter|r by |cff00FF00th|r|cff00D4FF3|r|cff00FF00pajay|r - /SA ")
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
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED")
    self:RegisterEvent("UNIT_SPELLCAST_START")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
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
    self.throttled = {}
    self.smarter = 0

    self.proximityAlertCache = {}
    self.proximityRecentGUIDs = {}
    self.identityRetryAt = {}
    self.enemyOnYouAt = {}
    self.guidToClassCache = {}
    self.trackedNameplates = {}
    self.enterWorldTime = 0

    self:ApplyNameplateRange()
    self:ApplyTotemPlates()

    self.failedGUIDLookups = {}

    self.classDetectionStats = {
        learnedClassCount = 0,
    }

    self:InitializeLearnedClassesCache()

    self:InitializeModule("ProximityToasts")
    self:InitializeModule("ResourceBar")
    self:InitializeModule("CastingBars")
    self:InitializeModule("SpellTracker")
    self:InitializeModule("CastFeed")
    self:InitializeModule("CombatTimer")
    self:InitializeModule("SpeedMeter")
    self:InitializeModule("MinimapTracking")

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
    self:ScheduleRepeatingTimer("SaveLearnedClasses", 60)

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

function SoundAlerter:SendChat(message, channels)
    if IsChatBlocked() then
        self:Debug("Chat", "not sent, chat is locked down: %s", message)
        return false
    end
    local sent = false
    local inInstance = IsInInstance()
    for _, channel in ipairs(channels) do
        local target, reason = ResolveChatChannel(channel, inInstance)
        if not target then
            self:Debug("Chat", "%s skipped, %s", channel, reason)
        elseif pcall(SendChatMessage, message, target, nil, nil) then
            sent = true
            self:Debug("Chat", "sent to %s: %s", target, message)
        else
            self:Debug("Chat", "%s send failed", target)
        end
    end
    return sent
end

function SoundAlerter:BroadcastChat(message)
    if sadb.chatgroups.NONE then return end
    local channels = {}
    for channel, enabled in pairs(sadb.chatgroups) do
        if enabled and channel ~= "NONE" then
            channels[#channels + 1] = channel
        end
    end
    local sent = self:SendChat(message, channels)
    if not sent then
        self:Debug("Chat", "no channel available, printed locally")
        self:Print(message)
    end
end

function SoundAlerter:PlaySpell(list, spellID, sourceGUID, sourceName)
    if list[spellID] then
        if not sadb[list[spellID]] then return end
        self:Debug("Sound", "%s.mp3 (spell %d, source %s)", list[spellID], spellID, tostring(sourceName or "?"))
        SoundAlerter:PlayVoice(sadb.sapath..list[spellID]..".mp3");

        if sadb.statistics and sadb.statistics.enabled then
            local Statistics = self:GetModule("Statistics")
            if Statistics then
                Statistics:RecordAlert("spellAlerts", spellID, sourceGUID, sourceName)
            end
        end
        return true
    end
end

function SoundAlerter:spellOptions(order, spellID, ...)
    local spellname, _, icon = GetSpellInfo(spellID)

    if spellname ~= nil then
        return {
            type = 'toggle',
            name = "\124T"..icon..":24\124t"..spellname,
            desc = function ()
                local spellLink = GetSpellLink(spellID)
                if spellLink then
                    GameTooltip:SetHyperlink(spellLink);
                end
            end,
            descStyle = "custom",
            order = order,
        }
    else
        return {
            type = 'description',
            name = "Unknown Spell ID (" .. spellID .. ")",
            desc = "This spell ID could not be found by your WoW client. It has been disabled.",
            order = order,
            disabled = true,
        }
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
end

function SoundAlerter:ApplyNameplateRange()
    if sadb.overrideNameplateRange then
        SetCVar("nameplateMaxDistance", sadb.nameplateRange or 60)
    else
        SetCVar("nameplateMaxDistance", GetCVarDefault("nameplateMaxDistance"))
    end
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

function SoundAlerter:PLAYER_ENTERING_WORLD()
    CombatLogClearEntries()
    self:ClearAuraTracking()
    if self.MinimapTracking then
        self.MinimapTracking:OnEnterWorld()
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

function SoundAlerter:PLAYER_LOGOUT()
    self:RemoveAllAuraSounds()
    self:RestoreTotemPlates()
    self:SaveLearnedClasses()

    if sadb.statistics and sadb.statistics.enabled then
        local Statistics = self:GetModule("Statistics")
        Statistics:SaveSessionHistory()
    end
end

function SoundAlerter:HandleCommand(input)
    local command, rest = input:match("^(%S*)%s*(.-)$")
    command = command:lower()

    if command == "stats" then
        self:ShowPerformanceStats()
    elseif command == "help" then
        self:Print("|cffFFD700=== SoundAlerter Commands ===|r")
        self:Print("|cff00FFFF[General]|r")
        self:Print("  |cffFFFFFF/sa|r - Open options panel")
        self:Print("  |cffFFFFFF/sa stats|r - Show class detection performance stats")
        self:Print("  |cffFFFFFF/sa probe|r - Print what the client lets the addon read (turn on Debug Mode first to record events)")
        self:Print("  |cffFFFFFF/sa snooze [minutes]|r / |cffFFFFFF/sa unsnooze|r - Silence proximity and enemy awareness alerts for a while")
        self:Print("  |cffFFFFFF/sa watch [guild] <name>|r / |cffFFFFFF/sa unwatch [guild] <name>|r / |cffFFFFFF/sa watchlist|r - Manage the watchlist")
        self:Print("  |cffFFFFFF/sa aurasound|r - Test engine aura sounds; |cffFFFFFF/sa aurasound play <spellID> [unit]|r listens for 30 s")
        self:Print("  |cffFFFFFF/sa help|r - Show this command list")
        if self.ProximityToasts then
            self.ProximityToasts:PrintHelp()
        end
        if self.FlagAlerts then
            self.FlagAlerts:PrintHelp()
        end
        if self.CombatTimer then
            self.CombatTimer:PrintHelp()
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
    elseif command == "ctprobe" then
        if self.CombatTimer then
            self.CombatTimer:HandleCommand(rest)
        else
            self:Print("|cffFF0000CombatTimer module not loaded.|r")
        end
    elseif command == "apicheck" then
        self:RunApiCheck()
    elseif command == "zonelog" then
        self:PrintZoneLog()
    elseif command == "probe" then
        self:PrintProbeReport()
    elseif command == "watch" or command == "unwatch" or command == "watchlist" then
        self:HandleWatchCommand(command, rest)
    elseif command == "aurasound" then
        self:AuraSoundCommand(rest)
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

function SoundAlerter:ShowPerformanceStats()
    local stats = self.classDetectionStats

    self:Print("=== |cffFF7D0AClass Detection Performance Stats|r ===")

    self:Print("Learned classes: |cff00FF00" .. stats.learnedClassCount .. "|r")

    local learnedStatus = sadb.learnedClassesEnabled and "|cff00FF00Enabled|r" or "|cffFF0000Disabled|r"
    local negativeStatus = sadb.negativeCacheEnabled and "|cff00FF00Enabled|r" or "|cffFF0000Disabled|r"
    self:Print("Persistent cache: " .. learnedStatus)
    self:Print("Negative cache: " .. negativeStatus)

    self:Print("Use |cffFFFF00/sa stats|r to refresh")
end

function SoundAlerter:CleanupProximityCaches()
    local currentTime = GetTime()
    local cooldown = sadb.proximityCooldown or 30

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

    for key, timestamp in pairs(self.enemyOnYouAt) do
        if currentTime - timestamp > 60 then
            self.enemyOnYouAt[key] = nil
        end
    end

    self:PruneWatchlist(currentTime)

    local cacheSize = 0
    for _ in pairs(self.guidToClassCache) do
        cacheSize = cacheSize + 1
    end
    if cacheSize > 500 then
        local entriesToRemove = cacheSize - 500
        local removed = 0
        for guid in pairs(self.guidToClassCache) do
            self.guidToClassCache[guid] = nil
            removed = removed + 1
            if removed >= entriesToRemove then
                break
            end
        end
    end

    for guid in pairs(self.proximityRecentGUIDs) do
        self.proximityRecentGUIDs[guid] = nil
    end

    if sadb.negativeCacheEnabled then
        local negativeTTL = sadb.negativeCacheTTL or 5
        for guid, timestamp in pairs(self.failedGUIDLookups) do
            if currentTime - timestamp > negativeTTL then
                self.failedGUIDLookups[guid] = nil
            end
        end
    end
end

function SoundAlerter:InitializeLearnedClassesCache()
    if not sadb.learnedClassesEnabled then
        self.learnedClasses = {}
        return
    end

    if not sadb.learnedClasses or type(sadb.learnedClasses) ~= "table" then
        sadb.learnedClasses = {}
    end

    self.learnedClasses = sadb.learnedClasses
    self.learnedClassesDirty = false

    local count = 0
    for _ in pairs(self.learnedClasses) do
        count = count + 1
    end

    local maxSize = sadb.learnedClassesMaxSize or 5000
    if count > maxSize then
        self:Debug("Classes", "learned class cache too large (%d), trimming to %d", count, maxSize)
        self:LimitLearnedClassesCache(maxSize)
        count = maxSize
    end

    self.classDetectionStats.learnedClassCount = count
end

function SoundAlerter:LimitLearnedClassesCache(maxSize)
    local entries = {}
    for guid in pairs(self.learnedClasses) do
        table.insert(entries, guid)
    end

    if #entries > maxSize then
        local toRemove = #entries - maxSize
        for i = 1, toRemove do
            self.learnedClasses[entries[i]] = nil
        end
    end

    sadb.learnedClasses = self.learnedClasses
    self.learnedClassesDirty = false
end

function SoundAlerter:SaveLearnedClasses()
    if not sadb.learnedClassesEnabled then return end
    if not self.learnedClassesDirty then return end

    sadb.learnedClasses = self.learnedClasses
    self.learnedClassesDirty = false

    local count = 0
    for _ in pairs(self.learnedClasses) do
        count = count + 1
    end
    self.classDetectionStats.learnedClassCount = count
end

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

local INTERRUPT_ABILITY_SPELLS = {
    [1766] = true,
    [1767] = true,
    [1768] = true,
    [1769] = true,
    [6552] = true,
    [6554] = true,
    [2139] = true,
    [19647] = true,
    [16979] = true,
    [72] = true,
    [8042] = true,
}
local lastInterruptCast = nil
local lastEnemyCast = {}
local lastEnemyCastAt = {}
local lastPlayerInterrupt = nil
local pendingEnemyInterrupt = nil
local INTERRUPT_CORRELATION_WINDOW = 0.6

local function InterrupterIsPlayer(interruptedBy)
    if interruptedBy == nil or issecretvalue(interruptedBy) then return nil end
    return interruptedBy == UnitGUID("player")
end

function SoundAlerter:AnnounceEnemyInterrupt(enemyName, interruptedSpellID, abilitySpellID, unit)
    self:Debug("Interrupt", "paired: %s interrupted with spell %s (interrupted spell %s); sound=%s chat=%s emote=%s",
        enemyName, tostring(abilitySpellID), tostring(interruptedSpellID or "unknown"),
        tostring(not sadb.interrupt), tostring(not sadb.chatalerts and sadb.interruptenemy and true or false), tostring(sadb.interruptemote and true or false))
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
    if sadb.chatalerts or not sadb.interruptenemy then return end

    local abilityText = abilitySpellID and (GetSpellLink(abilitySpellID) or GetSpellInfo(abilitySpellID)) or ""
    local interruptedText = interruptedSpellID and (GetSpellLink(interruptedSpellID) or GetSpellInfo(interruptedSpellID)) or "spell"
    local it = gsub(sadb.InterruptEnemyText, "(#spell#)", abilityText)
    it = gsub(it, "#interruptedspellname#", interruptedText)
    local finalMessage = gsub(it, "(#enemy#)", enemyName)
    finalMessage = string.gsub(finalMessage, "[\\]", "")
    self:BroadcastChat(finalMessage)
end

function SoundAlerter:ScheduleInterruptReady(spellID)
    if self.interruptReadyTimer then
        self:CancelTimer(self.interruptReadyTimer)
        self.interruptReadyTimer = nil
    end
    if not sadb.interruptReadyVoice then return end
    local cooldown = SA_Interrupt.Cooldown(spellID)
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
    if issecretvalue(spellID) or not INTERRUPT_ABILITY_SPELLS[spellID] then return end
    local now = GetTime()
    self:ScheduleInterruptReady(spellID)
    local pending = pendingEnemyInterrupt
    if pending and (now - pending.time) <= INTERRUPT_CORRELATION_WINDOW then
        pendingEnemyInterrupt = nil
        lastPlayerInterrupt = nil
        self:AnnounceEnemyInterrupt(pending.name, pending.spellID, spellID, pending.unit)
        return
    end
    lastPlayerInterrupt = { spellID = spellID, time = now }
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

function SoundAlerter:ResyncUnitAuras(unit, tracked, ctx)
    local hadBefore = {}
    if unitAuraCount[unit] then
        for spellID in pairs(unitAuraCount[unit]) do
            hadBefore[spellID] = true
        end
    end

    unitAuraMap[unit] = {}
    unitAuraCount[unit] = {}

    local sourceUnits = {}
    for spellID in pairs(tracked) do
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

    for spellID in pairs(unitAuraCount[unit]) do
        if not hadBefore[spellID] then
            self:HandleDebuffApplied(unit, spellID, ctx.isPlayer, ctx.isTargetOrFocus, ctx.isTracked, sourceUnits[spellID], ctx.isAlly)
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

function SoundAlerter:LOSS_OF_CONTROL_ADDED(event, index)
    if not sadb.lossOfControlVoice then return end
    if not (C_LossOfControl and C_LossOfControl.GetActiveLossOfControlData) then return end
    if not self:IsAlertZoneAllowed() then return end
    local ok, data = pcall(C_LossOfControl.GetActiveLossOfControlData, Plain(index) or 1)
    if not ok or type(data) ~= "table" then return end
    local category = SA_LossOfControl.Category(Plain(data.locType))
    if not category then return end
    local now = GetTime()
    if not SA_LossOfControl.ShouldSpeak(sadb, lossOfControlState, category, now) then return end
    lossOfControlState.lastSpoken[category] = now
    self:Debug("LossOfControl", "%s (%s)", category, tostring(Plain(data.locType)))
    self:PlayVoice(sadb.sapath .. SA_LossOfControl.Voice(category))
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

function SoundAlerter:HandleDebuffApplied(unit, spellID, isPlayer, isTargetOrFocus, isTracked, sourceUnit, isAlly)
    self:CheckCustomAlerts("SPELL_AURA_APPLIED", sourceUnit, unit, spellID)

    if isAlly then
        if not sadb.dArenaPartner then
            self:PlaySpell(self.spellList.friendCCSuccess, spellID)
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
        if not sadb.chatalerts then
            if ((spellID == 450600 and sadb.hexselffriend) or
                ((spellID == 6215 or spellID == 17928 or spellID == 5484) and sadb.fearselffriend) or
                ((spellID == 12826 or spellID == 118 or spellID == 28271 or spellID == 28272) and sadb.polyenemy) or
                (spellID == 2094 and sadb.blindselffriend)) then
                local form1 = gsub(sadb.selfchat, "(#spell#)", (GetSpellLink(spellID) or ""))
                local form2 = gsub(form1, "(#target#)", "me")
                local message = gsub(form2, "(#enemy#)", "")
                self:BroadcastChat(message)
            elseif (spellID == 6770 or spellID == 11297 or spellID == 2070) and sadb.sapselffriend then
                local message = gsub(sadb.sapselftext, "(#spell#)", (GetSpellLink(spellID) or ""))
                self:BroadcastChat(message)
            end
        end
        return
    end

    if not (isTargetOrFocus or isTracked) then return end

    local name = SafeUnitName(unit)
    local guid = UnitGUID(unit)
    if not name or not Plain(guid) then return end

    local isAllySource = sourceUnit ~= nil and UnitKind(sourceUnit) == "party"
    if isAllySource and not sadb.dArenaPartner then
        self:PlaySpell(self.spellList.friendCCenemy, spellID)
    elseif not sadb.dEnemyDebuff and not self:HasEngineAuraSound(unit, "Added", spellID) then
        self:PlaySpell(self.spellList.enemyDebuffs, spellID, guid, name)
    end

    if not sadb.chatalerts then
        if (((spellID == 6770 or spellID == 11297 or spellID == 2070) and sadb.sapenemy) or
            (spellID == 2094 and sadb.blindenemy) or
            (spellID == 450600 and sadb.hexenemy) or
            (spellID == 5782 and sadb.fearenemy)) then
            local ccenemychat = gsub(sadb.enemychat, "(#spell#)", (GetSpellLink(spellID) or ""))
            local message = gsub(ccenemychat, "(#enemy#)", name)
            self:BroadcastChat(message)
        end

        if sadb.bubbleenemy and spellID == 642 then
            local message = gsub(sadb.bubbleenemytext, "(#enemy#)", name)
            self:BroadcastChat(message)
        end
    end

    if ((sadb.myself and isTargetOrFocus) or (sadb.enemyinrange and isTracked)) and not sadb.castSuccess and not sadb.aruaApplied then
        self:PlaySpell(self.spellList.auraApplied, spellID)
        if not sadb.chatalerts and sadb.chatauraApplied and self.spellList.auraApplied[spellID] then
            local buffMsg = gsub(sadb.enemybuffchat, "(#spell#)", (GetSpellLink(spellID) or ""))
            buffMsg = gsub(buffMsg, "(#enemy#)", name)
            self:BroadcastChat(buffMsg)
        end
    end
end

function SoundAlerter:HandleDebuffRemoved(unit, spellID, isTargetOrFocus, isAlly, isTracked)
    self:CheckCustomAlerts("SPELL_AURA_REMOVED", nil, unit, spellID)

    if isAlly then
        if not sadb.dArenaPartner then
            self:PlaySpell(self.spellList.enemyDebuffdownAP, spellID)
        end
        return
    end

    if not (isTargetOrFocus or isTracked) then return end

    local name = SafeUnitName(unit)
    if not name then return end

    if not sadb.dEnemyDebuffDown and not self:HasEngineAuraSound(unit, "Removed", spellID) then
        self:PlaySpell(self.spellList.enemyDebuffdown, spellID)
    end

    if not sadb.chatalerts and sadb.chatdownfriend then
        if ((spellID == 450600 and sadb.hexenemy) or
            (spellID == 2094 and sadb.blindenemy) or
            ((spellID == 6770 or spellID == 11297 or spellID == 2070) and sadb.sapenemy) or
            ((spellID == 12826 or spellID == 118 or spellID == 28271 or spellID == 28272) and sadb.polyenemy) or
            ((spellID == 6215 or spellID == 5484 or spellID == 17928) and sadb.fearenemy)) then
            self:BroadcastChat((GetSpellLink(spellID) or GetSpellInfo(spellID) or "Unknown Spell").." down on "..name)
        end
    end

    if not sadb.auraRemoved then
        self:PlaySpell(self.spellList.auraRemoved, spellID)
    end
    if not sadb.chatalerts and sadb.chatauraRemoved and self.spellList.auraRemoved[spellID] then
        local downMsg = gsub(sadb.auraRemovedChat, "(#spell#)", (GetSpellLink(spellID) or ""))
        downMsg = gsub(downMsg, "(#enemy#)", name)
        self:BroadcastChat(downMsg)
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

    local spellName = GetSpellInfo(spellID)
    local destName = destUnit and SafeUnitName(destUnit)
    local sourceName = sourceUnit and SafeUnitName(sourceUnit)

    for _, css in pairs(sadb.custom) do
        if css.eventtype and css.eventtype[eventName] then
            local spellIdNum = css.spellidNum
            if spellIdNum == nil or css.spellidNumSrc ~= css.spellid then
                spellIdNum = tonumber(css.spellid)
                css.spellidNum = spellIdNum
                css.spellidNumSrc = css.spellid
            end

            if spellID == spellIdNum or (css.acceptSpellName and spellName and css.spellname == spellName) then
                local destOK = self:MatchesUidFilter(destUnit, css.destuidfilter, css.destcustomname)
                local sourceOK = self:MatchesUidFilter(sourceUnit, css.sourceuidfilter, css.sourcecustomname)
                local destTypeOK = self:MatchesTypeFilter(destUnit, css.desttypefilter)
                local sourceTypeOK = self:MatchesTypeFilter(sourceUnit, css.sourcetypefilter)

                if destOK and sourceOK and destTypeOK and sourceTypeOK then
                    self:Debug("CustomSound", "%s matched on %s (spell %s, source %s -> dest %s)", tostring(css.name), eventName, tostring(spellID), tostring(sourceName), tostring(destName))

                    if not css.chatAlert then
                        SoundAlerter:PlayVoice("Interface\\Addons\\SoundAlerter\\CustomSounds\\"..css.soundfilepath, "Master")
                    else
                        local spell = gsub(css.chatalerttext, "([#]spell[#])", (GetSpellLink(spellID) or ""))
                        local targetName = destName or sourceName or ""
                        local message
                        if eventName == "SPELL_CAST_START" then
                            message = gsub(spell, "([#]enemy[#])", "")
                        else
                            message = gsub(spell, "([#]enemy[#])", targetName)
                        end
                        self:BroadcastChat(message)
                    end
                end
            end
        end
    end
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
    if not UnitExists(unit) then return end

    if isArena then
        local currentZoneType, pvpType = self.cachedInstanceType, self.cachedZonePvpType
        if ((currentZoneType == "arena") or (pvpType == "arena")) and sadb.drinking then
            if not DRINK_SPELL then
                DRINK_SPELL = GetSpellInfo(57073)
            end
            if UnitAura(unit, DRINK_SPELL) then
                SoundAlerter:PlayVoice(sadb.sapath.."drinking.mp3");
            end
        end
    end

    local isTracked = isNameplate and self:IsTrackedNameplate(unit)
    if not (isPlayer or isTargetOrFocus or isTracked or isAlly) then return end
    if not isPlayer and not isAlly and (not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit)) then return end
    if isAlly and (not UnitIsPlayer(unit) or UnitIsEnemy("player", unit)) then return end
    if not self:IsAlertZoneAllowed() then return end

    local tracked = GetTrackedAuraSpellIDs()
    local ctx = { isPlayer = isPlayer, isTargetOrFocus = isTargetOrFocus, isTracked = isTracked, isAlly = isAlly }

    local usable, added, removed = ReadableDelta(updateInfo)
    if sadb.debugmode then
        local kind = isPlayer and "player" or isTargetOrFocus and unit or isArena and "arena" or isNameplate and "nameplate" or "party"
        local path = (usable and unitAuraMap[unit]) and "delta" or (not unitAuraMap[unit] and "resync (first sight)" or "resync (payload unreadable)")
        self:ProbeAuraUpdate(unit, kind, updateInfo, path)
    end

    if not unitAuraMap[unit] or not usable then
        self:ResyncUnitAuras(unit, tracked, ctx)
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
        self:ResyncUnitAuras(unit, tracked, ctx)
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

function SoundAlerter:GetApproxRange(unit)
    if not UnitExists(unit) then return nil end

    local function withinInteractRange(index)
        local ok, inRange = pcall(CheckInteractDistance, unit, index)
        return ok and Plain(inRange) == true
    end

    if withinInteractRange(3) then
        return "Close"
    elseif withinInteractRange(1) then
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
    for _, unit in pairs(self.trackedNameplates) do
        self:CheckProximityAlert(unit)
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
    local gate = C_Secrets and C_Secrets.ShouldUnitComparisonBeSecret
    if gate then
        local ok, secret = pcall(gate, unit .. "target", "player")
        if not ok or secret then return nil end
    end
    local ok, same = pcall(UnitIsUnit, unit .. "target", "player")
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
    local key = kind .. guid
    local now = GetTime()
    local last = self.enemyOnYouAt[key]
    if last and now - last < (rule.spacing or sadb.enemyTargetsYouCooldown or 8) then return end
    if EnemyTargetsPlayer(unit) ~= true then return end
    self.enemyOnYouAt[key] = now
    self:Debug("Targeting", "%s on you from %s", kind, unit)
    self:PlayVoice(sadb.sapath .. rule.voice)
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
    local spotted = unit .. "target"
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

function SoundAlerter:CheckProximityAlert(unit, allySpotted)
    if not sadb.proximityEnabled then return end

    if not UnitExists(unit) then return end
    if not UnitIsPlayer(unit) then return end
    if not UnitIsEnemy("player", unit) then return end
    if not allySpotted and not UnitIsVisible(unit) then return end

    local guid = UnitGUID(unit)
    if not Plain(guid) then return end

    if guid:sub(1, 7) ~= "Player-" then return end

    local currentTime = GetTime()
    local cooldown = sadb.proximityCooldown or 30
    if self.proximityAlertCache[guid] then
        local timeElapsed = currentTime - self.proximityAlertCache[guid]
        if timeElapsed < cooldown then return end
    end

    if currentTime - self.enterWorldTime < 10 then return end
    if self:IsQuiet() then return end

    local currentZoneType, pvpType = self.cachedInstanceType, self.cachedZonePvpType

    local inArena = (currentZoneType == "arena") or (pvpType == "arena")
    local inBattleground = (currentZoneType == "pvp")
    local inWorld = (pvpType == "contested" or pvpType == "hostile" or pvpType == "friendly")
    local inSanctuary = (pvpType == "sanctuary" or pvpType == nil)

    if inArena and not sadb.proximityArena then return end
    if inBattleground and not sadb.proximityBattleground then return end
    if inWorld and not sadb.proximityWorld then return end
    if inSanctuary and not sadb.proximitySanctuary then return end
    if not (inArena or inBattleground or inWorld or inSanctuary) then return end

    local unitName = UnitName(unit)
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
        self:ScheduleIdentityRetry(unit, guid, allySpotted)
        return
    end
    if issecretvalue(unitLevel) then return end

    local approxRange = self:GetApproxRange(unit) or (allySpotted and "Spotted" or nil)
    if SA_Distance.IsRestricted(sadb.proximityMaxBand) and not SA_Distance.Allows(sadb.proximityMaxBand, approxRange) then
        return
    end

    self.guidToClassCache[guid] = unitClass
    self.proximityAlertCache[guid] = currentTime

    local classAudioFile = CLASS_AUDIO_MAP[unitClass]
    if classAudioFile then
        SoundAlerter:PlayVoice(sadb.sapath .. classAudioFile .. ".mp3", "Master")
    end
    self:ScheduleTimer(function()
        SoundAlerter:PlayVoice(sadb.sapath .. "detected.mp3", "Master")
    end, 0.8)

    do
        local Statistics = self:GetModule("Statistics")
        if Statistics and Statistics:GetSettings().enabled then
            Statistics:RecordAlert("proximityAlerts", nil, guid, unitName, nil, unitClass)
        end
    end

    if self.ProximityToasts and self.ProximityToasts:GetSettings().enabled then
        local nearbyCount = 0
        for _ in pairs(self.trackedNameplates) do
            nearbyCount = nearbyCount + 1
        end
        self.ProximityToasts:ShowToast(unitName, unitClass, approxRange, guid, unitLevel, not allySpotted and unit or nil, nil, nil, nearbyCount)
    end

    if sadb.proximityChat and sadb.proximityChatText then
        local chatText = gsub(sadb.proximityChatText, "#class#", unitClass)
        chatText = gsub(chatText, "#player#", unitName)

        self:BroadcastChat(chatText)
    end
end

function SoundAlerter:PLAYER_TARGET_CHANGED()
    self:ClearAuraTracking("target")
    self:RefreshEnemyAuraUnits()
    self:CheckWatchlist("target")
    self:CheckProximityAlert("target")
end

function SoundAlerter:PLAYER_FOCUS_CHANGED()
    self:ClearAuraTracking("focus")
    self:RefreshEnemyAuraUnits()
end

function SoundAlerter:UPDATE_MOUSEOVER_UNIT()
    self:CheckWatchlist("mouseover")
    self:CheckProximityAlert("mouseover")
end

function SoundAlerter:NAME_PLATE_UNIT_ADDED(event, unit)
    if sadb.debugmode then self:ProbeNameplate(unit) end
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return end

    local guid = UnitGUID(unit)
    if not Plain(guid) then return end

    self.trackedNameplates[guid] = unit

    self:CheckWatchlist(unit)
    self:CheckProximityAlert(unit)
end

function SoundAlerter:NAME_PLATE_UNIT_REMOVED(event, unit)
    local guid = UnitGUID(unit)
    if not Plain(guid) then return end

    self.trackedNameplates[guid] = nil
    self:ClearAuraTracking(unit)
end

function SoundAlerter:IsTrackedNameplate(unit)
    local guid = UnitGUID(unit)
    if not Plain(guid) then return false end
    return self.trackedNameplates[guid] ~= nil
end

local function IsRelevantCastUnit(unit)
    if unit == "target" or unit == "focus" then return true end
    local kind = UnitKind(unit)
    return kind == "nameplate" or kind == "arena"
end

function SoundAlerter:UNIT_SPELLCAST_START(event, unit, castGUID, spellID)
    if unit == "target" or unit == "focus" or unit == "mouseover" then
        lastEnemyCast[unit] = not issecretvalue(spellID) and spellID or nil
        lastEnemyCastAt[unit] = GetTime()
    end
    if not unit or not IsRelevantCastUnit(unit) then return end
    if not self:IsAlertZoneAllowed() then return end
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return end
    self:AlertEnemyOnYou(unit, "casting")
    if issecretvalue(spellID) then return end

    local isTargetOrFocus = (unit == "target" or unit == "focus")
    local isTracked = not isTargetOrFocus and self:IsTrackedNameplate(unit)
    local isArenaEnemy = not isTargetOrFocus and not isTracked and UnitKind(unit) == "arena"

    if isArenaEnemy then
        if sadb.dArenaPartner then return end
        local currentZoneType, pvpType = self.cachedInstanceType, self.cachedZonePvpType
        if not ((currentZoneType == "arena") or (pvpType == "arena")) then return end
        for i = 1, 5 do
            if playerName == SafeUnitName("arena"..i.."target") then return end
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
            if not sadb.chatalerts and sadb.chatcastStart and self.spellList.castStart[spellID] then
                local startMsg = gsub(sadb.castStartChat, "(#spell#)", (GetSpellLink(spellID) or ""))
                startMsg = gsub(startMsg, "(#enemy#)", name)
                self:BroadcastChat(startMsg)
            end
        end
    end
end

function SoundAlerter:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
    if unit == "player" or (unit == "pet" and sadb.interruptPets) then
        self:RecordPlayerInterrupt(spellID)
        return
    end
    if not unit or not IsRelevantCastUnit(unit) then return end
    if not self:IsAlertZoneAllowed() then return end
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return end
    if issecretvalue(spellID) then return end

    local isTargetOrFocus = (unit == "target" or unit == "focus")
    local isTracked = not isTargetOrFocus and self:IsTrackedNameplate(unit)
    if not (isTargetOrFocus or isTracked) then return end

    local guid = UnitGUID(unit)
    local name = SafeUnitName(unit)
    if not Plain(guid) or not name then return end

    if INTERRUPT_ABILITY_SPELLS[spellID] then
        lastInterruptCast = { spellID = spellID, name = name, time = GetTime() }
    end

    self:CheckCustomAlerts("SPELL_CAST_SUCCESS", unit, nil, spellID)

    if not sadb.chatalerts then
        local isVanish = (spellID == 1856 or spellID == 1857 or spellID == 27617)
        local isStealth = (spellID == 1784 or spellID == 1785)
        local isProwl = (spellID == 5215 or spellID == 6783 or spellID == 9913)

        if ((sadb.vanishenemy and isVanish) or (sadb.stealthenemy and isStealth) or (sadb.prowlenemy and isProwl))
           and (isTargetOrFocus or ((sadb.vanishTF and isVanish) or (sadb.stealthTF and isStealth) or (sadb.prowlTF and isProwl))) then
            local message = gsub(gsub(sadb.enemychat, "(#spell#)", (GetSpellLink(spellID) or "")), "(#enemy#)", name)
            self:BroadcastChat(message)
        end
    end

    if not sadb.chatalerts and sadb.trinketalert and spellID == 1259718 then
        local message = gsub(sadb.trinketalerttext, "(#enemy#)", name)
        self:BroadcastChat(message)
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
        if not ((sadb.enemyinrange and isTracked and not isTargetOrFocus) and spellID == 1245940) then
            self:PlaySpell(self.spellList.castSuccess, spellID, guid, name)
        end
    end
end

function SoundAlerter:UNIT_SPELLCAST_INTERRUPTED(event, unit, castGUID, spellID, interruptedBy)
    if unit ~= "player" and unit ~= "target" and unit ~= "focus" and unit ~= "mouseover" then return end
    if not self:IsAlertZoneAllowed() then return end
    if sadb.debugmode then
        self:ProbeValue("interrupted " .. unit .. " spell/by", spellID, interruptedBy)
        if interruptedBy ~= nil and not issecretvalue(interruptedBy) then
            self:ProbeValue("interrupted " .. unit .. " by is player", interruptedBy == UnitGUID("player"))
        end
    end
    if issecretvalue(spellID) then
        if unit == "player" then return end
        spellID = lastEnemyCast[unit]
    end

    local replacementText = spellID and (GetSpellLink(spellID) or GetSpellInfo(spellID)) or ""

    if unit == "player" then
        local matched = lastInterruptCast and (GetTime() - lastInterruptCast.time) <= INTERRUPT_CORRELATION_WINDOW
        if not matched then return end

        self:CheckCustomAlerts("SPELL_INTERRUPT", nil, unit, spellID)

        if not sadb.interrupt then
            SoundAlerter:PlayVoice(sadb.sapath.."lockout.mp3");
            if not sadb.chatalerts and sadb.interruptself then
                local it = gsub(sadb.InterruptSelfText, "(#spell#)", (GetSpellLink(lastInterruptCast.spellID) or GetSpellInfo(lastInterruptCast.spellID) or ""))
                it = gsub(it, "#interruptedspellname#", replacementText)
                local finalMessage = gsub(it, "(#enemy#)", lastInterruptCast.name)
                finalMessage = string.gsub(finalMessage, "[\\]", "")
                self:BroadcastChat(finalMessage)
            end
        end
        return
    end

    if spellID then
        self:CheckCustomAlerts("SPELL_INTERRUPT", nil, unit, spellID)
    end

    if unit ~= "target" and unit ~= "focus" and unit ~= "mouseover" then return end
    if not UnitExists(unit) or not UnitIsEnemy("player", unit) then return end

    local name = SafeUnitName(unit)
    if not name then return end

    local now = GetTime()
    if not SA_Interrupt.PassesMinCast(sadb.interruptMinCast, lastEnemyCastAt[unit], now) then
        self:Debug("Interrupt", "%s (%s) interrupted before the %.1fs minimum cast time", name, unit, sadb.interruptMinCast)
        return
    end
    local mine = lastPlayerInterrupt
    local byPlayer = InterrupterIsPlayer(interruptedBy)
    if byPlayer == false then
        self:Debug("Interrupt", "%s (%s) was interrupted by someone else", name, unit)
        return
    end
    if byPlayer then
        local ability = mine and (now - mine.time) <= INTERRUPT_CORRELATION_WINDOW and mine.spellID or nil
        lastPlayerInterrupt = nil
        pendingEnemyInterrupt = nil
        self:AnnounceEnemyInterrupt(name, spellID, ability, unit)
    elseif mine and (now - mine.time) <= INTERRUPT_CORRELATION_WINDOW then
        lastPlayerInterrupt = nil
        pendingEnemyInterrupt = nil
        self:AnnounceEnemyInterrupt(name, spellID, mine.spellID, unit)
    else
        self:Debug("Interrupt", "%s (%s) was interrupted, waiting %.1fs for your interrupt cast", name, unit, INTERRUPT_CORRELATION_WINDOW)
        pendingEnemyInterrupt = { name = name, spellID = spellID, time = now, unit = unit }
    end
end
