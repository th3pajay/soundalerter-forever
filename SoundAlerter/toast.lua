local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
if not SoundAlerter then
    return
end

local Toast = {}
SA_Toast = Toast

local FADE_IN_DURATION = 0.2
local FADE_OUT_DURATION = 0.5
local SLIDE_DURATION = 0.2
local DISMISS_DELAY = 0.15
local MAX_SEGMENTS = 30

Toast.FADE_IN_DURATION = FADE_IN_DURATION

local Engine = {}
Engine.__index = Engine

function Toast.RainbowColor(time)
    local frequency = math.pi * 2 / 6.0
    local r = math.sin(frequency * time + 0) * 0.5 + 0.5
    local g = math.sin(frequency * time + 2.0944) * 0.5 + 0.5
    local b = math.sin(frequency * time + 4.1888) * 0.5 + 0.5
    return r, g, b
end

local function IsLocked(toast)
    return toast.isSecure and InCombatLockdown()
end

local function BeginPause(toast)
    if not toast.inUse or toast.pendingDismiss then
        return
    end
    local now = GetTime()
    local elapsed = now - toast.startTime - toast.pauseState.totalTime
    if elapsed >= FADE_IN_DURATION and elapsed < (FADE_IN_DURATION + toast.displayDuration) then
        toast.pauseState.active = true
        toast.pauseState.startTime = now
    end
end

local function EndPause(toast)
    local pause = toast.pauseState
    if pause.active then
        pause.active = false
        pause.totalTime = pause.totalTime + (GetTime() - pause.startTime)
        pause.startTime = 0
    end
end

local function SlideFinished(group)
    local toast = group.toast
    toast:SetPoint("TOP", UIParent, "TOP", toast.slideBaseX, toast.slideToY)
end

local function EngineSlide(toast, baseX, targetY)
    local group = toast.slideGroup
    if not group then
        group = toast:CreateAnimationGroup()
        group.toast = toast
        local move = group:CreateAnimation("Translation")
        move:SetDuration(SLIDE_DURATION)
        move:SetSmoothing("OUT")
        group.move = move
        group:SetScript("OnFinished", SlideFinished)
        toast.slideGroup = group
    end
    local fromY = toast.currentY
    if group:IsPlaying() then
        fromY = toast.slideFromY + (toast.slideToY - toast.slideFromY) * group.move:GetSmoothProgress()
        group:Stop()
    end
    toast:SetPoint("TOP", UIParent, "TOP", baseX, fromY)
    toast.slideFromY, toast.slideToY, toast.slideBaseX = fromY, targetY, baseX
    toast.currentY = targetY
    group.move:SetOffset(0, targetY - fromY)
    group:Play()
end

local function ByCreationTime(a, b)
    return a.creationTime < b.creationTime
end

local function UpdateCountdownSegments(toast, displayElapsed)
    local data = toast.cachedSegmentData
    if not toast.countdownBar or not data then
        return
    end

    local segments = toast.countdownBar.segments
    local secondsElapsed = math.floor(displayElapsed)
    local currentSegmentIndex = secondsElapsed + 1
    if currentSegmentIndex <= data.duration and segments[currentSegmentIndex] then
        segments[currentSegmentIndex]:SetAlpha(1 - (displayElapsed % 1))
    end

    for i = (data.lastHiddenSegment or 0) + 1, secondsElapsed do
        if segments[i] then
            segments[i]:SetAlpha(0)
        end
    end
    data.lastHiddenSegment = secondsElapsed
end

