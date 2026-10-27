do
SA_GlobalMap = {}

local ENTER_ZOOM, LEAVE_ZOOM = 3, 2.6
local FULL_AGE, GONE_AGE = 120, 600
local ZONE_TYPE = 3

SA_GlobalMap.GONE_AGE = GONE_AGE
SA_GlobalMap.TIERS = {
    low = { redraw = 3, refresh = 15, cap = 50, step = true, pulse = false, tip = 1, ringPulse = false, hideMoving = true, pins = 15, pinEvery = 0.25 },
    normal = { redraw = 1, refresh = 10, cap = 150, step = false, pulse = false, tip = 2, ringPulse = true, hideMoving = false, pins = 30, pinEvery = 0.1 },
    high = { redraw = 1, refresh = 10, cap = 100000, step = false, pulse = true, tip = 3, ringPulse = true, hideMoving = false, pins = 60, pinEvery = 0.05 },
}

function SA_GlobalMap.Tier(quality)
    return SA_GlobalMap.TIERS[quality] or SA_GlobalMap.TIERS.normal
end

function SA_GlobalMap.Alpha(age, step)
    if age <= FULL_AGE then return 1 end
    if age >= GONE_AGE then return 0 end
    if step then
        if age < 300 then return 0.7 end
        if age < 450 then return 0.45 end
        return 0.25
    end
    return 1 - (age - FULL_AGE) / (GONE_AGE - FULL_AGE) * 0.85
end

function SA_GlobalMap.Mode(previous, stitched, zoom, mapType)
    if stitched and type(zoom) == "number" then
        if previous == "dots" then return zoom >= LEAVE_ZOOM and "dots" or "rings" end
        return zoom >= ENTER_ZOOM and "dots" or "rings"
    end
    if type(mapType) == "number" and mapType >= ZONE_TYPE then return "dots" end
    return "rings"
end

