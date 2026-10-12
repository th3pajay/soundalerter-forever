local CombatTimer = {}

local Model = SA_CombatTimerModel
local BarUtils = SoundAlerter.BarUtils
local Plain = SA_COMPAT.Plain

local pcall = pcall
local math_sin = math.sin
local string_format = string.format

local DEFAULT_Y = -120
local FADE_DELAY = 1.2
local FADE_TIME = 0.8
local FLASH_TIME = 0.35
local BUMP_TIME = 0.15
local BUMP_PIXELS = 2
local PULSE_RATE = 7
local PULSE_WINDOW_MS = 1000
local LABEL_GAP = 2
local GRAB_PADDING = 4
local TEST_HIT_DELAY = 1.5
local TEST_DROP_MARGIN = 0.4
local RESYNC_INTERVAL = 0.25
local RESYNC_CONFIRMATIONS = 2
local MELEE_INTERVAL = 0.5
local FONT_PATH = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local SETTING_KEYS = {
    enabled = true, locked = true, PositionX = true, PositionY = true,
    scale = true, width = true, thickness = true, windowSeconds = true, decimals = true,
    showDigits = true, digitSize = true, animations = true, fadeWhenFree = true, freeAlpha = true,
    onlyInPvP = true, hotColor = true, warmColor = true, coolColor = true, freeColor = true,
}

local STATE_EVENTS = {
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
    "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
}
local PROBE_EVENTS = {
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
    "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
}

function CombatTimer:GetSettings()
    return self.db
end

function CombatTimer:SetSetting(key, value)
    if not SETTING_KEYS[key] then
        error("CombatTimer:SetSetting - unknown setting key '"..tostring(key).."'", 2)
    end
    self.db[key] = value
    self:LoadSettings()
end

function CombatTimer:InPvP()
    local _, instanceType = IsInInstance()
    if instanceType == "arena" or instanceType == "pvp" then
        return true
    end
    return Plain(UnitIsPVP("player")) == true
end

local function CastAtHostilePlayer()
    return Plain(UnitExists("target")) == true
        and Plain(UnitCanAttack("player", "target")) == true
        and Plain(UnitIsPlayer("target")) == true
end

local function RealCombat()
    if not UnitAffectingCombat then return nil end
    local value = UnitAffectingCombat("player")
    if value ~= nil and Plain(value) == nil then return nil end
    return value and true or false
end

function CombatTimer:Attach()
    if not self.attached then
        self.attached = true
        self.frame:SetScript("OnUpdate", function() CombatTimer:Step(GetTime()) end)
    end
end

function CombatTimer:Detach()
    if self.attached then
        self.attached = false
        self.frame:SetScript("OnUpdate", nil)
    end
end

function CombatTimer:BeginCombat(now, synced)
    self.suppressed = false
    self.bumpAt = nil
    self.mismatch = 0
    Model.Enter(self.model, now, synced)
    self:Attach()
    self:Render(now)
end

function CombatTimer:Activity(now, kind)
    if self.suppressed or not self.model.inCombat then return end
    Model.Activity(self.model, now, kind)
    if kind ~= "melee" then
        self.bumpAt = now
    end
end

function CombatTimer:EndCombat(now, record)
    self.suppressed = false
    self.melee = false
    self.mismatch = 0
    local wasInCombat = self.model.inCombat
    Model.Regen(self.model, now, record)
    if wasInCombat then
        self:Attach()
        self:Render(now)
    end
end

function CombatTimer:Resync(now, confirmed)
    local db, model = self.db, self.model
    if not db or not model or self.testing then return end

    if not db.enabled then
        if model.inCombat then
            Model.Regen(model, now, false)
        end
        return
    end

    local real = RealCombat()
    if real == nil then return end
    self.lastResync = now

    if real == model.inCombat then
        self.mismatch = 0
        return
    end

    if real then
        if not db.onlyInPvP or self:InPvP() then
            self.addon:Debug("CombatTimer", "resync: in combat without a start event, showing the unsynced state")
            self:BeginCombat(now, false)
        end
        return
    end

    self.mismatch = (self.mismatch or 0) + 1
    if confirmed and self.mismatch < RESYNC_CONFIRMATIONS then return end
    self.addon:Debug("CombatTimer", "resync: out of combat without an end event, ending the timer")
    self:EndCombat(now, false)
