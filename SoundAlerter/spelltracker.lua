local SpellTracker = {}
local GetSpellInfo = SA_COMPAT.GetSpellInfo
local Game = SA_TrackerGame
local Border = SA_TrackerBorder

local Settings = SA_TrackerSettings
local ICON_SIZE = Settings.DEFAULT_ICON_SIZE
local ICON_SPACING = 4
local ICON_POOL_SIZE = 20
local UPDATE_THROTTLE = 0.033

local CONSTANTS = {
    INACTIVE_ALPHA = 0.3,
    ACTIVE_ALPHA = 1.0,
    ICON_INSET = 4,
    BACKDROP_EDGE_SIZE = 16,
    DEFAULT_POS_X_OFFSET = -200,
    DEFAULT_POS_Y = -100,
    DEFAULT_COOLDOWN_TEXT_SIZE = Settings.IconDefault("cooldownTextSize"),
}

local iconFrames = {}
local throttleTime = 0
local spellTextureCache = {}
local trackedSpellsByUnit = { player = {}, target = {} }

local cooldownThrottle = 0
local COOLDOWN_UPDATE_INTERVAL = 0.1

local cooldownEnabledTrackers = {}

function SpellTracker:Initialize()
    if self.initialized then return end

    local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not SoundAlerter then
        error("SpellTracker:Initialize() called before addon is ready")
        return
    end

    self.addon = SoundAlerter
    self.db = self.addon.db1.profile.spellTracker

    self.state = SA_TrackerState.New()
    self.cachedTime = 0
    self.lookupFailed = {}

    self.timeStrings = {}
    for i = 0, 60 do
        self.timeStrings[i] = tostring(i)
    end

    self:CreateIconFrames()
    self:RegisterEvents()
    self:LoadSettings()

    self.initialized = true
end

function SpellTracker:CreateIconFrames()
    local container = CreateFrame("Frame", "SoundAlerter_SpellTrackerContainer", UIParent)
    container:SetSize(ICON_POOL_SIZE * (ICON_SIZE + ICON_SPACING), ICON_SIZE)
    container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    container:SetMovable(true)
    container:EnableMouse(false)

    self.container = container

    for i = 1, ICON_POOL_SIZE do
        local icon = self:CreateIcon(i)
        iconFrames[i] = icon
    end
end

function SpellTracker:CreateIconFrame(index)
    local frame = CreateFrame("Frame", "SoundAlerter_SpellTracker_Icon" .. index, self.container, "BackdropTemplate")
    frame:SetSize(ICON_SIZE, ICON_SIZE)

    local idle = Border.COLORS.IDLE
    frame.borderKey = "IDLE"
    self.addon.BarUtils:CreateBackdrop(frame, idle[1], idle[2], idle[3], 1,
        "Interface\\DialogFrame\\UI-DialogBox-Background", 0, 0, 0, 0.8,
        CONSTANTS.BACKDROP_EDGE_SIZE, CONSTANTS.ICON_INSET)

    return frame
end

function SpellTracker:CreateIconTexture(frame)
    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", CONSTANTS.ICON_INSET, -CONSTANTS.ICON_INSET)
    texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CONSTANTS.ICON_INSET, CONSTANTS.ICON_INSET)
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.texture = texture
end

function SpellTracker:CreateIconCooldown(frame)
    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(frame.texture)
    cooldown:SetReverse(true)
    frame.cooldown = cooldown

    frame.cooldownNumbers = self:CreateNumbersFrame(frame)
    frame.auraNumbers = self:CreateNumbersFrame(frame)
end

