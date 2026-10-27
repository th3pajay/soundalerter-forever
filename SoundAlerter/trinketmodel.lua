SA_TrinketModel = {}

local Model = SA_TrinketModel

Model.TOP, Model.BOTTOM = 13, 14
Model.SLOTS = { 13, 14 }
Model.SET_COUNT = 3
Model.FLYOUT_MAX = 12
Model.FADE_TIME = 0.4
Model.ORIENTATIONS = { { "vertical", "Vertical" }, { "horizontal", "Horizontal" } }

local ipairs, table_sort = ipairs, table.sort

function Model.Other(slot)
    return slot == 13 and 14 or 13
end

function Model.Order(swapOrder, showSet, showGear)
    local order = swapOrder and { 14, 13 } or { 13, 14 }
    if showSet then order[#order + 1] = "set" end
    if showGear then order[#order + 1] = "gear" end
    return order
end

function Model.Layout(orientation, swapOrder, showSet, showGear, size, spacing)
    local order = Model.Order(swapOrder, showSet, showGear)
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

function Model.IdleAlpha(enabled, idleFor, delay, target)
    if not enabled or idleFor < delay then return 1 end
    local progress = (idleFor - delay) / Model.FADE_TIME
    if progress >= 1 then return target end
    return 1 - (1 - target) * progress
end

function Model.Cooldown(start, duration, enable)
    if type(start) ~= "number" or type(duration) ~= "number" then return nil end
    if enable == false or enable == 0 or start <= 0 or duration <= 1.5 then return nil end
    return start, duration
end
