do
SA_GlobalMap = {}

local ENTER_ZOOM, LEAVE_ZOOM = 3, 2.6
local FULL_AGE, GONE_AGE = 120, 600
local ZONE_TYPE = 3
local WORLD_TYPE = 1
local INSIDE_STEPS = 8

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

local ARC_STEPS, MARK_FLOOR = 12, 0.55
local ATLAS_COLS, ATLAS_ROWS = 8, 4

SA_GlobalMap.ARC_STEPS = ARC_STEPS
SA_GlobalMap.CREST = {
    WARRIOR = 0, PALADIN = 1, HUNTER = 2, ROGUE = 3, PRIEST = 4, DEATHKNIGHT = 5, SHAMAN = 6, MAGE = 7,
    WARLOCK = 8, MONK = 9, DRUID = 10, DEMONHUNTER = 11, EVOKER = 12,
}
SA_GlobalMap.CELL = { FALLBACK = 13, ARC = 14, EYE = 26, BADGE = 27, PULSE = 28, DISC = 29, DIAMOND = 30, GLOW = 31 }
SA_GlobalMap.COORDS = {}
for index = 0, ATLAS_COLS * ATLAS_ROWS - 1 do
    local col, row = index % ATLAS_COLS, math.floor(index / ATLAS_COLS)
    SA_GlobalMap.COORDS[index] = { col / ATLAS_COLS, (col + 1) / ATLAS_COLS, row / ATLAS_ROWS, (row + 1) / ATLAS_ROWS }
end

function SA_GlobalMap.ArcStep(age)
    if age >= GONE_AGE then return 0 end
    if age <= 0 then return ARC_STEPS end
    return math.ceil((1 - age / GONE_AGE) * ARC_STEPS)
end

function SA_GlobalMap.MarkAlpha(age, step)
    local alpha = SA_GlobalMap.Alpha(age, step)
    if alpha <= 0 then return 0 end
    return alpha < MARK_FLOOR and MARK_FLOOR or alpha
end

function SA_GlobalMap.CellKey(mapID, cx, cy)
    return mapID * 10000 + cx * 100 + cy
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

function SA_GlobalMap.Inside(zone, host, infoOf)
    if zone == host then return true end
    local hostInfo = infoOf(host)
    if not hostInfo then return false end
    if type(hostInfo.mapType) == "number" and hostInfo.mapType <= WORLD_TYPE then return true end
    local id = zone
    for _ = 1, INSIDE_STEPS do
        local info = infoOf(id)
        local parent = info and info.parentMapID
        if type(parent) ~= "number" or parent == 0 or parent == id then return false end
        if parent == host then return true end
        id = parent
    end
    return false
end

function SA_GlobalMap.Verdict(count, nearGroup)
    if count == 0 then return "Quiet" end
    if count >= HOT_COUNT or (nearGroup and nearGroup >= HOT_GROUP) then return "Hot" end
    return "Active"
end

SA_GlobalMap.HOT_RANGE = HOT_RANGE

local WORLD_HOT = 10

function SA_GlobalMap.WorldVerdict(count)
    if count == 0 then return "Quiet" end
    if count >= WORLD_HOT then return "Hot" end
    return "Active"
end

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

local MARKS = "Interface\\AddOns\\SoundAlerter\\Textures\\gs_marks"
local NOTCH_TEXTURE = "Interface\\AddOns\\SoundAlerter\\Textures\\gs_notch"
local CREST, CELL, COORDS = M.CREST, M.CELL, M.COORDS
local FLAT = "Interface\\Buttons\\WHITE8X8"
local WATCH_COLOR = { r = 1, g = 0.16, b = 0.16 }
local WATCH_ROW_ALPHA = 0.32
local DOT_SIZE = 17
local WINDOW = 300
local HOT = 5
local RING_SIZE, RING_CRESTS, RING_CREST, RING_CREST_RADIUS, RING_GLOW = 26, 3, 10, 15, 1.7
local RING_CREST_ANGLES = { -50, 0, 50 }
local MERGE_DISTANCE = 26
local TIP_ZONES = 8
local GROUP_LIMIT = 60
local NOTCH_SCALE, EYE_SCALE, EYE_AT, BADGE_SCALE, BADGE_AT = 32 / 28, 0.36, 0.19, 0.44, 0.8
local ARC_COLOR = { 0.91, 0.93, 0.96, 0.85 }
local BADGE_COLOR = { 1, 0.62, 0.11 }
local RIM_COLOR = { 1, 0.85, 0.63 }
local HIGHER_COLOR = { 1, 0.35, 0.29 }
local VERDICT_COLOR = { Quiet = { 0.5, 0.83, 0.54 }, Active = { 1, 0.82, 0.29 }, Hot = { 1, 0.35, 0.29 } }
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
local clusters = {}
local markersOn = false
local crestTop = {}
local cellLead, cellCount, cellKeys = {}, {}, {}
local hostShown, scaleShown, quietUntil = nil, nil, 0
local sinceCheck, lastDraw, nextRefresh, nextPanel, forceDraw = 0, -1e9, 0, 0, true
local panelZone
local tier = M.TIERS.normal
local names = {}
local ordered, zones = {}, {}
local centres, centreHost = {}, nil
local mix, worldMix, zoneList = {}, {}, {}
local worldTotal, worldPrevious = 0, 0
local worldStealth, worldHigher = 0, 0
local litZone
local LIT_SCALE = 1.5
local zoneData = { kind = "zone", rows = {}, tiles = { {}, {}, {} }, mix = mix }
local worldData = { kind = "world", rows = {}, tiles = { {}, {}, {} }, mix = worldMix }
local groups, groupOf, groupDistance, order, swatchParts, worldSizes = {}, {}, {}, {}, {}, {}

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

