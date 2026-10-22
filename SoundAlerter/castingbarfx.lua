local CastingBarFX = {}

local math_max = math.max
local math_min = math.min

local FLAT = "Interface\\Buttons\\WHITE8X8"
local TEXTURE_DIR = "Interface\\AddOns\\SoundAlerter\\Textures\\"
local TICKS_H = TEXTURE_DIR .. "cb_ticks_h"
local TICKS_V = TEXTURE_DIR .. "cb_ticks_v"
local HATCH = TEXTURE_DIR .. "cb_hatch"
local SPARK = TEXTURE_DIR .. "cb_spark"
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
local CANCEL_GREY = { 0.47, 0.47, 0.47 }
local EMBER_OFFSETS = { { -16, 14 }, { 12, 22 }, { -6, 30 }, { 20, 16 }, { -22, 24 }, { 4, 12 }, { 16, 32 }, { -12, 18 } }
local BRACKET_SIZE = 9
local BRACKET_OUTSET = 4
local MARK_DIM = 0.12

local TIERS = {
	off = {
		name = "off", off = true, gloss = false, hatch = false, unfurl = 0, overshoot = false, unfurlRing = false,
		bloom = 0, shake = false, shockRing = false, lockFlash = false, throbs = 0, pulse = 0,
		pulseGlow = false, shrinkX = 1, shrinkY = 1, throttle = 1 / 15, subpixel = false,
		head = false, rim = false, lightning = false, pulses = 0, markFade = false, embers = 0,
		wipeLine = false, flashGlow = false, warnGlow = false, bracketSnap = false,
	},
	low = {
		name = "low", gloss = false, hatch = false, unfurl = 0.22, overshoot = false, unfurlRing = false,
		bloom = 1, shake = false, shockRing = false, lockFlash = false, throbs = 0, pulse = 0.45,
		pulseGlow = false, shrinkX = 0.4, shrinkY = 1, throttle = 1 / 15, subpixel = false,
		head = false, rim = false, lightning = false, pulses = 1, markFade = false, embers = 0,
		wipeLine = false, flashGlow = false, warnGlow = false, bracketSnap = false,
	},
	normal = {
		name = "normal", gloss = false, hatch = true, unfurl = 0.32, overshoot = true, unfurlRing = false,
		bloom = 2, shake = true, shockRing = false, lockFlash = false, throbs = 2, pulse = 0.7,
		pulseGlow = false, shrinkX = 0.3, shrinkY = 0.6, throttle = 0, subpixel = false,
		head = true, rim = false, lightning = false, pulses = 3, markFade = true, embers = 4,
		wipeLine = false, flashGlow = false, warnGlow = false, bracketSnap = true,
	},
	high = {
		name = "high", gloss = true, hatch = true, unfurl = 0.32, overshoot = true, unfurlRing = true,
		bloom = 3, shake = true, shockRing = true, lockFlash = true, throbs = 3, pulse = 0.7,
		pulseGlow = true, shrinkX = 0.3, shrinkY = 0.6, throttle = 0, subpixel = true,
		head = true, rim = true, lightning = true, pulses = 3, markFade = true, embers = 8,
		wipeLine = true, flashGlow = true, warnGlow = true, bracketSnap = true,
	},
}

local QUALITIES = {
	{ "off", "Off" },
	{ "low", "Low" },
	{ "normal", "Normal" },
	{ "high", "High" },
}

local STYLES = {
	solid = { head = "edge", enter = "wipe", success = "flash", cancel = "fade", lock = "steel", warn = "pulse", tick = "marks" },
	fog = { storm = true, enter = "pop", success = "flash", cancel = "fizzle", lock = "brackets", warn = "pulse", tick = "marks" },
	default = { head = "spark", enter = "fade", success = "hold", cancel = "fade", lock = "steel", warn = "flip", tick = "marks" },
}

CastingBarFX.TIERS = TIERS
CastingBarFX.STYLES = STYLES
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

local OPPOSITE = { LEFT = "RIGHT", RIGHT = "LEFT", TOP = "BOTTOM", BOTTOM = "TOP" }

local function startSide(b)
	local reverse = b.bar:GetReverseFill()
	if b.vertical then return reverse and "TOP" or "BOTTOM" end
	return reverse and "RIGHT" or "LEFT"
end

local function leadSide(b)
	return OPPOSITE[startSide(b)]
end

