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

Model.EVENT_LABEL = {
    ["Gained"] = "Enemy gains it",
    ["Faded"] = "It ends",
    ["Cast start"] = "Starts casting",
    ["Cast"] = "Uses it",
    ["On you"] = "Lands on you",
    ["On friend"] = "Lands on a friend",
    ["On enemy"] = "Lands on an enemy",
    ["CC faded"] = "Your CC ends",
    ["Interrupts you"] = "Interrupts you",
}

Model.EVENT_HELP = {
    ["Gained"] = "An enemy gains this buff or cooldown.",
    ["Faded"] = "The enemy buff or cooldown ends.",
    ["Cast start"] = "An enemy starts casting this spell.",
    ["Cast"] = "An enemy uses this ability.",
    ["On you"] = "This lands on you.",
    ["On friend"] = "This lands on your arena partner or a friend.",
    ["On enemy"] = "This lands on an enemy because of you or your partner.",
    ["CC faded"] = "Your crowd control on an enemy ends.",
    ["Interrupts you"] = "You are interrupted. Plays the lockout sound.",
}

function Model.EventLabel(event)
    return Model.EVENT_LABEL[event] or event
end

Model.SPELL_PLACES = {
    { key = "world", label = "World" },
    { key = "bg", label = "Battleground" },
    { key = "arena", label = "Arena" },
}

Model.ZONE_ROWS = {
    { key = "field", label = "World PvP", name = "world PvP" },
    { key = "battleground", label = "Battlegrounds", name = "battlegrounds" },
    { key = "arena", label = "Arenas", name = "arenas" },
}

Model.WHO = {
    { key = "myself", label = "Target & focus", hint = "Only your target and focus trigger spell alerts." },
    { key = "enemyinrange", label = "All enemies in range", hint = "Any enemy on a nameplate near you can trigger them." },
}

function Model.Who(db)
    return db.enemyinrange and "enemyinrange" or "myself"
end

function Model.SetWho(db, key)
    db.myself = key == "myself"
    db.enemyinrange = key == "enemyinrange"
end

function Model.WhoHint(db)
    local who = Model.Who(db)
    for _, row in ipairs(Model.WHO) do
        if row.key == who then return row.hint end
    end
    return ""
end