local insideMemo = {}

local function InsideHost(zone, host)
    local getInfo = C_Map and C_Map.GetMapInfo
    if not getInfo then return true end
    local byHost = insideMemo[host]
    if not byHost then
        byHost = {}
        insideMemo[host] = byHost
    end
    local known = byHost[zone]
    if known == nil then
        known = M.Inside(zone, host, getInfo)
        byHost[zone] = known
    end
    return known
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
    if owner.badgeOn and owner.shownCount then
        GameTooltip:AddLine("+" .. (owner.shownCount - 1) .. " more enemies on this spot", 1, 0.62, 0.11)
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

local function Cell(texture, index)
    local c = COORDS[index]
    texture:SetTexCoord(c[1], c[2], c[3], c[4])
end

local function MarkTexture(frame, drawLayer, sublevel, index)
    local texture = frame:CreateTexture(nil, drawLayer, nil, sublevel)
    texture:SetTexture(MARKS)
    if index then Cell(texture, index) end
    return texture
end

local function NewMarker(parent)
    local mark = CreateFrame("Button", nil, parent)
    mark.body = MarkTexture(mark, "OVERLAY", 0)
    mark.body:SetAllPoints(mark)
    mark.arc = MarkTexture(mark, "OVERLAY", 1)
    mark.arc:SetAllPoints(mark)
    mark.arc:SetVertexColor(ARC_COLOR[1], ARC_COLOR[2], ARC_COLOR[3], ARC_COLOR[4])
    mark.arc:Hide()
    mark:SetScript("OnEnter", ShowTip)
    mark:SetScript("OnLeave", HideTip)
    return mark
end

local function PlaceEye(mark, size)
    local eye = mark.eye
    eye:SetSize(size * EYE_SCALE, size * EYE_SCALE)
    eye:ClearAllPoints()
    eye:SetPoint("CENTER", mark, "TOPLEFT", size * EYE_AT, -size * EYE_AT)
end

local function PlaceBadge(mark, size)
    local side = size * BADGE_SCALE
    mark.badge:SetSize(side, side)
    mark.badge:ClearAllPoints()
    mark.badge:SetPoint("CENTER", mark, "TOPLEFT", size * BADGE_AT, -size * BADGE_AT)
    local font = math.max(6, math.floor(side * 0.78 + 0.5))
    if mark.fontSize ~= font then
        mark.fontSize = font
        mark.count:SetFont(STANDARD_TEXT_FONT, font, "OUTLINE")
    end
end

local function PlaceNotch(mark, size)
    mark.notch:SetSize(size * NOTCH_SCALE, size * NOTCH_SCALE)
end

local function NewEye(mark)
    mark.eye = MarkTexture(mark, "OVERLAY", 3, CELL.EYE)
    PlaceEye(mark, mark.size)
end

local function NewBadge(mark)
    mark.badge = MarkTexture(mark, "OVERLAY", 4, CELL.BADGE)
    mark.badge:SetVertexColor(BADGE_COLOR[1], BADGE_COLOR[2], BADGE_COLOR[3], 1)
    mark.count = mark:CreateFontString(nil, "OVERLAY")
    mark.count:SetDrawLayer("OVERLAY", 5)
    mark.count:SetPoint("CENTER", mark.badge, "CENTER", 0, 0)
    PlaceBadge(mark, mark.size)
end

local function NewNotch(mark)
    mark.notch = mark:CreateTexture(nil, "OVERLAY", nil, 2)
    mark.notch:SetTexture(NOTCH_TEXTURE)
    mark.notch:SetPoint("CENTER", mark, "CENTER", 0, 0)
    PlaceNotch(mark, mark.size)
end

local function StyleMarker(mark, record, size, count, age, bearing)
    if mark.size ~= size then
        mark.size = size
        mark:SetSize(size, size)
        if mark.eye then PlaceEye(mark, size) end
        if mark.badge then PlaceBadge(mark, size) end
        if mark.notch then PlaceNotch(mark, size) end
    end
    local class = record.class
    if mark.class ~= class then
        mark.class = class
        Cell(mark.body, CREST[class] or CELL.FALLBACK)
        local color = ClassColor(class)
        mark.body:SetVertexColor(color.r, color.g, color.b, 1)
        if mark.ring then mark.ring:SetVertexColor(color.r, color.g, color.b, 1) end
        if M.STEALTH[class] then
            if not mark.eye then NewEye(mark) end
            mark.eye:Show()
        elseif mark.eye then
            mark.eye:Hide()
        end
    end
    local step = M.ArcStep(age)
    if mark.step ~= step then
        mark.step = step
        if step > 0 then
            Cell(mark.arc, CELL.ARC + step - 1)
            mark.arc:Show()
        else
            mark.arc:Hide()
        end
    end
    if count > 1 then
        if not mark.badge then NewBadge(mark) end
        if mark.shownCount ~= count then
            mark.shownCount = count
            mark.count:SetText(count > 9 and "9+" or count)
        end
        if not mark.badgeOn then
            mark.badgeOn = true
            mark.badge:Show()
            mark.count:Show()
        end
    elseif mark.badgeOn then
        mark.badgeOn = false
        mark.badge:Hide()
        mark.count:Hide()
    end
    if bearing then
        if not mark.notch then NewNotch(mark) end
        if mark.bearing ~= bearing then
            mark.bearing = bearing
            mark.notch:SetRotation(-bearing)
        end
        if not mark.notchOn then
            mark.notchOn = true
            mark.notch:Show()
        end
    elseif mark.notchOn then
        mark.notchOn = false
        mark.notch:Hide()
    end
end

