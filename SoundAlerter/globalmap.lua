do
SA_GlobalMap = {}

local ENTER_ZOOM, LEAVE_ZOOM = 3, 2.6
local FULL_AGE, GONE_AGE = 120, 600
local ZONE_TYPE = 3

SA_GlobalMap.GONE_AGE = GONE_AGE
SA_GlobalMap.TIERS = {
    low = { redraw = 3, refresh = 15, cap = 50, step = true, pulse = false, tip = 1, badge = 1, hideMoving = true },
    normal = { redraw = 1, refresh = 10, cap = 150, step = false, pulse = false, tip = 2, badge = 2, hideMoving = false },
    high = { redraw = 1, refresh = 10, cap = 100000, step = false, pulse = true, tip = 3, badge = 3, hideMoving = false },
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
        if previous == "dots" then return zoom >= LEAVE_ZOOM and "dots" or "badges" end
        return zoom >= ENTER_ZOOM and "dots" or "badges"
    end
    if type(mapType) == "number" and mapType >= ZONE_TYPE then return "dots" end
    return "badges"
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

function SA_GlobalMap.Trend(records, zone, now, window)
    local current, previous = 0, 0
    for _, record in pairs(records) do
        if record.mapID == zone then
            if now - record.lastSeen <= window then current = current + 1 end
            if record.firstSeen <= now - window and now - record.lastSeen <= window * 2 then previous = previous + 1 end
        end
    end
    return current, previous
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
local PANEL_WIDTH = 230
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
local dots, badges = {}, {}
local dotsShown, badgesShown = 0, 0
local mode = "badges"
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
    local pulse = dot.ring:CreateAnimationGroup()
    pulse:SetLooping("REPEAT")
    local grow = pulse:CreateAnimation("Scale")
    if grow.SetScaleFrom then
        grow:SetScaleFrom(1, 1)
        grow:SetScaleTo(2.4, 2.4)
    else
        grow:SetScale(2.4, 2.4)
    end
    grow:SetDuration(1.2)
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.9)
    fade:SetToAlpha(0)
    fade:SetDuration(1.2)
    dot.pulse = pulse
    dot:SetScript("OnEnter", ShowTip)
    dot:SetScript("OnLeave", HideTip)
    return dot
end

local function NewBadge()
    local badge = CreateFrame("Button", nil, layer)
    badge:SetSize(78, 40)
    badge.bg = badge:CreateTexture(nil, "BACKGROUND")
    badge.bg:SetTexture(FLAT)
    badge.bg:SetVertexColor(0.04, 0.05, 0.06, 0.85)
    badge.bg:SetAllPoints(badge)
    badge.glow = badge:CreateTexture(nil, "BORDER")
    badge.glow:SetTexture(FLAT)
    badge.glow:SetVertexColor(1, 0.25, 0.25, 0.35)
    badge.glow:SetPoint("TOPLEFT", badge, "TOPLEFT", -2, 2)
    badge.glow:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", 2, -2)
    badge.name = badge:CreateFontString(nil, "OVERLAY")
    badge.name:SetFontObject("GameFontNormalSmall")
    badge.name:SetPoint("TOP", badge, "TOP", 0, -3)
    badge.name:SetWidth(74)
    badge.name:SetWordWrap(false)
    badge.count = badge:CreateFontString(nil, "OVERLAY")
    badge.count:SetFontObject("GameFontHighlightLarge")
    badge.count:SetPoint("TOP", badge.name, "BOTTOM", 0, -1)
    badge.top = badge:CreateFontString(nil, "OVERLAY")
    badge.top:SetFontObject("GameFontHighlightSmall")
    badge.top:SetPoint("TOP", badge.count, "BOTTOM", 0, -1)
    badge.bar = {}
    for i = 1, BAR_SEGMENTS do
        local segment = badge:CreateTexture(nil, "ARTWORK")
        segment:SetTexture(FLAT)
        segment:SetHeight(3)
        segment:Hide()
        badge.bar[i] = segment
    end
    badge:SetScript("OnEnter", function(self)
        local zone = self.zone
        if not zone then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.name:GetText() or "", 0.95, 0.85, 0.6)
        GameTooltip:AddLine(zone.count .. " enemies in the last 5 min", 1, 1, 1)
        for class, count in pairs(zone.classes) do
            if count > 0 then
                local color = ClassColor(class)
                GameTooltip:AddLine(count .. " " .. (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class), color.r, color.g, color.b)
            end
        end
        GameTooltip:Show()
    end)
    badge:SetScript("OnLeave", HideTip)
    return badge
