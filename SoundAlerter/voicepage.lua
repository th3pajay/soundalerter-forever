local SoundAlerter = SoundAlerter
local AceGUI = LibStub("AceGUI-3.0")
local Page = SoundAlerter.Page
local Kit = Page.Kit
local Model = SA_VoiceModel
local Rail = SA_OptionsRail
local FX = SA_MenuFX

local COLOR, Paint, Text = Kit.COLOR, Kit.Paint, Kit.Text

local WIDGET = "SoundAlerterVoicePage"
local HEADER_HEIGHT = 80
local GAP = 12
local RAIL_WIDTH = 150
local RAIL_ROW = 26
local ROW_PLAIN = 28
local ROW_HINT = 38
local ROW_TEXT = 48
local PILL_HEIGHT = 20
local PILL_STEP = 24
local LIST_HEAD = 36
local ROW_MIN = 30
local NAME_WIDTH = 210
local NAME_NARROW = 150
local BOX_SIZE = 14
local FILTER_STEP = 28
local CHIP_STEP = 28
local DRAWER_HEAD = 36
local ARM_SECONDS = 4
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local CHAT_ICON = "Interface\\Icons\\INV_Letter_15"
local PLAY_ICON = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
local CHECK_ICON = "Interface\\Buttons\\UI-CheckBox-Check"

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

function Voice:Changed()
    if self.spec.changed then self.spec.changed() end
end

function Voice:Change(entry, value)
    local spec = entry.spec
    local settings = self:Db()
    if spec.kind == "text" and settings[spec.key] == value then return end
    if spec.invert then value = not value end
    settings[spec.key] = value
    if spec.after then spec.after(value, settings) end
    if spec.chat then
        self:RefreshChat()
    else
        self:Changed()
        self:Refresh()
    end
    FX.Flash(entry.flash)
end

local function SyncSetting(entry, settings)
    local spec = entry.spec
    local value = settings[spec.key]
    if spec.invert then value = not value end
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
        local chip = NewChip(parent, preset.name, function() self:ApplyPreset(preset) end)
        local frame = chip.frame
        frame:HookScript("OnEnter", function() ShowTip(frame, preset.name, preset.note:gsub("^%l", string.upper) .. ". Overwrites every spell switch, undoable once.") end)
        frame:HookScript("OnLeave", HideTip)
        self.presetButtons[#self.presetButtons + 1] = chip
    end
    self.undoButton = NewChip(parent, "Undo", function() self:UndoPreset() end)
end

function Voice:ApplyPreset(preset)
    local settings = self:Db()
    self.undo = Model.Snapshot(settings, self.model)
    self.lastPreset = preset.name
    Model.ApplyPreset(settings, self.model, preset.id)
    self.spec.print("Preset applied: " .. preset.name)
    self:Changed()
    self:SpellsChanged(true)
    self:FlashChanged(Model.ChangedSpells(settings, self.model, self.undo))
end

function Voice:UndoPreset()
    if not self.undo then return end
    local settings = self:Db()
    local before = Model.Snapshot(settings, self.model)
    Model.Restore(settings, self.undo)
    self.undo = nil
    self.lastPreset = nil
    self.spec.print("Preset undone")
    self:Changed()
    self:SpellsChanged(true)
    self:FlashChanged(Model.ChangedSpells(settings, self.model, before))
end

local function NewPill(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(PILL_HEIGHT)
    local fill = Paint(button, COLOR.line)
    fill:SetAllPoints(button)
    local mark = Paint(button, COLOR.on, 1, "ARTWORK")
    mark:SetSize(6, 6)
    mark:SetPoint("LEFT", button, "LEFT", 6, 0)
    local label = Text(button, 11.5, COLOR.muted)
    label:SetPoint("LEFT", button, "LEFT", 16, 0)
    local play = CreateFrame("Button", nil, button)
    play:SetSize(16, PILL_HEIGHT)
    play:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    local glyph = play:CreateTexture(nil, "ARTWORK")
    glyph:SetSize(14, 14)
    glyph:SetPoint("CENTER", play, "CENTER", 0, 0)
    glyph:SetTexture(PLAY_ICON)
    play:SetAlpha(0)
    local pill = { frame = button, fill = fill, label = label, play = play, mark = mark }
    local function reveal() play:SetAlpha(1) end
    local function conceal()
        if not button:IsMouseOver() then play:SetAlpha(0) end
    end
    button:SetScript("OnEnter", function()
        reveal()
        if pill.event then
            local note = pill.muted and "\nThis kind of alert is switched off above." or ""
            local where = pill.availability and Model.AVAILABILITY[pill.availability].label or ""
            ShowTip(button, Model.EventLabel(pill.event), Model.EVENT_HELP[pill.event] .. "\nSound: " .. table.concat(Model.SoundKeys(pill.event, pill.keys), ", ") .. note .. "\n" .. where)
        end
    end)
    button:SetScript("OnLeave", function()
        conceal()
        HideTip()
    end)
    play:SetScript("OnEnter", reveal)
    play:SetScript("OnLeave", conceal)
    return pill
end

function Voice:Silenced(event)
    return self:Db()[Model.SILENCE_FLAG[event]] and true or false
end

function Voice:SilencedSet()
    local settings = self:Db()
    local silenced = self.silenced
    for _, event in ipairs(Model.EVENTS) do silenced[event] = settings[Model.SILENCE_FLAG[event]] and true or false end
    return silenced
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
    self:Changed()
    self:RowChanged(row)
end

function Voice:ToggleRow(row)
    local settings = self:Db()
    local spell = row.spell
    local value, event = Model.ToggleTile(settings, spell, self.filter, self:SilencedSet())
    if value == nil then return end
    if value then self.spec.play(settings.sapath .. Model.SoundKeys(event, spell.eventKeys[event])[1] .. ".mp3") end
    self:Changed()
    self:RowChanged(row)
    FX.Flash(row.flash)
end

local function RowTip(row)
    local spell = row.spell
    if not spell then return end
    GameTooltip:SetOwner(row.frame, "ANCHOR_RIGHT")
    local link = SA_COMPAT.GetSpellLink and SA_COMPAT.GetSpellLink(spell.iconSpellID)
    if link then
        GameTooltip:SetHyperlink(link)
    else
        GameTooltip:SetText(spell.name, 1, 1, 1)
    end
    local labels = {}
    for index, event in ipairs(spell.events) do labels[index] = Model.EventLabel(event) end
    GameTooltip:AddLine("Announces: " .. table.concat(labels, ", "), 1, 0.82, 0, true)
    GameTooltip:AddLine("Sound: " .. table.concat(spell.keys, ", "), 0.6, 0.65, 0.7, true)
    GameTooltip:AddLine("Click to switch the events shown on or off.", 0.6, 0.65, 0.7, true)
    GameTooltip:Show()
end

function Voice:AcquireRow(index)
    local row = self.rowPool[index]
    if row then return row end
    local frame = CreateFrame("Button", nil, self.listHolder)
    frame:SetHeight(ROW_MIN)
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
    local box = Paint(frame, COLOR.line, 1, "ARTWORK")
    box:SetSize(BOX_SIZE, BOX_SIZE)
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -7)
    local partial = Paint(frame, COLOR.on, 1, "OVERLAY")
    partial:SetSize(BOX_SIZE / 2, BOX_SIZE)
    partial:SetPoint("LEFT", box, "LEFT", 0, 0)
    partial:Hide()
    local check = frame:CreateTexture(nil, "OVERLAY")
    check:SetSize(BOX_SIZE + 6, BOX_SIZE + 6)
    check:SetPoint("CENTER", box, "CENTER", 0, 0)
    check:SetTexture(CHECK_ICON)
    check:Hide()
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 8 + BOX_SIZE + 7, -4)
    local name = Text(frame, 12.5, COLOR.text)
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 7, -3)
    if name.SetWordWrap then name:SetWordWrap(false) end
    local class = Text(frame, 10.5, COLOR.muted)
    class:SetPoint("LEFT", name, "RIGHT", 4, 0)
    row = { frame = frame, flash = flash, box = box, partial = partial, check = check, icon = icon, name = name, class = class, pills = {}, count = 0 }
    frame:SetScript("OnClick", function() self:ToggleRow(row) end)
    frame:SetScript("OnEnter", function() RowTip(row) end)
    frame:SetScript("OnLeave", HideTip)
    FX.Hover(frame, tint)
    self.rowPool[index] = row
    return row