end

function CombatTimer:HandleEvent(event, unit)
    local db = self.db
    if not db or not db.enabled then return end

    local now = GetTime()
    if event == "PLAYER_REGEN_DISABLED" then
        self.testing = false
        self.testToken = (self.testToken or 0) + 1
        if db.onlyInPvP and not self:InPvP() then
            self.suppressed = true
            return
        end
        self:BeginCombat(now)
    elseif event == "PLAYER_REGEN_ENABLED" then
        self.testing = false
        self.testToken = (self.testToken or 0) + 1
        self:EndCombat(now)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and CastAtHostilePlayer() then
            self:Activity(now, "cast")
        end
    elseif event == "UNIT_COMBAT" then
        self:Activity(now, unit == "pet" and "pet" or "combat")
    elseif event == "PLAYER_ENTER_COMBAT" then
        self.melee = true
        self:Activity(now, "enter")
    elseif event == "PLAYER_LEAVE_COMBAT" then
        self.melee = false
    else
        self:Resync(now)
    end
end

function CombatTimer:Render(now)
    local db, model, frame = self.db, self.model, self.frame
    if not db or not frame then return false end

    local state, remaining, tone, fraction = Model.Snapshot(model, now)
    local unlockedPreview = not db.locked and not model.inCombat
    local text

    if unlockedPreview then
        tone, fraction, text = "hot", 1, Model.Format(model.windowMs, db.decimals)
    elseif state == "counting" or state == "waiting" then
        text = Model.Format(remaining, db.decimals)
    elseif state == "unsynced" then
        text = "--"
    else
        text = "free"
    end

    local flashing = false
    if state == "free" and db.animations and model.dropAt then
        local progress = (now - model.dropAt) / FLASH_TIME
        if progress < 1 then
            flashing = true
            fraction = 1 - progress
        end
    end

    local last = self.last
    local color = db[tone .. "Color"] or db.freeColor
    if last.fraction ~= fraction then
        last.fraction = fraction
        self.bar:SetValue(fraction)
    end
    if last.r ~= color.r or last.g ~= color.g or last.b ~= color.b then
        last.r, last.g, last.b = color.r, color.g, color.b
        self.bar:SetStatusBarColor(color.r, color.g, color.b)
        self.digits:SetTextColor(color.r, color.g, color.b)
    end
    if last.text ~= text then
        last.text = text
        self.digits:SetText(text)
    end

    local thickness = db.thickness
    if db.animations and self.bumpAt and now - self.bumpAt < BUMP_TIME then
        thickness = thickness + BUMP_PIXELS * (1 - (now - self.bumpAt) / BUMP_TIME)
    end
    if last.thickness ~= thickness then
        last.thickness = thickness
        self.bar:SetHeight(thickness)
    end

    local alpha = 1
    local settled = false
    if unlockedPreview then
        settled = true
    elseif state == "counting" or state == "waiting" or state == "unsynced" then
        if db.animations and (state ~= "counting" or remaining < PULSE_WINDOW_MS) then
            alpha = 0.7 + 0.3 * (0.5 + 0.5 * math_sin(now * PULSE_RATE))
        end
    else
        if db.fadeWhenFree then
            alpha = Model.FadeAlpha(model, now, FADE_DELAY, db.animations and FADE_TIME or 0.001, db.freeAlpha)
            settled = not model.dropAt or now - model.dropAt >= FADE_DELAY + (db.animations and FADE_TIME or 0.001)
        else
            settled = true
        end
        if flashing then settled = false end
    end
    if last.alpha ~= alpha then
        last.alpha = alpha
        frame:SetAlpha(alpha)
    end
    return settled
end

