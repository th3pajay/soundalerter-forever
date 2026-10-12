local Model = {}

Model.HOT_MS = 2500
Model.WARM_MS = 1000
Model.DEFAULT_WINDOW_MS = 5000
Model.SAMPLE_LIMIT = 20

local math_max, math_min = math.max, math.min
local string_format = string.format

function Model.New(windowMs)
    return {
        windowMs = windowMs or Model.DEFAULT_WINDOW_MS,
        inCombat = false,
        lastActivity = nil,
        lastKind = nil,
        dropAt = nil,
        driftSum = 0,
        driftCount = 0,
        lastDrift = nil,
        samples = {},
    }
end

function Model.SetWindow(model, windowMs)
    model.windowMs = math_max(1, windowMs)
end

function Model.Enter(model, now, synced)
    model.inCombat = true
    model.lastActivity = synced ~= false and now or nil
    model.lastKind = "enter"
    model.dropAt = nil
end

function Model.Activity(model, now, kind)
    if model.inCombat then
        model.lastActivity = now
        model.lastKind = kind or "combat"
    end
end

function Model.Remaining(model, now)
    if not model.inCombat or not model.lastActivity then
        return 0
    end
    return math_max(0, model.windowMs - (now - model.lastActivity) * 1000)
end

local function stateOf(model, remaining)
    if not model.inCombat then
        return model.dropAt and "free" or "idle"
    end
    if not model.lastActivity then
        return "unsynced"
    end
    if remaining > 0 then
        return "counting"
    end
    return "waiting"
end

local function toneOf(state, remaining)
    if state == "idle" or state == "free" then
        return "free"
    end
    if state ~= "counting" then
        return "cool"
    end
    if remaining > Model.HOT_MS then
        return "hot"
    end
    if remaining > Model.WARM_MS then
        return "warm"
    end
    return "cool"
end

function Model.State(model, now)
    return stateOf(model, Model.Remaining(model, now))
end

function Model.Tone(model, now)
    local remaining = Model.Remaining(model, now)
    return toneOf(stateOf(model, remaining), remaining)
end

function Model.Fraction(model, now)
    if not model.inCombat then
        return 0
    end
    return math_min(1, Model.Remaining(model, now) / model.windowMs)
end

function Model.Snapshot(model, now)
    local remaining = Model.Remaining(model, now)
    local state = stateOf(model, remaining)
    local fraction = model.inCombat and math_min(1, remaining / model.windowMs) or 0
    return state, remaining, toneOf(state, remaining), fraction
end

function Model.Regen(model, now, record)
    if not model.inCombat then
        return nil
    end
    local drift = nil
    if model.lastActivity and record ~= false then
        drift = now - (model.lastActivity + model.windowMs / 1000)
        model.driftSum = model.driftSum + drift
        model.driftCount = model.driftCount + 1
        model.lastDrift = drift
        local samples = model.samples
        samples[#samples + 1] = { gap = now - model.lastActivity, kind = model.lastKind }
        if #samples > Model.SAMPLE_LIMIT then
            table.remove(samples, 1)
        end
    end
    model.inCombat = false
    model.dropAt = now
    return drift
end

function Model.AverageDrift(model)
    if model.driftCount == 0 then
        return nil
    end
    return model.driftSum / model.driftCount
end

function Model.ResetDrift(model)
    model.driftSum = 0
    model.driftCount = 0
    model.lastDrift = nil
    model.samples = {}
end

local function median(sorted)
    local count = #sorted
    if count % 2 == 1 then
        return sorted[(count + 1) / 2]
    end
    return (sorted[count / 2] + sorted[count / 2 + 1]) / 2
end

function Model.GapReport(model)
    local byKind, kinds = {}, {}
    for _, sample in ipairs(model.samples) do
        local list = byKind[sample.kind]
        if not list then
            list = {}
            byKind[sample.kind] = list
            kinds[#kinds + 1] = sample.kind
        end
        list[#list + 1] = sample.gap
    end
    table.sort(kinds)
    local report = {}
    for _, kind in ipairs(kinds) do
        local gaps = byKind[kind]
        table.sort(gaps)
        report[#report + 1] = { kind = kind, count = #gaps, min = gaps[1], median = median(gaps), max = gaps[#gaps] }
    end
    return report
end

local FORMATS = { [0] = "%.0f", "%.1f", "%.2f", "%.3f" }

function Model.Format(remainingMs, decimals)
    decimals = math_max(0, math_min(3, decimals or 3))
    return string_format(FORMATS[decimals], math_max(0, remainingMs) / 1000)
end

function Model.FadeAlpha(model, now, fadeDelay, fadeTime, freeAlpha)
    if not model.dropAt then
        return freeAlpha
    end
    local since = now - model.dropAt
    if since <= fadeDelay then
        return 1
    end
    local progress = math_min(1, (since - fadeDelay) / fadeTime)
    return 1 + (freeAlpha - 1) * progress
end

SA_CombatTimerModel = Model
