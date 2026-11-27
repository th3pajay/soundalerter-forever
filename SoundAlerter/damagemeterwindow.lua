local SoundAlerter = SoundAlerter
local Model = SA_MeterModel
local Plain = SA_COMPAT.Plain
local BarUtils = SoundAlerter.BarUtils

local Window = {}

Window.W, Window.H = 560, 330
Window.SIDE, Window.TAB_H, Window.PORTRAIT = 104, 27, 82
Window.ROW_H, Window.ROW_GAP = 18, 2
Window.ROWS, Window.TARGET_ROWS, Window.TAKEN_ROWS, Window.HEAL_ROWS = 8, 3, 5, 3
Window.GROW, Window.GROW_FROM = 0.25, 0.2
Window.TEXT_FADE = Window.GROW / 3
Window.PANE_FADE = 0.16
Window.CONFIRM = 3
Window.TABS = { "DAM", "DEF", "PARTY", "GRAPH", "?" }
Window.HELP = {
    { "Where it comes from", "The game's own damage meter. SoundAlerter reads it and saves each fight, so the numbers match what the game counts." },
    { "In combat", "Addons can show the game's numbers but not compare them. Lines measure you against the top of your group, and details wait until the fight ends." },
    { "After a fight", "Each fight is saved by its ID a moment after combat. Fights under %d s count in totals, not in averages, records or the trend." },
    { "Sessions", "World: new at login or after %d min without a fight. Dungeon: one run per visit with %d min grace. A fight with an enemy player is World PvP." },
    { "Hits and avoidance", "Counted from combat text on you and your target, so in a group the hit table is only exact when you fight alone." },
    { "Kept", "%d dungeon runs, %d PvP sessions and %d days of world play. Fight by fight detail only for the current session." },
}
Window.MEMBER_ROWS, Window.MEMBER_COLUMNS, Window.DETAIL_ROWS = 5, 5, 4
Window.FEEDBACK = 2
Window.STATS = { { "damage", "Damage", "DamageDone" }, { "healing", "Healing", "HealingDone" }, { "taken", "Taken", "DamageTaken" } }
Window.UTILITY = { { "interrupts", "Interrupts" }, { "dispels", "Dispels" }, { "deaths", "Deaths" } }
Window.POSTED = { sent = "Posted to group", solo = "Shown in your chat", busy = "Too many lines, wait", combat = "After combat", empty = "Nothing to post" }
Window.FLAT = "Interface\\Buttons\\WHITE8X8"
Window.CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"
Window.GLOW = "Interface\\AddOns\\SoundAlerter\\Textures\\cp_glow"
Window.CIRCLE = "Interface\\AddOns\\SoundAlerter\\Textures\\circle"
Window.SHINE = "Interface\\AddOns\\SoundAlerter\\Textures\\sp_shine"
Window.ICON, Window.BAR_H = 14, 3
Window.TAB_W, Window.GLIDE, Window.GLINT = 52, 0.18, 0.8
Window.GLOW_ALPHA, Window.FAR_GLOW_ALPHA, Window.EDGE_ALPHA = 0.17, 0.06, 0.22

local COLOR = {
    window = { 0.039, 0.047, 0.063, 0.97 },
    line = { 1, 1, 1, 0.07 },
    row = { 1, 1, 1, 0.045 },
    hover = { 1, 1, 1, 0.05 },
    black = { 0, 0, 0, 1 },
    gold = { 1, 0.82, 0 },
    bad = { 0.91, 0.4, 0.49 },
    text = { 0.906, 0.918, 0.941 },
    white = { 1, 1, 1 },
    muted = { 0.588, 0.627, 0.698 },
    dim = { 0.478, 0.518, 0.588 },
    accent = { 1, 0.49, 0.039, 1 },
    good = { 0.239, 0.863, 0.592 },
    dmg = { 0.851, 0.467, 0.086 },
    taken = { 0.835, 0.318, 0.506 },
    heal = { 0.098, 0.62, 0.439 },
}
Window.COLOR = COLOR

local OUT_COLORS = {
    { 0.851, 0.467, 0.086 }, { 1, 0.694, 0.361 }, { 0.541, 0.353, 0.122 }, { 0.75, 0.3, 0.1 },
    { 0.357, 0.396, 0.463 }, { 0.463, 0.506, 0.58 }, { 0.267, 0.302, 0.361 }, { 0.4, 0.42, 0.47 },
    { 0.3, 0.33, 0.4 }, { 0.55, 0.58, 0.64 }, { 0.35, 0.37, 0.42 }, { 0.45, 0.47, 0.52 }, { 0.25, 0.27, 0.3 },
}
local IN_COLORS = {
    { 0.835, 0.318, 0.506 }, { 0.949, 0.608, 0.741 }, { 0.6, 0.25, 0.4 }, { 0.7, 0.15, 0.3 },
    { 0.373, 0.812, 0.647 }, { 0.098, 0.62, 0.439 }, { 0.15, 0.5, 0.36 }, { 0.2, 0.7, 0.55 },
    { 0.224, 0.529, 0.898 }, { 0.561, 0.741, 0.949 }, { 0.4, 0.62, 0.9 }, { 0.3, 0.45, 0.8 }, { 0.5, 0.8, 0.7 },
}
Window.OUT_COLORS, Window.IN_COLORS = OUT_COLORS, IN_COLORS

local ease = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

local function Paint(parent, color, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetTexture(Window.FLAT)
    texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    return texture
end

local function Shade(texture, r, g, b, fromAlpha, toAlpha)
    if texture.SetGradient and CreateColor then
        texture:SetVertexColor(1, 1, 1, 1)
        texture:SetGradient("HORIZONTAL", CreateColor(r, g, b, fromAlpha), CreateColor(r, g, b, toAlpha))
    else
        texture:SetVertexColor(r, g, b, (fromAlpha + toAlpha) / 2)
    end
end
Window.Shade = Shade

local function Glow(parent, width, height, point, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetTexture(Window.GLOW)
    texture:SetSize(width, height)
    texture:SetPoint("CENTER", parent, point, 0, 0)
    texture:SetBlendMode("ADD")
    return texture
end

local function Num(value)
    value = math.floor(value + 0.5)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(value) end
    return string.format("%d", value)
end
Window.Num = Num

local function Live(value)
    if AbbreviateNumbers then return AbbreviateNumbers(value) end
    return ""
end

local function Percent(value)
    return string.format("%d%%", math.floor(value * 100 + 0.5))
end
Window.Percent = Percent

function Window.ChangeText(change, lowerIsBetter)
    if not change then return nil, nil end
    local good = (change >= 0) ~= (lowerIsBetter == true)
    return string.format("%+d%%", change), good
end

function Window:Text(parent, units, color, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    color = color or COLOR.text
    text:SetTextColor(color[1], color[2], color[3])
    if justify then text:SetJustifyH(justify) end
    text:SetWordWrap(false)
    self.texts[#self.texts + 1] = { text, units }
    return text
end

local function Bar(row, x, height, y)
    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetStatusBarTexture(Window.FLAT)
    bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x, y)
    bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, y)
    bar:SetHeight(height)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

function Window.BarColor(row, r, g, b)
    row.bar:SetStatusBarColor(r, g, b, 1)
    row.halo:SetStatusBarColor(r, g, b, 0.16)
end

function Window:Row(parent, width, color, kind)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, Window.ROW_H)
    row.kind = kind
    local x = 0
    if kind ~= "target" then
        row.iconBack = Paint(row, COLOR.black, "ARTWORK")
        row.iconBack:SetSize(Window.ICON + 2, Window.ICON + 2)
        row.iconBack:SetPoint("LEFT", row, "LEFT", 0, 1)
        row.icon = row:CreateTexture(nil, "OVERLAY")
        row.icon:SetSize(Window.ICON, Window.ICON)
        row.icon:SetPoint("CENTER", row.iconBack, "CENTER", 0, 0)
        row.iconBack:Hide()
        row.icon:Hide()
        x = Window.ICON + 6
    end
    row.hl = Paint(row, COLOR.hover)
    row.hl:SetAllPoints()
    row.hl:Hide()
    local track = Paint(row, COLOR.row, "BORDER")
    track:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x, 1)
    track:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
    track:SetHeight(Window.BAR_H)
    row.halo = Bar(row, x, Window.BAR_H + 2, 0)
    row.bar = Bar(row, x, Window.BAR_H, 1)
    Window.BarColor(row, color[1], color[2], color[3])
    row.name = self:Text(row, 11, COLOR.white, "LEFT")
    row.name:SetPoint("LEFT", row, "LEFT", x, 2)
    row.share = self:Text(row, 10, COLOR.muted, "RIGHT")
    row.share:SetPoint("RIGHT", row, "RIGHT", 0, 2)
    row.value = self:Text(row, 11, COLOR.white, "RIGHT")
    row.value:SetPoint("RIGHT", row.share, "LEFT", -6, 0)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) Window:RowEnter(self) end)
    row:SetScript("OnLeave", function(self) Window:RowLeave(self) end)
    row:Hide()
    return row