end

local function FillBar(segments, classes, total, left, right, anchor, y)
    local width = right - left
    local x, used = left, 0
    for class, count in pairs(classes) do
        if count > 0 and used < #segments then
            used = used + 1
            local segment = segments[used]
            local w = math.max(1, width * count / total)
            if segment.class ~= class then
                segment.class = class
                local color = ClassColor(class)
                segment:SetVertexColor(color.r, color.g, color.b, 1)
            end
            if segment.x ~= x or segment.y ~= y then
                segment.x, segment.y = x, y
                segment:ClearAllPoints()
                segment:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)
            end
            if segment.w ~= w then
                segment.w = w
                segment:SetWidth(w)
            end
            segment:Show()
            x = x + w
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
    panel:SetSize(PANEL_WIDTH, 120)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -10)
    panel:SetFrameLevel(math.min(parent:GetFrameLevel() + 3100, 9000))
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(FLAT)
    bg:SetVertexColor(0.04, 0.05, 0.06, 0.85)
    bg:SetAllPoints(panel)
    panel.head = CreateFrame("Button", nil, panel)
    panel.head:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.head:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
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
    panel.verdict = PanelText(panel, "GameFontNormal")
    panel.verdict:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -20)
    panel.count = PanelText(panel, "GameFontHighlightLarge")
    panel.count:SetPoint("LEFT", panel.verdict, "RIGHT", 6, 0)
    panel.trend = PanelText(panel, "GameFontHighlightSmall")
    panel.trend:SetPoint("LEFT", panel.count, "RIGHT", 6, 0)
    panel.facts = PanelText(panel, "GameFontDisableSmall")
    panel.facts:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -40)
    panel.facts:SetWidth(PANEL_WIDTH - 16)
    panel.bar = {}
    for i = 1, BAR_SEGMENTS do
        local segment = panel:CreateTexture(nil, "ARTWORK")
        segment:SetTexture(FLAT)
        segment:SetHeight(5)
        segment:Hide()
        panel.bar[i] = segment
    end
    panel.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, panel)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -ROWS_TOP - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
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

local function PlayerSpot(zone)
    if not C_Map or not C_Map.GetBestMapForUnit then return nil end
    if C_Map.GetBestMapForUnit("player") ~= zone then return nil end
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

local function DrawPanel(store, zone, now)
    if not panel then BuildPanel() end
    panelZone = zone
    local expanded = Expanded()
    for class in pairs(mix) do mix[class] = 0 end
    for i = 1, #ordered do ordered[i] = nil end
    local count, stealth, higher, confirmed = 0, 0, 0, 0
    local mine = UnitLevel and UnitLevel("player")
    for _, record in pairs(store.records) do
        if record.mapID == zone and now - record.lastSeen <= WINDOW then
            count = count + 1
            ordered[count] = record
            mix[record.class] = (mix[record.class] or 0) + 1
            if M.STEALTH[record.class] then stealth = stealth + 1 end
            if M.Higher(record.level, mine) then higher = higher + 1 end
            if SA_GlobalSight.Confirmed(record) then confirmed = confirmed + 1 end
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
    local _, previous = M.Trend(store.records, zone, now, WINDOW)
    local verdict = M.Verdict(count, nearGroup, confirmed)
    local color = VERDICT_COLOR[verdict]
    local name = ZoneName(zone)
    SetText(panel.title, (name ~= "" and name or "This zone") .. " · last 5 min")
    SetText(panel.toggle, expanded and "less" or "more")
    SetText(panel.verdict, verdict:upper())
    panel.verdict:SetTextColor(color[1], color[2], color[3])
    SetText(panel.count, count == 1 and "1 enemy" or count .. " enemies")
    local change = count - previous
    if change > 0 then
        SetText(panel.trend, "+" .. change)
        panel.trend:SetTextColor(1, 0.48, 0.35)
    elseif change < 0 then
        SetText(panel.trend, tostring(change))
        panel.trend:SetTextColor(0.5, 0.83, 0.54)
    else
        SetText(panel.trend, "=")
        panel.trend:SetTextColor(0.55, 0.58, 0.64)
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
        FillBar(panel.bar, mix, count, 8, PANEL_WIDTH - 8, panel, -54)
    else
        for i = 1, #panel.bar do panel.bar[i]:Hide() end
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
    local height = ROWS_TOP + math.max(1, shownRows) * ROW_HEIGHT + 6
    if count == 0 then height = ROWS_TOP + 4 end
    if panel.shownHeight ~= height then
        panel.shownHeight = height
        panel:SetHeight(height)
    end
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

