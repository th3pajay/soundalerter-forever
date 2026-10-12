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

function SpeedMeter.Evaluate(run, flight, swim, mounted, flying, swimming)
    local speed, base, mode
    if flying then
        speed, base, mode = flight, BASE_RUN, "flight"
    elseif swimming then
        speed, base, mode = swim, BASE_SWIM, "swim"
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
    local _, run, flight, swim = GetUnitSpeed("player")
    return Plain(run), Plain(flight), Plain(swim)
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
        local run, flight, swim = ReadSpeeds()
        percent, mode, tint = SpeedMeter.Evaluate(run, flight, swim, IsMounted(), IsFlying(), IsSwimming())
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

local function apply(key, value)
    local active = meter()
    if not active then return end
    active:SetSetting(key, value)
end

local function disabled()
    local active = meter()
    return not active or not active:GetSettings().enabled
end

local function range(order, name, desc, key, min, max, step)
    return {
        type = 'range',
        name = name,
        desc = desc,
        min = min,
        max = max,
        step = step,
        get = function() return meter():GetSettings()[key] end,
        set = function(_, value) apply(key, value) end,
        disabled = disabled,
        order = order,
    }
end

local function toggle(order, name, desc, key)
    return {
        type = 'toggle',
        name = name,
        desc = desc,
        get = function() return meter():GetSettings()[key] end,
        set = function(_, value) apply(key, value) end,
        disabled = disabled,
        width = "full",
        order = order,
    }
end

local function color(order, name, desc, key)
    return {
        type = 'color',
        name = name,
        desc = desc,
        get = function()
            local c = meter():GetSettings()[key]
            return c.r, c.g, c.b
        end,
        set = function(_, r, g, b) apply(key, { r = r, g = g, b = b }) end,
        disabled = disabled,
        order = order,
    }
end

function SoundAlerter:BuildSpeedMeterOptions()
    local options = {
        type = 'group',
        name = "Speed Meter",
        icon = "Interface\\Icons\\Ability_Rogue_Sprint",
        desc = "Your current movement speed as a percent of base run speed.",
        order = 2.89,
        args = {
            description = {
                type = 'description',
                name = "|cffFFD700Speed Meter|r\n\n" ..
                       "Shows your movement speed as a percent of base run speed, including talents, buffs, slows and gear. " ..
                       "It follows how you move: running, swimming or flying. On foot and swimming it turns green above 100% and red below it. " ..
                       "Mounted and flying show the number without a tint, since a mount is not a temporary boost. " ..
                       "Unlock to drag it into position. Disabled by default.\n",
                fontSize = "medium",
                order = 1,
            },

            initErrorWarning = {
                type = 'description',
                name = function()
                    return "|cffFF0000Speed Meter failed to initialize this session:|r\n" ..
                           tostring(SoundAlerter.moduleInitErrors and SoundAlerter.moduleInitErrors.SpeedMeter) ..
                           "\n\n|cffFFFFFFToggles below will not take effect until this is fixed and you /reload.|r\n"
                end,
                fontSize = "medium",
                order = 1.5,
                hidden = function() return SoundAlerter.SpeedMeter ~= nil end,
            },

            generalGroup = {
                type = 'group',
                inline = true,
                name = "General",
                order = 2,
                args = {
                    enabled = {
                        type = 'toggle',
                        name = "Enable Speed Meter",
                        get = function() return meter():GetSettings().enabled end,
                        set = function(_, value) apply("enabled", value) end,
                        width = "full",
                        order = 1,
                    },
                    locked = toggle(2, "Lock Position", "Unlock to drag the meter. A shaded outline and a 100% preview mark it while unlocked.", "locked"),
                    hideAtBaseline = toggle(3, "Hide At Base Speed", "Hide the number while you run or swim at exactly 100%, so it only shows when something changes your speed.", "hideAtBaseline"),
                    resetPosition = {
                        type = 'execute',
                        name = "Reset Position",
                        func = function()
                            if meter() then meter():ResetPosition() end
                        end,
                        disabled = disabled,
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
                    fontSize = range(1, "Font Size", "Size of the number.", "fontSize", 8, 40, 1),
                    scale = range(2, "Scale", "Overall size.", "scale", 0.5, 3, 0.05),
                    boostColor = color(3, "Boosted Color", "Above 100% on foot or swimming.", "boostColor"),
                    slowColor = color(4, "Slowed Color", "Below 100% on foot or swimming.", "slowColor"),
                    baseColor = color(5, "Normal Color", "Exactly 100%, mounted, flying, or no reading.", "baseColor"),
                },
            },
        },
    }

    return SoundAlerter:RailSpeedMeter(options)
end

SoundAlerter.SpeedMeter = SpeedMeter