function CombatTimer:Step(now)
    local model = self.model
    if model.inCombat then
        if self.melee and now - (self.lastMelee or 0) >= MELEE_INTERVAL and CastAtHostilePlayer() then
            self.lastMelee = now
            self:Activity(now, "melee")
        end
        if model.lastActivity == nil or Model.Remaining(model, now) <= 0 then
            if now - (self.lastResync or 0) >= RESYNC_INTERVAL then
                self:Resync(now, true)
            end
        end
    end
    if self:Render(now) then
        self:Detach()
    end
end

function CombatTimer:LoadSettings()
    local db, frame = self.db, self.frame
    if not db or not frame then return end

    self.last = {}
    Model.SetWindow(self.model, db.windowSeconds * 1000)

    local blockHeight = db.thickness
    if db.showDigits then
        blockHeight = blockHeight + LABEL_GAP + db.digitSize + 2
    end
    frame:SetScale(db.scale)
    frame:SetSize(db.width, blockHeight + GRAB_PADDING * 2)

    self.bar:ClearAllPoints()
    self.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -GRAB_PADDING)
    self.bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -GRAB_PADDING)
    self.bar:SetHeight(db.thickness)

    self.digits:SetFont(FONT_PATH, db.digitSize, "OUTLINE")
    self.digits:SetShown(db.showDigits)
    self.bg:SetShown(not db.locked)

    BarUtils:LoadPosition(frame, db, "", 0, DEFAULT_Y)
    BarUtils:UpdateVisibility(frame, db)

    self:Resync(GetTime())

    if self:Render(GetTime()) then
        self:Detach()
    else
        self:Attach()
    end
end

function CombatTimer:SetLocked(locked)
    if not self.db then return end
    self.db.locked = locked
    self:LoadSettings()
end

function CombatTimer:ResetPosition()
    if not self.db then return end
    self.db.PositionX = 0
    self.db.PositionY = DEFAULT_Y
    self:LoadSettings()
end

function CombatTimer:RunTest()
    if not self.initialized or not self.db.enabled then
        self.addon:Print("Combat Drop Timer is disabled - enable it first")
        return
    end
    if self.model.inCombat and not self.testing then
        self.addon:Print("Combat Drop Timer: you are in combat, the test would hide the real countdown")
        return
    end

    self.testing = true
    self.testToken = (self.testToken or 0) + 1
    local token = self.testToken
    local windowSeconds = self.db.windowSeconds

    self:BeginCombat(GetTime())
    C_Timer.After(TEST_HIT_DELAY, function()
        if token == self.testToken then self:Activity(GetTime(), "cast") end
    end)
    C_Timer.After(TEST_HIT_DELAY + windowSeconds + TEST_DROP_MARGIN, function()
        if token == self.testToken then
            self.testing = false
            self:EndCombat(GetTime(), false)
        end
    end)
end

function CombatTimer:OnProfileChanged()
    local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not SoundAlerter then return end

    self.addon = SoundAlerter
    self.db = self.addon.db1.profile.combatTimer

    if self.initialized then
        self:LoadSettings()
    end
end

local function describe(value)
    if value == nil then return "nil" end
    local plain = Plain(value)
    if plain == nil then return "SECRET" end
    return tostring(plain)
end

function CombatTimer:SetProbe(on)
    if not self.probe then
        self.probe = CreateFrame("Frame")
        self.probe:SetScript("OnEvent", function(_, event, unit, ...)
            local now = GetTime()
            local gap = self.probeLast and string_format("  +%.3f", now - self.probeLast) or ""
            self.probeLast = now
            local who = unit and ("  " .. describe(unit)) or ""
            local extra = ""
            if event == "UNIT_COMBAT" then
                extra = "  " .. describe((...)) .. " " .. describe((select(2, ...))) .. " " .. describe((select(3, ...)))
            end
            local flags = string_format("  [affecting %s, lockdown %s]", describe(UnitAffectingCombat and UnitAffectingCombat("player")), describe(InCombatLockdown()))
            self.addon:Print(string_format("|cff00FFFFctprobe|r %s%s%s  %.3f%s%s", event, who, extra, now, gap, flags))
        end)
    end

    self.probe:UnregisterAllEvents()
    self.probeLast = nil
    if not on then return end

    for _, event in ipairs(PROBE_EVENTS) do
        pcall(self.probe.RegisterEvent, self.probe, event)
    end
    pcall(self.probe.RegisterUnitEvent, self.probe, "UNIT_COMBAT", "player", "pet")
    pcall(self.probe.RegisterUnitEvent, self.probe, "UNIT_SPELLCAST_SUCCEEDED", "player")
    pcall(self.probe.RegisterUnitEvent, self.probe, "UNIT_FLAGS", "player")
