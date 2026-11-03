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

function Model.Close(match, now, clock, nameOf)
    local length = math.max(0, now - (match.started or now))
    if length > Model.STALE then length = math.max(0, (match.last or match.started or now) - (match.started or now)) end
    if length < Model.MIN_LENGTH and match.alerts == 0 then return nil end
    if clock then Model.Sync(match, clock) end
    local cc = match.cc
    local seconds
    if cc.timed > 0 then
        local overrun = clock and math.max(0, cc.untilAt - clock) or 0
        seconds = math.floor(math.min(length, math.max(0, cc.seconds - overrun)) + 0.5)
    end
    return {
        kind = match.kind,
        zone = match.zone,
        build = match.build,
        at = match.started,
        length = length,
        alerts = match.alerts,
        byCategory = match.byCategory,
        spells = topSpells(match.spells, nameOf),
        enemies = match.enemyCount,
        ccCount = cc.count,
        ccSeconds = seconds,
        ccPartial = cc.timed > 0 and cc.timed < cc.count or nil,
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

function Model.Row(record, now, ago)
    local spells = spellText(record.spells)
    return GREY .. (ago and ago(now, record.at) or "") .. RESET .. "  " .. (KIND_LABEL[record.kind] or record.kind) ..
        "  " .. record.zone .. "  " .. GOLD .. Model.Clock(record.length) .. RESET ..
        "  " .. record.alerts .. " alerts  " .. (record.enemies or 0) .. " enemies  " ..
        controlText(record.ccCount, record.ccSeconds, record.ccPartial) ..
        (spells ~= "" and ("  " .. GREY .. spells .. RESET) or "")
end

function Model.Rows(list, open, now, clock, ago)
    local rows = {}
    if open then rows[1] = Model.LiveRow(open, now, clock) end
    for index = 1, #(list or {}) do rows[#rows + 1] = Model.Row(list[index], now, ago) end
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
        local spells = spellText(record.spells)
        if spells ~= "" then lines[#lines] = lines[#lines] .. " | " .. spells end
    end
    return lines
end

SA_DebriefModel = Model
