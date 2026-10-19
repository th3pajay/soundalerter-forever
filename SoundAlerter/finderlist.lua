SA_FinderList = {}

local List = SA_FinderList

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
