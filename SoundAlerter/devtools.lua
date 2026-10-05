local DevTools = {}
SoundAlerter.DevTools = DevTools

local Format = SA_DevFormat

local REFRESH_SECONDS = 1
local MEMORY_SECONDS = 5

local TIMING_MODES = {
    { key = "search", label = "Search" },
    { key = "fuzzy", label = "Fuzzy" },
    { key = "description", label = "Description" },
    { key = "perform", label = "Search + render" },
    { key = "autocomplete", label = "Autocomplete" },
}

local cache = {}
local statusInfo = {}
local memoryInfo = {}
local timingRows = {}
for i, mode in ipairs(TIMING_MODES) do
    timingRows[i] = { label = mode.label }
end

local memoryKB = 0
local memoryReadAt = nil

local function currentMemoryKB(now)
    if not memoryReadAt or now - memoryReadAt >= MEMORY_SECONDS then
        UpdateAddOnMemoryUsage()
        memoryKB = GetAddOnMemoryUsage("SoundAlerter")
        memoryReadAt = now
    end
    return memoryKB
end

local function buildStatus(now)
    local stats = SoundAlerter:GetDatabaseStats()
    statusInfo.isBuilding = stats.isBuilding
    statusInfo.progress = stats.progress
    statusInfo.totalSpells = stats.totalSpells
    statusInfo.lastUpdate = stats.lastUpdate
    statusInfo.now = time()
    statusInfo.builtOnVersion = stats.builtOnVersion
    statusInfo.currentVersion = stats.currentVersion
    statusInfo.memoryKB = currentMemoryKB(now)
    statusInfo.debug = SoundAlerter.db1.profile.debugmode
    return Format.Status(statusInfo)
end

local function buildDatabase()
    local stats = SoundAlerter:GetDatabaseStats()
    stats.now = time()
    return Format.Database(stats)
end

local function buildPerformance(now)
    for i, mode in ipairs(TIMING_MODES) do
        local row = timingRows[i]
        row.p50, row.p95, row.p99, row.max, row.count = SoundAlerter:GetSearchPercentiles(mode.key)
    end

    local stats = SoundAlerter:GetDatabaseStats()
    memoryInfo.cacheEntries = stats.cacheEntries
    memoryInfo.cacheMax = stats.cacheMax
    memoryInfo.prefixBuckets = stats.prefixBuckets
    memoryInfo.memoryKB = currentMemoryKB(now)
    return Format.Timings(timingRows) .. "\n\n" .. Format.Memory(memoryInfo)
end

local BUILDERS = {
    status = buildStatus,
    database = buildDatabase,
    performance = buildPerformance,
}

local function cachedText(key)
    local now = GetTime()
    local entry = cache[key]
    if entry and now - entry.at < REFRESH_SECONDS then
        return entry.text
    end

    if not entry then
        entry = {}
        cache[key] = entry
    end
    entry.at = now
    entry.text = BUILDERS[key](now)
    return entry.text
end

function DevTools:GetStatusText()
    return cachedText("status")
end

function DevTools:GetDatabaseText()
    return cachedText("database")
end

function DevTools:GetPerformanceText()
    return cachedText("performance")
end

function DevTools:Invalidate()
    for _, entry in pairs(cache) do
        entry.at = -math.huge
    end
    memoryReadAt = nil
end
