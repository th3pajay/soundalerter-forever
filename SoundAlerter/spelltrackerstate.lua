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
