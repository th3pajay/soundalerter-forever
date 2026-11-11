local Model = {}

Model.KEEP = 20
Model.STALE = 3 * 3600
Model.MIN_LENGTH = 30
Model.MAX_ENEMIES = 80
Model.TOP_SPELLS = 3

Model.HARD_CONTROL = { stun = true, fear = true, incapacitate = true, silence = true }

local KIND_LABEL = { arena = "Arena", battleground = "BG" }

local GREY = "|cff888888"
local GOLD = "|cffFFD700"
local LIVE = "|cff3ddc84"
local RESET = "|r"
local DRAW = 255
local RESULT_TEXT = { won = "Won", lost = "Lost", draw = "Draw" }
local RESULT_COLOR = { won = "|cff3ddc84", lost = "|cffff5a4a", draw = GREY }

function Model.KindOf(instanceType)
    if instanceType == "arena" then return "arena" end
    if instanceType == "pvp" then return "battleground" end
    return nil
end

function Model.Open(kind, zone, now, build)
    return {
        kind = kind,
        zone = zone or "Unknown",
        build = build,
        started = now,
        alerts = 0,
        byCategory = {},
        spells = {},
        enemies = {},
        enemyCount = 0,
        cc = { count = 0, timed = 0, seconds = 0, untilAt = 0 },
    }
end

function Model.Continues(match, kind, zone, now)
    if not match or not kind then return false end
    if match.kind ~= kind or match.zone ~= (zone or "Unknown") then return false end
    return now - (match.started or 0) <= Model.STALE
end

function Model.Record(match, category, spellID, sourceName, now)
    match.alerts = match.alerts + 1
    match.last = now or match.last
    match.byCategory[category] = (match.byCategory[category] or 0) + 1
    if spellID then match.spells[spellID] = (match.spells[spellID] or 0) + 1 end
    if sourceName and not match.enemies[sourceName] and match.enemyCount < Model.MAX_ENEMIES then
        match.enemies[sourceName] = true
        match.enemyCount = match.enemyCount + 1
    end
end

local function positive(value)
    return type(value) == "number" and value > 0 and value or nil
end

function Model.Sync(match, clock)
    local cc = match.cc
    if clock < (cc.seen or 0) then cc.untilAt = math.min(cc.untilAt, clock) end
    cc.seen = clock
end

function Model.Control(match, now, remaining, duration)
    Model.Sync(match, now)
    local cc = match.cc
    cc.count = cc.count + 1
    local length = positive(remaining) or positive(duration)
    if not length then return end
    cc.timed = cc.timed + 1
    local finish = now + length
    local from = math.max(now, cc.untilAt)
    if finish > from then
        cc.seconds = cc.seconds + finish - from
        cc.untilAt = finish
    end
end

function Model.Trim(match, now, latest)
    local cc = match.cc
    local finish = math.max(now, latest or now)
    if cc.untilAt <= finish then return false end
    cc.seconds = math.max(0, cc.seconds - (cc.untilAt - finish))
    cc.untilAt = finish
    return true
end

function Model.ControlEnded(match, now)
    return Model.Trim(match, now, now)
end

local function topSpells(spells, nameOf)
    local top = {}
    for spellID, count in pairs(spells) do
        local at = #top + 1
        for index = 1, #top do
            if count > top[index][2] then
                at = index
                break
            end
        end
        if at <= Model.TOP_SPELLS then
            table.insert(top, at, { spellID, count })
            top[Model.TOP_SPELLS + 1] = nil
        end
    end
    for index = 1, #top do
        top[index] = { name = nameOf and nameOf(top[index][1]) or tostring(top[index][1]), count = top[index][2] }
    end
    return top
end

local function emptyMeter()
    return { damage = 0, healing = 0, spells = {} }
end

local function addGain(kept, last, base)
    kept.damage = kept.damage + math.max(0, last.damage - base.damage)
    kept.healing = kept.healing + math.max(0, last.healing - base.healing)
    for spellID, amount in pairs(last.spells) do
        local gain = amount - (base.spells[spellID] or 0)
        if gain > 0 then kept.spells[spellID] = (kept.spells[spellID] or 0) + gain end
    end
end

