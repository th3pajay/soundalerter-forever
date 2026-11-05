local SoundAlerter = SoundAlerter
local TrinketMenu = {}

local Model = SA_TrinketModel
local COMPAT = SA_COMPAT
local Plain = COMPAT.Plain
local BarUtils = SoundAlerter.BarUtils
local Tracker = SoundAlerter.SpellTracker
local GetTime = GetTime
local ipairs, pairs = ipairs, pairs

local BAR_NAME = "SoundAlerterTrinketMenu"
local FLYOUT_NAME = "SoundAlerterTrinketFlyout"
local DIAMOND_NAME = "SoundAlerterTrinketDiamond"
local BUTTON_NAMES = { [13] = "SA_TrinketButton1", [14] = "SA_TrinketButton2" }
local SET_NAME = "SA_TrinketSetButton"
local GEAR_NAME = "SA_TrinketGearButton"
local BINDINGS = {
    [13] = "CLICK SA_TrinketButton1:LeftButton",
    [14] = "CLICK SA_TrinketButton2:LeftButton",
    set = "CLICK SA_TrinketSetButton:LeftButton",
    gear = "CLICK SA_TrinketGearButton:LeftButton",
}

local DEFAULT_X, DEFAULT_Y = -300, -120
local EMPTY_ICON = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local FLAT_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local GLOW_SCALE = 1.72
local GLOW_ALPHA = 0.5
local SWEEP_ALPHA = 0.62
local TRINKET_COLOR = { 0.66, 0.77, 0.9 }
local SET_COLOR = { 0.24, 0.84, 0.78 }
local GEAR_COLOR = { 0.74, 0.58, 0.96 }
local WAIT_COLOR = { 1, 0.49, 0.04 }
local EMPTY_COLOR = { 0.29, 0.32, 0.38 }
local MUTED = { 0.588, 0.627, 0.698 }
local WHITE = { 1, 1, 1 }
local WARN_COLOR = { 1, 0.82, 0 }
local HOT_COLOR = { 1, 0.35, 0.3 }
local COUNTDOWN_STEPS = { { 10, WARN_COLOR }, { 3, HOT_COLOR } }
local HOTKEY_COLOR = { 0.6, 0.64, 0.7 }
local SPARK_TEXTURE = "Interface\\AddOns\\SoundAlerter\\Textures\\cp_glow"
local SPARKS = { { 1, 1 }, { 0.75, 0.6 }, { 0.55, 0.35 } }
local SPARK_RATIO = 0.6
local SPARK_LAG = 0.05
local COMET_LAP = 1.6
local COMET_LAPS = 2
local COMET_ALPHA = 0.55
local COMET_FADE_IN = 0.25
local COMET_FADE_OUT = 0.35
local READY_SLACK = 0.25
local DIM_SHADE = 0.8
local HOVER_LIFT = 0.35
local PLATE_PAD = 4
local OPEN_TIME = 0.15
local INSTANT = 0.001
local UNFOLD_STAGGER = 0.03
local UNFOLD_SCALE = 0.4
local SPIN_DEGREES = 90
local SPIN_SCALE = 0.5
local RIPPLE_TIME = 0.7
local RING_TEXTURE = "Interface\\AddOns\\SoundAlerter\\Textures\\cp_ring"
local NOTCH_SIZE = 8
local NUMBER_SIZE = 11
local HOTKEY_SIZE = 9
local LABEL_SIZE = 10
local BADGE_RATIO = 0.42
local FLYOUT_RATIO = 0.8
local FLYOUT_GAP = 6
local FLYOUT_PAD = 4
local FLYOUT_LINGER = 0.2
local AUTOHIDE_DELAY = 1.5
local DIAMOND_SIZE = 12
local DRIVE_RETRY = 0.6
local MAX_ATTEMPTS = 6
local FADE_TICK = 0.05
local PULSE_TIME = 0.5
local TEST_TIME = 3
local SWAP_WAIT = 2
local NUM_BAGS = NUM_BAG_SLOTS or 4
local LIVE_EVENTS = { "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "UPDATE_BINDINGS", "PLAYER_ENTERING_WORLD" }
local GEAR_EVENTS = { "EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SWAP_FINISHED" }

local SETTING_KEYS = {
    enabled = true, locked = true, PositionX = true, PositionY = true,
    orientation = true, swapOrder = true, iconSize = true, spacing = true,
    showSet = true, flyout = true, tooltips = true, cooldownNumbers = true,
    fade = true, fadeAlpha = true, fadeDelay = true, collapse = true, activeSet = true,
    showGear = true, gearMain = true, gearAlt = true, readyGlow = true,
}

local LIVE_KEYS = {
    tooltips = true, cooldownNumbers = true, flyout = true,
    fade = true, fadeAlpha = true, fadeDelay = true, activeSet = true,
    gearMain = true, gearAlt = true, readyGlow = true,
}

local function Lighten(color, amount)
    return { color[1] + (1 - color[1]) * amount, color[2] + (1 - color[2]) * amount, color[3] + (1 - color[3]) * amount }
end

local LIFT = {
    [TRINKET_COLOR] = Lighten(TRINKET_COLOR, HOVER_LIFT),
    [SET_COLOR] = Lighten(SET_COLOR, HOVER_LIFT),
    [GEAR_COLOR] = Lighten(GEAR_COLOR, HOVER_LIFT),
    [EMPTY_COLOR] = Lighten(EMPTY_COLOR, HOVER_LIFT),
}
local SPARK_COLOR = Lighten(TRINKET_COLOR, 0.55)
local RIPPLE_COLOR = Lighten(SET_COLOR, 0.55)

BINDING_HEADER_SOUNDALERTER = "SoundAlerter"
_G["BINDING_NAME_" .. BINDINGS[13]] = "Use top trinket"
_G["BINDING_NAME_" .. BINDINGS[14]] = "Use bottom trinket"
_G["BINDING_NAME_" .. BINDINGS.set] = "Equip selected trinket set"
_G["BINDING_NAME_" .. BINDINGS.gear] = "Switch main and alternate gear set"

local function Fighting()
    return InCombatLockdown() or Plain(UnitAffectingCombat("player")) == true
end

local function Casting()
    return Plain((COMPAT.UnitCastingInfo("player"))) ~= nil or Plain((COMPAT.UnitChannelInfo("player"))) ~= nil
end

local function ItemIcon(id)
    if not id then return nil end
    local _, icon = COMPAT.ItemBasics(id)
    return icon
end

local function KeyText(binding)
    local key = GetBindingKey(binding)
    if not key then return "" end
    return (key:gsub("SHIFT%-", "s"):gsub("CTRL%-", "c"):gsub("ALT%-", "a"))
end

function TrinketMenu:Run(key, fn)
    if not InCombatLockdown() then
        self.deferred[key] = nil
        fn()
        return true
    end
    if not self.deferred[key] then self.deferredOrder[#self.deferredOrder + 1] = key end
    self.deferred[key] = fn
    if not self.noticed and self.addon then
        self.noticed = true
        self.addon:Print("Trinket Menu changes apply when combat ends.")
    end
    return false
end

function TrinketMenu:Flush()
    if InCombatLockdown() then return end
    self.noticed = false
    local order = self.deferredOrder
    self.deferredOrder = {}
    for _, key in ipairs(order) do
        local fn = self.deferred[key]
        self.deferred[key] = nil
        if fn then fn() end
    end
end

function TrinketMenu:Equipped()
    local equipped = self.equipped
    equipped[13] = (COMPAT.InventoryItem(13))
    equipped[14] = (COMPAT.InventoryItem(14))
    return equipped
end

function TrinketMenu:ForgetBags()
    self.bagCache, self.flyoutItems = nil, nil
end

function TrinketMenu:FlyoutItems()
    if not self.flyoutItems then self.flyoutItems = Model.Flyout(self:BagTrinkets()) end
    return self.flyoutItems
end

function TrinketMenu:BagTrinkets()
    if self.bagCache then return self.bagCache end
    local list, owned = {}, {}
    for bag = 0, NUM_BAGS do
        for slot = 1, COMPAT.ContainerSlots(bag) do
            local id = COMPAT.ContainerItemID(bag, slot)
            if id then
                local equipLoc, icon = COMPAT.ItemBasics(id)
                if equipLoc == "INVTYPE_TRINKET" then
                    owned[id] = true
                    list[#list + 1] = { id = id, bag = bag, slot = slot, icon = icon, name = COMPAT.ItemName(id) }
                end
            end
        end
    end
    self.bagCache, self.owned = list, owned
    return list
end

function TrinketMenu:GearShown()
    if not self.db.showGear then return false end
    if self.gearUsable == nil then self.gearUsable = COMPAT.GearAvailable() end
    return self.gearUsable
end

function TrinketMenu:GearLive()
    return self.pendingGear ~= nil or self:GearShown()
end

function TrinketMenu:ForgetGear()
    self.gearCache, self.gearByName = nil, nil
end

function TrinketMenu:GearSets()
    if not self.gearCache then
        local list, byName = COMPAT.GearSets(), {}
        for _, set in ipairs(list) do byName[set.name] = set end
        self.gearCache, self.gearByName = list, byName
    end
    return self.gearCache, self.gearByName
end

function TrinketMenu:WearingGear()
    local _, byName = self:GearSets()
    local main, alt = Model.Named(self.db.gearMain), Model.Named(self.db.gearAlt)
    local set = main and byName[main]
    if set and set.equipped then return main end
    set = alt and byName[alt]
    if set and set.equipped then return alt end
    return nil
end

function TrinketMenu:GearTarget()
    local db = self.db
    return Model.GearTarget(db.gearMain, db.gearAlt, self:WearingGear(), self.pendingGear)
end

function TrinketMenu:GearQueued()
    return self.pendingGear ~= nil and Fighting()
end

function TrinketMenu:RequestGear(name)
    name = Model.Named(name)
    if not name then return false end
    local _, byName = self:GearSets()
    local set = byName[name]
    if not set then
        self.addon:Print("Gear set " .. name .. " was not found. Make it in the character panel first.")
        return false
    end
    self.pending, self.pendingSet, self.attempts, self.swapUntil = nil, nil, 0, 0
    self.pendingGear = not set.equipped and name or nil
    if self.pendingGear and not Fighting() then
        self:Drive()
    else
        self:Paint()
    end
    return true
end

function TrinketMenu:ToggleGear()
    local target = self:GearTarget()
    if not target then
        self.addon:Print("Pick a main gear set in the Trinket Menu options first.")
        return false
    end
    return self:RequestGear(target)
end

function TrinketMenu:Request(target, setIndex)
    if not target then return end
    self.pending, self.pendingSet, self.attempts = target, setIndex, 0
    self.pendingGear = nil
    if Fighting() then
        self:Paint()
    else
        self:Drive()
    end
end

local function DriveLater()
    TrinketMenu.driveQueued = false
    TrinketMenu:Drive()
end

local function PaintLater()
    TrinketMenu:Paint()
end

local function PaintQueued()
    TrinketMenu.paintQueued = false
    TrinketMenu:Paint()
end

function TrinketMenu:QueuePaint()
    if self.paintQueued then return end
    self.paintQueued = true
    C_Timer.After(0, PaintQueued)
end

local function ApplyLayoutNow()
    TrinketMenu:ApplyLayout()
end

local function PlaceNow()
    BarUtils:LoadPosition(TrinketMenu.bar, TrinketMenu.db, "", DEFAULT_X, DEFAULT_Y)
end

local function BuildNow()
    TrinketMenu:Build()
    TrinketMenu:LoadSettings()
end

function TrinketMenu:Retry()
    if self.driveQueued then return end
    self.driveQueued = true
    C_Timer.After(DRIVE_RETRY, DriveLater)
end

function TrinketMenu:Finish(message)
    self.pending, self.pendingSet, self.pendingGear, self.attempts, self.swapUntil = nil, nil, nil, 0, 0
    if message then self.addon:Print(message) end
    self:Paint()
end

function TrinketMenu:DriveGear()
    if Fighting() then
        self:Paint()
        return
    end
    if GetTime() < self.swapUntil then return self:Retry() end
    self:ForgetGear()
    local name = self.pendingGear
    local _, byName = self:GearSets()
    local set = byName[name]
    if not set then return self:Finish("Gear set " .. name .. " no longer exists.") end
    if set.equipped then return self:Finish() end
    if self.attempts > 0 and set.missing > 0 then
        return self:Finish("Gear set " .. name .. " is on, but " .. set.missing .. " of its items are not in your bags.")
    end
    if self.attempts >= MAX_ATTEMPTS then return self:Finish("Trinket Menu could not finish the gear swap.") end
    if CursorHasItem() or Casting() or COMPAT.GearSetLocked(set.id) then return self:Retry() end
    self.attempts = self.attempts + 1
    self.swapUntil = GetTime() + SWAP_WAIT
    COMPAT.UseGearSet(set.id)
    self:Retry()
end

function TrinketMenu:Drive()
    if not self.bar then return end
    if self.pendingGear then return self:DriveGear() end
    if not self.pending then return end
    if Fighting() then
        self:Paint()
        return
    end
    local equipped = self:Equipped()
    self:BagTrinkets()
    self.pending = Model.Prune(self.pending, equipped, self.owned)
    local steps = Model.Plan(self.pending, equipped)
    if #steps == 0 then return self:Finish() end
    if self.attempts >= MAX_ATTEMPTS then return self:Finish("Trinket Menu could not finish the trinket swap.") end
    if CursorHasItem() or Casting() then return self:Retry() end
    self.attempts = self.attempts + 1
    COMPAT.EquipItem(steps[1].id, steps[1].slot)
    self:Retry()
end

function TrinketMenu:SaveSet(index)
    local equipped = self:Equipped()
    if not equipped[13] and not equipped[14] then return false end
    self.db.sets[index] = { [13] = equipped[13], [14] = equipped[14] }
    self.addon:Print("Trinket set " .. index .. " saved.")
    self:Paint()
    return true
end

function TrinketMenu:ApplySet(index)
    local target = Model.FromSet(self.db.sets[index])
    if not target then
        self.addon:Print("Trinket set " .. index .. " is empty. Shift-click the set button to save your trinkets to it.")
        return false
    end
    self:Request(target, index)
    return true
end

function TrinketMenu:CycleSet(delta)
    self.db.activeSet = Model.NextSet(self.db.activeSet, delta)
    self:Paint()
    if GameTooltip:IsOwned(self.buttons.set) then self:SetTip(self.buttons.set) end
end

local function Shade(face)
    local dim = face.empty or face.cdStart ~= false
    if face.dim == dim then return end
    face.dim = dim
    face.texture:SetDesaturated(dim)
    local shade = dim and DIM_SHADE or 1
    face.texture:SetVertexColor(shade, shade, shade)
end

local function Countdown(face, start, duration)
    local text = face.numbers and face.numbers.text
    if not text then return end
    if not start then
        text:SetTextColor(WHITE[1], WHITE[2], WHITE[3], 1)
        return
    end
    local token, left = face.cdToken, start + duration - GetTime()
    local color = WHITE
    for _, step in ipairs(COUNTDOWN_STEPS) do
        local at, tint = step[1], step[2]
        if left <= at then
            color = tint
        else
            C_Timer.After(left - at, function()
                if face.cdToken == token then text:SetTextColor(tint[1], tint[2], tint[3], 1) end
            end)
        end
    end
    text:SetTextColor(color[1], color[2], color[3], 1)
end

local function StopComet(face)
    local comet = face.comet
    if not comet or not comet:IsShown() then return end
    comet.fade:Stop()
    for _, spark in ipairs(comet.sparks) do spark.path:Stop() end
    comet:Hide()
end

local function ApplyCooldown(face, start, duration)
    start, duration = start or false, duration or false
    local lastStart, lastDuration = face.cdStart, face.cdDuration
    if lastStart == start and lastDuration == duration then return end
    face.cdStart, face.cdDuration = start, duration
    face.cdToken = face.cdToken + 1
    if start then
        face.cooldown:SetCooldown(start, duration)
        if face.numbers then face.numbers:SetCooldown(start, duration) end
        StopComet(face)
    else
        face.cooldown:Clear()
        if face.numbers then face.numbers:Clear() end
        if face.slot and lastStart then TrinketMenu:Ready(face, lastStart, lastDuration) end
    end
    Countdown(face, start, duration)
    if face.slot then Shade(face) end
end

local function Pulse(texture, from)
    local pulse = texture:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local beat = pulse:CreateAnimation("Alpha")
    beat:SetFromAlpha(from)
    beat:SetToAlpha(1)
    beat:SetDuration(PULSE_TIME)
    return pulse
end

local function TogglePulse(pulse, on)
    if on then
        if not pulse:IsPlaying() then pulse:Play() end
    elseif pulse:IsPlaying() then
        pulse:Stop()
    end
end

local function Tint(face)
    local tint = face.waiting and WAIT_COLOR or face.hovered and LIFT[face.base] or face.base
    if face.tint == tint then return end
    face.tint = tint
    face:SetBackdropBorderColor(tint[1], tint[2], tint[3], 1)
    face.glow:SetVertexColor(tint[1], tint[2], tint[3], 1)
end

local function SetWaiting(face, waiting)
    if face.waiting == waiting then return end
    face.waiting = waiting
    Tint(face)
    TogglePulse(face.pulse, waiting)
end

local function SetBase(face, color)
    face.base = color
    Tint(face)
end

local function Hover(owner, on)
    local face = owner.face
    face.hovered = on
    Tint(face)
end

local function SetLabel(face, text)
    if face.labelText == text then return end
    face.labelText = text
    face.label:SetText(text)
    face.pill:SetShown(text ~= "")
end

local function OnCooldownDone(cooldown)
    local face = cooldown.face
    TrinketMenu:Ready(face, face.cdStart, face.cdDuration)
end

function TrinketMenu:Dress(button, color, split)
    local face = CreateFrame("Frame", nil, button, "BackdropTemplate")
    face:SetAllPoints(button)
    button.face = face
    face.color, face.base, face.tint = color, color, color
    BarUtils:CreateBackdrop(face, color[1], color[2], color[3], 1, nil, nil, nil, nil, nil, 8, 1)

    face.glow = face:CreateTexture(nil, "BACKGROUND")
    face.glow:SetTexture(GLOW_TEXTURE)
    face.glow:SetBlendMode("ADD")
    face.glow:SetPoint("CENTER")
    face.glow:SetAlpha(GLOW_ALPHA)
    face.glow:SetVertexColor(color[1], color[2], color[3], 1)
    face.pulse = Pulse(face.glow, GLOW_ALPHA)
    face.waiting, face.cdStart, face.cdDuration, face.cdToken = false, 0, 0, 0
    face.hovered, face.empty, face.dim, face.slot, face.size, face.comet, face.readyFor, face.unfold = false, false, false, false, false, false, false, false

    local inset = face:CreateTexture(nil, "BORDER")
    inset:SetColorTexture(0, 0, 0, 1)
    inset:SetPoint("TOPLEFT", 2, -2)
    inset:SetPoint("BOTTOMRIGHT", -2, 2)

    face.texture = face:CreateTexture(nil, "ARTWORK")
    face.texture:SetPoint("TOPLEFT", 3, -3)
    if split then
        face.texture:SetPoint("BOTTOMRIGHT", face, "BOTTOM", 0, 3)
        face.texture:SetTexCoord(0.07, 0.5, 0.07, 0.93)
        face.half = face:CreateTexture(nil, "ARTWORK")
        face.half:SetPoint("TOPLEFT", face, "TOP", 0, -3)
        face.half:SetPoint("BOTTOMRIGHT", -3, 3)
        face.half:SetTexCoord(0.5, 0.93, 0.07, 0.93)
        local divider = face:CreateTexture(nil, "OVERLAY")
        divider:SetColorTexture(0, 0, 0, 1)
        divider:SetWidth(1)
        divider:SetPoint("TOP", face, "TOP", 0, -3)
        divider:SetPoint("BOTTOM", face, "BOTTOM", 0, 3)
    else
        face.texture:SetPoint("BOTTOMRIGHT", -3, 3)
        face.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    face.cooldown = CreateFrame("Cooldown", nil, face, "CooldownFrameTemplate")
    face.cooldown.face = face
    face.cooldown:SetAllPoints(face.texture)
    face.cooldown:SetFrameLevel(face:GetFrameLevel() + 1)
    face.cooldown:SetDrawEdge(false)
    face.cooldown:SetDrawBling(false)
    face.cooldown:SetHideCountdownNumbers(true)
    face.cooldown:SetSwipeColor(0, 0, 0, SWEEP_ALPHA)
    face.cooldown.noCooldownCount = true

    if not split and Tracker then
        face.numbers = Tracker:CreateNumbersFrame(face)
        face.numbers:SetIgnoreParentAlpha(false)
        face.numbers.noCooldownCount = true
        local text = face.numbers.text
        if text then
            text:ClearAllPoints()
            text:SetPoint("BOTTOMRIGHT", face, "BOTTOMRIGHT", -2, 2)
            text:SetFont(STANDARD_TEXT_FONT, NUMBER_SIZE, "OUTLINE")
            text:SetTextColor(1, 1, 1, 1)
        end
    end

    local over = CreateFrame("Frame", nil, face)
    over:SetAllPoints(face)
    over:SetFrameLevel(face:GetFrameLevel() + 4)
    face.over = over

    face.hotkey = over:CreateFontString(nil, "OVERLAY")
    face.hotkey:SetFont(STANDARD_TEXT_FONT, HOTKEY_SIZE, "OUTLINE")
    face.hotkey:SetPoint("TOPLEFT", 3, -2)
    face.hotkey:SetTextColor(HOTKEY_COLOR[1], HOTKEY_COLOR[2], HOTKEY_COLOR[3], 1)

    face.badge = CreateFrame("Frame", nil, over, "BackdropTemplate")
    face.badge:SetPoint("CENTER", face, "TOPRIGHT", -2, -2)
    BarUtils:CreateBackdrop(face.badge, WAIT_COLOR[1], WAIT_COLOR[2], WAIT_COLOR[3], 1, nil, nil, nil, nil, nil, 6, 1)
    face.badge.icon = face.badge:CreateTexture(nil, "ARTWORK")
    face.badge.icon:SetPoint("TOPLEFT", 2, -2)
    face.badge.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    face.badge.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    face.badge:Hide()

    face.label = over:CreateFontString(nil, "OVERLAY")
    face.label:SetFont(STANDARD_TEXT_FONT, LABEL_SIZE, "OUTLINE")
    face.label:SetPoint("BOTTOM", 0, 3)
    face.pill = over:CreateTexture(nil, "ARTWORK")
    face.pill:SetColorTexture(0, 0, 0, 0.62)
    face.pill:SetPoint("TOPLEFT", face.label, "TOPLEFT", -2, 1)
    face.pill:SetPoint("BOTTOMRIGHT", face.label, "BOTTOMRIGHT", 2, -1)
    face.pill:Hide()
    face.labelText = ""
    return face
end

local function SizeComet(face)
    local comet, size = face.comet, face.size
    if not comet or not size then return end
    local side = size - 2
    local moves = { { side, 0 }, { 0, -side }, { -side, 0 }, { 0, side } }
    for _, spark in ipairs(comet.sparks) do
        local spot = size * SPARK_RATIO * spark.scale
        spark:SetSize(spot, spot)
        for step, move in ipairs(spark.moves) do
            local offset = moves[(step - 1) % 4 + 1]
            move:SetOffset(offset[1], offset[2])
        end
    end
end

local function Comet(face)
    if face.comet then return face.comet end
    local comet = CreateFrame("Frame", nil, face.over)
    comet:SetAllPoints(face)
    comet:Hide()
    local lap = COMET_LAP * COMET_LAPS
    local fade = comet:CreateAnimationGroup()
    local fadeIn = fade:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(COMET_FADE_IN)
    fadeIn:SetOrder(1)
    local fadeOut = fade:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetStartDelay(lap - COMET_FADE_IN - COMET_FADE_OUT + SPARK_LAG * #SPARKS)
    fadeOut:SetDuration(COMET_FADE_OUT)
    fadeOut:SetOrder(2)
    fade:SetScript("OnFinished", function() StopComet(face) end)
    comet.fade = fade
    comet.sparks = {}
    for index, spec in ipairs(SPARKS) do
        local spark = comet:CreateTexture(nil, "OVERLAY")
        spark:SetTexture(SPARK_TEXTURE)
        spark:SetBlendMode("ADD")
        spark:SetVertexColor(SPARK_COLOR[1], SPARK_COLOR[2], SPARK_COLOR[3], COMET_ALPHA * spec[2])
        spark:SetPoint("CENTER", comet, "TOPLEFT", 1, -1)
        spark.scale = spec[1]
        local path = spark:CreateAnimationGroup()
        spark.path, spark.moves = path, {}
        for step = 1, COMET_LAPS * 4 do
            local move = path:CreateAnimation("Translation")
            move:SetDuration(COMET_LAP / 4)
            move:SetOrder(step)
            if step == 1 then move:SetStartDelay((index - 1) * SPARK_LAG) end
            spark.moves[step] = move
        end
        comet.sparks[index] = spark
    end
    face.comet = comet
    SizeComet(face)
    return comet
end

local function PlayComet(face)
    StopComet(face)
    local comet = Comet(face)
    comet:Show()
    for _, spark in ipairs(comet.sparks) do spark.path:Play() end
    comet.fade:Play()
end

local function SizeFace(face, size)
    face.glow:SetSize(size * GLOW_SCALE, size * GLOW_SCALE)
    local badge = math.floor(size * BADGE_RATIO + 0.5)
    face.badge:SetSize(badge, badge)
    if face.size ~= size then
        face.size = size
        SizeComet(face)
    end
end

local function Step(group, kind, order, duration)
    local step = group:CreateAnimation(kind)
    step:SetOrder(order)
    step:SetDuration(duration)
    if duration > INSTANT then step:SetSmoothing("OUT") end
    return step
end

local function Spin(texture)
    local group = texture:CreateAnimationGroup()
    Step(group, "Rotation", 1, INSTANT):SetDegrees(-SPIN_DEGREES)
    Step(group, "Rotation", 2, OPEN_TIME):SetDegrees(SPIN_DEGREES)
    local grow = Step(group, "Scale", 2, OPEN_TIME)
    grow:SetScaleFrom(SPIN_SCALE, SPIN_SCALE)
    grow:SetScaleTo(1, 1)
    return group
end

local function OnDiamondShow(diamond)
    for _, spin in ipairs(diamond.spins) do
        spin:Stop()
        spin:Play()
    end
end

local function Unfold(face)
    local group = face:CreateAnimationGroup()
    group.from = Step(group, "Translation", 1, INSTANT)
    local hide = Step(group, "Alpha", 1, INSTANT)
    hide:SetFromAlpha(0)
    hide:SetToAlpha(0)
    group.move = Step(group, "Translation", 2, OPEN_TIME)
    local show = Step(group, "Alpha", 2, OPEN_TIME)
    show:SetFromAlpha(0)
    show:SetToAlpha(1)
    local grow = Step(group, "Scale", 2, OPEN_TIME)
    grow:SetScaleFrom(UNFOLD_SCALE, UNFOLD_SCALE)
    grow:SetScaleTo(1, 1)
    group.delayed = { group.move, show, grow }
    face.unfold = group
    return group
end

local function Stretch(plate)
    local group = plate:CreateAnimationGroup()
    group.scale = Step(group, "Scale", 1, OPEN_TIME)
    group.scale:SetScaleTo(1, 1)
    group.fade = Step(group, "Alpha", 1, OPEN_TIME)
    group.fade:SetFromAlpha(0)
    group.fade:SetToAlpha(1)
    plate.stretch = group
    return group
end

function TrinketMenu:PlayUnfold()
    local layout = self.layout
    if not layout then return end
    local size, step, count = layout.size, layout.size + layout.spacing, 0
    for key, button in pairs(self.buttons) do
        local offset = layout.offsets[key]
        if offset then
            count = count + 1
            local group = button.face.unfold or Unfold(button.face)
            if group.layout ~= layout then
                group.layout = layout
                local x, y = offset[1], offset[2]
                local delay = (math.abs(x) + math.abs(y)) / step * UNFOLD_STAGGER
                group.from:SetOffset(-x, -y)
                group.move:SetOffset(x, y)
                for _, part in ipairs(group.delayed) do part:SetStartDelay(delay) end
            end
            group:Stop()
            group:Play()
        end
    end
    local plate = self.plate
    local stretch = plate.stretch or Stretch(plate)
    if stretch.layout ~= layout then
        stretch.layout = layout
        local corner = PLATE_PAD + size / 2
        local seed = size + PLATE_PAD * 2
        stretch.scale:SetOrigin("TOPLEFT", corner, -corner)
        stretch.scale:SetScaleFrom(seed / (layout.width + PLATE_PAD * 2), seed / (layout.height + PLATE_PAD * 2))
        local span = OPEN_TIME + (count - 1) * UNFOLD_STAGGER
        stretch.scale:SetDuration(span)
        stretch.fade:SetDuration(span)
    end
    stretch:Stop()
    stretch:Play()
end

local function OnBarShow(bar)
    if bar:GetAttribute("collapse") then TrinketMenu:PlayUnfold() end
end

function TrinketMenu:Ripple()
    local diamond = self.diamond
    local ripple = diamond.ripple
    if not ripple then
        local ring = diamond.skin:CreateTexture(nil, "OVERLAY")
        ring:SetTexture(RING_TEXTURE)
        ring:SetBlendMode("ADD")
        ring:SetSize(DIAMOND_SIZE * 1.5, DIAMOND_SIZE * 1.5)
        ring:SetPoint("CENTER")
        ring:SetVertexColor(RIPPLE_COLOR[1], RIPPLE_COLOR[2], RIPPLE_COLOR[3], 1)
        ring:SetAlpha(0)
        ripple = ring:CreateAnimationGroup()
        local grow = Step(ripple, "Scale", 1, RIPPLE_TIME)
        grow:SetScaleFrom(0.6, 0.6)
        grow:SetScaleTo(2.2, 2.2)
        local fade = Step(ripple, "Alpha", 1, RIPPLE_TIME)
        fade:SetFromAlpha(0.8)
        fade:SetToAlpha(0)
        diamond.ripple = ripple
    end
    ripple:Stop()
    ripple:Play()
end

function TrinketMenu:Ready(face, start, duration)
    if not start or face.readyFor == start or start + duration > GetTime() + READY_SLACK then return end
    face.readyFor = start
    local diamond = self.diamond
    local target = Model.ReadyTarget(self.db.readyGlow, duration, (self.alpha or 1) < 1, self.bar:IsShown(), diamond and diamond:IsShown(), face.waiting)
    if target == "bar" then
        PlayComet(face)
    elseif target == "diamond" then
        self:Ripple()
    end
end

local function OnTrinketEnter(button)
    Hover(button, true)
    TrinketMenu:Wake()
    TrinketMenu:TrinketTip(button)
    TrinketMenu:OpenFlyout(button)
end

local function HideTip(owner)
    Hover(owner, false)
    if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
    TrinketMenu:Rest()
end

local function OnTrinketPostClick(_, mouse, down)
    if mouse ~= "RightButton" or down then return end
    TrinketMenu:Request(Model.Swap(TrinketMenu.pending, TrinketMenu:Equipped()))
end

local function OnSetClick(_, mouse)
    if mouse == "RightButton" then
        TrinketMenu:CycleSet(1)
    elseif IsShiftKeyDown() then
        TrinketMenu:SaveSet(TrinketMenu.db.activeSet)
    else
        TrinketMenu:ApplySet(TrinketMenu.db.activeSet)
    end
end

local function OnGearClick(button, mouse)
    if mouse == "RightButton" then
        TrinketMenu:OpenGearFlyout(button)
    else
        TrinketMenu.flyout:Hide()
        TrinketMenu:ToggleGear()
        if GameTooltip:IsOwned(button) then TrinketMenu:GearTip(button) end
    end
end

function TrinketMenu:CreateTrinketButton(slot)
    local button = CreateFrame("Button", BUTTON_NAMES[slot], self.bar, "SecureActionButtonTemplate")
    button:SetAttribute("type1", "item")
    button:SetAttribute("item", tostring(slot))
    button:RegisterForClicks("AnyUp", "AnyDown")
    button.slot = slot
    local face = self:Dress(button, TRINKET_COLOR)
    face.slot = slot
    face.cooldown:SetScript("OnCooldownDone", OnCooldownDone)
    button:SetScript("PostClick", OnTrinketPostClick)
    button:HookScript("OnEnter", OnTrinketEnter)
    button:HookScript("OnLeave", HideTip)
    return button
end

function TrinketMenu:CreateSetButton()
    local button = CreateFrame("Button", SET_NAME, self.bar)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:EnableMouseWheel(true)
    self:Dress(button, SET_COLOR, true)
    button:SetScript("OnClick", OnSetClick)
    button:SetScript("OnMouseWheel", function(_, delta) TrinketMenu:CycleSet(delta > 0 and -1 or 1) end)
    button:SetScript("OnEnter", function(owner)
        Hover(owner, true)
        TrinketMenu:Wake()
        TrinketMenu.flyout:Hide()
        TrinketMenu:SetTip(owner)
    end)
    button:SetScript("OnLeave", HideTip)
    return button
end

function TrinketMenu:CreateGearButton()
    local button = CreateFrame("Button", GEAR_NAME, self.bar)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self:Dress(button, GEAR_COLOR)
    button:SetScript("OnClick", OnGearClick)
    button:SetScript("OnEnter", function(owner)
        Hover(owner, true)
        TrinketMenu:Wake()
        if TrinketMenu.flyout.owner ~= owner then TrinketMenu.flyout:Hide() end
        TrinketMenu:GearTip(owner)
    end)
    button:SetScript("OnLeave", HideTip)
    return button
end

function TrinketMenu:CreateMover()
    local bar = self.bar
    local mover = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    mover:SetAllPoints(bar)
    mover:SetFrameLevel(bar:GetFrameLevel() + 20)
    BarUtils:CreateBackdrop(mover, WAIT_COLOR[1], WAIT_COLOR[2], WAIT_COLOR[3], 0.9, BarUtils.BACKDROP_TEXTURES.Solid, 0, 0, 0, 0.35, 8, 2)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function()
        if InCombatLockdown() or TrinketMenu.db.locked then return end
        TrinketMenu.moving = true
        bar:StartMoving()
    end)
    mover:SetScript("OnDragStop", function() TrinketMenu:StopMoving() end)
    mover:Hide()
    self.mover = mover
end

function TrinketMenu:StopMoving()
    if not self.moving then return end
    self.moving = false
    self.bar:StopMovingOrSizing()
    BarUtils:SavePosition(self.bar, self.db, "")
    self:Run("position", PlaceNow)
end

function TrinketMenu:CreateFlyout()
    local flyout = CreateFrame("Frame", FLYOUT_NAME, UIParent, "BackdropTemplate")
    flyout:SetFrameStrata("DIALOG")
    flyout:SetClampedToScreen(true)
    BarUtils:CreateBackdrop(flyout, 0.227, 0.263, 0.322, 1, BarUtils.BACKDROP_TEXTURES.Solid, 0.059, 0.071, 0.094, 0.92, 8, 2)
    flyout.notch = flyout:CreateTexture(nil, "BACKGROUND", nil, -8)
    flyout.notch:SetColorTexture(0.227, 0.263, 0.322, 1)
    flyout.notch:SetSize(NOTCH_SIZE, NOTCH_SIZE)
    flyout.notch:SetRotation(math.rad(45))
    flyout.buttons = {}
    flyout.idle = 0
    flyout:SetScript("OnUpdate", function(frame, elapsed)
        local owner = frame.owner
        if frame:IsMouseOver() or (owner and owner:IsVisible() and owner:IsMouseOver()) then
            frame.idle = 0
            return
        end
        frame.idle = frame.idle + elapsed
        if frame.idle > FLYOUT_LINGER then frame:Hide() end
    end)
    flyout:SetScript("OnHide", function() TrinketMenu:Rest() end)
    flyout:Hide()
    self.flyout = flyout
end

function TrinketMenu:FlyoutButton(index)
    local flyout = self.flyout
    local button = flyout.buttons[index]
    if button then return button end
    button = CreateFrame("Button", nil, flyout)
    button:RegisterForClicks("LeftButtonUp")
    self:Dress(button, TRINKET_COLOR)
    button:SetScript("OnClick", function(item)
        flyout:Hide()
        if flyout.mode == "gear" then
            TrinketMenu:RequestGear(item.gearName)
        else
            TrinketMenu:Request(Model.Request(TrinketMenu.pending, flyout.slot, item.itemID))
        end
    end)
    button:SetScript("OnEnter", function(item)
        Hover(item, true)
        TrinketMenu:Wake()
        if not TrinketMenu.db.tooltips then return end
        GameTooltip:SetOwner(item, "ANCHOR_RIGHT")
        if flyout.mode == "gear" then
            TrinketMenu:GearSetLines(item.gearName)
        else
            GameTooltip:SetBagItem(item.bag, item.bagSlot)
        end
        GameTooltip:AddLine(Fighting() and "Click: equip when combat ends" or "Click: equip", MUTED[1], MUTED[2], MUTED[3])
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", HideTip)
    flyout.buttons[index] = button
    return button
end

function TrinketMenu:FillTrinket(button, item)
    local face = button.face
    button.itemID, button.bag, button.bagSlot, button.gearName = item.id, item.bag, item.slot, nil
    face.texture:SetTexture(item.icon or UNKNOWN_ICON)
    face.texture:SetDesaturated(false)
    SetLabel(face, "")
    SetBase(face, TRINKET_COLOR)
    local start, duration = Model.Cooldown(COMPAT.ItemCooldown(item.id))
    ApplyCooldown(face, start, duration)
end

function TrinketMenu:FillGear(button, set)
    local face = button.face
    button.itemID, button.gearName = nil, set.name
    face.texture:SetTexture(set.icon or UNKNOWN_ICON)
    face.texture:SetDesaturated(set.missing > 0)
    SetLabel(face, Model.GearLabel(set.name))
    SetBase(face, set.equipped and GEAR_COLOR or TRINKET_COLOR)
    ApplyCooldown(face, nil)
end

function TrinketMenu:OpenFlyout(owner)
    if not self.db.flyout or not self.db.enabled then
        self.flyout:Hide()
        return
    end
    self:ShowFlyout(owner, "trinket", self:FlyoutItems())
end

function TrinketMenu:OpenGearFlyout(owner)
    if not self:GearShown() or not self.db.enabled then
        self.flyout:Hide()
        return
    end
    local sets = self:GearSets()
    if #sets == 0 then self.addon:Print("You have no equipment sets yet. Make them in the character panel.") end
    self:ShowFlyout(owner, "gear", sets)
end

function TrinketMenu:RefreshFlyout()
    local flyout = self.flyout
    if not flyout:IsShown() then return end
    if flyout.mode == "gear" then
        self:OpenGearFlyout(flyout.owner)
    else
        self:OpenFlyout(flyout.owner)
    end
end

function TrinketMenu:ShowFlyout(owner, mode, entries)
    local flyout = self.flyout
    local count = math.min(#entries, Model.FLYOUT_MAX)
    if count == 0 then
        flyout:Hide()
        return
    end

    local size = math.floor(self.db.iconSize * FLYOUT_RATIO + 0.5)
    local step = size + FLYOUT_PAD
    local vertical = self.db.orientation ~= "horizontal"
    for index = 1, count do
        local button = self:FlyoutButton(index)
        local offset = FLYOUT_PAD + (index - 1) * step
        button:SetSize(size, size)
        SizeFace(button.face, size)
        button:ClearAllPoints()
        if vertical then
            button:SetPoint("LEFT", flyout, "LEFT", offset, 0)
        else
            button:SetPoint("BOTTOM", flyout, "BOTTOM", 0, offset)
        end
        button:Show()
        if mode == "gear" then
            self:FillGear(button, entries[index])
        else
            self:FillTrinket(button, entries[index])
        end
    end
    for index = count + 1, #flyout.buttons do flyout.buttons[index]:Hide() end

    local span = FLYOUT_PAD + count * step
    local thick = size + FLYOUT_PAD * 2
    local scale = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local left, bottom, width, height = owner:GetRect()
    flyout:ClearAllPoints()
    flyout.notch:ClearAllPoints()
    flyout.notch:SetPoint("CENTER", flyout, vertical and "LEFT" or "BOTTOM")
    if vertical then
        flyout:SetSize(span, thick)
        flyout:SetPoint("LEFT", UIParent, "BOTTOMLEFT", (left + width) * scale + FLYOUT_GAP, (bottom + height / 2) * scale)
    else
        flyout:SetSize(thick, span)
        flyout:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", (left + width / 2) * scale, (bottom + height) * scale + FLYOUT_GAP)
    end
    flyout.owner, flyout.slot, flyout.mode, flyout.idle = owner, owner.slot, mode, 0
    flyout:Show()
end

function TrinketMenu:TrinketTip(button)
    if not self.db.tooltips then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetInventoryItem("player", button.slot)
    local incoming = Fighting() and self.pending and self.pending[button.slot]
    if incoming and incoming ~= self:Equipped()[button.slot] then
        GameTooltip:AddLine("Equips " .. (COMPAT.ItemName(incoming) or "a trinket") .. " when combat ends", WAIT_COLOR[1], WAIT_COLOR[2], WAIT_COLOR[3])
    end
    GameTooltip:AddLine("Click: use · Right-click: swap top and bottom", MUTED[1], MUTED[2], MUTED[3])
    GameTooltip:Show()
end

function TrinketMenu:SetTip(button)
    if not self.db.tooltips then return end
    local index = self.db.activeSet
    local set = self.db.sets[index]
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Trinket set " .. index)
    if Model.SetFilled(set) then
        GameTooltip:AddLine("Top: " .. (set[13] and COMPAT.ItemName(set[13]) or "empty"), 1, 1, 1)
        GameTooltip:AddLine("Bottom: " .. (set[14] and COMPAT.ItemName(set[14]) or "empty"), 1, 1, 1)
    else
        GameTooltip:AddLine("Empty", MUTED[1], MUTED[2], MUTED[3])
    end
    if self:SetQueued() then
        GameTooltip:AddLine("Equips set " .. self.pendingSet .. " when combat ends", WAIT_COLOR[1], WAIT_COLOR[2], WAIT_COLOR[3])
    end
    GameTooltip:AddLine("Click: equip · Right-click or wheel: next set · Shift-click: save current", MUTED[1], MUTED[2], MUTED[3], true)
    GameTooltip:Show()
end

function TrinketMenu:SetQueued()
    return self.pendingSet ~= nil and Fighting() and Model.Waiting(self.pending, self:Equipped())
end

function TrinketMenu:GearSetLines(name)
    local _, byName = self:GearSets()
    local set = byName[name]
    GameTooltip:AddLine(name or "Gear set")
    if not set then
        GameTooltip:AddLine("Not found on this character", WAIT_COLOR[1], WAIT_COLOR[2], WAIT_COLOR[3])
        return
    end
    if set.equipped then GameTooltip:AddLine("Worn now", GEAR_COLOR[1], GEAR_COLOR[2], GEAR_COLOR[3]) end
    if set.missing > 0 then
        GameTooltip:AddLine(set.missing .. " of its items are not in your bags", WAIT_COLOR[1], WAIT_COLOR[2], WAIT_COLOR[3])
    end
end

local function GearLine(label, name, set)
    if not name then return label .. ": none" end
    if not set then return label .. ": " .. name .. " (not found)" end
    return label .. ": " .. name .. (set.equipped and " (worn)" or "")
end

function TrinketMenu:GearTip(button)
    if not self.db.tooltips then return end
    local db = self.db
    local _, byName = self:GearSets()
    local main, alt = Model.Named(db.gearMain), Model.Named(db.gearAlt)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Gear sets")
    GameTooltip:AddLine(GearLine("Main", main, byName[main]), 1, 1, 1)
    GameTooltip:AddLine(GearLine("Alternate", alt, byName[alt]), 1, 1, 1)
    if not main then
        GameTooltip:AddLine("Pick the sets in the Trinket Menu options", WAIT_COLOR[1], WAIT_COLOR[2], WAIT_COLOR[3])
    end
    if self:GearQueued() then
        GameTooltip:AddLine("Equips " .. self.pendingGear .. " when combat ends", WAIT_COLOR[1], WAIT_COLOR[2], WAIT_COLOR[3])
    end
    GameTooltip:AddLine("Click: switch main and alternate · Right-click: all sets", MUTED[1], MUTED[2], MUTED[3], true)
    GameTooltip:Show()
end

function TrinketMenu:CreateDiamond()
    if not (SecureHandlerSetFrameRef and RegisterAutoHide and UnregisterAutoHide) then return end
    local bar = self.bar
    local diamond = CreateFrame("Frame", DIAMOND_NAME, UIParent, "SecureHandlerEnterLeaveTemplate")
    diamond:SetSize(DIAMOND_SIZE * 2, DIAMOND_SIZE * 2)
    diamond:SetFrameStrata("MEDIUM")
    diamond:EnableMouse(true)

    local skin = CreateFrame("Frame", nil, diamond)
    skin:SetAllPoints(diamond)
    diamond.skin = skin
    local function layer(level, texture, size, color, rotate)
        local region = skin:CreateTexture(nil, level)
        region:SetTexture(texture)
        region:SetSize(size, size)
        region:SetPoint("CENTER")
        region:SetVertexColor(color[1], color[2], color[3], 1)
        if rotate then region:SetRotation(math.rad(45)) end
        return region
    end
    diamond.spins = {
        Spin(layer("BORDER", FLAT_TEXTURE, DIAMOND_SIZE + 2, { 0, 0, 0 }, true)),
        Spin(layer("ARTWORK", FLAT_TEXTURE, DIAMOND_SIZE, SET_COLOR, true)),
    }
    local glow = layer("BACKGROUND", GLOW_TEXTURE, DIAMOND_SIZE * 3, WAIT_COLOR)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    diamond.pulse = Pulse(glow, 0)
    diamond.ripple = false
    diamond:HookScript("OnShow", OnDiamondShow)

    diamond:SetFrameRef("bar", bar)
    diamond:SetAttribute("_onenter", ([[
        local bar = self:GetFrameRef("bar")
        bar:Show()
        bar:RegisterAutoHide(%s)
    ]]):format(AUTOHIDE_DELAY))
    bar:SetFrameRef("diamond", diamond)
    bar:SetAttribute("_onshow", [[
        if self:GetAttribute("collapse") then self:GetFrameRef("diamond"):Hide() end
    ]])
    bar:SetAttribute("_onhide", [[
        if self:GetAttribute("collapse") then self:GetFrameRef("diamond"):Show() end
    ]])
    diamond:Hide()
    self.diamond = diamond
end

function TrinketMenu:Build()
    if self.bar then return end
    local template = SecureHandlerSetFrameRef and "SecureHandlerShowHideTemplate" or nil
    local bar = CreateFrame("Frame", BAR_NAME, UIParent, template)
    bar:SetFrameStrata("MEDIUM")
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:SetClampRectInsets(-PLATE_PAD, PLATE_PAD, PLATE_PAD, -PLATE_PAD)
    bar:Hide()
    self.bar = bar

    local plate = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    plate:SetPoint("TOPLEFT", -PLATE_PAD, PLATE_PAD)
    plate:SetPoint("BOTTOMRIGHT", PLATE_PAD, -PLATE_PAD)
    plate:SetFrameLevel(bar:GetFrameLevel())
    BarUtils:CreateBackdrop(plate, 1, 1, 1, 0.06, BarUtils.BACKDROP_TEXTURES.Solid, 0.04, 0.05, 0.07, 0.72, 8, 2)
    plate.stretch = false
    self.plate = plate
    bar:HookScript("OnShow", OnBarShow)

    self.buttons = {
        [13] = self:CreateTrinketButton(13),
        [14] = self:CreateTrinketButton(14),
        set = self:CreateSetButton(),
        gear = self:CreateGearButton(),
    }
    self:CreateMover()
    self:CreateFlyout()
    if template then self:CreateDiamond() end

    self.driver = CreateFrame("Frame")
end

function TrinketMenu:ApplyLayout()
    local db, bar, diamond = self.db, self.bar, self.diamond
    local size = db.iconSize
    local offsets, width, height = Model.Layout(db.orientation, db.swapOrder, db.showSet, self:GearShown(), size, db.spacing)
    self.layout = { offsets = offsets, width = width, height = height, size = size, spacing = db.spacing }
    bar:SetSize(width, height)
    for key, button in pairs(self.buttons) do
        local offset = offsets[key]
        button:ClearAllPoints()
        button:SetSize(size, size)
        SizeFace(button.face, size)
        if offset then
            button:SetPoint("TOPLEFT", bar, "TOPLEFT", offset[1], offset[2])
            button:Show()
        else
            button:Hide()
        end
    end
    BarUtils:LoadPosition(bar, db, "", DEFAULT_X, DEFAULT_Y)
    self.mover:SetShown(not db.locked)

    local collapse = db.enabled and db.collapse and db.locked and diamond ~= nil
    if diamond then
        bar:SetAttribute("collapse", collapse)
        UnregisterAutoHide(bar)
        diamond:ClearAllPoints()
        diamond:SetPoint("CENTER", bar, "TOPLEFT", size / 2, -size / 2)
    end
    if not db.enabled then
        bar:Hide()
        if diamond then diamond:Hide() end
    elseif collapse then
        bar:Hide()
        diamond:Show()
    else
        bar:Show()
        if diamond then diamond:Hide() end
    end
end

local fadeElapsed = 0

local function FadeStep(driver, elapsed)
    fadeElapsed = fadeElapsed + elapsed
    if fadeElapsed < FADE_TICK then return end
    fadeElapsed = 0
    local menu, now = TrinketMenu, GetTime()
    if menu.bar:IsMouseOver() or menu.flyout:IsShown() then menu.idleSince = now end
    local target = menu.db.fadeAlpha
    local alpha = Model.IdleAlpha(true, now - menu.idleSince, menu.db.fadeDelay, target)
    menu:SetBarAlpha(alpha)
    if alpha == target then driver:SetScript("OnUpdate", nil) end
end

function TrinketMenu:SetBarAlpha(alpha)
    if self.alpha == alpha then return end
    self.alpha = alpha
    self.bar:SetAlpha(alpha)
end

function TrinketMenu:Wake()
    if not self.fadeOn then return end
    self.driver:SetScript("OnUpdate", nil)
    self:SetBarAlpha(1)
end

function TrinketMenu:Rest()
    if not self.fadeOn then return end
    self.idleSince, fadeElapsed = GetTime(), 0
    self.driver:SetScript("OnUpdate", FadeStep)
end

function TrinketMenu:ApplyFade()
    local db = self.db
    self.fadeOn = db.enabled and db.fade and db.locked
    if self.fadeOn then
        self:Rest()
    else
        self.driver:SetScript("OnUpdate", nil)
        self:SetBarAlpha(1)
    end
end

function TrinketMenu:Paint()
    if not self.bar then return end
    local equipped = self:Equipped()
    local queued = Fighting() and self.pending
    for _, slot in ipairs(Model.SLOTS) do
        local face = self.buttons[slot].face
        local _, icon = COMPAT.InventoryItem(slot)
        face.texture:SetTexture(icon or EMPTY_ICON)
        local empty = icon == nil
        if face.empty ~= empty then
            face.empty = empty
            SetBase(face, empty and EMPTY_COLOR or TRINKET_COLOR)
            Shade(face)
        end
        local incoming = queued and queued[slot] or nil
        local waiting = incoming ~= nil and incoming ~= equipped[slot]
        face.badge:SetShown(waiting)
        if waiting then face.badge.icon:SetTexture(ItemIcon(incoming) or UNKNOWN_ICON) end
        SetWaiting(face, waiting)
    end

    local db = self.db
    local face = self.buttons.set.face
    local set = db.sets[db.activeSet]
    local filled = Model.SetFilled(set)
    face.texture:SetTexture(filled and (ItemIcon(set[13]) or EMPTY_ICON) or UNKNOWN_ICON)
    face.half:SetTexture(filled and (ItemIcon(set[14]) or EMPTY_ICON) or UNKNOWN_ICON)
    face.texture:SetDesaturated(not filled)
    face.half:SetDesaturated(not filled)
    SetLabel(face, Model.SetLabel(db.activeSet))
    SetWaiting(face, self:SetQueued())

    if self:GearShown() then self:PaintGear() end

    if self.diamond then
        TogglePulse(self.diamond.pulse, (queued and Model.Waiting(queued, equipped)) or self:GearQueued())
    end
end

function TrinketMenu:PaintGear()
    local face = self.buttons.gear.face
    local _, byName = self:GearSets()
    local shown = self.pendingGear or self:GearTarget()
    local set = shown and byName[shown]
    face.texture:SetTexture(set and set.icon or UNKNOWN_ICON)
    face.texture:SetDesaturated(set == nil)
    SetLabel(face, Model.GearLabel(shown))
    SetWaiting(face, self:GearQueued())
end

function TrinketMenu:PaintCooldowns()
    if not self.bar then return end
    for _, slot in ipairs(Model.SLOTS) do
        local start, duration = Model.Cooldown(COMPAT.InventoryCooldown(slot))
        ApplyCooldown(self.buttons[slot].face, start, duration)
    end
    local flyout = self.flyout
    if flyout:IsShown() and flyout.mode == "trinket" then
        for _, button in ipairs(flyout.buttons) do
            if button:IsShown() then
                local start, duration = Model.Cooldown(COMPAT.ItemCooldown(button.itemID))
                ApplyCooldown(button.face, start, duration)
            end
        end
    end
end

function TrinketMenu:PaintHotkeys()
    if not self.bar then return end
    for key, button in pairs(self.buttons) do
        button.face.hotkey:SetText(KeyText(BINDINGS[key]))
    end
end

function TrinketMenu:PaintNumbers()
    local hide = not self.db.cooldownNumbers
    for _, slot in ipairs(Model.SLOTS) do
        local numbers = self.buttons[slot].face.numbers
        if numbers then numbers:SetHideCountdownNumbers(hide) end
    end
    for _, button in ipairs(self.flyout.buttons) do
        if button.face.numbers then button.face.numbers:SetHideCountdownNumbers(hide) end
    end
end

function TrinketMenu:OnEvent(event, arg)
    if event == "PLAYER_REGEN_ENABLED" then
        self:Flush()
        if not self.bar then return end
        self.attempts = 0
        self:Paint()
        self:Drive()
        return
    end
    if not self.bar then return end
    if event == "PLAYER_REGEN_DISABLED" then
        self:StopMoving()
        self:Paint()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local trinket = arg == 13 or arg == 14
        if not trinket and not self:GearLive() then return end
        self:ForgetGear()
        if trinket then
            self:ForgetBags()
            self:PaintCooldowns()
        end
        self:QueuePaint()
        if self.pending then self:Drive() end
    elseif event == "EQUIPMENT_SETS_CHANGED" then
        if not self:GearLive() then return end
        self:ForgetGear()
        self:QueuePaint()
        if self.flyout.mode == "gear" then self:RefreshFlyout() end
    elseif event == "EQUIPMENT_SWAP_FINISHED" then
        if not self:GearLive() then return end
        self.swapUntil = 0
        self:ForgetGear()
        self:Paint()
        if self.pendingGear then self:Drive() end
    elseif event == "BAG_UPDATE_DELAYED" then
        self:ForgetBags()
        self:ForgetGear()
        self:RefreshFlyout()
    elseif event == "BAG_UPDATE_COOLDOWN" then
        self:PaintCooldowns()
    elseif event == "UPDATE_BINDINGS" then
        self:PaintHotkeys()
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:ForgetBags()
        self:ForgetGear()
        self.gearUsable = nil
        self:Paint()
        self:PaintCooldowns()
        self:PaintHotkeys()
    end
end

function TrinketMenu:GetSettings()
    return self.db
end

function TrinketMenu:SetSetting(key, value)
    if not SETTING_KEYS[key] then
        error("TrinketMenu:SetSetting - unknown setting key '" .. tostring(key) .. "'", 2)
    end
    self.db[key] = value
    self:LoadSettings(LIVE_KEYS[key])
end

function TrinketMenu:Listen(on)
    on = on and true or false
    if self.listening == on then return end
    self.listening = on
    local events = self.events
    for _, event in ipairs(LIVE_EVENTS) do
        if on then events:RegisterEvent(event) else events:UnregisterEvent(event) end
    end
    if COMPAT.GearAvailable() then
        for _, event in ipairs(GEAR_EVENTS) do
            pcall(on and events.RegisterEvent or events.UnregisterEvent, events, event)
        end
    end
    if on then
        self:ForgetBags()
        self:ForgetGear()
    end
end

function TrinketMenu:LoadSettings(live)
    local db = self.db
    self.gearUsable = nil
    self:Listen(db.enabled)
    if not self.bar then
        if db.enabled then self:Run("create", BuildNow) end
        return
    end
    if not (db.enabled and db.flyout) then self.flyout:Hide() end
    if not db.readyGlow then
        for _, slot in ipairs(Model.SLOTS) do StopComet(self.buttons[slot].face) end
    end
    if not live then self:Run("layout", ApplyLayoutNow) end
    self:ApplyFade()
    self:PaintNumbers()
    self:Paint()
    self:PaintCooldowns()
    self:PaintHotkeys()
end

function TrinketMenu:ResetPosition()
    if not self.db then return end
    self.db.PositionX = DEFAULT_X
    self.db.PositionY = DEFAULT_Y
    self:LoadSettings()
end

function TrinketMenu:RunTest()
    if not self.db.enabled then
        self.addon:Print("Turn the Trinket Menu on to see the test.")
        return
    end
    if not self.bar then return end
    local now = GetTime()
    for index, slot in ipairs(Model.SLOTS) do
        ApplyCooldown(self.buttons[slot].face, now, 6 + index * 4)
    end
    SetWaiting(self.buttons.set.face, true)
    SetWaiting(self.buttons.gear.face, true)
    if self.db.readyGlow then PlayComet(self.buttons[13].face) end
    C_Timer.After(TEST_TIME, PaintLater)
    self:Wake()
    self:Rest()
end

function TrinketMenu:OnProfileChanged()
    local addon = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not addon then return end
    self.addon = addon
    self.db = addon.db1.profile.trinketMenu
    self.pending, self.pendingSet, self.pendingGear = nil, nil, nil
    self:ForgetGear()
    if self.initialized then self:LoadSettings() end
end

function TrinketMenu:Initialize()
    if self.initialized then return end
    local addon = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not addon then
        error("TrinketMenu:Initialize() called before addon is ready")
        return
    end
    self.addon = addon
    self.db = addon.db1.profile.trinketMenu
    self.deferred, self.deferredOrder = {}, {}
    self.equipped = {}
    self.attempts, self.swapUntil = 0, 0
    self.idleSince = GetTime()

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", function(_, event, arg) TrinketMenu:OnEvent(event, arg) end)
    self.events = events

    self.initialized = true
    self:LoadSettings()
end

SoundAlerter.TrinketMenu = TrinketMenu
