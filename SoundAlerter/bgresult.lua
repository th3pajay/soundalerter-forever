local SoundAlerter = SoundAlerter
local Model = SA_BGResult
local FX = SA_MenuFX
local Kit = SoundAlerter.Page.Kit
local COLOR, Paint, Outline, Text, Tint = Kit.COLOR, Kit.Paint, Kit.Outline, Kit.Text, Kit.Tint

local UI = {}

local CARD_WIDTH, PAD, GAP = 380, 12, 6
local HEAD_HEIGHT, CELL_HEIGHT, BADGE_HEIGHT, FOOT_HEIGHT = 30, 38, 18, 20
local COLUMNS_PER_ROW, MAX_CELLS = 4, 8
local CARD_NAME = "SoundAlerterBGResultCard"
local PILL_HEIGHT, PILL_STRIPE, PILL_LINE, PILL_TEXT_X, PILL_CLOSE = 22, 3, 2, 10, 20
local DRAIN_END = 0.002
local PILL_OFFSET_Y = -22
local CARD_FILL = { 0.082, 0.094, 0.118 }
local CELL_FILL = { 0.106, 0.122, 0.153 }
local BEST_FILL = { 0.137, 0.122, 0.063 }
local GOLD = { 1, 0.82, 0 }
local LOSS = { 1, 0.36, 0.36 }
local PILL_EDGE = { 0.54, 0.39, 0.13 }
local DEBRIEF_NAME = "SoundAlerterBGDebrief"
local D_WIDTH, D_PAD, D_HEAD, D_FOOT, D_GAP, D_LABEL = 480, 12, 30, 30, 14, 18
local D_INNER = D_WIDTH - 2 * D_PAD
local TEXT_SCALE = 1.18
local TITLE_FONT = "Fonts\\MORPHEUS.TTF"
local WASH_HEIGHT, CREST_SIZE = 56, 34
local TUG_ROW, TUG_VALUE, TUG_BAR = 34, 60, 12
local TUG_TRACK = D_INNER - 2 * (TUG_VALUE + 8)
local STEP_GAP, STEP_HEIGHT, ME_LINE, CLASS_ICON = 6, 112, 20, 22
local STEP_WIDTH = (D_INNER - 2 * STEP_GAP) / 3
local STEP_BLOCKS = { 56, 40, 28 }
local STEP_SLOTS = { 2, 1, 3 }
local MEDALS = { { 1, 0.82, 0 }, { 0.784, 0.816, 0.855 }, { 0.788, 0.541, 0.294 } }
local REC_ROW, REC_GAP, REC_RIGHT, MINI_WIDTH, MINI_HEIGHT = 22, 3, 104, 64, 5
local SPELL_ROW, SPELL_ICON, SPELL_NAME, SPELL_VALUE, SPELL_BAR = 21, 16, 128, 56, 9
local SPELL_TRACK = D_INNER - SPELL_NAME - SPELL_VALUE - 8
local MAX_TUG, MAX_RECORDS, MAX_SPELLS = 3, 5, 5
local GROW_TIME, GROW_FROM = 0.45, 0.001
local SHADOWS = { { 3, 0.32 }, { 6, 0.18 }, { 10, 0.09 }, { 15, 0.04 } }
local SHADOW_DROP = 4
local BODY_TOP, BODY_BOTTOM = { 0.102, 0.122, 0.157 }, { 0.059, 0.071, 0.094 }
local HEAD_TOP, HEAD_BOTTOM = { 0.137, 0.165, 0.216 }, { 0.090, 0.110, 0.145 }
local EDGE_COLOR = { 0.227, 0.267, 0.337 }
local TRACK_FILL = { 0.075, 0.086, 0.11 }
local BLOCK_TOP, BLOCK_BOTTOM = { 0.165, 0.192, 0.251 }, { 0.094, 0.114, 0.149 }
local ME_TOP, ME_BOTTOM = { 0.251, 0.188, 0.110 }, { 0.141, 0.106, 0.067 }
local NEW_LEFT, NEW_RIGHT = { 0.227, 0.188, 0.063 }, { 0.133, 0.125, 0.059 }
local MINI_LOW, MINI_HIGH = { 0.54, 0.39, 0.13 }, { 1, 0.82, 0 }
local SPELL_TOP, SPELL_BOTTOM = { 1, 0.69, 0.4 }, { 0.78, 0.35, 0 }
local DIM = { 0.42, 0.455, 0.525 }
local GREY = { 0.6, 0.63, 0.7 }
local FACTION_COLOR = { [0] = { 0.78, 0.2, 0.23 }, [1] = { 0.23, 0.48, 0.84 } }
local CREST_ATLAS = { [0] = "questlog-questtypeicon-horde", [1] = "questlog-questtypeicon-alliance" }
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local NEW_TAG = "|cffffd100NEW|r  "

