local SoundAlerter = SoundAlerter
local Model = SA_MeterModel
local Plain = SA_COMPAT.Plain
local BarUtils = SoundAlerter.BarUtils
local GetTime, IsShiftKeyDown = GetTime, IsShiftKeyDown

local Kit = {}
local Strip = {}

Strip.HOLD = 10
Strip.OPTIONS_PAGE = "DamageMeter"
Strip.HEIGHT = 24
Strip.CELL = 92
Strip.TAG = 84
Strip.IDLE_ALPHA = 0.75
Strip.FADE = 0.3
Strip.FLAT = "Interface\\Buttons\\WHITE8X8"
Strip.CIRCLE = "Interface\\AddOns\\SoundAlerter\\Textures\\circle"
Kit.COUNT = 0.6
Strip.LINE_ALPHA = 0.5
Strip.DOT = 6
Strip.PULSE = 0.6
Strip.ROLL = 9
Strip.SHRINK = 0.25
Strip.SAMPLE = { 95, 3502, 412 }
Strip.SAMPLE_RATIOS = { 0.88, 1, 0.3 }

Strip.CELLS = {
    { label = "DPS", icon = "Interface\\Icons\\Ability_MeleeDamage", color = { 1, 0.694, 0.361 } },
    { label = "DAMAGE", icon = "Interface\\Icons\\Ability_Warrior_Cleave", color = { 0.851, 0.467, 0.086 } },
    { label = "HEAL", icon = "Interface\\Icons\\Spell_Holy_Heal", color = { 0.098, 0.722, 0.498 } },
}
Kit.KIND_COLOR = {
    world = { 0.851, 0.467, 0.086 },
    pvp = { 0.224, 0.529, 0.898 },
    run = { 0.239, 0.863, 0.592 },
}
Kit.KIND_LABEL = { world = "World", pvp = "World PvP" }

local COLOR = {
    plateTop = { 0.106, 0.129, 0.169, 0.96 },
    plateBottom = { 0.043, 0.055, 0.075, 0.96 },
    rim = { 0, 0, 0, 1 },
    highlight = { 1, 1, 1, 0.09 },
    live = { 0.91, 0.28, 0.35 },
    held = { 1, 0.82, 0 },
    line = { 1, 1, 1, 0.07 },
    accent = { 1, 0.49, 0.039 },
    track = { 0.227, 0.263, 0.322, 1 },
    text = { 1, 1, 1 },
    muted = { 0.588, 0.627, 0.698 },
}

local ease = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local METER = Enum and Enum.DamageMeterType or {}
local ZERO = { 0, 0, 0 }

local function Paint(parent, color, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetTexture(Strip.FLAT)
    texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    return texture
end

local function Short(value)
    if AbbreviateNumbers then return AbbreviateNumbers(value) end
    if type(value) ~= "number" then return "" end
    return string.format("%d", value)
end
Kit.Short = Short

local function Rate(value)
    if C_StringUtil and C_StringUtil.RoundToNearestString then return C_StringUtil.RoundToNearestString(value) end
    return Short(value)
end
Kit.Rate = Rate

local function Whole(value)
    return Short(math.floor(value + 0.5))
end
Kit.Whole = Whole

function Kit.Counter(frame, duration)
    local group = frame:CreateAnimationGroup()
    local step = group:CreateAnimation("Animation")
    step:SetDuration(duration or Kit.COUNT)
    local counter = { group = group, step = step, n = 0, items = {} }
    group:SetScript("OnUpdate", function() Kit.CountTick(counter, step:GetProgress() or 1) end)
    group:SetScript("OnFinished", function() Kit.CountTick(counter, 1) counter.n = 0 end)
    return counter
end

function Kit.CountAdd(counter, text, value, format)
    local n = counter.n + 1
    counter.n = n
    local item = counter.items[n]
    if not item then
        item = {}
        counter.items[n] = item
    end
    item[1], item[2], item[3] = text, value, format
end

function Kit.CountTick(counter, progress)
    local eased = 1 - (1 - progress) ^ 3
    local items = counter.items
    for i = 1, counter.n do
        local item = items[i]
        item[1]:SetText(item[3](item[2] * eased))
    end
end

function Kit.CountPlay(counter)
    if counter.n == 0 then return false end
    counter.group:Stop()
    Kit.CountTick(counter, 0)
    counter.group:Play()
    return true
end

function Kit.CountStop(counter)
    if counter.n == 0 then return end
    counter.group:Stop()
    Kit.CountTick(counter, 1)
    counter.n = 0
end

function Kit.PlayerColor()
    local _, class = UnitClass("player")
    class = Plain(class)
    local colors = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if colors then return colors.r, colors.g, colors.b end
    return COLOR.accent[1], COLOR.accent[2], COLOR.accent[3]
end

local function Plate(texture)
    local top, bottom = COLOR.plateTop, COLOR.plateBottom
    if texture.SetGradient and CreateColor then
        texture:SetVertexColor(1, 1, 1, 1)
        texture:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], bottom[4]), CreateColor(top[1], top[2], top[3], top[4]))
    else
        texture:SetVertexColor((top[1] + bottom[1]) / 2, (top[2] + bottom[2]) / 2, (top[3] + bottom[3]) / 2, top[4])
    end
