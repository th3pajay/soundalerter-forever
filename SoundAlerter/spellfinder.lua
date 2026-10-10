local AceGUI = LibStub("AceGUI-3.0")
local SoundAlerter = SoundAlerter

local pairs, tonumber = pairs, tonumber
local table_insert, table_sort, table_remove = table.insert, table.sort, table.remove
local string_lower, string_sub, string_match, string_find, string_format = string.lower, string.sub, string.match, string.find, string.format
local math_min, math_max, math_floor = math.min, math.max, math.floor
local time, select = time, select
local GetSpellInfo, GetSpellLink = SA_COMPAT.GetSpellInfo, SA_COMPAT.GetSpellLink
local GetSpellDescription, GetSpellSubtext = SA_COMPAT.GetSpellDescription, SA_COMPAT.GetSpellSubtext
local FinderFormat = SA_FinderFormat
local GetBuildInfo = GetBuildInfo

local MAX_SPELL_ID = 70000
local SCAN_CHUNK_SIZE = 1000
local SCAN_CHUNK_DELAY = 0.05
local DB_MAX_AGE = 2592000
local DB_FORMAT = 2

function SoundAlerter:GetSpellScanInfo()
    local seconds = math.ceil(MAX_SPELL_ID / SCAN_CHUNK_SIZE) * SCAN_CHUNK_DELAY
    return MAX_SPELL_ID, seconds
end

SoundAlerter.spellDatabase = {
    byID = {},
    names = {},
    namesLower = {},
    nameToIdx = {},
    searchIndex = {},
    prefixIndex = {},
    searchCache = {},
    isBuilding = false,
    progress = 0,
    totalScanned = 0,
    totalSpells = 0,
    lastUpdate = 0,
    rankedSpells = 0,
    prefixBuckets = 0,
    source = nil,
    buildSeconds = nil,
    builtOnVersion = nil
}

local cacheAge = {}
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

local function ReverseComparator(comparator)
    return function(a, b) return comparator(b, a) end
end

local REVERSED_COMPARATORS = {}
for mode, comparator in pairs(SORT_COMPARATORS) do
    REVERSED_COMPARATORS[mode] = ReverseComparator(comparator)
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

    db.byID[spellID] = {
        nameIdx = nameIdx,
        rank = rankNum
    }

    db.totalSpells = db.totalSpells + 1
end

function SoundAlerter:BuildSpellDatabase()
    local db = self.spellDatabase

    if db.isBuilding then
        return
    end

    db.isBuilding = true
    db.progress = 0
    db.totalScanned = 0
    local buildStartMs = debugprofilestop()

    if not self.dbRefreshTimer then
        self.dbRefreshTimer = self:ScheduleRepeatingTimer(function()
            if db.isBuilding then
                local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
                if AceConfigRegistry then
                    AceConfigRegistry:NotifyChange("SoundAlerter")
                end
            else
                if self.dbRefreshTimer then
                    self:CancelTimer(self.dbRefreshTimer)
                    self.dbRefreshTimer = nil
                end
            end
        end, 0.1)
    end

    local CHUNK_SIZE = SCAN_CHUNK_SIZE
    local CHUNK_DELAY = SCAN_CHUNK_DELAY
    local currentID = 1
    local ProcessChunk

    local function ProcessChunkInner()
        local endID = math_min(currentID + CHUNK_SIZE - 1, MAX_SPELL_ID)
        local foundCount = 0

        local AddSpellToDatabase = self.AddSpellToDatabase

        for spellID = currentID, endID do
            local ok, name, rank = pcall(GetSpellInfo, spellID)
            if ok and name then
                if not rank or rank == "" then
                    local okSub, subtext = pcall(GetSpellSubtext, spellID)
                    rank = okSub and subtext or nil
                end
                AddSpellToDatabase(self, spellID, name, rank)
                foundCount = foundCount + 1
            end
        end

        db.totalScanned = endID
        db.progress = (db.totalScanned / MAX_SPELL_ID) * 100

        currentID = endID + 1

        if currentID <= MAX_SPELL_ID then
            self:ScheduleTimer(ProcessChunk, CHUNK_DELAY)
        else
            self:BuildSearchIndexes()
            db.isBuilding = false
            db.lastUpdate = time()
            db.source = "built"
            db.buildSeconds = (debugprofilestop() - buildStartMs) / 1000
            db.builtOnVersion = GetBuildInfo()

            if self.dbRefreshTimer then
                self:CancelTimer(self.dbRefreshTimer)
                self.dbRefreshTimer = nil
            end

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
        local ok, err = pcall(ProcessChunkInner)
        if not ok then
            db.isBuilding = false
            if self.dbRefreshTimer then
                self:CancelTimer(self.dbRefreshTimer)
                self.dbRefreshTimer = nil
            end
            self:Print("|cffFF7D0ASoundAlerter|r: Spell database build failed and was stopped — "..tostring(err))
        end
    end

    local maxID, minimumSeconds = self:GetSpellScanInfo()
    local estimate = minimumSeconds >= 90
        and string_format("at least %d minutes", math.floor(minimumSeconds / 60 + 0.5))
        or string_format("at least %d seconds", math.ceil(minimumSeconds))
    self:Print(string_format("Building spell database: scanning spell IDs 1 to %d. This takes %s, longer on a slower PC. Progress shows in Developer Tools > Database.", maxID, estimate))
    ProcessChunk()
