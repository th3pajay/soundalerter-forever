SA_AuraSound = {}

local ENEMY_UNITS = { "target", "focus" }

SA_AuraSound.BATTLE_PLATES = 20
SA_AuraSound.BATTLE_UNITS = { "target", "focus" }
for index = 1, SA_AuraSound.BATTLE_PLATES do
    SA_AuraSound.BATTLE_UNITS[#SA_AuraSound.BATTLE_UNITS + 1] = "nameplate" .. index
end

function SA_AuraSound.BattleFiles(list, settings, active, out)
    for spellID in pairs(out) do out[spellID] = nil end
    if not active or not list or not settings.battleVoices or settings.aruaApplied then return out end
    local path = settings.sapath
    if not path then return out end
    for spellID, key in pairs(list) do
        if settings[key] then out[spellID] = path .. key .. ".mp3" end
    end
    return out
end

function SA_AuraSound.Key(unit, trigger, spellID)
    return unit .. ":" .. trigger .. ":" .. spellID
end

local function addEntries(desired, unit, trigger, list, settings)
    if not list then return end
    for spellID, key in pairs(list) do
        if settings[key] then
            desired[SA_AuraSound.Key(unit, trigger, spellID)] = {
                unit = unit,
                trigger = trigger,
                spellID = spellID,
                file = settings.sapath .. key .. ".mp3",
            }
        end
    end
end

function SA_AuraSound.Desired(lists, settings, enemyUnits, zoneAllowed)
    local desired = {}
    if not settings.engineAuraSounds or not zoneAllowed then return desired end
    if not settings.dSelfDebuff then
        addEntries(desired, "player", "Added", lists.selfDebuff, settings)
    end
    for _, unit in ipairs(ENEMY_UNITS) do
        if enemyUnits[unit] then
            if not settings.dEnemyDebuff then
                addEntries(desired, unit, "Added", lists.enemyDebuffs, settings)
            end
            if not settings.dEnemyDebuffDown then
                addEntries(desired, unit, "Removed", lists.enemyDebuffdown, settings)
            end
        end
    end
    return desired
end

function SA_AuraSound.Diff(registered, desired)
    local add, remove = {}, {}
    for key, entry in pairs(desired) do
        local existing = registered[key]
        if not existing or existing.file ~= entry.file then
            add[#add + 1] = key
        end
    end
    for key, entry in pairs(registered) do
        local wanted = desired[key]
        if not wanted or wanted.file ~= entry.file then
            remove[#remove + 1] = key
        end
    end
    return add, remove
end
