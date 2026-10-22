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
            end
        end)
    end
    self:BindStage()
    self:BindActive()
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
    local hadTransfer = self.transfer
    self:CloseTransfer()
    self:BindPills()
    self:BindStage()
    self:BindActive()
    FX.Flash(self.stage.flash)
    if hadTransfer then self:Layout() end
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

function Profile:BuildView()
    local view = NewView(self.body)
    self.view = view
    local child = view.child
    self.heading = NewHeading(child, "PROFILES")
    self:BuildStage(child)
    self.transferCard = self:BuildTransferCard(child)
    self.newHeading = NewHeading(child, "NEW PROFILE")
    self.newCard = self:BuildNewCard(child)
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
    self:ValidateName()
    if #self.names ~= previous or not self.laidOut then
        self.laidOut = true
        self:Layout()
    end
end

function Profile:Reset()
    self.sel = nil
    self.armed = nil
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
