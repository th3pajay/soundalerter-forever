SA_DRModel = {}

local Model = SA_DRModel

Model.RESET = 18
Model.STEPS = { 1, 0.5, 0.25 }
Model.MAX = #Model.STEPS
Model.MAX_AGE = 60
Model.ORDER = { "stun", "opener", "incap", "fear", "silence", "root", "horror", "cyclone" }

Model.CATEGORIES = {
    stun = { tag = "ST", name = "Stun", color = { 1, 0.48, 0.27 }, base = 5 },
    opener = { tag = "OP", name = "Opener stun", color = { 1, 0.72, 0.3 }, base = 4 },
    incap = { tag = "IN", name = "Incapacitate", color = { 0.78, 0.61, 1 }, base = 10 },
    fear = { tag = "FE", name = "Fear and disorient", color = { 0.72, 0.42, 1 }, base = 8 },
    silence = { tag = "SI", name = "Silence", color = { 0.48, 0.82, 1 }, base = 4 },
    root = { tag = "RO", name = "Root", color = { 0.36, 0.88, 0.54 }, base = 8 },
    horror = { tag = "HO", name = "Horror", color = { 1, 0.42, 0.69 }, base = 3 },
    cyclone = { tag = "CY", name = "Cyclone and banish", color = { 0.9, 0.9, 0.9 }, base = 6 },
}

Model.SEEDS = {
    stun = { 853, 5588, 5589, 10308, 408, 8643, 5211, 6798, 8983, 7922, 20253, 20614, 20615, 20549, 12809, 19577, 24394 },
    opener = { 1833, 9005, 9823, 9827 },
    incap = { 118, 12824, 12825, 12826, 28271, 28272, 6770, 2070, 11297, 1776, 1777, 8629, 11285, 11286, 2637, 18657, 18658, 3355, 14308, 14309, 20066, 19386, 24132, 24133, 19503 },
    fear = { 5782, 6213, 6215, 5484, 17928, 8122, 8124, 10888, 10890, 5246, 6358, 1513, 14326, 14327, 2094 },
    silence = { 15487, 18469, 18425, 24259, 18498 },
    root = { 122, 865, 6131, 10230, 339, 1062, 5195, 5196, 9852, 9853, 19185 },
    horror = { 6789, 17925, 17926 },
    cyclone = { 33786, 710, 18647 },
}

Model.LEVELS = {
    { 0.24, 0.86, 0.52 },
    { 1, 0.82, 0.24 },
    { 1, 0.3, 0.3 },
}

function Model.New()
    return { count = 0, version = 0 }
end

function Model.Expired(record, now)
    return record.count == 0 or (record.resetAt ~= nil and now >= record.resetAt)
end

function Model.Up(record, now)
    return record.count > 0 and (record.fadeAt == nil or now < record.fadeAt)
end

function Model.Apply(record, now, icon, expires, duration)
    if Model.Expired(record, now) then record.count = 0 end
    record.count = math.min(record.count + 1, Model.MAX)
    record.appliedAt, record.fadeAt, record.resetAt = now, nil, nil
    record.icon, record.expires, record.duration, record.estimate = icon, expires, duration, false
    record.version = record.version + 1
    return record.count
end

function Model.Hold(record, expires, duration)
    record.fadeAt, record.resetAt, record.estimate = nil, nil, false
    if expires then record.expires, record.duration = expires, duration end
    record.version = record.version + 1
end

function Model.Fade(record, now, reset)
    if record.count == 0 then return false end
    if record.fadeAt ~= nil and record.fadeAt <= now then return false end
    record.fadeAt, record.resetAt, record.estimate = now, now + reset, false
    record.version = record.version + 1
    return true
end

function Model.Lose(record, now, reset, base)
    if not Model.Up(record, now) or record.fadeAt ~= nil then return false end
    local at = record.expires
    local estimate = at == nil
    if estimate then at = record.appliedAt + base * (Model.STEPS[record.count] or 1) end
    record.fadeAt, record.resetAt, record.estimate = at, at + reset, estimate
    record.version = record.version + 1
    return true
end

function Model.Deadline(record, base)
    if record.count == 0 or record.fadeAt ~= nil or not record.appliedAt then return nil end
    local length = record.duration or base * (Model.STEPS[record.count] or 1)
    return record.appliedAt + math.min(Model.MAX_AGE, length * 2)
end

function Model.Cap(record, now, reset, base)
    local deadline = Model.Deadline(record, base)
    if not deadline or now < deadline then return false end
    record.fadeAt, record.resetAt, record.estimate = deadline, deadline + reset, true
    record.version = record.version + 1
    return true
end

function Model.Level(count)
    return Model.LEVELS[math.max(1, math.min(count, Model.MAX))]
end

function Model.NextChange(record, now)
    if record.count == 0 then return nil end
    if record.fadeAt and now < record.fadeAt then return record.fadeAt end
    return record.resetAt
end
