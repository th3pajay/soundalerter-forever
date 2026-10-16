local CastingBarFX = {}

local math_max = math.max

local FLAT = "Interface\\Buttons\\WHITE8X8"
local TEXTURE_DIR = "Interface\\AddOns\\SoundAlerter\\Textures\\"
local TICKS_H = TEXTURE_DIR .. "cb_ticks_h"
local TICKS_V = TEXTURE_DIR .. "cb_ticks_v"
local HATCH = TEXTURE_DIR .. "cb_hatch"
local TILE = 16
local TILE_INSET = 2
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local WHITE = { 1, 1, 1 }
local GREEN = { 0.2, 1, 0.2 }
local RED = { 1, 0.25, 0.25 }
local STEEL = { 0.55, 0.61, 0.69 }
local STEEL_BORDER = { 0.81, 0.85, 0.9 }
local TIME_COLOR = { 1, 0.82, 0 }
local WARN_COLOR = { 1, 0.35, 0.35 }

local TIERS = {
	off = {
		name = "off", off = true, gloss = false, hatch = false, unfurl = 0, overshoot = false, unfurlRing = false,
		bloom = 0, shake = false, shockRing = false, lockFlash = false, throbs = 0, pulse = 0,
		pulseGlow = false, shrinkX = 1, shrinkY = 1, throttle = 1 / 15, subpixel = false,
	},
	low = {
		name = "low", gloss = false, hatch = false, unfurl = 0.22, overshoot = false, unfurlRing = false,
		bloom = 1, shake = false, shockRing = false, lockFlash = false, throbs = 0, pulse = 0.45,
		pulseGlow = false, shrinkX = 0.4, shrinkY = 1, throttle = 1 / 15, subpixel = false,
	},
	normal = {
		name = "normal", gloss = false, hatch = true, unfurl = 0.32, overshoot = true, unfurlRing = false,
		bloom = 2, shake = true, shockRing = false, lockFlash = false, throbs = 2, pulse = 0.7,
		pulseGlow = false, shrinkX = 0.3, shrinkY = 0.6, throttle = 0, subpixel = false,
	},
	high = {
		name = "high", gloss = true, hatch = true, unfurl = 0.32, overshoot = true, unfurlRing = true,
		bloom = 3, shake = true, shockRing = true, lockFlash = true, throbs = 3, pulse = 0.7,
		pulseGlow = true, shrinkX = 0.3, shrinkY = 0.6, throttle = 0, subpixel = true,
	},
}

local QUALITIES = {
	{ "off", "Off" },
	{ "low", "Low" },
	{ "normal", "Normal" },
	{ "high", "High" },
}

CastingBarFX.TIERS = TIERS
CastingBarFX.QUALITIES = QUALITIES
CastingBarFX.quality = "normal"
CastingBarFX.tier = TIERS.normal

function CastingBarFX.Normalize(quality)
	if TIERS[quality] then return quality end
	return "normal"
end

function CastingBarFX:SetQuality(quality)
	self.quality = self.Normalize(quality)
	self.tier = TIERS[self.quality]
	return self.quality
end

local function alphaAnimation(group, order, from, to, duration)
	local animation = group:CreateAnimation("Alpha")
	animation:SetOrder(order)
	animation:SetFromAlpha(from)
	animation:SetToAlpha(to)
	animation:SetDuration(duration)
	return animation
end

local function scaleAnimation(group, order, fromX, fromY, toX, toY, duration, smoothing)
	local animation = group:CreateAnimation("Scale")
	animation:SetOrder(order)
	animation:SetDuration(duration)
	if animation.SetScaleFrom then
		animation:SetScaleFrom(fromX, fromY)
		animation:SetScaleTo(toX, toY)
	else
		animation:SetScale(toX / fromX, toY / fromY)
	end
	if smoothing then animation:SetSmoothing(smoothing) end
	return animation
end

