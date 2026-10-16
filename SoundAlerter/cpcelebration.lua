local Celebration = {}

local math_sin = math.sin
local math_cos = math.cos
local math_pi = math.pi
local math_random = math.random
local math_max = math.max
local math_min = math.min
local math_abs = math.abs
local math_floor = math.floor
local table_remove = table.remove
local wipe = wipe

local TWO_PI = math_pi * 2
local MAX = 5

local TEXTURE_DIR = "Interface\\AddOns\\SoundAlerter\\Textures\\"
local DOT = TEXTURE_DIR .. "circle"
local RING = TEXTURE_DIR .. "cp_ring"
local STAR = TEXTURE_DIR .. "cp_star"
local GLOW = TEXTURE_DIR .. "cp_glow"
local FLAT = "Interface\\Buttons\\WHITE8X8"

local GOLD = { r = 1, g = 0.8, b = 0.2 }
local GREEN = { r = 0.2, g = 1, b = 0.2 }
local GREY = { r = 0.227, g = 0.263, b = 0.322 }
local PALE = { r = 1, g = 0.97, b = 0.75 }
local WHITE = { r = 1, g = 1, b = 1 }
local CYAN = { r = 0.42, g = 0.8, b = 1 }
local SMOKE = { r = 0.56, g = 0.59, b = 0.62 }
local ECHO_COLOR = { r = 1, g = 0.89, b = 0.54 }
local WAVE_COLOR = { r = 1, g = 0.78, b = 0.2 }
local EMBER_COLORS = { { r = 1, g = 0.54, b = 0.16 }, { r = 1, g = 0.82, b = 0.25 } }

local GAIN_POP = 0.4
local GAIN_POP_TIME = 0.26
local ECHO_DELAY = 0.14
local ECHO_GROUPS = { { 3 }, { 2, 4 }, { 1, 5 } }
local ARC_STEP = 0.09
local OUTLINE_THICKNESS = 3
local OUTLINE_PAD_X = 14
local OUTLINE_PAD_Y = 9
local OUTLINE_BREATH = 2.1
local REEL_WIDTH = 40
local REEL_HEIGHT = 46
local REEL_FONT_SIZE = 34
local REEL_GAP = 12

local TIERS = {
	low = { particles = 0.35, extras = false, sparks = 0, rings = false, patterns = 2, segments = 3, breathe = false, spin = false },
	normal = { particles = 1, extras = true, sparks = 5, rings = true, patterns = 4, segments = 5, breathe = true, spin = true },
	high = { particles = 1.8, extras = true, sparks = 12, rings = true, patterns = 6, segments = 6, breathe = true, spin = true },
}

local QUALITIES = {
	{ "low", "Low" },
	{ "normal", "Normal" },
	{ "high", "High" },
}

local ORDER = {
	{ "classic", "Classic wave" },
	{ "ripple", "Centre-out echo" },
	{ "shockwave", "Shockwave burst" },
	{ "filament", "Charge filament" },
	{ "ember", "Ember aura" },
	{ "lightning", "Lightning arcs" },
	{ "star", "Merge into star" },
	{ "counter", "Slot reel" },
	{ "none", "None" },
}

local STYLES = {}

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function smooth(t)
	return t * t * (3 - 2 * t)
end

local function rotate(texture, angle)
	if texture.SetRotation then texture:SetRotation(angle) end
end

local function maxColor(fx)
	return fx.colors.comboMax or GOLD
end

local function activeColor(fx)
	return fx.colors.comboActive or GREEN
end

local function inactiveColor(fx)
	return fx.colors.comboInactive or GREY
end

local function scaled(fx, count)
	return math_max(1, math_floor(count * fx.tier.particles + 0.5))
end

local function metrics(fx)
	fx.size = fx.pips[1]:GetWidth()
	fx.step = fx.size + fx.spacing
end

