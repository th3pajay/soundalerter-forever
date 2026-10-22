local SoundAlerter = SoundAlerter
local AceGUI = LibStub("AceGUI-3.0")
local Kit = SoundAlerter.Page.Kit
local Model = SA_DevModel
local List = SA_FinderList
local FX = SA_MenuFX

local COLOR, Paint, Outline, Text, Tint = Kit.COLOR, Kit.Paint, Kit.Outline, Kit.Text, Kit.Tint
local NewView, NewHeading, NewDivider, PlaceDivider, NewCard, PlaceCard = Kit.NewView, Kit.NewHeading, Kit.NewDivider, Kit.PlaceDivider, Kit.NewCard, Kit.PlaceCard

local WIDGET = "SoundAlerterDevPage"
local HEADER_HEIGHT = 112
local GAP = 12
local TILE_HEIGHT = 42
local ROW_TILE = 50
local TILE_TEXT = {
    closed = { "Open Spell Finder", "Search every spell, rank and description" },
    open = { "Close Spell Finder", "Click again to close the window" },
}
local TILE_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local ROW_KV = 20
local ROW_TIMING = 24
local ROW_LEGEND = 22
local REDRAW_SECONDS = 0.25
local HIDDEN_TICKS = 3
local BAR_TOP = 66
local BAR_HEIGHT = 10
local ROW_NOTE = 30
local DATABASE_ROWS = 7

local LEVEL = {
    ok = COLOR.on,
    warn = { 1, 0.69, 0.125 },
    bad = { 1, 0.36, 0.36 },
}

local Dev = {}

local ShowTip, HideTip = Kit.ShowTip, Kit.HideTip

local function SetIf(region, key, value)
    if region[key] ~= value then
        region[key] = value
        region:SetText(value)
    end
end

