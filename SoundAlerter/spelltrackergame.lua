local Game = {}

local SECRET_OBSERVATION = { kind = "secret" }

local function matchesAuraType(data, auraType)
    local isHarmful = data.isHarmful
    if isHarmful == nil or issecretvalue(isHarmful) then
        return true
    end
    return (auraType == "HARMFUL") == isHarmful
end

function Game.Readable(value)
    if value ~= nil and issecretvalue(value) then
        return nil
    end
    return value
end

function Game.LookupAura(unit, spellID, auraType)
    local ok, data = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
    if not ok then
        return false
    end

    if not data or not matchesAuraType(data, auraType) then
        return true
    end

    if issecretvalue(data.expirationTime) or issecretvalue(data.duration) then
        return true, SECRET_OBSERVATION, data.auraInstanceID
    end

    return true, {
        kind = "real",
        spellID = spellID,
        expiration = data.expirationTime,
        duration = data.duration,
    }, data.auraInstanceID
end

function Game.AuraDelta(info)
    if info == nil or issecretvalue(info) then
        return false
    end
    local full, added, removed = info.isFullUpdate, info.addedAuras, info.removedAuraInstanceIDs
    if issecretvalue(full) or issecretvalue(added) or issecretvalue(removed) then
        return false
    end
    return true, added, removed
end

function Game.AddedAura(aura)
    if aura == nil or issecretvalue(aura) then
        return nil
    end
    return Game.Readable(aura.spellId), Game.Readable(aura.auraInstanceID)
end

local FINISHER_SPELLS = { 1079, 1943, 408, 22568, 8647, 2098, 26679, 22570 }
local finisherNames

function Game.ComboPoints()
    if not GetComboPoints then return nil end
    local ok, points = pcall(GetComboPoints, "player", "target")
    if not ok or points == nil or issecretvalue(points) then return nil end
    return points
end

function Game.IsFinisher(spellID)
    if not finisherNames then
        finisherNames = {}
        for _, id in ipairs(FINISHER_SPELLS) do
            local name = SA_COMPAT.GetSpellInfo(id)
            if name then finisherNames[name] = true end
        end
    end
    local name = SA_COMPAT.GetSpellInfo(spellID)
    return name ~= nil and finisherNames[name] == true
end

function Game.ReadSpellCooldown(spellID, reading)
    local info = C_Spell.GetSpellCooldown(spellID)
    if not info or info.startTime == nil or info.duration == nil then
        return nil
    end

    if issecretvalue(info.startTime) or issecretvalue(info.duration) then
        reading.kind = "secret"
        reading.isActive = info.isActive
        reading.isOnGCD = info.isOnGCD
        reading.start = nil
        reading.duration = nil
    else
        reading.kind = "plain"
        reading.isActive = nil
        reading.isOnGCD = nil
        reading.start = info.startTime
        reading.duration = info.duration
    end
    return reading
end

function Game.AuraDurationObject(unit, auraInstanceID)
    if unit and auraInstanceID and C_UnitAuras.GetAuraDuration then
        return C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
    end
    return nil
end

function Game.SpellCooldownDurationObject(spellID)
    if C_Spell.GetSpellCooldownDuration then
        return C_Spell.GetSpellCooldownDuration(spellID, true)
    end
    return nil
end

SA_TrackerGame = Game
