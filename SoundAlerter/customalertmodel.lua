SA_CustomModel = {}

local Model = SA_CustomModel

Model.INVALID = "Invalid Spell ID"
Model.NAME_LIMIT = 64

Model.EVENTS = {
    { "SPELL_CAST_SUCCESS", "Cast success" },
    { "SPELL_CAST_START", "Cast start" },
    { "SPELL_AURA_APPLIED", "Aura applied" },
    { "SPELL_AURA_REMOVED", "Aura removed" },
    { "SPELL_INTERRUPT", "Interrupt" },
    { "SPELL_SUMMON", "Summon" },
    { "SPELL_DAMAGE", "Damage" },
}

Model.UNFIRED = { SPELL_SUMMON = true, SPELL_DAMAGE = true }

Model.UNIT_ORDER = { "any", "player", "target", "focus", "mouseover", "party", "arena", "custom" }

function Model.Options(labels, order)
    local options = {}
    for _, key in ipairs(order) do
        options[#options + 1] = { key, labels[key] or tostring(key) }
    end
    return options
end

local function trim(text)
    return ((text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Model.NewAlert(name, everything)
    return {
        name = name,
        spellid = "",
        spellname = "",
        soundfilepath = name .. ".[ogg/mp3/wav]",
        chatAlert = false,
        chatalerttext = "",
        acceptSpellName = false,
        sourceuidfilter = "any",
        destuidfilter = "any",
        sourcecustomname = "",
        destcustomname = "",
        eventtype = {
            SPELL_CAST_SUCCESS = true,
            SPELL_CAST_START = false,
            SPELL_AURA_APPLIED = false,
            SPELL_AURA_REMOVED = false,
            SPELL_INTERRUPT = false,
            SPELL_SUMMON = false,
        },
        sourcetypefilter = everything,
        desttypefilter = everything,
        order = 0,
    }
end

function Model.Sorted(custom, into)
    local list = into or {}
    for index = #list, 1, -1 do list[index] = nil end
    for key in pairs(custom) do list[#list + 1] = key end
    table.sort(list, function(a, b)
        local left = (custom[a].name or a):lower()
        local right = (custom[b].name or b):lower()
        if left ~= right then return left < right end
        return a < b
    end)
    return list
end

function Model.Count(custom)
    local count = 0
    for _ in pairs(custom) do count = count + 1 end
    return count
end

function Model.Add(custom, name, everything)
    if custom[name] then return nil end
    local alert = Model.NewAlert(name, everything)
    custom[name] = alert
    return alert
end

function Model.Remove(custom, key)
    if custom[key] == nil then return false end
    custom[key] = nil
    return true
end

function Model.Rename(custom, key, value)
    local name = trim(value)
    if name == "" then return false, "The entry needs a name." end
    if #name > Model.NAME_LIMIT then return false, "Use at most " .. Model.NAME_LIMIT .. " characters." end
    if name == key then return true, nil, key end
    if custom[name] then return false, "same name already exists" end
    local alert = custom[key]
    if not alert then return false, "That alert no longer exists." end
    alert.name = name
    alert.order = 100
    custom[name] = alert
    custom[key] = nil
    return true, nil, name
end

function Model.IsSpellId(text)
    return type(text) == "string" and text:match("^%d+$") ~= nil
end

function Model.CommitSpellId(alert, value, lookup)
    local text = trim(value)
    if text == "" then
        alert.spellid = ""
        alert.spellname = ""
        alert.spellidNum, alert.spellidNumSrc = nil, nil
        return true
    end
    if not Model.IsSpellId(text) then
        return false, "Spell IDs are numbers only."
    end
    alert.spellid = text
    alert.spellidNum, alert.spellidNumSrc = nil, nil
    local name = lookup(tonumber(text))
    alert.spellname = name or Model.INVALID
    return true, nil, name ~= nil
end

function Model.SpellHint(alert)
    if alert.spellname == Model.INVALID then return "Invalid spell ID", "bad" end
    if alert.spellname and alert.spellname ~= "" and alert.spellid ~= "" then return "Spell: " .. alert.spellname, nil end
    return "Visible in the spell tooltip when tooltip spell IDs are on", nil
end

function Model.SetEvent(alert, event, on)
    alert.eventtype = alert.eventtype or {}
    alert.eventtype[event] = on and true or false
end

function Model.EventCount(alert)
    local count = 0
    for _, event in ipairs(Model.EVENTS) do
        if alert.eventtype and alert.eventtype[event[1]] then count = count + 1 end
    end
    return count
end

function Model.TracksAuras(alert)
    local events = alert.eventtype
    return events ~= nil and (events.SPELL_AURA_APPLIED or events.SPELL_AURA_REMOVED) and true or false
end

function Model.TouchesTracking(field)
    return field == "spellid" or field == "eventtype"
end

function Model.SoundPath(alert, folder)
    return folder .. (alert.soundfilepath or "")
end

function Model.SoundActive(alert)
    return not alert.chatAlert
end

function Model.CustomNameActive(alert, side)
    return alert[side .. "uidfilter"] == "custom"
end

function Model.Initials(alert)
    return ((alert.spellname and alert.spellname ~= "" and alert.spellname ~= Model.INVALID and alert.spellname) or alert.name or "?"):sub(1, 2):upper()
end

function Model.HeaderText(count)
    return count .. (count == 1 and " custom alert" or " custom alerts") .. ". Your own sound for any spell event."
end

function Model.EventTip(key, labels)
    return labels[key] or key
end

do
SA_CustomExport = {}

local CUSTOM_EVENT_ORDER = { "SPELL_CAST_SUCCESS", "SPELL_CAST_START", "SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED", "SPELL_INTERRUPT", "SPELL_SUMMON" }
local FS, ES = "\031", "\030"

function SA_CustomExport.Decode(str)
    if type(str) ~= "string" or str:sub(1, 1) ~= "@" or str:sub(-1) ~= "#" then
        return nil, "Import failed: not a valid export string."
    end
    local body = str:sub(2, -2)
    local ok, parsed = pcall(function()
        local result = {}
        if body == "" then return result end
        for entry in (body .. ES):gmatch("(.-)" .. ES) do
            local fields = {}
            for field in (entry .. FS):gmatch("(.-)" .. FS) do
                fields[#fields + 1] = field
            end
            if #fields ~= 15 then error("bad field count: " .. #fields) end
            local name, spellid, soundfilepath, chatAlert, chatalerttext, acceptSpellName, spellname, bits, sourceuidfilter, destuidfilter, sourcetypefilter, desttypefilter, sourcecustomname, destcustomname, order = unpack(fields)
            if name == "" then error("empty alert name") end
            local eventtype = {}
            for i, ev in ipairs(CUSTOM_EVENT_ORDER) do
                eventtype[ev] = (bits:sub(i, i) == "1")
            end
            result[name] = {
                name = name,
                spellid = spellid,
                soundfilepath = soundfilepath,
                chatAlert = (chatAlert == "1"),
                chatalerttext = chatalerttext,
                acceptSpellName = (acceptSpellName == "1"),
                spellname = spellname,
                eventtype = eventtype,
                sourceuidfilter = sourceuidfilter,
                destuidfilter = destuidfilter,
                sourcetypefilter = tonumber(sourcetypefilter) or COMBATLOG_FILTER_EVERYTHING,
                desttypefilter = tonumber(desttypefilter) or COMBATLOG_FILTER_EVERYTHING,
                sourcecustomname = sourcecustomname,
                destcustomname = destcustomname,
                order = tonumber(order) or 0,
            }
        end
        return result
    end)
    if not ok or not parsed then
        return nil, "Import failed: malformed data, no changes made."
    end
    return parsed
end

function SA_CustomExport.Encode(custom)
    if not custom or not next(custom) then return "@#" end
    local entries = {}
    for _, css in pairs(custom) do
        local bits = ""
        for _, ev in ipairs(CUSTOM_EVENT_ORDER) do
            bits = bits .. (css.eventtype[ev] and "1" or "0")
        end
        local fields = {
            css.name or "",
            tostring(css.spellid or "0"),
            css.soundfilepath or "",
            css.chatAlert and "1" or "0",
            css.chatalerttext or "",
            css.acceptSpellName and "1" or "0",
            css.spellname or "",
            bits,
            css.sourceuidfilter or "any",
            css.destuidfilter or "any",
            tostring(css.sourcetypefilter or COMBATLOG_FILTER_EVERYTHING),
            tostring(css.desttypefilter or COMBATLOG_FILTER_EVERYTHING),
            css.sourcecustomname or "",
            css.destcustomname or "",
            tostring(css.order or 0),
        }
        entries[#entries + 1] = table.concat(fields, FS)
    end
    return "@" .. table.concat(entries, ES) .. "#"
end
end