function SpellTracker:CreateNumbersFrame(frame)
    local numbers = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    numbers:SetAllPoints(frame.texture)
    numbers:SetFrameLevel(frame.cooldown:GetFrameLevel() + 3)
    numbers:SetIgnoreParentAlpha(true)
    numbers:SetDrawSwipe(false)
    numbers:SetDrawEdge(false)
    numbers:SetDrawBling(false)
    numbers:SetHideCountdownNumbers(false)
    for _, region in ipairs({ numbers:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            numbers.text = region
        end
    end
    return numbers
end

function SpellTracker:StyleCooldownNumbers(frame, size)
    local text = frame.cooldownNumbers and frame.cooldownNumbers.text
    if not text then return end
    text:ClearAllPoints()
    text:SetPoint("TOP", frame, "TOP", 0, -1)
    text:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    text:SetTextColor(1, 0.82, 0, 1)

    local auraText = frame.auraNumbers and frame.auraNumbers.text
    if auraText then
        auraText:ClearAllPoints()
        auraText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
        auraText:SetFont("Fonts\\FRIZQT__.TTF", CONSTANTS.DEFAULT_COOLDOWN_TEXT_SIZE, "OUTLINE")
        auraText:SetTextColor(1, 1, 1, 1)
    end
end

function SpellTracker:CreateIconText(frame)
    local textLayer = CreateFrame("Frame", nil, frame)
    textLayer:SetAllPoints(frame)
    textLayer:SetFrameLevel(frame.cooldown:GetFrameLevel() + 2)
    textLayer:SetIgnoreParentAlpha(true)
    frame.textLayer = textLayer

    local timerText = textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    timerText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2)
    timerText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2)
    timerText:SetJustifyH("CENTER")
    timerText:SetTextColor(1, 1, 1, 1)
    timerText:SetFont("Fonts\\FRIZQT__.TTF", CONSTANTS.DEFAULT_COOLDOWN_TEXT_SIZE, "OUTLINE")
    timerText:SetText("")
    frame.timerText = timerText

    local cooldownText = textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cooldownText:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
    cooldownText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -1)
    cooldownText:SetJustifyH("CENTER")
    cooldownText:SetTextColor(1, 0.82, 0, 1)
    cooldownText:SetFont("Fonts\\FRIZQT__.TTF", CONSTANTS.DEFAULT_COOLDOWN_TEXT_SIZE, "OUTLINE")
    cooldownText:SetText("")
    frame.cooldownText = cooldownText
end

function SpellTracker:CreateIconAnimation(frame)
    local pulseGroup = frame:CreateAnimationGroup()

    local pulseScale1 = pulseGroup:CreateAnimation("Scale")
    pulseScale1:SetScale(1.15, 1.15)
    pulseScale1:SetDuration(0.15)
    pulseScale1:SetOrder(1)

    local pulseScale2 = pulseGroup:CreateAnimation("Scale")
    pulseScale2:SetScale(0.87, 0.87)
    pulseScale2:SetDuration(0.15)
    pulseScale2:SetOrder(2)

    frame.pulseAnim = pulseGroup
end

function SpellTracker:CreateIconGlow(frame)
    local glowFrame = CreateFrame("Frame", nil, frame)
    glowFrame:SetAllPoints(frame)
    glowFrame:SetIgnoreParentAlpha(true)

    local glow = glowFrame:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetPoint("CENTER", frame, "CENTER")
    glow:Hide()

    local group = glow:CreateAnimationGroup()
    group:SetScript("OnFinished", function()
        if frame.glowKey == "applied" then
            frame.glowKey = nil
            glow:Hide()
            SpellTracker:RefreshBorder(frame.trackerIndex)
        end
    end)

    frame.glow = glow
    frame.glowGroup = group
    frame.glowFade = group:CreateAnimation("Alpha")
end

local function applyGlow(frame, key)
    if key == frame.glowKey then return end
    frame.glowKey = key
    frame.glowGroup:Stop()

    local style = key and Border.GLOWS[key]
    if not style then
        frame.glow:Hide()
        return
    end

    frame.glow:SetVertexColor(style[1], style[2], style[3])
    if style.mode == "steady" then
        frame.glow:SetAlpha(0.3)
    else
        local flash = style.mode == "flash"
        frame.glow:SetAlpha(1)
        frame.glowGroup:SetLooping(flash and "NONE" or "BOUNCE")
        frame.glowFade:SetFromAlpha(1)
        frame.glowFade:SetToAlpha(flash and 0 or 0.35)
        frame.glowFade:SetDuration(flash and 0.4 or 0.5)
        frame.glowGroup:Play()
    end
    frame.glow:Show()
end