end

local function FillBar(bar, maxValue, value, sweep)
    bar:SetMinMaxValues(0, maxValue)
    if sweep then bar:SetValue(0) end
    if ease then bar:SetValue(value, ease) else bar:SetValue(value) end
end

local function Fill(row, maxValue, value, sweep)
    FillBar(row.bar, maxValue, value, sweep)
    FillBar(row.halo, maxValue, value, sweep)
end

function Window:SetIcon(row, texture, coords)
    if not row.icon then return end
    if texture then
        row.icon:SetTexture(texture)
        if coords then
            row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end
    row.icon:SetShown(texture ~= nil)
    row.iconBack:SetShown(texture ~= nil)
end

function Window:SetClassIcon(row, class)
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    self:SetIcon(row, coords and Window.CLASS_ICONS or nil, coords)
end

function Window.LiveIcon(row, spellID)
    if not row.icon then return end
    local shown = false
    if not Window.iconRefused and C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
        shown = ok and pcall(row.icon.SetTexture, row.icon, texture)
        if not shown then Window.iconRefused = true end
    end
    if shown then row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    row.icon:SetShown(shown)
    row.iconBack:SetShown(shown)
end

local function Pair(left, right)
    GameTooltip:AddDoubleLine(left, right, COLOR.gold[1], COLOR.gold[2], COLOR.gold[3], 1, 1, 1)
end

local function TipHead(name, icon)
    if icon then name = "|T" .. icon .. ":16:16:0:0:64:64:5:59:5:59|t " .. name end
    GameTooltip:AddLine(name, 1, 1, 1)
end

local function TipShare(row, amount)
    if row.total and row.total > 0 then Pair("Share", Percent(amount / row.total)) end
end

Window.TIPS = {
    spell = function(window, row, item)
        local session = window.session
        TipHead(item[1], window.meter:IconFor(item[1]))
        Pair("Damage", Num(item[2]))
        TipShare(row, item[2])
        local casts = session and session.casts[item[1]]
        if casts and casts > 0 then
            Pair("Casts", tostring(casts))
            Pair("Per cast", Num(item[2] / casts))
        end
        if session and session.seconds > 0 then Pair("DPS", string.format("%.1f", item[2] / session.seconds)) end
    end,
    target = function(_, row, item)
        TipHead(item[1])
        Pair("Damage", Num(item[2]))
        TipShare(row, item[2])
        if Plain(IsInGroup and IsInGroup()) then GameTooltip:AddLine("Damage from the whole group", 0.6, 0.65, 0.72) end
    end,
    taken = function(window, row, item)
        TipHead(item[1], window.meter:IconFor(item[1]))
        Pair("Taken", Num(item[2]))
        TipShare(row, item[2])
    end,
    heal = function(window, row, item)
        local session = window.session
        TipHead(item[1], window.meter:IconFor(item[1]))
        Pair("Healing", Num(item[2]))
        TipShare(row, item[2])
        if session and session.seconds > 0 then Pair("HPS", string.format("%.1f", item[2] / session.seconds)) end
    end,
    detail = function(window, row, item)
        TipHead(item[1], window.meter:IconFor(item[1]))
        Pair((window:StatInfo()), Num(item[2]))
        TipShare(row, item[2])
    end,
    member = function(window, _, m)
        local r, g, b = Window.ClassColor(m.class)
        GameTooltip:AddLine(m.name, r, g, b)
        Pair("Damage", Num(m.damage or 0))
        Pair("Healing", Num(m.healing or 0))
        Pair("Taken", Num(m.taken or 0))
        for _, util in ipairs(Window.UTILITY) do
            local value = m[util[1]]
            if value and value > 0 then Pair(util[2], tostring(value)) end
        end
        if window.memberPick ~= m.name then GameTooltip:AddLine("Click for their spells", 0.6, 0.65, 0.72) end
    end,
}

function Window:RowEnter(row)
    row.hl:Show()
    if not GameTooltip then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if self.meter:InCombat() or not row.item then
        GameTooltip:AddLine("Details show after the fight", 0.6, 0.65, 0.72)
    else
        Window.TIPS[row.kind](self, row, row.item)
    end
    GameTooltip:Show()
end

function Window:RowLeave(row)
    row.hl:Hide()
    if GameTooltip then GameTooltip:Hide() end
end

function Window:Rows(parent, count, width, color, x, y, kind)
    local rows = {}
    for i = 1, count do
        local row = self:Row(parent, width, color, kind)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - (i - 1) * (Window.ROW_H + Window.ROW_GAP))
        rows[i] = row
    end
    return rows
end

function Window:Label(parent, x, y, width, left, right)
    local a = self:Text(parent, 10, COLOR.muted, "LEFT")
    a:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    a:SetText(left or "")
    local b = self:Text(parent, 10, COLOR.muted, "RIGHT")
    b:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y)
    b:SetText(right or "")
    return a, b
end

function Window:Segments(parent, x, y, width, colors)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width, 14)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    bar.parts, bar.colors = {}, colors
    for i = 1, Model.SLOTS do
        local part = Paint(bar, colors[i], "ARTWORK")
        part:SetHeight(14)
        part:Hide()
        bar.parts[i] = part
    end
    bar.empty = Paint(bar, COLOR.row)
    bar.empty:SetAllPoints()
    return bar
end

function Window.SegmentWidths(counts, width, gap, out)
    local total, shown = 0, 0
    for i = 1, Model.SLOTS do
        total = total + counts[i]
        if counts[i] > 0 then shown = shown + 1 end
    end
    for i = 1, Model.SLOTS do out[i] = 0 end
    if total == 0 then return out, 0 end
    local room = width - gap * (shown - 1)
    for i = 1, Model.SLOTS do
        if counts[i] > 0 then out[i] = math.max(1, room * counts[i] / total) end
    end
    return out, total
end

local widths = {}
function Window.SetSegments(bar, counts)
    local _, total = Window.SegmentWidths(counts, bar:GetWidth(), 2, widths)
    local x = 0
    for i = 1, Model.SLOTS do
        local part = bar.parts[i]
        if widths[i] > 0 then
            part:ClearAllPoints()
            part:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
            part:SetWidth(widths[i])
            part:Show()
            x = x + widths[i] + 2
        else
            part:Hide()
        end
    end
    bar.empty:SetShown(total == 0)
end

