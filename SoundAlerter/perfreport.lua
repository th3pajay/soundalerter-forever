local SoundAlerter = SoundAlerter
local Plain = SA_COMPAT.Plain

SA_PerfReport = {}
local Report = SA_PerfReport

Report.ADDON = "SoundAlerter"
Report.OVER = { 1, 5, 10, 50, 100 }

function Report.Lines(reading, memoryKb)
    local lines = {
        string.format("Time per frame: recent %.3f ms, session %.3f ms, peak %.1f ms", reading.recent, reading.session, reading.peak),
    }
    local shares = {}
    if reading.appRecent > 0 then
        shares[#shares + 1] = string.format("%.1f%% of the game", reading.recent / reading.appRecent * 100)
    end
    if reading.allRecent > 0 then
        shares[#shares + 1] = string.format("%.1f%% of all addons", reading.recent / reading.allRecent * 100)
    end
    if #shares > 0 then lines[#lines + 1] = "Share of recent frame time: " .. table.concat(shares, ", ") end
    local slow = {}
    for index, limit in ipairs(Report.OVER) do
        slow[index] = string.format("over %d ms %d", limit, reading.over[index] or 0)
    end
    lines[#lines + 1] = "Slow frames this session: " .. table.concat(slow, ", ")
    if memoryKb then lines[#lines + 1] = string.format("Memory: %.1f MB", memoryKb / 1024) end
    return lines
end

local function number(read, ...)
    local ok, value = pcall(read, ...)
    value = ok and Plain(value) or nil
    return type(value) == "number" and value or 0
end

local function memory()
    if InCombatLockdown() or not (UpdateAddOnMemoryUsage and GetAddOnMemoryUsage) then return nil end
    pcall(UpdateAddOnMemoryUsage)
    local ok, value = pcall(GetAddOnMemoryUsage, Report.ADDON)
    value = ok and Plain(value) or nil
    return type(value) == "number" and value or nil
end

local function read()
    local profiler, metric = C_AddOnProfiler, Enum.AddOnProfilerMetric
    local function own(key) return number(profiler.GetAddOnMetric, Report.ADDON, metric[key]) end
    local over = {}
    for index, limit in ipairs(Report.OVER) do over[index] = own("CountTimeOver" .. limit .. "Ms") end
    return {
        recent = own("RecentAverageTime"),
        session = own("SessionAverageTime"),
        peak = own("PeakTime"),
        appRecent = number(profiler.GetApplicationMetric, metric.RecentAverageTime),
        allRecent = number(profiler.GetOverallMetric, metric.RecentAverageTime),
        over = over,
    }
end

function SoundAlerter:PerfReport()
    local kb = memory()
    local lines = {}
    if not (C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric and Enum and Enum.AddOnProfilerMetric) then
        lines[1] = "The game's addon profiler is not available on this client."
    else
        local ok, enabled = pcall(C_AddOnProfiler.IsEnabled)
        if ok and enabled == true then
            lines = Report.Lines(read(), nil)
        else
            lines[1] = "The game's addon profiler is off, so there are no timings."
        end
    end
    if kb then lines[#lines + 1] = string.format("Memory: %.1f MB", kb / 1024) end
    self:Print("|cffFFD700=== SoundAlerter performance ===|r")
    for _, text in ipairs(lines) do self:Print("  " .. text) end
    local global = self.db1 and self.db1.global
    if global then global.perfReport = { at = time(), lines = lines } end
end