local function thicknessOf(b)
	return b.vertical and b.bar:GetWidth() or b.bar:GetHeight()
end

local function sizeAlong(texture, b, along, across)
	if b.vertical then texture:SetSize(across, along) else texture:SetSize(along, across) end
end

local function headOff(state)
	if state.head then state.head:Hide() end
	local lightning = state.lightning
	if lightning then
		lightning.group:Stop()
		lightning.texture:Hide()
	end
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

	state.settings = settings
	state.style = not tier.off and STYLES[settings.barTexture] or nil
	self:StyleLook(b, state, tier)
end

local function buildLightning(b, fill)
	local texture = overlay(b, 5)
	texture:SetTexture(FLAT)
	texture:SetBlendMode("ADD")
	texture:SetVertexColor(0.92, 0.94, 1, 1)
	texture:SetAllPoints(fill)
	local group = texture:CreateAnimationGroup()
	group:SetLooping("REPEAT")
	alphaAnimation(group, 1, 0, 0, 1.45)
	alphaAnimation(group, 2, 0, 0.9, 0.03)
	alphaAnimation(group, 3, 0.9, 0, 0.04)
	alphaAnimation(group, 4, 0, 0.6, 0.04)
	alphaAnimation(group, 5, 0.6, 0, 0.06)
	alphaAnimation(group, 6, 0, 0, 1)
	return { texture = texture, group = group }
end

function CastingBarFX:StyleLook(b, state, tier)
	local bar = b.bar
	local style = state.style
	local fill = bar:GetStatusBarTexture() or bar

	headOff(state)
	state.headOn = false
	state.lightningOn = false
	if state.rimTop then
		state.rimTop:Hide()
		state.rimBottom:Hide()
	end
	if state.storm then state.storm:Hide() end
	if not style then return end

	if style.head and tier.head then
		if not state.head then state.head = overlay(b, 6) end
		local head = state.head
		local spark = style.head == "spark"
		head:SetTexture(spark and SPARK or FLAT)
		head:SetBlendMode(spark and "ADD" or "BLEND")
		head:SetVertexColor(1, 1, 1, spark and 1 or 0.9)
		if spark and b.vertical then head:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1) else head:SetTexCoord(0, 1, 0, 1) end
		if spark then sizeAlong(head, b, 20, thicknessOf(b) * 1.7) else sizeAlong(head, b, 2, thicknessOf(b)) end
		head:ClearAllPoints()
		head:SetPoint("CENTER", fill, leadSide(b), 0, 0)
		state.headOn = true
	end

	if style.head == "edge" and tier.rim and not b.vertical then
		if not state.rimTop then
			state.rimTop = overlay(b, 5)
			state.rimTop:SetTexture(FLAT)
			state.rimTop:SetVertexColor(1, 1, 1, 0.55)
			state.rimBottom = overlay(b, 5)
			state.rimBottom:SetTexture(FLAT)
			state.rimBottom:SetVertexColor(0, 0, 0, 0.45)
		end
		state.rimTop:ClearAllPoints()
		state.rimTop:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
		state.rimTop:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, 0)
		state.rimTop:SetHeight(1)
		state.rimBottom:ClearAllPoints()
		state.rimBottom:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 0, 0)
		state.rimBottom:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
		state.rimBottom:SetHeight(1)
		state.rimTop:Show()
		state.rimBottom:Show()
	end

	if style.storm then
		if not state.storm then
			state.storm = overlay(b, 1)
			state.storm:SetTexture(FLAT)
		end
		local storm = state.storm
		storm:ClearAllPoints()
		storm:SetAllPoints(fill)
		if storm.SetGradient and CreateColor then
			storm:SetVertexColor(1, 1, 1, 1)
			storm:SetGradient("HORIZONTAL", CreateColor(0.04, 0.04, 0.2, 0.5), CreateColor(0.16, 0.2, 0.35, 0.2))
		else
			storm:SetVertexColor(0.08, 0.1, 0.27, 0.35)
		end
		storm:Show()
		if tier.lightning then
			if not state.lightning then state.lightning = buildLightning(b, fill) end
			state.lightning.texture:SetAllPoints(fill)
			state.lightningOn = true
		end
	end
end