function Window.CountsText(counts)
    local parts = {}
    for i = 1, Model.SLOTS do
        if counts[i] > 0 then parts[#parts + 1] = string.lower(Model.SLOT_NAMES[i]) .. " " .. counts[i] end
    end
    if #parts == 0 then return "Nothing counted yet." end
    local text = table.concat(parts, ", ")
    return text:sub(1, 1):upper() .. text:sub(2)
end

function Window:KeyValue(parent, x, y, width)
    local key = self:Text(parent, 11, COLOR.muted, "LEFT")
    key:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local value = self:Text(parent, 11, COLOR.white, "RIGHT")
    value:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y)
    local rule = Paint(parent, COLOR.line, "BORDER")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 15)
    rule:SetWidth(width)
    return { key = key, value = value, rule = rule }
end

function Window:BuildSide(frame)
    local side = CreateFrame("Frame", nil, frame)
    side:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    side:SetSize(Window.SIDE, Window.H)
    local edge = Paint(side, COLOR.line, "BORDER")
    edge:SetPoint("TOPRIGHT") edge:SetPoint("BOTTOMRIGHT") edge:SetWidth(1)
    local portrait = CreateFrame("Frame", nil, side)
    portrait:SetPoint("TOPLEFT", side, "TOPLEFT", 0, 0)
    portrait:SetSize(Window.SIDE - 1, Window.PORTRAIT)
    portrait:SetClipsChildren(true)
    local under = Paint(portrait, COLOR.line, "BORDER")
    under:SetPoint("BOTTOMLEFT") under:SetPoint("BOTTOMRIGHT") under:SetHeight(1)
    self.halo = Glow(portrait, 104, 104, "CENTER")
    self.ring = portrait:CreateTexture(nil, "BORDER")
    self.ring:SetTexture(Window.CIRCLE)
    self.ring:SetSize(60, 60)
    self.ring:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    local hole = portrait:CreateTexture(nil, "ARTWORK")
    hole:SetTexture(Window.CIRCLE)
    hole:SetVertexColor(0, 0, 0, 1)
    hole:SetSize(58, 58)
    hole:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    self.emblem = portrait:CreateTexture(nil, "OVERLAY")
    self.emblem:SetSize(54, 54)
    self.emblem:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    local mask = portrait:CreateMaskTexture()
    mask:SetTexture(Window.CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(self.emblem)
    self.emblem:AddMaskTexture(mask)
    self.ribbon = Paint(portrait, COLOR.accent, "OVERLAY")
    self.ribbon:SetSize(70, 8)
    self.ribbon:SetPoint("CENTER", portrait, "TOPRIGHT", -12, -12)
    self.ribbon:SetRotation(-math.pi / 4)
    self.heroes = {}
    local top = Window.PORTRAIT + 2
    local height = math.floor((Window.H - top - 4) / 4)
    for i = 1, 4 do
        local card = CreateFrame("Frame", nil, side)
        card:SetPoint("TOPLEFT", side, "TOPLEFT", 9, -(top + (i - 1) * height))
        card:SetSize(Window.SIDE - 18, height)
        if i > 1 then
            local rule = Paint(card, COLOR.line, "BORDER")
            rule:SetPoint("TOPLEFT") rule:SetPoint("TOPRIGHT") rule:SetHeight(1)
        end
        card.label = self:Text(card, 10, COLOR.muted, "LEFT")
        card.label:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -8)
        card.value = self:Text(card, 19, COLOR.white, "LEFT")
        card.value:SetPoint("TOPLEFT", card.label, "BOTTOMLEFT", 0, -2)
        card.value:SetPoint("RIGHT", card, "RIGHT", 0, 0)
        card.note = self:Text(card, 10, COLOR.dim, "LEFT")
        card.note:SetPoint("TOPLEFT", card.value, "BOTTOMLEFT", 0, -3)
        card.note:SetPoint("RIGHT", card, "RIGHT", 0, 0)
        card.change = self:Text(card, 10, COLOR.good, "LEFT")
        card.change:SetPoint("TOPLEFT", card.note, "TOPLEFT", 0, 0)
        card.chip = Paint(card, COLOR.good)
        card.chip:SetHeight(12)
        card.chip:SetPoint("LEFT", card.change, "LEFT", -3, 0)
        card.chip:SetPoint("RIGHT", card.change, "RIGHT", 3, 0)
        card.chip:Hide()
        self.heroes[i] = card
    end
    self.counter = SoundAlerter.DamageMeterKit.Counter(side)
    self:BuildGlint(self.heroes[1], height)
end

function Window:BuildGlint(card, height)
    local clip = CreateFrame("Frame", nil, card)
    clip:SetAllPoints(card)
    clip:SetClipsChildren(true)
    local shine = clip:CreateTexture(nil, "OVERLAY")
    shine:SetTexture(Window.SHINE)
    shine:SetSize(24, height)
    shine:SetPoint("RIGHT", clip, "LEFT", 0, 0)
    shine:SetBlendMode("ADD")
    shine:SetVertexColor(COLOR.gold[1], COLOR.gold[2], COLOR.gold[3], 0.7)
    shine:Hide()
    local group = shine:CreateAnimationGroup()
    local move = group:CreateAnimation("Translation")
    move:SetOffset(Window.SIDE, 0)
    move:SetDuration(Window.GLINT)
    if move.SetSmoothing then move:SetSmoothing("OUT") end
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetStartDelay(Window.GLINT * 0.6)
    fade:SetDuration(Window.GLINT * 0.4)
    group:SetScript("OnFinished", function() shine:Hide() end)
    self.glint, self.glintShine = group, shine
end

function Window:PlayGlint()
    self.glint:Stop()
    self.glintShine:Show()
    self.glint:Play()
end

