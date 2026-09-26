
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
local ARENA_UNIT_TOKENS = {"arena1", "arena2", "arena3", "arena4", "arena5"}

local function SafeUnitGUIDMatches(unit, guid)
    if not UnitExists(unit) then return false end
    local unitGUID = UnitGUID(unit)
    if issecretvalue(unitGUID) then return false end
    return unitGUID == guid
end

local function SafeUnitClass(unit)
    local _, class = UnitClass(unit)
    if issecretvalue(class) then return nil end
    return class
end

local function SafeUnitName(unit)
    local name = UnitName(unit)
    if issecretvalue(name) then return nil end
    return name
end


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
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("UNIT_SPELLCAST_START")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:RegisterEvent("PLAYER_LOGOUT")

    self:RefreshZoneState()

    if not self.SA_LANGUAGE[sadb.path] then sadb.path = self.SA_LOCALEPATH.enUS end
    self.throttled = {}
    self.smarter = 0

    self.proximityAlertCache = {}
    self.proximityRecentGUIDs = {}
    self.guidToClassCache = {}
    self.trackedNameplates = {}
    self.enterWorldTime = 0

    self:ApplyNameplateRange()

    self.failedGUIDLookups = {}

    self.classDetectionStats = {
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

function SoundAlerter:BroadcastChat(message)
    if sadb.chatgroups.NONE then return end
    for channel, enabled in pairs(sadb.chatgroups) do
        if enabled and channel ~= "NONE" then
            SendChatMessage(message, channel, nil, nil)
        end
    end
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

function SoundAlerter:RefreshZoneState()
    self.cachedInInstance, self.cachedInstanceType = IsInInstance()
    self.cachedZonePvpType = GetZonePVPInfo()

    local zoneName = GetRealZoneText() or GetZoneText() or "Unknown"
    self.zonePvpTypeLog = self.zonePvpTypeLog or {}
    self.zonePvpTypeLog[zoneName] = { instanceType = self.cachedInstanceType, pvpType = self.cachedZonePvpType }

    if sadb and sadb.debugmode then
        log("Zone state: zone="..zoneName..", instanceType="..tostring(self.cachedInstanceType)..", pvpType="..tostring(self.cachedZonePvpType))
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
    elseif command == "apicheck" then
        self:RunApiCheck()
    elseif command == "zonelog" then
        self:PrintZoneLog()
    else
        self:ShowConfig()
    end
end

function SoundAlerter:RunApiCheck()
    self:Print("|cffFFD700=== SoundAlerter API Check ===|r")

    local function checkPath(path)
        local value = _G
        for segment in path:gmatch("[^%.]+") do
            if type(value) ~= "table" then
                value = nil
                break
            end
            value = value[segment]
        end
        local ok = value ~= nil
        self:Print((ok and "|cff00FF00[OK]|r " or "|cffFF0000[MISSING]|r ")..path..(ok and (" ("..type(value)..")") or ""))
    end

    local paths = {
        "C_Spell", "C_Spell.GetSpellInfo", "C_Spell.GetSpellLink",
        "C_Spell.GetSpellDescription", "C_Spell.GetSpellCooldown", "C_Spell.RequestLoadSpellData",
        "C_PvP", "C_PvP.GetZonePVPInfo",
        "C_UnitAuras", "C_UnitAuras.GetAuraDataByIndex",
        "C_Timer", "C_Timer.After",
        "UnitCastingInfo", "UnitChannelInfo",
        "GetZonePVPInfo", "GetSpellInfo", "GetSpellLink", "GetSpellCooldown",
        "issecretvalue", "CombatLogGetCurrentEventInfo", "CombatLog_Object_IsA",
    }

    for _, path in ipairs(paths) do
        checkPath(path)
    end

    self:Print("|cffFFD700=== Scanning for CombatLog functions ===|r")

    for key, value in pairs(_G) do
        if type(key) == "string" and key:lower():find("combatlog") and type(value) == "function" then
            self:Print("|cff00FFFF[GLOBAL]|r "..key)
        end
    end

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

    self:Print("|cffFFD700=== End Scan ===|r")

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

local DRINK_SPELL
local unitAuraSnapshot = {}
local lastAuraScan = {}
local AURA_RESCAN_THROTTLE = 0.2

local function CollectTrackedSpellIDs(ids, source)
    if not source then return end
    for spellID in pairs(source) do
        ids[spellID] = true
    end
end

local function GetTrackedAuraSpellIDs()
    local ids = {}
    CollectTrackedSpellIDs(ids, SoundAlerter.spellList and SoundAlerter.spellList.selfDebuff)
    CollectTrackedSpellIDs(ids, SoundAlerter.spellList and SoundAlerter.spellList.enemyDebuffs)
    CollectTrackedSpellIDs(ids, SoundAlerter.spellList and SoundAlerter.spellList.enemyDebuffdown)
    if sadb and sadb.custom then
        for _, css in pairs(sadb.custom) do
            if css.eventtype and (css.eventtype["SPELL_AURA_APPLIED"] or css.eventtype["SPELL_AURA_REMOVED"]) and css.spellid then
                local id = tonumber(css.spellid)
                if id then ids[id] = true end
            end
        end
    end
    return ids
end

local function ScanHarmfulAuraSpellIDs(unit, target, sourceUnits)
    wipe(target)
    wipe(sourceUnits)
    local trackedIDs = GetTrackedAuraSpellIDs()
    for spellID in pairs(trackedIDs) do
        local ok, data = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
        if ok and data ~= nil and not issecretvalue(data) then
            target[spellID] = true
            local sourceUnit = data.sourceUnit
            if sourceUnit and not issecretvalue(sourceUnit) then
                sourceUnits[spellID] = sourceUnit
            end
        end
    end
end

function SoundAlerter:HandleDebuffApplied(unit, spellID, isPlayer, isTargetOrFocus, isTracked, sourceUnit)
    self:CheckCustomAlerts("SPELL_AURA_APPLIED", sourceUnit, unit, spellID)

    if isPlayer then
        if not sadb.dSelfDebuff then
            self:PlaySpell(self.spellList.selfDebuff, spellID)
        end
        if not sadb.chatalerts then
            if ((spellID == 51514 and sadb.hexselffriend) or
                (spellID == 33786 and sadb.cycloneselffriend) or
                ((spellID == 6215 or spellID == 17928 or spellID == 5484) and sadb.fearselffriend) or
                ((spellID == 12826 or spellID == 118 or spellID == 28271 or spellID == 28272) and sadb.polyenemy) or
                (spellID == 2094 and sadb.blindselffriend)) then
                local form1 = gsub(sadb.selfchat, "(#spell#)", (GetSpellLink(spellID) or ""))
                local form2 = gsub(form1, "(#target#)", "me")
                local message = gsub(form2, "(#enemy#)", "")
                self:BroadcastChat(message)
            elseif (spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapselffriend then
                local message = gsub(sadb.sapselftext, "(#spell#)", (GetSpellLink(spellID) or ""))
                self:BroadcastChat(message)
            end
        end
        return
    end

    if not (isTargetOrFocus or isTracked) then return end

    local name = SafeUnitName(unit)
    local guid = UnitGUID(unit)
    if not name or not guid or issecretvalue(guid) then return end

    if not sadb.dEnemyDebuff then
        self:PlaySpell(self.spellList.enemyDebuffs, spellID, guid, name)
    end

    if not sadb.chatalerts then
        if (((spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapenemy) or
            (spellID == 2094 and sadb.blindenemy) or
            (spellID == 33786 and sadb.cycloneenemy) or
            (spellID == 51514 and sadb.hexenemy) or
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
    end
end

function SoundAlerter:HandleDebuffRemoved(unit, spellID, isTargetOrFocus)
    self:CheckCustomAlerts("SPELL_AURA_REMOVED", nil, unit, spellID)

    if not isTargetOrFocus then return end

    local name = SafeUnitName(unit)
    if not name then return end

    if not sadb.dEnemyDebuffDown then
        self:PlaySpell(self.spellList.enemyDebuffdown, spellID)
    end

    if not sadb.chatalerts and sadb.chatdownfriend then
        if ((spellID == 33786 and sadb.cycloneenemy) or
            (spellID == 51514 and sadb.hexenemy) or
            (spellID == 2094 and sadb.blindenemy) or
            ((spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapenemy) or
            ((spellID == 12826 or spellID == 118 or spellID == 28271 or spellID == 28272) and sadb.polyenemy) or
            ((spellID == 6215 or spellID == 5484 or spellID == 17928) and sadb.fearenemy)) then
            self:BroadcastChat((GetSpellLink(spellID) or GetSpellInfo(spellID) or "Unknown Spell").." down on "..name)
        end
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
    if not filterKey or filterKey == COMBATLOG_FILTER_EVERYTHING then return true end
    if not unit or not UnitExists(unit) then return false end
    if filterKey == COMBATLOG_FILTER_ME then return UnitIsUnit(unit, "player") end
    if filterKey == COMBATLOG_FILTER_HOSTILE_PLAYERS then return UnitIsPlayer(unit) and UnitIsEnemy("player", unit) end
    if filterKey == COMBATLOG_FILTER_FRIENDLY_UNITS then return not UnitIsEnemy("player", unit) end
    if filterKey == COMBATLOG_FILTER_HOSTILE_UNITS then return UnitIsEnemy("player", unit) end
    return true
end

function SoundAlerter:CheckCustomAlerts(eventName, sourceUnit, destUnit, spellID)
    if not next(sadb.custom) then return end
    if issecretvalue(spellID) then return end

    local spellName = GetSpellInfo(spellID)
    local destName = destUnit and SafeUnitName(destUnit)
    local sourceName = sourceUnit and SafeUnitName(sourceUnit)

    for k, css in pairs(sadb.custom) do
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
                    if sadb.debugmode then
                        self:Print("playing css "..css.name)
                    end

                    if not css.chatAlert then
                        PlaySoundFile("Interface\\Addons\\SoundAlerter\\CustomSounds\\"..css.soundfilepath, "Master")
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

function SoundAlerter:UNIT_AURA(event, unit)
    if not unit then return end

    local isPlayer = unit == "player"
    local isTargetOrFocus = not isPlayer and (unit == "target" or unit == "focus")
    local isArena = not isPlayer and not isTargetOrFocus and unit:match("^arena%d$") ~= nil
    local isNameplate = not isPlayer and not isTargetOrFocus and not isArena and unit:match("^nameplate%d+$") ~= nil

    if not (isPlayer or isTargetOrFocus or isArena or isNameplate) then return end
    if not UnitExists(unit) then return end

    if isArena then
        local currentZoneType, pvpType = self.cachedInstanceType, self.cachedZonePvpType
        if ((currentZoneType == "arena") or (pvpType == "arena")) and sadb.drinking then
            if not DRINK_SPELL then
                DRINK_SPELL = GetSpellInfo(57073)
            end
            if UnitAura(unit, DRINK_SPELL) then
                PlaySoundFile(sadb.sapath.."drinking.mp3");
            end
        end
    end

    local isTracked = isNameplate and self:IsTrackedNameplate(unit)
    if not (isPlayer or isTargetOrFocus or isTracked) then return end
    if not isPlayer and (not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit)) then return end
    if not self:IsAlertZoneAllowed() then return end

    local now = GetTime()
    if lastAuraScan[unit] and (now - lastAuraScan[unit]) < AURA_RESCAN_THROTTLE then return end
    lastAuraScan[unit] = now

    local previous = unitAuraSnapshot[unit]
    if not previous then
        previous = {}
        unitAuraSnapshot[unit] = previous
    end

    local current = {}
    local sourceUnits = {}
    ScanHarmfulAuraSpellIDs(unit, current, sourceUnits)

    for spellID in pairs(current) do
        if not previous[spellID] then
            self:HandleDebuffApplied(unit, spellID, isPlayer, isTargetOrFocus, isTracked, sourceUnits[spellID])
        end
    end

    for spellID in pairs(previous) do
        if not current[spellID] then
            self:HandleDebuffRemoved(unit, spellID, isTargetOrFocus)
        end
    end

    wipe(previous)
    for spellID in pairs(current) do
        previous[spellID] = true
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
    if not guid or issecretvalue(guid) then return end

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
    local inSanctuary = (pvpType == "sanctuary" or pvpType == nil)

    if inArena and not sadb.proximityArena then return end
    if inBattleground and not sadb.proximityBattleground then return end
    if inWorld and not sadb.proximityWorld then return end
    if inSanctuary and not sadb.proximitySanctuary then return end
    if not (inArena or inBattleground or inWorld or inSanctuary) then return end

    local unitName = UnitName(unit)
    local _, unitClass = UnitClass(unit)
    local unitLevel = UnitLevel(unit)

    if not unitName or issecretvalue(unitName) then return end
    if not unitClass or issecretvalue(unitClass) then return end
    if issecretvalue(unitLevel) then return end

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

function SoundAlerter:PLAYER_TARGET_CHANGED()
    self:CheckProximityAlert("target")
end

function SoundAlerter:UPDATE_MOUSEOVER_UNIT()
    self:CheckProximityAlert("mouseover")
end

function SoundAlerter:NAME_PLATE_UNIT_ADDED(event, unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return end

    local guid = UnitGUID(unit)
    if not guid or issecretvalue(guid) then return end

    self.trackedNameplates[guid] = unit

    self:CheckProximityAlert(unit)
end

function SoundAlerter:NAME_PLATE_UNIT_REMOVED(event, unit)
    local guid = UnitGUID(unit)
    if not guid or issecretvalue(guid) then return end

    self.trackedNameplates[guid] = nil
    unitAuraSnapshot[unit] = nil
    lastAuraScan[unit] = nil
end

function SoundAlerter:IsTrackedNameplate(unit)
    local guid = UnitGUID(unit)
    if not guid or issecretvalue(guid) then return false end
    return self.trackedNameplates[guid] ~= nil
end

local function IsRelevantCastUnit(unit)
    return unit == "target" or unit == "focus" or unit:match("^nameplate%d+$") ~= nil
end

function SoundAlerter:UNIT_SPELLCAST_START(event, unit, castGUID, spellID)
    if not unit or not IsRelevantCastUnit(unit) then return end
    if not self:IsAlertZoneAllowed() then return end
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return end
    if issecretvalue(spellID) then return end

    local isTargetOrFocus = (unit == "target" or unit == "focus")
    local isTracked = not isTargetOrFocus and self:IsTrackedNameplate(unit)
    if not (isTargetOrFocus or isTracked) then return end

    self:CheckCustomAlerts("SPELL_CAST_START", unit, nil, spellID)

    if not sadb.castStart and ((sadb.myself and isTargetOrFocus) or (sadb.enemyinrange and isTracked)) then
        local guid = UnitGUID(unit)
        local name = SafeUnitName(unit)
        if guid and not issecretvalue(guid) and name then
            self:PlaySpell(self.spellList.castStart, spellID, guid, name)
        end
    end
end

function SoundAlerter:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
    if not unit or not IsRelevantCastUnit(unit) then return end
    if not self:IsAlertZoneAllowed() then return end
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return end
    if issecretvalue(spellID) then return end

    local isTargetOrFocus = (unit == "target" or unit == "focus")
    local isTracked = not isTargetOrFocus and self:IsTrackedNameplate(unit)
    if not (isTargetOrFocus or isTracked) then return end

    local guid = UnitGUID(unit)
    local name = SafeUnitName(unit)
    if not guid or issecretvalue(guid) or not name then return end

    self:CheckCustomAlerts("SPELL_CAST_SUCCESS", unit, nil, spellID)

    if not sadb.chatalerts then
        local isVanish = (spellID == 26889)
        local isStealth = (spellID == 1784 or spellID == 1785)
        local isProwl = (spellID == 5215 or spellID == 6783 or spellID == 9913)

        if ((sadb.vanishenemy and isVanish) or (sadb.stealthenemy and isStealth) or (sadb.prowlenemy and isProwl))
           and (isTargetOrFocus or ((sadb.vanishTF and isVanish) or (sadb.stealthTF and isStealth) or (sadb.prowlTF and isProwl))) then
            local message = gsub(gsub(sadb.enemychat, "(#spell#)", (GetSpellLink(spellID) or "")), "(#enemy#)", name)
            self:BroadcastChat(message)
        end
    end

    if not sadb.chatalerts and sadb.trinketalert and (spellID == 42292 or spellID == 59752) then
        local message = gsub(sadb.trinketalerttext, "(#enemy#)", name)
        self:BroadcastChat(message)
    end

    if (spellID == 42292 or spellID == 59752) and sadb.trinket then
        local class = SafeUnitClass(unit)
        if class and sadb.class then
            local classAudioFile = CLASS_AUDIO_MAP[class]
            if classAudioFile then
                PlaySoundFile(sadb.sapath..classAudioFile..".mp3");
            end
            self:ScheduleTimer(function() self:PlayTrinket(guid, name) end, 0.4);
        else
            self:PlayTrinket(guid, name)
        end
    elseif ((sadb.myself and isTargetOrFocus) or (sadb.enemyinrange and isTracked)) and not sadb.castSuccess then
        if not ((sadb.enemyinrange and isTracked and not isTargetOrFocus) and (spellID == 2825 or spellID == 32182)) then
            self:PlaySpell(self.spellList.castSuccess, spellID, guid, name)
        end
    end
end

function SoundAlerter:UNIT_SPELLCAST_INTERRUPTED(event, unit, castGUID, spellID)
    if unit ~= "player" and unit ~= "target" and unit ~= "focus" then return end
    if not self:IsAlertZoneAllowed() then return end
    if issecretvalue(spellID) then return end

    local replacementText = GetSpellLink(spellID) or GetSpellInfo(spellID) or ""

    self:CheckCustomAlerts("SPELL_INTERRUPT", nil, unit, spellID)

    if unit == "player" then
        if not sadb.interrupt then
            PlaySoundFile(sadb.sapath.."lockout.mp3");
            if not sadb.chatalerts and sadb.interruptself then
                local it = gsub(sadb.InterruptSelfText, "(#spell#)", "")
                it = gsub(it, "#interruptedspellname#", replacementText)
                local finalMessage = gsub(it, "(#enemy#)", "")
                finalMessage = string.gsub(finalMessage, "[\\]", "")
                self:BroadcastChat(finalMessage)
            end
        end
        return
    end

    if unit ~= "target" and unit ~= "focus" then return end
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return end

    local name = SafeUnitName(unit)
    if not name then return end

    if not sadb.interrupt then
        PlaySoundFile(sadb.sapath.."lockout.mp3");
        if not sadb.chatalerts and sadb.interruptenemy then
            local it = gsub(sadb.InterruptEnemyText, "(#spell#)", "")
            it = gsub(it, "#interruptedspellname#", replacementText)
            local finalMessage = gsub(it, "(#enemy#)", name)
            finalMessage = string.gsub(finalMessage, "[\\]", "")
            self:BroadcastChat(finalMessage)
        end
    end
end