local function NewVital(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(18)
    local dot = Paint(frame, COLOR.on, 1, "ARTWORK")
    dot:SetSize(8, 8)
    dot:SetPoint("LEFT", frame, "LEFT", 0, 0)
    local pre = Text(frame, 12, COLOR.muted)
    local value = Text(frame, 12.5, COLOR.text)
    local post = Text(frame, 12, COLOR.muted)
    local vital = { frame = frame, dot = dot, pre = pre, value = value, post = post }
    local last = {}
    local floor = 0
    function vital:Set(dotLevel, preText, valueText, valueLevel, postText, hold)
        if last.dot == dotLevel and last.pre == preText and last.value == valueText and last.level == valueLevel and last.post == postText and last.hold == hold then
            return false
        end
        last.dot, last.pre, last.value, last.level, last.post, last.hold = dotLevel, preText, valueText, valueLevel, postText, hold
        local x = 0
        if dotLevel then
            Tint(dot, LEVEL[dotLevel])
            dot:Show()
            x = 14
        else
            dot:Hide()
        end
        pre:SetText(preText or "")
        pre:ClearAllPoints()
        pre:SetPoint("LEFT", frame, "LEFT", x, 0)
        x = x + (preText and preText ~= "" and pre:GetStringWidth() + 5 or 0)
        value:SetText(valueText or "")
        Tint(value, LEVEL[valueLevel] or COLOR.text)
        value:ClearAllPoints()
        value:SetPoint("LEFT", frame, "LEFT", x, 0)
        x = x + value:GetStringWidth()
        post:SetText(postText or "")
        post:ClearAllPoints()
        post:SetPoint("LEFT", frame, "LEFT", x + (postText and postText ~= "" and 5 or 0), 0)
        x = x + (postText and postText ~= "" and post:GetStringWidth() + 5 or 0)
        local width = math.max(1, x)
        if not hold then
            floor = 0
        elseif width < floor then
            width = floor
        else
            floor = width
        end
        local moved = frame:GetWidth() ~= width
        frame:SetWidth(width)
        return moved
    end
    return vital
end

function Dev:AddSetting(card, row)
    local page = self
    local entry = Kit.AddRow(card, row, function() page:Tick(true) end)
    self.settings[#self.settings + 1] = entry
    return entry
end

function Dev:AddKv(card)
    local frame = CreateFrame("Frame", nil, card.frame)
    frame:SetHeight(ROW_KV)
    local label = Text(frame, 12.5, COLOR.muted)
    label:SetPoint("LEFT", frame, "LEFT", 4, 0)
    local value = Text(frame, 12.5, COLOR.text, "RIGHT")
    value:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    value:SetPoint("LEFT", label, "RIGHT", 8, 0)
    local kv = { frame = frame, height = ROW_KV, label = label, value = value }
    function kv:Set(row)
        if not row then
            frame:Hide()
            return
        end
        frame:Show()
        SetIf(label, "cached", row[1])
        SetIf(value, "cached", row[2])
        Tint(value, LEVEL[row[3]] or COLOR.text)
    end
    card.rows[#card.rows + 1] = kv
    return kv
end

function Dev:AddKvList(card, count)
    local list = {}
    for index = 1, count do list[index] = self:AddKv(card) end
    return list
end

function Dev:SetKvList(list, rows)
    for index, kv in ipairs(list) do kv:Set(rows[index]) end
end

function Dev:AddNote(card)
    local frame = CreateFrame("Frame", nil, card.frame)
    frame:SetHeight(ROW_NOTE)
    local note = Text(frame, 10.5, LEVEL.warn)
    note:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -2)
    note:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    if note.SetWordWrap then note:SetWordWrap(true) end
    note:SetJustifyV("TOP")
    note:SetHeight(ROW_NOTE - 2)
    self.rebuildNote = note
    card.rows[#card.rows + 1] = { frame = frame, height = ROW_NOTE }
end

local function NewProgressBar(parent)
    local frame = CreateFrame("StatusBar", nil, parent)
    frame:SetHeight(BAR_HEIGHT)
    frame:SetStatusBarTexture(Kit.FLAT)
    frame:SetStatusBarColor(LEVEL.warn[1], LEVEL.warn[2], LEVEL.warn[3], 1)
    frame:SetMinMaxValues(0, 100)
    local track = Paint(frame, COLOR.track, 1)
    track:SetAllPoints(frame)
    frame:Hide()
    local bar = { frame = frame, percent = 0 }
    function bar:Set(percent)
        percent = math.max(0, math.min(100, percent))
        if percent == self.percent then return end
        self.percent = percent
        frame:SetValue(percent)
    end
    return bar
end

function Dev:AddLegend(card)
    local frame = CreateFrame("Frame", nil, card.frame)
    frame:SetHeight(ROW_LEGEND)
    local x = 4
    for _, item in ipairs({ { "p50", LEVEL.ok, 1 }, { "p95", LEVEL.warn, 0.6 }, { "p99", { 1, 0.49, 0.04 }, 0.35 } }) do
        local swatch = Paint(frame, item[2], item[3], "ARTWORK")
        swatch:SetSize(10, 8)
        swatch:SetPoint("LEFT", frame, "LEFT", x, 0)
        local label = Text(frame, 11.5, COLOR.muted)
        label:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
        label:SetText(item[1])
        x = x + 50
    end
    card.rows[#card.rows + 1] = { frame = frame, height = ROW_LEGEND }
end

function Dev:AddTiming(card, mode)
    local frame = CreateFrame("Frame", nil, card.frame)
    frame:SetHeight(ROW_TIMING)
    frame:EnableMouse(true)
    local name = Text(frame, 12.5, COLOR.muted)
    name:SetPoint("LEFT", frame, "LEFT", 4, 0)
    name:SetWidth(106)
    name:SetText(mode.label)
    local numbers = Text(frame, 11.5, COLOR.muted, "RIGHT")
    numbers:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    numbers:SetWidth(150)
    local track = CreateFrame("Frame", nil, frame)
    track:SetHeight(10)
    track:SetPoint("LEFT", name, "RIGHT", 6, 0)
    track:SetPoint("RIGHT", numbers, "LEFT", -8, 0)
    local back = Paint(track, COLOR.track, 1)
    back:SetAllPoints(track)
    local bars = {}
    for index, spec in ipairs({ { LEVEL.warn, 0.35 }, { LEVEL.warn, 0.6 }, { LEVEL.ok, 1 } }) do
        local bar = Paint(track, spec[1], spec[2], "ARTWORK")
        bar:SetPoint("LEFT", track, "LEFT", 0, 0)
        bar:SetHeight(10)
        bars[index] = bar
    end
    frame:SetScript("OnEnter", function()
        if frame.tip then ShowTip(frame, mode.label, frame.tip) end
    end)
    frame:SetScript("OnLeave", HideTip)
    local timing = { frame = frame, height = ROW_TIMING, numbers = numbers, track = track, bars = bars }
    function timing:Set(row, scale)
        SetIf(numbers, "cached", Model.TimingText(row))
        local p50, p95, p99 = Model.TimingBars(row, scale)
        local width = track:GetWidth()
        local fractions = { p99, p95, p50 }
        for index, bar in ipairs(bars) do
            local size = width * fractions[index]
            bar:SetShown(size > 0)
            if size > 0 then bar:SetWidth(math.max(1, size)) end
        end
        if (row.count or 0) > 0 then
            frame.tip = string.format("p50 %.3f ms, p95 %.3f ms, p99 %.3f ms, max %.3f ms over %d samples", row.p50, row.p95, row.p99, row.max, row.count)
        else
            frame.tip = "No samples yet this session."
        end
    end
    card.rows[#card.rows + 1] = timing
    return timing
end

local function NewFinderTile(parent, onClick)
    local frame = CreateFrame("Button", nil, parent)
    frame:SetHeight(TILE_HEIGHT)
    local fill = Paint(frame, COLOR.line, 0.55)
    fill:SetAllPoints(frame)
    Outline(frame, COLOR.line)
    local tint = Paint(frame, COLOR.line, 0.6, "ARTWORK")
    tint:SetAllPoints(frame)
    tint:Hide()
    local edge = Paint(frame, COLOR.accent, 1, "OVERLAY")
    edge:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    edge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    edge:SetWidth(3)
    edge:Hide()
    local well = Paint(frame, COLOR.card, 1, "ARTWORK")
    well:SetSize(32, 32)
    well:SetPoint("LEFT", frame, "LEFT", 10, 0)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(TILE_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetSize(26, 26)
    icon:SetPoint("CENTER", well, "CENTER", 0, 0)
    local arrow = Text(frame, 18, COLOR.muted, "RIGHT")
    arrow:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    arrow:SetText(">")
    local title = Text(frame, 13, COLOR.text)
    title:SetPoint("TOPLEFT", well, "TOPRIGHT", 10, -2)
    title:SetText(TILE_TEXT.closed[1])
    local subtitle = Text(frame, 11, COLOR.muted)
    subtitle:SetPoint("BOTTOMLEFT", well, "BOTTOMRIGHT", 10, 2)
    subtitle:SetPoint("RIGHT", arrow, "LEFT", -8, 0)
    subtitle:SetText(TILE_TEXT.closed[2])
    frame:SetScript("OnClick", onClick)
    frame:HookScript("OnEnter", function()
        edge:Show()
        Tint(arrow, COLOR.accent)
    end)
    frame:HookScript("OnLeave", function()
        edge:Hide()
        Tint(arrow, COLOR.muted)
    end)
    FX.Hover(frame, tint)
    FX.Press(frame, fill)
    local tile = { frame = frame, height = ROW_TILE, open = false, title = title, subtitle = subtitle }
    function tile:Set(open)
        open = open and true or false
        if open == self.open then return end
        self.open = open
        local text = open and TILE_TEXT.open or TILE_TEXT.closed
        title:SetText(text[1])
        subtitle:SetText(text[2])
    end
    return tile
end

function Dev:BuildFinderCard(parent)
    local spec = self.spec
    local card = NewCard(parent, "Spell Finder")
    card.action = NewFinderTile(card.frame, function()
        spec.toggleFinder()
        card.action:Set(spec.finderOpen())
    end)
    card.rows[#card.rows + 1] = card.action
    self.scope = self:AddSetting(card, { kind = "select", label = "Search in", options = List.SCOPES, set = spec.setScope,
        tip = "Names: spell names only. Names + descriptions: name matches first, then matches inside spell descriptions. Descriptions: only the description text. Either description option builds a saved index of spell descriptions while the Spell Finder window is open (loaded in small batches, paused when the window closes, a few MB). Description searches need 3+ characters." })
    self.fuzzy = self:AddSetting(card, { kind = "toggle", label = "Fuzzy name search", hint = "Typo-tolerant matching, ranked by closeness.",
        set = function(value) spec.setFlag("fuzzy", value) end,
        tip = "Substring anywhere in the name, then in-order letters (abbreviations like frstblt), then one or two typos (the first letter must be right). Results rank by closeness. Typo-heavy queries cost more than plain ones." })
    self.autocomplete = self:AddSetting(card, { kind = "toggle", label = "Autocomplete spell names", hint = "Up to 8 suggestions while typing.",
        set = function(value) spec.setFlag("autocomplete", value) end,
        tip = "Up to 8 spell-name suggestions under the search box while typing (2+ characters, prefix match). Tab accepts the first or highlighted one, Up and Down move the highlight." })
    return card
end

function Dev:BuildDebugCard(parent)
    local spec = self.spec
    local card = NewCard(parent, "Debug")
    self.debugRow = self:AddSetting(card, { kind = "toggle", label = "Debug mode", hint = "Traces of alert decisions go to chat.",
        set = function(value) spec.setDebug(value) end,
        tip = "Prints readable traces of alert decisions, skipped chat sends, secret-value fallbacks and timings to chat. Each line is tagged with time and module, and the /sa test commands unlock." })
    self:AddSetting(card, { kind = "button", label = "Diagnostics report", hint = "Status, database, timings and memory as text.", button = "Copy diagnostics",
        onClick = function() self:ShowReport() end })
    return card
end

function Dev:BuildDatabaseCard(parent)
    local card = NewCard(parent, "Database")
    local button = Kit.MakeButton(card.frame, "Rebuild database", function() self:RequestRebuild() end)
    button.frame:SetPoint("TOPRIGHT", card.frame, "TOPRIGHT", -10, -5)
    self.rebuild = button
    self:AddNote(card)
    self.databaseRows = self:AddKvList(card, DATABASE_ROWS)
    return card
end

function Dev:BuildPerformanceCard(parent)
    local card = NewCard(parent, "Performance")
    local refresh = Kit.MakeButton(card.frame, "Refresh", function() self:Tick(true, true) end)
    refresh.frame:SetWidth(70)
    refresh.frame:SetPoint("TOPRIGHT", card.frame, "TOPRIGHT", -10, -5)
    self:AddLegend(card)
    self.timingRows = {}
    for index, mode in ipairs(Model.TIMINGS) do
        self.timingRows[index] = self:AddTiming(card, mode)
    end
    self.memoryRows = self:AddKvList(card, 2)
    return card
end

function Dev:BuildDescriptionCard(parent)
    local card = NewCard(parent, "Description index")
    self.descriptionRows = self:AddKvList(card, 3)
    self.clearButton = self:AddSetting(card, { kind = "button", label = "Clear description index", hint = "Deletes the saved index to free space.", button = "Clear index",
        onClick = function()
            self.spec.clearDescriptions()
            self:Tick(true)
        end })
    return card
end

function Dev:BuildInternalsCard(parent)
    local card = NewCard(parent, "Database internals")
    self.internalRows = self:AddKvList(card, 3)
    return card
end

function Dev:BuildView()
    local view = NewView(self.body)
    self.view = view
    local child = view.child
    self.heading = NewHeading(child, "TOOLS")
    self.finderCard = self:BuildFinderCard(child)
    self.debugCard = self:BuildDebugCard(child)
    self.databaseCard = self:BuildDatabaseCard(child)
    self.performanceCard = self:BuildPerformanceCard(child)
    self.moreDivider = NewDivider(child, "MORE OPTIONS")
    self.descriptionCard = self:BuildDescriptionCard(child)
    self.internalsCard = self:BuildInternalsCard(child)
    view.onWidth = function(width)
        self.width = width
        self:Layout()
    end
end

function Dev:Layout()
    local width = self.width
    if not width then return end
    local child = self.view.child
    local half = math.floor((width - GAP) / 2)
    self.heading:ClearAllPoints()
    self.heading:SetPoint("TOPLEFT", child, "TOPLEFT", 4, 0)
    local y = 22
    local left = PlaceCard(self.finderCard, child, 0, y, half)
    left = left + GAP + PlaceCard(self.debugCard, child, 0, y + left + GAP, half)
    local right = PlaceCard(self.databaseCard, child, half + GAP, y, half)
    self.performanceTop = y + right + GAP
    local performanceHeight = PlaceCard(self.performanceCard, child, half + GAP, self.performanceTop, half)
    self.performanceBottom = self.performanceTop + performanceHeight
    right = right + GAP + performanceHeight
    y = y + math.max(left, right) + GAP
    y = PlaceDivider(self.moreDivider, child, width, y)
    local first = PlaceCard(self.descriptionCard, child, 0, y, half)
    local second = PlaceCard(self.internalsCard, child, half + GAP, y, half)
    self.view:SetContentHeight(y + math.max(first, second) + 20)
    if self.lastTimings then self:ApplyPerformance(self.lastTimings, self.lastInfo) end
end

function Dev:PerformanceVisible()
    if not self.performanceTop or not self.frame:IsVisible() then return false end
    local scroll = self.view.scroll
    local offset = scroll:GetVerticalScroll()
    return self.performanceTop < offset + scroll:GetHeight() and self.performanceBottom > offset
end

function Dev:BuildHeader()
    local frame = self.frame
    self.title = Text(frame, 20, COLOR.accent)
    self.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -2)
    self.title:SetText("Developer Tools")

    self.pill = CreateFrame("Frame", nil, frame)
    self.pill:SetHeight(22)
    self.pill:SetPoint("LEFT", self.title, "RIGHT", 12, 0)
    self.pillFill = Paint(self.pill, LEVEL.ok, 0.16)
    self.pillFill:SetAllPoints(self.pill)
    self.pillText = Text(self.pill, 12.5, LEVEL.ok, "CENTER")
    self.pillText:SetAllPoints(self.pill)

    local copy = Kit.MakeButton(frame, "Copy diagnostics", function() self:ShowReport() end)
    copy.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -2)

    self.reasons = Text(frame, 11.5, COLOR.muted)
    self.reasons:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -8)
    self.reasons:SetPoint("RIGHT", frame, "RIGHT", -150, 0)
    if self.reasons.SetWordWrap then self.reasons:SetWordWrap(true) end
    self.reasons:SetJustifyV("TOP")
    self.reasons:SetHeight(32)

    self.progress = NewProgressBar(frame)
    self.progress.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -BAR_TOP)
    self.progress.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -BAR_TOP)

    self.vitals = {}
    local strip = {}
    for index = 1, 5 do
        self.vitals[index] = NewVital(frame)
        strip[index] = self.vitals[index]
    end
    local debug = CreateFrame("Frame", nil, frame)
    debug:SetSize(70, 18)
    local debugLabel = Text(debug, 12, COLOR.muted)
    debugLabel:SetPoint("LEFT", debug, "LEFT", 0, 0)
    debugLabel:SetText("debug")
    self.stripDebug = Kit.MakeToggle(debug, function(value)
        self.spec.setDebug(value)
        self:Tick(true)
    end)
    self.stripDebug.frame:SetPoint("LEFT", debug, "LEFT", 38, 0)
    strip[#strip + 1] = { frame = debug }
    self.strip = strip

    local rule = Paint(frame, COLOR.line)
    rule:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(HEADER_HEIGHT - 3))
    rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -(HEADER_HEIGHT - 3))
    rule:SetHeight(1)
end

function Dev:LayoutHeader()
    local width = self.frame:GetWidth()
    Kit.Flow(self.frame, self.strip, math.max(200, width - 8), 18, 4, 80, 22)
end

function Dev:BuildOverlay()
    local overlay = CreateFrame("Frame", nil, self.frame)
    overlay:SetAllPoints(self.frame)
    overlay:SetFrameLevel(self.frame:GetFrameLevel() + 60)
    overlay:EnableMouse(true)
    local dim = Paint(overlay, { 0.02, 0.03, 0.04 }, 0.78)
    dim:SetAllPoints(overlay)
    local box = CreateFrame("Frame", nil, overlay)
    box:SetSize(560, 360)
    box:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    local fill = Paint(box, COLOR.card, 1)
    fill:SetAllPoints(box)
    Outline(box, COLOR.track)
    local title = Text(box, 14, COLOR.text)
    title:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -12)
    title:SetText("Diagnostics")
    local hint = Text(box, 11.5, COLOR.muted)
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    hint:SetText("Selected for you: press Ctrl+C, then paste it into a bug report.")
    local close = Kit.MakeButton(box, "Close", function() overlay:Hide() end)
    close.frame:SetPoint("TOPRIGHT", box, "TOPRIGHT", -12, -10)
    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -56)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -14, 14)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFont(Kit.FONT, 12, "")
    edit:SetWidth(520)
    scroll:SetScrollChild(edit)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local range = math.max(0, edit:GetHeight() - scroll:GetHeight())
        scroll:SetVerticalScroll(math.max(0, math.min(range, scroll:GetVerticalScroll() - delta * Kit.SCROLL_STEP)))
    end)
    edit:SetScript("OnEscapePressed", function() overlay:Hide() end)
    overlay:Hide()
    self.overlay, self.report = overlay, edit