function Window:BuildTabs(frame)
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", Window.SIDE, 0)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    bar:SetHeight(Window.TAB_H)
    Paint(bar, { 1, 1, 1, 0.025 }):SetAllPoints()
    local under = Paint(bar, COLOR.line, "BORDER")
    under:SetPoint("BOTTOMLEFT") under:SetPoint("BOTTOMRIGHT") under:SetHeight(1)
    self.tabBar = bar
    self.tabButtons = {}
    local x = 0
    for i, name in ipairs(Window.TABS) do
        local button = CreateFrame("Button", nil, bar)
        button:SetSize(Window.TAB_W, Window.TAB_H)
        button:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
        button.label = self:Text(button, 12, COLOR.muted, "CENTER")
        button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.label:SetText(name)
        button:SetScript("OnClick", function() Window:Select(name) end)
        button.tab = name
        self.tabButtons[i] = button
        x = x + Window.TAB_W
    end
    local indicator = CreateFrame("Frame", nil, bar)
    indicator:SetSize(Window.TAB_W, 2)
    indicator.glow = Glow(indicator, Window.TAB_W - 8, 12, "CENTER", "ARTWORK")
    indicator.line = Paint(indicator, COLOR.accent, "OVERLAY")
    indicator.line:SetPoint("TOPLEFT", indicator, "TOPLEFT", 10, 0)
    indicator.line:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -10, 0)
    local glide = indicator:CreateAnimationGroup()
    local move = glide:CreateAnimation("Translation")
    move:SetDuration(Window.GLIDE)
    if move.SetSmoothing then move:SetSmoothing("OUT") end
    glide:SetScript("OnFinished", function() Window:PlaceIndicator(Window.indicatorX) end)
    self.indicator, self.glide, self.glideMove = indicator, glide, move
    local close = CreateFrame("Button", nil, bar)
    close:SetSize(Window.TAB_H, Window.TAB_H)
    close:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    local divider = Paint(close, COLOR.line, "BORDER")
    divider:SetPoint("TOPLEFT") divider:SetPoint("BOTTOMLEFT") divider:SetWidth(1)
    close.label = self:Text(close, 14, COLOR.muted, "CENTER")
    close.label:SetPoint("CENTER", close, "CENTER", 0, 0)
    close.label:SetText("x")
    close.hl = Paint(close, { COLOR.bad[1], COLOR.bad[2], COLOR.bad[3], 0.25 })
    close.hl:SetAllPoints()
    close.hl:Hide()
    close:SetScript("OnEnter", function() close.hl:Show() close.label:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() close.hl:Hide() close.label:SetTextColor(COLOR.muted[1], COLOR.muted[2], COLOR.muted[3]) end)
    close:SetScript("OnClick", function() Window:Close() end)
    self.closeButton = close
    self.title = self:Text(bar, 10, COLOR.muted, "RIGHT")
    self.title:SetPoint("RIGHT", close, "LEFT", -8, 0)
    self.title:SetPoint("LEFT", bar, "LEFT", #Window.TABS * Window.TAB_W + 14, 0)
    self.titleMark = Paint(bar, COLOR.good, "ARTWORK")
    self.titleMark:SetSize(5, 5)
    self.titleMark:SetRotation(math.pi / 4)
    self.titleMark:SetPoint("RIGHT", self.title, "LEFT", -5, 0)
    self.titleMark:Hide()
end

function Window:PlaceIndicator(x)
    self.indicator:ClearAllPoints()
    self.indicator:SetPoint("BOTTOMLEFT", self.tabBar, "BOTTOMLEFT", x, 0)
end

function Window:MoveIndicator(index, glide)
    local x = (index - 1) * Window.TAB_W
    local from = self.indicatorX
    self.glide:Stop()
    self.indicatorX = x
    if glide and from and from ~= x then
        self:PlaceIndicator(from)
        self.glideMove:SetOffset(x - from, 0)
        self.glide:Play()
        return true
    end
    self:PlaceIndicator(x)
    return false
end

function Window.TitleText(session)
    local name = SoundAlerter.DamageMeterKit.KindText(session.kind, session.name)
    local run = session.kind == "run"
    local span = Model.Clock(run and math.max(0, session.lastAt - session.start) or session.seconds)
    local unit
    if run then unit = session.count == 1 and " pull" or " pulls" else unit = session.count == 1 and " fight" or " fights" end
    return "|cffeef0f4" .. name .. "|r   " .. span .. "  ·  " .. session.count .. unit
end

function Window:SetTitle(session)
    if not session then
        self.title:SetText("")
        self.titleMark:Hide()
        return
    end
    self.title:SetText(Window.TitleText(session))
    local color = SoundAlerter.DamageMeterKit.KIND_COLOR[session.kind] or COLOR.good
    self.titleMark:SetVertexColor(color[1], color[2], color[3], 1)
    self.titleMark:Show()
end

function Window:SetAccent(r, g, b)
    local accent = COLOR.accent
    accent[1], accent[2], accent[3] = r, g, b
    self.glows[1]:SetVertexColor(r, g, b, Window.GLOW_ALPHA)
    self.glows[2]:SetVertexColor(r, g, b, Window.FAR_GLOW_ALPHA)
    for _, edge in ipairs(self.edges) do edge:SetVertexColor(r, g, b, Window.EDGE_ALPHA) end
    Shade(self.topLine, r, g, b, 1, 0)
    self.halo:SetVertexColor(r, g, b, 0.3)
    self.ring:SetVertexColor(r, g, b, 1)
    self.ribbon:SetVertexColor(r, g, b, 1)
    self.indicator.line:SetVertexColor(r, g, b, 1)
    self.indicator.glow:SetVertexColor(r, g, b, 0.45)
end

function Window:BuildDam(body, width)
    local pane = CreateFrame("Frame", nil, body)
    pane:SetAllPoints(body)
    local left = math.floor(width * 0.58)
    local right = width - left - 12
    local rx = left + 12
    pane.title, pane.sub = self:Label(pane, 0, 0, left, "Abilities", "damage, share")
    pane.rows = self:Rows(pane, Window.ROWS, left, COLOR.dmg, 0, -16, "spell")
    for i, row in ipairs(pane.rows) do
        row:SetScript("OnMouseUp", function() Window:Pick(i) end)
    end
    local hy = -16 - Window.ROWS * (Window.ROW_H + Window.ROW_GAP) - 6
    pane.hitTitle, pane.hitSub = self:Label(pane, 0, hy, left, "Hit table", "")
    pane.hits = self:Segments(pane, 0, hy - 15, left, OUT_COLORS)
    pane.hitNote = self:Text(pane, 10, COLOR.dim, "LEFT")
    pane.hitNote:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, hy - 33)
    pane.hitNote:SetWidth(left)
    pane.hitNote:SetWordWrap(true)
    pane.detailTitle = self:Text(pane, 11, COLOR.text, "LEFT")
    pane.detailTitle:SetPoint("TOPLEFT", pane, "TOPLEFT", rx, 0)
    pane.detailTitle:SetWidth(right)
    pane.kv = {}
    for i = 1, 5 do pane.kv[i] = self:KeyValue(pane, rx, -18 - (i - 1) * 17, right) end
    pane.wait = self:Text(pane, 10, COLOR.dim, "LEFT")
    pane.wait:SetPoint("TOPLEFT", pane, "TOPLEFT", rx, -18)
    pane.wait:SetWidth(right)
    pane.wait:SetWordWrap(true)
    pane.wait:SetText("Shares, casts and per-cast numbers fill in about a second after the fight. The game hides them while it runs.")
    local ty = -18 - 5 * 17 - 6
    pane.targetTitle, pane.targetSub = self:Label(pane, rx, ty, right, "Targets", "")
    pane.targets = self:Rows(pane, Window.TARGET_ROWS, right, COLOR.dmg, rx, ty - 16, "target")
    local ry = ty - 16 - Window.TARGET_ROWS * (Window.ROW_H + Window.ROW_GAP) - 6
    pane.recordTitle = self:Label(pane, rx, ry, right, "Records", "")
    pane.record = self:KeyValue(pane, rx, ry - 16, right)
    return pane
end

function Window:BuildDef(body, width)
    local pane = CreateFrame("Frame", nil, body)
    pane:SetAllPoints(body)
    local left = math.floor(width * 0.58)
    local right = width - left - 12
    local rx = left + 12
    pane.avoidTitle, pane.avoidSub = self:Label(pane, 0, 0, width, "Incoming attacks", "")
    pane.avoid = self:Segments(pane, 0, -15, width, IN_COLORS)
    pane.avoidNote = self:Text(pane, 10, COLOR.dim, "LEFT")
    pane.avoidNote:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -33)
    pane.avoidNote:SetWidth(width)
    local y = -52
    pane.takenTitle, pane.takenSub = self:Label(pane, 0, y, left, "Damage taken", "")
    pane.taken = self:Rows(pane, Window.TAKEN_ROWS, left, COLOR.taken, 0, y - 16, "taken")
    pane.healTitle, pane.healSub = self:Label(pane, rx, y, right, "Healing done", "")
    pane.heals = self:Rows(pane, Window.HEAL_ROWS, right, COLOR.heal, rx, y - 16, "heal")
    local dy = y - 16 - Window.HEAL_ROWS * (Window.ROW_H + Window.ROW_GAP) - 6
    pane.deathTitle = self:Label(pane, rx, dy, right, "Deaths", "")
    pane.deaths = self:Text(pane, 11, COLOR.text, "LEFT")
    pane.deaths:SetPoint("TOPLEFT", pane, "TOPLEFT", rx, dy - 16)
    pane.deaths:SetWidth(right)
    return pane
end

function Window.HelpText(index)
    local item = Window.HELP[index]
    if index == 3 then return item[1], string.format(item[2], Model.MIN_SECONDS) end
    if index == 4 then return item[1], string.format(item[2], Model.IDLE_SECONDS / 60, Model.RUN_GRACE / 60) end
    if index == 6 then return item[1], string.format(item[2], Model.RUNS, Model.PVP, Model.WORLD_DAYS) end
    return item[1], item[2]
end

