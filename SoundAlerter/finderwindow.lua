local SoundAlerter = SoundAlerter
local Kit = SoundAlerter.Page.Kit
local List = SA_FinderList
local Format = SA_FinderFormat
local FX = SA_MenuFX

local COLOR, Paint, Outline, Text, Tint, Flow = Kit.COLOR, Kit.Paint, Kit.Outline, Kit.Text, Kit.Tint, Kit.Flow

SA_FinderWindow = {}

local Window = {}

local WIDTH, MIN_WIDTH, HEIGHT = List.WIDTH, List.MIN_WIDTH, List.HEIGHT
local TITLE_HEIGHT = 30
local PAD = 12
local DETAIL_WIDTH = 270
local PANE_GAP = 8
local FOOTER_HEIGHT = 26
local SEARCH_HEIGHT = 24
local SUGGEST_HEIGHT = 22
local MENU_ROW = 22
local MENU_WIDTH = 150
local TOAST_SECONDS = 1.5
local CYAN = { 0.3, 0.85, 1 }
local AMBER = { 1, 0.67, 0 }
local BACKGROUND = { 0.059, 0.071, 0.094 }

local SELECT_KEYS = {
    rank = "rankFilter",
    kind = "kindFilter",
    known = "knownFilter",
    sort = "sortMode",
}

local SELECT_NAMES = { rank = "Rank", kind = "Type", known = "Known", sort = "Sort" }

local function HideTip()
    GameTooltip:Hide()
end

local function ShowTip(owner, title, body)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if body and body ~= "" then GameTooltip:AddLine(body, 0.6, 0.65, 0.7, true) end
    GameTooltip:Show()
end

function Window:Settings()
    return List.Normalize(self.host.settings(), self.host.rankOptions())
end

function Window:Text()
    return self.box:GetText() or ""
end

function Window:Layout()
    local width = self.width
    local inner = width - 2 * PAD
    self.frame:SetSize(width, HEIGHT)
    self.box:ClearAllPoints()
    self.box:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -(TITLE_HEIGHT + 6))
    self.box:SetSize(inner, SEARCH_HEIGHT)
    self.suggestFrame:ClearAllPoints()
    self.suggestFrame:SetPoint("TOPLEFT", self.box, "BOTTOMLEFT", 0, -2)
    self.suggestFrame:SetWidth(math.min(inner, 340))
    local y = TITLE_HEIGHT + 6 + SEARCH_HEIGHT + 6
    y = Flow(self.frame, self.controls, inner, 6, PAD, y, 26) + 2
    local bodyHeight = HEIGHT - FOOTER_HEIGHT - y
    self.list:ClearAllPoints()
    self.list:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -y)
    self.list:SetSize(inner - DETAIL_WIDTH - PANE_GAP, bodyHeight)
    self.detail:ClearAllPoints()
    self.detail:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -PAD, -y)
    self.detail:SetSize(DETAIL_WIDTH, bodyHeight)
    self.rowCount = List.Rows(bodyHeight)
    self.listHeight = bodyHeight
    self.emptyText:SetWidth(inner - DETAIL_WIDTH - PANE_GAP - 24)
    self:BindRows()
end

function Window:SetWidth(width)
    self.width = math.max(MIN_WIDTH, math.min(WIDTH, width))
    self:Layout()
end

