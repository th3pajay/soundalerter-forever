local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
if not SoundAlerter then
    return
end

local ProximityToasts = {}
SoundAlerter.ProximityToasts = ProximityToasts

local UnitAura = SA_COMPAT.UnitAura

ProximityToasts.inCombat = false

local MAX_TOASTS = 5
local TOAST_WIDTH = 340
local TOAST_HEIGHT = 96
local VERTICAL_SPACING = 8
local FADE_IN_DURATION = 0.2
local FADE_OUT_DURATION = 0.5
local SLIDE_DURATION = 0.2
local MAX_AURA_ICONS = 3
local AURA_ICON_SIZE = 18
local AURA_ICON_SPACING = 4
local AURA_SCAN_MAX = 6

local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local CLASS_ICONS = {
    WARRIOR = "Interface\\Icons\\ClassIcon_Warrior",
    PALADIN = "Interface\\Icons\\ClassIcon_Paladin",
    HUNTER = "Interface\\Icons\\ClassIcon_Hunter",
    ROGUE = "Interface\\Icons\\ClassIcon_Rogue",
    PRIEST = "Interface\\Icons\\ClassIcon_Priest",
    DEATHKNIGHT = "Interface\\Icons\\ClassIcon_DeathKnight",
    SHAMAN = "Interface\\Icons\\ClassIcon_Shaman",
    MAGE = "Interface\\Icons\\ClassIcon_Mage",
    WARLOCK = "Interface\\Icons\\ClassIcon_Warlock",
    DRUID = "Interface\\Icons\\ClassIcon_Druid",
}

local classColorCache = {}

ProximityToasts.secureToastPool = {}
ProximityToasts.insecureToastPool = {}
ProximityToasts.activeToasts = {}
ProximityToasts.lastToastTime = {}
ProximityToasts.initialized = false
ProximityToasts.swapInProgress = false
ProximityToasts.insecureSwapBuffer = {}
ProximityToasts.swapMetrics = {count = 0, totalTime = 0, maxTime = 0, histogram = {}}

local PROXIMITY_TOAST_KEYS = {
    enabled = true,
    displayDuration = true,
    maxConcurrent = true,
    showPlayerName = true,
    showAuraIcons = true,
    showLatestSpell = true,
    useClassColors = true,
    rainbowBorder = true,
    toastStyle = true,
    positionX = true,
    positionY = true,
    clickEnabled = true,
    enableClickToTarget = true,
    enableFocusTarget = true,
}

local PROXIMITY_TOAST_PREVIEWABLE_KEYS = {}

function ProximityToasts:GetSettings()
    local db = SoundAlerter.db1.profile
    db.proximityToasts = db.proximityToasts or {}
    return db.proximityToasts
end

function ProximityToasts:SetSetting(key, value)
    if not PROXIMITY_TOAST_KEYS[key] then
        error("ProximityToasts:SetSetting - unknown setting key '"..tostring(key).."'", 2)
    end
    self:GetSettings()[key] = value
    if value and PROXIMITY_TOAST_PREVIEWABLE_KEYS[key] then
        SoundAlerter:PlayVoice(SoundAlerter.db1.profile.sapath..key..".mp3")
    end
end

local SafeUnitName = SA_COMPAT.SafeUnitName

local function SanitizeMacroText(text)
    if not text then return "" end
    text = text:gsub("\n", ""):gsub("\r", ""):gsub("%z", "")
    return text
end

local unitScanOrder = {
    "target", "focus", "mouseover",
    "targettarget", "focustarget",
    "party1target", "party2target", "party3target", "party4target",
    "raid1target", "raid2target", "raid3target", "raid4target", "raid5target",
    "raid6target", "raid7target", "raid8target", "raid9target", "raid10target",
    "raid11target", "raid12target", "raid13target", "raid14target", "raid15target",
    "raid16target", "raid17target", "raid18target", "raid19target", "raid20target",
    "raid21target", "raid22target", "raid23target", "raid24target", "raid25target",
    "raid26target", "raid27target", "raid28target", "raid29target", "raid30target",
    "raid31target", "raid32target", "raid33target", "raid34target", "raid35target",
    "raid36target", "raid37target", "raid38target", "raid39target", "raid40target",
}

local function TargetByNameCompat(targetName, unitToken)
    if not targetName then return false end

    if UnitExists("target") and SafeUnitName("target") == targetName then
        return true
    end

    if unitToken and UnitExists(unitToken) and SafeUnitName(unitToken) == targetName then
        TargetUnit(unitToken)

        if UnitExists("target") and SafeUnitName("target") == targetName then
            return true
        end
    end

    for _, unitId in ipairs(unitScanOrder) do
        if UnitExists(unitId) and SafeUnitName(unitId) == targetName then
            TargetUnit(unitId)

            if UnitExists("target") and SafeUnitName("target") == targetName then
                return true
            end
        end
    end

    SoundAlerter:Debug("ProximityToasts", "toast click: could not locate %s in any scannable unit", targetName)

    return false
end

local function GetClassColor(className)
    if not className then return 0.5, 0.5, 0.5 end

    if not classColorCache[className] then
        local classColor = RAID_CLASS_COLORS[className]
        if classColor then
            classColorCache[className] = {classColor.r * 0.35, classColor.g * 0.35, classColor.b * 0.35}
        else
            classColorCache[className] = {0.175, 0.175, 0.175}
        end
    end

    local cached = classColorCache[className]
    return cached[1], cached[2], cached[3]
end

local function GetRainbowColor(time)
    local frequency = math.pi * 2 / 6.0
    local r = math.sin(frequency * time + 0) * 0.5 + 0.5
    local g = math.sin(frequency * time + 2.0944) * 0.5 + 0.5
    local b = math.sin(frequency * time + 4.1888) * 0.5 + 0.5

    return r, g, b
end