function Window:BuildHelp(body, width)
    local pane = CreateFrame("Frame", nil, body)
    pane:SetAllPoints(body)
    pane.mark = Paint(pane, COLOR.good, "ARTWORK")
    pane.mark:SetSize(6, 6)
    pane.mark:SetRotation(math.pi / 4)
    pane.mark:SetPoint("TOPLEFT", pane, "TOPLEFT", 2, -4)
    pane.status = self:Text(pane, 11, COLOR.white, "LEFT")
    pane.status:SetPoint("TOPLEFT", pane, "TOPLEFT", 14, 0)
    pane.status:SetWidth(width - 14)
    local rule = Paint(pane, COLOR.line, "BORDER")
    rule:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -19)
    rule:SetSize(width, 1)
    local column = math.floor((width - 16) / 2)
    pane.blocks = {}
    for i = 1, #Window.HELP do
        local x = (i - 1) % 2 * (column + 16)
        local y = -28 - math.floor((i - 1) / 2) * 76
        local head = self:Text(pane, 10, COLOR.gold, "LEFT")
        head:SetPoint("TOPLEFT", pane, "TOPLEFT", x, y)
        local text = self:Text(pane, 10, COLOR.text, "LEFT")
        text:SetPoint("TOPLEFT", pane, "TOPLEFT", x, y - 14)
        text:SetWidth(column)
        text:SetWordWrap(true)
        local title, words = Window.HelpText(i)
        head:SetText(string.upper(title))
        text:SetText(words)
        pane.blocks[i] = { head = head, text = text }
    end
    return pane
end

function Window.StatusText(status, refresh, session)
    if status == "unavailable" then return "The game's damage meter is not available here.", COLOR.bad end
    if status == "combat" then return "In combat: reading the game's meter every " .. refresh .. " s.", COLOR.gold end
    if status == "saving" then return "Fight over: saving it now.", COLOR.gold end
    if session and session.count > 0 then return "Ready. Last fight saved at " .. date("%H:%M", session.lastAt) .. ".", COLOR.good end
    return "Ready. No fights saved yet.", COLOR.good
end

function Window:RenderHelp(session)
    local pane = self.panes["?"]
    if not pane then return end
    local meter = self.meter
    local text, color = Window.StatusText(meter:Status(), meter:GetSettings().refresh, session)
    pane.status:SetText(text)
    pane.mark:SetVertexColor(color[1], color[2], color[3], 1)
end

function Window:Build(meter)
    self.meter, self.texts = meter, {}
    local frame = CreateFrame("Frame", "SoundAlerterDamageMeterWindow", UIParent)
    frame:SetSize(Window.W, Window.H)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(20)
    frame:EnableMouse(true)
    frame:Hide()
    self.frame = frame
    Paint(frame, COLOR.window):SetAllPoints()
    local ambient = CreateFrame("Frame", nil, frame)
    ambient:SetAllPoints(frame)
    ambient:SetClipsChildren(true)
    self.glows = { Glow(ambient, 640, 420, "TOPLEFT"), Glow(ambient, 420, 280, "BOTTOMRIGHT") }
    local edges = { Paint(frame, COLOR.line, "BORDER"), Paint(frame, COLOR.line, "BORDER"), Paint(frame, COLOR.line, "BORDER"), Paint(frame, COLOR.line, "BORDER") }
    self.edges = edges
    edges[1]:SetPoint("TOPLEFT") edges[1]:SetPoint("TOPRIGHT") edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT") edges[2]:SetPoint("BOTTOMRIGHT") edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT") edges[3]:SetPoint("BOTTOMLEFT") edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT") edges[4]:SetPoint("BOTTOMRIGHT") edges[4]:SetWidth(1)
    local content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints(frame)
    self.content = content
    self:BuildSide(content)
    self:BuildTabs(content)
    self.topLine = Paint(content, COLOR.accent, "OVERLAY")
    self.topLine:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    self.topLine:SetSize(Window.SIDE, 2)
    local body = CreateFrame("Frame", nil, content)
    body:SetPoint("TOPLEFT", content, "TOPLEFT", Window.SIDE + 10, -(Window.TAB_H + 8))
    body:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 8)
    local width = Window.W - Window.SIDE - 20
    self.body = body
    self.paneWidth = width
    self.panes, self.paneFades = {}, {}
    self.stat = "damage"
    self.empty = self:Text(body, 11, COLOR.dim, "LEFT")
    self.empty:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -20)
    self.empty:SetText("No fights yet this session. Fight something and the details show here.")
    self.newButton = CreateFrame("Button", nil, body)
    self.newButton:SetSize(118, 18)
    self.newButton:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
    Paint(self.newButton, COLOR.row):SetAllPoints()
    self.newButton.label = self:Text(self.newButton, 10, COLOR.muted, "CENTER")
    self.newButton.label:SetPoint("CENTER", self.newButton, "CENTER", 0, 0)
    self.newButton.label:SetText("New session")
    self.newButton:SetScript("OnClick", function() Window:NewSessionClick() end)
    self.postButton = CreateFrame("Button", nil, body)
    self.postButton:SetSize(118, 18)
    self.postButton:SetPoint("RIGHT", self.newButton, "LEFT", -6, 0)
    Paint(self.postButton, COLOR.row):SetAllPoints()
    self.postButton.label = self:Text(self.postButton, 10, COLOR.muted, "CENTER")
    self.postButton.label:SetPoint("CENTER", self.postButton, "CENTER", 0, 0)
    self.postButton.label:SetText("Post top 5")
    self.postButton:SetScript("OnClick", function() Window:PostClick() end)
    local grow = frame:CreateAnimationGroup()
    local scale = grow:CreateAnimation("Scale")
    scale:SetDuration(Window.GROW)
    scale:SetScaleFrom(Window.GROW_FROM, Window.GROW_FROM)
    scale:SetScaleTo(1, 1)
    if scale.SetSmoothing then scale:SetSmoothing("OUT") end
    self.grow, self.growScale = grow, scale
    local reveal = content:CreateAnimationGroup()
    local fadeIn = reveal:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetStartDelay(Window.GROW - Window.TEXT_FADE)
    fadeIn:SetDuration(Window.TEXT_FADE)
    reveal:SetToFinalAlpha(true)
    self.reveal = reveal
    frame:SetScript("OnEvent", function(_, event)
        if event == "UPDATE_SHAPESHIFT_FORM" then Window:UpdateEmblem() end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, "SoundAlerterDamageMeterWindow") end
    frame:SetScript("OnHide", function() Window:OnHidden() end)
    self.tab = "DAM"
    self.pick = nil
end

Window.BUILDERS = {
    DAM = function(window, body, width) return window:BuildDam(body, width) end,
    DEF = function(window, body, width) return window:BuildDef(body, width) end,
    PARTY = function(window, body, width) return window:BuildParty(body, width) end,
    GRAPH = function(window, body, width) return SoundAlerter.DamageMeterGraph.Build(window, body, width) end,
    ["?"] = function(window, body, width) return window:BuildHelp(body, width) end,
}

function Window:Pane(name)
    local pane = self.panes[name]
    if pane then return pane end
    pane = Window.BUILDERS[name](self, self.body, self.paneWidth)
    local group = pane:CreateAnimationGroup()
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.2)
    alpha:SetToAlpha(1)
    alpha:SetDuration(Window.PANE_FADE)
    group:SetToFinalAlpha(true)
    self.panes[name], self.paneFades[name] = pane, group
    if self.ppu then self:Fonts() end
    return pane
end

function Window:Fonts()
    local ppu = BarUtils:PixelsPerUnit(self.frame)
    local first = 1
    if ppu == self.ppu then first = (self.fonted or 0) + 1 end
    local texts = self.texts
    for i = first, #texts do BarUtils:CrispFont(texts[i][1], texts[i][2], ppu) end
    self.ppu, self.fonted = ppu, #texts
    return #texts - first + 1
