local SoundAlerter = SoundAlerter

local pairs, ipairs, tonumber, pcall = pairs, ipairs, tonumber, pcall
local table_insert, table_sort, table_remove = table.insert, table.sort, table.remove
local string_lower, string_sub, string_match, string_find, string_format = string.lower, string.sub, string.match, string.find, string.format
local math_min, math_max, math_floor = math.min, math.max, math.floor
local time = time
local GetSpellInfo, GetSpellLink = SA_COMPAT.GetSpellInfo, SA_COMPAT.GetSpellLink
local GetSpellDescription, GetSpellSubtext = SA_COMPAT.GetSpellDescription, SA_COMPAT.GetSpellSubtext
local IsSpellPassive, IsSpellKnown = SA_COMPAT.IsSpellPassive, SA_COMPAT.IsSpellKnown
local GetSpellCosts, GetSpellMaxCharges = SA_COMPAT.GetSpellCosts, SA_COMPAT.GetSpellMaxCharges
local FinderFormat = SA_FinderFormat
local GetBuildInfo = GetBuildInfo

local SCAN_SEGMENTS = { { 1, 520000 }, { 1150000, 1400000 } }
local SUBTEXT_MAX_ID = 70000
local MAX_SPELL_ID = SCAN_SEGMENTS[#SCAN_SEGMENTS][2]
local SCAN_TOTAL = 0
local SCAN_KEY
do
    local parts = {}
    for index, segment in ipairs(SCAN_SEGMENTS) do
        SCAN_TOTAL = SCAN_TOTAL + segment[2] - segment[1] + 1
        parts[index] = segment[1] .. "-" .. segment[2]
    end
    SCAN_KEY = table.concat(parts, ",")
end
local MIN_INNER_SUGGEST_CHARS = 3
local SCAN_CHUNK_SIZE = 4000
local SCAN_CHUNK_DELAY = 0.03
local DB_MAX_AGE = 2592000
local DB_FORMAT = 3
local PACK = 1000
local MAX_CACHE_ROWS = 4000

function SoundAlerter:GetSpellScanInfo()
    local seconds = math.ceil(SCAN_TOTAL / SCAN_CHUNK_SIZE) * SCAN_CHUNK_DELAY
    return MAX_SPELL_ID, seconds
end

SoundAlerter.spellScanKey = SCAN_KEY

SoundAlerter.spellDatabase = {
    ids = {},
    packed = {},
    names = {},
    namesLower = {},
    nameToIdx = {},
    searchCache = {},
    isBuilding = false,
    progress = 0,
    totalScanned = 0,
    totalSpells = 0,
    lastUpdate = 0,
    rankedSpells = 0,
    source = nil,
    buildSeconds = nil,
    builtOnVersion = nil
}

local cacheAge = {}
local cacheRows = {}
local cacheRowTotal = 0
local MAX_CACHE_SIZE = 10

local SEARCH_TIMING_SAMPLE_CAP = 100
local TIMING_MODES = {"search", "fuzzy", "description", "perform", "autocomplete"}
local searchTimings = {}
for _, mode in ipairs(TIMING_MODES) do
    searchTimings[mode] = {samples = {}, index = 1, count = 0}
end

local function RecordSearchTiming(elapsedMs, mode)
    local bucket = searchTimings[mode or "search"]
    bucket.samples[bucket.index] = elapsedMs
    bucket.index = (bucket.index % SEARCH_TIMING_SAMPLE_CAP) + 1
    if bucket.count < SEARCH_TIMING_SAMPLE_CAP then
        bucket.count = bucket.count + 1
    end
end

local bit_band, bit_bor, bit_bnot, bit_lshift = bit.band, bit.bor, bit.bnot, bit.lshift
local string_byte = string.byte

local function LetterMask(text)
    local mask = 0
    for i = 1, #text do
        local byte = string_byte(text, i)
        if byte >= 97 and byte <= 122 then
            mask = bit_bor(mask, bit_lshift(1, byte - 97))
        end
    end
    return mask
end

local function WordInitialMask(text)
    local mask = 0
    local inWord = false
    for i = 1, #text do
        local byte = string_byte(text, i)
        local isLetter = byte >= 97 and byte <= 122
        if isLetter and not inWord then
            mask = bit_bor(mask, bit_lshift(1, byte - 97))
        end
        inWord = isLetter
    end
    return mask
end

local function PopcountWithin(value, limit)
    while value ~= 0 do
        if limit == 0 then
            return false
        end
        value = bit_band(value, value - 1)
        limit = limit - 1
    end
    return true
end

local SORT_COMPARATORS = {
    relevance = function(a, b)
        if a.score ~= b.score then
            return a.score < b.score
        end
        if a.baseName ~= b.baseName then
            return a.baseName < b.baseName
        end
        if a.rankNum ~= b.rankNum then
            return a.rankNum < b.rankNum
        end
        return a.spellID < b.spellID
    end,
    name = function(a, b)
        if a.baseName ~= b.baseName then
            return a.baseName < b.baseName
        end
        if a.rankNum ~= b.rankNum then
            return a.rankNum < b.rankNum
        end
        return a.spellID < b.spellID
    end,
    spellid = function(a, b) return a.spellID < b.spellID end,
    rank = function(a, b)
        if a.rankNum ~= b.rankNum then
            return a.rankNum < b.rankNum
        end
        if a.baseName ~= b.baseName then
            return a.baseName < b.baseName
        end
        return a.spellID < b.spellID
    end,
}

local function SafeRead(reader, spellID)
    if not reader then return nil end
    local ok, value = pcall(reader, spellID)
    if ok then return value end
    return nil
end

local function ReadSpellProps(spellID)
    return {
        passive = SafeRead(IsSpellPassive, spellID),
        known = SafeRead(IsSpellKnown, spellID),
        costs = SafeRead(GetSpellCosts, spellID),
        maxCharges = SafeRead(GetSpellMaxCharges, spellID),
    }
end

local function ReverseComparator(comparator)
    return function(a, b) return comparator(b, a) end
end

local REVERSED_COMPARATORS = {}
for mode, comparator in pairs(SORT_COMPARATORS) do
    REVERSED_COMPARATORS[mode] = ReverseComparator(comparator)
end

local function LowerBound(ids, spellID)
    local low, high = 1, #ids + 1
    while low < high do
        local mid = math_floor((low + high) / 2)
        if ids[mid] < spellID then
            low = mid + 1
        else
            high = mid
        end
    end
    return low
end

function SoundAlerter:AddSpellToDatabase(spellID, name, rank)
    local db = self.spellDatabase
    local nameToIdx = db.nameToIdx
    local names = db.names
    local namesLower = db.namesLower

    local baseName = string_match(name, "^(.-)%s*%(") or name
    local lowerName = string_lower(baseName)

    local nameIdx = nameToIdx[lowerName]
    if not nameIdx then
        nameIdx = #names + 1
        names[nameIdx] = baseName
        namesLower[nameIdx] = lowerName
        nameToIdx[lowerName] = nameIdx
    end

    local rankNum = 0
    if rank and rank ~= "" then
        rankNum = tonumber(string_match(rank, "%d+")) or 0
    else
        local rankInName = string_match(name, "%(Rank%s*(%d+)%)")
        if rankInName then
            rankNum = tonumber(rankInName) or 0
        end
    end

    local ids, packed = db.ids, db.packed
    local value = nameIdx * PACK + math_min(rankNum, PACK - 1)
    local count = #ids
    if count == 0 or spellID > ids[count] then
        ids[count + 1] = spellID
        packed[count + 1] = value
        db.totalSpells = count + 1
        return
    end

    local at = LowerBound(ids, spellID)
    if ids[at] == spellID then
        packed[at] = value
    else
        table_insert(ids, at, spellID)
        table_insert(packed, at, value)
    end
    db.totalSpells = #ids
end

function SoundAlerter:BuildSpellDatabase()
    local db = self.spellDatabase
    db.ensured = true

    if db.isBuilding then
        return
    end

    db.isBuilding = true
    db.progress = 0
    db.totalScanned = 0
    local buildStartMs = debugprofilestop()
    db.namesLower = db.namesLower or {}
    db.nameToIdx = db.nameToIdx or {}

    local CHUNK_SIZE = SCAN_CHUNK_SIZE
    local CHUNK_DELAY = SCAN_CHUNK_DELAY
    local segmentIndex = 1
    local currentID = SCAN_SEGMENTS[1][1]
    local scanned = 0
    local ProcessChunk
    local AddSpellToDatabase = self.AddSpellToDatabase

    local function ReadSpell(spellID)
        local name, rank = GetSpellInfo(spellID)
        if name and (not rank or rank == "") and spellID <= SUBTEXT_MAX_ID then
            rank = GetSpellSubtext(spellID)
        end
        return name, rank
    end

    local function ScanChunk(fromID, toID, safe)
        for spellID = fromID, toID do
            local name, rank
            if safe then
                local ok
                ok, name, rank = pcall(ReadSpell, spellID)
                if not ok then name = nil end
            else
                name, rank = ReadSpell(spellID)
            end
            if name then
                AddSpellToDatabase(self, spellID, name, rank)
            end
        end
    end

    local function ProcessChunkInner(safe)
        local segmentEnd = SCAN_SEGMENTS[segmentIndex][2]
        local endID = math_min(currentID + CHUNK_SIZE - 1, segmentEnd)

        ScanChunk(currentID, endID, safe)

        scanned = scanned + (endID - currentID + 1)
        db.totalScanned = scanned
        db.progress = (scanned / SCAN_TOTAL) * 100

        if endID >= segmentEnd then
            segmentIndex = segmentIndex + 1
            local nextSegment = SCAN_SEGMENTS[segmentIndex]
            currentID = nextSegment and nextSegment[1] or nil
        else
            currentID = endID + 1
        end

        if currentID then
            self:ScheduleTimer(ProcessChunk, CHUNK_DELAY)
        else
            self:BuildSearchIndexes()
            self:TrimDerivedNames()
            db.isBuilding = false
            db.lastUpdate = time()
            db.source = "built"
            db.buildSeconds = (debugprofilestop() - buildStartMs) / 1000
            db.builtOnVersion = GetBuildInfo()

            local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
            if AceConfigRegistry then
                AceConfigRegistry:NotifyChange("SoundAlerter")
            end

            self:SaveSpellDatabase()

            local spellCount = self:CountSpells()
            self:Print(string_format("Spell database built: %d spells indexed in %.0f seconds", spellCount, db.buildSeconds or 0))
        end
    end

    function ProcessChunk()
        local ok, err = pcall(ProcessChunkInner, false)
        if not ok then
            ok, err = pcall(ProcessChunkInner, true)
        end
        if not ok then
            db.isBuilding = false
            self:Print("|cffFF7D0ASoundAlerter|r: Spell database build failed and was stopped — "..tostring(err))
        end
    end

    local maxID, minimumSeconds = self:GetSpellScanInfo()
    local estimate = minimumSeconds >= 90
        and string_format("at least %d minutes", math.floor(minimumSeconds / 60 + 0.5))
        or string_format("at least %d seconds", math.ceil(minimumSeconds))
    self:Print(string_format("Building spell database: scanning spell IDs 1 to %d (skipping the empty stretch). This takes %s, longer on a slower PC. Progress shows in Developer Tools > Database.", maxID, estimate))
    ProcessChunk()
end

function SoundAlerter:SaveSpellDatabase()
    SoundAlerterSpellDB = {
        ids = self.spellDatabase.ids,
        packed = self.spellDatabase.packed,
        names = self.spellDatabase.names,
        totalSpells = self.spellDatabase.totalSpells,
        version = GetBuildInfo(),
        format = DB_FORMAT,
        scanKey = SCAN_KEY,
        lastUpdate = time()
    }
end

function SoundAlerter:EnsureSpellDatabase()
    local db = self.spellDatabase
    if db.ensured then return end
    db.ensured = true
    if not self:LoadSpellDatabase() then
        self:BuildSpellDatabase()
    end
end

function SoundAlerter:EnsureNamesLower()
    local db = self.spellDatabase
    local lower = db.namesLower
    if lower then return lower end
    local names = db.names
    lower = {}
    for i = 1, #names do
        lower[i] = string_lower(names[i])
    end
    db.namesLower = lower
    return lower
end

function SoundAlerter:TrimDerivedNames()
    local db = self.spellDatabase
    db.nameToIdx = nil
    if not self:IsFinderOpen() then
        db.namesLower = nil
    end
end

local function MigrateSpellDatabase(saved)
    if saved.format ~= 2 or type(saved.byID) ~= "table" or type(saved.names) ~= "table" then
        return false
    end
    local byID = saved.byID
    local ids = {}
    for spellID in pairs(byID) do
        ids[#ids + 1] = spellID
    end
    table_sort(ids)
    local packed = {}
    for i = 1, #ids do
        local data = byID[ids[i]]
        packed[i] = data.nameIdx * PACK + math_min(data.rank or 0, PACK - 1)
    end
    saved.ids, saved.packed, saved.byID = ids, packed, nil
    saved.namesLower, saved.nameToIdx = nil, nil
    saved.totalSpells = #ids
    saved.format = DB_FORMAT
    return true
end

function SoundAlerter:LoadSpellDatabase()
    local saved = SoundAlerterSpellDB
    if not saved then
        return false
    end

    if saved.version ~= GetBuildInfo() then
        self:Print("Game version changed - rebuilding spell database")
        return false
    end

    if saved.scanKey ~= SCAN_KEY then
        self:Print("Spell scan range changed - rebuilding spell database")
        return false
    end

    local migrated = false
    if saved.format ~= DB_FORMAT then
        migrated = MigrateSpellDatabase(saved)
        if not migrated then
            self:Print("Spell database format changed - rebuilding")
            return false
        end
    end

    local age = time() - saved.lastUpdate
    if age > DB_MAX_AGE then
        self:Print("Spell database outdated - rebuilding")
        return false
    end

    local db = self.spellDatabase
    db.ids = saved.ids
    db.packed = saved.packed
    db.names = saved.names
    db.namesLower = nil
    db.nameToIdx = nil
    db.totalSpells = #db.ids
    db.lastUpdate = saved.lastUpdate
    db.source = "loaded"
    db.buildSeconds = nil
    db.builtOnVersion = saved.version

    if migrated then
        self:Print("Migrated the spell database to the compact format - saving...")
        self:SaveSpellDatabase()
    end

    self:BuildSearchIndexes()

    local spellCount = self:CountSpells()
    self:Print(string.format("Spell database loaded: %d spells indexed", spellCount))

    return true
end

function SoundAlerter:RebuildSpellDatabase()
    self:ReleaseSearchExtras()
    self.spellDatabase.ids = {}
    self.spellDatabase.packed = {}
    self.spellDatabase.names = {}
    self.spellDatabase.namesLower = {}
    self.spellDatabase.nameToIdx = {}
    self.spellDatabase.totalSpells = 0
    self:ClearSearchCache()
    self:BuildSpellDatabase()

    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    if AceConfigRegistry then
        AceConfigRegistry:NotifyChange("SoundAlerter")
    end
end

function SoundAlerter:CountSpells()
    return self.spellDatabase.totalSpells
end

function SoundAlerter:GetDatabaseStatus()
    self:EnsureSpellDatabase()
    local db = self.spellDatabase

    if db.isBuilding then
        return string_format("|cFFFFAA00Building: %.1f%% (%d scanned)|r",
            db.progress, db.totalScanned)
    else
        local spellCount = self:CountSpells()
        local ageMinutes = math_floor((time() - db.lastUpdate) / 60)
        if ageMinutes < 1 then
            return string_format("|cFF00FF00Ready: %d spells indexed (just now)|r", spellCount)
        elseif ageMinutes < 60 then
            return string_format("|cFF00FF00Ready: %d spells indexed (%dm ago)|r", spellCount, ageMinutes)
        else
            local ageHours = math_floor(ageMinutes / 60)
            return string_format("|cFF00FF00Ready: %d spells indexed (%dh ago)|r", spellCount, ageHours)
        end
    end
end

function SoundAlerter:BuildSearchIndexes()
    local db = self.spellDatabase
    local rankedSpells = 0
    local maxRank = 0

    local packed = db.packed
    for i = 1, #packed do
        local rank = packed[i] % PACK
        if rank > 0 then
            rankedSpells = rankedSpells + 1
            if rank > maxRank then
                maxRank = rank
            end
        end
    end

    db.rankedSpells = rankedSpells
    db.maxRank = maxRank
end

function SoundAlerter:EnsureFuzzyIndex()
    local db = self.spellDatabase
    if db.nameMasks then
        return
    end

    local namesLower = self:EnsureNamesLower()
    local nameMasks, initialMasks = {}, {}
    for nameIdx = 1, #db.names do
        nameMasks[nameIdx] = LetterMask(namesLower[nameIdx])
        initialMasks[nameIdx] = WordInitialMask(namesLower[nameIdx])
    end

    db.initialMasks = initialMasks
    db.nameMasks = nameMasks
end

function SoundAlerter:EnsureAutocompleteIndex()
    local db = self.spellDatabase
    if db.sortedNames then
        return
    end

    local namesLower = self:EnsureNamesLower()
    local sortedNames = {}
    for nameIdx = 1, #db.names do
        sortedNames[nameIdx] = nameIdx
    end
    table_sort(sortedNames, function(a, b)
        local nameA, nameB = namesLower[a], namesLower[b]
        if nameA ~= nameB then
            return nameA < nameB
        end
        return a < b
    end)
    db.sortedNames = sortedNames
end

function SoundAlerter:IsFinderOpen()
    local finder = self.findSpellFrame
    return finder ~= nil and finder.frame ~= nil and finder.frame:IsShown()
end

function SoundAlerter:PrepareSearchExtras()
    self:EnsureSpellDatabase()
    self:EnsureNamesLower()
    local findSpell = self:GetFinderSettings()
    if findSpell.fuzzy then
        self:EnsureFuzzyIndex()
    end
    if findSpell.autocomplete then
        self:EnsureAutocompleteIndex()
    end
    self:ResumeDescriptionIndex()
end

function SoundAlerter:ReleaseSearchExtras()
    local db = self.spellDatabase
    self:StopDescriptionIndex()
    db.nameMasks = nil
    db.initialMasks = nil
    db.sortedNames = nil
    if not db.isBuilding then
        db.namesLower = nil
    end
    self:ClearSearchCache()
end

local databaseStats = {}

function SoundAlerter:GetDatabaseStats()
    self:EnsureSpellDatabase()
    local db = self.spellDatabase
    local stats = databaseStats
    stats.isBuilding = db.isBuilding
    stats.progress = db.progress or 0
    stats.totalScanned = db.totalScanned or 0
    stats.maxSpellID = MAX_SPELL_ID
    stats.scanTotal = SCAN_TOTAL
    stats.maxAge = DB_MAX_AGE
    stats.totalSpells = db.totalSpells or 0
    stats.uniqueNames = #db.names
    stats.rankedSpells = db.rankedSpells or 0
    stats.lastUpdate = db.lastUpdate or 0
    stats.builtOnVersion = db.builtOnVersion
    stats.currentVersion = GetBuildInfo()
    stats.source = db.source
    stats.buildSeconds = db.buildSeconds
    stats.cacheEntries = #cacheAge
    stats.cacheMax = MAX_CACHE_SIZE
    return stats
end

local DESCRIPTION_SCORE = 5000
local FUZZY_ENOUGH_NAMES = 20
local FUZZY_TIER_SUBSEQUENCE = 1000
local FUZZY_TIER_EDIT = 2000

local editRowA, editRowB, editRowC = {}, {}, {}

local function SubsequenceSpan(name, termChars, termLen)
    local pos, first = 1, nil
    for i = 1, termLen do
        local found = string_find(name, termChars[i], pos, true)
        if not found then
            return nil
        end
        first = first or found
        pos = found + 1
    end
    return pos - first
end

local function EditDistanceWithin(termBytes, termLen, word, wordLen, maxDist)
    if wordLen - termLen > maxDist or termLen - wordLen > maxDist then
        return nil
    end

    local prev2, prev, curr = editRowA, editRowB, editRowC
    for j = 0, wordLen do
        prev[j] = j
    end

    for i = 1, termLen do
        curr[0] = i
        local rowMin = i
        local termByte = termBytes[i]
        for j = 1, wordLen do
            local wordByte = string_byte(word, j)
            local best = prev[j] + 1
            local candidate = curr[j - 1] + 1
            if candidate < best then
                best = candidate
            end
            candidate = prev[j - 1] + (termByte == wordByte and 0 or 1)
            if candidate < best then
                best = candidate
            end
            if i > 1 and j > 1 and termByte == string_byte(word, j - 1) and termBytes[i - 1] == wordByte then
                candidate = prev2[j - 2] + 1
                if candidate < best then
                    best = candidate
                end
            end
            curr[j] = best
            if best < rowMin then
                rowMin = best
            end
        end
        if rowMin > maxDist then
            return nil
        end
        prev2, prev, curr = prev, curr, prev2
    end

    local distance = prev[wordLen]
    if distance <= maxDist then
        return distance
    end
    return nil
end

local function BestEditDistance(termBytes, termLen, name, maxDist)
    local nameLen = #name
    local best = EditDistanceWithin(termBytes, termLen, name, nameLen, maxDist)
    if not string_find(name, " ", 1, true) then
        return best
    end

    local start = 1
    while start <= nameLen do
        local stop = string_find(name, " ", start, true) or (nameLen + 1)
        local wordLen = stop - start
        if wordLen > 0 and wordLen - termLen <= maxDist and termLen - wordLen <= maxDist then
            local distance = EditDistanceWithin(termBytes, termLen, string_sub(name, start, stop - 1), wordLen, maxDist)
            if distance and (not best or distance < best) then
                best = distance
            end
        end
        start = stop + 1
    end
    return best
end

local function FuzzyMatchNames(db, term)
    local namesLower, nameMasks, initialMasks = db.namesLower, db.nameMasks, db.initialMasks
    local matched = {}
    local matchedCount = 0
    local termLen = #term
    local nameCount = #namesLower

    for nameIdx = 1, nameCount do
        local name = namesLower[nameIdx]
        local pos = string_find(name, term, 1, true)
        if pos then
            matched[nameIdx] = pos + (#name - termLen) / 100
            matchedCount = matchedCount + 1
        end
    end

    if matchedCount >= FUZZY_ENOUGH_NAMES or termLen < 3 then
        return matched
    end

    local termChars, termBytes = {}, {}
    for i = 1, termLen do
        termChars[i] = string_sub(term, i, i)
        termBytes[i] = string_byte(term, i)
    end

    local termMask = LetterMask(term)
    local firstBit = termMask == 0 and -1 or LetterMask(string_sub(term, 1, 1))
    if firstBit == 0 then
        firstBit = -1
    end
    local maxSpan = termLen * 2

    for nameIdx = 1, nameCount do
        if not matched[nameIdx]
            and bit_band(firstBit, initialMasks[nameIdx] or -1) ~= 0
            and bit_band(termMask, bit_bnot(nameMasks[nameIdx] or -1)) == 0 then
            local name = namesLower[nameIdx]
            local span = SubsequenceSpan(name, termChars, termLen)
            if span and span <= maxSpan then
                matched[nameIdx] = FUZZY_TIER_SUBSEQUENCE + span + (#name - termLen) / 100
                matchedCount = matchedCount + 1
            end
        end
    end

    if matchedCount >= FUZZY_ENOUGH_NAMES or termLen < 4 then
        return matched
    end

    local maxDist = termLen >= 7 and 2 or 1
    for nameIdx = 1, nameCount do
        if not matched[nameIdx]
            and bit_band(firstBit, initialMasks[nameIdx] or -1) ~= 0
            and PopcountWithin(bit_band(termMask, bit_bnot(nameMasks[nameIdx] or -1)), maxDist) then
            local name = namesLower[nameIdx]
            local distance = BestEditDistance(termBytes, termLen, name, maxDist)
            if distance then
                matched[nameIdx] = FUZZY_TIER_EDIT + distance * 100 + math.abs(#name - termLen) / 100
            end
        end
    end

    return matched
end

function SoundAlerter:SearchSpells(searchTerm, rankFilter)
    self:EnsureSpellDatabase()
    local db = self.spellDatabase

    if not searchTerm or searchTerm == "" then
        return {}
    end

    local findSpell = self:GetFinderSettings()
    local scope = self:GetSearchScope()
    local descriptionsOnly = scope == "descriptions"
    local idQuery = string_match(searchTerm, "^%s*#?(%d+)%s*$")
    local fuzzy = findSpell.fuzzy and not descriptionsOnly and not idQuery and #searchTerm >= 2
    local descSearch = scope ~= "names" and db.descriptions and #searchTerm >= 3

    local cacheKey = searchTerm .. "\0" .. (rankFilter or "") .. "\0" ..
        (fuzzy and "f" or "") .. (descSearch and (descriptionsOnly and "D" or "d") or "")
    local searchCache = db.searchCache
    local cachedResult = searchCache[cacheKey]
    if cachedResult then
        self:Debug("SpellFinder", "'%s' cache hit: %d result(s)", searchTerm, #cachedResult)
        return cachedResult
    end

    local searchStartTime = debugprofilestop()

    local tokens = FinderFormat.Tokens(string_lower(searchTerm))
    if #tokens == 0 then
        return {}
    end
    local searchLower = table.concat(tokens, " ")
    local results = {}

    local ids, packedIDs = db.ids, db.packed
    local names = db.names

    local rankFilterNum = rankFilter and rankFilter ~= "" and tonumber(rankFilter) or nil

    if fuzzy then
        self:EnsureFuzzyIndex()
    end

    local resultCount = 0
    local namesLower = self:EnsureNamesLower()

    local seen = (idQuery or descSearch) and {} or nil

    local function AddResult(spellID, packed, score, inDescription)
        local rankNum = packed % PACK
        if rankFilterNum and rankNum ~= rankFilterNum then
            return
        end
        resultCount = resultCount + 1
        if seen then seen[spellID] = true end
        local row = {
            spellID = spellID,
            baseName = names[(packed - rankNum) / PACK],
            rankNum = rankNum,
            score = score,
        }
        if inDescription then row.inDescription = true end
        results[resultCount] = row
    end

    if idQuery then
        local idNumber = tonumber(idQuery)
        local at = LowerBound(ids, idNumber)
        if ids[at] == idNumber then
            AddResult(idNumber, packedIDs[at], -1)
            if results[resultCount] and results[resultCount].spellID == idNumber then
                results[resultCount].idMatch = true
            end
        end
    end

    if fuzzy then
        local matchedNames = FuzzyMatchNames(db, searchLower)
        if next(matchedNames) then
            for i = 1, #ids do
                local packed = packedIDs[i]
                local score = matchedNames[(packed - packed % PACK) / PACK]
                if score then
                    local spellID = ids[i]
                    if not (seen and seen[spellID]) then
                        AddResult(spellID, packed, score)
                    end
                end
            end
        end
    elseif not descriptionsOnly then
        local matchedNames = {}
        for nameIdx = 1, #namesLower do
            local score = FinderFormat.NameScore(namesLower[nameIdx], searchLower, tokens)
            if score then
                matchedNames[nameIdx] = score
            end
        end
        if next(matchedNames) then
            for i = 1, #ids do
                local packed = packedIDs[i]
                local score = matchedNames[(packed - packed % PACK) / PACK]
                if score then
                    local spellID = ids[i]
                    if not (seen and seen[spellID]) then
                        AddResult(spellID, packed, score)
                    end
                end
            end
        end
    end

    local scanDescriptions = descSearch
    if scanDescriptions then
        local texts = db.descriptions
        for i = 1, #ids do
            local spellID = ids[i]
            local text = texts[spellID]
            if text and not seen[spellID] and string_find(text, searchLower, 1, true) then
                AddResult(spellID, packedIDs[i], DESCRIPTION_SCORE, true)
            end
        end
    end

    table_sort(results, SORT_COMPARATORS.relevance)

    local elapsedMs = debugprofilestop() - searchStartTime
    self:CacheSearchResult(cacheKey, results)
    RecordSearchTiming(elapsedMs, scanDescriptions and "description" or (fuzzy and "fuzzy" or "search"))

    self:Debug("SpellFinder", "'%s' %s search: %d result(s) in %.2fms", searchTerm, scanDescriptions and "description" or (fuzzy and "fuzzy" or "name"), resultCount, elapsedMs)

    return results
end

local percentileScratch = {}

local function PercentileAt(sorted, count, fraction)
    return sorted[math_max(1, math.ceil(fraction * count))]
end

function SoundAlerter:GetSearchPercentiles(mode)
    local bucket = searchTimings[mode or "search"]
    local count = bucket.count
    if count == 0 then return nil end

    local sorted = percentileScratch
    for i = 1, count do
        sorted[i] = bucket.samples[i]
    end
    for i = #sorted, count + 1, -1 do
        sorted[i] = nil
    end
    table_sort(sorted)

    return PercentileAt(sorted, count, 0.50), PercentileAt(sorted, count, 0.95), PercentileAt(sorted, count, 0.99), sorted[count], count
end

local DESC_TICK = 0.25
local DESC_NEW_PER_TICK = 60
local DESC_INFLIGHT_MAX = 300
local DESC_LOAD_WAIT = 2
local DESC_EMPTY_READS = 2
local DESC_MAX_LEN = 400
local DESC_FORMAT = 2
local GetTime = GetTime

function SoundAlerter:EnsureDescriptionStore()
    local db = self.spellDatabase
    local version = GetBuildInfo()
    local store = SoundAlerterSpellDescDB
    if not store or store.version ~= version or store.format ~= DESC_FORMAT or not store.texts or not store.empty then
        store = {version = version, format = DESC_FORMAT, texts = {}, empty = {}}
        SoundAlerterSpellDescDB = store
    end

    if db.descriptions ~= store.texts then
        db.descriptions = store.texts
        db.descEmpty = store.empty
        local indexed, bytes, empty = 0, 0, 0
        for _, text in pairs(store.texts) do
            indexed = indexed + 1
            bytes = bytes + #text
        end
        for _ in pairs(store.empty) do
            empty = empty + 1
        end
        db.descIndexed, db.descBytes, db.descEmptyCount = indexed, bytes, empty
    end
end

function SoundAlerter:IsDescriptionIndexRunning()
    return self.spellDatabase.descIndexTimer ~= nil
end

function SoundAlerter:StopDescriptionIndex()
    local db = self.spellDatabase
    if db.descIndexTimer then
        self:CancelTimer(db.descIndexTimer)
        db.descIndexTimer = nil
    end
    db.descQueue = nil
    db.descInflight = nil
end

function SoundAlerter:StartDescriptionIndex()
    self:EnsureSpellDatabase()
    local db = self.spellDatabase
    if db.descIndexTimer then
        return
    end

    if db.isBuilding then
        db.descIndexTimer = self:ScheduleTimer(function()
            db.descIndexTimer = nil
            self:StartDescriptionIndex()
        end, 2)
        return
    end

    self:EnsureDescriptionStore()

    local texts, empty = db.descriptions, db.descEmpty
    local queue = {}
    local ids = db.ids
    for i = 1, #ids do
        local spellID = ids[i]
        if not texts[spellID] and not empty[spellID] then
            queue[#queue + 1] = spellID
        end
    end
    if #queue == 0 then
        return
    end

    db.descQueue = queue
    db.descQueuePos = 1
    db.descInflight = {head = 1, tail = 0}
    db.descIndexTimer = self:ScheduleRepeatingTimer(function()
        self:ProcessDescriptionBatch()
    end, DESC_TICK)
end

function SoundAlerter:ProcessDescriptionBatch()
    local db = self.spellDatabase
    local queue, inflight = db.descQueue, db.descInflight
    if not queue or not inflight then
        self:StopDescriptionIndex()
        return
    end

    local texts, empty = db.descriptions, db.descEmpty
    local now = GetTime()

    local function StoreText(spellID, text)
        local stored = string_lower(string_sub(text, 1, DESC_MAX_LEN))
        texts[spellID] = stored
        db.descIndexed = db.descIndexed + 1
        db.descBytes = db.descBytes + #stored
    end

    while inflight.head <= inflight.tail do
        local entry = inflight[inflight.head]
        if now - entry.at < DESC_LOAD_WAIT then
            break
        end
        inflight[inflight.head] = nil
        inflight.head = inflight.head + 1

        local ok, text = pcall(GetSpellDescription, entry.id)
        if ok and text and text ~= "" then
            StoreText(entry.id, text)
        else
            entry.reads = entry.reads + 1
            if entry.reads >= DESC_EMPTY_READS then
                empty[entry.id] = true
                db.descEmptyCount = db.descEmptyCount + 1
            else
                pcall(C_Spell.RequestLoadSpellData, entry.id)
                entry.at = now
                inflight.tail = inflight.tail + 1
                inflight[inflight.tail] = entry
            end
        end
    end

    local pos = db.descQueuePos
    local pending = inflight.tail - inflight.head + 1
    local requested, reads = 0, 0
    while pos <= #queue and pending < DESC_INFLIGHT_MAX and requested < DESC_NEW_PER_TICK and reads < 400 do
        local spellID = queue[pos]
        pos = pos + 1
        reads = reads + 1
        local ok, text = pcall(GetSpellDescription, spellID)
        if ok and text and text ~= "" then
            StoreText(spellID, text)
        else
            pcall(C_Spell.RequestLoadSpellData, spellID)
            inflight.tail = inflight.tail + 1
            inflight[inflight.tail] = {id = spellID, at = now, reads = 0}
            pending = pending + 1
            requested = requested + 1
        end
    end
    db.descQueuePos = pos

    if db.descQueuePos > #queue and inflight.head > inflight.tail then
        self:StopDescriptionIndex()
        self:ClearSearchCache()
        self:Print(string_format("Spell description index complete: %d descriptions (%.0f KB)",
            db.descIndexed, db.descBytes / 1024))
        local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
        if AceConfigRegistry then
            AceConfigRegistry:NotifyChange("SoundAlerter")
        end
    end
end

local FINDER_KEYS = {
    fuzzy = true,
    autocomplete = true,
    searchScope = true,
    searchDescriptions = true,
    rankFilter = true,
    sortMode = true,
    sortDesc = true,
    kindFilter = true,
    knownFilter = true,
    position = true,
}

function SoundAlerter:GetFinderSettings()
    local profile = self.db1.profile
    profile.findSpell = profile.findSpell or {}
    return profile.findSpell
end

function SoundAlerter:SetFinderSetting(key, value)
    if not FINDER_KEYS[key] then
        error("SpellFinder:SetFinderSetting - unknown setting key '"..tostring(key).."'", 2)
    end
    self:GetFinderSettings()[key] = value
end

function SoundAlerter:GetSearchScope()
    local findSpell = self:GetFinderSettings()
    return findSpell.searchScope or (findSpell.searchDescriptions and "both") or "names"
end

function SoundAlerter:SetSearchScope(scope)
    self:SetFinderSetting("searchScope", scope)
    self:SetFinderSetting("searchDescriptions", nil)

    if scope == "names" then
        self:StopDescriptionIndex()
    elseif self:IsFinderOpen() then
        self:ResumeDescriptionIndex()
    end
    self:ClearSearchCache()

    local finder = self.findSpellFrame
    if finder and finder.onScopeChanged then
        finder.onScopeChanged()
    end
end

function SoundAlerter:ResumeDescriptionIndex()
    if self:GetSearchScope() ~= "names" then
        self:EnsureDescriptionStore()
        self:StartDescriptionIndex()
    end
end

function SoundAlerter:ClearDescriptionIndex()
    local db = self.spellDatabase
    self:StopDescriptionIndex()
    SoundAlerterSpellDescDB = nil
    db.descriptions = nil
    db.descEmpty = nil
    db.descIndexed, db.descBytes, db.descEmptyCount = 0, 0, 0
    self:ClearSearchCache()
end

local descriptionInfo = {}

function SoundAlerter:GetDescriptionInfo()
    local db = self.spellDatabase
    local result = descriptionInfo
    if not db.descriptions then
        result.built = false
        return result
    end
    local total = math_max(db.totalSpells or 0, 1)
    result.built = true
    result.indexed = db.descIndexed or 0
    result.empty = db.descEmptyCount or 0
    result.total = db.totalSpells or 0
    result.percent = math_min(100, (result.indexed + result.empty) / total * 100)
    result.running = self:IsDescriptionIndexRunning()
    result.kb = (db.descBytes or 0) / 1024
    return result
end

function SoundAlerter:GetDescriptionStatus()
    local description = self:GetDescriptionInfo()
    if not description.built then
        return "|cFF888888Description index: not built|r"
    end

    local state = description.running and "|cFFFFAA00indexing|r" or "|cFF00FF00idle|r"
    return string_format("Description index: %s, %d texts + %d empty of %d spells (%.0f%%), %.0f KB",
        state, description.indexed, description.empty, description.total, description.percent, description.kb)
end

function SoundAlerter:SuggestSpellNames(prefix, limit)
    self:EnsureSpellDatabase()
    local db = self.spellDatabase
    local suggestions = {}
    if not prefix or #prefix < 2 then
        return suggestions
    end
    self:EnsureAutocompleteIndex()
    local sortedNames = db.sortedNames

    local startMs = debugprofilestop()
    local lowerPrefix = string_lower(prefix)
    local prefixLen = #lowerPrefix
    local namesLower = self:EnsureNamesLower()
    local names = db.names

    local low, high = 1, #sortedNames + 1
    while low < high do
        local mid = math_floor((low + high) / 2)
        if namesLower[sortedNames[mid]] < lowerPrefix then
            low = mid + 1
        else
            high = mid
        end
    end

    local max = limit or 8
    local index = low
    local taken = {}
    while #suggestions < max and index <= #sortedNames do
        local nameIdx = sortedNames[index]
        if string_sub(namesLower[nameIdx], 1, prefixLen) ~= lowerPrefix then
            break
        end
        suggestions[#suggestions + 1] = names[nameIdx]
        taken[nameIdx] = true
        index = index + 1
    end

    local remaining = max - #suggestions
    if remaining > 0 and prefixLen >= MIN_INNER_SUGGEST_CHARS then
        local tokens = FinderFormat.Tokens(lowerPrefix)
        local buckets = { {}, {}, {} }
        local firstToken = tokens[1]
        for position = 1, #sortedNames do
            local nameIdx = sortedNames[position]
            if not taken[nameIdx] and string_find(namesLower[nameIdx], firstToken, 1, true) then
                local score = FinderFormat.NameScore(namesLower[nameIdx], lowerPrefix, tokens)
                if score then
                    local bucket = buckets[score == 0 and 1 or score]
                    if #bucket < remaining then
                        bucket[#bucket + 1] = nameIdx
                    end
                    if score <= 1 and #bucket >= remaining then
                        break
                    end
                end
            end
        end
        for _, bucket in ipairs(buckets) do
            for _, nameIdx in ipairs(bucket) do
                if #suggestions < max then
                    suggestions[#suggestions + 1] = names[nameIdx]
                end
            end
        end
    end

    RecordSearchTiming(debugprofilestop() - startMs, "autocomplete")
    return suggestions
end

local function EvictOldestSearch(cache)
    local oldestKey = table_remove(cacheAge, 1)
    cacheRowTotal = cacheRowTotal - cacheRows[oldestKey]
    cacheRows[oldestKey] = nil
    cache[oldestKey] = nil
end

function SoundAlerter:CacheSearchResult(key, results)
    local cache = self.spellDatabase.searchCache
    local rows = #results

    for i = 1, #cacheAge do
        if cacheAge[i] == key then
            table_remove(cacheAge, i)
            cacheRowTotal = cacheRowTotal - cacheRows[key]
            cacheRows[key] = nil
            cache[key] = nil
            break
        end
    end

    if rows > MAX_CACHE_ROWS then return end

    while #cacheAge >= MAX_CACHE_SIZE or (#cacheAge > 0 and cacheRowTotal + rows > MAX_CACHE_ROWS) do
        EvictOldestSearch(cache)
    end

    cache[key] = results
    cacheRows[key] = rows
    cacheRowTotal = cacheRowTotal + rows
    table_insert(cacheAge, key)
end

function SoundAlerter:ClearSearchCache()
    self.spellDatabase.searchCache = {}
    cacheAge = {}
    cacheRows = {}
    cacheRowTotal = 0
end

local List = SA_FinderList
local FINDER_WIDTH = List.WIDTH
local FINDER_MIN_WIDTH = List.MIN_WIDTH

local iconCache = {}
local propsCache = {}

local function SpellIcon(spellID)
    local icon = iconCache[spellID]
    if not icon then
        local _, _, texture = GetSpellInfo(spellID)
        icon = texture
        iconCache[spellID] = icon
    end
    return icon
end

local function RowDescription(spellID)
    C_Spell.RequestLoadSpellData(spellID)
    local text = GetSpellDescription(spellID)
    if text and text ~= "" then
        return text
    end
    return nil
end

function SoundAlerter:InsertSpellText(spell, description, window)
    local editBox = ChatEdit_GetActiveWindow()
    if not editBox and ChatFrame1EditBox and ChatFrame1EditBox:IsShown() then
        editBox = ChatFrame1EditBox
    end

    if not editBox then
        self:Print((FinderFormat.ChatText(spell, description)))
        return
    end

    local maxLetters = editBox:GetMaxLetters()
    if not maxLetters or maxLetters <= 0 then
        maxLetters = FinderFormat.DEFAULT_CHAT_LIMIT
    end
    local text, shortened = FinderFormat.ChatText(spell, description, maxLetters - #editBox:GetText())
    editBox:Insert(text)
    editBox:SetFocus()
    window:Toast(shortened and "Inserted into chat (description shortened to fit)" or "Inserted into chat!", 0, 1, 0)
end

function SoundAlerter:InsertFinderSelection(window, spell, withDescription)
    if not withDescription then
        self:InsertSpellText(spell, nil, window)
        return
    end
    local description = RowDescription(spell.spellID)
    if not description then
        window:Toast("No description available for this spell.", 1, 0.3, 0.3)
        return
    end
    self:InsertSpellText(spell, description, window)
end

function SoundAlerter:ClearFinderCaches()
    propsCache = {}
end

function SoundAlerter:FilterResults(results, kind, known)
    if kind == "all" and known == "all" then
        return
    end
    local kept = 0
    for index = 1, #results do
        local spell = results[index]
        local spellID = spell.spellID
        local props = propsCache[spellID]
        if not props then
            props = {}
            propsCache[spellID] = props
        end
        if kind ~= "all" and not props.passiveRead then
            props.passive = SafeRead(IsSpellPassive, spellID)
            props.passiveRead = true
        end
        if known ~= "all" and not props.knownRead then
            props.known = SafeRead(IsSpellKnown, spellID)
            props.knownRead = true
        end
        if FinderFormat.PassesFilters(props, kind, known) then
            kept = kept + 1
            results[kept] = spell
        end
    end
    for index = #results, kept + 1, -1 do
        results[index] = nil
    end
end

function SoundAlerter:FinderStatusText(count, unfiltered)
    local descriptionStatus
    if self:GetSearchScope() ~= "names" or self.spellDatabase.descriptions then
        descriptionStatus = self:GetDescriptionStatus()
    end
    return FinderFormat.Status(count, self:GetDatabaseStatus(), descriptionStatus, unfiltered)
end

function SoundAlerter:FinderEmptyText(term, hiddenByFilters)
    return FinderFormat.Empty({
        building = self.spellDatabase.isBuilding,
        term = term,
        scope = self:GetSearchScope(),
        fuzzy = self:GetFinderSettings().fuzzy,
        hiddenByFilters = hiddenByFilters,
    })
end

function SoundAlerter:ShowSpellDetail(frame, spell, retried)
    if frame.detailTimer then
        self:CancelTimer(frame.detailTimer, true)
        frame.detailTimer = nil
    end
    frame.selectedSpell = spell

    if not spell then
        frame:SetDetail(nil)
        return
    end

    local _, _, texture, castTime, minRange, maxRange = GetSpellInfo(spell.spellID)
    local description = RowDescription(spell.spellID)
    frame:SetDetail({
        spell = spell,
        texture = texture,
        facts = { iconID = texture, castTime = castTime, minRange = minRange, maxRange = maxRange },
        props = ReadSpellProps(spell.spellID),
        description = description,
        loading = not description and not retried,
    })

    if not description and not retried then
        frame.detailTimer = self:ScheduleTimer("RetryFinderDescription", 0.5, frame)
    end
end

function SoundAlerter:RetryFinderDescription(frame)
    frame.detailTimer = nil
    if frame.selectedSpell then
        self:ShowSpellDetail(frame, frame.selectedSpell, true)
    end
end

local function ExtractRankToken(searchTerm)
    local rankNum = string_match(searchTerm, "%s+[Rr]%a*:?(%d+)$")
    if not rankNum then
        return searchTerm, nil
    end
    return string_match(searchTerm, "^(.-)%s+[Rr]%a*:?%d+$"), rankNum
end

function SoundAlerter:PerformSearch(frame, searchTerm)
    local startMs = debugprofilestop()
    self:RunSearch(frame, searchTerm)
    RecordSearchTiming(debugprofilestop() - startMs, "perform")
end

function SoundAlerter:RunSearch(frame, searchTerm)
    frame.lastSearchTerm = searchTerm

    local queryTerm, rankFilter = ExtractRankToken(searchTerm)
    if not rankFilter then
        local dropdownRank = self:GetFinderSettings().rankFilter
        if dropdownRank == "none" then
            rankFilter = "0"
        elseif dropdownRank and dropdownRank ~= "all" then
            rankFilter = dropdownRank
        end
    end
    local cached = self:SearchSpells(queryTerm, rankFilter)
    local results = frame.results or {}
    for i = 1, #cached do
        results[i] = cached[i]
    end
    for i = #results, #cached + 1, -1 do
        results[i] = nil
    end

    local findSpell = self:GetFinderSettings()
    local unfiltered = #results
    self:FilterResults(results, findSpell.kindFilter or "all", findSpell.knownFilter or "all")
    local mode = SORT_COMPARATORS[findSpell.sortMode] and findSpell.sortMode or "name"
    table_sort(results, (findSpell.sortDesc and REVERSED_COMPARATORS or SORT_COMPARATORS)[mode])
    for index = 2, #results do
        if results[index].idMatch then
            table_insert(results, 1, table_remove(results, index))
            break
        end
    end

    frame:ShowResults(results, unfiltered, searchTerm)
end

local function FinderRoom(mainFrame)
    local right = mainFrame and mainFrame.frame and mainFrame.frame:GetRight()
    if not right then return nil, nil end
    local left = mainFrame.frame:GetLeft()
    return UIParent:GetWidth() - right - 12, type(left) == "number" and left - 12 or nil
end

function SoundAlerter:FitFinderWidth(frame)
    local mainFrame = LibStub("AceConfigDialog-3.0").OpenFrames["SoundAlerter"]
    local roomRight, roomLeft = FinderRoom(mainFrame)
    if not roomRight then
        frame:SetWidth(FINDER_WIDTH)
        return
    end
    local available = frame.dockLeft and roomLeft or roomRight
    frame:SetWidth(math_max(FINDER_MIN_WIDTH, math_min(FINDER_WIDTH, available)))
end

local FINDER_OPTION_KEYS = {
    fuzzy = true,
    autocomplete = true,
    rankFilter = true,
    sortMode = true,
    sortDesc = true,
    kindFilter = true,
    knownFilter = true,
}

function SoundAlerter:SetFinderOption(key, value)
    if not FINDER_OPTION_KEYS[key] then
        error("SpellFinder:SetFinderOption - unknown option '" .. tostring(key) .. "'", 2)
    end
    self:SetFinderSetting(key, value)
    if key == "fuzzy" then
        if value then
            self:SetFinderSetting("sortMode", "relevance")
        end
        self:ClearSearchCache()
    end
end

function SoundAlerter:SyncFinderControls()
    local finder = self.findSpellFrame
    if finder and finder.RefreshControls then
        finder:RefreshControls()
    end
end

function SoundAlerter:FinderRankOptions()
    self:EnsureSpellDatabase()
    local maxRank = self.spellDatabase.maxRank or 0
    if self.finderRankCount ~= maxRank then
        self.finderRankCount = maxRank
        self.finderRankOptions = List.RankOptions(maxRank)
    end
    return self.finderRankOptions
end

function SoundAlerter:OnFindSpellShown(frame)
    self:FitFinderWidth(frame)
    self:PrepareSearchExtras()
    frame:RefreshControls()
    if frame.lastSearchTerm and frame.lastSearchTerm ~= "" then
        frame:RunSearch()
    end
end

function SoundAlerter:OnFindSpellHidden(frame)
    if frame.detailTimer then
        self:CancelTimer(frame.detailTimer, true)
        frame.detailTimer = nil
    end
    self:ReleaseSearchExtras()
    self:ClearFinderCaches()
end

function SoundAlerter:CreateFindSpellFrame()
    local addon = self
    local host = {
        settings = function() return addon:GetFinderSettings() end,
        rankOptions = function() return addon:FinderRankOptions() end,
        suggest = function(text) return addon:SuggestSpellNames(text, List.SUGGESTION_LIMIT) end,
        search = function(window, term) addon:PerformSearch(window, term) end,
        detail = function(window, spell) addon:ShowSpellDetail(window, spell) end,
        insert = function(spell, withDescription, window) addon:InsertFinderSelection(window, spell, withDescription) end,
        status = function(count, unfiltered) return addon:FinderStatusText(count, unfiltered) end,
        empty = function(term, hidden) return addon:FinderEmptyText(term, hidden) end,
        icon = SpellIcon,
        spellLink = GetSpellLink,
        after = function(delay, fn) return addon:ScheduleTimer(fn, delay) end,
        cancel = function(handle) addon:CancelTimer(handle, true) end,
        set = function(key, value) addon:SetFinderOption(key, value) end,
        setScope = function(value) addon:SetSearchScope(value) end,
        onShown = function(window) addon:OnFindSpellShown(window) end,
        onHidden = function(window) addon:OnFindSpellHidden(window) end,
        savePosition = function(point, relative, x, y)
            addon:GetFinderSettings().position = { point = point, relative = relative, x = x, y = y }
        end,
    }
    local window = SA_FinderWindow.Create(host)
    self:PrepareSearchExtras()
    return window
end

function SoundAlerter:ToggleSpellFinder()
    if self:IsFinderOpen() then
        self.findSpellFrame:Hide()
    else
        self:OpenSpellFinder()
    end
end

function SoundAlerter:OpenSpellFinder()
    if not self.findSpellFrame then
        self.findSpellFrame = self:CreateFindSpellFrame()
    end
    local finder = self.findSpellFrame
    local mainFrame = LibStub("AceConfigDialog-3.0").OpenFrames["SoundAlerter"]
    local saved = self:GetFinderSettings().position
    if mainFrame and mainFrame.frame then
        local roomRight, roomLeft = FinderRoom(mainFrame)
        local left = roomRight and roomRight < FINDER_MIN_WIDTH and roomLeft and roomLeft >= FINDER_MIN_WIDTH
        finder:Dock(mainFrame.frame, left)
    elseif saved and saved.point then
        finder:Place(saved.point, saved.relative, saved.x, saved.y)
    end
    if mainFrame and mainFrame.frame and not mainFrame.frame.soundAlerterFinderHideHooked then
        mainFrame.frame.soundAlerterFinderHideHooked = true
        mainFrame.frame:HookScript("OnHide", function()
            if SoundAlerter.findSpellFrame then
                SoundAlerter.findSpellFrame:Hide()
            end
        end)
    end
    finder:Show()
    finder.frame:Raise()
    finder.box:SetFocus()
end
