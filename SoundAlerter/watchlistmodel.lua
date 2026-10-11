SA_Watchlist = {}

function SA_Watchlist.Normalize(text, isGuild)
    if type(text) ~= "string" then return nil end
    local value = text:match("^%s*(.-)%s*$")
    if not isGuild then
        value = value:match("^([^-]*)")
    end
    value = value:lower()
    if value == "" then return nil end
    return value
end

function SA_Watchlist.Entries(text)
    local entries = {}
    if type(text) ~= "string" then return entries end
    for entry in text:gmatch("[^,;\n]+") do
        local trimmed = entry:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            entries[#entries + 1] = trimmed
        end
    end
    return entries
end

function SA_Watchlist.Parse(text, isGuild)
    local set = {}
    for _, entry in ipairs(SA_Watchlist.Entries(text)) do
        local key = SA_Watchlist.Normalize(entry, isGuild)
        if key then set[key] = true end
    end
    return set
end

function SA_Watchlist.Match(names, guilds, name, guild)
    local nameKey = SA_Watchlist.Normalize(name, false)
    if nameKey and names[nameKey] then return "name" end
    local guildKey = SA_Watchlist.Normalize(guild, true)
    if guildKey and guilds[guildKey] then return "guild" end
    return nil
end

function SA_Watchlist.Add(text, entry, isGuild)
    local key = SA_Watchlist.Normalize(entry, isGuild)
    if not key then return text, false end
    local entries = SA_Watchlist.Entries(text)
    for _, existing in ipairs(entries) do
        if SA_Watchlist.Normalize(existing, isGuild) == key then
            return text, false
        end
    end
    entries[#entries + 1] = entry:match("^%s*(.-)%s*$")
    return table.concat(entries, ", "), true
end

function SA_Watchlist.Remove(text, entry, isGuild)
    local key = SA_Watchlist.Normalize(entry, isGuild)
    if not key then return text, false end
    local kept, removed = {}, false
    for _, existing in ipairs(SA_Watchlist.Entries(text)) do
        if SA_Watchlist.Normalize(existing, isGuild) == key then
            removed = true
        else
            kept[#kept + 1] = existing
        end
    end
    return table.concat(kept, ", "), removed
end
