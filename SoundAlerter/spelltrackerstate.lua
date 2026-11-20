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
    onPlate = { default = true, reload = true },
    lethalSkull = { default = false, reload = true },
}

local GLOBAL_KEYS = {
    locked = true,
    showTimerText = true,
    showBorderTimer = true,
    showCooldownText = true,
    showReadyText = true,
    deleteWithoutConfirm = true,
    animQuality = true,
    skullSize = true,
    skullArt = true,
    skullPop = true,
}

local PLATE_KEYS = {
    plateEnabled = true, plateSize = true, plateSpacing = true, plateOffset = true,
    plateFollowScale = true, plateShowIdle = true, plateMax = true, plateFallback = true,
}

function Settings.IsGlobalKey(key)
    return GLOBAL_KEYS[key] == true or PLATE_KEYS[key] == true
end

function Settings.IsPlateKey(key)
    return PLATE_KEYS[key] == true
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
    record.held = nil
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

TrackerState.PARK_LIMIT = 8

function TrackerState.New()
    return setmetatable({ records = {}, auraOwners = {}, knownDurations = nil, parked = {}, parkedCount = 0, spareBuckets = {}, spareTables = {} }, TrackerState)
end

local function takeTable(spare)
    local count = #spare
    local item = spare[count]
    if item then
        spare[count] = nil
        return item
    end
    return {}
end

local function bucketEnd(bucket)
    local latest = 0
    for _, entry in pairs(bucket) do
        if entry.expiration > latest then latest = entry.expiration end
    end
    return latest
end

