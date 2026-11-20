local SoundAlerter = SoundAlerter
local SpeedMeter = {}

local BarUtils = SoundAlerter.BarUtils
local Plain = SA_COMPAT.Plain

local math_floor = math.floor
local math_abs = math.abs
local math_sqrt = math.sqrt
local string_format = string.format

local DEFAULT_Y = -150
local UPDATE_INTERVAL = 0.1
local IDLE_TICKS = 3
local GRAB_PADDING = 4
local BASE_RUN = 7
local BASE_SWIM = 4.722222
local WINDOW = 0.5
local WINDOW_SLOTS = 8
local JUMP_YARDS = 20
local MOVE_SPEED = 0.5
local SNAP_POINTS = 3
local DIM_ALPHA = 0.55
local FONT_PATH = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local SETTING_KEYS = {
    enabled = true, locked = true, PositionX = true, PositionY = true,
    scale = true, fontSize = true, hideAtBaseline = true, tintMounted = true,
    boostColor = true, slowColor = true, baseColor = true,
}

local WAKE_EVENTS = {
    "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "UPDATE_SHAPESHIFT_FORM",
    "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_ENTERING_WORLD",
}

local function usable(value)
    return type(value) == "number" and value > 0
end

local function Base(mode)
    return mode == "swim" and BASE_SWIM or BASE_RUN
end
SpeedMeter.Base = Base

function SpeedMeter.Pick(mode, current, run, flight, swim)
    if usable(current) then return current end
    if mode == "swim" then return swim end
    if mode == "flight" and usable(flight) then return flight end
    return run
end

function SpeedMeter.Classify(speed, mode, tintMounted)
    if not usable(speed) then return nil end
    local percent = math_floor(speed / Base(mode) * 100 + 0.5)
    local tint = "plain"
    if mode == "run" or mode == "swim" or (tintMounted and (mode == "mounted" or mode == "flight")) then
        if percent > 100 then
            tint = "boost"
        elseif percent < 100 then
            tint = "slow"
        else
            tint = "base"
        end
    end
    return percent, tint
end

function SpeedMeter.Snap(percent, anchor)
    if percent and anchor and math_abs(percent - anchor) <= SNAP_POINTS then return anchor end
    return percent
end

function SpeedMeter.NewTrack()
    return { x = {}, y = {}, t = {}, head = 0, count = 0, world = nil }
end

function SpeedMeter.ResetTrack(track)
    track.head, track.count, track.world = 0, 0, nil
end

function SpeedMeter.Measure(track, x, y, world, now)
    local xs, ys, ts = track.x, track.y, track.t
    if track.count > 0 then
        local last = track.head
        local dx, dy = x - xs[last], y - ys[last]
        if world ~= track.world or dx * dx + dy * dy > JUMP_YARDS * JUMP_YARDS then
            track.head, track.count = 0, 0
        end
    end
    local head = track.head % WINDOW_SLOTS + 1
    track.head, track.world = head, world
    xs[head], ys[head], ts[head] = x, y, now
    if track.count < WINDOW_SLOTS then track.count = track.count + 1 end
    local oldest = head
    for step = 1, track.count - 1 do
        oldest = (head - step - 1) % WINDOW_SLOTS + 1
        if now - ts[oldest] >= WINDOW then break end
    end
    local elapsed = now - ts[oldest]
    if elapsed < WINDOW * 0.6 then return nil end
    local dx, dy = x - xs[oldest], y - ys[oldest]
    return math_sqrt(dx * dx + dy * dy) / elapsed
end

local function flag(value)
    return Plain(value) == true
end

local function InWater()
    if flag(IsSwimming()) then return true end
    return IsSubmerged ~= nil and flag(IsSubmerged())
end

local function CurrentMode()
    if UnitOnTaxi ~= nil and flag(UnitOnTaxi("player")) then return "taxi" end
    if flag(IsFlying()) then return "flight" end
    if InWater() then return "swim" end
    if flag(IsMounted()) then return "mounted" end
    return "run"
end
SpeedMeter.CurrentMode = CurrentMode

