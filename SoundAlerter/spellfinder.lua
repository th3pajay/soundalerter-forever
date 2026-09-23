local AceGUI = LibStub("AceGUI-3.0")
local SoundAlerter = SoundAlerter

local pairs, tonumber = pairs, tonumber
local table_insert, table_sort, table_remove = table.insert, table.sort, table.remove
local string_lower, string_sub, string_match, string_find, string_format = string.lower, string.sub, string.match, string.find, string.format
local math_min, math_max, math_floor = math.min, math.max, math.floor
local time, select = time, select
local GetSpellInfo, GetSpellLink = SA_COMPAT.GetSpellInfo, SA_COMPAT.GetSpellLink
local GetSpellDescription = SA_COMPAT.GetSpellDescription
local GetBuildInfo = GetBuildInfo

local searchDebounceTimer = nil
local DEBOUNCE_DELAY = 0.2
local MAX_SPELL_ID = 70000
local DB_MAX_AGE = 2592000

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
local MAX_CACHE_SIZE = 50

local SEARCH_TIMING_SAMPLE_CAP = 100
local searchTimingSamples = {}
local searchTimingIndex = 1
local searchTimingCount = 0

local function RecordSearchTiming(elapsedMs)
    searchTimingSamples[searchTimingIndex] = elapsedMs
    searchTimingIndex = (searchTimingIndex % SEARCH_TIMING_SAMPLE_CAP) + 1
    if searchTimingCount < SEARCH_TIMING_SAMPLE_CAP then
        searchTimingCount = searchTimingCount + 1
    end
end

local SORT_COMPARATORS = {
    name = function(a, b)
        if a.baseName ~= b.baseName then
            return a.baseName < b.baseName
        end
        return a.rankNum < b.rankNum
    end,
    spellid = function(a, b) return a.spellID < b.spellID end,
    rank = function(a, b)
        if a.rankNum ~= b.rankNum then
            return a.rankNum < b.rankNum
        end
        return a.baseName < b.baseName
    end,
}

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

    local CHUNK_SIZE = 1000
    local CHUNK_DELAY = 0.05
    local currentID = 1
    local ProcessChunk

    local function ProcessChunkInner()
        local endID = math_min(currentID + CHUNK_SIZE - 1, MAX_SPELL_ID)
        local foundCount = 0

        local AddSpellToDatabase = self.AddSpellToDatabase

        for spellID = currentID, endID do
            local ok, name, rank = pcall(GetSpellInfo, spellID)
            if ok and name then
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
            self:Print(string_format("Spell database built: %d spells indexed", spellCount))
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

    self:Print("Building spell database... This will take ~3-4 seconds.")
    ProcessChunk()
end

