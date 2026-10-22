SA_DevModel = {}

local Model = SA_DevModel

local SECONDS_PER_DAY = 86400
local DEFAULT_MAX_AGE = 2592000

Model.MEMORY_WARN_KB = 10240
Model.MEMORY_SECONDS = 5
Model.TICK_SECONDS = 1
Model.LONG_SCAN_SECONDS = 30
Model.ARM_SECONDS = 5

Model.TIMINGS = {
    { key = "search", label = "Search" },
    { key = "fuzzy", label = "Fuzzy" },
    { key = "description", label = "Description" },
    { key = "perform", label = "Search + render" },
    { key = "autocomplete", label = "Autocomplete" },
}

local function number(value)
    return SA_StatsFormat and SA_StatsFormat.Number(value) or tostring(value)
end

local function plural(count, unit)
    return count .. " " .. unit .. (count == 1 and "" or "s")
end

function Model.Age(seconds, maxAge)
    maxAge = maxAge or DEFAULT_MAX_AGE
    local level = seconds >= maxAge and "warn" or "ok"
    if seconds < 60 then
        return level, "just now"
    elseif seconds < 3600 then
        return level, plural(math.floor(seconds / 60), "minute") .. " ago"
    elseif seconds < SECONDS_PER_DAY then
        return level, plural(math.floor(seconds / 3600), "hour") .. " ago"
    end
    return level, plural(math.floor(seconds / SECONDS_PER_DAY), "day") .. " ago"
end

function Model.BuildOutdated(info)
    return info.builtOnVersion ~= nil and info.builtOnVersion ~= info.currentVersion
end

function Model.Stale(info)
    if not info.lastUpdate or info.lastUpdate <= 0 then return false end
    return info.now - info.lastUpdate >= (info.maxAge or DEFAULT_MAX_AGE)
end

