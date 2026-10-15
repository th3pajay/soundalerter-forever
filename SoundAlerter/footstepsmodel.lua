local SoundAlerter = SoundAlerter
local Model = {}

local math_floor = math.floor
local math_sin = math.sin
local math_cos = math.cos
local math_sqrt = math.sqrt

local MIN_ALPHA = 0.25
local OUTDOOR_DIAMETER = { [0] = 466 + 2 / 3, [1] = 400, [2] = 333 + 1 / 3, [3] = 266 + 2 / 3, [4] = 200, [5] = 133 + 1 / 3 }
local INDOOR_DIAMETER = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 }

Model.MIN_ALPHA = MIN_ALPHA

local FIELDS = { "u", "v", "w", "m", "s", "nx", "ny" }

local MAPPINGS = {
    { swap = false, east = 1, north = 1 },
    { swap = false, east = 1, north = -1 },
    { swap = false, east = -1, north = 1 },
    { swap = false, east = -1, north = -1 },
    { swap = true, east = 1, north = 1 },
    { swap = true, east = 1, north = -1 },
    { swap = true, east = -1, north = 1 },
    { swap = true, east = -1, north = -1 },
}

Model.MAPPINGS = MAPPINGS
Model.DEFAULT_MAPPING = 7

local function slot(trail, index)
    return (trail.head - 1 + index - 1) % trail.cap + 1
end

local function round(value)
    return math_floor(value * 10 + 0.5) / 10
end

local function roundMap(value)
    return math_floor(value * 10000 + 0.5) / 10000
end

function Model.Init(trail, cap)
    for i = 1, #FIELDS do
        if type(trail[FIELDS[i]]) ~= "table" then trail[FIELDS[i]] = {} end
    end
    if type(trail.head) ~= "number" or type(trail.count) ~= "number" or type(trail.cap) ~= "number" or trail.cap < 1 then
        trail.head, trail.count, trail.cap = 1, 0, cap
        for i = 1, #FIELDS do
            local field = trail[FIELDS[i]]
            for k in pairs(field) do field[k] = nil end
        end
    end
    if type(trail.seg) ~= "number" then trail.seg = 1 end
    if type(trail.savedAt) ~= "number" then trail.savedAt = 0 end
    trail.rev = (type(trail.rev) == "number" and trail.rev or 0) + 1
    if type(trail.axes) ~= "number" or not MAPPINGS[trail.axes] then trail.axes = Model.DEFAULT_MAPPING end
    if trail.cap ~= cap then
        local kept = trail.count < cap and trail.count or cap
        local copy = {}
        for i = 1, #FIELDS do copy[FIELDS[i]] = {} end
        for i = 1, kept do
            local from = slot(trail, trail.count - kept + i)
            for f = 1, #FIELDS do
                local name = FIELDS[f]
                copy[name][i] = trail[name][from]
            end
        end
        for f = 1, #FIELDS do
            local name = FIELDS[f]
            local field = trail[name]
            for k in pairs(field) do field[k] = nil end
            for i = 1, kept do field[i] = copy[name][i] end
        end
        trail.head, trail.count, trail.cap = 1, kept, cap
    end
    trail.broken = true
    return trail
end

function Model.Clear(trail)
    trail.head, trail.count, trail.seg = 1, 0, 1
    trail.broken = false
    trail.rev = trail.rev + 1
    for i = 1, #FIELDS do
        local field = trail[FIELDS[i]]
        for k in pairs(field) do field[k] = nil end
    end
end

function Model.Break(trail)
    trail.broken = true
end

function Model.Count(trail)
    return trail.count
end

function Model.Add(trail, u, v, world, mapID, spacing, jump, nx, ny)
    local count = trail.count
    if count > 0 then
        if trail.broken then
            trail.seg = trail.seg + 1
        else
            local last = slot(trail, count)
            if trail.w[last] ~= world or trail.m[last] ~= mapID then
                trail.seg = trail.seg + 1
            else
                local du, dv = u - trail.u[last], v - trail.v[last]
                local distSq = du * du + dv * dv
                if distSq < spacing * spacing then return "skipped" end
                if distSq > jump * jump then trail.seg = trail.seg + 1 end
            end
        end
    end
    trail.broken = false

    local target
    if count < trail.cap then
        trail.count = count + 1
        target = slot(trail, trail.count)
    else
        target = trail.head
        trail.head = trail.head % trail.cap + 1
    end
    trail.u[target], trail.v[target] = round(u), round(v)
    trail.w[target], trail.m[target], trail.s[target] = world, mapID, trail.seg
    trail.nx[target], trail.ny[target] = nx and roundMap(nx), ny and roundMap(ny)
    trail.rev = trail.rev + 1
    return "added"