local Classify, Pick, Snap, Measure, ResetTrack = SpeedMeter.Classify, SpeedMeter.Pick, SpeedMeter.Snap, SpeedMeter.Measure, SpeedMeter.ResetTrack

function SpeedMeter:ReadLive(mode, current, run, flight, swim)
    local percent, tint = Classify(Pick(mode, current, run, flight, swim), mode, self.db.tintMounted)
    if percent then
        self.anchors[mode] = percent
        self.known, self.knownTint = percent, tint
    end
    local alive = usable(current) or mode == "taxi" or (IsFalling ~= nil and flag(IsFalling()))
    return percent, tint, "live", alive
end

function SpeedMeter:ReadMeasured(mode)
    local reader = self.position
    local x, y, world
    if reader then x, y, world = reader() end
    local speed
    local now = GetTime()
    if x then
        speed = Measure(self.track, x, y, world, now)
    else
        ResetTrack(self.track)
    end
    local settled = self.moving and now - (self.movedAt or now) >= WINDOW
    if settled and speed and speed >= MOVE_SPEED then
        local percent, tint = Classify(speed, mode, self.db.tintMounted)
        percent = Snap(percent, self.anchors[mode])
        if percent then
            self.known, self.knownTint = percent, tint
            return percent, tint, "measured", true
        end
    end
    local filling = x ~= nil and speed == nil
    return self.known, self.knownTint, "last", self.moving or filling
end

function SpeedMeter:Read()
    local current, run, flight, swim = GetUnitSpeed("player")
    local mode = CurrentMode()
    run = Plain(run)
    self.hidden = run == nil
    if not self.hidden then
        return self:ReadLive(mode, Plain(current), run, Plain(flight), Plain(swim))
    end
    return self:ReadMeasured(mode)
end

function SpeedMeter:Probe()
    local current, run, flight, swim = GetUnitSpeed("player")
    local function show(value)
        if Plain(value) == nil and value ~= nil then return "secret" end
        return tostring(value)
    end
    self.addon:Print(string_format("Speed probe: current %s, run %s, flight %s, swim %s", show(current), show(run), show(flight), show(swim)))
    self.addon:Print(string_format("Speed probe: swimming %s, submerged %s, flying %s, mounted %s, taxi %s, falling %s",
        show(IsSwimming()), IsSubmerged and show(IsSubmerged()) or "missing", show(IsFlying()), show(IsMounted()),
        UnitOnTaxi and show(UnitOnTaxi("player")) or "missing", IsFalling and show(IsFalling()) or "missing"))
    local x, y = nil, nil
    if SoundAlerter.PlayerWorldPosition then x, y = SoundAlerter.PlayerWorldPosition() end
    self.addon:Print(string_format("Speed probe: position %s, last known %s", x and string_format("%.1f, %.1f", x, y) or "unreadable", tostring(self.known)))
    if not (self.initialized and self.db) then return end
    local percent, tint, route = self:Read()
    self.addon:Print(string_format("Speed probe: the meter shows %s (%s, %s, %s)", percent and (percent .. "%") or "--", CurrentMode(), tostring(tint), route))
end

function SpeedMeter:GetSettings()
    return self.db
end

function SpeedMeter:SetSetting(key, value)
    if not SETTING_KEYS[key] then
        error("SpeedMeter:SetSetting - unknown setting key '"..tostring(key).."'", 2)
    end
    self.db[key] = value
    self:LoadSettings()
end

local function OnUpdate(_, elapsed)
    local meter = SpeedMeter
    meter.elapsed = meter.elapsed + elapsed
    if meter.elapsed < UPDATE_INTERVAL then return end
    meter.elapsed = 0
    if meter:Render() then
        meter.idleTicks = 0
        return
    end
    meter.idleTicks = meter.idleTicks + 1
    if meter.idleTicks >= IDLE_TICKS then meter:Sleep() end
end

function SpeedMeter:Wake()
    if not self.attached or self.ticking then return end
    self.ticking = true
    self.idleTicks = 0
    self.elapsed = UPDATE_INTERVAL
    self.frame:SetScript("OnUpdate", OnUpdate)