function SpellTracker:RefreshBorder(trackerIndex, now)
    local frame = iconFrames[trackerIndex]
    local config = self.db.icons[trackerIndex]
    if not frame or not config then return end

    local active = self.state:IsActive(trackerIndex)
    local borderKey = Border.BorderKey(config.auraType, active)
    if borderKey ~= frame.borderKey then
        frame.borderKey = borderKey
        local color = Border.COLORS[borderKey]
        frame:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    end

    if frame.glowKey == "applied" then return end
    local remaining = active and self.state:Remaining(trackerIndex, now or GetTime())
    local readout = config.trackCooldown and self.state:CooldownReadout(trackerIndex)
    applyGlow(frame, Border.GlowKey(active, remaining, readout))
end

function SpellTracker:SetupIconDragging(frame)
    self.addon.BarUtils:MakeDraggable(frame, self.db, function()
        if frame.trackerIndex then
            SpellTracker:SaveIconPosition(frame.trackerIndex)
        end
    end, false)
end

function SpellTracker:SaveIconPosition(trackerIndex)
    local frame = iconFrames[trackerIndex]
    if not frame then return end

    local x, y = frame:GetCenter()
    if not x or not y then return end

    local config = self.db.icons[trackerIndex]
    if not config then return end

    local screenWidth, screenHeight = UIParent:GetSize()
    config.posX = x - (screenWidth / 2)
    config.posY = y - (screenHeight / 2)

    frame.lastPosition = nil
end

function SpellTracker:CreateIcon(index)
    local frame = self:CreateIconFrame(index)
    self:CreateIconTexture(frame)
    self:CreateIconCooldown(frame)
    self:CreateIconText(frame)
    self:CreateIconAnimation(frame)
    self:CreateIconGlow(frame)
    self:SetupIconDragging(frame)

    frame:SetAlpha(CONSTANTS.INACTIVE_ALPHA)
    frame:Hide()
    frame.trackerIndex = nil
    frame.spellID = nil

    return frame
end

function SpellTracker:RegisterEvents()
    local eventFrame = self.container
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    pcall(eventFrame.RegisterEvent, eventFrame, "UPDATE_SHAPESHIFT_FORM")
    pcall(eventFrame.RegisterUnitEvent, eventFrame, "UNIT_SPELLCAST_SUCCEEDED", "player")

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        SpellTracker:OnEvent(event, ...)
    end)

    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        SpellTracker:OnUpdate(elapsed)
    end)
end

function SpellTracker:OnEvent(event, ...)
    if event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" or unit == "target" then
            self:ScanAuras(unit)
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        spellID = Game.Readable(spellID)
        if unit == "player" and spellID ~= nil then
            self:OnTrackedCast(spellID)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        for spellID, config in pairs(trackedSpellsByUnit.target) do
            self.state:ClearPredicted(config.trackerIndex)
        end
        self:ScanAuras("target")
    elseif event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_SHAPESHIFT_FORM" then
        self:RefreshAllTrackers()
    end
end

function SpellTracker:OnTrackedCast(spellID)
    if not InCombatLockdown() then return end

    for _, unit in ipairs({ "player", "target" }) do
        local config = trackedSpellsByUnit[unit][spellID]
        if config then
            local iconConfig = self.db.icons[config.trackerIndex]
            local manual = iconConfig and iconConfig.auraDuration
            local decision = self.state:Predict(config.trackerIndex, spellID, manual, GetTime())
            if decision then
                self:UpdateTracker(config.trackerIndex, spellID, decision)
            end
        end
    end
end

function SpellTracker:ScanAuras(unit)
    if not unit then return end

    local trackedSpells = trackedSpellsByUnit[unit]
    if not trackedSpells or not next(trackedSpells) then return end

    for spellID, config in pairs(trackedSpells) do
        local ok, observation, auraInstanceID = Game.LookupAura(unit, spellID, config.auraType)

        if not ok then
            if self.addon.db1.profile.debugmode and not self.lookupFailed[unit] then
                self.lookupFailed[unit] = true
                self.addon:Print(string.format("[SpellTracker] aura lookup failed for %s", unit))
            end
        else
            local decision = self.state:Observe(config.trackerIndex, observation, GetTime())
            if decision.action == "show" then
                self:UpdateTracker(config.trackerIndex, spellID, decision, unit, auraInstanceID)
            elseif decision.action == "hide" then
                self:HideTracker(config.trackerIndex)
            end
        end
    end