end

function Window.ActiveFormIcon()
    if not (GetNumShapeshiftForms and GetShapeshiftFormInfo) then return nil end
    local count = Plain(GetNumShapeshiftForms()) or 0
    for i = 1, count do
        local texture, active = GetShapeshiftFormInfo(i)
        if Plain(active) == true then return Plain(texture) end
    end
    return nil
end

function Window:UpdateEmblem()
    local emblem = self.emblem
    local _, class = UnitClass("player")
    class = Plain(class)
    self:SetAccent(SoundAlerter.DamageMeterKit.PlayerColor())
    local icon = Window.ActiveFormIcon()
    if icon then
        emblem:SetTexture(icon)
        emblem:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return
    end
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
        emblem:SetTexture(Window.CLASS_ICONS)
        emblem:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
end

function Window:Place()
    local frame, holder = self.frame, SoundAlerter.DamageMeterStrip.Holder()
    local _, y = holder:GetCenter()
    local above = y and y < UIParent:GetHeight() / 2
    frame:ClearAllPoints()
    if above then
        frame:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", 0, 6)
    else
        frame:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -6)
    end
    self.growScale:SetOrigin(above and "BOTTOMLEFT" or "TOPLEFT", 0, 0)
    return above
end

function Window:Open()
    local frame, meter = self.frame, self.meter
    frame:SetScale(meter:GetSettings().windowScale)
    self:Place()
    frame:Show()
    self:Fonts()
    self:UpdateEmblem()
    frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    self.onMeter = self.onMeter or function(reason, dirty) Window:OnMeter(reason, dirty) end
    meter:Subscribe("window", self.onMeter)
    self:Select(self.tab, true)
    self.content:SetAlpha(0)
    self.grow:Play()
    self.reveal:Play()
end

function Window:Close()
    if self.frame then self.frame:Hide() end
end

function Window:OnHidden()
    self.frame:UnregisterEvent("UPDATE_SHAPESHIFT_FORM")
    self.meter:Unsubscribe("window")
    self.confirmToken = (self.confirmToken or 0) + 1
    self.confirming = false
    self.newButton.label:SetText("New session")
    SoundAlerter.DamageMeterKit.CountStop(self.counter)
end

function Window:Toggle(meter)
    if not self.frame then self:Build(meter) end
    if self.frame:IsShown() then self:Close() else self:Open() end
end

function Window:IsOpen()
    return self.frame ~= nil and self.frame:IsShown()
end

function Window:Select(tab, quiet)
    self.tab = tab
    for i, button in ipairs(self.tabButtons) do
        local on = button.tab == tab
        local color = on and COLOR.white or COLOR.muted
        button.label:SetTextColor(color[1], color[2], color[3])
        if on then self:MoveIndicator(i, not quiet) end
    end
    self:Pane(tab)
    for name, pane in pairs(self.panes) do pane:SetShown(name == tab) end
    if not quiet and self.paneFades[tab] then self.paneFades[tab]:Play() end
    self:Refresh()
end

function Window:Session()
    local meter = self.meter
    local session = meter:CurrentSession()
    if session then Model.Complete(session) end
    return session, meter:Store()
end

function Window:Refresh()
    if self.meter:InCombat() then
        self:OnLive(nil)
    else
        self:Render()
    end
end

function Window:OnMeter(reason, data)
    if reason == "live" then
        self:OnLive(data)
    elseif reason == "start" then
        Window.iconRefused = nil
        self:OnLive(nil)
    elseif reason == "end" or reason == "saved" then
        if self.tab == "?" and self:IsOpen() then self:RenderHelp(self:Session()) end
    elseif reason == "fold" then
        self.counting = true
        self:Render()
        self.counting = false
        SoundAlerter.DamageMeterKit.CountPlay(self.counter)
        local fold = data
        if fold and fold.fresh and self:IsOpen() then self:PlayGlint() end
    end
end

function Window:SetHero(card, hero)
    card.label:SetText(hero.label)
    local value
    if hero.text then
        value = hero.text
    elseif hero.value == nil then
        value = "-"
    elseif hero.percent then
        value = Percent(hero.value)
    else
        value = Num(hero.value)
    end
    if self.counting and type(hero.value) == "number" and not hero.text then
        SoundAlerter.DamageMeterKit.CountAdd(self.counter, card.value, hero.value, hero.percent and Percent or Num)
    else
        card.value:SetText(value)
    end
    local text, good = Window.ChangeText(hero.change, hero.label == "Taken")
    if text then
        local color = good and COLOR.good or COLOR.bad
        card.note:SetText("")
        card.change:SetTextColor(color[1], color[2], color[3])
        card.change:SetText(text)
        card.chip:SetVertexColor(color[1], color[2], color[3], 0.14)
        card.chip:Show()
    else
        Window.HideChange(card)
        card.note:SetText(hero.note or "")
    end
end

function Window.HideChange(card)
    card.change:SetText("")
    card.chip:Hide()
end

local ranked, rankedTargets, rankedHeals = {}, {}, {}
local detailLines = { { "Damage" }, { "Casts" }, { "Per cast" }, { "DPS" }, { "Share" } }

function Window:SetRows(rows, list, total)
    local top = list[1] and list[1][2] or 0
    for i, row in ipairs(rows) do
        local item = list[i]
        if item then
            row.item, row.total = item, total
            row.name:SetText(item[1])
            row.value:SetText(Num(item[2]))
            row.share:SetText(total > 0 and Percent(item[2] / total) or "")
            Fill(row, top > 0 and top or 1, item[2], self.counting)
            if row.icon then self:SetIcon(row, self.meter:IconFor(item[1])) end
            row:Show()
        else
            row.item = nil
            row:Hide()
        end
    end
end

function Window:Render()
    if not self:IsOpen() then return end
    if not self.counting then SoundAlerter.DamageMeterKit.CountStop(self.counter) end
    local session, store = self:Session()
    self.session = session
    local has = session ~= nil and session.count > 0
    local help = self.tab == "?"
    self:SetTitle(has and session or nil)
    self.empty:SetShown(not has and not help)
    for name, pane in pairs(self.panes) do pane:SetShown((has or help) and name == self.tab) end
    if help then self:RenderHelp(session) end
    if not has then
        for _, card in ipairs(self.heroes) do
            card.label:SetText("")
            card.value:SetText("-")
            card.note:SetText("")
            Window.HideChange(card)
        end
        return
    end
    local heroes = Model.Heroes(self.tab, session, store)
    for i, card in ipairs(self.heroes) do self:SetHero(card, heroes[i]) end
    if self.tab == "DEF" then
        self:RenderDef(session)
    elseif self.tab == "PARTY" then
        self:RenderParty(session)
    elseif self.tab == "GRAPH" then
        SoundAlerter.DamageMeterGraph.Render(self.panes.GRAPH, session, store)
    elseif not help then
        self:RenderDam(session, store)
    end
end

function Window:Pick(index)
    if self.meter:InCombat() then return end
    local item = self.spellList and self.spellList[index]
    if not item then return end
    self.pick = item[1]
    self:Render()
end