local function GetBackdropConfig(alertType)
    local sadb = SoundAlerter.db1.profile
    local textureName = "Solid"

    if alertType == "FLAG_ENEMY" and sadb.flagTeamBackgroundColors and sadb.flagEnemyTexture then
        textureName = sadb.flagEnemyTexture
    elseif alertType == "FLAG_FRIENDLY" and sadb.flagTeamBackgroundColors and sadb.flagFriendlyTexture then
        textureName = sadb.flagFriendlyTexture
    end

    local textures = SoundAlerter.BarUtils.BACKDROP_TEXTURES
    local bgFile = textures[textureName] or textures["Solid"]

    return {
        bgFile = bgFile,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    }
end

local function UpdateCountdownSegments(toast, displayElapsed)
    if not toast.countdownBar or not toast.cachedSegmentData then
        return
    end

    local duration = toast.cachedSegmentData.duration
    local secondsElapsed = math.floor(displayElapsed)
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

local function IsLocked(toast)
    return toast.isSecure and InCombatLockdown()
end

local deferredHides = {}
local deferredButtons = {}

local function HideToast(toast)
    if IsLocked(toast) then
        toast:SetAlpha(0)
        deferredHides[toast] = true
    else
        toast:Hide()
    end
end

local function FlushDeferredHides()
    for toast in pairs(deferredHides) do
        deferredHides[toast] = nil
        if not toast.inUse then
            toast:Hide()
        end
    end
    for button in pairs(deferredButtons) do
        deferredButtons[button] = nil
        button:Hide()
        button:SetAlpha(1)
    end
end

local ACCENT = {1, 0.49, 0.04}
local THREAT_COLORS = {HIGH = {1, 0.3, 0.3}, MEDIUM = {1, 0.65, 0.2}, LOW = {0.7, 0.7, 0.7}}
local CELL_X = {10, 70, 190}
local CELL_LABELS = {"Level", "Distance", "Group"}

local function ClassTextColor(className)
    local color = className and RAID_CLASS_COLORS[className]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

local function DrawSpell(toast, view)
    local shown = view.spellName ~= nil and SA_Secret.Draw(toast.spellText, toast.spellIcon, view.spellName, view.spellIcon)
    toast.spellText:SetShown(shown)
    toast.spellIcon:SetShown(shown)
end

local function ApplyView(toast, view)
    local r, g, b = ClassTextColor(view.className)
    local threatStyle = view.style == "threat"

    toast.icon:SetTexture(view.iconTexture)
    toast.icon:ClearAllPoints()
    toast.icon:SetSize(36, 36)
    toast.titleText:ClearAllPoints()
    toast.detailText:ClearAllPoints()
    toast.levelText:ClearAllPoints()
    toast.tagText:ClearAllPoints()
    toast.auraIcons[1]:ClearAllPoints()

    toast.tagText:SetText(view.tag or "")
    toast.titleText:SetFontObject(GameFontNormalSmall)
    toast.titleText:SetTextColor(0.72, 0.74, 0.8)
    toast.titleText:SetText(view.title or "")
    toast.detailText:SetFontObject(GameFontNormalLarge)
    toast.detailText:SetTextColor(r, g, b)
    toast.detailText:SetText(view.primary or "")

    if threatStyle then
        toast.sideBlock:ClearAllPoints()
        toast.sideBlock:SetPoint("TOPLEFT", toast, "TOPLEFT", 4, -4)
        toast.sideBlock:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 4, 4)
        toast.sideBlock:SetWidth(70)
        toast.sideBlock:SetVertexColor(r, g, b, 0.95)
        toast.sideBlock:Show()
        toast.icon:SetPoint("TOP", toast.sideBlock, "TOP", 0, -12)
        toast.levelText:SetPoint("BOTTOM", toast.sideBlock, "BOTTOM", 0, 12)
        toast.levelText:SetTextColor(0.08, 0.09, 0.1)
        toast.levelText:SetText(view.sideLabel or "")
        toast.detailText:SetPoint("TOPLEFT", toast, "TOPLEFT", 86, -12)
        toast.detailText:SetPoint("RIGHT", toast, "RIGHT", -120, 0)
        toast.titleText:SetPoint("TOPLEFT", toast.detailText, "BOTTOMLEFT", 0, -4)
        toast.titleText:SetPoint("RIGHT", toast, "RIGHT", -10, 0)
        toast.tagText:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -10, -14)
        local tint = THREAT_COLORS[view.threatLevel] or THREAT_COLORS.LOW
        toast.tagText:SetTextColor(tint[1], tint[2], tint[3])
        toast.auraIcons[1]:SetPoint("TOPLEFT", toast, "TOPLEFT", 86, -54)
        for i = 1, 3 do
            toast.cellLabels[i]:Hide()
            toast.cellValues[i]:Hide()
        end
        for i = 1, 4 do toast.meterBars[i]:Hide() end
    else
        toast.sideBlock:Hide()
        toast.icon:SetPoint("TOPLEFT", toast, "TOPLEFT", 10, -10)
        toast.levelText:SetText("")
        toast.titleText:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 8, 0)
        toast.titleText:SetPoint("RIGHT", toast, "RIGHT", -100, 0)
        toast.detailText:SetPoint("TOPLEFT", toast.titleText, "BOTTOMLEFT", 0, -2)
        toast.detailText:SetPoint("RIGHT", toast, "RIGHT", -10, 0)
        toast.tagText:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -10, -12)
        toast.tagText:SetTextColor(0.85, 0.87, 0.92)
        toast.auraIcons[1]:SetPoint("TOPLEFT", toast, "TOPLEFT", 262, -52)
        local values = {view.levelShort or "-", view.band or "-", view.groupText or "-"}
        for i = 1, 3 do
            toast.cellLabels[i]:ClearAllPoints()
            toast.cellLabels[i]:SetPoint("TOPLEFT", toast, "TOPLEFT", CELL_X[i], -52)
            toast.cellLabels[i]:SetText(CELL_LABELS[i])
            toast.cellLabels[i]:Show()
            toast.cellValues[i]:ClearAllPoints()
            toast.cellValues[i]:SetPoint("TOPLEFT", toast.cellLabels[i], "BOTTOMLEFT", 0, -1)
            toast.cellValues[i]:SetText(values[i])
            toast.cellValues[i]:Show()
        end
        local rank = view.bandRank or 0
        for i = 1, 4 do
            local bar = toast.meterBars[i]
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", toast.cellValues[2], "BOTTOMLEFT", (i - 1) * 17, -3)
            if i <= rank then
                bar:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
            else
                bar:SetVertexColor(1, 1, 1, 0.2)
            end
            bar:SetShown(view.band ~= nil)
        end
    end

    local auras = view.auras or {}
    for i = 1, MAX_AURA_ICONS do
        local aura = auras[i]
        if aura then
            toast.auraIcons[i]:SetTexture(aura.icon)
            toast.auraIcons[i]:Show()
            if aura.text then
                toast.auraDurationTexts[i]:SetText(aura.text)
                toast.auraDurationTexts[i]:Show()
            else
                toast.auraDurationTexts[i]:Hide()
            end
        else
            toast.auraIcons[i]:Hide()
            toast.auraDurationTexts[i]:Hide()
        end
    end

    DrawSpell(toast, view)