end

function Voice:BindRow(row, spell)
    row.spell = spell
    row.icon:SetTexture(SpellIcon(spell.iconSpellID))
    row.name:SetText(spell.name)
    row.class:SetText(self.query ~= "" and spell.class or "")
    local count = 0
    for _, event in ipairs(spell.events) do
        if Model.Shown(spell, self.filter) and (self.filter == Model.ALL or event == self.filter) then
            count = count + 1
            local pill = row.pills[count]
            if not pill then
                pill = NewPill(row.frame)
                pill.frame:SetScript("OnClick", function() self:TogglePill(row, pill) end)
                pill.play:SetScript("OnClick", function() self:PlayPill(pill) end)
                row.pills[count] = pill
            end
            pill.event = event
            pill.keys = spell.eventKeys[event]
            pill.label:SetText(Model.EventLabel(event))
            pill.frame:SetWidth(pill.label:GetStringWidth() + 36)
            pill.frame:Show()
        end
    end
    for index = count + 1, #row.pills do row.pills[index].frame:Hide() end
    row.count = count
end

function Voice:LayoutRow(row, width)
    local x0 = NAME_WIDTH
    if width < 460 then x0 = NAME_NARROW end
    row.name:SetWidth(x0 - (8 + BOX_SIZE + 7 + 20 + 7) - 4)
    local available = width - x0 - 8
    local x, line = 0, 0
    for position = 1, row.count do
        local pill = row.pills[position]
        local size = pill.frame:GetWidth()
        if x > 0 and x + size > available then
            x = 0
            line = line + 1
        end
        pill.frame:ClearAllPoints()
        pill.frame:SetPoint("TOPLEFT", row.frame, "TOPLEFT", x0 + x, -(5 + line * PILL_STEP))
        x = x + size + 4
    end
    return math.max(ROW_MIN, 6 + (line + 1) * PILL_STEP)
end

function Voice:LayoutRows(width)
    local y = 0
    for index = 1, self.activeRows do
        local row = self.rowPool[index]
        local height = self:LayoutRow(row, width)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", self.listHolder, "TOPLEFT", 0, -y)
        row.frame:SetSize(width, height)
        y = y + height
    end
    return y
end

function Voice:FlashChanged(changed)
    for index = 1, self.activeRows do
        local row = self.rowPool[index]
        if changed[row.spell.id] then FX.Flash(row.flash) end
    end
end

function Voice:SetFilter(event)
    self.filter = self.filter == event and Model.ALL or event
    self:ShowList()
end