function Window:RenderDam(session, store)
    local pane = self.panes.DAM
    local list, total = Model.Ranked(session.spells, Window.ROWS, ranked)
    self.spellList = list
    pane.sub:SetText("damage, share")
    self:SetRows(pane.rows, list, total)
    local index = 1
    for i, item in ipairs(list) do
        if item[1] == self.pick then index = i end
    end
    for i, row in ipairs(pane.rows) do row:SetAlpha((list[i] and i ~= index) and 0.82 or 1) end
    local item = list[index]
    self.pick = item and item[1]
    pane.wait:Hide()
    pane.detailTitle:SetText(item and item[1] or "")
    local casts = item and session.casts[item[1]]
    local lines = detailLines
    lines[1][2] = item and Num(item[2]) or "-"
    lines[2][2] = casts and tostring(casts) or "-"
    lines[3][2] = (item and casts and casts > 0) and Num(item[2] / casts) or "-"
    lines[4][2] = (item and session.seconds > 0) and string.format("%.1f", item[2] / session.seconds) or "-"
    lines[5][2] = (item and total > 0) and Percent(item[2] / total) or "-"
    for i, kv in ipairs(pane.kv) do
        kv.key:SetText(lines[i][1])
        kv.value:SetText(lines[i][2])
        kv.key:Show() kv.value:Show() kv.rule:Show()
    end
    local targets, targetTotal = Model.Ranked(session.targets, Window.TARGET_ROWS, rankedTargets)
    pane.targetSub:SetText(Plain(IsInGroup and IsInGroup()) and "whole group" or "")
    self:SetRows(pane.targets, targets, targetTotal)
    local best = Model.BestDps(store, session.kind)
    pane.record.key:SetText("Best fight DPS")
    pane.record.value:SetText(best and Num(best) or "-")
    pane.hitSub:SetText(Plain(IsInGroup and IsInGroup()) and "solo only" or "")
    Window.SetSegments(pane.hits, session.hits)
    pane.hitNote:SetText(Window.CountsText(session.hits))
end

function Window:RenderDef(session)
    local pane = self.panes.DEF
    local rate = Model.AvoidRate(session.avoid)
    pane.avoidSub:SetText(rate and (Percent(rate) .. " avoided") or "")
    Window.SetSegments(pane.avoid, session.avoid)
    pane.avoidNote:SetText(Window.CountsText(session.avoid))
    local taken, takenTotal = Model.Ranked(session.takenSpells, Window.TAKEN_ROWS, ranked)
    pane.takenSub:SetText(Num(session.taken))
    self:SetRows(pane.taken, taken, math.max(takenTotal, session.taken))
    local heals, healTotal = Model.Ranked(session.healSpells, Window.HEAL_ROWS, rankedHeals)
    pane.healSub:SetText(session.seconds > 0 and (Num(session.healing / session.seconds) .. " HPS") or "")
    self:SetRows(pane.heals, heals, math.max(healTotal, session.healing))
    if session.deaths > 0 then
        pane.deaths:SetText(session.deaths == 1 and "1 death this session" or (session.deaths .. " deaths this session"))
    else
        pane.deaths:SetText("No deaths this session.")
    end
end

local function SetLive(text, row, field)
    if not row then
        text:SetText("0")
    elseif field == "amountPerSecond" then
        text:SetText(SoundAlerter.DamageMeterKit.Rate(row[field]))
    else
        text:SetText(Live(row[field]))
    end
end

local function LiveRows(rows, source)
    local list = source and source.combatSpells
    if type(list) ~= "table" then
        for _, row in ipairs(rows) do row:Hide() end
        return
    end
    for i, row in ipairs(rows) do
        local spell = list[i]
        if spell then
            row.item = nil
            row.name:SetText(C_Spell.GetSpellName(spell.spellID))
            row.value:SetText(Live(spell.totalAmount))
            row.share:SetText("")
            Fill(row, source.maxAmount, spell.totalAmount)
            Window.LiveIcon(row, spell.spellID)
            row:SetAlpha(1)
            row:Show()
        else
            row:Hide()
        end
    end
end

function Window:OnLive(dirty)
    if not self:IsOpen() then return end
    local meter = self.meter
    local counts = meter:Counts()
    local full = not dirty
    if full then
        SoundAlerter.DamageMeterKit.CountStop(self.counter)
        for _, card in ipairs(self.heroes) do Window.HideChange(card) end
        self.empty:Hide()
        for name, pane in pairs(self.panes) do pane:SetShown(name == self.tab) end
    end
    local T = Enum.DamageMeterType
    if self.tab == "GRAPH" then return end
    if self.tab == "?" then
        if full then self:RenderHelp(self:Session()) end
        return
    end
    if self.tab == "PARTY" then
        self:LiveParty(dirty)
        return
    end
    if self.tab == "DEF" then
        local pane = self.panes.DEF
        if not dirty or dirty[T.DamageTaken] or dirty.current then LiveRows(pane.taken, meter:LiveOwn("DamageTaken")) end
        if not dirty or dirty[T.HealingDone] or dirty.current then LiveRows(pane.heals, meter:LiveOwn("HealingDone")) end
        local heroes = self.heroes
        if full then
            pane.takenSub:SetText("")
            pane.healSub:SetText("")
            heroes[1].label:SetText("Taken")
            heroes[2].label:SetText("Avoided")
            heroes[3].label:SetText("Healing")
            for i = 1, 3 do heroes[i].note:SetText("") end
        end
        local rate = Model.AvoidRate(counts.avoid)
        pane.avoidSub:SetText(rate and (Percent(rate) .. " avoided") or "")
        Window.SetSegments(pane.avoid, counts.avoid)
        pane.avoidNote:SetText(Window.CountsText(counts.avoid))
        SetLive(heroes[1].value, meter:LiveOwnRow("DamageTaken"), "totalAmount")
        heroes[2].value:SetText(rate and Percent(rate) or "-")
        SetLive(heroes[3].value, meter:LiveOwnRow("HealingDone"), "totalAmount")
        return
    end
    local pane = self.panes.DAM
    local heroes = self.heroes
    if full then
        heroes[1].label:SetText("DPS")
        heroes[2].label:SetText("Damage")
        heroes[3].label:SetText("Crit")
        for i = 1, 3 do heroes[i].note:SetText("") end
        pane.sub:SetText("damage")
        pane.detailTitle:SetText("This fight")
        for _, kv in ipairs(pane.kv) do kv.key:Hide() kv.value:Hide() kv.rule:Hide() end
        pane.wait:Show()
    end
    if full or dirty[T.DamageDone] or dirty.current then
        LiveRows(pane.rows, meter:LiveOwn("DamageDone"))
        local row = meter:LiveOwnRow("DamageDone")
        SetLive(heroes[1].value, row, "amountPerSecond")
        SetLive(heroes[2].value, row, "totalAmount")
    end
    local crit = Model.CritRate(counts.hits)
    heroes[3].value:SetText(crit and Percent(crit) or "-")
    Window.SetSegments(pane.hits, counts.hits)
    pane.hitNote:SetText(Window.CountsText(counts.hits))
end