end

local function CreateToastFrame(index, isSecure)
    local frameName = isSecure and "SoundAlerterSecureToast"..index or "SoundAlerterInsecureToast"..index
    local toast = CreateFrame("Button", frameName, UIParent, "BackdropTemplate")
    toast:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
    toast:SetFrameStrata("HIGH")
    toast:SetFrameLevel(100)
    toast:Hide()
    toast:SetAlpha(0)

    toast:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
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

    toast.levelText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toast.levelText:SetPoint("BOTTOM", toast.icon, "BOTTOM", 0, 2)
    toast.levelText:SetTextColor(1, 0.82, 0)
    toast.levelText:SetShadowOffset(1, -1)
    toast.levelText:SetShadowColor(0, 0, 0, 1)

    toast.tagText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toast.sideBlock = toast:CreateTexture(nil, "BACKGROUND", nil, 1)
    toast.sideBlock:SetTexture("Interface\\Buttons\\WHITE8X8")
    toast.sideBlock:Hide()

    toast.cellLabels = {}
    toast.cellValues = {}
    for i = 1, 3 do
        toast.cellLabels[i] = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        toast.cellLabels[i]:SetTextColor(0.6, 0.63, 0.7)
        toast.cellValues[i] = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    end
    toast.meterBars = {}
    for i = 1, 4 do
        local bar = toast:CreateTexture(nil, "ARTWORK")
        bar:SetTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetSize(14, 3)
        toast.meterBars[i] = bar
    end

    toast.auraIcons = {}
    toast.auraDurationTexts = {}
    for i = 1, MAX_AURA_ICONS do
        local auraIcon = toast:CreateTexture(nil, "ARTWORK")
        auraIcon:SetSize(AURA_ICON_SIZE, AURA_ICON_SIZE)
        if i == 1 then
            auraIcon:SetPoint("TOPLEFT", toast.detailText, "BOTTOMLEFT", 0, -4)
        else
            auraIcon:SetPoint("LEFT", toast.auraIcons[i - 1], "RIGHT", AURA_ICON_SPACING, 0)
        end
        auraIcon:Hide()
        toast.auraIcons[i] = auraIcon

        local durationText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        local durationFont, _, durationFlags = durationText:GetFont()
        durationText:SetFont(durationFont, 8, durationFlags)
        durationText:SetPoint("TOP", auraIcon, "BOTTOM", 0, 0)
        durationText:SetTextColor(1, 1, 1)
        toast.auraDurationTexts[i] = durationText
    end

    toast.spellIcon = toast:CreateTexture(nil, "ARTWORK")
    toast.spellIcon:SetSize(18, 18)
    toast.spellIcon:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -10, -30)
    toast.spellIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    toast.spellIcon:Hide()
    toast.spellText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toast.spellText:SetPoint("RIGHT", toast.spellIcon, "LEFT", -4, 0)
    toast.spellText:SetWidth(110)
    toast.spellText:SetJustifyH("RIGHT")
    toast.spellText:SetWordWrap(false)
    toast.spellText:SetTextColor(1, 0.82, 0)
    toast.spellText:Hide()

    toast.countdownBar = CreateFrame("Frame", nil, toast)
    toast.countdownBar:SetHeight(3)
    toast.countdownBar:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 4, 4)
    toast.countdownBar:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -4, 4)
    toast.countdownBar:SetFrameLevel(toast:GetFrameLevel() + 2)
    toast.countdownBar.segments = {}

    local MAX_SEGMENTS = 30
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
        guid = nil,
        className = nil,
        unitToken = nil,
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
            if elapsed >= FADE_IN_DURATION and elapsed < (FADE_IN_DURATION + toast.displayDuration) then
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
        if self.isSecure or InCombatLockdown() then
            return
        end

        local sadb = SoundAlerter.db1.profile

        if not sadb.proximityToasts or not sadb.proximityToasts.clickEnabled then
            return
        end

        local targetName = self.userData and self.userData.unitName

        if not targetName then
            return
        end

        local targetSuccess = TargetByNameCompat(targetName, self.userData.unitToken)

        if not targetSuccess then
            SoundAlerter:Debug("ProximityToasts", "failed to target %s (unit not visible)", targetName)
        end

        if IsShiftKeyDown() then
            if sadb.proximityToasts.enableFocusTarget then
                FocusUnit("target")
            end
        end

        local dismissTime = GetTime() + 0.15
        self.pendingDismiss = true
        self.dismissTime = dismissTime

        self:SetScript("OnUpdate", function(frame, elapsed)
            if frame.pendingDismiss and GetTime() >= frame.dismissTime then
                frame.pendingDismiss = false
                frame:SetScript("OnUpdate", nil)
                ProximityToasts:ReleaseToast(frame)
            end
        end)
    end)

    toast:SetScript("OnEnter", function(self)
        if not self.inUse or self.pendingDismiss then
            return
        end

        local elapsed = GetTime() - self.startTime - self.pauseState.totalTime
        if elapsed >= FADE_IN_DURATION and elapsed < (FADE_IN_DURATION + self.displayDuration) then
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

function ProximityToasts:CreateSecurePool()
    for i = 1, MAX_TOASTS do
        local success, secureFrame = pcall(function()
            return CreateToastFrame(i, true)
        end)
        if success then
            self.secureToastPool[i] = secureFrame
        else
            error("ProximityToasts: secure frame "..i.." failed to create — "..tostring(secureFrame))
        end
    end

    self.secureCreationPending = false
    return true
end

function ProximityToasts:Initialize()
    if self.initialized then
        return
    end

    local sadb = SoundAlerter.db1.profile
    if not sadb.proximityToasts then
        sadb.proximityToasts = {}
    end

    if sadb.proximityToasts.clickEnabled == nil then
        sadb.proximityToasts.clickEnabled = true
    end
    if sadb.proximityToasts.enableClickToTarget == nil then
        sadb.proximityToasts.enableClickToTarget = true
    end
    if sadb.proximityToasts.enableFocusTarget == nil then
        sadb.proximityToasts.enableFocusTarget = true
    end

    for i = 1, MAX_TOASTS do
        local success2, insecureFrame = pcall(function()
            return CreateToastFrame(i, false)
        end)
        if success2 then
            self.insecureToastPool[i] = insecureFrame
        else
            error("ProximityToasts: insecure frame "..i.." failed to create — "..tostring(insecureFrame))
        end
    end

    if InCombatLockdown() then
        self.secureCreationPending = true
    else
        self:CreateSecurePool()
    end

    self.poolState = {
        securePool = self.secureToastPool,
        insecurePool = self.insecureToastPool,
        activeList = self.activeToasts,
        poolSize = MAX_TOASTS,
        swapInProgress = false,
        swapBuffer = self.insecureSwapBuffer,
        metrics = self.swapMetrics,
        onLayoutChanged = function() self:UpdateLayout() end,
    }

    local combatFrame = CreateFrame("Frame")
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            ProximityToasts.inCombat = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            ProximityToasts.inCombat = false
            FlushDeferredHides()
            if ProximityToasts.secureCreationPending then
                local ok, err = pcall(ProximityToasts.CreateSecurePool, ProximityToasts)
                if not ok then
                    SoundAlerter:Print("|cffFF7D0ASoundAlerter|r: ProximityToasts secure pool creation failed — "..tostring(err))
                end
            end
            ProximityToasts:SwapInsecureToSecureFrames()
        end
    end)

    self.initialized = true
    self:StartCleanupTimer()
    self:SubscribeCasts()

