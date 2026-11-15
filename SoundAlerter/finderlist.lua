SA_FinderList = {}

local List = SA_FinderList

local string_find, string_sub, string_byte = string.find, string.sub, string.byte

local editRowA, editRowB, editRowC = {}, {}, {}

function List.SubsequenceSpan(name, termChars, termLen)
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

function List.EditDistanceWithin(termBytes, termLen, word, wordLen, maxDist)
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

function List.BestEditDistance(termBytes, termLen, name, maxDist)
    local nameLen = #name
    local best = List.EditDistanceWithin(termBytes, termLen, name, nameLen, maxDist)
    if not string_find(name, " ", 1, true) then
        return best
    end

    local start = 1
    while start <= nameLen do
        local stop = string_find(name, " ", start, true) or (nameLen + 1)
        local wordLen = stop - start
        if wordLen > 0 and wordLen - termLen <= maxDist and termLen - wordLen <= maxDist then
            local distance = List.EditDistanceWithin(termBytes, termLen, string_sub(name, start, stop - 1), wordLen, maxDist)
            if distance and (not best or distance < best) then
                best = distance
            end
        end
        start = stop + 1
    end
    return best
end

local scoreChars, scoreBytes = {}, {}

local function StartsWord(text, char)
    return string_sub(text, 1, 1) == char or string_find(text, " " .. char, 1, true) ~= nil
end

function List.Score(text, term)
    local termLen = #term
    if termLen == 0 then return 0 end
    local pos = string_find(text, term, 1, true)
    if pos then return pos + (#text - termLen) / 100 end
    if termLen < 3 or not StartsWord(text, string_sub(term, 1, 1)) then return nil end
    for i = 1, termLen do
        scoreChars[i] = string_sub(term, i, i)
        scoreBytes[i] = string_byte(term, i)
    end
    local span = List.SubsequenceSpan(text, scoreChars, termLen)
    if span and span <= termLen * 2 then return 1000 + span + (#text - termLen) / 100 end
    if termLen < 4 then return nil end
    local distance = List.BestEditDistance(scoreBytes, termLen, text, termLen >= 7 and 2 or 1)
    if distance then return 2000 + distance * 100 + math.abs(#text - termLen) / 100 end
    return nil
end

List.WIDTH = 820
List.MIN_WIDTH = 640
List.HEIGHT = 560
List.ROW_HEIGHT = 26
List.RESULT_CAP = 500
List.MENU_COLUMN = 12
List.WHEEL_ROWS = 3
List.DEBOUNCE = 0.12
List.SUGGESTION_LIMIT = 8

List.SCOPES = {
    { "names", "Names" },
    { "both", "Names + descriptions" },
    { "descriptions", "Descriptions" },
}

List.KINDS = {
    { "all", "All spells" },
    { "active", "Active only" },
    { "passive", "Passive only" },
}

List.KNOWNS = {
    { "all", "Any" },
    { "known", "Known by you" },
    { "unknown", "Not known by you" },
}

List.SORTS = {
    { "name", "Name" },
    { "spellid", "Spell ID" },
    { "rank", "Rank" },
    { "relevance", "Relevance" },
}

function List.Cap(count)
    if count > List.RESULT_CAP then
        return List.RESULT_CAP, count - List.RESULT_CAP
    end
    return count, 0
end

function List.Rows(height)
    return math.max(1, math.floor(height / List.ROW_HEIGHT))
end

function List.ClampTop(top, count, rows)
    local last = math.max(1, count - rows + 1)
    return math.max(1, math.min(top or 1, last))
end

function List.Wheel(top, delta, count, rows)
    return List.ClampTop(top - delta * List.WHEEL_ROWS, count, rows)
end

function List.Move(selected, count, delta)
    if count <= 0 then return nil end
    if not selected then
        return delta >= 0 and 1 or count
    end
    return math.max(1, math.min(count, selected + delta))
end

function List.Reveal(top, selected, rows)
    if not selected then return top end
    if selected < top then return selected end
    if selected > top + rows - 1 then return selected - rows + 1 end
    return top
end

function List.Cycle(index, count, delta)
    if count <= 0 then return nil end
    if delta > 0 then
        return index and (index % count) + 1 or 1
    end
    return index and ((index - 2) % count) + 1 or count
end

function List.MinChars(scope)
    return scope == "descriptions" and 3 or 2
end

function List.Settled(term, scope)
    return term ~= nil and #term >= List.MinChars(scope)
end

function List.Columns(count)
    return math.max(1, math.ceil(count / List.MENU_COLUMN))
end

function List.RankOptions(maxRank)
    local options = { { "all", "All ranks" }, { "none", "No rank" } }
    for rank = 1, math.max(maxRank or 0, 1) do
        options[#options + 1] = { tostring(rank), "Rank " .. rank }
    end
    return options
end

function List.Label(options, value)
    for _, option in ipairs(options) do
        if option[1] == value then return option[2] end
    end
    return options[1][2]
end

function List.Has(options, value)
    for _, option in ipairs(options) do
        if option[1] == value then return true end
    end
    return false
end

function List.Choice(options, value)
    if List.Has(options, value) then return value end
    return options[1][1]
end

function List.ChipText(name, options, value)
    return name .. ": " .. List.Label(options, value)
end

function List.Normalize(settings, rankOptions)
    return {
        scope = List.Choice(List.SCOPES, settings.searchScope or (settings.searchDescriptions and "both") or "names"),
        kind = List.Choice(List.KINDS, settings.kindFilter),
        known = List.Choice(List.KNOWNS, settings.knownFilter),
        sort = List.Has(List.SORTS, settings.sortMode) and settings.sortMode or "name",
        rank = List.Has(rankOptions, settings.rankFilter) and settings.rankFilter or "all",
        fuzzy = settings.fuzzy and true or false,
        autocomplete = settings.autocomplete and true or false,
        descending = settings.sortDesc and true or false,
    }
end