end

function Strip.Roll(text)
    local group = text:CreateAnimationGroup()
    local drop = group:CreateAnimation("Translation")
    drop:SetOffset(0, -Strip.ROLL)
    drop:SetDuration(0.01)
    drop:SetOrder(1)
    local hide = group:CreateAnimation("Alpha")
    hide:SetFromAlpha(0)
    hide:SetToAlpha(0)
    hide:SetDuration(0.01)
    hide:SetOrder(1)
    local rise = group:CreateAnimation("Translation")
    rise:SetOffset(0, Strip.ROLL)
    rise:SetDuration(Kit.COUNT)
    rise:SetSmoothing("OUT")
    rise:SetOrder(2)
    local show = group:CreateAnimation("Alpha")
    show:SetFromAlpha(0)
    show:SetToAlpha(1)
    show:SetDuration(Kit.COUNT * 0.6)
    show:SetOrder(2)
    return group
end

function Kit.KindText(kind, name)
    if kind == "run" then return name or "Dungeon" end
    return Kit.KIND_LABEL[kind] or "World"
end

function Strip.Build(parent)
    local frame = CreateFrame("Frame", nil, parent)
    local full = Strip.CELL * #Strip.CELLS + Strip.TAG
    frame:SetSize(full, Strip.HEIGHT)
    local view = { frame = frame, cells = {}, fullWidth = full, width = full }
    view.back = Paint(frame, COLOR.rim)
    view.back:SetAllPoints()
    Plate(view.back)
    frame:SetClipsChildren(true)
    local rim = { Paint(frame, COLOR.rim, "BORDER"), Paint(frame, COLOR.rim, "BORDER"), Paint(frame, COLOR.rim, "BORDER") }
    view.rim = rim
    rim[1]:SetPoint("TOPLEFT") rim[1]:SetPoint("TOPRIGHT") rim[1]:SetHeight(1)
    rim[2]:SetPoint("TOPLEFT") rim[2]:SetPoint("BOTTOMLEFT") rim[2]:SetWidth(1)
    rim[3]:SetPoint("TOPRIGHT") rim[3]:SetPoint("BOTTOMRIGHT") rim[3]:SetWidth(1)
    view.highlight = Paint(frame, COLOR.highlight, "BORDER")
    view.highlight:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    view.highlight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    view.highlight:SetHeight(1)
    view.classLine = Paint(frame, COLOR.accent, "BORDER")
    view.classLine:SetPoint("BOTTOMLEFT")
    view.classLine:SetPoint("BOTTOMRIGHT")
    view.classLine:SetHeight(1)
    for i, spec in ipairs(Strip.CELLS) do
        local x = (i - 1) * Strip.CELL
        local cell = {}
        if i > 1 then
            local divider = Paint(frame, COLOR.line, "BORDER")
            divider:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
            divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 0)
            divider:SetWidth(1)
        end
        cell.icon = frame:CreateTexture(nil, "ARTWORK")
        cell.icon:SetTexture(spec.icon)
        cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        cell.icon:SetSize(14, 14)
        cell.icon:SetPoint("LEFT", frame, "LEFT", x + 6, 1)
        cell.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cell.label:SetPoint("LEFT", cell.icon, "RIGHT", 4, 0)
        cell.label:SetTextColor(COLOR.muted[1], COLOR.muted[2], COLOR.muted[3])
        cell.label:SetText(spec.label)
        cell.value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cell.value:SetPoint("RIGHT", frame, "LEFT", x + Strip.CELL - 6, 1)
        cell.value:SetJustifyH("RIGHT")
        cell.value:SetTextColor(COLOR.text[1], COLOR.text[2], COLOR.text[3])
        cell.line = CreateFrame("StatusBar", nil, frame)
        cell.line:SetStatusBarTexture(Strip.FLAT)
        cell.line:SetStatusBarColor(spec.color[1], spec.color[2], spec.color[3], 1)
        cell.line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x + 1, 1)
        cell.line:SetSize(Strip.CELL - 1, 2)
        cell.line:SetMinMaxValues(0, 1)
        cell.line:SetValue(0)
        cell.roll = Strip.Roll(cell.value)
        view.cells[i] = cell
    end
    view.dot = frame:CreateTexture(nil, "OVERLAY")
    view.dot:SetTexture(Strip.CIRCLE)
    view.dot:SetSize(Strip.DOT, Strip.DOT)
    view.dot:SetPoint("LEFT", frame, "LEFT", 5, 1)
    view.dot:Hide()
    view.pulse = view.dot:CreateAnimationGroup()
    view.pulse:SetLooping("BOUNCE")
    local beat = view.pulse:CreateAnimation("Alpha")
    beat:SetFromAlpha(1)
    beat:SetToAlpha(0.25)
    beat:SetDuration(Strip.PULSE)
    view.tween = function(_, elapsed) Strip.TweenTick(view, elapsed) end
    local x = Strip.CELL * #Strip.CELLS
    local divider = Paint(frame, COLOR.line, "BORDER")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
    divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 0)
    divider:SetWidth(1)
    view.swatch = Paint(frame, Kit.KIND_COLOR.world, "ARTWORK")
    view.swatch:SetSize(7, 7)
    view.swatch:SetPoint("LEFT", frame, "LEFT", x + 8, 0)
    view.tag = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.tag:SetPoint("LEFT", view.swatch, "RIGHT", 5, 0)
    view.tag:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
    view.tag:SetJustifyH("LEFT")
    view.tag:SetWordWrap(false)
    view.tag:SetTextColor(COLOR.text[1], COLOR.text[2], COLOR.text[3])
    Strip.SetAccent(view, Kit.PlayerColor())
    return view