local function DrawBadges(store, host, canvas, now, tier, stitched)
    for _, zone in pairs(zones) do
        zone.count = 0
        for class in pairs(zone.classes) do zone.classes[class] = 0 end
    end
    for _, record in pairs(store.records) do
        if now - record.lastSeen <= WINDOW then
            local zone = zones[record.mapID]
            if not zone then
                zone = { count = 0, classes = {} }
                zones[record.mapID] = zone
            end
            zone.count = zone.count + 1
            zone.classes[record.class] = (zone.classes[record.class] or 0) + 1
        end
    end
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    local k = canvas:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if k <= 0.01 then k = 1 end
    local shown = 0
    for mapID, zone in pairs(zones) do
        if zone.count > 0 then
            local x, y = Centre(mapID, host, stitched)
            if x and y then
                shown = shown + 1
                local badge = badges[shown]
                if not badge then
                    badge = NewBadge()
                    badges[shown] = badge
                end
                badge.zone = zone
                if badge.k ~= k then
                    badge.k = k
                    badge:SetScale(1 / k)
                end
                local px, py = x * width * k, -y * height * k
                if badge.px ~= px or badge.py ~= py then
                    badge.px, badge.py = px, py
                    badge:ClearAllPoints()
                    badge:SetPoint("CENTER", layer, "TOPLEFT", px, py)
                end
                if badge.mapID ~= mapID then
                    badge.mapID = mapID
                    badge.name:SetText(ZoneName(mapID))
                end
                if badge.shownCount ~= zone.count then
                    badge.shownCount = zone.count
                    badge.count:SetText(zone.count)
                    badge.glow:SetShown(zone.count >= HOT)
                end
                local topClass, topCount = nil, 0
                for class, count in pairs(zone.classes) do
                    if count > topCount then topClass, topCount = class, count end
                end
                if tier.badge >= 2 and topClass then
                    local color = ClassColor(topClass)
                    badge.top:SetText("mostly " .. (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[topClass] or topClass):lower())
                    badge.top:SetTextColor(color.r, color.g, color.b)
                else
                    badge.top:SetText("")
                end
                if tier.badge >= 3 then
                    FillBar(badge.bar, zone.classes, zone.count, 4, 74, badge, -36)
                    badge:SetHeight(42)
                else
                    for i = 1, #badge.bar do badge.bar[i]:Hide() end
                    badge:SetHeight(tier.badge >= 2 and 38 or 30)
                end
                badge:Show()
            end
        end
    end
    HideFrom(badges, shown + 1, badgesShown)
    badgesShown = shown
end

local function HideAll()
    HideFrom(dots, 1, dotsShown)
    HideFrom(badges, 1, badgesShown)
    dotsShown, badgesShown = 0, 0
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
        HideFrom(badges, 1, badgesShown)
        badgesShown = 0
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
        DrawBadges(store, host, canvas, now, tier, stitched)
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
end
end
