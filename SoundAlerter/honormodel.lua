local Model = {}

Model.DAYS = 90
Model.DAY = 86400
Model.PACE_DAYS = 14
Model.BARS = 30
Model.BAND_Z = 1.28
Model.BAND_FLOOR = 0.3
Model.RANGES = { 7, 30, 0 }

Model.STEP_RECORD, Model.STEP_BG, Model.STEP_WORLD = 1, 2, 3
Model.HONOR_FIELD = 7

local DAYS, DAY = Model.DAYS, Model.DAY
local floor = math.floor
local STEP_RECORD, STEP_BG, STEP_WORLD = Model.STEP_RECORD, Model.STEP_BG, Model.STEP_WORLD
local HONOR_FIELD = Model.HONOR_FIELD

function Model.Pattern(format)
    if type(format) ~= "string" or not format:find("%d", 1, true) and not format:find("%%%d+%$d") then return nil end
    local text = format:gsub("%%%d+%$", "%%")
    text = text:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    text = text:gsub("%%d", "(%%d+)")
    text = text:gsub("%%s", ".-")
    return "^" .. text .. "$"
end

function Model.Patterns(gain, gainNoRank, award)
    local list = {}
    local sources = { { gain, true }, { gainNoRank, true }, { award, false } }
    for index = 1, #sources do
        local pattern = Model.Pattern(sources[index][1])
        if pattern then list[#list + 1] = { pattern, sources[index][2] } end
    end
    return list
end

function Model.Parse(patterns, message)
    if type(message) ~= "string" then return nil end
    for index = 1, #patterns do
        local entry = patterns[index]
        local amount = message:match(entry[1])
        if amount then return tonumber(amount), entry[2] end
    end
    local last = message:match("(%d+)%D*$")
    if last then return tonumber(last), true end
    return nil
end

function Model.DayOf(at, offset)
    return floor((at + (offset or 0)) / DAY)
end

function Model.Store(saved)
    saved = saved or {}
    saved.day = saved.day or {}
    saved.bg = saved.bg or {}
    saved.world = saved.world or {}
    saved.before = saved.before or 0
    saved.gains = saved.gains or 0
    saved.best = saved.best or 0
    return saved
end

local function slotFor(store, day)
    local slot = day % DAYS + 1
    local held = store.day[slot]
    if held ~= day and (held == nil or held < day) then
        if held then store.before = store.before + (store.bg[slot] or 0) + (store.world[slot] or 0) end
        store.day[slot], store.bg[slot], store.world[slot] = day, 0, 0
    end
    return slot
end

function Model.Add(store, day, amount, world)
    if type(amount) ~= "number" or amount == 0 then return false end
    local slot = slotFor(store, day)
    if world then
        store.world[slot] = math.max(0, store.world[slot] + amount)
    else
        store.bg[slot] = math.max(0, store.bg[slot] + amount)
    end
    store.gains = math.max(0, store.gains + amount)
    if not store.since or day < store.since then store.since = day end
    return true
end

function Model.DayTotal(store, day)
    local slot = day % DAYS + 1
    if store.day[slot] ~= day then return 0, 0 end
    return store.bg[slot] or 0, store.world[slot] or 0
end

function Model.Settle(store, day, honor, seen)
    if type(honor) ~= "number" then return false end
    if honor > store.best then store.best = honor end
    return Model.Add(store, day, honor - (seen or 0), false)
end

local function honorOf(record)
    return record.me and record.me[HONOR_FIELD] or 0
end
Model.HonorOf = honorOf

local function push(out, count, at, value, kind, record)
    count = count + 1
    out.at[count], out.value[count], out.kind[count], out.record[count] = at, value, kind, record or false
    return count
end

function Model.NewSteps()
    return { at = {}, value = {}, kind = {}, record = {}, count = 0, base = 0, total = 0 }
end

function Model.Steps(store, history, fromDay, today, offset, now, out)
    out = out or Model.NewSteps()
    offset = offset or 0
    local base = 0
    if fromDay == nil then
        base = store.before
        local oldest = today - DAYS + 1
        for slot = 1, DAYS do
            local held = store.day[slot]
            if held and held < oldest then base = base + (store.bg[slot] or 0) + (store.world[slot] or 0) end
        end
        fromDay = oldest
        local index = history and #history or 0
        while index > 0 do
            local day = Model.DayOf(history[index].at or 0, offset)
            if day < fromDay then
                if not store.since or day < store.since then base = base + honorOf(history[index]) end
            else
                break
            end
            index = index - 1
        end
    end
    local count = 0
    local index = history and #history or 0
    while index > 0 and Model.DayOf(history[index].at or 0, offset) < fromDay do index = index - 1 end
    local run = base
    for day = fromDay, today do
        local recorded = 0
        while index > 0 do
            local record = history[index]
            local at = record.at or 0
            if Model.DayOf(at, offset) ~= day then break end
            local value = honorOf(record)
            recorded = recorded + value
            run = run + value
            count = push(out, count, at, run, STEP_RECORD, record)
            index = index - 1
        end
        local bg, world = Model.DayTotal(store, day)
        local close = math.min(now, (day + 1) * DAY - offset - 1)
        local rest = bg - recorded
        if rest > 0 then
            run = run + rest
            count = push(out, count, close, run, STEP_BG)
        end
        if world > 0 then
            run = run + world
            count = push(out, count, close, run, STEP_WORLD)
        end
    end
    for extra = count + 1, out.count do
        out.at[extra], out.value[extra], out.kind[extra], out.record[extra] = nil, nil, nil, nil
    end
    out.count, out.base, out.total = count, base, run
    out.from = fromDay * DAY - offset
    return out
end

function Model.Bars(history, map, limit, out)
    out = out or {}
    for index = #out, 1, -1 do out[index] = nil end
    limit = limit or Model.BARS
    if not history then return out end
    for index = 1, #history do
        local record = history[index]
        if map == nil or map == "all" or record.map == map then
            out[#out + 1] = record
            if #out >= limit then break end
        end
    end
    return out
end

function Model.Split(record)
    local honor = honorOf(record)
    local kills = record.kills
    if type(kills) ~= "number" or kills <= 0 then return honor, nil end
    kills = math.min(kills, honor)
    return honor, kills, honor - kills
end

function Model.Pace(store, today, days)
    days = days or Model.PACE_DAYS
    local since = store.since
    if not since or since > today then return nil end
    local count = math.min(days, today - since + 1)
    local sum, squares = 0, 0
    for day = today - count + 1, today do
        local bg, world = Model.DayTotal(store, day)
        local value = bg + world
        sum = sum + value
        squares = squares + value * value
    end
    local mean = sum / count
    local variance = count > 1 and math.max(0, (squares - count * mean * mean) / (count - 1)) or 0
    return mean, math.sqrt(variance), count
end

function Model.Band(left, mean, deviation)
    if not mean or mean <= 0 then return nil end
    if left <= 0 then return 0, 0, 0 end
    local eta = left / mean
    local spread = Model.BAND_Z * (deviation or 0) / math.sqrt(math.max(eta, 1))
    local fast = left / (mean + spread)
    local slow = left / math.max(mean - spread, mean * Model.BAND_FLOOR)
    return eta, fast, slow
end

function Model.SetGoal(store, target)
    target = tonumber(target)
    if not target or target <= 0 then
        store.goal = nil
        return nil
    end
    target = floor(target + 0.5)
    if store.goal then
        store.goal.target = target
    else
        store.goal = { target = target, start = store.gains }
    end
    return store.goal
end

function Model.ResetGoal(store)
    if store.goal then store.goal.start = store.gains end
end

function Model.Goal(store)
    local goal = store and store.goal
    if not goal or not goal.target then return nil end
    local have = math.max(0, math.min(goal.target, store.gains - (goal.start or 0)))
    return have, goal.target, goal.target - have
end

function Model.Summary(store, history, today, offset, out)
    out = out or {}
    local bg, world = Model.DayTotal(store, today)
    local todaySum, week = bg + world, 0
    for day = today - 6, today do
        local b, w = Model.DayTotal(store, day)
        week = week + b + w
    end
    local since = store.since or (today + 1)
    local honor, seconds, n, best = 0, 0, 0, store.best or 0
    if history then
        for index = 1, #history do
            local record = history[index]
            local value = honorOf(record)
            if value > best then best = value end
            if n < Model.BARS then
                n = n + 1
                honor = honor + value
                seconds = seconds + (record.length or 0)
            end
            local day = Model.DayOf(record.at or 0, offset)
            if day < since then
                if day == today then todaySum = todaySum + value end
                if day > today - 7 then week = week + value end
            end
        end
    end
    out.today, out.week, out.best = todaySum, week, best
    out.perMatch = n > 0 and honor / n or nil
    out.perHour = seconds > 0 and honor / (seconds / 3600) or nil
    out.matches = n
    return out
end

function Model.Nice(top)
    if not top or top <= 0 then return 1, 1 end
    local power = 10 ^ floor(math.log10(top))
    local steps = { 1, 2, 2.5, 5, 10 }
    for index = 1, #steps do
        local step = steps[index] * power
        if step * 4 >= top then return step, math.ceil(top / step) * step end
    end
    return 10 * power, math.ceil(top / (10 * power)) * 10 * power
end

function Model.Short(value)
    value = value or 0
    if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
    if value >= 10000 then return string.format("%.1fk", value / 1000) end
    return tostring(floor(value + 0.5))
end

SA_HonorModel = Model
