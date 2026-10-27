
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

SA_COMPAT.GetNumRaidMembers = function()
    if not (IsInRaid and GetNumGroupMembers and IsInRaid()) then return 0 end
    return GetNumGroupMembers() or 0
end

SA_COMPAT.GetNumPartyMembers = function()
    if not GetNumGroupMembers or (IsInRaid and IsInRaid()) then return 0 end
    return math.max((GetNumGroupMembers() or 0) - 1, 0)
end

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
    if indexOrName == nil then return nil end

    filter = filter or "HELPFUL"
    for i = 1, 40 do
        local data = SafeGetAuraDataByIndex(unit, i, filter)
        if issecretvalue(data) then
            return nil
        elseif data == nil then
            break
        elseif SA_COMPAT.Plain(data.name) == indexOrName then
            return BuildAuraTuple(data)
        end
    end
    return nil
end

SA_COMPAT.AuraTiming = function(unit, index, filter)
    local data = SafeGetAuraDataByIndex(unit, index, filter)
    if issecretvalue(data) or data == nil then return false end
    return true, data.icon, SA_COMPAT.Plain(data.duration), SA_COMPAT.Plain(data.expirationTime)
end

SA_COMPAT.InventoryItem = function(slot)
    return SA_COMPAT.Plain(GetInventoryItemID("player", slot)), SA_COMPAT.Plain(GetInventoryItemTexture("player", slot))
end

SA_COMPAT.InventoryCooldown = function(slot)
    local start, duration, enable = GetInventoryItemCooldown("player", slot)
    return SA_COMPAT.Plain(start), SA_COMPAT.Plain(duration), SA_COMPAT.Plain(enable)
end

SA_COMPAT.ContainerSlots = function(bag)
    local count = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)
    return SA_COMPAT.Plain(count) or 0
end

SA_COMPAT.ContainerItemID = function(bag, slot)
    return SA_COMPAT.Plain(C_Container.GetContainerItemID(bag, slot))
end

SA_COMPAT.ItemBasics = function(itemID)
    local info = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not info or not itemID then return nil end
    local _, _, _, equipLoc, icon = info(itemID)
    return SA_COMPAT.Plain(equipLoc), SA_COMPAT.Plain(icon)
end

SA_COMPAT.ItemName = function(itemID)
    if C_Item and C_Item.GetItemNameByID then
        return SA_COMPAT.Plain(C_Item.GetItemNameByID(itemID))
    end
    return SA_COMPAT.Plain((GetItemInfo(itemID)))
end

SA_COMPAT.ItemCooldown = function(itemID)
    local read = C_Container and C_Container.GetItemCooldown or C_Item and C_Item.GetItemCooldown
    if not read then return nil end
    local start, duration, enable = read(itemID)
    return SA_COMPAT.Plain(start), SA_COMPAT.Plain(duration), SA_COMPAT.Plain(enable)
end

SA_COMPAT.EquipItem = function(itemID, slot)
    local equip = C_Item and C_Item.EquipItemByName or EquipItemByName
    equip(itemID, slot)
end

SA_COMPAT.GearAvailable = function()
    local api = C_EquipmentSet
    if not (api and api.GetEquipmentSetIDs and api.GetEquipmentSetInfo and api.UseEquipmentSet) then return false end
    if not api.CanUseEquipmentSets then return true end
    local ok, can = pcall(api.CanUseEquipmentSets)
    return ok and SA_COMPAT.Plain(can) ~= false
end

local function ReadGearSets(sets)
    local api = C_EquipmentSet
    for _, id in ipairs(api.GetEquipmentSetIDs() or {}) do
        id = SA_COMPAT.Plain(id)
        if id then
            local name, icon, _, equipped, _, _, _, missing = api.GetEquipmentSetInfo(id)
            name = SA_COMPAT.Plain(name)
            if name and name ~= "" then
                sets[#sets + 1] = {
                    id = id, name = name, icon = SA_COMPAT.Plain(icon),
                    equipped = SA_COMPAT.Plain(equipped) == true,
                    missing = tonumber(SA_COMPAT.Plain(missing)) or 0,
                }
            end
        end
    end
end

local function ByGearName(a, b)
    return a.name < b.name
end

SA_COMPAT.GearSets = function()
    local sets = {}
    if not SA_COMPAT.GearAvailable() then return sets end
    if not pcall(ReadGearSets, sets) then return {} end
    table.sort(sets, ByGearName)
    return sets
end

SA_COMPAT.GearSetLocked = function(id)
    local check = C_EquipmentSet and C_EquipmentSet.EquipmentSetContainsLockedItems
    if not check then return false end
    local ok, locked = pcall(check, id)
    return ok and SA_COMPAT.Plain(locked) == true
end

SA_COMPAT.UseGearSet = function(id)
    local ok, done = pcall(C_EquipmentSet.UseEquipmentSet, id)
    return ok and SA_COMPAT.Plain(done) ~= false
end

SA_COMPAT.PlayFile = function(path)
    if not PlaySoundFile then return false end
    local ok, willPlay = pcall(PlaySoundFile, path, "Master")
    return ok and willPlay and true or false
end
