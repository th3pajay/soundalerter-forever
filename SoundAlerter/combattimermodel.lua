local Model = {}

Model.HOT_MS = 2500
Model.WARM_MS = 1000
Model.DEFAULT_WINDOW_MS = 5000

local math_max, math_min = math.max, math.min
local string_format = string.format

function Model.New(windowMs)
    return {
        windowMs = windowMs or Model.DEFAULT_WINDOW_MS,
        inCombat = false,
        lastActivity = nil,
        dropAt = nil,
        driftSum = 0,
        driftCount = 0,
        lastDrift = nil,
    }
end

function Model.SetWindow(model, windowMs)
    model.windowMs = math_max(1, windowMs)
end

function Model.Enter(model, now)
    model.inCombat = true
    model.lastActivity = now
    model.dropAt = nil
end

function Model.Activity(model, now)
    if model.inCombat then
        model.lastActivity = now
    end
end

function Model.Remaining(model, now)
    if not model.inCombat then
        return 0
    end
    return math_max(0, model.windowMs - (now - model.lastActivity) * 1000)
end

function Model.State(model, now)
    if not model.inCombat then
        return model.dropAt and "free" or "idle"
    end
    if Model.Remaining(model, now) > 0 then
        return "counting"
    end
    return "waiting"
end

function Model.Regen(model, now)
    if not model.inCombat then
        return nil
    end
    local estimatedZero = model.lastActivity + model.windowMs / 1000
    local drift = now - estimatedZero
    model.driftSum = model.driftSum + drift
    model.driftCount = model.driftCount + 1
    model.lastDrift = drift
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

function Model.Tone(model, now)
    local state = Model.State(model, now)
    if state == "idle" or state == "free" then
        return "free"
    end
    if state == "waiting" then
        return "cool"
    end
    local remaining = Model.Remaining(model, now)
    if remaining > Model.HOT_MS then
        return "hot"
    end
    if remaining > Model.WARM_MS then
        return "warm"
    end
    return "cool"
end

function Model.Fraction(model, now)
    if not model.inCombat then
        return 0
    end
    return math_min(1, Model.Remaining(model, now) / model.windowMs)
end

function Model.Format(remainingMs, decimals)
    decimals = math_max(0, math_min(3, decimals or 3))
    return string_format("%." .. decimals .. "f", math_max(0, remainingMs) / 1000)
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