UI.CARD_WIDTH = CARD_WIDTH

local function cardHeight(footer)
    return PAD + HEAD_HEIGHT + 2 * CELL_HEIGHT + GAP + BADGE_HEIGHT + (footer and FOOT_HEIGHT or 0) + PAD
end
UI.CardHeight = cardHeight

local function classColor(class)
    local colors = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if colors then return colors.r, colors.g, colors.b end
    return COLOR.text[1], COLOR.text[2], COLOR.text[3]
end
UI.ClassColor = classColor

local function newCell(card, index, width)
    local cell = CreateFrame("Frame", nil, card)
    cell:SetSize(width, CELL_HEIGHT)
    local column, row = (index - 1) % COLUMNS_PER_ROW, math.floor((index - 1) / COLUMNS_PER_ROW)
    cell:SetPoint("TOPLEFT", card, "TOPLEFT", PAD + column * (width + GAP), -(PAD + HEAD_HEIGHT + row * (CELL_HEIGHT + GAP)))
    cell.fill = Paint(cell, CELL_FILL, 1)
    cell.fill:SetAllPoints(cell)
    cell.value = Text(cell, 14, COLOR.text)
    cell.value:SetPoint("TOPLEFT", cell, "TOPLEFT", 6, -5)
    cell.label = Text(cell, 10, COLOR.muted)
    cell.label:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", 6, 5)
    cell.label:SetPoint("RIGHT", cell, "RIGHT", -4, 0)
    return cell
end

function UI.NewCard(parent, footer, name)
    local card = CreateFrame("Frame", name, parent)
    card:SetSize(CARD_WIDTH, cardHeight(footer))
    local fill = Paint(card, CARD_FILL, 0.97)
    fill:SetAllPoints(card)
    Outline(card, COLOR.line)
    card.result = Text(card, 18, COLOR.on)
    card.result:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -PAD)
    card.meta = Text(card, 11, COLOR.muted, "RIGHT")
    card.meta:SetPoint("TOPRIGHT", card, "TOPRIGHT", -(PAD + (footer and 14 or 0)), -(PAD + 5))
    local width = (CARD_WIDTH - 2 * PAD - (COLUMNS_PER_ROW - 1) * GAP) / COLUMNS_PER_ROW
    card.cells = {}
    for index = 1, MAX_CELLS do card.cells[index] = newCell(card, index, width) end
    card.badges = Text(card, 11, GOLD)
    card.badges:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -(PAD + HEAD_HEIGHT + 2 * CELL_HEIGHT + GAP + 4))
    card.badges:SetPoint("RIGHT", card, "RIGHT", -PAD, 0)
    card.badgeList = {}
    card.footer = footer and true or false
    card.record = false
    if footer then
        card.name = Text(card, 11, COLOR.text)
        card.name:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", PAD, PAD)
        local link = CreateFrame("Button", nil, card)
        link:SetSize(130, 16)
        link:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -PAD, PAD - 2)
        local label = Text(link, 11, COLOR.accent, "RIGHT")
        label:SetAllPoints(link)
        label:SetText("All battlegrounds >")
        link:SetScript("OnClick", function() SoundAlerter:ShowStatisticsBG() end)
        local close = CreateFrame("Button", nil, card)
        close:SetSize(18, 18)
        close:SetPoint("TOPRIGHT", card, "TOPRIGHT", -4, -4)
        local cross = Text(close, 13, COLOR.muted, "CENTER")
        cross:SetAllPoints(close)
        cross:SetText("x")
        close:SetScript("OnClick", function() card:Hide() end)
    end
    return card
end

function UI.FillCard(card, record)
    if card.record == record then return end
    card.record = record
    local result = record.result
    card.result:SetText(result == "won" and "VICTORY" or result == "lost" and "DEFEAT" or "MATCH OVER")
    Tint(card.result, result == "lost" and LOSS or result == "won" and COLOR.on or COLOR.text)
    local me = record.me
    card.meta:SetText((record.map or "?") .. " · " .. Model.Clock(record.length) .. " · +" .. (me[Model.HONOR] or 0) .. " honor")
    local stats = Model.Stats(record.columns)
    local used = 0
    for s = 1, #stats do
        if used >= MAX_CELLS - 1 then break end
        used = used + 1
        local stat, cell = stats[s], card.cells[used]
        local text, best = Model.RankText(record, stat)
        cell.value:SetText(Model.Short(me[stat.index]))
        cell.label:SetText(stat.label .. " · " .. text)
        Tint(cell.fill, best and BEST_FILL or CELL_FILL)
        Tint(cell.label, best and GOLD or COLOR.muted)
        cell:Show()
    end
    used = used + 1
    local honor = card.cells[used]
    honor.value:SetText("+" .. (me[Model.HONOR] or 0))
    honor.label:SetText("Honor")
    Tint(honor.fill, CELL_FILL)
    Tint(honor.label, COLOR.muted)
    honor:Show()
    for index = used + 1, MAX_CELLS do card.cells[index]:Hide() end
    card.badges:SetText(table.concat(Model.Badges(record, card.badgeList), "   ·   "))
    if card.footer then
        card.name:SetText(me[Model.NAME] or "")
        card.name:SetTextColor(classColor(me[Model.CLASS]))
    end
