local SoundAlerter = SoundAlerter

local SORT_OPTIONS = {
    topSpells = { { "count_desc", "Most alerts" }, { "trend", "Trend (rising first)" }, { "name_asc", "Name (A-Z)" }, { "time", "Most recent" } },
    enemies = { { "alerts_desc", "Most alerts" }, { "danger", "Danger" }, { "name_asc", "Name (A-Z)" }, { "time", "Most recent" } },
    classes = { { "alerts_desc", "Most alerts" }, { "players", "Most players" }, { "avg", "Alerts per player" }, { "class_asc", "Class (A-Z)" } },
}

local function statistics()
    return SoundAlerter:GetModule("Statistics", true)
end

local function view()
    local active = statistics()
    if not active then return nil end
    local on = active:GetSettings().enabled and true or false
    local data = { enabled = on, sort = {}, text = { kpi = "", overview = "", topSpells = "", enemies = "", classes = "", export = "" } }
    if not on then return data end
    local sorts = active:GetSortState()
    for key in pairs(SORT_OPTIONS) do data.sort[key] = sorts[key] and sorts[key].sortType end
    data.text.kpi = active:GetKpiText()
    data.text.overview = active:GetOverviewText()
    data.text.topSpells = active:GetListText("topSpells")
    data.text.enemies = active:GetListText("enemies")
    data.text.classes = active:GetListText("classes")
    data.text.export = active:GetExportText()
    data.panel = active:GetPanelModel()
    return data
end

local function write(key, value)
    local active = statistics()
    if not active then return end
    if key == "enabled" then
        active:SetSetting("enabled", value)
        if value then
            active:InitializeStatistics()
            SoundAlerter:Print("Statistics tracking enabled")
        else
            SoundAlerter:Print("Statistics tracking disabled (existing data preserved)")
        end
        return
    end
    local table_ = key:match("^sort%.(.+)$")
    if table_ then active:SetSortState(table_, value) end
end

local function summary(settings)
    if not settings.enabled then
        return "Tracking is off. Turn it on to start counting alerts."
    end
    return settings.text.kpi
end

local function reportOn(settings)
    return settings.enabled
end

local function resetSession()
    local active = statistics()
    if not active then return end
    active:ResetSession()
    SoundAlerter:Print("Session statistics reset")
end

local function resetAllTime()
    local active = statistics()
    if not active then return end
    active:ResetAllTime()
    SoundAlerter:Print("|cffFF0000All statistics reset|r")
end

local PANEL_WIDTH = 260
local TAB_VIEW_TOP = 28
local TABS = { { "now", "Now" }, { "trends", "Trends" }, { "rivals", "Rivals" } }

local function classHex(class)
    local r, g, b = SA_StatsFormat.ClassColor(class)
    return string.format("|cff%02x%02x%02x", r, g, b)
end

local function newCaption(parent, y, left)
    local Kit = SoundAlerter.Page.Kit
    local caption = Kit.Text(parent, 10, Kit.COLOR.muted)
    caption:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    caption:SetText(left)
    local right = Kit.Text(parent, 10, Kit.COLOR.muted, "RIGHT")
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
    return { left = caption, right = right }
end

local function newLine(parent, y)
    local Kit = SoundAlerter.Page.Kit
    local line = Kit.Text(parent, 11.5, Kit.COLOR.text)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    line:SetWidth(PANEL_WIDTH)
    return line
end

local function newTile(parent, x, y)
    local Kit = SoundAlerter.Page.Kit
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(128, 38)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    local fill = Kit.Paint(frame, Kit.COLOR.line, 0.5)
    fill:SetAllPoints(frame)
    local value = Kit.Text(frame, 17, Kit.COLOR.text)
    value:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -4)
    local caption = Kit.Text(frame, 10.5, Kit.COLOR.muted)
    caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 4)
    local tile = {}
    function tile:Set(item)
        value:SetText(item.value)
        caption:SetText(item.caption)
        local color = item.hot and Kit.COLOR.accent or Kit.COLOR.text
        value:SetTextColor(color[1], color[2], color[3])
    end
    return tile
end

