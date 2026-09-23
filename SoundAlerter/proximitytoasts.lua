local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
if not SoundAlerter then
    return
end

local ProximityToasts = {}
SoundAlerter.ProximityToasts = ProximityToasts

ProximityToasts.inCombat = false

local MAX_TOASTS = 5
local TOAST_WIDTH = 300
local TOAST_HEIGHT = 72
local VERTICAL_SPACING = 8
local FADE_IN_DURATION = 0.2
local FADE_OUT_DURATION = 0.5

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

    local sadb = SoundAlerter.db1.profile

    if UnitExists("target") and UnitName("target") == targetName then
        if sadb.debugmode then
            SoundAlerter:Print("[Toast Click] Already targeting: " .. targetName)
        end
        return true
    end

    if unitToken and UnitExists(unitToken) and UnitName(unitToken) == targetName then
        TargetUnit(unitToken)

        if UnitExists("target") and UnitName("target") == targetName then
            if sadb.debugmode then
                SoundAlerter:Print("[Toast Click] Targeted via cached token: " .. targetName .. " (" .. unitToken .. ")")
            end
            return true
        end
    end

    for _, unitId in ipairs(unitScanOrder) do
        if UnitExists(unitId) and UnitName(unitId) == targetName then
            TargetUnit(unitId)

            if UnitExists("target") and UnitName("target") == targetName then
                if sadb.debugmode then
                    SoundAlerter:Print("[Toast Click] Targeted via scan: " .. targetName .. " (" .. unitId .. ")")
                end
                return true
            end
        end
    end

    if sadb.debugmode then
        SoundAlerter:Print("[Toast Click] Could not locate unit: " .. targetName .. " (not in scannable units)")
    end

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

    toast.levelText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toast.levelText:SetPoint("BOTTOMLEFT", toast.icon, "BOTTOMRIGHT", 10, 2)
    toast.levelText:SetTextColor(1, 0.82, 0)

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
        if self.isSecure then
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
            if sadb.debugmode then
                SoundAlerter:Print("[ProximityToasts] Failed to target " .. targetName .. " (unit not visible)")
            end

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

    if SoundAlerter.db1.profile.debugmode then
        SoundAlerter:Print("Proximity Toasts initialized with dual pools (" .. MAX_TOASTS .. " secure + " .. MAX_TOASTS .. " insecure)")
    end
end

function ProximityToasts:AcquireToast()
    self.poolState.inCombat = self.inCombat
    return SoundAlerter.BarUtils:AcquireToastFromPool(self.poolState, function(toast) self:ReleaseToast(toast) end)
end

function ProximityToasts:ReleaseToast(toast)
    toast:SetScript("OnUpdate", nil)
    toast:Hide()
    toast:SetAlpha(0)
    toast:SetScale(1.0)
    toast.inUse = false
    toast.creationTime = 0
    toast.startTime = 0
    toast.displayDuration = 0
    toast.pendingDismiss = false

    toast.pauseState.active = false
    toast.pauseState.startTime = 0
    toast.pauseState.totalTime = 0

    toast.cachedSegmentData = nil

    if toast.secureButton then
        if not InCombatLockdown() then
            toast.secureButton:Hide()
            toast.secureButton:SetAttribute("macrotext1", nil)
            toast.secureButton:SetAttribute("shift-macrotext1", nil)
        else

            toast.secureButton:Hide()
        end
    end

    if toast.countdownBar and toast.countdownBar.segments then
        for i = 1, #toast.countdownBar.segments do
            toast.countdownBar.segments[i]:Hide()
            toast.countdownBar.segments[i]:SetAlpha(1)
        end
    end

    toast.titleText:SetText("")
    toast.levelText:SetText("")
    toast.detailText:SetText("")
    toast.icon:SetTexture(nil)
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

    if oldFrame.icon:GetTexture() then
        newFrame.icon:SetTexture(oldFrame.icon:GetTexture())
    end

    newFrame.titleText:SetText(oldFrame.titleText:GetText() or "")
    newFrame.levelText:SetText(oldFrame.levelText:GetText() or "")
    newFrame.detailText:SetText(oldFrame.detailText:GetText() or "")

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

            newFrame.secureButton:Show()
        elseif SoundAlerter.db1.profile.debugmode then
            SoundAlerter:Print("[ProximityToasts] CopyToastData: Skipped secure config (in combat - should never happen)")
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
        toast:ClearAllPoints()
        if i == 1 then
            toast:SetPoint("TOP", UIParent, "TOP", baseX, baseY)
        else
            toast:SetPoint("TOP", self.activeToasts[i-1], "BOTTOM", 0, -VERTICAL_SPACING)
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

