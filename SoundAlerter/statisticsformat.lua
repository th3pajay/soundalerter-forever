local Format = {}

local GOLD = "|cffFFD700"
local GREEN = "|cff00FF00"
local GREY = "|cff888888"
local WHITE = "|cffFFFFFF"
local RESET = "|r"

local DANGER_HIGH = 5
local DANGER_MEDIUM = 3


local ROW_BAR_WIDTH = 110
local ROW_BAR_HEIGHT = 8
local NAME_LIMIT = 22

local TREND_MARKS = {
    increasing = "|cff00FF00+|r",
    decreasing = "|cffFF4040-|r",
    stable = "|cff888888=|r",
}

Format.CATEGORIES = {
    { key = "spellAlerts", label = "Spell alerts", color = { 90, 168, 255 } },
    { key = "proximityAlerts", label = "Proximity", color = { 61, 220, 132 } },
    { key = "trinketAlerts", label = "Trinkets", color = { 255, 176, 32 } },
    { key = "flagAlerts", label = "Flags", color = { 199, 139, 255 } },
    { key = "interruptAlerts", label = "Interrupts", color = { 255, 107, 107 } },
    { key = "awarenessAlerts", label = "Awareness", color = { 255, 120, 120 } },
    { key = "lossOfControlAlerts", label = "Loss of control", color = { 120, 190, 255 } },
    { key = "watchlistAlerts", label = "Watchlist", color = { 255, 214, 102 } },
    { key = "chatAlerts", label = "Chat", color = { 160, 160, 190 } },
    { key = "noticeAlerts", label = "Notices", color = { 140, 220, 200 } },
}

Format.ZONES = {
    { key = "arena", label = "Arena", color = { 255, 125, 107 } },
    { key = "battleground", label = "Battleground", color = { 107, 208, 255 } },
    { key = "worldPvP", label = "World PvP", color = { 230, 195, 77 } },
}

Format.ClassColor = function()
    return 255, 255, 255
end

local function colorHex(r, g, b)
    return string.format("|cff%02x%02x%02x", r, g, b)
end

local function truncate(text, limit)
    text = text or "Unknown"
    if #text <= limit then return text end
    return text:sub(1, limit - 2) .. ".."
end

local function className(class)
    if not class or class == "UNKNOWN" then return "Unknown" end
    return class:sub(1, 1):upper() .. class:sub(2):lower()
end

Format.ClassName = className

local function rounded(value)
    return math.floor((value or 0) + 0.5)
end

function Format.Number(value)
    local text = tostring(rounded(value))
    local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if formatted:sub(1, 1) == "," then formatted = formatted:sub(2) end
    return formatted
end

function Format.Percent(value, total)
    if not total or total <= 0 then return 0 end
    return rounded(value / total * 100)
end

function Format.Duration(minutes)
    minutes = math.floor(minutes or 0)
    if minutes >= 60 then
        return string.format("%dh %dm", math.floor(minutes / 60), minutes % 60)
    end
    return string.format("%d min", minutes)
end

function Format.Bar(width, height, r, g, b)
    if width < 1 then return "" end
    return string.format("|TInterface\\Buttons\\WHITE8X8:%d:%d:0:0:8:8:0:8:0:8:%d:%d:%d|t", height, width, r, g, b)
end

function Format.Kpi(overview)
    local function value(text)
        return GOLD .. text .. RESET
    end

    return value(Format.Number(overview.sessionTotal)) .. " session   " ..
        value(string.format("%.1f", overview.perMinute)) .. " /min   " ..
        value(Format.Duration(overview.minutes)) .. "      " ..
        value(Format.Number(overview.allTimeTotal)) .. " all-time   " ..
        value(Format.Number(overview.sessions)) .. " sessions   " ..
        value(Format.Number(overview.avgPerSession)) .. " avg"
end

local function rowBar(value, maximum, r, g, b)
    if maximum <= 0 then return "" end
    local width = math.max(1, math.floor(value / maximum * ROW_BAR_WIDTH + 0.5))
    return Format.Bar(width, ROW_BAR_HEIGHT, r, g, b)
end

local function rank(position)
    return GREY .. string.format("%2d", position) .. RESET
end

