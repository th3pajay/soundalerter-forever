do
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
end

do
local SoundAlerter = SoundAlerter

local Plain, SafeUnitName = SA_COMPAT.Plain, SA_COMPAT.SafeUnitName

local WATCH_SPACING = 60
local watchAlertAt = {}
local cache = { namesText = nil, guildsText = nil, names = {}, guilds = {} }

local function Sets(profile)
    local namesText = profile.watchNamesText or ""
    local guildsText = profile.watchGuildsText or ""
    if cache.namesText ~= namesText then
        cache.namesText = namesText
        cache.names = SA_Watchlist.Parse(namesText, false)
    end
    if cache.guildsText ~= guildsText then
        cache.guildsText = guildsText
        cache.guilds = SA_Watchlist.Parse(guildsText, true)
    end
    return cache.names, cache.guilds
end

function SoundAlerter:CheckWatchlist(unit)
    local profile = self.db1.profile
    if not profile.watchlistEnabled then return end
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return end
    local guid = Plain(UnitGUID(unit))
    if not guid then return end
    local now = GetTime()
    local last = watchAlertAt[guid]
    if last and now - last < WATCH_SPACING then return end
    if not self:IsAlertZoneAllowed() or self:IsQuiet() then return end

    local name = SafeUnitName(unit)
    local guild = Plain((GetGuildInfo(unit)))
    local names, guilds = Sets(profile)
    local kind = SA_Watchlist.Match(names, guilds, name, guild)
    if not kind then return end

    watchAlertAt[guid] = now
    self:Debug("Watchlist", "%s matched by %s (guild %s)", tostring(name), kind, tostring(guild))
    self:PlayVoice(profile.sapath .. "watchlist.mp3")
    self:RecordStat("watchlistAlerts")
    self:Print(string.format("|cffFF7D0AWatchlist:|r %s%s is nearby", tostring(name or "A watched player"), guild and (" <" .. guild .. ">") or ""))
end

function SoundAlerter:PruneWatchlist(now)
    for guid, timestamp in pairs(watchAlertAt) do
        if now - timestamp > WATCH_SPACING * 2 then
            watchAlertAt[guid] = nil
        end
    end
end

function SoundAlerter:HandleWatchCommand(command, rest)
    local profile = self.db1.profile
    local isGuild = false
    local entry = rest
    local guildEntry = rest:match("^[Gg][Uu][Ii][Ll][Dd]%s+(.+)$")
    if guildEntry then
        isGuild = true
        entry = guildEntry
    end
    local field = isGuild and "watchGuildsText" or "watchNamesText"

    if command == "watchlist" or entry == "" then
        self:Print("|cffFFD700=== Watchlist (" .. (profile.watchlistEnabled and "on" or "off") .. ") ===|r")
        self:Print("  Names: " .. ((profile.watchNamesText or "") ~= "" and profile.watchNamesText or "none"))
        self:Print("  Guilds: " .. ((profile.watchGuildsText or "") ~= "" and profile.watchGuildsText or "none"))
        self:Print("  /sa watch [guild] <name>, /sa unwatch [guild] <name>")
        return
    end

    if command == "watch" then
        local text, added = SA_Watchlist.Add(profile[field], entry, isGuild)
        profile[field] = text
        self:Print(added and ("Now watching " .. entry .. ".") or (entry .. " is already on the list or empty."))
        if added and not profile.watchlistEnabled then
            self:Print("The watchlist is switched off: turn it on under /sa -> Proximity Alerts -> Watchlist.")
        end
    else
        local text, removed = SA_Watchlist.Remove(profile[field], entry, isGuild)
        profile[field] = text
        self:Print(removed and ("No longer watching " .. entry .. ".") or (entry .. " was not on the list."))
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter")
end
end