end

function SpeedMeter:Sleep()
    if not self.ticking then return end
    self.ticking = false
    self.frame:SetScript("OnUpdate", nil)
    ResetTrack(self.track)
end

function SpeedMeter:OnEvent(event, unit)
    if event == "UNIT_AURA" then
        if unit ~= "player" or self.hidden then return end
    elseif event == "PLAYER_STARTED_MOVING" then
        self.moving = true
        self.movedAt = GetTime()
        self:Wake()
        return
    elseif event == "PLAYER_STOPPED_MOVING" then
        self.moving = false
    elseif event == "PLAYER_CONTROL_LOST" then
        self:Wake()
        return
    end
    if self.ticking or not self.attached then return end
    if self:Render() then self:Wake() end
end

function SpeedMeter:Attach()
    if self.attached then return end
    self.attached = true
    local events = self.events
    for index = 1, #WAKE_EVENTS do pcall(events.RegisterEvent, events, WAKE_EVENTS[index]) end
    if events.RegisterUnitEvent then
        events:RegisterUnitEvent("UNIT_AURA", "player")
    else
        events:RegisterEvent("UNIT_AURA")
    end
end

function SpeedMeter:Detach()
    if not self.attached then return end
    self:Sleep()
    self.attached = false
    self.events:UnregisterAllEvents()
end

function SpeedMeter:Render()
    local db, text = self.db, self.text
    if not db or not text then return false end

    local percent, tint, route, alive
    if not db.locked then
        percent, tint, route, alive = 100, "base", "live", false
    else
        percent, tint, route, alive = self:Read()
    end

    local last = self.last
    local dim = route == "last"
    local color = tint == "boost" and db.boostColor or tint == "slow" and db.slowColor or db.baseColor
    if last.percent ~= percent or last.dim ~= dim then
        last.percent, last.dim = percent, dim
        local label = percent and string_format(dim and "~%d%%" or "%d%%", percent) or "--"
        if last.label ~= label then
            last.label = label
            text:SetText(label)
        end
    end
    local alpha = dim and DIM_ALPHA or 1
    if last.alpha ~= alpha then
        last.alpha = alpha
        text:SetAlpha(alpha)
    end

    local visible = not (db.hideAtBaseline and db.locked and tint == "base")
    if last.visible ~= visible then
        last.visible = visible
        text:SetShown(visible)
    end
    if last.color ~= color then
        last.color = color
        text:SetTextColor(color.r, color.g, color.b)
    end
    return alive and true or false
end

function SpeedMeter:LoadSettings()
    local db, frame = self.db, self.frame
    if not db or not frame then return end

    self.last = {}
    frame:SetScale(db.scale)
    frame:SetSize(db.fontSize * 4, db.fontSize + GRAB_PADDING * 2)
    self.text:SetFont(FONT_PATH, db.fontSize, "OUTLINE")
    self.bg:SetShown(not db.locked)

    BarUtils:LoadPosition(frame, db, "", 0, DEFAULT_Y)
    BarUtils:UpdateVisibility(frame, db)

    if db.enabled and db.locked then
        self:Attach()
        if self:Render() then self:Wake() end
    else
        self:Detach()
        if db.enabled then self:Render() end
    end
end

function SpeedMeter:ResetPosition()
    if not self.db then return end
    self.db.PositionX = 0
    self.db.PositionY = DEFAULT_Y
    self:LoadSettings()
end

function SpeedMeter:OnProfileChanged()
    local addon = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not addon then return end

    self.addon = addon
    self.db = addon.db1.profile.speedMeter

    if self.initialized then
        self:LoadSettings()
    end
end