local function layoutMarks(b, state)
	local marks = state.marks
	if not marks then
		marks = {}
		for i = 1, 3 do
			local texture = overlay(b, 7)
			texture:SetTexture(FLAT)
			texture:SetVertexColor(1, 1, 1, 0.55)
			local group = texture:CreateAnimationGroup()
			group:SetToFinalAlpha(true)
			alphaAnimation(group, 1, 1, MARK_DIM, 0.16)
			marks[i] = { texture = texture, group = group }
		end
		state.marks = marks
	end

	local side = startSide(b)
	local sign = (side == "LEFT" or side == "BOTTOM") and 1 or -1
	local length = b.vertical and b.bar:GetHeight() or b.bar:GetWidth()
	local thickness = thicknessOf(b)
	for i = 1, 3 do
		local mark = marks[i]
		local texture = mark.texture
		local offset = sign * length * (1 - i / 4)
		mark.group:Stop()
		sizeAlong(texture, b, 2, thickness)
		texture:ClearAllPoints()
		if b.vertical then
			texture:SetPoint("CENTER", b.bar, side, 0, offset)
		else
			texture:SetPoint("CENTER", b.bar, side, offset, 0)
		end
		texture:SetAlpha(1)
		texture:Show()
	end
end

function CastingBarFX:Begin(b)
	local tier = self.tier
	if tier.off then return end
	local state = stateFor(b)
	state.tick = 0

	if state.headOn then state.head:Show() end
	if state.lightningOn then
		state.lightning.texture:Show()
		play(state, state.lightning.group)
	end

	local style = state.style
	local settings = state.settings
	if style and style.tick == "marks" and b.channeling and not (settings and settings.channelPulse == false) then
		layoutMarks(b, state)
	end
end

function CastingBarFX:Enter(b)
	local tier = self.tier
	if tier.off then return end
	local state, set, common = setFor(b, tier)
	local style = state.style
	if style then
		self:StyleEnter(b, state, set, common, tier, style.enter)
		return
	end
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

function CastingBarFX:StyleEnter(b, state, set, common, tier, kind)
	if kind == "fade" then
		local group = set.fade
		if not group then
			group = b.frame:CreateAnimationGroup()
			alphaAnimation(group, 1, 0, 1, 0.2)
			set.fade = group
		end
		play(state, group)
	elseif kind == "wipe" then
		local key = b.vertical and "wipeV" or "wipeH"
		local wipe = set[key]
		if not wipe then
			local group = b.frame:CreateAnimationGroup()
			alphaAnimation(group, 1, 0, 1, 0.1)
			local grow
			if b.vertical then
				grow = scaleAnimation(group, 1, 1, 0.3, 1, 1, tier.unfurl, "OUT")
			else
				grow = scaleAnimation(group, 1, 0.3, 1, 1, 1, tier.unfurl, "OUT")
			end
			wipe = { group = group, grow = grow }
			set[key] = wipe
		end
		if wipe.grow.SetOrigin then wipe.grow:SetOrigin(startSide(b), 0, 0) end
		play(state, wipe.group)

		if tier.wipeLine and not b.vertical then
			local line = common.wipeLine
			if not line then
				local texture = b.frame:CreateTexture(nil, "OVERLAY")
				texture:SetTexture(FLAT)
				texture:SetBlendMode("ADD")
				texture:SetSize(3, 1)
				texture:Hide()
				local group = texture:CreateAnimationGroup()
				local travel = translateAnimation(group, 1, 0, tier.unfurl)
				alphaAnimation(group, 1, 1, 0, tier.unfurl)
				group:SetScript("OnFinished", function() texture:Hide() end)
				line = { texture = texture, group = group, travel = travel }
				common.wipeLine = line
			end
			local reverse = startSide(b) == "RIGHT"
			line.texture:SetHeight(b.bar:GetHeight() + 8)
			line.texture:ClearAllPoints()
			line.texture:SetPoint("CENTER", b.bar, reverse and "RIGHT" or "LEFT", 0, 0)
			line.travel:SetOffset(reverse and -b.bar:GetWidth() or b.bar:GetWidth(), 0)
			line.texture:Show()
			play(state, line.group)
		end
	elseif kind == "pop" then
		local group = set.pop
		if not group then
			group = b.frame:CreateAnimationGroup()
			alphaAnimation(group, 1, 0, 1, 0.1)
			scaleAnimation(group, 1, 1.25, 1.25, 0.97, 0.97, 0.17, "OUT")
			scaleAnimation(group, 2, 0.97, 0.97, 1, 1, 0.07)
			set.pop = group
		end
		play(state, group)
	end
end