function Window:BuildParty(body, width)
    local pane = CreateFrame("Frame", nil, body)
    pane:SetAllPoints(body)
    pane.stats = {}
    for i, stat in ipairs(Window.STATS) do
        local button = CreateFrame("Button", nil, pane)
        button:SetSize(58, 15)
        button:SetPoint("TOPLEFT", pane, "TOPLEFT", (i - 1) * 62, 0)
        button.back = Paint(button, COLOR.row)
        button.back:SetAllPoints()
        button.label = self:Text(button, 10, COLOR.muted, "CENTER")
        button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.label:SetText(string.upper(stat[2]))
        button.stat = stat[1]
        button:SetScript("OnClick", function() Window:SetStat(stat[1]) end)
        pane.stats[i] = button
    end
    pane.hint = self:Text(pane, 10, COLOR.muted, "RIGHT")
    pane.hint:SetPoint("TOPRIGHT", pane, "TOPLEFT", width, -2)
    pane.rows = self:Rows(pane, Window.MEMBER_ROWS, width, COLOR.dmg, 0, -20, "member")
    for i, row in ipairs(pane.rows) do
        row:SetScript("OnMouseUp", function() Window:PickMember(i) end)
    end
    local gy = -20 - Window.MEMBER_ROWS * (Window.ROW_H + Window.ROW_GAP) - 8
    pane.grid = CreateFrame("Frame", nil, pane)
    pane.grid:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, gy)
    pane.grid:SetSize(width, 16 * (#Window.UTILITY + 1))
    local first = 90
    local column = math.floor((width - first) / Window.MEMBER_COLUMNS)
    pane.heads, pane.cells = {}, {}
    for c = 1, Window.MEMBER_COLUMNS do
        local head = self:Text(pane.grid, 10, COLOR.muted, "RIGHT")
        head:SetPoint("TOPRIGHT", pane.grid, "TOPLEFT", first + c * column, 0)
        head:SetWidth(column - 4)
        pane.heads[c] = head
    end
    for r, util in ipairs(Window.UTILITY) do
        local y = -16 * r
        local label = self:Text(pane.grid, 11, COLOR.muted, "LEFT")
        label:SetPoint("TOPLEFT", pane.grid, "TOPLEFT", 0, y)
        label:SetText(util[2])
        local rule = Paint(pane.grid, COLOR.line, "BORDER")
        rule:SetHeight(1)
        rule:SetWidth(width)
        rule:SetPoint("TOPLEFT", pane.grid, "TOPLEFT", 0, y + 2)
        pane.cells[r] = {}
        for c = 1, Window.MEMBER_COLUMNS do
            local cell = self:Text(pane.grid, 11, COLOR.white, "RIGHT")
            cell:SetPoint("TOPRIGHT", pane.grid, "TOPLEFT", first + c * column, y)
            pane.cells[r][c] = cell
        end
    end
    pane.detail = CreateFrame("Frame", nil, pane)
    pane.detail:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, gy)
    pane.detail:SetSize(width, 16 + Window.DETAIL_ROWS * (Window.ROW_H + Window.ROW_GAP) + 16)
    pane.detailTitle, pane.detailSub = self:Label(pane.detail, 0, 0, width, "", "their last fight")
    pane.detailRows = self:Rows(pane.detail, Window.DETAIL_ROWS, width, COLOR.dmg, 0, -16, "detail")
    pane.detailNote = self:Text(pane.detail, 10, COLOR.dim, "LEFT")
    pane.detailNote:SetPoint("TOPLEFT", pane.detail, "TOPLEFT", 0, -18)
    pane.detailNote:SetText("The game no longer keeps that fight.")
    pane.detail:Hide()
    return pane
end

local function ClassColor(class)
    local colors = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if colors then return colors.r, colors.g, colors.b end
    return COLOR.dmg[1], COLOR.dmg[2], COLOR.dmg[3]
end
Window.ClassColor = ClassColor

local function FirstName(name)
    return name:match("^(%S+)") or name
end
Window.FirstName = FirstName

local DARK = { 0.1, 0.07, 0.02 }

function Window:StatButtons()
    for _, button in ipairs(self.panes.PARTY.stats) do
        local on = button.stat == self.stat
        local back = on and COLOR.accent or COLOR.row
        button.back:SetVertexColor(back[1], back[2], back[3], back[4] or 1)
        local color = on and DARK or COLOR.muted
        button.label:SetTextColor(color[1], color[2], color[3])
    end
end

function Window:SetStat(stat)
    self.stat = stat
    self.memberPick = nil
    self:Refresh()
end

function Window:PickMember(index)
    if self.meter:InCombat() then return end
    local member = self.memberList and self.memberList[index]
    if not member then return end
    if self.memberPick == member.name then self.memberPick = nil else self.memberPick = member.name end
    self:Render()
end

function Window:StatInfo()
    for _, stat in ipairs(Window.STATS) do
        if stat[1] == self.stat then return stat[2], stat[3] end
    end
    return "Damage", "DamageDone"
end

local memberRanked = {}

function Window:RenderParty(session)
    local pane = self.panes.PARTY
    local stat = self.stat
    self:StatButtons()
    pane.hint:SetText("click a member for details")
    local list, total = Model.RankMembers(session.members, stat, Window.MEMBER_ROWS, memberRanked)
    self.memberList = list
    local top = list[1] and list[1][stat] or 0
    for i, row in ipairs(pane.rows) do
        local m = list[i]
        if m then
            local r, g, b = ClassColor(m.class)
            Window.BarColor(row, r, g, b)
            row.item = m
            self:SetClassIcon(row, m.class)
            row.name:SetText(i .. "  " .. m.name)
            row.value:SetText(Num(m[stat]))
            row.share:SetText(total > 0 and Percent(m[stat] / total) or "")
            Fill(row, top > 0 and top or 1, m[stat], self.counting)
            row:SetAlpha((self.memberPick and self.memberPick ~= m.name) and 0.82 or 1)
            row:Show()
        else
            row:Hide()
        end
    end
    local picked = self.memberPick and session.members[self.memberPick]
    pane.grid:SetShown(not picked)
    pane.detail:SetShown(picked ~= nil and picked ~= false)
    if picked then
        local label = self:StatInfo()
        pane.detailTitle:SetText(picked.name .. ": " .. string.lower(label))
        local spells = self.meter:MemberSpells(picked, stat)
        local rows, sum = Model.Ranked(spells or {}, Window.DETAIL_ROWS, {})
        self:SetRows(pane.detailRows, rows, sum)
        pane.detailNote:SetShown(spells == nil)
        return
    end
    local columns = Model.RankMembers(session.members, "damage", Window.MEMBER_COLUMNS, {})
    for c, head in ipairs(pane.heads) do
        local m = columns[c]
        head:SetText(m and FirstName(m.name) or "")
        for r, util in ipairs(Window.UTILITY) do
            pane.cells[r][c]:SetText(m and tostring(m[util[1]]) or "")
        end
    end
end

function Window:LiveParty(dirty)
    local pane = self.panes.PARTY
    if not dirty then
        self:StatButtons()
        pane.hint:SetText("as the game shows it in combat")
        pane.detail:Hide()
        pane.grid:Show()
        for _, row in ipairs(pane.rows) do row.liveClass = false end
    end
    local _, name = self:StatInfo()
    if dirty and not dirty[Enum.DamageMeterType[name]] and not dirty.current then return end
    local session = self.meter:Live(name)
    local sources = session and session.combatSources
    for i, row in ipairs(pane.rows) do
        local source = type(sources) == "table" and sources[i]
        if source then
            local class = Plain(source.classFilename)
            if row.liveClass ~= class then
                row.liveClass = class
                Window.BarColor(row, ClassColor(class))
                self:SetClassIcon(row, class)
            end
            row.item = nil
            row.name:SetText(source.name)
            row.value:SetText(Live(source.totalAmount))
            row.share:SetText("")
            Fill(row, session.maxAmount, source.totalAmount)
            row:SetAlpha(1)
            row:Show()
        else
            row:Hide()
        end
    end
end

function Window:PostClick()
    local field = "damage"
    if self.tab == "PARTY" then field = self.stat elseif self.tab == "DEF" then field = "healing" end
    local label = field == "taken" and "damage taken" or field
    local result = self.meter:PostTop(field, label)
    local text = self.postButton.label
    text:SetText(Window.POSTED[result] or "Post top 5")
    self.postToken = (self.postToken or 0) + 1
    local token = self.postToken
    C_Timer.After(Window.FEEDBACK, function()
        if token == self.postToken then text:SetText("Post top 5") end
    end)
end

function Window:NewSessionClick()
    local label = self.newButton.label
    if not self.confirming then
        self.confirming = true
        label:SetText("Click again to reset")
        self.confirmToken = (self.confirmToken or 0) + 1
        local token = self.confirmToken
        C_Timer.After(Window.CONFIRM, function()
            if token == self.confirmToken then
                self.confirming = false
                label:SetText("New session")
            end
        end)
        return
    end
    self.confirming = false
    self.confirmToken = (self.confirmToken or 0) + 1
    label:SetText("New session")
    self.meter:NewSession()
    self:Render()
end

SoundAlerter.DamageMeterWindow = Window
