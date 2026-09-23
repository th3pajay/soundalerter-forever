
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
local sourcetype, sourceuid, desttype, destuid = {}, {}, {}, {}
local PARTY_UNIT_TOKENS = {"party1", "party2", "party3", "party4"}
local ARENA_UNIT_TOKENS = {"arena1", "arena2", "arena3", "arena4", "arena5"}

local unitAuraWatcher = CreateFrame("Frame")
unitAuraWatcher:SetScript("OnEvent", function(_, event, unit, updateInfo)
    SoundAlerter:UNIT_AURA(event, unit, updateInfo)
end)

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
    [COMBATLOG_FILTER_EVERYTHING] = L["Any"],
    [COMBATLOG_FILTER_FRIENDLY_UNITS] = L["Friendly"],
    [COMBATLOG_FILTER_HOSTILE_PLAYERS] = L["Hostile player"],
    [COMBATLOG_FILTER_HOSTILE_UNITS] = L["Hostile non-player"],
    [COMBATLOG_FILTER_NEUTRAL_UNITS] = L["Neutral"],
    [COMBATLOG_FILTER_ME] = L["Myself"],
    [COMBATLOG_FILTER_MINE] = L["My non-unit object (totem)"],
    [COMBATLOG_FILTER_MY_PET] = L["My pet"],
}

local function log(msg) DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF22SA|r:"..msg) end

function SoundAlerter:ChangeProfile()
	sadb = self.db1.profile
	self:OnOptionsProfileChanged()

	for k,v in SoundAlerter:IterateModules() do
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

	if self.FlagAlerts then
		self.FlagAlerts:OnProfileChanged()
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
		sadb.statistics.session = {
			totalAlerts = 0,
			startTime = GetTime(),
			byCategory = {
				spellAlerts = 0,
				proximityAlerts = 0,
				trinketAlerts = 0,
				flagAlerts = 0,
			},
		}
		sadb.statistics.allTime = {
			totalAlerts = 0,
			totalSessions = 0,
			topSpells = {},
			byCategory = {
				spellAlerts = 0,
				proximityAlerts = 0,
				trinketAlerts = 0,
				flagAlerts = 0,
			},
			byZone = {
				arena = 0,
				battleground = 0,
				worldPvP = 0,
			},
		}
		sadb.statistics.trackingStartTime = time()

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
    if not blizOptionsOk and sadb and sadb.debugmode then
        self:Print("|cffFF7D0ASoundAlerter|r: Blizzard Settings panel integration unavailable on this client (outdated AceConfigDialog-3.0) — use /sa instead.")
    end

    self:Print("|cffFF7D0ASoundAlerter|r by |cff00FF00th|r|cff00D4FF3|r|cff00FF00pajay|r - /SA ")
	self:CreateMinimapButton()

	if not self:LoadSpellDatabase() then

		self:BuildSpellDatabase()
	end
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
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    unitAuraWatcher:RegisterUnitEvent("UNIT_AURA", "arena1", "arena2", "arena3", "arena4", "arena5")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:RegisterEvent("PLAYER_LOGOUT")

    self:RefreshZoneState()

    if not self.SA_LANGUAGE[sadb.path] then sadb.path = self.SA_LOCALEPATH[GetLocale()] end
    self.throttled = {}
    self.smarter = 0

    self.proximityAlertCache = {}
    self.proximityRecentGUIDs = {}
    self.guidToClassCache = {}
    self.enterWorldTime = 0

    self.failedGUIDLookups = {}

    self.cleuTimingSamples = {}
    self.cleuTimingIndex = 1
    self.cleuTimingCount = 0

    self.classDetectionStats = {
        totalDetections = 0,
        cacheHits = 0,
        learnedCacheHits = 0,
        negativeCacheHits = 0,
        unitLookups = 0,
        apiLookups = 0,
        failedLookups = 0,
        totalLookupTime = 0,
        learnedClassCount = 0,
    }

    self:InitializeLearnedClassesCache()

    self:InitializeModule("ProximityToasts")
    self:InitializeModule("ResourceBar")
    self:InitializeModule("CastingBars")
    self:InitializeModule("SpellTracker")

    local Statistics = self:GetModule("Statistics")
    if Statistics then
        local ok, err = pcall(Statistics.Enable, Statistics)
        if not ok then
            self:Print("|cffFF7D0ASoundAlerter|r: Statistics failed to initialize and has been disabled for this session — "..tostring(err))
            self.moduleInitErrors.Statistics = tostring(err)
        end
    end

    self:ScheduleRepeatingTimer("CleanupProximityCaches", 30)
    self:ScheduleRepeatingTimer("SaveLearnedClasses", 60)

end

function SoundAlerter:PlayTrinket(sourceGUID, sourceName)
    PlaySoundFile(sadb.sapath.."Trinket.mp3");

    if sadb.statistics and sadb.statistics.enabled then
        local Statistics = self:GetModule("Statistics")
        if Statistics then
            Statistics:RecordAlert("trinketAlerts", nil, sourceGUID, sourceName)
        end
    end
end

function SoundAlerter:Interrupted()
    PlaySoundFile(sadb.sapath.."Interrupted.mp3");
end