end

function Strip.SetAccent(view, r, g, b)
    view.classLine:SetVertexColor(r, g, b, Strip.LINE_ALPHA)
end

function Strip.SetDot(view, mode)
    if view.dotMode == mode then return end
    view.dotMode = mode
    local icon = view.cells[1].icon
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", view.frame, "LEFT", mode and 14 or 6, 1)
    if not mode then
        view.pulse:Stop()
        view.dot:Hide()
        return
    end
    local color = COLOR[mode]
    view.dot:SetVertexColor(color[1], color[2], color[3], 1)
    view.dot:Show()
    if mode == "live" then view.pulse:Play() else view.pulse:Stop() end
end

function Strip.SetShrunk(view, shrunk, animate)
    view.shrunk = shrunk
    local target = shrunk and Strip.CELL or view.fullWidth
    if view.target == target then return end
    view.target = target
    if not animate or view.width == target then
        view.frame:SetScript("OnUpdate", nil)
        view.width = target
        view.frame:SetWidth(target)
        return
    end
    view.from, view.elapsed = view.width, 0
    view.frame:SetScript("OnUpdate", view.tween)
end

function Strip.TweenTick(view, elapsed)
    local t = view.elapsed + elapsed
    view.elapsed = t
    local p = t >= Strip.SHRINK and 1 or t / Strip.SHRINK
    local width = view.from + (view.target - view.from) * (1 - (1 - p) ^ 3)
    view.width = width
    view.frame:SetWidth(width)
    if p >= 1 then view.frame:SetScript("OnUpdate", nil) end
end

function Strip.Settle(view, counter)
    Kit.CountStop(counter)
    for _, cell in ipairs(view.cells) do cell.roll:Stop() end
end

function Strip.Fonts(view)
    local ppu = BarUtils:PixelsPerUnit(view.frame)
    for _, cell in ipairs(view.cells) do
        BarUtils:CrispFont(cell.label, 9, ppu)
        BarUtils:CrispFont(cell.value, 13, ppu)
    end
    BarUtils:CrispFont(view.tag, 10, ppu)
