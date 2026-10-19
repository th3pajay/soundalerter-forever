local SoundAlerter = SoundAlerter
local AceGUI = LibStub("AceGUI-3.0")
local Kit = SoundAlerter.Page.Kit
local Model = SA_CustomModel
local List = SA_FinderList
local FX = SA_MenuFX

local COLOR, Paint, Outline, Text, Tint = Kit.COLOR, Kit.Paint, Kit.Outline, Kit.Text, Kit.Tint
local NewView, NewDivider, PlaceDivider, NewCard, PlaceCard = Kit.NewView, Kit.NewDivider, Kit.PlaceDivider, Kit.NewCard, Kit.PlaceCard

local WIDGET = "SoundAlerterCustomPage"
local HEADER_HEIGHT = 52
local RAIL_WIDTH = 230
local RAIL_GAP = 14
local RAIL_ROW = 32
local RAIL_TOP = 44
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local DANGER = { 1, 0.36, 0.36 }

local Custom = {}

local function SetIf(region, key, value)
    if region[key] ~= value then
        region[key] = value
        region:SetText(value)
    end
end

local function SetLabel(button, text)
    if button.shownText ~= text then
        button.shownText = text
        button.label:SetText(text)
        button.frame:SetWidth(math.max(70, button.label:GetStringWidth() + 24))
    end
end

function Custom:Custom()
    return self.spec.custom()
end

function Custom:Alert()
    return self.key and self:Custom()[self.key] or nil
end

function Custom:Arm(key)
    if self.armed == key then
        self.armed = nil
        return true
    end
    self.armed = key
    self.armToken = (self.armToken or 0) + 1
    local token = self.armToken
    if C_Timer and C_Timer.After then
        C_Timer.After(4, function()
            if self.armToken == token and self.armed == key then
                self.armed = nil
                self:BindEditor()
            end
        end)
    end
    self:BindEditor()
    return false
end

function Custom:Write(field, value)
    local alert = self:Alert()
    if not alert then return end
    alert[field] = value
    if Model.TouchesTracking(field) then self.spec.invalidate() end
end

function Custom:Rename(value)
    local ok, message, newKey = Model.Rename(self:Custom(), self.key, value)
    if not ok then
        if message then self.spec.print(message) end
        FX.Shake(self.nameRow.control.frame)
        return
    end
    self.key = newKey
    self:Resort()
end

function Custom:CommitSpellId(value)
    local alert = self:Alert()
    if not alert then return end
    local ok, message = Model.CommitSpellId(alert, value, self.spec.lookup)
    if not ok then
        if message then self.spec.print(message) end
        FX.Shake(self.spellRow.control.frame)
        return
    end
    self.spec.invalidate()
end

function Custom:ToggleEvent(event)
    local alert = self:Alert()
    if not alert then return end
    Model.SetEvent(alert, event, not (alert.eventtype and alert.eventtype[event]))
    self.spec.invalidate()
    self:BindEditor()
    self:BindRail()
end