function Window:AcquireRow(index)
    local row = self.rows[index]
    if row then return row end
    local frame = CreateFrame("Button", nil, self.list)
    frame:SetHeight(List.ROW_HEIGHT)
    frame:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -(index - 1) * List.ROW_HEIGHT)
    frame:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", -12, -(index - 1) * List.ROW_HEIGHT)
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
    local rule = Paint(frame, COLOR.line, 0.55)
    rule:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", frame, "LEFT", 10, 0)
    local id = Text(frame, 11.5, COLOR.muted, "RIGHT")
    id:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    id:SetWidth(54)
    local rank = Text(frame, 11.5, COLOR.muted, "RIGHT")
    rank:SetPoint("RIGHT", id, "LEFT", -10, 0)
    rank:SetWidth(60)
    local tag = Text(frame, 10.5, CYAN, "RIGHT")
    tag:SetPoint("RIGHT", rank, "LEFT", -8, 0)
    tag:SetWidth(70)
    local name = Text(frame, 12.5, COLOR.text)
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    name:SetPoint("RIGHT", tag, "LEFT", -6, 0)
    row = { frame = frame, selected = selected, bar = bar, icon = icon, name = name, rank = rank, id = id, tag = tag }
    frame:SetScript("OnClick", function() self:Select(row.index) end)
    frame:SetScript("OnEnter", function()
        local spell = row.spell
        if not spell then return end
        GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
        local link = self.host.spellLink(spell.spellID)
        if link then
            GameTooltip:SetHyperlink(link)
        else
            GameTooltip:AddLine(spell.baseName or spell.name, 1, 1, 1)
            GameTooltip:AddLine("Spell ID: " .. spell.spellID, 0.5, 0.5, 1)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", HideTip)
    FX.Hover(frame, tint)
    self.rows[index] = row
    return row
end

function Window:BindRow(row, spell, index)
    row.index = index
    if row.spell ~= spell then
        row.spell = spell
        row.icon:SetTexture(self.host.icon(spell.spellID))
        row.name:SetText(spell.baseName or spell.name)
        row.rank:SetText(Format.RankText(spell.rankNum))
        row.id:SetText(tostring(spell.spellID))
        if spell.idMatch then
            row.tag:SetText("ID match")
            Tint(row.tag, CYAN)
        elseif spell.inDescription then
            row.tag:SetText("description")
            Tint(row.tag, AMBER)
        else
            row.tag:SetText("")
        end
    end
    local on = index == self.selected
    row.selected:SetShown(on)
    row.bar:SetShown(on)
    Tint(row.name, on and COLOR.accent or COLOR.text)
    row.frame:Show()
end

function Window:BindRows()
    local count = self.shownCount or 0
    self.top = List.ClampTop(self.top, count, self.rowCount)
    for slot = 1, self.rowCount do
        local row = self:AcquireRow(slot)
        local index = self.top + slot - 1
        local spell = index <= count and self.results[index] or nil
        if spell then
            self:BindRow(row, spell, index)
        else
            row.spell = nil
            row.index = nil
            row.frame:Hide()
        end
    end
    for slot = self.rowCount + 1, #self.rows do
        self.rows[slot].spell = nil
        self.rows[slot].frame:Hide()
    end
    local range = count - self.rowCount
    self.scrollbar:Update(range > 0 and (self.top - 1) / range or 0, range > 0 and self.rowCount / count or 1)
end

function Window:Select(index)
    local count = self.shownCount or 0
    if index and (index < 1 or index > count) then index = nil end
    self.selected = index
    if index then
        self.top = List.Reveal(self.top, index, self.rowCount)
    end
    self:BindRows()
    local spell = index and self.results[index] or nil
    self.selectedSpell = spell
    self.host.detail(self, spell)
end

function Window:Move(delta)
    local next = List.Move(self.selected, self.shownCount or 0, delta)
    if next then self:Select(next) end
end

function Window:SetFooter(count, unfiltered)
    self.footer:SetText(self.host.status(count, unfiltered))
    if self.hiddenCount and self.hiddenCount > 0 then
        self.more:SetText(Format.More(self.shownCount, self.shownCount + self.hiddenCount))
        self.more:Show()
    else
        self.more:SetText("")
        self.more:Hide()
    end
end

function Window:ShowResults(results, unfiltered, term)
    self.results = results
    local count = #results
    self.shownCount, self.hiddenCount = List.Cap(count)
    self.top = 1
    if count == 0 then
        self.emptyText:SetText(self.host.empty(term, unfiltered))
        self.emptyText:Show()
    else
        self.emptyText:Hide()
    end
    self:SetFooter(count, unfiltered)
    self:Select(count > 0 and 1 or nil)
end

function Window:ShowHint()
    self.results = self.results or {}
    for index = #self.results, 1, -1 do self.results[index] = nil end
    self.shownCount, self.hiddenCount = 0, 0
    self.top = 1
    self.emptyText:SetText(self.host.empty("", 0))
    self.emptyText:Show()
    self:SetFooter(nil)
    self:Select(nil)
end

function Window:SetDetail(info)
    local detail = self.fields
    if not info then
        detail.icon:Hide()
        detail.title:SetText("")
        detail.subtitle:SetText("")
        detail.facts:SetText("")
        detail.props:SetText("")
        detail.id:SetText("")
        detail.description:SetText(Format.NoSelection())
        self:SetButtons(false, false)
        return
    end
    local spell = info.spell
    detail.icon:Show()
    detail.icon:SetTexture(info.texture)
    detail.title:SetText(spell.baseName or spell.name)
    detail.subtitle:SetText(Format.Subtitle(spell))
    detail.facts:SetText(Format.Facts(info.facts))
    detail.props:SetText(Format.Properties(info.props))
    detail.id:SetText(tostring(spell.spellID))
    detail.description:SetText(Format.Description(info.description, info.loading))
    self:SetButtons(true, info.description ~= nil)
end

function Window:SetButtons(canInsert, canDescribe)
    local function set(button, enabled)
        button.frame:SetAlpha(enabled and 1 or 0.4)
        button.frame:EnableMouse(enabled)
    end
    set(self.fields.insert, canInsert)
    set(self.fields.insertDescription, canDescribe)
    set(self.fields.copy, canInsert)
end

function Window:Toast(text, r, g, b)
    self.toastText:SetText(text)
    self.toastText:SetTextColor(r or 0, g or 1, b or 0)
    self.toast:SetWidth(self.toastText:GetStringWidth() + 24)
    self.toast:Show()
    if self.toastTimer then self.host.cancel(self.toastTimer) end
    self.toastTimer = self.host.after(TOAST_SECONDS, function()
        self.toastTimer = nil
        self.toast:Hide()
    end)
end

function Window:CopyId()
    if not self.selectedSpell then return end
    self.fields.id:SetFocus()
    self.fields.id:HighlightText()
    self:Toast("ID selected, press Ctrl+C")
end

function Window:Insert(withDescription)
    local spell = self.selectedSpell
    if not spell then return end
    self.host.insert(spell, withDescription, self)
end

function Window:CancelPending()
    if self.pending then
        self.host.cancel(self.pending)
        self.pending = nil
    end
end

function Window:RunSearch()
    self:CancelPending()
    local term = self:Text()
    self.lastSearchTerm = term
    self:ClearSuggestions()
    if term == "" then
        self:ShowHint()
        return
    end
    self.host.search(self, term)
end

function Window:Refresh()
    if self:Text() ~= "" and List.Settled(self:Text(), self:Settings().scope) then
        self:RunSearch()
    end
end

function Window:ScheduleSearch()
    self:CancelPending()
    local term = self:Text()
    if term == "" or not List.Settled(term, self:Settings().scope) then
        self.lastSearchTerm = term
        self:ShowHint()
        return
    end
    self.pending = self.host.after(List.DEBOUNCE, function()
        self.pending = nil
        self:RunSearch()
    end)
end

function Window:ClearSuggestions()
    if #self.suggestions == 0 then return end
    self.suggestions = {}
    self.suggestIndex = nil
    self:DrawSuggestions()
end

function Window:DrawSuggestions()
    local count = #self.suggestions
    for index = 1, math.max(count, #self.suggestRows) do
        local row = self.suggestRows[index]
        if not row and index <= count then
            local frame = CreateFrame("Button", nil, self.suggestFrame)
            frame:SetHeight(SUGGEST_HEIGHT)
            frame:SetPoint("TOPLEFT", self.suggestFrame, "TOPLEFT", 0, -(index - 1) * SUGGEST_HEIGHT)
            frame:SetPoint("TOPRIGHT", self.suggestFrame, "TOPRIGHT", 0, -(index - 1) * SUGGEST_HEIGHT)
            local tint = Paint(frame, COLOR.line, 0.8)
            tint:SetAllPoints(frame)
            tint:Hide()
            local label = Text(frame, 12.5, COLOR.text)
            label:SetPoint("LEFT", frame, "LEFT", 10, 0)
            local hint = Text(frame, 10.5, COLOR.muted, "RIGHT")
            hint:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
            row = { frame = frame, tint = tint, label = label, hint = hint }
            frame:SetScript("OnClick", function() self:AcceptSuggestion(row.index, true) end)
            self.suggestRows[index] = row
        end
        if row then
            if index <= count then
                row.index = index
                row.label:SetText(self.suggestions[index])
                row.hint:SetText(index == 1 and "Tab" or "")
                row.tint:SetShown(index == self.suggestIndex)
                Tint(row.label, index == self.suggestIndex and COLOR.accent or COLOR.text)
                row.frame:Show()
            else
                row.frame:Hide()
            end
        end
    end
    self.suggestFrame:SetHeight(math.max(1, count * SUGGEST_HEIGHT))
    self.suggestFrame:SetShown(count > 0)
end

function Window:UpdateSuggestions()
    local settings = self:Settings()
    local text = self:Text()
    if not settings.autocomplete or settings.scope == "descriptions" or #text < 2 then
        self:ClearSuggestions()
        return
    end
    local fresh = self.host.suggest(text)
    if #fresh == 1 and string.lower(fresh[1]) == string.lower(text) then fresh = {} end
    local unchanged = #fresh == #self.suggestions
    if unchanged then
        for index = 1, #fresh do
            if fresh[index] ~= self.suggestions[index] then
                unchanged = false
                break
            end
        end
    end
    if unchanged then return end
    self.suggestions = fresh
    self.suggestIndex = nil
    self:DrawSuggestions()
end

function Window:AcceptSuggestion(index, andSearch)
    local name = self.suggestions[index]
    if not name then return end
    self.suggestions = {}
    self.suggestIndex = nil
    self:DrawSuggestions()
    self.box:SetText(name)
    self.box:SetFocus()
    self.box:SetCursorPosition(#name)
    if andSearch then
        self:RunSearch()
    else
        self:ScheduleSearch()
    end
end

function Window:OnArrow(key)
    if key ~= "DOWN" and key ~= "UP" then return end
    local delta = key == "DOWN" and 1 or -1
    if #self.suggestions > 0 then
        self.suggestIndex = List.Cycle(self.suggestIndex, #self.suggestions, delta)
        self:DrawSuggestions()
        return
    end
    self:Move(delta)
end

function Window:OnEnter()
    if self.suggestIndex then
        self:AcceptSuggestion(self.suggestIndex, true)
        return
    end
    local term = self:Text()
    if self.pending or term ~= self.lastSearchTerm then
        self:RunSearch()
        return
    end
    self:Insert(IsShiftKeyDown and IsShiftKeyDown() or false)
end

function Window:OnEscape()
    if #self.suggestions > 0 then
        self:ClearSuggestions()
    elseif self:Text() ~= "" then
        self.box:SetText("")
        self:CancelPending()
        self.lastSearchTerm = ""
        self:ShowHint()
    else
        self.box:ClearFocus()
    end
end

function Window:SyncPlaceholder()
    local text = self:Text()
    self.placeholder:SetShown(text == "" and not self.box:HasFocus())
    self.clear:SetShown(text ~= "")
end

function Window:RefreshControls()
    local settings = self:Settings()
    self.scopeSelect:Set(settings.scope)
    self.fuzzy:Set(settings.fuzzy)
    self.autocomplete:Set(settings.autocomplete)
    self.descending:Set(settings.descending)
    local ranks = self.host.rankOptions()
    local lists = { rank = ranks, kind = List.KINDS, known = List.KNOWNS, sort = List.SORTS }
    for key, chip in pairs(self.selectChips) do
        local value = settings[key]
        chip:SetLabel(List.ChipText(SELECT_NAMES[key], lists[key], value))
        local default = key == "sort" and "name" or lists[key][1][1]
        chip:Set(value ~= default, true)
    end
    self.placeholder:SetText(settings.scope == "descriptions" and "Description text" or "Spell name")
    self:Layout()
end

function Window:OnScopeChanged()
    self:RefreshControls()
    self:UpdateSuggestions()
    if self.frame:IsShown() then self:Refresh() end
end

function Window:Change(key, value)
    self.host.set(key, value)
    self:RefreshControls()
    if key == "autocomplete" then
        self:UpdateSuggestions()
    else
        self:Refresh()
    end
end

function Window:CloseMenu()
    self.menu:Hide()
    self.catcher:Hide()
    self.menuOpenFor = nil
end

function Window:OpenMenu(owner, options, current, onPick)
    if self.menuOpenFor == owner then
        self:CloseMenu()
        return
    end
    self.menuOpenFor = owner
    local columns = List.Columns(#options)
    local perColumn = math.min(#options, List.MENU_COLUMN)
    for index, option in ipairs(options) do
        local entry = self.menuRows[index]
        if not entry then
            local frame = CreateFrame("Button", nil, self.menu)
            frame:SetSize(MENU_WIDTH, MENU_ROW)
            local tint = Paint(frame, COLOR.line, 1)
            tint:SetAllPoints(frame)
            tint:Hide()
            local label = Text(frame, 12.5, COLOR.text)
            label:SetPoint("LEFT", frame, "LEFT", 10, 0)
            entry = { frame = frame, tint = tint, label = label }
            frame:SetScript("OnEnter", function() tint:Show() end)
            frame:SetScript("OnLeave", function() tint:Hide() end)
            frame:SetScript("OnClick", function()
                local pick = entry.onPick
                self:CloseMenu()
                if pick then pick(entry.value) end
            end)
            self.menuRows[index] = entry
        end
        entry.value = option[1]
        entry.onPick = onPick
        entry.label:SetText(option[2])
        Tint(entry.label, option[1] == current and COLOR.accent or COLOR.text)
        local column = math.floor((index - 1) / List.MENU_COLUMN)
        local line = (index - 1) % List.MENU_COLUMN
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("TOPLEFT", self.menu, "TOPLEFT", 4 + column * MENU_WIDTH, -(4 + line * MENU_ROW))
        entry.frame:Show()
    end
    for index = #options + 1, #self.menuRows do self.menuRows[index].frame:Hide() end
    self.menu:SetSize(8 + columns * MENU_WIDTH, 8 + perColumn * MENU_ROW)
    self.menu:ClearAllPoints()
    self.menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    self.catcher:Show()
    self.menu:Show()
end

function Window:BuildTitle()
    local frame = self.frame
    local bar = CreateFrame("Frame", nil, frame)
    self.titleBar = bar
    bar:SetHeight(TITLE_HEIGHT)
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    local fill = Paint(bar, COLOR.card)
    fill:SetAllPoints(bar)
    local title = Text(bar, 13, COLOR.text)
    title:SetPoint("LEFT", bar, "LEFT", PAD, 0)
    title:SetText("SoundAlerter - Find Spell")
    local hint = Text(bar, 11, COLOR.muted)
    hint:SetPoint("LEFT", title, "RIGHT", 10, 0)
    hint:SetText("drag to move")
    local close = CreateFrame("Button", nil, bar)
    close:SetSize(24, 22)
    close:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    local mark = Text(close, 16, COLOR.muted, "CENTER")
    mark:SetAllPoints(close)
    mark:SetText("x")
    close:SetScript("OnClick", function() frame:Hide() end)
    close:SetScript("OnEnter", function() Tint(mark, COLOR.accent) end)
    close:SetScript("OnLeave", function() Tint(mark, COLOR.muted) end)
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, relative, x, y = frame:GetPoint(1)
        self.host.savePosition(point, relative, x, y)
    end)
end

function Window:BuildSearch()
    local frame = self.frame
    local box = CreateFrame("EditBox", nil, frame)
    box:SetAutoFocus(false)
    box:SetFont(Kit.FONT, 13, "")
    box:SetTextInsets(8, 28, 3, 3)
    local fill = Paint(box, COLOR.line)
    fill:SetAllPoints(box)
    Outline(box, COLOR.line)
    self.box = box
    self.placeholder = Text(box, 13, COLOR.muted)
    self.placeholder:SetPoint("LEFT", box, "LEFT", 8, 0)
    self.clear = CreateFrame("Button", nil, box)
    self.clear:SetSize(22, 22)
    self.clear:SetPoint("RIGHT", box, "RIGHT", -3, 0)
    local mark = Text(self.clear, 14, COLOR.muted, "CENTER")
    mark:SetAllPoints(self.clear)
    mark:SetText("x")
    self.clear:SetScript("OnClick", function()
        box:SetText("")
        self:OnEscape()
        box:SetFocus()
    end)
    self.clear:Hide()
    box:SetScript("OnTextChanged", function(_, userInput)
        self:SyncPlaceholder()
        if not userInput then return end
        self:UpdateSuggestions()
        self:ScheduleSearch()
    end)
    box:SetScript("OnEditFocusGained", function() self:SyncPlaceholder() end)
    box:SetScript("OnEditFocusLost", function()
        self:SyncPlaceholder()
        self:ClearSuggestions()
    end)
    box:SetScript("OnEnterPressed", function() self:OnEnter() end)
    box:SetScript("OnEscapePressed", function() self:OnEscape() end)
    box:SetScript("OnTabPressed", function()
        if #self.suggestions > 0 then self:AcceptSuggestion(self.suggestIndex or 1, false) end
    end)
    box:SetScript("OnArrowPressed", function(_, key) self:OnArrow(key) end)

    self.suggestFrame = CreateFrame("Frame", nil, frame)
    self.suggestFrame:SetFrameLevel(frame:GetFrameLevel() + 30)
    local back = Paint(self.suggestFrame, COLOR.card, 1, "BACKGROUND")
    back:SetAllPoints(self.suggestFrame)
    Outline(self.suggestFrame, COLOR.track)
    self.suggestFrame:Hide()
    self.suggestions = {}
    self.suggestRows = {}
end

function Window:BuildControls()
    local frame = self.frame
    self.controls = {}
    local function add(control) self.controls[#self.controls + 1] = control return control end
    self.scopeSelect = add(Kit.MakeSelect(frame, { options = List.SCOPES }, function(value) self.host.setScope(value) end))
    self.fuzzy = add(Kit.MakeChip(frame, "Fuzzy", function() self:Change("fuzzy", not self:Settings().fuzzy) end))
    self.autocomplete = add(Kit.MakeChip(frame, "Autocomplete", function() self:Change("autocomplete", not self:Settings().autocomplete) end))
    self.selectChips = {}
    for _, key in ipairs({ "rank", "kind", "known", "sort" }) do
        local chip
        chip = Kit.MakeChip(frame, SELECT_NAMES[key], function()
            local options = ({ rank = self.host.rankOptions(), kind = List.KINDS, known = List.KNOWNS, sort = List.SORTS })[key]
            self:OpenMenu(chip.frame, options, self:Settings()[key], function(value) self:Change(SELECT_KEYS[key], value) end)
        end)
        self.selectChips[key] = chip
        add(chip)
    end
    self.descending = add(Kit.MakeChip(frame, "Descending", function() self:Change("sortDesc", not self:Settings().descending) end))
    self.fuzzy.frame:HookScript("OnEnter", function() ShowTip(self.fuzzy.frame, "Fuzzy", "Typo-tolerant matching: abbreviations like frstblt and one or two typos. Switches the sort to Relevance.") end)
    self.fuzzy.frame:HookScript("OnLeave", HideTip)

    self.catcher = CreateFrame("Button", nil, UIParent)
    self.catcher:SetAllPoints(UIParent)
    self.catcher:SetFrameStrata("DIALOG")
    self.catcher:SetFrameLevel(frame:GetFrameLevel() + 40)
    self.catcher:SetScript("OnClick", function() self:CloseMenu() end)
    self.catcher:Hide()
    self.menu = CreateFrame("Frame", nil, UIParent)
    self.menu:SetFrameStrata("DIALOG")
    self.menu:SetFrameLevel(frame:GetFrameLevel() + 50)
    local back = Paint(self.menu, COLOR.card, 1, "BACKGROUND")
    back:SetAllPoints(self.menu)
    Outline(self.menu, COLOR.track)
    self.menu:Hide()
    self.menuRows = {}
end

function Window:BuildBody()
    local frame = self.frame
    self.list = CreateFrame("Frame", nil, frame)
    self.list:EnableMouseWheel(true)
    self.list:SetScript("OnMouseWheel", function(_, delta)
        self.top = List.Wheel(self.top or 1, delta, self.shownCount or 0, self.rowCount)
        self:BindRows()
    end)
    self.rows = {}
    self.scrollbar = Kit.MakeScrollbar(self.list, function(fraction)
        local count = self.shownCount or 0
        local range = count - self.rowCount
        if range <= 0 then return end
        local top = List.ClampTop(1 + math.floor(fraction * range + 0.5), count, self.rowCount)
        if top ~= self.top then
            self.top = top
            self:BindRows()
        end
    end, 0)
    self.thumb = self.scrollbar.strip
    self.emptyText = Text(self.list, 12.5, COLOR.muted)
    self.emptyText:SetPoint("TOPLEFT", self.list, "TOPLEFT", 12, -16)
    if self.emptyText.SetWordWrap then self.emptyText:SetWordWrap(true) end
    self.emptyText:SetJustifyV("TOP")
    self.more = Text(frame, 11, AMBER)
    self.more:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, FOOTER_HEIGHT + 2)
    self.more:Hide()

    local detail = CreateFrame("Frame", nil, frame)
    self.detail = detail
    local fill = Paint(detail, COLOR.card)
    fill:SetAllPoints(detail)
    Outline(detail, COLOR.line)
    local fields = {}
    self.fields = fields
    fields.icon = detail:CreateTexture(nil, "ARTWORK")
    fields.icon:SetSize(36, 36)
    fields.icon:SetPoint("TOPLEFT", detail, "TOPLEFT", 12, -12)
    fields.title = Text(detail, 15, COLOR.text)
    fields.title:SetPoint("TOPLEFT", fields.icon, "TOPRIGHT", 10, -2)
    fields.title:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
    fields.subtitle = Text(detail, 11.5, COLOR.muted)
    fields.subtitle:SetPoint("TOPLEFT", fields.title, "BOTTOMLEFT", 0, -3)
    fields.subtitle:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
    fields.facts = Text(detail, 11.5, COLOR.text)
    fields.facts:SetPoint("TOPLEFT", detail, "TOPLEFT", 12, -58)
    fields.facts:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
    fields.props = Text(detail, 11.5, COLOR.text)
    fields.props:SetPoint("TOPLEFT", fields.facts, "BOTTOMLEFT", 0, -6)
    fields.props:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
    fields.description = Text(detail, 12, COLOR.text)
    fields.description:SetPoint("TOPLEFT", fields.props, "BOTTOMLEFT", 0, -10)
    fields.description:SetWidth(DETAIL_WIDTH - 24)
    if fields.description.SetWordWrap then fields.description:SetWordWrap(true) end
    fields.description:SetJustifyV("TOP")
    fields.description:SetHeight(150)

    local idBox = CreateFrame("EditBox", nil, detail)
    idBox:SetAutoFocus(false)
    idBox:SetFont(Kit.FONT, 12, "")
    idBox:SetTextInsets(6, 6, 3, 3)
    idBox:SetHeight(22)
    idBox:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 12, 44)
    idBox:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -88, 44)
    local idFill = Paint(idBox, COLOR.line)
    idFill:SetAllPoints(idBox)
    idBox:SetScript("OnEditFocusGained", function(box) box:HighlightText() end)
    idBox:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    fields.id = idBox
    fields.copy = Kit.MakeButton(detail, "Copy ID", function() self:CopyId() end)
    fields.copy.frame:SetWidth(70)
    fields.copy.frame:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -12, 44)
    fields.insert = Kit.MakeButton(detail, "Insert in chat", function() self:Insert(false) end)
    fields.insert.frame:SetWidth(112)
    fields.insert.frame:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 12, 12)
    fields.insertDescription = Kit.MakeButton(detail, "With description", function() self:Insert(true) end)
    fields.insertDescription.frame:SetWidth(120)
    fields.insertDescription.frame:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -12, 12)

    self.footerBar = CreateFrame("Frame", nil, frame)
    self.footerBar:SetHeight(FOOTER_HEIGHT)
    self.footerBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    self.footerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    local footerFill = Paint(self.footerBar, COLOR.card)
    footerFill:SetAllPoints(self.footerBar)
    self.footer = Text(self.footerBar, 11.5, COLOR.muted)
    self.footer:SetPoint("LEFT", self.footerBar, "LEFT", PAD, 0)
    self.footer:SetPoint("RIGHT", self.footerBar, "RIGHT", -PAD, 0)

    self.toast = CreateFrame("Frame", nil, frame)
    self.toast:SetHeight(26)
    self.toast:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, FOOTER_HEIGHT + 8)
    self.toast:SetFrameLevel(frame:GetFrameLevel() + 35)
    local toastFill = Paint(self.toast, { 0.02, 0.03, 0.04 })
    toastFill:SetAllPoints(self.toast)
    Outline(self.toast, COLOR.accent)
    self.toastText = Text(self.toast, 12, COLOR.text, "CENTER")
    self.toastText:SetAllPoints(self.toast)
    self.toast:Hide()