end

local pill, popup, hideTimer, current, debrief

local function crisp(frame, parent, units, color, justify, font)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label.crispUnits, label.crispFont = units * TEXT_SCALE, font
    SoundAlerter.BarUtils:CrispFont(label, label.crispUnits, frame.ppu, font)
    label:SetShadowColor(0, 0, 0, 0.95)
    label:SetTextColor(color[1], color[2], color[3])
    label:SetJustifyH(justify or "LEFT")
    if label.SetWordWrap then label:SetWordWrap(false) end
    frame.texts[#frame.texts + 1] = label
    return label
end

local function flat(parent, layer, sublevel)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
    texture:SetTexture(Kit.FLAT)
    return texture
end

local canShade = nil

local function shade(texture, orientation, low, high, alpha)
    if texture.shadeLow == low and texture.shadeHigh == high then return end
    texture.shadeLow, texture.shadeHigh = low, high
    if canShade == nil then canShade = texture.SetGradient ~= nil and CreateColor ~= nil end
    if not canShade then
        texture:SetVertexColor(high[1], high[2], high[3], alpha or 1)
        return
    end
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetGradient(orientation, CreateColor(low[1], low[2], low[3], alpha or 1), CreateColor(high[1], high[2], high[3], alpha or 1))
end

local function scaled(color, amount)
    return { color[1] * amount, color[2] * amount, color[3] * amount }
end

local barShades = {}

local function barShade(color)
    local entry = barShades[color]
    if not entry then
        entry = { scaled(color, 0.62), { math.min(1, color[1] * 1.25), math.min(1, color[2] * 1.25), math.min(1, color[3] * 1.25) } }
        barShades[color] = entry
    end
    return entry[1], entry[2]
end

local function grow(frame, texture, row, origin)
    local group = texture:CreateAnimationGroup()
    local scale = group:CreateAnimation("Scale")
    scale:SetDuration(GROW_TIME)
    scale:SetScaleFrom(GROW_FROM, 1)
    scale:SetScaleTo(1, 1)
    scale:SetOrigin(origin, 0, 0)
    if scale.SetSmoothing then scale:SetSmoothing("OUT") end
    group.row = row
    frame.grows[#frame.grows + 1] = group
end

local function sectionLabel(frame, section)
    section.label = crisp(frame, section, 9.5, DIM)
    section.label:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
end

local function recessed(parent, width, height)
    local track = flat(parent, "ARTWORK")
    track:SetVertexColor(TRACK_FILL[1], TRACK_FILL[2], TRACK_FILL[3], 1)
    track:SetSize(width, height)
    local lip = flat(parent, "ARTWORK", 1)
    lip:SetVertexColor(0, 0, 0, 0.55)
    lip:SetHeight(1)
    lip:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    lip:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, 0)
    return track
end

local function ordinal(n)
    local tens = n % 100
    if tens >= 11 and tens <= 13 then return n .. "th" end
    local last = n % 10
    return n .. (last == 1 and "st" or last == 2 and "nd" or last == 3 and "rd" or "th")
end

local function charStore()
    local db = SoundAlerter.db1
    local char = db and db.char
    if not char then return nil end
    char.bgDebrief = char.bgDebrief or {}
    return char.bgDebrief
end

local function setClassIcon(texture, class)
    if texture.class == class then return end
    texture.class = class
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
        texture:SetTexture(CLASS_ICONS)
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        texture:SetTexture(UNKNOWN_ICON)
        texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end

local function spellIcon(spellID)
    if type(spellID) ~= "number" or not (C_Spell and C_Spell.GetSpellTexture) then return UNKNOWN_ICON end
    local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
    return ok and icon or UNKNOWN_ICON
end

local function buildHeader(frame)
    local wash = flat(frame, "BORDER")
    wash:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -D_HEAD)
    wash:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -D_HEAD)
    wash:SetHeight(WASH_HEIGHT)
    local rule = flat(frame, "BORDER", 1)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", wash, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", wash, "BOTTOMRIGHT", 0, 0)
    local crest = frame:CreateTexture(nil, "ARTWORK")
    crest:SetSize(CREST_SIZE, CREST_SIZE)
    crest:SetPoint("LEFT", wash, "LEFT", D_PAD, 0)
    local result = crisp(frame, frame, 22, COLOR.text, "LEFT", TITLE_FONT)
    result:SetPoint("TOPLEFT", wash, "TOPLEFT", D_PAD + CREST_SIZE + 10, -9)
    local meta = crisp(frame, frame, 11, COLOR.muted)
    meta:SetPoint("TOPLEFT", result, "BOTTOMLEFT", 0, -4)
    frame.wash, frame.rule, frame.crest, frame.result, frame.meta = wash, rule, crest, result, meta
    frame.crestFaction = false