local function NewDot()
    local dot = NewMarker(layer)
    dot.ring = MarkTexture(dot, "ARTWORK", 0, CELL.PULSE)
    dot.ring:SetBlendMode("ADD")
    dot.ring:SetAllPoints(dot)
    dot.ring:Hide()
    dot.pulse = NewPulse(dot.ring, 2.4, 1.2, 0.9)
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
    ring.glow = MarkTexture(ring, "BACKGROUND", 0, CELL.GLOW)
    ring.glow:SetVertexColor(1, 0.3, 0.25, 1)
    ring.glow:SetBlendMode("ADD")
    ring.glow:SetSize(RING_SIZE * RING_GLOW, RING_SIZE * RING_GLOW)
    ring.glow:SetPoint("CENTER", ring, "CENTER", 0, 0)
    ring.glow:Hide()
    ring.disc = MarkTexture(ring, "BORDER", 0, CELL.DISC)
    ring.disc:SetVertexColor(RIM_COLOR[1], RIM_COLOR[2], RIM_COLOR[3], 1)
    ring.disc:SetAllPoints(ring)
    ring.crests = {}
    for i = 1, RING_CRESTS do
        local crest = MarkTexture(ring, "ARTWORK", 0)
        crest:SetSize(RING_CREST, RING_CREST)
        local angle = math.rad(RING_CREST_ANGLES[i])
        crest:SetPoint("CENTER", ring, "CENTER", math.sin(angle) * RING_CREST_RADIUS, math.cos(angle) * RING_CREST_RADIUS)
        crest:Hide()
        ring.crests[i] = crest
    end
    ring.count = ring:CreateFontString(nil, "OVERLAY")
    ring.count:SetFontObject("GameFontHighlightSmall")
    ring.count:SetPoint("CENTER", ring, "CENTER", 0, 0)
    ring.tick = MarkTexture(ring, "OVERLAY", 1, CELL.DIAMOND)
    ring.tick:SetVertexColor(HIGHER_COLOR[1], HIGHER_COLOR[2], HIGHER_COLOR[3], 1)
    ring.tick:SetSize(9, 9)
    ring.tick:SetPoint("CENTER", ring, "CENTER", 10, -10)
    ring.tick:Hide()
    ring.pulse = NewPulse(ring.glow, 1.7, 1.4, 0.8)
    ring:SetScript("OnEnter", ShowRingTip)
    ring:SetScript("OnLeave", HideTip)
    return ring
end

local function Better(class, count, other, classes)
    local otherCount = classes[other]
    return count > otherCount or (count == otherCount and class < other)
end

local function AssignCrests(ring, classes)
    local n = 0
    for class, count in pairs(classes) do
        if count > 0 then
            local slot
            if n < RING_CRESTS then
                n = n + 1
                slot = n
            elseif Better(class, count, crestTop[n], classes) then
                slot = n
            end
            if slot then
                while slot > 1 and Better(class, count, crestTop[slot - 1], classes) do
                    crestTop[slot] = crestTop[slot - 1]
                    slot = slot - 1
                end
                crestTop[slot] = class
            end
        end
    end
    for i = 1, RING_CRESTS do
        local texture = ring.crests[i]
        local class = i <= n and crestTop[i] or nil
        if texture.class ~= class then
            texture.class = class
            if class then
                Cell(texture, CREST[class] or CELL.FALLBACK)
                local color = ClassColor(class)
                texture:SetVertexColor(color.r, color.g, color.b, 1)
                texture:Show()
            else
                texture:Hide()
            end
        end
    end
end

local function ByRecent(a, b) return a.lastSeen > b.lastSeen end

local function HideFrom(list, first, shown)
    for i = first, shown do list[i]:Hide() end
end

local function Expanded()
    local profile = SoundAlerter.db1 and SoundAlerter.db1.profile
    return not profile or profile.globalPanelExpanded ~= false
end

local function ShowRowTip(owner)
    local row = owner
    if not row.members or row.count == 0 then return end
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    local now = GetTime()
    for i = 1, row.count do
        local record = row.members[i]
        local color = SoundAlerter:StampWatched(record) and WATCH_COLOR or ClassColor(record.class)
        local level = type(record.level) == "number" and record.level >= 0 and tostring(record.level) or "??"
        GameTooltip:AddDoubleLine(record.name .. "  " .. level, M.Short(now - record.lastSeen) .. " ago", color.r, color.g, color.b, 0.7, 0.7, 0.7)
        if record.reporterCount and record.reporterCount >= 2 then
            GameTooltip:AddLine("  seen by " .. record.reporterCount .. " players", 0.6, 0.65, 0.7)
        end
        if M.STEALTH[record.class] then GameTooltip:AddLine("  can stealth", 1, 0.96, 0.41) end
    end
    GameTooltip:Show()
end

local function ClusterHas(cluster, mapID)
    for j = 1, cluster.size do
        if cluster.zones[j].mapID == mapID then return true end
    end
    return false
end

local function StyleRing(ring)
    local lit = litZone ~= nil and ring.cluster ~= nil and ClusterHas(ring.cluster, litZone)
    local scale = (lit and LIT_SCALE or 1) / ring.k
    if ring.scaleSet ~= scale then
        ring.scaleSet = scale
        ring:SetScale(scale)
    end
end

local function ApplyLit()
    for i = 1, ringsShown do StyleRing(rings[i]) end
end

local function ShowFactsTip(owner, data)
    if not data then return end
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine("Enemies in the last 5 minutes", 1, 1, 1)
    local stealth, higher = data.stealth or 0, data.higher or 0
    if stealth == 0 and higher == 0 then
        GameTooltip:AddLine("None can stealth, none are higher level than you", 0.6, 0.65, 0.7)
    else
        GameTooltip:AddDoubleLine("Can stealth", tostring(stealth), 1, 0.96, 0.41, 1, 1, 1)
        GameTooltip:AddDoubleLine("Higher level than you", tostring(higher), 1, 0.48, 0.35, 1, 1, 1)
    end
    GameTooltip:Show()
