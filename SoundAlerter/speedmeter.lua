local SoundAlerter = SoundAlerter
local SpeedMeter = {}

local BarUtils = SoundAlerter.BarUtils
local Plain = SA_COMPAT.Plain

local math_floor = math.floor
local string_format = string.format

local DEFAULT_Y = -150
local UPDATE_INTERVAL = 0.1
local GRAB_PADDING = 4
local BASE_RUN = 7
local BASE_SWIM = 4.722222
local FONT_PATH = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local SETTING_KEYS = {
    enabled = true, locked = true, PositionX = true, PositionY = true,
    scale = true, fontSize = true, hideAtBaseline = true,
    boostColor = true, slowColor = true, baseColor = true,
}

local function usable(value)
    return type(value) == "number" and value > 0
end

function SpeedMeter.Evaluate(run, flight, swim, mounted, flying, swimming, current)
    local speed, base, mode
    if flying then
        speed, base, mode = flight, BASE_RUN, "flight"
    elseif swimming then
        speed, base, mode = swim, BASE_SWIM, "swim"
        if not usable(speed) and usable(current) then speed = current end
    else
        speed, base, mode = run, BASE_RUN, "run"
    end
    if type(speed) ~= "number" or speed <= 0 then return nil end

    local percent = math_floor(speed / base * 100 + 0.5)
    local tint = "plain"
    if not mounted and not flying then
        if percent > 100 then
            tint = "boost"
        elseif percent < 100 then
            tint = "slow"
        else
            tint = "base"
        end
    end
    return percent, mode, tint
end

local function ReadSpeeds()
    local current, run, flight, swim = GetUnitSpeed("player")
    return Plain(run), Plain(flight), Plain(swim), Plain(current)
end

local function flag(value)
    return Plain(value) == true
end

local function InWater()
    if flag(IsSwimming()) then return true end
    return IsSubmerged ~= nil and flag(IsSubmerged())
end

function SpeedMeter:Probe()
    local current, run, flight, swim = GetUnitSpeed("player")
    local function show(value)
        if Plain(value) == nil and value ~= nil then return "secret" end
        return tostring(value)
    end
    self.addon:Print(string_format("Speed probe: current %s, run %s, flight %s, swim %s", show(current), show(run), show(flight), show(swim)))
    self.addon:Print(string_format("Speed probe: swimming %s, submerged %s, flying %s, mounted %s", show(IsSwimming()), IsSubmerged and show(IsSubmerged()) or "missing", show(IsFlying()), show(IsMounted())))
    local percent, mode, tint = SpeedMeter.Evaluate(Plain(run), Plain(flight), Plain(swim), flag(IsMounted()), flag(IsFlying()), InWater(), Plain(current))
    self.addon:Print(string_format("Speed probe: the meter would show %s (%s, %s)", percent and (percent .. "%") or "--", tostring(mode), tostring(tint)))
end

function SpeedMeter:GetSettings()
    return self.db
end

function SpeedMeter:SetSetting(key, value)
    if not SETTING_KEYS[key] then
        error("SpeedMeter:SetSetting - unknown setting key '"..tostring(key).."'", 2)
    end
    self.db[key] = value
    self:LoadSettings()
end

function SpeedMeter:Attach()
    if self.attached then return end
    self.attached = true
    self.elapsed = UPDATE_INTERVAL
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        SpeedMeter.elapsed = SpeedMeter.elapsed + elapsed
        if SpeedMeter.elapsed >= UPDATE_INTERVAL then
            SpeedMeter.elapsed = 0
            SpeedMeter:Render()
        end
    end)
end

function SpeedMeter:Detach()
    if not self.attached then return end
    self.attached = false
    self.frame:SetScript("OnUpdate", nil)
end

function SpeedMeter:Render()
    local db, text = self.db, self.text
    if not db or not text then return end

    local percent, mode, tint
    if not db.locked then
        percent, tint = 100, "base"
    else
        local run, flight, swim, current = ReadSpeeds()
        percent, mode, tint = SpeedMeter.Evaluate(run, flight, swim, flag(IsMounted()), flag(IsFlying()), InWater(), current)
    end

    local label, color
    if not percent then
        label, color = "--", db.baseColor
    elseif tint == "boost" then
        label, color = string_format("%d%%", percent), db.boostColor
    elseif tint == "slow" then
        label, color = string_format("%d%%", percent), db.slowColor
    else
        label, color = string_format("%d%%", percent), db.baseColor
    end

    local visible = not (db.hideAtBaseline and db.locked and tint == "base")
    local last = self.last
    if last.visible ~= visible then
        last.visible = visible
        text:SetShown(visible)
    end
    if last.label ~= label then
        last.label = label
        text:SetText(label)
    end
    if last.r ~= color.r or last.g ~= color.g or last.b ~= color.b then
        last.r, last.g, last.b = color.r, color.g, color.b
        text:SetTextColor(color.r, color.g, color.b)
    end
end