end

function Dev:ShowReport()
    self.report:SetText(self.spec.report())
    self.overlay:Show()
    self.report:SetFocus()
    self.report:HighlightText()
end

function Dev:RequestRebuild()
    if self.armed then
        self.armed = false
        self.rebuildNote:SetText("")
        self.spec.rebuild()
        self:Tick(true)
        return
    end
    local _, _, warning = self.spec.rebuildInfo()
    self.armed = true
    self.rebuildNote:SetText(warning)
    self.rebuild.label:SetText("Confirm rebuild")
    self.rebuild.frame:SetWidth(math.max(70, self.rebuild.label:GetStringWidth() + 24))
    if C_Timer and C_Timer.After then
        C_Timer.After(Model.ARM_SECONDS, function() self:Disarm() end)
    end
end

function Dev:Disarm()
    if not self.armed then return end
    self.armed = false
    self.rebuildNote:SetText("")
    self:ApplyRebuildButton()
end

function Dev:ApplyRebuildButton()
    local building = self.lastInfo and self.lastInfo.isBuilding
    local text = building and "Rebuilding..." or (self.armed and "Confirm rebuild" or "Rebuild database")
    self.rebuild.label:SetText(text)
    self.rebuild.frame:SetWidth(math.max(70, self.rebuild.label:GetStringWidth() + 24))
    self.rebuild.frame:SetAlpha(building and 0.4 or 1)
    self.rebuild.frame:EnableMouse(not building)