end

function SpellTracker:UpdateTracker(trackerIndex, spellID, decision, unit, auraInstanceID)
    if not trackerIndex or trackerIndex < 1 or trackerIndex > ICON_POOL_SIZE then
        return
    end

    if not spellID or spellID <= 0 then
        return
    end

    local config = self.db.icons[trackerIndex]
    if not config or not config.enabled then return end

    local frame = iconFrames[trackerIndex]
    if not frame then return end

    frame.trackerIndex = trackerIndex
    frame.spellID = spellID

    local texture = self:GetSpellTexture(spellID)
    if texture and texture ~= "" then
        frame.texture:SetTexture(texture)
    else
        frame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    if decision.expiration then
        local startTime = decision.expiration - decision.duration
        if startTime > 0 then
            frame.cooldown:SetCooldown(startTime, decision.duration)
            frame.cooldown:Show()
        else
            frame.cooldown:Clear()
        end
        frame.auraNumbers:Clear()
    else
        frame.cooldown:Clear()
        local auraDuration = decision.secret and Game.AuraDurationObject(unit, auraInstanceID)
        if auraDuration and frame.cooldown.SetCooldownFromDurationObject then
            frame.cooldown:SetCooldownFromDurationObject(auraDuration, true)
            frame.auraNumbers:SetHideCountdownNumbers(not self.db.showTimerText)
            frame.auraNumbers:SetCooldownFromDurationObject(auraDuration, true)
            frame.timerText:SetText("")
            frame.lastTimerText = ""
        else
            frame.auraNumbers:Clear()
        end
    end

    self:SetFramePosition(frame, trackerIndex)

    local shouldShow, alpha = self:DetermineVisibility(trackerIndex, true)
    if shouldShow then
        frame:SetAlpha(alpha)
        frame:Show()
    else
        frame:Hide()
    end

    if decision.isNew then
        frame.pulseAnim:Play()
        applyGlow(frame, "applied")
    end
    self:RefreshBorder(trackerIndex)

    if decision.isNew and self.addon.db1.profile.debugmode then
        self.addon:Print(string.format("[SpellTracker] Tracker %d activated: spellID %d", trackerIndex, spellID))
    end
end

function SpellTracker:DetermineVisibility(trackerIndex, isActive)
    local config = self.db.icons[trackerIndex]
    if not config then
        return false, CONSTANTS.INACTIVE_ALPHA
    end

    if isActive then
        return true, CONSTANTS.ACTIVE_ALPHA
    end

    if not self.db.locked then
        return true, CONSTANTS.INACTIVE_ALPHA
    end

    if config.showWhenInactive then
        return true, CONSTANTS.INACTIVE_ALPHA
    end

    return false, CONSTANTS.INACTIVE_ALPHA
end

function SpellTracker:HideTracker(trackerIndex)
    local frame = iconFrames[trackerIndex]
    if not frame then return end

    frame.timerText:SetText("")
    frame.lastTimerText = ""
    frame.cooldown:Clear()
    frame.auraNumbers:Clear()
    self.state:Hide(trackerIndex)
    if frame.glowKey == "applied" then
        applyGlow(frame, nil)
    end
    self:RefreshBorder(trackerIndex)

    local shouldShow, alpha = self:DetermineVisibility(trackerIndex, false)

    if shouldShow then
        frame:SetAlpha(alpha)
        frame:Show()
    else
        frame:Hide()
    end
end

function SpellTracker:OnUpdate(elapsed)
    throttleTime = throttleTime + elapsed
    if throttleTime >= UPDATE_THROTTLE then
        throttleTime = 0

        self.cachedTime = GetTime()

        for trackerIndex = 1, ICON_POOL_SIZE do
            local frame = iconFrames[trackerIndex]
            local remaining = frame and self.state:Remaining(trackerIndex, self.cachedTime)
            if remaining then
                if remaining <= 0 then
                    self:HideTracker(trackerIndex)
                else
                    if self.db.showTimerText then
                        local newText = self:FormatTime(remaining)
                        if newText ~= frame.lastTimerText then
                            frame.timerText:SetText(newText)
                            frame.lastTimerText = newText
                        end
                    else
                        if frame.lastTimerText ~= "" then
                            frame.timerText:SetText("")
                            frame.lastTimerText = ""
                        end
                    end
                    if remaining <= Border.EXPIRING_SECONDS then
                        self:RefreshBorder(trackerIndex, self.cachedTime)
                    end
                end
            end
        end
    end

    cooldownThrottle = cooldownThrottle + elapsed
    if cooldownThrottle >= COOLDOWN_UPDATE_INTERVAL then
        cooldownThrottle = 0

        for j = 1, #cooldownEnabledTrackers do
            local i = cooldownEnabledTrackers[j]
            self:UpdateCooldown(i, self.cachedTime)
        end
    end
