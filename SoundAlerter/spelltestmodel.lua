local SoundAlerter = SoundAlerter
local Model = {}

local MAX_GROUPS = 400
local MAX_SPELLS = 300
local ENEMY_UNIT_KINDS = { target = true, focus = true, nameplate = true, arena = true }
local CAST_EVENTS = {
    UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_SUCCEEDED = true, UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_FAILED = true,
}

local function percent(part, whole)
    if whole == 0 then return 0 end
    return math.floor(part / whole * 100 + 0.5)
end

function Model.NewRun(now, build)
    return { startedAt = now, build = build, groups = {}, groupCount = 0, spells = {}, spellCount = 0, zones = {}, samples = 0 }
end

function Model.Stop(run, now)
    if not run.stoppedAt then run.stoppedAt = now end
end

function Model.Record(run, sample)
    local secrets = sample.secretsActive and "secrets on" or "secrets off"
    local key = sample.event .. " | " .. sample.unitKind .. " | " .. secrets
    local group = run.groups[key]
    if not group then
        if run.groupCount >= MAX_GROUPS then return end
        group = { event = sample.event, unitKind = sample.unitKind, secrets = secrets, total = 0, spellReadable = 0, classReadable = 0, enemy = 0, player = 0, payloadReadable = 0, extraSeen = 0, extraReadable = 0 }
        run.groups[key] = group
        run.groupCount = run.groupCount + 1
    end
    group.total = group.total + 1
    if sample.spellReadable then group.spellReadable = group.spellReadable + 1 end
    if sample.classReadable then group.classReadable = group.classReadable + 1 end
    if sample.isEnemy then group.enemy = group.enemy + 1 end
    if sample.isPlayer then group.player = group.player + 1 end
    if sample.payloadReadable then group.payloadReadable = group.payloadReadable + 1 end
    if sample.extraSeen then group.extraSeen = group.extraSeen + 1 end
    if sample.extraReadable then group.extraReadable = group.extraReadable + 1 end

    run.samples = run.samples + 1
    local zone = sample.zone or "unknown"
    run.zones[zone] = (run.zones[zone] or 0) + 1

    if sample.spellReadable and type(sample.spellID) == "number" then
        local spell = run.spells[sample.spellID]
        if not spell then
            if run.spellCount >= MAX_SPELLS then return end
            spell = { name = sample.spellName or "?", count = 0, enemyCount = 0, events = {} }
            run.spells[sample.spellID] = spell
            run.spellCount = run.spellCount + 1
        end
        spell.count = spell.count + 1
        if sample.isEnemy then spell.enemyCount = spell.enemyCount + 1 end
        spell.events[sample.event] = (spell.events[sample.event] or 0) + 1
    end
end

local function sortedGroups(run)
    local list = {}
    for _, group in pairs(run.groups) do list[#list + 1] = group end
    table.sort(list, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.event .. a.unitKind < b.event .. b.unitKind
    end)
    return list
end

function Model.EnemyCastReadability(run)
    local total, readable = 0, 0
    for _, group in pairs(run.groups) do
        if CAST_EVENTS[group.event] and ENEMY_UNIT_KINDS[group.unitKind] then
            total = total + group.enemy
            readable = readable + math.min(group.enemy, group.spellReadable)
        end
    end
    return total, readable
end

function Model.Report(run, now, maxGroups)
    local lines = {}
    local ended = run.stoppedAt or now
    local minutes = math.max(0, math.floor((ended - run.startedAt) / 60))
    local zones = {}
    for zone, count in pairs(run.zones) do zones[#zones + 1] = zone .. " " .. count end
    table.sort(zones)
    lines[#lines + 1] = string.format("%d samples in %d min (%s) | build %s | %s", run.samples, minutes, run.stoppedAt and "stopped" or "running", tostring(run.build), #zones > 0 and table.concat(zones, ", ") or "no zones yet")

    local list = sortedGroups(run)
    for index = 1, math.min(#list, maxGroups or 14) do
        local group = list[index]
        local line = string.format("%s | %s | %s: %d events, spell %d%%, class %d%%, enemy %d%%", group.event, group.unitKind, group.secrets, group.total, percent(group.spellReadable, group.total), percent(group.classReadable, group.total), percent(group.enemy, group.total))
        if group.event == "UNIT_AURA" then
            line = line .. string.format(", payload %d%%", percent(group.payloadReadable, group.total))
        elseif group.extraSeen > 0 then
            line = line .. string.format(", 4th value %d%%", percent(group.extraReadable, group.extraSeen))
        end
        lines[#lines + 1] = line
    end
    if #list > (maxGroups or 14) then lines[#lines + 1] = string.format("... and %d more groups saved", #list - (maxGroups or 14)) end

    local seen = {}
    for id, spell in pairs(run.spells) do seen[#seen + 1] = { id = id, spell = spell } end
    table.sort(seen, function(a, b) return a.spell.count > b.spell.count end)
    if #seen > 0 then
        local names = {}
        for index = 1, math.min(#seen, 5) do names[#names + 1] = seen[index].spell.name .. " x" .. seen[index].spell.count end
        lines[#lines + 1] = string.format("Readable spells seen: %d distinct (top: %s)", #seen, table.concat(names, ", "))
    else
        lines[#lines + 1] = "Readable spells seen: none"
    end

    local total, readable = Model.EnemyCastReadability(run)
    if total > 0 then
        lines[#lines + 1] = string.format("Enemy cast events with a readable spell ID: %d of %d (%d%%)", readable, total, percent(readable, total))
    else
        lines[#lines + 1] = "No enemy cast events yet. Target or focus an enemy player and let them cast."
    end
    return lines
end

SoundAlerter.SpellTestModel = Model
