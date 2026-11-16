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

local pill, popup, hideTimer, current

local function closePopup()
    if popup then popup:Hide() end
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
    if InCombatLockdown() then
        pill:Hide()
        pill:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    UI.RevealPill()
end

function SoundAlerter:HideBGResult()
    dismiss()
    closePopup()
end

SA_BGResultUI = UI