end

function SpellTracker:FormatTime(seconds)
    if not seconds or type(seconds) ~= "number" or seconds ~= seconds then
        return "0"
    end
    if seconds < 0 then seconds = 0 end

    if seconds >= 10 then
        local sec = math.floor(seconds)
        if sec <= 60 then
            return self.timeStrings[sec] or tostring(sec)
        end
        return tostring(sec)
    else
        local wholeSecs = math.floor(seconds)
        local tenths = math.floor((seconds - wholeSecs) * 10)
        return string.format("%d.%d", wholeSecs, tenths)
    end
end

function SpellTracker:GetSpellTexture(spellID)
    if not spellID or spellID <= 0 then
        return nil
    end

    if spellTextureCache[spellID] then
        return spellTextureCache[spellID]
    end

    local _, _, texture = GetSpellInfo(spellID)

    if texture and texture ~= "" then
        spellTextureCache[spellID] = texture
        return texture
    end

    return nil
end

local READY_TEXT = "Ready!"
local READY_COLOR = { 0.2, 1, 0.2 }
local COUNTDOWN_COLOR = { 1, 0.82, 0 }

local cooldownReading = {}

local function applyCooldownText(frame, text)
    if text == frame.lastCooldownText then
        return
    end
    if text == READY_TEXT then
        frame.cooldownText:SetTextColor(READY_COLOR[1], READY_COLOR[2], READY_COLOR[3], 1)
    elseif frame.lastCooldownText == READY_TEXT then
        frame.cooldownText:SetTextColor(COUNTDOWN_COLOR[1], COUNTDOWN_COLOR[2], COUNTDOWN_COLOR[3], 1)
    end
    frame.cooldownText:SetText(text)
    frame.lastCooldownText = text
end

local function clearCooldownNumbers(numbers)
    if numbers.secretShown then
        numbers:Clear()
        numbers.secretShown = nil
    end
    if numbers.sentStart then
        numbers:Clear()
        numbers.sentStart = nil
        numbers.sentDuration = nil
    end
end

function SpellTracker:DrawCooldownNumbers(numbers, spellID, readout)
    if readout.numbers == "secret" then
        numbers.sentStart = nil
        numbers.sentDuration = nil
        numbers:SetHideCountdownNumbers(not self.db.showCooldownText)
        local durationObject = Game.SpellCooldownDurationObject(spellID)
        if durationObject and numbers.SetCooldownFromDurationObject then
            numbers:SetCooldownFromDurationObject(durationObject, true)
            numbers.secretShown = true
        elseif numbers.secretShown then
            numbers:Clear()
            numbers.secretShown = nil
        end
    elseif readout.numbers == "countdown" then
        if numbers.secretShown then
            numbers:Clear()
            numbers.secretShown = nil
        end
        numbers:SetHideCountdownNumbers(not self.db.showCooldownText)
        if numbers.sentStart ~= readout.start or numbers.sentDuration ~= readout.duration then
            numbers:SetCooldown(readout.start, readout.duration)
            numbers.sentStart = readout.start
            numbers.sentDuration = readout.duration
        end
    else
        clearCooldownNumbers(numbers)
    end
end

function SpellTracker:UpdateCooldown(trackerIndex, now)
    local config = self.db.icons[trackerIndex]
    if not config or not config.enabled or not config.trackCooldown then
        return
    end

    local spellID = config.spellID
    if not spellID or spellID <= 0 then
        return
    end

    local frame = iconFrames[trackerIndex]
    if not frame or not frame.cooldownText then
        return
    end

    local reading = Game.ReadSpellCooldown(spellID, cooldownReading)

    local readout = self.state:ReadCooldown(trackerIndex, reading, now, self.db.showReadyText)

    if frame.cooldownNumbers then
        self:DrawCooldownNumbers(frame.cooldownNumbers, spellID, readout)
    end
    applyCooldownText(frame, readout.ready and READY_TEXT or "")
    self:RefreshBorder(trackerIndex, now)