function Model.Meter(match, reading)
    if not reading then return false end
    local meter = match.meter
    if not meter then
        match.meter = { base = reading, last = reading, kept = emptyMeter() }
        return false
    end
    if reading.damage < meter.last.damage or reading.healing < meter.last.healing then
        addGain(meter.kept, meter.last, meter.base)
        meter.base = emptyMeter()
    end
    meter.last = reading
    return true
end

local function meterTotals(meter)
    if not meter then return nil end
    local totals = emptyMeter()
    addGain(totals, meter.kept, emptyMeter())
    addGain(totals, meter.last, meter.base)
    return totals
end

function Model.Result(match, winner, team, duration)
    local changed = false
    if type(duration) == "number" and duration > 0 then
        match.gameLength = duration
        changed = true
    end
    if type(winner) ~= "number" or type(team) ~= "number" then return changed end
    if winner == DRAW then
        match.result = "draw"
    elseif winner == team then
        match.result = "won"
    elseif winner == 0 or winner == 1 then
        match.result = "lost"
    else
        return changed
    end
    return true
end

function Model.Close(match, now, clock, nameOf)
    local length = math.max(0, now - (match.started or now))
    if length > Model.STALE then length = math.max(0, (match.last or match.started or now) - (match.started or now)) end
    if length < Model.MIN_LENGTH and match.alerts == 0 then return nil end
    if match.gameLength and match.gameLength <= length then length = match.gameLength end
    if clock then Model.Sync(match, clock) end
    local cc = match.cc
    local seconds
    if cc.timed > 0 then
        local overrun = clock and math.max(0, cc.untilAt - clock) or 0
        seconds = math.floor(math.min(length, math.max(0, cc.seconds - overrun)) + 0.5)
    end
    local totals = meterTotals(match.meter)
    return {
        kind = match.kind,
        zone = match.zone,
        build = match.build,
        at = match.started,
        length = length,
        result = match.result,
        alerts = match.alerts,
        byCategory = match.byCategory,
        spells = topSpells(match.spells, nameOf),
        enemies = match.enemyCount,
        ccCount = cc.count,
        ccSeconds = seconds,
        ccPartial = cc.timed > 0 and cc.timed < cc.count or nil,
        damage = totals and totals.damage > 0 and totals.damage or nil,
        healing = totals and totals.healing > 0 and totals.healing or nil,
        damageSpells = totals and totals.damage > 0 and topSpells(totals.spells, nameOf) or nil,
    }
end

function Model.Push(list, record, keep)
    table.insert(list, 1, record)
    for index = #list, (keep or Model.KEEP) + 1, -1 do list[index] = nil end
end

function Model.Clock(seconds)
    seconds = math.floor(seconds or 0)
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function controlText(count, seconds, partial)
    if (count or 0) == 0 then return "no CC" end
    if not seconds then return "CC x" .. count end
    return "CC " .. seconds .. "s" .. (partial and "+" or "") .. " x" .. count
end

function Model.Amount(value)
    value = value or 0
    if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
    if value >= 10000 then return string.format("%.0fk", value / 1000) end
    if value >= 1000 then return string.format("%.1fk", value / 1000) end
    return tostring(math.floor(value))
end

local function damageSpellText(record)
    local parts = {}
    for index = 1, #(record.damageSpells or {}) do
        local spell = record.damageSpells[index]
        parts[index] = spell.name .. " " .. math.floor(spell.count / record.damage * 100 + 0.5) .. "%"
    end
    return table.concat(parts, ", ")
end