end

function ProximityToasts:ShowSpell(guid, spellID)
    for _, toast in ipairs(self.activeToasts) do
        local view = toast.view
        if view and toast.userData and toast.userData.guid == guid then
            local name, icon = SA_Secret.Name(spellID), SA_Secret.Icon(spellID)
            if name ~= nil or icon ~= nil then
                view.spellName, view.spellIcon = name, icon
                DrawSpell(toast, view)
            end
            return
        end
    end
end

function ProximityToasts:OnCastSeen(unit, castGUID, spellID)
    if #self.activeToasts == 0 then return end
    local settings = self:GetSettings()
    if not (settings.enabled and settings.showLatestSpell) then return end
    local guid = SA_Plates.GUID(unit)
    if not guid and (unit == "target" or unit == "focus") then guid = SA_COMPAT.Plain(UnitGUID(unit)) end
    if not guid then return end
    self:ShowSpell(guid, spellID)
end

function ProximityToasts:SubscribeCasts()
    local function seen(unit, castGUID, spellID) self:OnCastSeen(unit, castGUID, spellID) end
    SA_CastDispatch.Subscribe("toasts", {
        UNIT_SPELLCAST_START = seen,
        UNIT_SPELLCAST_CHANNEL_START = seen,
        UNIT_SPELLCAST_SUCCEEDED = seen,
    })
end

function ProximityToasts:AcquireToast()
    self.poolState.inCombat = self.inCombat
    return SoundAlerter.BarUtils:AcquireToastFromPool(self.poolState, function(toast) self:ReleaseToast(toast) end)
end

function ProximityToasts:ReleaseToast(toast)
    toast:SetScript("OnUpdate", nil)
    HideToast(toast)
    toast:SetAlpha(0)
    if not IsLocked(toast) then toast:SetScale(1.0) end
    toast.inUse = false
    toast.creationTime = 0
    toast.startTime = 0
    toast.displayDuration = 0
    toast.pendingDismiss = false

    toast.pauseState.active = false
    toast.pauseState.startTime = 0
    toast.pauseState.totalTime = 0
    toast.segmentsHidden = false

    toast.cachedSegmentData = nil

    toast.currentY = nil
    toast.isSliding = false
    toast.slideFromY = nil
    toast.slideToY = nil
    toast.slideStartTime = nil
    toast.slideBaseX = nil

    if toast.secureButton then
        if not InCombatLockdown() then
            toast.secureButton:Hide()
            toast.secureButton:SetAttribute("macrotext1", nil)
            toast.secureButton:SetAttribute("shift-macrotext1", nil)
        else
            toast.secureButton:SetAlpha(0)
            deferredButtons[toast.secureButton] = true
        end
    end

    if toast.countdownBar and toast.countdownBar.segments then
        for i = 1, #toast.countdownBar.segments do
            toast.countdownBar.segments[i]:Hide()
            toast.countdownBar.segments[i]:SetAlpha(1)
        end
    end

    toast.view = nil
    toast.titleText:SetText("")
    toast.levelText:SetText("")
    toast.detailText:SetText("")
    toast.tagText:SetText("")
    toast.sideBlock:Hide()
    toast.icon:SetTexture(nil)
    toast.spellText:SetText("")
    toast.spellText:Hide()
    toast.spellIcon:SetTexture(nil)
    toast.spellIcon:Hide()
    toast:SetBackdropColor(0, 0, 0, 0.85)
    toast:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    if toast.userData then
        toast.userData.unitName = nil
        toast.userData.guid = nil
        toast.userData.className = nil
        toast.userData.unitToken = nil
    end

    for i = #self.activeToasts, 1, -1 do
        if self.activeToasts[i] == toast then
            table.remove(self.activeToasts, i)
            break
        end
    end

    self:UpdateLayout()
end

local ToastDataSchema = {
    "unitName", "guid", "className", "unitToken",
}

