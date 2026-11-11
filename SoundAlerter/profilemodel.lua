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

SA_ProfileCleanup.PASS = 7

SA_ProfileCleanup.DEAD_KEYS = {
    "objectiveAlertsEnabled", "ArenaPartner", "prowlhenemy", "vanishalert", "enemyinterrupts",
    "PresenceofMind", "lavaburst", "sayspell", "saptextself", "blindtext", "blindtextfriend",
    "flagRainbowBorder", "persistentTeamCache", "cspell", "showAdvancedFlag", "showAdvancedProximity",
    "learnedClasses", "learnedClassesEnabled", "learnedClassesMaxSize", "negativeCacheEnabled", "negativeCacheTTL",
    "combatTimer",
}

SA_ProfileCleanup.DEAD_RESOURCE_KEYS = {
    "energyTexture", "rageTexture", "healthTexture", "manaTexture",
    "energyLowColor", "rageLowColor", "manaLowColor",
    "lowEnergyThreshold", "lowRageThreshold", "lowManaThreshold",
    "showOverCapAlert", "showLowEnergyAlert", "showLowRageAlert", "showLowManaAlert",
    "smoothPower", "cpAnimations", "fullCPAnimation",
}

SA_ProfileCleanup.DEAD_GLOBAL_KEYS = { "nextProbe", "nextProbeWatch", "swingProbe", "recapProbe" }

SA_ProfileCleanup.DEAD_DR_CATEGORY_KEYS = { "opener", "cyclone" }

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
            local dr = profile.drTracker
            if type(dr) == "table" and type(dr.categories) == "table" then
                removed = removed + strip(dr.categories, SA_ProfileCleanup.DEAD_DR_CATEGORY_KEYS)
            end
        end
    end
    removed = removed + strip(saved.global, SA_ProfileCleanup.DEAD_GLOBAL_KEYS)
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

function Transfer.Pack(prefix, payload)
    local out = {}
    if not put(out, payload, 1) then return nil end
    local body = table.concat(out)
    return prefix .. body .. "|" .. checksum(body)
end

function Transfer.Unpack(prefix, text, foreign)
    if type(text) ~= "string" then return nil, "Paste an export text first." end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil, "Paste an export text first." end
    if #text > Transfer.MAX_LENGTH then return nil, "That text is too long to be an export." end
    local body, sum = text:match("^" .. prefix .. "(.*)|(%x+)$")
    if not body then return nil, foreign end
    if checksum(body) ~= sum then return nil, "The text is damaged or incomplete. Copy the whole export again." end
    local state = { nodes = 0 }
    local ok, payload = pcall(function()
        local value, stop = take(body, 1, state, 1)
        if stop ~= #body + 1 then error("trailing") end
        return value
    end)
    if not ok or type(payload) ~= "table" then return nil, "The export could not be read. No changes were made." end
    return payload
end

function Transfer.Encode(name, profile, defaults)
    return Transfer.Pack(Transfer.PREFIX, { n = name, p = slim(Transfer.Copy(profile), defaults or {}) })
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

Transfer.BLOCK_PREFIX = "SAT1:"

function Transfer.Decode(text, defaults)
    if type(text) == "string" and text:find("^%s*" .. Transfer.BLOCK_PREFIX) then
        return nil, "This is a Spell Tracker blocks text. Import it under Spell Tracker blocks below."
    end
    local payload, message = Transfer.Unpack(Transfer.PREFIX, text, "That is not a SoundAlerter profile export.")
    if not payload then return nil, message end
    if type(payload.p) ~= "table" then
        return nil, "The export could not be read. No changes were made."
    end
    local name = type(payload.n) == "string" and trim(payload.n) or ""
    if name == "" then name = "Imported" end
    return name:sub(1, SA_ProfileModel.NAME_LIMIT), Transfer.Sanitize(payload.p, defaults or {})
end
end
do
SA_TrackerBlocks = {}

local Blocks = SA_TrackerBlocks
local Transfer = SA_ProfileTransfer

Blocks.PREFIX = Transfer.BLOCK_PREFIX
Blocks.POOL = 20
Blocks.MAX_ICONS = 60
Blocks.POSITION_LIMIT = 4096
Blocks.CLASSES = { "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior", "Other" }
Blocks.DISPLAY_KEYS = {
    "showTimerText", "showBorderTimer", "showCooldownText", "showReadyText", "animQuality",
    "plateEnabled", "plateSize", "plateSpacing", "plateOffset", "plateFollowScale", "plateShowIdle", "plateMax", "plateFallback",
}
Blocks.DISPLAY_LABELS = {
    showTimerText = "Timer text", showBorderTimer = "Border timer", showCooldownText = "Cooldown text",
    showReadyText = "Ready text", animQuality = "Animation quality",
    plateEnabled = "Nameplate icons", plateSize = "Nameplate icon size", plateSpacing = "Nameplate spacing",
    plateOffset = "Nameplate distance", plateFollowScale = "Follow plate scale", plateShowIdle = "Nameplate idle icons",
    plateMax = "Nameplate icon count", plateFallback = "No plate",
}

