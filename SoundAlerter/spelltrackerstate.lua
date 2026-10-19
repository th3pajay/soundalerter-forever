do
local Settings = {}

Settings.DEFAULT_ICON_SIZE = 48

local ICON_KEYS = {
    enabled = { default = true, reload = true },
    unit = { default = "player", reload = true },
    auraType = { default = "HELPFUL", reload = true },
    size = { default = Settings.DEFAULT_ICON_SIZE, reload = true },
    showWhenInactive = { default = false, reload = true },
    trackCooldown = { default = false, reload = true },
    cooldownTextSize = { default = 14, reload = true },
    auraDuration = { default = 0, reload = false },
}

local GLOBAL_KEYS = {
    locked = true,
    showTimerText = true,
    showBorderTimer = true,
    showCooldownText = true,
    showReadyText = true,
    deleteWithoutConfirm = true,
    animQuality = true,
}

function Settings.IsGlobalKey(key)
    return GLOBAL_KEYS[key] == true
end

function Settings.IconDefault(key)
    local spec = ICON_KEYS[key]
    return spec and spec.default
end

function Settings.NewIcon(fields)
    local icon = {}
    for key, spec in pairs(ICON_KEYS) do
        icon[key] = spec.default
    end
    for key, value in pairs(fields) do
        icon[key] = value
    end
    return icon
end

function Settings.Backfill(icon)
    for key, spec in pairs(ICON_KEYS) do
        if icon[key] == nil then
            icon[key] = spec.default
        end
    end
    return icon
end

function Settings.SetIcon(icon, key, value)
    local spec = ICON_KEYS[key]
    if not spec then
        error("SpellTracker icon setting - unknown key '" .. tostring(key) .. "'", 2)
    end
    icon[key] = value
    return spec.reload
end

SA_TrackerSettings = Settings
end

do
local Border = {}

Border.EXPIRING_SECONDS = 3

Border.COLORS = {
    IDLE = { 0.42, 0.45, 0.5 },
    HELPFUL = { 0.24, 0.86, 0.52 },
    HARMFUL = { 1, 0.35, 0.3 },
}

Border.GLOWS = {
    expiring = { 1, 0.35, 0.3, mode = "tint" },
    ready = { 0.24, 0.86, 0.52, mode = "steady" },
    cooldown = { 0.35, 0.66, 1, mode = "steady" },
}

function Border.BorderKey(auraType, active)
    if active and Border.COLORS[auraType] then
        return auraType
    end
    return "IDLE"
end

function Border.TimerMode(enabled, decision)
    if not enabled or not decision then
        return nil
    end
    if decision.expiration and decision.duration and decision.expiration - decision.duration > 0 then
        return "plain"
    end
    if not decision.expiration and decision.secret then
        return "secret"
    end
    return nil
end

function Border.TimerColor(auraType)
    return Border.COLORS[Border.BorderKey(auraType, true)]
end

function Border.GlowKey(active, remaining, readout)
    if active and remaining and remaining > 0 and remaining <= Border.EXPIRING_SECONDS then
        return "expiring"
    end
    if readout then
        if readout.ready and not active then
            return "ready"
        end
        if readout.numbers ~= "clear" then
            return "cooldown"
        end
    end
    return nil
end

SA_TrackerBorder = Border
end

do
local TrackerState = {}
TrackerState.__index = TrackerState

local GCD_THRESHOLD = 1.5

local HOLD = { action = "hold" }
local HIDE = { action = "hide" }

local function clearPredicted(record)
    record.predictedExpiration = nil
    record.predictedDuration = nil
end

local function show(record, expiration, duration, secret, predicted)
    local isNew = not record.active
    record.active = true
    record.expiration = expiration
    return {
        action = "show",
        expiration = expiration,
        duration = duration,
        secret = secret,
        predicted = predicted,
        isNew = isNew,
    }
end

function TrackerState.New()
    return setmetatable({ records = {}, knownDurations = nil }, TrackerState)
end

function TrackerState:SetKnownDurations(knownDurations)
    self.knownDurations = knownDurations
end

function TrackerState:Get(index)
    local record = self.records[index]
    if not record then
        record = { active = false }
        self.records[index] = record
    end
    return record
end

function TrackerState:IsActive(index)
    local record = self.records[index]
    return record ~= nil and record.active
end

function TrackerState:Remaining(index, now)
    local record = self.records[index]
    if record and record.active and record.expiration and record.expiration > 0 then
        return record.expiration - now
    end
    return nil
end

function TrackerState:CooldownReadout(index)
    local record = self.records[index]
    return record and record.cooldown
end

function TrackerState:Observe(index, observation, now)
    local record = self:Get(index)

    if observation and observation.kind == "real" then
        clearPredicted(record)
        local duration, expiration = observation.duration, observation.expiration
        if duration and expiration and duration > 0 and expiration > 0 then
            if self.knownDurations and observation.spellID then
                self.knownDurations[observation.spellID] = duration
            end
            return show(record, expiration, duration, false, false)
        end
        return show(record, nil, nil, false, false)
    end

    if observation and observation.kind == "secret" then
        clearPredicted(record)
        return show(record, nil, nil, true, false)
    end

    if record.predictedExpiration and record.predictedExpiration > now then
        return HOLD
    end

    self:Hide(index)
    return HIDE
end

function TrackerState:Predict(index, spellID, manualDuration, now)
    local duration
    if manualDuration and manualDuration > 0 then
        duration = manualDuration
    elseif self.knownDurations then
        duration = self.knownDurations[spellID]
    end
    if not duration or duration <= 0 then
        return nil
    end

    local record = self:Get(index)
    record.predictedExpiration = now + duration
    record.predictedDuration = duration
    return show(record, record.predictedExpiration, duration, false, true)
end

function TrackerState:Resume(index, now)
    local record = self.records[index]
    if record and record.predictedExpiration and record.predictedExpiration > now then
        return show(record, record.predictedExpiration, record.predictedDuration, false, true)
    end
    return nil
end

function TrackerState:ClearPredicted(index)
    local record = self.records[index]
    if record then
        clearPredicted(record)
    end
end

function TrackerState:ReadCooldown(index, reading, now, showReady)
    local record = self:Get(index)
    local readout = record.cooldown or {}
    record.cooldown = readout
    readout.numbers = "clear"
    readout.start = nil
    readout.duration = nil
    readout.ready = false

    if not reading then
        return readout
    end

    if reading.kind == "secret" then
        readout.numbers = "secret"
        readout.ready = (showReady and not reading.isActive) and true or false
        return readout
    end

    local start, duration = reading.start, reading.duration
    if start > 0 and duration > GCD_THRESHOLD then
        readout.numbers = "countdown"
        readout.start = start
        readout.duration = duration
        readout.ready = (showReady and duration - (now - start) <= 0) and true or false
    else
        readout.ready = showReady and true or false
    end
    return readout
end

function TrackerState:Hide(index)
    local record = self:Get(index)
    record.active = false
    record.expiration = nil
    clearPredicted(record)
end

function TrackerState:Remove(index, count)
    for i = index, count - 1 do
        self.records[i] = self.records[i + 1]
    end
    self.records[count] = nil
end

SA_TrackerState = TrackerState
end