function Voice:NewEventChip(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(22)
    local fill = Paint(button, COLOR.line)
    fill:SetAllPoints(button)
    local ring = Paint(button, COLOR.accent, 1, "BORDER")
    ring:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    ring:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    ring:SetHeight(2)
    ring:Hide()
    local switch = CreateFrame("Button", nil, button)
    switch:SetSize(24, 13)
    switch:SetPoint("LEFT", button, "LEFT", 5, 0)
    local track = Paint(switch, COLOR.track, 1, "ARTWORK")
    track:SetAllPoints(switch)
    local knob = Paint(switch, COLOR.knob, 1, "OVERLAY")
    knob:SetSize(9, 9)
    local label = Text(button, 12, COLOR.muted)
    label:SetPoint("LEFT", button, "LEFT", 35, 0)
    local count = Text(button, 10.5, COLOR.muted)
    count:SetPoint("LEFT", label, "RIGHT", 5, 0)
    local chip = { frame = button, fill = fill, ring = ring, switch = switch, track = track, knob = knob, label = label, count = count }
    button:SetScript("OnClick", function() self:SetFilter(chip.event) end)
    switch:SetScript("OnClick", function() self:ToggleEventType(chip.event) end)
    button:SetScript("OnEnter", function()
        if chip.event == Model.ALL then
            ShowTip(button, "All events", "Show every spell; a click on a spell switches all its events.")
        else
            ShowTip(button, Model.EventLabel(chip.event), Model.EVENT_HELP[chip.event] .. "\nThe switch turns this kind of alert on or off for every spell. Click the name to show only these.")
        end
    end)
    button:SetScript("OnLeave", HideTip)
    return chip
end

function Voice:ToggleEventType(event)
    local settings = self:Db()
    local flag = Model.SILENCE_FLAG[event]
    settings[flag] = not settings[flag]
    self:Changed()
    self:SyncRows()
    self:SyncEventChips()
    self:SyncSummary()
end

function Voice:SyncEventChips()
    local settings = self:Db()
    for index = 1, self.activeChips do
        local chip = self.eventChips[index]
        local selected = chip.event == self.filter
        chip.ring:SetShown(selected)
        Tint(chip.label, selected and COLOR.text or COLOR.muted)
        if chip.event ~= Model.ALL then
            local on = not settings[Model.SILENCE_FLAG[chip.event]]
            Tint(chip.track, on and COLOR.on or COLOR.track)
            chip.knob:ClearAllPoints()
            chip.knob:SetPoint("LEFT", chip.switch, "LEFT", on and 13 or 2, 0)
            chip.frame:SetAlpha(on and 1 or 0.55)
        end
    end
end

function Voice:SyncFilters(base)
    local events = Model.EventsIn(base)
    self.filterEvents = events
    for index, event in ipairs(events) do
        local chip = self.eventChips[index]
        if not chip then
            chip = self:NewEventChip(self.eventHolder)
            self.eventChips[index] = chip
        end
        chip.event = event
        local all = event == Model.ALL
        chip.switch:SetShown(not all)
        chip.label:ClearAllPoints()
        chip.label:SetPoint("LEFT", chip.frame, "LEFT", all and 10 or 35, 0)
        chip.label:SetText(all and "All events" or Model.EventLabel(event))
        chip.count:SetText(all and "" or tostring(#Model.ByEvent(base, event)))
        chip.frame:SetWidth((all and 10 or 35) + chip.label:GetStringWidth() + (all and 10 or (chip.count:GetStringWidth() + 14)))
        chip.frame:Show()
    end
    for index = #events + 1, #self.eventChips do self.eventChips[index].frame:Hide() end
    self.activeChips = #events
end

function Voice:ShowList()
    local base = Model.Filter(self.model, self.class, self.query)
    local events = Model.EventsIn(base)
    local known = false
    for _, event in ipairs(events) do
        if event == self.filter then known = true end
    end
    if not known then self.filter = Model.ALL end
    local list = Model.ByEvent(base, self.filter)
    self.visible = list
    for index, spell in ipairs(list) do
        local row = self:AcquireRow(index)
        self:BindRow(row, spell)
        row.frame:Show()
    end
    for index = #list + 1, #self.rowPool do self.rowPool[index].frame:Hide() end
    self.activeRows = #list
    self:SyncFilters(base)
    self:LayoutSpells()
    self:Refresh()
end

function Voice:SelectClass(name)
    self.class = name
    self.query = ""
    self.filter = Model.ALL
    self.search:SetText("")
    self:ShowList()
end

function Voice:BuildRail(parent)
    self.railItems = {}
    self.railCard = CreateFrame("Frame", nil, parent)
    local fill = Paint(self.railCard, COLOR.card)
    fill:SetAllPoints(self.railCard)
    Kit.Outline(self.railCard, COLOR.line)
    for index, group in ipairs(self.model.classes) do
        local name = group.name
        local frame = CreateFrame("Button", nil, self.railCard)
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
        frame:SetPoint("TOPLEFT", self.railCard, "TOPLEFT", 0, -(4 + (index - 1) * RAIL_ROW))
        self.railItems[index] = { frame = frame, name = name, selected = selected, bar = bar, count = count, label = label }
    end
    self.railCard:SetSize(RAIL_WIDTH, 8 + #self.model.classes * RAIL_ROW)
end

function Voice:BuildStrip(parent)
    local card = CreateFrame("Frame", nil, parent)
    local fill = Paint(card, COLOR.card)
    fill:SetAllPoints(card)
    Kit.Outline(card, COLOR.line)
    self.strip = { frame = card, columns = {} }
    local function column(title)
        local holder = CreateFrame("Frame", nil, card)
        local heading = NewHeading(holder, title)
        heading:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
        local hint = Text(holder, 10.5, COLOR.muted)
        if hint.SetWordWrap then hint:SetWordWrap(true) end
        hint:SetJustifyH("LEFT")
        local col = { frame = holder, heading = heading, hint = hint, chips = {} }
        self.strip.columns[#self.strip.columns + 1] = col
        return col
    end
    self.zoneColumn = column("WHERE")
    for _, row in ipairs(Model.ZONE_ROWS) do
        local key = row.key
        local chip = NewChip(self.zoneColumn.frame, row.label, function()
            local settings = self:Db()
            settings[key] = not settings[key]
            self:Changed()
            self:SyncStrip()
            self:SyncSummary()
        end)
        chip.key = key
        self.zoneColumn.chips[#self.zoneColumn.chips + 1] = chip
    end
    self.whoColumn = column("WHO")
    for _, row in ipairs(Model.WHO) do
        local key = row.key
        local chip = NewChip(self.whoColumn.frame, row.label, function()
            Model.SetWho(self:Db(), key)
            self:SyncStrip()
        end)
        chip.key = key
        self.whoColumn.chips[#self.whoColumn.chips + 1] = chip
    end
    self.placeColumn = column("PREVIEW AS")
    for _, place in ipairs(Model.SPELL_PLACES) do
        local key = place.key
        local chip = NewChip(self.placeColumn.frame, place.label, function()
            self.spellPlace = key
            self:SyncStrip()
            self:SyncMarks()
        end)
        chip.key = key
        self.placeColumn.chips[#self.placeColumn.chips + 1] = chip
    end
    self.legend = {}
    for _, kind in ipairs(Model.AVAILABILITY_ORDER) do
        local swatch = Paint(self.placeColumn.frame, Model.AVAILABILITY[kind].color, 1, "ARTWORK")
        swatch:SetSize(6, 6)
        local label = Text(self.placeColumn.frame, 10, COLOR.muted)
        label:SetText(Model.AVAILABILITY_LEGEND[kind])
        self.legend[#self.legend + 1] = { swatch = swatch, label = label }
    end
end

function Voice:BuildToolbar(parent)
    local card = CreateFrame("Frame", nil, parent)
    local fill = Paint(card, COLOR.card)
    fill:SetAllPoints(card)
    Kit.Outline(card, COLOR.line)
    self.toolbar = card
    local box = CreateFrame("EditBox", nil, card)
    box:SetAutoFocus(false)
    box:SetFont(Kit.FONT, 12, "")
    box:SetTextInsets(6, 6, 3, 3)
    box:SetSize(190, 22)
    local boxFill = Paint(box, COLOR.line)
    boxFill:SetAllPoints(box)
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
    self.presetLabel = Text(card, 11.5, COLOR.muted)
    self.presetLabel:SetText("Presets")
    self:BuildPresets(card)
    self.eventHolder = CreateFrame("Frame", nil, card)
    self.eventChips = {}
    self.activeChips = 0
end

function Voice:BuildListCard(parent)
    local card = CreateFrame("Frame", nil, parent)
    local fill = Paint(card, COLOR.card)
    fill:SetAllPoints(card)
    Kit.Outline(card, COLOR.line)
    self.listCard = card
    self.listTitle = Text(card, 15, COLOR.text)
    self.listTitle:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
    self.listCount = Text(card, 11.5, COLOR.muted)
    self.listCount:SetPoint("LEFT", self.listTitle, "RIGHT", 10, 0)
    local allOff = Kit.MakeButton(card, "All off", function() self:SetVisible(false) end)
    allOff.frame:SetWidth(60)
    allOff.frame:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -7)
    local allOn = Kit.MakeButton(card, "All on", function() self:SetVisible(true) end)
    allOn.frame:SetWidth(60)
    allOn.frame:SetPoint("RIGHT", allOff.frame, "LEFT", -6, 0)
    self.allButtons = { allOn, allOff }
    local rule = Paint(card, COLOR.line)
    rule:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -LIST_HEAD)
    rule:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, -LIST_HEAD)
    rule:SetHeight(1)
    self.listHolder = CreateFrame("Frame", nil, card)
    self.listNote = Text(card, 11.5, COLOR.muted)
    self.rowPool = {}
    self.activeRows = 0
end

function Voice:BuildDrawers(parent)
    self.moreHeading = NewDivider(parent, "MORE OPTIONS")
    self.drawers = {}
    self.drawerOpen = {}
    for _, drawer in ipairs(Model.DRAWERS) do
        local frame = CreateFrame("Frame", nil, parent)
        local fill = Paint(frame, COLOR.card)
        fill:SetAllPoints(frame)
        Kit.Outline(frame, COLOR.line)
        local head = CreateFrame("Button", nil, frame)
        head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        head:SetHeight(DRAWER_HEAD)
        local tint = Paint(head, COLOR.line, 0.5)
        tint:SetAllPoints(head)
        tint:Hide()
        FX.Hover(head, tint)
        local caret = Text(head, 11, COLOR.muted)
        caret:SetPoint("LEFT", head, "LEFT", 10, 0)
        local name = Text(head, 12.5, COLOR.text)
        name:SetPoint("LEFT", head, "LEFT", 24, 0)
        name:SetText(drawer.label)
        local summary = Text(head, 10.5, COLOR.muted, "RIGHT")
        summary:SetPoint("RIGHT", head, "RIGHT", -12, 0)
        local item = { drawer = drawer, frame = frame, head = head, caret = caret, summary = summary, specs = self:DrawerRows(drawer.key) }
        head:SetScript("OnClick", function()
            self.drawerOpen[drawer.key] = not self.drawerOpen[drawer.key]
            self:LayoutSpells()
            self:Refresh()
        end)
        self.drawers[#self.drawers + 1] = item
    end
end

function Voice:DrawerRows(key)
    if key == "arena" then
        local rows = {}
        for _, row in ipairs(Model.ARENA_ROWS) do
            local preview = row.preview
            rows[#rows + 1] = { kind = "toggle", key = row.key, label = row.label, hint = row.hint, inline = true,
                after = function(value) if value then self.spec.preview(preview) end end }
        end
        return rows
    elseif key == "interrupts" then
        local rows = {}
        for _, row in ipairs(Model.INTERRUPT_ROWS) do rows[#rows + 1] = { kind = "toggle", key = row.key, label = row.label, hint = row.hint, inline = true } end
        rows[#rows + 1] = { kind = "toggle", key = Model.INTERRUPT_PETS.key, label = Model.INTERRUPT_PETS.label }
        local minimum = Model.INTERRUPT_MIN
        rows[#rows + 1] = { kind = "range", key = minimum.key, label = minimum.label, hint = minimum.hint, inline = true, min = minimum.min, max = minimum.max, step = minimum.step, unit = minimum.unit }
        return rows
    elseif key == "loss" then
        local master = Model.LOSS_MASTER
        local rows = { { kind = "toggle", key = master.key, label = master.label, hint = master.hint, inline = true } }
        for _, row in ipairs(Model.LOSS_ROWS) do rows[#rows + 1] = { kind = "toggle", key = row.key, label = row.label, sub = true, requires = Gate(master.key) } end
        return rows
    end
    local rows = {}
    for _, row in ipairs({ Model.BATTLE_ROW, Model.ENGINE_ROW, Model.PROC_ROW }) do
        local spec = { kind = "toggle", key = row.key, label = row.label, hint = row.hint, inline = true }
        if row ~= Model.PROC_ROW then spec.available = self.spec.engineSupported end
        rows[#rows + 1] = spec
    end
    return rows
end

function Voice:EnsureDrawer(item)
    if item.card then return item.card end
    local body = CreateFrame("Frame", nil, item.frame)
    local card = { frame = body, rows = {} }
    item.card, item.body = card, body
    for _, spec in ipairs(item.specs) do self:AddSetting(card, spec) end
    return card
end

function Voice:SetVisible(value)
    Model.SetAll(self:Db(), self.visible, value, self.filter)
    self:Changed()
    self:SpellsChanged(false)
    local changed = {}
    for _, spell in ipairs(self.visible) do changed[spell.id] = true end
    self:FlashChanged(changed)
end

function Voice:BuildSpells()
    local view = NewView(self.body)
    self.spellsView = view
    local child = view.child
    self.spellPlace = "world"
    self.classCounts = {}
    self:BuildStrip(child)
    self:BuildToolbar(child)
    self:BuildRail(child)
    self:BuildListCard(child)
    self:BuildDrawers(child)
    view.onWidth = function(width)
        self.spellsWidth = width
        self:LayoutSpells()
    end
end

function Voice:LayoutStrip(width)
    local columns = self.strip.columns
    local wide = width >= 600
    local columnWidth = wide and math.floor((width - 24 - 2 * 16) / 3) or (width - 24)
    local y, tallest = 10, 0
    for index, col in ipairs(columns) do
        local x = wide and (12 + (index - 1) * (columnWidth + 16)) or 12
        local top = wide and 10 or y
        col.frame:ClearAllPoints()
        col.frame:SetPoint("TOPLEFT", self.strip.frame, "TOPLEFT", x, -top)
        col.frame:SetWidth(columnWidth)
        local bottom = Flow(col.frame, col.chips, columnWidth, 4, 0, 16, CHIP_STEP)
        if col == self.placeColumn then
            local lx, ly = 0, bottom + 2
            for _, item in ipairs(self.legend) do
                local size = item.label:GetStringWidth() + 18
                if lx > 0 and lx + size > columnWidth then
                    lx, ly = 0, ly + 14
                end
                item.swatch:ClearAllPoints()
                item.swatch:SetPoint("TOPLEFT", col.frame, "TOPLEFT", lx, -(ly + 4))
                item.label:ClearAllPoints()
                item.label:SetPoint("TOPLEFT", col.frame, "TOPLEFT", lx + 9, -ly)
                lx = lx + size
            end
            bottom = ly + 16
        else
            col.hint:ClearAllPoints()
            col.hint:SetPoint("TOPLEFT", col.frame, "TOPLEFT", 0, -bottom)
            col.hint:SetWidth(columnWidth)
            bottom = bottom + col.hint:GetStringHeight() + 2
        end
        col.frame:SetHeight(bottom)
        if wide then tallest = math.max(tallest, bottom) else y = y + bottom + 10 end
    end
    local height = wide and (tallest + 20) or (y + 2)
    return height
end

function Voice:LayoutToolbar(width)
    local card = self.toolbar
    self.search:ClearAllPoints()
    self.search:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -9)
    local items = {}
    for _, chip in ipairs(self.presetButtons) do items[#items + 1] = chip end
    items[#items + 1] = self.undoButton
    local chipsWidth = 0
    for _, chip in ipairs(items) do chipsWidth = chipsWidth + chip.frame:GetWidth() + 4 end
    local labelWidth = self.presetLabel:GetStringWidth() + 8
    local y = 9
    local presetX = width - 12 - chipsWidth
    if presetX - labelWidth < 12 + 190 + 12 then
        y = 9 + CHIP_STEP
        presetX = 12 + labelWidth
    end
    self.presetLabel:ClearAllPoints()
    self.presetLabel:SetPoint("TOPLEFT", card, "TOPLEFT", presetX - labelWidth, -(y + 4))
    local bottom = Flow(card, items, width - presetX - 8, 4, presetX, y, CHIP_STEP)
    local chips = self.shownChips
    for index = 1, self.activeChips do chips[index] = self.eventChips[index] end
    for index = self.activeChips + 1, #chips do chips[index] = nil end
    self.eventHolder:ClearAllPoints()
    self.eventHolder:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -(bottom + 2))
    self.eventHolder:SetWidth(width - 24)
    local eventsHeight = #chips > 0 and Flow(self.eventHolder, chips, width - 24, 5, 0, 0, FILTER_STEP) or 0
    self.eventHolder:SetHeight(math.max(1, eventsHeight))
    return bottom + 2 + eventsHeight + 6
end

function Voice:LayoutDrawer(item, width)
    local open = self.drawerOpen[item.drawer.key] and true or false
    item.caret:SetText(open and "v" or ">")
    local height = DRAWER_HEAD
    if open then
        local card = self:EnsureDrawer(item)
        local body = item.body
        body:ClearAllPoints()
        body:SetPoint("TOPLEFT", item.frame, "TOPLEFT", 0, -DRAWER_HEAD)
        body:SetWidth(width)
        body:Show()
        local y = 2
        for _, row in ipairs(card.rows) do
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -y)
            row.frame:SetWidth(width - 16)
            y = y + row.height
        end
        body:SetHeight(y + 6)
        height = height + y + 6
    elseif item.body then
        item.body:Hide()
    end
    item.frame:SetSize(width, height)
    return height
end

function Voice:LayoutSpells()
    local width = self.spellsWidth
    if not width then return end
    local child = self.spellsView.child
    local stripHeight = self:LayoutStrip(width)
    self.strip.frame:ClearAllPoints()
    self.strip.frame:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    self.strip.frame:SetSize(width, stripHeight)
    local y = stripHeight + GAP
    local toolbarHeight = self:LayoutToolbar(width)
    self.toolbar:ClearAllPoints()
    self.toolbar:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    self.toolbar:SetSize(width, toolbarHeight)
    y = y + toolbarHeight + GAP

    local stacked = width < 520
    local listX = stacked and 0 or (RAIL_WIDTH + GAP)
    local listTop = y
    self.railCard:ClearAllPoints()
    self.railCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    self.railCard:SetShown(not stacked)
    local listWidth = math.max(200, width - listX)
    local rowsHeight = self:LayoutRows(listWidth)
    self.listHolder:ClearAllPoints()
    self.listHolder:SetPoint("TOPLEFT", self.listCard, "TOPLEFT", 0, -(LIST_HEAD + 1))
    self.listHolder:SetSize(listWidth, math.max(1, rowsHeight))
    local note = ""
    if self.activeRows == 0 then
        note = self.query ~= "" and ("No spell matches \"" .. self.query .. "\".") or "No spells."
    end
    self.listNote:SetText(note)
    self.listNote:ClearAllPoints()
    self.listNote:SetPoint("TOPLEFT", self.listCard, "TOPLEFT", 12, -(LIST_HEAD + rowsHeight + 10))
    local listHeight = LIST_HEAD + 1 + rowsHeight + (note ~= "" and 30 or 4)
    self.listCard:ClearAllPoints()
    self.listCard:SetPoint("TOPLEFT", child, "TOPLEFT", listX, -listTop)
    self.listCard:SetSize(listWidth, listHeight)
    local railHeight = stacked and 0 or self.railCard:GetHeight()
    y = listTop + math.max(railHeight, listHeight) + 8

    y = PlaceDivider(self.moreHeading, child, width, y)
    local columns = width >= 560 and 2 or 1
    local columnWidth = math.floor((width - (columns - 1) * GAP) / columns)
    local rowTop, rowHeight = y, 0
    for index, item in ipairs(self.drawers) do
        local column = (index - 1) % columns
        if column == 0 and index > 1 then
            rowTop = rowTop + rowHeight + 8
            rowHeight = 0
        end
        local height = self:LayoutDrawer(item, columnWidth)
        item.frame:ClearAllPoints()
        item.frame:SetPoint("TOPLEFT", child, "TOPLEFT", column * (columnWidth + GAP), -rowTop)
        rowHeight = math.max(rowHeight, height)
    end
    y = rowTop + rowHeight + 16
    self.spellsView:SetContentHeight(y)
end

local function SyncPill(row, pill, settings, silenced, place)
    local on = Model.ChipOn(settings, row.spell, pill.event)
    pill.muted = silenced[pill.event]
    Tint(pill.fill, on and COLOR.on or COLOR.line, on and 0.28 or 0.7)
    Tint(pill.label, on and COLOR.on or COLOR.muted)
    pill.frame:SetAlpha(pill.muted and 0.35 or 1)
    local availability = Model.Availability(pill.event, place, settings)
    pill.availability = availability
    Tint(pill.mark, Model.AVAILABILITY[availability].color)
end

function Voice:SyncRow(row, settings, silenced)
    local state = Model.TileState(settings, row.spell, self.filter, silenced)
    row.state = state
    local on = state == "on"
    Tint(row.box, on and COLOR.on or COLOR.line, 1)
    row.check:SetShown(on)
    row.partial:SetShown(state == "some")
    row.frame:SetAlpha(state == "muted" and 0.35 or 1)
    for position = 1, row.count do SyncPill(row, row.pills[position], settings, silenced, self.spellPlace) end
end

function Voice:SyncRows()
    local settings = self:Db()
    local silenced = self:SilencedSet()
    for index = 1, self.activeRows do self:SyncRow(self.rowPool[index], settings, silenced) end
end

function Voice:SyncMarks()
    local settings = self:Db()
    for index = 1, self.activeRows do
        local row = self.rowPool[index]
        for position = 1, row.count do
            local pill = row.pills[position]
            local availability = Model.Availability(pill.event, self.spellPlace, settings)
            pill.availability = availability
            Tint(pill.mark, Model.AVAILABILITY[availability].color)
        end
    end
end

function Voice:CountClass(name, settings)
    local group = self.model.byClass[name]
    local on, total = Model.ClassCount(settings, group)
    local counts = self.classCounts[name]
    if not counts then
        counts = {}
        self.classCounts[name] = counts
    end
    counts.on, counts.total = on, total
    return counts
end

function Voice:SyncRail(settings, only)
    local allOn, allTotal = 0, 0
    for _, item in ipairs(self.railItems) do
        local counts = self.classCounts[item.name]
        if not counts or not only or only == item.name then counts = self:CountClass(item.name, settings) end
        item.count:SetText(counts.on .. "/" .. counts.total)
        local selected = self.query == "" and item.name == self.class
        item.selected:SetShown(selected)
        item.bar:SetShown(selected)
        Tint(item.label, selected and COLOR.accent or COLOR.text)
        allOn, allTotal = allOn + counts.on, allTotal + counts.total
    end
    self.tally = { on = allOn, total = allTotal }
end

function Voice:SyncSummary()
    if self.tab == "chat" then return end
    local settings = self:Db()
    local _, silent = Model.ZoneHint(settings)
    if silent then
        self.summary:SetText("|cffff5d5dSilent everywhere|r  |cff96a0b2pick a zone under Where|r")
        return
    end
    local tally = self.tally or { on = 0, total = 0 }
    local off = Model.SilencedCount(settings)
    local text = "|cff3ddc97" .. tally.on .. "|r of " .. tally.total .. " alerts on"
    if off > 0 then text = text .. "  |cffff5d5d" .. off .. (off == 1 and " kind of alert off" or " kinds of alert off") .. "|r" end
    self.summary:SetText(text)
end

function Voice:SyncListHead(settings)
    local searching = self.query ~= ""
    local filtered = self.filter ~= Model.ALL
    local on, total = Model.Count(settings, self.visible or {}, self.filter)
    self.listTitle:SetText(searching and "Search results" or self.class)
    Tint(self.listTitle, searching and COLOR.text or (CLASS_COLOR[self.class] or COLOR.text))
    self.listCount:SetText(on .. " of " .. total .. " on" .. (filtered and ("  -  " .. Model.EventLabel(self.filter)) or ""))
    local hasRows = self.activeRows > 0
    for _, button in ipairs(self.allButtons) do
        button.frame:SetAlpha(hasRows and 1 or 0.4)
        button.frame:EnableMouse(hasRows)
    end
end

function Voice:SyncStrip()
    local settings = self:Db()
    for _, chip in ipairs(self.zoneColumn.chips) do chip:Set(settings[chip.key] and true or false) end
    local who = Model.Who(settings)
    for _, chip in ipairs(self.whoColumn.chips) do chip:Set(chip.key == who) end
    for _, chip in ipairs(self.placeColumn.chips) do chip:Set(chip.key == self.spellPlace) end
    self.zoneColumn.hint:SetText((Model.ZoneHint(settings)))
    self.whoColumn.hint:SetText(Model.WhoHint(settings))
end

function Voice:SyncPresets()
    self.undoButton:SetLabel(self.undo and self.lastPreset and ("Undo " .. self.lastPreset) or "Undo")
    self.undoButton:Set(false, self.undo and true or false)
    self.undoButton.frame:EnableMouse(self.undo and true or false)
end

function Voice:RowChanged(row)
    local settings = self:Db()
    self:SyncRow(row, settings, self:SilencedSet())
    self:SyncRail(settings, row.spell.class)
    self:SyncListHead(settings)
    self:SyncSummary()
end

function Voice:SpellsChanged(presets)
    local settings = self:Db()
    self:SyncRows()
    self:SyncRail(settings)
    self:SyncListHead(settings)
    self:SyncSummary()
    if presets then self:SyncPresets() end
end

function Voice:SyncDrawers(settings)
    for _, item in ipairs(self.drawers) do
        local on, total = 0, 0
        for _, spec in ipairs(item.specs) do
            if spec.kind == "toggle" then
                total = total + 1
                if settings[spec.key] then on = on + 1 end
            end
        end
        item.summary:SetText(on .. " of " .. total .. " on")
    end
end

local AREA_HEAD = 46
local GROUP_HEAD = 30
local TAG_ROW = 22
local SECTION = 18
local AREA_GAP = 8
local CARD_FILL = { 0.125, 0.145, 0.18 }
local OFF_TEXT = "|cffff5d5dChat alerts are off.|r Nothing below is sent. Turn them on above."
local PLACE_HINT = "Shows where each line really goes. Channels you can't use there are skipped; if none is left, only you see the line."
local THROTTLE_NOTE = "Lines are limited to about one every 1.5 s, so your group never gets flooded."

local function Caret(open)
    return open and "v" or ">"
end

function Voice:AddChatSetting(card, spec)
    spec.chat = true
    local entry = self:AddSetting(card, spec)
    self.chatEntries[#self.chatEntries + 1] = entry
    return entry
end

function Voice:AddChatText(card, key)
    local row = Model.TEXT_ROW[key]
    local label = row.label
    local shared = Model.SHARED_TEXT[key]
    local spec = { kind = "text", key = key, label = label, hint = shared and (row.hint .. " " .. shared .. ".") or row.hint }
    if row.requires then spec.requires = Gate(row.requires) end
    local entry = self:AddChatSetting(card, spec)
    entry.height = ROW_TEXT + TAG_ROW
    entry.frame:SetHeight(entry.height)
    local box = entry.control.frame
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", entry.frame, "TOPLEFT", 4, -22)
    box:SetPoint("TOPRIGHT", entry.frame, "TOPRIGHT", -4, -22)
    box:SetHeight(22)
    local chips = {}
    for _, tag in ipairs(Model.Tags(key)) do
        local token = "#" .. tag .. "#"
        local chip = NewChip(entry.frame, token, function()
            box:Insert(token)
            self:TypeText(key, box:GetText(), box)
        end)
        chip.frame:SetHeight(18)
        chips[#chips + 1] = chip
    end
    local reset = NewChip(entry.frame, "Default", function()
        local value = self.spec.defaults()[key]
        self:TypeText(key, value, nil)
    end)
    reset.frame:SetHeight(18)
    chips[#chips + 1] = reset
    entry.tagChips = chips
    box:HookScript("OnTextChanged", function(editBox, user)
        if user then self:TypeText(key, editBox:GetText(), editBox) end
    end)
    local list = self.textEntries[key]
    if not list then
        list = {}
        self.textEntries[key] = list
    end
    list[#list + 1] = entry
    return entry
end

function Voice:TypeText(key, value, source)
    local settings = self:Db()
    if settings[key] == value then return end
    settings[key] = value
    for _, entry in ipairs(self.textEntries[key] or {}) do
        if entry.control.frame ~= source then entry.control:Set(value) end
    end
    self:SyncSamples(settings, Model.TEXT_ROW[key].area)
end

function Voice:BuildChat()
    local view = NewView(self.body)
    self.chatView = view
    local child = view.child
    self.chatEntries = {}
    self.textEntries = {}
    self.chatOpen = { spells = true }
    self.place = Model.Place("solo")

    self.masterCard = NewCard(child, "Chat alerts")
    local master = Model.MASTER_ROW
    self:AddChatSetting(self.masterCard, { kind = "toggle", key = master.key, label = master.label, hint = master.hint, inline = true, invert = master.invert })

    self.placeCard = NewCard(child, "Preview as")
    self.placeHint = Text(self.placeCard.frame, 10.5, COLOR.muted)
    if self.placeHint.SetWordWrap then self.placeHint:SetWordWrap(true) end
    self.placeHint:SetJustifyH("LEFT")
    self.placeHint:SetText(PLACE_HINT)
    self.placeChips = {}
    for _, place in ipairs(Model.PLACES) do
        local chip = NewChip(self.placeCard.frame, place.label, function()
            self.place = place
            self.placePicked = true
            self:RefreshChat()
        end)
        chip.place = place
        self.placeChips[#self.placeChips + 1] = chip
    end
    self.placeCard.content = function(card, width, y)
        self.placeHint:ClearAllPoints()
        self.placeHint:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 12, -(y - 4))
        self.placeHint:SetWidth(math.max(40, width - 24))
        return Flow(card.frame, self.placeChips, width - 24, 6, 12, y + self.placeHint:GetStringHeight() + 2, CHIP_STEP)
    end

    self.offText = Text(child, 11.5, COLOR.text)
    self.offText:SetText(OFF_TEXT)

    self.chatAreas = {}
    for _, area in ipairs(Model.CHAT_AREAS) do
        self.chatAreas[#self.chatAreas + 1] = self:NewChatArea(area)
    end

    self.throttleNote = Text(child, 10.5, COLOR.muted)
    self.throttleNote:SetText(THROTTLE_NOTE)
    self.testButton = Kit.MakeButton(child, "Print sample lines in my chat", function() self:PrintSamples() end)

    view.onWidth = function(width)
        self.chatWidth = width
        self:LayoutChat()
    end
end

function Voice:NewChatArea(area)
    local frame = CreateFrame("Frame", nil, self.chatView.child)
    local fill = Paint(frame, COLOR.card)
    fill:SetAllPoints(frame)
    Kit.Outline(frame, COLOR.line)
    local head = CreateFrame("Button", nil, frame)
    head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    head:SetHeight(AREA_HEAD)
    local tint = Paint(head, COLOR.line, 0.5)
    tint:SetAllPoints(head)
    tint:Hide()
    FX.Hover(head, tint)
    local caret = Text(head, 11, COLOR.muted)
    caret:SetPoint("LEFT", head, "LEFT", 10, 0)
    local icon = head:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("LEFT", head, "LEFT", 26, 0)
    icon:SetTexture(area.icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local name = Text(head, 13, COLOR.text)
    name:SetPoint("TOPLEFT", head, "TOPLEFT", 60, -8)
    name:SetText(area.label)
    local summary = Text(head, 10.5, COLOR.muted)
    summary:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    summary:SetPoint("RIGHT", head, "RIGHT", -150, 0)
    local entry = { area = area, frame = frame, head = head, caret = caret, summary = summary }
    local key = area.key
    if key == "spells" then
        entry.toggle = Kit.MakeToggle(head, function(value)
            Model.SetAllChat(self:Db(), value)
            self:RefreshChat()
        end)
    elseif area.toggle then
        entry.toggle = Kit.MakeToggle(head, function(value)
            self:Db()[area.toggle] = value
            self:RefreshChat()
        end)
    else
        entry.link = NewLink(head, "Open " .. area.pageLabel, function() SA_Actions.OpenPage(area.page) end)
        entry.link.frame:SetPoint("RIGHT", head, "RIGHT", -12, 0)
    end
    if entry.toggle then entry.toggle.frame:SetPoint("RIGHT", head, "RIGHT", -12, 0) end
    head:SetScript("OnClick", function()
        self.chatOpen[key] = not self.chatOpen[key]
        self:RefreshChat()
    end)
    entry.sample = Text(frame, 12, COLOR.text)
    if entry.sample.SetWordWrap then entry.sample:SetWordWrap(true) end
    entry.sample:SetJustifyH("LEFT")
    entry.sampleFill = Paint(frame, { 0.04, 0.05, 0.065 }, 1, "BORDER")
    return entry
end

function Voice:EnsureAreaBody(entry)
    if entry.body then return entry.body end
    local area, key = entry.area, entry.area.key
    local body = CreateFrame("Frame", nil, entry.frame)
    entry.body = body
    local rule = Paint(body, COLOR.line)
    rule:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    rule:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, 0)
    rule:SetHeight(1)
    if area.key ~= "spells" then
        entry.desc = Text(body, 10.5, COLOR.muted)
        if entry.desc.SetWordWrap then entry.desc:SetWordWrap(true) end
        entry.desc:SetJustifyH("LEFT")
        entry.desc:SetText(area.hint)
        if area.page and area.toggle then
            entry.pageLink = NewLink(body, "Open " .. area.pageLabel, function() SA_Actions.OpenPage(area.page) end)
        end
    end
    entry.sendsHeading = NewHeading(body, "SENDS TO")
    entry.chips = {}
    for _, channel in ipairs(Model.CHANNELS) do
        local channelKey = channel.key
        local chip = NewChip(body, channel.label, function()
            Model.ToggleChannel(self:Db(), key, channelKey)
            self:RefreshChat()
        end)
        chip.key = channelKey
        entry.chips[#entry.chips + 1] = chip
    end
    entry.copy = NewLink(body, "Use for all areas", function()
        Model.CopyChannels(self:Db(), key)
        self.spec.print(area.label .. " channels copied to every area")
        self:RefreshChat()
    end)
    entry.note = Text(body, 10.5, COLOR.muted)
    if entry.note.SetWordWrap then entry.note:SetWordWrap(true) end
    entry.note:SetJustifyH("LEFT")
    if key == "spells" then
        entry.announceHeading = NewHeading(body, "WHAT GETS ANNOUNCED")
        entry.groups = {}
        for _, group in ipairs(Model.CHAT_GROUPS) do
            entry.groups[#entry.groups + 1] = self:NewChatGroup(body, group)
        end
    else
        local keys = {}
        for _, row in ipairs(Model.CHAT_TEXTS) do
            if row.area == key then keys[#keys + 1] = row.key end
        end
        if #keys > 0 then
            entry.textHeading = NewHeading(body, #keys > 1 and "TEXTS" or "TEXT")
            entry.textCard = { frame = body, rows = {} }
            for _, textKey in ipairs(keys) do self:AddChatText(entry.textCard, textKey) end
        end
    end
    return body
end

function Voice:NewChatGroup(parent, group)
    local frame = CreateFrame("Frame", nil, parent)
    local fill = Paint(frame, CARD_FILL)
    fill:SetAllPoints(frame)
    Kit.Outline(frame, COLOR.line)
    local head = CreateFrame("Button", nil, frame)
    head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    head:SetHeight(GROUP_HEAD)
    local caret = Text(head, 10.5, COLOR.muted)
    caret:SetPoint("LEFT", head, "LEFT", 8, 0)
    local name = Text(head, 12, COLOR.text)
    name:SetPoint("LEFT", head, "LEFT", 22, 0)
    name:SetText(group.label)
    local count = Text(head, 10.5, COLOR.muted, "RIGHT")
    count:SetPoint("RIGHT", head, "RIGHT", -52, 0)
    local item = { group = group, frame = frame, head = head, caret = caret, count = count }
    item.toggle = Kit.MakeToggle(head, function(value)
        Model.SetGroup(self:Db(), group, value)
        self:RefreshChat()
    end)
    item.toggle.frame:SetPoint("RIGHT", head, "RIGHT", -8, 0)
    head:SetScript("OnClick", function()
        self.groupOpen = self.groupOpen or {}
        self.groupOpen[group.key] = not self.groupOpen[group.key]
        self:RefreshChat()
    end)
    return item
end

function Voice:EnsureGroupBody(item)
    if item.card then return item.card end
    local group = item.group
    local body = CreateFrame("Frame", nil, item.frame)
    item.body = body
    local card = { frame = body, rows = {} }
    item.card = card
    for _, key in ipairs(group.events) do
        local row = Model.EVENT_ROW[key]
        local spell = row.spell
        self:AddChatSetting(card, { kind = "toggle", key = key, label = row.label, iconFor = function() return spell and SpellIcon(spell) or CHAT_ICON end })
    end
    for _, key in ipairs(group.filters or {}) do
        local row = Model.EVENT_ROW[key]
        self:AddChatSetting(card, { kind = "toggle", key = key, label = row.label, sub = true, requires = Gate(row.requires) })
    end
    for _, key in ipairs(group.texts or {}) do self:AddChatText(card, key) end
    return card
end

local function PlaceRows(card, width, y)
    for _, row in ipairs(card.rows) do
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 8, -y)
        row.frame:SetWidth(width - 16)
        if row.tagChips then Flow(row.frame, row.tagChips, width - 24, 4, 4, ROW_TEXT - 2, TAG_ROW) end
        y = y + row.height
    end
    return y
end

function Voice:LayoutGroup(item, width)
    item.caret:SetText(Caret(self.groupOpen and self.groupOpen[item.group.key]))
    local height = GROUP_HEAD
    if self.groupOpen and self.groupOpen[item.group.key] then
        local card = self:EnsureGroupBody(item)
        local body = card.frame
        body:ClearAllPoints()
        body:SetPoint("TOPLEFT", item.frame, "TOPLEFT", 0, -GROUP_HEAD)
        body:SetWidth(width)
        body:Show()
        local bottom = PlaceRows(card, width, 2)
        body:SetHeight(bottom + 4)
        height = height + bottom + 4
    elseif item.body then
        item.body:Hide()
    end
    item.frame:SetSize(width, height)
    return height
end

function Voice:LayoutAreaBody(entry, width)
    local body = entry.body
    local y = 10
    if entry.desc then
        local linkWidth = entry.pageLink and (entry.pageLink.frame:GetWidth() + 16) or 0
        entry.desc:ClearAllPoints()
        entry.desc:SetPoint("TOPLEFT", body, "TOPLEFT", 12, -y)
        entry.desc:SetWidth(math.max(40, width - 24 - linkWidth))
        if entry.pageLink then
            entry.pageLink.frame:ClearAllPoints()
            entry.pageLink.frame:SetPoint("TOPRIGHT", body, "TOPRIGHT", -12, -y)
        end
        y = y + entry.desc:GetStringHeight() + 10
    end
    entry.sendsHeading:ClearAllPoints()
    entry.sendsHeading:SetPoint("TOPLEFT", body, "TOPLEFT", 12, -y)
    y = y + SECTION
    local copyWidth = entry.copy.frame:GetWidth() + 16
    entry.copy.frame:ClearAllPoints()
    entry.copy.frame:SetPoint("TOPRIGHT", body, "TOPRIGHT", -12, -(y + 3))
    y = Flow(body, entry.chips, width - 24 - copyWidth, 4, 12, y, CHIP_STEP)
    local noteText = entry.note:GetText()
    if noteText and noteText ~= "" then
        entry.note:ClearAllPoints()
        entry.note:SetPoint("TOPLEFT", body, "TOPLEFT", 12, -y)
        entry.note:SetWidth(math.max(40, width - 24))
        entry.note:Show()
        y = y + entry.note:GetStringHeight() + 8
    else
        entry.note:Hide()
    end
    if entry.groups then
        y = y + 6
        entry.announceHeading:ClearAllPoints()
        entry.announceHeading:SetPoint("TOPLEFT", body, "TOPLEFT", 12, -y)
        y = y + SECTION
        local columns = width >= 520 and 2 or 1
        local columnWidth = math.floor((width - 24 - (columns - 1) * 8) / columns)
        local rowTop, rowHeight = y, 0
        for index, item in ipairs(entry.groups) do
            local column = (index - 1) % columns
            if column == 0 and index > 1 then
                rowTop = rowTop + rowHeight + 8
                rowHeight = 0
            end
            local height = self:LayoutGroup(item, columnWidth)
            item.frame:ClearAllPoints()
            item.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 12 + column * (columnWidth + 8), -rowTop)
            rowHeight = math.max(rowHeight, height)
        end
        y = rowTop + rowHeight + 4
    end
    if entry.textCard then
        y = y + 6
        entry.textHeading:ClearAllPoints()
        entry.textHeading:SetPoint("TOPLEFT", body, "TOPLEFT", 12, -y)
        y = y + SECTION
        y = PlaceRows(entry.textCard, width - 8, y)
    end
    return y + 6
end

function Voice:LayoutChat()
    local width = self.chatWidth
    if not width then return end
    local child = self.chatView.child
    local half = math.floor((width - GAP) / 2)
    local y = 0
    local left = PlaceCard(self.masterCard, child, 0, y, half)
    local right = PlaceCard(self.placeCard, child, half + GAP, y, half)
    y = y + math.max(left, right) + GAP
    local settings = self:Db()
    local off = settings and settings.chatalerts
    self.offText:SetShown(off and true or false)
    if off then
        self.offText:ClearAllPoints()
        self.offText:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -y)
        y = y + 22
    end
    for _, entry in ipairs(self.chatAreas) do
        local open = self.chatOpen[entry.area.key] and true or false
        entry.caret:SetText(Caret(open))
        local height = AREA_HEAD
        if open then
            local body = self:EnsureAreaBody(entry)
            body:ClearAllPoints()
            body:SetPoint("TOPLEFT", entry.frame, "TOPLEFT", 0, -AREA_HEAD)
            body:SetWidth(width)
            body:Show()
            local bodyHeight = self:LayoutAreaBody(entry, width)
            body:SetHeight(bodyHeight)
            height = height + bodyHeight
        elseif entry.body then
            entry.body:Hide()
        end
        entry.sample:ClearAllPoints()
        entry.sample:SetPoint("TOPLEFT", entry.frame, "TOPLEFT", 20, -(height + 6))
        entry.sample:SetWidth(math.max(40, width - 40))
        local sampleHeight = math.max(14, entry.sample:GetStringHeight())
        entry.sampleFill:ClearAllPoints()
        entry.sampleFill:SetPoint("TOPLEFT", entry.frame, "TOPLEFT", 12, -height)
        entry.sampleFill:SetPoint("TOPRIGHT", entry.frame, "TOPRIGHT", -12, -height)
        entry.sampleFill:SetHeight(sampleHeight + 12)
        entry.sampleHeight = sampleHeight
        height = height + sampleHeight + 20
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
        entry.frame:SetSize(width, height)
        entry.top = y
        y = y + height + AREA_GAP
    end
    self.throttleNote:ClearAllPoints()
    self.throttleNote:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -(y + 6))
    self.testButton.frame:ClearAllPoints()
    self.testButton.frame:SetPoint("TOPRIGHT", child, "TOPLEFT", width, -y)
    self.chatView:SetContentHeight(y + 30)
end

function Voice:SyncSamples(settings, only)
    local player = self.spec.player and self.spec.player() or "You"
    local relayout = false
    for _, entry in ipairs(self.chatAreas) do
        if not only or entry.area.key == only then
            entry.sample:SetText(Model.Sample(settings, entry.area, self.place, player, Rail.ExpandChat))
            if only and entry.sampleHeight and math.max(14, entry.sample:GetStringHeight()) ~= entry.sampleHeight then relayout = true end
        end
    end
    if relayout then self:LayoutChat() end
end

function Voice:RefreshChat()
    local settings = self:Db()
    if not settings then return end
    for _, entry in ipairs(self.chatEntries) do SyncSetting(entry, settings) end
    for _, chip in ipairs(self.placeChips) do chip:Set(chip.place == self.place) end
    local sending, areas = Model.SendingCount(settings)
    if settings.chatalerts then
        self.summary:SetText("|cffff5d5dChat alerts off|r  |cff96a0b2nothing is sent|r")
    else
        self.summary:SetText("|cff3ddc97Chat alerts on|r  |cff96a0b2" .. sending .. " of " .. areas .. " areas sending|r")
    end
    local events, allEvents = Model.ChatEventCount(settings)
    local customOn, customTotal = Model.CustomChatCount(settings)
    for _, entry in ipairs(self.chatAreas) do
        local area = entry.area
        local names = Model.ChannelNames(settings, area.key)
        local where = #names > 0 and ("to |cffe7eaf0" .. table.concat(names, ", ") .. "|r") or "|cffffb84dno channel, only you see it|r"
        local state
        if area.key == "spells" then
            state = events .. " of " .. allEvents .. " on"
            entry.toggle:Set(events > 0)
        elseif area.toggle then
            local on = settings[area.toggle] and true or false
            state = on and "on" or "off"
            entry.toggle:Set(on)
        else
            state = customOn .. " of " .. customTotal .. " alerts announce"
        end
        entry.summary:SetText(state .. "  -  " .. where)
        entry.frame:SetAlpha(Model.AreaOn(settings, area) and 1 or 0.6)
        if entry.chips then
            local own = Model.Channels(settings, area.key)
            for _, chip in ipairs(entry.chips) do
                local usable = Model.Resolve(chip.key, self.place) ~= nil
                chip:Set(own[chip.key] and true or false, usable)
            end
            local note = Model.ChannelNote(settings, area.key, self.place)
            entry.note:SetText(note)
        end
        if entry.groups then
            for _, item in ipairs(entry.groups) do
                local on, total = Model.GroupCount(settings, item.group)
                item.count:SetText(on .. " of " .. total)
                item.toggle:Set(on == total)
            end
        end
    end
    self:SyncSamples(settings)
    self:LayoutChat()
end

function Voice:PrintSamples()
    local settings = self:Db()
    local player = self.spec.player and self.spec.player() or "You"
    for _, entry in ipairs(self.chatAreas) do
        local sample = Model.Sample(settings, entry.area, self.place, player, Rail.ExpandChat)
        for line in sample:gmatch("[^\n]+") do self.spec.print(entry.area.label .. ": " .. line) end
    end
end

function Voice:FocusArea(key)
    self.chatOpen[key] = true
    self:RefreshChat()
    for _, entry in ipairs(self.chatAreas) do
        if entry.area.key == key and entry.top then self.chatView:ScrollTo(entry.top) end
    end
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
    if key == "chat" and not self.placePicked and self.spec.situation then
        self.place = Model.Place(self.spec.situation())
    end
    local view = key == "chat" and self.chatView or self.spellsView
    local other = key == "chat" and self.spellsView or self.chatView
    other.frame:Hide()
    view.frame:ClearAllPoints()
    view.frame:SetAllPoints(self.body)
    view.frame:Show()
    local width = view.scroll:GetWidth()
    if width and width > 12 then view:LayWidth(width - 12) end
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

function Voice:Refresh()
    local settings = self:Db()
    if not settings then return end
    for _, entry in ipairs(self.settings) do
        if not entry.spec.chat then SyncSetting(entry, settings) end
    end
    if self.tab == "chat" then
        self:RefreshChat()
        return
    end
    self:SyncStrip()
    self:SyncRows()
    self:SyncRail(settings)
    self:SyncEventChips()
    self:SyncListHead(settings)
    self:SyncPresets()
    self:SyncDrawers(settings)
    self:SyncSummary()
end

local function BuildPage(spec)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    local page = { frame = frame, spec = spec, settings = {}, query = "", filter = Model.ALL, silenced = {}, shownChips = {} }
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
    local wanted = SoundAlerter.voicePageTab
    local area = SoundAlerter.voicePageArea
    SoundAlerter.voicePageTab, SoundAlerter.voicePageArea = nil, nil
    if area then page.chatOpen[area] = true end
    if wanted and wanted ~= page.tab then
        page:ShowTab(wanted, false)
    else
        page:Refresh()
    end
    if area then page:FocusArea(area) end
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
        changed = function() SoundAlerter:OnConfigTableChange(nil, "SoundAlerter") end,
        situation = function()
            local inInstance, instanceType = IsInInstance()
            return Model.PlaceFor(inInstance, instanceType, IsInGroup())
        end,
        player = function() return UnitName("player") or "You" end,
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
