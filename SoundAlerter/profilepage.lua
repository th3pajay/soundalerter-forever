local SoundAlerter = SoundAlerter
local AceGUI = LibStub("AceGUI-3.0")
local Kit = SoundAlerter.Page.Kit
local Model = SA_ProfileModel
local Transfer = SA_ProfileTransfer
local FX = SA_MenuFX

local COLOR, Paint, Outline, Text, Tint = Kit.COLOR, Kit.Paint, Kit.Outline, Kit.Text, Kit.Tint
local NewView, NewHeading, NewDivider, PlaceDivider, NewCard, PlaceCard = Kit.NewView, Kit.NewHeading, Kit.NewDivider, Kit.PlaceDivider, Kit.NewCard, Kit.PlaceCard

local WIDGET = "SoundAlerterProfilePage"
local HEADER_HEIGHT = 52
local TOAST_SECONDS = 1.5
local DANGER = { 1, 0.36, 0.36 }
local WHITE = { 1, 1, 1 }
local GLYPH = 64
local PAD = 18
local TEXT_X = PAD + GLYPH + 14
local CHIP_HEIGHT, CHIP_STEP = 20, 24
local PILL_HEIGHT, PILL_GAP, PILL_MIN, PILL_MAX = 44, 8, 150, 260
local TAG_ROOM = 200
local NEW_HINT = "A new profile starts from the defaults. Use Copy here or Duplicate to start from another profile instead."
local EXPORT_HINT = "Copy the text with Ctrl+C and send it. Anyone can paste it into Import text to get this profile."
local IMPORT_HINT = "Paste an export text and press Enter. It becomes a new profile; the active profile is not touched."

local Profile = {}

local function SetLabel(button, text)
    if button.shownText ~= text then
        button.shownText = text
        button.label:SetText(text)
        button.frame:SetWidth(math.max(70, button.label:GetStringWidth() + 24))
    end
end

local function SetIf(region, key, value)
    if region[key] ~= value then
        region[key] = value
        region:SetText(value)
    end
end

local function Enable(button, enabled)
    button.frame:SetAlpha(enabled and 1 or 0.4)
    button.frame:EnableMouse(enabled and true or false)
end

local function NewTag(parent, text, color)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(16)
    local fill = Paint(frame, color, 0.14)
    fill:SetAllPoints(frame)
    local label = Text(frame, 10.5, color, "CENTER")
    label:SetAllPoints(frame)
    label:SetText(text)
    frame:SetWidth(label:GetStringWidth() + 14)
    return frame
end

local function NewGlyph(frame, size, fontSize)
    local fill = Paint(frame, COLOR.accent, 1, "ARTWORK")
    fill:SetSize(size, size)
    local initials = Text(frame, fontSize, WHITE, "CENTER")
    initials:SetAllPoints(fill)
    local glyph = { fill = fill }
    function glyph:Set(name)
        if self.name == name then return end
        self.name = name
        local r, g, b = Model.Color(name)
        fill:SetVertexColor(r, g, b, 1)
        initials:SetText(Model.Initials(name))
        return r, g, b
    end
    return glyph
end

local function NewEditBox(parent, height, fontSize)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetAutoFocus(false)
    box:SetFont(Kit.FONT, fontSize, "")
    box:SetTextInsets(8, 8, 3, 3)
    box:SetHeight(height)
    local fill = Paint(box, COLOR.line)
    fill:SetAllPoints(box)
    return box
end

function Profile:Arm(key)
    if self.armed == key then
        self.armed = nil
        self:BindStage()
        self:BindActive()
        self:BindBlocks()
        return true
    end
    self.armed = key
    self.armToken = (self.armToken or 0) + 1
    local token = self.armToken
    if C_Timer and C_Timer.After then
        C_Timer.After(Model.ARM_SECONDS, function()
            if self.armToken == token and self.armed == key then
                self.armed = nil
                self:BindStage()
                self:BindActive()
                self:BindBlocks()
            end
        end)
    end
    self:BindStage()
    self:BindActive()
    self:BindBlocks()
    return false
end

function Profile:Toast(text)
    self.toastText:SetText(text)
    self.toast:SetWidth(self.toastText:GetStringWidth() + 26)
    self.toast:Show()
    self.toastToken = (self.toastToken or 0) + 1
    local token = self.toastToken
    if C_Timer and C_Timer.After then
        C_Timer.After(TOAST_SECONDS, function()
            if self.toastToken == token then self.toast:Hide() end
        end)
    end
end

function Profile:Details(name)
    local detail = self.details[name]
    if not detail then
        detail = {}
        self.details[name] = detail
    end
    if detail.stamp ~= self.stamp then
        detail.stamp = self.stamp
        self.spec.summary(name, detail)
    end
    return detail
end

function Profile:UseSelected()
    local name = self.sel
    if not name or name == self.current then return end
    self.armed = nil
    self.spec.use(name)
    self:Toast("Now using " .. name)
    self:Refresh(false)
end

function Profile:CopySelected()
    local name = self.sel
    if not name or name == self.current then return end
    if not self:Arm("copy:" .. name) then return end
    self.spec.copy(name)
    self:Toast("Copied settings from " .. name)
    self:Refresh(true)
    FX.Flash(self.stage.flash)
end

function Profile:DeleteSelected()
    local name = self.sel
    if not name or not Model.CanDelete(name, self.current) then return end
    if not self:Arm("delete:" .. name) then return end
    self.spec.delete(name)
    self.sel = self.current
    self:Toast("Deleted " .. name)
    self:Refresh(true)
end

function Profile:DuplicateSelected()
    local name = Model.UniqueName(self.sel, self.existing, " copy")
    self.spec.duplicate(self.sel, name)
    self.sel = name
    self:Toast("Duplicated as " .. name)
    self:Refresh(true)
    FX.Flash(self.stage.flash)
end

function Profile:BeginRename()
    if self.renaming then return end
    self.renaming = true
    local stage = self.stage
    stage.name:Hide()
    stage.currentTag:Hide()
    stage.defaultTag:Hide()
    stage.renameBox:SetText(self.sel)
    stage.renameBox:Show()
    stage.renameBox:SetFocus()
    stage.renameBox:HighlightText()
end

function Profile:EndRename()
    if not self.renaming then return end
    self.renaming = false
    local stage = self.stage
    stage.renameBox:ClearFocus()
    stage.renameBox:Hide()
    stage.name:Show()
    self:BindStage()
end

function Profile:CommitRename()
    if not self.renaming then return end
    local old = self.sel
    local clean = Model.Clean(self.stage.renameBox:GetText())
    if clean == "" or clean == old then
        self:EndRename()
        return
    end
    local ok, message = Model.Validate(clean, self.existing)
    if not ok then
        FX.Shake(self.stage.renameBox)
        self:Toast(message)
        return
    end
    self.spec.rename(old, clean)
    self.sel = clean
    self.renaming = false
    self.stage.renameBox:ClearFocus()
    self.stage.renameBox:Hide()
    self.stage.name:Show()
    self:Toast("Renamed " .. old .. " to " .. clean)
    self:Refresh(true)
