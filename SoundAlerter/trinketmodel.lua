SA_TrinketModel = {}

local Model = SA_TrinketModel

Model.TOP, Model.BOTTOM = 13, 14
Model.SLOTS = { 13, 14 }
Model.SET_COUNT = 3
Model.FLYOUT_MAX = 12
Model.FADE_TIME = 0.4
Model.READY_MIN = 30
Model.ORIENTATIONS = { { "vertical", "Vertical" }, { "horizontal", "Horizontal" } }

local ipairs, table_sort = ipairs, table.sort

function Model.Other(slot)
    return slot == 13 and 14 or 13
end

function Model.Order(swapOrder, showSet, showGear, showWeapon)
    local order = swapOrder and { 14, 13 } or { 13, 14 }
    if showWeapon then order[#order + 1] = "weapon" end
    if showSet then order[#order + 1] = "set" end
    if showGear then order[#order + 1] = "gear" end
    return order
end

function Model.Layout(orientation, swapOrder, showSet, showGear, size, spacing, showWeapon)
    local order = Model.Order(swapOrder, showSet, showGear, showWeapon)
    local offsets, step = {}, size + spacing
    local horizontal = orientation == "horizontal"
    for index, key in ipairs(order) do
        local along = (index - 1) * step
        offsets[key] = horizontal and { along, 0 } or { 0, -along }
    end
    local length = #order * size + (#order - 1) * spacing
    if horizontal then return offsets, length, size end
    return offsets, size, length
end

function Model.Flyout(bagItems)
    local seen, list = {}, {}
    for _, item in ipairs(bagItems) do
        if not seen[item.id] then
            seen[item.id] = true
            list[#list + 1] = item
        end
    end
    table_sort(list, function(a, b)
        local an, bn = a.name or "", b.name or ""
        if an ~= bn then return an < bn end
        return a.id < b.id
    end)
    for index = #list, Model.FLYOUT_MAX + 1, -1 do list[index] = nil end
    return list
end

function Model.Effective(pending, equipped, slot)
    return pending and pending[slot] or equipped[slot]
end

function Model.Request(pending, slot, id)
    local result = { [13] = pending and pending[13], [14] = pending and pending[14] }
    result[slot] = id
    return result
end

function Model.Swap(pending, equipped)
    local top, bottom = Model.Effective(pending, equipped, 13), Model.Effective(pending, equipped, 14)
    if top == nil and bottom == nil then return pending end
    return { [13] = bottom, [14] = top }
end

function Model.FromSet(set)
    if not Model.SetFilled(set) then return nil end
    return { [13] = set[13], [14] = set[14] }
end

function Model.Prune(pending, equipped, owned)
    if not pending then return nil end
    local kept = false
    for _, slot in ipairs(Model.SLOTS) do
        local id = pending[slot]
        if id and not (owned[id] or equipped[13] == id or equipped[14] == id) then
            pending[slot] = nil
        elseif id then
            kept = true
        end
    end
    return kept and pending or nil
end

function Model.Plan(pending, equipped)
    local steps = {}
    if not pending then return steps end
    local top, bottom = pending[13], pending[14]
    if top and bottom and top ~= bottom and top == equipped[14] and bottom == equipped[13] then
        steps[1] = { slot = 13, id = top }
        return steps
    end
    for _, slot in ipairs(Model.SLOTS) do
        local id = pending[slot]
        if id and id ~= equipped[slot] then steps[#steps + 1] = { slot = slot, id = id } end
    end
    return steps
end

function Model.Waiting(pending, equipped)
    return #Model.Plan(pending, equipped) > 0
end

function Model.SetFilled(set)
    return type(set) == "table" and (set[13] ~= nil or set[14] ~= nil)
end

function Model.NextSet(index, delta)
    local count = Model.SET_COUNT
    return ((index or 1) - 1 + (delta or 1)) % count + 1
end

function Model.SetLabel(index)
    return "S" .. index
end

function Model.Named(name)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

function Model.GearTarget(main, alt, wearing, pending)
    main, alt = Model.Named(main), Model.Named(alt)
    if not main then return nil end
    local current = Model.Named(pending) or Model.Named(wearing)
    if current == main and alt and alt ~= main then return alt end
    return main
end

function Model.GearLabel(name)
    name = Model.Named(name)
    if not name then return "" end
    local label, count = "", 0
    for char in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if count == 3 then break end
        label, count = label .. char, count + 1
    end
    return label
end

Model.MAIN_HAND, Model.OFF_HAND = 16, 17
Model.WEAPON_SLOTS = {
    INVTYPE_WEAPON = 16, INVTYPE_2HWEAPON = 16, INVTYPE_WEAPONMAINHAND = 16,
    INVTYPE_WEAPONOFFHAND = 17, INVTYPE_SHIELD = 17, INVTYPE_HOLDABLE = 17,
}
Model.WEAPON_NAMES = { "DPS", "Healing" }
local WEAPON_LABELS = { "DPS", "HEAL" }
local WEAPON_LETTERS = { "N", "H" }
local WEAPON_WORD_MIN = 30

function Model.PairFilled(pair)
    return type(pair) == "table" and pair[16] ~= nil
end

function Model.PairFrom(main, off)
    if not main then return nil end
    return { [16] = main, [17] = off }
end

function Model.PairWorn(weaponPairs, main, off)
    if not main then return nil end
    for index = 1, 2 do
        local pair = weaponPairs[index]
        if Model.PairFilled(pair) and pair[16] == main and (pair[17] == nil or pair[17] == off) then return index end
    end
    return nil
end

function Model.ArmWorn(weaponPairs, worn)
    if worn then return worn end
    return Model.PairFilled(weaponPairs[1]) and 2 or 1
end

function Model.WeaponMacro(pair)
    if not Model.PairFilled(pair) then return nil end
    local macro = "/equipslot 16 item:" .. pair[16]
    if pair[17] then macro = macro .. "\n/equipslot 17 item:" .. pair[17] end
    return macro
end

function Model.SaveTarget(weaponPairs, main, off, last)
    local worn = Model.PairWorn(weaponPairs, main, off)
    if worn then return worn end
    for index = 1, 2 do
        if not Model.PairFilled(weaponPairs[index]) then return index end
    end
    return last or 1
end

function Model.WeaponLabel(index, size)
    if size < WEAPON_WORD_MIN then return WEAPON_LETTERS[index] end
    return WEAPON_LABELS[index]
end

local function Available(id, owned, main, off)
    return id == nil or owned[id] or id == main or id == off
end

function Model.WeaponState(weaponPairs, main, off, owned)
    if not Model.PairFilled(weaponPairs[1]) and not Model.PairFilled(weaponPairs[2]) then
        return "unsaved", nil, nil
    end
    local worn = Model.PairWorn(weaponPairs, main, off)
    if not worn then return "other", nil, nil end
    local nextIndex = 3 - worn
    local pair = weaponPairs[nextIndex]
    if not Model.PairFilled(pair) then return "ready", worn, nil end
    if not (Available(pair[16], owned, main, off) and Available(pair[17], owned, main, off)) then
        return "missing", worn, nextIndex
    end
    return "ready", worn, nextIndex
end

function Model.WeaponFlyout(bagWeapons)
    local mains, offs = {}, {}
    for _, item in ipairs(bagWeapons) do
        local list = item.equipSlot == 16 and mains or offs
        list[#list + 1] = item
    end
    mains, offs = Model.Flyout(mains), Model.Flyout(offs)
    local entries, lanes = {}, 0
    for _, list in ipairs({ mains, offs }) do
        if #list > 0 then
            lanes = lanes + 1
            for along, item in ipairs(list) do
                item.lane, item.along = lanes, along
                entries[#entries + 1] = item
            end
        end
    end
    return entries, lanes, math.max(#mains, #offs)
end

function Model.IdleAlpha(enabled, idleFor, delay, target)
    if not enabled or idleFor < delay then return 1 end
    local progress = (idleFor - delay) / Model.FADE_TIME
    if progress >= 1 then return target end
    local eased = 1 - (1 - progress) * (1 - progress)
    return 1 - (1 - target) * eased
end

function Model.ReadyTarget(enabled, duration, faded, shown, collapsed, waiting)
    if enabled ~= true or waiting or type(duration) ~= "number" or duration <= Model.READY_MIN then return nil end
    if shown then return not faded and "bar" or nil end
    return collapsed and "diamond" or nil
end

function Model.Cooldown(start, duration, enable)
    if type(start) ~= "number" or type(duration) ~= "number" then return nil end
    if enable == false or enable == 0 or start <= 0 or duration <= 1.5 then return nil end
    return start, duration
end