end

function Strip.ShowTag(view, shown)
    view.fullWidth = Strip.CELL * #Strip.CELLS + (shown and Strip.TAG or 0)
    view.target = nil
    Strip.SetShrunk(view, view.shrunk, false)
    view.swatch:SetShown(shown)
    view.tag:SetShown(shown)
end

function Strip.SetKind(view, kind, name)
    local color = Kit.KIND_COLOR[kind] or Kit.KIND_COLOR.world
    view.swatch:SetVertexColor(color[1], color[2], color[3], 1)
    view.tag:SetText(Kit.KindText(kind, name))
end

function Strip.SetPlain(view, dps, damage, healing, ratios, counter)
    local cells = view.cells
    if counter then
        Kit.CountStop(counter)
        Kit.CountAdd(counter, cells[1].value, dps, Whole)
        Kit.CountAdd(counter, cells[2].value, damage, Whole)
        Kit.CountAdd(counter, cells[3].value, healing, Whole)
        Kit.CountPlay(counter)
        for i = 1, 3 do
            local roll = cells[i].roll
            roll:Stop()
            roll:Play()
        end
    else
        cells[1].value:SetText(Whole(dps))
        cells[2].value:SetText(Whole(damage))
        cells[3].value:SetText(Whole(healing))
    end
    for i = 1, 3 do
        local line = cells[i].line
        line:SetMinMaxValues(0, 1)
        if counter then line:SetValue(0) end
        if ease then line:SetValue(ratios[i], ease) else line:SetValue(ratios[i]) end
    end
end

local function Glide(line, maxValue, value)
    line:SetMinMaxValues(0, maxValue)
    if ease then line:SetValue(value, ease) else line:SetValue(value) end
end

function Strip.SetLiveDamage(view, session, row)
    local cells = view.cells
    if not row then
        cells[1].value:SetText("0")
        cells[2].value:SetText("0")
        return
    end
    cells[1].value:SetText(Rate(row.amountPerSecond))
    cells[2].value:SetText(Short(row.totalAmount))
    Glide(cells[1].line, session.maxAmount, row.totalAmount)
    Glide(cells[2].line, session.maxAmount, row.totalAmount)
end

function Strip.SetLiveHealing(view, session, row)
    local cell = view.cells[3]
    if not row then
        cell.value:SetText("0")
        return
    end
    cell.value:SetText(Short(row.totalAmount))
    Glide(cell.line, session.maxAmount, row.totalAmount)
end


local Controller = {}
Strip.Controller = Controller

function Controller:Create(meter)
    local frame = BarUtils:CreateContainerFrame("SoundAlerterDamageMeterStrip", Strip.CELL * 3 + Strip.TAG, Strip.HEIGHT, -230, meter:GetSettings(), nil, true)
    local view = Strip.Build(frame)
    view.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    view.holder = frame
    self.view, self.meter = view, meter
    self.counter = Kit.Counter(view.frame)
    local fade = frame:CreateAnimationGroup()
    local alpha = fade:CreateAnimation("Alpha")
    alpha:SetDuration(Strip.FADE)
    fade:SetToFinalAlpha(true)
    fade:SetScript("OnFinished", function() if Controller.shownAlpha == 0 then frame:Hide() end end)
    self.fade, self.alpha = fade, alpha
    frame:SetScript("OnEnter", function() Controller.hover = true Controller:Dim() end)
    frame:SetScript("OnLeave", function() Controller.hover = false Controller:Dim() end)
    frame:SetScript("OnDragStart", function(holder) Controller:DragStart(holder) end)
    frame:SetScript("OnDragStop", function(holder) Controller:DragStop(holder) end)
    frame:SetScript("OnMouseUp", function(_, button) Controller:Click(button) end)
end

function Controller:DragStart(holder)
    if self.meter:GetSettings().locked and not IsShiftKeyDown() then return end
    self.moving = true
    holder:StartMoving()
end

function Controller:DragStop(holder)
    holder:StopMovingOrSizing()
    if not self.moving then return end
    self.moving, self.droppedAt = false, GetTime()
    BarUtils:SavePosition(holder, self.meter:GetSettings(), "")
end