end

function SoundAlerter:SaveSpellDatabase()
    SoundAlerterSpellDB = {
        byID = self.spellDatabase.byID,
        names = self.spellDatabase.names,
        totalSpells = self.spellDatabase.totalSpells,
        version = GetBuildInfo(),
        format = DB_FORMAT,
        lastUpdate = time()
    }
end

function SoundAlerter:LoadSpellDatabase()
    if not SoundAlerterSpellDB then
        return false
    end

    if SoundAlerterSpellDB.version ~= GetBuildInfo() then
        self:Print("Game version changed - rebuilding spell database")
        return false
    end

    if SoundAlerterSpellDB.format ~= DB_FORMAT then
        self:Print("Spell database format changed - rebuilding")
        return false
    end

    local age = time() - SoundAlerterSpellDB.lastUpdate
    if age > DB_MAX_AGE then
        self:Print("Spell database outdated - rebuilding")
        return false
    end

    self.spellDatabase.byID = SoundAlerterSpellDB.byID
    self.spellDatabase.names = SoundAlerterSpellDB.names
    self.spellDatabase.namesLower = {}
    self.spellDatabase.nameToIdx = {}
    self.spellDatabase.totalSpells = SoundAlerterSpellDB.totalSpells or 0
    self.spellDatabase.lastUpdate = SoundAlerterSpellDB.lastUpdate
    self.spellDatabase.source = "loaded"
    self.spellDatabase.buildSeconds = nil
    self.spellDatabase.builtOnVersion = SoundAlerterSpellDB.version

    local db = self.spellDatabase
    local namesLower, nameToIdx = db.namesLower, db.nameToIdx
    for i = 1, #db.names do
        local lowerName = string_lower(db.names[i])
        namesLower[i] = lowerName
        nameToIdx[lowerName] = i
    end

    if SoundAlerterSpellDB.namesLower or SoundAlerterSpellDB.nameToIdx or not SoundAlerterSpellDB.totalSpells then
        if not SoundAlerterSpellDB.totalSpells then
            db.totalSpells = 0
            for _ in pairs(db.byID) do
                db.totalSpells = db.totalSpells + 1
            end
        end
        self:Print("Migrated spell database to new format - saving...")
        self:SaveSpellDatabase()
    end

    self:BuildSearchIndexes()

    local spellCount = self:CountSpells()
    self:Print(string.format("Spell database loaded: %d spells indexed", spellCount))

    return true
end

function SoundAlerter:RebuildSpellDatabase()
    self:ReleaseSearchExtras()
    self.spellDatabase.byID = {}
    self.spellDatabase.names = {}
    self.spellDatabase.namesLower = {}
    self.spellDatabase.nameToIdx = {}
    self.spellDatabase.searchIndex = {}
    self.spellDatabase.prefixIndex = {}
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
    local searchIndex = {}
    local prefixIndex = {}
    local namesLower = db.namesLower
    local byID = db.byID

    local string_byte, string_char = string.byte, string.char

    for letter = string_byte('a'), string_byte('z') do
        searchIndex[string_char(letter)] = {}
    end

    local rankedSpells = 0
    local prefixBuckets = 0
    local maxRank = 0

    for spellID, data in pairs(byID) do
        if data.rank and data.rank > 0 then
            rankedSpells = rankedSpells + 1
            if data.rank > maxRank then
                maxRank = data.rank
            end
        end
        local lower = namesLower[data.nameIdx]
        if lower then
            local lowerLen = #lower

            local firstChar = string_sub(lower, 1, 1)
            local firstCharIndex = searchIndex[firstChar]
            if firstCharIndex then
                firstCharIndex[spellID] = true
            end

            if lowerLen >= 3 then
                local prefix = string_sub(lower, 1, 3)
                local prefixTable = prefixIndex[prefix]
                if not prefixTable then
                    prefixTable = {}
                    prefixIndex[prefix] = prefixTable
                    prefixBuckets = prefixBuckets + 1
                end
                prefixTable[spellID] = true
            end
        end
    end

    db.searchIndex = searchIndex
    db.prefixIndex = prefixIndex
    db.rankedSpells = rankedSpells
    db.prefixBuckets = prefixBuckets
    db.maxRank = maxRank
end

