local SoundAlerter = SoundAlerter
local AceGUI = LibStub("AceGUI-3.0")
local Kit = SoundAlerter.Page.Kit
local QuickStart = SA_QuickStart
local FX = SA_MenuFX

local COLOR, Paint, Outline, Text, Tint = Kit.COLOR, Kit.Paint, Kit.Outline, Kit.Text, Kit.Tint

local WIDGET = "SoundAlerterQuickStart"
local WINDOW_NAME = "SoundAlerterSetupWindow"
local WINDOW_WIDTH, WINDOW_HEIGHT, TITLE_HEIGHT = 680, 520, 30
local WINDOW_COLOR = { 0.059, 0.071, 0.094 }
local GOLD = { 0.95, 0.85, 0.6 }
local PAD, GAP = 18, 8
local SEGMENT_HEIGHT = 4
local HEAD_Y, BODY_Y = 50, 112
local FOOTER_HEIGHT = 46
local ROW_HEIGHT, CARD_HEIGHT, HEADING_HEIGHT, CHOICE_HEIGHT, SUMMARY_HEIGHT = 34, 58, 22, 36, 26
local VALUE_X = 170
local FIRST_RUN_DELAY = 3
local TEST_SOUND = "trinket.mp3"
local MAX_STEPS = #QuickStart.STEPS
local SCOPES = { { "myself", "Target and focus" }, { "enemyinrange", "All enemies in range" } }

local wizard, window
local environment = { supported = false }

local function profile()
    return SoundAlerter.db1 and SoundAlerter.db1.profile
end

local function volume()
    return math.floor((tonumber(GetCVar("Sound_MasterVolume")) or 1) * 100 + 0.5)
end

local function markDone()
    local global = SoundAlerter.db1 and SoundAlerter.db1.global
    if global then global.quickStartDone = true end
end

local function reload(name)
    return function()
        local active = SoundAlerter[name]
        if active then active:LoadSettings() end
    end
end

local function refreshIcon()
    SoundAlerter:UpdateMinimapButtonIcon()
end

local REFRESH = {
    castbars = reload("CastingBars"),
    tracker = reload("SpellTracker"),
    castfeed = reload("CastFeed"),
    resource = function()
        local bars = SoundAlerter.ResourceBar
        if bars then bars:UpdateVisibility() end
    end,
    proximity = refreshIcon,
    flags = refreshIcon,
    sightings = function() SoundAlerter:UpdateGlobalSight() end,
    party = function() SoundAlerter:UpdatePartyShare() end,
}

local function Take(pool, index, factory, owner, parent)
    local frame = pool[index]
    if not frame then
        frame = factory(owner, parent)
        pool[index] = frame
    end
    return frame
end

local function HideFrom(pool, first)
    for index = first, #pool do pool[index]:Hide() end
end

local function NewHeading(_, parent)
    local heading = CreateFrame("Frame", nil, parent)
    heading.text = Text(heading, 11, COLOR.muted)
    heading.text:SetPoint("BOTTOMLEFT", heading, "BOTTOMLEFT", 8, 3)
    return heading
end

local function NewRow(owner, parent)
    local row = CreateFrame("Button", nil, parent)
    row.tint = Paint(row, COLOR.line, 0.5)
    row.tint:SetAllPoints(row)
    row.tint:Hide()
    row.title = Text(row, 13, COLOR.text)
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
    row.title:SetPoint("RIGHT", row, "RIGHT", -64, 0)
    row.hint = Text(row, 11, COLOR.muted)
    row.hint:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
    row.hint:SetPoint("RIGHT", row, "RIGHT", -64, 0)
    row.switch = Kit.MakeToggle(row, function(value) owner:Toggle(row, value) end)
    row.switch.frame:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row:SetScript("OnClick", function() row.switch.frame:Click() end)
    FX.Hover(row, row.tint, row.switch.frame)
    return row
end

local function NewCard(owner, parent)
    local card = CreateFrame("Button", nil, parent)
    card.fill = Paint(card, COLOR.card)
    card.fill:SetAllPoints(card)
    Outline(card, COLOR.line)
    card.title = Text(card, 13, COLOR.text)
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
    card.title:SetPoint("RIGHT", card, "RIGHT", -10, 0)
    card.hint = Text(card, 11, COLOR.muted)
    card.hint:SetWordWrap(true)
    card.hint:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
    card.hint:SetPoint("RIGHT", card, "RIGHT", -10, 0)
    card:SetScript("OnClick", function() owner:Preset(card.key) end)
    return card
end

