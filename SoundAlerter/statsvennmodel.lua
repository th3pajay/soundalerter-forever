SA_StatsVenn = {}

local Venn = SA_StatsVenn

Venn.ZONES = {
    { key = "arena", label = "Arena", color = { 1, 0.49, 0.42 } },
    { key = "battleground", label = "Battlegrounds", color = { 0.42, 0.82, 1 } },
    { key = "worldPvP", label = "World PvP", color = { 0.9, 0.76, 0.3 } },
}

Venn.GROUPS = {
    { key = "CC", label = "Crowd control", short = "CC", color = { 0.78, 0.55, 1 } },
    { key = "Defensive", label = "Defensive", short = "Def", color = { 0.24, 0.86, 0.52 } },
    { key = "Interrupt", label = "Interrupt", short = "Int", color = { 1, 0.42, 0.42 } },
    { key = "Removal", label = "Buff and debuff removal", short = "Rem", color = { 0.35, 0.66, 1 } },
    { key = "Other", label = "Other", short = "Oth", color = { 0.6, 0.63, 0.7 } },
}

Venn.GROUP_COLOR = {}
for _, group in ipairs(Venn.GROUPS) do Venn.GROUP_COLOR[group.key] = group.color end

local GROUP_OF = {
    CC = "CC",
    Defensive = "Defensive",
    Interrupt = "Interrupt",
    ["Buff Removal"] = "Removal",
    ["Debuff Removal"] = "Removal",
}

local ZONE_BIT = { arena = 1, battleground = 2, worldPvP = 4 }

local HAS_ZONE, ZONE_COUNT = {}, {}
for mask = 0, 7 do
    local first, second, third = mask % 2 == 1, math.floor(mask / 2) % 2 == 1, math.floor(mask / 4) % 2 == 1
    HAS_ZONE[mask] = { first, second, third }
    ZONE_COUNT[mask] = (first and 1 or 0) + (second and 1 or 0) + (third and 1 or 0)
end

Venn.CAPS = { 7, 3, 2 }
Venn.SIZES = { 17, 15, 13 }
Venn.MORE_SIZE = 15
Venn.SLOT = 17
Venn.MARGIN = 9

local REF_WIDTH, REF_HEIGHT, REF_RADIUS = 640, 510, 148
local REF_CENTERS = { { 218, 185 }, { 422, 185 }, { 320, 335 } }
local RING = { { 1, 0 }, { 0.7, 0.7 }, { 0, 1 }, { -0.7, 0.7 }, { -1, 0 }, { -0.7, -0.7 }, { 0, -1 }, { 0.7, -0.7 } }
local ROW_STEP = 0.87

function Venn.GroupOf(category)
    return GROUP_OF[category] or "Other"
end

function Venn.MaskOf(byZone)
    local mask = 0
    if type(byZone) ~= "table" then return mask end
    for key, bit in pairs(ZONE_BIT) do
        if (byZone[key] or 0) > 0 then mask = mask + bit end
    end
    return mask
end

function Venn.HasZone(mask, index)
    return HAS_ZONE[mask][index]
end

function Venn.TopKey(map)
    local best, bestCount
    if type(map) ~= "table" then return nil end
    for key, count in pairs(map) do
        if bestCount == nil or count > bestCount or (count == bestCount and tostring(key) < tostring(best)) then
            best, bestCount = key, count
        end
    end
    return best, bestCount
end

local function regionOf(centers, radius, x, y)
    local mask = 0
    for index = 1, 3 do
        local dx, dy = x - centers[index][1], y - centers[index][2]
        if dx * dx + dy * dy <= radius * radius then mask = mask + 2 ^ (index - 1) end
    end
    return mask
end

local function nearestFirst(a, b)
    if a.d ~= b.d then return a.d < b.d end
    if a.y ~= b.y then return a.y < b.y end
    return a.x < b.x
end

local geometries = {}