function SoundAlerter:EnsureFuzzyIndex()
    local db = self.spellDatabase
    if db.nameMasks then
        return
    end

    local namesLower = db.namesLower
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

    local namesLower = db.namesLower
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
    self:ClearSearchCache()
end

function SoundAlerter:OnFindSpellShown(frame)
    self:FitFinderWidth(frame)
    self:PrepareSearchExtras()
    if frame.lastSearchTerm and frame.lastSearchTerm ~= "" then
        self:PerformSearch(frame, frame.lastSearchTerm)
    end
end

function SoundAlerter:OnFindSpellHidden(frame)
    frame.renderGen = (frame.renderGen or 0) + 1
    if frame.renderTimer then
        self:CancelTimer(frame.renderTimer, true)
        frame.renderTimer = nil
    end
    if frame.detailTimer then
        self:CancelTimer(frame.detailTimer, true)
        frame.detailTimer = nil
    end
    frame.selectedRow = nil
    frame.selectedSpell = nil
    if frame.scrollFrame then
        frame.scrollFrame:ReleaseChildren()
    end
    if frame.clearSuggestions then
        frame.clearSuggestions()
    end
    self:ReleaseSearchExtras()
end

local databaseStats = {}

function SoundAlerter:GetDatabaseStats()
    local db = self.spellDatabase
    local stats = databaseStats
    stats.isBuilding = db.isBuilding
    stats.progress = db.progress or 0
    stats.totalScanned = db.totalScanned or 0
    stats.maxSpellID = MAX_SPELL_ID
    stats.maxAge = DB_MAX_AGE
    stats.totalSpells = db.totalSpells or 0
    stats.uniqueNames = #db.names
    stats.rankedSpells = db.rankedSpells or 0
    stats.prefixBuckets = db.prefixBuckets or 0
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
    local db = self.spellDatabase

    if not searchTerm or searchTerm == "" then
        return {}
    end

    local findSpell = self:GetFinderSettings()
    local scope = self:GetSearchScope()
    local descriptionsOnly = scope == "descriptions"
    local fuzzy = findSpell.fuzzy and not descriptionsOnly and #searchTerm >= 2
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

    local searchLower = string_lower(searchTerm)
    local searchLen = #searchLower
    local results = {}
    local candidateSpells

    local byID = db.byID
    local names = db.names
    local prefixIndex = db.prefixIndex
    local searchIndex = db.searchIndex

    if fuzzy then
        candidateSpells = {}
    elseif searchLen >= 3 then
        local prefix = string_sub(searchLower, 1, 3)
        candidateSpells = prefixIndex[prefix] or {}
    elseif searchLen >= 1 then
        local firstChar = string_sub(searchLower, 1, 1)
        candidateSpells = searchIndex[firstChar] or {}
    else
        return {}
    end

    local rankFilterNum = rankFilter and rankFilter ~= "" and tonumber(rankFilter) or nil

    if fuzzy then
        self:EnsureFuzzyIndex()
    end

    local resultCount = 0
    local namesLower = db.namesLower

    local seen = {}

    local function AddResult(spellID, data, score, inDescription)
        if rankFilterNum and data.rank ~= rankFilterNum then
            return
        end
        local baseName = names[data.nameIdx]
        resultCount = resultCount + 1
        seen[spellID] = true
        results[resultCount] = {
            spellID = spellID,
            name = baseName,
            rank = data.rank,
            baseName = baseName,
            rankNum = data.rank,
            score = score,
            inDescription = inDescription
        }
    end

    if fuzzy then
        local matchedNames = FuzzyMatchNames(db, searchLower)
        if next(matchedNames) then
            for spellID, data in pairs(byID) do
                local score = matchedNames[data.nameIdx]
                if score then
                    AddResult(spellID, data, score)
                end
            end
        end
    elseif not descriptionsOnly then
        for spellID in pairs(candidateSpells) do
            local data = byID[spellID]
            if data then
                local baseNameLower = namesLower[data.nameIdx] or string_lower(names[data.nameIdx])
                if string_find(baseNameLower, searchLower, 1, true) then
                    AddResult(spellID, data, 0)
                end
            end
        end
    end

    local scanDescriptions = descSearch
    if scanDescriptions then
        for spellID, text in pairs(db.descriptions) do
            if not seen[spellID] and string_find(text, searchLower, 1, true) then
                local data = byID[spellID]
                if data then
                    AddResult(spellID, data, DESCRIPTION_SCORE, true)
                end
            end
        end
    end

    table_sort(results, (fuzzy or scanDescriptions) and SORT_COMPARATORS.relevance or SORT_COMPARATORS.name)

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

function SoundAlerter:PrintSearchTimingReport()
    for _, mode in ipairs(TIMING_MODES) do
        local p50, p95, p99, max, count = self:GetSearchPercentiles(mode)
        if p50 then
            self:Print(string_format("[SpellFinder] %-12s n=%d p50=%.3fms p95=%.3fms p99=%.3fms max=%.3fms",
                mode, count, p50, p95, p99, max))
        else
            self:Print(string_format("[SpellFinder] %-12s no samples", mode))
        end
    end