end

function Window:Show()
    self.frame:Show()
end

function Window:Hide()
    self.frame:Hide()
end

function Window:Dock(anchor)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, 0)
end

function Window:Place(point, relative, x, y)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, UIParent, relative or point, x or 0, y or 0)
end

function Window:Cleanup()
    self:CancelPending()
    if self.toastTimer then
        self.host.cancel(self.toastTimer)
        self.toastTimer = nil
    end
    self:CloseMenu()
    self:ClearSuggestions()
    self.selectedSpell = nil
    self.selected = nil
    self.shownCount, self.hiddenCount = 0, 0
    for index = 1, #self.rows do
        self.rows[index].spell = nil
        self.rows[index].frame:Hide()
    end
    self.toast:Hide()
end

function SA_FinderWindow.Create(host)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    local fill = Paint(frame, BACKGROUND)
    fill:SetAllPoints(frame)
    Outline(frame, COLOR.line)
    frame:Hide()

    local window = { frame = frame, host = host, width = WIDTH, top = 1, shownCount = 0, hiddenCount = 0, results = {}, lastSearchTerm = "", rowCount = 1 }
    for name, method in pairs(Window) do window[name] = method end

    window:BuildTitle()
    window:BuildSearch()
    window:BuildControls()
    window:BuildBody()

    frame:SetScript("OnShow", function()
        host.onShown(window)
    end)
    frame:SetScript("OnHide", function()
        window:Cleanup()
        host.onHidden(window)
    end)

    window.onScopeChanged = function() window:OnScopeChanged() end
    window:RefreshControls()
    window:SyncPlaceholder()
    window:ShowHint()
    return window
end

