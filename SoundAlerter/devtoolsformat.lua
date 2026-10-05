local Format = {}

local StatsFormat = SA_StatsFormat

local GREY = "|cff888888"
local WHITE = "|cffFFFFFF"
local GOLD = "|cffFFD700"
local GREEN = "|cff00FF00"
local AMBER = "|cffFFAA00"
local RED = "|cffFF5555"
local RESET = "|r"

local SECONDS_PER_DAY = 86400
local MEMORY_WARN_KB = 10240

local function plural(count, unit)
    return count .. " " .. unit .. (count == 1 and "" or "s")
end

function Format.Age(seconds)
    if seconds < 60 then
        return GREEN, "just now"
    elseif seconds < 3600 then
        return "|cff88FF88", plural(math.floor(seconds / 60), "minute") .. " ago"
    elseif seconds < SECONDS_PER_DAY then
        return GOLD, plural(math.floor(seconds / 3600), "hour") .. " ago"
    end
    return AMBER, plural(math.floor(seconds / SECONDS_PER_DAY), "day") .. " ago"
end

local function line(label, value)
    return GREY .. label .. RESET .. "  " .. value
end

local function megabytes(kb)
    local color = kb > MEMORY_WARN_KB and AMBER or GREEN
    return color .. string.format("%.1f MB", kb / 1024) .. RESET
end

function Format.Status(info)
    local parts = {}

    if info.isBuilding then
        parts[1] = StatsFormat.Bar(8, 8, 255, 170, 0) .. " " .. AMBER .. string.format("Building %.0f%%", info.progress) .. RESET
    else
        parts[1] = StatsFormat.Bar(8, 8, 0, 255, 0) .. " " .. GREEN .. "Ready" .. RESET
    end

    parts[#parts + 1] = GOLD .. StatsFormat.Number(info.totalSpells) .. RESET .. " spells"

    if info.lastUpdate > 0 then
        local color, age = Format.Age(info.now - info.lastUpdate)
        parts[#parts + 1] = "updated " .. color .. age .. RESET
    end

    if info.builtOnVersion then
        if info.builtOnVersion == info.currentVersion then
            parts[#parts + 1] = "build " .. GREEN .. "current" .. RESET
        else
            parts[#parts + 1] = "build " .. RED .. "outdated" .. RESET
        end
    end

    parts[#parts + 1] = megabytes(info.memoryKB)
    parts[#parts + 1] = "debug " .. (info.debug and AMBER .. "on" or GREY .. "off") .. RESET

    return table.concat(parts, "     ")
end

function Format.Database(info)
    local lines = {}

    if info.isBuilding then
        lines[1] = line("Status", AMBER .. "Building database" .. RESET)
        lines[2] = line("Progress", string.format("%.1f%% complete", info.progress))
        lines[3] = line("Scanned", StatsFormat.Number(info.totalScanned) .. " / " .. StatsFormat.Number(info.maxSpellID) .. " spell IDs")
        return table.concat(lines, "\n")
    end

    local ranked = info.totalSpells > 0 and info.rankedSpells / info.totalSpells * 100 or 0
    local density = info.maxSpellID > 0 and info.totalSpells / info.maxSpellID * 100 or 0

    lines[#lines + 1] = line("Spells indexed", GOLD .. StatsFormat.Number(info.totalSpells) .. RESET)
    lines[#lines + 1] = line("Unique names", StatsFormat.Number(info.uniqueNames))
    lines[#lines + 1] = line("Ranked spells", StatsFormat.Number(info.rankedSpells) .. GREY .. string.format(" (%.1f%%)", ranked) .. RESET)
    lines[#lines + 1] = line("Scan range", "1 - " .. StatsFormat.Number(info.maxSpellID) .. GREY .. string.format(" (%.1f%% of IDs are spells)", density) .. RESET)

    if info.lastUpdate > 0 then
        local age = info.now - info.lastUpdate
        local color, text = Format.Age(age)
        local daysLeft = math.max(0, math.ceil((info.maxAge - age) / SECONDS_PER_DAY))
        lines[#lines + 1] = line("Last updated", color .. text .. RESET)
        lines[#lines + 1] = line("Auto-rebuild", "in " .. plural(daysLeft, "day") .. GREY .. " (or on game patch)" .. RESET)
    end

    if info.source == "built" then
        lines[#lines + 1] = line("Source", string.format("Built this session in %.1fs", info.buildSeconds or 0))
    elseif info.source == "loaded" then
        lines[#lines + 1] = line("Source", "Loaded from saved cache")
    end

    if info.builtOnVersion then
        if info.builtOnVersion == info.currentVersion then
            lines[#lines + 1] = line("Game build", info.builtOnVersion .. GREEN .. " (current)" .. RESET)
        else
            lines[#lines + 1] = line("Game build", info.builtOnVersion .. RED .. " (current: " .. info.currentVersion .. ")" .. RESET)
        end
    end

    return table.concat(lines, "\n")
end

function Format.Timings(rows)
    local lines = {}
    for i, row in ipairs(rows) do
        if row.count and row.count > 0 then
            lines[i] = WHITE .. row.label .. RESET .. "   p50 " .. string.format("%.3f", row.p50) ..
                "   p95 " .. string.format("%.3f", row.p95) ..
                "   p99 " .. string.format("%.3f", row.p99) ..
                "   max " .. string.format("%.3f", row.max) ..
                GREY .. " ms  (" .. row.count .. " samples)" .. RESET
        else
            lines[i] = WHITE .. row.label .. RESET .. "   " .. GREY .. "no samples yet this session" .. RESET
        end
    end
    return table.concat(lines, "\n")
end

function Format.Memory(info)
    return table.concat({
        line("Result cache", info.cacheEntries .. " / " .. info.cacheMax .. " entries"),
        line("Prefix index", StatsFormat.Number(info.prefixBuckets) .. " buckets"),
        line("Addon memory", megabytes(info.memoryKB) .. GREY .. " (total)" .. RESET),
    }, "\n")
end

SA_DevFormat = Format