local function relativeScale(group, order, factorX, factorY, duration, smoothing)
	local animation = group:CreateAnimation("Scale")
	animation:SetOrder(order)
	animation:SetDuration(duration)
	animation:SetScale(factorX, factorY)
	if smoothing then animation:SetSmoothing(smoothing) end
	return animation
end

local function translateAnimation(group, order, dx, duration)
	local animation = group:CreateAnimation("Translation")
	animation:SetOrder(order)
	animation:SetOffset(dx, 0)
	animation:SetDuration(duration)
	return animation
end

local function stateFor(b)
	local state = b.fx
	if not state then
		state = { sets = {}, active = {}, common = { rings = {} } }
		b.fx = state
	end
	return state
end

local function setFor(b, tier)
	local state = stateFor(b)
	local set = state.sets[tier.name]
	if not set then
		set = {}
		state.sets[tier.name] = set
	end
	return state, set, state.common
end

local function play(state, group)
	group:Stop()
	group:Play()
	if not group.tracked then
		group.tracked = true
		state.active[#state.active + 1] = group
	end
end

local function buildRing(b, spec)
	local texture = b.frame:CreateTexture(nil, "OVERLAY")
	texture:SetTexture(FLAT)
	texture:SetBlendMode("ADD")
	texture:SetPoint("TOPLEFT", b.bar, "TOPLEFT", -1, 1)
	texture:SetPoint("BOTTOMRIGHT", b.bar, "BOTTOMRIGHT", 1, -1)
	texture:Hide()
	local group = texture:CreateAnimationGroup()
	local order = 1
	if spec.delay > 0 then
		alphaAnimation(group, order, 0, 0, spec.delay)
		order = order + 1
	end
	alphaAnimation(group, order, spec.peak, 0, spec.duration)
	scaleAnimation(group, order, 1, 1, spec.toX, spec.toY, spec.duration, "OUT")
	group:SetScript("OnFinished", function() texture:Hide() end)
	return { frame = texture, group = group }
end

local function flash(b, state, common, key, color, spec)
	local ring = common.rings[key]
	if not ring then
		ring = buildRing(b, spec)
		common.rings[key] = ring
	end
	ring.frame:SetVertexColor(color[1], color[2], color[3], 1)
	ring.frame:Show()
	play(state, ring.group)
end

local function overlay(b, layer)
	local texture = b.bar:CreateTexture(nil, "ARTWORK", nil, layer)
	texture:Hide()
	return texture
end

local function tile(texture, bar, path)
	texture:SetTexture(path, "REPEAT", "REPEAT")
	texture:SetTexCoord(0, math_max(1, bar:GetWidth() - TILE_INSET * 2) / TILE, 0, math_max(1, bar:GetHeight() - TILE_INSET * 2) / TILE)
end

function CastingBarFX:Look(b, settings)
	local state = stateFor(b)
	local bar = b.bar
	local tier = self.tier

	if not state.ticks then state.ticks = overlay(b, 3) end
	local ticks = state.ticks
	if settings.segments then
		ticks:ClearAllPoints()
		ticks:SetPoint("TOPLEFT", bar, "TOPLEFT", TILE_INSET, -TILE_INSET)
		ticks:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -TILE_INSET, TILE_INSET)
		tile(ticks, bar, b.vertical and TICKS_V or TICKS_H)
		ticks:Show()
	else
		ticks:Hide()
	end

	local fill = bar:GetStatusBarTexture()
	if tier.gloss and not b.vertical and fill then
		if not state.gloss then
			state.gloss = overlay(b, 4)
			state.gloss:SetTexture(FLAT)
		end
		local gloss = state.gloss
		gloss:ClearAllPoints()
		gloss:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
		gloss:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, 0)
		gloss:SetHeight(math_max(1, bar:GetHeight() * 0.4))
		if gloss.SetGradient and CreateColor then
			gloss:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0.04), CreateColor(1, 1, 1, 0.4))
		else
			gloss:SetVertexColor(1, 1, 1, 0.2)
		end
		gloss:Show()
	elseif state.gloss then
		state.gloss:Hide()
	end

	if state.hatch then
		state.hatch:ClearAllPoints()
		state.hatch:SetAllPoints(fill or bar)
		tile(state.hatch, bar, HATCH)
	end