function SoundAlerter:PlaySpell(list, spellID, sourceGUID, sourceName)
    if list[spellID] then
        if not sadb[list[spellID]] then return end
        if sadb.debugmode then print("<SA> DEBUG: Playing sound file: "..list[spellID]..".mp3"); end
        PlaySoundFile(sadb.sapath..list[spellID]..".mp3");

        if sadb.statistics and sadb.statistics.enabled then
            local Statistics = self:GetModule("Statistics")
            if Statistics then
                Statistics:RecordAlert("spellAlerts", spellID, sourceGUID, sourceName)
            end
        end
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

function SoundAlerter:ArenaClass(id)
    for i = 1, 5 do
        if id == UnitGUID("arena"..i) then
            return select(2, UnitClass("arena"..i))
        end
    end
end

function SoundAlerter:RefreshZoneState()
    self.cachedInInstance, self.cachedInstanceType = IsInInstance()
    self.cachedZonePvpType = GetZonePVPInfo()
end

function SoundAlerter:PLAYER_ENTERING_WORLD()
    CombatLogClearEntries()
    self.enterWorldTime = GetTime()
    self:RefreshZoneState()
end

function SoundAlerter:ZONE_CHANGED_NEW_AREA()
    self:RefreshZoneState()
end

function SoundAlerter:PLAYER_LOGOUT()
    self:SaveLearnedClasses()

    if sadb.statistics and sadb.statistics.enabled then
        local Statistics = self:GetModule("Statistics")
        Statistics:SaveSessionHistory()
    end

    if sadb.debugmode then
        self:Print("Saved learned classes and session history on logout")
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
        self:Print("  |cffFFFFFF/sa help|r - Show this command list")
        if self.ProximityToasts then
            self.ProximityToasts:PrintHelp()
        end
        if self.FlagAlerts then
            self.FlagAlerts:PrintHelp()
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
    else
        self:ShowConfig()
    end
end

local CLEU_TIMING_SAMPLE_CAP = 200

function SoundAlerter:RecordCleuTiming(elapsedMs)
    local samples = self.cleuTimingSamples
    samples[self.cleuTimingIndex] = elapsedMs
    self.cleuTimingIndex = (self.cleuTimingIndex % CLEU_TIMING_SAMPLE_CAP) + 1
    if self.cleuTimingCount < CLEU_TIMING_SAMPLE_CAP then
        self.cleuTimingCount = self.cleuTimingCount + 1
    end
end

function SoundAlerter:GetCleuPercentiles()
    local count = self.cleuTimingCount
    if count == 0 then return nil end

    local sorted = {}
    for i = 1, count do
        sorted[i] = self.cleuTimingSamples[i]
    end
    table.sort(sorted)

    local function percentile(p)
        local idx = math.max(1, math.ceil(p * count))
        return sorted[idx]
    end

    return percentile(0.50), percentile(0.95), percentile(0.99), sorted[count]
end

function SoundAlerter:ShowPerformanceStats()
    local stats = self.classDetectionStats

    self:Print("=== |cffFF7D0AClass Detection Performance Stats|r ===")

    local p50, p95, p99, maxMs = self:GetCleuPercentiles()
    if p50 then
        self:Print(string.format("CLEU handler: p50 |cff00FF00%.3fms|r  p95 |cffFFFF00%.3fms|r  p99 |cffFF7D0A%.3fms|r  max |cffFF0000%.3fms|r (last %d events)",
            p50, p95, p99, maxMs, self.cleuTimingCount))
    else
        self:Print("CLEU handler: no samples yet")
    end

    self:Print("Total detections: |cff00FF00" .. stats.totalDetections .. "|r")

    if stats.totalDetections > 0 then
        local cacheHitRate = (stats.cacheHits / stats.totalDetections) * 100
        local learnedHitRate = (stats.learnedCacheHits / stats.totalDetections) * 100
        local negativeHitRate = (stats.negativeCacheHits / stats.totalDetections) * 100
        local totalHitRate = ((stats.cacheHits + stats.learnedCacheHits + stats.negativeCacheHits) / stats.totalDetections) * 100

        self:Print("Cache hits: |cff00FF00" .. stats.cacheHits .. "|r (" .. string.format("%.1f%%", cacheHitRate) .. ")")
        self:Print("Learned cache hits: |cff00FF00" .. stats.learnedCacheHits .. "|r (" .. string.format("%.1f%%", learnedHitRate) .. ")")
        self:Print("Negative cache hits: |cffFFFF00" .. stats.negativeCacheHits .. "|r (" .. string.format("%.1f%%", negativeHitRate) .. ")")
        self:Print("Total fast-path: |cff00FF00" .. string.format("%.1f%%", totalHitRate) .. "|r")

        self:Print("Unit lookups: |cff00FFFF" .. stats.unitLookups .. "|r")
        self:Print("API lookups (GetPlayerInfoByGUID): |cff00FFFF" .. stats.apiLookups .. "|r")
        self:Print("Failed lookups: |cffFF0000" .. stats.failedLookups .. "|r")

        local avgTime = (stats.totalLookupTime / stats.totalDetections) * 1000
        self:Print("Avg lookup time: |cffFFFF00" .. string.format("%.2f", avgTime) .. "µs|r")
    end

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

    if sadb.debugmode then
        local cacheSize = 0
        for _ in pairs(self.proximityAlertCache) do
            cacheSize = cacheSize + 1
        end
        if cacheSize > 0 then
            self:Print("Proximity cache cleanup: " .. cacheSize .. " active alerts")
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
        if sadb.debugmode then
            self:Print("Learned classes cache too large (" .. count .. "), limiting to " .. maxSize)
        end
        self:LimitLearnedClassesCache(maxSize)
        count = maxSize
    end

    self.classDetectionStats.learnedClassCount = count

    if sadb.debugmode then
        self:Print("Loaded " .. count .. " learned player classes from cache")
    end