local function ToastOnUpdate(toast)
    if not toast.inUse then
        toast:SetScript("OnUpdate", nil)
        return
    end

    local engine = toast.engine
    local config = engine.config
    local now = GetTime()
    local locked = IsLocked(toast)

    if toast.isSliding then
        local t = (now - toast.slideStartTime) / SLIDE_DURATION
        if t >= 1 then
            toast.currentY = toast.slideToY
            toast.isSliding = false
        else
            local eased = 1 - (1 - t) * (1 - t)
            toast.currentY = toast.slideFromY + (toast.slideToY - toast.slideFromY) * eased
        end
        if not locked then
            toast:SetPoint("TOP", UIParent, "TOP", toast.slideBaseX, toast.currentY)
        end
    end

    if toast.pauseState.active then
        return
    end

    local elapsed = now - toast.startTime - toast.pauseState.totalTime
    local secureButton = config.mirrorSecureAlpha and toast.secureButton

    config.tickBorder(toast, now)

    if elapsed < FADE_IN_DURATION then
        local linear = elapsed / FADE_IN_DURATION
        local progress = 1 - (1 - linear) * (1 - linear)
        toast:SetAlpha(progress)
        if not locked then
            toast:SetScale(1.15 - (0.15 * progress))
        end
        if secureButton then
            secureButton:SetAlpha(progress)
        end
    elseif elapsed < (FADE_IN_DURATION + toast.displayDuration) then
        if not toast.displayApplied then
            toast:SetAlpha(1)
            if secureButton then
                secureButton:SetAlpha(1)
            end
            if not locked then
                toast:SetScale(1.0)
                toast.displayApplied = true
            end
        end
        UpdateCountdownSegments(toast, elapsed - FADE_IN_DURATION)
    elseif elapsed < (FADE_IN_DURATION + toast.displayDuration + FADE_OUT_DURATION) then
        local linear = (elapsed - FADE_IN_DURATION - toast.displayDuration) / FADE_OUT_DURATION
        local fadeProgress = linear * linear
        toast:SetAlpha(1 - fadeProgress)
        if secureButton then
            secureButton:SetAlpha(1 - fadeProgress)
        end

        if not toast.segmentsHidden and toast.countdownBar and toast.cachedSegmentData then
            for i = 1, toast.cachedSegmentData.duration do
                local segment = toast.countdownBar.segments[i]
                if segment then
                    segment:SetAlpha(0)
                end
            end
            toast.segmentsHidden = true
        end
    else
        toast:SetScript("OnUpdate", nil)
        engine:Release(toast)
    end
end

function Toast.New(config)
    return setmetatable({
        config = config,
        securePool = {},
        insecurePool = {},
        active = {},
        swapBuffer = {},
        swapMetrics = {count = 0, totalTime = 0, maxTime = 0, histogram = {}},
        deferredHides = {},
        deferredButtons = {},
        secureCreationPending = false,
        initialized = false,
    }, Engine)
end

function Engine:BuildFrame(index, isSecure)
    local config = self.config
    local engine = self
    local frameName = config.prefix..(isSecure and "SecureToast" or "InsecureToast")..index
    local toast = CreateFrame("Button", frameName, UIParent, "BackdropTemplate")
    toast:SetSize(config.width, config.height)
    toast:SetFrameStrata("HIGH")
    toast:SetFrameLevel(100)
    toast:Hide()
    toast:SetAlpha(0)

    toast:SetBackdrop({
        bgFile = config.backdropFile(),
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

    if config.buildContent then
        config.buildContent(toast)
    end

    toast.countdownBar = CreateFrame("Frame", nil, toast)
    toast.countdownBar:SetHeight(3)
    toast.countdownBar:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 4, 4)
    toast.countdownBar:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -4, 4)
    toast.countdownBar:SetFrameLevel(toast:GetFrameLevel() + 2)
    toast.countdownBar.segments = {}

    for i = 1, MAX_SEGMENTS do
        local segment = toast.countdownBar:CreateTexture(nil, "OVERLAY")
        segment:SetTexture("Interface\\Buttons\\WHITE8X8")
        segment:SetHeight(3)
        segment:SetVertexColor(0.8, 0.2, 0.2, 1)
        segment:Hide()
        toast.countdownBar.segments[i] = segment
    end

    toast.engine = self
    toast.startTime = 0
    toast.displayDuration = 0
    toast.elapsedTime = 0
    toast.poolIndex = index
    toast.inUse = false
    toast.creationTime = 0
    toast.pauseState = {active = false, startTime = 0, totalTime = 0}
    toast.cachedSegmentData = nil
    toast.userData = {}
    toast.isSecure = isSecure

    if isSecure then
        local secureButton = CreateFrame("Button", frameName.."SecureAction", UIParent, "SecureActionButtonTemplate")
        secureButton:SetAllPoints(toast)
        secureButton:SetFrameStrata("HIGH")
        secureButton:SetFrameLevel(101)
        secureButton:Hide()
        secureButton:RegisterForClicks("LeftButtonDown")
        secureButton:SetAttribute("type1", "macro")

        if config.onSecureCreated then
            config.onSecureCreated(secureButton, toast)
        end

        secureButton:SetScript("OnEnter", function() BeginPause(toast) end)
        secureButton:SetScript("OnLeave", function() EndPause(toast) end)

        toast.secureButton = secureButton
    end

    toast:EnableMouse(true)
    toast:RegisterForClicks("LeftButtonDown")
    toast:SetScript("OnClick", function(frame)
        if frame.isSecure or not config.canDismissOnClick() then
            return
        end

        if not (frame.userData and frame.userData.unitName) then
            return
        end

        frame.pendingDismiss = true
        frame.dismissTime = GetTime() + DISMISS_DELAY

        frame:SetScript("OnUpdate", function(dismissing)
            if dismissing.pendingDismiss and GetTime() >= dismissing.dismissTime then
                dismissing.pendingDismiss = false
                dismissing:SetScript("OnUpdate", nil)
                engine:Release(dismissing)
            end
        end)
    end)

    toast:SetScript("OnEnter", BeginPause)
    toast:SetScript("OnLeave", EndPause)

    return toast
