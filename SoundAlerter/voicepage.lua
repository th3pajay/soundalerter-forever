local SoundAlerter = SoundAlerter
local AceGUI = LibStub("AceGUI-3.0")
local Page = SoundAlerter.Page
local Kit = Page.Kit
local Model = SA_VoiceModel
local Rail = SA_OptionsRail
local FX = SA_MenuFX

local COLOR, Paint, Outline, Text = Kit.COLOR, Kit.Paint, Kit.Outline, Kit.Text

local WIDGET = "SoundAlerterVoicePage"
local HEADER_HEIGHT = 80
local GAP = 12
local RAIL_WIDTH = 150
local RAIL_ROW = 26
local ROW_PLAIN = 28
local ROW_HINT = 38
local ROW_TEXT = 48
local CARD_TITLE = Kit.CARD_TITLE
local PILL_HEIGHT = 20
local PILL_STEP = 24
local NAME_X = 38
local NAME_WIDTH = 140
local SPELL_ROW_MIN = 34
local LIST_HEAD = 36
local MAX_RESULTS = 40
local ARM_SECONDS = 4
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local CHAT_ICON = "Interface\\Icons\\INV_Letter_15"
local PLAY_ICON = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"

local EVENT_HELP = {
    ["Gained"] = "An enemy gains this buff or cooldown.",
    ["Faded"] = "The buff or cooldown ends.",
    ["Cast start"] = "An enemy starts casting this spell.",
    ["Cast"] = "An enemy casts this spell.",
    ["On you"] = "This lands on you.",
    ["On friend"] = "This lands on your arena partner or a friend.",
    ["On enemy"] = "This lands on an enemy because of you or your partner.",
    ["CC faded"] = "Your crowd control on an enemy ends.",
    ["Interrupts you"] = "You are interrupted.",
}

local CLASS_COLOR = {
    Druid = { 1, 0.49, 0.04 }, Hunter = { 0.67, 0.83, 0.45 }, Mage = { 0.41, 0.8, 0.94 }, Paladin = { 0.96, 0.55, 0.73 },
    Priest = { 1, 1, 1 }, Rogue = { 1, 0.96, 0.41 }, Shaman = { 0, 0.44, 0.87 }, Warlock = { 0.58, 0.51, 0.79 },
    Warrior = { 0.78, 0.61, 0.43 }, Races = { 0.6, 0.64, 0.71 }, Other = { 0.49, 0.52, 0.59 },
}

local CLASS_ICON = {
    Druid = "Interface\\Icons\\ClassIcon_Druid",
    Hunter = "Interface\\Icons\\ClassIcon_Hunter",
    Mage = "Interface\\Icons\\ClassIcon_Mage",
    Paladin = "Interface\\Icons\\ClassIcon_Paladin",
    Priest = "Interface\\Icons\\ClassIcon_Priest",
    Rogue = "Interface\\Icons\\ClassIcon_Rogue",
    Shaman = "Interface\\Icons\\ClassIcon_Shaman",
    Warlock = "Interface\\Icons\\ClassIcon_Warlock",
    Warrior = "Interface\\Icons\\ClassIcon_Warrior",
    Races = "Interface\\Icons\\INV_Misc_Head_Human_01",
    Other = QUESTION,
}

local TABS = { { "spells", "Spell Alerts" }, { "chat", "Chat Alerts" } }

local Voice = {}

local iconCache = {}

local function SpellIcon(spellID)
    local icon = iconCache[spellID]
    if not icon then
        local _, _, texture = SA_COMPAT.GetSpellInfo(spellID)
        icon = texture
        iconCache[spellID] = icon
    end
    return icon or QUESTION
end

local function ShowTip(owner, title, body)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if body and body ~= "" then GameTooltip:AddLine(body, 0.6, 0.65, 0.7, true) end
    GameTooltip:Show()
end

local function HideTip()
    GameTooltip:Hide()
end

local Tint, Flow, NewChip = Kit.Tint, Kit.Flow, Kit.MakeChip

local function Gate(key)
    return function(settings) return settings[key] end
end

local NewView, NewHeading, NewLink = Kit.NewView, Kit.NewHeading, Kit.NewLink
local NewDivider, PlaceDivider, NewCard, PlaceCard = Kit.NewDivider, Kit.PlaceDivider, Kit.NewCard, Kit.PlaceCard

function Voice:Db()
    return self.spec.db()
end

