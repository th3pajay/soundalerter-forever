SA_MenuFX = {}

local FX = SA_MenuFX

local SLIDE_DISTANCE = 12
local SLIDE_TIME = 0.16
local TINT_TIME = 0.12
local KNOB_TIME = 0.14
local FLASH_TIME = 0.65
local SHAKE_TIME = 0.05
local SHAKE_OFFSETS = { 7, -13, 9, -5, 2 }
local PRESS_ALPHA = 0.75

local function registry()
    return setmetatable({}, { __mode = "k" })
end

local slides, fades, glides, flashes, shakes = registry(), registry(), registry(), registry(), registry()

function FX.Enabled()
    local addon = SoundAlerter
    local profile = addon and addon.db1 and addon.db1.profile
    return not profile or profile.menuAnimations ~= false
end

local function alpha(group, order, from, to, duration)
    local animation = group:CreateAnimation("Alpha")
    animation:SetOrder(order)
    animation:SetFromAlpha(from)
    animation:SetToAlpha(to)
    animation:SetDuration(duration)
    return animation
end

local function settle(frame)
    local set = slides[frame]
    if not set.parent then return end
    frame:ClearAllPoints()
    frame:SetAllPoints(set.parent)
end

function FX.SlideIn(frame, parent)
    local set = slides[frame]
    if set then
        set.parent = parent
        set.group:Stop()
    elseif FX.Enabled() then
        local group = frame:CreateAnimationGroup()
        local move = group:CreateAnimation("Translation")
        move:SetOrder(1)
        move:SetDuration(SLIDE_TIME)
        move:SetOffset(-SLIDE_DISTANCE, 0)
        move:SetSmoothing("OUT")
        alpha(group, 1, 0, 1, SLIDE_TIME):SetSmoothing("OUT")
        set = { group = group }
        slides[frame] = set
        local function done() settle(frame) end
        group:SetScript("OnFinished", done)
        group:SetScript("OnStop", done)
    end
    if not set or not FX.Enabled() then return false end
    set.parent = parent
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", SLIDE_DISTANCE, 0)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", SLIDE_DISTANCE, 0)
    set.group:Play()
    return true
end

function FX.Hover(frame, tint, ...)
    local function enter()
        if tint:IsShown() then return end
        tint:Show()
        if not FX.Enabled() then return end
        local group = fades[tint]
        if not group then
            group = tint:CreateAnimationGroup()
            group:SetToFinalAlpha(true)
            alpha(group, 1, 0, 1, TINT_TIME)
            fades[tint] = group
        end
        group:Play()
    end
    local function leave()
        if frame:IsMouseOver() then return end
        if fades[tint] then fades[tint]:Stop() end
        tint:Hide()
    end
    frame:HookScript("OnEnter", enter)
    frame:HookScript("OnLeave", leave)
    for index = 1, select("#", ...) do
        local child = select(index, ...)
        child:HookScript("OnEnter", enter)
        child:HookScript("OnLeave", leave)
    end
end

function FX.Press(button, fill, label)
    button:HookScript("OnMouseDown", function()
        if not FX.Enabled() then return end
        fill:SetAlpha(PRESS_ALPHA)
        if label then label:SetPoint("CENTER", button, "CENTER", 0, -1) end
    end)
    button:HookScript("OnMouseUp", function()
        fill:SetAlpha(1)
        if label then label:SetPoint("CENTER", button, "CENTER", 0, 0) end
    end)
end

local function place(region, relative, x)
    region:ClearAllPoints()
    region:SetPoint("LEFT", relative, "LEFT", x, 0)
end

function FX.Glide(region, relative, x, animate)
    local set = glides[region]
    if not set then
        set = {}
        glides[region] = set
    end
    local from = set.x
    local playing = set.group and set.group:IsPlaying()
    if from == x then
        if not playing then place(region, relative, x) end
        return
    end
    if playing then set.group:Stop() end
    set.x = x
    set.relative = relative
    if not animate or from == nil or not FX.Enabled() then
        place(region, relative, x)
        return
    end
    if not set.group then
        local group = region:CreateAnimationGroup()
        local move = group:CreateAnimation("Translation")
        move:SetOrder(1)
        move:SetDuration(KNOB_TIME)
        move:SetSmoothing("OUT")
        set.group, set.move = group, move
        local function done() place(region, set.relative, set.x) end
        group:SetScript("OnFinished", done)
        group:SetScript("OnStop", done)
    end
    place(region, relative, from)
    set.move:SetOffset(x - from, 0)
    set.group:Play()
end

function FX.Flash(texture)
    if not FX.Enabled() then return false end
    local group = flashes[texture]
    if not group then
        group = texture:CreateAnimationGroup()
        group:SetToFinalAlpha(true)
        alpha(group, 1, 1, 0, FLASH_TIME):SetSmoothing("OUT")
        local function done() texture:Hide() end
        group:SetScript("OnFinished", done)
        group:SetScript("OnStop", done)
        flashes[texture] = group
    end
    group:Stop()
    texture:Show()
    group:Play()
    return true
end

function FX.Shake(frame)
    if not FX.Enabled() then return false end
    local group = shakes[frame]
    if not group then
        group = frame:CreateAnimationGroup()
        for index = 1, #SHAKE_OFFSETS do
            local step = group:CreateAnimation("Translation")
            step:SetOrder(index)
            step:SetDuration(SHAKE_TIME)
            step:SetOffset(SHAKE_OFFSETS[index], 0)
        end
        shakes[frame] = group
    end
    group:Stop()
    group:Play()
    return true
end
