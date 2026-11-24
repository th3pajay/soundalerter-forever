local FX = {}

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_rad = math.rad
local math_cos = math.cos
local TWO_PI = math.pi * 2
local SCALE_STEPS = 32

local FLAT = "Interface\\Buttons\\WHITE8X8"
local RING = "Interface\\AddOns\\SoundAlerter\\Textures\\border_ring.tga"
local SHINE = "Interface\\AddOns\\SoundAlerter\\Textures\\sp_shine"

local AMBER = { 1, 0.78, 0.24 }
local RED = { 1, 0.3, 0.25 }
local WHITE = { 1, 1, 1 }
local GREEN = { 0.24, 0.86, 0.52 }
local WARN_BORDER = { 1, 0.35, 0.3 }
local WARN_TEXT = { 1, 0.48, 0.42 }
local TINT = { 1, 0.16, 0.1, 0.55 }

local SHIFT_STEPS = 16
local TINT_TIME = 3
local THROB_TIME = 0.25
local THROB_SCALE = 1.35
local EXIT_TIME = 0.24
local EXIT_SCALE = 0.4
local IDLE_FADE_TIME = 0.25
local SHINE_ANGLE = 20
local SHINE_WIDTH = 0.4
local SHINE_HEIGHT = 1.6

local TIERS = {
	off = { name = "off", off = true, rings = 0, popTime = 0, throb = false, shiftBorder = false, shines = 0, shineTime = 0, throttle = 0.1 },
	low = { name = "low", rings = 0, popTime = 0.18, throb = false, shiftBorder = false, shines = 1, shineTime = 0.3, throttle = 0.1 },
	normal = { name = "normal", rings = 1, popTime = 0.26, throb = true, shiftBorder = true, shines = 1, shineTime = 0.42, throttle = 0.05 },
	high = { name = "high", rings = 2, popTime = 0.26, throb = true, shiftBorder = true, shines = 2, shineTime = 0.42, throttle = 0 },
}

local QUALITIES = {
	{ "off", "Off" },
	{ "low", "Low" },
	{ "normal", "Normal" },
	{ "high", "High" },
}

FX.TIERS = TIERS
FX.QUALITIES = QUALITIES
FX.quality = "normal"
FX.tier = TIERS.normal
FX.SHIFT_STEPS = SHIFT_STEPS

function FX.Normalize(quality)
	if TIERS[quality] then return quality end
	return "normal"
end

function FX:SetQuality(quality)
	self.quality = self.Normalize(quality)
	self.tier = TIERS[self.quality]
	return self.quality
end

local function clamp(value)
	return math_max(0, math_min(1, value))
end

local function blend(from, to, t)
	return from[1] + (to[1] - from[1]) * t, from[2] + (to[2] - from[2]) * t, from[3] + (to[3] - from[3]) * t
end

function FX.ShiftStep(progress)
	return math_min(SHIFT_STEPS, math_floor(clamp(progress) * SHIFT_STEPS))
end

function FX.ShiftColor(base, progress)
	local p = clamp(progress)
	if p < 0.5 then
		return blend(base, AMBER, p / 0.5)
	end
	return blend(AMBER, RED, (p - 0.5) / 0.5)
end

local function alphaAnimation(group, order, from, to, duration)
	local animation = group:CreateAnimation("Alpha")
	animation:SetOrder(order)
	animation:SetFromAlpha(from)
	animation:SetToAlpha(to)
	animation:SetDuration(duration)
	return animation
end

local function scaleAnimation(group, order, from, to, duration, smoothing)
	local animation = group:CreateAnimation("Scale")
	animation:SetOrder(order)
	animation:SetDuration(duration)
	if animation.SetScaleFrom then
		animation:SetScaleFrom(from, from)
		animation:SetScaleTo(to, to)
	else
		animation:SetScale(to / from, to / from)
	end
	if smoothing then animation:SetSmoothing(smoothing) end
	return animation
end

local function relativeScale(group, order, factor, duration, smoothing)
	local animation = group:CreateAnimation("Scale")
	animation:SetOrder(order)
	animation:SetDuration(duration)
	animation:SetScale(factor, factor)
	if smoothing then animation:SetSmoothing(smoothing) end
	return animation
end

local function setTextScale(text, value)
	value = math_floor(value * SCALE_STEPS + 0.5) / SCALE_STEPS
	if (text.saTextScale or 1) == value then return end
	text.saTextScale = value
	text:SetTextScale(value)
end

local function throbUpdate(animation, elapsed)
	local throttle = FX.tier.throttle
	if throttle > 0 then
		local waited = animation.waited + elapsed
		if waited < throttle then
			animation.waited = waited
			return
		end
		animation.waited = 0
	end
	setTextScale(animation.text, 1 + animation.peak * (1 - math_cos(animation:GetProgress() * TWO_PI)) * 0.5)
end

local function throbRest(group)
	group.beat.waited = 0
	setTextScale(group.text, 1)
end

local function textThrob(text, peak, beatTime)
	local group = text:CreateAnimationGroup()
	group:SetLooping("REPEAT")
	local beat = group:CreateAnimation("Animation")
	beat.text, beat.peak, beat.waited = text, peak, 0
	group.text, group.beat = text, beat
	beat:SetDuration(beatTime * 2)
	beat:SetScript("OnUpdate", throbUpdate)
	group:SetScript("OnStop", throbRest)
	return group
end

local function stateFor(frame)
	local state = frame.fx
	if not state then
		state = { active = {} }
		frame.fx = state
	end
	return state
end

local function setFor(frame)
	local state = stateFor(frame)
	local set = state.set
	if not set then
		set = { rings = {}, shines = {} }
		state.set = set
	end
	return state, set
end

