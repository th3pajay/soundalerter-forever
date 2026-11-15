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

function SA_Watchlist.Toggle(text, entry, isGuild)
    if not SA_Watchlist.Normalize(entry, isGuild) then return text, nil end
    local updated, removed = SA_Watchlist.Remove(text, entry, isGuild)
    if removed then return updated, "removed" end
    local added
    updated, added = SA_Watchlist.Add(text, entry, isGuild)
    return updated, added and "added" or nil
end
end

do
local SoundAlerter = SoundAlerter

local Plain, SafeUnitName, SafeUnitClass = SA_COMPAT.Plain, SA_COMPAT.SafeUnitName, SA_COMPAT.SafeUnitClass
local Normalize, Match = SA_Watchlist.Normalize, SA_Watchlist.Match
local type, next, wipe = type, next, wipe or function(t) for k in pairs(t) do t[k] = nil end return t end

local WATCH_SPACING = 60
local MATCH_LIMIT = 400
local KEY_LIMIT = 512
local watchAlertAt = {}
local cache = { namesText = nil, guildsText = nil, names = {}, guilds = {} }
local state = { version = 0, active = false }
local matchKind, matchCount = {}, 0
local nameKeys, nameKeyCount = {}, 0

local function Sets(profile)
    local namesText = profile.watchNamesText or ""
    local guildsText = profile.watchGuildsText or ""
    local changed = false
    if cache.namesText ~= namesText then
        cache.namesText = namesText
        cache.names = SA_Watchlist.Parse(namesText, false)
        changed = true
    end
    if cache.guildsText ~= guildsText then
        cache.guildsText = guildsText
        cache.guilds = SA_Watchlist.Parse(guildsText, true)
        changed = true
    end
    local active = (profile.watchlistEnabled and (next(cache.names) ~= nil or next(cache.guilds) ~= nil)) and true or false
    if changed or active ~= state.active then
        state.active = active
        state.version = state.version + 1
        wipe(matchKind)
        matchCount = 0
    end
    return cache.names, cache.guilds
end

local function NameKey(name)
    local key = nameKeys[name]
    if key ~= nil then return key end
    if nameKeyCount >= KEY_LIMIT then
        wipe(nameKeys)
        nameKeyCount = 0
    end
    key = Normalize(name, false) or false
    nameKeys[name] = key
    nameKeyCount = nameKeyCount + 1
    return key
end

local function NameWatched(names, name)
    if type(name) ~= "string" then return false end
    local key = NameKey(name)
    return key and names[key] and true or false
end

local function MatchUnit(names, guilds, guid, unit)
    local cached = matchKind[guid]
    if cached ~= nil then return cached or nil end
    local name = SafeUnitName(unit)
    local guild = Plain((GetGuildInfo(unit)))
    local kind = Match(names, guilds, name, guild)
    if kind or (name ~= nil and (guild ~= nil or next(guilds) == nil)) then
        matchKind[guid] = kind or false
        matchCount = matchCount + 1
    end
    return kind, name, guild
end

local function FireWatchAlert(self, profile, guid, name, guild, now, spotter)
    watchAlertAt[guid] = now
    self:PlayVoice(profile.sapath .. "watchlist.mp3")
    self:RecordStat("watchlistAlerts")
    self:Print(string.format("|cffFF7D0AWatchlist:|r %s%s is nearby%s", tostring(name or "A watched player"), guild and (" <" .. guild .. ">") or "", spotter and (" (spotted by " .. spotter .. ")") or ""))
end

local function OptionsOpen()
    local dialog = LibStub and LibStub("AceConfigDialog-3.0", true)
    return dialog and dialog.OpenFrames and dialog.OpenFrames["SoundAlerter"] ~= nil
end

local function ReportChange(self, profile, entry, result)
    if result == "added" then
        self:Print("Now watching " .. entry .. ".")
        if not profile.watchlistEnabled then
            self:Print("The watchlist is switched off: turn it on under /sa -> Proximity Alerts -> Watchlist.")
        end
    else
        self:Print("No longer watching " .. entry .. ".")
    end
    Sets(profile)
    if OptionsOpen() then LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter") end
    local toasts = self.ProximityToasts
    if toasts and toasts.RefreshWatched then toasts:RefreshWatched() end
    if self.RefreshEnemyFinder then self:RefreshEnemyFinder() end
end

function SoundAlerter:WatchState()
    Sets(self.db1.profile)
    return state
end