end

local panelHooks = {
    factsTip = ShowFactsTip,
    rowTip = ShowRowTip,
    hideTip = HideTip,
    rowEnter = function(mapID)
        litZone = mapID
        ApplyLit()
    end,
    rowLeave = function()
        if litZone ~= nil then
            litZone = nil
            ApplyLit()
        end
    end,
    toggle = function()
        local profile = SoundAlerter.db1 and SoundAlerter.db1.profile
        if not profile then return end
        profile.globalPanelExpanded = not Expanded()
        forceDraw = true
    end,
}

local function PanelOption(key)
    local profile = SoundAlerter.db1 and SoundAlerter.db1.profile
    return SA_GlobalPanel.Option(profile and profile[key])
end

local function BuildPanel()
    panel = SA_GlobalPanel.Create(WorldMapFrame.ScrollContainer or WorldMapFrame, panelHooks)
end

local function Trend(data, change)
    if change > 0 then
        data.trend, data.trR, data.trG, data.trB = "+" .. change, 1, 0.48, 0.35
    elseif change < 0 then
        data.trend, data.trR, data.trG, data.trB = tostring(change), 0.5, 0.83, 0.54
    else
        data.trend, data.trR, data.trG, data.trB = "", 0.55, 0.58, 0.64
    end
end

local function Tile(tile, label, value, sub, r, g, b)
    tile.label, tile.value, tile.sub = label, value, sub or ""
    tile.r, tile.g, tile.b = r or 0.55, g or 0.58, b or 0.64
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

local function GroupCells(list, limit, leads, counts, keys)
    for key in pairs(leads) do leads[key] = nil end
    for key in pairs(counts) do counts[key] = nil end
    for i = 1, limit do
        local record = list[i]
        local key = M.CellKey(record.mapID, record.cx, record.cy)
        keys[i] = key
        local lead = leads[key]
        if not lead or record.lastSeen > lead.lastSeen then leads[key] = record end
        counts[key] = (counts[key] or 0) + 1
    end
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
    local option = PanelOption("globalPanelZone")
    if option == "off" then
        panelZone = nil
        if panel then SA_GlobalPanel.Hide(panel) end
        return
    end
    if not panel then BuildPanel() end
    panelZone = zone
    local expanded = Expanded()
    for class in pairs(mix) do mix[class] = 0 end
    for i = 1, #ordered do ordered[i] = nil end
    local count, previous, stealth, higher = 0, 0, 0, 0
    local mine = UnitLevel and UnitLevel("player")
    for _, record in pairs(store.records) do
        if record.mapID == zone then
            local age = now - record.lastSeen
            if age <= WINDOW then
                count = count + 1
                if M.STEALTH[record.class] then stealth = stealth + 1 end
                if M.Higher(record.level, mine) then higher = higher + 1 end
                ordered[count] = record
                mix[record.class] = (mix[record.class] or 0) + 1
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
            local size = #members
            if size >= 3 and distance <= M.HOT_RANGE and (not nearGroup or size > nearGroup) then nearGroup = size end
        end
        groupDistance[g] = distance or false
    end
    local verdict = M.Verdict(count, nearGroup)
    local color = VERDICT_COLOR[verdict]
    local data = zoneData
    local name = ZoneName(zone)
    data.option, data.expanded = option, expanded
    data.title = (name ~= "" and name or "This zone") .. " · last 5 min"
    data.verdict = verdict:upper()
    data.vr, data.vg, data.vb = color[1], color[2], color[3]
    data.count, data.total, data.countText = count, count, tostring(count)
    data.stealth, data.higher = stealth, higher
    Trend(data, count - previous)
    local tiles = data.tiles
    Tile(tiles[1], "Enemies", data.countText, data.trend, data.trR, data.trG, data.trB)
    Tile(tiles[2], "Nearest", nearest and (M.Yards(nearest) .. " yd " .. nearestDir) or "none")
    Tile(tiles[3], "Watching", tostring(store.watcherCounts[zone] or 0))
    for g = 1, total do order[g] = g end
    for g = total + 1, #order do order[g] = nil end
    table.sort(order, ByGroup)
    local rows = SA_GlobalPanel.RowLimit(total, expanded)
    data.rowCount = rows
    data.more = SA_GlobalPanel.MoreText(total, rows, expanded)
    for i = 1, rows do
        local entry = data.rows[i]
        if not entry then
            entry = {}
            data.rows[i] = entry
        end
        local members = groups[order[i]]
        local size = #members
        local lead = members[1]
        entry.members, entry.count, entry.zone, entry.meter = members, size, nil, nil
        if size >= 2 then
            entry.name = "Group of " .. size .. " " .. Swatches(members, size)
            entry.nameR, entry.nameG, entry.nameB = 1, 0.69, 0.63
        else
            local leadColor = ClassColor(lead.class)
            entry.name = lead.name
            entry.nameR, entry.nameG, entry.nameB = leadColor.r, leadColor.g, leadColor.b
        end
        entry.dotR, entry.dotG, entry.dotB = entry.nameR, entry.nameG, entry.nameB
        local level = lead.level
        for k = 2, size do
            local other = members[k].level
            if type(other) ~= "number" or other < 0 then level = -1 elseif type(level) == "number" and level >= 0 and other > level then level = other end
        end
        if type(level) == "number" and level >= 0 then
            entry.lvlText = tostring(level)
        else
            entry.lvlText = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:10:10|t"
        end
        entry.lvlR, entry.lvlG, entry.lvlB = M.LevelColor(level, mine)
        entry.chip = true
        entry.ago = SA_GlobalPanel.AgeText(now - lead.lastSeen)
        entry.bearing = Heading(lead, width, height)
        entry.alpha = 1
    end
    SA_GlobalPanel.Draw(panel, data)
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
    GroupCells(ordered, limit, cellLead, cellCount, cellKeys)
    for i = 1, limit do
        local record = ordered[i]
        local cell = cellKeys[i]
        local x, y
        if cellLead[cell] == record then
            if record.projHost == key and record.projMap == record.mapID and record.projCx == record.cx and record.projCy == record.cy then
                x, y = record.projX, record.projY
            else
                x, y = Project(record.mapID, (record.cx + 0.5) / 100, (record.cy + 0.5) / 100, host, stitched)
                record.projHost, record.projMap, record.projCx, record.projCy = key, record.mapID, record.cx, record.cy
                record.projX, record.projY = x or false, y or false
            end
        end
        if x and y then
            shown = shown + 1
            local dot = dots[shown]
            if not dot then
                dot = NewDot()
                dots[shown] = dot
            end
            dot.record = record
            local age = now - record.lastSeen
            StyleMarker(dot, record, size, cellCount[cell], age, Heading(record))
            local px, py = x * width, -y * height
            if dot.px ~= px or dot.py ~= py then
                dot.px, dot.py = px, py
                dot:ClearAllPoints()
                dot:SetPoint("CENTER", layer, "TOPLEFT", px, py)
            end
            local alpha = M.MarkAlpha(age, tier.step)
            if dot.alpha ~= alpha then
                dot.alpha = alpha
                dot:SetAlpha(alpha)
            end
            if tier.pulse and age < FRESH then
                if not dot.pulseOn then
                    dot.pulseOn = true
                    dot.ring:Show()
                    dot.pulse:Play()
                end
            elseif dot.pulseOn then
                dot.pulseOn = false
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