function Voice:AddSetting(card, spec)
    local page = self
    local inline = spec.hint and spec.inline
    local height = spec.kind == "text" and ROW_TEXT or (inline and ROW_HINT or ROW_PLAIN)
    local frame = CreateFrame("Frame", nil, card.frame)
    frame:SetHeight(height)
    frame:EnableMouse(true)
    local tint = Paint(frame, COLOR.line, 0.5)
    tint:SetAllPoints(frame)
    tint:Hide()
    local flash = Paint(frame, COLOR.accent, 0.3, "BORDER")
    flash:SetAllPoints(frame)
    flash:Hide()
    local rule = Paint(frame, COLOR.line, 0.55)
    rule:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)

    local entry = { spec = spec, frame = frame, flash = flash, height = height }
    local function change(value) page:Change(entry, value) end
    local control
    if spec.kind == "range" then
        control = Kit.MakeRange(frame, spec, change)
        control.frame:SetSize(180, 22)
        control.slider:SetWidth(118)
    elseif spec.kind == "text" then
        control = Kit.MakeText(frame, spec, change)
    else
        control = Kit.MakeToggle(frame, change)
    end
    entry.control = control

    local left = spec.sub and 18 or 4
    if spec.iconFor then
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", frame, "LEFT", 4, 0)
        icon:SetTexture(spec.iconFor())
        left = 30
    end
    local label = Text(frame, 12.5, COLOR.text)
    label:SetText(spec.label)
    if spec.kind == "text" then
        label:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -5)
        label:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
        control.frame:ClearAllPoints()
        control.frame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 4)
        control.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
        control.frame:SetHeight(22)
    else
        control.frame:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
        label:SetPoint("LEFT", frame, "LEFT", left, inline and 7 or 0)
        label:SetPoint("RIGHT", control.frame, "LEFT", -8, 0)
        if inline then
            local hint = Text(frame, 10.5, COLOR.muted)
            hint:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
            hint:SetPoint("RIGHT", control.frame, "LEFT", -8, 0)
            hint:SetText(spec.hint)
        end
    end

    local function enter() ShowTip(frame, spec.label, spec.hint) end
    frame:SetScript("OnEnter", enter)
    frame:SetScript("OnLeave", HideTip)
    control.frame:HookScript("OnEnter", enter)
    control.frame:HookScript("OnLeave", HideTip)
    FX.Hover(frame, tint)

    card.rows[#card.rows + 1] = entry
    self.settings[#self.settings + 1] = entry
    return entry
end

function Voice:Change(entry, value)
    local spec = entry.spec
    local settings = self:Db()
    if spec.kind == "text" and settings[spec.key] == value then return end
    settings[spec.key] = value
    if spec.after then spec.after(value, settings) end
    self:Refresh()
    FX.Flash(entry.flash)
end

local function SyncSetting(entry, settings)
    local spec = entry.spec
    local value = settings[spec.key]
    if spec.kind == "toggle" then
        entry.control:Set(value and true or false)
    elseif spec.kind == "range" then
        entry.control:Set(value or spec.min)
    else
        entry.control:Set(value or "")
    end
    local active = true
    if spec.requires and not spec.requires(settings) then active = false end
    if spec.available and not spec.available() then active = false end
    entry.frame:SetAlpha(active and 1 or 0.45)
    entry.control.frame:EnableMouse(active)
end

function Voice:AddRows(card, rows, shape)
    for _, row in ipairs(rows) do
        local spec = { kind = "toggle", key = row.key, label = row.label, hint = row.hint, inline = shape.inline, sub = shape.sub, requires = shape.requires }
        if row.requires then spec.requires = Gate(row.requires) end
        if shape.after and row.preview then
            local preview = row.preview
            spec.after = function(value) if value then self.spec.preview(preview) end end
        end
        self:AddSetting(card, spec)
    end
end

function Voice:BuildPresets(parent)
    self.presetButtons = {}
    for _, preset in ipairs(Model.PRESETS) do
        local button = Kit.MakeButton(parent, preset.name, function() self:ApplyPreset(preset) end)
        local frame = button.frame
        frame:HookScript("OnEnter", function() ShowTip(frame, preset.name, preset.note:gsub("^%l", string.upper) .. ". Overwrites every spell toggle, undoable once.") end)
        frame:HookScript("OnLeave", HideTip)
        self.presetButtons[#self.presetButtons + 1] = button
    end
    self.undoButton = Kit.MakeButton(parent, "Undo", function() self:UndoPreset() end)
    self.presetButtons[#self.presetButtons + 1] = self.undoButton
end

function Voice:ApplyPreset(preset)
    local settings = self:Db()
    local snapshot = Model.Snapshot(settings, self.model)
    self.undo = snapshot
    self.lastPreset = preset.name
    Model.ApplyPreset(settings, self.model, preset.id)
    self.spec.print("Preset applied: " .. preset.name)
    self:Refresh()
    self:FlashChanged(Model.ChangedSpells(settings, self.model, snapshot))
end

function Voice:UndoPreset()
    if not self.undo then return end
    local settings = self:Db()
    local before = Model.Snapshot(settings, self.model)
    Model.Restore(settings, self.undo)
    self.undo = nil
    self.lastPreset = nil
    self.spec.print("Preset undone")
    self:Refresh()
    self:FlashChanged(Model.ChangedSpells(settings, self.model, before))
end

function Voice:FlashChanged(changed)
    for index = 1, self.activeRows do
        local row = self.rowPool[index]
        if changed[row.spell.id] then FX.Flash(row.flash) end
    end
end

function Voice:BuildGlobal(parent)
    self.heading = NewHeading(parent, "GLOBAL")
    self.jump = NewLink(parent, "Jump to spells", function() self.spellsView:ScrollTo(self.spellsY or 0) end)
    self:BuildPresets(parent)

    self.silenceCard = NewCard(parent, "Silence whole categories")
    self:AddRows(self.silenceCard, Model.SILENCE_ROWS, {})
    self.arenaCard = NewCard(parent, "Arena extras")
    self:AddRows(self.arenaCard, Model.ARENA_ROWS, { inline = true, after = true })
    self.interruptCard = NewCard(parent, "Interrupts")
    self:AddRows(self.interruptCard, Model.INTERRUPT_ROWS, { inline = true })

    self.moreDivider = NewDivider(parent, "MORE OPTIONS")
    self.lossCard = NewCard(parent, "Loss of control voice")
    local master = Model.LOSS_MASTER
    self:AddSetting(self.lossCard, { kind = "toggle", key = master.key, label = master.label, hint = master.hint, inline = true })
    self:AddRows(self.lossCard, Model.LOSS_ROWS, { sub = true, requires = Gate(master.key) })
    self.detailCard = NewCard(parent, "Interrupt details")
    local minimum = Model.INTERRUPT_MIN
    self:AddSetting(self.detailCard, { kind = "range", key = minimum.key, label = minimum.label, hint = minimum.hint, inline = true, min = minimum.min, max = minimum.max, step = minimum.step, unit = minimum.unit })
    self:AddSetting(self.detailCard, { kind = "toggle", key = Model.INTERRUPT_PETS.key, label = Model.INTERRUPT_PETS.label })
    self.engineCard = NewCard(parent, "Engine")
    local engine = Model.ENGINE_ROW
    self:AddSetting(self.engineCard, { kind = "toggle", key = engine.key, label = engine.label, hint = engine.hint, inline = true, available = self.spec.engineSupported })
end

local function NewPill(row)
    local button = CreateFrame("Button", nil, row.frame)
    button:SetHeight(PILL_HEIGHT)
    local fill = Paint(button, COLOR.line)
    fill:SetAllPoints(button)
    local label = Text(button, 11.5, COLOR.muted)
    label:SetPoint("LEFT", button, "LEFT", 8, 0)
    local play = CreateFrame("Button", nil, button)
    play:SetSize(16, PILL_HEIGHT)
    play:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    local glyph = play:CreateTexture(nil, "ARTWORK")
    glyph:SetSize(14, 14)
    glyph:SetPoint("CENTER", play, "CENTER", 0, 0)
    glyph:SetTexture(PLAY_ICON)
    play:SetAlpha(0)
    local pill = { frame = button, fill = fill, label = label, play = play }
    local function reveal() play:SetAlpha(1) end
    local function conceal()
        if not button:IsMouseOver() then play:SetAlpha(0) end
    end
    button:SetScript("OnEnter", function()
        reveal()
        if pill.event then
            local note = pill.muted and "\nSilenced by a category toggle." or ""
            ShowTip(button, pill.event, (EVENT_HELP[pill.event] or pill.event) .. "\nSound: " .. table.concat(Model.SoundKeys(pill.event, pill.keys), ", ") .. note)
        end
    end)
    button:SetScript("OnLeave", function()
        conceal()
        HideTip()
    end)
    play:SetScript("OnEnter", reveal)
    play:SetScript("OnLeave", conceal)
    button:SetScript("OnMouseDown", function()
        if not FX.Enabled() then return end
        fill:SetAlpha(0.75)
        label:SetPoint("LEFT", button, "LEFT", 8, -1)
    end)
    button:SetScript("OnMouseUp", function()
        fill:SetAlpha(1)
        label:SetPoint("LEFT", button, "LEFT", 8, 0)
    end)
    return pill
end

function Voice:Silenced(event)
    return self:Db()[Model.SILENCE_FLAG[event]] and true or false
end

function Voice:PlayPill(pill)
    self.spec.play(self:Db().sapath .. Model.SoundKeys(pill.event, pill.keys)[1] .. ".mp3")
end

function Voice:TogglePill(row, pill)
    if self:Silenced(pill.event) then return end
    local settings = self:Db()
    local value = not Model.ChipOn(settings, row.spell, pill.event)
    Model.SetChip(settings, row.spell, pill.event, value)
    if value then self:PlayPill(pill) end
    self:Refresh()
    FX.Flash(row.flash)
end

function Voice:AcquireRow(index)
    local row = self.rowPool[index]
    if row then return row end
    local page = self
    local frame = CreateFrame("Frame", nil, self.listHolder)
    frame:EnableMouse(true)
    local tint = Paint(frame, COLOR.line, 0.4)
    tint:SetAllPoints(frame)
    tint:Hide()
    local flash = Paint(frame, COLOR.accent, 0.3, "BORDER")
    flash:SetAllPoints(frame)
    flash:Hide()
    local rule = Paint(frame, COLOR.line, 0.55)
    rule:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    row = { frame = frame, flash = flash, pills = {} }
    local tile = CreateFrame("Button", nil, frame)
    tile:SetSize(24, 24)
    tile:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -5)
    row.icon = tile:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints(tile)
    tile:SetScript("OnEnter", function()
        local spell = row.spell
        if not spell then return end
        GameTooltip:SetOwner(tile, "ANCHOR_RIGHT")
        local link = SA_COMPAT.GetSpellLink and SA_COMPAT.GetSpellLink(spell.iconSpellID)
        if link then
            GameTooltip:SetHyperlink(link)
        else
            GameTooltip:SetText(spell.name, 1, 1, 1)
        end
        GameTooltip:AddLine("Sound: " .. table.concat(spell.keys, ", "), 0.6, 0.65, 0.7, true)
        GameTooltip:Show()
    end)
    tile:SetScript("OnLeave", HideTip)
    row.name = Text(frame, 12.5, COLOR.text)
    row.name:SetWidth(NAME_WIDTH)
    row.name:SetPoint("LEFT", frame, "TOPLEFT", NAME_X, -17)
    FX.Hover(frame, tint)
    self.rowPool[index] = row
    return row
end

function Voice:BindRow(row, spell)
    row.spell = spell
    row.icon:SetTexture(SpellIcon(spell.iconSpellID))
    row.name:SetText(spell.name)
    row.count = #spell.events
    for index, event in ipairs(spell.events) do
        local pill = row.pills[index]
        if not pill then
            pill = NewPill(row)
            pill.frame:SetScript("OnClick", function() self:TogglePill(row, pill) end)
            pill.play:SetScript("OnClick", function() self:PlayPill(pill) end)
            row.pills[index] = pill
        end
        pill.event = event
        pill.keys = spell.eventKeys[event]
        pill.label:SetText(event)
        pill.frame:SetWidth(pill.label:GetStringWidth() + 32)
        pill.frame:Show()
    end
    for index = #spell.events + 1, #row.pills do row.pills[index].frame:Hide() end
end

function Voice:LayoutRows(listWidth)
    local available = listWidth - NAME_X - NAME_WIDTH - 14
    local y = 0
    for index = 1, self.activeRows do
        local row = self.rowPool[index]
        local x, line = 0, 0
        for position = 1, row.count do
            local pill = row.pills[position]
            local size = pill.frame:GetWidth()
            if x > 0 and x + size > available then
                x = 0
                line = line + 1
            end
            pill.frame:ClearAllPoints()
            pill.frame:SetPoint("TOPLEFT", row.frame, "TOPLEFT", NAME_X + NAME_WIDTH + 8 + x, -(6 + line * PILL_STEP))
            x = x + size + 6
        end
        local height = math.max(SPELL_ROW_MIN, 8 + (line + 1) * PILL_STEP)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", self.listHolder, "TOPLEFT", 0, -y)
        row.frame:SetPoint("TOPRIGHT", self.listHolder, "TOPRIGHT", 0, -y)
        row.frame:SetHeight(height)
        y = y + height
    end
    return y
end

function Voice:ShowList()
    local query = self.query
    local list = Model.Filter(self.model, self.class, query)
    self.hiddenResults = 0
    if #list > MAX_RESULTS then
        self.hiddenResults = #list - MAX_RESULTS
        local trimmed = {}
        for index = 1, MAX_RESULTS do trimmed[index] = list[index] end
        list = trimmed
    end
    self.visible = list
    for index, spell in ipairs(list) do
        local row = self:AcquireRow(index)
        self:BindRow(row, spell)
        row.frame:Show()
    end
    for index = #list + 1, #self.rowPool do self.rowPool[index].frame:Hide() end
    self.activeRows = #list
    self:LayoutSpells()
    self:Refresh()
end

function Voice:SelectClass(name)
    self.class = name
    self.query = ""
    self.search:SetText("")
    self.spellsView:ScrollTo(self.spellsY or 0)
    self:ShowList()
end

function Voice:BuildRail(parent)
    self.railItems = {}
    for index, group in ipairs(self.model.classes) do
        local name = group.name
        local frame = CreateFrame("Button", nil, parent)
        frame:SetSize(RAIL_WIDTH, RAIL_ROW)
        local tint = Paint(frame, COLOR.line, 0.5)
        tint:SetAllPoints(frame)
        tint:Hide()
        local selected = Paint(frame, COLOR.line, 1)
        selected:SetAllPoints(frame)
        selected:Hide()
        local bar = Paint(frame, COLOR.accent, 1, "ARTWORK")
        bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        bar:SetWidth(3)
        bar:Hide()
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", frame, "LEFT", 10, 0)
        icon:SetTexture(CLASS_ICON[name] or QUESTION)
        local label = Text(frame, 12.5, COLOR.text)
        label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        label:SetText(name)
        local count = Text(frame, 11, COLOR.muted, "RIGHT")
        count:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
        frame:SetScript("OnClick", function() self:SelectClass(name) end)
        FX.Hover(frame, tint)
        self.railItems[index] = { frame = frame, name = name, selected = selected, bar = bar, count = count, label = label }
    end
end

function Voice:BuildListHead(parent)
    local head = CreateFrame("Frame", nil, parent)
    head:SetHeight(LIST_HEAD)
    self.listHead = head
    self.listTitle = Text(head, 15, COLOR.text)
    self.listTitle:SetPoint("LEFT", head, "LEFT", 4, 0)
    self.listCount = Text(head, 11.5, COLOR.muted)
    self.listCount:SetPoint("LEFT", self.listTitle, "RIGHT", 10, 0)

    local allOff = Kit.MakeButton(head, "All off", function() self:SetVisible(false) end)
    allOff.frame:SetWidth(60)
    allOff.frame:SetPoint("RIGHT", head, "RIGHT", 0, 0)
    local allOn = Kit.MakeButton(head, "All on", function() self:SetVisible(true) end)
    allOn.frame:SetWidth(60)
    allOn.frame:SetPoint("RIGHT", allOff.frame, "LEFT", -6, 0)
    self.allButtons = { allOn, allOff }

    local box = CreateFrame("EditBox", nil, head)
    box:SetAutoFocus(false)
    box:SetFont(Kit.FONT, 12, "")
    box:SetTextInsets(6, 6, 3, 3)
    box:SetSize(150, 22)
    box:SetPoint("RIGHT", allOn.frame, "LEFT", -8, 0)
    local fill = Paint(box, COLOR.line)
    fill:SetAllPoints(box)
    local placeholder = Text(box, 12, COLOR.muted)
    placeholder:SetPoint("LEFT", box, "LEFT", 6, 0)
    placeholder:SetText("Search spell or sound")
    local function sync()
        placeholder:SetShown(box:GetText() == "" and not box:HasFocus())
    end
    box:SetScript("OnTextChanged", function(_, userInput)
        sync()
        if not userInput then return end
        self.query = Model.Normalize(box:GetText())
        self:ShowList()
    end)
    box:SetScript("OnEditFocusGained", sync)
    box:SetScript("OnEditFocusLost", sync)
    box:SetScript("OnEscapePressed", function(frame) frame:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(frame) frame:ClearFocus() end)
    self.search = box

    self.listHolder = CreateFrame("Frame", nil, parent)
    self.listNote = Text(parent, 11.5, COLOR.muted)
end

function Voice:SetVisible(value)
    Model.SetAll(self:Db(), self.visible, value)
    self:Refresh()
    local changed = {}
    for _, spell in ipairs(self.visible) do changed[spell.id] = true end
    self:FlashChanged(changed)
end

function Voice:BuildSpells()
    local view = NewView(self.body)
    self.spellsView = view
    local child = view.child
    self:BuildGlobal(child)
    self.spellsHeading = NewHeading(child, "SPELLS")
    self.backLink = NewLink(child, "Back to global", function() view:ScrollTo(0) end)
    self:BuildRail(child)
    self:BuildListHead(child)
    view.onWidth = function(width)
        self.spellsWidth = width
        self:LayoutSpells()
    end
end

function Voice:LayoutSpells()
    local width = self.spellsWidth
    if not width then return end
    local child = self.spellsView.child
    local half = math.floor((width - GAP) / 2)
    local y = 0
    self.heading:ClearAllPoints()
    self.heading:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -y)
    self.jump.frame:ClearAllPoints()
    self.jump.frame:SetPoint("TOPLEFT", child, "TOPLEFT", width - self.jump.frame:GetWidth(), -y)
    y = y + 22
    y = Flow(child, self.presetButtons, width, 6, 0, y, 28) + 4

    local left = PlaceCard(self.silenceCard, child, 0, y, half)
    local right = PlaceCard(self.arenaCard, child, half + GAP, y, half)
    right = right + GAP + PlaceCard(self.interruptCard, child, half + GAP, y + right + GAP, half)
    y = y + math.max(left, right) + GAP

    y = PlaceDivider(self.moreDivider, child, width, y)
    left = PlaceCard(self.lossCard, child, 0, y, half)
    right = PlaceCard(self.detailCard, child, half + GAP, y, half)
    right = right + GAP + PlaceCard(self.engineCard, child, half + GAP, y + right + GAP, half)
    y = y + math.max(left, right) + 22

    self.spellsY = y
    self.spellsHeading:ClearAllPoints()
    self.spellsHeading:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -y)
    self.backLink.frame:ClearAllPoints()
    self.backLink.frame:SetPoint("TOPLEFT", child, "TOPLEFT", width - self.backLink.frame:GetWidth(), -y)
    y = y + 22

    local railTop = y
    for index, item in ipairs(self.railItems) do
        item.frame:ClearAllPoints()
        item.frame:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(railTop + (index - 1) * RAIL_ROW))
    end
    local railHeight = #self.railItems * RAIL_ROW

    local listX = RAIL_WIDTH + GAP
    local listWidth = math.max(200, width - listX)
    self.listHead:ClearAllPoints()
    self.listHead:SetPoint("TOPLEFT", child, "TOPLEFT", listX, -y)
    self.listHead:SetWidth(listWidth)
    self.listHolder:ClearAllPoints()
    self.listHolder:SetPoint("TOPLEFT", child, "TOPLEFT", listX, -(y + LIST_HEAD))
    self.listHolder:SetWidth(listWidth)
    local rowsHeight = self:LayoutRows(listWidth)
    self.listHolder:SetHeight(math.max(1, rowsHeight))
    local listHeight = LIST_HEAD + rowsHeight
    self.listNote:ClearAllPoints()
    self.listNote:SetPoint("TOPLEFT", child, "TOPLEFT", listX + 6, -(y + listHeight + 8))
    local note = ""
    if self.activeRows == 0 then
        note = self.query ~= "" and ("No spell matches \"" .. self.query .. "\".") or "No spells."
    elseif self.hiddenResults > 0 then
        note = self.hiddenResults .. " more match. Narrow the search to see them."
    end
    self.listNote:SetText(note)
    if note ~= "" then listHeight = listHeight + 28 end
    self.spellsView:SetContentHeight(y + math.max(railHeight, listHeight) + 16)