end

local function buildTug(frame)
    local tug = CreateFrame("Frame", nil, frame)
    tug.rows = {}
    for index = 1, MAX_TUG do
        local row = CreateFrame("Frame", nil, tug)
        row:SetSize(D_INNER, TUG_ROW)
        row:SetPoint("TOPLEFT", tug, "TOPLEFT", 0, -((index - 1) * TUG_ROW))
        row.label = crisp(frame, row, 9.5, DIM, "CENTER")
        row.label:SetPoint("TOP", row, "TOP", 0, 0)
        local track = recessed(row, TUG_TRACK, TUG_BAR)
        track:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", TUG_VALUE + 8, 3)
        row.us = crisp(frame, row, 11.5, COLOR.text, "RIGHT")
        row.us:SetPoint("RIGHT", track, "LEFT", -8, 0)
        row.them = crisp(frame, row, 11.5, COLOR.text)
        row.them:SetPoint("LEFT", track, "RIGHT", 8, 0)
        row.left = flat(row, "OVERLAY")
        row.left:SetHeight(TUG_BAR)
        row.left:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
        row.right = flat(row, "OVERLAY")
        row.right:SetHeight(TUG_BAR)
        row.right:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, 0)
        grow(frame, row.left, row, "LEFT")
        grow(frame, row.right, row, "RIGHT")
        tug.rows[index] = row
    end
    return tug
end

local function buildPodium(frame)
    local podium = CreateFrame("Frame", nil, frame)
    sectionLabel(frame, podium)
    podium.steps = {}
    for slot = 1, 3 do
        local step = CreateFrame("Frame", nil, podium)
        step:SetSize(STEP_WIDTH, STEP_HEIGHT)
        step:SetPoint("TOPLEFT", podium, "TOPLEFT", (slot - 1) * (STEP_WIDTH + STEP_GAP), -D_LABEL)
        local rank = STEP_SLOTS[slot]
        local medal = MEDALS[rank]
        step.block = flat(step, "ARTWORK")
        step.block:SetSize(STEP_WIDTH, STEP_BLOCKS[rank])
        step.block:SetPoint("BOTTOMLEFT", step, "BOTTOMLEFT", 0, 0)
        shade(step.block, "VERTICAL", BLOCK_BOTTOM, BLOCK_TOP)
        local edge = flat(step, "OVERLAY")
        edge:SetVertexColor(medal[1], medal[2], medal[3], 1)
        edge:SetSize(STEP_WIDTH, 2)
        edge:SetPoint("TOPLEFT", step.block, "TOPLEFT", 0, 0)
        step.rank = crisp(frame, step, 17, medal, "CENTER", TITLE_FONT)
        step.rank:SetPoint("CENTER", step.block, "CENTER", 0, 0)
        step.rank:SetText(tostring(rank))
        step.amount = crisp(frame, step, 11, COLOR.muted, "CENTER")
        step.amount:SetPoint("BOTTOM", step.block, "TOP", 0, 5)
        step.who = crisp(frame, step, 12.5, COLOR.text, "CENTER")
        step.who:SetPoint("BOTTOM", step.amount, "TOP", 0, 3)
        step.who:SetWidth(STEP_WIDTH - 4)
        local ring = flat(step, "ARTWORK")
        ring:SetVertexColor(0, 0, 0, 0.85)
        ring:SetSize(CLASS_ICON + 2, CLASS_ICON + 2)
        ring:SetPoint("BOTTOM", step.who, "TOP", 0, 3)
        step.icon = step:CreateTexture(nil, "OVERLAY")
        step.icon:SetSize(CLASS_ICON, CLASS_ICON)
        step.icon:SetPoint("CENTER", ring, "CENTER", 0, 0)
        step.icon.class = false
        podium.steps[slot] = step
    end
    podium.mine = crisp(frame, podium, 11.5, COLOR.muted)
    podium.mine:SetPoint("TOPLEFT", podium, "TOPLEFT", 0, -(D_LABEL + STEP_HEIGHT + 6))
    return podium
end