function Controller:Click(button)
    if button == "RightButton" then
        SA_Actions.OpenPage(Strip.OPTIONS_PAGE)
        return
    end
    if button ~= "LeftButton" or self.moving or self.droppedAt == GetTime() or IsShiftKeyDown() then return end
    local meter = self.meter
    if meter:GetSettings().locked and meter.ToggleWindow then meter:ToggleWindow() end
end

function Controller:Target()
    local db = self.meter:GetSettings()
    if not db.locked or self.hover or self.state == "live" or self.state == "held" then return 1, false end
    if db.combatOnly then return 0, false end
    return Strip.IDLE_ALPHA, true
end

function Controller:Dim()
    local view = self.view
    local holder = view.holder
    local target, shrunk = self:Target()
    Strip.SetShrunk(view, shrunk, (self.shownAlpha or 0) > 0)
    if target > 0 then holder:Show() end
    if self.shownAlpha == target then return end
    self.fade:Stop()
    self.alpha:SetFromAlpha(holder:GetAlpha())
    self.alpha:SetToAlpha(target)
    self.fade:Play()
    self.shownAlpha = target
end

function Controller:Apply()
    local meter = self.meter
    local db, view = meter:GetSettings(), self.view
    local holder = view.holder
    holder:SetScale(db.scale)
    Strip.Fonts(view)
    Strip.ShowTag(view, db.showTag)
    holder:SetSize(view.fullWidth, Strip.HEIGHT)
    BarUtils:LoadPosition(holder, db, "", 0, -230)
    if not db.locked then
        Strip.SetKind(view, "run", "Deadmines")
        Strip.SetPlain(view, Strip.SAMPLE[1], Strip.SAMPLE[2], Strip.SAMPLE[3], Strip.SAMPLE_RATIOS)
    elseif not self.state then
        self:ShowSession()
    end
    self:Dim()
end

function Controller:OnLive(dirty)
    local view = self.view
    if self.state ~= "live" then
        Strip.Settle(view, self.counter)
        Strip.SetDot(view, "live")
        self.state = "live"
        self:Dim()
        local place = self.meter:Place()
        Strip.SetKind(view, Model.KindOf(place.zone, false) or "world", place.name)
        dirty = nil
    end
    local meter = self.meter
    if not dirty or dirty[METER.DamageDone] or dirty.current then Strip.SetLiveDamage(view, meter:Live("DamageDone"), meter:LiveOwnRow("DamageDone")) end
    if not dirty or dirty[METER.HealingDone] or dirty.current then Strip.SetLiveHealing(view, meter:Live("HealingDone"), meter:LiveOwnRow("HealingDone")) end
end

function Controller:OnCombatEnd()
    self.endedAt = GetTime()
    self.holdToken = (self.holdToken or 0) + 1
    local token = self.holdToken
    self.state = "held"
    Strip.SetDot(self.view, "held")
    self:Dim()
    C_Timer.After(Strip.HOLD, function()
        if token == self.holdToken and self.state == "held" then self:ShowSession() end
    end)
end

function Controller:OnFold(fold)
    if self.state ~= "held" or not fold then return end
    local dps, ratios = Model.FightRatios(self.meter:Store(), fold.fight, fold.kind)
    Strip.SetKind(self.view, fold.kind, fold.session.name)
    Strip.SetPlain(self.view, dps, fold.fight.damage, fold.fight.healing, ratios, self.counter)
end

function Controller:ShowSession()
    self.state = "session"
    Strip.Settle(self.view, self.counter)
    Strip.SetDot(self.view, nil)
    local meter = self.meter
    local place = meter:Place()
    local session, kind = meter:CurrentSession(place)
    local view = self.view
    if session then
        local dps, ratios = Model.SessionRatios(meter:Store(), session)
        Strip.SetKind(view, session.kind, session.name)
        Strip.SetPlain(view, dps, session.damage, session.healing, ratios)
    else
        Strip.SetKind(view, kind, place.name)
        Strip.SetPlain(view, 0, 0, 0, ZERO)
    end
    self:Dim()
end

function Controller:Hide()
    if not self.view then return end
    self.holdToken = (self.holdToken or 0) + 1
    self.state = nil
    self.shownAlpha = nil
    Strip.Settle(self.view, self.counter)
    Strip.SetDot(self.view, nil)
    self.view.holder:Hide()
end

function Strip.Holder()
    local view = Controller.view
    return view and view.holder
end

SoundAlerter.DamageMeterKit = Kit
SoundAlerter.DamageMeterStrip = Strip