local function DrawRings(store, host, canvas, now, tier, stitched, showRings)
    for _, zone in pairs(zones) do
        zone.count, zone.higher = 0, false
        for class in pairs(zone.classes) do zone.classes[class] = 0 end
    end
    local mine = UnitLevel and UnitLevel("player")
    worldTotal, worldPrevious, worldStealth, worldHigher = 0, 0, 0, 0
    for class in pairs(worldMix) do worldMix[class] = 0 end
    for _, record in pairs(store.records) do
        local age = now - record.lastSeen
        if age > WINDOW * 2 or (not stitched and not InsideHost(record.mapID, host)) then age = nil end
        if age and record.firstSeen <= now - WINDOW then worldPrevious = worldPrevious + 1 end
        if age and age <= WINDOW then
            worldTotal = worldTotal + 1
            if M.STEALTH[record.class] then worldStealth = worldStealth + 1 end
            if M.Higher(record.level, mine) then worldHigher = worldHigher + 1 end
            worldMix[record.class] = (worldMix[record.class] or 0) + 1
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
    if not showRings then
        HideFrom(rings, 1, ringsShown)
        ringsShown = 0
        return
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
        ring.k = k
        StyleRing(ring)
        if ring.px ~= cluster.x or ring.py ~= cluster.y then
            ring.px, ring.py = cluster.x, cluster.y
            ring:ClearAllPoints()
            ring:SetPoint("CENTER", layer, "TOPLEFT", cluster.x, cluster.y)
        end
        AssignCrests(ring, cluster.classes)
        if ring.shownTotal ~= cluster.total then
            ring.shownTotal = cluster.total
            ring.count:SetText(cluster.total > 99 and "99+" or cluster.total)
        end
        if ring.higher ~= cluster.higher then
            ring.higher = cluster.higher
            ring.tick:SetShown(cluster.higher)
        end
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