local function buildRecords(frame)
    local records = CreateFrame("Frame", nil, frame)
    sectionLabel(frame, records)
    records.label:SetText("PERSONAL RECORDS")
    records.rows = {}
    for index = 1, MAX_RECORDS do
        local row = CreateFrame("Frame", nil, records)
        row:SetSize(D_INNER, REC_ROW)
        row:SetPoint("TOPLEFT", records, "TOPLEFT", 0, -(D_LABEL + (index - 1) * (REC_ROW + REC_GAP)))
        row.fill = flat(row, "BACKGROUND")
        row.fill:SetAllPoints(row)
        row.edge = flat(row, "BORDER")
        row.edge:SetVertexColor(MINI_HIGH[1], MINI_HIGH[2], MINI_HIGH[3], 1)
        row.edge:SetWidth(2)
        row.edge:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.edge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.left = crisp(frame, row, 11.5, COLOR.text)
        row.left:SetPoint("LEFT", row, "LEFT", 9, 0)
        row.right = crisp(frame, row, 11, DIM, "RIGHT")
        row.right:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.mini = recessed(row, MINI_WIDTH, MINI_HEIGHT)
        row.mini:SetPoint("RIGHT", row, "RIGHT", -(REC_RIGHT + 8), 0)
        row.progress = flat(row, "OVERLAY")
        row.progress:SetHeight(MINI_HEIGHT)
        row.progress:SetPoint("LEFT", row.mini, "LEFT", 0, 0)
        shade(row.progress, "HORIZONTAL", MINI_LOW, MINI_HIGH)
        records.rows[index] = row
    end
    return records
end

local function buildSpells(frame)
    local spells = CreateFrame("Frame", nil, frame)
    sectionLabel(frame, spells)
    spells.label:SetText("TOP SPELLS · DAMAGE")
    spells.rows = {}
    for index = 1, MAX_SPELLS do
        local row = CreateFrame("Frame", nil, spells)
        row:SetSize(D_INNER, SPELL_ROW)
        row:SetPoint("TOPLEFT", spells, "TOPLEFT", 0, -(D_LABEL + (index - 1) * SPELL_ROW))
        local ring = flat(row, "ARTWORK")
        ring:SetVertexColor(0, 0, 0, 1)
        ring:SetSize(SPELL_ICON + 2, SPELL_ICON + 2)
        ring:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon = row:CreateTexture(nil, "OVERLAY")
        row.icon:SetSize(SPELL_ICON, SPELL_ICON)
        row.icon:SetPoint("CENTER", ring, "CENTER", 0, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.name = crisp(frame, row, 11.5, COLOR.text)
        row.name:SetPoint("LEFT", ring, "RIGHT", 6, 0)
        row.name:SetWidth(SPELL_NAME - SPELL_ICON - 12)
        local track = recessed(row, SPELL_TRACK, SPELL_BAR)
        track:SetPoint("LEFT", row, "LEFT", SPELL_NAME, 0)
        row.bar = flat(row, "OVERLAY")
        row.bar:SetHeight(SPELL_BAR)
        row.bar:SetPoint("LEFT", track, "LEFT", 0, 0)
        shade(row.bar, "VERTICAL", SPELL_BOTTOM, SPELL_TOP)
        row.value = crisp(frame, row, 11, COLOR.muted, "RIGHT")
        row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        grow(frame, row.bar, row, "LEFT")
        spells.rows[index] = row
    end
    return spells
end

local function startDrag(head)
    head.owner:StartMoving()
end

local function stopDrag(head)
    local frame = head.owner
    frame:StopMovingOrSizing()
    local store = charStore()
    if store then SoundAlerter.BarUtils:SavePosition(frame, store, "") end
end

local function hideFrame(button)
    button.owner:Hide()
end

local function settleDebrief(frame)
    local grows = frame.grows
    for index = 1, #grows do grows[index]:Stop() end
    if FX and FX.StopAppear then FX.StopAppear(frame) end
end

local function openBG()
    SoundAlerter:ShowStatisticsBG()
end

local function buildChrome(frame)
    for index = 1, #SHADOWS do
        local spec = SHADOWS[index]
        local size = spec[1]
        local layer = flat(frame, "BACKGROUND", -8 + index - 1)
        layer:SetVertexColor(0, 0, 0, spec[2])
        layer:SetPoint("TOPLEFT", frame, "TOPLEFT", -size, size - SHADOW_DROP)
        layer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", size, -size - SHADOW_DROP)
    end
    local body = flat(frame, "BACKGROUND", 0)
    body:SetAllPoints(frame)
    shade(body, "VERTICAL", BODY_BOTTOM, BODY_TOP, 0.98)
    Outline(frame, EDGE_COLOR)
    local lit = flat(frame, "BORDER", 2)
    lit:SetVertexColor(1, 1, 1, 0.07)
    lit:SetHeight(1)
    lit:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    lit:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    local footRule = flat(frame, "BORDER", 1)
    footRule:SetVertexColor(1, 1, 1, 0.06)
    footRule:SetHeight(1)
    footRule:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, D_FOOT)
    footRule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, D_FOOT)
end