local KNOWN_CLASS = {}
for _, class in ipairs(Blocks.CLASSES) do KNOWN_CLASS[class] = true end
local UNITS = { player = true, target = true }
local AURAS = { HELPFUL = true, HARMFUL = true }
local QUALITIES = { off = true, low = true, normal = true, high = true }
local FLAGS = { enabled = true, trackCooldown = false, showWhenInactive = false, onPlate = true }
local DISPLAY_RANGES = { plateSize = { 14, 40 }, plateSpacing = { 0, 10 }, plateOffset = { 0, 20 }, plateMax = { 1, 8 } }
local FALLBACKS = { screen = true, hide = true }

local function whole(value, low, high)
    return type(value) == "number" and value == value and value % 1 == 0 and value >= low and value <= high
end

local function within(value, low, high)
    return type(value) == "number" and value == value and value >= low and value <= high
end

local function classOfIcon(classOf, icon)
    local class = classOf(icon.spellID)
    return KNOWN_CLASS[class] and class or "Other"
end

function Blocks.Key(icon)
    return icon.spellID .. ":" .. (icon.unit or "player") .. ":" .. (icon.auraType or "HELPFUL")
end

local function hasLayout(icon)
    return within(icon.size, 16, 96) and within(icon.posX, -Blocks.POSITION_LIMIT, Blocks.POSITION_LIMIT)
        and within(icon.posY, -Blocks.POSITION_LIMIT, Blocks.POSITION_LIMIT)
end

function Blocks.CleanIcon(raw, withLayout)
    if type(raw) ~= "table" then return nil end
    local unit, aura = raw.unit or "player", raw.auraType or "HELPFUL"
    if not whole(raw.spellID, 1, 9999999) or not UNITS[unit] or not AURAS[aura] then return nil end
    local icon = { spellID = raw.spellID, unit = unit, auraType = aura }
    for key, default in pairs(FLAGS) do
        if type(raw[key]) == "boolean" then icon[key] = raw[key] else icon[key] = default end
    end
    if whole(raw.cooldownTextSize, 6, 32) then icon.cooldownTextSize = raw.cooldownTextSize end
    if withLayout and hasLayout(raw) then
        icon.size, icon.posX, icon.posY = raw.size, raw.posX, raw.posY
    end
    return icon
end

local function cleanDisplay(raw)
    if type(raw) ~= "table" then return nil end
    local display, any = {}, false
    for _, key in ipairs(Blocks.DISPLAY_KEYS) do
        local value = raw[key]
        local range = DISPLAY_RANGES[key]
        if key == "animQuality" then
            if QUALITIES[value] then display[key], any = value, true end
        elseif key == "plateFallback" then
            if FALLBACKS[value] then display[key], any = value, true end
        elseif range then
            if whole(value, range[1], range[2]) then display[key], any = value, true end
        elseif type(value) == "boolean" then
            display[key], any = value, true
        end
    end
    return any and display or nil
end

local function displayOf(tracker, defaults)
    local display = {}
    for _, key in ipairs(Blocks.DISPLAY_KEYS) do
        local value = tracker[key]
        if value == nil then value = defaults[key] end
        display[key] = value
    end
    return display
end