end

function Profile:OpenTransfer(kind)
    local box, card = self.transferBox, self.transferCard
    self.transfer = kind
    if kind == "export" then
        local text = self.spec.export(self.sel)
        card.title:SetText("Export of " .. self.sel)
        box:SetText(text or "")
        self:SetTransferHint(text and EXPORT_HINT or "This profile could not be exported.", text == nil)
        self.transferGo.frame:Hide()
    else
        card.title:SetText("Import a profile")
        box:SetText("")
        self:SetTransferHint(IMPORT_HINT, false)
        self.transferGo.frame:Show()
    end
    card.frame:Show()
    self:Layout()
    box:SetFocus()
    box:HighlightText()
end

function Profile:CloseTransfer()
    if not self.transfer then return end
    self.transfer = nil
    self.transferBox:ClearFocus()
    self.transferCard.frame:Hide()
end

function Profile:ToggleTransfer(kind)
    if self.transfer == kind then
        self:CloseTransfer()
        self:Layout()
        return
    end
    self:OpenTransfer(kind)
end

function Profile:SetTransferHint(text, bad)
    SetIf(self.transferHint, "cached", text)
    Tint(self.transferHint, bad and DANGER or COLOR.muted)
end

function Profile:RunImport()
    local name, message = self.spec.importText(self.transferBox:GetText())
    if not name then
        self:SetTransferHint(message, true)
        FX.Shake(self.transferBox)
        return
    end
    self.sel = name
    self:CloseTransfer()
    self:Toast("Imported as " .. name)
    self:Refresh(true)
    self:Layout()
end

function Profile:Select(name)
    if self.sel == name then return end
    self.sel = name
    self.armed = nil
    if self.renaming then self:EndRename() end
    self:CloseTransfer()
    self:BindPills()
    self:BindStage()
    self:BindActive()
    self.blockPicked = {}
    self.blockText = nil
    self:BindBlocks()
    FX.Flash(self.stage.flash)
    self:Layout()
end

function Profile:AcquirePill(index)
    local pill = self.pills[index]
    if pill then return pill end
    local frame = CreateFrame("Button", nil, self.view.child)
    frame:SetHeight(PILL_HEIGHT)
    local fill = Paint(frame, COLOR.card)
    fill:SetAllPoints(frame)
    Outline(frame, COLOR.line)
    local tint = Paint(frame, COLOR.line, 0.5)
    tint:SetAllPoints(frame)
    tint:Hide()
    pill = { frame = frame, fill = fill }
    pill.mark = Paint(frame, COLOR.accent, 1, "ARTWORK")
    pill.mark:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    pill.mark:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    pill.mark:SetWidth(3)
    pill.glyph = NewGlyph(frame, 28, 12)
    pill.glyph.fill:SetPoint("LEFT", frame, "LEFT", 12, 0)
    pill.name = Text(frame, 12.5, COLOR.text)
    pill.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 50, -7)
    pill.name:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    pill.sub = Text(frame, 10.5, COLOR.muted)
    pill.sub:SetPoint("TOPLEFT", frame, "TOPLEFT", 50, -25)
    pill.sub:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    frame:SetScript("OnClick", function()
        if pill.profile then self:Select(pill.profile) end
    end)
    FX.Hover(frame, tint)
    self.pills[index] = pill
    return pill
end

function Profile:BindPills()
    local current, sel, chars = self.current, self.sel, self.chars
    for index, name in ipairs(self.names) do
        local pill = self:AcquirePill(index)
        pill.profile = name
        pill.glyph:Set(name)
        SetIf(pill.name, "cached", name)
        SetIf(pill.sub, "cached", (name == current and "active \194\183 " or "") .. Model.CountText(chars[name]))
        local selected = name == sel
        pill.mark:SetShown(selected)
        if pill.selected ~= selected then
            pill.selected = selected
            Tint(pill.fill, selected and COLOR.line or COLOR.card, selected and 0.7 or 1)
        end
        pill.frame:Show()
    end
    for index = #self.names + 1, #self.pills do
        self.pills[index].profile = nil
        self.pills[index].frame:Hide()
    end
end

function Profile:PlacePills(width, y)
    local count = #self.names
    if count == 0 then return y end
    local child = self.view.child
    local size = math.max(PILL_MIN, math.min(PILL_MAX, (width - (count - 1) * PILL_GAP) / count))
    local x, rowY = 0, y
    for index = 1, count do
        local frame = self:AcquirePill(index).frame
        if x > 0 and x + size > width then
            x = 0
            rowY = rowY + PILL_HEIGHT + PILL_GAP
        end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", child, "TOPLEFT", x, -rowY)
        frame:SetWidth(size)
        x = x + size + PILL_GAP
    end
    return rowY + PILL_HEIGHT
end