local function buildDebrief()
    local frame = CreateFrame("Frame", DEBRIEF_NAME, UIParent)
    frame:SetSize(D_WIDTH, 300)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame.texts, frame.grows, frame.record = {}, {}, false
    frame.ppu = SoundAlerter.BarUtils:PixelsPerUnit(UIParent)
    buildChrome(frame)

    local head = CreateFrame("Frame", nil, frame)
    head.owner = frame
    head:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    head:SetHeight(D_HEAD - 1)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", startDrag)
    head:SetScript("OnDragStop", stopDrag)
    frame.head = head
    local band = flat(head, "ARTWORK")
    band:SetAllPoints(head)
    shade(band, "VERTICAL", HEAD_BOTTOM, HEAD_TOP)
    local title = crisp(frame, head, 10, COLOR.muted)
    title:SetPoint("LEFT", head, "LEFT", D_PAD, 0)
    title:SetText("BATTLEGROUND DEBRIEF")
    frame.map = crisp(frame, head, 11, DIM, "RIGHT")
    frame.map:SetPoint("RIGHT", head, "RIGHT", -28, 0)
    local close = CreateFrame("Button", nil, head)
    close.owner = frame
    close:SetSize(20, 20)
    close:SetPoint("RIGHT", head, "RIGHT", -4, 0)
    local cross = crisp(frame, close, 13, COLOR.muted, "CENTER")
    cross:SetAllPoints(close)
    cross:SetText("x")
    close:SetScript("OnClick", hideFrame)
    frame.close = close

    buildHeader(frame)
    frame.tug = buildTug(frame)
    frame.podium = buildPodium(frame)
    frame.records = buildRecords(frame)
    frame.spells = buildSpells(frame)

    frame.me = crisp(frame, frame, 11.5, COLOR.text)
    frame.me:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", D_PAD, 9)
    local link = CreateFrame("Button", nil, frame)
    link:SetSize(150, 20)
    link:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -D_PAD, 5)
    local label = crisp(frame, link, 11.5, COLOR.accent, "RIGHT")
    label:SetAllPoints(link)
    label:SetText("All battlegrounds >")
    link:SetScript("OnClick", openBG)
    frame.link = link

    local store = charStore()
    if store and store.PositionX then
        SoundAlerter.BarUtils:LoadPosition(frame, store, "", 0, 0)
    else
        frame:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -14, 0)
    end
    frame:SetScript("OnHide", settleDebrief)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, DEBRIEF_NAME) end
    return frame
end

local function applyFonts(frame)
    local BarUtils = SoundAlerter.BarUtils
    local ppu = BarUtils:PixelsPerUnit(UIParent)
    if ppu == frame.ppu then return end
    frame.ppu = ppu
    local texts = frame.texts
    for index = 1, #texts do
        local label = texts[index]
        BarUtils:CrispFont(label, label.crispUnits, ppu, label.crispFont)
    end
end

local function place(frame, section, y, height)
    section:ClearAllPoints()
    section:SetPoint("TOPLEFT", frame, "TOPLEFT", D_PAD, -y)
    section:SetSize(D_INNER, height)
    section:Show()
    return y + height + D_GAP
end

local function fillHeader(frame, record)
    local result = record.result
    local color = result == "won" and COLOR.on or result == "lost" and LOSS or GREY
    frame.result:SetText(result == "won" and "Victory" or result == "lost" and "Defeat" or "Match over")
    Tint(frame.result, color)
    if frame.washColor ~= color then
        frame.washColor = color
        if frame.wash.SetGradient and CreateColor then
            frame.wash:SetVertexColor(1, 1, 1, 1)
            frame.wash:SetGradient("HORIZONTAL", CreateColor(color[1], color[2], color[3], 0.3), CreateColor(color[1], color[2], color[3], 0))
        else
            frame.wash:SetVertexColor(color[1], color[2], color[3], 0.15)
        end
        frame.rule:SetVertexColor(color[1], color[2], color[3], 0.3)
    end
    frame.meta:SetText((record.map or "?") .. " · " .. Model.Clock(record.length) .. " · +" .. (record.me[Model.HONOR] or 0) .. " honor")
    local faction = record.faction
    if frame.crestFaction ~= faction then
        frame.crestFaction = faction
        local atlas = CREST_ATLAS[faction]
        if atlas and frame.crest.SetAtlas then
            frame.crest:SetAtlas(atlas)
            frame.crest:Show()
        else
            frame.crest:Hide()
        end
    end
end

