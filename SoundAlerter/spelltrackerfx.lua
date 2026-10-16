local FX = {}

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_rad = math.rad

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
			throb = frame.timerText:CreateAnimationGroup()
			throb:SetLooping("REPEAT")
			relativeScale(throb, 1, THROB_SCALE, THROB_TIME, "IN_OUT")
			relativeScale(throb, 2, 1 / THROB_SCALE, THROB_TIME, "IN_OUT")
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
		if set.throb then set.throb:Stop() end
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