function SoundAlerter:SaveSpellDatabase()
    SoundAlerterSpellDB = {
        byID = self.spellDatabase.byID,
        names = self.spellDatabase.names,
        namesLower = self.spellDatabase.namesLower,
        nameToIdx = self.spellDatabase.nameToIdx,
        totalSpells = self.spellDatabase.totalSpells,
        version = GetBuildInfo(),
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

    local age = time() - SoundAlerterSpellDB.lastUpdate
    if age > DB_MAX_AGE then
        self:Print("Spell database outdated - rebuilding")
        return false
    end

    self.spellDatabase.byID = SoundAlerterSpellDB.byID
    self.spellDatabase.names = SoundAlerterSpellDB.names
    self.spellDatabase.namesLower = SoundAlerterSpellDB.namesLower or {}
    self.spellDatabase.nameToIdx = SoundAlerterSpellDB.nameToIdx
    self.spellDatabase.totalSpells = SoundAlerterSpellDB.totalSpells or 0
    self.spellDatabase.lastUpdate = SoundAlerterSpellDB.lastUpdate
    self.spellDatabase.source = "loaded"
    self.spellDatabase.buildSeconds = nil
    self.spellDatabase.builtOnVersion = SoundAlerterSpellDB.version

    if not SoundAlerterSpellDB.namesLower then
        local db = self.spellDatabase
        for i = 1, #db.names do
            db.namesLower[i] = string_lower(db.names[i])
        end

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
    local names = db.names
    local byID = db.byID

    local string_byte, string_char = string.byte, string.char

    for letter = string_byte('a'), string_byte('z') do
        searchIndex[string_char(letter)] = {}
    end

    local rankedSpells = 0
    local prefixBuckets = 0

    for spellID, data in pairs(byID) do
        if data.rank and data.rank > 0 then
            rankedSpells = rankedSpells + 1
        end
        local baseName = names[data.nameIdx]
        if baseName then
            local lower = string_lower(baseName)
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
end

function SoundAlerter:GetDatabaseStats()
    local db = self.spellDatabase
    return {
        isBuilding = db.isBuilding,
        progress = db.progress or 0,
        totalScanned = db.totalScanned or 0,
        maxSpellID = MAX_SPELL_ID,
        maxAge = DB_MAX_AGE,
        totalSpells = db.totalSpells or 0,
        uniqueNames = #db.names,
        rankedSpells = db.rankedSpells or 0,
        prefixBuckets = db.prefixBuckets or 0,
        lastUpdate = db.lastUpdate or 0,
        builtOnVersion = db.builtOnVersion,
        currentVersion = GetBuildInfo(),
        source = db.source,
        buildSeconds = db.buildSeconds,
        cacheEntries = #cacheAge,
        cacheMax = MAX_CACHE_SIZE,
    }
end

function SoundAlerter:SearchSpells(searchTerm, rankFilter)
    local db = self.spellDatabase

    if not searchTerm or searchTerm == "" then
        return {}
    end

    local cacheKey = searchTerm .. (rankFilter or "")
    local searchCache = db.searchCache
    local cachedResult = searchCache[cacheKey]
    if cachedResult then
        if self.db1.profile.debugmode then
            self:Print(string_format("[SpellFinder] Cache hit for '%s': %d result(s)", searchTerm, #cachedResult))
        end
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

    if searchLen >= 3 then
        local prefix = string_sub(searchLower, 1, 3)
        candidateSpells = prefixIndex[prefix] or {}
    elseif searchLen >= 1 then
        local firstChar = string_sub(searchLower, 1, 1)
        candidateSpells = searchIndex[firstChar] or {}
    else
        return {}
    end

    local rankFilterNum = rankFilter and rankFilter ~= "" and tonumber(rankFilter) or nil

    local resultCount = 0
    local namesLower = db.namesLower
    for spellID in pairs(candidateSpells) do
        local data = byID[spellID]
        if data then
            local baseName = names[data.nameIdx]
            local baseNameLower = namesLower[data.nameIdx] or string_lower(baseName)

            if string_find(baseNameLower, searchLower, 1, true) then
                if not rankFilterNum or data.rank == rankFilterNum then
                    resultCount = resultCount + 1
                    results[resultCount] = {
                        spellID = spellID,
                        name = baseName,
                        rank = data.rank,
                        baseName = baseName,
                        rankNum = data.rank
                    }
                end
            end
        end
    end

    table_sort(results, function(a, b)
        if a.baseName ~= b.baseName then
            return a.baseName < b.baseName
        end
        return a.rankNum < b.rankNum
    end)

    local elapsedMs = debugprofilestop() - searchStartTime
    self:CacheSearchResult(cacheKey, results)
    RecordSearchTiming(elapsedMs)

    if self.db1.profile.debugmode then
        self:Print(string_format("[SpellFinder] Search '%s': %d result(s) in %.2fms", searchTerm, resultCount, elapsedMs))
    end

    return results
end

function SoundAlerter:GetSearchPercentiles()
    if searchTimingCount == 0 then return nil end

    local sorted = {}
    for i = 1, searchTimingCount do
        sorted[i] = searchTimingSamples[i]
    end
    table_sort(sorted)

    local function percentile(p)
        local idx = math_max(1, math.ceil(p * searchTimingCount))
        return sorted[idx]
    end

    return percentile(0.50), percentile(0.95), percentile(0.99), sorted[searchTimingCount], searchTimingCount
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

function SoundAlerter:DisplayDatabaseStatus(scrollFrame)
    local statusLabel = AceGUI:Create("Label")
    statusLabel:SetText("Database Status: " .. self:GetDatabaseStatus())
    statusLabel:SetFullWidth(true)
    scrollFrame:AddChild(statusLabel)
end

function SoundAlerter:RenderSpellRows(scrollFrame, frame, results, cap)
    local resultCount = #results
    local displayCount = math_min(resultCount, cap or 100)
    local BATCH_SIZE = 15

    local function CreateSpellEntry(spell, isLast)
        local icon = select(3, GetSpellInfo(spell.spellID))
        local iconStr = icon and "\124T" .. icon .. ":20\124t " or ""

        local rankText = spell.rankNum > 0 and ("Rank " .. spell.rankNum) or "No Rank"

        local spellDescription
        local descriptionFetched = false
        local function EnsureDescription()
            if descriptionFetched then return end
            C_Spell.RequestLoadSpellData(spell.spellID)
            local tooltipText = GetSpellDescription(spell.spellID)
            if tooltipText and tooltipText ~= "" then
                spellDescription = tooltipText
                descriptionFetched = true
            end
        end

        local spellLabel = AceGUI:Create("InteractiveLabel")
        spellLabel:SetText(string_format("%s|cFFFFFFFF%s|r |cFFAAAAAA(%s)|r |cFF00FFFF[%d]|r |cFF888888[click: insert, shift-click: desc]|r",
            iconStr, spell.baseName, rankText, spell.spellID))
        spellLabel:SetFullWidth(true)

        spellLabel:SetCallback("OnClick", function(widget)
            EnsureDescription()

            local baseText = string_format("%s (%s) - ID: %d", spell.baseName, rankText, spell.spellID)

            if IsShiftKeyDown() and not spellDescription then
                GameTooltip:SetOwner(widget.frame, "ANCHOR_CURSOR")
                GameTooltip:AddLine("No description available for this spell.", 1, 0.3, 0.3)
                GameTooltip:Show()
                self:ScheduleTimer(function() GameTooltip:Hide() end, 1.5)
                return
            end

            local text = IsShiftKeyDown() and (baseText .. ": " .. spellDescription) or baseText
            local editBox = ChatEdit_GetActiveWindow()
            if not editBox and ChatFrame1EditBox and ChatFrame1EditBox:IsShown() then
                editBox = ChatFrame1EditBox
            end

            if editBox then
                editBox:Insert(text)
                editBox:SetFocus()

                GameTooltip:SetOwner(widget.frame, "ANCHOR_CURSOR")
                GameTooltip:AddLine("Inserted into chat!", 0, 1, 0)
                GameTooltip:Show()
                self:ScheduleTimer(function() GameTooltip:Hide() end, 1.5)
            else
                self:Print(text)
            end
        end)

        spellLabel:SetCallback("OnEnter", function(widget)
            EnsureDescription()
            GameTooltip:SetOwner(widget.frame, "ANCHOR_CURSOR")
            local spellLink = GetSpellLink(spell.spellID)
            if spellLink then
                GameTooltip:SetHyperlink(spellLink)
            else
                GameTooltip:AddLine(spell.name, 1, 1, 1)
                GameTooltip:AddLine("Spell ID: " .. spell.spellID, 0.5, 0.5, 1)
            end
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("Click: Insert name, rank, and ID", 0.7, 0.7, 0.7)
            if spellDescription then
                GameTooltip:AddLine("Shift-Click: Insert name, rank, ID, and description", 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
        spellLabel:SetCallback("OnLeave", function()
            GameTooltip:Hide()
        end)
        scrollFrame:AddChild(spellLabel)

        if not isLast then
            local entrySpacer = AceGUI:Create("Label")
            entrySpacer:SetText(" ")
            entrySpacer:SetFullWidth(true)
            scrollFrame:AddChild(entrySpacer)
        end
    end

    local nextIndex = 1
    local function RenderBatch()
        local batchEnd = math_min(nextIndex + BATCH_SIZE - 1, displayCount)
        for i = nextIndex, batchEnd do
            CreateSpellEntry(results[i], i == displayCount)
        end
        nextIndex = batchEnd + 1
        if nextIndex <= displayCount then
            self:ScheduleTimer(RenderBatch, 0.02)
        elseif resultCount > displayCount then
            local spacerMore = AceGUI:Create("Label")
            spacerMore:SetText(" ")
            spacerMore:SetFullWidth(true)
            scrollFrame:AddChild(spacerMore)

            local moreLabel = AceGUI:Create("Label")
            moreLabel:SetText(string_format("|cFFFF8800Showing first %d of %d. Refine your search to see more specific results.|r", displayCount, resultCount))
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
    frame.lastSearchTerm = searchTerm

    local queryTerm, rankFilter = ExtractRankToken(searchTerm)
    local cached = self:SearchSpells(queryTerm, rankFilter)
    local results = {}
    for i = 1, #cached do
        results[i] = cached[i]
    end

    local sortMode = (self.db1.profile.findSpell and self.db1.profile.findSpell.sortMode) or "name"
    table_sort(results, SORT_COMPARATORS[sortMode] or SORT_COMPARATORS.name)

    local scrollFrame = frame.scrollFrame
    scrollFrame:ReleaseChildren()

    local resultCount = #results
    if resultCount == 0 then
        local label = AceGUI:Create("Label")
        if self.spellDatabase.isBuilding then
            label:SetText("|cFFFF8800Database still building. Please wait and try again.|r\n\n" ..
                          self:GetDatabaseStatus())
        else
            label:SetText("|cFFFF0000No spells found for '" .. searchTerm .. "'|r\n\n" ..
                          "Try a different search term or check spelling.")
        end
        label:SetFullWidth(true)
        scrollFrame:AddChild(label)

        self:DisplayDatabaseStatus(scrollFrame)
        return
    end

    local header = AceGUI:Create("Heading")
    header:SetText(string_format("Found %d spell(s) for '%s'", resultCount, searchTerm))
    header:SetFullWidth(true)
    scrollFrame:AddChild(header)

    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    scrollFrame:AddChild(spacer)

    self:RenderSpellRows(scrollFrame, frame, results, 50)

    local footerSpacer = AceGUI:Create("Label")
    footerSpacer:SetText(" ")
    footerSpacer:SetFullWidth(true)
    scrollFrame:AddChild(footerSpacer)

    self:DisplayDatabaseStatus(scrollFrame)
end

function SoundAlerter:RenderSearchPane(container, frame)
    local desc = AceGUI:Create("Label")
    desc:SetText("Search for spell IDs to add to spellist.lua. Add 'r2' or 'rank:2' to filter by rank (e.g. 'frostbolt r2').")
    desc:SetFullWidth(true)
    desc:SetColor(0.8, 0.8, 0.8)
    container:AddChild(desc)

    local inputGroup = AceGUI:Create("SimpleGroup")
    inputGroup:SetFullWidth(true)
    inputGroup:SetLayout("Flow")
    container:AddChild(inputGroup)

    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel("Spell Name:")
    searchBox:SetWidth(280)
    searchBox:SetText(frame.lastSearchTerm or "")
    inputGroup:AddChild(searchBox)

    local searchBtn = AceGUI:Create("Button")
    searchBtn:SetText("Search")
    searchBtn:SetWidth(100)
    inputGroup:AddChild(searchBtn)

    frame.searchBox = searchBox

    local sortGroup = AceGUI:Create("SimpleGroup")
    sortGroup:SetFullWidth(true)
    sortGroup:SetLayout("Flow")
    container:AddChild(sortGroup)

    local sortDropdown = AceGUI:Create("Dropdown")
    sortDropdown:SetLabel("Sort By:")
    sortDropdown:SetWidth(150)
    sortDropdown:SetList({name = "Name", spellid = "Spell ID", rank = "Rank"}, {"name", "spellid", "rank"})
    sortDropdown:SetValue((self.db1.profile.findSpell and self.db1.profile.findSpell.sortMode) or "name")
    sortGroup:AddChild(sortDropdown)

    frame.sortDropdown = sortDropdown

    sortDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        if not self.db1.profile.findSpell then
            self.db1.profile.findSpell = {}
        end
        self.db1.profile.findSpell.sortMode = value

        if frame.searchBox:GetText() and frame.searchBox:GetText() ~= "" then
            self:PerformSearch(frame, frame.searchBox:GetText())
        end
    end)

    searchBox:SetCallback("OnTextChanged", function(widget, event, text)
        local sadb = self.db1.profile
        if sadb.findSpell and sadb.findSpell.autoSearch then
            if searchDebounceTimer then
                self:CancelTimer(searchDebounceTimer)
            end
            searchDebounceTimer = self:ScheduleTimer(function()
                if text and text ~= "" and #text >= 2 then
                    self:PerformSearch(frame, frame.searchBox:GetText())
                end
            end, DEBOUNCE_DELAY)
        end
    end)

    searchBox:SetCallback("OnEnterPressed", function(widget)
        if searchDebounceTimer then
            self:CancelTimer(searchDebounceTimer)
            searchDebounceTimer = nil
        end
        self:PerformSearch(frame, frame.searchBox:GetText())
    end)

    searchBtn:SetCallback("OnClick", function()
        if searchDebounceTimer then
            self:CancelTimer(searchDebounceTimer)
            searchDebounceTimer = nil
        end
        self:PerformSearch(frame, frame.searchBox:GetText())
    end)

    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetLayout("List")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetFullHeight(true)
    container:AddChild(scrollFrame)

    frame.scrollFrame = scrollFrame

    if frame.lastSearchTerm and frame.lastSearchTerm ~= "" then
        self:PerformSearch(frame, frame.lastSearchTerm)
    else
        self:DisplayDatabaseStatus(scrollFrame)
    end
end

function SoundAlerter:CreateFindSpellFrame()
    local frame = AceGUI:Create("Window")
    frame:SetTitle("SoundAlerter - Find Spell")
    frame:SetLayout("Flow")
    frame:SetWidth(620)
    frame:SetHeight(520)

    if frame.frame then
        frame.frame:SetFrameStrata("DIALOG")
        frame.frame:Raise()
    end

    frame.lastSearchTerm = ""

    self:RenderSearchPane(frame, frame)

    return frame
end