end

function SpellTracker:RefreshAllTrackers()
    for i = 1, #self.db.icons do
        local config = self.db.icons[i]
        if config.enabled then
            self:ScanAuras(config.unit)
        else
            self:HideTracker(i)
        end
    end
end

function SpellTracker:SetFramePosition(frame, trackerIndex)
    if not frame or not trackerIndex then return end

    local config = self.db.icons[trackerIndex]
    if not config then return end

    local relativeX = config.posX or ((trackerIndex - 1) * (ICON_SIZE + ICON_SPACING) + CONSTANTS.DEFAULT_POS_X_OFFSET)
    local relativeY = config.posY or CONSTANTS.DEFAULT_POS_Y
    local size = config.size or ICON_SIZE
    local cooldownTextSize = config.cooldownTextSize or CONSTANTS.DEFAULT_COOLDOWN_TEXT_SIZE

    local lastPos = frame.lastPosition
    if lastPos and lastPos.x == relativeX and lastPos.y == relativeY and lastPos.size == size and lastPos.textSize == cooldownTextSize then
        return
    end

    local screenWidth, screenHeight = UIParent:GetSize()
    local x = relativeX + (screenWidth / 2)
    local y = relativeY + (screenHeight / 2)

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    frame:SetSize(size, size)
    frame.glow:SetSize(size * 1.75, size * 1.75)

    if frame.cooldownText then
        frame.cooldownText:SetFont("Fonts\\FRIZQT__.TTF", cooldownTextSize, "OUTLINE")
    end
    self:StyleCooldownNumbers(frame, cooldownTextSize)

    frame.lastPosition = {
        x = relativeX,
        y = relativeY,
        size = size,
        textSize = cooldownTextSize
    }
end

function SpellTracker:MigrateIconSettings()
    for i = 1, #self.db.icons do
        if self.db.icons[i] then
            Settings.Backfill(self.db.icons[i])
        end
    end
end

function SpellTracker:UpdateContainerVisibility()
    local anyEnabled = false
    for i = 1, #self.db.icons do
        if self.db.icons[i].enabled then
            anyEnabled = true
            break
        end
    end

    if anyEnabled then
        self.container:Show()
    else
        self.container:Hide()
    end
end

function SpellTracker:RestoreIconStates()
    for i = 1, #self.db.icons do
        local config = self.db.icons[i]
        local frame = iconFrames[i]

        if frame then
            if config.enabled then
                frame:EnableMouse(not self.db.locked)
                frame.trackerIndex = i
                frame.spellID = config.spellID

                local texture = self:GetSpellTexture(config.spellID)
                if texture and texture ~= "" then
                    frame.texture:SetTexture(texture)
                else
                    frame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end

                self:SetFramePosition(frame, i)
                self:RefreshBorder(i)

                local shouldShow, alpha = self:DetermineVisibility(i, self.state:IsActive(i))

                if shouldShow then
                    frame:SetAlpha(alpha)
                    frame:Show()
                else
                    frame:Hide()
                end
            else
                frame:Hide()
            end
        end
    end
end