function Profile:BuildStage(parent)
    local frame = CreateFrame("Frame", nil, parent)
    local fill = Paint(frame, COLOR.card)
    fill:SetAllPoints(frame)
    Outline(frame, COLOR.line)
    local stage = { frame = frame, buttons = {}, chips = {} }
    stage.flash = Paint(frame, COLOR.accent, 0.3, "BORDER")
    stage.flash:SetAllPoints(frame)
    stage.flash:Hide()
    stage.bar = Paint(frame, COLOR.accent, 1, "ARTWORK")
    stage.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    stage.bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    stage.bar:SetWidth(3)
    stage.glyph = NewGlyph(frame, GLYPH, 26)
    stage.glyph.fill:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
    stage.name = Text(frame, 20, COLOR.text)
    stage.name:SetPoint("TOPLEFT", frame, "TOPLEFT", TEXT_X, -16)
    stage.name:SetPoint("RIGHT", frame, "RIGHT", -TAG_ROOM, 0)
    stage.currentTag = NewTag(frame, "active", COLOR.on)
    stage.defaultTag = NewTag(frame, "new characters", COLOR.accent)
    stage.users = Text(frame, 11.5, COLOR.muted)
    stage.users:SetPoint("TOPLEFT", frame, "TOPLEFT", TEXT_X, -48)
    stage.users:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    stage.alertsCaption = Text(frame, 10.5, COLOR.muted)
    stage.alertsCaption:SetText("ALERTS")
    stage.alerts = Text(frame, 12, COLOR.text)
    stage.modulesCaption = Text(frame, 10.5, COLOR.muted)
    stage.modulesCaption:SetText("SWITCHED ON")
    stage.summary = Text(frame, 11.5, COLOR.muted)

    local box = NewEditBox(frame, 26, 14)
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", TEXT_X, -12)
    box:SetWidth(260)
    box:SetMaxLetters(Model.NAME_LIMIT)
    box:Hide()
    box:SetScript("OnEnterPressed", function() self:CommitRename() end)
    box:SetScript("OnEscapePressed", function() self:EndRename() end)
    box:SetScript("OnEditFocusLost", function() self:EndRename() end)
    stage.renameBox = box

    for index, module in ipairs(Model.MODULES) do
        local chip = CreateFrame("Frame", nil, frame)
        chip:SetHeight(CHIP_HEIGHT)
        local chipFill = Paint(chip, COLOR.line)
        chipFill:SetAllPoints(chip)
        local label = Text(chip, 11, COLOR.muted, "CENTER")
        label:SetAllPoints(chip)
        label:SetText(module[1])
        chip:SetWidth(label:GetStringWidth() + 18)
        stage.chips[index] = { frame = chip, fill = chipFill, label = label }
    end

    local function add(text, handler)
        local button = Kit.MakeButton(frame, text, handler)
        stage.buttons[#stage.buttons + 1] = button
        return button
    end
    stage.use = add("Use", function() self:UseSelected() end)
    stage.copy = add("Copy here", function() self:CopySelected() end)
    stage.duplicate = add("Duplicate", function() self:DuplicateSelected() end)
    stage.rename = add("Rename", function() self:BeginRename() end)
    stage.export = add("Export", function() self:ToggleTransfer("export") end)
    stage.delete = add("Delete", function() self:DeleteSelected() end)
    stage.copy.frame:HookScript("OnEnter", function()
        if self.sel then Kit.ShowTip(stage.copy.frame, "Copy settings here", "Overwrites the active profile with the settings of " .. self.sel .. ".") end
    end)
    stage.copy.frame:HookScript("OnLeave", Kit.HideTip)
    self.stage = stage
    return stage
end

function Profile:PlaceActions()
    local stage = self.stage
    local width = (self.width or 640) - 2 * PAD
    local x, y = 0, stage.actionsY or 0
    for _, button in ipairs(stage.buttons) do
        local frame = button.frame
        if frame:IsShown() then
            local size = frame:GetWidth()
            if x > 0 and x + size > width then
                x = 0
                y = y + 28
            end
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", stage.frame, "TOPLEFT", PAD + x, -y)
            x = x + size + 6
        end
    end
    return y + 22 + PAD
end

function Profile:LayoutStage(width, y)
    local stage = self.stage
    local frame = stage.frame
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", self.view.child, "TOPLEFT", 0, -y)
    frame:SetWidth(width)
    local top = PAD + GLYPH + 16
    stage.alertsCaption:ClearAllPoints()
    stage.alertsCaption:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -top)
    stage.alerts:ClearAllPoints()
    stage.alerts:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(top + 14))
    stage.alerts:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    stage.modulesCaption:ClearAllPoints()
    stage.modulesCaption:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(top + 44))
    local bottom = Kit.Flow(frame, stage.chips, width - 2 * PAD, 6, PAD, top + 60, CHIP_STEP)
    stage.summary:ClearAllPoints()
    stage.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(bottom + 2))
    stage.summary:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    stage.actionsY = bottom + 26
    local height = self:PlaceActions()
    stage.height = height
    frame:SetHeight(height)
    return height
end

function Profile:BindStage()
    local stage, name = self.stage, self.sel
    if not name then return end
    local active = name == self.current
    local detail = self:Details(name)
    local r, g, b = stage.glyph:Set(name)
    if r then stage.bar:SetVertexColor(r, g, b, 1) end
    SetIf(stage.name, "cached", name)
    local room = (self.width or 640) - TEXT_X - TAG_ROOM
    local x = TEXT_X + math.min(stage.name:GetStringWidth(), room) + 10
    local showTags = not self.renaming
    stage.currentTag:SetShown(active and showTags)
    stage.defaultTag:SetShown(name == self.newDefault and showTags)
    stage.currentTag:ClearAllPoints()
    stage.currentTag:SetPoint("TOPLEFT", stage.frame, "TOPLEFT", x, -20)
    if active then x = x + stage.currentTag:GetWidth() + 6 end
    stage.defaultTag:ClearAllPoints()
    stage.defaultTag:SetPoint("TOPLEFT", stage.frame, "TOPLEFT", x, -20)
    SetIf(stage.users, "cached", Model.CharactersText(self.chars[name]))
    SetIf(stage.alerts, "cached", Model.OverviewText(detail))
    for index, chip in ipairs(stage.chips) do
        local on = detail.modules[index] and true or false
        if chip.on ~= on then
            chip.on = on
            Tint(chip.fill, on and COLOR.on or COLOR.line, on and 0.3 or 1)
            Tint(chip.label, on and COLOR.on or COLOR.muted)
        end
    end
    SetIf(stage.summary, "cached", Model.SummaryText(detail))
    stage.use.frame:SetShown(not active)
    stage.copy.frame:SetShown(not active)
    SetLabel(stage.copy, self.armed == "copy:" .. name and "Overwrite?" or "Copy here")
    SetLabel(stage.delete, self.armed == "delete:" .. name and "Really delete?" or "Delete")
    Enable(stage.delete, Model.CanDelete(name, self.current))
    if self:PlaceActions() ~= stage.height then self:Layout() end
end

function Profile:ValidateName()
    local text = self.nameBox:GetText()
    local ok, message = Model.Validate(text, self.existing or {})
    local clean = Model.Clean(text)
    self.nameValid = ok
    Enable(self.create, ok)
    if clean == "" or ok then
        SetIf(self.nameHint, "cached", NEW_HINT)
        Tint(self.nameHint, COLOR.muted)
    else
        SetIf(self.nameHint, "cached", message)
        Tint(self.nameHint, DANGER)
    end
end

function Profile:CreateProfile()
    local ok, _, clean = Model.Validate(self.nameBox:GetText(), self.existing or {})
    if not ok then
        FX.Shake(self.nameBox)
        return
    end
    self.spec.create(clean)
    self.nameBox:SetText("")
    self.armed = nil
    self.sel = clean
    self:Toast("Created and using " .. clean)
    self:Refresh(true)
end