end

function Dev:ApplyInfo(info)
    self.lastInfo = info
    local level, label, reasons = Model.Verdict(info)
    SetIf(self.pillText, "cached", label)
    self.pill:SetWidth(self.pillText:GetStringWidth() + 28)
    Tint(self.pillFill, LEVEL[level], 0.16)
    Tint(self.pillText, LEVEL[level])
    local text = #reasons > 0 and ("- " .. table.concat(reasons, "\n- ")) or "Database current, nothing to do."
    SetIf(self.reasons, "cached", text)

    local vitals = Model.Vitals(info)
    local state = vitals.building and "warn" or "ok"
    local hold = vitals.building
    local moved = self.vitals[1]:Set(state, nil, vitals.building and string.format("Building %.0f%%", vitals.progress) or "Ready", state, nil, hold)
    moved = self.vitals[2]:Set(nil, nil, SA_StatsFormat.Number(vitals.spells), nil, "spells", hold) or moved
    moved = self.vitals[3]:Set(nil, "updated", vitals.ageText or "never", vitals.ageLevel, nil, hold) or moved
    moved = self.vitals[4]:Set(nil, "build", vitals.build == "bad" and "outdated" or (vitals.build and "current" or "unknown"), vitals.build, nil, hold) or moved
    moved = self.vitals[5]:Set(nil, nil, vitals.memoryText, vitals.memoryLevel == "warn" and "warn" or nil, "memory", hold) or moved
    self.stripDebug:Set(vitals.debug)
    if moved then self:LayoutHeader() end

    self.progress.frame:SetShown(vitals.building)
    if vitals.building then self.progress:Set(vitals.progress) end
    self:SetKvList(self.databaseRows, Model.DatabaseRows(info))
    self:SetKvList(self.internalRows, Model.InternalRows(info))
    self:ApplyRebuildButton()

    local finder = self.spec.finderSettings()
    self.scope.control:Set(finder.scope)
    self.fuzzy.control:Set(finder.fuzzy)
    self.autocomplete.control:Set(finder.autocomplete)
    self.debugRow.control:Set(vitals.debug)