local function newMeter(parent, y)
    local Kit = SoundAlerter.Page.Kit
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(PANEL_WIDTH, 18)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    local label = Kit.Text(frame, 11.5, Kit.COLOR.text)
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    label:SetWidth(PANEL_WIDTH - 90)
    local value = Kit.Text(frame, 11.5, Kit.COLOR.muted, "RIGHT")
    value:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    local track = Kit.Paint(frame, Kit.COLOR.track, 1)
    track:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    track:SetSize(PANEL_WIDTH, 3)
    local fill = Kit.Paint(frame, Kit.COLOR.accent, 1, "ARTWORK")
    fill:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    fill:SetHeight(3)
    local meter = { frame = frame }
    function meter:Set(text, valueText, fraction, r, g, b)
        label:SetText(text)
        value:SetText(valueText)
        fill:SetVertexColor(r or Kit.COLOR.accent[1], g or Kit.COLOR.accent[2], b or Kit.COLOR.accent[3], 1)
        fill:SetWidth(math.max(1, PANEL_WIDTH * math.max(0, math.min(1, fraction or 0))))
    end
    function meter:SetShown(shown) frame:SetShown(shown) end
    return meter
end

local function newSpark(parent, y, count, height, r, g, b)
    local Kit = SoundAlerter.Page.Kit
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(PANEL_WIDTH, height)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    local gap = 2
    local width = (PANEL_WIDTH - (count - 1) * gap) / count
    local bars = {}
    for index = 1, count do
        local bar = Kit.Paint(frame, Kit.COLOR.track, 1, "ARTWORK")
        bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (index - 1) * (width + gap), 0)
        bar:SetSize(width, 2)
        bars[index] = bar
    end
    local empty = Kit.Text(frame, 11, Kit.COLOR.muted, "CENTER")
    empty:SetAllPoints(frame)
    local spark = {}
    function spark:Set(values, isEmpty, emptyText)
        empty:SetText(isEmpty and emptyText or "")
        local maximum = 1
        for index = 1, count do
            if (values[index] or 0) > maximum then maximum = values[index] end
        end
        for index = 1, count do
            local value = values[index] or 0
            local bar = bars[index]
            if value > 0 then
                bar:SetVertexColor(r, g, b, 1)
                bar:SetHeight(math.max(3, height * value / maximum))
            else
                bar:SetVertexColor(Kit.COLOR.track[1], Kit.COLOR.track[2], Kit.COLOR.track[3], 1)
                bar:SetHeight(2)
            end
        end
    end
    return spark
end

local function selectTab(state, key)
    local Kit = SoundAlerter.Page.Kit
    state.tab = key
    for _, tab in ipairs(TABS) do
        local active = tab[1] == key
        state.views[tab[1]]:SetShown(active and state.model ~= nil)
        local button = state.buttons[tab[1]]
        local color = active and Kit.COLOR.accent or Kit.COLOR.muted
        button.label:SetTextColor(color[1], color[2], color[3])
        button.underline:SetShown(active)
    end
end

local function buildNow(view)
    local tiles = {}
    for index = 1, 4 do
        tiles[index] = newTile(view, ((index - 1) % 2) * 132, math.floor((index - 1) / 2) * 44)
    end
    local versusCaption = newCaption(view, 92, "VS YOUR AVERAGE")
    local versus = { newMeter(view, 108), newMeter(view, 128) }
    local partyCaption = newCaption(view, 154, "PARTY SHARING")
    local lines = { newLine(view, 170), newLine(view, 184), newLine(view, 198), newLine(view, 212) }
    local lastCaption = newCaption(view, 234, "LAST RIVAL SEEN")
    local last = newLine(view, 248)
    return { tiles = tiles, versus = versus, party = lines, last = last, captions = { versusCaption, partyCaption, lastCaption } }
end

