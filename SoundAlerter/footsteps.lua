local SoundAlerter = SoundAlerter
local Footsteps = {}

local Model = SoundAlerter.FootstepsModel
local Plain = SA_COMPAT.Plain

local SAMPLE_INTERVAL = 0.25
local RENDER_INTERVAL = 0.05
local POOL_SIZE = 150
local TRAIL_CAP = 1500
local JUMP_YARDS = 100
local RELOAD_GRACE = 120
local EDGE_MARGIN = 0.95
local ZOOM_PROBE_QUIET = 0.5
local VOTE_WINDOW = 20
local VOTE_THRESHOLD = 0.5
local VOTE_MIN_STEP = 1
local MAP_POOL_SIZE = 400
local MAP_RENDER_EVERY = 2
local MAP_LAYER_LEVELS = 4000
local PLAYER_PIN_PATTERNS = { "GroupMembers", "UnitPosition", "PlayerArrow" }
local DOT_TEXTURE = "Interface\\AddOns\\SoundAlerter\\Textures\\circle.tga"
local ZOOM_EVENTS = { "MINIMAP_UPDATE_ZOOM", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED" }

local SETTING_KEYS = {
    enabled = true, showMinimap = true, showWorldMap = true, rotation = true, dotSize = true, color = true, spacing = true, ageFade = true,
}

local function show(value)
    if issecretvalue(value) then return "secret" end
    return tostring(value)
end

local function PositionFromUnit()
    if not UnitPosition then return nil end
    local ok, u, v, _, world = pcall(UnitPosition, "player")
    if not ok then return nil end
    u, v, world = Plain(u), Plain(v), Plain(world)
    if type(u) ~= "number" or type(v) ~= "number" then return nil end
    return u, v, world or 0
end

local function BestMap()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok then return nil end
    return Plain(mapID)
end

local function PositionFromMap(mapID)
    if not (mapID and C_Map and C_Map.GetPlayerMapPosition and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, u, v, world = pcall(function()
        local position = C_Map.GetPlayerMapPosition(mapID, "player")
        if not position then return nil end
        local x, y = position:GetXY()
        x, y = Plain(x), Plain(y)
        if type(x) ~= "number" or type(y) ~= "number" then return nil end
        local instance, worldPosition = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
        if not worldPosition then return nil end
        return worldPosition.x, worldPosition.y, instance
    end)
    if not ok or type(u) ~= "number" or type(v) ~= "number" then return nil end
    return u, v, world or 0
end

local function MapPosition(mapID)
    if not (mapID and C_Map and C_Map.GetPlayerMapPosition) then return nil end
    local ok, x, y = pcall(function()
        local position = C_Map.GetPlayerMapPosition(mapID, "player")
        if not position then return nil end
        return position:GetXY()
    end)
    x, y = Plain(x), Plain(y)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then return nil end
    if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    return x, y
end

local function WorldMap(allowHidden)
    local frame = WorldMapFrame
    if not frame or not (allowHidden or frame:IsShown()) then return nil end
    local canvas
    if frame.GetCanvas then
        canvas = frame:GetCanvas()
    elseif frame.ScrollContainer then
        canvas = frame.ScrollContainer.Child
    end
    if not canvas then return nil end
    local mapID
    if frame.GetMapID then mapID = frame:GetMapID() else mapID = frame.mapID end
    return canvas, mapID
end

local function PlayerPinLevel(canvas)
    if not canvas.GetChildren then return nil end
    local ok, level = pcall(function()
        local lowest
        for _, child in ipairs({ canvas:GetChildren() }) do
            local template = child.pinTemplate
            if type(template) == "string" and child.IsShown and child:IsShown() then
                for index = 1, #PLAYER_PIN_PATTERNS do
                    if template:find(PLAYER_PIN_PATTERNS[index], 1, true) then
                        local childLevel = child:GetFrameLevel()
                        if not lowest or childLevel < lowest then lowest = childLevel end
                        break
                    end
                end
            end
        end
        return lowest
    end)
    if not ok then return nil end
    return level
end

local function ReadPosition(withMap)
    local mapID = withMap and BestMap() or nil
    local u, v, world = PositionFromUnit()
    if not u then
        u, v, world = PositionFromMap(mapID or BestMap())
    end
    if not u then return nil end
    return u, v, world, mapID or 0
end

local function Unusable()
    if Plain(IsInInstance()) then return true end
    if UnitOnTaxi and Plain(UnitOnTaxi("player")) then return true end
    return false
end

local function ProbeIndoor(zoom)
    local ok, indoor = pcall(function()
        if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
            Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
        end
        local outdoor = tonumber(GetCVar("minimapZoom")) == Minimap:GetZoom()
        Minimap:SetZoom(zoom)
        return not outdoor
    end)
    return ok and indoor or false
end

local function ViewRadius()
    if not (C_Minimap and C_Minimap.GetViewRadius) then return nil end
    local ok, yards = pcall(C_Minimap.GetViewRadius)
    yards = ok and Plain(yards) or nil
    if type(yards) ~= "number" or yards <= 0 then return nil end
    return yards
end

local function CompassShown()
    local compass = MinimapCompassTexture
    if not compass or not compass.IsShown then return false end
    local ok, shown = pcall(compass.IsShown, compass)
    return ok and shown and true or false
end

local function MinimapRotates(setting)
    if setting == "rotate" then return true end
    if setting == "fixed" then return false end
    return GetCVar("rotateMinimap") == "1"
end

local function Ask(object, method, ...)
    if not object or not object[method] then return "n/a" end
    local ok, first, second = pcall(object[method], object, ...)
    if not ok then return "error" end
    if second ~= nil then return show(first)..","..show(second) end
    return show(first)
end

local function Now()
    return GetServerTime()
end

function Footsteps:GetSettings()
    return self.db
end

function Footsteps:SetSetting(key, value)
    if not SETTING_KEYS[key] then
        error("Footsteps:SetSetting - unknown setting key '"..tostring(key).."'", 2)
    end
    self.db[key] = value
    self:LoadSettings()
end

function Footsteps:GetCount()
    return self.trail and Model.Count(self.trail) or 0
end

function Footsteps:GetDot(index)
    local dot = self.dots[index]
    if dot then return dot end
    dot = self.canvas:CreateTexture(nil, "OVERLAY")
    dot:SetTexture(DOT_TEXTURE)
    local db = self.db
    dot:SetSize(db.dotSize, db.dotSize)
    dot:SetVertexColor(db.color.r, db.color.g, db.color.b)
    self.dots[index] = dot
    return dot
end

function Footsteps:HideDots(from)
    local dots = self.dots
    for index = from + 1, self.shown do
        dots[index]:Hide()
    end
    self.shown = from
end

function Footsteps:Sample()
    local trail = self.trail
    if Unusable() then
        Model.Break(trail)
        return
    end
    local u, v, world, mapID = ReadPosition(true)
    if not u then
        Model.Break(trail)
        self.previous = nil
        return
    end
    self:Calibrate(u, v, world)
    local nx, ny = MapPosition(mapID)
    Model.Add(trail, u, v, world, mapID, self.db.spacing, JUMP_YARDS, nx, ny)
    trail.savedAt = Now()
end

function Footsteps:Calibrate(u, v, world)
    local previous = self.previous
    self.previous = previous or {}
    previous = self.previous
    local lastU, lastV, lastWorld = previous.u, previous.v, previous.world
    previous.u, previous.v, previous.world = u, v, world
    if not lastU or lastWorld ~= world then return end

    local facing = GetPlayerFacing and Plain(GetPlayerFacing())
    if type(facing) ~= "number" then return end
    local du, dv = u - lastU, v - lastV
    if du * du + dv * dv < VOTE_MIN_STEP * VOTE_MIN_STEP then return end
    if du * du + dv * dv > JUMP_YARDS * JUMP_YARDS then return end

    Model.Vote(self.votes, du, dv, facing)
    local picked = Model.Pick(self.votes, VOTE_WINDOW, VOTE_THRESHOLD)
    if picked then
        self.trail.axes = picked
        self.mapping = Model.MAPPINGS[picked]
    end
end

function Footsteps:UpdateRadius(zoom)
    self.probedAt = GetTime()
    self.zoom = zoom
    self.radiusYards = Model.RadiusYards(zoom, ProbeIndoor(zoom))
    self.zoomDirty = false
end

function Footsteps:HideMapDots(from)
    local dots = self.mapDots
    for index = from + 1, self.mapShown do
        dots[index]:Hide()
    end
    self.mapShown = from
end

function Footsteps:RenderMap()
    local db = self.db
    local ok, canvas, mapID = pcall(WorldMap)
    if not ok or not canvas or type(mapID) ~= "number" or not db.showWorldMap then
        self.mapChanged = true
        self:HideMapDots(0)
        return
    end

    if self.mapLayerParent ~= canvas then
        self:HideMapDots(0)
        self.mapDots = {}
        self.mapLayerParent = canvas
        self.mapLayer = CreateFrame("Frame", nil, canvas)
        self.mapLayer:SetAllPoints(canvas)
        self.mapLevel = nil
        self.mapChanged = true
    end

    local canvasLevel = canvas:GetFrameLevel()
    local pinLevel = PlayerPinLevel(canvas)
    local level = canvasLevel + MAP_LAYER_LEVELS
    if pinLevel then level = math.max(canvasLevel + 1, pinLevel - 1) end
    if level ~= self.mapLevel then
        self.mapLevel = level
        self.mapLayer:SetFrameLevel(level)
    end

    local width, height, scale = canvas:GetWidth(), canvas:GetHeight(), canvas:GetEffectiveScale()
    local trail = self.trail
    if not self.mapChanged and self.mapRev == trail.rev and self.mapID == mapID
        and self.mapWidth == width and self.mapHeight == height and self.mapScale == scale then
        return
    end
    self.mapChanged = false
    self.mapRev, self.mapID, self.mapWidth, self.mapHeight, self.mapScale = trail.rev, mapID, width, height, scale

    local found = Model.GatherMap(trail, mapID, MAP_POOL_SIZE, db.ageFade, self.mapOut)
    local size = db.dotSize * UIParent:GetEffectiveScale() / (scale > 0.01 and scale or 1)
    local color = db.color
    local xs, ys, alphas = self.mapOut.x, self.mapOut.y, self.mapOut.a
    local dots, layer = self.mapDots, self.mapLayer
    for index = 1, found do
        local dot = dots[index]
        if not dot then
            dot = layer:CreateTexture(nil, "OVERLAY")
            dot:SetTexture(DOT_TEXTURE)
            dots[index] = dot
        end
        dot:SetSize(size, size)
        dot:SetVertexColor(color.r, color.g, color.b)
        dot:SetAlpha(alphas[index])
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", layer, "TOPLEFT", xs[index] * width, -ys[index] * height)
        dot:Show()
    end
    if found > self.mapShown then self.mapShown = found end
    self:HideMapDots(found)
end

function Footsteps:ToggleMapMarker()
    local dot = self.mapDots[1]
    if not dot or self.mapShown == 0 then
        self.addon:Print("|cffFF7D0AFootsteps|r: open the world map with a trail on it first")
        return
    end
    if not self.marker then
        local marker = CreateFrame("Frame", nil, UIParent)
        marker:SetFrameStrata("TOOLTIP")
        marker:SetSize(24, 24)
        local fill = marker:CreateTexture(nil, "OVERLAY")
        fill:SetAllPoints(marker)
        fill:SetColorTexture(1, 0, 1, 1)
        marker:Hide()
        self.marker = marker
    end
    if self.marker:IsShown() then
        self.marker:Hide()
        return
    end
    self.marker:ClearAllPoints()
    self.marker:SetPoint("CENTER", dot, "CENTER", 0, 0)
    self.marker:Show()
end

function Footsteps:Render()
    self:RenderMinimap()
    self.mapTick = self.mapTick + 1
    if self.mapTick >= MAP_RENDER_EVERY then
        self.mapTick = 0
        self:RenderMap()
    end
end

function Footsteps:RenderMinimap()
    local db = self.db
    if not db.showMinimap or not Minimap:IsVisible() or Unusable() then
        self:HideDots(0)
        return
    end

    local radiusYards = ViewRadius()
    if not radiusYards then
        local zoom = Minimap:GetZoom()
        if self.zoomDirty or zoom ~= self.zoom then
            self:UpdateRadius(zoom)
        end
        radiusYards = self.radiusYards
    end
    local u, v, world = ReadPosition(false)
    if not radiusYards or not u then
        self:HideDots(0)
        return
    end

    local rotate = MinimapRotates(db.rotation)
    local facing = rotate and Plain(GetPlayerFacing()) or nil
    local out = self.out
    local found = Model.Gather(self.trail, u, v, world, facing, rotate and facing ~= nil, radiusYards * EDGE_MARGIN, POOL_SIZE, db.ageFade, out, self.mapping)

    local scale = (Minimap:GetWidth() / 2) / radiusYards
    local xs, ys, alphas = out.x, out.y, out.a
    local canvas = self.canvas
    for index = 1, found do
        local dot = self:GetDot(index)
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", canvas, "CENTER", xs[index] * scale, ys[index] * scale)
        dot:SetAlpha(alphas[index])
        if index > self.shown then dot:Show() end
    end
    if found > self.shown then self.shown = found end
    self:HideDots(found)
end

function Footsteps:Attach()
    if self.attached then return end
    self.attached = true
    self.sampleElapsed = SAMPLE_INTERVAL
    self.renderElapsed = RENDER_INTERVAL
    self.driver:SetScript("OnUpdate", function(_, elapsed)
        local active = Footsteps
        active.sampleElapsed = active.sampleElapsed + elapsed
        if active.sampleElapsed >= SAMPLE_INTERVAL then
            active.sampleElapsed = 0
            active:Sample()
        end
        active.renderElapsed = active.renderElapsed + elapsed
        if active.renderElapsed >= RENDER_INTERVAL then
            active.renderElapsed = 0
            active:Render()
        end
    end)
end

function Footsteps:Detach()
    if not self.attached then return end
    self.attached = false
    self.driver:SetScript("OnUpdate", nil)
    self:HideDots(0)
    self:HideMapDots(0)
end

function Footsteps:LoadSettings()
    local db = self.db
    if not db or not self.driver then return end

    local color = db.color
    for index = 1, #self.dots do
        local dot = self.dots[index]
        dot:SetSize(db.dotSize, db.dotSize)
        dot:SetVertexColor(color.r, color.g, color.b)
    end

    self.mapChanged = true
    if db.enabled then
        self.zoomDirty = true
        self:Attach()
    else
        self:Detach()
    end
end

function Footsteps:ClearTrail()
    if not self.trail then return end
    Model.Clear(self.trail)
    self:HideDots(0)
    self:HideMapDots(0)
end

function Footsteps:OnEnterWorld(isInitialLogin, isReloadingUi)
    if not self.initialized then return end
    self.lastFlags = { isInitialLogin, isReloadingUi }
    if not self.entered then
        self.entered = true
        local action = Model.RestoreAction(isInitialLogin, isReloadingUi, self.trail.savedAt, Now(), RELOAD_GRACE)
        self.lastAction = action
        if action == "clear" then Model.Clear(self.trail) end
    end
    Model.Break(self.trail)
    self.zoomDirty = true
end

function Footsteps:OnProfileChanged()
    local addon = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not addon then return end

    self.addon = addon
    self.db = addon.db1.profile.footsteps

    if self.initialized then
        self:LoadSettings()
    end
end

function Footsteps:PrintHelp()
    self.addon:Print("  |cffFFFFFF/sa footsteps clear|r - Erase the footsteps trail; |cffFFFFFF/sa footsteps debug|r prints what the client reports; |cffFFFFFF/sa footsteps maptest|r marks the newest world map dot")
end

function Footsteps:Debug()
    local print = function(text) self.addon:Print(text) end
    local rawU, rawV, rawZ, rawW = nil, nil, nil, nil
    if UnitPosition then
        local ok, a, b, c, d = pcall(UnitPosition, "player")
        if ok then rawU, rawV, rawZ, rawW = a, b, c, d else rawU = "error: "..tostring(a) end
    end
    local mapID = BestMap()
    local mu, mv, mworld = PositionFromMap(mapID)
    local zoom = Minimap:GetZoom()
    print("|cffFFD700=== Footsteps ===|r")
    print("UnitPosition: "..show(rawU)..", "..show(rawV)..", "..show(rawZ)..", "..show(rawW))
    print("Best map: "..show(mapID).."  C_Map position as world (first, second, instance): "..show(mu)..", "..show(mv)..", "..show(mworld))
    print("Facing: "..show(GetPlayerFacing and GetPlayerFacing()).."  rotateMinimap: "..show(GetCVar("rotateMinimap")))
    print("Zoom: "..show(zoom).."  minimapZoom: "..show(GetCVar("minimapZoom")).."  minimapInsideZoom: "..show(GetCVar("minimapInsideZoom")))
    print("View radius: "..show(ViewRadius()).."  table radius: "..show(self.radiusYards).."  minimap width: "..show(Minimap:GetWidth()).."  compass shown: "..show(CompassShown()).."  rotates: "..show(MinimapRotates(self.db.rotation)).."  ignored: "..show(C_Minimap and C_Minimap.IsRotateMinimapIgnored and C_Minimap.IsRotateMinimapIgnored()))
    print("In instance: "..show(Plain(IsInInstance())).."  on taxi: "..show(UnitOnTaxi and Plain(UnitOnTaxi("player"))))
    local flags = self.lastFlags or {}
    print("Entering world flags: initialLogin="..show(flags[1]).." reloadingUi="..show(flags[2]).."  restore: "..show(self.lastAction))
    print("Trail: "..self:GetCount().." points, segment "..show(self.trail.seg).."  server time: "..show(Now()).."  saved at: "..show(self.trail.savedAt))
    local okMap, mapCanvas, shownMap = pcall(WorldMap, true)
    local mapNx, mapNy = MapPosition(mapID)
    print("World map frame: "..show(WorldMapFrame ~= nil).."  canvas: "..show(okMap and mapCanvas ~= nil).."  displayed map: "..show(okMap and shownMap).."  player on map: "..show(mapNx)..", "..show(mapNy).."  GetCanvas: "..show(WorldMapFrame and WorldMapFrame.GetCanvas ~= nil).."  ScrollContainer: "..show(WorldMapFrame and WorldMapFrame.ScrollContainer ~= nil))
    local layer, firstDot = self.mapLayer, self.mapDots[1]
    local drawable = Model.GatherMap(self.trail, type(shownMap) == "number" and shownMap or -1, MAP_POOL_SIZE, false, { x = {}, y = {}, a = {} })
    print("Map steps: with map position "..Model.CountWithMap(self.trail).." of "..self:GetCount().."  drawable on displayed map "..drawable.."  drawn "..self.mapShown.."  show setting: "..show(self.db.showWorldMap))
    print("Map layer: level "..show(layer and layer:GetFrameLevel()).."  canvas level "..show(okMap and mapCanvas and mapCanvas:GetFrameLevel()).."  canvas size "..show(okMap and mapCanvas and mapCanvas:GetWidth())..", "..show(okMap and mapCanvas and mapCanvas:GetHeight()).."  scale "..show(okMap and mapCanvas and mapCanvas:GetScale()).."  first dot shown "..show(firstDot and firstDot:IsShown()).." alpha "..show(firstDot and firstDot:GetAlpha()).." size "..show(firstDot and firstDot:GetWidth()))
    local scrollContainer = WorldMapFrame and WorldMapFrame.ScrollContainer
    print("Map geometry: layer shown "..Ask(layer, "IsShown").." visible "..Ask(layer, "IsVisible").." size "..Ask(layer, "GetWidth")..","..Ask(layer, "GetHeight").." strata "..Ask(layer, "GetFrameStrata").." alpha "..Ask(layer, "GetEffectiveAlpha").."  canvas strata "..Ask(mapCanvas, "GetFrameStrata").." visible "..Ask(mapCanvas, "IsVisible"))
    print("Map positions: dot visible "..Ask(firstDot, "IsVisible").." center "..Ask(firstDot, "GetCenter").." texture "..Ask(firstDot, "GetTexture").." layer "..Ask(firstDot, "GetDrawLayer").."  canvas center "..Ask(mapCanvas, "GetCenter").."  scroll container center "..Ask(scrollContainer, "GetCenter").." size "..Ask(scrollContainer, "GetWidth")..","..Ask(scrollContainer, "GetHeight").."  map frame scale "..Ask(WorldMapFrame, "GetEffectiveScale").." canvas effective scale "..Ask(mapCanvas, "GetEffectiveScale"))
    local pinLevel = okMap and mapCanvas and PlayerPinLevel(mapCanvas)
    print("Player pin level: "..show(pinLevel).."  layer level "..show(layer and layer:GetFrameLevel()))
    if okMap and mapCanvas and mapCanvas.GetChildren then
        local line = "Canvas children (level template):"
        local children = { mapCanvas:GetChildren() }
        for index = 1, math.min(#children, 40) do
            local child = children[index]
            local entry = " "..show(child:GetFrameLevel()).." "..show(child.pinTemplate or (child.GetName and child:GetName()) or child:GetObjectType())..(child:IsShown() and "" or "(hidden)")..";"
            if #line + #entry > 200 then
                print(line)
                line = "  "
            end
            line = line..entry
        end
        print(line)
    end
    print("Axis mapping: "..show(self.trail.axes).." of "..#Model.MAPPINGS.."  learned from "..show(self.votes.count).." of "..VOTE_WINDOW.." movement samples in this window")
end

function Footsteps:HandleCommand(input)
    local command = (input or ""):match("^(%S*)"):lower()
    if command == "clear" then
        self:ClearTrail()
        self.addon:Print("|cffFF7D0AFootsteps|r: trail cleared")
    elseif command == "debug" then
        self:Debug()
    elseif command == "maptest" then
        self:ToggleMapMarker()
    else
        self:PrintHelp()
    end
end

function Footsteps:Initialize()
    if self.initialized then return end

    local addon = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not addon then
        error("Footsteps:Initialize() called before addon is ready")
        return
    end

    self.addon = addon
    self.db = addon.db1.profile.footsteps

    local store = addon.db1.char.footsteps
    if type(store) ~= "table" then
        store = {}
        addon.db1.char.footsteps = store
    end
    self.trail = Model.Init(store, TRAIL_CAP)
    self.mapping = Model.MAPPINGS[self.trail.axes]
    self.votes = Model.NewVotes()

    self.dots = {}
    self.shown = 0
    self.out = { x = {}, y = {}, a = {} }
    self.mapOut = { x = {}, y = {}, a = {} }
    self.mapDots = {}
    self.mapShown = 0
    self.mapTick = 0
    self.zoomDirty = true
    self.probedAt = 0

    self.driver = CreateFrame("Frame")
    self.canvas = CreateFrame("Frame", "SoundAlerterFootsteps", Minimap)
    self.canvas:SetAllPoints(Minimap)
    self.canvas:SetFrameLevel(Minimap:GetFrameLevel() + 2)

    self.events = CreateFrame("Frame")
    self.events:SetScript("OnEvent", function()
        if GetTime() - Footsteps.probedAt >= ZOOM_PROBE_QUIET then
            Footsteps.zoomDirty = true
        end
    end)
    for _, event in ipairs(ZOOM_EVENTS) do
        pcall(self.events.RegisterEvent, self.events, event)
    end

    self.initialized = true
    self:LoadSettings()
end

local function module()
    return SoundAlerter.Footsteps
end

local function apply(key, value)
    local active = module()
    if not active then return end
    active:SetSetting(key, value)
end

local function disabled()
    local active = module()
    return not active or not active:GetSettings().enabled
end

local function toggle(order, name, desc, key)
    return {
        type = 'toggle',
        name = name,
        desc = desc,
        get = function() return module():GetSettings()[key] end,
        set = function(_, value) apply(key, value) end,
        disabled = disabled,
        width = "full",
        order = order,
    }
end

local function range(order, name, desc, key, min, max, step)
    return {
        type = 'range',
        name = name,
        desc = desc,
        min = min,
        max = max,
        step = step,
        get = function() return module():GetSettings()[key] end,
        set = function(_, value) apply(key, value) end,
        disabled = disabled,
        order = order,
    }
end

function SoundAlerter:BuildFootstepsOptions()
    return {
        type = 'group',
        name = "Footsteps",
        icon = "Interface\\Icons\\Ability_Tracking",
        desc = "A dotted trail on the minimap showing the path you have walked.",
        order = 2.91,
        args = {
            description = {
                type = 'description',
                name = "|cffFFD700Footsteps|r\n\n" ..
                       "Draws a dotted trail on the minimap and on the zone map along the path you have walked. It survives /reload and is erased when you log in again. " ..
                       "Nothing is recorded inside instances, battlegrounds or on flight paths, and a teleport starts a new stretch instead of drawing a line across the gap. " ..
                       "Only the newest 1500 steps are kept. Disabled by default.\n",
                fontSize = "medium",
                order = 1,
            },

            initErrorWarning = {
                type = 'description',
                name = function()
                    return "|cffFF0000Footsteps failed to initialize this session:|r\n" ..
                           tostring(SoundAlerter.moduleInitErrors and SoundAlerter.moduleInitErrors.Footsteps) ..
                           "\n\n|cffFFFFFFToggles below will not take effect until this is fixed and you /reload.|r\n"
                end,
                fontSize = "medium",
                order = 1.5,
                hidden = function() return SoundAlerter.Footsteps ~= nil end,
            },

            generalGroup = {
                type = 'group',
                inline = true,
                name = "General",
                order = 2,
                args = {
                    enabled = {
                        type = 'toggle',
                        name = "Enable Footsteps",
                        get = function() return module():GetSettings().enabled end,
                        set = function(_, value) apply("enabled", value) end,
                        width = "full",
                        order = 1,
                    },
                    showMinimap = toggle(2, "Show On Minimap", "Draw the trail on the minimap. Turn off to keep recording without drawing.", "showMinimap"),
                    showWorldMap = toggle(2.5, "Show On World Map", "Draw the trail on the world map when it shows the zone you walked in.", "showWorldMap"),
                    status = {
                        type = 'description',
                        name = function()
                            local active = module()
                            return "Trail: " .. (active and active:GetCount() or 0) .. " steps"
                        end,
                        order = 3,
                    },
                    clear = {
                        type = 'execute',
                        name = "Clear Trail",
                        desc = "Erase every recorded step.",
                        func = function()
                            if module() then module():ClearTrail() end
                        end,
                        disabled = function() return not module() end,
                        order = 4,
                    },
                },
            },

            appearanceGroup = {
                type = 'group',
                inline = true,
                name = "Appearance",
                order = 3,
                args = {
                    dotSize = range(1, "Dot Size", "Size of each dot in pixels.", "dotSize", 2, 16, 1),
                    spacing = range(2, "Spacing", "Distance in yards between two dots.", "spacing", 1, 10, 0.5),
                    rotation = {
                        type = 'select',
                        name = "Minimap Rotation",
                        desc = "Automatic follows the game's setting. If the trail drifts while you turn, pick Rotating or Fixed north to match your minimap.",
                        values = { auto = "Automatic", rotate = "Rotating", fixed = "Fixed north" },
                        get = function() return module():GetSettings().rotation end,
                        set = function(_, value) apply("rotation", value) end,
                        disabled = disabled,
                        order = 3.5,
                    },
                    ageFade = toggle(3, "Fade With Age", "Older dots are fainter, so the direction you came from is easy to read.", "ageFade"),
                    color = {
                        type = 'color',
                        name = "Dot Color",
                        get = function()
                            local c = module():GetSettings().color
                            return c.r, c.g, c.b
                        end,
                        set = function(_, r, g, b) apply("color", { r = r, g = g, b = b }) end,
                        disabled = disabled,
                        order = 4,
                    },
                },
            },
        },
    }
end

SoundAlerter.Footsteps = Footsteps
