local SoundAlerter = SoundAlerter

local SORT_OPTIONS = {
    topSpells = { { "count_desc", "Most alerts" }, { "trend", "Trend (rising first)" }, { "name_asc", "Name (A-Z)" }, { "time", "Most recent" } },
    enemies = { { "alerts_desc", "Most alerts" }, { "danger", "Threat" }, { "name_asc", "Name (A-Z)" }, { "time", "Most recent" } },
    classes = { { "alerts_desc", "Most alerts" }, { "players", "Most players" }, { "avg", "Alerts per player" }, { "class_asc", "Class (A-Z)" } },
}

local MATCHES_SHORT = 5
local expanded = { matches = false, topSpells = false, enemies = false, classes = false }

local function statistics()
    return SoundAlerter:GetModule("Statistics", true)
end

local function view()
    local active = statistics()
    if not active then return nil end
    local on = active:GetSettings().enabled and true or false
    local data = { enabled = on, sort = {}, text = { kpi = "", matches = "", matchesShort = "", topSpells = "", enemies = "", classes = "", export = "" }, counts = {}, matchCount = 0 }
    if not on then return data end
    local sorts = active:GetSortState()
    for key in pairs(SORT_OPTIONS) do data.sort[key] = sorts[key] and sorts[key].sortType end
    data.mode = active:GetSettings().overviewMode == "session" and "session" or "all"
    data.dashboard = active:GetDashboard(data.mode)
    data.counts = active:GetListCounts() or data.counts
    data.matchCount = active:GetMatchCount()
    data.text.kpi = active:GetKpiText()
    data.text.matchesShort = active:GetMatchText(MATCHES_SHORT)
    if expanded.matches then data.text.matches = active:GetMatchText() end
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
        active:SetSetting("overviewMode", value == "session" and "session" or "all")
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
local NO_ENTRIES = {}

local SOURCES = {
    visuals = {
        unit = "alerts",
        entries = function()
            local active = statistics()
            return active and active:GetVennData() or NO_ENTRIES
        end,
        note = function(_, layout) return SA_StatsVenn.NoteText(layout) end,
        empty = function() return "No spells with a recorded zone yet. Play a match and they appear here." end,
    },
}

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
    for index, zone in ipairs(widgets.zones) do
        local hot = mask ~= nil and Venn.HasZone(mask, index)
        local color = Venn.ZONES[index].color
        zone.disc:SetVertexColor(color[1], color[2], color[3], hot and DISC_HOT or DISC_ALPHA)
        zone.ring:SetVertexColor(color[1], color[2], color[3], hot and RING_HOT or RING_ALPHA)
    end
end