local function bindNow(widgets, model)
    for index, tile in ipairs(widgets.tiles) do tile:Set(model.tiles[index]) end
    for index, meter in ipairs(widgets.versus) do
        local item = model.versus[index]
        local r, g, b = 0.6, 0.65, 0.72
        if index == 1 then r, g, b = 1, 0.49, 0.04 end
        meter:Set(item.label, item.value, item.fraction, r, g, b)
    end
    local party = model.party
    widgets.party[1]:SetText("This session   " .. party.session)
    widgets.party[2]:SetText("All-time   " .. party.allTime)
    widgets.party[3]:SetText(party.senders)
    widgets.party[4]:SetText(party.status)
    if model.last then
        widgets.last:SetText(classHex(model.last.class) .. model.last.name .. "|r  " .. model.last.when)
    else
        widgets.last:SetText("No rival seen yet.")
    end
end

local function buildTrends(view)
    local dayCaption = newCaption(view, 0, "ALERTS PER DAY, LAST 14 DAYS")
    local days = newSpark(view, 14, 14, 40, 0.35, 0.66, 1)
    local hourCaption = newCaption(view, 64, "BUSIEST HOURS (LOCAL)")
    local hours = newSpark(view, 78, 24, 40, 0.24, 0.86, 0.59)
    local moverCaption = newCaption(view, 128, "RISING AND FALLING SPELLS")
    local movers = {}
    for index = 1, 4 do movers[index] = newLine(view, 142 + (index - 1) * 14) end
    return { dayCaption = dayCaption, days = days, hourCaption = hourCaption, hours = hours, movers = movers, captions = { moverCaption } }
end

local function bindTrends(widgets, model)
    local days, hours = model.days, model.hours
    widgets.dayCaption.right:SetText(days.empty and "" or ("peak " .. days.peak))
    widgets.days:Set(days.values, days.empty, "No alerts recorded in the last 14 days yet")
    widgets.hourCaption.right:SetText(hours.peak and ("peak " .. hours.peak) or "")
    widgets.hours:Set(hours.values, hours.empty, "No alerts recorded yet")
    local movers = model.movers
    for index, line in ipairs(widgets.movers) do
        local entry = movers[index]
        if entry then
            line:SetText(string.format("|cff%02x%02x%02x%s|r %s   |cff96a0b2%s|r", entry.color[1], entry.color[2], entry.color[3], entry.sign, entry.name, entry.text))
        elseif index == 1 then
            line:SetText("|cff96a0b2Needs a few sessions with spell alerts to show a trend.|r")
        else
            line:SetText("")
        end
    end
end

local function buildRivals(view)
    local rivalCaption = newCaption(view, 0, "TOP RIVALS")
    rivalCaption.right:SetText("alerts - encounters")
    local rows = {}
    for index = 1, 6 do rows[index] = newMeter(view, 14 + (index - 1) * 22) end
    local empty = newLine(view, 14)
    local visitorCaption = newCaption(view, 156, "MOST REPEAT VISITORS")
    visitorCaption.right:SetText("alerts per player")
    local visitors = {}
    for index = 1, 3 do visitors[index] = newLine(view, 170 + (index - 1) * 16) end
    return { rows = rows, empty = empty, visitors = visitors, captions = { rivalCaption, visitorCaption } }
end

