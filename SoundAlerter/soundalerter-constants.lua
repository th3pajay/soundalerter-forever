
SA_LOCALEPATH = {
    enUS = "Interface\\Addons\\SoundAlerter\\Voice\\",
}

SA_COMPAT = {}

SA_COMPAT.GetSpellInfo = function(spellID)
    local info = C_Spell.GetSpellInfo(spellID)
    if not info then return nil end
    return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID
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

SA_COMPAT.GetSpellCooldown = function(spellID)
    local info = C_Spell.GetSpellCooldown(spellID)
    if not info then return nil end
    return info.startTime, info.duration, info.isEnabled, info.modRate, info.isActive
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