end

function Dev:ApplyDescription(description)
    self:SetKvList(self.descriptionRows, Model.DescriptionRows(description))
    local built = description.built
    self.clearButton.button.frame:SetAlpha(built and 1 or 0.4)
    self.clearButton.button.frame:EnableMouse(built and true or false)
end

function Dev:ApplyPerformance(timings, info)
    self.lastTimings = timings
    local scale = Model.TimingScale(timings)
    for index, row in ipairs(self.timingRows) do row:Set(timings[index], scale) end
    if info then
        self:SetKvList(self.memoryRows, {
            { "Memory", Model.MemoryMB(info.memoryKB), Model.MemoryLevel(info.memoryKB) == "warn" and "warn" or nil },
            { "Search cache", (info.cacheEntries or 0) .. " / " .. (info.cacheMax or 0) .. " entries" },
        })
    end
end

function Dev:Tick(force, memory)
    if not self.spec.db() then return end
    local wantPerformance = self:PerformanceVisible()
    local info = self.spec.snapshot(wantPerformance or memory, memory)
    local signature = Model.Signature(info)
    if force or signature ~= self.signature then
        self.signature = signature
        self:ApplyInfo(info)
    end
    self.finderCard.action:Set(self.spec.finderOpen())
    local description = self.spec.description()
    local descriptionSignature = description.built and (description.indexed .. "|" .. description.empty .. "|" .. tostring(description.running) .. "|" .. math.floor(description.kb)) or "none"
    if force or descriptionSignature ~= self.descriptionSignature then
        self.descriptionSignature = descriptionSignature
        self:ApplyDescription(description)
    end
    if wantPerformance or memory then
        self:ApplyPerformance(self.spec.timings(), info)
    end