end

function Engine:BuildFrameChecked(index, isSecure)
    local ok, frame = pcall(self.BuildFrame, self, index, isSecure)
    if not ok then
        error(self.config.label..": "..(isSecure and "secure" or "insecure").." frame "..index.." failed to create — "..tostring(frame))
    end
    return frame
end

function Engine:CreateSecurePool()
    for i = 1, self.config.maxToasts do
        self.securePool[i] = self:BuildFrameChecked(i, true)
    end
    self.secureCreationPending = false
    return true
end

function Engine:Initialize()
    if self.initialized then
        return
    end

    local config = self.config
    for i = 1, config.maxToasts do
        self.insecurePool[i] = self:BuildFrameChecked(i, false)
    end

    if InCombatLockdown() then
        self.secureCreationPending = true
    else
        self:CreateSecurePool()
    end

    self.poolState = {
        securePool = self.securePool,
        insecurePool = self.insecurePool,
        activeList = self.active,
        poolSize = config.maxToasts,
        swapInProgress = false,
        swapBuffer = self.swapBuffer,
        metrics = self.swapMetrics,
        onLayoutChanged = function() self:UpdateLayout() end,
    }
    self.releaseFn = function(toast) self:Release(toast) end
    self.copyFn = function(old, new) return self:CopyToast(old, new) end

    self.initialized = true
end

function Engine:Acquire(inCombat)
    local state = self.poolState
    state.inCombat = inCombat or InCombatLockdown()

    local pool = state.inCombat and state.insecurePool or state.securePool
    for i = 1, state.poolSize do
        local toast = pool[i]
        if toast and not toast.inUse then
            toast.inUse = true
            return toast
        end
    end

    local locked = InCombatLockdown()
    for i = 1, #state.activeList do
        local oldest = state.activeList[i]
        if oldest and not (locked and oldest.isSecure) then
            self.releaseFn(oldest)
            oldest.inUse = true
            if self.config.onExhausted then
                self.config.onExhausted(oldest)
            end
            return oldest
        end
    end

    return nil
end

function Engine:HideToast(toast)
    if IsLocked(toast) then
        toast:SetAlpha(0)
        self.deferredHides[toast] = true
    else
        toast:Hide()
    end
end

function Engine:FlushDeferred()
    local manageMouse = self.config.manageMouse
    for toast in pairs(self.deferredHides) do
        self.deferredHides[toast] = nil
        if not toast.inUse then
            toast:Hide()
            if manageMouse then
                toast:EnableMouse(false)
            end
        end
    end
    for button in pairs(self.deferredButtons) do
        self.deferredButtons[button] = nil
        button:Hide()
        button:SetAlpha(1)
    end
end

function Engine:Release(toast)
    if not toast then
        return
    end

    local config = self.config

    toast:SetScript("OnUpdate", nil)
    self:HideToast(toast)
    toast:SetAlpha(0)
    if not IsLocked(toast) then
        toast:SetScale(1.0)
        if config.manageMouse then
            toast:EnableMouse(false)
        end
    end

    toast.inUse = false
    toast.creationTime = 0
    toast.startTime = 0
    toast.displayDuration = 0
    toast.elapsedTime = 0
    toast.pendingDismiss = false
    toast.dismissTime = nil
    toast.segmentsHidden = false
    toast.displayApplied = false
    toast.cachedSegmentData = nil

    toast.pauseState.active = false
    toast.pauseState.startTime = 0
    toast.pauseState.totalTime = 0

    if toast.slideGroup then toast.slideGroup:Stop() end
    toast.currentY = nil
    toast.isSliding = false
    toast.slideFromY = nil
    toast.slideToY = nil
    toast.slideStartTime = nil
    toast.slideBaseX = nil

    local secureButton = toast.secureButton
    if secureButton then
        if InCombatLockdown() then
            secureButton:SetAlpha(0)
            self.deferredButtons[secureButton] = true
        else
            secureButton:Hide()
            if config.manageMouse then
                secureButton:EnableMouse(false)
            end
            for _, attribute in ipairs(config.secureAttributes) do
                secureButton:SetAttribute(attribute, nil)
            end
        end
    end

    for i = 1, #toast.countdownBar.segments do
        toast.countdownBar.segments[i]:Hide()
        toast.countdownBar.segments[i]:SetAlpha(1)
    end

    toast.titleText:SetText("")
    toast.detailText:SetText("")
    toast.icon:SetTexture(nil)
    toast:SetBackdropColor(0, 0, 0, 0.85)
    toast:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)

    if config.onRelease then
        config.onRelease(toast)
    end

    for _, field in ipairs(config.userFields) do
        toast.userData[field] = nil
    end

    local active = self.active
    for i = #active, 1, -1 do
        if active[i] == toast then
            table.remove(active, i)
            break
        end
    end

    self:UpdateLayout()