function SpeedMeter:Initialize()
    if self.initialized then return end

    local addon = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not addon then
        error("SpeedMeter:Initialize() called before addon is ready")
        return
    end

    self.addon = addon
    self.db = addon.db1.profile.speedMeter
    self.last = {}
    self.anchors = {}
    self.track = SpeedMeter.NewTrack()
    self.position = SoundAlerter.PlayerWorldPosition

    self.dragProxy = setmetatable({}, {
        __index = function(_, key)
            local db = SpeedMeter.db
            return db and db[key]
        end,
    })

    self.frame = BarUtils:CreateContainerFrame("SoundAlerterSpeedMeter", self.db.fontSize * 4, self.db.fontSize + GRAB_PADDING * 2, DEFAULT_Y, self.dragProxy, function()
        BarUtils:SavePosition(SpeedMeter.frame, SpeedMeter.db, "")
    end, false)

    self.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
    self.bg:SetColorTexture(0, 0, 0, 0.45)

    self.text = BarUtils:CreateFontString(self.frame, self.db.fontSize, "OUTLINE")
    self.text:ClearAllPoints()
    self.text:SetPoint("CENTER", self.frame, "CENTER", 0, 0)

    self.events = CreateFrame("Frame")
    self.events:SetScript("OnEvent", function(_, event, unit) SpeedMeter:OnEvent(event, unit) end)

    self.initialized = true
    self:LoadSettings()
end

local function meter()
    return SoundAlerter.SpeedMeter
end

local SPEED_SAMPLES = { { 130, "boostColor" }, { 100, "baseColor" }, { 60, "slowColor" } }
local SpeedPreview = { height = 56 }

function SpeedPreview.build(stage)
    local state = { labels = {} }
    for index = 1, #SPEED_SAMPLES do
        local label = stage:CreateFontString(nil, "OVERLAY")
        label:SetPoint("CENTER", stage, "CENTER", (index - 2) * 78, 0)
        state.labels[index] = label
    end
    return state
end

function SpeedPreview.update(state, settings)
    for index = 1, #SPEED_SAMPLES do
        local sample = SPEED_SAMPLES[index]
        local label = state.labels[index]
        local color = settings[sample[2]]
        label:SetFont(FONT_PATH, math_floor(math.min(30, settings.fontSize * settings.scale)), "OUTLINE")
        label:SetTextColor(color.r, color.g, color.b)
        label:SetText(string_format("%d%%", sample[1]))
    end
end

function SoundAlerter:BuildSpeedMeterOptions()
    local Page = SoundAlerter.Page
    return Page.Module({
        key = "SpeedMeter",
        title = "Speed Meter",
        icon = "Interface\\Icons\\Ability_Rogue_Sprint",
        desc = "Your movement speed as a percent of base run speed.",
        blurb = "Your real speed while you move, the speed you would move at while you stand. In combat the game hides it, so the meter measures how fast you move; a dimmed ~ number is the last one it could read.",
        order = 2.89,
        module = meter,
        defaults = function() return dbDefaults.profile.speedMeter end,
        summary = function(settings)
            return Page.Summary(settings,
                settings.locked and "locked" or "unlocked, drag to move",
                settings.hideAtBaseline and "hidden at base speed" or "always shown")
        end,
        preview = SpeedPreview,
        lock = {
            key = "locked",
            hint = "Unlocked: drag the meter. A 100% preview shows while unlocked.",
            reset = function()
                local active = meter()
                if active then active:ResetPosition() end
            end,
        },
        rows = {
            Page.Toggle("hideAtBaseline", "Hide at base speed", "Hide the number at exactly 100% on foot or swimming, so it only shows when something changes your speed. Walking, slows and boosts still show.", false, "General"),
            Page.Range("fontSize", "Font size", "Size of the number.", 8, 40, 1, false, "Look", " px"),
            Page.Color("boostColor", "Boosted color", "Above 100% on foot or swimming.", false, "Look"),
            Page.Color("slowColor", "Slowed color", "Below 100% on foot or swimming, walking included.", false, "Look"),
            Page.Toggle("tintMounted", "Tint mounted speed", "Colour the number while mounted or flying too, against base run speed. Off keeps it in the normal colour there.", true, "Look"),
            Page.Range("scale", "Scale", "Overall size.", 0.5, 3, 0.05, true, "Look", "x"),
            Page.Color("baseColor", "Normal color", "Exactly 100%, mounted, flying, on a flight path, or no reading.", true, "Look"),
        },
    })
end

SoundAlerter.SpeedMeter = SpeedMeter