local function fillTug(tug, record, rows)
    local faction = record.faction
    local ours, theirs = FACTION_COLOR[faction] or COLOR.on, FACTION_COLOR[faction == 0 and 1 or 0]
    local oursLow, oursHigh = barShade(ours)
    local theirsLow, theirsHigh = barShade(theirs)
    for index = 1, MAX_TUG do
        local row, data = tug.rows[index], rows[index]
        if data then
            local total = data.us + data.them
            local share = total > 0 and data.us / total or 0.5
            row.label:SetText(string.upper(data.label))
            row.us:SetText(Model.Short(data.us))
            row.them:SetText(Model.Short(data.them))
            row.left:SetWidth(math.max(1, share * TUG_TRACK))
            row.right:SetWidth(math.max(1, (1 - share) * TUG_TRACK))
            shade(row.left, "VERTICAL", oursLow, oursHigh)
            shade(row.right, "VERTICAL", theirsLow, theirsHigh)
            row:Show()
        else
            row:Hide()
        end
    end
    return #rows * TUG_ROW
end

local function fillPodium(podium, record, data)
    podium.label:SetText("TEAM " .. string.upper(data.name) .. " PODIUM")
    local stat, me = data.stat, record.me
    for slot = 1, 3 do
        local step, row = podium.steps[slot], data.top[STEP_SLOTS[slot]]
        if row then
            step.who:SetText(row[Model.NAME] or "?")
            step.who:SetTextColor(classColor(row[Model.CLASS]))
            step.amount:SetText(Model.Short(row[stat]))
            setClassIcon(step.icon, row[Model.CLASS])
            local mine = row == me
            shade(step.block, "VERTICAL", mine and ME_BOTTOM or BLOCK_BOTTOM, mine and ME_TOP or BLOCK_TOP)
            step:Show()
        else
            step:Hide()
        end
    end
    if data.place > Model.PODIUM then
        podium.mine:SetText("You: " .. ordinal(data.place) .. " of " .. data.of .. " · " .. Model.Short(data.value) .. " " .. data.name)
        podium.mine:Show()
        return D_LABEL + STEP_HEIGHT + ME_LINE
    end
    podium.mine:Hide()
    return D_LABEL + STEP_HEIGHT
end

local function fillRecords(records, list)
    for index = 1, MAX_RECORDS do
        local row, data = records.rows[index], list[index]
        if data then
            row.left:SetText((data.new and NEW_TAG or "") .. data.label .. "  " .. Model.Short(data.value))
            local progress
            if data.prior == nil then
                row.right:SetText("first record")
            elseif data.new then
                row.right:SetText("was " .. Model.Short(data.prior))
                progress = 1
            else
                row.right:SetText("best " .. Model.Short(data.prior) .. (data.percent and (" · " .. data.percent .. "%") or ""))
                progress = data.prior > 0 and math.min(1, data.value / data.prior) or 0
            end
            local hasBar = progress ~= nil
            row.mini:SetShown(hasBar)
            row.progress:SetShown(hasBar and progress > 0)
            if hasBar then row.progress:SetWidth(math.max(1, progress * MINI_WIDTH)) end
            if data.new then
                shade(row.fill, "HORIZONTAL", NEW_LEFT, NEW_RIGHT)
            else
                shade(row.fill, "HORIZONTAL", CELL_FILL, CELL_FILL)
            end
            row.edge:SetShown(data.new)
            row:Show()
        else
            row:Hide()
        end
    end
    return D_LABEL + #list * (REC_ROW + REC_GAP) - REC_GAP
end

local function fillSpells(spells, list)
    local top = list[1][2]
    local count = math.min(#list, MAX_SPELLS)
    for index = 1, MAX_SPELLS do
        local row, data = spells.rows[index], list[index]
        if data and index <= count then
            row.name:SetText(data[1])
            row.value:SetText(Model.Short(data[2]))
            row.bar:SetWidth(math.max(1, top > 0 and data[2] / top * SPELL_TRACK or 1))
            row.icon:SetTexture(spellIcon(data[3]))
            row:Show()
        else
            row:Hide()
        end
    end
    return D_LABEL + count * SPELL_ROW
end

local function bgStore()
    local stats = SoundAlerter.Statistics
    return stats and stats.GetBG and stats:GetBG() or nil
end

local function fillDebrief(frame, record)
    if frame.record == record then return end
    frame.record = record
    local data = Model.Debrief(record, Model.Snapshot(bgStore()))
    frame.map:SetText(record.map or "")
    fillHeader(frame, record)
    local y = D_HEAD + WASH_HEIGHT + D_PAD
    if #data.tug > 0 then
        y = place(frame, frame.tug, y, fillTug(frame.tug, record, data.tug))
    else
        frame.tug:Hide()
    end
    if data.podium then
        y = place(frame, frame.podium, y, fillPodium(frame.podium, record, data.podium))
    else
        frame.podium:Hide()
    end
    if data.records then
        y = place(frame, frame.records, y, fillRecords(frame.records, data.records))
    else
        frame.records:Hide()
    end
    if data.spells then
        y = place(frame, frame.spells, y, fillSpells(frame.spells, data.spells))
    else
        frame.spells:Hide()
    end
    local me = record.me
    frame.me:SetText(me[Model.NAME] or "")
    frame.me:SetTextColor(classColor(me[Model.CLASS]))
    frame:SetHeight(y - D_GAP + D_PAD + D_FOOT)
end

local function playGrow(frame)
    local grows = frame.grows
    for index = 1, #grows do
        local group = grows[index]
        if group.row:IsShown() then
            group:Stop()
            group:Play()
        end
    end
end

function UI.OpenDebrief(record, toggle)
    if not record then return false end
    debrief = debrief or buildDebrief()
    if toggle and debrief:IsShown() and debrief.record == record then
        debrief:Hide()
        return false
    end
    applyFonts(debrief)
    fillDebrief(debrief, record)
    debrief:Show()
    if FX and FX.Appear and FX.Appear(debrief) then playGrow(debrief) end
    return true
end

function UI.Debrief()
    return debrief
end

local function debriefOn()
    local stats = SoundAlerter.Statistics
    local settings = stats and stats.GetSettings and stats:GetSettings()
    return not settings or settings.bgDebrief ~= false
end

local function closePopup()
    if popup then popup:Hide() end
    if debrief then debrief:Hide() end
end

local function dismiss()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
    if pill then
        pill.drain:Stop()
        pill:Hide()
        pill:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end

local function togglePopup()
    if not current then return end
    if debriefOn() then
        UI.OpenDebrief(current, true)
        return
    end
    if not popup then
        popup = UI.NewCard(UIParent, true, CARD_NAME)
        popup:SetFrameStrata("HIGH")
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        popup:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -14, 0)
        popup:Hide()
        if UISpecialFrames then table.insert(UISpecialFrames, CARD_NAME) end
    end
    if popup:IsShown() and popup.record == current then
        popup:Hide()
        return
    end
    UI.FillCard(popup, current)
    popup:Show()
    if FX and FX.Appear then FX.Appear(popup) end