local function showIconTip(button)
    local item = button.item
    if not item then return end
    local Venn = SA_StatsVenn
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if item.more then
        GameTooltip:SetText(string.format("%d more spells", #item.hidden), 1, 1, 1)
        for index = 1, math.min(#item.hidden, 8) do
            GameTooltip:AddLine(item.hidden[index].name, 0.8, 0.8, 0.8)
        end
        if #item.hidden > 8 then GameTooltip:AddLine("...", 0.6, 0.65, 0.72) end
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
    if item and not item.more then SoundAlerter:OpenSpellFinderFor(item.entry.id) end
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
    else
        local color = SA_StatsVenn.GROUP_COLOR[item.entry.group]
        icon.art:SetTexture(spellTexture(item.entry.id))
        icon.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon.ring:SetVertexColor(color[1], color[2], color[3], 1)
        icon.count:SetText("")
    end
end

local bindVisuals

local function buildVisuals(view, source)
    local Kit = SoundAlerter.Page.Kit
    local Venn = SA_StatsVenn
    local geometry = Venn.Geometry(PANEL_WIDTH, Venn.SLOT, Venn.MARGIN)
    local widgets = { geometry = geometry, source = source, off = {}, byKey = {}, free = {}, seen = {}, made = 0, zones = {}, legend = {} }
    local canvas = CreateFrame("Frame", nil, view)
    canvas:SetSize(PANEL_WIDTH, geometry.height)
    canvas:SetPoint("TOPLEFT", view, "TOPLEFT", 0, 0)
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
    heatZones(widgets, nil)
    for index, group in ipairs(Venn.GROUPS) do
        local button = CreateFrame("Button", nil, view)
        button:SetSize(LEGEND_WIDTH, 16)
        button:SetPoint("TOPLEFT", view, "TOPLEFT", (index - 1) * (LEGEND_WIDTH + LEGEND_GAP), -(geometry.height + 6))
        local dot = button:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(DISC_TEXTURE)
        dot:SetSize(8, 8)
        dot:SetPoint("LEFT", button, "LEFT", 2, 0)
        dot:SetVertexColor(group.color[1], group.color[2], group.color[3], 1)
        local label = Kit.Text(button, 10, Kit.COLOR.muted)
        label:SetPoint("LEFT", dot, "RIGHT", 3, 0)
        button:SetScript("OnClick", function()
            widgets.off[group.key] = not widgets.off[group.key] or nil
            widgets.stale = true
            bindVisuals(widgets, false)
        end)
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
            GameTooltip:SetText(group.label, group.color[1], group.color[2], group.color[3])
            GameTooltip:AddLine("Click to show or hide this type", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        widgets.legend[index] = { button = button, label = label }
    end
    widgets.note = Kit.Text(view, 10, Kit.COLOR.muted)
    widgets.note:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -(geometry.height + 28))
    widgets.empty = Kit.Text(view, 11, Kit.COLOR.muted, "CENTER")
    widgets.empty:SetPoint("CENTER", canvas, "CENTER", 0, 0)
    widgets.empty:SetWidth(PANEL_WIDTH - 40)
    widgets.empty:SetWordWrap(true)
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
    for index, group in ipairs(Venn.GROUPS) do
        local legend = widgets.legend[index]
        put(legend.label, group.short .. " " .. (layout.groupCounts[group.key] or 0))
        legend.button:SetAlpha(widgets.off[group.key] and 0.38 or 1)
    end
    local source = widgets.source
    put(widgets.note, source.note(source, layout))
    if layout.pool > 0 then
        put(widgets.empty, "")
    elseif next(widgets.off) and next(layout.groupCounts) then
        put(widgets.empty, "Every spell type is switched off. Click a legend entry to show it again.")
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
        put(widgets.note, string.format("%d-%d of %d spells - 7 days, %d players", widgets.offset + 1, last, count, widgets.players or 0))
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

local Panel = { height = 300, caption = "SNAPSHOT" }

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

    local matchToggle = Page.Action(function()
        return expanded.matches and "Show the last " .. MATCHES_SHORT or "Show all matches"
    end, "", function() expanded.matches = not expanded.matches end, false, "Matches")

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
            Page.Visible(reportOn, Page.Select("mode", "Show", "Session numbers or everything since you started. Spells, enemies and places follow this; totals show both.", { { "all", "All-time" }, { "session", "Session" } }, false, "Overview")),
            Page.Visible(reportOn, Page.Custom(DASH_HEIGHT, buildDashboard, updateDashboard, false, "Overview")),
            Page.Visible(function(settings) return settings.enabled and not expanded.matches end, Page.Block("Matches", function(settings) return settings.text.matchesShort end, false, "Matches")),
            Page.Visible(function(settings) return settings.enabled and expanded.matches end, Page.Block("Matches", function(settings) return settings.text.matches end, false, "Matches")),
            Page.Visible(function(settings) return settings.enabled and (settings.matchCount or 0) > MATCHES_SHORT end, matchToggle),
            showAll("topSpells", "Spells"),
            sorter("topSpells", "Sort by", "Spells"),
            listBlock("topSpells", "Spells"),
            showAll("enemies", "Enemies"),
            sorter("enemies", "Sort by", "Enemies"),
            listBlock("enemies", "Enemies"),
            showAll("classes", "Classes"),
            sorter("classes", "Sort by", "Classes"),
            listBlock("classes", "Classes"),
            Page.Visible(reportOn, exportRow),
            Page.Visible(reportOn, resetSessionRow),
            Page.Visible(reportOn, resetAllRow),
        },
    })
    local options = Page.Options(spec, "Statistics", "Interface\\Icons\\Spell_Holy_MindVision", "Alert statistics for this profile.", 2.9)
    return Page.Guard(options, "Statistics", "Statistics", statistics)
end