end

function CastingBarFX:Enter(b)
	local tier = self.tier
	if tier.off then return end
	local state, set, common = setFor(b, tier)
	local group = set.enter
	if not group then
		group = b.frame:CreateAnimationGroup()
		alphaAnimation(group, 1, 0, 1, 0.12)
		if tier.overshoot then
			relativeScale(group, 1, 1.05, 1, tier.unfurl * 0.5, "OUT")
			relativeScale(group, 2, 1 / 1.05, 1, tier.unfurl * 0.5)
		end
		set.enter = group
	end
	play(state, group)
	if tier.unfurlRing then
		flash(b, state, common, "unfurl", WHITE, { delay = 0.2, duration = 0.38, toX = 1.08, toY = 1.5, peak = 0.9 })
	end
end

function CastingBarFX:Success(b)
	local tier = self.tier
	if tier.off then return end
	local state, _, common = setFor(b, tier)
	for i = 1, tier.bloom do
		flash(b, state, common, "bloom" .. i, GREEN, { delay = (i - 1) * 0.11, duration = 0.48, toX = 1.12, toY = 1.9, peak = 0.9 })
	end
end

function CastingBarFX:Interrupt(b)
	local tier = self.tier
	if tier.off then return nil end
	local state, _, common = setFor(b, tier)

	local stamp = common.stamp
	if not stamp then
		local frame = CreateFrame("Frame", nil, b.frame)
		frame:SetPoint("CENTER", b.bar, "CENTER", 0, 0)
		frame:SetSize(160, 24)
		frame:SetFrameLevel(b.bar:GetFrameLevel() + 5)
		local text = frame:CreateFontString(nil, "OVERLAY")
		text:SetFont(FONT, 15, "OUTLINE")
		text:SetTextColor(1, 0.35, 0.35, 1)
		text:SetPoint("CENTER", frame, "CENTER", 0, 0)
		text:SetText("INTERRUPTED")
		local group = frame:CreateAnimationGroup()
		alphaAnimation(group, 1, 0, 1, 0.1)
		relativeScale(group, 1, 1.3, 1.3, 0.08, "OUT")
		relativeScale(group, 2, 1 / 1.3, 1 / 1.3, 0.1)
		frame:Hide()
		stamp = { frame = frame, group = group }
		common.stamp = stamp
	end
	b.bar:SetAlpha(0.3)
	stamp.frame:Show()
	play(state, stamp.group)

	if tier.shake then
		local shake = common.shake
		if not shake then
			shake = b.frame:CreateAnimationGroup()
			local first = translateAnimation(shake, 1, -4, 0.053)
			first:SetStartDelay(0.13)
			translateAnimation(shake, 2, 8, 0.053)
			translateAnimation(shake, 3, -4, 0.053)
			common.shake = shake
		end
		play(state, shake)
	end

	if tier.shockRing then
		flash(b, state, common, "shock", RED, { delay = 0.12, duration = 0.38, toX = 1.15, toY = 2, peak = 0.9 })
	end
	return true
end

function CastingBarFX:Lock(b)
	local tier = self.tier
	if tier.off then return end
	local state, _, common = setFor(b, tier)

	b.bar:SetStatusBarColor(STEEL[1], STEEL[2], STEEL[3], 1)
	b.bar:SetBackdropBorderColor(STEEL_BORDER[1], STEEL_BORDER[2], STEEL_BORDER[3], 1)
	b.restBorder = STEEL_BORDER

	if tier.hatch then
		if not state.hatch then
			state.hatch = overlay(b, 2)
			state.hatch:SetAllPoints(b.bar:GetStatusBarTexture() or b.bar)
			tile(state.hatch, b.bar, HATCH)
		end
		state.hatch:Show()
	end

	if tier.lockFlash then
		flash(b, state, common, "lock", WHITE, { delay = 0, duration = 0.36, toX = 1, toY = 1, peak = 0.9 })
	end
