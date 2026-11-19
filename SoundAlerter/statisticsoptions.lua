local SoundAlerter = SoundAlerter

local SORT_OPTIONS = {
    topSpells = { { "count_desc", "Most alerts" }, { "trend", "Trend (rising first)" }, { "name_asc", "Name (A-Z)" }, { "time", "Most recent" } },
    enemies = { { "alerts_desc", "Most alerts" }, { "danger", "Threat" }, { "name_asc", "Name (A-Z)" }, { "time", "Most recent" } },
    classes = { { "alerts_desc", "Most alerts" }, { "players", "Most players" }, { "avg", "Alerts per player" }, { "class_asc", "Class (A-Z)" } },
}

local expanded = { topSpells = false, enemies = false, classes = false }
local MODES = { all = true, session = true, bg = true, honor = true }
local OVERVIEW_MODES = { all = true, session = true }

local function statistics()
    return SoundAlerter:GetModule("Statistics", true)
end

local function view()
    local active = statistics()
    if not active then return nil end
    local on = active:GetSettings().enabled and true or false
    local data = { enabled = on, sort = {}, text = { kpi = "", topSpells = "", enemies = "", classes = "", export = "" }, counts = {} }
    if not on then return data end
    local settings = active:GetSettings()
    local mode = settings.overviewMode
    data.mode = MODES[mode] and mode or "all"
    data.bgPill = settings.bgPill ~= false
    if data.mode == "bg" then
        data.bg = active:GetBG()
        return data
    end
    if data.mode == "honor" then
        data.bg = active:GetBG()
        data.honor = active:GetHonor()
        data.now = time()
        data.today, data.offset = active:HonorDay(data.now)
        return data
    end
    local sorts = active:GetSortState()
    for key in pairs(SORT_OPTIONS) do data.sort[key] = sorts[key] and sorts[key].sortType end
    data.dashboard = active:GetDashboard(data.mode)
    data.counts = active:GetListCounts() or data.counts
    data.text.kpi = active:GetKpiText()
    if expanded.topSpells then data.text.topSpells = active:GetListText("topSpells") end
    if expanded.enemies then data.text.enemies = active:GetListText("enemies") end
    if expanded.classes then data.text.classes = active:GetListText("classes") end
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
            active:UpdateMatch()
            SoundAlerter:Print("Statistics tracking disabled (existing data preserved)")
        end
        return
    end
    if key == "mode" then
        active:SetSetting("overviewMode", MODES[value] and value or "all")
        return
    end
    if key == "bgPill" then
        active:SetSetting("bgPill", value and true or false)
        if not value then SoundAlerter:HideBGResult() end
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
local TABS = { { "now", "Now" }, { "trends", "Trends" }, { "rivals", "Rivals" }, { "visuals", "Visuals" }, { "global", "Global" } }
local TAB_WIDTH, TAB_STEP = 50, 52
local GLOBAL_REFRESH = 15

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

local HOUR_TICKS = { { 1, "00", "LEFT" }, { 7, "06", "CENTER" }, { 13, "12", "CENTER" }, { 19, "18", "CENTER" }, { 24, "23", "RIGHT" } }

local function newSpark(parent, y, count, height, r, g, b, ticks)
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
    local spark = { ticks = {} }
    for index, tick in ipairs(ticks or {}) do
        local center = (tick[1] - 1) * (width + gap) + width / 2
        local mark = Kit.Paint(frame, Kit.COLOR.muted, 1, "ARTWORK")
        mark:SetPoint("TOP", frame, "BOTTOMLEFT", center, -1)
        mark:SetSize(1, 3)
        local label = Kit.Text(frame, 9, Kit.COLOR.muted, tick[3])
        if tick[3] == "LEFT" then
            label:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
        elseif tick[3] == "RIGHT" then
            label:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
        else
            label:SetPoint("TOP", frame, "BOTTOMLEFT", center, -4)
        end
        label:SetText(tick[2])
        spark.ticks[index] = label
    end
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

local MEDIA = "Interface\\AddOns\\SoundAlerter\\Textures\\"
local DISC_TEXTURE = MEDIA .. "circle"
local ZONE_RING_TEXTURE = MEDIA .. "venn_ring"
local ICON_RING_TEXTURE = MEDIA .. "cp_ring"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local LEGEND_WIDTH = 50
local LEGEND_GAP = 2
local ICON_POOL = 48
local DISC_ALPHA, DISC_HOT = 0.14, 0.3
local RING_ALPHA, RING_HOT = 0.55, 1
local HIDDEN_DIM = 0.4
local NO_ENTRIES = {}
local MODE_HEIGHT = 18
local LEGEND_ROW = 18
local LEGEND_PER_ROW = 5
local SHARE_ROW = 15
local SHARE_LABEL = 70
local SHARE_COUNT = 30

local SOURCES = {
    visuals = {
        kind = "spells",
        label = "Spells",
        unit = "alerts",
        honest = true,
        groups = "GROUPS",
        entries = function()
            local active = statistics()
            return active and active:GetVennData() or NO_ENTRIES
        end,
        note = function(_, layout)
            local profile = SoundAlerter.db1 and SoundAlerter.db1.profile
            return SA_StatsVenn.NoteText(layout, nil, profile and profile.battleVoices)
        end,
        empty = function() return "No spells with a recorded zone yet. Play a match and they appear here." end,
    },
    classes = {
        kind = "classes",
        label = "Classes",
        unit = "players",
        groups = "CLASSES",
        entries = function()
            local active = statistics()
            return active and active:GetClassVennData() or NO_ENTRIES
        end,
        shares = function()
            local active = statistics()
            return active and active:GetClassShares() or nil
        end,
        note = function(source, layout) return SA_StatsVenn.ClassNoteText(layout, source.shares(source)) end,
        empty = function() return "No enemy players with a zone yet. Proximity and spell alerts add them, battlegrounds included." end,
    },
}
local VISUAL_MODES = { SOURCES.visuals, SOURCES.classes }

local function globalEmptyText(players)
    if not (SoundAlerter.GlobalStatsActive and SoundAlerter:GlobalStatsActive()) then
        return "Global sightings is off. Turn it on under Proximity Alerts to share and see global statistics."
    end
    if (players or 0) == 0 then
        return "No reports yet. SoundAlerter players on your realm and faction report every 15 minutes."
    end
    if players == 1 then
        return "1 player reporting (you). Your spells show here once your next report goes out."
    end
    return players .. " players reporting. Spells show here once their reports arrive."
end

local function spellTexture(spellID)
    local api = C_Spell and C_Spell.GetSpellTexture
    return api and api(spellID) or FALLBACK_ICON
end

local function put(label, text)
    if label.venText ~= text then
        label.venText = text
        label:SetText(text)
    end
end

local function heatZones(widgets, mask)
    local key = mask or false
    if widgets.heat == key then return end
    widgets.heat = key
    local Venn = SA_StatsVenn
    local honest = widgets.source and widgets.source.honest
    for index, zone in ipairs(widgets.zones) do
        local hot = mask ~= nil and Venn.HasZone(mask, index)
        local color = Venn.ZONES[index].color
        local dim = (honest and index == 2) and HIDDEN_DIM or 1
        zone.disc:SetVertexColor(color[1], color[2], color[3], (hot and DISC_HOT or DISC_ALPHA) * dim)
        zone.ring:SetVertexColor(color[1], color[2], color[3], (hot and RING_HOT or RING_ALPHA) * dim)
    end
end