local function drive(layer, elapsed)
	local fx = layer.fx
	local anims = fx.anims
	local i = 1
	while i <= #anims do
		local anim = anims[i]
		anim.t = anim.t + elapsed
		if anim.t >= anim.dur then
			anim.update(1)
			if anim.done then anim.done() end
			anims[i] = anims[#anims]
			anims[#anims] = nil
		else
			if anim.t >= 0 then anim.update(anim.t / anim.dur) end
			i = i + 1
		end
	end
	for _, step in pairs(fx.loops) do
		step(elapsed)
	end
	if #anims == 0 and next(fx.loops) == nil then
		layer:SetScript("OnUpdate", nil)
	end
end

local function wake(fx)
	fx.layer:SetScript("OnUpdate", drive)
end

local function run(fx, delay, duration, update, done)
	fx.anims[#fx.anims + 1] = { t = -delay, dur = duration, update = update, done = done }
	wake(fx)
end

local function later(fx, delay, action)
	run(fx, delay, 0.0001, function() end, action)
end

local function loop(fx, name, update)
	fx.loops[name] = update
	wake(fx)
end

local function take(fx, path, blend)
	local texture = table_remove(fx.pool)
	if not texture then
		texture = fx.layer:CreateTexture(nil, "OVERLAY")
	end
	texture:SetTexture(path)
	texture:SetBlendMode(blend or "ADD")
	texture:SetVertexColor(1, 1, 1, 1)
	texture:SetAlpha(1)
	rotate(texture, 0)
	texture:ClearAllPoints()
	texture:Show()
	fx.live[texture] = true
	return texture
end

local function give(fx, texture)
	if not fx.live[texture] then return end
	fx.live[texture] = nil
	texture:Hide()
	fx.pool[#fx.pool + 1] = texture
end

local function place(fx, texture, x, y, width, height)
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", fx.origin, "CENTER", x, y)
	texture:SetSize(width, height or width)
end

local function color(texture, c, alpha)
	texture:SetVertexColor(c.r, c.g, c.b, alpha or 1)
end

local function pipX(fx, index)
	return (index - 3) * fx.step
end

local function own(fx, region)
	fx.persistent[#fx.persistent + 1] = region
	return region
end

local function ownTexture(fx, path, blend)
	local texture = fx.layer:CreateTexture(nil, "OVERLAY")
	texture:SetTexture(path)
	texture:SetBlendMode(blend or "ADD")
	texture:SetAlpha(1)
	texture:Hide()
	return own(fx, texture)
end

local function newGroup(region, looping)
	local group = region:CreateAnimationGroup()
	group:SetLooping(looping)
	return group
end

local function alphaAnimation(group, order, from, to, duration, delay)
	local animation = group:CreateAnimation("Alpha")
	animation:SetOrder(order)
	animation:SetFromAlpha(from)
	animation:SetToAlpha(to)
	animation:SetDuration(duration)
	if delay then animation:SetStartDelay(delay) end
	return animation
end

local function scaleAnimation(group, order, from, to, duration)
	local animation = group:CreateAnimation("Scale")
	animation:SetOrder(order)
	animation:SetDuration(duration)
	if animation.SetScaleFrom then
		animation:SetScaleFrom(from, from)
		animation:SetScaleTo(to, to)
	else
		animation:SetScale(to / from, to / from)
	end
	return animation
end

local function translateAnimation(group, order, dx, dy, duration)
	local animation = group:CreateAnimation("Translation")
	animation:SetOrder(order)
	animation:SetOffset(dx, dy)
	animation:SetDuration(duration)
	return animation
end

local function rotateAnimation(group, order, degrees, duration)
	local animation = group:CreateAnimation("Rotation")
	animation:SetOrder(order)
	animation:SetDegrees(degrees)
	animation:SetDuration(duration)
	return animation
end

local function playGroup(fx, group)
	group:Play()
	fx.groups[#fx.groups + 1] = group
end

local function stopGroups(fx)
	for i = #fx.groups, 1, -1 do
		fx.groups[i]:Stop()
		fx.groups[i] = nil
	end
end

local function releaseLive(fx)
	for texture in pairs(fx.live) do
		texture:Hide()
		fx.pool[#fx.pool + 1] = texture
	end
	wipe(fx.live)
end

local function restPips(fx)
	for i = 1, MAX do
		local pip = fx.pips[i]
		pip:SetScale(1)
		pip:SetAlpha(1)
	end
end

local function restoreShake(fx)
	if fx.shaken then
		fx.pips[1]:SetPoint("LEFT", fx.frame, "LEFT", fx.inset, 0)
		fx.shaken = false
	end
end

local function clearTransient(fx)
	wipe(fx.anims)
	releaseLive(fx)
	restPips(fx)
	restoreShake(fx)
	if fx.maxText then fx.maxText:Hide() end
end

local function litPips(fx, from, to)
	local c = maxColor(fx)
	for i = from, to do
		fx.pips[i].texture:SetVertexColor(c.r, c.g, c.b, 1)
	end
end

local function settlePip(fx, i, cp)
	local pip = fx.pips[i]
	pip:SetScale(1)
	pip:SetAlpha(1)
	local c = inactiveColor(fx)
	if i <= cp then c = cp == MAX and maxColor(fx) or activeColor(fx) end
	pip.texture:SetVertexColor(c.r, c.g, c.b, 1)
end

local function pipExit(fx, i, next, delay, duration, update)
	local pip = fx.pips[i]
	run(fx, delay, duration, function(p)
		if update then update(pip, p) end
	end, function() settlePip(fx, i, next) end)
end

local function beginExit(fx, next)
	clearTransient(fx)
	fx.exiting = true
	litPips(fx, next + 1, MAX)
end

local function finishExit(fx, delay, next)
	later(fx, delay, function()
		Celebration:Reset(fx)
		local definition = STYLES[fx.style]
		if definition and definition.settle then definition.settle(fx, next) end
	end)
end

local function pop(fx, index, delay, duration, amount)
	local pip = fx.pips[index]
	run(fx, delay, duration, function(p)
		pip:SetScale(p >= 1 and 1 or 1 + math_sin(p * math_pi) * amount)
	end)
end

local function drop(fx, index, delay)
	local pip = fx.pips[index]
	run(fx, delay, 0.2, function(p)
		pip:SetScale(1 - 0.7 * p)
		pip:SetAlpha(1 - 0.8 * p)
	end, function()
		pip:SetScale(1)
		pip:SetAlpha(1)
	end)
end

local function gain(fx, prev, next, amount)
	for i = prev + 1, next do
		pop(fx, i, (i - prev - 1) * 0.07, GAIN_POP_TIME, amount or GAIN_POP)
	end
end

local function partialDrop(fx, prev, next)
	for i = prev, next + 1, -1 do
		drop(fx, i, (prev - i) * 0.055)
	end
end

local function expand(fx, path, x, y, from, to, duration, delay, c)
	local texture = take(fx, path, "ADD")
	color(texture, c)
	run(fx, delay, duration, function(p)
		place(fx, texture, x, y, lerp(from, to, p))
		texture:SetAlpha(1 - p)
	end, function() give(fx, texture) end)
end

local function contract(fx, path, x, y, from, to, duration, delay, c)
	local texture = take(fx, path, "ADD")
	color(texture, c)
	texture:SetAlpha(0)
	run(fx, delay, duration, function(p)
		place(fx, texture, x, y, lerp(from, to, p * p))
		texture:SetAlpha(p < 0.2 and p / 0.2 * 0.9 or 0.9 * (1 - (p - 0.2) / 0.8))
	end, function() give(fx, texture) end)
end

local function barWidth(fx)
	return (MAX - 1) * fx.step + fx.size
end

local function flash(fx, c, peak, duration, padX, padY)
	local texture = take(fx, FLAT, "ADD")
	color(texture, c)
	place(fx, texture, 0, 0, barWidth(fx) + padX, fx.size + padY)
	run(fx, 0, duration, function(p)
		texture:SetAlpha(peak * (1 - p))
	end, function() give(fx, texture) end)
end

local function spark(fx, x, y, drift, life, size, c, rise)
	local texture = take(fx, GLOW, "ADD")
	color(texture, c)
	run(fx, 0, life, function(p)
		place(fx, texture, x + drift * p, y + rise * p, size)
		texture:SetAlpha(p < 0.15 and p / 0.15 or 1 - (p - 0.15) / 0.85)
	end, function() give(fx, texture) end)
end

local function maxText(fx)
	local text = fx.maxText
	if not text then
		text = fx.layer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		fx.maxText = text
		own(fx, text)
	end
	local c = maxColor(fx)
	text:SetText("MAX")
	text:SetTextColor(c.r, c.g, c.b, 1)
	text:Show()
	local base = -fx.size * 1.1
	run(fx, 0, 0.9, function(p)
		text:ClearAllPoints()
		text:SetPoint("CENTER", fx.origin, "CENTER", 0, base + 14 * p)
		text:SetAlpha(p < 0.25 and p / 0.25 or 1 - (p - 0.25) / 0.75)
	end, function() text:Hide() end)
end

local function shake(fx, duration, power)
	local first = fx.pips[1]
	fx.shaken = true
	run(fx, 0, duration, function(p)
		local k = (1 - p) * power
		first:SetPoint("LEFT", fx.frame, "LEFT", fx.inset + (math_random() * 2 - 1) * k, (math_random() * 2 - 1) * k)
	end, function()
		first:SetPoint("LEFT", fx.frame, "LEFT", fx.inset, 0)
		fx.shaken = false
	end)
end

local function shatter(fx, index, c)
	local x = pipX(fx, index)
	for _ = 1, scaled(fx, 5) do
		local angle = math_random() * TWO_PI
		local distance = 30 + math_random() * 40
		local dx, dy = math_cos(angle) * distance, math_sin(angle) * distance
		local texture = take(fx, DOT, "ADD")
		color(texture, c)
		run(fx, 0, 0.45 + math_random() * 0.15, function(p)
			place(fx, texture, x + dx * p, dy * p, 8 * (1 - 0.8 * p))
			texture:SetAlpha(1 - p)
		end, function() give(fx, texture) end)
	end
end

STYLES.none = {
	change = function() end,
}

STYLES.classic = {
	change = function(fx, prev, next)
		if next > prev then
			if next < MAX then
				gain(fx, prev, next, 0.25)
			else
				for i = 1, MAX do
					local delay = (i - 1) * 0.08
					pop(fx, i, delay, 0.4, 0.25)
					local texture = take(fx, GLOW, "ADD")
					color(texture, WAVE_COLOR)
					texture:SetAlpha(0)
					run(fx, delay, 0.4, function(p)
						place(fx, texture, pipX(fx, i), 0, fx.size * 2.3)
						texture:SetAlpha(0.9 * math_sin(p * math_pi))
					end, function() give(fx, texture) end)
					expand(fx, RING, pipX(fx, i), 0, fx.size, fx.size * 2.4, 0.4, delay, WAVE_COLOR)
				end
			end
		else
			partialDrop(fx, prev, next)
		end
	end,
	exit = function(fx, next, kind)
		beginExit(fx, next)
		local lit = maxColor(fx)
		for i = next + 1, MAX do
			if kind == "spent" then
				pipExit(fx, i, next, (i - next - 1) * 0.07, 0.2, function(pip, p)
					local k = math_sin(p * math_pi)
					pip.texture:SetVertexColor(lerp(lit.r, 1, k), lerp(lit.g, 1, k), lerp(lit.b, 1, k), 1)
				end)
			else
				pipExit(fx, i, next, 0, 0.45, function(pip, p)
					pip:SetAlpha(1 - 0.85 * p)
				end)
			end
		end
		finishExit(fx, 0.85, next)
	end,
}

STYLES.ripple = {
	change = function(fx, prev, next)
		if next > prev then
			gain(fx, prev, next, 0.45)
			if next == MAX then
				for step, group in ipairs(ECHO_GROUPS) do
					if step == 1 or fx.tier.extras then
						local delay = (step - 1) * ECHO_DELAY
						for _, i in ipairs(group) do
							pop(fx, i, delay, 0.3, 0.5)
						end
						expand(fx, RING, 0, 0, fx.size, fx.size * (3 + (step - 1) * 1.6), 0.52, delay, ECHO_COLOR)
					end
				end
			end
		else
			partialDrop(fx, prev, next)
		end
	end,
	exit = function(fx, next, kind)
		beginExit(fx, next)
		local lit = maxColor(fx)
		for i = next + 1, MAX do
			if kind == "spent" then
				pipExit(fx, i, next, math_abs(i - 3) * 0.11, 0.2, function(pip, p)
					pip:SetScale(1 + 0.5 * p)
					pip:SetAlpha(1 - p)
				end)
			else
				local rank = (i == 1 or i == 5) and 0 or (i == 3 and 2 or 1)
				pipExit(fx, i, next, rank * 0.14, 0.3, function(pip, p)
					local k = 1 - 0.5 * p
					pip.texture:SetVertexColor(lit.r * k, lit.g * k, lit.b * k, 1)
					pip:SetAlpha(1 - 0.9 * p)
				end)
			end
		end
		if kind == "spent" then
			for step = 0, 2 do
				if step == 0 or fx.tier.extras then
					expand(fx, RING, 0, 0, fx.size, fx.size * (3 + step * 1.4), 0.42, step * 0.11, ECHO_COLOR)
				end
			end
		end
		finishExit(fx, 0.8, next)
	end,
}

STYLES.shockwave = {
	change = function(fx, prev, next)
		if next > prev then
			gain(fx, prev, next, 0.3)
			if next == MAX then
				local last = pipX(fx, MAX)
				expand(fx, GLOW, last, 0, 40, 160, 0.45, 0, PALE)
				expand(fx, RING, last, 0, 44, 140, 0.55, 0, maxColor(fx))
				if fx.tier.extras then
					expand(fx, RING, 0, 0, 60, 190, 0.7, 0.09, PALE)
					shake(fx, 0.26, 4)
					maxText(fx)
				end
			end
		else
			local c = prev == MAX and maxColor(fx) or activeColor(fx)
			for i = next + 1, prev do
				shatter(fx, i, c)
			end
		end
	end,
	exit = function(fx, next, kind)
		beginExit(fx, next)
		if kind == "spent" then
			contract(fx, RING, 0, 0, fx.size * 9.4, fx.size * 1.1, 0.42, 0, GOLD)
			for i = next + 1, MAX do
				pipExit(fx, i, next, 0, 0.38, function(pip, p)
					pip:SetScale(1 - 0.6 * p)
					pip:SetAlpha(1 - 0.7 * p)
				end)
			end
			local texture = take(fx, GLOW, "ADD")
			color(texture, PALE)
			texture:SetAlpha(0)
			run(fx, 0.38, 0.3, function(p)
				place(fx, texture, 0, 0, 90 * lerp(0.4, 1.8, p))
				texture:SetAlpha(math_sin(p * math_pi))
			end, function() give(fx, texture) end)
			finishExit(fx, 0.9, next)
		else
			local c = maxColor(fx)
			for i = next + 1, MAX do
				shatter(fx, i, c)
				settlePip(fx, i, next)
			end
			finishExit(fx, 0.9, next)
		end
	end,
}

local function filamentParts(fx)
	if fx.track then return end
	local frame = fx.frame
	fx.track = own(fx, frame:CreateTexture(nil, "BACKGROUND"))
	fx.track:SetTexture(FLAT)
	fx.track:SetVertexColor(0.227, 0.263, 0.322, 1)
	fx.track:SetHeight(4)
	fx.track:SetPoint("LEFT", fx.pips[1], "CENTER", 0, 0)
	fx.track:SetPoint("RIGHT", fx.pips[MAX], "CENTER", 0, 0)
	fx.fill = own(fx, frame:CreateTexture(nil, "ARTWORK"))
	fx.fill:SetTexture(FLAT)
	fx.fill:SetHeight(4)
	fx.fill:SetPoint("LEFT", fx.pips[1], "CENTER", 0, 0)
	fx.outlineFrame = own(fx, CreateFrame("Frame", nil, fx.layer))
	fx.outlineFrame:SetAllPoints(fx.layer)
	fx.glowFrame = own(fx, CreateFrame("Frame", nil, frame))
	fx.glowFrame:SetAllPoints(frame)
	fx.glowFrame:SetFrameLevel(frame:GetFrameLevel())
	fx.outline = {}
	for _, name in ipairs({ "top", "bottom", "left", "right" }) do
		local edge = fx.outlineFrame:CreateTexture(nil, "OVERLAY")
		edge:SetTexture(FLAT)
		fx.outline[name] = edge
	end
	fx.outline.glow = fx.glowFrame:CreateTexture(nil, "BACKGROUND")
	fx.outline.glow:SetTexture(GLOW)
	fx.outline.glow:SetBlendMode("ADD")
	fx.fillNow = 0
	fx.outlineGroup = newGroup(fx.outlineFrame, "BOUNCE")
	alphaAnimation(fx.outlineGroup, 1, 1, 0.65, OUTLINE_BREATH / 2)
	fx.glowGroup = newGroup(fx.glowFrame, "BOUNCE")
	alphaAnimation(fx.glowGroup, 1, 1, 0.65, OUTLINE_BREATH / 2)
end

local function fillTarget(fx, cp)
	return cp <= 1 and 0 or (cp - 1) * fx.step
end

local function paintFill(fx, cp)
	local c = cp == MAX and maxColor(fx) or activeColor(fx)
	fx.fill:SetVertexColor(c.r, c.g, c.b, 1)
	fx.fill:SetWidth(math_max(fx.fillNow, 0.001))
	fx.fill:SetShown(fx.fillNow > 0.5)
end

local function chaseFill(fx, cp)
	local target = fillTarget(fx, cp)
	loop(fx, "fill", function(elapsed)
		fx.fillNow = fx.fillNow + (target - fx.fillNow) * math_min(1, elapsed * 14)
		if math_abs(target - fx.fillNow) < 0.5 then
			fx.fillNow = target
			fx.loops.fill = nil
		end
		paintFill(fx, cp)
	end)
end

local function drawOutline(fx, reveal, grow, alpha)
	grow = grow or 1
	alpha = alpha or 1
	local parts = fx.outline
	local c = maxColor(fx)
	local width = (barWidth(fx) + OUTLINE_PAD_X * 2) * grow
	local height = (fx.size + OUTLINE_PAD_Y * 2) * grow
	local half = reveal * width
	local sides = math_max(0, (reveal - 0.85) / 0.15) * alpha
	fx.outlineFrame:Show()
	fx.glowFrame:Show()
	for _, name in ipairs({ "top", "bottom", "left", "right" }) do
		parts[name]:SetVertexColor(c.r, c.g, c.b, 1)
		parts[name]:Show()
	end
	parts.glow:SetVertexColor(c.r, c.g, c.b, 1)
	parts.glow:Show()
	place(fx, parts.top, 0, height / 2, half, OUTLINE_THICKNESS)
	place(fx, parts.bottom, 0, -height / 2, half, OUTLINE_THICKNESS)
	place(fx, parts.left, -width / 2, 0, OUTLINE_THICKNESS, height)
	place(fx, parts.right, width / 2, 0, OUTLINE_THICKNESS, height)
	place(fx, parts.glow, 0, 0, width + 40, height + 40)
	parts.left:SetAlpha(sides)
	parts.right:SetAlpha(sides)
	parts.top:SetAlpha(alpha)
	parts.bottom:SetAlpha(alpha)
	parts.glow:SetAlpha(0.5 * reveal * alpha)
end

local function hideOutline(fx)
	fx.outlineFrame:Hide()
	fx.glowFrame:Hide()
end

local function breatheOutline(fx)
	if not fx.tier.breathe then return end
	playGroup(fx, fx.outlineGroup)
	playGroup(fx, fx.glowGroup)
end

STYLES.filament = {
	prepare = function(fx)
		filamentParts(fx)
	end,
	settle = function(fx, cp)
		fx.track:Show()
		fx.fillNow = fillTarget(fx, cp)
		paintFill(fx, cp)
		if cp == MAX then
			drawOutline(fx, 1)
			breatheOutline(fx)
		end
	end,
	change = function(fx, prev, next)
		fx.track:Show()
		chaseFill(fx, next)
		if next > prev then
			if next < MAX then
				gain(fx, prev, next, GAIN_POP)
			else
				run(fx, 0, 0.38, function(p)
					drawOutline(fx, smooth(p))
				end, function() breatheOutline(fx) end)
				for i = 1, MAX do
					pop(fx, i, (i - 1) * 0.04, 0.26, 0.3)
				end
			end
		else
			partialDrop(fx, prev, next)
			local texture = take(fx, FLAT, "ADD")
			place(fx, texture, 0, 0, barWidth(fx), 6)
			run(fx, 0, 0.3, function(p)
				texture:SetAlpha(1 - p)
			end, function() give(fx, texture) end)
		end
	end,
	exit = function(fx, next, kind)
		beginExit(fx, next)
		stopGroups(fx)
		fx.track:Show()
		chaseFill(fx, next)
		drawOutline(fx, 1)
		if kind == "spent" then
			local orb = take(fx, GLOW, "ADD")
			color(orb, WHITE)
			local from, to = pipX(fx, 1), pipX(fx, MAX) + 18
			run(fx, 0, 0.3, function(p)
				place(fx, orb, lerp(from, to, p * p), 0, 18)
				orb:SetAlpha(p > 0.9 and (1 - p) * 10 or 1)
			end, function() give(fx, orb) end)
			run(fx, 0, 0.32, function(p)
				drawOutline(fx, 1, 1 + 0.15 * p, 1 - p)
			end, function() hideOutline(fx) end)
			expand(fx, RING, pipX(fx, MAX), 0, 30, 90, 0.4, 0.28, WHITE)
			for i = next + 1, MAX do
				pipExit(fx, i, next, 0.28, 0.001)
			end
		else
			local width = barWidth(fx) + OUTLINE_PAD_X * 2
			local height = fx.size + OUTLINE_PAD_Y * 2
			local parts = fx.outline
			run(fx, 0, 0.52, function(p)
				place(fx, parts.top, 0, height / 2 + 14 * p, width, OUTLINE_THICKNESS)
				place(fx, parts.bottom, 0, -height / 2 - 14 * p, width, OUTLINE_THICKNESS)
				parts.top:SetAlpha(1 - p)
				parts.bottom:SetAlpha(1 - p)
				parts.left:SetAlpha(math_max(0, 1 - 2 * p))
				parts.right:SetAlpha(math_max(0, 1 - 2 * p))
				parts.glow:SetAlpha(0.5 * (1 - p))
			end, function() hideOutline(fx) end)
			for i = next + 1, MAX do
				pipExit(fx, i, next, 0.2, 0.001)
			end
		end
		finishExit(fx, 0.7, next)
	end,
}

local function prepareEmber(fx)
	local tier = fx.tier
	local e = fx.ember
	if not e then
		e = { halos = {}, rings = {}, sparks = {} }
		fx.ember = e
	end
	for i = 1, MAX do
		if not e.halos[i] then
			local halo = ownTexture(fx, GLOW, "ADD")
			halo:SetVertexColor(1, 0.5, 0.14, 1)
			local group = newGroup(halo, "BOUNCE")
			alphaAnimation(group, 1, 0.2, 0.9, 1.05)
			e.halos[i] = { texture = halo, group = group }
		end
		if tier.rings and not e.rings[i] then
			local ring = ownTexture(fx, RING, "ADD")
			ring:SetVertexColor(1, 0.69, 0.18, 1)
			local group = newGroup(ring, "REPEAT")
			scaleAnimation(group, 1, 1, 2.6, 1.25)
			alphaAnimation(group, 1, 0.9, 0, 1.25)
			e.rings[i] = { texture = ring, group = group }
		end
	end
	for k = #e.sparks + 1, tier.sparks do
		local texture = ownTexture(fx, GLOW, "ADD")
		local c = EMBER_COLORS[(k % 2) + 1]
		texture:SetVertexColor(c.r, c.g, c.b, 1)
		local life = 1 + (k % 4) * 0.2
		local group = newGroup(texture, "REPEAT")
		translateAnimation(group, 1, math_random(-8, 8), 70, life)
		alphaAnimation(group, 1, 0, 1, life * 0.15)
		alphaAnimation(group, 1, 1, 0, life * 0.85, life * 0.15)
		e.sparks[k] = { texture = texture, group = group, column = ((k - 1) % MAX) + 1, offset = math_random(-5, 5) }
	end
end

local function startEmber(fx)
	local e = fx.ember
	local tier = fx.tier
	for i = 1, MAX do
		local halo = e.halos[i]
		place(fx, halo.texture, pipX(fx, i), 0, fx.size * 2.65)
		halo.texture:Show()
		later(fx, (i - 1) * 0.18, function() playGroup(fx, halo.group) end)
		local ring = e.rings[i]
		if tier.rings and ring then
			place(fx, ring.texture, pipX(fx, i), 0, fx.size)
			ring.texture:Show()
			later(fx, (i - 1) * 0.25, function() playGroup(fx, ring.group) end)
		end
	end
	for k = 1, tier.sparks do
		local s = e.sparks[k]
		place(fx, s.texture, pipX(fx, s.column) + s.offset, -2, 12)
		s.texture:Show()
		later(fx, (k - 1) * 0.11, function() playGroup(fx, s.group) end)
	end
end

local function emberHalos(fx, update, duration)
	local e = fx.ember
	for i = 1, MAX do e.halos[i].texture:Show() end
	local function step(p)
		local scale, alpha = update(p)
		for i = 1, MAX do
			place(fx, e.halos[i].texture, pipX(fx, i), 0, fx.size * 2.65 * scale)
			e.halos[i].texture:SetAlpha(alpha)
		end
	end
	step(0)
	run(fx, 0, duration, step)
end

local function hideEmberSparks(fx)
	local sparks = fx.ember.sparks
	for k = 1, #sparks do
		sparks[k].texture:Hide()
	end
end

local function fadeEmberRings(fx, duration)
	local e = fx.ember
	for i = 1, MAX do
		local ring = e.rings[i]
		if ring then
			local texture = ring.texture
			texture:Show()
			texture:SetAlpha(0.5)
			run(fx, 0, duration, function(p) texture:SetAlpha(0.5 * (1 - p)) end)
		end
	end
end

STYLES.ember = {
	prepare = prepareEmber,
	settle = function(fx, cp)
		if cp == MAX then startEmber(fx) end
	end,
	change = function(fx, prev, next)
		if next > prev then
			gain(fx, prev, next, GAIN_POP)
			if next == MAX then startEmber(fx) end
		else
			partialDrop(fx, prev, next)
		end
	end,
	exit = function(fx, next, kind)
		beginExit(fx, next)
		stopGroups(fx)
		hideEmberSparks(fx)
		if kind == "spent" then
			emberHalos(fx, function(p)
				if p < 0.35 then return lerp(1, 2, p / 0.35), lerp(0.7, 1, p / 0.35) end
				return lerp(2, 2.6, (p - 0.35) / 0.65), lerp(1, 0, (p - 0.35) / 0.65)
			end, 0.52)
			fadeEmberRings(fx, 0.2)
			later(fx, 0.15, function()
				for i = 1, MAX do
					for k = 1, scaled(fx, 6) do
						spark(fx, pipX(fx, i) + math_random(-5, 5), 0, math_random(-20, 20), 0.6 + math_random() * 0.3, 6, EMBER_COLORS[(k % 2) + 1], 70 + math_random() * 50)
					end
				end
			end)
			for i = next + 1, MAX do
				pipExit(fx, i, next, 0.12, 0.001)
			end
			finishExit(fx, 0.95, next)
		else
			emberHalos(fx, function(p) return lerp(1, 0.2, p), lerp(0.7, 0, p) end, 0.6)
			fadeEmberRings(fx, 0.25)
			for i = 1, MAX do
				for k = 1, scaled(fx, 2) do
					later(fx, (k - 1) * 0.2, function()
						spark(fx, pipX(fx, i) + math_random(-6, 6), 0, 0, 1.1, 9, SMOKE, 40)
					end)
				end
			end
			for i = next + 1, MAX do
				pipExit(fx, i, next, 0.35, 0.001)
			end
			finishExit(fx, 1.5, next)
		end
	end,
}

local function patternGroup(frame, index, count)
	local cache = frame.groups
	if not cache then
		cache = {}
		frame.groups = cache
	end
	local group = cache[count]
	if group then return group end
	group = newGroup(frame, "REPEAT")
	local order = 0
	if index > 1 then
		order = order + 1
		alphaAnimation(group, order, 0, 0, (index - 1) * ARC_STEP)
	end
	order = order + 1
	alphaAnimation(group, order, 1, 1, ARC_STEP)
	if index < count then
		order = order + 1
		alphaAnimation(group, order, 0, 0, (count - index) * ARC_STEP)
	end
	cache[count] = group
	return group
end

local function buildBolt(fx, frame, x1, x2, segments, thickness, c, jitter)
	local px, py = x1, 0
	for s = 1, segments do
		local nx = x1 + (x2 - x1) * s / segments
		local ny = s == segments and 0 or (math_random() * 2 - 1) * jitter
		local line = frame:CreateLine(nil, "OVERLAY")
		line:SetTexture(FLAT)
		line:SetThickness(thickness)
		line:SetVertexColor(c.r, c.g, c.b, 1)
		line:SetStartPoint("CENTER", fx.origin, px, py)
		line:SetEndPoint("CENTER", fx.origin, nx, ny)
		px, py = nx, ny
	end
end

local function arcFrame(fx)
	local frame = CreateFrame("Frame", nil, fx.layer)
	frame:SetAllPoints(fx.layer)
	frame:Hide()
	return own(fx, frame)
end

local function prepareArcs(fx)
	local tier = fx.tier
	local a = fx.arcs
	if not a then
		a = { sets = {} }
		fx.arcs = a
		a.burst = arcFrame(fx)
		for i = 1, MAX - 1 do
			buildBolt(fx, a.burst, pipX(fx, i), pipX(fx, i + 1), 4, 6, WHITE, 8)
		end
	end
	local set = a.sets[tier.segments]
	if not set then
		set = {}
		a.sets[tier.segments] = set
	end
	for k = #set + 1, tier.patterns do
		local frame = arcFrame(fx)
		for i = 1, MAX - 1 do
			if math_random() < 0.8 then
				buildBolt(fx, frame, pipX(fx, i), pipX(fx, i + 1), tier.segments, 2.5, math_random() < 0.3 and PALE or CYAN, 13)
			end
		end
		set[k] = frame
	end
end

local function startArcs(fx)
	local tier = fx.tier
	local set = fx.arcs.sets[tier.segments]
	for k = 1, tier.patterns do
		local frame = set[k]
		frame:SetAlpha(1)
		frame:Show()
		playGroup(fx, patternGroup(frame, k, tier.patterns))
	end
end

STYLES.lightning = {
	prepare = prepareArcs,
	settle = function(fx, cp)
		if cp == MAX then startArcs(fx) end
	end,
	change = function(fx, prev, next)
		if next > prev then
			gain(fx, prev, next, GAIN_POP)
			if next == MAX then
				if fx.tier.extras then flash(fx, CYAN, 0.5, 0.2, 20, 20) end
				startArcs(fx)
			end
		else
			partialDrop(fx, prev, next)
		end
	end,
	exit = function(fx, next, kind)
		beginExit(fx, next)
		stopGroups(fx)
		local set = fx.arcs.sets[fx.tier.segments]
		for k = 1, fx.tier.patterns do
			set[k]:Hide()
		end
		if kind == "spent" then
			fx.arcs.burst:Show()
			flash(fx, CYAN, 0.8, 0.2, 20, 20)
			later(fx, 0.17, function() fx.arcs.burst:Hide() end)
			for i = next + 1, MAX do
				pipExit(fx, i, next, 0, 0.001)
			end
			finishExit(fx, 0.4, next)
		else
			local frame = set[1]
			frame:SetAlpha(1)
			frame:Show()
			run(fx, 0, 0.5, function(p) frame:SetAlpha(1 - p) end, function() frame:Hide() end)
			for i = next + 1, MAX do
				pipExit(fx, i, next, 0.25, 0.001)
			end
			finishExit(fx, 0.6, next)
		end
	end,
}

local function prepareStar(fx)
	if fx.starTexture then return end
	local star = ownTexture(fx, STAR, "BLEND")
	fx.starTexture = star
	fx.starGroup = newGroup(star, "REPEAT")
	rotateAnimation(fx.starGroup, 1, -360, 3)
end

local function showStar(fx, size, alpha)
	local star = fx.starTexture
	color(star, maxColor(fx))
	place(fx, star, 0, 0, size)
	star:SetAlpha(alpha)
	rotate(star, 0)
	star:Show()
	return star
end

local function spinStar(fx)
	if fx.tier.spin then playGroup(fx, fx.starGroup) end
end

local function merge(fx)
	local size = fx.size
	local c = maxColor(fx)
	for i = 1, MAX do
		local pip = fx.pips[i]
		local ghost = take(fx, pip.texture:GetTexture() or DOT, "BLEND")
		color(ghost, c)
		local x0 = pipX(fx, i)
		pip:SetAlpha(0)
		run(fx, 0, 0.34, function(p)
			local k = smooth(p)
			place(fx, ghost, lerp(x0, 0, k), 0, lerp(size, size * 0.5, k))
		end, function() give(fx, ghost) end)
	end
	later(fx, 0.34, function()
		showStar(fx, 64 * 2.4, 0)
		run(fx, 0, 0.3, function(p)
			place(fx, fx.starTexture, 0, 0, 64 * lerp(2.4, 1, smooth(p)))
			fx.starTexture:SetAlpha(p)
		end, function() spinStar(fx) end)
		expand(fx, RING, 0, 0, 50, 160, 0.5, 0, maxColor(fx))
	end)
end

STYLES.star = {
	prepare = prepareStar,
	settle = function(fx, cp)
		if cp == MAX then
			for i = 1, MAX do fx.pips[i]:SetAlpha(0) end
			showStar(fx, 64, 1)
			spinStar(fx)
		end
	end,
	change = function(fx, prev, next)
		if next > prev then
			if next < MAX then
				gain(fx, prev, next, GAIN_POP)
			else
				merge(fx)
			end
		else
			partialDrop(fx, prev, next)
		end
	end,
	exit = function(fx, next, kind)
		beginExit(fx, next)
		stopGroups(fx)
		local star = showStar(fx, 64, 1)
		for i = 1, MAX do settlePip(fx, i, next) end
		if kind == "spent" then
			run(fx, 0, 0.3, function(p)
				place(fx, star, 0, 0, 64 * lerp(1, 2.4, p))
				star:SetAlpha(1 - p)
			end)
			flash(fx, WHITE, 0.7, 0.26, 20, 20)
			expand(fx, RING, 0, 0, 60, 300, 0.5, 0, WHITE)
			if fx.tier.extras then expand(fx, RING, 0, 0, 60, 420, 0.65, 0.08, maxColor(fx)) end
			for _ = 1, scaled(fx, 14) do
				local angle = math_random() * TWO_PI
				local distance = 50 + math_random() * 60
				spark(fx, 0, 0, math_cos(angle) * distance, 0.5 + math_random() * 0.3, 6, maxColor(fx), math_sin(angle) * distance)
			end
			finishExit(fx, 0.85, next)
		else
			run(fx, 0, 0.6, function(p)
				local k = p * p
				place(fx, star, 0, -60 * k, 64)
				rotate(star, 2.1 * k)
				star:SetAlpha(1 - k)
			end)
			finishExit(fx, 0.7, next)
		end
	end,
}

local function reelParts(fx)
	if fx.reel then return end
	local layer = fx.layer
	fx.reelBorder = own(fx, layer:CreateTexture(nil, "BACKGROUND"))
	fx.reelBorder:SetTexture(FLAT)
	fx.reelBorder:SetVertexColor(0.79, 0.54, 0.06, 1)
	fx.reelBorder:SetSize(REEL_WIDTH + 4, REEL_HEIGHT + 4)
	fx.reelBack = own(fx, layer:CreateTexture(nil, "ARTWORK"))
	fx.reelBack:SetTexture(FLAT)
	fx.reelBack:SetVertexColor(0.07, 0.05, 0.01, 1)
	fx.reelBack:SetSize(REEL_WIDTH, REEL_HEIGHT)
	fx.reel = own(fx, CreateFrame("Frame", nil, layer))
	fx.reel:SetSize(REEL_WIDTH, REEL_HEIGHT)
	fx.reel:SetClipsChildren(true)
	fx.digits = {}
	for value = 0, MAX do
		local digit = fx.reel:CreateFontString(nil, "OVERLAY")
		digit:SetFont(STANDARD_TEXT_FONT, REEL_FONT_SIZE, "OUTLINE")
		digit:SetText(value)
		fx.digits[value] = digit
	end
	fx.reelBorder:SetPoint("BOTTOM", fx.origin, "TOP", 0, REEL_GAP - 2)
	fx.reelBack:SetPoint("BOTTOM", fx.origin, "TOP", 0, REEL_GAP)
	fx.reel:SetPoint("BOTTOM", fx.origin, "TOP", 0, REEL_GAP)
	fx.reelS = 0
end

local function layoutReel(fx, scroll)
	fx.reelS = scroll
	for value = 0, MAX do
		fx.digits[value]:SetPoint("CENTER", fx.reel, "CENTER", 0, (scroll - value) * REEL_HEIGHT)
	end
end

local function showReel(fx)
	local lit, dim = maxColor(fx), activeColor(fx)
	for value = 0, MAX do
		local c = value == MAX and lit or dim
		fx.digits[value]:SetTextColor(c.r, c.g, c.b, 1)
	end
	fx.reelBorder:SetAlpha(1)
	fx.reelBack:SetAlpha(1)
	fx.reel:SetAlpha(1)
	fx.reelBorder:Show()
	fx.reelBack:Show()
	fx.reel:Show()
end

local function scrollTo(fx, target, duration)
	local from = fx.reelS
	if from == target then return end
	local rising = target > from
	duration = duration or (rising and (0.25 + 0.13 * (target - from)) or 0.25)
	local clock = 0
	loop(fx, "reel", function(elapsed)
		clock = clock + elapsed
		local p = math_min(1, clock / duration)
		local value
		if not rising then
			value = lerp(from, target, 1 - (1 - p) ^ 3)
		elseif p < 0.8 then
			value = lerp(from, target + 0.22, 1 - (1 - p / 0.8) ^ 3)
		elseif p < 0.9 then
			value = lerp(target + 0.22, target - 0.13, (p - 0.8) / 0.1)
		else
			value = lerp(target - 0.13, target, (p - 0.9) / 0.1)
		end
		layoutReel(fx, value)
		if p >= 1 then
			layoutReel(fx, target)
			fx.loops.reel = nil
		end
	end)
end

local function reelFrame(fx, gap, widthScale, heightScale)
	local width, height = REEL_WIDTH * widthScale, REEL_HEIGHT * heightScale
	fx.reelBorder:ClearAllPoints()
	fx.reelBorder:SetPoint("BOTTOM", fx.origin, "TOP", 0, gap - 2)
	fx.reelBorder:SetSize(width + 4, height + 4)
	fx.reelBack:ClearAllPoints()
	fx.reelBack:SetPoint("BOTTOM", fx.origin, "TOP", 0, gap)
	fx.reelBack:SetSize(width, height)
	fx.reel:ClearAllPoints()
	fx.reel:SetPoint("BOTTOM", fx.origin, "TOP", 0, gap)
	fx.reel:SetSize(width, height)
end

local function reelCentre(fx)
	return fx.size / 2 + REEL_GAP + REEL_HEIGHT / 2
end

STYLES.counter = {
	prepare = reelParts,
	settle = function(fx, cp)
		showReel(fx)
		layoutReel(fx, cp)
	end,
	change = function(fx, prev, next)
		showReel(fx)
		scrollTo(fx, next)
		if next > prev then
			if next < MAX then
				gain(fx, prev, next, GAIN_POP)
			else
				for i = 1, MAX do
					pop(fx, i, 0.5 + (i - 1) * 0.04, 0.26, 0.3)
				end
			end
		else
			partialDrop(fx, prev, next)
		end
	end,
	exit = function(fx, next, kind)
		beginExit(fx, next)
		showReel(fx)
		for i = next + 1, MAX do
			pipExit(fx, i, next, 0, 0.001)
		end
		if kind == "spent" then
			run(fx, 0, 0.3, function(p)
				local k = math_sin(p * math_pi)
				reelFrame(fx, REEL_GAP - 8 * k, 1 + 0.12 * k, 1 - 0.15 * k)
			end, function() reelFrame(fx, REEL_GAP, 1, 1) end)
			later(fx, 0.15, function() scrollTo(fx, next, 0.09) end)
			local glow = take(fx, GLOW, "ADD")
			color(glow, maxColor(fx))
			glow:SetAlpha(0)
			local y = reelCentre(fx)
			run(fx, 0, 0.36, function(p)
				place(fx, glow, 0, y, 70)
				glow:SetAlpha(p < 0.3 and p / 0.3 or 1 - (p - 0.3) / 0.7)
			end, function() give(fx, glow) end)
			later(fx, 0.12, function()
				for _ = 1, scaled(fx, 8) do
					spark(fx, 0, y, math_random(-40, 40), 0.5, 5, maxColor(fx), math_random(-10, 30))
				end
			end)
			later(fx, 0.5, function() fx.exiting = false end)
		else
			run(fx, 0, 0.5, function(p)
				fx.reelBorder:SetAlpha(1 - p)
				fx.reelBack:SetAlpha(1 - p)
				fx.reel:SetAlpha(1 - p)
			end, function()
				fx.reelBorder:Hide()
				fx.reelBack:Hide()
				fx.reel:Hide()
				fx.exiting = false
			end)
			scrollTo(fx, next, 0.25)
		end
	end,
}

function Celebration:Create(frame, pips, spacing, colors)
	local layer = CreateFrame("Frame", nil, frame)
	layer:SetAllPoints(frame)
	layer:SetFrameLevel(frame:GetFrameLevel() + 20)
	local fx = {
		frame = frame,
		layer = layer,
		pips = pips,
		origin = pips[3],
		spacing = spacing,
		colors = colors,
		size = pips[1]:GetWidth(),
		step = pips[1]:GetWidth() + spacing,
		inset = 10,
		style = "classic",
		quality = "normal",
		tier = TIERS.normal,
		anims = {},
		loops = {},
		pool = {},
		live = {},
		groups = {},
		persistent = {},
		exiting = false,
	}
	layer.fx = fx
	return fx
end

function Celebration:SetInset(fx, inset)
	fx.inset = inset
end

function Celebration:Styles()
	return ORDER
end

function Celebration:Qualities()
	return QUALITIES
end

function Celebration:Normalize(style)
	if STYLES[style] then return style end
	return "classic"
end

function Celebration:NormalizeQuality(quality)
	if TIERS[quality] then return quality end
	return "normal"
end

function Celebration:IsCustom(style)
	return STYLES[style] ~= nil
end

function Celebration:Reset(fx)
	wipe(fx.anims)
	wipe(fx.loops)
	fx.layer:SetScript("OnUpdate", nil)
	stopGroups(fx)
	releaseLive(fx)
	for i = 1, #fx.persistent do
		fx.persistent[i]:Hide()
	end
	restPips(fx)
	restoreShake(fx)
	fx.exiting = false
end

function Celebration:Apply(fx, style, cp, quality)
	self:Reset(fx)
	quality = self:NormalizeQuality(quality)
	fx.quality = quality
	fx.tier = TIERS[quality]
	if style == "lightning" and not fx.layer.CreateLine then
		style = "shockwave"
	end
	fx.style = style
	metrics(fx)
	local definition = STYLES[style]
	if definition then
		if definition.prepare then definition.prepare(fx) end
		if definition.settle then definition.settle(fx, cp) end
	end
end

function Celebration:Change(fx, prev, next, kind)
	local definition = STYLES[fx.style]
	if not definition then return end
	metrics(fx)
	if fx.exiting then self:Reset(fx) end
	if next < prev and prev == MAX and definition.exit then
		definition.exit(fx, next, kind or "lost")
		return
	end
	if next < prev then self:Reset(fx) end
	definition.change(fx, prev, next, kind)
end

SoundAlerter.CPCelebration = Celebration