function Profile:BuildNewCard(parent)
    local card = NewCard(parent, "New profile")
    local box = NewEditBox(card.frame, 24, 12)
    self.nameBox = box
    self.placeholder = Text(box, 12, COLOR.muted)
    self.placeholder:SetPoint("LEFT", box, "LEFT", 8, 0)
    self.placeholder:SetText("Name of the new profile")
    box:SetScript("OnTextChanged", function()
        self.placeholder:SetShown(box:GetText() == "")
        self:ValidateName()
    end)
    box:SetScript("OnEnterPressed", function() self:CreateProfile() end)
    box:SetScript("OnEscapePressed", function(frame) frame:ClearFocus() end)
    self.create = Kit.MakeButton(card.frame, "Create and use", function() self:CreateProfile() end)
    self.importButton = Kit.MakeButton(card.frame, "Import text", function() self:ToggleTransfer("import") end)
    self.nameHint = Text(card.frame, 11, COLOR.muted)
    self.nameHint:SetHeight(14)
    card.content = function(frame, width, y)
        self.importButton.frame:ClearAllPoints()
        self.importButton.frame:SetPoint("TOPRIGHT", card.frame, "TOPRIGHT", -12, -(y + 1))
        self.create.frame:ClearAllPoints()
        self.create.frame:SetPoint("TOPRIGHT", self.importButton.frame, "TOPLEFT", -6, 0)
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 12, -y)
        box:SetPoint("RIGHT", self.create.frame, "LEFT", -8, 0)
        self.nameHint:ClearAllPoints()
        self.nameHint:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 14, -(y + 32))
        self.nameHint:SetPoint("RIGHT", card.frame, "RIGHT", -12, 0)
        return y + 50
    end
    return card
end

function Profile:BuildTransferCard(parent)
    local card = NewCard(parent, "")
    local box = NewEditBox(card.frame, 24, 12)
    box:SetMaxLetters(Transfer.MAX_LENGTH)
    box:SetScript("OnEscapePressed", function(frame) frame:ClearFocus() end)
    box:SetScript("OnEnterPressed", function()
        if self.transfer == "import" then self:RunImport() end
    end)
    self.transferBox = box
    self.transferHint = Text(card.frame, 11, COLOR.muted)
    self.transferHint:SetHeight(14)
    self.transferGo = Kit.MakeButton(card.frame, "Import as new profile", function() self:RunImport() end)
    self.transferClose = Kit.MakeButton(card.frame, "Close", function()
        self:CloseTransfer()
        self:Layout()
    end)
    card.content = function(frame, width, y)
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 12, -y)
        box:SetPoint("RIGHT", card.frame, "RIGHT", -12, 0)
        self.transferHint:ClearAllPoints()
        self.transferHint:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 14, -(y + 32))
        self.transferHint:SetPoint("RIGHT", card.frame, "RIGHT", -12, 0)
        self.transferGo.frame:ClearAllPoints()
        self.transferGo.frame:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 12, -(y + 54))
        self.transferClose.frame:ClearAllPoints()
        if self.transferGo.frame:IsShown() then
            self.transferClose.frame:SetPoint("TOPLEFT", self.transferGo.frame, "TOPRIGHT", 6, 0)
        else
            self.transferClose.frame:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 12, -(y + 54))
        end
        return y + 84
    end
    card.frame:Hide()
    return card
end

function Profile:BuildActiveCard(parent)
    local spec = self.spec
    local card = NewCard(parent, "Active profile")
    self.newDefaultRow = Kit.AddRow(card, {
        kind = "toggle",
        label = "Use this profile for new characters",
        hint = "Characters that have never logged in start on this profile.",
        set = function(value)
            spec.setNewDefault(value and self.current or nil)
            self.newDefault = spec.newDefault()
        end,
    }, function()
        self:BindStage()
    end)
    self.resetRow = Kit.AddRow(card, {
        kind = "button",
        label = "Reset the active profile",
        hint = "Puts every setting of the active profile back to its default. Other profiles are not touched.",
        button = "Reset profile",
        onClick = function()
            if not self:Arm("reset") then return end
            spec.reset()
            self:Toast(self.current .. " reset to defaults")
            self:Refresh(true)
        end,
    })
    return card
end

function Profile:BindActive()
    SetIf(self.activeCard.title, "cached", "Active profile: " .. (self.current or ""))
    self.newDefaultRow.control:Set(self.newDefault == self.current)
    SetLabel(self.resetRow.button, self.armed == "reset" and "Click again to reset" or "Reset profile")
end

local BLOCK_CLASS_COLORS = {
    Druid = { 1, 0.49, 0.04 }, Hunter = { 0.67, 0.83, 0.45 }, Mage = { 0.41, 0.8, 0.94 }, Paladin = { 0.96, 0.55, 0.73 },
    Priest = { 1, 1, 1 }, Rogue = { 1, 0.96, 0.41 }, Shaman = { 0, 0.44, 0.87 }, Warlock = { 0.58, 0.51, 0.79 },
    Warrior = { 0.78, 0.61, 0.43 }, Other = { 0.49, 0.52, 0.59 },
}
local WARN = { 1, 0.69, 0.13 }
local SEG_HEIGHT, SEG_GAP, SEG_MIN = 40, 3, 64
local DIFF_ROW = 22
local BLOCK_EXPORT_HINT = "Copy the text with Ctrl+C. Anyone can paste it under Spell Tracker blocks, Import."
local BLOCK_IMPORT_HINT = "Paste a Spell Tracker blocks text and press Enter or Read text."

local function BlockLabel(block)
    if block.class then
        local count = block.weight
        return block.class, count .. (count == 1 and " spell" or " spells"), BLOCK_CLASS_COLORS[block.class] or BLOCK_CLASS_COLORS.Other
    end
    if block.key == "display" then return "Display", "timer and text settings", COLOR.muted end
    return "Layout", "positions and sizes", COLOR.on
end

function Profile:AcquireSegment(pool, index, parent, onToggle)
    local seg = pool[index]
    if seg then return seg end
    local frame = CreateFrame("Button", nil, parent)
    frame:SetHeight(SEG_HEIGHT)
    local fill = Paint(frame, COLOR.line)
    fill:SetAllPoints(frame)
    local tint = Paint(frame, COLOR.track, 0.5)
    tint:SetAllPoints(frame)
    tint:Hide()
    local stripe = Paint(frame, COLOR.muted, 1, "ARTWORK")
    stripe:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    stripe:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    stripe:SetWidth(3)
    local edge = Paint(frame, COLOR.accent, 1, "ARTWORK")
    edge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    edge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    edge:SetHeight(2)
    edge:Hide()
    local name = Text(frame, 12, COLOR.text)
    name:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -7)
    name:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
    local count = Text(frame, 10.5, COLOR.muted)
    count:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -23)
    count:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
    seg = { frame = frame, fill = fill, stripe = stripe, edge = edge, name = name, count = count }
    frame:SetScript("OnClick", function()
        if seg.key then onToggle(seg.key) end
    end)
    frame:HookScript("OnEnter", function()
        if seg.tip then Kit.ShowTip(frame, seg.tipTitle, seg.tip) end
    end)
    frame:HookScript("OnLeave", Kit.HideTip)
    FX.Hover(frame, tint)
    pool[index] = seg
    return seg
end

