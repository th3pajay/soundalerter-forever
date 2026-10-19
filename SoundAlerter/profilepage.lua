local SoundAlerter = SoundAlerter
local AceGUI = LibStub("AceGUI-3.0")
local Kit = SoundAlerter.Page.Kit
local Model = SA_ProfileModel
local FX = SA_MenuFX

local COLOR, Paint, Outline, Text, Tint = Kit.COLOR, Kit.Paint, Kit.Outline, Kit.Text, Kit.Tint
local NewView, NewHeading, NewDivider, PlaceDivider, NewCard, PlaceCard = Kit.NewView, Kit.NewHeading, Kit.NewDivider, Kit.PlaceDivider, Kit.NewCard, Kit.PlaceCard

local WIDGET = "SoundAlerterProfilePage"
local HEADER_HEIGHT = 52
local ROW_HEIGHT = 46
local TOAST_SECONDS = 1.5
local DANGER = { 1, 0.36, 0.36 }

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

function Profile:Arm(key)
    if self.armed == key then
        self.armed = nil
        self:BindRows()
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
                self:BindRows()
                self:BindActive()
            end
        end)
    end
    self:BindRows()
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

function Profile:AcquireRow(index)
    local row = self.rows[index]
    if row then return row end
    local frame = CreateFrame("Frame", nil, self.profilesCard.frame)
    frame:SetHeight(ROW_HEIGHT)
    frame:EnableMouse(true)
    local tint = Paint(frame, COLOR.line, 0.5)
    tint:SetAllPoints(frame)
    tint:Hide()
    local rule = Paint(frame, COLOR.line, 0.55)
    rule:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    local flash = Paint(frame, COLOR.accent, 0.3, "BORDER")
    flash:SetAllPoints(frame)
    flash:Hide()
    row = { frame = frame, flash = flash }
    row.name = Text(frame, 13.5, COLOR.text)
    row.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
    row.summary = Text(frame, 11.5, COLOR.muted)
    row.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -27)
    row.currentTag = NewTag(frame, "active", COLOR.on)
    row.defaultTag = NewTag(frame, "new characters", COLOR.accent)

    row.delete = Kit.MakeButton(frame, "Delete", function()
        local name = row.profile
        if not name or not Model.CanDelete(name, self.current) then return end
        if not self:Arm("delete:" .. name) then return end
        self.spec.delete(name)
        self:Toast("Deleted " .. name)
        self:Refresh(true)
    end)
    row.delete.frame:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    row.copy = Kit.MakeButton(frame, "Copy here", function()
        local name = row.profile
        if not name then return end
        if not self:Arm("copy:" .. name) then return end
        self.spec.copy(name)
        self:Toast("Copied settings from " .. name)
        self:Refresh(true)
        FX.Flash(row.flash)
    end)
    row.copy.frame:SetPoint("RIGHT", row.delete.frame, "LEFT", -6, 0)
    row.use = Kit.MakeButton(frame, "Use", function()
        local name = row.profile
        if not name then return end
        self.armed = nil
        self.spec.use(name)
        self:Toast("Now using " .. name)
        self:Refresh(false)
    end)
    row.use.frame:SetPoint("RIGHT", row.copy.frame, "LEFT", -6, 0)
    row.copy.frame:HookScript("OnEnter", function()
        if row.profile then Kit.ShowTip(row.copy.frame, "Copy settings here", "Overwrites the active profile with the settings of " .. row.profile .. ".") end
    end)
    row.copy.frame:HookScript("OnLeave", Kit.HideTip)
    SA_MenuFX.Hover(frame, tint)
    self.rows[index] = row
    return row
end

function Profile:BindRow(row, name)
    row.profile = name
    local active = name == self.current
    SetIf(row.name, "cached", name)
    SetIf(row.summary, "cached", self.summaries[name] or "")
    row.currentTag:SetShown(active)
    row.defaultTag:SetShown(name == self.newDefault)
    local x = 10 + row.name:GetStringWidth() + 10
    row.currentTag:ClearAllPoints()
    row.currentTag:SetPoint("TOPLEFT", row.frame, "TOPLEFT", x, -8)
    if active then x = x + row.currentTag:GetWidth() + 6 end
    row.defaultTag:ClearAllPoints()
    row.defaultTag:SetPoint("TOPLEFT", row.frame, "TOPLEFT", x, -8)
    row.use.frame:SetShown(not active)
    row.copy.frame:SetShown(not active)
    SetLabel(row.copy, self.armed == "copy:" .. name and "Overwrite?" or "Copy here")
    SetLabel(row.delete, self.armed == "delete:" .. name and "Really delete?" or "Delete")
    Enable(row.delete, Model.CanDelete(name, self.current))
    row.frame:Show()