function ProximityToasts:CopyToastData(oldFrame, newFrame)
    for _, field in ipairs(ToastDataSchema) do
        if oldFrame.userData and oldFrame.userData[field] ~= nil then
            newFrame.userData[field] = oldFrame.userData[field]
        end
    end

    newFrame.startTime = oldFrame.startTime
    newFrame.displayDuration = oldFrame.displayDuration
    newFrame.creationTime = oldFrame.creationTime
    newFrame.elapsedTime = oldFrame.elapsedTime
    newFrame.currentY = oldFrame.currentY

    if newFrame.currentY then
        local sadb = SoundAlerter.db1.profile
        local baseX = sadb.proximityToasts.positionX or 0
        newFrame:ClearAllPoints()
        newFrame:SetPoint("TOP", UIParent, "TOP", baseX, newFrame.currentY)
    end

    newFrame.pauseState.active = oldFrame.pauseState.active
    newFrame.pauseState.startTime = oldFrame.pauseState.active and GetTime() or 0
    newFrame.pauseState.totalTime = oldFrame.pauseState.totalTime

    newFrame.pendingDismiss = oldFrame.pendingDismiss
    newFrame.dismissTime = oldFrame.dismissTime

    if oldFrame.cachedSegmentData then
        newFrame.cachedSegmentData = {
            duration = oldFrame.cachedSegmentData.duration,
            segmentWidth = oldFrame.cachedSegmentData.segmentWidth,
            lastHiddenSegment = oldFrame.cachedSegmentData.lastHiddenSegment
        }

        for i = 1, oldFrame.cachedSegmentData.duration do
            local oldSegment = oldFrame.countdownBar.segments[i]
            local newSegment = newFrame.countdownBar.segments[i]
            if oldSegment and newSegment then
                newSegment:ClearAllPoints()
                newSegment:SetPoint("LEFT", newFrame.countdownBar, "LEFT", (i-1) * newFrame.cachedSegmentData.segmentWidth, 0)
                newSegment:SetWidth(newFrame.cachedSegmentData.segmentWidth - 2)
                if oldSegment:IsShown() then
                    newSegment:Show()
                else
                    newSegment:Hide()
                end
            end
        end
    end

    newFrame.view = oldFrame.view
    if newFrame.view then
        ApplyView(newFrame, newFrame.view)
    end

    local r, g, b, a = oldFrame:GetBackdropColor()
    newFrame:SetBackdropColor(r, g, b, a)

    r, g, b, a = oldFrame:GetBackdropBorderColor()
    newFrame:SetBackdropBorderColor(r, g, b, a)

    if newFrame.secureButton and oldFrame.userData.unitName then
        if not InCombatLockdown() then
            local sadb = SoundAlerter.db1.profile
            local safeUnitName = SanitizeMacroText(oldFrame.userData.unitName)
            newFrame.secureButton:SetAttribute("type1", "macro")
            newFrame.secureButton:SetAttribute("macrotext1", "/target " .. safeUnitName)

            if sadb.proximityToasts.enableFocusTarget then
                newFrame.secureButton:SetAttribute("shift-type1", "macro")
                newFrame.secureButton:SetAttribute("shift-macrotext1", "/target " .. safeUnitName .. "\n/focus target")
            end

            newFrame.secureButton:SetAlpha(1)
            newFrame.secureButton:Show()
        else
            SoundAlerter:Debug("ProximityToasts", "CopyToastData skipped the secure config, in combat (should not happen)")
        end
    end

    newFrame.inUse = true
    newFrame.needsVisualRefresh = true

    newFrame:SetScript("OnUpdate", oldFrame:GetScript("OnUpdate"))

    return true
end

function ProximityToasts:SwapInsecureToSecureFrames()
    SoundAlerter.BarUtils:SwapInsecureToSecurePool(
        self.poolState,
        function(toast) self:ReleaseToast(toast) end,
        function(old, new) return self:CopyToastData(old, new) end,
        SoundAlerter, "Proximity", 6.0
    )
end

function ProximityToasts:UpdateLayout()
    local sadb = SoundAlerter.db1.profile
    local baseX = sadb.proximityToasts.positionX or 0
    local baseY = sadb.proximityToasts.positionY or -200

    table.sort(self.activeToasts, function(a, b)
        return a.creationTime < b.creationTime
    end)

    for i, toast in ipairs(self.activeToasts) do
        local targetY = baseY - (i - 1) * (TOAST_HEIGHT + VERTICAL_SPACING)

        if toast.currentY == nil then
            toast.currentY = targetY
            toast:ClearAllPoints()
            toast:SetPoint("TOP", UIParent, "TOP", baseX, targetY)
        elseif toast.currentY ~= targetY then
            toast.slideFromY = toast.currentY
            toast.slideToY = targetY
            toast.slideStartTime = GetTime()
            toast.slideBaseX = baseX
            toast.isSliding = true
        end
    end
end

function ProximityToasts:ShouldShowToast(guid)
    if not guid then return true end

    local now = GetTime()
    local cooldown = 0.5
    local lastTime = self.lastToastTime[guid] or 0

    if now - lastTime < cooldown then
        return false
    end

    self.lastToastTime[guid] = now
    return true
end

function ProximityToasts:CleanupHistory()
    local now = GetTime()
    for guid, time in pairs(self.lastToastTime) do
        if now - time > 30 then
            self.lastToastTime[guid] = nil
        end
    end
end

local AURA_FILTERS = {"HARMFUL", "HELPFUL"}

local function FormatAuraDuration(remaining)
    if remaining >= 60 then
        return math.floor(remaining / 60) .. "m"
    end
    return tostring(math.ceil(remaining))
end

local function CollectAuras(unitToken)
    local list = {}
    if unitToken and UnitExists(unitToken) then
        for _, filter in ipairs(AURA_FILTERS) do
            for i = 1, AURA_SCAN_MAX do
                local name, _, icon, _, _, duration, expirationTime = UnitAura(unitToken, i, filter)
                if not name then break end
                if #list < MAX_AURA_ICONS then
                    local remaining = duration and duration > 0 and expirationTime and (expirationTime - GetTime())
                    list[#list + 1] = {
                        icon = icon,
                        text = remaining and remaining > 0 and FormatAuraDuration(remaining) or nil,
                    }
                end
            end
        end
    end
    return list