function Custom:Resort()
    self.keys = Model.Sorted(self:Custom(), self.keys)
    local alert = self:Alert()
    if not alert and self.keys[1] then self.key = self.keys[1] end
    if #self.keys == 0 then self.key = nil end
    self.top = List.ClampTop(self.top, #self.keys, self.railRows)
    self:BindRail()
    self:BindEditor()
    self:BindHeader()
end

function Custom:Select(key)
    if key == self.key then return end
    self.key = key
    self.armed = nil
    local index
    for position, candidate in ipairs(self.keys) do
        if candidate == key then index = position end
    end
    if index then self.top = List.Reveal(self.top, index, self.railRows) end
    self:BindRail()
    self:BindEditor()
    FX.SlideIn(self.editor.frame, self.host)
end

function Custom:AddAlert()
    local custom = self:Custom()
    local name = self.spec.newName()
    local alert = Model.Add(custom, name, self.spec.everything())
    if not alert then return end
    self.spec.invalidate()
    self.keys = Model.Sorted(custom, self.keys)
    self.key = nil
    self:Select(name)
    self:BindHeader()
    self:Layout()
end

function Custom:RemoveAlert()
    local custom = self:Custom()
    local key = self.key
    if not key or not self:Arm("remove") then return end
    Model.Remove(custom, key)
    self.spec.invalidate()
    local index = 1
    for position, candidate in ipairs(self.keys) do
        if candidate == key then index = position end
    end
    self.keys = Model.Sorted(custom, self.keys)
    self.key = self.keys[math.min(index, #self.keys)]
    self:Resort()
    self:Layout()
end

function Custom:BuildRail()
    local rail = CreateFrame("Frame", nil, self.body)
    rail:SetWidth(RAIL_WIDTH)
    rail:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, 0)
    rail:SetPoint("BOTTOMLEFT", self.body, "BOTTOMLEFT", 0, 0)
    rail:EnableMouseWheel(true)
    self.rail = rail
    self.newButton = Kit.MakeButton(rail, "New alert", function() self:AddAlert() end)
    self.newButton.frame:SetWidth(RAIL_WIDTH)
    self.newButton.frame:SetHeight(26)
    self.newButton.frame:SetPoint("TOPLEFT", rail, "TOPLEFT", 0, 0)
    self.railRows = 10
    self.rows = {}
    self.scrollbar = Kit.MakeScrollbar(rail, function(fraction)
        local count = #self.keys
        local range = count - self.railRows
        if range <= 0 then return end
        local top = List.ClampTop(1 + math.floor(fraction * range + 0.5), count, self.railRows)
        if top ~= self.top then
            self.top = top
            self:BindRail()
        end
    end, 0, RAIL_TOP)
    self.thumb = self.scrollbar.strip
    self.empty = Text(rail, 12, COLOR.muted)
    self.empty:SetPoint("TOPLEFT", rail, "TOPLEFT", 10, -(RAIL_TOP + 12))
    self.empty:SetWidth(RAIL_WIDTH - 20)
    if self.empty.SetWordWrap then self.empty:SetWordWrap(true) end
    self.empty:SetJustifyV("TOP")
    self.empty:SetText("No custom alerts yet. Create one to play your own sound for any spell event.")
    rail:SetScript("OnMouseWheel", function(_, delta)
        self.top = List.Wheel(self.top or 1, delta, #self.keys, self.railRows)
        self:BindRail()
    end)
    rail:SetScript("OnSizeChanged", function(_, _, height)
        self.railRows = math.max(1, math.floor((height - RAIL_TOP) / RAIL_ROW))
        self:BindRail()
    end)
end

function Custom:AcquireRow(index)
    local row = self.rows[index]
    if row then return row end
    local frame = CreateFrame("Button", nil, self.rail)
    frame:SetHeight(RAIL_ROW)
    frame:SetPoint("TOPLEFT", self.rail, "TOPLEFT", 0, -(RAIL_TOP + (index - 1) * RAIL_ROW))
    frame:SetPoint("TOPRIGHT", self.rail, "TOPRIGHT", -12, -(RAIL_TOP + (index - 1) * RAIL_ROW))
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
    icon:SetSize(22, 22)
    icon:SetPoint("LEFT", frame, "LEFT", 10, 0)
    local count = Text(frame, 11, COLOR.muted, "RIGHT")
    count:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    count:SetWidth(24)
    local name = Text(frame, 12.5, COLOR.text)
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    name:SetPoint("RIGHT", count, "LEFT", -6, 0)
    row = { frame = frame, selected = selected, bar = bar, icon = icon, name = name, count = count }
    frame:SetScript("OnClick", function()
        if row.key then self:Select(row.key) end
    end)
    SA_MenuFX.Hover(frame, tint)
    self.rows[index] = row
    return row
end

function Custom:BindRail()
    local custom = self:Custom()
    local count = #self.keys
    self.top = List.ClampTop(self.top, count, self.railRows)
    local exists = custom[self.spec.newName()] ~= nil
    SetLabel(self.newButton, exists and "Rename the New Alert entry" or "New alert")
    self.newButton.frame:SetWidth(RAIL_WIDTH)
    self.newButton.frame:SetAlpha(exists and 0.4 or 1)
    self.newButton.frame:EnableMouse(not exists)
    self.empty:SetShown(count == 0)
    for slot = 1, self.railRows do
        local row = self:AcquireRow(slot)
        local key = self.keys[self.top + slot - 1]
        local alert = key and custom[key]
        if alert then
            row.key = key
            row.icon:SetTexture(self.spec.icon(tonumber(alert.spellid)) or QUESTION)
            SetIf(row.name, "cached", alert.name or key)
            SetIf(row.count, "cached", tostring(Model.EventCount(alert)))
            local on = key == self.key
            row.selected:SetShown(on)
            row.bar:SetShown(on)
            Tint(row.name, on and COLOR.accent or COLOR.text)
            row.frame:Show()
        else
            row.key = nil
            row.frame:Hide()
        end
    end
    for slot = self.railRows + 1, #self.rows do
        self.rows[slot].key = nil
        self.rows[slot].frame:Hide()
    end
    local range = count - self.railRows
    self.scrollbar:Update(range > 0 and (self.top - 1) / range or 0, range > 0 and self.railRows / count or 1)
end

function Custom:AddRow(card, row)
    local page = self
    local entry = Kit.AddRow(card, row, function() page:AfterEdit() end)
    self.entries[#self.entries + 1] = entry
    return entry
end

function Custom:AfterEdit()
    self:BindEditor()
    self:BindRail()
end

function Custom:BuildEditor()
    local host = CreateFrame("Frame", nil, self.body)
    host:SetPoint("TOPLEFT", self.body, "TOPLEFT", RAIL_WIDTH + RAIL_GAP, 0)
    host:SetPoint("BOTTOMRIGHT", self.body, "BOTTOMRIGHT", 0, 0)
    self.host = host
    local view = NewView(host)
    self.editor = view
    local child = view.child
    self.entries = {}
    local spec = self.spec
    local page = self

    self.alertCard = NewCard(child, "Alert")
    self.removeButton = Kit.MakeButton(self.alertCard.frame, "Remove", function() page:RemoveAlert() end)
    self.removeButton.frame:SetPoint("TOPRIGHT", self.alertCard.frame, "TOPRIGHT", -10, -5)
    self.nameRow = self:AddRow(self.alertCard, { kind = "text", label = "Entry name", hint = "The name in the list on the left.", width = 210,
        set = function(value) page:Rename(value) end })

    self.spellCard = NewCard(child, "Spell")
    self.spellRow = self:AddRow(self.spellCard, { kind = "text", label = "Spell ID", hint = "", width = 120, tip = "Visible in the spell tooltip when tooltip spell IDs are enabled. Numbers only.",
        set = function(value) page:CommitSpellId(value) end })
    self.exactRow = self:AddRow(self.spellCard, { kind = "toggle", label = "Use specific spell name", hint = "Use this when a spell has several ranks.",
        set = function(value) page:Write("acceptSpellName", value) end })
    self.nameMatchRow = self:AddRow(self.spellCard, { kind = "text", label = "Spell name to match", indent = 18, width = 190,
        set = function(value) page:Write("spellname", value) end })

    self.soundCard = NewCard(child, "Sound")
    self.soundRow = self:AddRow(self.soundCard, { kind = "text", label = "Sound file", hint = "Put your ogg, mp3 or wav in the CustomSounds folder of the addon.", width = 170, tip = "Place your ogg, mp3 or wav custom sound in the CustomSounds folder in Interface/Addons/SoundAlerter/. A chat alert replaces the sound.",
        button = { label = "Test", onClick = function()
            local alert = page:Alert()
            if alert then spec.play(Model.SoundPath(alert, spec.soundFolder)) end
        end },
        set = function(value) page:Write("soundfilepath", value) end })

    self.chatCard = NewCard(child, "Chat")
    self.chatRow = self:AddRow(self.chatCard, { kind = "toggle", label = "Chat alert", hint = "Say it in chat instead of playing the sound.",
        set = function(value) page:Write("chatAlert", value) end })
    self.chatTextRow = self:AddRow(self.chatCard, { kind = "text", label = "Chat alert text", full = true, tip = "For example #enemy# casted #spell# on me! Use %t when you cast the spell on an enemy.",
        set = function(value) page:Write("chatalerttext", value) end })

    self.eventsCard = NewCard(child, "Events")
    self.chips = {}
    for _, event in ipairs(Model.EVENTS) do
        local key = event[1]
        local chip = Kit.MakeChip(self.eventsCard.frame, event[2], function() page:ToggleEvent(key) end)
        chip.key = key
        chip.frame:HookScript("OnEnter", function() Kit.ShowTip(chip.frame, event[2], spec.eventTip(key)) end)
        chip.frame:HookScript("OnLeave", Kit.HideTip)
        self.chips[#self.chips + 1] = chip
    end
    self.eventsNote = Text(self.eventsCard.frame, 11, COLOR.muted)
    self.eventsNote:SetText("It is best to keep the event conditions to the fewest you need.")
    self.eventsCard.content = function(card, width, y)
        local bottom = Kit.Flow(card.frame, self.chips, width - 24, 6, 12, y + 4, 28)
        self.eventsNote:ClearAllPoints()
        self.eventsNote:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 14, -(bottom + 2))
        return bottom + 22
    end

    self.moreDivider = NewDivider(child, "MORE OPTIONS")
    self.sourceCard = NewCard(child, "Source")
    self.sourceUnit = self:AddRow(self.sourceCard, { kind = "select", label = "Source unit", hint = "Is the caster your target, focus or mouseover?", options = spec.units,
        set = function(value) page:Write("sourceuidfilter", value) end })
    self.sourceType = self:AddRow(self.sourceCard, { kind = "select", label = "Source of the spell", hint = "Leave on Any if a spell landed on you.", options = spec.types,
        set = function(value) page:Write("sourcetypefilter", value) end })
    self.sourceName = self:AddRow(self.sourceCard, { kind = "text", label = "Custom source name", hint = "A specific player or boss.", width = 170,
        set = function(value) page:Write("sourcecustomname", value) end })
    self.destCard = NewCard(child, "Destination")
    self.destUnit = self:AddRow(self.destCard, { kind = "select", label = "Destination unit", hint = "Was the spell aimed at your target, focus or mouseover?", options = spec.units,
        set = function(value) page:Write("destuidfilter", value) end })
    self.destType = self:AddRow(self.destCard, { kind = "select", label = "Spell destination", hint = "Who was afflicted. Leave on Any for casts and buffs.", options = spec.types,
        set = function(value) page:Write("desttypefilter", value) end })
    self.destName = self:AddRow(self.destCard, { kind = "text", label = "Custom destination name", hint = "A specific player or boss.", width = 170,
        set = function(value) page:Write("destcustomname", value) end })

    self.none = Text(host, 12.5, COLOR.muted, "CENTER")
    self.none:SetPoint("CENTER", host, "CENTER", 0, 20)
    self.none:SetText("Nothing selected. Create an alert on the left.")

    view.onWidth = function(width)
        self.width = width
        self:Layout()
    end
end

function Custom:Layout()
    local width = self.width
    if not width then return end
    local child = self.editor.child
    local y = 0
    for _, card in ipairs({ self.alertCard, self.spellCard, self.soundCard, self.chatCard, self.eventsCard }) do
        y = y + PlaceCard(card, child, 0, y, width) + 12
    end
    y = PlaceDivider(self.moreDivider, child, width, y - 4)
    for _, card in ipairs({ self.sourceCard, self.destCard }) do
        y = y + PlaceCard(card, child, 0, y, width) + 12
    end
    self.editor:SetContentHeight(y + 8)
end

function Custom:BindEditor()
    local alert = self:Alert()
    self.editor.frame:SetShown(alert ~= nil)
    self.none:SetShown(alert == nil)
    if not alert then return end
    local spec = self.spec
    self.nameRow.control:Set(alert.name or self.key)
    self.spellRow.control:Set(alert.spellid or "")
    local hint, level = Model.SpellHint(alert)
    self.spellRow:SetHint(hint, level == "bad" and DANGER or nil)
    self.exactRow.control:Set(alert.acceptSpellName and true or false)
    self.nameMatchRow.control:Set(alert.spellname or "")
    self.nameMatchRow:SetActive(alert.acceptSpellName and true or false)
    self.soundRow.control:Set(alert.soundfilepath or "")
    local soundActive = Model.SoundActive(alert)
    self.soundRow:SetActive(soundActive)
    self.chatRow.control:Set(alert.chatAlert and true or false)
    self.chatTextRow.control:Set(alert.chatalerttext or "")
    self.chatTextRow:SetActive(alert.chatAlert and true or false)
    for _, chip in ipairs(self.chips) do
        chip:Set(alert.eventtype and alert.eventtype[chip.key] and true or false, true)
    end
    self.sourceUnit.control:Set(alert.sourceuidfilter or "any")
    self.sourceType.control:Set(alert.sourcetypefilter)
    self.sourceName.control:Set(alert.sourcecustomname or "")
    self.sourceName:SetActive(Model.CustomNameActive(alert, "source"))
    self.destUnit.control:Set(alert.destuidfilter or "any")
    self.destType.control:Set(alert.desttypefilter)
    self.destName.control:Set(alert.destcustomname or "")
    self.destName:SetActive(Model.CustomNameActive(alert, "dest"))
    SetLabel(self.removeButton, self.armed == "remove" and "Really remove?" or "Remove")
end

function Custom:BindHeader()
    SetIf(self.sub, "cached", Model.HeaderText(#self.keys))
end

function Custom:BuildHeader()
    local frame = self.frame
    self.title = Text(frame, 20, COLOR.accent)
    self.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -2)
    self.title:SetText("Advanced")
    self.sub = Text(frame, 11.5, COLOR.muted)
    self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
    self.sub:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
end

function Custom:Refresh()
    if not self.spec.db() then return end
    self.armed = nil
    self.keys = Model.Sorted(self:Custom(), self.keys)
    if not self:Alert() then self.key = self.keys[1] end
    self.top = List.ClampTop(self.top, #self.keys, self.railRows)
    self:BindRail()
    self:BindEditor()
    self:BindHeader()
    self:Layout()
end

local function BuildPage(spec)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    local page = { frame = frame, spec = spec, keys = {}, top = 1 }
    for name, method in pairs(Custom) do page[name] = method end
    page:BuildHeader()
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -HEADER_HEIGHT)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    page.body = body
    page:BuildRail()
    page:BuildEditor()
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

SoundAlerter.CustomPage = { Get = GetPage }

do
local SOUND_FOLDER = "Interface\\Addons\\SoundAlerter\\CustomSounds\\"

function SoundAlerter:BuildCustomAlertOptions()
    local spec = self.customSpec
    if not spec then
        local Model = SA_CustomModel
        local L = LibStub("AceLocale-3.0"):GetLocale("SoundAlerter")
        local icons = {}
        spec = {
            db = function() return SoundAlerter.db1 and SoundAlerter.db1.profile end,
            custom = function()
                local profile = SoundAlerter.db1.profile
                profile.custom = profile.custom or {}
                return profile.custom
            end,
            newName = function() return L["New Alert"] end,
            everything = function() return COMBATLOG_FILTER_EVERYTHING end,
            soundFolder = SOUND_FOLDER,
            lookup = function(id) return (SA_COMPAT.GetSpellInfo(id)) end,
            icon = function(id)
                if not id then return nil end
                local icon = icons[id]
                if not icon then
                    local _, _, texture = SA_COMPAT.GetSpellInfo(id)
                    icon = texture
                    icons[id] = icon
                end
                return icon
            end,
            play = function(path) SoundAlerter:PlayVoice(path) end,
            invalidate = function() SoundAlerter:InvalidateTrackedAuraIDs() end,
            print = function(text) SoundAlerter:Print(text) end,
            eventTip = function(key) return SoundAlerter.SA_EVENT[key] or key end,
            units = Model.Options(SoundAlerter.SA_UNIT, Model.UNIT_ORDER),
            types = Model.Options(SoundAlerter.SA_TYPE, {
                FILTER_TYPE_ANY, FILTER_TYPE_FRIENDLY, FILTER_TYPE_HOSTILE_PLAYER, FILTER_TYPE_HOSTILE_UNIT,
                FILTER_TYPE_NEUTRAL, FILTER_TYPE_ME, FILTER_TYPE_MINE, FILTER_TYPE_MY_PET,
            }),
        }
        self.customSpec = spec
    end
    return {
        type = 'group',
        name = "Advanced",
        icon = "Interface\\Icons\\INV_Misc_Wrench_01",
        desc = "Advanced customization: create custom alerts, configure event filters, and fine-tune addon behavior for power users.",
        order = 4,
        args = {
            page = {
                type = 'description',
                name = "Advanced could not draw its page.",
                dialogControl = "SoundAlerterCustomPage",
                arg = spec,
                order = 1,
            },
        },
    }
end
end