function Format.SpellRows(list, limit)
    if not list or #list == 0 then
        return GREY .. "No spell alerts tracked yet." .. RESET
    end

    local count = math.min(limit, #list)
    local maximum = list[1].count
    for i = 2, count do
        if list[i].count > maximum then maximum = list[i].count end
    end

    local rows = {}
    for i = 1, count do
        local spell = list[i]
        rows[i] = rank(i) .. "  " .. rowBar(spell.count, maximum, 90, 168, 255) ..
            "  " .. GREEN .. Format.Number(spell.count) .. RESET ..
            GREY .. " " .. rounded(spell.percentage) .. "%" .. RESET ..
            "  " .. WHITE .. truncate(spell.name, NAME_LIMIT) .. RESET ..
            "  " .. (TREND_MARKS[spell.trend] or TREND_MARKS.stable) ..
            "  " .. GREY .. (spell.topZone or "N/A") .. RESET
    end
    return table.concat(rows, "\n")
end

function Format.EnemyRows(list, limit)
    if not list or #list == 0 then
        return GREY .. "No enemy players tracked yet." .. RESET
    end

    local count = math.min(limit, #list)
    local rows = {}
    for i = 1, count do
        local enemy = list[i]
        local r, g, b = Format.ClassColor(enemy.class)
        rows[i] = rank(i) .. "  " .. colorHex(r, g, b) .. truncate(enemy.name, NAME_LIMIT) .. RESET ..
            "  " .. GREY .. className(enemy.class) .. RESET ..
            "  " .. GREEN .. Format.Number(enemy.alerts) .. RESET ..
            GREY .. " " .. rounded(enemy.percentage) .. "%" .. RESET ..
            "  " .. GREY .. (enemy.topZone or "N/A") .. RESET
    end
    return table.concat(rows, "\n")
end

function Format.ClassRows(list, limit)
    if not list or #list == 0 then
        return GREY .. "No class data tracked yet." .. RESET
    end

    local count = math.min(limit, #list)
    local maximum = list[1].alerts
    for i = 2, count do
        if list[i].alerts > maximum then maximum = list[i].alerts end
    end

    local rows = {}
    for i = 1, count do
        local entry = list[i]
        local r, g, b = Format.ClassColor(entry.class)
        rows[i] = rowBar(entry.alerts, maximum, r, g, b) ..
            "  " .. colorHex(r, g, b) .. className(entry.class) .. RESET ..
            "  " .. GREEN .. Format.Number(entry.alerts) .. RESET ..
            GREY .. " " .. rounded(entry.percentage) .. "%" .. RESET ..
            "  " .. entry.players .. " players" ..
            GREY .. "  " .. string.format("%.0f", entry.avgPerPlayer or 0) .. " each" .. RESET
    end
    return table.concat(rows, "\n")
end

local ACTIVITY_DAYS = 14
local MAX_RIVALS = 6
local MAX_VISITORS = 3
local MAX_MOVERS = 2
local MAX_SENDERS = 3

function Format.NewActivity()
    local days, hours = {}, {}
    for index = 1, ACTIVITY_DAYS do days[index] = 0 end
    for index = 1, 24 do hours[index] = 0 end
    return { day = 0, days = days, hours = hours }
end

local function advanceActivity(activity, day)
    local known = activity.day or 0
    if known == 0 then
        activity.day = day
        return
    end
    local shift = day - known
    if shift <= 0 then return end
    local days = activity.days
    if shift >= ACTIVITY_DAYS then
        for index = 1, ACTIVITY_DAYS do days[index] = 0 end
    else
        for index = ACTIVITY_DAYS, shift + 1, -1 do days[index] = days[index - shift] end
        for index = 1, shift do days[index] = 0 end
    end
    activity.day = day
end

function Format.ActivityRecord(activity, day, hour)
    advanceActivity(activity, day)
    activity.days[1] = activity.days[1] + 1
    local slot = math.max(0, math.min(23, math.floor(hour or 0))) + 1
    activity.hours[slot] = activity.hours[slot] + 1
end

function Format.ActivityDays(activity, day)
    local out = {}
    local shift = day - (activity and activity.day or day)
    if shift < 0 then shift = 0 end
    for position = 1, ACTIVITY_DAYS do
        local source = ACTIVITY_DAYS - position + 1 - shift
        out[position] = (activity and activity.days[source]) or 0
    end
    return out
end

function Format.Ago(now, at)
    if not at or at <= 0 then return "never" end
    local seconds = math.max(0, (now or at) - at)
    if seconds < 90 then return "just now" end
    if seconds < 5400 then return string.format("%d min ago", math.floor(seconds / 60 + 0.5)) end
    if seconds < 129600 then return string.format("%d h ago", math.floor(seconds / 3600 + 0.5)) end
    return string.format("%d d ago", math.floor(seconds / 86400 + 0.5))
end

local function dangerLabel(value)
    if value > DANGER_HIGH then return "High", { 255, 92, 92 } end
    if value > DANGER_MEDIUM then return "Medium", { 255, 176, 32 } end
    return "Low", { 61, 220, 132 }
end

local function sumOf(values)
    local total = 0
    for index = 1, #values do total = total + values[index] end
    return total
end

local function peakIndex(values)
    local best, bestIndex = 0, nil
    for index = 1, #values do
        if values[index] > best then best, bestIndex = values[index], index end
    end
    return bestIndex, best
end

local function sharePair(sent, received)
    return "sent " .. GOLD .. Format.Number(sent) .. RESET .. "   heard " .. GOLD .. Format.Number(received) .. RESET
end

function Format.PanelModel(data)
    local model = { now = {}, trends = {}, rivals = {} }
    local sessionTotal = data.sessionTotal or 0
    local sessions = data.sessions or 0
    local perSession = sessions > 0 and (data.allTotal or 0) / sessions or 0

    model.now.tiles = {
        { value = Format.Number(sessionTotal), caption = "this session", hot = sessionTotal > 0 },
        { value = string.format("%.1f", data.perMinute or 0), caption = "per minute" },
        { value = Format.Duration(data.minutes), caption = "session time" },
        { value = "#" .. Format.Number(data.sessionNumber or 0), caption = "of " .. Format.Number(sessions) .. " sessions" },
    }
    local scale = math.max(sessionTotal, perSession, 1)
    model.now.versus = {
        { label = "This session", value = Format.Number(sessionTotal), fraction = sessionTotal / scale },
        { label = "Typical session", value = string.format("%.1f", perSession), fraction = perSession / scale },
    }

    local party = data.party or {}
    model.now.party = {
        session = sharePair(party.sessionSent or 0, party.sessionReceived or 0),
        allTime = sharePair(party.allSent or 0, party.allReceived or 0),
    }
    local senders = {}
    for index = 1, math.min(MAX_SENDERS, #(party.senders or {})) do
        senders[index] = party.senders[index][1] .. " " .. Format.Number(party.senders[index][2])
    end
    model.now.party.senders = #senders > 0 and ("Most helpful: " .. table.concat(senders, ", ")) or "Nobody has shared an alert with you yet."
    local sending = party.sending and "on" or "off"
    local receiving = party.receiving and "on" or "off"
    model.now.party.status = "Sharing " .. sending .. ", hearing " .. receiving

    local last = data.lastEnemy
    model.now.last = last and { name = last.name, class = last.class, when = Format.Ago(data.now, last.last) } or nil

    local days = data.days or {}
    local dayTotal = sumOf(days)
    local _, dayPeak = peakIndex(days)
    model.trends.days = { values = days, empty = dayTotal == 0, total = dayTotal, peak = dayPeak or 0 }
    local hours = data.hours or {}
    local hourSlot = peakIndex(hours)
    model.trends.hours = { values = hours, empty = sumOf(hours) == 0, peak = hourSlot and string.format("%02d:00", hourSlot - 1) or nil }

    local rising, falling = {}, {}
    for _, spell in ipairs(data.spells or {}) do
        local last_, average = spell.last or 0, spell.avg or 0
        if spell.direction == "increasing" then
            rising[#rising + 1] = { name = spell.name, now = last_, average = average, delta = last_ - average }
        elseif spell.direction == "decreasing" then
            falling[#falling + 1] = { name = spell.name, now = last_, average = average, delta = average - last_ }
        end
    end
    table.sort(rising, function(a, b) return a.delta > b.delta end)
    table.sort(falling, function(a, b) return a.delta > b.delta end)
    local movers = {}
    for index = 1, math.min(MAX_MOVERS, #rising) do
        local entry = rising[index]
        movers[#movers + 1] = { sign = "+", name = entry.name, text = string.format("%d vs %.0f avg", entry.now, entry.average), color = { 61, 220, 132 } }
    end
    for index = 1, math.min(MAX_MOVERS, #falling) do
        local entry = falling[index]
        movers[#movers + 1] = { sign = "-", name = entry.name, text = string.format("%d vs %.0f avg", entry.now, entry.average), color = { 255, 92, 92 } }
    end
    model.trends.movers = movers

    local enemies = data.enemies or {}
    local rows = {}
    local maximum = 0
    for index = 1, math.min(MAX_RIVALS, #enemies) do
        if enemies[index].alerts > maximum then maximum = enemies[index].alerts end
    end
    for index = 1, math.min(MAX_RIVALS, #enemies) do
        local enemy = enemies[index]
        local label, color = dangerLabel(enemy.danger or 0)
        rows[index] = {
            name = enemy.name, class = enemy.class, danger = label, dangerColor = color,
            value = Format.Number(enemy.alerts) .. " - " .. Format.Number(enemy.encounters or 0) .. "x",
            fraction = maximum > 0 and enemy.alerts / maximum or 0,
        }
    end
    model.rivals.rows = rows

    local visitors = {}
    for _, entry in ipairs(data.classes or {}) do
        if (entry.players or 0) > 0 then
            visitors[#visitors + 1] = { class = entry.class, ratio = entry.alerts / entry.players, players = entry.players }
        end
    end
    table.sort(visitors, function(a, b)
        if a.ratio ~= b.ratio then return a.ratio > b.ratio end
        return a.class < b.class
    end)
    local classes = {}
    for index = 1, math.min(MAX_VISITORS, #visitors) do
        local entry = visitors[index]
        classes[index] = { class = entry.class, text = string.format("%.2f each", entry.ratio), players = entry.players }
    end
    model.rivals.classes = classes
    return model
end

local DASH_TOP = 3

local function plainCount(value)
    return value
end

local function ranked(map, nameOf, countOf)
    local list, seen = {}, 0
    countOf = countOf or plainCount
    for key, value in pairs(map or {}) do
        local count = countOf(value)
        if type(count) == "number" and count > 0 then
            seen = seen + 1
            local name = nameOf(key)
            local at = #list + 1
            for index = 1, #list do
                local other = list[index]
                if count > other.count or (count == other.count and name < other.name) then
                    at = index
                    break
                end
            end
            if at <= DASH_TOP then
                table.insert(list, at, { key = key, name = name, count = count })
                list[DASH_TOP + 1] = nil
            end
        end
    end
    return list, seen
end

local function shareText(value, total)
    return Format.Percent(value, total) .. "%"
end

function Format.Dashboard(input)
    local scope = (input.mode == "session" and input.session or input.allTime) or {}
    local session, allTime = input.session or {}, input.allTime or {}
    local model = { mode = input.mode, tiles = {}, mix = { segments = {}, top = {}, total = 0 }, spells = {}, enemies = {}, zones = {} }

    local mixTotal = 0
    for _, category in ipairs(Format.CATEGORIES) do
        local value = (scope.byCategory or {})[category.key] or 0
        if value > 0 then
            model.mix.segments[#model.mix.segments + 1] = { label = category.label, value = value, color = category.color }
            mixTotal = mixTotal + value
        end
    end
    model.mix.total = mixTotal
    local order = {}
    for index, segment in ipairs(model.mix.segments) do order[index] = segment end
    table.sort(order, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.label < b.label
    end)
    for index = 1, math.min(DASH_TOP, #order) do
        local segment = order[index]
        model.mix.top[index] = { label = segment.label, value = segment.value, color = segment.color, share = shareText(segment.value, mixTotal) }
    end

    local spellName = input.spellName or function() end
    local spells, spellCount = ranked(scope.spells, function(id) return spellName(id) or ("Spell " .. tostring(id)) end, scope.spellCount)
    model.spellCount = spellCount
    for index = 1, math.min(DASH_TOP, #spells) do model.spells[index] = { id = spells[index].key, name = spells[index].name, count = spells[index].count } end

    local classOf = input.classOf or function() end
    local enemies, enemyCount = ranked(scope.enemies, tostring, scope.enemyCount)
    model.enemyCount = enemyCount
    for index = 1, math.min(DASH_TOP, #enemies) do
        local entry = enemies[index]
        model.enemies[index] = { name = entry.name, class = classOf(entry.name), count = entry.count }
    end

    local zoneTotal, topZone = 0, nil
    for index, zone in ipairs(Format.ZONES) do
        local value = (scope.byZone or {})[zone.key] or 0
        model.zones[index] = { label = zone.label, value = value, color = zone.color }
        zoneTotal = zoneTotal + value
        if value > 0 and (not topZone or value > topZone.value) then topZone = model.zones[index] end
    end

    local tiles = model.tiles
    tiles[1] = { value = Format.Number(session.total or 0), label = "alerts this session" }
    tiles[2] = { value = Format.Number(allTime.total or 0), label = "alerts all-time" }
    local record = input.record
    if record and (record.total or 0) > 0 then
        tiles[3] = { value = record.won .. " of " .. record.total, label = "matches won" }
    else
        local sessions = input.sessions or 0
        tiles[3] = { value = string.format("%.1f", sessions > 0 and (allTime.total or 0) / sessions or 0), label = "per session (" .. sessions .. ")" }
    end
    local enemy = model.enemies[1]
    tiles[4] = enemy and { value = enemy.name, class = enemy.class, label = "top enemy, " .. enemy.count .. " alerts" } or { value = "-", label = "no enemy yet" }
    local alert = model.mix.top[1]
    tiles[5] = alert and { value = alert.label, label = "top alert, " .. alert.share } or { value = "-", label = "no alerts yet" }
    tiles[6] = topZone and { value = topZone.label, label = shareText(topZone.value, zoneTotal) .. " of alerts with a place" } or { value = "-", label = "no place yet" }
    return model
end

SA_StatsFormat = Format