local function play(state, group)
	group:Stop()
	group:Play()
	if not group.tracked then
		group.tracked = true
		state.active[#state.active + 1] = group
	end
end

local function ring(frame, state, set, key, color, delay, scale)
	local entry = set.rings[key]
	if not entry then
		local texture = frame:CreateTexture(nil, "OVERLAY")
		texture:SetTexture(RING)
		texture:SetBlendMode("ADD")
		texture:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
		texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
		texture:Hide()
		local group = texture:CreateAnimationGroup()
		local order = 1
		if delay > 0 then
			alphaAnimation(group, order, 0, 0, delay)
			order = order + 1
		end
		alphaAnimation(group, order, 0.9, 0, 0.42)
		scaleAnimation(group, order, 1, scale, 0.42, "OUT")
		group:SetScript("OnFinished", function() texture:Hide() end)
		entry = { frame = texture, group = group }
		set.rings[key] = entry
	end
	entry.frame:SetVertexColor(color[1], color[2], color[3], 1)
	entry.frame:Show()
	play(state, entry.group)
end

function FX:Appear(frame)
	local tier = self.tier
	if tier.off then return end
	local state, set = setFor(frame)

	local pop = set.pop
	if not pop then
		local fadeGroup = frame:CreateAnimationGroup()
		local group = frame.texture:CreateAnimationGroup()
		pop = {
			fadeGroup = fadeGroup,
			group = group,
			fade = alphaAnimation(fadeGroup, 1, 0, 1, 0),
			rise = scaleAnimation(group, 1, 0.4, 1.14, 0, "OUT"),
			settle = scaleAnimation(group, 2, 1.14, 1, 0),
		}
		set.pop = pop
	end
	pop.fade:SetDuration(tier.popTime * 0.65)
	pop.rise:SetDuration(tier.popTime * 0.65)
	pop.settle:SetDuration(tier.popTime * 0.35)
	play(state, pop.fadeGroup)
	play(state, pop.group)

	if tier.rings >= 1 then
		ring(frame, state, set, "pop1", WHITE, 0.12, 1.7)
	end
	if tier.rings >= 2 then
		ring(frame, state, set, "pop2", GREEN, 0.2, 2.1)
	end
end

function FX:BorderShift(frame, remaining)
	if self.tier.off then return end
	local duration, base = frame.shiftDuration, frame.shiftBase
	if not duration or not base or duration <= 0 then return end

	local step = self.ShiftStep(1 - remaining / duration)
	if step == frame.shiftStep then return end
	frame.shiftStep = step

	local r, g, b = self.ShiftColor(base, step / SHIFT_STEPS)
	local swipe = frame.borderCooldown
	if swipe then swipe:SetSwipeColor(r, g, b, 1) end
	if self.tier.shiftBorder and frame.glowKey ~= "expiring" then
		frame:SetBackdropBorderColor(r, g, b, 1)
	end
end

function FX:Warn(frame)
	local tier = self.tier

	frame:SetBackdropBorderColor(WARN_BORDER[1], WARN_BORDER[2], WARN_BORDER[3], 1)
	frame.timerText:SetTextColor(WARN_TEXT[1], WARN_TEXT[2], WARN_TEXT[3], 1)
	if tier.off then return end
	local state, set = setFor(frame)

	local tint = set.tint
	if not tint then
		local texture = frame:CreateTexture(nil, "ARTWORK", nil, 1)
		texture:SetAllPoints(frame.texture)
		texture:SetTexture(FLAT)
		texture:SetVertexColor(TINT[1], TINT[2], TINT[3], TINT[4])
		texture:Hide()
		local group = texture:CreateAnimationGroup()
		group:SetToFinalAlpha(true)
		alphaAnimation(group, 1, 0, 1, TINT_TIME)
		tint = { texture = texture, group = group }
		set.tint = tint
	end
	tint.texture:Show()
	play(state, tint.group)

	if tier.throb then
		local throb = set.throb
		if not throb then
			throb = textThrob(frame.timerText, THROB_SCALE - 1, THROB_TIME)
			set.throb = throb
		end
		play(state, throb)
	end
end

function FX:ClearWarn(frame)
	local set = frame.fx and frame.fx.set
	if set then
		if set.tint then
			set.tint.group:Stop()
			set.tint.texture:Hide()
		end
		if set.throb then
			set.throb:Stop()
			setTextScale(frame.timerText, 1)
		end
	end
	frame.timerText:SetTextColor(WHITE[1], WHITE[2], WHITE[3], 1)
	frame.shiftStep = nil
	local base = frame.baseBorder
	if base then frame:SetBackdropBorderColor(base[1], base[2], base[3], 1) end
end

function FX:Shine(frame)
	local tier = self.tier
	if tier.off then return end
	local state, set = setFor(frame)

	if not state.clip then
		local clip = CreateFrame("Frame", nil, frame)
		clip:SetAllPoints(frame.texture)
		clip:SetClipsChildren(true)
		state.clip = clip
	end

	local size = frame.iconSize or 48
	local width = size * SHINE_WIDTH
	for i = 1, tier.shines do
		local entry = set.shines[i]
		if not entry then
			local texture = state.clip:CreateTexture(nil, "OVERLAY")
			texture:SetTexture(SHINE)
			texture:SetBlendMode("ADD")
			if texture.SetRotation then texture:SetRotation(math_rad(SHINE_ANGLE)) end
			texture:Hide()
			local group = texture:CreateAnimationGroup()
			local slide = group:CreateAnimation("Translation")
			slide:SetOrder(1)
			slide:SetSmoothing("IN_OUT")
			if i > 1 then slide:SetStartDelay(0.11) end
			group:SetScript("OnFinished", function() texture:Hide() end)
			entry = { texture = texture, group = group, slide = slide }
			set.shines[i] = entry
		end
		local shineWidth = i == 1 and width or width * 0.5
		entry.texture:ClearAllPoints()
		entry.texture:SetSize(shineWidth, size * SHINE_HEIGHT)
		entry.texture:SetPoint("LEFT", state.clip, "LEFT", -shineWidth, 0)
		entry.slide:SetOffset(size + shineWidth * 2, 0)
		entry.slide:SetDuration(tier.shineTime)
		entry.texture:Show()
		play(state, entry.group)
	end
end

function FX:Exit(frame, idleAlpha, done)
	if self.tier.off then return nil end
	local state, set = setFor(frame)
	local hiding = idleAlpha <= 0

	local group = hiding and set.exitHide or set.exitIdle
	if not group then
		group = frame:CreateAnimationGroup()
		group:SetToFinalAlpha(true)
		group:SetScript("OnFinished", function()
			local callback = state.exitDone
			state.exitDone = nil
			if callback then callback() end
		end)
		if hiding then
			alphaAnimation(group, 1, 1, 0, EXIT_TIME)
			relativeScale(group, 1, EXIT_SCALE, EXIT_TIME, "IN")
			set.exitHide = group
		else
			set.idleFade = alphaAnimation(group, 1, 1, idleAlpha, IDLE_FADE_TIME)
			set.exitIdle = group
		end
	end
	if not hiding then set.idleFade:SetToAlpha(idleAlpha) end

	state.exitDone = done
	play(state, group)
	return true
end

function FX:CancelExit(frame)
	local state = frame.fx
	if not state then return end
	state.exitDone = nil
	local set = state.set
	if set then
		if set.exitHide then set.exitHide:Stop() end
		if set.exitIdle then set.exitIdle:Stop() end
	end
end

function FX:Rest(frame)
	local state = frame.fx
	if not state then return end

	state.exitDone = nil
	local active = state.active
	for i = #active, 1, -1 do
		active[i]:Stop()
		active[i].tracked = false
		active[i] = nil
	end

	local set = state.set
	if set then
		for _, entry in pairs(set.rings) do entry.frame:Hide() end
		for _, entry in pairs(set.shines) do entry.texture:Hide() end
		if set.tint then set.tint.texture:Hide() end
	end

	frame.timerText:SetTextColor(WHITE[1], WHITE[2], WHITE[3], 1)
	frame.shiftStep = nil
end

SA_TrackerFX = FX

SA_Pulse = {}

do
	local Pulse = SA_Pulse
	local TEX = "Interface\\AddOns\\SoundAlerter\\Textures\\pulse\\"
	local BASE = 64
	local PRE = 0.01
	local QUEUE = 4
	local ROW = 3
	local ROW_GAP = 1.15
	local CROP = 0.08
	local ipairs, math_max = ipairs, math.max

	Pulse.IN = {
		{ id = "fade", name = "Fade", e = "OUT", k = { { t = 0, a = 0 }, { t = 1, a = 1 } } },
		{ id = "zoom", name = "Zoom", e = "OUT", k = { { t = 0, a = 0, s = .4 }, { t = 1, a = 1, s = 1 } } },
		{ id = "slam", name = "Slam", e = "IN", k = { { t = 0, a = 0, s = 1.35 }, { t = .75, a = 1, s = .96 }, { t = 1, s = 1 } } },
		{ id = "pop", name = "Pop", e = "OUT", k = { { t = 0, a = 0, s = .5 }, { t = .6, a = 1, s = 1.1 }, { t = .82, s = .97 }, { t = 1, s = 1 } } },
		{ id = "elastic", name = "Elastic", e = "OUT", k = { { t = 0, a = 0, s = .3 }, { t = .42, a = 1, s = 1.14 }, { t = .62, s = .93 }, { t = .8, s = 1.03 }, { t = 1, s = 1 } } },
		{ id = "stamp", name = "Stamp", e = "IN", k = { { t = 0, a = 0, s = 1.4, r = 12 }, { t = .7, a = 1, s = .95, r = -2 }, { t = 1, s = 1, r = 0 } } },
		{ id = "drop", name = "Drop", e = "IN", k = { { t = 0, a = 0, y = .7 }, { t = .7, a = 1, y = -.08 }, { t = .86, y = .03 }, { t = 1, y = 0 } } },
		{ id = "rise", name = "Rise", e = "OUT", k = { { t = 0, a = 0, y = -.55 }, { t = 1, a = 1, y = 0 } } },
		{ id = "slideL", name = "Slide from left", e = "OUT", k = { { t = 0, a = 0, x = -.9 }, { t = 1, a = 1, x = 0 } } },
		{ id = "slideR", name = "Slide from right", e = "OUT", k = { { t = 0, a = 0, x = .9 }, { t = 1, a = 1, x = 0 } } },
		{ id = "spin", name = "Spin", e = "OUT", k = { { t = 0, a = 0, r = 200, s = .3 }, { t = 1, a = 1, r = 0, s = 1 } } },
		{ id = "flip", name = "Flip", e = "OUT", k = { { t = 0, a = 0, sx = .01, sy = 1 }, { t = .75, a = 1, sx = 1.08 }, { t = 1, sx = 1 } } },
		{ id = "unfold", name = "Unfold", e = "OUT", k = { { t = 0, a = 0, sx = 1, sy = .01 }, { t = .75, a = 1, sy = 1.08 }, { t = 1, sy = 1 } } },
		{ id = "blink", name = "Blink", e = "NONE", k = { { t = 0, a = 0 }, { t = .2, a = 1 }, { t = .4, a = .1 }, { t = .6, a = 1 }, { t = .8, a = .35 }, { t = 1, a = 1 } } },
	}

	Pulse.OUT = {
		{ id = "fade", name = "Fade", e = "IN", k = { { t = 0, a = 1 }, { t = 1, a = 0 } } },
		{ id = "grow", name = "Grow and fade", e = "OUT", k = { { t = 0, a = 1, s = 1 }, { t = 1, a = 0, s = 1.25 } } },
		{ id = "shrink", name = "Shrink", e = "IN", k = { { t = 0, a = 1, s = 1 }, { t = 1, a = 0, s = .3 } } },
		{ id = "popout", name = "Pop out", e = "IN", k = { { t = 0, a = 1, s = 1 }, { t = .35, s = 1.08 }, { t = 1, a = 0, s = .2 } } },
		{ id = "burst", name = "Burst", e = "OUT", ring = true, k = { { t = 0, a = 1, s = 1 }, { t = 1, a = 0, s = 1.2 } } },
		{ id = "riseaway", name = "Rise away", e = "IN", k = { { t = 0, a = 1, y = 0 }, { t = 1, a = 0, y = .6 } } },
		{ id = "sink", name = "Sink", e = "IN", k = { { t = 0, a = 1, y = 0 }, { t = 1, a = 0, y = -.5 } } },
		{ id = "slideL", name = "Slide left", e = "IN", k = { { t = 0, a = 1, x = 0 }, { t = 1, a = 0, x = -.9 } } },
		{ id = "slideR", name = "Slide right", e = "IN", k = { { t = 0, a = 1, x = 0 }, { t = 1, a = 0, x = .9 } } },
		{ id = "spin", name = "Spin away", e = "IN", k = { { t = 0, a = 1, r = 0, s = 1 }, { t = 1, a = 0, r = -200, s = .2 } } },
		{ id = "flip", name = "Flip", e = "IN", k = { { t = 0, a = 1, sx = 1, sy = 1 }, { t = 1, a = 0, sx = .01 } } },
		{ id = "fold", name = "Fold", e = "IN", k = { { t = 0, a = 1, sx = 1, sy = 1 }, { t = 1, a = 0, sy = .01 } } },
	}

	Pulse.HOLDS = { { id = "still", name = "Still" }, { id = "breathe", name = "Breathe" }, { id = "glow", name = "Glow" }, { id = "shine", name = "Shine" }, { id = "bob", name = "Bob" }, { id = "heart", name = "Heartbeat" } }
	Pulse.SHAPES = { { id = "square", name = "Square" }, { id = "rounded", name = "Rounded" }, { id = "circle", name = "Circle" }, { id = "hex", name = "Hexagon" }, { id = "octagon", name = "Octagon" }, { id = "diamond", name = "Diamond" } }
	Pulse.STYLES = {
		{ id = "none", name = "None" }, { id = "thin", name = "Thin" }, { id = "thick", name = "Thick" }, { id = "double", name = "Double" },
		{ id = "seg4", name = "4 segments" }, { id = "seg8", name = "8 segments" }, { id = "seg12", name = "12 segments" },
		{ id = "dotted", name = "Dotted" }, { id = "brackets", name = "Corner brackets" }, { id = "glow", name = "Soft glow" },
	}
	Pulse.BORDERS = {
		{ id = "none", name = "None" }, { id = "drawin", name = "Draw in" }, { id = "drain", name = "Drain" }, { id = "spin", name = "Spin" },
		{ id = "counter", name = "Counter spin" }, { id = "chase", name = "Chase light" }, { id = "hop", name = "Segment hop" }, { id = "pulse", name = "Pulse" },
		{ id = "breathe", name = "Breathe glow" }, { id = "ripple", name = "Ripple" }, { id = "flash", name = "Flash" }, { id = "cycle", name = "Colour cycle" },
	}
	Pulse.COLORS = { { id = "category", name = "By category" }, { id = "class", name = "Class colour" }, { id = "white", name = "White" }, { id = "gold", name = "Gold" } }
	Pulse.MODES = { { id = "queue", name = "One after another" }, { id = "replace", name = "Newest replaces" }, { id = "row", name = "Side by side (3)" } }
	Pulse.CATEGORY_COLORS = {
		class = { 1, .49, .04 }, charges = { 1, .83, .42 }, racial = { .78, .61, 1 }, pet = { .65, .89, .42 }, profession = { .85, .70, .55 },
		trinket = { .44, .83, 1 }, equipped = { .62, .70, .78 }, potion = { 1, .35, .35 }, healthstone = { .36, .86, .55 }, usable = { .78, .78, .78 },
	}
	local CYCLE = { { 1, .49, .04 }, { 1, .83, .42 }, { .78, .61, 1 }, { .65, .89, .42 }, { .44, .83, 1 }, { 1, .35, .35 } }
	local WHITE, GOLD = { 1, 1, 1 }, { 1, .82, .2 }
	local CLASS = { 1, 1, 1 }
	local HEART = { { t = 0, s = 1 }, { t = .15, s = 1.09 }, { t = .3, s = 1 }, { t = .45, s = 1.05 }, { t = .6, s = 1 }, { t = 1, s = 1 } }

	local function Find(list, id)
		for _, spec in ipairs(list) do if spec.id == id then return spec end end
		return list[1]
	end
	Pulse.Find = Find

	Pulse.stats = { pulses = 0, callbacks = 0, builds = 0 }
	local stats = Pulse.stats

	local function Anim(group, kind, order, duration, smooth)
		local anim = group:CreateAnimation(kind)
		anim:SetOrder(order)
		anim:SetDuration(duration)
		anim:SetSmoothing(smooth or "NONE")
		if kind == "Scale" or kind == "Rotation" then anim:SetOrigin("CENTER", 0, 0) end
		return anim
	end

	local function Hold(group, order, duration, a)
		local anim = Anim(group, "Alpha", order, duration, "NONE")
		anim:SetFromAlpha(a)
		anim:SetToAlpha(a)
		return anim
	end

	local PROPS = { "a", "sx", "sy", "x", "y", "r" }
	local DEFAULT = { a = 1, sx = 1, sy = 1, x = 0, y = 0, r = 0 }

	local function Normalize(keys)
		local out = {}
		for i, key in ipairs(keys) do
			out[i] = { t = key.t, a = key.a, x = key.x, y = key.y, r = key.r, sx = key.sx or key.s, sy = key.sy or key.s }
		end
		for _, prop in ipairs(PROPS) do
			if out[1][prop] == nil then out[1][prop] = DEFAULT[prop] end
			local last = 1
			for i = 2, #out do
				if out[i][prop] ~= nil then
					for j = last + 1, i - 1 do
						local span = out[i].t - out[last].t
						local f = span > 0 and (out[j].t - out[last].t) / span or 0
						out[j][prop] = out[last][prop] + (out[i][prop] - out[last][prop]) * f
					end
					last = i
				end
			end
			for j = last + 1, #out do out[j][prop] = out[last][prop] end
		end
		return out
	end
	Pulse.Normalize = Normalize

	local ENDS = { OUT = { false, true }, IN = { true, false }, IN_OUT = { true, true }, NONE = { false, false } }
	local EASE = { [true] = { [true] = "IN_OUT", [false] = "IN" }, [false] = { [true] = "OUT", [false] = "NONE" } }
	local SHAPED = { "sx", "sy", "x", "y", "r" }

	local function Stops(k, prop, smooth)
		local n, stops = #k, {}
		local ends = ENDS[smooth] or ENDS.NONE
		stops[1], stops[n] = ends[1], ends[2]
		for i = 2, n - 1 do
			stops[i] = (k[i][prop] - k[i - 1][prop]) * (k[i + 1][prop] - k[i][prop]) <= 0
		end
		return stops
	end

	local function Eases(k, smooth)
		if #k <= 2 then return nil end
		local eases = {}
		for _, prop in ipairs(SHAPED) do eases[prop] = Stops(k, prop, smooth) end
		return eases
	end
	Pulse.Eases = Eases

	local function Ease(eases, prop, i, smooth)
		if not eases then return smooth end
		local stops = eases[prop]
		return EASE[stops[i - 1]][stops[i]]
	end
	Pulse.Ease = Ease

	local function Scale(group, order, duration, smooth, chain, fx, fy, tx, ty)
		local sc = Anim(group, "Scale", order, duration, smooth)
		sc:SetScaleFrom(fx / chain.x, fy / chain.y)
		sc:SetScaleTo(tx / chain.x, ty / chain.y)
		chain.x, chain.y = tx, ty
	end

	local function Motion(group, keys, total, smooth, order, lead, px)
		local k = Normalize(keys)
		local eases = Eases(k, smooth)
		local k0 = k[1]
		local scaled = k0.sx ~= 1 or k0.sy ~= 1
		local chain = { x = 1, y = 1 }
		if lead then
			Hold(group, order, lead, k0.a)
			if scaled then Scale(group, order, lead, "NONE", chain, k0.sx, k0.sy, k0.sx, k0.sy) end
			order = order + 1
		end
		if k0.x ~= 0 or k0.y ~= 0 or k0.r ~= 0 or (scaled and not lead) then
			Hold(group, order, PRE, k0.a)
			if k0.x ~= 0 or k0.y ~= 0 then Anim(group, "Translation", order, PRE, "NONE"):SetOffset(k0.x * px, k0.y * px) end
			if scaled and not lead then Scale(group, order, PRE, "NONE", chain, k0.sx, k0.sy, k0.sx, k0.sy) end
			if k0.r ~= 0 then Anim(group, "Rotation", order, PRE, "NONE"):SetDegrees(k0.r) end
			order = order + 1
		end
		for i = 2, #k do
			local a, b = k[i - 1], k[i]
			local duration = (b.t - a.t) * total
			if duration > 0 then
				local any = false
				if a.a ~= b.a then
					local al = Anim(group, "Alpha", order, duration, "NONE")
					al:SetFromAlpha(a.a)
					al:SetToAlpha(b.a)
					any = true
				end
				if a.sx ~= b.sx or a.sy ~= b.sy then
					Scale(group, order, duration, Ease(eases, a.sx ~= b.sx and "sx" or "sy", i, smooth), chain, a.sx, a.sy, b.sx, b.sy)
					any = true
				end
				if a.x ~= b.x or a.y ~= b.y then
					Anim(group, "Translation", order, duration, Ease(eases, a.y ~= b.y and "y" or "x", i, smooth)):SetOffset((b.x - a.x) * px, (b.y - a.y) * px)
					any = true
				end
				if a.r ~= b.r then
					Anim(group, "Rotation", order, duration, Ease(eases, "r", i, smooth)):SetDegrees(b.r - a.r)
					any = true
				end
				if not any then Hold(group, order, duration, a.a) end
				order = order + 1
			end
		end
		return order
	end

	local function InFinished(group, requested)
		if requested then return end
		local icon = group.icon
		stats.callbacks = stats.callbacks + 1
		if icon.gHold then icon.gHold:Play() end
		icon.gOut:Play()
	end

	local function OutStarted(anim)
		local icon = anim.icon
		stats.callbacks = stats.callbacks + 1
		if icon.gBurst then icon.gBurst:Play() end
	end

	local function StopBorder(icon)
		local border = icon.border
		if border then for i = 1, #border do border[i]:Stop() end end
	end

	local function OutFinished(group, requested)
		if requested then return end
		local icon = group.icon
		stats.callbacks = stats.callbacks + 1
		if icon.gHold then icon.gHold:Stop() end
		StopBorder(icon)
		icon.frame:Hide()
		icon.busy = false
		if icon.label then icon.label:Hide() end
		if icon.onDone then icon.onDone(icon) end
	end

	local function SwipeDone(cooldown)
		stats.callbacks = stats.callbacks + 1
		local icon = cooldown.icon
		if icon.banim == "drawin" and icon.hasRing then icon.ring:Show() end
	end

	local function Tint(icon, c)
		local list = icon.tinted
		for i = 1, #list do list[i]:SetVertexColor(c[1], c[2], c[3]) end
		if icon.swipe then icon.swipe:SetSwipeColor(c[1], c[2], c[3], 1) end
	end

	local function CycleLoop(group)
		stats.callbacks = stats.callbacks + 1
		local icon = group.icon
		icon.cycle = icon.cycle % #CYCLE + 1
		Tint(icon, CYCLE[icon.cycle])
	end

	local function Tex(parent, layer, sub)
		return parent:CreateTexture(nil, layer, nil, sub or 0)
	end

	local function Layer(icon, key, make)
		local region = icon[key]
		if not region then
			region = make(icon.frame)
			icon[key] = region
		end
		return region
	end

	local function Toggle(region, on)
		if region then region:SetShown(on) end
	end

	function Pulse.New(parent)
		local holder = CreateFrame("Frame", nil, parent)
		holder:SetSize(BASE, BASE)
		local f = CreateFrame("Frame", nil, holder)
		f:SetSize(BASE, BASE)
		f:SetPoint("CENTER")
		f:Hide()
		local icon = { holder = holder, frame = f, tinted = {}, groups = {}, borders = {}, cycle = 1, busy = false }
		local art = Tex(f, "ARTWORK")
		art:SetAllPoints()
		art:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
		local mask = f:CreateMaskTexture()
		mask:SetAllPoints(art)
		art:AddMaskTexture(mask)
		icon.art, icon.mask = art, mask
		return icon
	end

	local function Cached(icon, key, build)
		local group = icon.groups[key]
		if not group then
			group = build()
			icon.groups[key] = group
			stats.builds = stats.builds + 1
		end
		return group
	end

	local function BuildIn(icon, cfg)
		local spec = Find(Pulse.IN, cfg.inA)
		return Cached(icon, "in:" .. spec.id .. ":" .. cfg.tin .. ":" .. cfg.size, function()
			local g = icon.frame:CreateAnimationGroup()
			g.icon = icon
			Motion(g, spec.k, cfg.tin, spec.e, 1, nil, cfg.size)
			g:SetScript("OnFinished", InFinished)
			return g
		end)
	end

	local function BuildOut(icon, cfg)
		local spec = Find(Pulse.OUT, cfg.outA)
		return Cached(icon, "out:" .. spec.id .. ":" .. cfg.thold .. ":" .. cfg.tout .. ":" .. cfg.size, function()
			local g = icon.frame:CreateAnimationGroup()
			g.icon = icon
			Motion(g, spec.k, cfg.tout, spec.e, 1, cfg.thold, cfg.size)
			local marker = Anim(g, "Translation", 2, PRE, "NONE")
			marker:SetOffset(0, 0)
			marker.icon = icon
			marker:SetScript("OnPlay", OutStarted)
			g:SetScript("OnFinished", OutFinished)
			return g
		end)
	end

	local function Looping(region, looping)
		local g = region:CreateAnimationGroup()
		g:SetLooping(looping)
		return g
	end

	local function BuildHold(icon, cfg)
		local hold = cfg.hold
		if hold == "breathe" then
			return Cached(icon, "hold:breathe", function()
				local g = Looping(icon.frame, "BOUNCE")
				local sc = Anim(g, "Scale", 1, .7, "IN_OUT")
				sc:SetScaleFrom(1, 1)
				sc:SetScaleTo(1.06, 1.06)
				return g
			end)
		elseif hold == "glow" then
			return Cached(icon, "hold:glow", function()
				local g = Looping(icon.halo, "BOUNCE")
				local al = Anim(g, "Alpha", 1, .55, "IN_OUT")
				al:SetFromAlpha(.2)
				al:SetToAlpha(1)
				return g
			end)
		elseif hold == "shine" then
			return Cached(icon, "hold:shine:" .. cfg.size, function()
				local g = Looping(icon.gleam, "REPEAT")
				Anim(g, "Translation", 1, 1.5, "IN_OUT"):SetOffset(cfg.size * 2, 0)
				Hold(g, 1, 1.5, .7)
				return g
			end)
		elseif hold == "bob" then
			return Cached(icon, "hold:bob:" .. cfg.size, function()
				local g = Looping(icon.frame, "BOUNCE")
				Anim(g, "Translation", 1, .45, "IN_OUT"):SetOffset(0, cfg.size * .07)
				return g
			end)
		elseif hold == "heart" then
			return Cached(icon, "hold:heart", function()
				local g = Looping(icon.frame, "REPEAT")
				Motion(g, HEART, 1.1, "OUT", 1, nil, 1)
				return g
			end)
		end
		return nil
	end

	local function BuildBurst(icon, cfg)
		return Cached(icon, "burst:" .. cfg.tout, function()
			local g = icon.ripple:CreateAnimationGroup()
			local sc = Anim(g, "Scale", 1, cfg.tout + .15, "OUT")
			sc:SetScaleFrom(1, 1)
			sc:SetScaleTo(1.4, 1.4)
			local al = Anim(g, "Alpha", 1, cfg.tout + .15, "OUT")
			al:SetFromAlpha(1)
			al:SetToAlpha(0)
			return g
		end)
	end

	local function Spin(region, seconds, degrees)
		local g = Looping(region, "REPEAT")
		Anim(g, "Rotation", 1, seconds, "NONE"):SetDegrees(degrees)
		return g
	end

	local function BuildBorder(icon, cfg)
		local banim = cfg.banim
		local key = banim .. ":" .. cfg.tin
		local list = icon.borders[key]
		if list then return list end
		list = {}
		stats.builds = stats.builds + 1
		if banim == "spin" then
			list[1] = Spin(icon.frame, 4, -360)
		elseif banim == "counter" then
			list[1] = Spin(icon.frame, 3.6, -360)
			list[2] = Spin(icon.inner, 1.5, 720)
		elseif banim == "chase" then
			list[1] = Spin(icon.chase, 1.3, -360)
		elseif banim == "hop" then
			local g = Looping(icon.chase, "REPEAT")
			for step = 1, 8 do
				local r = Anim(g, "Rotation", step, .001, "NONE")
				r:SetDegrees(-45)
				r:SetStartDelay(.149)
			end
			list[1] = g
		elseif banim == "pulse" then
			local g = Looping(icon.ring, "BOUNCE")
			local al = Anim(g, "Alpha", 1, .5, "IN_OUT")
			al:SetFromAlpha(1)
			al:SetToAlpha(.25)
			list[1] = g
		elseif banim == "breathe" then
			local g = Looping(icon.halo, "BOUNCE")
			local al = Anim(g, "Alpha", 1, .7, "IN_OUT")
			al:SetFromAlpha(.15)
			al:SetToAlpha(.95)
			list[1] = g
		elseif banim == "ripple" then
			local g = Looping(icon.ripple, "REPEAT")
			local sc = Anim(g, "Scale", 1, 1, "OUT")
			sc:SetScaleFrom(1, 1)
			sc:SetScaleTo(1.3, 1.3)
			local al = Anim(g, "Alpha", 1, 1, "OUT")
			al:SetFromAlpha(.9)
			al:SetToAlpha(0)
			list[1] = g
		elseif banim == "flash" then
			local g = icon.flash:CreateAnimationGroup()
			local al = Anim(g, "Alpha", 1, .55, "OUT")
			al:SetFromAlpha(1)
			al:SetToAlpha(0)
			al:SetStartDelay(cfg.tin * .6)
			list[1] = g
		elseif banim == "cycle" then
			local g = Looping(icon.frame, "REPEAT")
			Anim(g, "Translation", 1, .5, "NONE"):SetOffset(0, 0)
			g.icon = icon
			g:SetScript("OnLoop", CycleLoop)
			list[1] = g
		end
		icon.borders[key] = list
		return list
	end

	function Pulse.Apply(icon, cfg)
		local shape, style, banim = cfg.shape, cfg.style, cfg.banim
		local ringStyle = (style == "none" or style == "glow") and "thin" or style
		local ringFile = TEX .. "ring_" .. shape .. "_" .. ringStyle
		icon.banim = banim
		icon.mask:SetTexture(TEX .. "mask_" .. shape, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		local tinted = icon.tinted
		for i = #tinted, 1, -1 do tinted[i] = nil end

		local needHalo = style == "glow" or cfg.hold == "glow" or banim == "breathe"
		if needHalo then
			local halo = Layer(icon, "halo", function(parent)
				local t = Tex(parent, "BACKGROUND")
				t:SetPoint("CENTER")
				return t
			end)
			halo:SetTexture(TEX .. "glow_" .. shape)
			halo:SetAlpha(style == "glow" and .95 or 0)
			tinted[#tinted + 1] = halo
		end
		Toggle(icon.halo, needHalo)

		local hasRing = style ~= "none" and style ~= "glow"
		if hasRing or banim == "pulse" or banim == "drawin" or banim == "drain" then
			local ring = Layer(icon, "ring", function(parent)
				local t = Tex(parent, "OVERLAY")
				t:SetAllPoints()
				return t
			end)
			ring:SetTexture(ringFile)
			ring:SetAlpha(1)
			tinted[#tinted + 1] = ring
		end
		Toggle(icon.ring, hasRing)
		icon.hasRing = hasRing

		local counter = banim == "counter"
		if counter then
			local inner = Layer(icon, "inner", function(parent)
				local t = Tex(parent, "OVERLAY", 1)
				t:SetPoint("CENTER")
				return t
			end)
			inner:SetTexture(TEX .. "ring_" .. shape .. "_seg12")
			inner:SetAlpha(.7)
			tinted[#tinted + 1] = inner
		end
		Toggle(icon.inner, counter)

		local chasing = banim == "chase" or banim == "hop"
		if chasing then
			local chase = Layer(icon, "chase", function(parent)
				local t = Tex(parent, "OVERLAY", 2)
				t:SetAllPoints()
				t:SetBlendMode("ADD")
				local m = parent:CreateMaskTexture()
				m:SetAllPoints(parent)
				t:AddMaskTexture(m)
				icon.chaseMask = m
				return t
			end)
			chase:SetTexture(TEX .. (banim == "chase" and "comet" or "wedge"))
			icon.chaseMask:SetTexture(ringFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		end
		Toggle(icon.chase, chasing)

		local outSpec = Find(Pulse.OUT, cfg.outA)
		local rippling = banim == "ripple" or outSpec.ring == true
		if rippling then
			local ripple = Layer(icon, "ripple", function(parent)
				local t = Tex(parent, "OVERLAY", 1)
				t:SetAllPoints()
				t:SetAlpha(0)
				return t
			end)
			ripple:SetTexture(ringFile)
			tinted[#tinted + 1] = ripple
		end
		Toggle(icon.ripple, rippling)

		local flashing = banim == "flash"
		if flashing then
			local flash = Layer(icon, "flash", function(parent)
				local t = Tex(parent, "OVERLAY", 3)
				t:SetAllPoints()
				t:SetBlendMode("ADD")
				t:SetAlpha(0)
				return t
			end)
			flash:SetTexture(ringFile)
		end
		Toggle(icon.flash, flashing)

		local shining = cfg.hold == "shine"
		if shining then
			Layer(icon, "gleam", function(parent)
				local clip = CreateFrame("Frame", nil, parent)
				clip:SetAllPoints()
				clip:SetClipsChildren(true)
				local t = Tex(clip, "ARTWORK", 2)
				t:SetTexture(TEX .. "gleam")
				t:SetBlendMode("ADD")
				t:SetAlpha(0)
				return t
			end)
		end
		Toggle(icon.gleam, shining)

		local swiping = banim == "drawin" or banim == "drain"
		if swiping then
			Layer(icon, "swipe", function(parent)
				local cd = CreateFrame("Cooldown", nil, parent)
				cd:SetAllPoints()
				cd:SetDrawEdge(false)
				cd:SetDrawBling(false)
				cd:SetHideCountdownNumbers(true)
				cd.icon = icon
				cd:SetScript("OnCooldownDone", SwipeDone)
				return cd
			end)
			icon.swipe:SetSwipeTexture(ringFile)
			icon.swipe:SetReverse(banim == "drawin")
			icon.swipeLength = banim == "drawin" and cfg.tin + .25 or cfg.tin + cfg.thold + cfg.tout
			if banim == "drain" and icon.ring then icon.ring:SetAlpha(0) end
		end
		Toggle(icon.swipe, swiping)
		icon.swiping = swiping

		icon.gIn = BuildIn(icon, cfg)
		icon.gOut = BuildOut(icon, cfg)
		icon.gHold = BuildHold(icon, cfg)
		icon.gBurst = outSpec.ring and BuildBurst(icon, cfg) or nil
		icon.border = BuildBorder(icon, cfg)
		icon.colorMode = cfg.color
		local size = math_max(cfg.size, 1)
		icon.frame:SetSize(size, size)
		icon.holder:SetSize(size, size)
		if icon.halo then icon.halo:SetSize(size * 1.4, size * 1.4) end
		if icon.inner then icon.inner:SetSize(size * .86, size * .86) end
		local gleam = icon.gleam
		if gleam then
			gleam:SetSize(size, size)
			gleam:ClearAllPoints()
			gleam:SetPoint("CENTER", icon.frame, "CENTER", -size, 0)
		end
	end

	local function ColorOf(mode, category)
		if mode == "white" then return WHITE end
		if mode == "gold" then return GOLD end
		if mode == "class" then
			local _, token = UnitClass("player")
			local c = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
			if not c then return WHITE end
			CLASS[1], CLASS[2], CLASS[3] = c.r, c.g, c.b
			return CLASS
		end
		return Pulse.CATEGORY_COLORS[category] or WHITE
	end
	Pulse.ColorOf = ColorOf

	function Pulse.Stop(icon)
		if icon.gIn then icon.gIn:Stop() end
		if icon.gOut then icon.gOut:Stop() end
		if icon.gHold then icon.gHold:Stop() end
		if icon.gBurst then icon.gBurst:Stop() end
		StopBorder(icon)
		if icon.swipe then icon.swipe:Clear() end
		icon.frame:Hide()
		if icon.label then icon.label:Hide() end
		icon.busy = false
	end

	function Pulse.Play(icon, texture, category, name)
		stats.pulses = stats.pulses + 1
		if icon.busy then Pulse.Stop(icon) end
		icon.busy = true
		icon.art:SetTexture(texture)
		icon.cycle = 1
		Tint(icon, ColorOf(icon.colorMode, category))
		if icon.label and name then
			icon.label:SetText(name)
			icon.label:Show()
		end
		icon.frame:Show()
		if icon.swiping then
			if icon.banim == "drawin" and icon.hasRing then icon.ring:Hide() end
			icon.swipe:SetCooldown(GetTime(), icon.swipeLength)
		end
		local border = icon.border
		for i = 1, #border do border[i]:Play() end
		icon.gIn:Play()
	end

	local Down = {}
	Down.TEST = { { "spell", 1850, "class" }, { "item", 6948, "usable" }, { "spell", 20580, "racial" } }

	local qKind, qId, qCat = {}, {}, {}
	local qHead, qCount = 1, 0

	local function Display(kind, id, category)
		local icons, db = Down.icons, Down.db
		local texture, name = SA_CooldownWatch.Describe(kind, id, db.showName)
		if not texture then return end
		local icon = icons[1]
		if db.mode == "row" then
			icon = nil
			for i = 1, ROW do
				if not icons[i].busy then
					icon = icons[i]
					break
				end
			end
			if not icon then
				Down.oldest = Down.oldest % ROW + 1
				icon = icons[Down.oldest]
			end
		end
		Pulse.Play(icon, texture, category, name)
	end

	local function Enqueue(kind, id, category)
		for i = 0, qCount - 1 do
			local slot = (qHead + i - 1) % QUEUE + 1
			if qKind[slot] == kind and qId[slot] == id then return end
		end
		if qCount == QUEUE then
			qKind[qHead], qId[qHead], qCat[qHead] = nil, nil, nil
			qHead = qHead % QUEUE + 1
			qCount = qCount - 1
		end
		local slot = (qHead + qCount - 1) % QUEUE + 1
		qKind[slot], qId[slot], qCat[slot] = kind, id, category
		qCount = qCount + 1
	end

	local function Next()
		if qCount == 0 or not (Down.db and Down.db.enabled) then return end
		local slot = qHead
		local kind, id, category = qKind[slot], qId[slot], qCat[slot]
		qKind[slot], qId[slot], qCat[slot] = nil, nil, nil
		qHead = qHead % QUEUE + 1
		qCount = qCount - 1
		Display(kind, id, category)
	end

	local function Ready(kind, id, category)
		local db = Down.db
		if not db or not db.enabled then return end
		if db.mode == "queue" and Down.icons[1].busy then
			Enqueue(kind, id, category)
			return
		end
		Display(kind, id, category)
	end
	Down.Ready = Ready

	function Down.Queued()
		return qCount
	end

	function Down:Place()
		local db, anchor = self.db, self.anchor
		anchor:ClearAllPoints()
		anchor:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or 0)
		anchor:SetAlpha(db.alpha or 1)
		local unlocked = not db.locked
		anchor:EnableMouse(unlocked)
		anchor.shade:SetShown(unlocked)
		anchor:SetSize(db.size, db.size)
		for i = 1, ROW do
			local holder = self.icons[i].holder
			holder:ClearAllPoints()
			holder:SetPoint("CENTER", anchor, "CENTER", db.mode == "row" and (i - 2) * db.size * ROW_GAP or 0, 0)
			holder:SetShown(i == 1 or db.mode == "row")
		end
	end

	function Down:SaveSpot()
		local x, y = self.anchor:GetCenter()
		local cx, cy = UIParent:GetCenter()
		if not (x and y and cx and cy) then return end
		self.db.x, self.db.y = x - cx, y - cy
		self:Place()
	end

	function Down:Mask()
		local set = {}
		for _, category in ipairs(SA_CooldownWatch.CATEGORIES) do set[category] = self.db.cats[category] ~= false end
		return set
	end

	function Down:Apply()
		local db = self.db
		if not db or not self.icons then return end
		db.cats = db.cats or {}
		local count = db.mode == "row" and ROW or 1
		for i = 1, ROW do
			local icon = self.icons[i]
			if icon.gIn or i <= count then Pulse.Stop(icon) end
			if i <= count then Pulse.Apply(icon, db) end
		end
		for i = 1, QUEUE do qKind[i], qId[i], qCat[i] = nil, nil, nil end
		qHead, qCount = 1, 0
		self:Place()
		local Watch = SA_CooldownWatch
		if db.enabled then
			Watch.SetMinimum(db.minCd)
			Watch.SetIgnore(db.ignore)
			Watch.SetMask(self:Mask())
			Watch.Subscribe(Down, Ready)
		else
			Watch.Unsubscribe(Down)
		end
	end

	function Down:GetSettings()
		return self.db
	end

	function Down:RunTest()
		if not self.icons then return end
		for _, entry in ipairs(Down.TEST) do
			if self.db.mode == "queue" and self.icons[1].busy then Enqueue(entry[1], entry[2], entry[3]) else Display(entry[1], entry[2], entry[3]) end
		end
	end

	function Down:ResetPositions()
		if not self.db then return end
		self.db.x, self.db.y = 0, 120
		self:Place()
	end

	function Down:Initialize()
		if self.initialized then return end
		local anchor = CreateFrame("Frame", "SoundAlerterPulseDown", UIParent)
		anchor:SetFrameStrata("HIGH")
		anchor:SetClampedToScreen(true)
		anchor:SetMovable(true)
		anchor:RegisterForDrag("LeftButton")
		anchor:SetScript("OnDragStart", function(frame)
			if not Down.db.locked then frame:StartMoving() end
		end)
		anchor:SetScript("OnDragStop", function(frame)
			frame:StopMovingOrSizing()
			Down:SaveSpot()
		end)
		anchor.shade = anchor:CreateTexture(nil, "BACKGROUND")
		anchor.shade:SetAllPoints(anchor)
		anchor.shade:SetColorTexture(0, 0, 0, 0.35)
		anchor.shade:Hide()
		self.anchor = anchor
		self.icons = {}
		self.oldest = 0
		for i = 1, ROW do
			local icon = Pulse.New(anchor)
			icon.onDone = Next
			local label = anchor:CreateFontString(nil, "OVERLAY")
			label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
			label:SetPoint("TOP", icon.holder, "BOTTOM", 0, -2)
			label:Hide()
			icon.label = label
			self.icons[i] = icon
		end
		self.initialized = true
	end

	Pulse.Down = Down
	SoundAlerter.PulseDown = Down
	SA_Modules.Register({ key = "PulseDown", module = Down, db = "pulseDown", title = "PulseDown", nav = { section = "Displays", order = 30 }, options = "BuildPulseDownOptions", enabled = { "enabled" } })
end