function SoundAlerter:IsWatchedGuid(guid)
    if not guid then return false end
    Sets(self.db1.profile)
    if not state.active then return false end
    return matchKind[guid] and true or false
end

function SoundAlerter:IsWatchedName(name)
    local names = Sets(self.db1.profile)
    if not state.active then return false end
    return NameWatched(names, name)
end

function SoundAlerter:WatchFiredNow(guid)
    return guid ~= nil and watchAlertAt[guid] == GetTime()
end

function SoundAlerter:StampWatched(record)
    local names = Sets(self.db1.profile)
    if record.watchVer ~= state.version or record.watchName ~= record.name then
        record.watchVer, record.watchName = state.version, record.name
        record.watched = state.active and (NameWatched(names, record.name) or (matchKind[record.guid] and true or false)) or false
    end
    return record.watched
end

function SoundAlerter:ToggleWatchName(name)
    if type(name) ~= "string" then return nil end
    local profile = self.db1.profile
    local text, result = SA_Watchlist.Toggle(profile.watchNamesText, name, false)
    if not result then return nil end
    profile.watchNamesText = text
    ReportChange(self, profile, name:match("^%s*(.-)%s*$"), result)
    return result
end

function SoundAlerter:AlertSharedWatch(guid, name, sender)
    local profile = self.db1.profile
    local names = Sets(profile)
    if not state.active or not NameWatched(names, name) then return false end
    local now = GetTime()
    local last = watchAlertAt[guid]
    if last and now - last < WATCH_SPACING then return false end
    if not self:IsAlertZoneAllowed() or self:IsQuiet() then return false end
    FireWatchAlert(self, profile, guid, name, nil, now, sender)
    return true
end

function SoundAlerter:AlertGlobalWatch(record, sender)
    local guid = record.guid
    if not guid then return false end
    local now = GetTime()
    local last = watchAlertAt[guid]
    if last and now - last < WATCH_SPACING then return false end
    if not self:IsAlertZoneAllowed() or self:IsQuiet() then return false end
    local spotter = type(sender) == "string" and sender:match("^[^-]*") or nil
    if spotter == "" then spotter = nil end
    FireWatchAlert(self, self.db1.profile, guid, record.name, nil, now, spotter)
    local toasts = self.ProximityToasts
    if toasts and toasts:GetSettings().enabled then
        toasts:ShowToast(record.name, record.class, nil, guid, record.level, nil, spotter and ("WATCHED  spotted by " .. spotter) or "WATCHED", nil, nil, true)
    end
    return true
end

function SoundAlerter:CheckWatchlist(unit)
    local profile = self.db1.profile
    local names, guilds = Sets(profile)
    if not state.active then return nil end
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return nil end
    local guid, byName = SA_Plates.UnitKey(unit)
    if not guid then return nil end
    local kind, name, guild = MatchUnit(names, guilds, guid, unit)
    if not kind then return nil end
    local now = GetTime()
    local last = watchAlertAt[guid]
    if last and now - last < WATCH_SPACING then return kind end
    if not self:IsAlertZoneAllowed() or self:IsQuiet() then return kind end

    if name == nil then
        name = SafeUnitName(unit)
        guild = Plain((GetGuildInfo(unit)))
    end
    self:Debug("Watchlist", "%s matched by %s (guild %s)", tostring(name), kind, tostring(guild))
    FireWatchAlert(self, profile, guid, name, guild, now)
    if profile.shareAlertsSend and not byName then self:ShareAlert("W", guid, 0, SafeUnitClass(unit), nil, name) end
    return kind
end

function SoundAlerter:PruneWatchlist(now)
    for guid, timestamp in pairs(watchAlertAt) do
        if now - timestamp > WATCH_SPACING * 2 then
            watchAlertAt[guid] = nil
        end
    end
    if matchCount > MATCH_LIMIT then
        wipe(matchKind)
        matchCount = 0
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
        self:Print("  /sa watch [guild] <name>, /sa unwatch [guild] <name>, or Ctrl-click a toast or Enemy Finder row")
        return
    end

    if command == "watch" then
        local text, added = SA_Watchlist.Add(profile[field], entry, isGuild)
        profile[field] = text
        if added then
            ReportChange(self, profile, entry, "added")
        else
            self:Print(entry .. " is already on the list or empty.")
        end
    else
        local text, removed = SA_Watchlist.Remove(profile[field], entry, isGuild)
        profile[field] = text
        if removed then
            ReportChange(self, profile, entry, "removed")
        else
            self:Print(entry .. " was not on the list.")
        end
    end
end
end