end

function Model.Point(trail, index)
    local at = slot(trail, index)
    return trail.u[at], trail.v[at], trail.w[at], trail.m[at], trail.s[at]
end

function Model.RestoreAction(isInitialLogin, isReloadingUi, savedAt, now, grace)
    if isReloadingUi == true then return "keep" end
    if isInitialLogin == true then return "clear" end
    if isInitialLogin == false and isReloadingUi == false then return "keep" end
    if type(savedAt) ~= "number" or savedAt <= 0 or type(now) ~= "number" then return "clear" end
    if now - savedAt <= grace then return "keep" end
    return "clear"
end

function Model.Offset(u, v, playerU, playerV, mapping)
    local a, b = u - playerU, v - playerV
    if mapping.swap then a, b = b, a end
    return mapping.east * a, mapping.north * b
end

function Model.NewVotes()
    return { count = 0, 0, 0, 0, 0, 0, 0, 0, 0 }
end

function Model.Vote(votes, du, dv, facing)
    local length = math_sqrt(du * du + dv * dv)
    if length <= 0 then return end
    local headingEast, headingNorth = -math_sin(facing), math_cos(facing)
    for index = 1, #MAPPINGS do
        local east, north = Model.Offset(du, dv, 0, 0, MAPPINGS[index])
        votes[index] = votes[index] + (east * headingEast + north * headingNorth) / length
    end
    votes.count = votes.count + 1
end

function Model.Pick(votes, window, threshold)
    if votes.count < window then return nil end
    local best, bestScore = nil, nil
    for index = 1, #MAPPINGS do
        if not bestScore or votes[index] > bestScore then
            best, bestScore = index, votes[index]
        end
    end
    local agreed = bestScore / votes.count >= threshold
    for index = 1, #MAPPINGS do votes[index] = 0 end
    votes.count = 0
    if agreed then return best end
    return nil
end

function Model.Project(east, north, facing, rotate)
    if not rotate or not facing then return east, north end
    local sine, cosine = math_sin(facing), math_cos(facing)
    return east * cosine + north * sine, -east * sine + north * cosine
end

function Model.RadiusYards(zoom, indoor)
    local sizes = indoor and INDOOR_DIAMETER or OUTDOOR_DIAMETER
    local diameter = sizes[zoom]
    if not diameter then return nil end
    return diameter / 2
end

function Model.Alpha(index, count, fade)
    if not fade or count < 2 then return 1 end
    local age = (count - index) / (count - 1)
    return 1 - (1 - MIN_ALPHA) * age
end

function Model.CountWithMap(trail)
    local total = 0
    for index = 1, trail.count do
        local at = slot(trail, index)
        if trail.nx[at] and trail.ny[at] then total = total + 1 end
    end
    return total
end

function Model.GatherMap(trail, mapID, maxDots, fade, out)
    local count = trail.count
    local matches = 0
    for index = 1, count do
        local at = slot(trail, index)
        if trail.m[at] == mapID and trail.nx[at] and trail.ny[at] then matches = matches + 1 end
    end
    local stride = math.ceil(matches / maxDots)
    if stride < 1 then stride = 1 end

    local xs, ys, alphas = out.x, out.y, out.a
    local found, seen = 0, 0
    for index = count, 1, -1 do
        local at = slot(trail, index)
        if trail.m[at] == mapID and trail.nx[at] and trail.ny[at] then
            if seen % stride == 0 and found < maxDots then
                found = found + 1
                xs[found], ys[found] = trail.nx[at], trail.ny[at]
                alphas[found] = Model.Alpha(index, count, fade)
            end
            seen = seen + 1
        end
    end
    return found
end

function Model.Gather(trail, playerU, playerV, world, facing, rotate, radius, maxDots, fade, out, mapping)
    local xs, ys, alphas = out.x, out.y, out.a
    local count = trail.count
    local radiusSq = radius * radius
    local found = 0
    for index = count, 1, -1 do
        local at = slot(trail, index)
        if trail.w[at] == world then
            local east, north = Model.Offset(trail.u[at], trail.v[at], playerU, playerV, mapping)
            if east * east + north * north <= radiusSq then
                found = found + 1
                xs[found], ys[found] = Model.Project(east, north, facing, rotate)
                alphas[found] = Model.Alpha(index, count, fade)
                if found >= maxDots then break end
            end
        end
    end
    return found
end

SoundAlerter.FootstepsModel = Model