end

function Voice:BuildChat()
    local view = NewView(self.body)
    self.chatView = view
    local child = view.child
    self.chatSettings = {}
    self.whereHeading = NewHeading(child, "WHERE")

    self.channelCard = NewCard(child, "Chat channels to alert in")
    self.channelChips = {}
    for _, channel in ipairs(Model.CHANNELS) do
        local key = channel.key
        local chip = NewChip(self.channelCard.frame, channel.label, function()
            local groups = self:Db().chatgroups
            groups[key] = not groups[key]
            self:Refresh()
        end)
        chip.key = key
        self.channelChips[#self.channelChips + 1] = chip
    end
    self.channelCard.content = function(card, width, y)
        return Flow(card.frame, self.channelChips, width - 24, 6, 12, y + 2, 28)
    end

    self.filterCard = NewCard(child, "Filter")
    local target = Model.CHAT_TARGET_ONLY
    self:AddSetting(self.filterCard, { kind = "toggle", key = target.key, label = target.label, hint = target.hint, inline = true })
    self:AddSetting(self.filterCard, { kind = "toggle", key = "chatalerts", label = "Silence all chat alerts", hint = "Same switch as in Silence whole categories.", inline = true })

    self.announceHeading = NewHeading(child, "WHAT GETS ANNOUNCED")
    self.eventsCard = NewCard(child, "Announcements", 2)
    for _, row in ipairs(Model.CHAT_EVENTS) do
        local spell = row.spell
        self:AddSetting(self.eventsCard, {
            kind = "toggle", key = row.key, label = row.label,
            iconFor = function() return spell and SpellIcon(spell) or CHAT_ICON end,
        })
    end

    self.chatDivider = NewDivider(child, "MORE OPTIONS")
    self.targetCard = NewCard(child, "Stealth and vanish")
    self:AddRows(self.targetCard, Model.CHAT_FILTERS, {})
    self.previewCard = NewCard(child, "What your channels will read")
    self.previewText = Text(self.previewCard.frame, 11.5, COLOR.text)
    self.previewText:SetPoint("TOPLEFT", self.previewCard.frame, "TOPLEFT", 12, -CARD_TITLE)
    if self.previewText.SetWordWrap then self.previewText:SetWordWrap(true) end
    self.previewText:SetJustifyV("TOP")
    self.previewCard.content = function(card, width, y)
        self.previewText:SetWidth(math.max(40, width - 24))
        return y + math.max(16, self.previewText:GetStringHeight()) + 4
    end
    self.textsCard = NewCard(child, "Message text")
    for _, row in ipairs(Model.CHAT_TEXTS) do
        local spec = { kind = "text", key = row.key, label = row.label, hint = row.hint }
        if row.requires then spec.requires = Gate(row.requires) end
        self:AddSetting(self.textsCard, spec)
    end

    view.onWidth = function(width)
        self.chatWidth = width
        self:LayoutChat()
    end
end

function Voice:LayoutChat()
    local width = self.chatWidth
    if not width then return end
    local child = self.chatView.child
    local half = math.floor((width - GAP) / 2)
    local y = 0
    self.whereHeading:ClearAllPoints()
    self.whereHeading:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -y)
    y = y + 22
    local left = PlaceCard(self.channelCard, child, 0, y, half)
    local right = PlaceCard(self.filterCard, child, half + GAP, y, half)
    y = y + math.max(left, right) + 18

    self.announceHeading:ClearAllPoints()
    self.announceHeading:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -y)
    y = y + 22
    y = y + PlaceCard(self.eventsCard, child, 0, y, width) + GAP

    y = PlaceDivider(self.chatDivider, child, width, y)
    left = PlaceCard(self.targetCard, child, 0, y, half)
    right = PlaceCard(self.previewCard, child, half + GAP, y, half)
    y = y + math.max(left, right) + GAP
    y = y + PlaceCard(self.textsCard, child, 0, y, width) + 16
    self.chatView:SetContentHeight(y)
