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

function Game.ReadSpellCooldown(spellID, reading)
    local info = C_Spell.GetSpellCooldown(spellID)
    if not info or info.startTime == nil or info.duration == nil then
        return nil
    end

    if issecretvalue(info.startTime) or issecretvalue(info.duration) then
        reading.kind = "secret"
        reading.isActive = info.isActive
        reading.start = nil
        reading.duration = nil
    else
        reading.kind = "plain"
        reading.isActive = nil
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