function SA_GlobalMap.Ago(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds < 60 then return seconds .. " s ago" end
    return math.floor(seconds / 60) .. " min ago"
end

local DIRS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
local STEALTH = { ROGUE = true, DRUID = true }
local HOT_COUNT, HOT_GROUP, HOT_RANGE = 5, 3, 200

SA_GlobalMap.STEALTH = STEALTH

function SA_GlobalMap.Short(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    if seconds < 60 then return seconds .. " s" end
    return math.floor(seconds / 60) .. " m " .. (seconds % 60) .. " s"
end

function SA_GlobalMap.Dir(dx, dy)
    local angle = math.atan2(dx, -dy)
    local index = math.floor(angle / (math.pi / 4) + 0.5) % 8
    return DIRS[index + 1]
end

function SA_GlobalMap.Bearing(dx, dy)
    return math.atan2(dx, -dy)
end

function SA_GlobalMap.Yards(distance)
    return math.max(20, math.floor(distance / 20 + 0.5) * 20)
end

local PIN_EDGE, PIN_REACH = 0.92, 2

SA_GlobalMap.PIN_EDGE, SA_GlobalMap.PIN_REACH = PIN_EDGE, PIN_REACH

function SA_GlobalMap.MinimapSpot(east, north, radius, facing)
    if type(radius) ~= "number" or radius <= 0 then return nil end
    if facing then
        local sine, cosine = math.sin(facing), math.cos(facing)
        east, north = east * cosine + north * sine, -east * sine + north * cosine
    end
    local distance = math.sqrt(east * east + north * north)
    if distance > radius * PIN_REACH then return nil end
    if distance <= radius * PIN_EDGE then return east / radius, north / radius, false end
    return east / distance * PIN_EDGE, north / distance * PIN_EDGE, true
end

function SA_GlobalMap.LevelColor(level, mine)
    if type(level) ~= "number" or level < 0 or type(mine) ~= "number" then return 1, 0.1, 0.1 end
    local diff = level - mine
    if diff >= 5 then return 1, 0.1, 0.1 end
    if diff >= 3 then return 1, 0.5, 0.25 end
    if diff >= -2 then return 1, 1, 0 end
    if diff >= -7 then return 0.25, 0.75, 0.25 end
    return 0.5, 0.5, 0.5
end

function SA_GlobalMap.Higher(level, mine)
    if type(level) ~= "number" or level < 0 then return true end
    return type(mine) == "number" and level >= mine + 3
end

function SA_GlobalMap.Verdict(count, nearGroup, confirmed)
    if count == 0 then return "Quiet" end
    if (confirmed or count) >= HOT_COUNT or (nearGroup and nearGroup >= HOT_GROUP) then return "Hot" end
    return "Active"
end

SA_GlobalMap.HOT_RANGE = HOT_RANGE

function SA_GlobalMap.Group(list, count, groupOf, groups)
    for i = 1, count do groupOf[i] = 0 end
    local total = 0
    for i = 1, count do
        if groupOf[i] == 0 then
            total = total + 1
            local members = groups[total]
            if not members then
                members = {}
                groups[total] = members
            end
            local size = 1
            members[1] = list[i]
            groupOf[i] = total
            local head = 1
            while head <= size do
                local a = members[head]
                for j = 1, count do
                    if groupOf[j] == 0 then
                        local b = list[j]
                        if math.abs(a.cx - b.cx) <= 1 and math.abs(a.cy - b.cy) <= 1 then
                            groupOf[j] = total
                            size = size + 1
                            members[size] = b
                        end
                    end
                end
                head = head + 1
            end
            for k = size + 1, #members do members[k] = nil end
        end
    end
    for k = total + 1, #groups do groups[k] = nil end
    return total
end
end

do
local SoundAlerter = SoundAlerter
local M = SA_GlobalMap

local DOT_TEXTURE = "Interface\\AddOns\\SoundAlerter\\Textures\\circle"
local FLAT = "Interface\\Buttons\\WHITE8X8"
local DOT_SIZE = 9
local WINDOW = 300
local HOT = 5
local UNCONFIRMED_ALPHA = 0.45
local PANEL_WIDTH = 220
local STRIP_WIDTH = 22
local STRIP_HEIGHT = 150
local RING_SIZE, RING_PIPS, RING_PIP, RING_RADIUS = 24, 12, 5, 9
local MERGE_DISTANCE = 26
local TIP_ZONES = 8
local MAX_ROWS = 8
local COMPACT_ROWS = 3
local ROW_HEIGHT = 14
local ROWS_TOP = 62
local GROUP_LIMIT = 60
local ARROW_TEXTURE = "Interface\\AddOns\\SoundAlerter\\Textures\\gs_arrow"
local VERDICT_COLOR = { Quiet = { 0.5, 0.83, 0.54 }, Active = { 1, 0.82, 0.29 }, Hot = { 1, 0.35, 0.29 } }
local BAR_SEGMENTS = 10
local FRESH = 20
local QUIET_AFTER_MOVE = 0.4
local CHECK_EVERY = 0.1
local PANEL_EVERY = 5
local BAND_TEXT = { C = "about 10 yd from the reporter", N = "about 28 yd from the reporter", M = "about 35 yd from the reporter", D = "seen, distance unknown" }
local SOURCE_TEXT = { P = "nameplate", T = "target", F = "focus", A = "a group member's target" }
local GREY = { r = 0.6, g = 0.6, b = 0.6 }

local layer, panel, attached
local dots, rings = {}, {}
local dotsShown, ringsShown = 0, 0
local mode = "rings"
local panelOpen = false
local clusters = {}
local pipClass, pipExact, pipGive, pipSource = {}, {}, {}, nil
local hostShown, scaleShown, quietUntil = nil, nil, 0
local sinceCheck, lastDraw, nextRefresh, nextPanel, forceDraw = 0, -1e9, 0, 0, true
local panelZone
local tier = M.TIERS.normal
local names = {}
local ordered, zones = {}, {}
local centres, centreHost = {}, nil
local mix = {}
local groups, groupOf, groupDistance, order, factParts, swatchParts, worldSizes = {}, {}, {}, {}, {}, {}, {}

local function ClassColor(class)
    local colors = RAID_CLASS_COLORS
    return colors and colors[class] or GREY
end

local function Tier()
    return tier
end

local function ZoneName(mapID)
    local name = names[mapID]
    if name == nil then
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        name = info and info.name or ""
        names[mapID] = name
    end
    return name
end

local function Stitched()
    return OpenMapAPI and OpenMapAPI.IsStitched and OpenMapAPI.IsStitched() and true or false
end

local function CanvasAndHost()
    local frame = WorldMapFrame
    if not frame or not frame:IsShown() then return nil end
    local canvas = frame.GetCanvas and frame:GetCanvas() or (frame.ScrollContainer and frame.ScrollContainer.Child)
    local host = frame.GetMapID and frame:GetMapID()
    if not canvas or type(host) ~= "number" then return nil end
    return canvas, host
end

local function Project(zone, x, y, host, stitched)
    if zone == host then return x, y end
    if not stitched then return nil end
    local u, v = OpenMapAPI.WorldFromMap(zone, x, y)
    if not u then return nil end
    return OpenMapAPI.MapFromWorld(host, u, v)
end

local function Centre(zone, host, stitched)
    if centreHost ~= host then
        for key in pairs(centres) do centres[key] = nil end
        centreHost = host
    end
    local cached = centres[zone]
    if cached == nil then
        local x, y
        if stitched then
            x, y = Project(zone, 0.5, 0.5, host, true)
        elseif C_Map and C_Map.GetMapRectOnMap then
            local ok, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, zone, host)
            if ok and minX and maxX and minY and maxY then x, y = (minX + maxX) / 2, (minY + maxY) / 2 end
        end
        cached = x and { x, y } or false
        centres[zone] = cached
    end
    if not cached then return nil end
    return cached[1], cached[2]
end

local function LayerLevel(canvas)
    local level = canvas:GetFrameLevel() + 3000
    local artTop = OpenMapAPI and OpenMapAPI.ArtTopLevel and OpenMapAPI.ArtTopLevel()
    if type(artTop) == "number" and level <= artTop then level = artTop + 5 end
    return math.min(level, 9000)
end

local function ShowTip(owner)
    local record = owner.record
    if not record or not record.guid then return end
    local tier = Tier()
    local now = GetTime()
    local color = ClassColor(record.class)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(record.name, color.r, color.g, color.b)
    local level = record.level and tostring(record.level) or "??"
    GameTooltip:AddLine(level .. " " .. (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[record.class] or record.class), 1, 1, 1)
    GameTooltip:AddLine("Last seen " .. M.Ago(now - record.lastSeen), 0.8, 0.8, 0.8)
    if not SA_GlobalSight.Confirmed(record) then
        GameTooltip:AddLine("One report, not confirmed yet", 0.6, 0.65, 0.7)
    end
    if tier.tip >= 2 then
        local count = record.reporterCount or 1
        GameTooltip:AddLine("Seen by " .. count .. (count == 1 and " player" or " players"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(BAND_TEXT[record.band] or "", 0.6, 0.65, 0.7)
    end
    if tier.tip >= 3 then
        GameTooltip:AddLine("Via " .. (SOURCE_TEXT[record.source] or "?") .. ", first seen " .. M.Ago(now - record.firstSeen), 0.6, 0.65, 0.7)
    end
    GameTooltip:Show()
end

local function HideTip() GameTooltip:Hide() end

local function NewPulse(texture, scale, duration, fromAlpha)
    local pulse = texture:CreateAnimationGroup()
    pulse:SetLooping("REPEAT")
    local grow = pulse:CreateAnimation("Scale")
    if grow.SetScaleFrom then
        grow:SetScaleFrom(1, 1)
        grow:SetScaleTo(scale, scale)
    else
        grow:SetScale(scale, scale)
    end
    grow:SetDuration(duration)
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(fromAlpha)
    fade:SetToAlpha(0)
    fade:SetDuration(duration)
    return pulse
end

local function NewDot()
    local dot = CreateFrame("Button", nil, layer)
    dot.icon = dot:CreateTexture(nil, "OVERLAY")
    dot.icon:SetTexture(DOT_TEXTURE)
    dot.icon:SetAllPoints(dot)
    dot.ring = dot:CreateTexture(nil, "OVERLAY", nil, 1)
    dot.ring:SetTexture(DOT_TEXTURE)
    dot.ring:SetBlendMode("ADD")
    dot.ring:SetAllPoints(dot)
    dot.ring:Hide()
    dot.arrow = dot:CreateTexture(nil, "OVERLAY", nil, 2)
    dot.arrow:SetTexture(ARROW_TEXTURE)
    dot.arrow:SetVertexColor(1, 1, 1, 0.9)
    dot.arrow:Hide()
    dot.pulse = NewPulse(dot.ring, 2.4, 1.2, 0.9)
    dot:SetScript("OnEnter", ShowTip)
    dot:SetScript("OnLeave", HideTip)
    return dot
end

local function ShowRingTip(owner)
    local cluster = owner.cluster
    if not cluster then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local size = cluster.size
    if size == 1 then
        GameTooltip:AddLine(ZoneName(cluster.zones[1].mapID), 0.95, 0.85, 0.6)
    else
        GameTooltip:AddLine(size .. " zones", 0.95, 0.85, 0.6)
    end
    GameTooltip:AddLine(cluster.total .. (cluster.total == 1 and " enemy" or " enemies") .. " in the last 5 min", 1, 1, 1)
    if size > 1 then
        for i = 2, size do
            local zone, j = cluster.zones[i], i - 1
            while j >= 1 and cluster.zones[j].count < zone.count do
                cluster.zones[j + 1] = cluster.zones[j]
                j = j - 1
            end
            cluster.zones[j + 1] = zone
        end
        for i = 1, math.min(size, TIP_ZONES) do
            local zone = cluster.zones[i]
            GameTooltip:AddDoubleLine(ZoneName(zone.mapID), zone.count, 0.8, 0.8, 0.8, 1, 1, 1)
        end
        if size > TIP_ZONES then GameTooltip:AddLine("+ " .. (size - TIP_ZONES) .. " more", 0.55, 0.58, 0.64) end
    end
    for class, count in pairs(cluster.classes) do
        if count > 0 then
            local color = ClassColor(class)
            GameTooltip:AddLine(count .. " " .. (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class), color.r, color.g, color.b)
        end
    end
    if cluster.higher then GameTooltip:AddLine("Higher-level enemies present", 1, 0.48, 0.35) end
    GameTooltip:Show()
end

local function NewRing()
    local ring = CreateFrame("Button", nil, layer)
    ring:SetSize(RING_SIZE, RING_SIZE)
    ring.glow = ring:CreateTexture(nil, "BACKGROUND")
    ring.glow:SetTexture(DOT_TEXTURE)
    ring.glow:SetVertexColor(1, 0.3, 0.25, 1)
    ring.glow:SetBlendMode("ADD")
    ring.glow:SetAllPoints(ring)
    ring.glow:Hide()
    ring.disc = ring:CreateTexture(nil, "BORDER")
    ring.disc:SetTexture(DOT_TEXTURE)
    ring.disc:SetVertexColor(0.04, 0.05, 0.06, 0.9)
    ring.disc:SetAllPoints(ring)
    ring.pips = {}
    for i = 1, RING_PIPS do
        local pip = ring:CreateTexture(nil, "ARTWORK")
        pip:SetTexture(DOT_TEXTURE)
        pip:SetSize(RING_PIP, RING_PIP)
        local angle = (i - 1) / RING_PIPS * 2 * math.pi
        pip:SetPoint("CENTER", ring, "CENTER", math.sin(angle) * RING_RADIUS, math.cos(angle) * RING_RADIUS)
        ring.pips[i] = pip
    end
    ring.count = ring:CreateFontString(nil, "OVERLAY")
    ring.count:SetFontObject("GameFontHighlightSmall")
    ring.count:SetPoint("CENTER", ring, "CENTER", 0, 0)
    ring.tick = ring:CreateTexture(nil, "OVERLAY")
    ring.tick:SetTexture(DOT_TEXTURE)
    ring.tick:SetVertexColor(1, 0.2, 0.2, 1)
    ring.tick:SetSize(7, 7)
    ring.tick:SetPoint("CENTER", ring, "TOPRIGHT", -1, -1)
    ring.tick:Hide()
    ring.pulse = NewPulse(ring.glow, 1.7, 1.4, 0.8)
    ring:SetScript("OnEnter", ShowRingTip)
    ring:SetScript("OnLeave", HideTip)
    return ring
end

local function ByPip(a, b)
    if pipSource[a] ~= pipSource[b] then return pipSource[a] > pipSource[b] end
    return a < b
end

local function AssignPips(ring, classes, total)
    local n = 0
    for class, count in pairs(classes) do
        if count > 0 and n < RING_PIPS then
            n = n + 1
            pipClass[n] = class
        end
    end
    for i = n + 1, #pipClass do pipClass[i] = nil end
    pipSource = classes
    table.sort(pipClass, ByPip)
    local given = 0
    for i = 1, n do
        local exact = classes[pipClass[i]] / total * RING_PIPS
        pipExact[i] = exact
        pipGive[i] = math.max(1, math.floor(exact))
        given = given + pipGive[i]
    end
    while given ~= RING_PIPS do
        local best, bestGap
        for i = 1, n do
            local gap = pipExact[i] - pipGive[i]
            if given < RING_PIPS then
                if not bestGap or gap > bestGap then best, bestGap = i, gap end
            elseif pipGive[i] > 1 and (not bestGap or gap < bestGap) then
                best, bestGap = i, gap
            end
        end
        if not best then break end
        pipGive[best] = pipGive[best] + (given < RING_PIPS and 1 or -1)
        given = given + (given < RING_PIPS and 1 or -1)
    end
    local pip, index = 0, 1
    for i = 1, RING_PIPS do
        while index <= n and pip >= pipGive[index] do
            index, pip = index + 1, 0
        end
        local texture = ring.pips[i]
        local class = pipClass[index]
        if class then
            pip = pip + 1
            if texture.class ~= class then
                texture.class = class
                local color = ClassColor(class)
                texture:SetVertexColor(color.r, color.g, color.b, 1)
            end
            texture:Show()
        else
            texture.class = nil
            texture:Hide()
        end
    end
end

local function FillBar(segments, classes, total, length, anchor, x, y, vertical)
    local offset, used = 0, 0
    for class, count in pairs(classes) do
        if count > 0 and used < #segments then
            used = used + 1
            local segment = segments[used]
            local size = math.max(1, length * count / total)
            if segment.class ~= class then
                segment.class = class
                local color = ClassColor(class)
                segment:SetVertexColor(color.r, color.g, color.b, 1)
            end
            local px, py = x, y
            if vertical then py = y - offset else px = x + offset end
            if segment.x ~= px or segment.y ~= py then
                segment.x, segment.y = px, py
                segment:ClearAllPoints()
                segment:SetPoint("TOPLEFT", anchor, "TOPLEFT", px, py)
            end
            if segment.size ~= size then
                segment.size = size
                if vertical then segment:SetHeight(size) else segment:SetWidth(size) end
            end
            segment:Show()
            offset = offset + size
        end
    end
    for i = used + 1, #segments do segments[i]:Hide() end
end

local function ByRecent(a, b) return a.lastSeen > b.lastSeen end

local function SetText(fontString, text)
    if fontString.shownText ~= text then
        fontString.shownText = text
        fontString:SetText(text)
    end
end

local function HideFrom(list, first, shown)
    for i = first, shown do list[i]:Hide() end
end

local function Expanded()
    local profile = SoundAlerter.db1 and SoundAlerter.db1.profile
    return profile and profile.globalPanelExpanded and true or false
end

local function PanelText(parent, fontObject)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(fontObject)
    text:SetJustifyH("LEFT")
    if text.SetWordWrap then text:SetWordWrap(false) end
    return text
end

local function ShowRowTip(owner)
    local row = owner
    if not row.members or row.count == 0 then return end
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    local now = GetTime()
    for i = 1, row.count do
        local record = row.members[i]
        local color = ClassColor(record.class)
        local level = type(record.level) == "number" and record.level >= 0 and tostring(record.level) or "??"
        GameTooltip:AddDoubleLine(record.name .. "  " .. level, M.Short(now - record.lastSeen) .. " ago", color.r, color.g, color.b, 0.7, 0.7, 0.7)
        if record.reporterCount and record.reporterCount >= 2 then
            GameTooltip:AddLine("  seen by " .. record.reporterCount .. " players", 0.6, 0.65, 0.7)
        end
        if M.STEALTH[record.class] then GameTooltip:AddLine("  can stealth", 1, 0.96, 0.41) end
        if not SA_GlobalSight.Confirmed(record) then GameTooltip:AddLine("  one report, not confirmed yet", 0.6, 0.65, 0.7) end
    end
    GameTooltip:Show()
end

local function BuildPanel()
    local parent = WorldMapFrame.ScrollContainer or WorldMapFrame
    panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(STRIP_WIDTH, STRIP_HEIGHT)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -10)
    panel:SetFrameLevel(math.min(parent:GetFrameLevel() + 3100, 9000))
    panel:EnableMouse(true)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(FLAT)
    bg:SetVertexColor(0.04, 0.05, 0.06, 0.85)
    bg:SetAllPoints(panel)
    panel.edge = panel:CreateTexture(nil, "BORDER")
    panel.edge:SetTexture(FLAT)
    panel.edge:SetWidth(2)
    panel.edge:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.edge:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    local strip = CreateFrame("Frame", nil, panel)
    strip:SetAllPoints(panel)
    panel.strip = strip
    panel.stripDot = strip:CreateTexture(nil, "OVERLAY")
    panel.stripDot:SetTexture(DOT_TEXTURE)
    panel.stripDot:SetSize(8, 8)
    panel.stripDot:SetPoint("TOP", strip, "TOP", 1, -8)
    panel.stripCount = PanelText(strip, "GameFontHighlight")
    panel.stripCount:SetJustifyH("CENTER")
    panel.stripCount:SetPoint("TOP", panel.stripDot, "BOTTOM", 0, -3)
    panel.stripTrend = PanelText(strip, "GameFontHighlightSmall")
    panel.stripTrend:SetJustifyH("CENTER")
    panel.stripTrend:SetPoint("TOP", panel.stripCount, "BOTTOM", 0, -2)
    panel.stripBar = {}
    for i = 1, BAR_SEGMENTS do
        local segment = strip:CreateTexture(nil, "ARTWORK")
        segment:SetTexture(FLAT)
        segment:SetWidth(5)
        segment:Hide()
        panel.stripBar[i] = segment
    end
    local full = CreateFrame("Frame", nil, panel)
    full:SetAllPoints(panel)
    full:Hide()
    panel.full = full
    panel.head = CreateFrame("Button", nil, full)
    panel.head:SetPoint("TOPLEFT", full, "TOPLEFT", 2, 0)
    panel.head:SetPoint("TOPRIGHT", full, "TOPRIGHT", 0, 0)
    panel.head:SetHeight(18)
    panel.head:SetScript("OnClick", function()
        local profile = SoundAlerter.db1 and SoundAlerter.db1.profile
        if not profile then return end
        profile.globalPanelExpanded = not profile.globalPanelExpanded
        forceDraw = true
    end)
    panel.title = PanelText(panel.head, "GameFontNormalSmall")
    panel.title:SetPoint("LEFT", panel.head, "LEFT", 8, -1)
    panel.title:SetPoint("RIGHT", panel.head, "RIGHT", -44, -1)
    panel.toggle = PanelText(panel.head, "GameFontDisableSmall")
    panel.toggle:SetPoint("RIGHT", panel.head, "RIGHT", -8, -1)
    panel.verdict = PanelText(full, "GameFontNormal")
    panel.verdict:SetPoint("TOPLEFT", full, "TOPLEFT", 8, -20)
    panel.count = PanelText(full, "GameFontHighlightLarge")
    panel.count:SetPoint("LEFT", panel.verdict, "RIGHT", 6, 0)
    panel.trend = PanelText(full, "GameFontHighlightSmall")
    panel.trend:SetPoint("LEFT", panel.count, "RIGHT", 6, 0)
    panel.facts = PanelText(full, "GameFontDisableSmall")
    panel.facts:SetPoint("TOPLEFT", full, "TOPLEFT", 8, -40)
    panel.facts:SetWidth(PANEL_WIDTH - 16)
    panel.bar = {}
    for i = 1, BAR_SEGMENTS do
        local segment = full:CreateTexture(nil, "ARTWORK")
        segment:SetTexture(FLAT)
        segment:SetHeight(5)
        segment:Hide()
        panel.bar[i] = segment
    end
    panel.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, full)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", full, "TOPLEFT", 2, -ROWS_TOP - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", full, "RIGHT", 0, 0)
        row.name = PanelText(row, "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.ago = PanelText(row, "GameFontDisableSmall")
        row.ago:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.ago:SetJustifyH("RIGHT")
        row.dist = PanelText(row, "GameFontHighlightSmall")
        row.dist:SetPoint("RIGHT", row, "RIGHT", -54, 0)
        row.dist:SetJustifyH("RIGHT")
        row.level = PanelText(row, "GameFontHighlightSmall")
        row.level:SetJustifyH("RIGHT")
        row.arrow = row:CreateTexture(nil, "OVERLAY")
        row.arrow:SetTexture(ARROW_TEXTURE)
        row.arrow:SetSize(9, 9)
        row.arrow:SetVertexColor(0.85, 0.88, 0.92, 1)
        row.arrow:SetPoint("RIGHT", row.level, "LEFT", -4, 0)
        row.name:SetPoint("RIGHT", row.arrow, "LEFT", -4, 0)
        row.members = {}
        row.count = 0
        row:SetScript("OnEnter", ShowRowTip)
        row:SetScript("OnLeave", HideTip)
        row:Hide()
        panel.rows[i] = row
    end
    panel:Hide()
end

local function PlayerSpot(zone, current)
    if not C_Map or not C_Map.GetBestMapForUnit then return nil end
    if not current and C_Map.GetBestMapForUnit("player") ~= zone then return nil end
    local ok, position = pcall(C_Map.GetPlayerMapPosition, zone, "player")
    if not ok or not position then return nil end
    local x, y = position:GetXY()
    if not x or not y then return nil end
    local size = worldSizes[zone]
    if size == nil then
        local width, height
        if C_Map.GetMapWorldSize then width, height = C_Map.GetMapWorldSize(zone) end
        size = (width and width > 0 and height and height > 0) and { width, height } or false
        worldSizes[zone] = size
    end
    if not size then return nil end
    return x, y, size[1], size[2]
end

local function Offset(record, px, py, width, height)
    return ((record.cx + 0.5) / 100 - px) * width, ((record.cy + 0.5) / 100 - py) * height
end

local function Heading(record, width, height)
    if record.prevMapID ~= record.mapID or not record.prevCx then return nil end
    local dx, dy = (record.cx - record.prevCx) * (width or 1.5), (record.cy - record.prevCy) * (height or 1)
    if dx == 0 and dy == 0 then return nil end
    return M.Bearing(dx, dy)
end

local function SetArrow(texture, bearing)
    if not bearing then
        texture:Hide()
        return
    end
    if texture.bearing ~= bearing then
        texture.bearing = bearing
        texture:SetRotation(-bearing)
    end
    texture:Show()
end

local function ByGroup(a, b)
    local sa, sb = #groups[a] >= 2, #groups[b] >= 2
    if sa ~= sb then return sa end
    local da, db = groupDistance[a], groupDistance[b]
    if da and db and da ~= db then return da < db end
    return groups[a][1].lastSeen > groups[b][1].lastSeen
end

local function Swatches(group, size)
    local count = math.min(size, 6)
    for i = 1, count do
        local color = ClassColor(group[i].class)
        swatchParts[i] = string.format("|T%s:8:8:0:0:8:8:0:8:0:8:%d:%d:%d|t", FLAT, color.r * 255, color.g * 255, color.b * 255)
    end
    for i = count + 1, #swatchParts do swatchParts[i] = nil end
    return table.concat(swatchParts, "")
end

local function Layout()
    local width = panelOpen and PANEL_WIDTH or STRIP_WIDTH
    if panel.shownWidth ~= width then
        panel.shownWidth = width
        panel:SetWidth(width)
        panel.full:SetShown(panelOpen)
        panel.strip:SetShown(not panelOpen)
    end
    local height = panelOpen and panel.fullHeight or STRIP_HEIGHT
    if panel.shownHeight ~= height then
        panel.shownHeight = height
        panel:SetHeight(height)
    end
end

local function DrawPanel(store, zone, now)
    if not panel then BuildPanel() end
    panelZone = zone
    local expanded = Expanded()
    for class in pairs(mix) do mix[class] = 0 end
    for i = 1, #ordered do ordered[i] = nil end
    local count, previous, stealth, higher, confirmed = 0, 0, 0, 0, 0
    local mine = UnitLevel and UnitLevel("player")
    for _, record in pairs(store.records) do
        if record.mapID == zone then
            local age = now - record.lastSeen
            if age <= WINDOW then
                count = count + 1
                ordered[count] = record
                mix[record.class] = (mix[record.class] or 0) + 1
                if M.STEALTH[record.class] then stealth = stealth + 1 end
                if M.Higher(record.level, mine) then higher = higher + 1 end
                if SA_GlobalSight.Confirmed(record) then confirmed = confirmed + 1 end
            end
            if record.firstSeen <= now - WINDOW and age <= WINDOW * 2 then previous = previous + 1 end
        end
    end
    table.sort(ordered, ByRecent)
    local grouped = math.min(count, GROUP_LIMIT)
    local total = M.Group(ordered, grouped, groupOf, groups)
    local px, py, width, height = PlayerSpot(zone)
    local nearest, nearestDir, nearGroup
    for g = 1, total do
        local members = groups[g]
        local lead = members[1]
        local distance
        if px then
            local dx, dy = Offset(lead, px, py, width, height)
            distance = math.sqrt(dx * dx + dy * dy)
            if not nearest or distance < nearest then nearest, nearestDir = distance, M.Dir(dx, dy) end
            local sure = 0
            for k = 1, #members do
                if SA_GlobalSight.Confirmed(members[k]) then sure = sure + 1 end
            end
            if sure >= 3 and distance <= M.HOT_RANGE and (not nearGroup or sure > nearGroup) then nearGroup = sure end
        end
        groupDistance[g] = distance or false
    end
    local verdict = M.Verdict(count, nearGroup, confirmed)
    local color = VERDICT_COLOR[verdict]
    local name = ZoneName(zone)
    SetText(panel.title, (name ~= "" and name or "This zone") .. " · last 5 min")
    SetText(panel.toggle, expanded and "less" or "more")
    SetText(panel.verdict, verdict:upper())
    panel.verdict:SetTextColor(color[1], color[2], color[3])
    if panel.verdictShown ~= verdict then
        panel.verdictShown = verdict
        panel.edge:SetVertexColor(color[1], color[2], color[3], 1)
        panel.stripDot:SetVertexColor(color[1], color[2], color[3], 1)
    end
    SetText(panel.stripCount, tostring(count))
    SetText(panel.count, count == 1 and "1 enemy" or count .. " enemies")
    local change = count - previous
    if change > 0 then
        SetText(panel.trend, "+" .. change)
        panel.trend:SetTextColor(1, 0.48, 0.35)
        SetText(panel.stripTrend, "+" .. change)
        panel.stripTrend:SetTextColor(1, 0.48, 0.35)
    elseif change < 0 then
        SetText(panel.trend, tostring(change))
        panel.trend:SetTextColor(0.5, 0.83, 0.54)
        SetText(panel.stripTrend, tostring(change))
        panel.stripTrend:SetTextColor(0.5, 0.83, 0.54)
    else
        SetText(panel.trend, "=")
        panel.trend:SetTextColor(0.55, 0.58, 0.64)
        SetText(panel.stripTrend, "")
    end
    local facts, n = factParts, 0
    if nearest then
        n = n + 1
        facts[n] = "Nearest ~" .. M.Yards(nearest) .. " yd " .. nearestDir
    end
    if stealth > 0 then
        n = n + 1
        facts[n] = stealth .. " can stealth"
    end
    if higher > 0 then
        n = n + 1
        facts[n] = higher .. " higher level"
    end
    local watchers = store.watcherCounts[zone] or 0
    n = n + 1
    facts[n] = watchers .. " watching"
    for i = n + 1, #facts do facts[i] = nil end
    SetText(panel.facts, table.concat(facts, " · "))
    if count > 0 then
        FillBar(panel.bar, mix, count, PANEL_WIDTH - 20, panel.full, 10, -54)
        FillBar(panel.stripBar, mix, count, STRIP_HEIGHT - 72, panel.strip, 9, -62, true)
    else
        for i = 1, #panel.bar do panel.bar[i]:Hide() end
        for i = 1, #panel.stripBar do panel.stripBar[i]:Hide() end
    end
    for g = 1, total do order[g] = g end
    for g = total + 1, #order do order[g] = nil end
    table.sort(order, ByGroup)
    local limit = expanded and MAX_ROWS or COMPACT_ROWS
    local rows = math.min(total, limit)
    local extra = total - rows
    if extra > 0 then rows = rows - 1 end
    local shownRows = 0
    for i = 1, MAX_ROWS do
        local row = panel.rows[i]
        if i <= rows then
            local members = groups[order[i]]
            local size = #members
            local lead = members[1]
            row.count = size
            for k = 1, size do row.members[k] = members[k] end
            for k = size + 1, #row.members do row.members[k] = nil end
            local leadColor = ClassColor(lead.class)
            if size >= 2 then
                SetText(row.name, "Group of " .. size .. " " .. Swatches(members, size))
                row.name:SetTextColor(1, 0.69, 0.63)
            else
                SetText(row.name, lead.name)
                row.name:SetTextColor(leadColor.r, leadColor.g, leadColor.b)
            end
            local level = lead.level
            for k = 2, size do
                local other = members[k].level
                if type(other) ~= "number" or other < 0 then level = -1 elseif type(level) == "number" and level >= 0 and other > level then level = other end
            end
            if type(level) == "number" and level >= 0 then
                SetText(row.level, tostring(level))
            else
                SetText(row.level, "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:10:10|t")
            end
            row.level:SetTextColor(M.LevelColor(level, mine))
            local distance = groupDistance[order[i]]
            local seen = size == 1 and lead.reporterCount and lead.reporterCount >= 2 and (" (" .. lead.reporterCount .. ")") or ""
            if expanded and distance then
                local dx, dy = Offset(lead, px, py, width, height)
                SetText(row.dist, "~" .. M.Yards(distance) .. " yd " .. M.Dir(dx, dy) .. seen)
            else
                SetText(row.dist, seen)
            end
            SetText(row.ago, M.Short(now - lead.lastSeen))
            local sure = false
            for k = 1, size do
                if SA_GlobalSight.Confirmed(members[k]) then sure = true break end
            end
            row:SetAlpha(sure and 1 or 0.55)
            local gap = row.dist.shownText == "" and 0 or -6
            if row.gap ~= gap then
                row.gap = gap
                row.level:ClearAllPoints()
                row.level:SetPoint("RIGHT", row.dist, "LEFT", gap, 0)
            end
            SetArrow(row.arrow, Heading(lead, width, height))
            row:Show()
            shownRows = shownRows + 1
        elseif i == rows + 1 and extra > 0 then
            row.count = 0
            SetText(row.name, "+ " .. (extra + 1) .. " more")
            row.name:SetTextColor(0.55, 0.58, 0.64)
            SetText(row.level, "")
            SetText(row.dist, "")
            SetText(row.ago, "")
            row.arrow:Hide()
            row:SetAlpha(1)
            row:Show()
            shownRows = shownRows + 1
        else
            row.count = 0
            row:Hide()
        end
    end
    local panelHeight = ROWS_TOP + math.max(1, shownRows) * ROW_HEIGHT + 6
    if count == 0 then panelHeight = ROWS_TOP + 4 end
    panel.fullHeight = panelHeight
    Layout()
    panel:Show()
end

local function DrawDots(store, host, canvas, now, tier, stitched)
    local count = 0
    for _, record in pairs(store.records) do
        if now - record.lastSeen < M.GONE_AGE and (stitched or record.mapID == host) then
            count = count + 1
            ordered[count] = record
        end
    end
    for i = count + 1, #ordered do ordered[i] = nil end
    if count > tier.cap then table.sort(ordered, ByRecent) end
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    local k = canvas:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local size = DOT_SIZE / (k > 0.01 and k or 1)
    local shown = 0
    local limit = math.min(count, tier.cap)
    local key = stitched and -host or host
    for i = 1, limit do
        local record = ordered[i]
        local x, y
        if record.projHost == key and record.projMap == record.mapID and record.projCx == record.cx and record.projCy == record.cy then
            x, y = record.projX, record.projY
        else
            x, y = Project(record.mapID, (record.cx + 0.5) / 100, (record.cy + 0.5) / 100, host, stitched)
            record.projHost, record.projMap, record.projCx, record.projCy = key, record.mapID, record.cx, record.cy
            record.projX, record.projY = x or false, y or false
        end
        if x and y then
            shown = shown + 1
            local dot = dots[shown]
            if not dot then
                dot = NewDot()
                dots[shown] = dot
            end
            dot.record = record
            if dot.size ~= size then
                dot.size = size
                dot:SetSize(size, size)
            end
            local px, py = x * width, -y * height
            if dot.px ~= px or dot.py ~= py then
                dot.px, dot.py = px, py
                dot:ClearAllPoints()
                dot:SetPoint("CENTER", layer, "TOPLEFT", px, py)
            end
            if dot.class ~= record.class then
                dot.class = record.class
                local color = ClassColor(record.class)
                dot.icon:SetVertexColor(color.r, color.g, color.b, 1)
                dot.ring:SetVertexColor(color.r, color.g, color.b, 1)
            end
            if dot.arrowSize ~= size then
                dot.arrowSize = size
                dot.arrow:SetSize(size * 1.2, size * 1.2)
            end
            local bearing = Heading(record)
            if bearing and (dot.arrowBearing ~= bearing or dot.arrowAt ~= size) then
                dot.arrowBearing, dot.arrowAt = bearing, size
                dot.arrow:ClearAllPoints()
                dot.arrow:SetPoint("CENTER", dot, "CENTER", math.sin(bearing) * size, math.cos(bearing) * size)
            end
            SetArrow(dot.arrow, bearing)
            local alpha = M.Alpha(now - record.lastSeen, tier.step) * (SA_GlobalSight.Confirmed(record) and 1 or UNCONFIRMED_ALPHA)
            if dot.alpha ~= alpha then
                dot.alpha = alpha
                dot:SetAlpha(alpha)
            end
            if tier.pulse and now - record.lastSeen < FRESH then
                dot.ring:Show()
                if not dot.pulse:IsPlaying() then dot.pulse:Play() end
            elseif dot.ring:IsShown() then
                dot.pulse:Stop()
                dot.ring:Hide()
            end
            dot:Show()
        end
    end
    HideFrom(dots, shown + 1, dotsShown)
    dotsShown = shown
end

local function Closest(count)
    local limit = MERGE_DISTANCE * MERGE_DISTANCE
    for a = 1, count - 1 do
        local first = clusters[a]
        for b = a + 1, count do
            local second = clusters[b]
            local dx, dy = first.x - second.x, first.y - second.y
            if dx * dx + dy * dy < limit then return a, b end
        end
    end
end

local function Absorb(a, b, count)
    local first, second = clusters[a], clusters[b]
    local weight = first.weight + second.weight
    first.x = (first.x * first.weight + second.x * second.weight) / weight
    first.y = (first.y * first.weight + second.y * second.weight) / weight
    first.weight = weight
    for i = 1, second.size do
        first.size = first.size + 1
        first.zones[first.size] = second.zones[i]
    end
    clusters[b], clusters[count] = clusters[count], second
end

local function DrawRings(store, host, canvas, now, tier, stitched)
    for _, zone in pairs(zones) do
        zone.count, zone.higher = 0, false
        for class in pairs(zone.classes) do zone.classes[class] = 0 end
    end
    local mine = UnitLevel and UnitLevel("player")
    for _, record in pairs(store.records) do
        if now - record.lastSeen <= WINDOW then
            local zone = zones[record.mapID]
            if not zone then
                zone = { mapID = record.mapID, count = 0, higher = false, classes = {} }
                zones[record.mapID] = zone
            end
            zone.count = zone.count + 1
            zone.classes[record.class] = (zone.classes[record.class] or 0) + 1
            if not zone.higher and M.Higher(record.level, mine) then zone.higher = true end
        end
    end
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    local k = canvas:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if k <= 0.01 then k = 1 end
    local count = 0
    for mapID, zone in pairs(zones) do
        if zone.count > 0 then
            local x, y = Centre(mapID, host, stitched)
            if x and y then
                count = count + 1
                local cluster = clusters[count]
                if not cluster then
                    cluster = { zones = {}, classes = {} }
                    clusters[count] = cluster
                end
                cluster.x, cluster.y, cluster.weight, cluster.size = x * width * k, -y * height * k, zone.count, 1
                cluster.zones[1] = zone
            end
        end
    end
    local a, b = Closest(count)
    while a do
        Absorb(a, b, count)
        count = count - 1
        a, b = Closest(count)
    end
    for i = 1, count do
        local cluster = clusters[i]
        cluster.total, cluster.higher = 0, false
        for class in pairs(cluster.classes) do cluster.classes[class] = 0 end
        for j = 1, cluster.size do
            local zone = cluster.zones[j]
            cluster.total = cluster.total + zone.count
            if zone.higher then cluster.higher = true end
            for class, number in pairs(zone.classes) do
                if number > 0 then cluster.classes[class] = (cluster.classes[class] or 0) + number end
            end
        end
        local ring = rings[i]
        if not ring then
            ring = NewRing()
            rings[i] = ring
        end
        ring.cluster = cluster
        if ring.k ~= k then
            ring.k = k
            ring:SetScale(1 / k)
        end
        if ring.px ~= cluster.x or ring.py ~= cluster.y then
            ring.px, ring.py = cluster.x, cluster.y
            ring:ClearAllPoints()
            ring:SetPoint("CENTER", layer, "TOPLEFT", cluster.x, cluster.y)
        end
        AssignPips(ring, cluster.classes, cluster.total)
        if ring.shownTotal ~= cluster.total then
            ring.shownTotal = cluster.total
            ring.count:SetText(cluster.total > 99 and "99+" or cluster.total)
        end
        ring.tick:SetShown(cluster.higher)
        if tier.ringPulse and cluster.total >= HOT then
            ring.glow:Show()
            if not ring.pulse:IsPlaying() then ring.pulse:Play() end
        elseif ring.glow:IsShown() then
            ring.pulse:Stop()
            ring.glow:Hide()
        end
        ring:Show()
    end
    HideFrom(rings, count + 1, ringsShown)
    ringsShown = count
end

local function HideAll()
    HideFrom(dots, 1, dotsShown)
    HideFrom(rings, 1, ringsShown)
    dotsShown, ringsShown = 0, 0
    if panel then panel:Hide() end
end

local function ClearDirty(store)
    local dirty = store.dirty
    for key in pairs(dirty) do dirty[key] = nil end
end

local function Draw()
    local store = SoundAlerter:GlobalSightStore()
    local canvas, host = CanvasAndHost()
    if not store or not canvas then
        HideAll()
        return
    end
    local now = GetTime()
    if tier.hideMoving and now < quietUntil then
        HideAll()
        return
    end
    lastDraw, nextRefresh, nextPanel, forceDraw = now, now + tier.refresh, now + PANEL_EVERY, false
    ClearDirty(store)
    local stitched = Stitched()
    local zoom, u, v
    if stitched then u, v, zoom = OpenMapAPI.GetView() end
    local info = not stitched and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(host)
    mode = M.Mode(mode, stitched, zoom, info and info.mapType)
    if mode == "dots" then
        HideFrom(rings, 1, ringsShown)
        ringsShown = 0
        DrawDots(store, host, canvas, now, tier, stitched)
        local zone = host
        if stitched and u and v and OpenMapAPI.MapAt then
            local at = OpenMapAPI.MapAt(u, v)
            if type(at) == "number" then zone = at end
        end
        DrawPanel(store, zone, now)
    else
        HideFrom(dots, 1, dotsShown)
        dotsShown = 0
        if panel then panel:Hide() end
        DrawRings(store, host, canvas, now, tier, stitched)
    end
end

local function OnUpdate(_, elapsed)
    sinceCheck = sinceCheck + elapsed
    if sinceCheck < CHECK_EVERY then return end
    sinceCheck = 0
    local canvas, host = CanvasAndHost()
    if not canvas then return end
    local now = GetTime()
    local scale = canvas:GetEffectiveScale()
    if scale ~= scaleShown or host ~= hostShown then
        scaleShown, hostShown = scale, host
        if tier.hideMoving then
            quietUntil = now + QUIET_AFTER_MOVE
            HideAll()
        end
        forceDraw = true
    end
    if tier.hideMoving and now < quietUntil then return end
    local store = SoundAlerter:GlobalSightStore()
    if not store then return end
    if panel and panel:IsShown() then
        local over = panel:IsMouseOver()
        if over ~= panelOpen then
            panelOpen = over
            Layout()
        end
    end
    if forceDraw or now >= nextRefresh or (next(store.dirty) ~= nil and now - lastDraw >= tier.redraw) then
        Draw()
    elseif mode == "dots" and now >= nextPanel and panelZone then
        nextPanel = now + PANEL_EVERY
        DrawPanel(store, panelZone, now)
    end
end

local function Attach()
    if attached or not WorldMapFrame then return end
    local canvas = WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas() or (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
    if not canvas then return end
    attached = true
    layer = CreateFrame("Frame", nil, canvas)
    layer:SetAllPoints(canvas)
    layer:SetFrameLevel(LayerLevel(canvas))
    layer:SetScript("OnShow", function(self)
        self:SetFrameLevel(LayerLevel(canvas))
        scaleShown, hostShown, forceDraw, sinceCheck = nil, nil, true, CHECK_EVERY
    end)
    layer:SetScript("OnUpdate", OnUpdate)
    if OpenMapAPI and OpenMapAPI.RegisterCallback then
        local owner = {}
        pcall(OpenMapAPI.RegisterCallback, owner, "OpenMap_ViewChanged", function()
            if layer:IsShown() and tier.hideMoving then
                quietUntil = GetTime() + QUIET_AFTER_MOVE
                HideAll()
            end
        end)
        pcall(OpenMapAPI.RegisterCallback, owner, "OpenMap_StitchedChanged", function()
            centreHost = nil
            forceDraw = true
        end)
    end
end

local PIN_SIZE, RIM_SIZE, RIM_ALPHA = 8, 6, 0.55
local GATHER_EVERY = 1
local pinFrame
local pins, pinsShown = {}, 0
local nearby, nearbyCount, gatherZone, nextGather, sincePin = {}, 0, nil, 0, 0

local function NewPin()
    local pin = CreateFrame("Button", nil, pinFrame)
    pin.icon = pin:CreateTexture(nil, "OVERLAY")
    pin.icon:SetTexture(DOT_TEXTURE)
    pin.icon:SetAllPoints(pin)
    pin:SetScript("OnEnter", ShowTip)
    pin:SetScript("OnLeave", HideTip)
    return pin
end

local function HidePins()
    HideFrom(pins, 1, pinsShown)
    pinsShown = 0
end

local function PlayerZone()
    if not C_Map or not C_Map.GetBestMapForUnit then return nil end
    local ok, zone = pcall(C_Map.GetBestMapForUnit, "player")
    zone = ok and SA_COMPAT.Plain(zone) or nil
    return type(zone) == "number" and zone or nil
end

local function GatherNearby(store, zone, now)
    nextGather, gatherZone = now + GATHER_EVERY, zone
    local count = 0
    for _, record in pairs(store.records) do
        if record.mapID == zone and now - record.lastSeen < M.GONE_AGE then
            count = count + 1
            nearby[count] = record
        end
    end
    for index = count + 1, nearbyCount do nearby[index] = nil end
    nearbyCount = count
    if count > 1 then table.sort(nearby, ByRecent) end
end

local function PlacePin(pin, size, color, alpha, x, y)
    if pin.lastSize ~= size then
        pin.lastSize = size
        pin:SetSize(size, size)
    end
    if pin.lastColor ~= color then
        pin.lastColor = color
        pin.icon:SetVertexColor(color.r, color.g, color.b)
    end
    if pin.lastAlpha ~= alpha then
        pin.lastAlpha = alpha
        pin:SetAlpha(alpha)
    end
    if pin.lastX ~= x or pin.lastY ~= y then
        pin.lastX, pin.lastY = x, y
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", pinFrame, "CENTER", x, y)
    end
    pin:Show()
end

local function DrawPins()
    local store = SoundAlerter:GlobalSightStore()
    if not store or store.count == 0 or SA_COMPAT.Plain(IsInInstance()) then
        HidePins()
        return
    end
    local zone = PlayerZone()
    if not zone then
        HidePins()
        return
    end
    local now = GetTime()
    if zone ~= gatherZone or now >= nextGather then GatherNearby(store, zone, now) end
    if nearbyCount == 0 then
        HidePins()
        return
    end
    local px, py, width, height = PlayerSpot(zone, true)
    local radius = SoundAlerter.MinimapRadius and SoundAlerter.MinimapRadius(zone)
    if not px or not radius then
        HidePins()
        return
    end
    local facing
    if GetCVar("rotateMinimap") == "1" and GetPlayerFacing then
        facing = SA_COMPAT.Plain(GetPlayerFacing())
        if type(facing) ~= "number" then facing = nil end
    end
    local half = Minimap:GetWidth() / 2
    local shown = 0
    for index = 1, nearbyCount do
        if shown >= tier.pins then break end
        local record = nearby[index]
        local x, y, rim
        if record.mapID == zone and store.records[record.guid] == record then
            local dx, dy = Offset(record, px, py, width, height)
            x, y, rim = M.MinimapSpot(dx, -dy, radius, facing)
        end
        if x then
            shown = shown + 1
            local pin = pins[shown]
            if not pin then
                pin = NewPin()
                pins[shown] = pin
            end
            pin.record = record
            local alpha = M.Alpha(now - record.lastSeen, tier.step)
            if not SA_GlobalSight.Confirmed(record) then alpha = alpha * UNCONFIRMED_ALPHA end
            if rim then alpha = alpha * RIM_ALPHA end
            PlacePin(pin, rim and RIM_SIZE or PIN_SIZE, ClassColor(record.class), alpha, x * half, y * half)
        end
    end
    HideFrom(pins, shown + 1, pinsShown)
    pinsShown = shown
end

local function AttachPins()
    if pinFrame or not Minimap then return end
    pinFrame = CreateFrame("Frame", nil, Minimap)
    pinFrame:SetAllPoints(Minimap)
    pinFrame:SetFrameLevel(Minimap:GetFrameLevel() + 3)
    pinFrame:SetScript("OnUpdate", function(_, elapsed)
        sincePin = sincePin + elapsed
        if sincePin < tier.pinEvery then return end
        sincePin = 0
        DrawPins()
    end)
    pinFrame:SetScript("OnHide", HidePins)
end

function SoundAlerter:UpdateGlobalMap()
    local profile = self.db1 and self.db1.profile
    local on = profile and profile.globalSightings and self:GlobalSightStore() ~= nil
    tier = M.Tier(profile and profile.globalQuality)
    forceDraw = true
    if on then
        Attach()
        if layer then
            layer:Show()
        end
    elseif layer then
        HideAll()
        layer:Hide()
    end
    local wantPins = on and profile.globalMinimap ~= false
    if wantPins then
        AttachPins()
        if pinFrame then
            nextGather, sincePin = 0, tier.pinEvery
            pinFrame:Show()
        end
    elseif pinFrame then
        HidePins()
        pinFrame:Hide()
    end
end
end