end

function Voice:BuildHeader()
    local frame = self.frame
    self.title = Text(frame, 20, COLOR.accent)
    self.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -2)
    self.title:SetText("Voice Alerts")
    self.summary = Text(frame, 11.5, COLOR.muted)
    self.summary:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
    self.summary:SetPoint("RIGHT", frame, "RIGHT", -150, 0)

    local reset = CreateFrame("Button", nil, frame)
    reset:SetSize(150, 16)
    reset:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -8)
    local resetLabel = Text(reset, 11, COLOR.muted, "RIGHT")
    resetLabel:SetAllPoints(reset)
    resetLabel:SetText("Reset to defaults")
    local armed = false
    reset:SetScript("OnClick", function()
        if not armed then
            armed = true
            resetLabel:SetText("Click again to reset")
            Tint(resetLabel, COLOR.accent)
            if C_Timer and C_Timer.After then
                C_Timer.After(ARM_SECONDS, function()
                    if armed then
                        armed = false
                        resetLabel:SetText("Reset to defaults")
                        Tint(resetLabel, COLOR.muted)
                    end
                end)
            end
            return
        end
        armed = false
        resetLabel:SetText("Reset to defaults")
        Tint(resetLabel, COLOR.muted)
        self:Reset()
    end)
    reset:SetScript("OnEnter", function() Tint(resetLabel, COLOR.accent) end)
    reset:SetScript("OnLeave", function() if not armed then Tint(resetLabel, COLOR.muted) end end)

    self.tabs = {}
    local x = 0
    for _, entry in ipairs(TABS) do
        local key, name = entry[1], entry[2]
        local button = CreateFrame("Button", nil, frame)
        local hover = Paint(button, COLOR.card)
        hover:SetAllPoints(button)
        hover:Hide()
        local label = Text(button, 13, COLOR.muted, "CENTER")
        label:SetPoint("CENTER", button, "CENTER", 0, 1)
        label:SetText(name)
        local underline = Paint(button, COLOR.accent, 1, "ARTWORK")
        underline:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        underline:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        underline:SetHeight(2)
        underline:Hide()
        button:SetSize(label:GetStringWidth() + 32, 28)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -48)
        x = x + button:GetWidth() + 2
        button:SetScript("OnClick", function() self:ShowTab(key, true) end)
        FX.Hover(button, hover)
        self.tabs[key] = { button = button, label = label, underline = underline }
    end
    local rule = Paint(frame, COLOR.line)
    rule:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(HEADER_HEIGHT - 3))
    rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -(HEADER_HEIGHT - 3))
    rule:SetHeight(1)
