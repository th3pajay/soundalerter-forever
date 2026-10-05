local BarWave = {}
BarWave.__index = BarWave

local MOMENTUM = 0.88
local RANDOMNESS = 0.4
local POINTS_ACROSS = 28
local BASE_STEP = 3

local LAYERS = {
    { ratio = 2.2, speed = 0.41, amplitude = 0.45 },
    { ratio = 1.4, speed = 1.0, amplitude = 0.36 },
    { ratio = 1.0, speed = 1.89, amplitude = 0.30 },
}

BarWave.LAYER_COUNT = #LAYERS

local function nextHeight(layer)
    local step = layer.step
    local carry = MOMENTUM ^ step
    layer.v = layer.v * carry + (layer.random() - 0.5) * RANDOMNESS * 0.5 * step
    layer.v = layer.v + (0.5 - layer.h) * 0.05 * step
    layer.h = layer.h + layer.v * step
    if layer.h > 1 then
        layer.h = 1
        layer.v = -math.abs(layer.v) * 0.5
    elseif layer.h < 0 then
        layer.h = 0
        layer.v = math.abs(layer.v) * 0.5
    end
    return layer.h
end

local function newLayer(width, spec, random)
    local layer = {
        spacing = width / POINTS_ACROSS * spec.ratio,
        speed = spec.speed,
        amplitude = spec.amplitude,
        step = BASE_STEP * spec.ratio,
        random = random,
        points = {},
        scroll = 0,
        h = random(),
        v = 0,
    }
    local needed = math.ceil(width / layer.spacing) + 5
    for i = 1, needed do
        layer.points[i] = nextHeight(layer)
    end
    return layer
end

local function catmull(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

local function pointAt(points, last, n)
    if n < 0 then
        n = 0
    elseif n > last - 1 then
        n = last - 1
    end
    return points[n + 1]
end

function BarWave.New(width, random)
    random = random or math.random
    local wave = setmetatable({ width = width, layers = {} }, BarWave)
    for i, spec in ipairs(LAYERS) do
        wave.layers[i] = newLayer(width, spec, random)
    end
    return wave
end

function BarWave:Advance(dt)
    for _, layer in ipairs(self.layers) do
        layer.scroll = layer.scroll + layer.speed * layer.spacing * dt
        while layer.scroll >= layer.spacing do
            layer.scroll = layer.scroll - layer.spacing
            table.insert(layer.points, 1, nextHeight(layer))
            table.remove(layer.points)
        end
    end
end

function BarWave:Height(index, x, barHeight)
    local layer = self.layers[index]
    local points = layer.points
    local last = #points
    local position = (x - layer.scroll) / layer.spacing + 1
    local base = math.floor(position)
    local t = position - base

    local normalized = catmull(
        pointAt(points, last, base - 1),
        pointAt(points, last, base),
        pointAt(points, last, base + 1),
        pointAt(points, last, base + 2),
        t
    )
    if normalized < 0 then normalized = 0 elseif normalized > 1 then normalized = 1 end

    local amplitude = layer.amplitude * barHeight
    return barHeight - 2 * amplitude * (1 - normalized)
end

SA_BarWave = BarWave