function ProximityToasts:ShowToast(unitName, className, distance, guid, level, unitToken, customTitle, alertType)
    local sadb = SoundAlerter.db1.profile

    if not self.initialized then
        if sadb.debugmode then
            SoundAlerter:Print("[ProximityToasts] ShowToast blocked: not initialized")
        end
        return
    end

    if not sadb.proximityToasts or not sadb.proximityToasts.enabled then
        if sadb.debugmode then
            SoundAlerter:Print("[ProximityToasts] ShowToast blocked: toasts disabled")
        end
        return
    end

    if not unitName then
        if sadb.debugmode then
            SoundAlerter:Print("[ProximityToasts] ShowToast blocked: no unitName")
        end
        return
    end

    if guid and not self:ShouldShowToast(guid) then
        if sadb.debugmode then
            SoundAlerter:Print("[ProximityToasts] ShowToast blocked: cooldown (" .. unitName .. ")")
        end
        return
    end

    local maxConcurrent = sadb.proximityToasts.maxConcurrent or 3
    if #self.activeToasts >= maxConcurrent then
        local oldest = self.activeToasts[1]
        if oldest then self:ReleaseToast(oldest) end
    end

    local toast = self:AcquireToast()
    if not toast then
        if sadb.debugmode then
            SoundAlerter:Print("[ProximityToasts] ShowToast blocked: no available toast frame")
        end
        return
    end

    if sadb.debugmode then
        SoundAlerter:Print("[ProximityToasts] Showing toast for " .. unitName .. " (" .. (className or "UNKNOWN") .. ")")
    end

    toast.icon:SetTexture(CLASS_ICONS[className] or "Interface\\Icons\\Ability_Rogue_Ambush")

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

    if customTitle then
        toast.titleText:SetText(customTitle)
    else
        toast.titleText:SetText(className and (className .. " NEARBY!") or "ENEMY NEARBY!")
    end

    if level then
        if level == -1 then
            toast.levelText:SetText("High Level")
        else
            toast.levelText:SetText("Level " .. level)
        end
    else
        toast.levelText:SetText("")
    end

    local detailText = ""
    if sadb.proximityToasts.showPlayerName and unitName then
        detailText = unitName
    end

    local extras = {}
    if distance then table.insert(extras, "~" .. distance) end
    if #extras > 0 then
        local extraText = table.concat(extras, ", ")
        detailText = (detailText ~= "") and (detailText .. " (" .. extraText .. ")") or extraText
    end

    toast.detailText:SetText(detailText)

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

            toast.secureButton:Show()
        elseif sadb.debugmode then
            SoundAlerter:Print("[ProximityToasts] Skipped secure button config (in combat)")
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

    toast:SetAlpha(0)
    toast:SetScale(1.0)
    toast:Show()

    toast:SetScript("OnUpdate", function(self, frameDelta)
        if self.pauseState.active then
            return
        end

        local now = GetTime()
        local elapsed = now - self.startTime - self.pauseState.totalTime

        if sadb.proximityToasts.rainbowBorder then
            local r, g, b = GetRainbowColor(now)
            self:SetBackdropBorderColor(r, g, b, 1)
        end

        if elapsed < FADE_IN_DURATION then
            local progress = elapsed / FADE_IN_DURATION
            self:SetAlpha(progress)
            local scale = 1.15 - (0.15 * progress)
            self:SetScale(scale)

        elseif elapsed < (FADE_IN_DURATION + self.displayDuration) then
            self:SetAlpha(1)
            self:SetScale(1.0)

            local displayElapsed = elapsed - FADE_IN_DURATION
            UpdateCountdownSegments(self, displayElapsed)

        elseif elapsed < (FADE_IN_DURATION + self.displayDuration + FADE_OUT_DURATION) then
            local fadeProgress = (elapsed - FADE_IN_DURATION - self.displayDuration) / FADE_OUT_DURATION
            self:SetAlpha(1 - fadeProgress)

            if self.countdownBar and self.cachedSegmentData then
                local duration = self.cachedSegmentData.duration
                for i = 1, duration do
                    self.countdownBar.segments[i]:SetAlpha(0)
                end
            end

        else
            self:SetScript("OnUpdate", nil)
            self:Hide()
            ProximityToasts:ReleaseToast(self)
        end
    end)
end

function ProximityToasts:OnProfileChanged()
    for _, toast in ipairs(self.activeToasts) do
        self:ReleaseToast(toast)
    end
    wipe(self.lastToastTime)

    if SoundAlerter.db1.profile.debugmode then
        SoundAlerter:Print("Proximity Toasts: Profile changed")
    end
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
            PlaySoundFile(sadb.sapath .. "ROGUE.mp3", "Master")
            SoundAlerter:ScheduleTimer(function()
                PlaySoundFile(sadb.sapath .. "detected.mp3", "Master")
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
            PlaySoundFile(sadb.sapath .. "ROGUE.mp3", "Master")
            SoundAlerter:ScheduleTimer(function()
                PlaySoundFile(sadb.sapath .. "FlagPickup.mp3", "Master")
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