end

function Engine:ReleaseAll()
    local active = self.active
    for i = #active, 1, -1 do
        self:Release(active[i])
    end
end

function Engine:UpdateLayout()
    local config = self.config
    local baseX, baseY = config.position()
    local active = self.active

    table.sort(active, ByCreationTime)

    if config.slide then
        local step = config.height + config.spacing
        for i, toast in ipairs(active) do
            local targetY = baseY - (i - 1) * step

            if toast.currentY == nil then
                toast.currentY = targetY
                toast:ClearAllPoints()
                toast:SetPoint("TOP", UIParent, "TOP", baseX, targetY)
            elseif toast.currentY ~= targetY and not toast.isSecure then
                EngineSlide(toast, baseX, targetY)
            elseif toast.currentY ~= targetY then
                toast.slideFromY = toast.currentY
                toast.slideToY = targetY
                toast.slideStartTime = GetTime()
                toast.slideBaseX = baseX
                toast.isSliding = true
            end
        end
        return
    end

    for i, toast in ipairs(active) do
        if not IsLocked(toast) then
            toast:ClearAllPoints()
            if i == 1 then
                toast:SetPoint("TOP", UIParent, "TOP", baseX, baseY)
            else
                toast:SetPoint("TOP", active[i - 1], "BOTTOM", 0, -config.spacing)
            end
        end
    end
end

function Engine:Start(toast, displayDuration, segmentColor)
    local config = self.config

    local now = GetTime()
    toast.creationTime = now
    table.insert(self.active, toast)
    self:UpdateLayout()

    toast.startTime = now
    toast.displayDuration = displayDuration
    toast.elapsedTime = 0

    local duration = math.ceil(displayDuration)
    local segmentWidth = config.segmentWidth(toast, duration)
    local segments = toast.countdownBar.segments

    toast.cachedSegmentData = {
        duration = duration,
        segmentWidth = segmentWidth,
        lastHiddenSegment = 0
    }

    for i = 1, duration do
        local segment = segments[i]
        if segment then
            segment:ClearAllPoints()
            segment:SetPoint("LEFT", toast.countdownBar, "LEFT", (i - 1) * segmentWidth, 0)
            segment:SetWidth(segmentWidth - 2)
            if segmentColor then
                segment:SetVertexColor(segmentColor[1], segmentColor[2], segmentColor[3], segmentColor[4])
            end
            segment:SetAlpha(1)
            segment:Show()
        end
    end

    for i = duration + 1, #segments do
        segments[i]:Hide()
    end

    toast.pauseState.active = false
    toast.pauseState.startTime = 0
    toast.pauseState.totalTime = 0
    toast.segmentsHidden = false
    toast.displayApplied = false

    local locked = IsLocked(toast)
    toast:SetAlpha(0)
    if not locked then
        toast:SetScale(1.0)
    end
    toast:Show()

    if config.manageMouse then
        if not locked then
            toast:EnableMouse(true)
        end
        if toast.secureButton and not InCombatLockdown() then
            toast.secureButton:EnableMouse(true)
        end
    end

    toast:SetScript("OnUpdate", ToastOnUpdate)
end