local function NewCardRow(owner, parent)
    local row = CreateFrame("Frame", nil, parent)
    row.cards = {}
    for index = 1, #QuickStart.PRESETS do
        row.cards[index] = NewCard(owner, row)
    end
    row:SetScript("OnSizeChanged", function(self, width)
        local count = #self.cards
        local size = (width - (count - 1) * GAP) / count
        for index, card in ipairs(self.cards) do
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", self, "TOPLEFT", (index - 1) * (size + GAP), 0)
            card:SetSize(size, CARD_HEIGHT)
        end
    end)
    return row
end

local function NewChoice(owner, parent)
    local row = CreateFrame("Frame", nil, parent)
    row.title = Text(row, 13, COLOR.text)
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
    row.hint = Text(row, 11, COLOR.muted)
    row.hint:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
    row.chips = {}
    local anchor
    for index = #SCOPES, 1, -1 do
        local option = SCOPES[index]
        local chip = Kit.MakeChip(row, option[2], function() owner:Scope(option[1]) end)
        if anchor then
            chip.frame:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
        else
            chip.frame:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        end
        anchor = chip.frame
        row.chips[index] = chip
    end
    return row
end

local function NewVolume(_, parent)
    local row = CreateFrame("Frame", nil, parent)
    row.title = Text(row, 13, COLOR.text)
    row.title:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.test = Kit.MakeButton(row, "Play test sound", function()
        local current = profile()
        if current then SoundAlerter:PlayVoice(current.sapath .. TEST_SOUND) end
    end)
    row.test.frame:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.slider = Kit.MakeRange(row, { min = 0, max = 100, step = 10, unit = "%" }, function(value)
        SetCVar("Sound_MasterVolume", tostring(value / 100))
    end)
    row.slider.frame:SetPoint("RIGHT", row.test.frame, "LEFT", -12, 0)
    return row
end

local function NewSummary(_, parent)
    local row = CreateFrame("Frame", nil, parent)
    row.label = Text(row, 12, COLOR.muted)
    row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.value = Text(row, 12, COLOR.text)
    row.value:SetPoint("LEFT", row, "LEFT", VALUE_X, 0)
    row.value:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    return row
end

local Wizard = {}
Wizard.__index = Wizard

function Wizard:Place(frame, height)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -self.y)
    frame:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", 0, -self.y)
    frame:SetHeight(height)
    frame:Show()
    self.y = self.y + height + 2
end

function Wizard:Heading(text)
    self.headingCount = self.headingCount + 1
    local heading = Take(self.headings, self.headingCount, NewHeading, self, self.body)
    heading.text:SetText(text)
    self:Place(heading, HEADING_HEIGHT)
end

function Wizard:Row(source, key, item, title, hint, on)
    self.rowCount = self.rowCount + 1
    local row = Take(self.rows, self.rowCount, NewRow, self, self.body)
    row.source, row.key, row.item = source, key, item
    row.title:SetText(title)
    row.hint:SetText(hint)
    row.switch:Set(on)
    self:Place(row, ROW_HEIGHT)
end

function Wizard:Summary(label, value)
    self.summaryCount = self.summaryCount + 1
    local row = Take(self.summaries, self.summaryCount, NewSummary, self, self.body)
    row.label:SetText(label)
    row.value:SetText(value)
    self:Place(row, SUMMARY_HEIGHT)
end

function Wizard:Toggle(row, value)
    local current = profile()
    if not current then return end
    if row.source == "zone" then
        current[row.key] = value
    elseif row.source == "heard" then
        QuickStart.SetHeard(current, row.key, value)
    else
        row.item.set(current, value)
        local refresh = REFRESH[row.item.key]
        if refresh then refresh() end
    end
    self:Render()
end

function Wizard:Preset(key)
    local current = profile()
    if current and QuickStart.ApplyPreset(current, key) then self:Render() end
end

function Wizard:Scope(value)
    local current = profile()
    if current then
        QuickStart.SetScope(current, value)
        self:Render()
    end
end

function Wizard:Move(delta)
    local target = self.index + delta
    if target > #self.steps then
        self:Finish()
        return
    end
    self.index = math.max(1, target)
    self:Render()
    FX.SlideIn(self.content, self.holder)
end

function Wizard:Finish()
    markDone()
    if self.mode == "window" then
        window.frame:Hide()
        return
    end
    SoundAlerter:Print("Quick Start: your choices are saved.")
    self.index = 1
    self:Render()
end

function Wizard:LayoutProgress()
    local width = self.root:GetWidth() - 2 * PAD
    local count = #self.steps
    if width <= 0 or count == 0 then return end
    local cell = (width + GAP) / count
    for index = 1, MAX_STEPS do
        local segment, label = self.segments[index], self.labels[index]
        if index <= count then
            local x = PAD + (index - 1) * cell
            segment:ClearAllPoints()
            segment:SetPoint("TOPLEFT", self.root, "TOPLEFT", x, -14)
            segment:SetSize(cell - GAP, SEGMENT_HEIGHT)
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", self.root, "TOPLEFT", x, -24)
            label:SetWidth(cell - GAP)
            segment:Show()
            label:Show()
        else
            segment:Hide()
            label:Hide()
        end
    end
