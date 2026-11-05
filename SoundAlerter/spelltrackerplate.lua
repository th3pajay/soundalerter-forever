local Plate = { plate = false, on = false, behind = false, batching = false, dirty = false, width = 0, height = 0 }

local Plain = SA_COMPAT.Plain
local GetTime = GetTime
local PLATE_EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "NAME_PLATE_UNIT_BEHIND_CAMERA_CHANGED" }
local LAYER_LIFT = 5
local MIN_TEXT = 8
local TEXT_RATIO = 0.45
local AURA_ROWS = { "AurasFrame", "BuffFrame", "AuraFrame" }

local pool, order = {}, {}

local function Region(object)
    if type(object) == "table" and type(object.GetObjectType) == "function" then return object end
    return nil
end

local function PlateFor(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and Region(plate) then return plate end
    return nil
end

local function Anchor(plate)
    local unitFrame = Region(plate.UnitFrame)
    if not unitFrame then return plate end
    for _, key in ipairs(AURA_ROWS) do
        local row = Region(unitFrame[key])
        if row then return row end
    end
    local name = Region(unitFrame.name)
    if name then return name end
    local container = Region(unitFrame.HealthBarsContainer)
    return container and (Region(container.healthBar) or container) or plate
end

local function Candidate(config)
    return config ~= nil and config.enabled == true and config.unit == "target" and config.onPlate == true
end

local function KeyOf(state, index)
    if not state:IsActive(index) then return false end
    return state:Expiration(index) or true
end

local function Forget(frame)
    frame.plateX, frame.plateAlpha, frame.plateShown, frame.plateKey = nil, nil, nil, nil
end

local function Conceal(frame)
    if frame.plateShown == false then return end
    frame.plateShown = false
    frame:Hide()
end

local function OnEvent(_, event, unit, behind)
    Plate:OnEvent(event, unit, behind)
end

function Plate:Setup(tracker)
    self.tracker = tracker
    self.holder = CreateFrame("Frame", nil, UIParent)
    self.holder:SetSize(1, 1)
    self.holder:Hide()
    self.events = CreateFrame("Frame")
    self.events:SetScript("OnEvent", OnEvent)
    self.listening = false
end

function Plate:Owns(config)
    return self.on and Candidate(config)
end

function Plate:Holds(config)
    return self.plate ~= false and self:Owns(config)
end

function Plate:Wanted()
    local tracker = self.tracker
    if not (tracker and tracker.db and tracker.db.plateEnabled) then return false end
    for _, config in ipairs(tracker.db.icons) do
        if Candidate(config) then return true end
    end
    return false
end

function Plate:Listen(on)
    if self.listening == on then return end
    self.listening = on
    local events = self.events
    for _, event in ipairs(PLATE_EVENTS) do
        pcall(on and events.RegisterEvent or events.UnregisterEvent, events, event)
    end
end

function Plate:Refresh()
    if not self.tracker then return end
    local wanted = self:Wanted()
    local changed = wanted ~= self.on
    self.on = wanted
    self:Listen(wanted)
    if self:Resolve() then return end
    if self.plate then
        self:Place()
        self:Layout()
    elseif changed then
        self:Restore()
    end
end

function Plate:Resolve()
    local plate = self.on and not self.behind and PlateFor("target") or false
    return self:Set(plate)
end

function Plate:Place()
    local plate = self.plate
    if not plate then return end
    local holder, db = self.holder, self.tracker.db
    local strata, level = Plain(plate:GetFrameStrata()), Plain(plate:GetFrameLevel())
    if type(strata) == "string" then holder:SetFrameStrata(strata) end
    if type(level) == "number" then holder:SetFrameLevel(level + LAYER_LIFT) end
    holder:ClearAllPoints()
    holder:SetPoint("BOTTOM", Anchor(plate), "TOP", 0, db.plateOffset or 0)
    local follow = db.plateFollowScale ~= false
    holder:SetIgnoreParentScale(not follow)
    holder:SetScale(follow and 1 or UIParent:GetScale())
end

function Plate:Restore()
    local tracker = self.tracker
    local icons, frames = tracker.db.icons, tracker.frames
    for index = 1, #icons do
        local frame = frames[index]
        if frame and Candidate(icons[index]) then
            Forget(frame)
            tracker:RestoreIcon(index)
        end
    end
end

function Plate:Release()
    local tracker, holder = self.tracker, self.holder
    for _, frame in ipairs(tracker.frames) do
        if frame.onPlate then
            frame.onPlate = nil
            frame:SetParent(tracker.container)
            frame:ClearAllPoints()
            frame.lastPosition = nil
        end
    end
    holder:Hide()
    holder:ClearAllPoints()
    holder:SetParent(UIParent)
    self:Restore()
end

function Plate:Set(plate)
    local old = self.plate
    if plate == old then return false end
    self.plate = plate
    if not plate then
        self:Release()
        return true
    end
    self.holder:SetParent(plate)
    self:Place()
    if old then return true end
    self.holder:Show()
    self:Layout()
    return true
end

function Plate:Begin()
    self.batching = true
end

function Plate:Finish()
    self.batching = false
    if self.dirty then self:Layout() end
end

function Plate:Touch(index)
    if not self.plate then return end
    local tracker = self.tracker
    if index then
        if not self:Owns(tracker.db.icons[index]) then return end
        local frame = tracker.frames[index]
        if frame and frame.plateKey == KeyOf(tracker.state, index) then return end
    end
    if self.batching then
        self.dirty = true
        return
    end
    self:Layout()
end

function Plate:Layout()
    self.dirty = false
    if not self.plate then return end
    local tracker = self.tracker
    local db, frames, state = tracker.db, tracker.frames, tracker.state
    local icons, now, count = db.icons, GetTime(), 0
    for index = 1, #icons do
        local frame = frames[index]
        if frame then
            local owned = self:Owns(icons[index])
            if frame.onPlate and not owned then
                frame.onPlate = nil
                Forget(frame)
                frame:SetParent(tracker.container)
                frame:ClearAllPoints()
                frame.lastPosition = nil
                tracker:SetFramePosition(frame, index)
            elseif owned and not frame.exiting then
                local active = state:IsActive(index)
                frame.plateKey = active and (state:Expiration(index) or true) or false
                local shown, alpha = tracker:DetermineVisibility(index, active)
                if shown then
                    count = count + 1
                    local entry = pool[count]
                    if not entry then
                        entry = {}
                        pool[count] = entry
                    end
                    entry.index, entry.active, entry.alpha = index, active, alpha
                    entry.left = active and state:Remaining(index, now) or nil
                    order[count] = entry
                else
                    Conceal(frame)
                end
            end
        end
    end
    for k = count + 1, #order do order[k] = nil end

    local shown, width, height = SA_TrackerModel.PlateRow(order, db.plateMax or 4, db.plateSize or 24, db.plateSpacing or 0, SA_TrackerModel.PLATE_LEAD)
    local holder = self.holder
    width, height = math.max(width, 1), math.max(height, 1)
    if width ~= self.width or height ~= self.height then
        self.width, self.height = width, height
        holder:SetSize(width, height)
    end
    for k = 1, count do
        local entry = order[k]
        local frame = frames[entry.index]
        if k <= shown then
            local x, size = entry.x, entry.size
            if not frame.onPlate then
                frame.onPlate = true
                frame.plateX = nil
                frame.lastPosition = nil
                frame:SetParent(holder)
                frame:EnableMouse(false)
            end
            if frame.plateX ~= x then
                frame.plateX = x
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", x, 0)
            end
            tracker:SizeIcon(frame, size, math.min(icons[entry.index].cooldownTextSize or size, math.max(MIN_TEXT, math.floor(size * TEXT_RATIO))))
            if frame.plateAlpha ~= entry.alpha then
                frame.plateAlpha = entry.alpha
                frame:SetAlpha(entry.alpha)
            end
            if frame.plateShown ~= true then
                frame.plateShown = true
                frame:Show()
            end
        else
            Conceal(frame)
        end
    end
end

function Plate:OnEvent(event, unit, behind)
    if event == "NAME_PLATE_UNIT_REMOVED" then
        if not self.plate then return end
        local gone = PlateFor(unit)
        if gone then
            if gone == self.plate then self:Set(false) end
            return
        end
        self:Resolve()
    elseif event == "NAME_PLATE_UNIT_BEHIND_CAMERA_CHANGED" then
        local plate = PlateFor(unit)
        if not plate then return end
        if self.plate then
            if plate ~= self.plate then return end
        elseif not self.behind or plate ~= PlateFor("target") then
            return
        end
        self.behind = Plain(behind) == true
        self:Resolve()
    elseif not self.plate then
        self:Resolve()
    end
end

function Plate:TargetChanged()
    self.behind = false
    if self.on then self:Resolve() end
end

SA_TrackerPlate = Plate