end

function Dev:StartTicker()
    self:StopTicker()
    self.hiddenTicks = 0
    self.ticker = self.spec.newTicker(Model.TICK_SECONDS, function()
        if not self.frame:IsVisible() then
            self.hiddenTicks = self.hiddenTicks + 1
            if self.hiddenTicks >= HIDDEN_TICKS then self:StopTicker() end
            return
        end
        self.hiddenTicks = 0
        self:Tick(false)
    end)
end

function Dev:StopTicker()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
end

local function BuildPage(spec)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    local page = { frame = frame, spec = spec, settings = {} }
    for name, method in pairs(Dev) do page[name] = method end
    page:BuildHeader()
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -HEADER_HEIGHT)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    page.body = body
    page:BuildView()
    page:BuildOverlay()
    frame:SetScript("OnShow", function()
        if not page.ticker then page:StartTicker() end
    end)
    frame:SetScript("OnHide", function()
        page:StopTicker()
        page:Disarm()
        page.overlay:Hide()
    end)
    frame:SetScript("OnSizeChanged", function() page:LayoutHeader() end)
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
        page.releasedAt = GetTime()
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
    page:Tick(true, true)
    page:StartTicker()
    if not page.releasedAt or GetTime() - page.releasedAt > REDRAW_SECONDS then
        FX.SlideIn(page.frame, self.frame)
    end
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