function Venn.Geometry(width, slot, margin)
    local key = width .. ":" .. slot .. ":" .. margin
    local cached = geometries[key]
    if cached then return cached end
    local scale = width / REF_WIDTH
    local height = REF_HEIGHT * scale
    local radius = REF_RADIUS * scale
    local centers = {}
    for index = 1, 3 do
        centers[index] = { REF_CENTERS[index][1] * scale, REF_CENTERS[index][2] * scale }
    end

    local sums = {}
    local step = math.max(1, slot / 6)
    local y = 0
    while y <= height do
        local x = 0
        while x <= width do
            local mask = regionOf(centers, radius, x, y)
            if mask > 0 then
                local sum = sums[mask]
                if not sum then
                    sum = { 0, 0, 0 }
                    sums[mask] = sum
                end
                sum[1], sum[2], sum[3] = sum[1] + x, sum[2] + y, sum[3] + 1
            end
            x = x + step
        end
        y = y + step
    end

    local regions = {}
    for mask, sum in pairs(sums) do
        regions[mask] = { x = sum[1] / sum[3], y = sum[2] / sum[3], slots = {} }
    end

    local row = 0
    y = margin
    while y <= height - margin do
        local x = margin + ((row % 2 == 1) and slot / 2 or 0)
        while x <= width - margin do
            local mask = regionOf(centers, radius, x, y)
            local region = regions[mask]
            if region then
                local clean = true
                for index = 1, #RING do
                    if regionOf(centers, radius, x + RING[index][1] * margin, y + RING[index][2] * margin) ~= mask then
                        clean = false
                        break
                    end
                end
                if clean then
                    local slots = region.slots
                    local dx, dy = x - region.x, y - region.y
                    slots[#slots + 1] = { x = x, y = y, d = math.sqrt(dx * dx + dy * dy) }
                end
            end
            x = x + slot
        end
        row = row + 1
        y = y + slot * ROW_STEP
    end
    for _, region in pairs(regions) do table.sort(region.slots, nearestFirst) end

    local geometry = { width = width, height = height, radius = radius, centers = centers, regions = regions }
    geometries[key] = geometry
    return geometry
end

local function heaviestFirst(a, b)
    if a.total ~= b.total then return a.total > b.total end
    return a.id < b.id
end

local function tierSize(total, high, mid, sizes)
    if total >= high then return sizes[1] end
    if total >= mid then return sizes[2] end
    return sizes[3]
end

function Venn.Layout(entries, geometry, options)
    options = options or {}
    local off = options.off or {}
    local caps = options.caps or Venn.CAPS
    local sizes = options.sizes or Venn.SIZES
    local moreSize = options.moreSize or Venn.MORE_SIZE

    local pool, groupCounts, zoneCounts = {}, {}, { 0, 0, 0 }
    for index = 1, #entries do
        local entry = entries[index]
        if entry.mask > 0 then
            groupCounts[entry.group] = (groupCounts[entry.group] or 0) + 1
            if not off[entry.group] then pool[#pool + 1] = entry end
        end
    end
    table.sort(pool, heaviestFirst)

    local total = #pool
    local high = total > 0 and pool[math.floor(total * 0.2) + 1].total or 0
    local mid = total > 0 and pool[math.floor(total * 0.55) + 1].total or 0

    local buckets = {}
    for index = 1, total do
        local entry = pool[index]
        local has = HAS_ZONE[entry.mask]
        for zone = 1, 3 do
            if has[zone] then zoneCounts[zone] = zoneCounts[zone] + 1 end
        end
        local bucket = buckets[entry.mask]
        if not bucket then
            bucket = {}
            buckets[entry.mask] = bucket
        end
        bucket[#bucket + 1] = entry
    end

    local items, shown = {}, 0
    for mask = 1, 7 do
        local list, region = buckets[mask], geometry.regions[mask]
        if list and region then
            local slots = region.slots
            local cap = math.min(#slots, caps[ZONE_COUNT[mask]])
            if cap == 0 then
                items[#items + 1] = { key = "more" .. mask, more = true, hidden = list, x = region.x, y = region.y, size = moreSize, mask = mask }
            else
                local fit = #list
                if #list > cap then fit = cap - 1 end
                for position = 1, fit do
                    local entry = list[position]
                    local slot = slots[position]
                    items[#items + 1] = { key = entry.id, entry = entry, x = slot.x, y = slot.y, size = tierSize(entry.total, high, mid, sizes), mask = mask }
                    shown = shown + 1
                end
                if #list > cap then
                    local hidden = {}
                    for position = fit + 1, #list do hidden[#hidden + 1] = list[position] end
                    local slot = slots[cap]
                    items[#items + 1] = { key = "more" .. mask, more = true, hidden = hidden, x = slot.x, y = slot.y, size = moreSize, mask = mask }
                end
            end
        end
    end

    return { items = items, shown = shown, pool = total, groupCounts = groupCounts, zoneCounts = zoneCounts }
end

Venn.CATEGORY_ORDER = {
    { "friendCCs", "CC" },
    { "enemyDebuffs", "CC" },
    { "friendCCenemy", "CC" },
    { "friendCCSuccess", "CC" },
    { "auraApplied", "Defensive" },
    { "interruptFriend", "Interrupt" },
    { "enemyDebuffdown", "Debuff Removal" },
    { "enemyDebuffdownAP", "Debuff Removal" },
    { "auraRemoved", "Buff Removal" },
    { "castStart", "Cast" },
    { "castSuccess", "Instant" },
    { "selfDebuff", "Debuff on Self" },
}

function Venn.CategoryOf(spells, spellID)
    if type(spells) ~= "table" then return "Other" end
    for _, rule in ipairs(Venn.CATEGORY_ORDER) do
        local list = spells[rule[1]]
        if list and list[spellID] then return rule[2] end
    end
    return "Other"
end

Venn.GAME_VOICED_NOTE = ". Game-voiced BG and arena buffs not counted"

function Venn.NoteText(layout, scope, gameVoiced)
    if layout.pool == 0 then return "" end
    scope = scope or "all-time"
    local text
    if layout.shown < layout.pool then
        text = string.format("Showing %d of %d spells - %s", layout.shown, layout.pool, scope)
    else
        text = string.format("%d spells - %s", layout.pool, scope)
    end
    return gameVoiced and text .. Venn.GAME_VOICED_NOTE or text
end


Venn.BG_HIDDEN = "hidden by the game"
Venn.BG_HIDDEN_TIP = {
    "The game hides enemy spells from addons in battlegrounds, so they can't be counted.",
    "Enemy buffs are still voiced by the game there, but it doesn't tell SoundAlerter, so those aren't counted either.",
    "See Classes for who you met there.",
}

Venn.CLASSES = {
    { key = "DRUID", label = "Druid", short = "Dru", color = { 1, 0.49, 0.04 } },
    { key = "HUNTER", label = "Hunter", short = "Hun", color = { 0.67, 0.83, 0.45 } },
    { key = "MAGE", label = "Mage", short = "Mag", color = { 0.41, 0.8, 0.94 } },
    { key = "PALADIN", label = "Paladin", short = "Pal", color = { 0.96, 0.55, 0.73 } },
    { key = "PRIEST", label = "Priest", short = "Pri", color = { 1, 1, 1 } },
    { key = "ROGUE", label = "Rogue", short = "Rog", color = { 1, 0.96, 0.41 } },
    { key = "SHAMAN", label = "Shaman", short = "Sha", color = { 0, 0.44, 0.87 } },
    { key = "WARLOCK", label = "Warlock", short = "Wlk", color = { 0.58, 0.51, 0.79 } },
    { key = "WARRIOR", label = "Warrior", short = "War", color = { 0.78, 0.61, 0.43 } },
    { key = "UNKNOWN", label = "Unknown", short = "?", color = { 0.49, 0.52, 0.59 } },
}

Venn.CLASS_INDEX, Venn.CLASS_COLOR, Venn.CLASS_LABEL = {}, {}, {}
for index, class in ipairs(Venn.CLASSES) do
    Venn.CLASS_INDEX[class.key] = index
    Venn.CLASS_COLOR[class.key] = class.color
    Venn.CLASS_LABEL[class.key] = class.label
end

Venn.REGION_NAME = {
    [1] = "Arena only", [2] = "Battlegrounds only", [4] = "World PvP only",
    [3] = "Arena and battlegrounds", [5] = "Arena and world PvP", [6] = "Battlegrounds and world PvP", [7] = "All three",
}

Venn.CLASS_NAMES = 6

function Venn.ClassOf(token)
    if Venn.CLASS_INDEX[token] then return token end
    return "UNKNOWN"
end

local function byAlertsThenName(a, b)
    if a[2] ~= b[2] then return a[2] > b[2] end
    return a[1] < b[1]
end

function Venn.ClassEntries(enemies, pool)
    pool = pool or {}
    local entries = {}
    local generation = (pool.generation or 0) + 1
    pool.generation = generation
    for name, enemy in pairs(enemies or {}) do
        local mask = Venn.MaskOf(enemy.byZone)
        if mask > 0 then
            local class = Venn.ClassOf(enemy.class)
            local key = class .. ":" .. mask
            local entry = pool[key]
            if not entry then
                entry = { id = key, class = class, group = class, mask = mask, ranked = {} }
                pool[key] = entry
            end
            if entry.generation ~= generation then
                entry.generation = generation
                entry.total = 0
                for index = #entry.ranked, 1, -1 do entry.ranked[index] = nil end
                entries[#entries + 1] = entry
            end
            entry.total = entry.total + 1
            entry.ranked[#entry.ranked + 1] = { name, enemy.totalAlerts or 0 }
        end
    end
    for key, entry in pairs(pool) do
        if type(entry) == "table" and entry.generation ~= generation then pool[key] = nil end
    end
    for _, entry in ipairs(entries) do
        table.sort(entry.ranked, byAlertsThenName)
        local names = entry.names or {}
        for index = #names, 1, -1 do names[index] = nil end
        for index = 1, math.min(Venn.CLASS_NAMES, #entry.ranked) do names[index] = entry.ranked[index][1] end
        entry.names = names
    end
    return entries
end

function Venn.ClassShares(classByZone)
    local rows = {}
    for index, zone in ipairs(Venn.ZONES) do
        local counts = classByZone and classByZone[zone.key] or {}
        local parts, total = {}, 0
        for _, class in ipairs(Venn.CLASSES) do
            local count = counts[class.key] or 0
            if count > 0 then
                parts[#parts + 1] = { key = class.key, count = count }
                total = total + count
            end
        end
        rows[index] = { zone = zone, parts = parts, total = total }
    end
    return rows
end

function Venn.ClassNoteText(layout, shares)
    if layout.pool == 0 then return "" end
    local players = 0
    for index = 1, #layout.items do
        local item = layout.items[index]
        if item.entry then players = players + item.entry.total end
        if item.more then
            for _, entry in ipairs(item.hidden) do players = players + entry.total end
        end
    end
    local battleground = shares and shares[2] and shares[2].total or 0
    return string.format("%d players from your top 100. Bars: everyone met, %d in BGs.", players, battleground)
end
