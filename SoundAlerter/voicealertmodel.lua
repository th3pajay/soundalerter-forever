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

Model.EVENT_SOUND = {
    ["Interrupts you"] = "lockout",
}

function Model.SoundKeys(event, keys)
    local sound = Model.EVENT_SOUND[event]
    if sound then return { sound } end
    return keys
end

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

local shared = {}

function Model.Shared(spellList, meta)
    if shared.model == nil or shared.list ~= spellList or shared.meta ~= meta then
        shared.list, shared.meta = spellList, meta
        shared.model = Model.Build(spellList, meta)
    end
    return shared.model
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

Model.ALL = "All"

local single = {}

function Model.Shown(spell, filter)
    if filter == nil or filter == Model.ALL then return spell.events end
    if not spell.eventKeys[filter] then return {} end
    single[filter] = single[filter] or { filter }
    return single[filter]
end

function Model.EventsIn(spells)
    local present = {}
    for _, spell in ipairs(spells) do
        for _, event in ipairs(spell.events) do present[event] = true end
    end
    local list = { Model.ALL }
    for _, event in ipairs(Model.EVENTS) do
        if present[event] then list[#list + 1] = event end
    end
    return list
end

function Model.ByEvent(spells, filter)
    if filter == nil or filter == Model.ALL then return spells end
    local list = {}
    for _, spell in ipairs(spells) do
        if spell.eventKeys[filter] then list[#list + 1] = spell end
    end
    return list
end

function Model.TileState(db, spell, filter, silenced)
    local on, live = 0, 0
    for _, event in ipairs(Model.Shown(spell, filter)) do
        if not (silenced and silenced[event]) then
            live = live + 1
            if Model.ChipOn(db, spell, event) then on = on + 1 end
        end
    end
    if live == 0 then return "muted" end
    if on == live then return "on" end
    if on == 0 then return "off" end
    return "some"
end

function Model.ToggleTile(db, spell, filter, silenced)
    local state = Model.TileState(db, spell, filter, silenced)
    if state == "muted" then return nil end
    local value = state ~= "on"
    local first
    for _, event in ipairs(Model.Shown(spell, filter)) do
        if not (silenced and silenced[event]) then
            Model.SetChip(db, spell, event, value)
            first = first or event
        end
    end
    return value, first
end

function Model.Count(db, spells, filter)
    local total, on = 0, 0
    for _, spell in ipairs(spells) do
        for _, event in ipairs(Model.Shown(spell, filter)) do
            total = total + 1
            if Model.ChipOn(db, spell, event) then on = on + 1 end
        end
    end
    return on, total
end

function Model.SetAll(db, spells, value, filter)
    for _, spell in ipairs(spells) do
        for _, event in ipairs(Model.Shown(spell, filter)) do Model.SetChip(db, spell, event, value) end
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

Model.SILENCE_ROWS = {
    { key = "aruaApplied", label = "Buff applied", hint = "Mutes every alert when an enemy gains a buff." },
    { key = "auraRemoved", label = "Buff removed", hint = "Mutes every alert when an enemy buff ends." },
    { key = "castStart", label = "Spell casting", hint = "Mutes every alert when an enemy starts a cast." },
    { key = "castSuccess", label = "Enemy cooldowns", hint = "Mutes every alert for enemy cooldown abilities." },
    { key = "chatalerts", label = "Chat alerts", hint = "Mutes every chat announcement." },
    { key = "interrupt", label = "Interrupts", hint = "Mutes alerts for interrupted friendly spells." },
    { key = "dArenaPartner", label = "Arena partner CC", hint = "Mutes alerts when your arena partner is crowd controlled." },
    { key = "dSelfDebuff", label = "Debuffs on you", hint = "Mutes alerts when you are debuffed or crowd controlled." },
    { key = "dEnemyDebuff", label = "Enemy debuffs", hint = "Mutes alerts for debuffs and crowd control on enemies." },
    { key = "dEnemyDebuffDown", label = "Enemy debuff expired", hint = "Mutes alerts when a debuff or crowd control on an enemy ends." },
}

Model.ARENA_ROWS = {
    { key = "class", label = "Call the class that trinkets", hint = "Says the class when an enemy trinkets in arena.", preview = "arenaClass" },
    { key = "drinking", label = "Drinking", hint = "Says it when an enemy drinks in arena.", preview = "drinking" },
}

Model.INTERRUPT_ROWS = {
    { key = "interruptFocusVoice", label = "Own sound for focus", hint = "Plays focusinterrupted for focus interrupts." },
    { key = "interruptReadyVoice", label = "Say when interrupt is ready", hint = "Estimated from the spell's usual cooldown." },
}

Model.LOSS_MASTER = { key = "lossOfControlVoice", label = "Enable", hint = "Speaks the control effect that hits you." }

Model.LOSS_ROWS = {
    { key = "lossOfControlDedupe", label = "Skip if a spell alert just spoke" },
    { key = "lossOfControlStun", label = "Stun" },
    { key = "lossOfControlFear", label = "Fear" },
    { key = "lossOfControlRoot", label = "Root" },
    { key = "lossOfControlSilence", label = "Silence" },
    { key = "lossOfControlDisarm", label = "Disarm" },
    { key = "lossOfControlIncapacitate", label = "Incapacitate" },
    { key = "lossOfControlInterrupt", label = "Spell lockout" },
}

Model.INTERRUPT_MIN = { key = "interruptMinCast", label = "Minimum cast time", hint = "Ignore interrupts of shorter casts. 0 announces all.", min = 0, max = 3, step = 0.1, unit = " s" }
Model.INTERRUPT_PETS = { key = "interruptPets", label = "Count pet interrupts" }
Model.ENGINE_ROW = { key = "engineAuraSounds", label = "Let the game play debuff alerts", hint = "Experimental. Covers you and an enemy target or focus. Skips Statistics. /sa aurasound tests it." }

Model.CHANNELS = {
    { key = "SAY", label = "Say" },
    { key = "PARTY", label = "Party" },
    { key = "RAID", label = "Raid" },
    { key = "BATTLEGROUND", label = "Battleground" },
    { key = "NONE", label = "None (chat alerts off)" },
}

Model.CHAT_EVENTS = {
    { key = "stealthenemy", label = "Stealth on enemy", spell = 1784 },
    { key = "prowlenemy", label = "Prowl on enemy", spell = 5215 },
    { key = "vanishenemy", label = "Vanish", spell = 1856 },
    { key = "blindenemy", label = "Blind on enemy", spell = 2094 },
    { key = "blindselffriend", label = "Blind on you or a friend", spell = 2094 },
    { key = "hexenemy", label = "Hex on enemy", spell = 450600 },
    { key = "hexselffriend", label = "Hex on you or a friend", spell = 450600 },
    { key = "fearenemy", label = "Fear on enemy", spell = 5484 },
    { key = "fearselffriend", label = "Fear on you or a friend", spell = 5484 },
    { key = "sapenemy", label = "Sap on enemy", spell = 6770 },
    { key = "polyenemy", label = "Polymorph", spell = 118 },
    { key = "bubbleenemy", label = "Divine Shield", spell = 642 },
    { key = "trinketalert", label = "PvP trinket", spell = 1259718 },
    { key = "interruptenemy", label = "You interrupt an enemy" },
    { key = "interruptemote", label = "Roar when you interrupt" },
    { key = "interruptself", label = "An enemy interrupts you" },
    { key = "chatdownself", label = "Enemy debuff down (from you)" },
    { key = "chatdownfriend", label = "Enemy debuff down (from a friend)" },
    { key = "chatauraApplied", label = "Enemy defensives and buffs" },
    { key = "chatauraRemoved", label = "Enemy defensives expired" },
    { key = "chatcastStart", label = "Enemy cast start" },
}

Model.CHAT_FILTERS = {
    { key = "stealthTF", label = "Stealth: ignore target and focus", requires = "stealthenemy" },
    { key = "prowlTF", label = "Prowl: ignore target and focus", requires = "prowlenemy" },
    { key = "vanishTF", label = "Vanish: ignore target and focus", requires = "vanishenemy" },
}

Model.CHAT_TARGET_ONLY = { key = "caonlyTF", label = "Target and focus only", hint = "Announce only when your target or focus is the source." }

Model.CHAT_TEXTS = {
    { key = "enemychat", label = "To enemy", hint = "#spell# up on #enemy# reads [Blind] up on Enemyname." },
    { key = "friendchat", label = "From enemy to friend", hint = "#enemy# casted #spell# on #friend#." },
    { key = "selfchat", label = "From enemy to you", hint = "#enemy# casted #spell# on me!" },
    { key = "enemybuffchat", label = "Enemy buffs and cooldowns", hint = "#enemy# casted #spell#." },
    { key = "auraRemovedChat", label = "Enemy defensives expired", hint = "#spell# wore off #enemy#." },
    { key = "castStartChat", label = "Enemy cast start", hint = "#enemy# is casting #spell#." },
    { key = "InterruptEnemyText", label = "You interrupt an enemy", hint = "Also knows #interruptedspellname#.", requires = "interruptenemy" },
    { key = "InterruptSelfText", label = "An enemy interrupts you", hint = "Also knows #interruptedspellname#.", requires = "interruptself" },
    { key = "sapselftext", label = "Sap on you", hint = "Avoid #enemy#: the sapper is unknown while stealthed.", requires = "sapenemy" },
    { key = "sapfriendtext", label = "Sap on a friend", hint = "Avoid #enemy#: the sapper is unknown while stealthed.", requires = "sapenemy" },
    { key = "trinketalerttext", label = "PvP trinket", hint = "#enemy# casted #spell#!", requires = "trinketalert" },
}

Model.CHAT_SAMPLE = {
    enemy = "Cutthroat", target = "Starmistx", friend = "Starmistx", spell = "[Polymorph]",
    interruptedspellname = "[Polymorph]", interruptedspell = "[Polymorph]",
}

Model.CHAT_PREVIEW = {
    { "To enemy", "enemychat" },
    { "Enemy to friend", "friendchat" },
    { "Enemy to you", "selfchat" },
    { "Enemy cooldown", "enemybuffchat" },
    { "Defensive expired", "auraRemovedChat" },
    { "Cast start", "castStartChat" },
    { "You interrupt", "InterruptEnemyText" },
    { "You are interrupted", "InterruptSelfText" },
}

function Model.ChatPreview(db, expand)
    local lines = {}
    for _, entry in ipairs(Model.CHAT_PREVIEW) do
        local text = expand(db[entry[2]], Model.CHAT_SAMPLE)
        if text ~= "" then lines[#lines + 1] = { entry[1], text } end
    end
    return lines
end

function Model.ChatEventCount(db)
    local on = 0
    for _, row in ipairs(Model.CHAT_EVENTS) do
        if db[row.key] then on = on + 1 end
    end
    return on, #Model.CHAT_EVENTS
end

function Model.Tally(db, model)
    local tally = { on = 0, total = 0, byClass = {} }
    for _, group in ipairs(model.classes) do
        local on, total = Model.Count(db, group.spells)
        tally.byClass[group.name] = { on = on, total = total }
        tally.on = tally.on + on
        tally.total = tally.total + total
    end
    return tally
end

function Model.SilencedCount(db)
    local count = 0
    for _, row in ipairs(Model.SILENCE_ROWS) do
        if row.key ~= "chatalerts" and db[row.key] then count = count + 1 end
    end
    return count
end

function Model.Filter(model, class, query)
    if query and query ~= "" then
        local hits = {}
        for _, spell in ipairs(model.spells) do
            if Model.Matches(spell, query) then hits[#hits + 1] = spell end
        end
        return hits
    end
    local group = model.byClass[class]
    return group and group.spells or {}
end

function Model.ChangedSpells(db, model, snapshot)
    local changed = {}
    for _, spell in ipairs(model.spells) do
        for _, key in ipairs(spell.keys) do
            if (db[key] and true or false) ~= snapshot[key] then
                changed[spell.id] = true
                break
            end
        end
    end
    return changed
end

function Model.Normalize(query)
    return ((query or ""):lower():gsub("^%s+", ""):gsub("%s+$", ""))
end

local function copyValue(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = copyValue(item) end
    return copy
end

function Model.ResetKeys(model)
    local keys = {}
    local function add(key) keys[#keys + 1] = key end
    for key in pairs(model.allKeys) do add(key) end
    for _, row in ipairs(Model.SILENCE_ROWS) do add(row.key) end
    for _, row in ipairs(Model.ARENA_ROWS) do add(row.key) end
    for _, row in ipairs(Model.INTERRUPT_ROWS) do add(row.key) end
    add(Model.LOSS_MASTER.key)
    for _, row in ipairs(Model.LOSS_ROWS) do add(row.key) end
    add(Model.INTERRUPT_MIN.key)
    add(Model.INTERRUPT_PETS.key)
    add(Model.ENGINE_ROW.key)
    add(Model.CHAT_TARGET_ONLY.key)
    add("chatgroups")
    for _, row in ipairs(Model.CHAT_EVENTS) do add(row.key) end
    for _, row in ipairs(Model.CHAT_FILTERS) do add(row.key) end
    for _, row in ipairs(Model.CHAT_TEXTS) do add(row.key) end
    return keys
end

function Model.Reset(db, defaults, model)
    for _, key in ipairs(Model.ResetKeys(model)) do
        db[key] = copyValue(defaults[key])
    end
end