local function ByZoneCount(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.mapID < b.mapID
end

local function DrawWorldPanel(store, host, stitched)
    local option = PanelOption("globalPanelWorld")
    if option == "off" then
        if panel then SA_GlobalPanel.Hide(panel) end
        return
    end
    if not panel then BuildPanel() end
    local expanded = Expanded()
    local zoneCount, mostEnemies = 0, 1
    for _, zone in pairs(zones) do
        if zone.count > 0 then
            zoneCount = zoneCount + 1
            zoneList[zoneCount] = zone
            if zone.count > mostEnemies then mostEnemies = zone.count end
        end
    end
    for i = zoneCount + 1, #zoneList do zoneList[i] = nil end
    table.sort(zoneList, ByZoneCount)
    local watchers = 0
    for zoneID, number in pairs(store.watcherCounts) do
        if stitched or InsideHost(zoneID, host) then watchers = watchers + number end
    end
    local verdict = M.WorldVerdict(worldTotal)
    local color = VERDICT_COLOR[verdict]
    local data = worldData
    local name = ZoneName(host)
    data.option, data.expanded = option, expanded
    data.title = (name ~= "" and name or "World") .. " · last 5 min"
    data.verdict = verdict:upper()
    data.vr, data.vg, data.vb = color[1], color[2], color[3]
    data.count, data.total, data.countText = worldTotal, worldTotal, tostring(worldTotal)
    data.stealth, data.higher = worldStealth, worldHigher
    Trend(data, worldTotal - worldPrevious)
    local tiles = data.tiles
    Tile(tiles[1], "Enemies", data.countText, data.trend, data.trR, data.trG, data.trB)
    Tile(tiles[2], "Zones", tostring(zoneCount))
    Tile(tiles[3], "Watching", tostring(watchers))
    local rows = SA_GlobalPanel.RowLimit(zoneCount, expanded)
    data.rowCount = rows
    data.more = SA_GlobalPanel.MoreText(zoneCount, rows, expanded)
    for i = 1, rows do
        local entry = data.rows[i]
        if not entry then
            entry = {}
            data.rows[i] = entry
        end
        local zone = zoneList[i]
        entry.members, entry.count, entry.zone = nil, 0, zone.mapID
        entry.name = ZoneName(zone.mapID)
        entry.nameR, entry.nameG, entry.nameB = 1, 1, 1
        if zone.higher then
            entry.dotR, entry.dotG, entry.dotB = 1, 0.6, 0.25
        else
            entry.dotR, entry.dotG, entry.dotB = 0.36, 0.48, 0.69
        end
        entry.lvlText, entry.lvlR, entry.lvlG, entry.lvlB = tostring(zone.count), 1, 1, 1
        entry.chip, entry.ago, entry.bearing, entry.alpha = false, "", nil, 1
        entry.meter = math.max(3, math.floor(zone.count / mostEnemies * 60))
    end
    SA_GlobalPanel.Draw(panel, data)
end

local function HideAll()
    HideFrom(dots, 1, dotsShown)
    HideFrom(rings, 1, ringsShown)
    dotsShown, ringsShown = 0, 0
    if panel then SA_GlobalPanel.Hide(panel) end
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
        if markersOn then
            DrawDots(store, host, canvas, now, tier, stitched)
        else
            HideFrom(dots, 1, dotsShown)
            dotsShown = 0
        end
        local zone = host
        if stitched and u and v and OpenMapAPI.MapAt then
            local at = OpenMapAPI.MapAt(u, v)
            if type(at) == "number" then zone = at end
        end
        DrawPanel(store, zone, now)
    else
        HideFrom(dots, 1, dotsShown)
        dotsShown = 0
        DrawRings(store, host, canvas, now, tier, stitched, markersOn)
        DrawWorldPanel(store, host, stitched)
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

local PIN_SIZE, RIM_SIZE, RIM_ALPHA = 15, 11, 0.55
local GATHER_EVERY = 1
local pinFrame
local pins, pinsShown = {}, 0
local nearby, nearbyCount, gatherZone, nextGather, sincePin = {}, 0, nil, 0, 0
local pinLead, pinCount, pinKeys = {}, {}, {}

local function NewPin()
    return NewMarker(pinFrame)
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
    GroupCells(nearby, count, pinLead, pinCount, pinKeys)
end

local function PlacePin(pin, alpha, x, y)
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
        local cell = pinKeys[index]
        local x, y, rim
        if pinLead[cell] == record and record.mapID == zone and store.records[record.guid] == record then
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
            local age = now - record.lastSeen
            local bearing = Heading(record)
            if bearing and facing then bearing = bearing + facing end
            StyleMarker(pin, record, rim and RIM_SIZE or PIN_SIZE, pinCount[cell], age, bearing)
            local alpha = M.MarkAlpha(age, tier.step)
            if rim then alpha = alpha * RIM_ALPHA end
            PlacePin(pin, alpha, x * half, y * half)
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
    local sharing = profile and profile.globalSightings and self:GlobalSightStore() ~= nil
    markersOn = sharing and profile.globalMapMarkers == true or false
    local panelApi = SA_GlobalPanel
    local panels = sharing and (not panelApi or panelApi.Option(profile.globalPanelZone) ~= "off" or panelApi.Option(profile.globalPanelWorld) ~= "off")
    local on = sharing and (markersOn or panels)
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
    local wantPins = sharing and profile.globalMinimap ~= false
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

local Enemy = {
    REFRESH = 5,
    TITLE = "SoundAlerter - Enemy Finder",
    CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
    SETTINGS = { scope = "names", fuzzy = true, autocomplete = false, descending = false },
    results = {}, scores = {}, lower = {}, lowerCount = 0, classLower = {}, zoneLower = {},
}

function Enemy.Lower(text)
    local cached = Enemy.lower[text]
    if cached then return cached end
    if Enemy.lowerCount >= 2000 then
        wipe(Enemy.lower)
        Enemy.lowerCount = 0
    end
    cached = string.lower(text)
    Enemy.lower[text] = cached
    Enemy.lowerCount = Enemy.lowerCount + 1
    return cached
end

function Enemy.ClassName(class)
    return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class or "?"
end

function Enemy.ClassLower(class)
    local cached = Enemy.classLower[class]
    if not cached then
        cached = string.lower(Enemy.ClassName(class))
        Enemy.classLower[class] = cached
    end
    return cached
end

function Enemy.ZoneLower(mapID)
    local cached = Enemy.zoneLower[mapID]
    if not cached then
        cached = string.lower(ZoneName(mapID))
        Enemy.zoneLower[mapID] = cached
    end
    return cached
end

function Enemy.Score(record, term)
    if term == "" then return 0 end
    local score = SA_FinderList.Score(Enemy.Lower(record.name or ""), term)
    if score then return score end
    if string.find(Enemy.ClassLower(record.class), term, 1, true) then return 3000 end
    if type(record.race) == "string" and string.find(Enemy.Lower(record.race), term, 1, true) then return 3100 end
    if string.find(Enemy.ZoneLower(record.mapID), term, 1, true) then return 3200 end
    return nil
end

Enemy.COLUMNS = {
    { key = "seen", label = "Seen", width = 54, gap = 0 },
    { key = "level", label = "Level", width = 60, gap = 10 },
    { key = "zone", label = "Zone", width = 70, gap = 8 },
    { key = "name", label = "Name", align = "LEFT", offset = 38 },
}

Enemy.sortKey = nil
Enemy.sortDescending = false

local function EnemyLevel(record)
    local level = record.level
    if type(level) == "number" and level >= 0 then return level end
    return 1000
end

local SORT_VALUE = {
    name = function(record) return Enemy.Lower(record.name or "") end,
    zone = function(record) return Enemy.ZoneLower(record.mapID) end,
    level = EnemyLevel,
    seen = function(record) return -record.lastSeen end,
}

local function ByEnemyScore(a, b)
    local scores = Enemy.scores
    if scores[a] ~= scores[b] then return scores[a] < scores[b] end
    return a.lastSeen > b.lastSeen
end

local function ByEnemyColumn(a, b)
    local value = SORT_VALUE[Enemy.sortKey]
    local left, right = value(a), value(b)
    if left ~= right then
        if Enemy.sortDescending then return left > right end
        return left < right
    end
    return ByEnemyScore(a, b)
end

function Enemy.SortState()
    return Enemy.sortKey, Enemy.sortDescending
end

function Enemy.OnSort(key)
    if Enemy.sortKey ~= key then
        Enemy.sortKey = key
        Enemy.sortDescending = false
    elseif not Enemy.sortDescending then
        Enemy.sortDescending = true
    else
        Enemy.sortKey = nil
        Enemy.sortDescending = false
    end
end

function Enemy.Store()
    local profile = SoundAlerter.db1 and SoundAlerter.db1.profile
    if not (profile and profile.globalSightings) then return nil end
    return SoundAlerter:GlobalSightStore()
end

function Enemy.Search(window, term, keepGuid)
    local results, scores = Enemy.results, Enemy.scores
    for i = #results, 1, -1 do results[i] = nil end
    wipe(scores)
    local store = Enemy.Store()
    local count = 0
    if store then
        local now = GetTime()
        term = string.lower(term or "")
        for _, record in pairs(store.records) do
            if now - record.lastSeen <= M.GONE_AGE then
                local score = Enemy.Score(record, term)
                if score then
                    count = count + 1
                    results[count] = record
                    scores[record] = score
                end
            end
        end
        table.sort(results, Enemy.sortKey and ByEnemyColumn or ByEnemyScore)
    end
    window:ShowResults(results, count, term)
    if keepGuid then
        for i = 2, count do
            if results[i].guid == keepGuid then
                window:Select(i)
                break
            end
        end
    end
end

function Enemy.Count()
    local store = Enemy.Store()
    if not store then return nil end
    local now, count = GetTime(), 0
    for _, record in pairs(store.records) do
        if now - record.lastSeen <= M.GONE_AGE then count = count + 1 end
    end
    return count
end

function Enemy.Icon(texture, class)
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
        texture:SetTexture(Enemy.CLASS_ICONS)
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

function Enemy.LevelText(record)
    local level = record.level
    if type(level) == "number" and level >= 0 then return tostring(level) end
    return "??"
end

function Enemy.Where(mapID, cx, cy)
    local name = ZoneName(mapID)
    if name == "" then name = "Unknown zone" end
    if type(cx) == "number" and type(cy) == "number" then return name .. "  " .. cx .. ", " .. cy end
    return name
end

function Enemy.WatchTint(row, on)
    local tint = row.watch
    if not tint then
        if not on then return end
        tint = row.frame:CreateTexture(nil, "BORDER")
        tint:SetAllPoints(row.frame)
        tint:SetColorTexture(WATCH_COLOR.r, WATCH_COLOR.g, WATCH_COLOR.b, WATCH_ROW_ALPHA)
        row.watch = tint
    elseif row.watchOn == on then
        return
    end
    row.watchOn = on
    tint:SetShown(on)
end

function Enemy.BindRow(row, record)
    Enemy.WatchTint(row, SoundAlerter:StampWatched(record) and true or false)
    Enemy.Icon(row.icon, record.class)
    row.name:SetText(record.name or "?")
    row.rank:SetText(Enemy.LevelText(record))
    row.tag:SetText(ZoneName(record.mapID))
    row.id:SetText(M.Short(GetTime() - record.lastSeen))
end

function Enemy.RowTip(record)
    local color = ClassColor(record.class)
    GameTooltip:AddLine(record.name or "?", color.r, color.g, color.b)
    GameTooltip:AddLine(Enemy.LevelText(record) .. " " .. Enemy.ClassName(record.class), 1, 1, 1)
    GameTooltip:AddLine(Enemy.Where(record.mapID, record.cx, record.cy), 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Last seen " .. M.Ago(GetTime() - record.lastSeen), 0.6, 0.65, 0.7)
    if record.watched then GameTooltip:AddLine("On your watchlist", WATCH_COLOR.r, WATCH_COLOR.g, WATCH_COLOR.b) end
    GameTooltip:AddLine("Ctrl-click to " .. (record.watched and "unwatch" or "watch"), 0.55, 0.58, 0.64)
end

function Enemy.FillDetail(window, fields, record)
    if not record then
        fields.icon:Hide()
        fields.title:SetText("")
        fields.subtitle:SetText("")
        fields.facts:SetText("")
        fields.props:SetText("")
        fields.id:SetText("")
        fields.description:SetText("Select an enemy to see everything known about them. Ctrl-click a row to watch or unwatch.")
        window:SetButtons(false, false)
        return
    end
    local now = GetTime()
    local color = ClassColor(record.class)
    fields.icon:Show()
    Enemy.Icon(fields.icon, record.class)
    fields.title:SetText(record.name or "?")
    fields.title:SetTextColor(color.r, color.g, color.b)
    local race = type(record.race) == "string" and record.race ~= "" and (record.race .. " ") or ""
    fields.subtitle:SetText("Level " .. Enemy.LevelText(record) .. " " .. race .. Enemy.ClassName(record.class))
    local facts = "Where: " .. Enemy.Where(record.mapID, record.cx, record.cy)
    if record.prevMapID and (record.prevMapID ~= record.mapID or record.prevCx ~= record.cx or record.prevCy ~= record.cy) then
        facts = facts .. "\nCame from: " .. Enemy.Where(record.prevMapID, record.prevCx, record.prevCy)
    end
    facts = facts .. "\nLast seen " .. M.Ago(now - record.lastSeen) .. ", first seen " .. M.Ago(now - record.firstSeen)
    fields.facts:SetText(facts)
    local count = record.reporterCount or 1
    if count < 1 then count = 1 end
    local store = Enemy.Store()
    local watchers = store and store.watcherCounts[record.mapID] or 0
    fields.props:SetText("Seen by " .. count .. (count == 1 and " player" or " players")
        .. "\nDistance: " .. (BAND_TEXT[record.band] or "unknown")
        .. "\nVia " .. (SOURCE_TEXT[record.source] or "unknown")
        .. "\nWatching this zone: " .. watchers)
    local notes = SoundAlerter:StampWatched(record) and "|cffFF2929On your watchlist.|r" or ""
    if M.STEALTH[record.class] then notes = notes ~= "" and (notes .. "\nCan stealth.") or "Can stealth." end
    local mine = UnitLevel and UnitLevel("player")
    local levelNote
    if type(record.level) ~= "number" or record.level < 0 then
        levelNote = "Level unknown: likely far above yours."
    elseif M.Higher(record.level, mine) then
        levelNote = "Higher level than you."
    end
    if levelNote then notes = notes ~= "" and (notes .. "\n" .. levelNote) or levelNote end
    fields.description:SetText(notes)
    fields.id:SetText(record.name or "")
    window:SetButtons(true, false)
end

function Enemy.Status(count)
    if not Enemy.Store() then return "Global sightings is off" end
    count = count or 0
    return count .. (count == 1 and " enemy" or " enemies") .. " in the last 10 minutes"
end

function Enemy.Empty(term)
    if not Enemy.Store() then return "Global sightings is off. Turn it on under Global sightings to collect enemies spotted by your faction." end
    if term and term ~= "" then return "No recent enemy matches \"" .. term .. "\"." end
    return "No enemies spotted in the last 10 minutes."
end

function Enemy.Refresh()
    local window = Enemy.window
    if not (window and window.frame:IsShown()) then return end
    local selected = window.selectedSpell
    Enemy.Search(window, window:Text(), selected and selected.guid)
end

function Enemy.ToggleWatch(record)
    if record and record.name then SoundAlerter:ToggleWatchName(record.name) end
end

function Enemy.Shown(window)
    if not Enemy.ticker then Enemy.ticker = C_Timer.NewTicker(Enemy.REFRESH, Enemy.Refresh) end
    window:RunSearch()
end

function Enemy.Hidden()
    if Enemy.ticker then
        Enemy.ticker:Cancel()
        Enemy.ticker = nil
    end
end

function Enemy.Host()
    return {
        title = Enemy.TITLE,
        placeholder = "Name, class, race or zone",
        controls = false,
        listAll = true,
        columns = Enemy.COLUMNS,
        sortState = Enemy.SortState,
        onSort = Enemy.OnSort,
        copyLabel = "Copy name",
        copyToast = "Name selected, press Ctrl+C",
        settings = function() return Enemy.SETTINGS end,
        rankOptions = function() return {} end,
        search = function(window, term) Enemy.Search(window, term) end,
        suggest = function() return {} end,
        status = Enemy.Status,
        empty = Enemy.Empty,
        detail = function(window, record) window:SetDetail(record) end,
        bindRow = Enemy.BindRow,
        rowTip = Enemy.RowTip,
        rowModifiedClick = Enemy.ToggleWatch,
        fillDetail = Enemy.FillDetail,
        set = function() end,
        setScope = function() end,
        after = function(delay, fn) return SoundAlerter:ScheduleTimer(fn, delay) end,
        cancel = function(handle) SoundAlerter:CancelTimer(handle, true) end,
        savePosition = function(point, relative, x, y)
            local profile = SoundAlerter.db1 and SoundAlerter.db1.profile
            if not profile then return end
            profile.enemyFinder = profile.enemyFinder or {}
            profile.enemyFinder.position = { point = point, relative = relative, x = x, y = y }
        end,
        onShown = Enemy.Shown,
        onHidden = Enemy.Hidden,
    }
end

function SoundAlerter:RefreshEnemyFinder()
    Enemy.Refresh()
end

function SoundAlerter:IsEnemyFinderOpen()
    return Enemy.window ~= nil and Enemy.window.frame:IsShown()
end

function SoundAlerter:EnemyFinderCount()
    return Enemy.Count()
end

function SoundAlerter:ToggleEnemyFinder()
    if self:IsEnemyFinderOpen() then
        Enemy.window:Hide()
        return
    end
    if not Enemy.window then Enemy.window = SA_FinderWindow.Create(Enemy.Host()) end
    local window = Enemy.window
    local dialog = LibStub and LibStub("AceConfigDialog-3.0", true)
    local options = dialog and dialog.OpenFrames and dialog.OpenFrames["SoundAlerter"]
    local profile = self.db1 and self.db1.profile
    local saved = profile and profile.enemyFinder and profile.enemyFinder.position
    if options and options.frame then
        local spellFinderOpen = self.IsFinderOpen and self:IsFinderOpen() or false
        window:Dock(options.frame, spellFinderOpen)
        if not options.frame.saEnemyFinderHooked then
            options.frame.saEnemyFinderHooked = true
            options.frame:HookScript("OnHide", function()
                if Enemy.window then Enemy.window:Hide() end
            end)
        end
    elseif saved and saved.point then
        window:Place(saved.point, saved.relative, saved.x, saved.y)
    end
    window:Show()
end

SA_GlobalMap.Enemy = Enemy
end