function Model.ZoneHint(db)
    local off = {}
    for _, row in ipairs(Model.ZONE_ROWS) do
        if not db[row.key] then off[#off + 1] = row.name end
    end
    if #off == #Model.ZONE_ROWS then return "Spell alerts are silent everywhere.", true end
    if #off > 0 then return "Silent in " .. table.concat(off, " and ") .. ".", false end
    return "Alerts play in every PvP zone.", false
end

Model.AVAILABILITY = {
    addon = { color = { 0.239, 0.863, 0.592 }, label = "SoundAlerter plays it here." },
    game = { color = { 0.443, 0.835, 1 }, label = "The game plays it here (Let the game voice enemy buffs). Not counted in Statistics." },
    blocked = { color = { 1, 0.36, 0.36 }, label = "The game hides this from addons here, so it stays silent." },
    untested = { color = { 1, 0.72, 0.3 }, label = "Not tested here yet." },
}
Model.AVAILABILITY_ORDER = { "addon", "game", "blocked", "untested" }
Model.AVAILABILITY_LEGEND = { addon = "SoundAlerter", game = "the game plays it", blocked = "hidden there", untested = "not tested yet" }

local ENEMY_EVENT = { ["Gained"] = true, ["Faded"] = true, ["Cast start"] = true, ["Cast"] = true, ["On enemy"] = true, ["CC faded"] = true }

function Model.Availability(event, place, db)
    if place == "world" then return "addon" end
    if event == "Gained" then
        if db.battleVoices then return "game" end
        return place == "bg" and "blocked" or "untested"
    end
    if place == "bg" and ENEMY_EVENT[event] then return "blocked" end
    return "untested"
end

Model.DRAWERS = {
    { key = "arena", label = "Arena extras" },
    { key = "interrupts", label = "Interrupts" },
    { key = "loss", label = "Loss of control voice" },
    { key = "engine", label = "Game voices and procs" },
}

function Model.ClassCount(db, group)
    return Model.Count(db, group.spells)
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

local DEFENSIVE_KEYS = {
    iceblock = true, divineshield = true, evasion = true, barkskin = true, icebarrier = true, powerwordshield = true,
    shieldwall = true, deterrence = true, handofprotection = true, divineprotection = true, survivalinstincts = true,
    cloakofshadows = true, holyshield = true, soullink = true, ghostlystrike = true,
}
local STEALTH_KEYS = { prowl = true, stealth = true, vanish = true, shadowmeld = true }
local TRINKET_KEYS = { trinket = true, willoftheforsaken = true }
local BG_SKIP = { bigheal = true, resurrection = true, summonpet = true, revivepet = true, rebirth = true }

local function spellHas(spell, set)
    for _, key in ipairs(spell.keys) do
        if set[key] then return true end
    end
    return false
end

local function always() return true end

Model.ICON_SAVED = "Interface\\Icons\\INV_Misc_Note_01"
Model.SAVED_MAX = 5
Model.SAVED_NAME = 24
Model.HISTORY_MAX = 5

Model.PRESETS = {
    { id = "arena", name = "Arena", note = "Everything on", icon = "Interface\\Icons\\Ability_DualWield", include = always },
    { id = "battleground", name = "Battleground", note = "Everything except heals, rezzes and pet summons", icon = "Interface\\Icons\\INV_BannerPVP_02", include = always, skip = BG_SKIP },
    { id = "hitsme", name = "Only what hits me", note = "Crowd control on you and interrupts on you", icon = "Interface\\Icons\\Ability_Gouge",
        include = function(_, event) return event == "On you" or event == "Interrupts you" end },
    { id = "bigcooldowns", name = "Big cooldowns", note = "An enemy gains a cooldown, and when it ends", icon = "Interface\\Icons\\Spell_Nature_Lightning",
        include = function(_, event) return event == "Gained" or event == "Faded" end },
    { id = "defensives", name = "Defensives only", note = "Enemy defensives, so you know when to hold your burst", icon = "Interface\\Icons\\Spell_Holy_DivineIntervention",
        include = function(spell, event) return (event == "Gained" or event == "Faded") and spellHas(spell, DEFENSIVE_KEYS) end },
    { id = "worldpvp", name = "World PvP / stealth", note = "Stealth, trinkets, crowd control on you and big cooldowns", icon = "Interface\\Icons\\Ability_Stealth",
        include = function(spell, event) return event == "On you" or event == "Gained" or spellHas(spell, STEALTH_KEYS) or spellHas(spell, TRINKET_KEYS) end },
    { id = "quiet", name = "Quiet", note = "Only crowd control on you, interrupts on you and trinkets", icon = "Interface\\Icons\\Spell_Holy_Silence",
        include = function(spell, event) return event == "On you" or event == "Interrupts you" or spellHas(spell, TRINKET_KEYS) end },
}

local function newSet()
    return { has = {}, keys = {}, count = 0 }
end

local function addKey(set, key)
    if set.has[key] then return end
    set.has[key] = true
    set.count = set.count + 1
    set.keys[set.count] = key
end

local function buildSet(model, preset)
    local set = newSet()
    local skip = preset.skip
    for _, spell in ipairs(model.spells) do
        for _, event in ipairs(spell.events) do
            if preset.include(spell, event) then
                for _, key in ipairs(spell.eventKeys[event]) do
                    if not (skip and skip[key]) then addKey(set, key) end
                end
            end
        end
    end
    return set
end

function Model.PresetSet(model, preset)
    local sets = model.presetSets
    if not sets then
        sets = {}
        model.presetSets = sets
    end
    local set = sets[preset.id]
    if not set then
        set = buildSet(model, preset)
        sets[preset.id] = set
    end
    return set
end

local savedSets = setmetatable({}, { __mode = "k" })

function Model.SavedSet(model, saved)
    local cached = savedSets[saved]
    if cached and cached.model == model then return cached.set end
    local set = newSet()
    for _, key in ipairs(saved.keys or {}) do
        if model.allKeys[key] then addKey(set, key) end
    end
    savedSets[saved] = { model = model, set = set }
    return set
end

function Model.OnCount(db, model)
    local count = 0
    for key in pairs(model.allKeys) do
        if db[key] then count = count + 1 end
    end
    return count
end

function Model.PresetMatches(db, set, onCount)
    if set.count ~= onCount then return false end
    local keys = set.keys
    for index = 1, set.count do
        if not db[keys[index]] then return false end
    end
    return true
end

function Model.PresetDiff(db, model, set, out)
    out = out or {}
    local plus, minus = 0, 0
    for key in pairs(model.allKeys) do
        local now, want = db[key] and true or false, set.has[key] == true
        if want and not now then plus = plus + 1 elseif now and not want then minus = minus + 1 end
    end
    out.plus, out.minus, out.after = plus, minus, set.count
    return out
end

function Model.ApplySet(db, model, set, before)
    local changed = 0
    for key in pairs(model.allKeys) do
        local want = set.has[key] == true
        if (db[key] and true or false) ~= want then
            if before then before[key] = db[key] and true or false end
            db[key] = want
            changed = changed + 1
        end
    end
    return changed
end

function Model.FindPreset(presetID)
    for _, preset in ipairs(Model.PRESETS) do
        if preset.id == presetID then return preset end
    end
    return nil
end

function Model.ApplyPreset(db, model, presetID, before)
    local preset = Model.FindPreset(presetID)
    if not preset then return false end
    Model.ApplySet(db, model, Model.PresetSet(model, preset), before)
    return true
end

function Model.TouchedSpells(model, keys)
    local touched = {}
    for _, spell in ipairs(model.spells) do
        for _, key in ipairs(spell.keys) do
            if keys[key] ~= nil then
                touched[spell.id] = true
                break
            end
        end
    end
    return touched
end

local function cutName(text)
    text = (type(text) == "string" and text or ""):match("^%s*(.-)%s*$")
    if #text <= Model.SAVED_NAME then return text end
    local stop = Model.SAVED_NAME
    while stop > 0 do
        local byte = text:byte(stop + 1)
        if not byte or byte < 0x80 or byte >= 0xC0 then break end
        stop = stop - 1
    end
    return text:sub(1, stop)
end

function Model.SavedPresets(db)
    local list = db.voicePresets
    if type(list) ~= "table" then
        list = {}
        db.voicePresets = list
    end
    return list
end

local function currentKeys(db, model)
    local keys = {}
    for key in pairs(model.allKeys) do
        if db[key] then keys[#keys + 1] = key end
    end
    table.sort(keys)
    return keys
end

function Model.SaveCurrent(db, model, name)
    local list = Model.SavedPresets(db)
    if #list >= Model.SAVED_MAX then return nil end
    name = cutName(name)
    if name == "" then name = "My preset " .. (#list + 1) end
    local saved = { name = name, keys = currentKeys(db, model) }
    list[#list + 1] = saved
    return saved
end

function Model.OverwriteSaved(db, model, saved)
    saved.keys = currentKeys(db, model)
    savedSets[saved] = nil
    return saved
end

function Model.DeleteSaved(db, saved)
    local list = Model.SavedPresets(db)
    for index = 1, #list do
        if list[index] == saved then
            table.remove(list, index)
            return true
        end
    end
    return false
end

function Model.PushHistory(history, name, before)
    if next(before) == nil then return false end
    history[#history + 1] = { name = name, before = before }
    if #history > Model.HISTORY_MAX then table.remove(history, 1) end
    return true
end

function Model.PopHistory(db, history)
    local step = table.remove(history)
    if not step then return nil end
    for key, value in pairs(step.before) do db[key] = value end
    return step
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
    { key = "interruptReadyVoice", label = "Say when interrupt is ready", hint = "Uses the cooldown learned from your own casts, else the spell's usual cooldown." },
}

Model.LOSS_MASTER = { key = "lossOfControlVoice", label = "Speak control effects on you", hint = "Stun, fear, root and the rest, from the game's own data." }

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
Model.PROC_ROW = { key = "procVoices", label = "Say my procs", hint = "Says the spell when one of yours lights up. /sa procs lists which have a voice." }
Model.BATTLE_ROW = { key = "battleVoices", label = "Let the game voice enemy buffs in BGs and arenas", hint = "The game hides enemy spells there, so it plays these voices itself on target, focus and nameplates. Not counted in Statistics." }
Model.ENGINE_ROW = { key = "engineAuraSounds", label = "Let the game play debuff alerts", hint = "Experimental. Covers you and an enemy target or focus. Skips Statistics. /sa aurasound tests it." }

Model.CHANNELS = {
    { key = "SAY", label = "Say" },
    { key = "PARTY", label = "Party" },
    { key = "RAID", label = "Raid" },
    { key = "BATTLEGROUND", label = "Battleground" },
}

Model.MASTER_ROW = { key = "chatalerts", label = "Send chat alerts", hint = "Posts a short line to your group when something happens. Off silences every area below.", invert = true }

Model.PLACES = {
    { key = "solo", label = "Solo, world", group = false, raid = false, instance = false, instanceGroup = false },
    { key = "party", label = "Party, world", group = true, raid = false, instance = false, instanceGroup = false },
    { key = "bg", label = "Battleground", group = true, raid = true, instance = true, instanceGroup = true },
    { key = "arena", label = "Arena", group = true, raid = false, instance = true, instanceGroup = true },
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
    { key = "sapselffriend", label = "Sap on you or a friend", spell = 6770 },
    { key = "polyenemy", label = "Polymorph on enemy", spell = 118 },
    { key = "polyselffriend", label = "Polymorph on you or a friend", spell = 118 },
    { key = "bubbleenemy", label = "Divine Shield", spell = 642 },
    { key = "trinketalert", label = "PvP trinket", spell = 1259718 },
    { key = "interruptenemy", label = "You interrupt an enemy" },
    { key = "interruptemote", label = "Roar when you interrupt" },
    { key = "interruptself", label = "An enemy interrupts you" },
    { key = "chatdownfriend", label = "Your CC on an enemy ended" },
    { key = "chatauraApplied", label = "Enemy defensives and buffs" },
    { key = "chatauraRemoved", label = "Enemy defensives expired" },
    { key = "chatcastStart", label = "Enemy cast start" },
}

Model.CHAT_FILTERS = {
    { key = "stealthTF", label = "Stealth: skip my target and focus", requires = "stealthenemy" },
    { key = "prowlTF", label = "Prowl: skip my target and focus", requires = "prowlenemy" },
    { key = "vanishTF", label = "Vanish: skip my target and focus", requires = "vanishenemy" },
}

Model.CHAT_GROUPS = {
    { key = "ccself", label = "CC on you or a friend",
      events = { "blindselffriend", "hexselffriend", "fearselffriend", "polyselffriend", "sapselffriend" },
      texts = { "selfchat", "friendchat", "sapselftext", "sapfriendtext" } },
    { key = "ccenemy", label = "Your team's CC on an enemy",
      events = { "blindenemy", "hexenemy", "fearenemy", "sapenemy", "polyenemy", "chatdownfriend" },
      texts = { "enemychat", "ccDownChat" } },
    { key = "stealth", label = "Stealth",
      events = { "stealthenemy", "prowlenemy", "vanishenemy" },
      filters = { "stealthTF", "prowlTF", "vanishTF" },
      texts = { "enemychat" } },
    { key = "cooldowns", label = "Enemy cooldowns",
      events = { "bubbleenemy", "trinketalert", "chatauraApplied", "chatauraRemoved", "chatcastStart" },
      texts = { "bubbleenemytext", "trinketalerttext", "enemybuffchat", "auraRemovedChat", "castStartChat" } },
    { key = "interrupts", label = "Interrupts",
      events = { "interruptenemy", "interruptself", "interruptemote" },
      texts = { "InterruptEnemyText", "InterruptSelfText" } },
}

Model.SHARED_TEXT = { enemychat = "Shared by CC on an enemy and Stealth" }

Model.CHAT_AREAS = {
    { key = "spells", label = "Spell alerts", icon = "Interface\\Icons\\Spell_Nature_Polymorph", hint = "CC, stealth, enemy cooldowns and interrupts." },
    { key = "proximity", label = "Proximity", icon = "Interface\\Icons\\Ability_Hunter_SniperShot", toggle = "proximityChat", page = "ProximityAlerts", pageLabel = "Proximity Alerts", hint = "Enemies spotted near you. Several within 1.5 s become one line." },
    { key = "battleground", label = "Battlegrounds", icon = "Interface\\Icons\\INV_BannerPVP_02", toggle = "flagChatEnabled", page = "BattlegroundAlerts", pageLabel = "Battleground Alerts", hint = "Flag and base events." },
    { key = "custom", label = "Custom alerts", icon = "Interface\\Icons\\INV_Misc_Note_01", page = "custom", pageLabel = "Custom Alerts", hint = "Each custom alert has its own chat switch and text. This card only sets where those lines go." },
}

Model.CHAT_TEXTS = {
    { key = "enemychat", area = "spells", label = "CC or stealth on an enemy", hint = "#spell# up on #enemy# reads [Blind] up on Enemyname." },
    { key = "friendchat", area = "spells", label = "CC on a friend", hint = "#enemy# casted #spell# on #friend#." },
    { key = "selfchat", area = "spells", label = "CC on you", hint = "#enemy# casted #spell# on me!" },
    { key = "ccDownChat", area = "spells", label = "Your CC on an enemy ended", hint = "#spell# down on #enemy#.", requires = "chatdownfriend" },
    { key = "bubbleenemytext", area = "spells", label = "Divine Shield", hint = "#enemy# bubbled!", requires = "bubbleenemy" },
    { key = "enemybuffchat", area = "spells", label = "Enemy buffs and cooldowns", hint = "#enemy# casted #spell#.", requires = "chatauraApplied" },
    { key = "auraRemovedChat", area = "spells", label = "Enemy defensives expired", hint = "#spell# wore off #enemy#.", requires = "chatauraRemoved" },
    { key = "castStartChat", area = "spells", label = "Enemy cast start", hint = "#enemy# is casting #spell#.", requires = "chatcastStart" },
    { key = "InterruptEnemyText", area = "spells", label = "You interrupt an enemy", hint = "#enemy#, #spell# and #interruptedspellname#.", requires = "interruptenemy" },
    { key = "InterruptSelfText", area = "spells", label = "An enemy interrupts you", hint = "#enemy#, #spell# and #interruptedspellname#.", requires = "interruptself" },
    { key = "sapselftext", area = "spells", label = "Sap on you", hint = "#spell# on me!", requires = "sapselffriend" },
    { key = "sapfriendtext", area = "spells", label = "Sap on a friend", hint = "#friend# is Sapped!", requires = "sapselffriend" },
    { key = "trinketalerttext", area = "spells", label = "PvP trinket", hint = "#enemy# Trinketted!", requires = "trinketalert" },
    { key = "proximityChatText", area = "proximity", label = "Enemy spotted", hint = "#class#, #player#, #level#, #race# and #place#. Enemies seen within 1.5 s are merged into one line.", requires = "proximityChat" },
    { key = "flagPickupChat", area = "battleground", label = "Flag picked up", hint = "#class# and #player#.", requires = "flagChatEnabled" },
    { key = "flagDropChat", area = "battleground", label = "Flag dropped", hint = "#class# and #player#.", requires = "flagChatEnabled" },
    { key = "flagCaptureChat", area = "battleground", label = "Flag captured", hint = "#class# and #player#.", requires = "flagChatEnabled" },
    { key = "flagReturnChat", area = "battleground", label = "Flag returned", hint = "#class# and #player#.", requires = "flagChatEnabled" },
    { key = "baseAssaultChat", area = "battleground", label = "Base assaulted", hint = "#base#, #outcome# (attacked or assaulted) and #player#.", requires = "flagChatEnabled" },
    { key = "baseTakenChat", area = "battleground", label = "Base taken", hint = "#base#, #outcome# (lost or captured) and #player#.", requires = "flagChatEnabled" },
    { key = "baseDefendChat", area = "battleground", label = "Base defended", hint = "#base#, #outcome# (retaken or defended) and #player#.", requires = "flagChatEnabled" },
}

Model.CHAT_SAMPLE = {
    enemy = "Cutthroat", target = "Starmistx", friend = "Starmistx", spell = "[Polymorph]",
    interruptedspellname = "[Polymorph]", interruptedspell = "[Polymorph]",
    class = "Rogue", player = "Cutthroat", level = "60", race = "Undead", place = "Stables 45,61",
    base = "Stables", outcome = "attacked",
}

local CHANNEL_LABEL = {}
for _, channel in ipairs(Model.CHANNELS) do CHANNEL_LABEL[channel.key] = channel.label end
local TEXT_ROW, EVENT_ROW, AREA_ROW = {}, {}, {}
for _, row in ipairs(Model.CHAT_TEXTS) do TEXT_ROW[row.key] = row end
for _, row in ipairs(Model.CHAT_EVENTS) do EVENT_ROW[row.key] = row end
for _, row in ipairs(Model.CHAT_FILTERS) do EVENT_ROW[row.key] = row end
for _, area in ipairs(Model.CHAT_AREAS) do AREA_ROW[area.key] = area end
Model.TEXT_ROW, Model.EVENT_ROW, Model.AREA_ROW = TEXT_ROW, EVENT_ROW, AREA_ROW

local tagCache = {}
function Model.Tags(textKey)
    local tags = tagCache[textKey]
    if tags then return tags end
    tags = {}
    local row = TEXT_ROW[textKey]
    local seen = {}
    for tag in ((row and row.hint) or ""):gmatch("#(%l+)#") do
        if not seen[tag] then
            seen[tag] = true
            tags[#tags + 1] = tag
        end
    end
    tagCache[textKey] = tags
    return tags
end

function Model.AreaLabel(key)
    local area = AREA_ROW[key]
    return area and area.label or key
end

function Model.Channels(db, area)
    local all = db.chatAreaChannels
    if type(all) ~= "table" then
        all = {}
        db.chatAreaChannels = all
    end
    local own = all[area]
    if type(own) ~= "table" then
        own = {}
        all[area] = own
    end
    return own
end

function Model.ToggleChannel(db, area, channel)
    local own = Model.Channels(db, area)
    own[channel] = not own[channel]
end

function Model.CopyChannels(db, from)
    local source = Model.Channels(db, from)
    for _, area in ipairs(Model.CHAT_AREAS) do
        if area.key ~= from then
            local target = Model.Channels(db, area.key)
            for _, channel in ipairs(Model.CHANNELS) do target[channel.key] = source[channel.key] and true or false end
        end
    end
end

function Model.ChannelNames(db, area)
    local own = Model.Channels(db, area)
    local names = {}
    for _, channel in ipairs(Model.CHANNELS) do
        if own[channel.key] then names[#names + 1] = channel.label end
    end
    return names
end

function Model.AreaSummary(db, area)
    local names = Model.ChannelNames(db, area)
    local where = #names > 0 and table.concat(names, ", ") or "only your own chat window"
    return "Sends to " .. where .. ". Channels and message text are set in Voice Alerts, Chat Alerts tab."
end

function Model.GroupCount(db, group)
    local on = 0
    for _, key in ipairs(group.events) do
        if db[key] then on = on + 1 end
    end
    return on, #group.events
end

function Model.SetGroup(db, group, value)
    for _, key in ipairs(group.events) do db[key] = value and true or false end
end

function Model.SetAllChat(db, value)
    for _, row in ipairs(Model.CHAT_EVENTS) do db[row.key] = value and true or false end
end

function Model.AreaOn(db, area)
    if area.toggle then return db[area.toggle] and true or false end
    if area.key == "spells" then return (Model.ChatEventCount(db)) > 0 end
    return (Model.CustomChatCount(db)) > 0
end

function Model.Resolve(channel, place)
    if channel == "BATTLEGROUND" then
        if place.instanceGroup then return "INSTANCE_CHAT" end
        return nil, "needs a battleground or arena group"
    elseif channel == "SAY" then
        if place.instance then return "SAY" end
        return nil, "the game only allows it inside instances"
    elseif channel == "PARTY" then
        if place.group then return "PARTY" end
        return nil, "you are not in a group"
    elseif channel == "RAID" then
        if place.raid then return "RAID" end
        return nil, "you are not in a raid"
    end
    return channel
end

function Model.Routes(db, area, place)
    local own = Model.Channels(db, area)
    local targets, skipped = {}, {}
    for _, channel in ipairs(Model.CHANNELS) do
        if own[channel.key] then
            local target, why = Model.Resolve(channel.key, place)
            if target then targets[#targets + 1] = target else skipped[#skipped + 1] = { channel.label, why } end
        end
    end
    local picked = {}
    for index, target in ipairs(SA_ChatTargets.Pick(targets)) do picked[index] = target end
    return picked, skipped, #targets > #picked
end

function Model.TargetLabel(target)
    return target == "INSTANCE_CHAT" and "Battleground" or CHANNEL_LABEL[target] or target
end

local CUSTOM_SAMPLE = "Shadowmeld on #enemy#!"

function Model.SampleTemplate(db, area)
    if area.key == "spells" then
        for _, group in ipairs(Model.CHAT_GROUPS) do
            for _, key in ipairs(group.events) do
                if db[key] and key ~= "interruptemote" and key ~= "chatdownfriend" then
                    local text = group.texts[1]
                    for _, textKey in ipairs(group.texts) do
                        if TEXT_ROW[textKey].requires == key then
                            text = textKey
                            break
                        end
                    end
                    local event = EVENT_ROW[key]
                    local spellName = event.spell and (event.label:gsub(" on .*$", "")) or nil
                    return db[text], spellName
                end
            end
        end
        return nil
    end
    if area.key == "custom" then return CUSTOM_SAMPLE end
    for _, row in ipairs(Model.CHAT_TEXTS) do
        if row.area == area.key then return db[row.key] end
    end
    return nil
end

local CHAT_LINE = {
    SAY = "|cffffffff[%s] says: %s|r",
    PARTY = "|cffaaaaff[Party] [%s]: %s|r",
    RAID = "|cffff7f00[Raid] [%s]: %s|r",
    INSTANCE_CHAT = "|cffff7d00[Battleground] [%s]: %s|r",
}
local LOCAL_LINE = "|cff33ff99SoundAlerter|r: %s"
local sampleValues = {}

function Model.Sample(db, area, place, player, expand)
    if db.chatalerts then return "|cff8a93a3Chat alerts are off.|r" end
    if not Model.AreaOn(db, area) then return "|cff8a93a3This area is off, nothing is sent.|r" end
    local template, spellName = Model.SampleTemplate(db, area)
    if not template or template == "" then return "|cff8a93a3Nothing switched on yet.|r" end
    for key, value in pairs(Model.CHAT_SAMPLE) do sampleValues[key] = value end
    if spellName then sampleValues.spell = "[" .. spellName .. "]" end
    local text = expand(template, sampleValues):gsub("%s+%-%s*$", "")
    local targets = Model.Routes(db, area.key, place)
    if #targets == 0 then
        local why = #Model.ChannelNames(db, area.key) == 0 and "No channel picked" or "None of these channels work here"
        return "|cffffb84d" .. why .. ": only you see it.|r\n" .. LOCAL_LINE:format(text)
    end
    local lines = {}
    for index, target in ipairs(targets) do lines[index] = CHAT_LINE[target]:format(player, text) end
    return table.concat(lines, "\n")
end

function Model.ChannelNote(db, area, place)
    local targets, skipped, merged = Model.Routes(db, area, place)
    local parts = {}
    if merged then parts[1] = "Battleground already reaches your party and raid here, so they are not sent twice." end
    for _, entry in ipairs(skipped) do parts[#parts + 1] = entry[1] .. " is skipped here: " .. entry[2] .. "." end
    return table.concat(parts, " "), #targets == 0
end

function Model.SendingCount(db)
    if db.chatalerts then return 0, #Model.CHAT_AREAS end
    local count = 0
    for _, area in ipairs(Model.CHAT_AREAS) do
        if Model.AreaOn(db, area) and #Model.ChannelNames(db, area.key) > 0 then count = count + 1 end
    end
    return count, #Model.CHAT_AREAS
end

function Model.PlaceFor(inInstance, instanceType, inGroup)
    if inInstance and instanceType == "pvp" then return "bg" end
    if inInstance and instanceType == "arena" then return "arena" end
    if inGroup then return "party" end
    return "solo"
end

function Model.Place(key)
    for _, place in ipairs(Model.PLACES) do
        if place.key == key then return place end
    end
    return Model.PLACES[1]
end

function Model.CustomChatCount(db)
    local on, total = 0, 0
    for _, alert in pairs(db.custom or {}) do
        total = total + 1
        if alert.chatAlert then on = on + 1 end
    end
    return on, total
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
    add(Model.BATTLE_ROW.key)
    add(Model.ENGINE_ROW.key)
    add(Model.PROC_ROW.key)
    for _, row in ipairs(Model.ZONE_ROWS) do add(row.key) end
    for _, row in ipairs(Model.WHO) do add(row.key) end
    add("chatAreaChannels")
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
