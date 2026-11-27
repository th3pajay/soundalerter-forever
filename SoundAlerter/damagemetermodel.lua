local Model = {}

Model.MIN_SECONDS = 5
Model.IDLE_SECONDS = 1800
Model.RUN_GRACE = 900
Model.SESSION_FIGHTS = 200
Model.RUNS = 20
Model.PVP = 20
Model.WORLD_DAYS = 14
Model.WORLD_MAX = 60
Model.TOP_SPELLS = 5
Model.RUN_PULLS = 40
Model.PARTY = 5
Model.TREND = 0.25
Model.SPELL_CAP = 60
Model.ICON_CAP = 300
Model.TARGET_CAP = 30
Model.MEMBER_CAP = 12
Model.MEMBER_FIELDS = { "damage", "healing", "taken", "interrupts", "dispels", "deaths" }
Model.CHAT_LIMIT = 255

Model.KINDS = { "world", "pvp", "run" }

Model.HIT, Model.CRIT, Model.GLANCE, Model.CRUSH = 1, 2, 3, 4
Model.MISS, Model.DODGE, Model.PARRY, Model.BLOCK = 5, 6, 7, 8
Model.RESIST, Model.IMMUNE, Model.ABSORB, Model.REFLECT, Model.EVADE = 9, 10, 11, 12, 13
Model.SLOTS = 13
Model.AVOIDED = { [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true, [12] = true, [13] = true }

local ACTION = {
    MISS = Model.MISS, DODGE = Model.DODGE, PARRY = Model.PARRY, BLOCK = Model.BLOCK, RESIST = Model.RESIST,
    IMMUNE = Model.IMMUNE, ABSORB = Model.ABSORB, REFLECT = Model.REFLECT, EVADE = Model.EVADE, DEFLECT = Model.PARRY,
}
local FLAG = { CRITICAL = Model.CRIT, GLANCING = Model.GLANCE, CRUSHING = Model.CRUSH }

function Model.HitSlot(action, flag)
    if action == "WOUND" then return FLAG[flag] or Model.HIT end
    return ACTION[action]
end

function Model.NewCounts()
    local counts = {}
    for i = 1, Model.SLOTS do counts[i] = 0 end
    return counts
end

function Model.Avoided(counts)
    local total, avoided = 0, 0
    for i = 1, Model.SLOTS do
        local n = counts[i] or 0
        total = total + n
        if Model.AVOIDED[i] then avoided = avoided + n end
    end
    return avoided, total
end

function Model.KindOf(zoneKind, pvp)
    if zoneKind == "instance" then return "run" end
    if zoneKind == "battleground" or zoneKind == "arena" then return nil end
    if pvp then return "pvp" end
    return "world"
end

function Model.FightName(raw)
    if type(raw) ~= "string" or raw == "" then return nil, false end
    local boss = raw:match("^%(!%)%s*(.+)$")
    if boss then return boss, true end
    return raw, false
end

function Model.Foldable(list, lastID, newestOpen, out)
    for i = #out, 1, -1 do out[i] = nil end
    local newest = 0
    for i = 1, #list do
        local id = list[i].sessionID
        if id > newest then newest = id end
    end
    for i = 1, #list do
        local id = list[i].sessionID
        if id > lastID and not (newestOpen and id == newest) then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

function Model.GroupSpells(list, nameOf, out, ids)
    for key in pairs(out) do out[key] = nil end
    for i = 1, #list do
        local entry = list[i]
        local id, amount = entry.spellID, entry.totalAmount
        if type(id) == "number" and type(amount) == "number" then
            local name = nameOf(id, entry) or ("#" .. id)
            out[name] = (out[name] or 0) + amount
            if ids and not ids[name] then ids[name] = id end
        end
    end
    return out
end

function Model.NoteIcons(db, ids)
    local icons = db.icons
    if not icons then
        icons = {}
        db.icons, db.iconCount = icons, 0
    end
    for name, id in pairs(ids) do
        if icons[name] ~= id then
            if not icons[name] then db.iconCount = (db.iconCount or 0) + 1 end
            icons[name] = id
        end
    end
    if db.iconCount > Model.ICON_CAP then
        for name in pairs(icons) do icons[name] = nil end
        db.iconCount = 0
        for name, id in pairs(ids) do
            icons[name] = id
            db.iconCount = db.iconCount + 1
        end
    end
end

function Model.AddCapped(into, from, cap)
    if not from then return end
    local size = 0
    for name, amount in pairs(from) do into[name] = (into[name] or 0) + amount end
    for _ in pairs(into) do size = size + 1 end
    if size <= cap then return end
    local list = {}
    for name, amount in pairs(into) do list[#list + 1] = { name, amount } end
    table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
    for i = cap + 1, #list do into[list[i][1]] = nil end
end

local function newSession(kind, now, fight)
    return {
        kind = kind, start = now, lastAt = now, seconds = 0,
        damage = 0, healing = 0, taken = 0, count = 0, deaths = 0,
        name = fight and fight.place, instance = fight and fight.instance,
        spells = {}, casts = {}, targets = {}, takenSpells = {}, healSpells = {}, hits = Model.NewCounts(), avoid = Model.NewCounts(), fights = {},
        best = 0,
    }
end

local function topSpells(spells, limit)
    local list = {}
    for name, amount in pairs(spells) do list[#list + 1] = { name, amount } end
    table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
    for i = #list, limit + 1, -1 do list[i] = nil end
    return list
end

function Model.Average(session)
    local damage, seconds = 0, 0
    local fights = session.fights
    for i = 1, #fights do
        local fight = fights[i]
        if fight.seconds >= Model.MIN_SECONDS then
            damage = damage + fight.damage
            seconds = seconds + fight.seconds
        end
    end
    if seconds == 0 then return 0 end
    return damage / seconds
end

function Model.Trend(session, out)
    for i = #out, 1, -1 do out[i] = nil end
    local run
    local fights = session.fights
    for i = 1, #fights do
        local fight = fights[i]
        if fight.seconds >= Model.MIN_SECONDS then
            local dps = fight.damage / fight.seconds
            run = run and (run * (1 - Model.TREND) + dps * Model.TREND) or dps
        end
        out[i] = run or 0
    end
    return out
end

local function summary(session)
    local item = {
        kind = session.kind, name = session.name, start = session.start, finish = session.lastAt,
        seconds = session.seconds, damage = session.damage, healing = session.healing, taken = session.taken,
        count = session.count, deaths = session.deaths, best = session.best, dps = Model.Average(session),
        spells = topSpells(session.spells, Model.TOP_SPELLS),
    }
    if session.kind == "run" then
        local pulls = {}
        local fights = session.fights
        local first = math.max(1, #fights - Model.RUN_PULLS + 1)
        for i = first, #fights do
            local fight = fights[i]
            pulls[#pulls + 1] = { o = fight.at - session.start, s = fight.seconds, d = fight.damage, b = fight.boss and fight.name or nil }
        end
        item.pulls = pulls
    end
    return item
end

local function prune(db, now)
    local history = db.history
    while #history.run > Model.RUNS do table.remove(history.run, 1) end
    while #history.pvp > Model.PVP do table.remove(history.pvp, 1) end
    local world = history.world
    local cutoff = now - Model.WORLD_DAYS * 86400
    while world[1] and (world[1].finish < cutoff or #world > Model.WORLD_MAX) do table.remove(world, 1) end
end

function Model.New()
    return { last = 0, current = {}, history = { world = {}, pvp = {}, run = {} }, records = {}, icons = {}, iconCount = 0 }
end

function Model.Close(db, kind, now)
    local session = db.current[kind]
    if not session then return end
    db.current[kind] = nil
    if session.count > 0 then
        local list = db.history[kind]
        list[#list + 1] = summary(session)
        prune(db, now)
    end
end

function Model.OnLogin(db, now)
    Model.Close(db, "world", now)
    Model.Close(db, "pvp", now)
end

local function stale(session, kind, now, fight)
    if kind == "run" then
        return session.instance ~= fight.instance or now - session.lastAt > Model.RUN_GRACE
    end
    return now - session.lastAt > Model.IDLE_SECONDS
end

function Model.SessionFor(db, kind, now, fight)
    local session = db.current[kind]
    if session and stale(session, kind, now, fight) then
        Model.Close(db, kind, now)
        session = nil
    end
    if not session then
        session = newSession(kind, now, fight)
        db.current[kind] = session
    end
    Model.Complete(session)
    return session
end

local MAPS = { "spells", "casts", "targets", "takenSpells", "healSpells", "fights", "members" }

function Model.Complete(session)
    for i = 1, #MAPS do
        if type(session[MAPS[i]]) ~= "table" then session[MAPS[i]] = {} end
    end
    if type(session.hits) ~= "table" then session.hits = Model.NewCounts() end
    if type(session.avoid) ~= "table" then session.avoid = Model.NewCounts() end
    return session
end

local function addCounts(into, from)
    if not from then return end
    for i = 1, Model.SLOTS do into[i] = into[i] + (from[i] or 0) end
end

local function record(db, kind, fight, now)
    if fight.seconds < Model.MIN_SECONDS then return false end
    local best = db.records[kind]
    if not best then
        best = { dps = 0, damage = 0, healing = 0 }
        db.records[kind] = best
    end
    local dps = fight.damage / fight.seconds
    local fresh = false
    if dps > best.dps then
        best.dps, best.dpsAt, fresh = dps, now, true
    end
    if fight.damage > best.damage then
        best.damage, best.damageAt, fresh = fight.damage, now, true
    end
    if fight.healing > (best.healing or 0) then
        best.healing, best.healingAt, fresh = fight.healing, now, true
    end
    return fresh
end

function Model.AddMembers(session, fight)
    if not fight.members then return end
    local members = session.members
    for name, m in pairs(fight.members) do
        local into = members[name]
        if not into then
            into = { name = name }
            for _, field in ipairs(Model.MEMBER_FIELDS) do into[field] = 0 end
            members[name] = into
        end
        for _, field in ipairs(Model.MEMBER_FIELDS) do into[field] = into[field] + (m[field] or 0) end
        into.class = m.class or into.class
        into.guid = m.guid or into.guid
        if m.me then into.me = true end
        into.lastId = fight.id
    end
    local size = 0
    for _ in pairs(members) do size = size + 1 end
    if size <= Model.MEMBER_CAP then return end
    local list = {}
    for name, m in pairs(members) do list[#list + 1] = { name, m.damage + m.healing, m.me } end
    table.sort(list, function(a, b)
        if a[3] ~= b[3] then return a[3] == true end
        if a[2] ~= b[2] then return a[2] > b[2] end
        return a[1] < b[1]
    end)
    for i = Model.MEMBER_CAP + 1, #list do members[list[i][1]] = nil end
end

function Model.RankMembers(members, field, limit, out)
    for i = #out, 1, -1 do out[i] = nil end
    local total = 0
    for _, m in pairs(members or {}) do
        if m[field] > 0 then
            out[#out + 1] = m
            total = total + m[field]
        end
    end
    table.sort(out, function(a, b) if a[field] ~= b[field] then return a[field] > b[field] end return a.name < b.name end)
    for i = #out, limit + 1, -1 do out[i] = nil end
    return out, total
end

local function Short(n)
    n = math.floor(n + 0.5)
    if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if n >= 10000 then return string.format("%.1fK", n / 1000) end
    return tostring(n)
end
Model.ShortNumber = Short

function Model.ChatLine(label, place, list, field, total)
    local head = "SoundAlerter " .. label .. (place and (", " .. place) or "") .. ":"
    local line = head
    for i, m in ipairs(list) do
        if i > 5 then break end
        local share = total > 0 and string.format(" %d%%", math.floor(m[field] / total * 100 + 0.5)) or ""
        local part = string.format(" %d. %s %s%s", i, m.name, Short(m[field]), share)
        if #line + #part > Model.CHAT_LIMIT then break end
        line = line .. part
    end
    if line == head then return nil end
    return line
end

function Model.Fold(db, fight, now)
    if fight.id <= db.last then return nil end
    db.last = fight.id
    local kind = fight.kind
    local session = Model.SessionFor(db, kind, now, fight)
    session.lastAt = now
    session.seconds = session.seconds + fight.seconds
    session.damage = session.damage + fight.damage
    session.healing = session.healing + fight.healing
    session.taken = session.taken + fight.taken
    session.deaths = session.deaths + (fight.deaths or 0)
    session.count = session.count + 1
    Model.AddCapped(session.spells, fight.spells, Model.SPELL_CAP)
    Model.AddCapped(session.casts, fight.casts, Model.SPELL_CAP)
    Model.AddCapped(session.targets, fight.targets, Model.TARGET_CAP)
    Model.AddCapped(session.takenSpells, fight.takenSpells, Model.TARGET_CAP)
    Model.AddCapped(session.healSpells, fight.healSpells, Model.TARGET_CAP)
    Model.AddMembers(session, fight)
    addCounts(session.hits, fight.hits)
    addCounts(session.avoid, fight.avoid)
    if fight.seconds >= Model.MIN_SECONDS then
        local dps = fight.damage / fight.seconds
        if dps > session.best then session.best = dps end
    end
    local entry = { id = fight.id, at = now, seconds = fight.seconds, damage = fight.damage, healing = fight.healing, taken = fight.taken, name = fight.name, boss = fight.boss or nil, deaths = (fight.deaths or 0) > 0 and fight.deaths or nil }
    if kind == "run" and fight.party then
        local party = {}
        for i = 1, math.min(#fight.party, Model.PARTY) do
            local member = fight.party[i]
            party[i] = { member.name, member.class, member.damage }
        end
        entry.party = party
    end
    local fights = session.fights
    fights[#fights + 1] = entry
    while #fights > Model.SESSION_FIGHTS do table.remove(fights, 1) end
    return session, record(db, kind, fight, now)
end

function Model.Compare(db, kind, name, value)
    local list = db.history[kind]
    local sum, count, best = 0, 0, 0
    for i = 1, #list do
        local item = list[i]
        if (not name or item.name == name) and item.dps > 0 then
            sum = sum + item.dps
            count = count + 1
            if item.dps > best then best = item.dps end
        end
    end
    local average = count > 0 and sum / count or 0
    local rec = db.records[kind]
    if rec and rec.dps > best and not name then best = rec.dps end
    return value or 0, average, best, count
end

function Model.Change(value, average)
    if not average or average <= 0 then return nil end
    return math.floor((value / average - 1) * 100 + 0.5)
end

function Model.Clock(seconds)
    seconds = math.floor((seconds or 0) + 0.5)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor(seconds % 3600 / 60)
    if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, seconds % 60) end
    return string.format("%d:%02d", minutes, seconds % 60)
end

function Model.FightDps(fight)
    if not fight or fight.seconds <= 0 then return 0 end
    return fight.damage / fight.seconds
end

local trendAll = {}

function Model.Timeline(session, limit, points, trend)
    for i = #points, 1, -1 do points[i] = nil end
    for i = #trend, 1, -1 do trend[i] = nil end
    local fights = session.fights
    Model.Trend(session, trendAll)
    local first = math.max(1, #fights - limit + 1)
    local top = 0
    for i = first, #fights do
        local n = #points + 1
        points[n], trend[n] = fights[i], trendAll[i]
        local dps = Model.FightDps(fights[i])
        if dps > top then top = dps end
        if trendAll[i] > top then top = trendAll[i] end
    end
    return #points, top
end

local function pullEntry(out, i)
    local pool = out.pool
    if not pool then
        pool = {}
        out.pool = pool
    end
    local entry = pool[i]
    if not entry then
        entry = {}
        pool[i] = entry
    end
    out[i] = entry
    return entry
end

function Model.Pulls(source, out)
    for i = #out, 1, -1 do out[i] = nil end
    if source.fights then
        local start = source.start
        for i, fight in ipairs(source.fights) do
            local e = pullEntry(out, i)
            e.t0, e.s, e.d, e.party, e.boss, e.deaths = fight.at - start - fight.seconds, fight.seconds, fight.damage, fight.party, fight.boss and fight.name or nil, fight.deaths
        end
    else
        for i, pull in ipairs(source.pulls or {}) do
            local e = pullEntry(out, i)
            e.t0, e.s, e.d, e.party, e.boss, e.deaths = pull.o - pull.s, pull.s, pull.d, nil, pull.b, nil
        end
    end
    return out
end

function Model.PullLayout(pulls, width, minWidth)
    if #pulls == 0 then return 0, 0 end
    local t0 = pulls[1].t0
    local t1 = t0
    local top = 0
    for _, pull in ipairs(pulls) do
        if pull.t0 < t0 then t0 = pull.t0 end
        if pull.t0 + pull.s > t1 then t1 = pull.t0 + pull.s end
        if pull.d > top then top = pull.d end
    end
    local span = math.max(1, t1 - t0)
    for _, pull in ipairs(pulls) do
        pull.x = (pull.t0 - t0) / span * width
        pull.w = math.max(minWidth, pull.s / span * width)
        if pull.x + pull.w > width then pull.x = math.max(0, width - pull.w) end
    end
    return span, top
end

local function compareRow(out, n, label, now, history, field, lower, best)
    local sum, count = 0, 0
    for _, item in ipairs(history) do
        local value = field(item)
        if value then
            sum = sum + value
            count = count + 1
            if best == nil or (lower and value < best) or (not lower and value > best) then best = value end
        end
    end
    local row = out[n] or {}
    row.label, row.now, row.lower = label, now, lower
    row.average = count > 0 and sum / count or nil
    row.best = best
    out[n] = row
    return n
end

local function itemDps(item) return item.dps > 0 and item.dps or nil end
local function itemDamage(item) return item.damage end
local function itemHealing(item) return item.healing end
local function itemDeaths(item) return item.deaths end
local function itemTime(item) return item.finish - item.start end
local function itemCount(item) return item.count end
local compareHistory = {}

function Model.CompareRows(store, session, out)
    for i = #out, 1, -1 do out[i] = nil end
    local history = compareHistory
    for i = #history, 1, -1 do history[i] = nil end
    for _, item in ipairs(store.history[session.kind] or {}) do
        if session.kind ~= "run" or item.name == session.name then history[#history + 1] = item end
    end
    local record = store.records[session.kind]
    local n = 0
    n = compareRow(out, n + 1, "DPS", Model.Average(session), history, itemDps, false, session.kind ~= "run" and record and record.dps > 0 and record.dps or nil)
    n = compareRow(out, n + 1, "Damage", session.damage, history, itemDamage, false)
    n = compareRow(out, n + 1, "Healing", session.healing, history, itemHealing, false)
    n = compareRow(out, n + 1, "Deaths", session.deaths, history, itemDeaths, true)
    if session.kind == "run" then
        compareRow(out, n + 1, "Run time", session.lastAt - session.start, history, itemTime, true)
    else
        compareRow(out, n + 1, "Fights", session.count, history, itemCount, false)
    end
    return out, #history
end

Model.SLOT_NAMES = { "Hit", "Crit", "Glancing", "Crushing", "Miss", "Dodge", "Parry", "Block", "Resist", "Immune", "Absorb", "Reflect", "Evade" }

local function byAmount(a, b)
    if a[2] ~= b[2] then return a[2] > b[2] end
    return a[1] < b[1]
end

function Model.Ranked(map, limit, out)
    local pool = out.pool
    if not pool then
        pool = {}
        out.pool = pool
    end
    for i = #out, 1, -1 do out[i] = nil end
    local total, n = 0, 0
    for name, amount in pairs(map or {}) do
        n = n + 1
        local pair = pool[n]
        if not pair then
            pair = {}
            pool[n] = pair
        end
        pair[1], pair[2] = name, amount
        out[n] = pair
        total = total + amount
    end
    table.sort(out, byAmount)
    for i = #out, limit + 1, -1 do out[i] = nil end
    return out, total
end

function Model.CritRate(counts)
    local landed = counts[Model.HIT] + counts[Model.CRIT] + counts[Model.GLANCE] + counts[Model.CRUSH]
    if landed == 0 then return nil end
    return counts[Model.CRIT] / landed
end

function Model.AvoidRate(counts)
    local avoided, total = Model.Avoided(counts)
    if total == 0 then return nil end
    return avoided / total
end

local function lastFight(session)
    return session.fights[#session.fights]
end

local function perFight(session, field)
    if session.count == 0 then return 0 end
    return session[field] / session.count
end

local function fightDps(fight)
    if not fight or fight.seconds <= 0 then return 0 end
    return fight.damage / fight.seconds
end

function Model.CurrentSession(store, zone)
    local kind = Model.KindOf(zone, false) or "world"
    local session = store.current[kind]
    if not session and kind == "world" and store.current.pvp then return store.current.pvp, "pvp" end
    return session, kind
end

function Model.LastRun(store, session)
    if session and session.kind == "run" then return session end
    if store.current.run then return store.current.run end
    local list = store.history.run
    return list[#list]
end

function Model.BestDps(store, kind)
    local record = store.records[kind]
    if record and record.dps > 0 then return record.dps end
    return nil
end

local RATIO_EMPTY = {}
local fightRatios, sessionRatios = {}, {}

local function Ratio(value, best)
    if not best or best <= 0 then return value > 0 and 1 or 0 end
    return math.min(1, value / best)
end
Model.Ratio = Ratio

function Model.FightRatios(store, fight, kind)
    local dps = fight.seconds > 0 and fight.damage / fight.seconds or 0
    local record = store.records[kind] or RATIO_EMPTY
    local out = fightRatios
    out[1], out[2], out[3] = Ratio(dps, record.dps), Ratio(fight.damage, record.damage), Ratio(fight.healing, record.healing)
    return dps, out
end

function Model.SessionRatios(store, session)
    local dps = Model.Average(session)
    local history = store.history[session.kind]
    local damage, healing = 0, 0
    for i = 1, #history do
        local item = history[i]
        if item.damage > damage then damage = item.damage end
        if item.healing > healing then healing = item.healing end
    end
    local out = sessionRatios
    out[1], out[2], out[3] = Ratio(dps, (store.records[session.kind] or RATIO_EMPTY).dps), Ratio(session.damage, damage), Ratio(session.healing, healing)
    return dps, out
end

local function HelpHeroes(session, store)
    local counted = 0
    local fights = session.fights
    for i = 1, #fights do
        if fights[i].seconds >= Model.MIN_SECONDS then counted = counted + 1 end
    end
    local saved, records = 0, 0
    if store then
        for _, kind in ipairs(Model.KINDS) do
            saved = saved + #store.history[kind]
            local record = store.records[kind]
            if record and record.dps > 0 then records = records + 1 end
        end
    end
    return {
        { label = session.kind == "run" and "Pulls" or "Fights", value = session.count, note = "this session" },
        { label = "In averages", value = counted, note = Model.MIN_SECONDS .. " s or longer" },
        { label = "Saved", value = saved, note = "earlier sessions" },
        { label = "Records", text = records .. " / " .. #Model.KINDS, note = "world, PvP, runs" },
    }
end

function Model.Heroes(tab, session, store)
    if tab == "?" then return HelpHeroes(session, store) end
    local last = lastFight(session)
    if tab == "GRAPH" then
        local record = store and store.records[session.kind]
        local average = Model.Average(session)
        local wall = session.lastAt - session.start
        return {
            { label = "Best DPS", value = record and record.dps > 0 and record.dps or nil, note = record and "your record" or "no record yet" },
            { label = "Average", value = average, note = session.count .. (session.count == 1 and " fight" or " fights") },
            { label = "Time fighting", text = Model.Clock(session.seconds), note = wall > 0 and ("of " .. Model.Clock(wall)) or nil },
            { label = session.kind == "run" and "Pulls" or "Fights", value = session.count, note = session.kind == "run" and session.name or nil },
        }
    end
    if tab == "DEF" then
        local avoid = Model.AvoidRate(session.avoid)
        return {
            { label = "Taken", value = session.taken, change = last and Model.Change(last.taken, perFight(session, "taken")) },
            { label = "Avoided", value = avoid, percent = true, note = avoid and "of attacks on you" or "no attacks yet" },
            { label = "Healing", value = session.healing, change = last and Model.Change(last.healing, perFight(session, "healing")) },
            { label = "Deaths", value = session.deaths, note = "this session" },
        }
    end
    if tab == "PARTY" then
        local ranked, total = Model.RankMembers(session.members, "damage", Model.MEMBER_CAP, {})
        local rank, mine, interrupts, myInterrupts = nil, nil, 0, 0
        for i, m in ipairs(ranked) do
            if m.me then rank, mine = i, m.damage end
        end
        for _, m in pairs(session.members) do
            interrupts = interrupts + m.interrupts
            if m.me then myInterrupts = m.interrupts end
        end
        return {
            { label = "Your rank", text = rank and (rank .. " / " .. #ranked) or "-", note = #ranked > 1 and "by damage" or "solo" },
            { label = "Your share", value = (mine and total > 0) and mine / total or nil, percent = true, note = "of group damage" },
            { label = "Group DPS", value = session.seconds > 0 and total / session.seconds or 0, note = "while you fought" },
            { label = "Interrupts", value = interrupts, note = myInterrupts .. " yours" },
        }
    end
    local top, total = Model.Ranked(session.spells, 1, {})
    local crit = Model.CritRate(session.hits)
    return {
        { label = "DPS", value = fightDps(last), change = last and Model.Change(fightDps(last), Model.Average(session)) },
        { label = "Damage", value = session.damage, change = last and Model.Change(last.damage, perFight(session, "damage")) },
        { label = "Crit", value = crit, percent = true, note = crit and "of your hits" or "no hits yet" },
        { label = "Top ability", text = top[1] and top[1][1] or "-", note = top[1] and total > 0 and string.format("%d%% of damage", math.floor(top[1][2] / total * 100 + 0.5)) or nil },
    }
end

SA_MeterModel = Model