function SpeedMeter:LoadSettings()
    local db, frame = self.db, self.frame
    if not db or not frame then return end

    self.last = {}
    frame:SetScale(db.scale)
    frame:SetSize(db.fontSize * 4, db.fontSize + GRAB_PADDING * 2)
    self.text:SetFont(FONT_PATH, db.fontSize, "OUTLINE")
    self.bg:SetShown(not db.locked)

    BarUtils:LoadPosition(frame, db, "", 0, DEFAULT_Y)
    BarUtils:UpdateVisibility(frame, db)

    if db.enabled then
        self:Attach()
        self:Render()
    else
        self:Detach()
    end
end

function SpeedMeter:ResetPosition()
    if not self.db then return end
    self.db.PositionX = 0
    self.db.PositionY = DEFAULT_Y
    self:LoadSettings()
end

function SpeedMeter:OnProfileChanged()
    local addon = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not addon then return end

    self.addon = addon
    self.db = addon.db1.profile.speedMeter

    if self.initialized then
        self:LoadSettings()
    end
end

function SpeedMeter:Initialize()
    if self.initialized then return end

    local addon = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not addon then
        error("SpeedMeter:Initialize() called before addon is ready")
        return
    end

    self.addon = addon
    self.db = addon.db1.profile.speedMeter
    self.last = {}

    self.dragProxy = setmetatable({}, {
        __index = function(_, key)
            local db = SpeedMeter.db
            return db and db[key]
        end,
    })

    self.frame = BarUtils:CreateContainerFrame("SoundAlerterSpeedMeter", self.db.fontSize * 4, self.db.fontSize + GRAB_PADDING * 2, DEFAULT_Y, self.dragProxy, function()
        BarUtils:SavePosition(SpeedMeter.frame, SpeedMeter.db, "")
    end, false)

    self.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
    self.bg:SetColorTexture(0, 0, 0, 0.45)

    self.text = BarUtils:CreateFontString(self.frame, self.db.fontSize, "OUTLINE")
    self.text:ClearAllPoints()
    self.text:SetPoint("CENTER", self.frame, "CENTER", 0, 0)

    self.initialized = true
    self:LoadSettings()
end

local function meter()
    return SoundAlerter.SpeedMeter
end

local SPEED_SAMPLES = { { 130, "boostColor" }, { 100, "baseColor" }, { 60, "slowColor" } }
local SpeedPreview = { height = 56 }

function SpeedPreview.build(stage)
    local state = { labels = {} }
    for index = 1, #SPEED_SAMPLES do
        local label = stage:CreateFontString(nil, "OVERLAY")
        label:SetPoint("CENTER", stage, "CENTER", (index - 2) * 78, 0)
        state.labels[index] = label
    end
    return state
end

function SpeedPreview.update(state, settings)
    for index = 1, #SPEED_SAMPLES do
        local sample = SPEED_SAMPLES[index]
        local label = state.labels[index]
        local color = settings[sample[2]]
        label:SetFont(FONT_PATH, math_floor(math.min(30, settings.fontSize * settings.scale)), "OUTLINE")
        label:SetTextColor(color.r, color.g, color.b)
        label:SetText(string_format("%d%%", sample[1]))
    end
end

function SoundAlerter:BuildSpeedMeterOptions()
    local Page = SoundAlerter.Page
    return Page.Module({
        key = "SpeedMeter",
        title = "Speed Meter",
        icon = "Interface\\Icons\\Ability_Rogue_Sprint",
        desc = "Your current movement speed as a percent of base run speed.",
        blurb = "Your movement speed as a percent of base run speed, tinted when something changes it.",
        order = 2.89,
        module = meter,
        defaults = function() return dbDefaults.profile.speedMeter end,
        summary = function(settings)
            return Page.Summary(settings,
                settings.locked and "locked" or "unlocked, drag to move",
                settings.hideAtBaseline and "hidden at base speed" or "always shown")
        end,
        preview = SpeedPreview,
        rows = {
            Page.Toggle("locked", "Lock position", "Unlock to drag the meter. A shaded outline and a 100% preview mark it while unlocked.", false, "General"),
            Page.Toggle("hideAtBaseline", "Hide at base speed", "Hide the number while you run or swim at exactly 100%, so it only shows when something changes your speed.", false, "General"),
            Page.Range("fontSize", "Font size", "Size of the number.", 8, 40, 1, false, "Look", " px"),
            Page.Color("boostColor", "Boosted color", "Above 100% on foot or swimming.", false, "Look"),
            Page.Color("slowColor", "Slowed color", "Below 100% on foot or swimming.", false, "Look"),
            Page.Range("scale", "Scale", "Overall size.", 0.5, 3, 0.05, true, "Look", "x"),
            Page.Color("baseColor", "Normal color", "Exactly 100%, mounted, flying, or no reading.", true, "Look"),
            Page.Action("Reset position", "Put the meter back where it started.", function()
                local active = meter()
                if active then active:ResetPosition() end
            end, true, "General"),
        },
    })
end

SoundAlerter.SpeedMeter = SpeedMeter