end

local DESC_TICK = 0.25
local DESC_NEW_PER_TICK = 60
local DESC_INFLIGHT_MAX = 300
local DESC_LOAD_WAIT = 2
local DESC_EMPTY_READS = 2
local DESC_MAX_LEN = 400
local DESC_NOTIFY_EVERY = 8
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
    for spellID in pairs(db.byID) do
        if not texts[spellID] and not empty[spellID] then
            queue[#queue + 1] = spellID
        end
    end
    if #queue == 0 then
        return
    end
    table_sort(queue)

    db.descQueue = queue
    db.descQueuePos = 1
    db.descInflight = {head = 1, tail = 0}
    db.descBatches = 0
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

    db.descBatches = db.descBatches + 1
    if db.descBatches % DESC_NOTIFY_EVERY == 0 then
        local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
        if AceConfigRegistry then
            AceConfigRegistry:NotifyChange("SoundAlerter")
        end
    end

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

function SoundAlerter:GetDescriptionStatus()
    local db = self.spellDatabase
    if not db.descriptions then
        return "|cFF888888Description index: not built|r"
    end

    local total = math_max(db.totalSpells or 0, 1)
    local done = (db.descIndexed or 0) + (db.descEmptyCount or 0)
    local percent = math_min(100, done / total * 100)
    local state = self:IsDescriptionIndexRunning() and "|cFFFFAA00indexing|r" or "|cFF00FF00idle|r"
    return string_format("Description index: %s, %d texts + %d empty of %d spells (%.0f%%), %.0f KB",
        state, db.descIndexed or 0, db.descEmptyCount or 0, db.totalSpells or 0, percent, (db.descBytes or 0) / 1024)
end

function SoundAlerter:SuggestSpellNames(prefix, limit)
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
    local namesLower = db.namesLower
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
    while #suggestions < max and index <= #sortedNames do
        local nameIdx = sortedNames[index]
        if string_sub(namesLower[nameIdx], 1, prefixLen) ~= lowerPrefix then
            break
        end
        suggestions[#suggestions + 1] = names[nameIdx]
        index = index + 1
    end

    RecordSearchTiming(debugprofilestop() - startMs, "autocomplete")
    return suggestions
end

function SoundAlerter:CacheSearchResult(key, results)
    local cache = self.spellDatabase.searchCache

    for i = 1, #cacheAge do
        if cacheAge[i] == key then
            table_remove(cacheAge, i)
            break
        end
    end

    if #cacheAge >= MAX_CACHE_SIZE then
        local oldestKey = table_remove(cacheAge, 1)
        cache[oldestKey] = nil
    end

    cache[key] = results
    table_insert(cacheAge, key)
end

function SoundAlerter:ClearSearchCache()
    self.spellDatabase.searchCache = {}
    cacheAge = {}
end

local FINDER_WIDTH = 820
local FINDER_MIN_WIDTH = 640
local DETAIL_WIDTH = 270
local PANE_GAP = 8
local TOOLBAR_GAP = 6
local ROW_CAP = 50

local function RowDescription(spellID)
    C_Spell.RequestLoadSpellData(spellID)
    local text = GetSpellDescription(spellID)
    if text and text ~= "" then
        return text
    end
    return nil
end

local function HideFinderToast()
    GameTooltip:Hide()
end

local function ShowFinderToast(widget, text, r, g, b)
    GameTooltip:SetOwner(widget.frame, "ANCHOR_CURSOR")
    GameTooltip:AddLine(text, r, g, b)
    GameTooltip:Show()
    SoundAlerter:ScheduleTimer(HideFinderToast, 1.5)
end

local function OnFinderRowClick(widget)
    SoundAlerter:SelectFinderRow(widget)
end

local function OnFinderRowEnter(widget)
    local spell = widget:GetUserData("spell")
    if not spell then
        return
    end
    GameTooltip:SetOwner(widget.frame, "ANCHOR_CURSOR")
    local spellLink = GetSpellLink(spell.spellID)
    if spellLink then
        GameTooltip:SetHyperlink(spellLink)
    else
        GameTooltip:AddLine(spell.name, 1, 1, 1)
        GameTooltip:AddLine("Spell ID: " .. spell.spellID, 0.5, 0.5, 1)
    end
    GameTooltip:Show()
end

local function OnFinderRowLeave()
    GameTooltip:Hide()
end

function SoundAlerter:InsertSpellText(spell, description, widget)
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
    ShowFinderToast(widget, shortened and "Inserted into chat (description shortened to fit)" or "Inserted into chat!", 0, 1, 0)
end

function SoundAlerter:UpdateFinderStatus(frame, count)
    local descriptionStatus
    if self:GetSearchScope() ~= "names" or self.spellDatabase.descriptions then
        descriptionStatus = self:GetDescriptionStatus()
    end
    frame.statusLabel:SetText(FinderFormat.Status(count, self:GetDatabaseStatus(), descriptionStatus))
    frame.toolbar:DoLayout()
    frame:DoLayout()
end

function SoundAlerter:ShowFinderEmpty(frame, term)
    local label = AceGUI:Create("Label")
    label:SetText(FinderFormat.Empty({
        building = self.spellDatabase.isBuilding,
        term = term,
        scope = self:GetSearchScope(),
        fuzzy = self:GetFinderSettings().fuzzy,
    }))
    label:SetFullWidth(true)
    frame.scrollFrame:AddChild(label)
end

function SoundAlerter:ShowSpellDetail(frame, spell, retried)
    local detail = frame.detail
    if frame.detailTimer then
        self:CancelTimer(frame.detailTimer, true)
        frame.detailTimer = nil
    end
    frame.selectedSpell = spell

    if not spell then
        detail.title:SetText(" ")
        detail.subtitle:SetText(" ")
        detail.idBox:SetText("")
        detail.idBox:SetDisabled(true)
        detail.description:SetText(FinderFormat.NoSelection())
        detail.insert:SetDisabled(true)
        detail.insertDescription:SetDisabled(true)
        frame.detailGroup:DoLayout()
        return
    end

    local texture = select(3, GetSpellInfo(spell.spellID))
    local description = RowDescription(spell.spellID)
    detail.title:SetText(FinderFormat.Title(spell, texture))
    detail.subtitle:SetText(FinderFormat.Subtitle(spell))
    detail.idBox:SetDisabled(false)
    detail.idBox:SetText(tostring(spell.spellID))
    detail.description:SetText(FinderFormat.Description(description, not description and not retried))
    detail.insert:SetDisabled(false)
    detail.insertDescription:SetDisabled(description == nil)
    frame.detailGroup:DoLayout()

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

function SoundAlerter:SelectFinderRow(widget)
    local frame = widget:GetUserData("frame")
    local spell = widget:GetUserData("spell")
    if not frame or not spell then
        return
    end

    local previous = frame.selectedRow
    if previous and previous ~= widget then
        local previousSpell = previous:GetUserData("spell")
        if previousSpell then
            previous:SetText(FinderFormat.Row(previousSpell, select(3, GetSpellInfo(previousSpell.spellID)), false))
        end
    end

    frame.selectedRow = widget
    widget:SetText(FinderFormat.Row(spell, select(3, GetSpellInfo(spell.spellID)), true))
    self:ShowSpellDetail(frame, spell)
end

function SoundAlerter:RenderSpellRows(frame, results, cap)
    local scrollFrame = frame.scrollFrame
    local resultCount = #results
    local displayCount = math_min(resultCount, cap or ROW_CAP)
    local BATCH_SIZE = 15

    local generation = frame.renderGen
    local nextIndex = 1
    local function RenderBatch()
        if frame.renderGen ~= generation then
            return
        end
        frame.renderTimer = nil
        local batchEnd = math_min(nextIndex + BATCH_SIZE - 1, displayCount)
        for i = nextIndex, batchEnd do
            local spell = results[i]
            local row = AceGUI:Create("InteractiveLabel")
            row:SetFullWidth(true)
            row:SetUserData("frame", frame)
            row:SetUserData("spell", spell)
            row:SetText(FinderFormat.Row(spell, select(3, GetSpellInfo(spell.spellID)), false))
            row:SetCallback("OnClick", OnFinderRowClick)
            row:SetCallback("OnEnter", OnFinderRowEnter)
            row:SetCallback("OnLeave", OnFinderRowLeave)
            scrollFrame:AddChild(row)
            if i == 1 then
                self:SelectFinderRow(row)
            end
        end
        nextIndex = batchEnd + 1
        if nextIndex <= displayCount then
            frame.renderTimer = self:ScheduleTimer(RenderBatch, 0.02)
        elseif resultCount > displayCount then
            local moreLabel = AceGUI:Create("Label")
            moreLabel:SetText(FinderFormat.More(displayCount, resultCount))
            moreLabel:SetFullWidth(true)
            scrollFrame:AddChild(moreLabel)
        end
    end
    RenderBatch()
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
    frame.renderGen = (frame.renderGen or 0) + 1
    if frame.renderTimer then
        self:CancelTimer(frame.renderTimer, true)
        frame.renderTimer = nil
    end

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
    frame.results = results
    for i = 1, #cached do
        results[i] = cached[i]
    end
    for i = #results, #cached + 1, -1 do
        results[i] = nil
    end

    local findSpell = self:GetFinderSettings()
    local mode = SORT_COMPARATORS[findSpell.sortMode] and findSpell.sortMode or "name"
    table_sort(results, (findSpell.sortDesc and REVERSED_COMPARATORS or SORT_COMPARATORS)[mode])

    frame.selectedRow = nil
    frame.scrollFrame:ReleaseChildren()
    self:ShowSpellDetail(frame, nil)

    local resultCount = #results
    if resultCount == 0 then
        self:ShowFinderEmpty(frame, searchTerm)
        self:UpdateFinderStatus(frame, 0)
        return
    end

    self:UpdateFinderStatus(frame, resultCount)
    self:RenderSpellRows(frame, results, ROW_CAP)
end

function SoundAlerter:FitFinderWidth(frame)
    local mainFrame = LibStub("AceConfigDialog-3.0").OpenFrames["SoundAlerter"]
    local right = mainFrame and mainFrame.frame and mainFrame.frame:GetRight()
    if not right then
        frame:SetWidth(FINDER_WIDTH)
        return
    end
    local available = UIParent:GetWidth() - right - 12
    frame:SetWidth(math_max(FINDER_MIN_WIDTH, math_min(FINDER_WIDTH, available)))
    frame:DoLayout()
end

function SoundAlerter:RenderSearchPane(container, frame)
    local toolbar = AceGUI:Create("SimpleGroup")
    frame.toolbar = toolbar
    toolbar:SetLayout("Flow")
    container:AddChild(toolbar)
    toolbar.frame:ClearAllPoints()
    toolbar.frame:SetPoint("TOPLEFT", container.content, "TOPLEFT", 0, 0)
    toolbar.frame:SetPoint("TOPRIGHT", container.content, "TOPRIGHT", 0, 0)

    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel(self:GetSearchScope() == "descriptions" and "Description text:" or "Spell Name:")
    searchBox:SetRelativeWidth(0.8)
    searchBox:SetText(frame.lastSearchTerm or "")
    toolbar:AddChild(searchBox)

    local searchBtn = AceGUI:Create("Button")
    searchBtn:SetText("Search")
    searchBtn:SetRelativeWidth(0.19)
    toolbar:AddChild(searchBtn)

    frame.searchBox = searchBox

    local suggestGroup = AceGUI:Create("SimpleGroup")
    suggestGroup:SetFullWidth(true)
    suggestGroup:SetLayout("Flow")
    toolbar:AddChild(suggestGroup)

    local suggestions = {}
    local selectedIdx = nil

    local function RenderSuggestions()
        suggestGroup:ReleaseChildren()
        for i, name in ipairs(suggestions) do
            local label = AceGUI:Create("InteractiveLabel")
            label:SetWidth(190)
            label:SetText(i == selectedIdx and ("|cFFFFD100" .. name .. "|r") or name)
            label:SetCallback("OnClick", function()
                frame.acceptSuggestion(i, true)
            end)
            suggestGroup:AddChild(label)
        end
        toolbar:DoLayout()
        container:DoLayout()
    end

    local function ClearSuggestions()
        if #suggestions > 0 then
            suggestions = {}
            selectedIdx = nil
            RenderSuggestions()
        end
    end

    frame.clearSuggestions = ClearSuggestions

    local function UpdateSuggestions(text)
        if not self:GetFinderSettings().autocomplete or self:GetSearchScope() == "descriptions"
            or not text or #text < 2 then
            ClearSuggestions()
            return
        end

        local fresh = self:SuggestSpellNames(text, 8)
        if #fresh == 1 and string_lower(fresh[1]) == string_lower(text) then
            fresh = {}
        end

        local unchanged = #fresh == #suggestions
        if unchanged then
            for i = 1, #fresh do
                if fresh[i] ~= suggestions[i] then
                    unchanged = false
                    break
                end
            end
        end
        if unchanged then
            return
        end

        suggestions = fresh
        selectedIdx = nil
        RenderSuggestions()
    end

    function frame.acceptSuggestion(index, andSearch)
        local name = suggestions[index]
        if not name then
            return
        end
        suggestions = {}
        selectedIdx = nil
        RenderSuggestions()
        searchBox:SetText(name)
        searchBox:SetFocus()
        if searchBox.editbox then
            searchBox.editbox:SetCursorPosition(#name)
        end
        if andSearch then
            self:PerformSearch(frame, name)
        end
    end

    if searchBox.editbox then
        searchBox.editbox:HookScript("OnTabPressed", function()
            if #suggestions > 0 then
                frame.acceptSuggestion(selectedIdx or 1, false)
            end
        end)
        searchBox.editbox:HookScript("OnArrowPressed", function(_, key)
            if #suggestions == 0 then
                return
            end
            if key == "DOWN" then
                selectedIdx = selectedIdx and (selectedIdx % #suggestions) + 1 or 1
            elseif key == "UP" then
                selectedIdx = selectedIdx and ((selectedIdx - 2) % #suggestions) + 1 or #suggestions
            else
                return
            end
            RenderSuggestions()
        end)
    end

    local scopeDropdown = AceGUI:Create("Dropdown")
    scopeDropdown:SetLabel("Search in:")
    scopeDropdown:SetRelativeWidth(0.28)
    scopeDropdown:SetList({names = "Names", both = "Names + descriptions", descriptions = "Descriptions only"},
        {"names", "both", "descriptions"})
    scopeDropdown:SetValue(self:GetSearchScope())
    toolbar:AddChild(scopeDropdown)

    local rankList = {all = "All ranks", none = "No rank"}
    local rankOrder = {"all", "none"}
    for rank = 1, math_max(self.spellDatabase.maxRank or 0, 1) do
        local key = tostring(rank)
        rankList[key] = "Rank " .. key
        rankOrder[#rankOrder + 1] = key
    end

    local rankDropdown = AceGUI:Create("Dropdown")
    rankDropdown:SetLabel("Rank:")
    rankDropdown:SetRelativeWidth(0.18)
    rankDropdown:SetList(rankList, rankOrder)
    local savedRank = self:GetFinderSettings().rankFilter or "all"
    rankDropdown:SetValue(rankList[savedRank] and savedRank or "all")
    toolbar:AddChild(rankDropdown)

    local sortDropdown = AceGUI:Create("Dropdown")
    sortDropdown:SetLabel("Sort By:")
    sortDropdown:SetRelativeWidth(0.24)
    sortDropdown:SetList({name = "Name", spellid = "Spell ID", rank = "Rank", relevance = "Relevance"},
        {"name", "spellid", "rank", "relevance"})
    local savedSort = self:GetFinderSettings().sortMode
    sortDropdown:SetValue(SORT_COMPARATORS[savedSort] and savedSort or "name")
    toolbar:AddChild(sortDropdown)

    frame.sortDropdown = sortDropdown

    local descendingBox = AceGUI:Create("CheckBox")
    descendingBox:SetLabel("Descending")
    descendingBox:SetRelativeWidth(0.22)
    descendingBox:SetValue(self:GetFinderSettings().sortDesc or false)
    toolbar:AddChild(descendingBox)

    local fuzzyBox = AceGUI:Create("CheckBox")
    fuzzyBox:SetLabel("Fuzzy")
    fuzzyBox:SetRelativeWidth(0.18)
    fuzzyBox:SetValue(self:GetFinderSettings().fuzzy or false)
    toolbar:AddChild(fuzzyBox)

    local autocompleteBox = AceGUI:Create("CheckBox")
    autocompleteBox:SetLabel("Autocomplete")
    autocompleteBox:SetRelativeWidth(0.28)
    autocompleteBox:SetValue(self:GetFinderSettings().autocomplete or false)
    toolbar:AddChild(autocompleteBox)

    local statusLabel = AceGUI:Create("Label")
    statusLabel:SetFullWidth(true)
    toolbar:AddChild(statusLabel)
    frame.statusLabel = statusLabel

    local function RefreshResults()
        local text = frame.searchBox:GetText()
        if text and text ~= "" then
            self:PerformSearch(frame, text)
        end
    end

    local function SetFindSpellOption(key, value)
        self:SetFinderSetting(key, value)
        RefreshResults()
    end

    sortDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        SetFindSpellOption("sortMode", value)
    end)

    rankDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        SetFindSpellOption("rankFilter", value)
    end)

    descendingBox:SetCallback("OnValueChanged", function(widget, event, value)
        SetFindSpellOption("sortDesc", value and true or false)
    end)

    function frame.onScopeChanged()
        local scope = self:GetSearchScope()
        scopeDropdown:SetValue(scope)
        searchBox:SetLabel(scope == "descriptions" and "Description text:" or "Spell Name:")
        if scope == "descriptions" then
            ClearSuggestions()
        else
            UpdateSuggestions(searchBox:GetText())
        end
        if self:IsFinderOpen() then
            RefreshResults()
        end
    end

    scopeDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        self:SetSearchScope(value)
    end)

    fuzzyBox:SetCallback("OnValueChanged", function(widget, event, value)
        self:SetFinderSetting("fuzzy", value and true or false)
        if value then
            self:SetFinderSetting("sortMode", "relevance")
            sortDropdown:SetValue("relevance")
        end
        RefreshResults()
    end)

    autocompleteBox:SetCallback("OnValueChanged", function(widget, event, value)
        self:SetFinderSetting("autocomplete", value and true or false)
        UpdateSuggestions(frame.searchBox:GetText())
    end)

    searchBox:SetCallback("OnTextChanged", function(widget, event, text)
        UpdateSuggestions(text)
    end)

    searchBox:SetCallback("OnEnterPressed", function(widget)
        if selectedIdx then
            frame.acceptSuggestion(selectedIdx, true)
            return
        end
        ClearSuggestions()
        self:PerformSearch(frame, frame.searchBox:GetText())
    end)

    searchBtn:SetCallback("OnClick", function()
        ClearSuggestions()
        self:PerformSearch(frame, frame.searchBox:GetText())
    end)

    local body = AceGUI:Create("SimpleGroup")
    body.noAutoHeight = true
    body:SetLayout("Manual")
    container:AddChild(body)
    body.frame:ClearAllPoints()
    body.frame:SetPoint("TOPLEFT", toolbar.frame, "BOTTOMLEFT", 0, -TOOLBAR_GAP)
    body.frame:SetPoint("BOTTOMRIGHT", container.content, "BOTTOMRIGHT", 0, 0)

    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetLayout("List")
    body:AddChild(scrollFrame)

    frame.scrollFrame = scrollFrame

    local detailGroup = AceGUI:Create("SimpleGroup")
    frame.detailGroup = detailGroup
    detailGroup.noAutoHeight = true
    detailGroup:SetLayout("List")
    body:AddChild(detailGroup)
    detailGroup.frame:ClearAllPoints()
    detailGroup.frame:SetPoint("TOPRIGHT", body.content, "TOPRIGHT", 0, 0)
    detailGroup.frame:SetPoint("BOTTOMRIGHT", body.content, "BOTTOMRIGHT", 0, 0)
    detailGroup:SetWidth(DETAIL_WIDTH)
    scrollFrame.frame:ClearAllPoints()
    scrollFrame.frame:SetPoint("TOPLEFT", body.content, "TOPLEFT", 0, 0)
    scrollFrame.frame:SetPoint("BOTTOMRIGHT", detailGroup.frame, "BOTTOMLEFT", -PANE_GAP, 0)

    local detail = {}
    frame.detail = detail

    detail.title = AceGUI:Create("Label")
    detail.title:SetFullWidth(true)
    detail.title:SetFontObject(GameFontNormalLarge)
    detailGroup:AddChild(detail.title)

    detail.subtitle = AceGUI:Create("Label")
    detail.subtitle:SetFullWidth(true)
    detailGroup:AddChild(detail.subtitle)

    detail.idBox = AceGUI:Create("EditBox")
    detail.idBox:SetLabel("Spell ID (click, then Ctrl+C)")
    detail.idBox:SetFullWidth(true)
    detail.idBox:DisableButton(true)
    if detail.idBox.editbox then
        detail.idBox.editbox:HookScript("OnEditFocusGained", function(editbox)
            editbox:HighlightText()
        end)
    end
    detailGroup:AddChild(detail.idBox)

    detail.description = AceGUI:Create("Label")
    detail.description:SetFullWidth(true)
    detailGroup:AddChild(detail.description)

    local buttons = AceGUI:Create("SimpleGroup")
    buttons:SetFullWidth(true)
    buttons:SetLayout("Flow")
    detailGroup:AddChild(buttons)

    detail.insert = AceGUI:Create("Button")
    detail.insert:SetText("Insert in chat")
    detail.insert:SetRelativeWidth(0.5)
    detail.insert:SetCallback("OnClick", function(widget)
        local spell = frame.selectedSpell
        if spell then
            self:InsertSpellText(spell, nil, widget)
        end
    end)
    buttons:AddChild(detail.insert)

    detail.insertDescription = AceGUI:Create("Button")
    detail.insertDescription:SetText("With description")
    detail.insertDescription:SetRelativeWidth(0.5)
    detail.insertDescription:SetCallback("OnClick", function(widget)
        local spell = frame.selectedSpell
        if not spell then
            return
        end
        local description = RowDescription(spell.spellID)
        if not description then
            ShowFinderToast(widget, "No description available for this spell.", 1, 0.3, 0.3)
            return
        end
        self:InsertSpellText(spell, description, widget)
    end)
    buttons:AddChild(detail.insertDescription)

    self:ShowSpellDetail(frame, nil)

    if frame.lastSearchTerm and frame.lastSearchTerm ~= "" then
        self:PerformSearch(frame, frame.lastSearchTerm)
    else
        self:ShowFinderEmpty(frame, "")
        self:UpdateFinderStatus(frame, nil)
    end
end

function SoundAlerter:CreateFindSpellFrame()
    local frame = AceGUI:Create("Window")
    frame:SetTitle("SoundAlerter - Find Spell")
    frame:SetLayout("Manual")
    frame:SetWidth(FINDER_WIDTH)
    frame:SetHeight(560)

    if frame.frame then
        frame.frame:SetFrameStrata("DIALOG")
        frame.frame:Raise()
    end

    frame.lastSearchTerm = ""

    self:RenderSearchPane(frame, frame)
    self:PrepareSearchExtras()

    if frame.frame then
        frame.frame:HookScript("OnShow", function()
            self:OnFindSpellShown(frame)
        end)
        frame.frame:HookScript("OnHide", function()
            self:OnFindSpellHidden(frame)
        end)
    end

    return frame
end