end

function CastingBarFX:Warn(b)
	local tier = self.tier
	b.timeText:SetTextColor(WARN_COLOR[1], WARN_COLOR[2], WARN_COLOR[3], 1)
	if tier.off or tier.throbs < 1 then return end

	local state, set = setFor(b, tier)
	local group = set.throb
	if not group then
		group = b.timeText:CreateAnimationGroup()
		for i = 1, tier.throbs do
			relativeScale(group, i * 2 - 1, 1.45, 1.45, 0.13)
			relativeScale(group, i * 2, 1 / 1.45, 1 / 1.45, 0.13)
		end
		set.throb = group
	end
	play(state, group)
end

function CastingBarFX:ClearWarn(b)
	b.timeText:SetTextColor(TIME_COLOR[1], TIME_COLOR[2], TIME_COLOR[3], 1)
	local state = b.fx
	if state then
		for _, set in pairs(state.sets) do
			if set.throb then set.throb:Stop() end
		end
	end
end

function CastingBarFX:Pulse(b)
	local tier = self.tier
	if tier.off then return end
	local state, _, common = setFor(b, tier)

	local pulse = common.pulse
	if not pulse then
		local texture = overlay(b, 5)
		texture:SetTexture(FLAT)
		texture:SetBlendMode("ADD")
		texture:SetVertexColor(1, 1, 1, 1)
		texture:SetAllPoints(b.bar:GetStatusBarTexture() or b.bar)
		local group = texture:CreateAnimationGroup()
		local fade = alphaAnimation(group, 1, tier.pulse, 0, 0.17)
		group:SetScript("OnFinished", function() texture:Hide() end)
		pulse = { texture = texture, group = group, fade = fade }
		common.pulse = pulse
	end
	pulse.fade:SetFromAlpha(tier.pulse)
	pulse.texture:Show()
	play(state, pulse.group)

	if tier.pulseGlow then
		flash(b, state, common, "glow", GREEN, { delay = 0, duration = 0.26, toX = 1.04, toY = 1.4, peak = 1 })
	end
end

function CastingBarFX:Cancel(b, done)
	local tier = self.tier
	if tier.off then return nil end
	local state, _, common = setFor(b, tier)

	local cancel = common.cancel
	if not cancel then
		local group = b.frame:CreateAnimationGroup()
		group:SetToFinalAlpha(true)
		alphaAnimation(group, 1, 1, 0, 0.22)
		cancel = { group = group, shrink = relativeScale(group, 1, 1, 1, 0.22, "IN") }
		group:SetScript("OnFinished", function()
			local callback = state.cancelDone
			state.cancelDone = nil
			if callback then callback() end
		end)
		common.cancel = cancel
	end
	cancel.shrink:SetScale(tier.shrinkX, tier.shrinkY)
	state.cancelDone = done
	play(state, cancel.group)
	return true
end

function CastingBarFX:Rest(b)
	local state = b.fx
	if not state then return end

	state.cancelDone = nil
	local active = state.active
	for i = #active, 1, -1 do
		active[i]:Stop()
		active[i].tracked = false
		active[i] = nil
	end

	local common = state.common
	for _, ring in pairs(common.rings) do
		ring.frame:Hide()
	end
	if common.stamp then common.stamp.frame:Hide() end
	if common.pulse then common.pulse.texture:Hide() end
	if state.hatch then state.hatch:Hide() end

	b.bar:SetAlpha(1)
	b.timeText:SetTextColor(TIME_COLOR[1], TIME_COLOR[2], TIME_COLOR[3], 1)
	b.restBorder = nil
end

SoundAlerter.CastingBarFX = CastingBarFX