end

function SoundAlerter:LimitLearnedClassesCache(maxSize)
    local entries = {}
    for guid, class in pairs(self.learnedClasses) do
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

    if sadb.debugmode then
        self:Print("Saved " .. count .. " learned classes to cache")
    end
end

function SoundAlerter:HandleAuraApplied(sourceGUID, sourceName, destGUID, destName, spellID)
    local currentZoneType, pvpType = self.cachedInstanceType, self.cachedZonePvpType

    if desttype[COMBATLOG_FILTER_HOSTILE_PLAYERS] then
        if sourcetype[COMBATLOG_FILTER_ME] then
            if not sadb.dEnemyDebuff then
                self:PlaySpell(self.spellList.enemyDebuffs, spellID, destGUID, destName)
            end
            if not sadb.chatalerts then
                if (((spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapenemy) or (spellID == 2094 and sadb.blindenemy) or (spellID == 33786 and sadb.cycloneenemy) or (spellID == 51514 and sadb.hexenemy) or (spellID == 5782 and sadb.fearenemy)) then
                    local ccenemychat = gsub(sadb.enemychat, "(#spell#)", (GetSpellLink(spellID) or ""))
                    local message = gsub(ccenemychat, "(#enemy#)", destName)
                    if not sadb.chatgroups.NONE then
                        for channel, enabled in pairs(sadb.chatgroups) do
                            if enabled and channel ~= "NONE" then
                                SendChatMessage(message, channel, nil, nil)
                            end
                        end
                    end
                end
            end
        elseif (sourcetype[COMBATLOG_FILTER_FRIENDLY_UNITS] and (destuid.target or destuid.focus) and not sadb.dArenaPartner) then
            self:PlaySpell(self.spellList.friendCCenemy, spellID)
        elseif ((sadb.myself and (destuid.target or destuid.focus)) or sadb.enemyinrange) and not sadb.castSuccess and not sadb.aruaApplied then
            self:PlaySpell(self.spellList.auraApplied, spellID)
        end

        if not sadb.chatalerts and sadb.bubbleenemy and spellID == 642 then
            local message = gsub(sadb.bubbleenemytext, "(#enemy#)", destName)
            if not sadb.chatgroups.NONE then
                for channel, enabled in pairs(sadb.chatgroups) do
                    if enabled and channel ~= "NONE" then
                        SendChatMessage(message, channel, nil, nil)
                    end
                end
            end
        end
    elseif desttype[COMBATLOG_FILTER_ME] then
        if not sadb.chatalerts then
            if sourcetype[COMBATLOG_FILTER_HOSTILE_PLAYERS] or ((spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapselffriend) then
                if ((spellID == 51514 and sadb.hexselffriend) or
                    (spellID == 33786 and sadb.cycloneselffriend) or
                    ((spellID == 6215 or spellID == 17928 or spellID == 5484) and sadb.fearselffriend) or
                    ((spellID == 12826 or spellID == 118 or spellID == 28271 or spellID == 28272) and sadb.polyenemy) or
                    (spellID == 2094 and sadb.blindselffriend)) then
                        local form1 = gsub(sadb.selfchat, "(#spell#)", (GetSpellLink(spellID) or ""))
                        local form2 = gsub(form1, "(#target#)", "me")
                        local message = gsub(form2, "(#enemy#)", sourceName)
                        if not sadb.chatgroups.NONE then
                            for channel, enabled in pairs(sadb.chatgroups) do
                                if enabled and channel ~= "NONE" then
                                    SendChatMessage(message, channel, nil, nil)
                                end
                            end
                        end
                elseif (spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapselffriend then
                        local message = gsub(sadb.sapselftext, "(#spell#)", (GetSpellLink(spellID) or ""))
                        if not sadb.chatgroups.NONE then
                            for channel, enabled in pairs(sadb.chatgroups) do
                                if enabled and channel ~= "NONE" then
                                    SendChatMessage(message, channel, nil, nil)
                                end
                            end
                        end
                end
            end
        end
        if not sourceuid.target and not sourceuid.focus and not sadb.dSelfDebuff then
            self:PlaySpell(self.spellList.selfDebuff, spellID)
        end
    elseif desttype[COMBATLOG_FILTER_FRIENDLY_UNITS] then
        if (not sadb.chatalerts and not desttype[COMBATLOG_FILTER_ME] and (destuid.target or destuid.focus or (currentZoneType == "arena" or pvpType == "arena"))) then
            if (spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapselffriend then
                local sapfriendtext = gsub(sadb.sapfriendtext, "(#spell#)", (GetSpellLink(spellID) or ""))
                local message = gsub(sapfriendtext, "(#friend#)", destName)
                if not sadb.chatgroups.NONE then
                    for channel, enabled in pairs(sadb.chatgroups) do
                        if enabled and channel ~= "NONE" then
                            SendChatMessage(message, channel, nil, nil)
                        end
                    end
                end
            elseif ((spellID == 51514 and sadb.hexselffriend) or
                (spellID == 642 and sadb.bubbleselffriend) or
                (spellID == 33786 and sadb.cycloneselffriend) or
                ((spellID == 6215 or spellID == 17928 or spellID == 5484) and sadb.fearselffriend) or
                ((spellID == 12826 or spellID == 118 or spellID == 28271 or spellID == 28272) and sadb.polyenemy) or
                (spellID == 2094 and sadb.blindselffriend)) then
                    local form1 = gsub(sadb.friendchat, "(#spell#)", (GetSpellLink(spellID) or ""))
                    local form2 = gsub(form1, "(#friend#)", destName)
                    local message = gsub(form2, "(#enemy#)", sourceName)
                    if not sadb.chatgroups.NONE then
                        for channel, enabled in pairs(sadb.chatgroups) do
                            if enabled and channel ~= "NONE" then
                                SendChatMessage(message, channel, nil, nil)
                            end
                        end
                    end
            end
        end
    end
end

function SoundAlerter:HandleAuraRemoved(sourceGUID, destGUID, destName, spellID)
    local currentZoneType, pvpType = self.cachedInstanceType, self.cachedZonePvpType

    if desttype[COMBATLOG_FILTER_HOSTILE_PLAYERS] and ((sourcetype[COMBATLOG_FILTER_ME] or (destuid.target or destuid.focus))) then
        if sourcetype[COMBATLOG_FILTER_FRIENDLY_UNITS] and ((destuid.target or (currentZoneType == "arena" or pvpType == "arena")) and not sadb.dArenaPartner) then
            self:PlaySpell(self.spellList.enemyDebuffdownAP, spellID)
        elseif sourcetype[COMBATLOG_FILTER_ME] and not sadb.dEnemyDebuffDown then
            self:PlaySpell(self.spellList.enemyDebuffdown, spellID)
        elseif sourcetype[COMBATLOG_FILTER_HOSTILE_PLAYERS] and not sadb.auraRemoved then
            self:PlaySpell(self.spellList.auraRemoved, spellID)
        end

        if (not sadb.chatalerts and ((sourcetype[COMBATLOG_FILTER_ME] and sadb.chatdownself) or ((not sadb.caonlyTF or destuid.target or destuid.focus) and sadb.chatdownfriend))) then
            if ((spellID == 33786 and sadb.cycloneenemy) or
                (spellID == 51514 and sadb.hexenemy) or
                (spellID == 2094 and sadb.blindenemy) or
                ((spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapenemy) or
                ((spellID == 12826 or spellID == 118 or spellID == 28271 or spellID == 28272) and sadb.polyenemy) or
                ((spellID == 6215 or spellID == 5484 or spellID == 17928) and sadb.fearenemy)) then
                    SendChatMessage((GetSpellLink(spellID) or GetSpellInfo(spellID) or "Unknown Spell").." down on "..destName)
            end
        end
    end
end

function SoundAlerter:HandleCastSuccess(sourceGUID, sourceName, destName, spellID)
    local currentZoneType, pvpType = self.cachedInstanceType, self.cachedZonePvpType

    if sourcetype[COMBATLOG_FILTER_HOSTILE_PLAYERS] then
        if (not sadb.chatalerts) then
            local isVanish = (spellID == 26889)
            local isStealth = (spellID == 1784 or spellID == 1785)
            local isProwl = (spellID == 5215 or spellID == 6783 or spellID == 9913)

            if (
                ((sadb.vanishenemy and isVanish) or (sadb.stealthenemy and isStealth) or (sadb.prowlenemy and isProwl))
                and
                ( (sourceuid.target or sourceuid.focus) or ((sadb.vanishTF and isVanish) or (sadb.stealthTF and isStealth) or (sadb.prowlTF and isProwl)) )
            ) then
                local message = gsub(gsub(sadb.enemychat,"(#spell#)", (GetSpellLink(spellID) or "")),"(#enemy#)", sourceName)
                if not sadb.chatgroups.NONE then
                    for channel, enabled in pairs(sadb.chatgroups) do
                        if enabled and channel ~= "NONE" then
                            SendChatMessage(message, channel, nil, nil)
                        end
                    end
                end
            end
        end

        if not sadb.chatalerts and sadb.trinketalert and (spellID == 42292 or spellID == 59752) then
            local message = gsub(sadb.trinketalerttext, "(#enemy#)", sourceName)
            if not sadb.chatgroups.NONE then
                for channel, enabled in pairs(sadb.chatgroups) do
                    if enabled and channel ~= "NONE" then
                        SendChatMessage(message, channel, nil, nil)
                    end
                end
            end
        end

        if ((spellID == 42292 or spellID == 59752) and sadb.trinket) then
            if ((currentZoneType == "arena" or pvpType == "arena") or (sourceuid.target or sourceuid.focus)) then
                local c = self:ArenaClass(sourceGUID)
                if (c and sadb.class) then
                    PlaySoundFile(sadb.sapath..c..".mp3");
                    self:ScheduleTimer(function() self:PlayTrinket(sourceGUID, sourceName) end, 0.4);
                else
                    self:PlayTrinket(sourceGUID, sourceName)
                end
            end
        elseif ((sadb.myself and (sourceuid.target or sourceuid.focus)) or sadb.enemyinrange) and not sadb.castSuccess then
            if not (sadb.enemyinrange and (spellID == 2825 or spellID == 32182)) then
                self:PlaySpell(self.spellList.castSuccess, spellID, sourceGUID, sourceName)
            elseif (sourceuid.target or sourceuid.focus) then
                self:PlaySpell(self.spellList.castSuccess, spellID, sourceGUID, sourceName)
            end
        end
    elseif (desttype[COMBATLOG_FILTER_FRIENDLY_UNITS] and not desttype[COMBATLOG_FILTER_ME] and ((destuid.target or destuid.focus) or (currentZoneType == "arena" or pvpType == "arena")) and not sadb.dArenaPartner) then
        self:PlaySpell(self.spellList.friendCCSuccess, spellID)
    end
end

function SoundAlerter:HandleInterrupt(sourceName, destName, spellID, extraSpellID)
    local interruptedSpellLink = GetSpellLink(extraSpellID)
    local interruptedSpellName = GetSpellInfo(extraSpellID)
    local replacementText = interruptedSpellLink or interruptedSpellName or ""

    if (desttype[COMBATLOG_FILTER_ME] and not sadb.interrupt) then
        PlaySoundFile(sadb.sapath.."lockout.mp3");
        if (not sadb.chatalerts) then
            if (sadb.interruptself) then
                local it = gsub(sadb.InterruptSelfText, "(#spell#)", (GetSpellLink(spellID) or ""))

                local new_it, _ = gsub(it, "#interruptedspellname#", replacementText)
                it = new_it

                local finalMessage = gsub(it, "(#enemy#)", sourceName)
                finalMessage = string.gsub(finalMessage, "[\\]", "")

                if not sadb.chatgroups.NONE then
                    for channel, enabled in pairs(sadb.chatgroups) do
                        if enabled and channel ~= "NONE" then
                            SendChatMessage(finalMessage, channel, nil, nil)
                        end
                    end
                end
            end
        end
    elseif (sourcetype[COMBATLOG_FILTER_ME] and not sadb.interrupt) then
        if ((destuid.target or destuid.focus) and (desttype[COMBATLOG_FILTER_HOSTILE_PLAYERS] or desttype[COMBATLOG_FILTER_HOSTILE_UNITS])) then
            PlaySoundFile(sadb.sapath.."lockout.mp3");
            if (not sadb.chatalerts) then
                if (sadb.interruptenemy) then
                    local it = gsub(sadb.InterruptEnemyText, "(#spell#)", (GetSpellLink(spellID) or ""))

                    local new_it, _ = gsub(it, "#interruptedspellname#", replacementText)
                    it = new_it

                    local finalMessage = gsub(it, "(#enemy#)", destName)
                    finalMessage = string.gsub(finalMessage, "[\\]", "")

                    if not sadb.chatgroups.NONE then
                        for channel, enabled in pairs(sadb.chatgroups) do
                            if enabled and channel ~= "NONE" then
                                SendChatMessage(finalMessage, channel, nil, nil)
                            end
                        end
                    end
                end
            end
        end
    end
end

function SoundAlerter:HandleCastStart(sourceGUID, sourceName, spellID)
    local currentZoneType, pvpType = self.cachedInstanceType, self.cachedZonePvpType

    if sourcetype[COMBATLOG_FILTER_HOSTILE_PLAYERS] then
        if not sadb.castStart and (sadb.myself and (sourceuid.target or sourceuid.focus) or sadb.enemyinrange) then
            self:PlaySpell(self.spellList.castStart, spellID)
        elseif ((currentZoneType == "arena") or (pvpType == "arena")) and not sadb.dArenaPartner then
            for i = 1, 6 do
                if i == 6 then
                    self:PlaySpell(self.spellList.friendCCs, spellID)
                    break
                elseif playerName == UnitName("arena"..i.."target") then
                    self:PlaySpell(self.spellList.castStart, spellID)
                    break
                end
            end
        end
    end
end

function SoundAlerter:COMBAT_LOG_EVENT_UNFILTERED()
    local cleuStartTime = debugprofilestop()

    local _, event, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _ = CombatLogGetCurrentEventInfo()

    local HOSTILE_PLAYERS_FILTER = COMBATLOG_FILTER_HOSTILE_PLAYERS
    local currentZoneType = self.cachedInstanceType
    local pvpType = self.cachedZonePvpType

    if (not (
        (pvpType == "contested" and sadb.field) or
        (pvpType == "hostile" and sadb.field) or
        (pvpType == "friendly" and sadb.field) or
        (currentZoneType == "pvp" and sadb.battleground) or
        (((currentZoneType == "arena") or (pvpType == "arena")) and sadb.arena) or
        sadb.all
    )) then
        return
    end

    if sadb.proximityEnabled and sourceGUID and sourceName and CombatLog_Object_IsA(sourceFlags, HOSTILE_PLAYERS_FILTER) then
        self:CheckProximityAlertFromCombatLog(sourceGUID, sourceName, sourceFlags)
    end

    if event:sub(1, 6) == "SPELL_" then
        local spellID, spellName = select(12, CombatLogGetCurrentEventInfo())

        for k in pairs(self.SA_TYPE) do
            desttype[k] = CombatLog_Object_IsA(destFlags, k)
            sourcetype[k] = CombatLog_Object_IsA(sourceFlags, k)
        end

        for k in pairs(self.SA_UNIT) do
            if k ~= "any" and k ~= "custom" then
                destuid[k], sourceuid[k] = nil, nil
                if k == "party" and UnitName("party1") ~= nil then
                    for i = 1, MAX_PARTY_MEMBERS do
                        local token = PARTY_UNIT_TOKENS[i]
                        if destGUID == UnitGUID(token) then destuid[k] = true; end
                        if sourceGUID == UnitGUID(token) then sourceuid[k] = true; end
                        if destuid[k] and sourceuid[k] then break end
                    end
                elseif k == "arena" and currentZoneType == "arena" then
                    for i = 1, 5 do
                        local token = ARENA_UNIT_TOKENS[i]
                        if destGUID == UnitGUID(token) then destuid[k] = true; end
                        if sourceGUID == UnitGUID(token) then sourceuid[k] = true; end
                        if destuid[k] and sourceuid[k] then break end
                    end
                else
                    if destGUID then destuid[k] = (UnitGUID(k) == destGUID); end
                    if sourceGUID then sourceuid[k] = (UnitGUID(k) == sourceGUID); end
                end
            end
        end
        destuid.any, sourceuid.any = true, true

        if sadb.debugmode and sadb.spelldebug then
            print(spellName, spellID, event, sourceName, destName)
        end
        if sadb.debugmode and spellName == sadb.csname and spellName then
            print("Custom spell name: "..spellName, spellID, event, sourceName, destName)
        end

        if desttype[COMBATLOG_FILTER_HOSTILE_PLAYERS] and event == "SPELL_CREATE" and (spellID == 13809 or spellID == 13810 or spellID == 1499) and ((sadb.myself and (destuid.target or destuid.focus)) or sadb.enemyinrange) then
            self:PlaySpell(self.spellList.castSuccess, spellID)
        end

        if event == "SPELL_AURA_APPLIED" then
            self:HandleAuraApplied(sourceGUID, sourceName, destGUID, destName, spellID)
        elseif event == "SPELL_AURA_REMOVED" then
            self:HandleAuraRemoved(sourceGUID, destGUID, destName, spellID)
        elseif event == "SPELL_CAST_SUCCESS" then
            self:HandleCastSuccess(sourceGUID, sourceName, destName, spellID)
        elseif event == "SPELL_INTERRUPT" then
            local extraSpellID = select(15, CombatLogGetCurrentEventInfo())
            self:HandleInterrupt(sourceName, destName, spellID, extraSpellID)
        elseif event == "SPELL_CAST_START" then
            self:HandleCastStart(sourceGUID, sourceName, spellID)
        end

        for k, css in pairs(sadb.custom) do
            destuid.custom = (css.destuidfilter == "custom" and destName == css.destcustomname)
            sourceuid.custom = (css.sourceuidfilter == "custom" and sourceName == css.sourcecustomname)

            local spellIdNum = css.spellidNum
            if spellIdNum == nil or css.spellidNumSrc ~= css.spellid then
                spellIdNum = tonumber(css.spellid)
                css.spellidNum = spellIdNum
                css.spellidNumSrc = css.spellid
            end

            if sadb.debugmode and css.name == sadb.cspell and (spellID == spellIdNum or (css.acceptSpellName and (css.spellname == spellName))) then
                log(css.name..": event: "..(css.eventtype and css.eventtype[event] and "true" or "false")..", actual event: "..event..", dest spell: "..(destuid[css.destuidfilter] and "true" or "false")..", dest type: "..(desttype[css.desttypefilter] and "true" or "false")..", sourceunit: "..(sourceuid[css.sourceuidfilter] and "true" or "false")..", source type: "..(sourcetype[css.sourcetypefilter] and "true" or "false"))
            end

            if css.eventtype and css.eventtype[event] and destuid[css.destuidfilter] and desttype[css.desttypefilter] and sourceuid[css.sourceuidfilter] and sourcetype[css.sourcetypefilter] and (spellID == spellIdNum or (css.acceptSpellName and (css.spellname == spellName))) then
                if sadb.debugmode then
                    self:Print("playing css "..css.name)
                end

                if not css.chatAlert then
                    PlaySoundFile("Interface\\Addons\\SoundAlerter\\CustomSounds\\"..css.soundfilepath,"Master")
                else
                    local spell = gsub(css.chatalerttext, "([#]spell[#])", (GetSpellLink(spellID) or ""))
                    local targetName = destuid[css.destuidfilter] and destName or sourceName

                    local message
                    if event == "SPELL_CAST_START" then
                        message = gsub(spell, "([#]enemy[#])", "")
                    else
                        message = gsub(spell, "([#]enemy[#])", targetName)
                    end

                    if not sadb.chatgroups.NONE then
                        for channel, enabled in pairs(sadb.chatgroups) do
                            if enabled and channel ~= "NONE" then
                                SendChatMessage(message, channel, nil, nil)
                            end
                        end
                    end
                end
            end
        end
    end

    self:RecordCleuTiming(debugprofilestop() - cleuStartTime)
end

local DRINK_SPELL
function SoundAlerter:UNIT_AURA(event, uid)
    local currentZoneType, pvpType = self.cachedInstanceType, self.cachedZonePvpType
    if ((currentZoneType == "arena") or (pvpType == "arena")) and sadb.drinking then
        if not DRINK_SPELL then
            DRINK_SPELL = GetSpellInfo(57073)
        end
        if UnitAura(uid, DRINK_SPELL) then
            PlaySoundFile(sadb.sapath.."drinking.mp3");
        end
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

function SoundAlerter:GetClassFromGUID(guid, currentZoneType, pvpType)
    local startTime = debugprofilestop()

    if self.classDetectionStats then
        self.classDetectionStats.totalDetections = self.classDetectionStats.totalDetections + 1
    end

    local cachedClass = rawget(self.guidToClassCache, guid)
    if cachedClass then
        if self.classDetectionStats then
            self.classDetectionStats.cacheHits = self.classDetectionStats.cacheHits + 1
            self.classDetectionStats.totalLookupTime = self.classDetectionStats.totalLookupTime + (debugprofilestop() - startTime)
        end
        return cachedClass
    end

    if sadb.learnedClassesEnabled and self.learnedClasses and self.learnedClasses[guid] then
        local learnedClass = self.learnedClasses[guid]
        self.guidToClassCache[guid] = learnedClass
        if self.classDetectionStats then
            self.classDetectionStats.learnedCacheHits = self.classDetectionStats.learnedCacheHits + 1
            self.classDetectionStats.totalLookupTime = self.classDetectionStats.totalLookupTime + (debugprofilestop() - startTime)
        end
        return learnedClass
    end

    if sadb.negativeCacheEnabled and self.failedGUIDLookups and self.failedGUIDLookups[guid] then
        local failTime = self.failedGUIDLookups[guid]
        local negativeTTL = sadb.negativeCacheTTL or 5
        if GetTime() - failTime < negativeTTL then
            if self.classDetectionStats then
                self.classDetectionStats.negativeCacheHits = self.classDetectionStats.negativeCacheHits + 1
                self.classDetectionStats.totalLookupTime = self.classDetectionStats.totalLookupTime + (debugprofilestop() - startTime)
            end
            return nil
        end
    end

    local unitClass = nil

    if UnitExists("target") and UnitGUID("target") == guid then
        _, unitClass = UnitClass("target")
    elseif UnitExists("mouseover") and UnitGUID("mouseover") == guid then
        _, unitClass = UnitClass("mouseover")
    elseif UnitExists("focus") and UnitGUID("focus") == guid then
        _, unitClass = UnitClass("focus")
    else
        if currentZoneType == "arena" or pvpType == "arena" then
            for i = 1, 5 do
                local arenaUnit = "arena" .. i
                if UnitExists(arenaUnit) and UnitGUID(arenaUnit) == guid then
                    _, unitClass = UnitClass(arenaUnit)
                    break
                end
            end
        end

        if not unitClass and currentZoneType == "pvp" then
            local numRaidMembers = GetNumRaidMembers()
            if numRaidMembers > 0 then
                for i = 1, numRaidMembers do
                    local bgUnit = "raid" .. i .. "target"
                    if UnitExists(bgUnit) and UnitGUID(bgUnit) == guid then
                        _, unitClass = UnitClass(bgUnit)
                        break
                    end
                end
            end
        end
    end

    if not unitClass then
        local _, apiClass = GetPlayerInfoByGUID(guid)
        if apiClass then
            unitClass = apiClass
            if self.classDetectionStats then
                self.classDetectionStats.apiLookups = self.classDetectionStats.apiLookups + 1
            end
        end
    end

    if unitClass then
        self.guidToClassCache[guid] = unitClass
        if self.classDetectionStats then
            self.classDetectionStats.unitLookups = self.classDetectionStats.unitLookups + 1
        end

        if sadb.learnedClassesEnabled and self.learnedClasses then
            self.learnedClasses[guid] = unitClass
            self.learnedClassesDirty = true
        end
    else
        if sadb.negativeCacheEnabled and self.failedGUIDLookups then
            self.failedGUIDLookups[guid] = GetTime()
        end
        if self.classDetectionStats then
            self.classDetectionStats.failedLookups = self.classDetectionStats.failedLookups + 1
        end
    end

    if self.classDetectionStats then
        self.classDetectionStats.totalLookupTime = self.classDetectionStats.totalLookupTime + (debugprofilestop() - startTime)
    end
    return unitClass
end

function SoundAlerter:GetApproxRange(unit)
    if not UnitExists(unit) then return nil end

    if CheckInteractDistance(unit, 3) then
        return "Close"
    elseif CheckInteractDistance(unit, 1) then
        return "Near"
    else
        return "Detected"
    end
end

function SoundAlerter:CheckProximityAlert(unit)
    if not sadb.proximityEnabled then return end

    if not UnitExists(unit) then return end
    if not UnitIsPlayer(unit) then return end
    if not UnitIsEnemy("player", unit) then return end
    if not UnitIsVisible(unit) then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    if guid:sub(1, 7) ~= "Player-" then return end

    local currentTime = GetTime()
    local cooldown = sadb.proximityCooldown or 30
    if self.proximityAlertCache[guid] then
        local timeElapsed = currentTime - self.proximityAlertCache[guid]
        if timeElapsed < cooldown then return end
    end

    if currentTime - self.enterWorldTime < 10 then return end

    local currentZoneType, pvpType = self.cachedInstanceType, self.cachedZonePvpType

    local inArena = (currentZoneType == "arena") or (pvpType == "arena")
    local inBattleground = (currentZoneType == "pvp")
    local inWorld = (pvpType == "contested" or pvpType == "hostile" or pvpType == "friendly")

    if inArena and not sadb.proximityArena then return end
    if inBattleground and not sadb.proximityBattleground then return end
    if inWorld and not sadb.proximityWorld then return end
    if not (inArena or inBattleground or inWorld) then return end

    local unitName = UnitName(unit)
    local _, unitClass = UnitClass(unit)
    local unitLevel = UnitLevel(unit)

    if not unitName or not unitClass then return end

    self.guidToClassCache[guid] = unitClass
    self.proximityAlertCache[guid] = currentTime

    local classAudioFile = CLASS_AUDIO_MAP[unitClass]
    if classAudioFile then
        PlaySoundFile(sadb.sapath .. classAudioFile .. ".mp3", "Master")
    end
    self:ScheduleTimer(function()
        PlaySoundFile(sadb.sapath .. "detected.mp3", "Master")
    end, 0.8)

    if sadb.statistics and sadb.statistics.enabled then
        local Statistics = self:GetModule("Statistics")
        if Statistics then
            Statistics:RecordAlert("proximityAlerts", nil, guid, unitName)
        end
    end

    if sadb.proximityToasts and sadb.proximityToasts.enabled and self.ProximityToasts then
        local approxRange = self:GetApproxRange(unit)
        self.ProximityToasts:ShowToast(unitName, unitClass, approxRange, guid, unitLevel, unit)
    end

    if sadb.proximityChat and sadb.proximityChatText then
        local chatText = gsub(sadb.proximityChatText, "#class#", unitClass)
        chatText = gsub(chatText, "#player#", unitName)

        if not sadb.chatgroups.NONE then
            for channel, enabled in pairs(sadb.chatgroups) do
                if enabled and channel ~= "NONE" then
                    SendChatMessage(chatText, channel, nil, nil)
                end
            end
        end
    end

    if sadb.debugmode then
        self:Print("Proximity Alert: " .. unitClass .. " " .. unitName .. " detected!")
    end
end

function SoundAlerter:CheckProximityAlertFromCombatLog(guid, name, flags)
    if rawget(self.proximityRecentGUIDs, guid) then return end
    if not sadb.proximityEnabled then return end
    if not guid or not name then return end

    if guid:sub(1, 7) ~= "Player-" then return end

    local currentTime = GetTime()
    local cooldown = sadb.proximityCooldown or 30
    local cachedTime = rawget(self.proximityAlertCache, guid)
    if cachedTime then
        if currentTime - cachedTime < cooldown then
            self.proximityRecentGUIDs[guid] = true
            return
        end
    end

    if currentTime - self.enterWorldTime < 10 then return end

    local currentZoneType, pvpType = self.cachedInstanceType, self.cachedZonePvpType

    local zoneAllowed = (
        ((currentZoneType == "arena" or pvpType == "arena") and sadb.proximityArena) or
        (currentZoneType == "pvp" and sadb.proximityBattleground) or
        ((pvpType == "contested" or pvpType == "hostile" or pvpType == "friendly") and sadb.proximityWorld)
    )
    if not zoneAllowed then return end

    local unitClass = self:GetClassFromGUID(guid, currentZoneType, pvpType)

    self.proximityAlertCache[guid] = currentTime
    self.proximityRecentGUIDs[guid] = true

    if unitClass then
        local classAudioFile = CLASS_AUDIO_MAP[unitClass]
        if classAudioFile then
            PlaySoundFile(sadb.sapath .. classAudioFile .. ".mp3", "Master")
            self:ScheduleTimer(function()
                PlaySoundFile(sadb.sapath .. "detected.mp3", "Master")
            end, 0.8)
        else
            PlaySoundFile(sadb.sapath .. "detected.mp3", "Master")
        end
    else
        PlaySoundFile(sadb.sapath .. "enemy.mp3", "Master")
        self:ScheduleTimer(function()
            PlaySoundFile(sadb.sapath .. "detected.mp3", "Master")
        end, 0.8)
    end

    if sadb.statistics and sadb.statistics.enabled then
        local Statistics = self:GetModule("Statistics")
        if Statistics then
            Statistics:RecordAlert("proximityAlerts", nil, guid, name)
        end
    end

    if sadb.proximityToasts and sadb.proximityToasts.enabled and self.ProximityToasts then
        self.ProximityToasts:ShowToast(name, unitClass, nil, guid, nil, nil)
    end

    if sadb.proximityChat and sadb.proximityChatText then
        local chatText = gsub(sadb.proximityChatText, "#class#", unitClass or "Enemy")
        chatText = gsub(chatText, "#player#", name)

        if not sadb.chatgroups.NONE then
            for channel, enabled in pairs(sadb.chatgroups) do
                if enabled and channel ~= "NONE" then
                    SendChatMessage(chatText, channel, nil, nil)
                end
            end
        end
    end

    if sadb.debugmode then
        if unitClass then
            self:Print("Proximity Alert (Combat Log): " .. unitClass .. " " .. name .. " detected!")
        else
            self:Print("Proximity Alert (Combat Log): Enemy " .. name .. " detected!")
        end
    end
end

function SoundAlerter:PLAYER_TARGET_CHANGED()
    self:CheckProximityAlert("target")
end

function SoundAlerter:UPDATE_MOUSEOVER_UNIT()
    self:CheckProximityAlert("mouseover")
end
