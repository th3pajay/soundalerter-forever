local Model = {}

Model.DAYS = 90
Model.DAY = 86400
Model.PACE_DAYS = 14
Model.BARS = 30
Model.RANGES = { 7, 30, 0 }
Model.CURRENCY = 1792
Model.SAMPLES = 600
Model.MERGE = 300
Model.CAP_SHOW = 0.6
Model.CAP_WARN = 0.9
Model.GOALS = 5
Model.GOAL_NAME = 40
Model.SPLIT = 2
Model.KILL_WINDOW = 1.5
Model.HONOR_FIELD = 7

local DAYS, DAY, SAMPLES, MERGE = Model.DAYS, Model.DAY, Model.SAMPLES, Model.MERGE
local floor = math.floor
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
    local sources = { gain, gainNoRank, award }
    for index = 1, 3 do
        local pattern = Model.Pattern(sources[index])
        if pattern then list[#list + 1] = pattern end
    end
    return list
end

function Model.Parse(patterns, message)
    if type(message) ~= "string" then return nil end
    for index = 1, #patterns do
        local amount = message:match(patterns[index])
        if amount then return tonumber(amount) end
    end
    local last = message:match("(%d+)%D*$")
    if last then return tonumber(last) end
    return nil
end

function Model.DayOf(at, offset)
    return floor((at + (offset or 0)) / DAY)
end

local function newWallet()
    return { at = {}, value = {}, head = 0, count = 0, day = {}, close = {} }
end

function Model.Store(saved)
    saved = saved or {}
    saved.day = saved.day or {}
    saved.bg = saved.bg or {}
    saved.world = saved.world or {}
    saved.before = saved.before or 0
    saved.gains = saved.gains or 0
    saved.best = saved.best or 0
    saved.wallet = saved.wallet or newWallet()
    saved.goals = saved.goals or {}
    local old = saved.goal
    if old then
        saved.goal = nil
        if type(old.target) == "number" and old.target > 0 then Model.AddGoal(saved, "Honor goal", old.target) end
    end
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

function Model.Record(store, at, value, day)
    local wallet = store.wallet
    local count, head = wallet.count, wallet.head
    local values, ats = wallet.value, wallet.at
    if count > 0 then
        local last = values[head]
        if last == value then return false end
        if count > 1 and at - ats[head] < MERGE then
            local before = values[(head - 2) % SAMPLES + 1]
            if (value > last) == (last > before) then
                values[head], ats[head] = value, at
                local slot = day % DAYS + 1
                wallet.day[slot], wallet.close[slot] = day, value
                return true
            end
        end
    end
    head = head % SAMPLES + 1
    ats[head], values[head] = at, value
    wallet.head = head
    if count < SAMPLES then wallet.count = count + 1 end
    local slot = day % DAYS + 1
    wallet.day[slot], wallet.close[slot] = day, value
    return true
end

function Model.Balance(store)
    local wallet = store and store.wallet
    if not wallet or wallet.count == 0 then return nil end
    return wallet.value[wallet.head]
end

function Model.NewSeries()
    return { at = {}, value = {}, count = 0, base = nil }
end

function Model.Series(store, from, offset, out)
    out = out or Model.NewSeries()
    offset = offset or 0
    local ats, values = out.at, out.value
    local count, base = 0, nil
    local wallet = store and store.wallet
    if wallet and wallet.count > 0 then
        local first = (wallet.head - wallet.count) % SAMPLES + 1
        local oldestDay = Model.DayOf(wallet.at[first], offset)
        local days, closes = wallet.day, wallet.close
        for day = oldestDay - DAYS + 1, oldestDay - 1 do
            local slot = day % DAYS + 1
            if days[slot] == day then
                local at = (day + 1) * DAY - offset - 1
                if from and at < from then
                    base = closes[slot]
                else
                    count = count + 1
                    ats[count], values[count] = at, closes[slot]
                end
            end
        end
        local wAt, wValue = wallet.at, wallet.value
        for step = 0, wallet.count - 1 do
            local index = (first - 1 + step) % SAMPLES + 1
            local at = wAt[index]
            if from and at < from then
                base = wValue[index]
            else
                count = count + 1
                ats[count], values[count] = at, wValue[index]
            end
        end
    end
    for extra = count + 1, out.count do ats[extra], values[extra] = nil, nil end
    out.count, out.base = count, base
    return out
end

function Model.ValueAt(series, at)
    local count = series.count
    if count == 0 or series.at[1] > at then return series.base end
    local low, high = 1, count
    while low < high do
        local mid = floor((low + high + 1) / 2)
        if series.at[mid] <= at then low = mid else high = mid - 1 end
    end
    return series.value[low]
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
    if record.split ~= Model.SPLIT then return honor, nil end
    local kills = record.kills
    kills = type(kills) == "number" and math.max(0, math.min(kills, honor)) or 0
    return honor, kills, honor - kills
end

function Model.NewKills()
    return { lineAt = nil, lineAmount = 0, killAt = nil, owed = 0 }
end

function Model.KillLine(kills, now, amount)
    if kills.owed > 0 and now - kills.killAt <= Model.KILL_WINDOW then
        kills.owed = kills.owed - 1
        return true
    end
    kills.owed = 0
    kills.lineAt, kills.lineAmount = now, amount
    return false
end

function Model.KillCount(kills, now, gained)
    if gained <= 0 then return 0 end
    local moved = 0
    if kills.lineAt and now - kills.lineAt <= Model.KILL_WINDOW then
        moved = kills.lineAmount
        gained = gained - 1
    end
    kills.lineAt, kills.lineAmount = nil, 0
    if gained > 0 then
        if not kills.killAt or now - kills.killAt > Model.KILL_WINDOW then kills.owed = 0 end
        kills.owed, kills.killAt = kills.owed + gained, now
    end
    return moved
end

function Model.Pace(store, today, days)
    days = days or Model.PACE_DAYS
    local since = store.since
    if not since or since > today then return nil end
    local count = math.min(days, today - since + 1)
    local sum = 0
    for day = today - count + 1, today do
        local bg, world = Model.DayTotal(store, day)
        sum = sum + bg + world
    end
    return sum / count, count
end

function Model.Cut(text, limit)
    if #text <= limit then return text end
    local stop = limit
    while stop > 0 do
        local byte = text:byte(stop + 1)
        if not byte or byte < 0x80 or byte >= 0xC0 then break end
        stop = stop - 1
    end
    return text:sub(1, stop)
end

function Model.AddGoal(store, name, cost)
    cost = tonumber(cost)
    if not cost or cost <= 0 then return false end
    cost = floor(cost + 0.5)
    local goals = store.goals
    if #goals >= Model.GOALS then return false end
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then name = Model.Short(cost) .. " honor" end
    name = Model.Cut(name, Model.GOAL_NAME)
    local index = #goals + 1
    while index > 1 and goals[index - 1].cost > cost do
        goals[index] = goals[index - 1]
        index = index - 1
    end
    goals[index] = { name = name, cost = cost }
    return true
end

function Model.RemoveGoal(store, index)
    local goals = store.goals
    if not goals[index] then return false end
    table.remove(goals, index)
    return true
end

function Model.GoalDays(balance, cost, mean)
    if balance >= cost then return 0 end
    if not mean or mean <= 0 then return nil end
    return math.ceil((cost - balance) / mean)
end

function Model.CapState(balance, cap)
    if not balance or not cap or cap <= 0 then return nil end
    return cap - balance, balance >= cap * Model.CAP_WARN
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

function Model.Comma(value)
    local text = tostring(floor((value or 0) + 0.5))
    local sign, digits = text:match("^(-?)(%d+)$")
    if not digits then return text end
    local head = #digits % 3
    local out = head > 0 and digits:sub(1, head) or ""
    for index = head + 1, #digits, 3 do
        out = out .. (out ~= "" and "," or "") .. digits:sub(index, index + 2)
    end
    return sign .. out
end

SA_HonorModel = Model