function CastingBarFX:Success(b)
	local tier = self.tier
	if tier.off then return end
	local state, _, common = setFor(b, tier)
	local style = state.style
	if style then
		headOff(state)
		if style.success == "flash" then
			flash(b, state, common, "sflash", WHITE, { delay = 0, duration = 0.24, toX = 1, toY = 1, peak = 0.8 })
			if tier.flashGlow then
				flash(b, state, common, "sglow", GREEN, { delay = 0, duration = 0.42, toX = 1.1, toY = 1.7, peak = 0.7 })
			end
		end
		return
	end
	for i = 1, tier.bloom do
		flash(b, state, common, "bloom" .. i, GREEN, { delay = (i - 1) * 0.11, duration = 0.48, toX = 1.12, toY = 1.9, peak = 0.9 })
	end
end

function CastingBarFX:Interrupt(b)
	local tier = self.tier
	if tier.off then return nil end
	local state, _, common = setFor(b, tier)
	headOff(state)

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

	if state.style and state.style.lock == "brackets" then
		self:Brackets(b, state, common, tier)
		return
	end

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

local function bracketPiece(frame, corner, width, height)
	local texture = frame:CreateTexture(nil, "OVERLAY")
	texture:SetTexture(FLAT)
	texture:SetVertexColor(STEEL_BORDER[1], STEEL_BORDER[2], STEEL_BORDER[3], 1)
	texture:SetSize(width, height)
	texture:SetPoint(corner, frame, corner, 0, 0)
end

function CastingBarFX:Brackets(b, state, common, tier)
	local brackets = common.brackets
	if not brackets then
		local frame = CreateFrame("Frame", nil, b.frame)
		frame:SetPoint("TOPLEFT", b.bar, "TOPLEFT", -BRACKET_OUTSET, BRACKET_OUTSET)
		frame:SetPoint("BOTTOMRIGHT", b.bar, "BOTTOMRIGHT", BRACKET_OUTSET, -BRACKET_OUTSET)
		frame:SetFrameLevel(b.bar:GetFrameLevel() + 6)
		for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
			bracketPiece(frame, corner, BRACKET_SIZE, 2)
			bracketPiece(frame, corner, 2, BRACKET_SIZE)
		end
		local group = frame:CreateAnimationGroup()
		alphaAnimation(group, 1, 0, 1, 0.2)
		scaleAnimation(group, 1, 1.2, 1.2, 1, 1, 0.2, "OUT")
		frame:Hide()
		brackets = { frame = frame, group = group }
		common.brackets = brackets
	end

	b.bar:SetBackdropBorderColor(STEEL_BORDER[1], STEEL_BORDER[2], STEEL_BORDER[3], 1)
	b.restBorder = STEEL_BORDER
	brackets.frame:Show()
	if tier.bracketSnap then play(state, brackets.group) end
end

local function edgeStrip(frame, first, second, width, height)
	local texture = frame:CreateTexture(nil, "OVERLAY")
	texture:SetTexture(FLAT)
	texture:SetBlendMode("ADD")
	texture:SetVertexColor(1, 0.2, 0.2, 1)
	texture:SetPoint(first, frame, first, 0, 0)
	texture:SetPoint(second, frame, second, 0, 0)
	if width then texture:SetWidth(width) end
	if height then texture:SetHeight(height) end
end