end

function ProximityToasts:ShowToast(unitName, className, distance, guid, level, unitToken, customTitle, alertType, nearbyCount)
    local sadb = SoundAlerter.db1.profile

    if not self.initialized then
        SoundAlerter:Debug("ProximityToasts", "toast blocked: not initialized")
        return
    end

    if not sadb.proximityToasts or not sadb.proximityToasts.enabled then
        SoundAlerter:Debug("ProximityToasts", "toast blocked: toasts disabled in options (%s)", tostring(unitName))
        return
    end

    if not unitName then
        SoundAlerter:Debug("ProximityToasts", "toast blocked: no unit name (class %s, type %s)", tostring(className), tostring(alertType))
        return
    end

    if guid and not self:ShouldShowToast(guid) then
        SoundAlerter:Debug("ProximityToasts", "toast blocked: %s is on the toast cooldown", unitName)
        return
    end

    local maxConcurrent = sadb.proximityToasts.maxConcurrent or 3
    if #self.activeToasts >= maxConcurrent then
        local oldest = self.activeToasts[1]
        if oldest then self:ReleaseToast(oldest) end
    end

    local toast = self:AcquireToast()
    if not toast then
        SoundAlerter:Debug("ProximityToasts", "toast blocked: no free toast frame for %s", unitName)
        return
    end

    SoundAlerter:Debug("ProximityToasts", "showing toast for %s (%s, %s), %d/%d active", unitName, className or "UNKNOWN", tostring(alertType), #self.activeToasts, maxConcurrent)

    local backdropConfig = GetBackdropConfig(alertType)
    toast:SetBackdrop(backdropConfig)

    if alertType == "FLAG_ENEMY" and sadb.flagTeamBackgroundColors and sadb.flagEnemyRedBackground then

        toast:SetBackdropColor(0.4, 0.05, 0.05, 0.85)
    elseif alertType == "FLAG_FRIENDLY" and sadb.flagTeamBackgroundColors and sadb.flagFriendlyGreenBackground then

        toast:SetBackdropColor(0.05, 0.4, 0.05, 0.85)
    elseif sadb.proximityToasts.useClassColors and className then

        local r, g, b = GetClassColor(className)
        toast:SetBackdropColor(r, g, b, 0.85)
    else

        toast:SetBackdropColor(0, 0, 0, 0.85)
    end

    if not sadb.proximityToasts.rainbowBorder then
        toast:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    end

    if nearbyCount == 0 then nearbyCount = 1 end

    local Style = SA_ToastStyle
    local style = Style.Normalize(sadb.proximityToasts.toastStyle)
    local classLabel = className and (className:sub(1, 1) .. className:sub(2):lower()) or "Enemy"
    local isFlag = Style.IsFlag(alertType)
    local view = {
        style = style,
        className = className,
        iconTexture = CLASS_ICONS[className] or "Interface\\Icons\\Ability_Rogue_Ambush",
        primary = (sadb.proximityToasts.showPlayerName and unitName) or classLabel,
        band = distance,
        bandRank = Style.BandRank(distance),
        levelShort = Style.LevelText(level),
        groupText = Style.GroupText(nearbyCount),
        tag = Style.Tag(alertType),
        sideLabel = className and className:upper() or "ENEMY",
        auras = sadb.proximityToasts.showAuraIcons and CollectAuras(unitToken) or {},
    }
    if style == "threat" then
        local threatLevel, _, why = Style.Threat(className, distance, nearbyCount)
        view.threatLevel = threatLevel
        if not isFlag then view.tag = threatLevel .. " THREAT" end
        if customTitle then
            view.title = customTitle
        else
            local lead = level and (level == -1 and "Lv ??" or ("Lv " .. level)) or nil
            if why == "" then why = "Enemy player nearby" end
            view.title = lead and (lead .. "  " .. why) or why
        end
        view.high = threatLevel == "HIGH" and not isFlag
    else
        view.title = customTitle or (className and (className .. " NEARBY!") or "ENEMY NEARBY!")
    end
    toast.view = view
    ApplyView(toast, view)

    if toast.userData then
        toast.userData.unitName = unitName
        toast.userData.guid = guid
        toast.userData.className = className
        toast.userData.unitToken = unitToken
    end

    if toast.secureButton and unitName then
        if not self.inCombat then
            local safeUnitName = SanitizeMacroText(unitName)
            toast.secureButton:SetAttribute("type1", "macro")
            toast.secureButton:SetAttribute("macrotext1", "/target " .. safeUnitName)

            if sadb.proximityToasts.enableFocusTarget then
                toast.secureButton:SetAttribute("shift-type1", "macro")
                toast.secureButton:SetAttribute("shift-macrotext1", "/target " .. safeUnitName .. "\n/focus target")
            end

            toast.secureButton:SetAlpha(1)
            toast.secureButton:Show()
        else
            SoundAlerter:Debug("ProximityToasts", "secure button config skipped, in combat")
        end
    end

    toast.creationTime = GetTime()
    table.insert(self.activeToasts, toast)
    self:UpdateLayout()

    toast.startTime = GetTime()
    toast.displayDuration = sadb.proximityToasts.displayDuration or 3.0

    local duration = math.ceil(toast.displayDuration)
    local segmentWidth = (TOAST_WIDTH - 8) / duration

    toast.cachedSegmentData = {
        duration = duration,
        segmentWidth = segmentWidth,
        lastHiddenSegment = 0
    }

    for i = 1, duration do
        local segment = toast.countdownBar.segments[i]
        if segment then
            segment:ClearAllPoints()
            segment:SetPoint("LEFT", toast.countdownBar, "LEFT", (i-1) * segmentWidth, 0)
            segment:SetWidth(segmentWidth - 2)
            segment:SetAlpha(1)
            segment:Show()
        end
    end

    for i = duration + 1, #toast.countdownBar.segments do
        toast.countdownBar.segments[i]:Hide()
    end

    toast.pauseState.active = false
    toast.pauseState.startTime = 0
    toast.pauseState.totalTime = 0
    toast.segmentsHidden = false

    toast:SetAlpha(0)
    if not IsLocked(toast) then toast:SetScale(1.0) end
    toast:Show()

    toast:SetScript("OnUpdate", function(self, frameDelta)
        local now = GetTime()

        if self.isSliding then
            local t = (now - self.slideStartTime) / SLIDE_DURATION
            if t >= 1 then
                self.currentY = self.slideToY
                self.isSliding = false
            else
                local eased = 1 - (1 - t) * (1 - t)
                self.currentY = self.slideFromY + (self.slideToY - self.slideFromY) * eased
            end
            if not IsLocked(self) then
                self:SetPoint("TOP", UIParent, "TOP", self.slideBaseX, self.currentY)
            end
        end

        if self.pauseState.active then
            return
        end

        local elapsed = now - self.startTime - self.pauseState.totalTime

        if sadb.proximityToasts.rainbowBorder then
            local r, g, b = GetRainbowColor(now)
            self:SetBackdropBorderColor(r, g, b, 1)
        elseif self.view and self.view.high then
            local pulse = 0.55 + 0.45 * math.abs(math.sin(now * 3))
            self:SetBackdropBorderColor(1, 0.25 * pulse, 0.2 * pulse, 1)
        end

        if elapsed < FADE_IN_DURATION then
            local progress = elapsed / FADE_IN_DURATION
            self:SetAlpha(progress)
            if not IsLocked(self) then
                self:SetScale(1.15 - (0.15 * progress))
            end

        elseif elapsed < (FADE_IN_DURATION + self.displayDuration) then
            self:SetAlpha(1)
            if not IsLocked(self) then self:SetScale(1.0) end

            local displayElapsed = elapsed - FADE_IN_DURATION
            UpdateCountdownSegments(self, displayElapsed)

        elseif elapsed < (FADE_IN_DURATION + self.displayDuration + FADE_OUT_DURATION) then
            local fadeProgress = (elapsed - FADE_IN_DURATION - self.displayDuration) / FADE_OUT_DURATION
            self:SetAlpha(1 - fadeProgress)

            if not self.segmentsHidden and self.countdownBar and self.cachedSegmentData then
                local duration = self.cachedSegmentData.duration
                for i = 1, duration do
                    self.countdownBar.segments[i]:SetAlpha(0)
                end
                self.segmentsHidden = true
            end

        else
            self:SetScript("OnUpdate", nil)
            ProximityToasts:ReleaseToast(self)
        end
    end)
end

function ProximityToasts:OnProfileChanged()
    for _, toast in ipairs(self.activeToasts) do
        self:ReleaseToast(toast)
    end
    wipe(self.lastToastTime)

end

function ProximityToasts:OnDisable()
    if self.cleanupTimer then
        SoundAlerter:CancelTimer(self.cleanupTimer)
        self.cleanupTimer = nil
    end

    for i = #self.activeToasts, 1, -1 do
        self:ReleaseToast(self.activeToasts[i])
    end
end

function ProximityToasts:StartCleanupTimer()
    if not self.cleanupTimer then
        self.cleanupTimer = SoundAlerter:ScheduleRepeatingTimer(function()
            ProximityToasts:CleanupHistory()
        end, 60)
    end
end

local SA_DEBUG_GATE_NOTE = "Debug mode is off — enable it in /sa options to use developer/testing commands."

function SoundAlerter.ProximityToasts:HandleCommand(msg)
    local command, args = msg:match("^(%S*)%s*(.-)$")
    local sadb = SoundAlerter.db1.profile

    if command == "test" then
        if not sadb.debugmode then
            DEFAULT_CHAT_FRAME:AddMessage(SA_DEBUG_GATE_NOTE)
            return
        end
        local wasDisabled = not sadb.proximityToasts.enabled
        if wasDisabled then
            sadb.proximityToasts.enabled = true
        end

        if sadb.sapath then
            SoundAlerter:PlayVoice(sadb.sapath .. "ROGUE.mp3", "Master")
            SoundAlerter:ScheduleTimer(function()
                SoundAlerter:PlayVoice(sadb.sapath .. "detected.mp3", "Master")
            end, 0.8)
        end

        local duration = tonumber(args)
        if duration and duration > 0 then
            local savedDuration = sadb.proximityToasts.displayDuration
            sadb.proximityToasts.displayDuration = duration
            self:ShowToast("TestEnemy", "ROGUE", nil, nil, 80, nil, nil)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Test toast displayed with " .. duration .. "s duration.|r")
            sadb.proximityToasts.displayDuration = savedDuration
        else
            self:ShowToast("TestEnemy", "ROGUE", nil, nil, 80, nil, nil)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Test toast displayed.|r")
        end

        if wasDisabled then
            sadb.proximityToasts.enabled = false
        end
    elseif command == "multi" then
        if not sadb.debugmode then
            DEFAULT_CHAT_FRAME:AddMessage(SA_DEBUG_GATE_NOTE)
            return
        end
        local count = tonumber(args) or 3
        local wasDisabled = not sadb.proximityToasts.enabled
        if wasDisabled then
            sadb.proximityToasts.enabled = true
        end

        local classes = {"WARRIOR", "PALADIN", "ROGUE", "MAGE", "WARLOCK"}
        for i = 1, math.min(count, 5) do
            self:ShowToast("TestEnemy"..i, classes[i], nil, nil, 80, nil, nil)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Created " .. count .. " test toasts.|r")

        if wasDisabled then
            sadb.proximityToasts.enabled = false
        end
    elseif command == "countdown" then
        if not sadb.debugmode then
            DEFAULT_CHAT_FRAME:AddMessage(SA_DEBUG_GATE_NOTE)
            return
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF=== Countdown Debug ===|r")
        for i, toast in ipairs(self.activeToasts) do
            if toast.cachedSegmentData then
                local elapsed = GetTime() - toast.startTime - toast.pauseState.totalTime
                local displayElapsed = math.max(0, elapsed - FADE_IN_DURATION)
                DEFAULT_CHAT_FRAME:AddMessage("Toast " .. i .. ":")
                DEFAULT_CHAT_FRAME:AddMessage("  Duration: " .. toast.displayDuration .. "s")
                DEFAULT_CHAT_FRAME:AddMessage("  Segments: " .. toast.cachedSegmentData.duration)
                DEFAULT_CHAT_FRAME:AddMessage("  Elapsed: " .. string.format("%.2f", displayElapsed) .. "s")
                DEFAULT_CHAT_FRAME:AddMessage("  Paused: " .. tostring(toast.pauseState.active))
                DEFAULT_CHAT_FRAME:AddMessage("  Total Pause Time: " .. string.format("%.2f", toast.pauseState.totalTime) .. "s")
            end
        end
    elseif command == "init" then
        self:Initialize()
    elseif command == "enable" then
        sadb.proximityToasts.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Toasts enabled|r")
    elseif command == "enableclick" then
        if not sadb.proximityToasts then
            sadb.proximityToasts = {}
        end
        sadb.proximityToasts.clickEnabled = true
        sadb.proximityToasts.enableClickToTarget = true
        sadb.proximityToasts.enableFocusTarget = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Click-to-target enabled|r")
    elseif command == "testcustom" then
        if not sadb.debugmode then
            DEFAULT_CHAT_FRAME:AddMessage(SA_DEBUG_GATE_NOTE)
            return
        end
        local wasDisabled = not sadb.proximityToasts.enabled
        if wasDisabled then
            sadb.proximityToasts.enabled = true
        end

        if sadb.sapath then
            SoundAlerter:PlayVoice(sadb.sapath .. "ROGUE.mp3", "Master")
            SoundAlerter:ScheduleTimer(function()
                SoundAlerter:PlayVoice(sadb.sapath .. "FlagPickup.mp3", "Master")
            end, 0.8)
        end

        self:ShowToast("TestCarrier", "ROGUE", nil, "Player-Test-FLAG", 80, nil, "FLAG CARRIER!")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Test toast with custom title displayed.|r")

        if wasDisabled then
            sadb.proximityToasts.enabled = false
        end
    elseif command == "swapmetrics" then
        if not sadb.debugmode then
            DEFAULT_CHAT_FRAME:AddMessage(SA_DEBUG_GATE_NOTE)
            return
        end
        local m = self.swapMetrics
        if not m or m.count == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700=== Frame Swap Metrics ===|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF6B6BNo swap data collected yet|r")
            return
        end

        local avgTime = m.totalTime / m.count
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700=== Frame Swap Performance Metrics ===|r")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Total swaps: |cffFFFFFF%d|r", m.count))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Avg time: |cffFFFFFF%.2fms|r", avgTime))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Max time: |cffFFFFFF%.2fms|r", m.maxTime))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Total time: |cffFFFFFF%.2fms|r", m.totalTime))
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Frame Count Distribution]|r")
        for frameCount, count in pairs(m.histogram) do
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %d frames: |cffFFFFFF%d|r swaps", frameCount, count))
        end
    elseif command == "status" then
        local PT = self

        local securePoolSize = #PT.secureToastPool
        local insecurePoolSize = #PT.insecureToastPool
        local activeCount = #PT.activeToasts
        local activePoolType = PT.inCombat and "Insecure (Combat)" or "Secure (Non-Combat)"
        local utilization = (PT.inCombat and insecurePoolSize > 0) and (activeCount / insecurePoolSize * 100) or
                           (not PT.inCombat and securePoolSize > 0) and (activeCount / securePoolSize * 100) or 0

        local historyCount = 0
        for _ in pairs(PT.lastToastTime) do
            historyCount = historyCount + 1
        end

        local statusColor = PT.initialized and "|cff00FF00" or "|cffFF6B6B"
        local statusText = PT.initialized and "Online" or "Offline"

        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700=== Proximity Alerts - Performance Metrics ===|r")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[System Status]|r")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Status: %s%s|r", statusColor, statusText))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Initialized: |cffFFFFFF%s|r", tostring(PT.initialized)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  In Combat: |cffFFFFFF%s|r", tostring(PT.inCombat)))
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Click Settings]|r")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Click Enabled: |cffFFFFFF%s|r", tostring(sadb.proximityToasts and sadb.proximityToasts.clickEnabled or false)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Click-to-Target: |cffFFFFFF%s|r", tostring(sadb.proximityToasts and sadb.proximityToasts.enableClickToTarget or false)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Focus Target: |cffFFFFFF%s|r", tostring(sadb.proximityToasts and sadb.proximityToasts.enableFocusTarget or false)))
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Toast Pool]|r")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Active Pool: |cffFFFFFF%s|r", activePoolType))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Secure Pool Size: |cffFFFFFF%d|r frames", securePoolSize))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Insecure Pool Size: |cffFFFFFF%d|r frames", insecurePoolSize))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Active Toasts: |cffFFFFFF%d|r", activeCount))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Utilization: |cffFFFFFF%.1f%%|r", utilization))
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Alert History]|r")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Tracked Players: |cffFFFFFF%d|r", historyCount))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Cooldown Window: |cffFFFFFF30|r seconds"))
    else
        self:PrintHelp()
    end
end

function SoundAlerter.ProximityToasts:PrintHelp()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Proximity Toasts]|r")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast status|r - Show performance metrics and system status")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast swapmetrics|r - Show frame swap performance data")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast enable|r - Enable toast notifications")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast enableclick|r - Enable click-to-target functionality")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast init|r - Manually initialize toast system")
    if SoundAlerter.db1.profile.debugmode then
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast test [duration]|r - [debug] Show test toast (optional duration in seconds)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast testcustom|r - [debug] Test custom title (FLAG CARRIER!)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast multi [count]|r - [debug] Create multiple test toasts (default: 3)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast countdown|r - [debug] Show countdown debug info for active toasts")
    else
        DEFAULT_CHAT_FRAME:AddMessage("  |cffAAAAAA4 developer commands hidden — enable debug mode in /sa options to see them.|r")
    end
end