function Profile:BindSegments(pool, parent, blocks, picked, onToggle, tips)
    for index, block in ipairs(blocks) do
        local seg = self:AcquireSegment(pool, index, parent, onToggle)
        local title, count, color = BlockLabel(block)
        seg.key = block.key
        seg.weight = block.weight
        seg.tipTitle = title
        seg.tip = tips and tips[block.key] or nil
        SetIf(seg.name, "cached", title)
        SetIf(seg.count, "cached", count)
        Tint(seg.stripe, color)
        local on = picked[block.key] == true
        seg.edge:SetShown(on)
        Tint(seg.fill, on and COLOR.accent or COLOR.line, on and 0.22 or 1)
        Tint(seg.name, on and COLOR.accent or COLOR.text)
        seg.frame:Show()
    end
    for index = #blocks + 1, #pool do
        pool[index].key = nil
        pool[index].frame:Hide()
    end
end

local function PlaceSegments(pool, count, card, x, y, width)
    if count == 0 then return y end
    local total = 0
    for index = 1, count do total = total + pool[index].weight end
    local room = width - SEG_GAP * (count - 1)
    local extra = room - SEG_MIN * count
    if extra >= 0 then
        local cursor = x
        for index = 1, count do
            local seg = pool[index]
            local size = math.floor(SEG_MIN + extra * seg.weight / total)
            if index == count then size = x + width - cursor end
            seg.frame:ClearAllPoints()
            seg.frame:SetPoint("TOPLEFT", card.frame, "TOPLEFT", cursor, -y)
            seg.frame:SetWidth(size)
            cursor = cursor + size + SEG_GAP
        end
        return y + SEG_HEIGHT
    end
    local perRow = math.max(1, math.floor((width + SEG_GAP) / (SEG_MIN + SEG_GAP)))
    local size = math.floor((width - SEG_GAP * (perRow - 1)) / perRow)
    for index = 1, count do
        local column = (index - 1) % perRow
        local line = math.floor((index - 1) / perRow)
        local frame = pool[index].frame
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", card.frame, "TOPLEFT", x + column * (size + SEG_GAP), -(y + line * (SEG_HEIGHT + SEG_GAP)))
        frame:SetWidth(size)
    end
    return y + math.ceil(count / perRow) * (SEG_HEIGHT + SEG_GAP) - SEG_GAP
end