end

function CombatTimer:HandleCommand(input)
    local command = (input or ""):lower()
    if not self.addon.db1.profile.debugmode then
        self.addon:Print("Turn on Debug mode in General first.")
        return
    end

    if command == "on" then
        self:SetProbe(true)
        self.addon:Print("ctprobe on. Fight, stop, and read the gap before PLAYER_REGEN_ENABLED.")
    elseif command == "off" then
        self:SetProbe(false)
        self.addon:Print("ctprobe off.")
    elseif command == "reset" then
        Model.ResetDrift(self.model)
        self.addon:Print("Combat drop measurements cleared.")
    elseif command == "drift" then
        local average = Model.AverageDrift(self.model)
        if average then
            for _, row in ipairs(Model.GapReport(self.model)) do
                self.addon:Print(string_format("  after %s: %d drop(s), gap min %.2f s, median %.2f s, max %.2f s", row.kind, row.count, row.min, row.median, row.max))
            end
            self.addon:Print(string_format("Combat drop drift: average %+.3f s over %d drop(s), last %+.3f s. Positive means the game dropped combat later than the estimate.",
                average, self.model.driftCount, self.model.lastDrift))
        else
            self.addon:Print("No drops measured yet.")
        end
    else
        self.addon:Print("/sa ctprobe on|off|drift|reset")
    end
end

function CombatTimer:PrintHelp()
    self.addon:Print("  |cffFFFFFF/sa ctprobe on|off|drift|reset|r - Log combat events and measure the combat drop window (debug mode)")
end

function CombatTimer:Initialize()
    if self.initialized then return end

    local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not SoundAlerter then
        error("CombatTimer:Initialize() called before addon is ready")
        return
    end

    self.addon = SoundAlerter
    self.db = SoundAlerter.db1.profile.combatTimer
    self.model = Model.New(self.db.windowSeconds * 1000)
    self.last = {}
    self.mismatch = 0

    self.dragProxy = setmetatable({}, {
        __index = function(_, key)
            local db = CombatTimer.db
            return db and db[key]
        end,
    })

    self.frame = BarUtils:CreateContainerFrame("SoundAlerterCombatTimer", self.db.width, 20, DEFAULT_Y, self.dragProxy, function()
        BarUtils:SavePosition(CombatTimer.frame, CombatTimer.db, "")
    end, false)

    self.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
    self.bg:SetColorTexture(0, 0, 0, 0.45)

    self.bar = BarUtils:CreateStatusBarWidget(self.frame, self.db.width, self.db.thickness, 0, 1)
    self.digits = BarUtils:CreateFontString(self.frame, self.db.digitSize, "OUTLINE")
    self.digits:ClearAllPoints()
    self.digits:SetPoint("TOPLEFT", self.bar, "BOTTOMLEFT", 0, -LABEL_GAP)
    self.digits:SetJustifyH("LEFT")

    self.events = CreateFrame("Frame")
    self.events:SetScript("OnEvent", function(_, event, unit)
        CombatTimer:HandleEvent(event, unit)
    end)
    for _, event in ipairs(STATE_EVENTS) do
        pcall(self.events.RegisterEvent, self.events, event)
    end
    pcall(self.events.RegisterUnitEvent, self.events, "UNIT_COMBAT", "player", "pet")
    pcall(self.events.RegisterUnitEvent, self.events, "UNIT_SPELLCAST_SUCCEEDED", "player")

    self.initialized = true
    self:LoadSettings()
end

SoundAlerter.CombatTimer = CombatTimer