function Blocks.Build(tracker, classOf)
    local groups = {}
    for index, icon in ipairs(tracker.icons or {}) do
        local class = classOfIcon(classOf, icon)
        local group = groups[class]
        if not group then
            group = {}
            groups[class] = group
        end
        group[#group + 1] = index
    end
    local list = {}
    for _, class in ipairs(Blocks.CLASSES) do
        local group = groups[class]
        if group then list[#list + 1] = { key = "class:" .. class, class = class, indices = group, weight = #group } end
    end
    list[#list + 1] = { key = "display", weight = 2 }
    if #(tracker.icons or {}) > 0 then list[#list + 1] = { key = "layout", weight = 2 } end
    return list
end

function Blocks.Incoming(clean)
    local list = {}
    for _, class in ipairs(clean.order) do
        list[#list + 1] = { key = "class:" .. class, class = class, weight = #clean.classes[class] }
    end
    if clean.display then list[#list + 1] = { key = "display", weight = 2 } end
    if clean.withLayout then list[#list + 1] = { key = "layout", weight = 2 } end
    return list
end

function Blocks.Export(tracker, defaults, classOf, picked)
    local withLayout = picked.layout == true
    local payload = { v = 1, classes = {} }
    local any = false
    for _, icon in ipairs(tracker.icons or {}) do
        local class = classOfIcon(classOf, icon)
        if picked["class:" .. class] then
            local clean = Blocks.CleanIcon(icon, withLayout)
            if clean then
                local list = payload.classes[class]
                if not list then
                    list = {}
                    payload.classes[class] = list
                end
                list[#list + 1] = clean
                any = true
            end
        end
    end
    if picked.display then payload.display = displayOf(tracker, defaults or {}) end
    if withLayout and not any then
        local layout = {}
        for _, icon in ipairs(tracker.icons or {}) do
            local clean = Blocks.CleanIcon(icon, true)
            if clean and clean.size then
                layout[#layout + 1] = { spellID = clean.spellID, unit = clean.unit, auraType = clean.auraType, size = clean.size, posX = clean.posX, posY = clean.posY }
            end
        end
        if #layout > 0 then payload.layout = layout end
    end
    if withLayout then payload.withLayout = true end
    if not any and not payload.display and not payload.layout then return nil end
    return Transfer.Pack(Blocks.PREFIX, payload)
end

function Blocks.Decode(text)
    if type(text) == "string" and text:find("^%s*" .. Transfer.PREFIX) then
        return nil, "This is a full profile export. Import it with Import text under New profile."
    end
    local payload, message = Transfer.Unpack(Blocks.PREFIX, text, "That is not a Spell Tracker blocks text.")
    if not payload then return nil, message end
    local withLayout = payload.withLayout == true
    local clean = { classes = {}, order = {}, count = 0, dropped = 0, withLayout = withLayout }
    if type(payload.classes) == "table" then
        for _, class in ipairs(Blocks.CLASSES) do
            local list = payload.classes[class]
            if type(list) == "table" then
                local out = {}
                for index = 1, #list do
                    local icon = clean.count < Blocks.MAX_ICONS and Blocks.CleanIcon(list[index], withLayout)
                    if icon then
                        out[#out + 1] = icon
                        clean.count = clean.count + 1
                    else
                        clean.dropped = clean.dropped + 1
                    end
                end
                if #out > 0 then
                    clean.classes[class] = out
                    clean.order[#clean.order + 1] = class
                end
            end
        end
    end
    clean.display = cleanDisplay(payload.display)
    if withLayout and type(payload.layout) == "table" then
        local layout = {}
        for index = 1, math.min(#payload.layout, Blocks.MAX_ICONS) do
            local entry = Blocks.CleanIcon(payload.layout[index], true)
            if entry and entry.size then
                layout[#layout + 1] = entry
            else
                clean.dropped = clean.dropped + 1
            end
        end
        if #layout > 0 then clean.layout = layout end
    end
    if clean.withLayout and not clean.layout then
        local positioned = false
        for _, class in ipairs(clean.order) do
            for _, icon in ipairs(clean.classes[class]) do
                if icon.size then positioned = true end
            end
        end
        clean.withLayout = positioned
    end
    if #clean.order == 0 and not clean.display and not clean.layout then
        return nil, "The text holds nothing the Spell Tracker can use."
    end
    return clean
end

local function where(icon)
    return string.format("%dpx at %d, %d", icon.size or 0, math.floor((icon.posX or 0) + 0.5), math.floor((icon.posY or 0) + 0.5))
end

function Blocks.Describe(icon, withLayout)
    local parts = {
        icon.unit == "target" and "target" or "you",
        icon.auraType == "HARMFUL" and "debuff" or "buff",
    }
    if icon.trackCooldown then parts[#parts + 1] = "cooldown" end
    if icon.enabled == false then parts[#parts + 1] = "off" end
    if icon.showWhenInactive then parts[#parts + 1] = "always shown" end
    if withLayout and icon.size then parts[#parts + 1] = where(icon) end
    return table.concat(parts, " \194\183 ")
end

local function indexOf(icons)
    local index = {}
    for _, icon in ipairs(icons) do
        if icon.spellID then index[Blocks.Key(icon)] = icon end
    end
    return index
end

local function layoutPicked(clean, picked)
    return picked.layout == true and clean.withLayout == true
end

function Blocks.Diff(tracker, clean, picked, defaults)
    local rows = {}
    local index = indexOf(tracker.icons or {})
    local withLayout = layoutPicked(clean, picked)
    for _, class in ipairs(clean.order) do
        if picked["class:" .. class] then
            for _, icon in ipairs(clean.classes[class]) do
                local key = Blocks.Key(icon)
                local have = index[key]
                local incoming = Blocks.Describe(icon, withLayout and icon.size ~= nil)
                if not have then
                    rows[#rows + 1] = { id = "i:" .. key, kind = "new", class = class, spellID = icon.spellID, incoming = incoming }
                else
                    local mine = Blocks.Describe(have, withLayout and icon.size ~= nil)
                    if mine ~= incoming then
                        rows[#rows + 1] = { id = "i:" .. key, kind = "changed", class = class, spellID = icon.spellID, mine = mine, incoming = incoming }
                    end
                end
            end
        end
    end
    if picked.display and clean.display then
        for _, key in ipairs(Blocks.DISPLAY_KEYS) do
            local value = clean.display[key]
            if value ~= nil then
                local current = tracker[key]
                if current == nil then current = (defaults or {})[key] end
                if current ~= value then
                    rows[#rows + 1] = { id = "d:" .. key, kind = "changed", setting = key, mine = tostring(current), incoming = tostring(value) }
                end
            end
        end
    end
    if withLayout and clean.layout then
        for _, entry in ipairs(clean.layout) do
            local key = Blocks.Key(entry)
            local have = index[key]
            if not have then
                rows[#rows + 1] = { id = "l:" .. key, kind = "skip", spellID = entry.spellID, incoming = where(entry) }
            elseif not hasLayout(have) or where(have) ~= where(entry) then
                rows[#rows + 1] = { id = "l:" .. key, kind = "changed", spellID = entry.spellID, mine = hasLayout(have) and where(have) or "default spot", incoming = where(entry) }
            end
        end
    end
    return rows
end

local function copyIcon(icon)
    local copy = {}
    for key, value in pairs(icon) do copy[key] = value end
    return copy
end

local function settle(target, icon, withLayout)
    target.enabled, target.trackCooldown, target.showWhenInactive = icon.enabled, icon.trackCooldown, icon.showWhenInactive
    target.onPlate = icon.onPlate
    if icon.cooldownTextSize then target.cooldownTextSize = icon.cooldownTextSize end
    if withLayout and icon.size then
        target.size, target.posX, target.posY = icon.size, icon.posX, icon.posY
    end
end

local function fresh(icon, withLayout)
    local new = { spellID = icon.spellID, unit = icon.unit, auraType = icon.auraType }
    settle(new, icon, withLayout)
    return new
end

function Blocks.Apply(tracker, clean, picked, choices, replace, classOf, defaults)
    local icons = {}
    for index, icon in ipairs(tracker.icons or {}) do icons[index] = copyIcon(icon) end
    local display = {}
    local result = { added = 0, changed = 0, removed = 0, full = 0 }
    local withLayout = layoutPicked(clean, picked)
    choices = choices or {}
    local function take(id) return replace or choices[id] ~= "keep" end
    if replace then
        local drop = {}
        for _, class in ipairs(clean.order) do
            if picked["class:" .. class] then drop[class] = true end
        end
        local kept = {}
        for _, icon in ipairs(icons) do
            if drop[classOfIcon(classOf, icon)] then result.removed = result.removed + 1 else kept[#kept + 1] = icon end
        end
        icons = kept
    end
    local index = indexOf(icons)
    for _, class in ipairs(clean.order) do
        if picked["class:" .. class] then
            for _, icon in ipairs(clean.classes[class]) do
                local key = Blocks.Key(icon)
                if take("i:" .. key) then
                    local have = index[key]
                    if have then
                        local placed = withLayout and icon.size ~= nil
                        if Blocks.Describe(have, placed) ~= Blocks.Describe(icon, placed) then
                            settle(have, icon, withLayout)
                            result.changed = result.changed + 1
                        end
                    elseif #icons >= Blocks.POOL then
                        result.full = result.full + 1
                    else
                        local new = fresh(icon, withLayout)
                        icons[#icons + 1] = new
                        index[key] = new
                        result.added = result.added + 1
                    end
                end
            end
        end
    end
    if picked.display and clean.display then
        for _, key in ipairs(Blocks.DISPLAY_KEYS) do
            local value = clean.display[key]
            local current = tracker[key]
            if current == nil then current = (defaults or {})[key] end
            if value ~= nil and current ~= value and take("d:" .. key) then
                display[key] = value
                result.changed = result.changed + 1
            end
        end
    end
    if withLayout and clean.layout then
        for _, entry in ipairs(clean.layout) do
            local key = Blocks.Key(entry)
            local have = index[key]
            if have and take("l:" .. key) and (not hasLayout(have) or where(have) ~= where(entry)) then
                have.size, have.posX, have.posY = entry.size, entry.posX, entry.posY
                result.changed = result.changed + 1
            end
        end
    end
    return icons, display, result
end

function Blocks.ResultText(result, replace)
    local parts = {}
    if replace and result.removed > 0 then parts[#parts + 1] = result.removed .. " removed" end
    if result.added > 0 then parts[#parts + 1] = result.added .. " added" end
    if result.changed > 0 then parts[#parts + 1] = result.changed .. " changed" end
    if result.full > 0 then parts[#parts + 1] = result.full .. " not added (tracker full at " .. Blocks.POOL .. ")" end
    if #parts == 0 then return "Nothing changed" end
    return table.concat(parts, ", ")
end
end
