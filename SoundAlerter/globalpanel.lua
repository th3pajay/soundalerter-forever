SA_GlobalPanel = {}

local Panel = SA_GlobalPanel

local WIDTH, STRIP_WIDTH, STRIP_HEIGHT = 232, 22, 150
local HEAD, TILES, BAR, LEGEND, ROW, MORE, PAD = 24, 40, 10, 16, 18, 14, 6
local COMPACT_ROWS, MAX_ROWS = 3, 8
local CLOSE_DELAY, EASE_TIME = 0.25, 0.12
local BAR_SEGMENTS, LEGEND_CLASSES = 10, 3
local TILE_WIDTH, TILE_GAP, TILE_HEIGHT = 70, 4, 34
local ZONE_NAME_WIDTH, WORLD_NAME_WIDTH = 126, 98
local MEDIA = "Interface\\AddOns\\SoundAlerter\\Textures\\"
local FLAT = "Interface\\Buttons\\WHITE8X8"
local DOT, ARROW = MEDIA .. "circle", MEDIA .. "gs_arrow"
local GREY = { r = 0.6, g = 0.6, b = 0.6 }
local INK = 0.06
local OPTIONS = { off = true, strip = true, full = true }

Panel.WIDTH, Panel.STRIP_WIDTH, Panel.STRIP_HEIGHT = WIDTH, STRIP_WIDTH, STRIP_HEIGHT
Panel.COMPACT_ROWS, Panel.MAX_ROWS = COMPACT_ROWS, MAX_ROWS
Panel.CLOSE_DELAY, Panel.EASE_TIME = CLOSE_DELAY, EASE_TIME

function Panel.Option(value)
    return OPTIONS[value] and value or "strip"
end

function Panel.RowLimit(total, expanded)
    local rows = math.min(total, expanded and MAX_ROWS or COMPACT_ROWS)
    return rows, total - rows
end

function Panel.MoreText(total, rows, expanded)
    local extra = total - rows
    if extra > 0 then return "+" .. extra .. " more" end
    if expanded and total > COMPACT_ROWS then return "show less" end
    return nil
end

function Panel.Layout(rows, hasMix, hasMore)
    local y = HEAD + TILES
    local barTop, legendTop = y, nil
    if hasMix then
        legendTop = y + BAR
        y = y + BAR + LEGEND
    end
    local rowsTop = y
    y = y + rows * ROW
    local moreTop = nil
    if hasMore then
        moreTop = y
        y = y + MORE
    end
    return y + PAD, barTop, legendTop, rowsTop, moreTop
end

function Panel.Ease(elapsed, duration)
    if elapsed >= duration then return 1 end
    local x = elapsed / duration
    return 1 - (1 - x) * (1 - x)
end

function Panel.AgeText(seconds)
    if seconds < 20 then return "now" end
    if seconds < 60 then return "<1m" end
    return math.floor(seconds / 60) .. "m"
end

local function put(region, text)
    if region.putText ~= text then
        region.putText = text
        region:SetText(text)
    end
end

local function ink(region, r, g, b)
    if region.inkR ~= r or region.inkG ~= g or region.inkB ~= b then
        region.inkR, region.inkG, region.inkB = r, g, b
        region:SetTextColor(r, g, b)
    end
end

local function tint(region, r, g, b)
    if region.tintR ~= r or region.tintG ~= g or region.tintB ~= b then
        region.tintR, region.tintG, region.tintB = r, g, b
        region:SetVertexColor(r, g, b, 1)
    end
end

local function place(region, anchor, x, y)
    if region.placeX ~= x or region.placeY ~= y then
        region.placeX, region.placeY = x, y
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)
    end
end

local function resize(region, w, h)
    if region.sizeW ~= w or region.sizeH ~= h then
        region.sizeW, region.sizeH = w, h
        region:SetSize(w, h)
    end
end

local function reveal(region, on)
    if region.revealed ~= on then
        region.revealed = on
        if on then region:Show() else region:Hide() end
    end
end

local function fade(region, alpha)
    if region.fadeTo ~= alpha then
        region.fadeTo = alpha
        region:SetAlpha(alpha)
    end
end

local function classColor(class)
    local colors = RAID_CLASS_COLORS
    return colors and colors[class] or GREY
end

local classOrder, sortMix = {}, nil