end

function Wizard:DrawProgress()
    for index, step in ipairs(self.steps) do
        local current = index == self.index
        if current then
            Tint(self.segments[index], COLOR.accent, 1)
        elseif index < self.index then
            Tint(self.segments[index], COLOR.accent, 0.5)
        else
            Tint(self.segments[index], COLOR.line, 1)
        end
        Tint(self.labels[index], current and COLOR.accent or COLOR.muted)
        self.labels[index]:SetText(step.label)
    end
end

function Wizard:DrawStyle(current)
    local active = QuickStart.ActivePreset(current)
    self:Place(self.cardRow, CARD_HEIGHT)
    for index, preset in ipairs(QuickStart.PRESETS) do
        local card = self.cardRow.cards[index]
        card.key = preset.key
        card.title:SetText(preset.label)
        card.hint:SetText(preset.hint)
        if active and active.key == preset.key then
            Tint(card.fill, COLOR.accent, 0.25)
        else
            Tint(card.fill, COLOR.card, 1)
        end
    end
    self.y = self.y + 6
    self:Heading("Where should it be active?")
    for _, zone in ipairs(QuickStart.ZONES) do
        self:Row("zone", zone.key, nil, zone.label, zone.hint, current[zone.key] and true or false)
    end
    self:Heading("Who triggers alerts?")
    local choice = self.choice
    choice.title:SetText("Alert source")
    choice.hint:SetText("Recommended: target and focus for Arena, all enemies for Battlegrounds")
    local scope = QuickStart.Scope(current)
    for index, option in ipairs(SCOPES) do choice.chips[index]:Set(scope == option[1]) end
    self:Place(choice, CHOICE_HEIGHT)
end

function Wizard:DrawHear(current)
    local row = self.volume
    row.title:SetText("Master volume")
    row.slider:Set(volume())
    self:Place(row, CHOICE_HEIGHT)
    for _, category in ipairs(QuickStart.CATEGORIES) do
        self:Row("heard", category.key, nil, category.label, category.hint, QuickStart.Heard(current, category.key))
    end
end

function Wizard:DrawItems(current, stepKey)
    for _, item in ipairs(QuickStart.Items(stepKey, current, environment)) do
        self:Row("item", item.key, item, item.label, item.hint, item.get(current))
    end
end

function Wizard:DrawDone(current)
    for _, pair in ipairs(QuickStart.SummaryRows(current, volume(), environment)) do
        self:Summary(pair[1], pair[2])
    end
end

