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
        local spellID = top[index][1]
        top[index] = { nameOf and nameOf(spellID) or tostring(spellID), top[index][2], spellID }
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

local pillBadges = {}

function Model.PillText(record)
    local result = record.result == "won" and "Victory" or record.result == "lost" and "Defeat" or "Match over"
    local badges = Model.Badges(record, pillBadges)
    return result .. " · " .. Model.ShortMap(record.map) .. (#badges > 0 and " · " .. badges[1] or "")
end

do
    local SNAP_STATS = {
        { index = KB, label = "Killing blows" },
        { index = HK, label = "Honorable kills" },
        { index = DEATHS, label = "Deaths", low = true },
        { index = DAMAGE, label = "Damage done" },
        { index = HEALING, label = "Healing done" },
        { index = HONOR, label = "Honor gained" },
    }
    local BEST_STATS = { SNAP_STATS[1], SNAP_STATS[2], SNAP_STATS[4], SNAP_STATS[5], SNAP_STATS[6] }
    local STAT_COUNT, BEST_COUNT = #SNAP_STATS, #BEST_STATS
    Model.SNAP_STATS = SNAP_STATS
    Model.BEST_STATS = BEST_STATS
    Model.SNAP_FORM = 10
    Model.SNAP_MIN = 3
    Model.SNAP_STACK = 3
    Model.SNAP_EDGE = 0.05
    Model.SNAP_MAPS = 6
    Model.SNAP_RIVALS = 3
    Model.snapshotBuilds = 0
    local FORM, MIN, STACK, EDGE, MAX_MAPS, RIVALS = Model.SNAP_FORM, Model.SNAP_MIN, Model.SNAP_STACK, Model.SNAP_EDGE, Model.SNAP_MAPS, Model.SNAP_RIVALS


    local function newSnapshot()
        local out = { build = 0, count = 0, sums = {} }
        local now = { rows = {}, column = {} }
        for s = 1, STAT_COUNT do now.rows[s] = { stat = SNAP_STATS[s] } end
        out.now = now
        out.form = { last = {}, rates = {} }
        out.maps = { rows = {}, pool = {}, rivals = {} }
        local bests = { list = {}, prior = {} }
        for s = 1, BEST_COUNT + 1 do bests.list[s] = {} end
        out.bests = bests
        return out
    end

    local snapshots = setmetatable({}, { __mode = "k" })
    local EMPTY_STORE = { history = {} }
    local classCount, classOrder = {}, {}

    local function arrow(value, average, low)
        if average <= 0 then return value > 0 and (low and -1 or 1) or 0 end
        if low then
            if value < average * (1 - EDGE) then return 1 end
            if value > average * (1 + EDGE) then return -1 end
            return 0
        end
        if value > average * (1 + EDGE) then return 1 end
        if value < average * (1 - EDGE) then return -1 end
        return 0
    end

    local function teamRank(board, faction, index, mine, low)
        local rank, size = 1, 0
        for r = 1, #board do
            local row = board[r]
            if row[FACTION] == faction then
                size = size + 1
                local value = row[index] or 0
                if low and value < mine or not low and value > mine then rank = rank + 1 end
            end
        end
        return rank, size
    end

    local function fillNow(out, record)
        local now = out.now
        now.record = record
        local count = out.count
        if not record then return end
        local me, board, faction = record.me, record.board, record.faction
        local own = type(board) == "table" and faction ~= nil
        now.team = own
        local sums = out.sums
        for s = 1, STAT_COUNT do
            local row = now.rows[s]
            local stat = row.stat
            local value = me[stat.index] or 0
            row.value = value
            row.average = count > 0 and sums[s] / count or 0
            row.arrow = arrow(value, row.average, stat.low)
            if own then
                row.rank, row.of = teamRank(board, faction, stat.index, value, stat.low)
            else
                row.rank, row.of = record.ranks and record.ranks[stat.index] or 1, record.count or 1
            end
        end
        local column = now.column
        local label = record.columns and record.columns[1]
        column.label = label and Model.ColumnLabel(label) or nil
        if label then
            column.value = me[FIRST_COLUMN] or 0
            if own then
                column.rank, column.of = teamRank(board, faction, FIRST_COLUMN, column.value, false)
            else
                column.rank, column.of = record.ranks and record.ranks[FIRST_COLUMN] or 1, record.count or 1
            end
        end
        local teams = record.teams and faction ~= nil and record.teams[faction]
        now.teamDamage = teams and teams[DAMAGE] or 0
        now.teamKB = teams and teams[KB] or 0
    end

    local function mapRow(maps, name)
        local rows, pool = maps.rows, maps.pool
        for index = 1, #rows do
            if rows[index].map == name then return rows[index] end
        end
        local row = pool[#rows + 1]
        if not row then
            row = {}
            pool[#rows + 1] = row
        end
        row.map, row.n, row.won, row.seconds, row.honor, row.tag = name, 0, 0, 0, 0, nil
        rows[#rows + 1] = row
        return row
    end

    local function byMatches(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.map < b.map
    end

    local function byClassCount(a, b)
        if classCount[a] ~= classCount[b] then return classCount[a] > classCount[b] end
        return a < b
    end

    local function enemyMix(record)
        local faction = record.faction
        if faction ~= 0 and faction ~= 1 then return nil end
        return record.classes and record.classes[1 - faction]
    end

    local function build(out, history)
        local n = #history
        out.count = n
        out.build = out.build + 1
        Model.snapshotBuilds = Model.snapshotBuilds + 1
        local sums = out.sums
        for s = 1, STAT_COUNT do sums[s] = 0 end
        local form, maps, bests = out.form, out.maps, out.bests
        local last, rates = form.last, form.rates
        for index = #last, 1, -1 do last[index] = nil end
        for index = #rates, 1, -1 do rates[index] = nil end
        local rows = maps.rows
        for index = #rows, 1, -1 do rows[index] = nil end
        for key in pairs(classCount) do classCount[key] = nil end
        for index = #classOrder, 1, -1 do classOrder[index] = nil end
        local prior = bests.prior
        for s = 1, BEST_COUNT + 1 do
            local best = bests.list[s]
            best.record, best.value, best.label = nil, 0, s <= BEST_COUNT and BEST_STATS[s].label or nil
            prior[s] = nil
        end
        local wins, decided, length10 = 0, 0, 0
        local streak, streakWon, streakOpen = 0, nil, true
        local run, longest, longestAt = 0, 0, nil
        local enemies, stackMatches, stackWon = 0, 0, 0
        local window, windowSize = 0, n < FORM and n or FORM
        for index = n, 1, -1 do
            local record = history[index]
            local won = record.result == "won"
            if won then
                run = run + 1
                if run > longest then longest, longestAt = run, record end
            else
                run = 0
            end
            window = window + (won and 1 or 0)
            local leaving = history[index + windowSize]
            if leaving and leaving.result == "won" then window = window - 1 end
            if index <= n - windowSize + 1 and windowSize > 0 then rates[#rates + 1] = window / windowSize end
        end
        for index = 1, n do
            local record = history[index]
            local me = record.me
            local result = record.result
            local won = result == "won"
            if won then wins = wins + 1 end
            if result == "won" or result == "lost" then decided = decided + 1 end
            if streakOpen then
                if result ~= "won" and result ~= "lost" then
                    streakOpen = false
                elseif streakWon == nil then
                    streakWon, streak = won, 1
                elseif won == streakWon then
                    streak = streak + 1
                else
                    streakOpen = false
                end
            end
            if index <= FORM then
                last[index] = record
                length10 = length10 + (record.length or 0)
            end
            for s = 1, STAT_COUNT do sums[s] = sums[s] + (me[SNAP_STATS[s].index] or 0) end
            for s = 1, BEST_COUNT do
                local value = me[BEST_STATS[s].index] or 0
                local best = bests.list[s]
                if value > best.value then best.value, best.record = value, record end
                if index > 1 and (prior[s] == nil or value > prior[s]) then prior[s] = value end
            end
            local label = record.columns and record.columns[1]
            if label and string.lower(label):find("flag cap", 1, true) then
                local value = me[FIRST_COLUMN] or 0
                local best = bests.list[BEST_COUNT + 1]
                if value > best.value then best.value, best.record, best.label = value, record, Model.ColumnLabel(label) end
            end
            local row = mapRow(maps, record.map or "?")
            row.n = row.n + 1
            if won then row.won = row.won + 1 end
            row.seconds = row.seconds + (record.length or 0)
            row.honor = row.honor + (me[HONOR] or 0)
            local mix = enemyMix(record)
            if mix then
                local stacked = false
                for class, amount in pairs(mix) do
                    if not classCount[class] then
                        classCount[class] = 0
                        classOrder[#classOrder + 1] = class
                    end
                    classCount[class] = classCount[class] + amount
                    enemies = enemies + amount
                    if amount >= STACK then stacked = true end
                end
                if stacked then
                    stackMatches = stackMatches + 1
                    if won then stackWon = stackWon + 1 end
                end
            end
        end
        form.streak, form.streakWon = streak, streakWon
        form.lastCount = #last
        local lastWins = 0
        for index = 1, #last do if last[index].result == "won" then lastWins = lastWins + 1 end end
        form.lastWins = lastWins
        form.overall = decided > 0 and wins / decided or nil
        form.lastRate = #last > 0 and lastWins / #last or nil
        form.length = #last > 0 and length10 / #last or nil
        form.longest, form.longestAt = longest, longestAt
        form.window = windowSize
        table.sort(rows, byMatches)
        for index = #rows, MAX_MAPS + 1, -1 do rows[index] = nil end
        local best, worst, ranked = nil, nil, 0
        for index = 1, #rows do
            local row = rows[index]
            row.rate = row.n > 0 and row.won / row.n or 0
            row.length = row.n > 0 and row.seconds / row.n or 0
            row.perMatch = row.n > 0 and row.honor / row.n or 0
            if row.n >= MIN then
                ranked = ranked + 1
                if not best or row.rate > best.rate then best = row end
                if not worst or row.rate < worst.rate then worst = row end
            end
        end
        if ranked >= 2 and best.rate > worst.rate then
            best.tag, worst.tag = "best", "worst"
        end
        table.sort(classOrder, byClassCount)
        local rivals = maps.rivals
        for index = 1, RIVALS do
            local class = classOrder[index]
            local entry = rivals[index] or {}
            rivals[index] = entry
            entry.class = class
            entry.share = class and enemies > 0 and classCount[class] / enemies or 0
        end
        maps.rivalCount = math.min(RIVALS, #classOrder)
        maps.stackMatches, maps.stackWon = stackMatches, stackWon
        local shown = 0
        for s = 1, BEST_COUNT + 1 do
            if bests.list[s].record then shown = shown + 1 end
        end
        bests.count = shown
        fillNow(out, history[1])
    end

    function Model.Snapshot(saved)
        saved = saved or EMPTY_STORE
        local history = saved.history or EMPTY_STORE.history
        local cached = snapshots[saved]
        if not cached then
            cached = { out = newSnapshot() }
            snapshots[saved] = cached
        elseif cached.head == history[1] and cached.count == #history and cached.history == history then
            return cached.out
        end
        cached.head, cached.count, cached.history = history[1], #history, history
        build(cached.out, history)
        return cached.out
    end

    function Model.SnapshotIndex(saved, record)
        local history = saved and saved.history
        if not history then return nil end
        for index = 1, #history do
            if history[index] == record then return index end
        end
        return nil
    end
end

Model.PODIUM = 3
Model.debriefBuilds = 0

do
    local debriefs = setmetatable({}, { __mode = "k" })
    local RECORD_ORDER = { 3, 1, 2, 4, 5 }
    local TUG = { { index = KB, label = "Killing blows" }, { index = DAMAGE, label = "Damage" } }

    local function tugRows(record)
        local faction, teams = record.faction, record.teams
        if (faction ~= 0 and faction ~= 1) or type(teams) ~= "table" then return {} end
        local us, them = teams[faction], teams[1 - faction]
        if not us or not them then return {} end
        local rows = {}
        local objective = record.columns and record.columns[1]
        if type(objective) == "string" and objective ~= "" and us[FIRST_COLUMN] ~= nil then
            rows[1] = { label = objective, us = us[FIRST_COLUMN] or 0, them = them[FIRST_COLUMN] or 0 }
        end
        for t = 1, #TUG do
            local stat = TUG[t]
            rows[#rows + 1] = { label = stat.label, us = us[stat.index] or 0, them = them[stat.index] or 0 }
        end
        return rows
    end

    local function podium(record)
        local board, faction, me = record.board, record.faction, record.me
        if type(board) ~= "table" or faction == nil then return nil end
        local stat = (me[HEALING] or 0) > (me[DAMAGE] or 0) and HEALING or DAMAGE
        local mine = me[stat] or 0
        local top, place, size = {}, 1, 0
        for r = 1, #board do
            local row = board[r]
            if row[FACTION] == faction then
                size = size + 1
                local value = row[stat] or 0
                if row ~= me and value > mine then place = place + 1 end
                for slot = 1, Model.PODIUM do
                    local held = top[slot]
                    if not held or value > (held[stat] or 0) then
                        for shift = Model.PODIUM, slot + 1, -1 do top[shift] = top[shift - 1] end
                        top[slot] = row
                        break
                    end
                end
            end
        end
        if size == 0 then return nil end
        return { stat = stat, name = stat == HEALING and "healing" or "damage", top = top, place = place, of = size, value = mine }
    end

    local BEST_STATS = Model.BEST_STATS

    local function records(record, snapshot)
        if not snapshot or not snapshot.now or snapshot.now.record ~= record then return nil end
        local prior, list, me = snapshot.bests.prior, {}, record.me
        for position = 1, #RECORD_ORDER do
            local s = RECORD_ORDER[position]
            local stat = BEST_STATS[s]
            local value, was = me[stat.index] or 0, prior[s]
            list[position] = {
                label = stat.label, value = value, prior = was,
                new = was ~= nil and value > was,
                percent = was and was > 0 and math.floor(value / was * 100 + 0.5) or nil,
            }
        end
        return list
    end

    function Model.Debrief(record, snapshot)
        if not record then return nil end
        local cached = debriefs[record]
        if cached then return cached end
        Model.debriefBuilds = Model.debriefBuilds + 1
        cached = {
            result = record.result,
            tug = tugRows(record),
            podium = podium(record),
            records = records(record, snapshot),
            spells = type(record.spells) == "table" and #record.spells > 0 and record.spells or nil,
        }
        debriefs[record] = cached
        return cached
    end
end

SA_BGResult = Model