function Model.Verdict(info)
    if info.isBuilding then
        return "warn", "Rebuilding", { "the database is rebuilding, search is limited until it finishes" }
    end
    local reasons = {}
    local level = "ok"
    if (info.totalSpells or 0) == 0 then
        level = "bad"
        reasons[#reasons + 1] = "the spell database is empty, rebuild it"
    end
    if Model.BuildOutdated(info) then
        level = level == "bad" and level or "warn"
        reasons[#reasons + 1] = "the saved database was built on game build " .. info.builtOnVersion .. " and the client is " .. tostring(info.currentVersion)
    end
    if Model.Stale(info) then
        level = level == "bad" and level or "warn"
        local _, age = Model.Age(info.now - info.lastUpdate, info.maxAge)
        reasons[#reasons + 1] = "it was last updated " .. age
    end
    return level, level == "ok" and "Healthy" or "Needs attention", reasons
end

function Model.Eta(progress, seconds)
    local remaining = (seconds or 0) * (100 - (progress or 0)) / 100
    return math.max(1, math.ceil(remaining))
end

function Model.MemoryMB(kb)
    return string.format("%.1f MB", (kb or 0) / 1024)
end

function Model.MemoryLevel(kb)
    return (kb or 0) > Model.MEMORY_WARN_KB and "warn" or "ok"
end

function Model.Vitals(info)
    local ageLevel, ageText
    if info.lastUpdate and info.lastUpdate > 0 then
        ageLevel, ageText = Model.Age(info.now - info.lastUpdate, info.maxAge)
    end
    local build
    if info.builtOnVersion then
        build = Model.BuildOutdated(info) and "bad" or "ok"
    end
    return {
        building = info.isBuilding and true or false,
        progress = info.progress or 0,
        spells = info.totalSpells or 0,
        ageLevel = ageLevel,
        ageText = ageText,
        build = build,
        memoryText = Model.MemoryMB(info.memoryKB),
        memoryLevel = Model.MemoryLevel(info.memoryKB),
        debug = info.debug and true or false,
    }
end

function Model.Signature(info)
    local minutes = info.lastUpdate and info.lastUpdate > 0 and math.floor((info.now - info.lastUpdate) / 60) or -1
    return table.concat({
        info.isBuilding and "b" or "r", math.floor(info.progress or 0), info.totalSpells or 0, minutes,
        info.builtOnVersion or "-", info.currentVersion or "-", info.debug and 1 or 0, math.floor((info.memoryKB or 0) / 100),
        info.cacheEntries or 0, info.source or "-",
    }, "|")
end

function Model.DatabaseRows(info)
    local rows = {}
    if info.isBuilding then
        rows[1] = { "Progress", string.format("%.0f%%", info.progress or 0), "warn" }
        rows[2] = { "Estimated time left", "about " .. Model.Eta(info.progress, info.scanSeconds) .. " s" }
        rows[3] = { "Scanned", number(info.totalScanned or 0) .. " / " .. number(info.scanTotal or info.maxSpellID or 0) .. " IDs" }
        return rows
    end
    local ranked = (info.totalSpells or 0) > 0 and (info.rankedSpells or 0) / info.totalSpells * 100 or 0
    rows[#rows + 1] = { "Spells indexed", number(info.totalSpells or 0) }
    rows[#rows + 1] = { "Unique names", number(info.uniqueNames or 0) }
    rows[#rows + 1] = { "Ranked spells", number(info.rankedSpells or 0) .. string.format(" (%.1f%%)", ranked) }
    if info.lastUpdate and info.lastUpdate > 0 then
        local age = info.now - info.lastUpdate
        local level, text = Model.Age(age, info.maxAge)
        rows[#rows + 1] = { "Updated", text, level }
        local daysLeft = math.max(0, math.ceil(((info.maxAge or DEFAULT_MAX_AGE) - age) / SECONDS_PER_DAY))
        rows[#rows + 1] = { "Auto rebuild", Model.Stale(info) and "due now" or ("in " .. plural(daysLeft, "day") .. " or on a game patch"), Model.Stale(info) and "warn" or nil }
    end
    if info.builtOnVersion then
        if Model.BuildOutdated(info) then
            rows[#rows + 1] = { "Built on", info.builtOnVersion .. " (outdated)", "bad" }
        else
            rows[#rows + 1] = { "Built on", info.builtOnVersion .. " (current)", "ok" }
        end
    end
    if info.source == "built" then
        rows[#rows + 1] = { "Source", string.format("built this session in %.1f s", info.buildSeconds or 0) }
    elseif info.source == "loaded" then
        rows[#rows + 1] = { "Source", "loaded from saved cache" }
    end
    return rows
end

function Model.InternalRows(info)
    local scanTotal = info.scanTotal or info.maxSpellID or 0
    local density = scanTotal > 0 and (info.totalSpells or 0) / scanTotal * 100 or 0
    return {
        { "Scan range", "1 - " .. number(info.maxSpellID or 0) .. (scanTotal < (info.maxSpellID or 0) and " (empty stretch skipped)" or "") },
        { "IDs that are spells", string.format("%.1f%%", density) },
        { "Result cache", (info.cacheEntries or 0) .. " / " .. (info.cacheMax or 0) .. " entries" },
    }
end

function Model.DescriptionRows(description)
    if not description or not description.built then
        return { { "Status", "not built" }, { "Saved size", "0 KB" } }
    end
    return {
        { "Status", description.running and "indexing" or "idle", description.running and "warn" or "ok" },
        { "Indexed", number(description.indexed) .. " texts + " .. number(description.empty) .. " empty of " .. number(description.total) .. string.format(" (%.0f%%)", description.percent) },
        { "Saved size", string.format("%.1f MB", description.kb / 1024) },
    }
end

function Model.TimingScale(rows)
    local scale = 1
    for _, row in ipairs(rows) do
        if row.count and row.count > 0 and row.p99 and row.p99 > scale then scale = row.p99 end
    end
    return scale
end

local function fraction(value, scale)
    return math.max(0, math.min(1, (value or 0) / scale))
end

function Model.TimingBars(row, scale)
    if not row.count or row.count == 0 then return 0, 0, 0 end
    return fraction(row.p50, scale), fraction(row.p95, scale), fraction(row.p99, scale)
end

function Model.TimingText(row)
    if not row.count or row.count == 0 then return "no samples yet" end
    return string.format("%.3g / %.3g / %.3g ms", row.p50, row.p95, row.p99)
end

function Model.RebuildWarning(maxID, seconds)
    local duration
    if seconds >= 90 then
        duration = string.format("%d minutes", math.floor(seconds / 60 + 0.5))
    else
        duration = string.format("%d seconds", math.ceil(seconds))
    end
    return string.format("Indexing spell IDs 1 to %d takes at least %s and can make the game stutter while it runs. Click again to start.", maxID, duration), duration
end

function Model.Report(info, timings, description, version)
    local level, label, reasons = Model.Verdict(info)
    local lines = {}
    lines[#lines + 1] = "SoundAlerter " .. (version or "unknown") .. " on game build " .. tostring(info.currentVersion)
    lines[#lines + 1] = "Verdict: " .. label .. (#reasons > 0 and (" (" .. table.concat(reasons, "; ") .. ")") or "")
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Database:"
    for _, row in ipairs(Model.DatabaseRows(info)) do
        lines[#lines + 1] = "  " .. row[1] .. ": " .. row[2]
    end
    for _, row in ipairs(Model.InternalRows(info)) do
        lines[#lines + 1] = "  " .. row[1] .. ": " .. row[2]
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Description index:"
    for _, row in ipairs(Model.DescriptionRows(description)) do
        lines[#lines + 1] = "  " .. row[1] .. ": " .. row[2]
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Timings (p50 / p95 / p99, samples):"
    for _, row in ipairs(timings) do
        lines[#lines + 1] = "  " .. row.label .. ": " .. Model.TimingText(row) .. ((row.count or 0) > 0 and (" (" .. row.count .. ")") or "")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Memory: " .. Model.MemoryMB(info.memoryKB)
    lines[#lines + 1] = "Debug mode: " .. (info.debug and "on" or "off")
    return table.concat(lines, "\n")
end