local function showIconTip(button)
    local item = button.item
    if not item then return end
    local Venn = SA_StatsVenn
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if item.more then
        local first = item.hidden[1]
        GameTooltip:SetText(string.format("%d more %s", #item.hidden, first and first.class and "classes" or "spells"), 1, 1, 1)
        for index = 1, math.min(#item.hidden, 8) do
            local hidden = item.hidden[index]
            GameTooltip:AddLine(hidden.class and (hidden.total .. " " .. Venn.CLASS_LABEL[hidden.class]) or hidden.name, 0.8, 0.8, 0.8)
        end
        if #item.hidden > 8 then GameTooltip:AddLine("...", 0.6, 0.65, 0.72) end
    elseif item.entry.class then
        local entry = item.entry
        local color = Venn.CLASS_COLOR[entry.class]
        GameTooltip:SetText(string.format("%d %s", entry.total, Venn.CLASS_LABEL[entry.class]), color[1], color[2], color[3])
        GameTooltip:AddLine(Venn.REGION_NAME[entry.mask], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(table.concat(entry.names, ", ") .. (entry.total > #entry.names and ", ..." or ""), 0.6, 0.65, 0.72, true)
    else
        local entry = item.entry
        local color = Venn.GROUP_COLOR[entry.group]
        GameTooltip:SetText(entry.name, color[1], color[2], color[3])
        GameTooltip:AddLine(string.format("%s   ID %d", entry.category, entry.id), 0.6, 0.65, 0.72)
        local unit = button.owner.source.unit
        GameTooltip:AddLine(SA_StatsFormat.Number(entry.total) .. " " .. unit, 1, 1, 1)
        local byZone = entry.byZone or {}
        GameTooltip:AddLine(string.format("Arena %d   Battlegrounds %d   World %d", byZone.arena or 0, byZone.battleground or 0, byZone.worldPvP or 0), 0.8, 0.8, 0.8)
        local class = entry.byClass and Venn.TopKey(entry.byClass)
        if class then GameTooltip:AddLine("Mostly " .. SA_StatsFormat.ClassName(class), 0.8, 0.8, 0.8) end
        GameTooltip:AddLine("Click: open in Spell Finder", 1, 0.49, 0.04)
    end
    GameTooltip:Show()
    heatZones(button.owner, item.mask)
end

local function hideIconTip(button)
    GameTooltip:Hide()
    heatZones(button.owner, nil)
end

local function clickIcon(button)
    local item = button.item
    if item and not item.more and not item.entry.class then SoundAlerter:OpenSpellFinderFor(item.entry.id) end
end

local function newIcon(widgets)
    local Kit = SoundAlerter.Page.Kit
    local button = CreateFrame("Button", nil, widgets.canvas)
    button:SetFrameLevel(widgets.canvas:GetFrameLevel() + 2)
    local art = button:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints(button)
    if button.CreateMaskTexture and art.AddMaskTexture then
        local mask = button:CreateMaskTexture()
        mask:SetTexture(DISC_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(button)
        art:AddMaskTexture(mask)
    end
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(ICON_RING_TEXTURE)
    ring:SetAllPoints(button)
    local count = Kit.Text(button, 9, Kit.COLOR.text, "CENTER")
    count:SetAllPoints(button)
    button.art, button.ring, button.count, button.owner = art, ring, count, widgets
    button:SetScript("OnEnter", showIconTip)
    button:SetScript("OnLeave", hideIconTip)
    button:SetScript("OnClick", clickIcon)
    return button
end

local function styleIcon(icon, item)
    local Kit = SoundAlerter.Page.Kit
    if icon.styledSize ~= item.size then
        icon.styledSize = item.size
        icon:SetSize(item.size, item.size)
    end
    local hidden = item.more and #item.hidden or 0
    if icon.styledKey == item.key and icon.styledHidden == hidden then return end
    icon.styledKey, icon.styledHidden = item.key, hidden
    if item.more then
        icon.art:SetColorTexture(0.05, 0.06, 0.08, 1)
        icon.art:SetTexCoord(0, 1, 0, 1)
        icon.ring:SetVertexColor(Kit.COLOR.muted[1], Kit.COLOR.muted[2], Kit.COLOR.muted[3], 1)
        icon.count:SetText("+" .. hidden)
    elseif item.entry.class then
        local color = SA_StatsVenn.CLASS_COLOR[item.entry.class]
        icon.art:SetColorTexture(0.05, 0.06, 0.08, 1)
        icon.art:SetTexCoord(0, 1, 0, 1)
        icon.ring:SetVertexColor(color[1], color[2], color[3], 1)
        icon.count:SetText(item.entry.total)
    else
        local color = SA_StatsVenn.GROUP_COLOR[item.entry.group]
        icon.art:SetTexture(spellTexture(item.entry.id))
        icon.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon.ring:SetVertexColor(color[1], color[2], color[3], 1)
        icon.count:SetText("")
    end
end

local bindVisuals

local function legendTip(button)
    local entry = button.group
    if not entry then return end
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    GameTooltip:SetText(entry.label, entry.color[1], entry.color[2], entry.color[3])
    GameTooltip:AddLine("Click to show or hide", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function hiddenTip(button)
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Battlegrounds: " .. SA_StatsVenn.BG_HIDDEN, 1, 1, 1)
    for _, line in ipairs(SA_StatsVenn.BG_HIDDEN_TIP) do GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
end

local function placeBelow(widgets)
    local source = widgets.source
    local top = MODE_HEIGHT + widgets.geometry.height + 6
    local groups = SA_StatsVenn[source.groups]
    for index, legend in ipairs(widgets.legend) do
        local group = groups[index]
        legend.button.group = group
        if group then
            local row, column = math.floor((index - 1) / LEGEND_PER_ROW), (index - 1) % LEGEND_PER_ROW
            legend.button:ClearAllPoints()
            legend.button:SetPoint("TOPLEFT", widgets.view, "TOPLEFT", column * (LEGEND_WIDTH + LEGEND_GAP), -(top + row * LEGEND_ROW))
            legend.dot:SetVertexColor(group.color[1], group.color[2], group.color[3], 1)
            legend.button:Show()
        else
            legend.button:Hide()
        end
    end
    top = top + math.ceil(#groups / LEGEND_PER_ROW) * LEGEND_ROW + 2
    local showShares = source.shares ~= nil
    for index, row in ipairs(widgets.shareRows) do
        row.frame:SetShown(showShares)
        if showShares then
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", widgets.view, "TOPLEFT", 0, -(top + (index - 1) * SHARE_ROW))
        end
    end
    if showShares then top = top + #widgets.shareRows * SHARE_ROW + 4 end
    widgets.note:ClearAllPoints()
    widgets.note:SetPoint("TOPLEFT", widgets.view, "TOPLEFT", 0, -top)
    widgets.hidden:SetShown(source.honest and true or false)
    widgets.hiddenHit:SetShown(source.honest and true or false)
    for _, mode in ipairs(widgets.modes) do
        local on = mode.source == source
        mode.label:SetAlpha(on and 1 or 0.55)
        mode.underline:SetShown(on)
    end
end

local function drawShares(widgets)
    local source = widgets.source
    if not source.shares then return end
    local shares = source.shares(source)
    if widgets.sharesDrawn == shares then return end
    widgets.sharesDrawn = shares
    local Venn = SA_StatsVenn
    for index, row in ipairs(widgets.shareRows) do
        local data = shares and shares[index]
        local total = data and data.total or 0
        put(row.count, tostring(total))
        local x = 0
        local width = row.width
        for position, segment in ipairs(row.segments) do
            local part = data and data.parts[position]
            if part and total > 0 then
                local size = math.max(1, width * part.count / total)
                local color = Venn.CLASS_COLOR[part.key]
                segment:ClearAllPoints()
                segment:SetPoint("TOPLEFT", row.track, "TOPLEFT", x, 0)
                segment:SetSize(size, SHARE_ROW - 5)
                segment:SetVertexColor(color[1], color[2], color[3], 1)
                segment:Show()
                x = x + size
            else
                segment:Hide()
            end
        end
    end
end

local function buildVisuals(view, source)
    local Kit = SoundAlerter.Page.Kit
    local Venn = SA_StatsVenn
    local geometry = Venn.Geometry(PANEL_WIDTH, Venn.SLOT, Venn.MARGIN)
    local widgets = { geometry = geometry, source = source, view = view, offBy = {}, byKey = {}, free = {}, seen = {}, made = 0, zones = {}, legend = {}, modes = {}, shareRows = {} }
    widgets.offBy[source.kind] = {}
    widgets.off = widgets.offBy[source.kind]
    local x = 0
    for _, mode in ipairs(VISUAL_MODES) do
        local button = CreateFrame("Button", nil, view)
        local label = Kit.Text(button, 10.5, Kit.COLOR.text)
        label:SetPoint("LEFT", button, "LEFT", 2, 1)
        label:SetText(mode.label)
        button:SetSize(label:GetStringWidth() + 10, MODE_HEIGHT - 2)
        button:SetPoint("TOPLEFT", view, "TOPLEFT", x, 0)
        local underline = button:CreateTexture(nil, "ARTWORK")
        underline:SetColorTexture(1, 0.49, 0.04, 1)
        underline:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 0)
        underline:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 0)
        underline:SetHeight(1)
        x = x + button:GetWidth() + 6
        button:SetScript("OnClick", function()
            if widgets.source == mode then return end
            widgets.source = mode
            widgets.offBy[mode.kind] = widgets.offBy[mode.kind] or {}
            widgets.off = widgets.offBy[mode.kind]
            widgets.heat, widgets.sharesDrawn = nil, nil
            heatZones(widgets, nil)
            placeBelow(widgets)
            bindVisuals(widgets, true)
        end)
        widgets.modes[#widgets.modes + 1] = { source = mode, button = button, label = label, underline = underline }
    end
    local canvas = CreateFrame("Frame", nil, view)
    canvas:SetSize(PANEL_WIDTH, geometry.height)
    canvas:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -MODE_HEIGHT)
    widgets.canvas = canvas
    for index, zone in ipairs(Venn.ZONES) do
        local center = geometry.centers[index]
        local size = geometry.radius * 2
        local disc = canvas:CreateTexture(nil, "BACKGROUND")
        disc:SetTexture(DISC_TEXTURE)
        disc:SetSize(size, size)
        disc:SetPoint("CENTER", canvas, "TOPLEFT", center[1], -center[2])
        local ring = canvas:CreateTexture(nil, "BORDER")
        ring:SetTexture(ZONE_RING_TEXTURE)
        ring:SetSize(size, size)
        ring:SetPoint("CENTER", disc, "CENTER", 0, 0)
        local justify = index == 2 and "RIGHT" or (index == 3 and "CENTER" or "LEFT")
        local label = Kit.Text(canvas, 10, zone.color, justify)
        if index == 1 then
            label:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
        elseif index == 2 then
            label:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, 0)
        else
            label:SetPoint("BOTTOM", canvas, "BOTTOM", 0, 0)
        end
        widgets.zones[index] = { disc = disc, ring = ring, label = label }
    end
    local bgColor = Venn.ZONES[2].color
    widgets.hidden = Kit.Text(canvas, 9, bgColor, "RIGHT")
    widgets.hidden:SetPoint("TOPRIGHT", widgets.zones[2].label, "BOTTOMRIGHT", 0, -1)
    widgets.hidden:SetText(Venn.BG_HIDDEN)
    widgets.hidden:SetAlpha(0.75)
    widgets.hiddenHit = CreateFrame("Button", nil, canvas)
    widgets.hiddenHit:SetSize(110, 26)
    widgets.hiddenHit:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, 0)
    widgets.hiddenHit:SetFrameLevel(canvas:GetFrameLevel() + 3)
    widgets.hiddenHit:SetScript("OnEnter", hiddenTip)
    widgets.hiddenHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    heatZones(widgets, nil)
    for index = 1, #Venn.CLASSES do
        local button = CreateFrame("Button", nil, view)
        button:SetSize(LEGEND_WIDTH, 16)
        local dot = button:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(DISC_TEXTURE)
        dot:SetSize(8, 8)
        dot:SetPoint("LEFT", button, "LEFT", 2, 0)
        local label = Kit.Text(button, 10, Kit.COLOR.muted)
        label:SetPoint("LEFT", dot, "RIGHT", 3, 0)
        button:SetScript("OnClick", function()
            local group = button.group
            if not group then return end
            widgets.off[group.key] = not widgets.off[group.key] or nil
            widgets.stale = true
            bindVisuals(widgets, false)
        end)
        button:SetScript("OnEnter", legendTip)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        widgets.legend[index] = { button = button, label = label, dot = dot }
    end
    for index, zone in ipairs(Venn.ZONES) do
        local frame = CreateFrame("Frame", nil, view)
        frame:SetSize(PANEL_WIDTH, SHARE_ROW)
        local label = Kit.Text(frame, 9.5, zone.color)
        label:SetPoint("LEFT", frame, "LEFT", 0, 0)
        label:SetText(zone.label)
        local track = frame:CreateTexture(nil, "BACKGROUND")
        track:SetColorTexture(0.06, 0.07, 0.09, 1)
        track:SetPoint("LEFT", frame, "LEFT", SHARE_LABEL, 0)
        track:SetSize(PANEL_WIDTH - SHARE_LABEL - SHARE_COUNT, SHARE_ROW - 5)
        local count = Kit.Text(frame, 9.5, Kit.COLOR.muted, "RIGHT")
        count:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        local segments = {}
        for position = 1, #Venn.CLASSES do
            local segment = frame:CreateTexture(nil, "ARTWORK")
            segment:SetColorTexture(1, 1, 1, 1)
            segment:Hide()
            segments[position] = segment
        end
        widgets.shareRows[index] = { frame = frame, track = track, count = count, segments = segments, width = PANEL_WIDTH - SHARE_LABEL - SHARE_COUNT }
    end
    widgets.note = Kit.Text(view, 10, Kit.COLOR.muted)
    widgets.note:SetWidth(PANEL_WIDTH)
    widgets.note:SetWordWrap(true)
    widgets.empty = Kit.Text(view, 11, Kit.COLOR.muted, "CENTER")
    widgets.empty:SetPoint("CENTER", canvas, "CENTER", 0, 0)
    widgets.empty:SetWidth(PANEL_WIDTH - 40)
    widgets.empty:SetWordWrap(true)
    placeBelow(widgets)
    return widgets
end

local function releaseIcons(widgets, seen)
    for key, icon in pairs(widgets.byKey) do
        if not seen[key] then
            widgets.byKey[key] = nil
            icon.item = nil
            icon:Hide()
            widgets.free[#widgets.free + 1] = icon
        end
    end
end

local function takeIcon(widgets)
    local free = widgets.free
    local icon = free[#free]
    if icon then
        free[#free] = nil
        return icon
    end
    if widgets.made >= ICON_POOL then return nil end
    widgets.made = widgets.made + 1
    return newIcon(widgets)
end

local function placeIcons(widgets, layout, fresh)
    local geometry = widgets.geometry
    local centerX, centerY = geometry.width / 2, geometry.height / 2
    for index = 1, #layout.items do
        local item = layout.items[index]
        local icon = widgets.byKey[item.key]
        local isNew = icon == nil
        if isNew then
            icon = takeIcon(widgets)
            if icon then
                SA_MenuFX.Forget(icon)
                widgets.byKey[item.key] = icon
            end
        end
        if icon then
            icon.item = item
            styleIcon(icon, item)
            local x, y = item.x - item.size / 2, item.y - item.size / 2
            local fromX, fromY = x, y
            if fresh then fromX, fromY = centerX - item.size / 2, centerY - item.size / 2 end
            icon:Show()
            SA_MenuFX.GlideXY(icon, widgets.canvas, x, y, true, fromX, fromY)
            if fresh or isNew then SA_MenuFX.Appear(icon) end
        end
    end
end

local function showCounts(widgets, layout)
    local Venn = SA_StatsVenn
    for index, zone in ipairs(Venn.ZONES) do
        put(widgets.zones[index].label, zone.label .. " " .. layout.zoneCounts[index])
    end
    local source = widgets.source
    local counts = layout.groupCounts
    if source.kind == "classes" then
        counts = widgets.playerCounts or {}
        widgets.playerCounts = counts
        for key in pairs(counts) do counts[key] = nil end
        for _, entry in ipairs(widgets.entries) do
            if entry.mask > 0 then counts[entry.group] = (counts[entry.group] or 0) + entry.total end
        end
    end
    for index, group in ipairs(SA_StatsVenn[source.groups]) do
        local legend = widgets.legend[index]
        put(legend.label, group.short .. " " .. (counts[group.key] or 0))
        legend.button:SetAlpha(widgets.off[group.key] and 0.38 or 1)
    end
    drawShares(widgets)
    put(widgets.note, source.note(source, layout))
    if layout.pool > 0 then
        put(widgets.empty, "")
    elseif next(widgets.off) and next(layout.groupCounts) then
        put(widgets.empty, "Everything is switched off. Click a legend entry to show it again.")
    else
        put(widgets.empty, source.empty(source))
    end
end

function bindVisuals(widgets, fresh)
    local source = widgets.source
    local entries = source.entries(source)
    if not fresh and not widgets.stale and widgets.entries == entries then return end
    widgets.entries, widgets.stale = entries, false

    local layout = SA_StatsVenn.Layout(entries, widgets.geometry, { off = widgets.off })
    local seen = widgets.seen
    for key in pairs(seen) do seen[key] = nil end
    for index = 1, #layout.items do seen[layout.items[index].key] = true end
    releaseIcons(widgets, seen)
    if fresh then
        for _, icon in pairs(widgets.byKey) do SA_MenuFX.Forget(icon) end
    end
    placeIcons(widgets, layout, fresh)
    showCounts(widgets, layout)
end

local BAR_ROWS, ROW_HEIGHT, LIST_TOP = 13, 16, 16
local BAR_LEFT, BAR_WIDTH, NUM_WIDTH = 110, 120, 24
local WHEEL_STEP = 2
local ZONE_ORDER = { "arena", "battleground", "worldPvP" }
local SORT_TABS = { { "total", "Total" }, { "arena", "Arena" }, { "battleground", "BGs" }, { "worldPvP", "World" } }
local DIM_ALPHA = 0.35
local bindBars

local function zoneColor(zoneKey)
    for _, zone in ipairs(SA_StatsVenn.ZONES) do
        if zone.key == zoneKey then return zone.color end
    end
    return { 1, 1, 1 }
end

local function showRowTip(row)
    local entry = row.entry
    if not entry then return end
    local color = SA_StatsVenn.GROUP_COLOR[entry.group]
    local zones = entry.byZone
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(entry.name, color[1], color[2], color[3])
    GameTooltip:AddLine(string.format("%s   ID %d", entry.category, entry.id), 0.6, 0.65, 0.72)
    GameTooltip:AddLine(SA_StatsFormat.Number(entry.total) .. " players", 1, 1, 1)
    GameTooltip:AddLine(string.format("Arena %d   Battlegrounds %d   World %d", zones.arena or 0, zones.battleground or 0, zones.worldPvP or 0), 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Click: open in Spell Finder", 1, 0.49, 0.04)
    GameTooltip:Show()
end

local function newBarRow(widgets, index)
    local Kit = SoundAlerter.Page.Kit
    local row = CreateFrame("Button", nil, widgets.list)
    row:SetSize(PANEL_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", widgets.list, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    local art = row:CreateTexture(nil, "ARTWORK")
    art:SetSize(13, 13)
    art:SetPoint("LEFT", row, "LEFT", 2, 0)
    if row.CreateMaskTexture and art.AddMaskTexture then
        local mask = row:CreateMaskTexture()
        mask:SetTexture(DISC_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(art)
        art:AddMaskTexture(mask)
    end
    art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local ring = row:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(ICON_RING_TEXTURE)
    ring:SetAllPoints(art)
    local name = Kit.Text(row, 10, Kit.COLOR.text)
    name:SetPoint("LEFT", row, "LEFT", 19, 0)
    name:SetWidth(BAR_LEFT - 22)
    local track = Kit.Paint(row, Kit.COLOR.card, 1, "BACKGROUND")
    track:SetSize(BAR_WIDTH, 8)
    track:SetPoint("LEFT", row, "LEFT", BAR_LEFT, 0)
    local segments = {}
    for zoneIndex, zoneKey in ipairs(ZONE_ORDER) do
        local segment = Kit.Paint(row, zoneColor(zoneKey), 1, "ARTWORK")
        segment:SetHeight(8)
        segment:Hide()
        segments[zoneIndex] = segment
    end
    local number = Kit.Text(row, 9, Kit.COLOR.muted, "RIGHT")
    number:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    number:SetWidth(NUM_WIDTH)
    row.art, row.ring, row.name, row.segments, row.number = art, ring, name, segments, number
    row.widths, row.lefts, row.alphas, row.entry = {}, {}, {}, false
    row:SetScript("OnEnter", showRowTip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if self.entry then SoundAlerter:OpenSpellFinderFor(self.entry.id) end
    end)
    row:Hide()
    return row
end

local function drawBarRow(widgets, row, entry)
    if row.entry ~= entry then
        row.entry = entry
        local color = SA_StatsVenn.GROUP_COLOR[entry.group]
        row.art:SetTexture(spellTexture(entry.id))
        row.ring:SetVertexColor(color[1], color[2], color[3], 1)
        row.name:SetText(entry.name)
    end
    local zones, peak, sort = entry.byZone, widgets.peak, widgets.sort
    local x = 0
    for zoneIndex, zoneKey in ipairs(ZONE_ORDER) do
        local segment = row.segments[zoneIndex]
        local value = zones[zoneKey] or 0
        local width = peak > 0 and math.floor(value / peak * BAR_WIDTH + 0.5) or 0
        if width < 1 then
            if row.widths[zoneIndex] ~= 0 then
                row.widths[zoneIndex] = 0
                segment:Hide()
            end
        else
            if row.widths[zoneIndex] ~= width or row.lefts[zoneIndex] ~= x then
                row.widths[zoneIndex], row.lefts[zoneIndex] = width, x
                segment:ClearAllPoints()
                segment:SetPoint("LEFT", row, "LEFT", BAR_LEFT + x, 0)
                segment:SetWidth(width)
                segment:Show()
            end
            local alpha = (sort == "total" or sort == zoneKey) and 1 or DIM_ALPHA
            if row.alphas[zoneIndex] ~= alpha then
                row.alphas[zoneIndex] = alpha
                segment:SetAlpha(alpha)
            end
            x = x + width
        end
    end
    put(row.number, tostring(sort == "total" and entry.total or (zones[sort] or 0)))
    row:Show()
end

local function drawBars(widgets)
    local rows = widgets.rows
    for index = 1, BAR_ROWS do
        local row = widgets.rowFrames[index]
        local entry = rows[widgets.offset + index]
        if entry then
            drawBarRow(widgets, row, entry)
        elseif row.entry then
            row.entry = false
            row:Hide()
        end
    end
    local count = #rows
    if count == 0 then
        put(widgets.note, "")
        put(widgets.empty, (next(widgets.off) and #widgets.entries > 0) and "Every spell type is switched off. Click a legend entry to show it again." or globalEmptyText(widgets.players))
    else
        put(widgets.empty, "")
        local last = math.min(count, widgets.offset + BAR_ROWS)
        local hidden = widgets.sort == "battleground" and ". Battlegrounds: enemy spells are hidden by the game" or ""
        put(widgets.note, string.format("%d-%d of %d spells - 7 days, %d players", widgets.offset + 1, last, count, widgets.players or 0) .. hidden)
    end
    if widgets.chrome then return end
    widgets.chrome = true
    for _, tab in ipairs(widgets.sortTabs) do
        local active = tab.key == widgets.sort
        tab.label:SetAlpha(active and 1 or 0.55)
        tab.underline:SetShown(active)
    end
    for index, group in ipairs(SA_StatsVenn.GROUPS) do
        local legend = widgets.legend[index]
        put(legend.label, group.short .. " " .. (widgets.groupCounts[group.key] or 0))
        legend.button:SetAlpha(widgets.off[group.key] and 0.38 or 1)
    end
    widgets.exportButton:SetShown(#widgets.entries > 0)
end

local function regroup(widgets)
    local counts = widgets.groupCounts
    for key in pairs(counts) do counts[key] = nil end
    for _, entry in ipairs(widgets.entries) do counts[entry.group] = (counts[entry.group] or 0) + 1 end
end

local function reflow(widgets)
    widgets.chrome = false
    local _, peak = SA_GlobalStatsModel.Rows(widgets.entries, widgets.sort, widgets.off, widgets.rows)
    widgets.peak = peak
    widgets.offset = SA_GlobalStatsModel.ClampOffset(widgets.offset, #widgets.rows, BAR_ROWS)
    drawBars(widgets)
end

local function openExport(widgets)
    local text = SoundAlerter.GetGlobalExport and SoundAlerter:GetGlobalExport()
    if not text then return end
    local box = widgets.exportBox
    box.text = text
    box.edit:SetText(text)
    box:Show()
    box.edit:SetFocus()
    box.edit:HighlightText()
end

local function buildExportBox(widgets, view)
    local Kit = SoundAlerter.Page.Kit
    local box = CreateFrame("Frame", nil, view)
    box:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -LIST_TOP)
    box:SetSize(PANEL_WIDTH, BAR_ROWS * ROW_HEIGHT)
    box:SetFrameLevel(view:GetFrameLevel() + 10)
    box:EnableMouse(true)
    local fill = Kit.Paint(box, Kit.COLOR.card, 0.97, "BACKGROUND")
    fill:SetAllPoints(box)
    local title = Kit.Text(box, 11, Kit.COLOR.text)
    title:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
    title:SetText("Global statistics export")
    local hint = Kit.Text(box, 10, Kit.COLOR.muted)
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    hint:SetWidth(PANEL_WIDTH - 16)
    hint:SetWordWrap(true)
    hint:SetText("Press Ctrl+C to copy, then paste it on the website. Realm totals only, no player names. Esc closes.")
    local edit = CreateFrame("EditBox", nil, box)
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -64)
    edit:SetSize(PANEL_WIDTH - 16, 24)
    edit:SetAutoFocus(false)
    edit:SetFont(Kit.FONT, 11, "")
    edit:SetTextInsets(6, 6, 3, 3)
    local field = Kit.Paint(edit, Kit.COLOR.line, 1, "BACKGROUND")
    field:SetAllPoints(edit)
    edit:SetScript("OnEscapePressed", function() box:Hide() end)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput and box.text then
            self:SetText(box.text)
            self:HighlightText()
        end
    end)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    local close = Kit.MakeButton(box, "Close", function() box:Hide() end).frame
    close:SetSize(64, 20)
    close:SetPoint("TOPRIGHT", edit, "BOTTOMRIGHT", 0, -8)
    box.edit = edit
    box:Hide()
    widgets.exportBox = box
end

local function buildBars(view)
    local Kit = SoundAlerter.Page.Kit
    local widgets = { sort = "total", off = {}, rows = {}, rowFrames = {}, offset = 0, peak = 0, players = 0, entries = NO_ENTRIES, groupCounts = {}, sortTabs = {}, legend = {} }
    for index, tab in ipairs(SORT_TABS) do
        local button = CreateFrame("Button", nil, view)
        button:SetSize(46, 14)
        button:SetPoint("TOPLEFT", view, "TOPLEFT", (index - 1) * 48, 0)
        local color = tab[1] == "total" and Kit.COLOR.text or zoneColor(tab[1])
        local label = Kit.Text(button, 10, color, "LEFT")
        label:SetPoint("LEFT", button, "LEFT", 2, 0)
        label:SetText(tab[2])
        local underline = Kit.Paint(button, color, 1, "OVERLAY")
        underline:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 0)
        underline:SetSize(30, 1)
        underline:Hide()
        button:SetScript("OnClick", function()
            if widgets.sort == tab[1] then return end
            widgets.sort, widgets.offset = tab[1], 0
            reflow(widgets)
        end)
        widgets.sortTabs[index] = { key = tab[1], label = label, underline = underline, button = button }
    end
    local list = CreateFrame("Frame", nil, view)
    list:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -LIST_TOP)
    list:SetSize(PANEL_WIDTH, BAR_ROWS * ROW_HEIGHT)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        local offset = SA_GlobalStatsModel.ClampOffset(widgets.offset - delta * WHEEL_STEP, #widgets.rows, BAR_ROWS)
        if offset == widgets.offset then return end
        widgets.offset = offset
        drawBars(widgets)
    end)
    widgets.list = list
    for index = 1, BAR_ROWS do widgets.rowFrames[index] = newBarRow(widgets, index) end
    local legendTop = LIST_TOP + BAR_ROWS * ROW_HEIGHT + 4
    for index, group in ipairs(SA_StatsVenn.GROUPS) do
        local button = CreateFrame("Button", nil, view)
        button:SetSize(LEGEND_WIDTH, 16)
        button:SetPoint("TOPLEFT", view, "TOPLEFT", (index - 1) * (LEGEND_WIDTH + LEGEND_GAP), -legendTop)
        local dot = button:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(DISC_TEXTURE)
        dot:SetSize(8, 8)
        dot:SetPoint("LEFT", button, "LEFT", 2, 0)
        dot:SetVertexColor(group.color[1], group.color[2], group.color[3], 1)
        local label = Kit.Text(button, 10, Kit.COLOR.muted)
        label:SetPoint("LEFT", dot, "RIGHT", 3, 0)
        button:SetScript("OnClick", function()
            widgets.off[group.key] = not widgets.off[group.key] or nil
            reflow(widgets)
        end)
        widgets.legend[index] = { button = button, label = label }
    end
    widgets.note = Kit.Text(view, 10, Kit.COLOR.muted)
    widgets.note:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -(legendTop + 22))
    widgets.note:SetWidth(PANEL_WIDTH - 60)
    widgets.exportButton = Kit.MakeButton(view, "Export", function() openExport(widgets) end).frame
    widgets.exportButton:SetSize(54, 18)
    widgets.exportButton:SetPoint("TOPRIGHT", view, "TOPRIGHT", 0, -(legendTop + 19))
    widgets.empty = Kit.Text(view, 11, Kit.COLOR.muted, "CENTER")
    widgets.empty:SetPoint("CENTER", list, "CENTER", 0, 0)
    widgets.empty:SetWidth(PANEL_WIDTH - 40)
    widgets.empty:SetWordWrap(true)
    buildExportBox(widgets, view)
    local function startRefresh()
        if widgets.ticker then widgets.ticker:Cancel() end
        widgets.ticker = C_Timer.NewTicker(GLOBAL_REFRESH, function() bindBars(widgets, false) end)
    end
    view:SetScript("OnShow", startRefresh)
    view:SetScript("OnHide", function()
        if widgets.ticker then widgets.ticker:Cancel() end
        widgets.ticker = nil
        widgets.exportBox:Hide()
    end)
    if view:IsShown() then startRefresh() end
    return widgets
end

function bindBars(widgets, fresh)
    local entries, players = NO_ENTRIES, 0
    if SoundAlerter.GetGlobalVennData then
        local got, count = SoundAlerter:GetGlobalVennData()
        entries, players = got or NO_ENTRIES, count or 0
    end
    if not fresh and widgets.entries == entries and widgets.players == players then return end
    widgets.entries, widgets.players = entries, players
    regroup(widgets)
    reflow(widgets)
end

local VIEWS = {
    visuals = { build = function(view) return buildVisuals(view, SOURCES.visuals) end, bind = function(widgets, fresh) bindVisuals(widgets, fresh) end },
    global = { build = buildBars, bind = function(widgets, fresh) bindBars(widgets, fresh) end },
}

local function selectTab(state, key)
    local Kit = SoundAlerter.Page.Kit
    local changed = state.tab ~= key
    state.tab = key
    for _, tab in ipairs(TABS) do
        local active = tab[1] == key
        state.views[tab[1]]:SetShown(active and state.model ~= nil)
        local button = state.buttons[tab[1]]
        local color = active and Kit.COLOR.accent or Kit.COLOR.muted
        button.label:SetTextColor(color[1], color[2], color[3])
        button.underline:SetShown(active)
    end
    local spec = VIEWS[key]
    if spec and state.model then
        local widgets = state.widgets[key]
        local dirtyKey = key .. "Dirty"
        if not widgets then
            widgets = spec.build(state.views[key])
            state.widgets[key] = widgets
            state[dirtyKey] = true
        end
        if changed or state[dirtyKey] then
            state[dirtyKey] = false
            spec.bind(widgets, changed)
        end
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
    local hours = newSpark(view, 78, 24, 40, 0.24, 0.86, 0.59, HOUR_TICKS)
    local moverCaption = newCaption(view, 138, "RISING AND FALLING SPELLS")
    local movers = {}
    for index = 1, 4 do movers[index] = newLine(view, 152 + (index - 1) * 14) end
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

local Panel = { height = 360, caption = "SNAPSHOT" }

function Panel.build(stage)
    local Kit = SoundAlerter.Page.Kit
    local state = { tab = "now", views = {}, buttons = {}, widgets = {} }
    for index, tab in ipairs(TABS) do
        local button = CreateFrame("Button", nil, stage)
        button:SetSize(TAB_WIDTH, 22)
        button:SetPoint("TOPLEFT", stage, "TOPLEFT", (index - 1) * TAB_STEP, 0)
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
        state.visualsDirty = true
        state.globalDirty = true
    end
    selectTab(state, state.tab)
end

local DASH_GAP = 6
local TILE_HEIGHT = 40
local CARD_HEIGHT = 84
local CARD_LINES = 3
local MIX_SLOTS = 10
local DASH_HEIGHT = 2 * TILE_HEIGHT + 2 * CARD_HEIGHT + 3 * DASH_GAP + 4
local DASH_REFRESH = 1
local CARD_TITLES = { "Alert mix", "Top spells", "Top enemies", "Where" }

local function dashBox(parent, Kit)
    local box = CreateFrame("Frame", nil, parent)
    local fill = Kit.Paint(box, Kit.COLOR.card, 1)
    fill:SetAllPoints(box)
    Kit.Outline(box, Kit.COLOR.line)
    return box
end

local function buildDashboard(frame, page)
    local Kit = SoundAlerter.Page.Kit
    local state = { frame = frame, tiles = {}, cards = {}, width = 0 }
    for index = 1, 6 do
        local tile = dashBox(frame, Kit)
        tile.value = Kit.Text(tile, 15, Kit.COLOR.text)
        tile.value:SetPoint("TOPLEFT", tile, "TOPLEFT", 7, -5)
        tile.value:SetPoint("RIGHT", tile, "RIGHT", -5, 0)
        tile.label = Kit.Text(tile, 10.5, Kit.COLOR.muted)
        tile.label:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 7, 5)
        tile.label:SetPoint("RIGHT", tile, "RIGHT", -5, 0)
        state.tiles[index] = tile
    end
    for index = 1, 4 do
        local card = dashBox(frame, Kit)
        local title = Kit.Text(card, 11.5, { 1, 0.82, 0 })
        title:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
        title:SetText(CARD_TITLES[index])
        card.lines = {}
        local top = index == 1 and -32 or -22
        for line = 1, CARD_LINES do
            local left = Kit.Text(card, 11.5, Kit.COLOR.text)
            left:SetPoint("TOPLEFT", card, "TOPLEFT", 8, top - (line - 1) * 16)
            local right = Kit.Text(card, 11.5, Kit.COLOR.on, "RIGHT")
            right:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, top - (line - 1) * 16)
            left:SetPoint("RIGHT", right, "LEFT", -6, 0)
            card.lines[line] = { left = left, right = right }
        end
        state.cards[index] = card
    end
    local mix = state.cards[1]
    mix.track = Kit.Paint(mix, Kit.COLOR.track, 1, "BORDER")
    mix.track:SetPoint("TOPLEFT", mix, "TOPLEFT", 8, -22)
    mix.track:SetPoint("TOPRIGHT", mix, "TOPRIGHT", -8, -22)
    mix.track:SetHeight(6)
    mix.slots = {}
    for slot = 1, MIX_SLOTS do mix.slots[slot] = Kit.Paint(mix, Kit.COLOR.track, 1, "ARTWORK") end

    local ticker
    local function stop()
        if ticker then ticker:Cancel() end
        ticker = nil
    end
    frame:HookScript("OnShow", function()
        stop()
        ticker = C_Timer.NewTicker(DASH_REFRESH, function()
            local active = statistics()
            if not active then return end
            local data, matches = active:Version()
            if data ~= state.dataVersion or matches ~= state.matchVersion then page:Refresh() end
        end)
    end)
    frame:HookScript("OnHide", stop)
    return state
end

local function placeDashboard(state, frame, width)
    if width == state.width then return end
    state.width = width
    local tileWidth = (width - 2 * DASH_GAP) / 3
    for index, tile in ipairs(state.tiles) do
        local column, row = (index - 1) % 3, math.floor((index - 1) / 3)
        tile:ClearAllPoints()
        tile:SetSize(tileWidth, TILE_HEIGHT)
        tile:SetPoint("TOPLEFT", frame, "TOPLEFT", column * (tileWidth + DASH_GAP), -2 - row * (TILE_HEIGHT + DASH_GAP))
    end
    local cardWidth = (width - DASH_GAP) / 2
    local top = 2 + 2 * (TILE_HEIGHT + DASH_GAP)
    for index, card in ipairs(state.cards) do
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        card:ClearAllPoints()
        card:SetSize(cardWidth, CARD_HEIGHT)
        card:SetPoint("TOPLEFT", frame, "TOPLEFT", column * (cardWidth + DASH_GAP), -top - row * (CARD_HEIGHT + DASH_GAP))
    end
    state.mixWidth = nil
end

local function cardLine(line, left, right, r, g, b)
    line.left:SetText(left or "")
    line.right:SetText(right or "")
    line.left:SetTextColor(r or 0.906, g or 0.918, b or 0.941)
end

local function paintMix(card, mix, width)
    local used, x = 0, 0
    local total = mix.total
    for _, segment in ipairs(mix.segments) do
        used = used + 1
        if used > MIX_SLOTS then break end
        local slot = card.slots[used]
        local share = total > 0 and segment.value / total or 0
        local span = math.max(1, share * width)
        slot:ClearAllPoints()
        slot:SetPoint("TOPLEFT", card.track, "TOPLEFT", x, 0)
        slot:SetSize(span, 6)
        slot:SetVertexColor(segment.color[1] / 255, segment.color[2] / 255, segment.color[3] / 255, 1)
        slot:Show()
        x = x + span
    end
    for slot = used + 1, MIX_SLOTS do card.slots[slot]:Hide() end
end

local function updateDashboard(state, settings, width)
    local active = statistics()
    if active then state.dataVersion, state.matchVersion = active:Version() end
    local model = settings.dashboard
    placeDashboard(state, state.frame, width)
    if not model then return DASH_HEIGHT end
    if model == state.model and state.mixWidth == width then return DASH_HEIGHT end
    state.model, state.mixWidth = model, width
    for index, tile in ipairs(state.tiles) do
        local data = model.tiles[index]
        tile.value:SetText(data.value)
        tile.label:SetText(data.label)
        if data.class then
            local r, g, b = SA_StatsFormat.ClassColor(data.class)
            tile.value:SetTextColor(r / 255, g / 255, b / 255)
        else
            tile.value:SetTextColor(0.906, 0.918, 0.941)
        end
    end
    local mixCard, spellCard, enemyCard, zoneCard = state.cards[1], state.cards[2], state.cards[3], state.cards[4]
    paintMix(mixCard, model.mix, (width - DASH_GAP) / 2 - 16)
    for line = 1, CARD_LINES do
        local mix = model.mix.top[line]
        cardLine(mixCard.lines[line], mix and mix.label, mix and mix.share)
        local spell = model.spells[line]
        cardLine(spellCard.lines[line], spell and spell.name or (line == 1 and "No spell alerts yet" or nil), spell and tostring(spell.count))
        local enemy = model.enemies[line]
        if enemy then
            local r, g, b = SA_StatsFormat.ClassColor(enemy.class)
            cardLine(enemyCard.lines[line], enemy.name, tostring(enemy.count), r / 255, g / 255, b / 255)
        else
            cardLine(enemyCard.lines[line], line == 1 and "No enemies yet" or nil, nil)
        end
        local zone = model.zones[line]
        cardLine(zoneCard.lines[line], zone and zone.label, zone and tostring(zone.value))
    end
    return DASH_HEIGHT
end

local BG = SA_BGResult
local BG_SHORT = 5
local BG_GAP, BG_KPI_HEIGHT, BG_CHIP_HEIGHT, BG_HEAD_HEIGHT, BG_ROW_HEIGHT = 6, 40, 22, 18, 28
local BG_BAR_HEIGHT, BG_TAB_HEIGHT, BG_SPELL_HEIGHT, BG_DETAIL_PAD, BG_TEAM_MIN = 18, 20, 14, 8, 280
local BG_VALUE_WIDTH = 50
local BG_SPELLS_MIN = 170
local BG_ALLIANCE, BG_HORDE = { 0.31, 0.56, 1 }, { 0.89, 0.27, 0.23 }
local BG_LOSS = { 1, 0.36, 0.36 }
local BG_GOLD = { 1, 0.82, 0 }
local BG_KPI_LABELS = { "Matches", "Won", "HK per match", "KB per match", "Deaths per match" }
local BG_ROW_FIELDS = { BG.KB, BG.HK, BG.DEATHS, BG.DAMAGE, BG.HEALING, BG.HONOR }
local BG_ROW_LABELS = { "KB", "HK", "DTH", "DMG", "HEAL", "HONOR" }
local BG_LOOK = {
    EDGE = 3,
    BAR_GAP = 4,
    SPELL_ROW = 20,
    SPELL_TEXT = 4,
    RULE = { 0.208, 0.235, 0.286 },
    HILITE = { 1, 1, 1 },
    HILITE_ALPHA = 0.025,
    SPELL_RULE = { 0.173, 0.196, 0.239 },
    SHADE = { 0.075, 0.086, 0.11 },
    TIPS = { "Killing blows", "Honorable kills", "Deaths", "Damage done", "Healing done", "Honor gained" },
}
function BG_LOOK.HeadEnter(self) SoundAlerter.Page.Kit.ShowTip(self, self.tip) end
function BG_LOOK.HeadLeave() SoundAlerter.Page.Kit.HideTip() end
local bgUI = { open = 1, stat = BG.DAMAGE, filter = "all", all = false }
local sortIndex = BG.DAMAGE

local function byStat(a, b)
    local left, right = a[sortIndex] or 0, b[sortIndex] or 0
    if left ~= right then return left > right end
    return (a[BG.NAME] or "") < (b[BG.NAME] or "")
end

local function wipeArray(list)
    for index = #list, 1, -1 do list[index] = nil end
    return list
end

local function bgChip(state, index)
    local chip = state.chips[index]
    if chip then return chip end
    local Kit = SoundAlerter.Page.Kit
    chip = Kit.MakeChip(state.frame, "", function()
        bgUI.filter = state.chips[index].map
        bgUI.open, bgUI.all = 1, false
        state.page:Refresh()
    end)
    state.chips[index] = chip
    return chip
end

local function bgRow(state, index)
    local row = state.rows[index]
    if row then return row end
    local Kit = SoundAlerter.Page.Kit
    row = CreateFrame("Button", nil, state.frame)
    row:SetHeight(BG_ROW_HEIGHT)
    row.hover = Kit.Paint(row, Kit.COLOR.card, 1, "BACKGROUND")
    row.hover:SetAllPoints(row)
    row.hover:Hide()
    row.rule = Kit.Paint(row, BG_LOOK.RULE, 1, "BORDER")
    row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.rule:SetHeight(1)
    row.hilite = Kit.Paint(row, BG_LOOK.HILITE, BG_LOOK.HILITE_ALPHA, "BORDER")
    row.hilite:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.hilite:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.hilite:SetHeight(1)
    row.edge = Kit.Paint(row, Kit.COLOR.on, 1, "ARTWORK")
    row.edge:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.edge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
    row.edge:SetWidth(BG_LOOK.EDGE)
    row.result = Kit.Text(row, 12, Kit.COLOR.on, "CENTER")
    row.result:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.result:SetWidth(16)
    row.title = Kit.Text(row, 12, Kit.COLOR.text)
    row.title:SetPoint("LEFT", row, "LEFT", 22, 0)
    row.values = {}
    for column = #BG_ROW_FIELDS, 1, -1 do
        local value = Kit.Text(row, 12, Kit.COLOR.text, "RIGHT")
        value:SetWidth(BG_VALUE_WIDTH)
        value:SetPoint("RIGHT", row, "RIGHT", -(14 + (#BG_ROW_FIELDS - column) * BG_VALUE_WIDTH), 0)
        row.values[column] = value
    end
    row.title:SetPoint("RIGHT", row.values[1], "LEFT", -6, 0)
    row.caret = Kit.Text(row, 12, Kit.COLOR.muted, "RIGHT")
    row.caret:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row:SetScript("OnEnter", function(self) self.hover:Show() end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    row:SetScript("OnClick", function(self)
        bgUI.open = bgUI.open == self.index and 0 or self.index
        state.page:Refresh()
    end)
    state.rows[index] = row
    return row
end

local function bgBar(state, index)
    local bar = state.bars[index]
    if bar then return bar end
    local Kit = SoundAlerter.Page.Kit
    bar = CreateFrame("Frame", nil, state.detail)
    bar:SetHeight(BG_BAR_HEIGHT)
    bar.track = Kit.Paint(bar, { 0.055, 0.067, 0.086 }, 1)
    bar.track:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.track:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -BG_VALUE_WIDTH, 0)
    bar.fill = Kit.Paint(bar, Kit.COLOR.text, 0.55, "ARTWORK")
    bar.fill:SetPoint("TOPLEFT", bar.track, "TOPLEFT", 0, 0)
    bar.fill:SetPoint("BOTTOMLEFT", bar.track, "BOTTOMLEFT", 0, 0)
    bar.edge = Kit.Paint(bar, BG_GOLD, 1, "OVERLAY")
    bar.edge:SetPoint("TOPLEFT", bar.track, "TOPLEFT", 0, 0)
    bar.edge:SetPoint("BOTTOMLEFT", bar.track, "BOTTOMLEFT", 0, 0)
    bar.edge:SetWidth(2)
    bar.name = Kit.Text(bar, 11, Kit.COLOR.text)
    bar.name:SetPoint("LEFT", bar.track, "LEFT", 5, 0)
    bar.name:SetPoint("RIGHT", bar.track, "RIGHT", -3, 0)
    bar.value = Kit.Text(bar, 11, Kit.COLOR.muted, "RIGHT")
    bar.value:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    bar.value:SetWidth(BG_VALUE_WIDTH - 4)
    state.bars[index] = bar
    return bar
end

local function bgTab(state, index)
    local tab = state.tabs[index]
    if tab then return tab end
    local Kit = SoundAlerter.Page.Kit
    tab = Kit.MakeChip(state.detail, "", function()
        bgUI.stat = state.tabs[index].stat
        state.page:Refresh()
    end)
    tab.frame:SetHeight(BG_TAB_HEIGHT)
    state.tabs[index] = tab
    return tab
end

local function bgSpell(state, index)
    local line = state.spells[index]
    if line then return line end
    local Kit = SoundAlerter.Page.Kit
    line = { name = Kit.Text(state.detail, 11, Kit.COLOR.text), value = Kit.Text(state.detail, 11, Kit.COLOR.muted, "RIGHT"), rule = Kit.Paint(state.detail, BG_LOOK.SPELL_RULE, 1, "BORDER") }
    line.value:SetWidth(90)
    state.spells[index] = line
    return line
end

local function watchWidth(state, frame, page)
    local function redraw()
        state.pending = false
        page:Refresh()
    end
    frame:HookScript("OnSizeChanged", function(_, width)
        if not state.built or state.pending or not frame:IsVisible() then return end
        if math.abs((width or 0) - state.width) < 1 then return end
        state.pending = true
        C_Timer.After(0, redraw)
    end)
    return state
end

local function buildBG(frame, page)
    return watchWidth({ frame = frame, page = page, built = false, height = 0, width = 0, pending = false }, frame, page)
end

local function fillBG(state)
    local Kit = SoundAlerter.Page.Kit
    local frame, page = state.frame, state.page
    state.kpis, state.chips, state.rows, state.bars, state.tabs, state.spells = {}, {}, {}, {}, {}, {}
    state.maps, state.list, state.alliance, state.horde = {}, {}, {}, {}
    state.built = true
    for index = 1, #BG_KPI_LABELS do
        local tile = dashBox(frame, Kit)
        tile.value = Kit.Text(tile, 15, Kit.COLOR.text)
        tile.value:SetPoint("TOPLEFT", tile, "TOPLEFT", 7, -5)
        tile.label = Kit.Text(tile, 10.5, Kit.COLOR.muted)
        tile.label:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 7, 5)
        tile.label:SetText(BG_KPI_LABELS[index])
        state.kpis[index] = tile
    end
    state.empty = Kit.Text(frame, 12, Kit.COLOR.muted)
    state.empty:SetText("No battlegrounds yet. Each match is added here the moment it ends.")
    state.head = CreateFrame("Frame", nil, frame)
    state.head:SetHeight(BG_HEAD_HEIGHT)
    local matchLabel = Kit.Text(state.head, 10.5, Kit.COLOR.muted)
    matchLabel:SetPoint("LEFT", state.head, "LEFT", 22, 0)
    matchLabel:SetText("MATCH")
    state.headTips = {}
    for column = 1, #BG_ROW_FIELDS do
        local hit = CreateFrame("Frame", nil, state.head)
        hit:SetSize(BG_VALUE_WIDTH, BG_HEAD_HEIGHT)
        hit:SetPoint("RIGHT", state.head, "RIGHT", -(14 + (#BG_ROW_FIELDS - column) * BG_VALUE_WIDTH), 0)
        hit.tip = BG_LOOK.TIPS[column]
        hit:EnableMouse(true)
        hit:SetScript("OnEnter", BG_LOOK.HeadEnter)
        hit:SetScript("OnLeave", BG_LOOK.HeadLeave)
        local label = Kit.Text(hit, 10.5, Kit.COLOR.muted, "RIGHT")
        label:SetWidth(BG_VALUE_WIDTH)
        label:SetPoint("RIGHT", hit, "RIGHT", 0, 0)
        label:SetText(BG_ROW_LABELS[column])
        hit.label = label
        state.headTips[column] = hit
    end
    state.more = Kit.MakeButton(frame, "Show all", function()
        bgUI.all = not bgUI.all
        page:Refresh()
    end)
    state.detail = CreateFrame("Frame", nil, frame)
    local shade = Kit.Paint(state.detail, BG_LOOK.SHADE, 1)
    shade:SetAllPoints(state.detail)
    local detailRule = Kit.Paint(state.detail, BG_LOOK.RULE, 1, "BORDER")
    detailRule:SetPoint("BOTTOMLEFT", state.detail, "BOTTOMLEFT", 0, 0)
    detailRule:SetPoint("BOTTOMRIGHT", state.detail, "BOTTOMRIGHT", 0, 0)
    detailRule:SetHeight(1)
    state.card = SA_BGResultUI.NewCard(state.detail, false)
    state.spellTitle = Kit.Text(state.detail, 10.5, Kit.COLOR.accent)
    state.spellTitle:SetText("YOUR DAMAGE BY SPELL")
    state.teamNote = Kit.Text(state.detail, 11, Kit.COLOR.muted)
    state.teamNote:SetText("Both teams are kept for your 10 newest battlegrounds.")
    state.allianceTitle = Kit.Text(state.detail, 11, BG_ALLIANCE)
    state.hordeTitle = Kit.Text(state.detail, 11, BG_HORDE)
end

local function placeKpis(state, saved, width, y)
    local totals = BG.Totals(saved, bgUI.filter) or BG.Totals(saved, "all")
    local count = #state.kpis
    local tileWidth = (width - (count - 1) * BG_GAP) / count
    local n = totals and totals.n or 0
    local per = math.max(1, n)
    local values = {
        tostring(n),
        n > 0 and (math.floor(totals.won / n * 100 + 0.5) .. "%") or "-",
        n > 0 and tostring(math.floor(totals.hk / per + 0.5)) or "-",
        n > 0 and string.format("%.1f", totals.kb / per) or "-",
        n > 0 and string.format("%.1f", totals.deaths / per) or "-",
    }
    for index, tile in ipairs(state.kpis) do
        tile:ClearAllPoints()
        tile:SetSize(tileWidth, BG_KPI_HEIGHT)
        tile:SetPoint("TOPLEFT", state.frame, "TOPLEFT", (index - 1) * (tileWidth + BG_GAP), -y)
        tile.value:SetText(values[index])
    end
    return y + BG_KPI_HEIGHT + BG_GAP
end

local function placeChips(state, saved, y)
    local maps = BG.Maps(saved, state.maps)
    local x, used = 0, 0
    if #maps > 1 then
        for index = 0, #maps do
            used = used + 1
            local chip = bgChip(state, used)
            chip.map = index == 0 and "all" or maps[index]
            chip:SetLabel(index == 0 and "All battlegrounds" or maps[index])
            chip:Set(bgUI.filter == chip.map)
            chip.frame:ClearAllPoints()
            chip.frame:SetPoint("TOPLEFT", state.frame, "TOPLEFT", x, -y)
            chip.frame:Show()
            x = x + chip.frame:GetWidth() + BG_GAP
        end
    end
    for index = used + 1, #state.chips do state.chips[index].frame:Hide() end
    return used > 0 and (y + BG_CHIP_HEIGHT + BG_GAP) or y
end

local function placeTeams(state, record, x, y, width)
    local stats = BG.Stats(record.columns)
    local tabX, tabY, used = x, y, 0
    for s = 1, #stats do
        used = used + 1
        local tab = bgTab(state, used)
        tab.stat = stats[s].index
        tab:SetLabel(stats[s].label)
        tab:Set(bgUI.stat == tab.stat)
        local tabWidth = tab.frame:GetWidth()
        if tabX + tabWidth > x + width then
            tabX, tabY = x, tabY + BG_TAB_HEIGHT + 4
        end
        tab.frame:ClearAllPoints()
        tab.frame:SetPoint("TOPLEFT", state.detail, "TOPLEFT", tabX, -tabY)
        tab.frame:Show()
        tabX = tabX + tabWidth + 4
    end
    for index = used + 1, #state.tabs do state.tabs[index].frame:Hide() end
    local valid = false
    for s = 1, #stats do if stats[s].index == bgUI.stat then valid = true end end
    if not valid then bgUI.stat = BG.DAMAGE end
    sortIndex = bgUI.stat
    local alliance, horde = wipeArray(state.alliance), wipeArray(state.horde)
    local top = 0
    for _, row in ipairs(record.board) do
        local value = row[sortIndex] or 0
        if value > top then top = value end
        if row[BG.FACTION] == 1 then alliance[#alliance + 1] = row elseif row[BG.FACTION] == 0 then horde[#horde + 1] = row end
    end
    table.sort(alliance, byStat)
    table.sort(horde, byStat)
    local columnWidth = (width - BG_GAP) / 2
    local barsY = tabY + BG_TAB_HEIGHT + 6
    state.allianceTitle:ClearAllPoints()
    state.allianceTitle:SetPoint("TOPLEFT", state.detail, "TOPLEFT", x, -barsY)
    state.allianceTitle:SetText("Alliance · " .. BG.Short(record.teams[1] and record.teams[1][sortIndex]))
    state.hordeTitle:ClearAllPoints()
    state.hordeTitle:SetPoint("TOPLEFT", state.detail, "TOPLEFT", x + columnWidth + BG_GAP, -barsY)
    state.hordeTitle:SetText("Horde · " .. BG.Short(record.teams[0] and record.teams[0][sortIndex]))
    barsY = barsY + 16
    local me = record.me
    local bars = 0
    local function lay(list, columnX)
        for index, row in ipairs(list) do
            bars = bars + 1
            local bar = bgBar(state, bars)
            bar:ClearAllPoints()
            bar:SetWidth(columnWidth)
            bar:SetPoint("TOPLEFT", state.detail, "TOPLEFT", columnX, -(barsY + (index - 1) * (BG_BAR_HEIGHT + BG_LOOK.BAR_GAP)))
            local value = row[sortIndex] or 0
            local track = columnWidth - BG_VALUE_WIDTH
            bar.fill:SetWidth(math.max(1, top > 0 and track * value / top or 1))
            bar.fill:SetVertexColor(SA_BGResultUI.ClassColor(row[BG.CLASS]))
            bar.fill:SetAlpha(0.55)
            bar.name:SetText(row[BG.NAME] or "?")
            bar.value:SetText(BG.Short(value))
            bar.edge:SetShown(row == me)
            bar:Show()
        end
    end
    lay(alliance, x)
    lay(horde, x + columnWidth + BG_GAP)
    for index = bars + 1, #state.bars do state.bars[index]:Hide() end
    state.teamNote:Hide()
    return barsY + math.max(#alliance, #horde) * (BG_BAR_HEIGHT + BG_LOOK.BAR_GAP)
end

local function placeDetail(state, record, width, y)
    local detail = state.detail
    local card = state.card
    SA_BGResultUI.FillCard(card, record)
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", detail, "TOPLEFT", BG_DETAIL_PAD, -BG_DETAIL_PAD)
    local cardWidth = SA_BGResultUI.CARD_WIDTH
    local cardBottom = BG_DETAIL_PAD + SA_BGResultUI.CardHeight(false)
    local left = cardBottom
    local free = width - cardWidth - 3 * BG_DETAIL_PAD
    local side = free >= BG_TEAM_MIN
    local beside = not side and free >= BG_SPELLS_MIN
    local spellX = beside and (cardWidth + 2 * BG_DETAIL_PAD) or BG_DETAIL_PAD
    local spellRight = beside and (width - BG_DETAIL_PAD) or (BG_DETAIL_PAD + cardWidth)
    local spellTop = beside and (BG_DETAIL_PAD - 6) or cardBottom
    local spells = record.spells
    local used = 0
    if spells and #spells > 0 then
        state.spellTitle:ClearAllPoints()
        state.spellTitle:SetPoint("TOPLEFT", detail, "TOPLEFT", spellX, -(spellTop + 6))
        state.spellTitle:Show()
        local top = spellTop + 6 + BG_SPELL_HEIGHT
        local total = 0
        for index = 1, #spells do total = total + spells[index][2] end
        local rowHeight, textY = BG_LOOK.SPELL_ROW, BG_LOOK.SPELL_TEXT
        for index = 1, #spells do
            used = used + 1
            local line = bgSpell(state, used)
            local lineY = top + (index - 1) * rowHeight
            line.name:ClearAllPoints()
            line.name:SetPoint("TOPLEFT", detail, "TOPLEFT", spellX, -(lineY + textY))
            line.name:SetText(spells[index][1])
            line.value:ClearAllPoints()
            line.value:SetPoint("TOPRIGHT", detail, "TOPLEFT", spellRight, -(lineY + textY))
            line.value:SetText(BG.Short(spells[index][2]) .. "  " .. math.floor(spells[index][2] / math.max(1, total) * 100 + 0.5) .. "%")
            line.rule:ClearAllPoints()
            line.rule:SetPoint("TOPLEFT", detail, "TOPLEFT", spellX, -(lineY + rowHeight - 1))
            line.rule:SetSize(math.max(1, spellRight - spellX), 1)
            line.name:Show()
            line.value:Show()
            line.rule:Show()
        end
        left = math.max(left, top + #spells * rowHeight)
    else
        state.spellTitle:Hide()
    end
    for index = used + 1, #state.spells do
        state.spells[index].name:Hide()
        state.spells[index].value:Hide()
        state.spells[index].rule:Hide()
    end
    local teamX = side and (cardWidth + 2 * BG_DETAIL_PAD) or BG_DETAIL_PAD
    local teamY = side and BG_DETAIL_PAD or (left + BG_DETAIL_PAD)
    local teamWidth = side and (width - teamX - BG_DETAIL_PAD) or (width - 2 * BG_DETAIL_PAD)
    local bottom
    if record.board then
        state.allianceTitle:Show()
        state.hordeTitle:Show()
        bottom = placeTeams(state, record, teamX, teamY, teamWidth)
    else
        for _, tab in ipairs(state.tabs) do tab.frame:Hide() end
        for _, bar in ipairs(state.bars) do bar:Hide() end
        state.allianceTitle:Hide()
        state.hordeTitle:Hide()
        state.teamNote:ClearAllPoints()
        state.teamNote:SetPoint("TOPLEFT", detail, "TOPLEFT", teamX, -teamY)
        state.teamNote:Show()
        bottom = teamY + 16
    end
    local height = math.max(left, bottom) + BG_DETAIL_PAD
    detail:ClearAllPoints()
    detail:SetPoint("TOPLEFT", state.frame, "TOPLEFT", 0, -y)
    detail:SetSize(width, height)
    detail:Show()
    return y + height
end

local function updateBG(state, settings, width)
    if not state.built then fillBG(state) end
    local saved = settings.bg
    local active = statistics()
    local version = active and select(2, active:Version()) or 0
    local key = version .. "|" .. width .. "|" .. bgUI.open .. "|" .. bgUI.stat .. "|" .. bgUI.filter .. "|" .. (bgUI.all and 1 or 0)
    if key == state.key then return state.height end
    state.key, state.width = key, width
    local history = saved and saved.history or {}
    local y = placeKpis(state, saved, width, 0)
    y = placeChips(state, saved, y)
    local list = wipeArray(state.list)
    for _, record in ipairs(history) do
        if bgUI.filter == "all" or record.map == bgUI.filter then list[#list + 1] = record end
    end
    if #list == 0 then
        state.empty:ClearAllPoints()
        state.empty:SetPoint("TOPLEFT", state.frame, "TOPLEFT", 0, -y)
        state.empty:Show()
        state.head:Hide()
        state.more.frame:Hide()
        state.detail:Hide()
        for _, row in ipairs(state.rows) do row:Hide() end
        state.height = y + 24
        return state.height
    end
    state.empty:Hide()
    state.head:ClearAllPoints()
    state.head:SetPoint("TOPLEFT", state.frame, "TOPLEFT", 0, -y)
    state.head:SetWidth(width)
    state.head:Show()
    y = y + BG_HEAD_HEIGHT
    local shown = bgUI.all and #list or math.min(#list, BG_SHORT)
    if bgUI.open > shown then bgUI.open = 0 end
    local Kit = SoundAlerter.Page.Kit
    local detailShown = false
    for index = 1, shown do
        local record, row = list[index], bgRow(state, index)
        row.index = index
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", state.frame, "TOPLEFT", 0, -y)
        row:SetWidth(width)
        local result = record.result or "none"
        if row.look ~= result then
            row.look = result
            local color = result == "lost" and BG_LOSS or result == "won" and Kit.COLOR.on or Kit.COLOR.muted
            row.result:SetText(result == "won" and "W" or result == "lost" and "L" or "-")
            Kit.Tint(row.result, color)
            row.edge:SetVertexColor(color[1], color[2], color[3], 1)
            row.edge:SetShown(result == "won" or result == "lost")
        end
        row.title:SetText((record.map or "?") .. "  |cff8d95a3" .. (record.when or "") .. " · " .. BG.Clock(record.length) .. "|r")
        local me = record.me
        for column, field in ipairs(BG_ROW_FIELDS) do
            row.values[column]:SetText(field == BG.HONOR and ("+" .. (me[field] or 0)) or BG.Short(me[field]))
        end
        local open = bgUI.open == index
        row.caret:SetText(open and "v" or ">")
        Kit.Tint(row.caret, open and Kit.COLOR.accent or Kit.COLOR.muted)
        row:Show()
        y = y + BG_ROW_HEIGHT
        if open then
            y = placeDetail(state, record, width, y)
            detailShown = true
        end
    end
    for index = shown + 1, #state.rows do state.rows[index]:Hide() end
    if not detailShown then state.detail:Hide() end
    if #list > BG_SHORT then
        state.more.label:SetText(bgUI.all and ("Show the last " .. BG_SHORT) or ("Show all " .. #list))
        state.more.frame:SetWidth(math.max(70, state.more.label:GetStringWidth() + 24))
        state.more.frame:ClearAllPoints()
        state.more.frame:SetPoint("TOPLEFT", state.frame, "TOPLEFT", 0, -(y + BG_GAP))
        state.more.frame:Show()
        y = y + BG_GAP + 22
    else
        state.more.frame:Hide()
    end
    state.height = y + BG_GAP
    return state.height
end

local Honor = SA_HonorModel
local HV = {
    DAY = Honor.DAY,
    KPI_LABELS = { "Today", "This week", "Per match", "Per BG hour", "Best match" },
    RANGES = { { 7, "7 days" }, { 30, "30 days" }, { 0, "All" } },
    AXIS = 40,
    RIGHT = 6,
    HEAD = 24,
    A_HEIGHT = 150,
    B_HEIGHT = 110,
    FOOT = 16,
    LEGEND = 16,
    LINE = 2,
    DOT = 6,
    BUCKET = 2,
    GRID = 6,
    RAIL_MIN = 200,
    RAIL_MAX = 250,
    RAIL_SHARE = 0.34,
    STACK = 600,
    CARD_HEIGHT = 62,
    PAD = 8,
    CAP_BAR = 4,
    GOAL_TITLE = 20,
    GOAL_ROW = 40,
    GOAL_TRACK = 6,
    GOAL_LINE = 16,
    ADD_HEIGHT = 22,
    COST_WIDTH = 58,
    REMOVE = 16,
    DASH = 5,
    DASH_GAP = 3,
    BG_SLACK = 60,
    REFRESH_DELAY = 0.2,
    KIND_BG = 1,
    KIND_WORLD = 2,
    KIND_SPEND = 3,
}
local HC = {
    KILL = { 1, 0.49, 0.04 },
    BONUS = { 1, 0.82, 0 },
    WORLD = { 0.435, 0.659, 1 },
    SPEND = { 1, 0.36, 0.36 },
    SOLID = { 0.604, 0.478, 0.333 },
    LOSS = { 1, 0.36, 0.36 },
    TRACK = { 0.059, 0.067, 0.082 },
    WARN_FILL = { 0.165, 0.141, 0.063 },
}
HV.KIND_COLOR = { HC.KILL, HC.WORLD, HC.SPEND }
local HONOR_EMPTY_STORE = Honor.Store({})
local honorUI = { range = 30, map = "all" }

local function honorPool(state, name, parent, color, alpha, layer, texture)
    local pool = state[name]
    local used = pool.used + 1
    pool.used = used
    local region = pool[used]
    if not region then
        region = SoundAlerter.Page.Kit.Paint(parent, color, alpha, layer)
        if texture then region:SetTexture(texture) end
        pool[used] = region
    end
    return region
end

local function honorPools(state, ...)
    for index = 1, select("#", ...) do
        local pool = state[select(index, ...)]
        for slot = pool.used + 1, pool.shown do pool[slot]:Hide() end
        pool.shown = pool.used
    end
end

local function honorBegin(state, ...)
    for index = 1, select("#", ...) do state[select(index, ...)].used = 0 end
end

local function honorRect(region, parent, x, y, w, h)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    region:SetSize(math.max(1, w), math.max(1, h))
    region:Show()
end

local function honorAxis(state, plot, gridName, labelName, width, height, top)
    local step, ceiling = Honor.Nice(top)
    local Kit = SoundAlerter.Page.Kit
    local lines, labels = state[gridName], state[labelName]
    local used = 0
    local value = 0
    while value <= ceiling + 1e-6 and used < HV.GRID do
        used = used + 1
        local y = height - value / ceiling * height
        local line = lines[used]
        if not line then
            line = Kit.Paint(plot, Kit.COLOR.line, 1, "BACKGROUND")
            lines[used] = line
        end
        honorRect(line, plot, HV.AXIS, y, width, 1)
        local label = labels[used]
        if not label then
            label = Kit.Text(plot, 10, Kit.COLOR.muted, "RIGHT")
            label:SetWidth(HV.AXIS - 6)
            labels[used] = label
        end
        label:ClearAllPoints()
        label:SetPoint("RIGHT", plot, "TOPLEFT", HV.AXIS - 6, -y)
        label:SetText(Honor.Short(value))
        label:Show()
        value = value + step
    end
    for index = used + 1, #lines do
        lines[index]:Hide()
        labels[index]:Hide()
    end
    return ceiling
end

local function honorChip(list, index, parent, onClick)
    local chip = list[index]
    if chip then return chip end
    chip = SoundAlerter.Page.Kit.MakeChip(parent, "", function() onClick(list[index]) end)
    chip.frame:SetHeight(HV.HEAD - 4)
    list[index] = chip
    return chip
end

local function honorHover(plot, find, show)
    local index
    local function track(self)
        local scale = self:GetEffectiveScale()
        local x = GetCursorPosition() / scale - (self:GetLeft() or 0)
        local found = find(x)
        if found == index then return end
        index = found
        if found then show(self, found) else SoundAlerter.Page.Kit.HideTip() end
    end
    plot:EnableMouse(true)
    plot:SetScript("OnEnter", function(self)
        index = nil
        self:SetScript("OnUpdate", track)
    end)
    plot:SetScript("OnLeave", function(self)
        self:SetScript("OnUpdate", nil)
        index = nil
        SoundAlerter.Page.Kit.HideTip()
    end)
end

local function nearest(xs, count, x)
    if count == 0 then return nil end
    local low, high = 1, count
    while low < high do
        local mid = math.floor((low + high) / 2)
        if xs[mid] < x then low = mid + 1 else high = mid end
    end
    if low > 1 and math.abs(xs[low - 1] - x) < math.abs(xs[low] - x) then low = low - 1 end
    return low
end

local function honorResultText(record)
    local result = record.result
    if result == "won" then return "|cff3ddc97Victory|r" end
    if result == "lost" then return "|cffff5c5cDefeat|r" end
    return "Match over"
end

local function matchAround(history, at)
    for index = 1, #history do
        local record = history[index]
        local ends = record.at or 0
        if ends + HV.BG_SLACK < at then return nil end
        if at >= ends - (record.length or 0) - HV.BG_SLACK then return record end
    end
    return nil
end

local function showStep(state, plot, index)
    local kind, gain = state.drawKind[index], state.drawGain[index]
    local title
    if kind == HV.KIND_SPEND then
        title = "|cffff5c5cSpent " .. Honor.Comma(-gain) .. "|r"
    elseif kind == HV.KIND_WORLD then
        title = "|cff6fa8ffWorld PvP|r · +" .. Honor.Comma(gain)
    else
        local record = matchAround(state.history, state.drawAt[index])
        title = (record and (honorResultText(record) .. " · " .. (record.map or "?")) or "Battleground") .. " · +" .. Honor.Comma(gain)
    end
    SoundAlerter.Page.Kit.ShowTip(plot, title, date("%d %b %H:%M", state.drawAt[index]) .. " · balance " .. Honor.Comma(state.drawValue[index]))
end

local function showBar(state, plot, index)
    local record = state.list[index]
    if not record then return end
    local honor, kills, bonus = Honor.Split(record)
    local body = kills and ("Kills " .. kills .. " + bonus " .. bonus) or "Saved before the kill split fix"
    local hours = (record.length or 0) / 3600
    if hours > 0 then body = body .. "\n" .. math.floor(honor / hours + 0.5) .. " honor per hour" end
    SoundAlerter.Page.Kit.ShowTip(plot, honorResultText(record) .. " · " .. (record.map or "?") .. " · +" .. honor, (record.when or "") .. "\n" .. body)
end

local function buildHonor(frame, page)
    local state = watchWidth({ frame = frame, page = page, built = false, height = 0, width = 0, pending = false }, frame, page)
    local queued = false
    local function redraw()
        queued = false
        if frame:IsVisible() then page:Refresh() end
    end
    state.changed = function()
        if queued or not state.built then return end
        queued = true
        C_Timer.After(HV.REFRESH_DELAY, redraw)
    end
    frame:HookScript("OnShow", function()
        local active = statistics()
        if active then active:SetHonorListener(state.changed) end
    end)
    frame:HookScript("OnHide", function()
        local active = statistics()
        if active then active:SetHonorListener(nil) end
    end)
    return state
end

local function newGoalRow(state, card)
    local Kit = SoundAlerter.Page.Kit
    local row = {}
    row.name = Kit.Text(card, 11.5, Kit.COLOR.text)
    row.have = Kit.Text(card, 10.5, Kit.COLOR.muted, "RIGHT")
    row.track = Kit.Paint(card, HC.TRACK, 1, "ARTWORK")
    row.fill = Kit.Paint(card, HC.KILL, 1, "OVERLAY")
    row.eta = Kit.Text(card, 10, Kit.COLOR.muted)
    local remove = CreateFrame("Button", nil, card)
    remove:SetSize(HV.REMOVE, HV.REMOVE)
    local fill = Kit.Paint(remove, Kit.COLOR.line, 1)
    fill:SetAllPoints(remove)
    local mark = Kit.Text(remove, 11, Kit.COLOR.muted, "CENTER")
    mark:SetPoint("CENTER", remove, "CENTER", 0, 0)
    mark:SetText("x")
    remove:SetScript("OnClick", function()
        local active = statistics()
        if active and row.index and active:RemoveHonorGoal(row.index) then state.page:Refresh() end
    end)
    SA_MenuFX.Press(remove, fill, mark)
    row.remove = remove
    return row
end

local function fillHonor(state)
    local Kit = SoundAlerter.Page.Kit
    local frame, page = state.frame, state.page
    state.built = true
    state.kpis, state.rangeChips, state.mapChips, state.maps, state.list, state.goalRows = {}, {}, {}, {}, {}, {}
    state.series = Honor.NewSeries()
    state.summary = {}
    state.drawX, state.drawAt, state.drawValue, state.drawGain, state.drawKind = {}, {}, {}, {}, {}
    state.drawCount, state.barCount, state.barSlot = 0, 0, 1
    for _, name in ipairs({ "hz", "vt", "fill", "dots", "cap", "kill", "bonus", "tick" }) do state[name] = { used = 0, shown = 0 } end
    state.gridA, state.labelA, state.gridB, state.labelB = {}, {}, {}, {}

    local card = dashBox(frame, Kit)
    state.card = card
    state.cardWarn = Kit.Paint(card, HC.WARN_FILL, 1, "BORDER")
    state.cardWarn:SetAllPoints(card)
    state.balance = Kit.Text(card, 22, Kit.COLOR.text)
    state.balance:SetPoint("TOPLEFT", card, "TOPLEFT", HV.PAD + 2, -HV.PAD)
    state.balanceLabel = Kit.Text(card, 10.5, Kit.COLOR.muted)
    state.balanceLabel:SetPoint("TOPLEFT", card, "TOPLEFT", HV.PAD + 2, -(HV.PAD + 28))
    state.capTrack = Kit.Paint(card, HC.TRACK, 1, "ARTWORK")
    state.capFill = Kit.Paint(card, HC.KILL, 1, "OVERLAY")

    for index = 1, #HV.KPI_LABELS do
        local tile = dashBox(frame, Kit)
        tile.value = Kit.Text(tile, 15, Kit.COLOR.text)
        tile.value:SetPoint("TOPLEFT", tile, "TOPLEFT", 7, -5)
        tile.label = Kit.Text(tile, 10.5, index == #HV.KPI_LABELS and BG_GOLD or Kit.COLOR.muted)
        tile.label:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 7, 5)
        tile.label:SetText(HV.KPI_LABELS[index])
        state.kpis[index] = tile
    end

    local goals = dashBox(frame, Kit)
    state.goalCard = goals
    state.goalTitle = Kit.Text(goals, 10.5, Kit.COLOR.accent)
    state.goalTitle:SetPoint("TOPLEFT", goals, "TOPLEFT", HV.PAD, -HV.PAD)
    state.goalTitle:SetText("GOALS")
    state.goalNote = Kit.Text(goals, 10.5, Kit.COLOR.muted)
    state.goalTotal = Kit.Text(goals, 10.5, Kit.COLOR.muted)
    state.goalName = Kit.MakeText(goals, {}, function() end)
    state.goalCost = Kit.MakeText(goals, {}, function() end)
    state.goalAdd = Kit.MakeButton(goals, "Add", function()
        local active = statistics()
        if not active then return end
        local nameBox, costBox = state.goalName.frame, state.goalCost.frame
        if not active:AddHonorGoal(nameBox:GetText(), (costBox:GetText() or ""):gsub("%D", "")) then return end
        nameBox:SetText("")
        costBox:SetText("")
        page:Refresh()
    end)
    state.goalAdd.frame:SetHeight(HV.ADD_HEIGHT)
    state.goalAdd.frame:SetWidth(46)

    state.titleA = Kit.Text(frame, 10.5, Kit.COLOR.accent)
    state.titleA:SetText("HONOR POINTS")
    for index, range in ipairs(HV.RANGES) do
        local chip = honorChip(state.rangeChips, index, frame, function(own)
            honorUI.range = own.range
            page:Refresh()
        end)
        chip.range = range[1]
        chip:SetLabel(range[2])
    end
    state.plotA = CreateFrame("Frame", nil, frame)
    state.paceLabel = Kit.Text(state.plotA, 10.5, HC.BONUS, "RIGHT")
    state.capLabel = Kit.Text(state.plotA, 10, HC.BONUS)
    state.fromLabel = Kit.Text(state.plotA, 10, Kit.COLOR.muted)
    state.nowLabel = Kit.Text(state.plotA, 10, Kit.COLOR.muted, "RIGHT")
    state.nowLabel:SetText("now")
    state.legendA = Kit.Text(frame, 10.5, Kit.COLOR.muted)
    state.legendA:SetText("|cffff7d0aBattlegrounds|r   |cff6fa8ffWorld PvP|r   |cffff5c5cSpent|r   |cff3ddc97Won|r   |cffff5c5cLost|r")
    state.emptyA = Kit.Text(frame, 12, Kit.COLOR.muted)
    state.emptyA:SetText("Your Honor Points are drawn from the next change.")
    honorHover(state.plotA, function(x) return nearest(state.drawX, state.drawCount, x) end, function(plot, index) showStep(state, plot, index) end)

    state.titleB = Kit.Text(frame, 10.5, Kit.COLOR.accent)
    state.titleB:SetText("PER MATCH")
    state.plotB = CreateFrame("Frame", nil, frame)
    state.avgLine = Kit.Paint(state.plotB, Kit.COLOR.text, 0.45, "OVERLAY")
    state.avgLabel = Kit.Text(state.plotB, 10, Kit.COLOR.text)
    state.legendB = Kit.Text(frame, 10.5, Kit.COLOR.muted)
    state.legendB:SetText("|cffff7d0aKills|r   |cffffd100Bonus|r   |cffff5c5cLost match bonus|r   |cff9a7a55Before the fix|r")
    state.emptyB = Kit.Text(frame, 12, Kit.COLOR.muted)
    state.emptyB:SetText("No battlegrounds yet. Each match adds a bar when it ends.")
    honorHover(state.plotB, function(x)
        if state.barCount == 0 then return nil end
        local slot = math.floor((x - HV.AXIS) / state.barSlot)
        local index = Honor.BARS - slot
        if index < 1 or index > state.barCount then return nil end
        return index
    end, function(plot, index) showBar(state, plot, index) end)
end

local function placeBalance(state, width)
    local Kit = SoundAlerter.Page.Kit
    local card = state.card
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", state.frame, "TOPLEFT", 0, 0)
    card:SetSize(width, HV.CARD_HEIGHT)
    local balance = Honor.Balance(state.store)
    local cap = state.store.wallet.cap
    local left, warn = Honor.CapState(balance, cap)
    state.balanceLabel:SetWidth(width - HV.PAD * 2 - 2)
    state.cardWarn:SetShown(warn == true)
    Kit.Tint(state.balanceLabel, warn and BG_GOLD or Kit.COLOR.muted)
    if not balance then
        state.balance:SetText("-")
        state.balanceLabel:SetText("Honor Points · shown after the next change")
    elseif left then
        state.balance:SetText(Honor.Comma(balance))
        state.balanceLabel:SetText("Honor Points · " .. (warn and "only " or "") .. Honor.Comma(math.max(0, left)) .. " to cap")
    else
        state.balance:SetText(Honor.Comma(balance))
        state.balanceLabel:SetText("Honor Points")
    end
    local barWidth = width - HV.PAD * 2
    local barY = HV.CARD_HEIGHT - HV.PAD - HV.CAP_BAR
    if balance and cap and cap > 0 then
        honorRect(state.capTrack, card, HV.PAD, barY, barWidth, HV.CAP_BAR)
        Kit.Tint(state.capFill, warn and HC.BONUS or HC.KILL)
        honorRect(state.capFill, card, HV.PAD, barY, barWidth * math.min(1, balance / cap), HV.CAP_BAR)
        state.capFill:SetShown(balance > 0)
    else
        state.capTrack:Hide()
        state.capFill:Hide()
    end
    return HV.CARD_HEIGHT + BG_GAP
end

local function placeHonorKpis(state, width, y)
    local summary = state.summary
    local half = (width - BG_GAP) / 2
    local values = {
        Honor.Short(summary.today),
        Honor.Short(summary.week),
        summary.perMatch and Honor.Short(summary.perMatch) or "-",
        summary.perHour and Honor.Short(summary.perHour) or "-",
        summary.best > 0 and Honor.Short(summary.best) or "-",
    }
    local count = #state.kpis
    for index, tile in ipairs(state.kpis) do
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        local full = index == count and count % 2 == 1
        tile:ClearAllPoints()
        tile:SetSize(full and width or half, BG_KPI_HEIGHT)
        tile:SetPoint("TOPLEFT", state.frame, "TOPLEFT", full and 0 or column * (half + BG_GAP), -(y + row * (BG_KPI_HEIGHT + BG_GAP)))
        tile.value:SetText(values[index])
    end
    local rows = math.ceil(count / 2)
    return y + rows * (BG_KPI_HEIGHT + BG_GAP)
end

local function placeGoals(state, settings, width, y)
    local Kit = SoundAlerter.Page.Kit
    local card = state.goalCard
    local goals = state.store.goals
    local balance = Honor.Balance(state.store) or 0
    local mean = Honor.Pace(state.store, settings.today)
    local inner = width - HV.PAD * 2
    local rowY = HV.PAD + HV.GOAL_TITLE
    local rows = state.goalRows
    local sum = 0
    for index = 1, #goals do
        local goal = goals[index]
        local row = rows[index]
        if not row then
            row = newGoalRow(state, card)
            rows[index] = row
        end
        row.index = index
        sum = sum + goal.cost
        local done = balance >= goal.cost
        row.remove:ClearAllPoints()
        row.remove:SetPoint("TOPRIGHT", card, "TOPRIGHT", -HV.PAD, -rowY)
        row.remove:Show()
        row.have:ClearAllPoints()
        row.have:SetPoint("TOPRIGHT", card, "TOPRIGHT", -(HV.PAD + HV.REMOVE + 4), -(rowY + 2))
        row.have:SetText(Honor.Comma(math.min(balance, goal.cost)) .. " / " .. Honor.Comma(goal.cost))
        row.have:Show()
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", card, "TOPLEFT", HV.PAD, -(rowY + 1))
        row.name:SetWidth(math.max(20, inner - HV.REMOVE - 8 - row.have:GetStringWidth()))
        row.name:SetText(goal.name)
        row.name:Show()
        honorRect(row.track, card, HV.PAD, rowY + 18, inner, HV.GOAL_TRACK)
        Kit.Tint(row.fill, done and Kit.COLOR.on or HC.KILL)
        honorRect(row.fill, card, HV.PAD, rowY + 18, inner * math.min(1, balance / goal.cost), HV.GOAL_TRACK)
        row.fill:SetShown(balance > 0)
        row.eta:ClearAllPoints()
        row.eta:SetPoint("TOPLEFT", card, "TOPLEFT", HV.PAD, -(rowY + 27))
        row.eta:SetWidth(inner)
        if done then
            Kit.Tint(row.eta, Kit.COLOR.on)
            row.eta:SetText("Ready to buy")
        else
            Kit.Tint(row.eta, Kit.COLOR.muted)
            local days = Honor.GoalDays(balance, goal.cost, mean)
            local text = Honor.Comma(goal.cost - balance) .. " to go"
            row.eta:SetText(days and (text .. " · about " .. days .. (days == 1 and " day" or " days")) or text)
        end
        row.eta:Show()
        rowY = rowY + HV.GOAL_ROW
    end
    for index = #goals + 1, #rows do
        local row = rows[index]
        row.index = nil
        row.name:Hide()
        row.have:Hide()
        row.track:Hide()
        row.fill:Hide()
        row.eta:Hide()
        row.remove:Hide()
    end
    state.goalNote:ClearAllPoints()
    state.goalTotal:ClearAllPoints()
    state.goalNote:SetWidth(inner)
    state.goalTotal:SetWidth(inner)
    if #goals == 0 then
        state.goalNote:SetPoint("TOPLEFT", card, "TOPLEFT", HV.PAD, -rowY)
        state.goalNote:SetText("Add an item and its honor cost.")
        state.goalNote:Show()
        rowY = rowY + HV.GOAL_LINE
    else
        state.goalNote:Hide()
    end
    if #goals > 1 then
        state.goalTotal:SetPoint("TOPLEFT", card, "TOPLEFT", HV.PAD, -rowY)
        local days = Honor.GoalDays(balance, sum, mean)
        local text = "All " .. #goals .. ": " .. Honor.Comma(sum)
        if balance >= sum then
            text = text .. " · you can buy them all"
        elseif days then
            text = text .. " · about " .. days .. (days == 1 and " day" or " days")
        end
        state.goalTotal:SetText(text)
        state.goalTotal:Show()
        rowY = rowY + HV.GOAL_LINE
    else
        state.goalTotal:Hide()
    end
    local nameBox, costBox, add = state.goalName.frame, state.goalCost.frame, state.goalAdd.frame
    if #goals < Honor.GOALS then
        local addWidth = add:GetWidth()
        nameBox:ClearAllPoints()
        nameBox:SetPoint("TOPLEFT", card, "TOPLEFT", HV.PAD, -(rowY + 2))
        nameBox:SetSize(math.max(40, inner - HV.COST_WIDTH - addWidth - 8), HV.ADD_HEIGHT)
        costBox:ClearAllPoints()
        costBox:SetPoint("TOPLEFT", nameBox, "TOPRIGHT", 4, 0)
        costBox:SetSize(HV.COST_WIDTH, HV.ADD_HEIGHT)
        add:ClearAllPoints()
        add:SetPoint("TOPLEFT", costBox, "TOPRIGHT", 4, 0)
        nameBox:Show()
        costBox:Show()
        add:Show()
        rowY = rowY + HV.ADD_HEIGHT + 4
    else
        nameBox:Hide()
        costBox:Hide()
        add:Hide()
    end
    local height = rowY + HV.PAD - 2
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", state.frame, "TOPLEFT", 0, -y)
    card:SetSize(width, height)
    return y + height + BG_GAP
end

local function placeHead(state, title, chips, active, x0, y, width)
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", state.frame, "TOPLEFT", x0, -(y + 5))
    local x = x0 + width
    for index = #chips, 1, -1 do
        local chip = chips[index]
        if chip.visible ~= false then
            x = x - chip.frame:GetWidth()
            chip.frame:ClearAllPoints()
            chip.frame:SetPoint("TOPLEFT", state.frame, "TOPLEFT", x, -y)
            chip:Set(active(chip))
            x = x - 4
        end
    end
    return y + HV.HEAD
end

local function collapse(state, series, plotWidth, start, span, base)
    local xs, ats, values, gains, kinds = state.drawX, state.drawAt, state.drawValue, state.drawGain, state.drawKind
    local history = state.history
    local cursor = #history
    local count, previous = 0, base
    for index = 1, series.count do
        local at, value = series.at[index], series.value[index]
        local x = HV.AXIS + math.min(1, math.max(0, (at - start) / span)) * plotWidth
        local kind = HV.KIND_SPEND
        if value >= previous then
            while cursor > 0 and (history[cursor].at or 0) + HV.BG_SLACK < at do cursor = cursor - 1 end
            local record = history[cursor]
            kind = (record and at >= (record.at or 0) - (record.length or 0) - HV.BG_SLACK) and HV.KIND_BG or HV.KIND_WORLD
        end
        if count > 0 and x - xs[count] < HV.BUCKET and kinds[count] == kind then
            gains[count] = gains[count] + value - previous
            values[count], ats[count] = value, at
        else
            count = count + 1
            xs[count], ats[count], values[count], gains[count], kinds[count] = x, at, value, value - previous, kind
        end
        previous = value
    end
    for extra = count + 1, state.drawCount do
        xs[extra], ats[extra], values[extra], gains[extra], kinds[extra] = nil, nil, nil, nil, nil
    end
    state.drawCount = count
    return count
end

local function placeChartA(state, settings, x0, width, y)
    local Kit = SoundAlerter.Page.Kit
    local store = state.store
    local plot = state.plotA
    local range = honorUI.range
    local from = range > 0 and ((settings.today - range + 1) * HV.DAY - settings.offset) or nil
    local series = Honor.Series(store, from, settings.offset, state.series)
    honorBegin(state, "hz", "vt", "fill", "dots", "cap")
    if series.count == 0 and not series.base then
        state.drawCount = 0
        plot:Hide()
        state.legendA:Hide()
        state.capLabel:Hide()
        honorPools(state, "hz", "vt", "fill", "dots", "cap")
        state.emptyA:ClearAllPoints()
        state.emptyA:SetPoint("TOPLEFT", state.frame, "TOPLEFT", x0, -y)
        state.emptyA:Show()
        return y + 24
    end
    state.emptyA:Hide()
    local plotWidth = width - HV.AXIS - HV.RIGHT
    local height = HV.A_HEIGHT
    plot:ClearAllPoints()
    plot:SetPoint("TOPLEFT", state.frame, "TOPLEFT", x0, -y)
    plot:SetSize(width, height + HV.FOOT)
    plot:Show()
    local now = settings.now
    local base = series.base or series.value[1]
    local start = from or series.at[1]
    local span = math.max(1, now - start)
    local top = base
    for index = 1, series.count do if series.value[index] > top then top = series.value[index] end end
    local cap = store.wallet.cap
    local showCap = cap and cap > 0 and top >= cap * Honor.CAP_SHOW
    local ceiling = honorAxis(state, plot, "gridA", "labelA", plotWidth, height, showCap and cap or math.max(top, 1))
    local function Y(value) return height - math.min(value, ceiling) / ceiling * height end
    local count = collapse(state, series, plotWidth, start, span, base)
    local xs, values, kinds = state.drawX, state.drawValue, state.drawKind
    local prevX, prevY = HV.AXIS, Y(base)
    for index = 1, count + 1 do
        local x = index <= count and xs[index] or (HV.AXIS + plotWidth)
        honorRect(honorPool(state, "fill", plot, HC.KILL, 0.1, "BACKGROUND"), plot, prevX, prevY, x - prevX, height - prevY)
        honorRect(honorPool(state, "hz", plot, HC.KILL, 1, "ARTWORK"), plot, prevX, prevY - HV.LINE / 2, x - prevX + HV.LINE / 2, HV.LINE)
        if index <= count then
            local y2 = Y(values[index])
            local upper, lower = math.min(prevY, y2), math.max(prevY, y2)
            local vertical = honorPool(state, "vt", plot, HC.KILL, 1, "ARTWORK")
            Kit.Tint(vertical, HV.KIND_COLOR[kinds[index]])
            honorRect(vertical, plot, x - HV.LINE / 2, upper - HV.LINE / 2, HV.LINE, lower - upper + HV.LINE)
            prevX, prevY = x, y2
        end
    end
    local history = state.history
    for index = 1, #history do
        local record = history[index]
        local at = record.at or 0
        if at < start then break end
        local value = Honor.ValueAt(series, at) or base
        local dot = honorPool(state, "dots", plot, Kit.COLOR.on, 1, "OVERLAY", DISC_TEXTURE)
        Kit.Tint(dot, record.result == "lost" and HC.LOSS or Kit.COLOR.on)
        local x = HV.AXIS + math.min(1, (at - start) / span) * plotWidth
        honorRect(dot, plot, x - HV.DOT / 2, Y(value) - HV.DOT / 2, HV.DOT, HV.DOT)
    end
    if showCap then
        local capY = Y(cap)
        for x = HV.AXIS, HV.AXIS + plotWidth - HV.DASH, HV.DASH + HV.DASH_GAP do
            honorRect(honorPool(state, "cap", plot, HC.BONUS, 0.8, "OVERLAY"), plot, x, capY, HV.DASH, 1)
        end
        state.capLabel:ClearAllPoints()
        state.capLabel:SetPoint("BOTTOMLEFT", plot, "TOPLEFT", HV.AXIS + 4, -capY + 2)
        state.capLabel:SetText("Cap " .. Honor.Comma(cap))
        state.capLabel:Show()
    else
        state.capLabel:Hide()
    end
    honorPools(state, "hz", "vt", "fill", "dots", "cap")
    local mean = Honor.Pace(store, settings.today)
    if mean and mean > 0 and not showCap then
        state.paceLabel:ClearAllPoints()
        state.paceLabel:SetPoint("TOPRIGHT", plot, "TOPLEFT", HV.AXIS + plotWidth, -2)
        state.paceLabel:SetText("about " .. Honor.Short(mean) .. " a day")
        state.paceLabel:Show()
    else
        state.paceLabel:Hide()
    end
    state.fromLabel:ClearAllPoints()
    state.fromLabel:SetPoint("TOPLEFT", plot, "TOPLEFT", HV.AXIS, -(height + 3))
    state.fromLabel:SetText(range > 0 and (range .. " days ago") or date("%d %b", start))
    state.nowLabel:ClearAllPoints()
    state.nowLabel:SetPoint("TOPRIGHT", plot, "TOPLEFT", HV.AXIS + plotWidth, -(height + 3))
    y = y + height + HV.FOOT
    state.legendA:ClearAllPoints()
    state.legendA:SetPoint("TOPLEFT", state.frame, "TOPLEFT", x0 + HV.AXIS, -y)
    state.legendA:Show()
    return y + HV.LEGEND + BG_GAP
end

local function placeChartB(state, settings, x0, width, y)
    local Kit = SoundAlerter.Page.Kit
    local maps = BG.Maps(settings.bg, state.maps)
    local valid = honorUI.map == "all"
    for index = 1, #maps do if maps[index] == honorUI.map then valid = true end end
    if not valid then honorUI.map = "all" end
    local chips = state.mapChips
    local used = 0
    if #maps > 1 then
        for index = 0, #maps do
            used = used + 1
            local chip = honorChip(chips, used, state.frame, function(own)
                honorUI.map = own.map
                state.page:Refresh()
            end)
            chip.map = index == 0 and "all" or maps[index]
            chip:SetLabel(index == 0 and "All" or BG.ShortMap(maps[index]))
            chip.visible = true
            chip.frame:Show()
        end
    end
    for index = used + 1, #chips do
        chips[index].visible = false
        chips[index].frame:Hide()
    end
    y = placeHead(state, state.titleB, chips, function(chip) return chip.map == honorUI.map end, x0, y, width)
    local list = Honor.Bars(state.history, honorUI.map, Honor.BARS, state.list)
    honorBegin(state, "kill", "bonus", "tick")
    local plot = state.plotB
    state.barCount = #list
    if #list == 0 then
        plot:Hide()
        state.legendB:Hide()
        honorPools(state, "kill", "bonus", "tick")
        state.emptyB:ClearAllPoints()
        state.emptyB:SetPoint("TOPLEFT", state.frame, "TOPLEFT", x0, -y)
        state.emptyB:Show()
        return y + 24
    end
    state.emptyB:Hide()
    local plotWidth = width - HV.AXIS - HV.RIGHT
    local height = HV.B_HEIGHT
    plot:ClearAllPoints()
    plot:SetPoint("TOPLEFT", state.frame, "TOPLEFT", x0, -y)
    plot:SetSize(width, height + 6)
    plot:Show()
    local top, sum = 1, 0
    for index = 1, #list do
        local honor = Honor.HonorOf(list[index])
        sum = sum + honor
        if honor > top then top = honor end
    end
    local ceiling = honorAxis(state, plot, "gridB", "labelB", plotWidth, height, top)
    local function Y(value) return height - math.min(value, ceiling) / ceiling * height end
    local slot = plotWidth / Honor.BARS
    state.barSlot = slot
    local barWidth = math.max(1, slot - 2)
    for index = 1, #list do
        local record = list[index]
        local x = HV.AXIS + (Honor.BARS - index) * slot + 1
        local honor, kills = Honor.Split(record)
        local lost = record.result == "lost"
        if kills then
            if kills > 0 then
                local killBar = honorPool(state, "kill", plot, HC.KILL, 1, "ARTWORK")
                Kit.Tint(killBar, HC.KILL)
                honorRect(killBar, plot, x, Y(kills), barWidth, height - Y(kills))
            end
            if honor > kills then
                local bonus = honorPool(state, "bonus", plot, HC.BONUS, 1, "ARTWORK")
                Kit.Tint(bonus, lost and HC.LOSS or HC.BONUS, lost and 0.6 or 1)
                honorRect(bonus, plot, x, Y(honor), barWidth, Y(kills) - Y(honor))
            end
        elseif honor > 0 then
            local solid = honorPool(state, "kill", plot, HC.SOLID, 1, "ARTWORK")
            Kit.Tint(solid, HC.SOLID)
            honorRect(solid, plot, x, Y(honor), barWidth, height - Y(honor))
        end
        local tick = honorPool(state, "tick", plot, Kit.COLOR.on, 1, "ARTWORK")
        Kit.Tint(tick, lost and HC.LOSS or Kit.COLOR.on)
        honorRect(tick, plot, x, height + 3, barWidth, 2)
    end
    honorPools(state, "kill", "bonus", "tick")
    local average = sum / #list
    honorRect(state.avgLine, plot, HV.AXIS, Y(average), plotWidth, 1)
    state.avgLabel:ClearAllPoints()
    state.avgLabel:SetPoint("BOTTOMLEFT", plot, "TOPLEFT", HV.AXIS + 4, -Y(average) + 2)
    state.avgLabel:SetText("average " .. Honor.Short(average))
    y = y + height + 6 + 4
    state.legendB:ClearAllPoints()
    state.legendB:SetPoint("TOPLEFT", state.frame, "TOPLEFT", x0 + HV.AXIS, -y)
    state.legendB:Show()
    return y + HV.LEGEND
end

local function updateHonor(state, settings, width)
    if not state.built then fillHonor(state) end
    local active = statistics()
    local version = active and active:HonorVersion() or 0
    local matches = active and select(2, active:Version()) or 0
    local key = version .. "|" .. matches .. "|" .. width .. "|" .. honorUI.range .. "|" .. honorUI.map .. "|" .. (settings.today or 0)
    if key == state.key then return state.height end
    state.key, state.width, state.honorVersion = key, width, version
    state.layouts = (state.layouts or 0) + 1
    state.store = settings.honor or HONOR_EMPTY_STORE
    state.history = settings.bg and settings.bg.history or NO_ENTRIES
    Honor.Summary(state.store, state.history, settings.today, settings.offset, state.summary)
    local stacked = width < HV.STACK
    local rail = stacked and width or math.max(HV.RAIL_MIN, math.min(HV.RAIL_MAX, math.floor(width * HV.RAIL_SHARE)))
    local left = placeBalance(state, rail)
    left = placeHonorKpis(state, rail, left)
    left = placeGoals(state, settings, rail, left)
    local x0 = stacked and 0 or rail + BG_GAP
    local chartWidth = width - x0
    local y = stacked and left or 0
    y = placeHead(state, state.titleA, state.rangeChips, function(chip) return chip.range == honorUI.range end, x0, y, chartWidth)
    y = placeChartA(state, settings, x0, chartWidth, y)
    y = placeChartB(state, settings, x0, chartWidth, y)
    state.height = (stacked and y or math.max(left, y)) + BG_GAP
    return state.height
end

local SHOW_LABELS = { topSpells = "spells", enemies = "enemies", classes = "classes" }

function SoundAlerter:BuildStatisticsOptions()
    local Page = SoundAlerter.Page

    local SORT_HINTS = {
        topSpells = "How the list below is ordered.",
        enemies = "How the list below is ordered. Threat is alerts per encounter: a player who sets off many alerts each time they show up ranks high.",
        classes = "How the list below is ordered.",
    }

    local function open(key)
        return function(settings) return settings.enabled and expanded[key] end
    end

    local function sorter(key, label, group)
        return Page.Visible(open(key), Page.Select("sort." .. key, "Sort by", SORT_HINTS[key], SORT_OPTIONS[key], false, group))
    end

    local function showAll(key, group)
        local function label(settings)
            if expanded[key] then return "Hide the full list" end
            return "Show all " .. ((settings.counts or {})[key] or 0) .. " " .. SHOW_LABELS[key]
        end
        local row = Page.Action(label, "", function() expanded[key] = not expanded[key] end, false, group)
        return Page.Visible(function(settings) return settings.enabled and ((settings.counts or {})[key] or 0) > 0 end, row)
    end

    local function listBlock(key, group)
        return Page.Visible(open(key), Page.Block(group, function(settings) return settings.text[key] end, false, group))
    end


    local exportRow = Page.Text("text.export", "Export", "Select all and copy to share or keep your numbers.", true, "Data", 8)
    local resetSessionRow = Page.Action("Reset session", "Reset this session's numbers. All-time statistics are kept.", resetSession, true, "Data")
    resetSessionRow.confirm = "Click again to reset"
    local resetAllRow = Page.Action("Reset all-time", "Delete all statistics for this profile, session and all-time. This cannot be undone.", resetAllTime, true, "Data")
    resetAllRow.confirm = "Click again to delete everything"

    local function bgOn(settings)
        return settings.enabled and settings.mode == "bg"
    end

    local function honorOn(settings)
        return settings.enabled and settings.mode == "honor"
    end

    local function overview(row)
        local inner = row.visible
        row.visible = function(settings)
            local mode = settings.mode
            return (mode == nil or OVERVIEW_MODES[mode] == true) and (inner == nil or inner(settings))
        end
        return row
    end

    local spec = Page.Spec({
        title = "Statistics",
        icon = "Interface\\Icons\\Spell_Holy_MindVision",
        blurb = "What triggered your alerts this session and all-time: which fired, from whom and where. Counting costs under 0.02 ms per alert.",
        get = view,
        set = write,
        summary = summary,
        preview = Panel,
        rows = {
            Page.Visible(reportOn, Page.Select("mode", "Show", "Session numbers, everything since you started, your battlegrounds, or your honor over time. Spells, enemies and places follow this; totals show both.", { { "all", "All-time" }, { "session", "Session" }, { "bg", "BG" }, { "honor", "Honor" } }, false, "Overview")),
            overview(Page.Visible(reportOn, Page.Custom(DASH_HEIGHT, buildDashboard, updateDashboard, false, "Overview"))),
            Page.Visible(bgOn, Page.Custom(BG_KPI_HEIGHT, buildBG, updateBG, false, "Battlegrounds")),
            Page.Visible(honorOn, Page.Custom(BG_KPI_HEIGHT, buildHonor, updateHonor, false, "Honor")),
            Page.Visible(bgOn, Page.Toggle("bgPill", "Result pill after battlegrounds", "A small pill under the minimap button for 2 minutes after each match; click it for your results.", false, "Battlegrounds")),
            overview(showAll("topSpells", "Spells")),
            overview(sorter("topSpells", "Sort by", "Spells")),
            overview(listBlock("topSpells", "Spells")),
            overview(showAll("enemies", "Enemies")),
            overview(sorter("enemies", "Sort by", "Enemies")),
            overview(listBlock("enemies", "Enemies")),
            overview(showAll("classes", "Classes")),
            overview(sorter("classes", "Sort by", "Classes")),
            overview(listBlock("classes", "Classes")),
            overview(Page.Visible(reportOn, exportRow)),
            Page.Visible(reportOn, resetSessionRow),
            Page.Visible(reportOn, resetAllRow),
        },
    })
    local options = Page.Options(spec, "Statistics", "Interface\\Icons\\Spell_Holy_MindVision", "Alert statistics for this profile.", 2.9)
    return Page.Guard(options, "Statistics", "Statistics", statistics)
end