local function byShare(a, b)
    local ca, cb = sortMix[a], sortMix[b]
    if ca ~= cb then return ca > cb end
    return a < b
end

local function sortClasses(mix)
    local n = 0
    for class, count in pairs(mix) do
        if count > 0 then
            n = n + 1
            classOrder[n] = class
        end
    end
    for i = n + 1, #classOrder do classOrder[i] = nil end
    sortMix = mix
    table.sort(classOrder, byShare)
    return n
end

local function fillBar(segments, anchor, n, mix, total, length, x, y, vertical)
    local used = math.min(n, #segments)
    local offset = 0
    for i = 1, #segments do
        local segment = segments[i]
        if i <= used then
            local class = classOrder[i]
            local share = math.max(1, math.floor(length * mix[class] / total))
            if i == used then share = math.max(1, length - offset) end
            local color = classColor(class)
            tint(segment, color.r, color.g, color.b)
            if vertical then
                place(segment, anchor, x, y - offset)
                resize(segment, 8, share)
            else
                place(segment, anchor, x + offset, y)
                resize(segment, share, 6)
            end
            reveal(segment, true)
            offset = offset + share
        else
            reveal(segment, false)
        end
    end
end

local function newText(parent, fontObject, justify)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(fontObject)
    text:SetJustifyH(justify or "LEFT")
    if text.SetWordWrap then text:SetWordWrap(false) end
    return text
end

local function newFlat(parent, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture(FLAT)
    return texture
end

local function wantOpen(p)
    return (p.option == "full" or p.pinned or p.hover) and true or false
end

local function animated()
    return SA_MenuFX ~= nil and SA_MenuFX.Enabled()
end

local function settle(p)
    local w, h, b = p.toW, p.toH, p.toB
    resize(p, w, h)
    resize(p.back, w, b)
    resize(p.edge, 2, b)
    p.curW, p.curH, p.curB = w, h, b
    reveal(p.full, p.open)
    reveal(p.strip, not p.open)
end

local function glide(p, f)
    local w = p.fromW + (p.toW - p.fromW) * f
    local h = p.fromH + (p.toH - p.fromH) * f
    local b = p.fromB + (p.toB - p.fromB) * f
    resize(p, w, h)
    resize(p.back, w, b)
    resize(p.edge, 2, b)
    p.curW, p.curH, p.curB = w, h, b
end

local apply

local function step(p, elapsed)
    if p.easeT then
        p.easeT = p.easeT + elapsed
        local f = Panel.Ease(p.easeT, EASE_TIME)
        if f >= 1 then
            p.easeT = nil
            settle(p)
        else
            glide(p, f)
        end
    end
    if p.closeAt and GetTime() >= p.closeAt then
        p.closeAt = nil
        if not p:IsMouseOver() then
            p.hover = false
            apply(p)
        end
    end
    if not p.easeT and not p.closeAt then p:SetScript("OnUpdate", nil) end
end

local function wake(p)
    p:SetScript("OnUpdate", step)
end

local function fillStrip(p, d)
    tint(p.edge, d.vr, d.vg, d.vb)
    tint(p.letterBack, d.vr, d.vg, d.vb)
    put(p.letter, d.verdict:sub(1, 1))
    put(p.stripCount, d.countText)
    put(p.stripTrend, d.trend)
    ink(p.stripTrend, d.trR, d.trG, d.trB)
    local n = d.total > 0 and sortClasses(d.mix) or 0
    if n > 0 then
        fillBar(p.stripBar, p.strip, n, d.mix, d.total, 72, 7, -72, true)
    else
        for i = 1, #p.stripBar do reveal(p.stripBar[i], false) end
    end
end

local function fillRow(p, row, entry, nameWidth, y)
    place(row, p.full, 2, -y)
    row.members, row.count, row.zone = entry.members, entry.count or 0, entry.zone
    tint(row.dot, entry.dotR, entry.dotG, entry.dotB)
    put(row.name, entry.name)
    ink(row.name, entry.nameR, entry.nameG, entry.nameB)
    if row.nameWidth ~= nameWidth then
        row.nameWidth = nameWidth
        row.name:SetWidth(nameWidth)
    end
    put(row.ago, entry.ago)
    put(row.level, entry.lvlText)
    if entry.chip then
        tint(row.levelBack, entry.lvlR, entry.lvlG, entry.lvlB)
        reveal(row.levelBack, true)
        ink(row.level, INK, INK, INK)
    else
        reveal(row.levelBack, false)
        ink(row.level, entry.lvlR, entry.lvlG, entry.lvlB)
    end
    if entry.bearing then
        if row.arrow.bearing ~= entry.bearing then
            row.arrow.bearing = entry.bearing
            row.arrow:SetRotation(-entry.bearing)
        end
        reveal(row.arrow, true)
    else
        reveal(row.arrow, false)
    end
    if entry.meter then
        resize(row.meter, entry.meter, 5)
        tint(row.meter, entry.dotR, entry.dotG, entry.dotB)
        reveal(row.meter, true)
    else
        reveal(row.meter, false)
    end
    fade(row, entry.alpha)
    reveal(row, true)
end

local function fillFull(p, d)
    tint(p.edge, d.vr, d.vg, d.vb)
    put(p.title, d.title)
    put(p.pill, d.verdict)
    tint(p.pillBack, d.vr, d.vg, d.vb)
    if p.option == "full" then
        put(p.pin, "")
    else
        put(p.pin, p.pinned and "pinned" or "pin")
        if p.pinned then ink(p.pin, 1, 0.84, 0.4) else ink(p.pin, 0.45, 0.48, 0.55) end
    end
    for i = 1, 3 do
        local tile, source = p.tiles[i], d.tiles[i]
        put(tile.label, source.label)
        put(tile.value, source.value)
        put(tile.sub, source.sub)
        ink(tile.sub, source.r, source.g, source.b)
    end
    local n = d.total > 0 and sortClasses(d.mix) or 0
    local hasMore = d.more ~= nil
    local height, barTop, legendTop, rowsTop, moreTop = Panel.Layout(d.rowCount, n > 0, hasMore)
    p.layoutH = height
    resize(p.full, WIDTH, height)
    if n > 0 then
        fillBar(p.bar, p.full, n, d.mix, d.total, WIDTH - 20, 10, -(barTop + 2), false)
        for i = 1, LEGEND_CLASSES do
            local item = p.legend[i]
            if i <= n then
                local class = classOrder[i]
                local count = d.mix[class]
                if item.class ~= class or item.count ~= count then
                    item.class, item.count = class, count
                    local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
                    item.text:SetText(name .. " " .. count)
                end
                local color = classColor(class)
                tint(item.swatch, color.r, color.g, color.b)
                place(item.swatch, p.full, 10 + (i - 1) * 74, -(legendTop + 5))
                place(item.text, p.full, 19 + (i - 1) * 74, -(legendTop + 2))
                reveal(item.swatch, true)
                reveal(item.text, true)
            else
                reveal(item.swatch, false)
                reveal(item.text, false)
            end
        end
    else
        for i = 1, #p.bar do reveal(p.bar[i], false) end
        for i = 1, LEGEND_CLASSES do
            reveal(p.legend[i].swatch, false)
            reveal(p.legend[i].text, false)
        end
    end
    local nameWidth = d.kind == "world" and WORLD_NAME_WIDTH or ZONE_NAME_WIDTH
    for i = 1, MAX_ROWS do
        local row = p.rows[i]
        if i <= d.rowCount then
            fillRow(p, row, d.rows[i], nameWidth, rowsTop + (i - 1) * ROW)
        else
            row.count, row.zone = 0, nil
            reveal(row, false)
        end
    end
    if hasMore then
        place(p.more, p.full, 2, -moreTop)
        put(p.moreText, d.more)
        reveal(p.more, true)
    else
        reveal(p.more, false)
    end
end

apply = function(p)
    local d = p.data
    if not d then return end
    local open = wantOpen(p)
    local toggled = open ~= p.open
    p.open = open
    if open then
        fillFull(p, d)
        p.toW, p.toH, p.toB = WIDTH, math.max(p.layoutH, STRIP_HEIGHT), p.layoutH
    else
        fillStrip(p, d)
        p.toW, p.toH, p.toB = STRIP_WIDTH, STRIP_HEIGHT, STRIP_HEIGHT
    end
    if toggled and p.curW and animated() then
        p.fromW, p.fromH, p.fromB = p.curW, p.curH, p.curB
        p.easeT = 0
        if open then
            reveal(p.full, true)
            reveal(p.strip, false)
        end
        wake(p)
        return
    end
    if not p.easeT then settle(p) end
end

local function enter(p)
    p.hover = true
    p.closeAt = nil
    if not p.open then apply(p) end
end

local function leave(p)
    if p.option == "full" or p.pinned then
        p.hover = false
        return
    end
    p.closeAt = GetTime() + CLOSE_DELAY
    wake(p)
end

local function newRow(p, hooks)
    local row = CreateFrame("Button", nil, p.full)
    row:SetSize(WIDTH - 2, ROW)
    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetTexture(DOT)
    row.dot:SetSize(6, 6)
    row.dot:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.name = newText(row, "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.dot, "RIGHT", 7, 0)
    row.levelBack = newFlat(row, "BACKGROUND")
    row.levelBack:SetSize(22, 14)
    row.levelBack:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.level = newText(row, "GameFontHighlightSmall", "CENTER")
    row.level:SetWidth(22)
    row.level:SetPoint("CENTER", row.levelBack, "CENTER", 0, 0)
    row.arrow = row:CreateTexture(nil, "OVERLAY")
    row.arrow:SetTexture(ARROW)
    row.arrow:SetSize(9, 9)
    row.arrow:SetVertexColor(0.85, 0.88, 0.92, 1)
    row.arrow:SetPoint("RIGHT", row.levelBack, "LEFT", -4, 0)
    row.ago = newText(row, "GameFontDisableSmall", "RIGHT")
    row.ago:SetWidth(28)
    row.ago:SetPoint("RIGHT", row.arrow, "LEFT", -4, 0)
    row.meter = newFlat(row, "ARTWORK")
    row.meter:SetPoint("RIGHT", row.levelBack, "LEFT", -8, 0)
    row.members, row.count = nil, 0
    row:SetScript("OnEnter", function(self)
        enter(p)
        if self.zone then
            if hooks.rowEnter then hooks.rowEnter(self.zone) end
        elseif self.members and self.count > 0 and hooks.rowTip then
            hooks.rowTip(self)
        end
    end)
    row:SetScript("OnLeave", function()
        leave(p)
        if hooks.rowLeave then hooks.rowLeave() end
        if hooks.hideTip then hooks.hideTip() end
    end)
    row:Hide()
    return row
end

function Panel.Create(parent, hooks)
    hooks = hooks or {}
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(STRIP_WIDTH, STRIP_HEIGHT)
    p:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -10)
    p:SetFrameLevel(math.min(parent:GetFrameLevel() + 3100, 9000))
    p:EnableMouse(true)
    if p.SetClipsChildren then p:SetClipsChildren(true) end
    p.hooks = hooks

    p.back = newFlat(p, "BACKGROUND")
    p.back:SetVertexColor(0.04, 0.05, 0.06, 0.9)
    p.back:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    p.edge = newFlat(p, "BORDER")
    p.edge:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)

    local strip = CreateFrame("Frame", nil, p)
    strip:SetSize(STRIP_WIDTH, STRIP_HEIGHT)
    strip:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    p.strip = strip
    p.letterBack = newFlat(strip, "ARTWORK")
    p.letterBack:SetSize(16, 16)
    p.letterBack:SetPoint("TOPLEFT", strip, "TOPLEFT", 4, -7)
    p.letter = newText(strip, "GameFontNormalSmall", "CENTER")
    p.letter:SetPoint("CENTER", p.letterBack, "CENTER", 0, 0)
    ink(p.letter, INK, INK, INK)
    p.stripCount = newText(strip, "GameFontHighlight", "CENTER")
    p.stripCount:SetWidth(STRIP_WIDTH)
    p.stripCount:SetPoint("TOP", p.letterBack, "BOTTOM", 0, -3)
    p.stripTrend = newText(strip, "GameFontHighlightSmall", "CENTER")
    p.stripTrend:SetWidth(STRIP_WIDTH)
    p.stripTrend:SetPoint("TOP", p.stripCount, "BOTTOM", 0, -1)
    p.stripBar = {}
    for i = 1, BAR_SEGMENTS do
        p.stripBar[i] = newFlat(strip, "ARTWORK")
    end

    local full = CreateFrame("Frame", nil, p)
    full:SetSize(WIDTH, 100)
    full:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    full:Hide()
    p.full = full
    p.head = CreateFrame("Button", nil, full)
    p.head:SetPoint("TOPLEFT", full, "TOPLEFT", 2, 0)
    p.head:SetSize(WIDTH - 2, HEAD)
    p.pin = newText(p.head, "GameFontDisableSmall", "RIGHT")
    p.pin:SetPoint("RIGHT", p.head, "RIGHT", -8, 0)
    p.pillBack = newFlat(p.head, "ARTWORK")
    p.pillBack:SetSize(50, 15)
    p.pillBack:SetPoint("RIGHT", p.head, "RIGHT", -52, 0)
    p.pill = newText(p.head, "GameFontNormalSmall", "CENTER")
    p.pill:SetPoint("CENTER", p.pillBack, "CENTER", 0, 0)
    ink(p.pill, INK, INK, INK)
    p.title = newText(p.head, "GameFontNormalSmall")
    p.title:SetPoint("LEFT", p.head, "LEFT", 10, 0)
    p.title:SetPoint("RIGHT", p.pillBack, "LEFT", -4, 0)
    p.head:SetScript("OnClick", function()
        p.pinned = not p.pinned
        apply(p)
    end)
    p.head:SetScript("OnEnter", function() enter(p) end)
    p.head:SetScript("OnLeave", function() leave(p) end)

    p.tiles = {}
    for i = 1, 3 do
        local tile = {}
        tile.back = newFlat(full, "BACKGROUND")
        tile.back:SetVertexColor(0.08, 0.1, 0.13, 1)
        tile.back:SetSize(TILE_WIDTH, TILE_HEIGHT)
        tile.back:SetPoint("TOPLEFT", full, "TOPLEFT", 8 + (i - 1) * (TILE_WIDTH + TILE_GAP), -(HEAD + 3))
        tile.label = newText(full, "GameFontDisableSmall")
        tile.label:SetPoint("TOPLEFT", tile.back, "TOPLEFT", 6, -4)
        tile.value = newText(full, "GameFontHighlight")
        tile.value:SetWidth(TILE_WIDTH - 12)
        tile.value:SetPoint("TOPLEFT", tile.back, "TOPLEFT", 6, -16)
        tile.sub = newText(full, "GameFontHighlightSmall", "RIGHT")
        tile.sub:SetPoint("TOPRIGHT", tile.back, "TOPRIGHT", -5, -4)
        if i == 1 then
            tile.hit = CreateFrame("Frame", nil, full)
            tile.hit:SetAllPoints(tile.back)
            tile.hit:EnableMouse(true)
            tile.hit:SetScript("OnEnter", function(self)
                enter(p)
                if hooks.factsTip then hooks.factsTip(self, p.data) end
            end)
            tile.hit:SetScript("OnLeave", function()
                leave(p)
                if hooks.hideTip then hooks.hideTip() end
            end)
        end
        p.tiles[i] = tile
    end

    p.bar = {}
    for i = 1, BAR_SEGMENTS do
        p.bar[i] = newFlat(full, "ARTWORK")
    end
    p.legend = {}
    for i = 1, LEGEND_CLASSES do
        local item = {}
        item.swatch = newFlat(full, "ARTWORK")
        item.swatch:SetSize(6, 6)
        item.text = newText(full, "GameFontDisableSmall")
        item.text:SetWidth(62)
        p.legend[i] = item
    end

    p.rows = {}
    for i = 1, MAX_ROWS do
        p.rows[i] = newRow(p, hooks)
    end
    p.more = CreateFrame("Button", nil, full)
    p.more:SetSize(WIDTH - 2, MORE)
    p.moreText = newText(p.more, "GameFontDisableSmall")
    p.moreText:SetPoint("LEFT", p.more, "LEFT", 10, 0)
    p.more:SetScript("OnClick", function()
        if hooks.toggle then hooks.toggle() end
    end)
    p.more:SetScript("OnEnter", function() enter(p) end)
    p.more:SetScript("OnLeave", function() leave(p) end)
    p.more:Hide()

    p:SetScript("OnEnter", function() enter(p) end)
    p:SetScript("OnLeave", function() leave(p) end)
    p:Hide()
    return p
end

function Panel.Draw(p, data)
    p.data = data
    p.option = data.option
    if not p:IsShown() then p:Show() end
    apply(p)
end

function Panel.Hide(p)
    p.hover, p.closeAt = false, nil
    p:Hide()
end