function Engine:CopyToast(oldFrame, newFrame)
    if not oldFrame or not newFrame then
        return false
    end

    local config = self.config

    for _, field in ipairs(config.userFields) do
        newFrame.userData[field] = oldFrame.userData and oldFrame.userData[field]
    end

    newFrame.startTime = oldFrame.startTime
    newFrame.displayDuration = oldFrame.displayDuration
    newFrame.creationTime = oldFrame.creationTime
    newFrame.elapsedTime = oldFrame.elapsedTime
    newFrame.currentY = oldFrame.currentY

    if newFrame.currentY then
        local baseX = config.position()
        newFrame:ClearAllPoints()
        newFrame:SetPoint("TOP", UIParent, "TOP", baseX, newFrame.currentY)
    end

    newFrame.pauseState.active = oldFrame.pauseState.active
    newFrame.pauseState.startTime = oldFrame.pauseState.active and GetTime() or 0
    newFrame.pauseState.totalTime = oldFrame.pauseState.totalTime

    newFrame.pendingDismiss = oldFrame.pendingDismiss
    newFrame.dismissTime = oldFrame.dismissTime

    local data = oldFrame.cachedSegmentData
    if data then
        newFrame.cachedSegmentData = {
            duration = data.duration,
            segmentWidth = data.segmentWidth,
            lastHiddenSegment = data.lastHiddenSegment
        }

        for i = 1, data.duration do
            local oldSegment = oldFrame.countdownBar.segments[i]
            local newSegment = newFrame.countdownBar.segments[i]
            if oldSegment and newSegment then
                newSegment:ClearAllPoints()
                newSegment:SetPoint("LEFT", newFrame.countdownBar, "LEFT", (i - 1) * data.segmentWidth, 0)
                newSegment:SetWidth(data.segmentWidth - 2)
                newSegment:SetVertexColor(oldSegment:GetVertexColor())
                if oldSegment:IsShown() then
                    newSegment:Show()
                else
                    newSegment:Hide()
                end
            end
        end
    end

    newFrame:SetBackdropColor(oldFrame:GetBackdropColor())
    newFrame:SetBackdropBorderColor(oldFrame:GetBackdropBorderColor())

    if config.copyContent then
        config.copyContent(oldFrame, newFrame)
    end

    newFrame.inUse = true
    newFrame:SetScript("OnUpdate", oldFrame:GetScript("OnUpdate"))

    return true
end

local function SwapInsecureToSecurePool(state, releaseFn, copyFn, label, budgetMs)
    if InCombatLockdown() or state.swapInProgress then
        return 0, 0
    end

    state.swapInProgress = true
    local startTime = debugprofilestop()

    local insecureToasts = state.swapBuffer
    wipe(insecureToasts)
    for i = #state.activeList, 1, -1 do
        if state.activeList[i] and not state.activeList[i].isSecure then
            table.insert(insecureToasts, {index = i, frame = state.activeList[i]})
        end
    end

    if #insecureToasts == 0 then
        state.swapInProgress = false
        return 0, 0
    end

    local availableSecure = 0
    for i = 1, state.poolSize do
        if state.securePool[i] and not state.securePool[i].inUse then
            availableSecure = availableSecure + 1
        end
    end

    if availableSecure < #insecureToasts then
        local needed = #insecureToasts - availableSecure
        for i = 1, #state.activeList do
            if needed <= 0 then break end
            local toast = state.activeList[i]
            if toast and toast.isSecure then
                releaseFn(toast)
                availableSecure = availableSecure + 1
                needed = needed - 1
            end
        end
    end

    local swappedCount = 0
    for _, data in ipairs(insecureToasts) do
        local oldFrame = data.frame
        local newFrame = nil

        for i = 1, state.poolSize do
            if state.securePool[i] and not state.securePool[i].inUse then
                newFrame = state.securePool[i]
                newFrame.inUse = true
                break
            end
        end

        if not newFrame then
            SoundAlerter:Debug("BarSwap", "%s: no secure frames available, swap aborted after %d frames", label, swappedCount)
            break
        end

        if copyFn(oldFrame, newFrame) then
            state.activeList[data.index] = newFrame
            newFrame:Show()
            releaseFn(oldFrame)
            swappedCount = swappedCount + 1
        end
    end

    if swappedCount > 0 and state.onLayoutChanged then
        state.onLayoutChanged()
    end

    local elapsed = debugprofilestop() - startTime
    state.metrics.count = state.metrics.count + 1
    state.metrics.totalTime = state.metrics.totalTime + elapsed
    state.metrics.maxTime = math.max(state.metrics.maxTime, elapsed)
    if state.metrics.histogram then
        state.metrics.histogram[swappedCount] = (state.metrics.histogram[swappedCount] or 0) + 1
    end

    SoundAlerter:Debug("BarSwap", "%s: %d frames swapped in %.2fms (avg %.2fms, max %.2fms)",
        label, swappedCount, elapsed, state.metrics.totalTime / state.metrics.count, state.metrics.maxTime)

    if elapsed > budgetMs then
        SoundAlerter:Print(string.format("[%s SWAP WARNING] Frame swap took %.2fms (exceeds %.1fms budget)",
            label, elapsed, budgetMs))
    end

    state.swapInProgress = false
    return swappedCount, elapsed
end

function Engine:SwapToSecure()
    local config = self.config
    return SwapInsecureToSecurePool(self.poolState, self.releaseFn, self.copyFn, config.swapLabel, config.swapBudgetMs)
end