end

function Voice:ShowTab(key, animate)
    self.tab = key
    for name, tab in pairs(self.tabs) do
        local on = name == key
        Tint(tab.label, on and COLOR.accent or COLOR.muted)
        tab.underline:SetShown(on)
    end
    local view = key == "chat" and self.chatView or self.spellsView
    local other = key == "chat" and self.spellsView or self.chatView
    other.frame:Hide()
    view.frame:ClearAllPoints()
    view.frame:SetAllPoints(self.body)
    view.frame:Show()
    local width = view.scroll:GetWidth()
    if width and width > 12 then
        view.child:SetWidth(width - 12)
        if view.onWidth then view.onWidth(width - 12) end
    end
    if animate then FX.SlideIn(view.frame, self.body) end
    self:Refresh()
    view:UpdateScroll()
end

function Voice:Reset()
    Model.Reset(self:Db(), self.spec.defaults(), self.model)
    self.undo = nil
    self.lastPreset = nil
    self:Refresh()
end

local function SyncPill(row, pill, settings, silenced)
    local on = Model.ChipOn(settings, row.spell, pill.event)
    pill.muted = silenced[pill.event]
    Tint(pill.fill, on and COLOR.on or COLOR.line, on and 0.28 or 0.7)
    Tint(pill.label, on and COLOR.on or COLOR.muted)
    pill.frame:SetAlpha(pill.muted and 0.35 or 1)
