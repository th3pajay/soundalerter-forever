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
