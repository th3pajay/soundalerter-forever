SA_ProfileModel = {}

local Model = SA_ProfileModel

Model.NAME_LIMIT = 48
Model.ARM_SECONDS = 4

local function trim(text)
    return ((text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Model.Clean(name)
    return trim(name)
end

function Model.Validate(name, existing)
    local clean = trim(name)
    if clean == "" then
        return false, "Type a name for the new profile."
    end
    if #clean > Model.NAME_LIMIT then
        return false, "Use at most " .. Model.NAME_LIMIT .. " characters."
    end
    if existing[clean] then
        return false, "That profile already exists. Use it from the list."
    end
    return true, nil, clean
end

function Model.NewCharacterDefault(saved)
    if type(saved) ~= "table" then return nil end
    local name = saved.newCharacterProfile
    if type(name) ~= "string" or name == "" then return nil end
    if type(saved.profiles) ~= "table" or type(saved.profiles[name]) ~= "table" then return nil end
    return name
end

function Model.SetNewCharacterDefault(saved, name)
    if type(saved) ~= "table" then return end
    saved.newCharacterProfile = name
end

function Model.ForgetDefault(saved, deleted)
    if type(saved) == "table" and saved.newCharacterProfile == deleted then
        saved.newCharacterProfile = nil
    end
end

function Model.Sorted(names, into)
    local list = into or {}
    for index = #list, 1, -1 do list[index] = nil end
    for _, name in ipairs(names) do list[#list + 1] = name end
    table.sort(list, function(a, b)
        local left, right = a:lower(), b:lower()
        if left ~= right then return left < right end
        return a < b
    end)
    return list
end

function Model.Set(names)
    local set = {}
    for _, name in ipairs(names) do set[name] = true end
    return set
end

local function effective(profile, defaults, key)
    local value = profile[key]
    if value == nil then value = defaults[key] end
    return value and true or false
end

function Model.Summary(profile, defaults, voiceModel, into)
    local summary = into or {}
    local custom = 0
    if type(profile.custom) == "table" then
        for _ in pairs(profile.custom) do custom = custom + 1 end
    end
    local on, total = 0, 0
    for _, spell in ipairs(voiceModel.spells) do
        for _, event in ipairs(spell.events) do
            total = total + 1
            local all = true
            for _, key in ipairs(spell.eventKeys[event]) do
                if not effective(profile, defaults, key) then
                    all = false
                    break
                end
            end
            if all then on = on + 1 end
        end
    end
    summary.custom, summary.on, summary.total = custom, on, total
    return summary
end

function Model.SummaryText(summary)
    return summary.custom .. (summary.custom == 1 and " custom alert" or " custom alerts") .. " \194\183 " .. summary.on .. " of " .. summary.total .. " spell alerts on"
end

function Model.CanDelete(name, current)
    return name ~= current
end

function Model.HeaderText(current, count)
    return "Active: " .. current .. " \194\183 " .. count .. (count == 1 and " profile" or " profiles")
end

Model.MODULES = {
    { "Proximity", { { "proximityEnabled" } } },
    { "Watchlist", { { "watchlistEnabled" } } },
    { "Battlegrounds", { { "battlegroundAlertsEnabled" } } },
    { "Toasts", { { "proximityToasts", "enabled" } } },
    { "Notices", { { "notices", "enabled" } } },
    { "Casting bars", { { "castingBars", "player", "enabled" }, { "castingBars", "target", "enabled" }, { "castingBars", "focus", "enabled" } } },
    { "Resource bars", { { "resourceBar", "energyEnabled" }, { "resourceBar", "rageEnabled" }, { "resourceBar", "healthEnabled" }, { "resourceBar", "manaEnabled" }, { "resourceBar", "comboEnabled" } } },
    { "Combat timer", { { "combatTimer", "enabled" } } },
    { "Cast feed", { { "castFeed", "enabled" } } },
    { "Statistics", { { "statistics", "enabled" } } },
}

local function walk(root, path)
    local value = root
    for index = 1, #path do
        if type(value) ~= "table" then return nil end
        value = value[path[index]]
    end
    return value
end

local function pathOn(profile, defaults, path)
    local value = walk(profile, path)
    if value == nil then value = walk(defaults, path) end
    return value and true or false
end

function Model.Overview(profile, defaults, into)
    local overview = into or {}
    local modules = overview.modules or {}
    local count = 0
    for index, module in ipairs(Model.MODULES) do
        local on = false
        for _, path in ipairs(module[2]) do
            if pathOn(profile, defaults, path) then
                on = true
                break
            end
        end
        modules[index] = on
        if on then count = count + 1 end
    end
    overview.modules, overview.moduleCount = modules, count

    local zones = overview.zoneList or {}
    for index = #zones, 1, -1 do zones[index] = nil end
    if effective(profile, defaults, "all") then
        zones[1] = "Everywhere"
    else
        if effective(profile, defaults, "arena") then zones[#zones + 1] = "Arena" end
        if effective(profile, defaults, "battleground") then zones[#zones + 1] = "Battlegrounds" end
        if effective(profile, defaults, "field") then zones[#zones + 1] = "World" end
    end
    overview.zoneList = zones
    overview.scope = effective(profile, defaults, "enemyinrange") and "Target, focus and nearby enemies" or "Target and focus"
    overview.zones = #zones > 0 and table.concat(zones, ", ") or "No zones"
    return overview
end

function Model.OverviewText(overview)
    return overview.scope .. " \194\183 " .. overview.zones
end

local function shortName(key)
    return (key:match("^(.-) %- ") or key)
end

function Model.Characters(keys, into)
    local map = into or {}
    for _, list in pairs(map) do
        for index = #list, 1, -1 do list[index] = nil end
    end
    if type(keys) == "table" then
        for key, name in pairs(keys) do
            if type(key) == "string" and type(name) == "string" then
                local list = map[name]
                if not list then
                    list = {}
                    map[name] = list
                end
                list[#list + 1] = shortName(key)
            end
        end
    end
    for name, list in pairs(map) do
        if #list == 0 then
            map[name] = nil
        else
            table.sort(list)
        end
    end
    return map
end

Model.CHARACTER_LIMIT = 3

function Model.CharactersText(list)
    if not list or #list == 0 then return "No characters use it" end
    local shown = math.min(#list, Model.CHARACTER_LIMIT)
    local text = "Used by " .. table.concat(list, ", ", 1, shown)
    if #list > shown then text = text .. " +" .. (#list - shown) end
    return text
end

function Model.CountText(list)
    local count = list and #list or 0
    if count == 0 then return "no characters" end
    return count .. (count == 1 and " character" or " characters")
end

local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"

function Model.Initials(name)
    local letters = ""
    local words = 0
    for word in tostring(name):gmatch("%S+") do
        words = words + 1
        letters = letters .. word:match(UTF8_CHAR)
        if words == 2 then break end
    end
    if words == 1 then
        local second = tostring(name):match(UTF8_CHAR .. "(" .. UTF8_CHAR .. ")")
        if second then letters = letters .. second end
    end
    return letters:upper()
end

local function channel(p, q, t)
    if t < 0 then t = t + 1 elseif t > 1 then t = t - 1 end
    if t < 1 / 6 then return p + (q - p) * 6 * t end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
    return p
end

function Model.Color(name)
    local hash = 7
    for index = 1, #name do
        hash = (hash * 31 + name:byte(index)) % 4294967296
    end
    local hue = (hash % 360) / 360
    local saturation, lightness = 0.55, 0.45
    local q = lightness + saturation - lightness * saturation
    local p = 2 * lightness - q
    return channel(p, q, hue + 1 / 3), channel(p, q, hue), channel(p, q, hue - 1 / 3)
end

function Model.UniqueName(base, existing, suffix)
    local clean = trim(base)
    if clean == "" then clean = "Profile" end
    if not suffix and not existing[clean] and #clean <= Model.NAME_LIMIT then return clean end
    suffix = suffix or ""
    local stem = clean:sub(1, Model.NAME_LIMIT - #suffix - 4)
    local number = suffix == "" and 2 or 1
    local candidate = stem .. suffix .. (number > 1 and (" " .. number) or "")
    while existing[candidate] do
        number = number + 1
        candidate = stem .. suffix .. " " .. number
    end
    return candidate
end

function Model.Rename(saved, old, new)
    local profiles = type(saved) == "table" and saved.profiles
    if type(profiles) ~= "table" or type(profiles[old]) ~= "table" or profiles[new] ~= nil or old == new then return false end
    profiles[new], profiles[old] = profiles[old], nil
    if type(saved.profileKeys) == "table" then
        for key, name in pairs(saved.profileKeys) do
            if name == old then saved.profileKeys[key] = new end
        end
    end
    if saved.newCharacterProfile == old then saved.newCharacterProfile = new end
    return true
end

do
SA_ProfileCleanup = {}

SA_ProfileCleanup.PASS = 4

SA_ProfileCleanup.DEAD_KEYS = {
    "objectiveAlertsEnabled", "ArenaPartner", "prowlhenemy", "vanishalert", "enemyinterrupts",
    "PresenceofMind", "lavaburst", "sayspell", "saptextself", "blindtext", "blindtextfriend",
    "flagRainbowBorder", "persistentTeamCache", "cspell", "showAdvancedFlag", "showAdvancedProximity",
    "learnedClasses", "learnedClassesEnabled", "learnedClassesMaxSize", "negativeCacheEnabled", "negativeCacheTTL",
}

SA_ProfileCleanup.DEAD_RESOURCE_KEYS = {
    "energyTexture", "rageTexture", "healthTexture", "manaTexture",
    "energyLowColor", "rageLowColor", "manaLowColor",
    "lowEnergyThreshold", "lowRageThreshold", "lowManaThreshold",
    "showOverCapAlert", "showLowEnergyAlert", "showLowRageAlert", "showLowManaAlert",
    "smoothPower", "cpAnimations", "fullCPAnimation",
}

SA_ProfileCleanup.COPIED_KEYS = {
    { from = "friendcountered", to = "lockout" },
}

local function copyAcross(profile)
    for _, rule in ipairs(SA_ProfileCleanup.COPIED_KEYS) do
        if profile[rule.to] == nil and profile[rule.from] ~= nil then profile[rule.to] = profile[rule.from] end
    end
end

local function strip(target, keys)
    local removed = 0
    for _, key in ipairs(keys) do
        if target[key] ~= nil then
            target[key] = nil
            removed = removed + 1
        end
    end
    return removed
end

function SA_ProfileCleanup.Run(saved)
    if type(saved) ~= "table" or type(saved.profiles) ~= "table" then return 0 end
    saved.global = saved.global or {}
    if saved.global.deadKeysPass == SA_ProfileCleanup.PASS then return 0 end

    local removed = 0
    for _, profile in pairs(saved.profiles) do
        if type(profile) == "table" then
            copyAcross(profile)
            removed = removed + strip(profile, SA_ProfileCleanup.DEAD_KEYS)
            if type(profile.resourceBar) == "table" then
                removed = removed + strip(profile.resourceBar, SA_ProfileCleanup.DEAD_RESOURCE_KEYS)
            end
        end
    end
    saved.global.deadKeysRemoved = nil
    saved.global.deadKeysPass = SA_ProfileCleanup.PASS
    return removed
end
end

do
SA_ProfileTransfer = {}

local Transfer = SA_ProfileTransfer

Transfer.PREFIX = "SAP1:"
Transfer.MAX_LENGTH = 200000
Transfer.MAX_DEPTH = 8
Transfer.MAX_NODES = 40000
Transfer.VOLATILE = { statistics = true, persistentClassCache = true }

local function finite(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

local function storable(key, value)
    local keyKind, valueKind = type(key), type(value)
    if keyKind ~= "string" and keyKind ~= "number" then return false end
    if keyKind == "number" and not finite(key) then return false end
    if valueKind == "number" then return finite(value) end
    return valueKind == "string" or valueKind == "boolean" or valueKind == "table"
end

local function put(out, value, depth)
    local kind = type(value)
    if kind == "table" then
        if depth > Transfer.MAX_DEPTH then return false end
        out[#out + 1] = "{"
        for key, item in pairs(value) do
            if storable(key, item) then
                if not put(out, key, depth + 1) or not put(out, item, depth + 1) then return false end
            end
        end
        out[#out + 1] = "}"
    elseif kind == "string" then
        out[#out + 1] = "s" .. #value .. ":" .. value
    elseif kind == "number" then
        out[#out + 1] = "n" .. string.format("%.14g", value) .. ";"
    else
        out[#out + 1] = value and "T" or "F"
    end
    return true
end

local function take(text, pos, state, depth)
    state.nodes = state.nodes + 1
    if state.nodes > Transfer.MAX_NODES or depth > Transfer.MAX_DEPTH then error("limit") end
    local tag = text:sub(pos, pos)
    if tag == "T" then return true, pos + 1 end
    if tag == "F" then return false, pos + 1 end
    if tag == "n" then
        local stop = text:find(";", pos + 1, true)
        local number = stop and tonumber(text:sub(pos + 1, stop - 1))
        if not number or not finite(number) then error("number") end
        return number, stop + 1
    end
    if tag == "s" then
        local colon = text:find(":", pos + 1, true)
        local length = colon and tonumber(text:sub(pos + 1, colon - 1))
        if not length or length < 0 or length % 1 ~= 0 or colon + length > #text then error("string") end
        return text:sub(colon + 1, colon + length), colon + length + 1
    end
    if tag == "{" then
        local result = {}
        pos = pos + 1
        while text:sub(pos, pos) ~= "}" do
            if pos > #text then error("table") end
            local key, value
            key, pos = take(text, pos, state, depth + 1)
            if type(key) ~= "string" and type(key) ~= "number" then error("key") end
            value, pos = take(text, pos, state, depth + 1)
            result[key] = value
        end
        return result, pos + 1
    end
    error("tag")
end

local function checksum(body)
    local low, high = 1, 0
    for index = 1, #body do
        low = (low + body:byte(index)) % 65521
        high = (high + low) % 65521
    end
    return string.format("%x", high * 65536 + low)
end

local function copy(value, depth)
    if type(value) ~= "table" then return value end
    if depth > Transfer.MAX_DEPTH then return nil end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item, depth + 1) end
    return result
end

function Transfer.Copy(profile)
    local result = {}
    for key, value in pairs(profile) do
        if not Transfer.VOLATILE[key] then result[key] = copy(value, 1) end
    end
    return result
end

local function slim(target, defaults)
    for key, value in pairs(target) do
        local fallback = defaults[key]
        if type(value) == "table" then
            if type(fallback) == "table" then
                slim(value, fallback)
                if next(value) == nil then target[key] = nil end
            end
        elseif value == fallback then
            target[key] = nil
        end
    end
    return target
end

function Transfer.Slim(target, defaults)
    return slim(target, defaults or {})
end

function Transfer.Duplicate(saved, source, target, defaults)
    local profiles = type(saved) == "table" and saved.profiles
    if type(profiles) ~= "table" or type(profiles[source]) ~= "table" or profiles[target] ~= nil then return false end
    profiles[target] = slim(Transfer.Copy(profiles[source]), defaults or {})
    return true
end

function Transfer.Encode(name, profile, defaults)
    local out = {}
    local payload = { n = name, p = slim(Transfer.Copy(profile), defaults or {}) }
    if not put(out, payload, 1) then return nil end
    local body = table.concat(out)
    return Transfer.PREFIX .. body .. "|" .. checksum(body)
end

function Transfer.Sanitize(profile, defaults)
    local clean = {}
    for key, value in pairs(profile) do
        if type(key) == "string" and not Transfer.VOLATILE[key] then
            local expected = defaults[key]
            if expected ~= nil and type(expected) == type(value) then clean[key] = value end
        end
    end
    return clean
end

function Transfer.Decode(text, defaults)
    if type(text) ~= "string" then return nil, "Paste an export text first." end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil, "Paste an export text first." end
    if #text > Transfer.MAX_LENGTH then return nil, "That text is too long to be a profile export." end
    local body, sum = text:match("^" .. Transfer.PREFIX .. "(.*)|(%x+)$")
    if not body then return nil, "That is not a SoundAlerter profile export." end
    if checksum(body) ~= sum then return nil, "The text is damaged or incomplete. Copy the whole export again." end
    local state = { nodes = 0 }
    local ok, payload = pcall(function()
        local value, stop = take(body, 1, state, 1)
        if stop ~= #body + 1 then error("trailing") end
        return value
    end)
    if not ok or type(payload) ~= "table" or type(payload.p) ~= "table" then
        return nil, "The export could not be read. No changes were made."
    end
    local name = type(payload.n) == "string" and trim(payload.n) or ""
    if name == "" then name = "Imported" end
    return name:sub(1, SA_ProfileModel.NAME_LIMIT), Transfer.Sanitize(payload.p, defaults or {})
end
end
