local SpellTracker = {}
local GetSpellInfo = SA_COMPAT.GetSpellInfo
local GetSpellCooldown = SA_COMPAT.GetSpellCooldown
local UnitAura = SA_COMPAT.UnitAura

local ICON_SIZE = 48
local ICON_SPACING = 4
local ICON_POOL_SIZE = 20
local UPDATE_THROTTLE = 0.033

local CONSTANTS = {
    INACTIVE_ALPHA = 0.3,
    ACTIVE_ALPHA = 1.0,
    MAX_AURA_SCAN = 40,
    GCD_THRESHOLD = 1.5,
    ICON_INSET = 4,
    BACKDROP_EDGE_SIZE = 16,
    DEFAULT_POS_X_OFFSET = -200,
    DEFAULT_POS_Y = -100,
    DEFAULT_COOLDOWN_TEXT_SIZE = 14,
}

local iconFrames = {}
local activeTrackers = {}
local throttleTime = 0
local spellTextureCache = {}
local trackedSpellsByUnit = { player = {}, target = {} }

local cooldownState = {}
local cooldownThrottle = 0
local COOLDOWN_UPDATE_INTERVAL = 0.1

local scratchFoundSpells = {}
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

    self.lastTimerText = {}
    self.lastCooldownText = {}
    self.cachedTime = 0
    self.lastIconPositions = {}

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

    self.addon.BarUtils:CreateBackdrop(frame, 0.5, 0.5, 0.5, 1,
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
end

function SpellTracker:CreateIconText(frame)
    local timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    timerText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
    timerText:SetTextColor(1, 1, 1, 1)
    timerText:SetFont("Fonts\\FRIZQT__.TTF", CONSTANTS.DEFAULT_COOLDOWN_TEXT_SIZE, "OUTLINE")
    timerText:SetText("")
    frame.timerText = timerText

    local cooldownText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cooldownText:SetPoint("CENTER", frame, "CENTER", 0, 8)
    cooldownText:SetTextColor(1, 1, 1, 1)
    cooldownText:SetFont("Fonts\\FRIZQT__.TTF", CONSTANTS.DEFAULT_COOLDOWN_TEXT_SIZE, "OUTLINE, THICKOUTLINE")
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

    self.lastIconPositions[trackerIndex] = nil
end

function SpellTracker:CreateIcon(index)
    local frame = self:CreateIconFrame(index)
    self:CreateIconTexture(frame)
    self:CreateIconCooldown(frame)
    self:CreateIconText(frame)
    self:CreateIconAnimation(frame)
    self:SetupIconDragging(frame)

    frame:SetAlpha(CONSTANTS.INACTIVE_ALPHA)
    frame:Hide()
    frame.trackerIndex = nil
    frame.spellID = nil
    frame.expirationTime = nil

    return frame
end

function SpellTracker:RegisterEvents()
    local eventFrame = self.container
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

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
    elseif event == "PLAYER_TARGET_CHANGED" then
        self:ScanAuras("target")
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:RefreshAllTrackers()
    end
end

function SpellTracker:ScanAuras(unit)
    if not unit then return end

    local trackedSpells = trackedSpellsByUnit[unit]
    if not trackedSpells or not next(trackedSpells) then return end

    for k in pairs(scratchFoundSpells) do
        scratchFoundSpells[k] = nil
    end

    for i = 1, CONSTANTS.MAX_AURA_SCAN do
        local name, _, _, _, _, duration, expirationTime, _, _, _, foundSpellID = UnitAura(unit, i, "HELPFUL")
        if not name then break end

        local config = trackedSpells[foundSpellID]
        if config and config.auraType == "HELPFUL" then
            scratchFoundSpells[foundSpellID] = true
            self:UpdateTracker(config.trackerIndex, foundSpellID, expirationTime, duration)
        end
    end

    for i = 1, CONSTANTS.MAX_AURA_SCAN do
        local name, _, _, _, _, duration, expirationTime, _, _, _, foundSpellID = UnitAura(unit, i, "HARMFUL")
        if not name then break end

        local config = trackedSpells[foundSpellID]
        if config and config.auraType == "HARMFUL" then
            scratchFoundSpells[foundSpellID] = true
            self:UpdateTracker(config.trackerIndex, foundSpellID, expirationTime, duration)
        end
    end

    for spellID, config in pairs(trackedSpells) do
        if not scratchFoundSpells[spellID] then
            self:HideTracker(config.trackerIndex)
        end
    end
end

function SpellTracker:UpdateTracker(trackerIndex, spellID, expirationTime, duration)
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

    local isNewApplication = not activeTrackers[trackerIndex]

    frame.trackerIndex = trackerIndex
    frame.spellID = spellID
    frame.expirationTime = expirationTime

    local texture = self:GetSpellTexture(spellID)
    if texture and texture ~= "" then
        frame.texture:SetTexture(texture)
    else
        frame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    if duration and expirationTime and not (issecretvalue(duration) or issecretvalue(expirationTime)) and duration > 0 and expirationTime > 0 then
        local startTime = expirationTime - duration
        if startTime > 0 then
            frame.cooldown:SetCooldown(startTime, duration)
            frame.cooldown:Show()
        else
            frame.cooldown:Clear()
        end
    else
        frame.cooldown:Clear()
    end

    self:SetFramePosition(frame, trackerIndex)

    local shouldShow, alpha = self:DetermineVisibility(trackerIndex, true)
    if shouldShow then
        frame:SetAlpha(alpha)
        frame:Show()
    else
        frame:Hide()
    end

    if isNewApplication and frame.pulseAnim then
        frame.pulseAnim:Play()
    end

    if isNewApplication and self.addon.db1.profile.debugmode then
        self.addon:Print(string.format("[SpellTracker] Tracker %d activated: spellID %d", trackerIndex, spellID))
    end

    activeTrackers[trackerIndex] = true
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
    self.lastTimerText[trackerIndex] = ""
    frame.cooldown:Clear()

    local shouldShow, alpha = self:DetermineVisibility(trackerIndex, false)

    if shouldShow then
        frame:SetAlpha(alpha)
        frame:Show()
    else
        frame:Hide()
    end

    frame.expirationTime = nil
    activeTrackers[trackerIndex] = nil
end

function SpellTracker:OnUpdate(elapsed)
    throttleTime = throttleTime + elapsed
    if throttleTime >= UPDATE_THROTTLE then
        throttleTime = 0

        self.cachedTime = GetTime()

        for trackerIndex in pairs(activeTrackers) do
            local frame = iconFrames[trackerIndex]
            if frame and frame.expirationTime and frame.expirationTime > 0 then
                local remaining = frame.expirationTime - self.cachedTime

                if remaining <= 0 then
                    self:HideTracker(trackerIndex)
                else
                    if self.db.showTimerText then
                        local newText = self:FormatTime(remaining)
                        if newText ~= self.lastTimerText[trackerIndex] then
                            frame.timerText:SetText(newText)
                            self.lastTimerText[trackerIndex] = newText
                        end
                    else
                        if self.lastTimerText[trackerIndex] ~= "" then
                            frame.timerText:SetText("")
                            self.lastTimerText[trackerIndex] = ""
                        end
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
            self:UpdateCooldownTracking(i)
            self:UpdateCooldownText(i, self.cachedTime)
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

function SpellTracker:UpdateCooldownTracking(trackerIndex)
    local config = self.db.icons[trackerIndex]
    if not config or not config.enabled or not config.trackCooldown then
        return
    end

    local spellID = config.spellID
    if not spellID or spellID <= 0 then
        return
    end

    local start, duration, _, _, isActive = GetSpellCooldown(spellID)

    if start == nil or duration == nil then
        return
    end

    if issecretvalue(start) or issecretvalue(duration) then
        cooldownState[trackerIndex] = {
            spellID = spellID,
            startTime = nil,
            duration = nil,
            isOnCooldown = isActive,
        }
        return
    end

    local isOnCooldown = (start > 0 and duration > CONSTANTS.GCD_THRESHOLD)

    cooldownState[trackerIndex] = {
        spellID = spellID,
        startTime = start,
        duration = duration,
        isOnCooldown = isOnCooldown,
    }
end

function SpellTracker:UpdateCooldownText(trackerIndex, now)
    local frame = iconFrames[trackerIndex]
    if not frame or not frame.cooldownText then
        return
    end

    local state = cooldownState[trackerIndex]
    if not state then
        if self.lastCooldownText[trackerIndex] ~= "" then
            frame.cooldownText:SetText("")
            self.lastCooldownText[trackerIndex] = ""
        end
        return
    end

    if not self.db.showCooldownText then
        if self.lastCooldownText[trackerIndex] ~= "" then
            frame.cooldownText:SetText("")
            self.lastCooldownText[trackerIndex] = ""
        end
        return
    end

    if not state.isOnCooldown or state.startTime == nil or state.duration == nil then
        if self.lastCooldownText[trackerIndex] ~= "" then
            frame.cooldownText:SetText("")
            self.lastCooldownText[trackerIndex] = ""
        end
        return
    end

    local elapsed = now - state.startTime
    local remaining = state.duration - elapsed

    if remaining <= 0 then
        if self.lastCooldownText[trackerIndex] ~= "" then
            frame.cooldownText:SetText("")
            self.lastCooldownText[trackerIndex] = ""
        end
    else
        local newText = self:FormatTime(remaining)
        if newText ~= self.lastCooldownText[trackerIndex] then
            frame.cooldownText:SetText(newText)
            self.lastCooldownText[trackerIndex] = newText
        end
    end
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

    local lastPos = self.lastIconPositions[trackerIndex]
    if lastPos and lastPos.x == relativeX and lastPos.y == relativeY and lastPos.size == size and lastPos.textSize == cooldownTextSize then
        return
    end

    local screenWidth, screenHeight = UIParent:GetSize()
    local x = relativeX + (screenWidth / 2)
    local y = relativeY + (screenHeight / 2)

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    frame:SetSize(size, size)

    if frame.cooldownText then
        frame.cooldownText:SetFont("Fonts\\FRIZQT__.TTF", cooldownTextSize, "OUTLINE, THICKOUTLINE")
    end

    self.lastIconPositions[trackerIndex] = {
        x = relativeX,
        y = relativeY,
        size = size,
        textSize = cooldownTextSize
    }
end

function SpellTracker:MigrateIconSettings()
    for i = 1, #self.db.icons do
        if self.db.icons[i] and not self.db.icons[i].cooldownTextSize then
            self.db.icons[i].cooldownTextSize = CONSTANTS.DEFAULT_COOLDOWN_TEXT_SIZE
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

                local shouldShow, alpha = self:DetermineVisibility(i, activeTrackers[i] ~= nil)

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

    self:MigrateIconSettings()
    self:UpdateContainerVisibility()
    self:RestoreIconStates()
    self:RebuildTrackingLookups()
    self:RefreshAllTrackers()
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

    self.db.icons[newIndex] = {
        enabled = true,
        spellID = spellID,
        unit = unit,
        auraType = auraType,
        size = ICON_SIZE,
        posX = defaultX,
        posY = defaultY,
        showWhenInactive = false,
        trackCooldown = false,
        cooldownTextSize = CONSTANTS.DEFAULT_COOLDOWN_TEXT_SIZE,
    }

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

    self:HideTracker(index)
    table.remove(self.db.icons, index)
    self:LoadSettings()
end

SoundAlerter.SpellTracker = SpellTracker
