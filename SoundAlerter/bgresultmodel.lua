local Model = {}

Model.HISTORY = 50
Model.BOARDS = 10
Model.TOP_SPELLS = 5
Model.PILL_SECONDS = 120

Model.NAME, Model.CLASS, Model.FACTION = 1, 2, 3
Model.KB, Model.HK, Model.DEATHS, Model.HONOR, Model.DAMAGE, Model.HEALING = 4, 5, 6, 7, 8, 9
Model.FIRST_COLUMN = 10
Model.MAX_COLUMNS = 4

local NAME, CLASS, FACTION = Model.NAME, Model.CLASS, Model.FACTION
local KB, HK, DEATHS, HONOR, DAMAGE, HEALING = Model.KB, Model.HK, Model.DEATHS, Model.HONOR, Model.DAMAGE, Model.HEALING
local FIRST_COLUMN = Model.FIRST_COLUMN

Model.BASE_STATS = {
    { index = KB, label = "KB", name = "killing blows" },
    { index = HK, label = "HK", name = "honorable kills" },
    { index = DEATHS, label = "Deaths", name = "deaths", low = true },
    { index = DAMAGE, label = "Damage", name = "damage" },
    { index = HEALING, label = "Healing", name = "healing" },
}

local statCache = {}

function Model.Stats(columns)
    local count = columns and #columns or 0
    local key = count == 0 and "" or table.concat(columns, "\31")
    local cached = statCache[key]
    if cached then return cached end
    local list = {}
    for i = 1, #Model.BASE_STATS do list[i] = Model.BASE_STATS[i] end
    for c = 1, math.min(count, Model.MAX_COLUMNS) do
        local name = columns[c]
        list[#list + 1] = { index = FIRST_COLUMN + c - 1, label = Model.ColumnLabel(name), name = string.lower(name), column = true }
    end
    statCache[key] = list
    return list
end

function Model.ColumnLabel(name)
    if type(name) ~= "string" or name == "" then return "?" end
    local last = name:match("(%S+)%s*$") or name
    if #last > 9 then last = last:sub(1, 9) end
    return last
end

function Model.ShortMap(map)
    if type(map) ~= "string" then return "BG" end
    local letters = {}
    for word in map:gmatch("%a+") do
        if #word > 2 then letters[#letters + 1] = word:sub(1, 1):upper() end
    end
    return #letters > 0 and table.concat(letters) or map
end

function Model.Result(winner, faction)
    if type(winner) ~= "number" or type(faction) ~= "number" then return nil end
    if winner == faction then return "won" end
    if winner == 0 or winner == 1 then return "lost" end
    return "draw"
end

local function better(stat, value, other)
    if stat.low then return value < other end
    return value > other
end

function Model.Build(rows, columns, meIndex, info)
    local me = rows[meIndex]
    if not me then return nil end
    local stats = Model.Stats(columns)
    local teams = { [0] = {}, [1] = {} }
    local classes = { [0] = {}, [1] = {} }
    local ranks, top = {}, {}
    for s = 1, #stats do
        local index = stats[s].index
        ranks[index] = 1
        teams[0][index], teams[1][index] = 0, 0
    end
    teams[0][HONOR], teams[1][HONOR] = 0, 0
    for r = 1, #rows do
        local row = rows[r]
        local faction = row[FACTION]
        local team, mix = teams[faction], classes[faction]
        if mix then mix[row[CLASS]] = (mix[row[CLASS]] or 0) + 1 end
        if team then team[HONOR] = team[HONOR] + (row[HONOR] or 0) end
        for s = 1, #stats do
            local stat = stats[s]
            local index = stat.index
            local value = row[index] or 0
            if team then team[index] = team[index] + value end
            if better(stat, value, me[index] or 0) then ranks[index] = ranks[index] + 1 end
            local best = top[index]
            if not best or better(stat, value, best[index] or 0) then top[index] = row end
        end
    end
    local tops = {}
    for s = 1, #stats do
        local index = stats[s].index
        local row = top[index]
        if row then tops[index] = { row[NAME], row[CLASS], row[index] or 0 } end
    end
    return {
        map = info.map,
        at = info.at,
        when = info.when,
        length = info.length,
        result = Model.Result(info.winner, me[FACTION]),
        faction = me[FACTION],
        columns = columns,
        me = me,
        ranks = ranks,
        count = #rows,
        teams = teams,
        top = tops,
        classes = classes,
        board = rows,
        spells = info.spells,
    }
end

local function newTotals()
    return { n = 0, won = 0, kb = 0, hk = 0, deaths = 0, honor = 0, damage = 0, healing = 0 }
end

local function addTotals(totals, record)
    local me = record.me
    totals.n = totals.n + 1
    if record.result == "won" then totals.won = totals.won + 1 end
    totals.kb = totals.kb + (me[KB] or 0)
    totals.hk = totals.hk + (me[HK] or 0)
    totals.deaths = totals.deaths + (me[DEATHS] or 0)
    totals.honor = totals.honor + (me[HONOR] or 0)
    totals.damage = totals.damage + (me[DAMAGE] or 0)
    totals.healing = totals.healing + (me[HEALING] or 0)
end

function Model.Store(saved)
    saved = saved or {}
    saved.history = saved.history or {}
    saved.totals = saved.totals or {}
    saved.totals.all = saved.totals.all or newTotals()
    saved.totals.maps = saved.totals.maps or {}
    return saved
end

function Model.Push(saved, record)
    local history = saved.history
    table.insert(history, 1, record)
    local stale = history[Model.BOARDS + 1]
    if stale then stale.board = nil end
    for index = #history, Model.HISTORY + 1, -1 do history[index] = nil end
    addTotals(saved.totals.all, record)
    local map = record.map or "?"
    local byMap = saved.totals.maps[map]
    if not byMap then
        byMap = newTotals()
        saved.totals.maps[map] = byMap
    end
    addTotals(byMap, record)
end

function Model.Totals(saved, map)
    if not saved then return nil end
    if map == nil or map == "all" then return saved.totals.all end
    return saved.totals.maps[map]
end

function Model.Maps(saved, out)
    out = out or {}
    for index = #out, 1, -1 do out[index] = nil end
    if not saved then return out end
    for map in pairs(saved.totals.maps) do out[#out + 1] = map end
    table.sort(out)
    return out
end

function Model.Badges(record, out)
    out = out or {}
    for index = #out, 1, -1 do out[index] = nil end
    local stats = Model.Stats(record.columns)
    for pass = 1, 2 do
        local columns = pass == 1
        for s = 1, #stats do
            local stat = stats[s]
            local value = record.me[stat.index] or 0
            if (stat.column == true) == columns and not stat.low and value > 0 and record.ranks[stat.index] == 1 then
                out[#out + 1] = "Most " .. stat.name
            end
        end
    end
    if (record.me[DEATHS] or 0) == 0 then out[#out + 1] = "Never died" end
    return out
end

function Model.TopSpells(spells, nameOf, limit)
    if type(spells) ~= "table" then return nil end
    limit = limit or Model.TOP_SPELLS
    local top = {}
    for spellID, amount in pairs(spells) do
        if amount > 0 then
            local at = #top + 1
            for index = 1, #top do
                if amount > top[index][2] then
                    at = index
                    break
                end
            end
            if at <= limit then
                table.insert(top, at, { spellID, amount })
                top[limit + 1] = nil
            end
        end
    end
    if #top == 0 then return nil end
    for index = 1, #top do
        top[index] = { nameOf and nameOf(top[index][1]) or tostring(top[index][1]), top[index][2] }
    end
    return top
end

function Model.Short(value)
    value = value or 0
    if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
    if value >= 10000 then return string.format("%.1fk", value / 1000) end
    return tostring(math.floor(value + 0.5))
end

function Model.Clock(seconds)
    seconds = math.max(0, math.floor((seconds or 0) + 0.5))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Model.RankText(record, stat)
    local value = record.me[stat.index] or 0
    local rank = record.ranks[stat.index] or record.count
    if not stat.low and rank == 1 and value > 0 then return "best", true end
    return "#" .. rank .. " of " .. record.count, false
end

function Model.PillText(record)
    local result = record.result == "won" and "Victory" or record.result == "lost" and "Defeat" or "Match over"
    local badges = Model.Badges(record)
    return result .. " · " .. Model.ShortMap(record.map) .. (#badges > 0 and " · " .. badges[1] or "")
end

SA_BGResult = Model