end

local function buildPill()
    local frame = CreateFrame("Button", nil, UIParent)
    frame:SetHeight(PILL_HEIGHT)
    frame:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, PILL_OFFSET_Y)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:Hide()
    local fill = Paint(frame, CARD_FILL, 0.95)
    fill:SetAllPoints(frame)
    Outline(frame, PILL_EDGE)
    local stripe = Paint(frame, COLOR.on, 1, "ARTWORK")
    stripe:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    stripe:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    stripe:SetWidth(PILL_STRIPE)
    local line = Paint(frame, COLOR.on, 0.7, "OVERLAY")
    line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    line:SetHeight(PILL_LINE)
    local drain = line:CreateAnimationGroup()
    local shrink = drain:CreateAnimation("Scale")
    shrink:SetDuration(Model.PILL_SECONDS)
    if shrink.SetScaleFrom then
        shrink:SetScaleFrom(1, 1)
        shrink:SetScaleTo(DRAIN_END, 1)
    else
        shrink:SetScale(DRAIN_END, 1)
    end
    if shrink.SetOrigin then shrink:SetOrigin("LEFT", 0, 0) end
    frame.stripe, frame.line, frame.drain = stripe, line, drain
    frame.text = Text(frame, 11.5, COLOR.text)
    frame.text:SetPoint("LEFT", frame, "LEFT", PILL_TEXT_X, 0)
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(PILL_CLOSE, PILL_HEIGHT)
    close:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    local cross = Text(close, 12, COLOR.muted, "CENTER")
    cross:SetAllPoints(close)
    cross:SetText("x")
    close:SetScript("OnClick", dismiss)
    frame:SetScript("OnClick", togglePopup)
    frame:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        UI.RevealPill()
    end)
    return frame
end

function UI.RevealPill()
    if not (pill and current) then return end
    pill.text:SetText(Model.PillText(current))
    pill:SetWidth(PILL_TEXT_X + pill.text:GetStringWidth() + 6 + PILL_CLOSE)
    local color = current.result == "lost" and LOSS or COLOR.on
    Tint(pill.stripe, color, 1)
    Tint(pill.line, color, 0.7)
    pill.drain:Stop()
    pill.drain:Play()
    pill:Show()
    if FX and FX.Appear then FX.Appear(pill) end
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(Model.PILL_SECONDS, dismiss)
end

function SoundAlerter:ShowBGResult(record)
    if not record then return end
    current = record
    pill = pill or buildPill()
    if popup and popup:IsShown() then UI.FillCard(popup, record) end
    if debrief and debrief:IsShown() then fillDebrief(debrief, record) end
    if InCombatLockdown() then
        pill:Hide()
        pill:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    UI.RevealPill()
end

function SoundAlerter:ShowBGDebrief()
    local store = bgStore()
    local record = store and store.history and store.history[1]
    if not record then
        self:Print("No battleground recorded yet.")
        return false
    end
    return UI.OpenDebrief(record, false)
end

function SoundAlerter:HideBGResult()
    dismiss()
    closePopup()
end

SA_BGResultUI = UI