function TrackerState:ReleaseBucket(key)
    local bucket = self.parked[key]
    if not bucket then return end
    self.parked[key] = nil
    self.parkedCount = self.parkedCount - 1
    for index, entry in pairs(bucket) do
        bucket[index] = nil
        entry.expiration, entry.duration = nil, nil
        self.spareBuckets[#self.spareBuckets + 1] = entry
    end
    self.spareTables[#self.spareTables + 1] = bucket
end

function TrackerState:PruneParked(now)
    for key, bucket in pairs(self.parked) do
        if bucketEnd(bucket) <= now then self:ReleaseBucket(key) end
    end
    while self.parkedCount > TrackerState.PARK_LIMIT do
        local soonestKey, soonestEnd
        for key, bucket in pairs(self.parked) do
            local finish = bucketEnd(bucket)
            if not soonestEnd or finish < soonestEnd then soonestKey, soonestEnd = key, finish end
        end
        self:ReleaseBucket(soonestKey)
    end
end

function TrackerState:Park(key, index, now)
    if key == nil then return false end
    local record = self.records[index]
    local expiration = record and record.predictedExpiration
    if not expiration or expiration <= now then return false end
    local bucket = self.parked[key]
    if not bucket then
        bucket = takeTable(self.spareTables)
        self.parked[key] = bucket
        self.parkedCount = self.parkedCount + 1
    end
    local entry = bucket[index]
    if not entry then
        entry = takeTable(self.spareBuckets)
        bucket[index] = entry
    end
    entry.expiration, entry.duration = expiration, record.predictedDuration
    self:PruneParked(now)
    return true
end

function TrackerState:Unpark(key, index, now)
    local bucket = key ~= nil and self.parked[key]
    local entry = bucket and bucket[index]
    if not entry then return nil end
    bucket[index] = nil
    local expiration, duration = entry.expiration, entry.duration
    entry.expiration, entry.duration = nil, nil
    self.spareBuckets[#self.spareBuckets + 1] = entry
    if next(bucket) == nil then
        self.parked[key] = nil
        self.parkedCount = self.parkedCount - 1
        self.spareTables[#self.spareTables + 1] = bucket
    end
    if expiration <= now then return nil end
    local record = self:Get(index)
    record.active = false
    record.predictedExpiration = expiration
    record.predictedDuration = duration
    return show(record, expiration, duration, false, true)
end

function TrackerState:DropParked(key)
    if key ~= nil then self:ReleaseBucket(key) end
end

function TrackerState:ParkedCount()
    return self.parkedCount
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

function TrackerState:Expiration(index)
    local record = self.records[index]
    return record and record.active and record.expiration or nil
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

    if record.held or (record.predictedExpiration and record.predictedExpiration > now) then
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

function TrackerState:IsHeld(index)
    local record = self.records[index]
    return record ~= nil and record.held == true
end

function TrackerState:Hold(index)
    local record = self:Get(index)
    clearPredicted(record)
    record.held = true
    return show(record, nil, nil, false, true)
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

local function releaseAura(owners, record)
    local instanceID = record.auraInstance
    if instanceID and owners[instanceID] == record then owners[instanceID] = nil end
    record.auraInstance = nil
end

function TrackerState:NoteAura(index, instanceID)
    local record = self:Get(index)
    releaseAura(self.auraOwners, record)
    record.auraInstance = instanceID
    self.auraOwners[instanceID] = record
end

function TrackerState:AuraRemoved(instanceID)
    local record = self.auraOwners[instanceID]
    if not record then return false end
    releaseAura(self.auraOwners, record)
    clearPredicted(record)
    return true
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
        readout.ready = (showReady and (not reading.isActive or reading.isOnGCD == true)) and true or false
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
    local removed = self.records[index]
    if removed then releaseAura(self.auraOwners, removed) end
    for i = index, count - 1 do
        self.records[i] = self.records[i + 1]
    end
    self.records[count] = nil
    for _, bucket in pairs(self.parked) do
        local dropped = bucket[index]
        if dropped then
            dropped.expiration, dropped.duration = nil, nil
            self.spareBuckets[#self.spareBuckets + 1] = dropped
        end
        for i = index, count - 1 do
            bucket[i] = bucket[i + 1]
        end
        bucket[count] = nil
    end
end

SA_TrackerState = TrackerState
end

do
local Lethal = {}

Lethal.SKULL_BAR = 1000
Lethal.POP_SCALE = 1.18
Lethal.POP_GROW = 0.12
Lethal.POP_SETTLE = 0.22
Lethal.POP_REST = 1.26
Lethal.WEIGHT_CAP = 120
Lethal.ART = {
    skull = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
    tomb = "Interface\\AddOns\\SoundAlerter\\Textures\\lethal_tomb",
    drop = "Interface\\AddOns\\SoundAlerter\\Textures\\lethal_drop",
}

function Lethal.DescRate(text)
    if type(text) ~= "string" then return nil end
    local amount, seconds = text:match("(%d+)%s*[%a ]-damage over (%d+%.?%d*) sec")
    amount, seconds = tonumber(amount), tonumber(seconds)
    if not amount or not seconds or seconds <= 0 or amount <= 0 then return nil end
    local direct = tonumber(text:match("for (%d+) damage and an additional"))
    if not direct then
        local low, high = text:match("for (%d+) to (%d+) [%a ]-damage and then an additional")
        if low and high then direct = (tonumber(low) + tonumber(high)) / 2 end
    end
    return amount / seconds, direct and amount / (amount + direct) or 1
end

function Lethal.Learn(rates, name, damage, seconds)
    if type(name) ~= "string" or type(damage) ~= "number" or type(seconds) ~= "number" or damage <= 0 or seconds <= 0 then return nil end
    local entry = rates[name]
    if not entry then
        entry = { damage = 0, seconds = 0 }
        rates[name] = entry
    end
    entry.damage, entry.seconds = entry.damage + damage, entry.seconds + seconds
    if entry.seconds > Lethal.WEIGHT_CAP then
        local scale = Lethal.WEIGHT_CAP / entry.seconds
        entry.damage, entry.seconds = entry.damage * scale, Lethal.WEIGHT_CAP
    end
    return entry.damage / entry.seconds
end

function Lethal.Rate(rates, name, fallback)
    local entry = rates and rates[name]
    if entry and entry.seconds > 0 then return entry.damage / entry.seconds end
    return fallback
end

function Lethal.MeterByName(spells, nameOf, out)
    for name in pairs(out) do out[name] = nil end
    if type(spells) ~= "table" then return out end
    for index = 1, #spells do
        local spell = spells[index]
        local spellID, amount = spell and spell.spellID, spell and spell.totalAmount
        if not issecretvalue(spellID) and not issecretvalue(amount) and type(spellID) == "number" and type(amount) == "number" then
            local name = nameOf(spellID)
            if name then out[name] = (out[name] or 0) + amount end
        end
    end
    return out
end

function Lethal.Remaining(rate, expiration, now)
    if not rate or not expiration or expiration <= now then return 0 end
    return rate * (expiration - now)
end

SA_TrackerLethal = Lethal
end