function CastingBarFX:EdgePulse(b, state, set, common, tier)
	local edge = common.edge
	if not edge then
		local frame = CreateFrame("Frame", nil, b.frame)
		frame:SetAllPoints(b.bar)
		frame:SetFrameLevel(b.bar:GetFrameLevel() + 6)
		edgeStrip(frame, "TOPLEFT", "TOPRIGHT", nil, 2)
		edgeStrip(frame, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
		edgeStrip(frame, "TOPLEFT", "BOTTOMLEFT", 2, nil)
		edgeStrip(frame, "TOPRIGHT", "BOTTOMRIGHT", 2, nil)
		frame:Hide()
		edge = { frame = frame }
		common.edge = edge
	end

	local group = set.edgePulse
	if not group then
		group = edge.frame:CreateAnimationGroup()
		for i = 1, tier.pulses do
			alphaAnimation(group, i * 2 - 1, 0, 1, 0.115)
			alphaAnimation(group, i * 2, 1, 0, 0.115)
		end
		group:SetScript("OnFinished", function() edge.frame:Hide() end)
		set.edgePulse = group
	end
	edge.frame:Show()
	play(state, group)
	if tier.warnGlow then
		flash(b, state, common, "warnglow", RED, { delay = 0, duration = 0.4, toX = 1.03, toY = 1.4, peak = 0.5 })
	end
end

function CastingBarFX:Warn(b)
	local tier = self.tier
	b.timeText:SetTextColor(WARN_COLOR[1], WARN_COLOR[2], WARN_COLOR[3], 1)
	if tier.off then return end

	local state, set, common = setFor(b, tier)
	local style = state.style
	if style and style.warn == "pulse" then
		if tier.pulses > 0 then self:EdgePulse(b, state, set, common, tier) end
		return
	end
	if tier.throbs < 1 then return end

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
			if set.edgePulse then set.edgePulse:Stop() end
		end
		if state.common.edge then state.common.edge.frame:Hide() end
	end
end

function CastingBarFX:Pulse(b)
	local tier = self.tier
	if tier.off then return end
	local state, _, common = setFor(b, tier)

	local style = state.style
	if style and style.tick == "marks" then
		local index = (state.tick or 0) + 1
		state.tick = index
		local mark = state.marks and state.marks[index]
		if mark then
			if tier.markFade then play(state, mark.group) else mark.texture:SetAlpha(MARK_DIM) end
		end
		return
	end

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

function CastingBarFX:Fizzle(b, state, common, tier)
	b.bar:SetStatusBarColor(CANCEL_GREY[1], CANCEL_GREY[2], CANCEL_GREY[3], 1)
	b.bar:SetBackdropBorderColor(CANCEL_GREY[1], CANCEL_GREY[2], CANCEL_GREY[3], 1)
	b.spellText:SetText("Cancelled")
	b.timeText:SetText("")
	if tier.embers < 1 then return end

	local embers = common.embers
	if not embers then
		embers = {}
		for i, offset in ipairs(EMBER_OFFSETS) do
			local texture = b.frame:CreateTexture(nil, "OVERLAY")
			texture:SetTexture(FLAT)
			texture:SetBlendMode("ADD")
			texture:SetVertexColor(0.75, 0.75, 0.75, 1)
			texture:SetSize(3, 3)
			texture:Hide()
			local group = texture:CreateAnimationGroup()
			local move = group:CreateAnimation("Translation")
			move:SetOrder(1)
			move:SetOffset(offset[1], -offset[2])
			move:SetDuration(0.3)
			alphaAnimation(group, 1, 1, 0, 0.3)
			group:SetScript("OnFinished", function() texture:Hide() end)
			embers[i] = { texture = texture, group = group }
		end
		common.embers = embers
	end

	local fill = b.bar:GetStatusBarTexture() or b.bar
	for i = 1, math_min(tier.embers, #embers) do
		local ember = embers[i]
		ember.texture:ClearAllPoints()
		ember.texture:SetPoint("CENTER", fill, leadSide(b), 0, 0)
		ember.texture:Show()
		play(state, ember.group)
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
		cancel = { group = group, fade = alphaAnimation(group, 1, 1, 0, 0.22), shrink = relativeScale(group, 1, 1, 1, 0.22, "IN") }
		group:SetScript("OnFinished", function()
			local callback = state.cancelDone
			state.cancelDone = nil
			if callback then callback() end
		end)
		common.cancel = cancel
	end
	local style = state.style
	local fizzle = style and style.cancel == "fizzle"
	local duration = fizzle and 0.3 or 0.22
	cancel.fade:SetDuration(duration)
	cancel.shrink:SetDuration(duration)
	if style then
		cancel.shrink:SetScale(1, 1)
		headOff(state)
		if fizzle then self:Fizzle(b, state, common, tier) end
	else
		cancel.shrink:SetScale(tier.shrinkX, tier.shrinkY)
	end
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
	headOff(state)
	if state.marks then
		for _, mark in ipairs(state.marks) do mark.texture:Hide() end
	end
	if common.brackets then common.brackets.frame:Hide() end
	if common.edge then common.edge.frame:Hide() end
	if common.wipeLine then common.wipeLine.texture:Hide() end
	if common.embers then
		for _, ember in ipairs(common.embers) do ember.texture:Hide() end
	end

	b.bar:SetAlpha(1)
	b.timeText:SetTextColor(TIME_COLOR[1], TIME_COLOR[2], TIME_COLOR[3], 1)
	b.restBorder = nil
end

SoundAlerter.CastingBarFX = CastingBarFX