function Profile:BlockTips()
    local tips, names = {}, self.spec.trackerNames(self.sel)
    for _, block in ipairs(self.exportBlocks) do
        if block.indices then
            local list = {}
            for _, index in ipairs(block.indices) do list[#list + 1] = names[index] end
            tips[block.key] = table.concat(list, ", ")
        end
    end
    tips.display = "Timer text, border timer, cooldown text, ready text and animation quality."
    tips.layout = "Icon sizes and positions. On their own they only move spells the receiver already tracks."
    return tips
end

function Profile:BlockSummary()
    local parts, spells = {}, 0
    for _, block in ipairs(self.exportBlocks) do
        if self.blockPicked[block.key] then
            if block.class then
                spells = spells + block.weight
                parts[#parts + 1] = block.class
            elseif block.key == "display" then
                parts[#parts + 1] = "display"
            else
                parts[#parts + 1] = "layout"
            end
        end
    end
    if #parts == 0 then return "Pick at least one block above.", false end
    return table.concat(parts, ", ") .. (spells > 0 and (" \194\183 " .. spells .. (spells == 1 and " spell" or " spells")) or ""), true
end

function Profile:ToggleExportBlock(key)
    self.blockPicked[key] = not self.blockPicked[key] or nil
    self.blockText = nil
    self:BindBlocks()
    self:Layout()
end

function Profile:ToggleImportBlock(key)
    self.inPicked[key] = not self.inPicked[key] or nil
    self:BindBlocks()
    self:Layout()
end

function Profile:SetBlockMode(mode)
    if self.blockMode == mode then return end
    self.blockMode = mode
    self.armed = nil
    self:BindBlocks()
    self:Layout()
end

function Profile:RunBlockExport()
    local text = self.spec.trackerExport(self.sel, self.blockPicked)
    self.blockText = text
    self:BindBlocks()
    self:Layout()
    if text then
        self.blockOut:SetFocus()
        self.blockOut:HighlightText()
        self:Toast("Blocks ready to copy")
    end
end

function Profile:SetBlockHint(text, bad)
    SetIf(self.blockHint, "cached", text)
    Tint(self.blockHint, bad and DANGER or COLOR.muted)
end

function Profile:ReadBlocks()
    local clean, message = self.spec.trackerDecode(self.blockIn:GetText())
    if not clean then
        self.incoming = nil
        self:SetBlockHint(message, true)
        FX.Shake(self.blockIn)
        self:BindBlocks()
        self:Layout()
        return
    end
    self.incoming = clean
    self.inPicked, self.choices = {}, {}
    for _, block in ipairs(SA_TrackerBlocks.Incoming(clean)) do self.inPicked[block.key] = true end
    local note = clean.dropped > 0 and (" " .. clean.dropped .. " invalid entries were skipped.") or ""
    self:SetBlockHint("Text read. Changes go into " .. self.current .. "." .. note, false)
    self.blockIn:ClearFocus()
    self:BindBlocks()
    self:Layout()
end

function Profile:SetAllChoices(value)
    for _, row in ipairs(self.blockRows or {}) do
        if row.kind ~= "skip" then self.choices[row.id] = value end
    end
    self:BindBlocks()
end

function Profile:ApplyBlocks(replace)
    if not self.incoming then return end
    if replace and not self:Arm("replace") then return end
    local result = self.spec.trackerApply(self.incoming, self.inPicked, self.choices, replace)
    self.armed = nil
    self.choices = {}
    self:Toast(self.current .. ": " .. SA_TrackerBlocks.ResultText(result, replace))
    self:Refresh(true)
    self:BindBlocks()
    self:Layout()
end

function Profile:AcquireDiffRow(index)
    local row = self.diffRows[index]
    if row then return row end
    local parent = self.blocksCard.frame
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(DIFF_ROW)
    local line = Paint(frame, COLOR.line, 0.6)
    line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    line:SetHeight(1)
    local dot = Paint(frame, COLOR.muted, 1, "ARTWORK")
    dot:SetSize(8, 8)
    dot:SetPoint("LEFT", frame, "LEFT", 2, 0)
    local name = Text(frame, 11.5, COLOR.text)
    local mine = Text(frame, 11, COLOR.muted)
    local incoming = Text(frame, 11, WARN)
    local choice = Kit.MakeButton(frame, "Take", function()
        local current = row.id and self.choices[row.id] == "keep"
        self.choices[row.id] = current and "take" or "keep"
        self:BindBlocks()
    end)
    choice.frame:SetHeight(18)
    row = { frame = frame, dot = dot, name = name, mine = mine, incoming = incoming, choice = choice }
    self.diffRows[index] = row
    return row
end

local function RowName(row)
    if row.setting then return SA_TrackerBlocks.DISPLAY_LABELS[row.setting] or row.setting end
    local name = SA_COMPAT.GetSpellInfo(row.spellID) or ("Spell " .. tostring(row.spellID))
    if row.kind == "new" then return name .. "  (new)" end
    if row.kind == "skip" then return name .. "  (not tracked)" end
    return name
end

function Profile:BindDiff()
    local rows = self.incoming and self.spec.trackerDiff(self.incoming, self.inPicked) or {}
    self.blockRows = rows
    local taking, offered = 0, 0
    for index, data in ipairs(rows) do
        local row = self:AcquireDiffRow(index)
        row.id = data.id
        row.kind = data.kind
        Tint(row.dot, data.class and (BLOCK_CLASS_COLORS[data.class] or BLOCK_CLASS_COLORS.Other) or COLOR.muted)
        SetIf(row.name, "cached", RowName(data))
        SetIf(row.mine, "cached", data.mine or (data.kind == "new" and "not tracked" or ""))
        SetIf(row.incoming, "cached", data.kind == "skip" and "skipped: only tracked spells move" or (data.incoming or ""))
        Tint(row.incoming, data.kind == "new" and COLOR.on or data.kind == "skip" and COLOR.muted or WARN)
        if data.kind == "skip" then
            row.choice.frame:Hide()
        else
            offered = offered + 1
            local keep = self.choices[data.id] == "keep"
            if not keep then taking = taking + 1 end
            SetLabel(row.choice, keep and (data.kind == "new" and "Skip" or "Keep mine") or (data.kind == "new" and "Add" or "Take"))
            Tint(row.choice.label, keep and COLOR.muted or COLOR.accent)
            row.choice.frame:Show()
        end
        row.frame:Show()
    end
    for index = #rows + 1, #self.diffRows do
        self.diffRows[index].id = nil
        self.diffRows[index].frame:Hide()
    end
    if #rows == 0 then
        SetIf(self.diffCaption, "cached", "Nothing would change: " .. (self.current or "") .. " already matches the picked blocks.")
    else
        SetIf(self.diffCaption, "cached", #rows .. (#rows == 1 and " difference" or " differences") .. " \194\183 " .. taking .. " of " .. offered .. " will be applied by Merge")
    end
end

function Profile:BindBlocks()
    if not self.blocksCard then return end
    local exporting = self.blockMode ~= "import"
    SetIf(self.blockScope, "cached", "Export from " .. (self.sel or "") .. " (picked above) \194\183 import into " .. (self.current or "") .. " (active). Nothing else in either profile changes.")
    Tint(self.exportTab.label, exporting and COLOR.accent or COLOR.muted)
    Tint(self.importTab.label, exporting and COLOR.muted or COLOR.accent)
    self.exportBlocks = self.spec.trackerBlocks(self.sel)
    for key in pairs(self.blockPicked) do
        local known = false
        for _, block in ipairs(self.exportBlocks) do if block.key == key then known = true end end
        if not known then self.blockPicked[key] = nil end
    end
    if exporting then
        self:BindSegments(self.exportSegs, self.blocksCard.frame, self.exportBlocks, self.blockPicked, function(key) self:ToggleExportBlock(key) end, self:BlockTips())
    else
        self:BindSegments(self.exportSegs, self.blocksCard.frame, {}, {}, nil)
    end
    local summary, any = self:BlockSummary()
    SetIf(self.blockSummary, "cached", summary)
    Enable(self.blockGo, any)
    self.blockOut:SetText(self.blockText or "")
    local incomingBlocks = (not exporting and self.incoming) and SA_TrackerBlocks.Incoming(self.incoming) or {}
    self:BindSegments(self.importSegs, self.blocksCard.frame, incomingBlocks, self.inPicked, function(key) self:ToggleImportBlock(key) end)
    if not exporting and self.incoming then self:BindDiff() else
        for _, row in ipairs(self.diffRows) do row.frame:Hide() end
    end
    SetLabel(self.mergeButton, "Merge into " .. (self.current or ""))
    SetLabel(self.replaceButton, self.armed == "replace" and "Really replace?" or "Replace picked blocks")
    local anyIn = next(self.inPicked) ~= nil
    Enable(self.mergeButton, anyIn)
    Enable(self.replaceButton, anyIn)
end

function Profile:BuildBlocksCard(parent)
    local card = NewCard(parent, "Spell Tracker blocks")
    local frame = card.frame
    self.blocksCard = card
    self.blockMode = "export"
    self.blockPicked, self.inPicked, self.choices = {}, {}, {}
    self.exportSegs, self.importSegs, self.diffRows = {}, {}, {}
    self.blockScope = Text(frame, 11, COLOR.muted)
    self.exportTab = Kit.MakeButton(frame, "Export", function() self:SetBlockMode("export") end)
    self.importTab = Kit.MakeButton(frame, "Import", function() self:SetBlockMode("import") end)
    self.blockSummary = Text(frame, 11, COLOR.muted)
    self.blockGo = Kit.MakeButton(frame, "Export picked blocks", function() self:RunBlockExport() end)
    local out = NewEditBox(frame, 24, 12)
    out:SetMaxLetters(Transfer.MAX_LENGTH)
    out:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    out:SetScript("OnTextChanged", function(box, user)
        if user then box:SetText(self.blockText or "") box:HighlightText() end
    end)
    self.blockOut = out
    self.blockOutHint = Text(frame, 11, COLOR.muted)
    self.blockOutHint:SetText(BLOCK_EXPORT_HINT)
    local input = NewEditBox(frame, 24, 12)
    input:SetMaxLetters(Transfer.MAX_LENGTH)
    input:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    input:SetScript("OnEnterPressed", function() self:ReadBlocks() end)
    self.blockIn = input
    self.blockRead = Kit.MakeButton(frame, "Read text", function() self:ReadBlocks() end)
    self.blockHint = Text(frame, 11, COLOR.muted)
    self.blockHint:SetText(BLOCK_IMPORT_HINT)
    self.diffCaption = Text(frame, 11, COLOR.muted)
    self.takeAll = Kit.MakeButton(frame, "Take all", function() self:SetAllChoices("take") end)
    self.keepAll = Kit.MakeButton(frame, "Keep all mine", function() self:SetAllChoices("keep") end)
    self.mergeButton = Kit.MakeButton(frame, "Merge", function() self:ApplyBlocks(false) end)
    self.replaceButton = Kit.MakeButton(frame, "Replace picked blocks", function() self:ApplyBlocks(true) end)
    self.replaceButton.frame:HookScript("OnEnter", function()
        Kit.ShowTip(self.replaceButton.frame, "Replace picked blocks", "Removes your spells of the picked classes and puts the imported ones in their place. Picked display settings are replaced too. Click twice.")
    end)
    self.replaceButton.frame:HookScript("OnLeave", Kit.HideTip)
    local exportOnly = { self.blockSummary, self.blockGo.frame, out, self.blockOutHint }
    local importOnly = { input, self.blockRead.frame, self.blockHint, self.diffCaption, self.takeAll.frame, self.keepAll.frame, self.mergeButton.frame, self.replaceButton.frame }
    card.content = function(_, width, y)
        local inner = width - 24
        local exporting = self.blockMode ~= "import"
        for _, region in ipairs(exportOnly) do region:SetShown(exporting) end
        for _, region in ipairs(importOnly) do region:SetShown(not exporting) end
        self.blockScope:ClearAllPoints()
        self.blockScope:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -y)
        self.blockScope:SetWidth(inner)
        y = y + 20
        self.exportTab.frame:ClearAllPoints()
        self.exportTab.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -y)
        self.importTab.frame:ClearAllPoints()
        self.importTab.frame:SetPoint("TOPLEFT", self.exportTab.frame, "TOPRIGHT", 6, 0)
        y = y + 32
        if exporting then
            y = PlaceSegments(self.exportSegs, #self.exportBlocks, card, 12, y, inner) + 10
            self.blockGo.frame:ClearAllPoints()
            self.blockGo.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -y)
            self.blockSummary:ClearAllPoints()
            self.blockSummary:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -(y + 4))
            self.blockSummary:SetPoint("RIGHT", self.blockGo.frame, "LEFT", -10, 0)
            y = y + 30
            local hasText = self.blockText ~= nil
            out:SetShown(hasText)
            self.blockOutHint:SetShown(hasText)
            if hasText then
                out:ClearAllPoints()
                out:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -y)
                out:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
                self.blockOutHint:ClearAllPoints()
                self.blockOutHint:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -(y + 30))
                self.blockOutHint:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
                y = y + 50
            end
            return y
        end
        self.blockRead.frame:ClearAllPoints()
        self.blockRead.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -(y + 1))
        input:ClearAllPoints()
        input:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -y)
        input:SetPoint("RIGHT", self.blockRead.frame, "LEFT", -8, 0)
        self.blockHint:ClearAllPoints()
        self.blockHint:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -(y + 30))
        self.blockHint:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
        y = y + 52
        local reading = self.incoming ~= nil
        for _, region in ipairs({ self.diffCaption, self.takeAll.frame, self.keepAll.frame, self.mergeButton.frame, self.replaceButton.frame }) do
            region:SetShown(reading)
        end
        if not reading then return y end
        local count = 0
        for _, seg in ipairs(self.importSegs) do if seg.key then count = count + 1 end end
        y = PlaceSegments(self.importSegs, count, card, 12, y, inner) + 10
        self.keepAll.frame:ClearAllPoints()
        self.keepAll.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -y)
        self.takeAll.frame:ClearAllPoints()
        self.takeAll.frame:SetPoint("TOPRIGHT", self.keepAll.frame, "TOPLEFT", -6, 0)
        self.diffCaption:ClearAllPoints()
        self.diffCaption:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -(y + 4))
        self.diffCaption:SetPoint("RIGHT", self.takeAll.frame, "LEFT", -10, 0)
        y = y + 28
        local nameWidth = math.floor(inner * 0.28)
        local sideWidth = math.floor((inner - nameWidth - 110) / 2)
        for _, row in ipairs(self.diffRows) do
            if row.id then
                row.frame:ClearAllPoints()
                row.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -y)
                row.frame:SetWidth(inner)
                row.name:ClearAllPoints()
                row.name:SetPoint("LEFT", row.frame, "LEFT", 16, 0)
                row.name:SetWidth(nameWidth - 18)
                row.mine:ClearAllPoints()
                row.mine:SetPoint("LEFT", row.frame, "LEFT", nameWidth + 4, 0)
                row.mine:SetWidth(sideWidth - 8)
                row.incoming:ClearAllPoints()
                row.incoming:SetPoint("LEFT", row.frame, "LEFT", nameWidth + sideWidth + 4, 0)
                row.incoming:SetWidth(sideWidth - 8)
                row.choice.frame:ClearAllPoints()
                row.choice.frame:SetPoint("RIGHT", row.frame, "RIGHT", 0, 0)
                y = y + DIFF_ROW
            end
        end
        y = y + 10
        self.mergeButton.frame:ClearAllPoints()
        self.mergeButton.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -y)
        self.replaceButton.frame:ClearAllPoints()
        self.replaceButton.frame:SetPoint("TOPLEFT", self.mergeButton.frame, "TOPRIGHT", 6, 0)
        return y + 30
    end
    return card