SoundAlerter.DevPage = { Get = GetPage }

do
function SoundAlerter:BuildSpellFinderOptions()
    local tools = SoundAlerter.DevTools
    local spec = self.devSpec or {
        db = function() return SoundAlerter.db1 and SoundAlerter.db1.profile end,
        snapshot = function(wantMemory, forceMemory) return tools:Snapshot(wantMemory, forceMemory) end,
        timings = function() return tools:Timings() end,
        description = function() return tools:Description() end,
        report = function() return tools:Report() end,
        finderSettings = function()
            local settings = SoundAlerter:GetFinderSettings()
            return { scope = SoundAlerter:GetSearchScope(), fuzzy = settings.fuzzy and true or false, autocomplete = settings.autocomplete and true or false }
        end,
        setScope = function(value) tools:SetScope(value) end,
        setFlag = function(key, value) tools:SetFinderFlag(key, value) end,
        setDebug = function(value) tools:SetDebug(value) end,
        toggleFinder = function() SoundAlerter:ToggleSpellFinder() end,
        finderOpen = function() return SoundAlerter:IsFinderOpen() end,
        clearDescriptions = function() SoundAlerter:ClearDescriptionIndex() end,
        rebuildInfo = function() return tools:RebuildInfo() end,
        rebuild = function() tools:Rebuild() end,
        newTicker = function(seconds, fn)
            local handle = SoundAlerter:ScheduleRepeatingTimer(fn, seconds)
            return { Cancel = function() SoundAlerter:CancelTimer(handle) end }
        end,
    }
    self.devSpec = spec
    return {
        type = 'group',
        name = "Developer Tools",
        icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
        desc = "Spell Finder, spell database and debug tools.",
        order = 5,
        args = {
            page = {
                type = 'description',
                name = "Developer Tools could not draw its page.",
                dialogControl = "SoundAlerterDevPage",
                arg = spec,
                order = 1,
            },
        },
    }
end
end