local function meterText(record, grey, reset)
    local parts = {}
    if record.damage then
        local spells = damageSpellText(record)
        parts[#parts + 1] = "Damage " .. Model.Amount(record.damage) ..
            (spells ~= "" and (" " .. grey .. "(" .. spells .. ")" .. reset) or "")
    end
    if record.healing then parts[#parts + 1] = "Healing " .. Model.Amount(record.healing) end
    return table.concat(parts, "  ")
end

local function spellText(spells)
    local parts = {}
    for index = 1, #(spells or {}) do
        parts[index] = spells[index].name .. " x" .. spells[index].count
    end
    return table.concat(parts, ", ")
end

function Model.LiveRow(match, now, clock)
    local cc = match.cc
    local seconds = cc.timed > 0 and math.floor(math.max(0, cc.seconds - math.max(0, cc.untilAt - (clock or 0))) + 0.5) or nil
    return LIVE .. "Live" .. RESET .. "  " .. (KIND_LABEL[match.kind] or match.kind) .. "  " .. match.zone ..
        "  " .. GOLD .. Model.Clock(now - match.started) .. RESET ..
        "  " .. match.alerts .. " alerts  " .. controlText(cc.count, seconds, cc.timed > 0 and cc.timed < cc.count)
end

function Model.Summary(list)
    local counts = { arena = { won = 0, total = 0 }, battleground = { won = 0, total = 0 } }
    local won, total = 0, 0
    for index = 1, #(list or {}) do
        local record = list[index]
        local count = counts[record.kind]
        if record.result and count then
            total = total + 1
            count.total = count.total + 1
            if record.result == "won" then
                won = won + 1
                count.won = count.won + 1
            end
        end
    end
    if total == 0 then return nil end
    local parts = { GOLD .. "Won " .. won .. " of " .. total .. RESET }
    for _, kind in ipairs({ "arena", "battleground" }) do
        local count = counts[kind]
        if count.total > 0 then parts[#parts + 1] = KIND_LABEL[kind] .. " " .. count.won .. " of " .. count.total end
    end
    return table.concat(parts, "  ")
end

function Model.Row(record, now, ago)
    local spells = spellText(record.spells)
    local meter = meterText(record, GREY, RESET)
    local result = record.result and ("  " .. RESULT_COLOR[record.result] .. RESULT_TEXT[record.result] .. RESET) or ""
    return GREY .. (ago and ago(now, record.at) or "") .. RESET .. "  " .. (KIND_LABEL[record.kind] or record.kind) ..
        "  " .. record.zone .. result .. "  " .. GOLD .. Model.Clock(record.length) .. RESET ..
        "  " .. record.alerts .. " alerts  " .. (record.enemies or 0) .. " enemies  " ..
        controlText(record.ccCount, record.ccSeconds, record.ccPartial) ..
        (meter ~= "" and ("  " .. meter) or "") ..
        (spells ~= "" and ("  " .. GREY .. spells .. RESET) or "")
end

function Model.Tally(list)
    local won, total = 0, 0
    for index = 1, #(list or {}) do
        local record = list[index]
        if record.result and (record.kind == "arena" or record.kind == "battleground") then
            total = total + 1
            if record.result == "won" then won = won + 1 end
        end
    end
    return won, total
end

function Model.Rows(list, open, now, clock, ago, limit)
    local rows = {}
    local summary = Model.Summary(list)
    if summary then rows[1] = summary end
    if open then rows[#rows + 1] = Model.LiveRow(open, now, clock) end
    local count = #(list or {})
    if limit and limit < count then count = limit end
    for index = 1, count do rows[#rows + 1] = Model.Row(list[index], now, ago) end
    if #rows == 0 then
        return GREY .. "No arena or battleground match recorded yet. A match runs from entering the instance until you leave it." .. RESET
    end
    return table.concat(rows, "\n")
end

function Model.ExportLines(lines, list, categories)
    lines[#lines + 1] = "Recent matches:"
    if not list or #list == 0 then
        lines[#lines + 1] = "(none recorded yet)"
        return lines
    end
    for index = 1, #list do
        local record = list[index]
        local parts = {}
        for _, category in ipairs(categories or {}) do
            local count = record.byCategory and record.byCategory[category.key]
            if count and count > 0 then parts[#parts + 1] = category.label .. " " .. count end
        end
        lines[#lines + 1] = string.format("%d. %s %s %s | %d alerts (%s) | %d enemies | %s | %s | %s", index,
            date("%Y-%m-%d %H:%M", record.at or 0), KIND_LABEL[record.kind] or record.kind, record.zone,
            record.alerts or 0, #parts > 0 and table.concat(parts, ", ") or "none", record.enemies or 0,
            controlText(record.ccCount, record.ccSeconds, record.ccPartial), Model.Clock(record.length),
            record.build and ("build " .. record.build) or "unknown build")
        if record.result then lines[#lines] = lines[#lines] .. " | " .. RESULT_TEXT[record.result] end
        local spells = spellText(record.spells)
        if spells ~= "" then lines[#lines] = lines[#lines] .. " | " .. spells end
        local meter = meterText(record, "", "")
        if meter ~= "" then lines[#lines] = lines[#lines] .. " | " .. meter end
    end
    return lines
end

SA_DebriefModel = Model