end

function Profile:BuildView()
    local view = NewView(self.body)
    self.view = view
    local child = view.child
    self.heading = NewHeading(child, "PROFILES")
    self:BuildStage(child)
    self.transferCard = self:BuildTransferCard(child)
    self.newHeading = NewHeading(child, "NEW PROFILE")
    self.newCard = self:BuildNewCard(child)
    self.blocksHeading = NewHeading(child, "SPELL TRACKER BLOCKS")
    self:BuildBlocksCard(child)
    self.moreDivider = NewDivider(child, "MORE OPTIONS")
    self.activeCard = self:BuildActiveCard(child)
    view.onWidth = function(width)
        self.width = width
        self:Layout()
    end
end

function Profile:Layout()
    local width = self.width
    if not width then return end
    local child = self.view.child
    self.heading:ClearAllPoints()
    self.heading:SetPoint("TOPLEFT", child, "TOPLEFT", 4, 0)
    local y = 22
    y = y + self:LayoutStage(width, y) + 10
    y = self:PlacePills(width, y) + 14
    if self.transfer then
        y = y + PlaceCard(self.transferCard, child, 0, y, width) + 12
    end
    self.newHeading:ClearAllPoints()
    self.newHeading:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -y)
    y = y + 22
    y = y + PlaceCard(self.newCard, child, 0, y, width) + 12
    self.blocksHeading:ClearAllPoints()
    self.blocksHeading:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -y)
    y = y + 22
    y = y + PlaceCard(self.blocksCard, child, 0, y, width) + 12
    y = PlaceDivider(self.moreDivider, child, width, y)
    y = y + PlaceCard(self.activeCard, child, 0, y, width)
    self.view:SetContentHeight(y + 20)
end

function Profile:BuildHeader()
    local frame = self.frame
    self.title = Text(frame, 20, COLOR.accent)
    self.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -2)
    self.title:SetText("Profiles")
    self.sub = Text(frame, 11.5, COLOR.muted)
    self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
    self.sub:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    self.toast = CreateFrame("Frame", nil, frame)
    self.toast:SetHeight(26)
    self.toast:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    self.toast:SetFrameLevel(frame:GetFrameLevel() + 40)
    local fill = Paint(self.toast, { 0.02, 0.03, 0.04 })
    fill:SetAllPoints(self.toast)
    Outline(self.toast, COLOR.accent)
    self.toastText = Text(self.toast, 12, COLOR.text, "CENTER")
    self.toastText:SetAllPoints(self.toast)
    self.toast:Hide()