end

function Voice:Refresh()
    local settings = self:Db()
    if not settings then return end
    local tally = Model.Tally(settings, self.model)
    self.tally = tally

    for _, entry in ipairs(self.settings) do SyncSetting(entry, settings) end

    local silenced = {}
    for _, event in ipairs(Model.EVENTS) do silenced[event] = settings[Model.SILENCE_FLAG[event]] and true or false end
    for index = 1, self.activeRows do
        local row = self.rowPool[index]
        for position = 1, row.count do SyncPill(row, row.pills[position], settings, silenced) end
    end

    local groups = settings.chatgroups or {}
    for _, chip in ipairs(self.channelChips) do
        chip:Set(groups[chip.key] and true or false, chip.key == "NONE" or not groups.NONE)
    end

    for _, item in ipairs(self.railItems) do
        local counts = tally.byClass[item.name]
        item.count:SetText(counts.on .. "/" .. counts.total)
        local selected = self.query == "" and item.name == self.class
        item.selected:SetShown(selected)
        item.bar:SetShown(selected)
        Tint(item.label, selected and COLOR.accent or COLOR.text)
    end

    local searching = self.query ~= ""
    local on, total = Model.Count(settings, self.visible or {})
    self.listTitle:SetText(searching and "Search results" or self.class)
    local color = searching and COLOR.text or (CLASS_COLOR[self.class] or COLOR.text)
    Tint(self.listTitle, color)
    self.listCount:SetText(on .. " of " .. total .. " on")
    local hasRows = self.activeRows > 0
    for _, button in ipairs(self.allButtons) do
        button.frame:SetAlpha(hasRows and 1 or 0.4)
        button.frame:EnableMouse(hasRows)
    end

    local undoLabel = self.undo and self.lastPreset and ("Undo " .. self.lastPreset) or "Undo"
    self.undoButton.label:SetText(undoLabel)
    self.undoButton.frame:SetWidth(math.max(70, self.undoButton.label:GetStringWidth() + 24))
    self.undoButton.frame:SetAlpha(self.undo and 1 or 0.4)
    self.undoButton.frame:EnableMouse(self.undo and true or false)

    if self.tab == "chat" then
        local items = {}
        for _, channel in ipairs(Model.CHANNELS) do
            if channel.key ~= "NONE" then items[#items + 1] = { channel.label, groups[channel.key] } end
        end
        local count, all = Model.ChatEventCount(settings)
        self.summary:SetText(Rail.Status("Sending to", items, groups.NONE and "nothing, chat alerts are off" or "your own chat only") .. "  |cff96a0b2" .. count .. " of " .. all .. " events announced|r")
        local lines = {}
        for _, line in ipairs(Model.ChatPreview(settings, Rail.ExpandChat)) do
            lines[#lines + 1] = "|cff96a0b2" .. line[1] .. ":|r " .. line[2]
        end
        self.previewText:SetText(#lines > 0 and table.concat(lines, "\n") or "|cff96a0b2Every message template is empty.|r")
        self:LayoutChat()
    else
        local silencedCount = Model.SilencedCount(settings)
        local text = "|cff3ddc97" .. tally.on .. "|r of " .. tally.total .. " alerts on"
        if silencedCount > 0 then
            text = text .. "  |cffff5d5d" .. silencedCount .. (silencedCount == 1 and " category" or " categories") .. " silenced|r"
        end
        self.summary:SetText(text)
    end
end

local function BuildPage(spec)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    local page = { frame = frame, spec = spec, settings = {}, rowPool = {}, activeRows = 0, query = "" }
    for name, method in pairs(Voice) do page[name] = method end
    page.model = Model.Shared(spec.spellList(), spec.spellMeta())
    page.class = page.model.classes[1] and page.model.classes[1].name or "Other"
    page.visible = {}

    page:BuildHeader()
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -HEADER_HEIGHT)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    page.body = body
    page:BuildSpells()
    page:BuildChat()
    page.tab = "spells"
    page:ShowTab("spells", false)
    page:ShowList()
    return page
end

local cache = setmetatable({}, { __mode = "k" })

local function GetPage(spec)
    local page = cache[spec]
    if not page then
        page = BuildPage(spec)
        cache[spec] = page
    end
    return page
end

local WidgetMethods = {}

function WidgetMethods:OnAcquire()
    self.frame:SetHeight(Kit.PAGE_HEIGHT)
    self.frame:Show()
end

function WidgetMethods:OnRelease()
    local page = self.page
    if page then
        HideTip()
        page.frame:Hide()
        page.frame:SetParent(UIParent)
    end
    self.page = nil
end

function WidgetMethods:SetText() end
function WidgetMethods:SetFontObject() end

function WidgetMethods:SetCustomData(spec)
    if type(spec) ~= "table" or not spec.db then return end
    local page = GetPage(spec)
    self.page = page
    page.frame:SetParent(self.frame)
    page.frame:ClearAllPoints()
    page.frame:SetAllPoints(self.frame)
    page.frame:Show()
    page:Refresh()
    FX.SlideIn(page.frame, self.frame)
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

SoundAlerter.VoicePage = { Get = GetPage }

do
local PAGE = "SoundAlerterVoicePage"

local PREVIEWS = {
    arenaClass = function()
        SoundAlerter:PlayVoice(SoundAlerter.db1.profile.sapath .. "paladin.mp3")
        SoundAlerter:ScheduleTimer("PlayTrinket", 0.4)
    end,
    drinking = function()
        SoundAlerter:PlayVoice(SoundAlerter.db1.profile.sapath .. "drinking.mp3")
    end,
}

function SoundAlerter:BuildVoiceAlertOptions()
    local spec = self.voiceSpec or {
        db = function() return SoundAlerter.db1 and SoundAlerter.db1.profile end,
        defaults = function() return dbDefaults.profile end,
        spellList = function() return SoundAlerter.spellList or SoundAlerterSpells end,
        spellMeta = function() return SoundAlerterSpellMeta end,
        play = function(path) SoundAlerter:PlayVoice(path) end,
        print = function(text) SoundAlerter:Print(text) end,
        preview = function(kind)
            local play = PREVIEWS[kind]
            if play then play() end
        end,
        engineSupported = function() return SoundAlerter:EngineAuraSoundSupported() end,
    }
    self.voiceSpec = spec
    return {
        type = 'group',
        name = "Voice Alerts",
        icon = "Interface\\Icons\\INV_Misc_Bell_01",
        desc = "Choose which enemy and friendly spells trigger a voice alert, silence whole categories, and set up chat announcements.",
        order = 2,
        args = {
            page = {
                type = 'description',
                name = "Voice Alerts could not draw its page.",
                dialogControl = PAGE,
                arg = spec,
                order = 1,
            },
        },
    }
end
end