function SpellTracker:RebuildTrackingLookups()
    trackedSpellsByUnit = { player = {}, target = {} }
    for k in pairs(cooldownEnabledTrackers) do
        cooldownEnabledTrackers[k] = nil
    end

    for i = 1, #self.db.icons do
        local config = self.db.icons[i]
        if config.enabled then
            if not trackedSpellsByUnit[config.unit] then
                trackedSpellsByUnit[config.unit] = {}
            end
            trackedSpellsByUnit[config.unit][config.spellID] = {
                trackerIndex = i,
                auraType = config.auraType,
            }
            if config.trackCooldown then
                cooldownEnabledTrackers[#cooldownEnabledTrackers + 1] = i
            end
        end
    end
end

function SpellTracker:LoadSettings()
    if not self.db then return end

    self.db.knownDurations = self.db.knownDurations or {}
    self.state:SetKnownDurations(self.db.knownDurations)

    self:MigrateIconSettings()
    self:UpdateContainerVisibility()
    self:RestoreIconStates()
    self:RebuildTrackingLookups()
    self:RefreshAllTrackers()
end

function SpellTracker:GetSettings()
    return self.db
end

function SpellTracker:SetSetting(key, value)
    if not Settings.IsGlobalKey(key) then
        error("SpellTracker:SetSetting - unknown setting key '"..tostring(key).."'", 2)
    end
    if key == "locked" then
        self:SetLocked(value)
    else
        self.db[key] = value
    end
end

function SpellTracker:GetIconSetting(index, key)
    local icon = self.db and self.db.icons[index]
    local value = icon and icon[key]
    if value == nil then
        return Settings.IconDefault(key)
    end
    return value
end

function SpellTracker:SetIconSetting(index, key, value)
    local icon = self.db and self.db.icons[index]
    if not icon then return end
    if Settings.SetIcon(icon, key, value) then
        self:LoadSettings()
    end
end

function SpellTracker:SetLocked(locked)
    if not self.db then return end
    self.db.locked = locked

    for i = 1, ICON_POOL_SIZE do
        local frame = iconFrames[i]
        if frame then
            frame:EnableMouse(not locked)
        end
    end
end

function SpellTracker:OnProfileChanged()
    self.db = self.addon.db1.profile.spellTracker
    self:LoadSettings()
end

function SpellTracker:AddTrackedSpell(spellID, unit, auraType)
    if not self.db then return false end
    local newIndex = #self.db.icons + 1
    if newIndex > ICON_POOL_SIZE then
        self.addon:Print("Cannot add more than " .. ICON_POOL_SIZE .. " tracked spells.")
        return false
    end

    local defaultX = (newIndex - 1) * (ICON_SIZE + ICON_SPACING) + CONSTANTS.DEFAULT_POS_X_OFFSET
    local defaultY = CONSTANTS.DEFAULT_POS_Y

    self.db.icons[newIndex] = Settings.NewIcon({
        spellID = spellID,
        unit = unit,
        auraType = auraType,
        posX = defaultX,
        posY = defaultY,
    })

    if self.addon.db1.profile.debugmode then
        self.addon:Print(string.format("[SpellTracker] Added tracked spell %d (%s, %s)", spellID, unit, auraType))
    end

    self:LoadSettings()
    return true
end

function SpellTracker:RemoveTrackedSpell(index)
    if not self.db then return end
    if index < 1 or index > #self.db.icons then return end

    if self.addon.db1.profile.debugmode then
        self.addon:Print(string.format("[SpellTracker] Removed tracked spell at index %d", index))
    end

    local count = #self.db.icons
    table.remove(self.db.icons, index)
    self.state:Remove(index, count)
    for i = index, count do
        self:ResetFrameDisplay(iconFrames[i])
    end
    self:LoadSettings()
    self:ReapplyPredictedAuras(index)
end

function SpellTracker:ResetFrameDisplay(frame)
    if not frame then return end
    frame.timerText:SetText("")
    frame.lastTimerText = ""
    frame.cooldown:Clear()
    frame.auraNumbers:Clear()
    frame.cooldownNumbers:Clear()
    frame.cooldownNumbers.sentStart = nil
    frame.cooldownNumbers.sentDuration = nil
    frame.cooldownNumbers.secretShown = nil
    frame.cooldownText:SetText("")
    frame.cooldownText:SetTextColor(1, 0.82, 0, 1)
    frame.lastCooldownText = ""
    applyGlow(frame, nil)
    frame.lastPosition = nil
    frame.trackerIndex = nil
    frame.spellID = nil
    frame:Hide()
end

function SpellTracker:ReapplyPredictedAuras(fromIndex)
    local now = GetTime()
    for i = fromIndex, #self.db.icons do
        local config = self.db.icons[i]
        local decision = config and config.enabled and self.state:Resume(i, now)
        if decision then
            self:UpdateTracker(i, config.spellID, decision)
        end
    end
end

SpellTracker.MAX_ICONS = ICON_POOL_SIZE

SoundAlerter.SpellTracker = SpellTracker