end

function Profile:Refresh(recompute)
    local spec = self.spec
    if not spec.db() then return end
    local previous = #self.names
    self.current = spec.current()
    self.names = Model.Sorted(spec.names(), self.names)
    self.existing = Model.Set(self.names)
    self.newDefault = spec.newDefault()
    if recompute or not self.ready then
        self.ready = true
        self.stamp = self.stamp + 1
        spec.characters(self.chars)
    end
    if not self.sel or not self.existing[self.sel] then self.sel = self.current end
    SetIf(self.sub, "cached", Model.HeaderText(self.current, #self.names))
    self:BindPills()
    self:BindStage()
    self:BindActive()
    self:BindBlocks()
    self:ValidateName()
    if #self.names ~= previous or not self.laidOut then
        self.laidOut = true
        self:Layout()
    end
end

function Profile:Reset()
    self.sel = nil
    self.armed = nil
    if self.blocksCard then
        self.blockMode = "export"
        self.blockPicked, self.inPicked, self.choices = {}, {}, {}
        self.blockText, self.incoming = nil, nil
        self.blockIn:SetText("")
        self:SetBlockHint(BLOCK_IMPORT_HINT, false)
        self.laidOut = false
    end
    if self.renaming then self:EndRename() end
    if self.transfer then
        self:CloseTransfer()
        self.laidOut = false
    end
end

local function BuildPage(spec)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    local page = { frame = frame, spec = spec, pills = {}, names = {}, details = {}, chars = {}, stamp = 0 }
    for name, method in pairs(Profile) do page[name] = method end
    page:BuildHeader()
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -HEADER_HEIGHT)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    page.body = body
    page:BuildView()
    frame:SetScript("OnHide", function()
        page.armed = nil
        if page.renaming then page:EndRename() end
        Kit.HideTip()
    end)
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
    page:Reset()
    page:Refresh(true)
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

SoundAlerter.ProfilePage = { Get = GetPage }

do
function SoundAlerter:BuildProfileOptions()
    local spec = self.profileSpec
    if not spec then
        local function database() return SoundAlerter.db1 end
        local function profileOf(name)
            local db = database()
            return name == db:GetCurrentProfile() and db.profile or db.sv.profiles[name]
        end
        local classLookup
        local function classOf(spellID)
            if not classLookup then
                classLookup = SA_TrackerModel.BuildLookup(SoundAlerter.spellList or SoundAlerterSpells, SoundAlerterSpellMeta)
            end
            local _, token = UnitClass("player")
            return SA_TrackerModel.ClassOf(spellID, classLookup, token)
        end
        local trackerDefaults = dbDefaults.profile.spellTracker or {}
        local function trackerOf(name)
            local profile = profileOf(name)
            local tracker = type(profile) == "table" and profile.spellTracker
            return type(tracker) == "table" and tracker or { icons = {} }
        end
        spec = {
            db = function() return SoundAlerter.db1 and SoundAlerter.db1.profile end,
            names = function() return (database():GetProfiles()) end,
            current = function() return database():GetCurrentProfile() end,
            newDefault = function() return Model.NewCharacterDefault(database().sv) or "Default" end,
            setNewDefault = function(name) Model.SetNewCharacterDefault(database().sv, name) end,
            summary = function(name, into)
                local voice = SA_VoiceModel.Shared(SoundAlerter.spellList or SoundAlerterSpells, SoundAlerterSpellMeta)
                local profile = profileOf(name) or {}
                return Model.Overview(profile, dbDefaults.profile, Model.Summary(profile, dbDefaults.profile, voice, into))
            end,
            characters = function(into) return Model.Characters(database().sv.profileKeys, into) end,
            use = function(name) database():SetProfile(name) end,
            create = function(name) database():SetProfile(name) end,
            copy = function(name) database():CopyProfile(name) end,
            delete = function(name)
                local db = database()
                db:DeleteProfile(name)
                Model.ForgetDefault(db.sv, name)
            end,
            reset = function() database():ResetProfile() end,
            rename = function(old, new)
                local db = database()
                local wasCurrent = old == db:GetCurrentProfile()
                if Model.Rename(db.sv, old, new) and wasCurrent then db.keys.profile = new end
            end,
            duplicate = function(source, target)
                return SA_ProfileTransfer.Duplicate(database().sv, source, target, dbDefaults.profile)
            end,
            export = function(name)
                local profile = profileOf(name)
                return profile and SA_ProfileTransfer.Encode(name, profile, dbDefaults.profile)
            end,
            importText = function(text)
                local name, profile = SA_ProfileTransfer.Decode(text, dbDefaults.profile)
                if not name then return nil, profile end
                local db = database()
                local unique = Model.UniqueName(name, Model.Set((db:GetProfiles())))
                db.sv.profiles[unique] = profile
                return unique
            end,
            trackerBlocks = function(name) return SA_TrackerBlocks.Build(trackerOf(name), classOf) end,
            trackerNames = function(name)
                local names = {}
                for index, icon in ipairs(trackerOf(name).icons or {}) do
                    names[index] = icon.spellID and (SA_COMPAT.GetSpellInfo(icon.spellID) or ("Spell " .. icon.spellID)) or "?"
                end
                return names
            end,
            trackerExport = function(name, picked)
                return SA_TrackerBlocks.Export(trackerOf(name), trackerDefaults, classOf, picked)
            end,
            trackerDecode = function(text) return SA_TrackerBlocks.Decode(text) end,
            trackerDiff = function(clean, picked)
                return SA_TrackerBlocks.Diff(trackerOf(database():GetCurrentProfile()), clean, picked, trackerDefaults)
            end,
            trackerApply = function(clean, picked, choices, replace)
                local profile = database().profile
                profile.spellTracker = profile.spellTracker or { icons = {} }
                local tracker = profile.spellTracker
                local icons, display, result = SA_TrackerBlocks.Apply(tracker, clean, picked, choices, replace, classOf, trackerDefaults)
                tracker.icons = icons
                for key, value in pairs(display) do tracker[key] = value end
                if SoundAlerter.SpellTracker and SoundAlerter.SpellTracker.ReloadIcons then
                    SoundAlerter.SpellTracker:ReloadIcons()
                end
                return result
            end,
        }
        self.profileSpec = spec
    end
    return {
        type = 'group',
        name = "Profiles",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        desc = "Switch, copy, create, duplicate, rename, share, delete and reset the settings profiles.",
        order = -1,
        args = {
            page = {
                type = 'description',
                name = "Profiles could not draw its page.",
                dialogControl = "SoundAlerterProfilePage",
                arg = spec,
                order = 1,
            },
        },
    }
end
end