end

function Profile:BindRows()
    for index, name in ipairs(self.names) do
        self:BindRow(self:AcquireRow(index), name)
    end
    for index = #self.names + 1, #self.rows do
        self.rows[index].profile = nil
        self.rows[index].frame:Hide()
    end
end

function Profile:PlaceRows(card, width, y)
    for index = 1, #self.names do
        local row = self:AcquireRow(index)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 8, -(y + (index - 1) * ROW_HEIGHT))
        row.frame:SetWidth(width - 16)
    end
    return y + #self.names * ROW_HEIGHT
end

function Profile:ValidateName()
    local text = self.nameBox:GetText()
    local ok, message = Model.Validate(text, self.existing or {})
    local clean = Model.Clean(text)
    self.nameValid = ok
    Enable(self.create, ok)
    if clean == "" or ok then
        SetIf(self.nameHint, "cached", "A new profile starts from the defaults. Use Copy here to start from another profile instead.")
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
    self:Toast("Created and using " .. clean)
    self:Refresh(true)
end

function Profile:BuildNewCard(parent)
    local card = NewCard(parent, "New profile")
    local box = CreateFrame("EditBox", nil, card.frame)
    box:SetAutoFocus(false)
    box:SetFont(Kit.FONT, 12, "")
    box:SetTextInsets(8, 8, 3, 3)
    box:SetHeight(24)
    local fill = Paint(box, COLOR.line)
    fill:SetAllPoints(box)
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
    self.nameHint = Text(card.frame, 11, COLOR.muted)
    self.nameHint:SetHeight(14)
    card.content = function(frame, width, y)
        self.create.frame:ClearAllPoints()
        self.create.frame:SetPoint("TOPRIGHT", card.frame, "TOPRIGHT", -12, -(y + 1))
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
        self:BindRows()
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
    self.profilesCard = NewCard(child, "Profiles")
    self.profilesCard.content = function(card, width, y) return self:PlaceRows(card, width, y) end
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
    y = y + PlaceCard(self.profilesCard, child, 0, y, width) + 16
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
    if recompute or not self.summaryReady then
        self.summaryReady = true
        for _, name in ipairs(self.names) do
            self.summaries[name] = Model.SummaryText(spec.summary(name))
        end
    end
    SetIf(self.sub, "cached", Model.HeaderText(self.current, #self.names))
    self:BindRows()
    self:BindActive()
    self:ValidateName()
    if #self.names ~= previous or not self.laidOut then
        self.laidOut = true
        self:Layout()
    end
end

local function BuildPage(spec)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    local page = { frame = frame, spec = spec, rows = {}, names = {}, summaries = {} }
    for name, method in pairs(Profile) do page[name] = method end
    page:BuildHeader()
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -HEADER_HEIGHT)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    page.body = body
    page:BuildView()
    frame:SetScript("OnHide", function()
        page.armed = nil
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
        local Model = SA_ProfileModel
        local summary = {}
        local function database() return SoundAlerter.db1 end
        spec = {
            db = function() return SoundAlerter.db1 and SoundAlerter.db1.profile end,
            names = function() return (database():GetProfiles()) end,
            current = function() return database():GetCurrentProfile() end,
            newDefault = function() return Model.NewCharacterDefault(database().sv) or "Default" end,
            setNewDefault = function(name) Model.SetNewCharacterDefault(database().sv, name) end,
            summary = function(name)
                local db = database()
                local profile = name == db:GetCurrentProfile() and db.profile or db.sv.profiles[name]
                local voice = SA_VoiceModel.Shared(SoundAlerter.spellList or SoundAlerterSpells, SoundAlerterSpellMeta)
                return Model.Summary(profile or {}, dbDefaults.profile, voice, summary)
            end,
            use = function(name) database():SetProfile(name) end,
            create = function(name) database():SetProfile(name) end,
            copy = function(name) database():CopyProfile(name) end,
            delete = function(name)
                local db = database()
                db:DeleteProfile(name)
                Model.ForgetDefault(db.sv, name)
            end,
            reset = function() database():ResetProfile() end,
        }
        self.profileSpec = spec
    end
    return {
        type = 'group',
        name = "Profiles",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        desc = "Switch, copy, create, delete and reset the settings profiles.",
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