function Wizard:Render()
    local current = profile()
    if not current then return end
    environment.supported = SA_PartyShare.Supported()
    self.steps = QuickStart.ActiveSteps(current, environment)
    self.index = math.min(math.max(self.index, 1), #self.steps)
    local step = self.steps[self.index]
    local last = self.index == #self.steps
    self:LayoutProgress()
    self:DrawProgress()
    self.title:SetText(step.title)
    self.hint:SetText(step.hint)
    self.y, self.rowCount, self.headingCount, self.summaryCount = 0, 0, 0, 0
    self.cardRow:Hide()
    self.choice:Hide()
    self.volume:Hide()
    if step.key == "style" then
        self:DrawStyle(current)
    elseif step.key == "hear" then
        self:DrawHear(current)
    elseif step.key == "done" then
        self:DrawDone(current)
    else
        self:DrawItems(current, step.key)
    end
    HideFrom(self.rows, self.rowCount + 1)
    HideFrom(self.headings, self.headingCount + 1)
    HideFrom(self.summaries, self.summaryCount + 1)
    self.back.frame:SetShown(self.index > 1)
    self.skip:SetShown(self.mode == "window" and not last)
    self.next.label:SetText(last and "Done" or "Next")
end

function Wizard:Attach(parent, mode)
    local root = self.root
    root:SetParent(parent)
    root:ClearAllPoints()
    root:SetAllPoints(parent)
    root:Show()
    self.parent, self.mode, self.index = parent, mode, 1
    self:Render()
end

function Wizard:Detach()
    self.root:Hide()
    self.root:SetParent(UIParent)
    self.parent = nil
end

local function NewWizard()
    local self = setmetatable({ steps = {}, index = 1, y = 0, rows = {}, headings = {}, summaries = {}, segments = {}, labels = {} }, Wizard)
    local root = CreateFrame("Frame", nil, UIParent)
    root:Hide()
    self.root = root
    for index = 1, MAX_STEPS do
        self.segments[index] = Paint(root, COLOR.line)
        self.labels[index] = Text(root, 11, COLOR.muted)
    end
    root:SetScript("OnSizeChanged", function() self:LayoutProgress() end)
    self.title = Text(root, 17, GOLD)
    self.title:SetPoint("TOPLEFT", root, "TOPLEFT", PAD, -HEAD_Y)
    self.hint = Text(root, 12, COLOR.muted)
    self.hint:SetWordWrap(true)
    self.hint:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
    self.hint:SetPoint("RIGHT", root, "RIGHT", -PAD, 0)
    self.holder = CreateFrame("Frame", nil, root)
    self.holder:SetPoint("TOPLEFT", root, "TOPLEFT", PAD, -BODY_Y)
    self.holder:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -PAD, FOOTER_HEIGHT)
    self.content = CreateFrame("Frame", nil, self.holder)
    self.content:SetAllPoints(self.holder)
    self.body = self.content
    self.cardRow = NewCardRow(self, self.body)
    self.choice = NewChoice(self, self.body)
    self.volume = NewVolume(self, self.body)
    self.next = Kit.MakeButton(root, "Next", function() self:Move(1) end)
    self.next.frame:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -PAD, 12)
    self.next.label:SetTextColor(COLOR.accent[1], COLOR.accent[2], COLOR.accent[3])
    self.back = Kit.MakeButton(root, "Back", function() self:Move(-1) end)
    self.back.frame:SetPoint("RIGHT", self.next.frame, "LEFT", -8, 0)
    self.skip = CreateFrame("Button", nil, root)
    self.skip:SetSize(100, 22)
    self.skip:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", PAD, 12)
    local skipLabel = Text(self.skip, 12, COLOR.muted, "LEFT")
    skipLabel:SetPoint("LEFT", self.skip, "LEFT", 0, 0)
    skipLabel:SetText("Skip setup")
    self.skip:SetScript("OnClick", function() window.frame:Hide() end)
    return self
end

local function Get()
    if not wizard then wizard = NewWizard() end
    return wizard
end

local function BuildWindow()
    local frame = CreateFrame("Frame", WINDOW_NAME, UIParent)
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:Hide()
    Paint(frame, WINDOW_COLOR):SetAllPoints(frame)
    Outline(frame, COLOR.line)
    local title = Text(frame, 14, GOLD)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -9)
    title:SetText("Welcome to SoundAlerter")
    local line = Paint(frame, COLOR.line, 1, "BORDER")
    line:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -TITLE_HEIGHT)
    line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -TITLE_HEIGHT)
    line:SetHeight(1)
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(TITLE_HEIGHT, TITLE_HEIGHT)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    local cross = Text(close, 14, COLOR.muted, "CENTER")
    cross:SetPoint("CENTER", close, "CENTER", 0, 0)
    cross:SetText("x")
    close:SetScript("OnClick", function() frame:Hide() end)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -TITLE_HEIGHT - 1)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame:SetScript("OnHide", function()
        markDone()
        if wizard and wizard.parent == content then wizard:Detach() end
    end)
    tinsert(UISpecialFrames, WINDOW_NAME)
    return { frame = frame, content = content }
end

local function OpenWindow()
    if not profile() then return end
    window = window or BuildWindow()
    Get():Attach(window.content, "window")
    window.frame:Show()
end

function SoundAlerter:ShowQuickStartSetup()
    OpenWindow()
end

function SoundAlerter:CheckQuickStartSetup()
    local global = self.db1 and self.db1.global
    if global and QuickStart.NeedsSetup(global) then self:ScheduleTimer("ShowQuickStartSetup", FIRST_RUN_DELAY) end
end

local WidgetMethods = {}

function WidgetMethods:OnAcquire()
    self.frame:SetHeight(Kit.PAGE_HEIGHT)
    self.frame:Show()
end

function WidgetMethods:OnRelease()
    if wizard and wizard.parent == self.frame then wizard:Detach() end
    self.page = nil
end

function WidgetMethods:SetText() end
function WidgetMethods:SetFontObject() end

function WidgetMethods:SetCustomData()
    if window and window.frame:IsShown() then window.frame:Hide() end
    local active = Get()
    self.page = active
    active:Attach(self.frame, "page")
    FX.SlideIn(active.root, self.frame)
    Kit.FitWidget(self)
end

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetHeight(Kit.PAGE_HEIGHT)
    local widget = { type = WIDGET, frame = frame }
    frame.obj = widget
    for name, method in pairs(WidgetMethods) do widget[name] = method end
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(WIDGET, Constructor, 1)

SoundAlerter.QuickStartWizard = { Widget = WIDGET, Get = Get }
