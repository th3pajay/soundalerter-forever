local Format = {}

local GOLD = "|cffFFD700"
local GREEN = "|cff00FF00"
local GREY = "|cff888888"
local WHITE = "|cffFFFFFF"
local RESET = "|r"

local DANGER_HIGH = 5
local DANGER_MEDIUM = 3

local SEGMENT_WIDTH = 380
local SEGMENT_HEIGHT = 10
local SWATCH_SIZE = 8
local ROW_BAR_WIDTH = 110
local ROW_BAR_HEIGHT = 8
local NAME_LIMIT = 22

local ZONE_NAMES = { arena = "Arena", battleground = "BG", worldPvP = "World", sanctuary = "City" }
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

function Format.Danger(danger)
    local color = "|cff00FF00"
    if danger > DANGER_HIGH then
        color = "|cffFF0000"
    elseif danger > DANGER_MEDIUM then
        color = "|cffFFD700"
    end
    return color .. string.format("%.1f", danger) .. RESET
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

function Format.Segments(items, total)
    if total <= 0 then
        return GREY .. "no data yet" .. RESET
    end

    local parts = {}
    for _, item in ipairs(items) do
        if item.value > 0 then
            local width = math.max(1, math.floor(item.value / total * SEGMENT_WIDTH + 0.5))
            parts[#parts + 1] = Format.Bar(width, SEGMENT_HEIGHT, item.color[1], item.color[2], item.color[3])
        end
    end
    return table.concat(parts)
end

function Format.Mix(title, items)
    local total = 0
    for _, item in ipairs(items) do
        total = total + item.value
    end

    local lines = { GOLD .. title .. RESET, Format.Segments(items, total) }
    for _, item in ipairs(items) do
        lines[#lines + 1] = Format.Bar(SWATCH_SIZE, SWATCH_SIZE, item.color[1], item.color[2], item.color[3]) ..
            " " .. item.label .. "  " .. GREEN .. Format.Number(item.value) .. RESET ..
            "  " .. GREY .. Format.Percent(item.value, total) .. "%" .. RESET
    end
    return table.concat(lines, "\n")
end

function Format.CategoryItems(byCategory)
    local items = {}
    for i, category in ipairs(Format.CATEGORIES) do
        items[i] = { label = category.label, value = (byCategory and byCategory[category.key]) or 0, color = category.color }
    end
    return items
end

function Format.ZoneItems(byZone)
    local items = {}
    for i, zone in ipairs(Format.ZONES) do
        items[i] = { label = zone.label, value = (byZone and byZone[zone.key]) or 0, color = zone.color }
    end
    return items
end

function Format.Overview(session, allTime)
    return table.concat({
        Format.Mix("This session", Format.CategoryItems(session and session.byCategory)),
        Format.Mix("All-time", Format.CategoryItems(allTime and allTime.byCategory)),
        Format.Mix("Where, all-time", Format.ZoneItems(allTime and allTime.byZone)),
    }, "\n\n")
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
            "  danger " .. Format.Danger(enemy.danger or 0) ..
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

function Format.ZoneName(zone)
    return ZONE_NAMES[zone] or zone or "N/A"
end

SA_StatsFormat = Format
