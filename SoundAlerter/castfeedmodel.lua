local Model = {}

local APPEAR_TIME = 0.12
local SETTLE_TIME = 0.16
local SETTLE_FROM = 0.88
local SETTLE_PEAK = 1.04
local SETTLE_SPLIT = 0.6
local PULSE_TIME = 0.28
local PULSE_PEAK = 1.12
local SHAKE_TIME = 0.26
local SHAKE_PIXELS = 3
local SHAKE_CYCLES = 2
local EDGE_FADE = 0.18

Model.STACK_WINDOW = 3

Model.QUALITIES = {
	{ "low", "Low" },
	{ "normal", "Normal" },
	{ "high", "High" },
}

Model.TIERS = {
	low = { name = "low", sweep = false, fade = false, edge = false, settle = false, result = false },
	normal = { name = "normal", sweep = true, fade = true, edge = true, settle = false, result = false },
	high = { name = "high", sweep = true, fade = true, edge = true, settle = true, result = true },
}

Model.GLYPHS = {
	success = "Interface\\RAIDFRAME\\ReadyCheck-Ready",
	interrupted = "Interface\\RAIDFRAME\\ReadyCheck-NotReady",
	cancelled = "Interface\\RAIDFRAME\\ReadyCheck-Waiting",
}

local function clamp(value)
	if value < 0 then return 0 end
	if value > 1 then return 1 end
	return value
end

local function lerp(from, to, t)
	return from + (to - from) * t
end

function Model.Tier(quality)
	return Model.TIERS[quality] or Model.TIERS.normal
end

function Model.Appear(tier, age)
	if not tier.fade then return 1, 1 end
	local alpha = clamp(age / APPEAR_TIME)
	if not tier.settle then return alpha, 1 end
	local t = clamp(age / SETTLE_TIME)
	if t < SETTLE_SPLIT then
		return alpha, lerp(SETTLE_FROM, SETTLE_PEAK, t / SETTLE_SPLIT)
	end
	return alpha, lerp(SETTLE_PEAK, 1, (t - SETTLE_SPLIT) / (1 - SETTLE_SPLIT))
end

function Model.Result(tier, status, age)
	if not tier.result or age < 0 then return 1, 0 end
	if status == "success" then
		local t = age / PULSE_TIME
		if t >= 1 then return 1, 0 end
		return 1 + (PULSE_PEAK - 1) * math.sin(math.pi * t), 0
	end
	if status == "interrupted" then
		local t = age / SHAKE_TIME
		if t >= 1 then return 1, 0 end
		return 1, SHAKE_PIXELS * (1 - t) * math.sin(2 * math.pi * SHAKE_CYCLES * t)
	end
	return 1, 0
end

function Model.Edge(tier, position, length)
	if not tier.edge or length <= 0 then return 1 end
	local fade = length * EDGE_FADE
	local start = length - fade
	if position <= start then return 1 end
	return clamp((length - position) / fade)
end

function Model.GapText(seconds)
	if seconds < 10 then return string.format("%.1fs", seconds) end
	if seconds < 60 then return string.format("%ds", seconds) end
	return string.format("%dm%02ds", seconds / 60, seconds % 60)
end

function Model.StackKey(unit, spellID)
	if type(spellID) ~= "number" then return nil end
	return unit .. ":" .. spellID
end

function Model.StackText(count)
	if not count or count < 2 then return nil end
	return "x" .. count
end

SA_CastFeedModel = Model
