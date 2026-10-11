
SA_LOCALEPATH = {
    enUS = "Interface\\Addons\\SoundAlerter\\Voice\\",
}

SA_COMPAT = {}

SA_COMPAT.Plain = function(value)
    if issecretvalue(value) then return nil end
    return value
end

SA_COMPAT.SafeUnitName = function(unit)
    return SA_COMPAT.Plain(UnitName(unit))
end

SA_COMPAT.SafeUnitClass = function(unit)
    local _, class = UnitClass(unit)
    return SA_COMPAT.Plain(class)
end

SA_COMPAT.GetSpellInfo = function(spellID)
    local info = C_Spell.GetSpellInfo(spellID)
    if not info then return nil end
    return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID
end

SA_COMPAT.GetSpellSubtext = function(spellID)
    if C_Spell.GetSpellSubtext then
        return C_Spell.GetSpellSubtext(spellID)
    end
    return nil
end

SA_COMPAT.IsSpellPassive = function(spellID)
    if C_Spell.IsSpellPassive then
        return SA_COMPAT.Plain(C_Spell.IsSpellPassive(spellID))
    end
    return nil
end

SA_COMPAT.IsSpellKnown = function(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return SA_COMPAT.Plain(C_SpellBook.IsSpellKnown(spellID))
    end
    if IsSpellKnown then
        return SA_COMPAT.Plain(IsSpellKnown(spellID))
    end
    return nil
end

SA_COMPAT.GetSpellCosts = function(spellID)
    if not C_Spell.GetSpellPowerCost then return nil end
    local list = C_Spell.GetSpellPowerCost(spellID)
    if type(list) ~= "table" then return nil end
    local costs = {}
    for _, entry in ipairs(list) do
        local cost = SA_COMPAT.Plain(entry.cost)
        local name = SA_COMPAT.Plain(entry.name)
        if type(cost) == "number" and cost > 0 and type(name) == "string" then
            costs[#costs + 1] = { name = name, cost = cost }
        end
    end
    return costs
end

SA_COMPAT.GetSpellMaxCharges = function(spellID)
    if not C_Spell.GetSpellCharges then return nil end
    local info = C_Spell.GetSpellCharges(spellID)
    if type(info) ~= "table" then return nil end
    return SA_COMPAT.Plain(info.maxCharges)
end

SA_COMPAT.GetSpellLink = function(spellID)
    return C_Spell.GetSpellLink(spellID)
end

SA_COMPAT.GetNumRaidMembers = GetNumGroupMembers

SA_COMPAT.GetZonePVPInfo = function()
    return C_PvP.GetZonePVPInfo()
end

SA_COMPAT.GetSpellDescription = function(spellID)
    return C_Spell.GetSpellDescription(spellID)
end

SA_COMPAT.UnitCastingInfo = function(unit)
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, _, notInterruptible, _ = UnitCastingInfo(unit)
    return name, nil, text, texture, startTimeMS, endTimeMS, isTradeSkill, notInterruptible
end

SA_COMPAT.UnitChannelInfo = function(unit)
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, notInterruptible, _ = UnitChannelInfo(unit)
    return name, nil, text, texture, startTimeMS, endTimeMS, isTradeSkill, notInterruptible
end

local function BuildAuraTuple(data)
    if not data then return nil end
    return data.name, nil, data.icon, data.applications, data.dispelName,
           data.duration, data.expirationTime, data.sourceUnit,
           data.isStealable, data.nameplateShowPersonal, data.spellId,
           data.canApplyAura, data.isBossAura, data.isFromPlayerOrPlayerPet,
           data.nameplateShowAll, data.timeMod
end

local function SafeGetAuraDataByIndex(unit, index, filter)
    local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
    if not ok then return nil end
    return data
end

SA_COMPAT.UnitAura = function(unit, indexOrName, filter)
    if type(indexOrName) == "number" then
        return BuildAuraTuple(SafeGetAuraDataByIndex(unit, indexOrName, filter))
    end

    filter = filter or "HELPFUL"
    for i = 1, 40 do
        local data = SafeGetAuraDataByIndex(unit, i, filter)
        if not data then break end
        if data.name == indexOrName then
            return BuildAuraTuple(data)
        end
    end
    return nil
end

