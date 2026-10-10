SA_VoiceModel = {}

local Model = SA_VoiceModel

Model.EVENTS = { "Gained", "Faded", "Cast start", "Cast", "On you", "On friend", "On enemy", "CC faded", "Interrupts you" }

Model.EVENT_OF = {
    auraApplied = "Gained",
    auraRemoved = "Faded",
    castStart = "Cast start",
    castSuccess = "Cast",
    selfDebuff = "On you",
    friendCCs = "On friend",
    friendCCSuccess = "On friend",
    friendCCenemy = "On enemy",
    enemyDebuffs = "On enemy",
    enemyDebuffdown = "CC faded",
    enemyDebuffdownAP = "CC faded",
    interruptFriend = "Interrupts you",
}

Model.SILENCE_FLAG = {
    ["Gained"] = "aruaApplied",
    ["Faded"] = "auraRemoved",
    ["Cast start"] = "castStart",
    ["Cast"] = "castSuccess",
    ["On you"] = "dSelfDebuff",
    ["On friend"] = "dArenaPartner",
    ["On enemy"] = "dEnemyDebuff",
    ["CC faded"] = "dEnemyDebuffDown",
    ["Interrupts you"] = "interrupt",
}

Model.CLASS_ORDER = { "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior", "Races", "Other" }

local EVENT_INDEX = {}
for index, event in ipairs(Model.EVENTS) do EVENT_INDEX[event] = index end

local CLASS_INDEX = {}
for index, class in ipairs(Model.CLASS_ORDER) do CLASS_INDEX[class] = index end

local function sortedKeys(set)
    local list = {}
    for key in pairs(set) do list[#list + 1] = key end
    table.sort(list)
    return list
end

function Model.Build(spellList, meta)
    meta = meta or {}
    local keyInfo = {}
    for category, entries in pairs(spellList or {}) do
        local event = Model.EVENT_OF[category]
        if event then
            for spellID, key in pairs(entries) do
                local info = keyInfo[key]
                if not info then
                    info = { events = {}, lowestID = spellID }
                    keyInfo[key] = info
                end
                info.events[event] = true
                if spellID < info.lowestID then info.lowestID = spellID end
            end
        end
    end

    local spellsByID = {}
    for key, info in pairs(keyInfo) do
        local entry = meta[key]
        local class = entry and entry[1] or "Other"
        if not CLASS_INDEX[class] then class = "Other" end
        local name = entry and entry[2] or key
        local id = class .. "|" .. name
        local spell = spellsByID[id]
        if not spell then
            spell = { id = id, class = class, name = name, keySets = {}, eventKeys = {}, iconSpellID = info.lowestID }
            spellsByID[id] = spell
        end
        if info.lowestID < spell.iconSpellID then spell.iconSpellID = info.lowestID end
        spell.keySets[key] = true
        for event in pairs(info.events) do
            spell.eventKeys[event] = spell.eventKeys[event] or {}
            spell.eventKeys[event][key] = true
        end
    end

    local model = { classes = {}, byClass = {}, allKeys = {}, spells = {} }
    for _, class in ipairs(Model.CLASS_ORDER) do
        local group = { name = class, spells = {} }
        model.byClass[class] = group
    end

    local list = {}
    for _, spell in pairs(spellsByID) do list[#list + 1] = spell end
    table.sort(list, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.class < b.class
    end)

    for _, spell in ipairs(list) do
        spell.keys = sortedKeys(spell.keySets)
        spell.keySets = nil
        spell.events = {}
        for event, keys in pairs(spell.eventKeys) do
            spell.events[#spell.events + 1] = event
            spell.eventKeys[event] = sortedKeys(keys)
        end
        table.sort(spell.events, function(a, b) return EVENT_INDEX[a] < EVENT_INDEX[b] end)
        local group = model.byClass[spell.class]
        group.spells[#group.spells + 1] = spell
        model.spells[#model.spells + 1] = spell
        for _, key in ipairs(spell.keys) do model.allKeys[key] = true end
    end

    for _, class in ipairs(Model.CLASS_ORDER) do
        local group = model.byClass[class]
        if #group.spells > 0 then model.classes[#model.classes + 1] = group end
    end
    return model
end

function Model.ChipOn(db, spell, event)
    local keys = spell.eventKeys[event]
    if not keys then return false end
    for _, key in ipairs(keys) do
        if not db[key] then return false end
    end
    return true
end

function Model.SetChip(db, spell, event, value)
    local keys = spell.eventKeys[event]
    if not keys then return end
    for _, key in ipairs(keys) do db[key] = value and true or false end
end

function Model.Count(db, spells)
    local total, on = 0, 0
    for _, spell in ipairs(spells) do
        for _, event in ipairs(spell.events) do
            total = total + 1
            if Model.ChipOn(db, spell, event) then on = on + 1 end
        end
    end
    return on, total
end

function Model.SetAll(db, spells, value)
    for _, spell in ipairs(spells) do
        for _, event in ipairs(spell.events) do Model.SetChip(db, spell, event, value) end
    end
end

function Model.Matches(spell, query)
    if not query or query == "" then return true end
    if spell.name:lower():find(query, 1, true) then return true end
    for _, key in ipairs(spell.keys) do
        if key:find(query, 1, true) then return true end
    end
    return false
end

function Model.Snapshot(db, model)
    local snapshot = {}
    for key in pairs(model.allKeys) do snapshot[key] = db[key] and true or false end
    return snapshot
end

function Model.Restore(db, snapshot)
    for key, value in pairs(snapshot) do db[key] = value end
end

local function setEvents(db, model, events)
    local wanted = {}
    for _, event in ipairs(events) do wanted[event] = true end
    local keep = {}
    for _, spell in ipairs(model.spells) do
        for _, event in ipairs(spell.events) do
            if wanted[event] then
                for _, key in ipairs(spell.eventKeys[event]) do keep[key] = true end
            end
        end
    end
    for key in pairs(model.allKeys) do db[key] = keep[key] and true or false end
end

Model.PRESETS = {
    { id = "arena", name = "Arena", note = "everything on", apply = function(db, model)
        for key in pairs(model.allKeys) do db[key] = true end
    end },
    { id = "battleground", name = "Battleground", note = "everything except heals, rezzes and pet summons", apply = function(db, model)
        for key in pairs(model.allKeys) do db[key] = true end
        for _, key in ipairs({ "bigheal", "resurrection", "summonpet", "revivepet", "rebirth" }) do
            if model.allKeys[key] then db[key] = false end
        end
    end },
    { id = "hitsme", name = "Only what hits me", note = "On you and Interrupts you", apply = function(db, model)
        setEvents(db, model, { "On you", "Interrupts you" })
    end },
    { id = "bigcooldowns", name = "Big cooldowns only", note = "Gained and Faded buffs", apply = function(db, model)
        setEvents(db, model, { "Gained", "Faded" })
    end },
    { id = "silence", name = "Silence all", note = "everything off", apply = function(db, model)
        for key in pairs(model.allKeys) do db[key] = false end
    end },
}

function Model.ApplyPreset(db, model, presetID)
    for _, preset in ipairs(Model.PRESETS) do
        if preset.id == presetID then
            preset.apply(db, model)
            return true
        end
    end
    return false
end
