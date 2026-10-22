local DevTools = {}
SoundAlerter.DevTools = DevTools

local Model = SA_DevModel

local info = {}
local timings = {}
for index, mode in ipairs(Model.TIMINGS) do
    timings[index] = { key = mode.key, label = mode.label }
end

local memoryKB = 0
local memoryReadAt = nil

local function readMemory(force)
    local now = GetTime()
    if force or not memoryReadAt or now - memoryReadAt >= Model.MEMORY_SECONDS then
        UpdateAddOnMemoryUsage()
        memoryKB = GetAddOnMemoryUsage("SoundAlerter")
        memoryReadAt = now
    end
end

local function addonVersion()
    local read = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return read and read("SoundAlerter", "Version") or "unknown"
end

function DevTools:Snapshot(wantMemory, forceMemory)
    local stats = SoundAlerter:GetDatabaseStats()
    info.isBuilding = stats.isBuilding
    info.progress = stats.progress
    info.totalScanned = stats.totalScanned
    info.maxSpellID = stats.maxSpellID
    info.scanTotal = stats.scanTotal
    info.maxAge = stats.maxAge
    info.totalSpells = stats.totalSpells
    info.uniqueNames = stats.uniqueNames
    info.rankedSpells = stats.rankedSpells
    info.lastUpdate = stats.lastUpdate
    info.builtOnVersion = stats.builtOnVersion
    info.currentVersion = stats.currentVersion
    info.source = stats.source
    info.buildSeconds = stats.buildSeconds
    info.cacheEntries = stats.cacheEntries
    info.cacheMax = stats.cacheMax
    if wantMemory or forceMemory or not memoryReadAt then
        readMemory(forceMemory)
    end
    info.memoryKB = memoryKB
    info.now = time()
    info.debug = SoundAlerter.db1.profile.debugmode
    info.addonVersion = addonVersion()
    if stats.isBuilding then
        local _, seconds = SoundAlerter:GetSpellScanInfo()
        info.scanSeconds = seconds
    else
        info.scanSeconds = nil
    end
    return info
end

function DevTools:Timings()
    for index, mode in ipairs(Model.TIMINGS) do
        local row = timings[index]
        row.p50, row.p95, row.p99, row.max, row.count = SoundAlerter:GetSearchPercentiles(mode.key)
    end
    return timings
end

function DevTools:Description()
    return SoundAlerter:GetDescriptionInfo()
end

function DevTools:Report()
    local snapshot = self:Snapshot(true, true)
    return Model.Report(snapshot, self:Timings(), self:Description(), snapshot.addonVersion)
end

function DevTools:RebuildInfo()
    local maxID, seconds = SoundAlerter:GetSpellScanInfo()
    local warning, duration = Model.RebuildWarning(maxID, seconds)
    return maxID, seconds, warning, duration
end

function DevTools:Rebuild()
    local maxID, seconds, _, duration = self:RebuildInfo()
    local function startScan()
        self:Invalidate()
        SoundAlerter:RebuildSpellDatabase()
    end
    if seconds < Model.LONG_SCAN_SECONDS then
        startScan()
        return
    end
    StaticPopupDialogs["SOUNDALERTER_CONFIRM_SPELL_SCAN"] = {
        text = string.format("|cffFF4040FINAL CONFIRMATION|r\n\nThis starts a full spell index (IDs 1 to %d). It takes at least %s and you may notice stuttering until it finishes. Start the scan now?", maxID, duration),
        button1 = "Start scan",
        button2 = CANCEL,
        OnAccept = startScan,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("SOUNDALERTER_CONFIRM_SPELL_SCAN")
end

function DevTools:SetFinderFlag(key, value)
    SoundAlerter:SetFinderOption(key, value)
    SoundAlerter:SyncFinderControls()
end

function DevTools:SetScope(value)
    SoundAlerter:SetSearchScope(value)
end

function DevTools:SetDebug(value)
    SoundAlerter.db1.profile.debugmode = value
    self:Invalidate()
end

function DevTools:Invalidate()
    memoryReadAt = nil
end