local function bindRivals(widgets, model)
    local rows = model.rows
    widgets.empty:SetText(#rows == 0 and "|cff96a0b2No enemy players tracked yet.|r" or "")
    for index, meter in ipairs(widgets.rows) do
        local row = rows[index]
        meter:SetShown(row ~= nil)
        if row then
            local r, g, b = SA_StatsFormat.ClassColor(row.class)
            local tag = string.format("|cff%02x%02x%02x%s|r", row.dangerColor[1], row.dangerColor[2], row.dangerColor[3], row.danger)
            meter:Set(classHex(row.class) .. row.name .. "|r  " .. tag, row.value, row.fraction, r / 255, g / 255, b / 255)
        end
    end
    for index, line in ipairs(widgets.visitors) do
        local entry = model.classes[index]
        if entry then
            line:SetText(classHex(entry.class) .. SA_StatsFormat.ClassName(entry.class) .. "|r   |cff96a0b2" .. entry.text .. "|r")
        else
            line:SetText(index == 1 and "|cff96a0b2No class data yet.|r" or "")
        end
    end
end

local Panel = { height = 300, caption = "SNAPSHOT" }

function Panel.build(stage)
    local Kit = SoundAlerter.Page.Kit
    local state = { tab = "now", views = {}, buttons = {}, widgets = {} }
    for index, tab in ipairs(TABS) do
        local button = CreateFrame("Button", nil, stage)
        button:SetSize(62, 22)
        button:SetPoint("TOPLEFT", stage, "TOPLEFT", (index - 1) * 64, 0)
        local label = Kit.Text(button, 12, Kit.COLOR.muted, "CENTER")
        label:SetAllPoints(button)
        label:SetText(tab[2])
        local underline = Kit.Paint(button, Kit.COLOR.accent, 1, "OVERLAY")
        underline:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 6, 0)
        underline:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 0)
        underline:SetHeight(2)
        underline:Hide()
        button.label, button.underline = label, underline
        button:SetScript("OnClick", function() selectTab(state, tab[1]) end)
        state.buttons[tab[1]] = button
        local view = CreateFrame("Frame", nil, stage)
        view:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, -TAB_VIEW_TOP)
        view:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", 0, 0)
        view:Hide()
        state.views[tab[1]] = view
    end
    state.widgets.now = buildNow(state.views.now)
    state.widgets.trends = buildTrends(state.views.trends)
    state.widgets.rivals = buildRivals(state.views.rivals)
    state.off = Kit.Text(stage, 11.5, Kit.COLOR.muted, "CENTER")
    state.off:SetAllPoints(stage)
    state.off:SetText("Tracking is off. Turn it on to see your snapshot here.")
    return state
end

function Panel.update(state, settings)
    if not state then return end
    local model = settings.panel
    state.model = model
    state.off:SetShown(model == nil)
    for _, button in pairs(state.buttons) do button:SetShown(model ~= nil) end
    if model then
        bindNow(state.widgets.now, model.now)
        bindTrends(state.widgets.trends, model.trends)
        bindRivals(state.widgets.rivals, model.rivals)
    end
    selectTab(state, state.tab)
end

function SoundAlerter:BuildStatisticsOptions()
    local Page = SoundAlerter.Page

    local function block(label, group, getter)
        return Page.Visible(reportOn, Page.Block(label, getter, false, group))
    end

    local function sorter(key, label, group)
        return Page.Visible(reportOn, Page.Select("sort." .. key, "Sort by", "How the list below is ordered.", SORT_OPTIONS[key], false, group))
    end

    local exportRow = Page.Text("text.export", "Export", "Select all and copy to share or keep your numbers.", true, "Data", 8)
    local resetSessionRow = Page.Action("Reset session", "Reset this session's numbers. All-time statistics are kept.", resetSession, true, "Data")
    resetSessionRow.confirm = "Click again to reset"
    local resetAllRow = Page.Action("Reset all-time", "Delete all statistics for this profile, session and all-time. This cannot be undone.", resetAllTime, true, "Data")
    resetAllRow.confirm = "Click again to delete everything"

    local spec = Page.Spec({
        title = "Statistics",
        icon = "Interface\\Icons\\Spell_Holy_MindVision",
        blurb = "What triggered your alerts this session and all-time: which fired, from whom and where. Counting costs under 0.02 ms per alert.",
        get = view,
        set = write,
        summary = summary,
        preview = Panel,
        rows = {
            Page.Visible(reportOn, Page.Action("Refresh", "Redraw the statistics with the latest numbers.", function() end, false, "Overview")),
            block("Overview", "Overview", function(settings) return settings.text.overview end),
            sorter("topSpells", "Sort by", "Spells"),
            block("Spells", "Spells", function(settings) return settings.text.topSpells end),
            sorter("enemies", "Sort by", "Enemies"),
            block("Enemies", "Enemies", function(settings) return settings.text.enemies end),
            sorter("classes", "Sort by", "Classes"),
            block("Classes", "Classes", function(settings) return settings.text.classes end),
            Page.Visible(reportOn, exportRow),
            Page.Visible(reportOn, resetSessionRow),
            Page.Visible(reportOn, resetAllRow),
        },
    })
    local options = Page.Options(spec, "Statistics", "Interface\\Icons\\Spell_Holy_MindVision", "Alert statistics for this profile.", 2.9)
    return Page.Guard(options, "Statistics", "Statistics", statistics)
end
