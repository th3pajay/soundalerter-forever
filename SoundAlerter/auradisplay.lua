local SoundAlerter = SoundAlerter
local AuraDisplay = {}
SoundAlerter.AuraDisplay = AuraDisplay

local Plain = SA_COMPAT.Plain
local issecretvalue = _G.issecretvalue or function() return false end

local ICON_SIZE = 28
local NAME_SIZE = 10
local FADE_IN, HOLD, FADE_OUT = 0.1, 1.5, 0.3
local SETTLE = FADE_IN + HOLD + FADE_OUT + 0.1
local MAX_BUTTONS = 20
local GAP = 8
local WHITE = "Interface\\Buttons\\WHITE8X8"
local COLORS = { buff = { 0.3, 0.85, 0.35 }, debuff = { 0.9, 0.25, 0.2 } }
local FILTERS = { buff = "HELPFUL", debuff = "HARMFUL" }
local UNITS = { "target", "focus" }

local spots = {}
local events = CreateFrame("Frame")

local function Settings()
    local feed = SoundAlerter.CastFeed
    return feed and feed.db
end

local function Wanted()
    local settings = Settings()
    return settings ~= nil and settings.enabled and settings.auraDisplay == true and SA_Secret.Usable("aura")
end

local function IsEnemy(unit)
    if Plain(UnitExists(unit)) ~= true then return false end
    if Plain(UnitIsUnit(unit, "player")) == true then return false end
    if Plain(UnitIsPlayer(unit)) == false then return false end
    local attackable = UnitCanAttack("player", unit)
    return issecretvalue(attackable) or attackable == true
end

local function IsDuelOpponent(unit)
    if Plain(UnitIsPlayer(unit)) ~= true or Plain(UnitCanAttack("player", unit)) ~= true then return false end
    if Plain((IsInInstance())) ~= false then return false end
    local mine, theirs = Plain((UnitFactionGroup("player"))), Plain((UnitFactionGroup(unit)))
    return type(mine) == "string" and mine ~= "" and mine == theirs
end

local function BuildButton(button, kind)
    local edge = button:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(0, 0, 0, 1)
    edge:SetPoint("TOPLEFT", 0, 0)
    edge:SetSize(ICON_SIZE, ICON_SIZE)
    local line = button:CreateTexture(nil, "BORDER")
    line:SetTexture(WHITE)
    line:SetVertexColor(COLORS[kind][1], COLORS[kind][2], COLORS[kind][3], 1)
    line:SetPoint("TOPLEFT", 1, -1)
    line:SetSize(ICON_SIZE - 2, ICON_SIZE - 2)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetSize(ICON_SIZE - 4, ICON_SIZE - 4)
    local name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local file, _, flags = GameFontHighlightSmall:GetFont()
    if file then name:SetFont(file, NAME_SIZE, flags ~= "" and flags or "OUTLINE") end
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetWidth(90)
    name:SetPoint("LEFT", icon, "RIGHT", 4, 0)

    local flash = button:CreateAnimationGroup()
    flash:SetToFinalAlpha(true)
    local into = flash:CreateAnimation("Alpha")
    into:SetFromAlpha(0)
    into:SetToAlpha(1)
    into:SetDuration(FADE_IN)
    into:SetOrder(1)
    local hold = flash:CreateAnimation("Alpha")
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)
    hold:SetDuration(HOLD)
    hold:SetOrder(2)
    local out = flash:CreateAnimation("Alpha")
    out:SetFromAlpha(1)
    out:SetToAlpha(0)
    out:SetDuration(FADE_OUT)
    out:SetOrder(3)

    button:SetAlpha(0)
    button:EnableMouse(false)
    button:SetSize(ICON_SIZE + 94, ICON_SIZE)
    button:SetIcon(icon)
    button:SetSpellName(name)
    button:AddAuraAssignedAnimation(flash)
end

local Feed = {}
Feed.__index = Feed

local function NewFeed(spot, kind)
    return setmetatable({ spot = spot, kind = kind, unit = "none", token = 0 }, Feed)
end

function Feed:Create()
    local kind = self.kind
    local holder = CreateFrame("Frame", nil, self.spot.frame)
    holder:SetSize(1, 1)
    holder:EnableMouse(false)
    holder:SetAlpha(0)
    holder:SetPoint("TOPLEFT", self.spot.frame, "TOPLEFT", 0, 0)
    local container = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    container:SetEditModePreviewEnabled(false)
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Vertical)
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    container:SetFlowLayoutAnchorPoint("TOPLEFT")
    container:AddAuraGroup(kind, FILTERS[kind], {
        maxFrameCount = MAX_BUTTONS,
        sortMethod = AuraContainerSortMethod.AuraInstanceIDOnly,
        sortDirection = AuraContainerSortDirection.Reverse,
        layout = { lineSpacing = 1 },
        initializeFrame = function(button)
            local ok, err = pcall(BuildButton, button, kind)
            if not ok then SA_Secret.Block("aura", err) end
        end,
    })
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    self.holder, self.container = holder, container
end

function Feed:Build()
    if self.container then return true end
    if self.failed or InCombatLockdown() then return false end
    local ok, err = pcall(self.Create, self)
    if not ok then
        self.failed = true
        SA_Secret.Block("aura", err)
        return false
    end
    SA_Secret.Succeed("aura", true)
    return true
end

function Feed:Reveal(token)
    if self.token == token and self.holder then
        self.holder:SetAlpha(self.unit ~= "none" and 1 or 0)
    end
end

function Feed:SetUnit(unit, fresh)
    if unit == self.unit and not fresh then return end
    if unit == "none" and not self.container then
        self.unit = "none"
        return
    end
    if unit ~= "none" and not self:Build() then return end
    local ok, err = pcall(function()
        self.container:SetUnit("none")
        if unit ~= "none" then self.container:SetUnit(unit) end
    end)
    if not ok then
        SA_Secret.Block("aura", err)
        return
    end
    self.unit = unit
    self.token = self.token + 1
    self.holder:SetAlpha(0)
    if unit ~= "none" then
        local token = self.token
        C_Timer.After(SETTLE, function() self:Reveal(token) end)
    end
end

local Spot = {}
Spot.__index = Spot

function Spot:Anchor()
    local feed = SoundAlerter.CastFeed
    local row
    for _, candidate in ipairs(feed and feed.rows or {}) do
        if candidate.unit == self.unit then row = candidate end
    end
    if not row then return false end
    if self.row ~= row then
        self.row = row
        self.frame:SetParent(row.frame)
        self.frame:ClearAllPoints()
        self.frame:SetPoint("LEFT", row.frame, "RIGHT", GAP, 0)
    end
    return true
end

function Spot:Follow(want, fresh)
    local enemy = want and self:Anchor() and IsEnemy(self.unit)
    self.buffs:SetUnit(enemy and self.unit or "none", fresh)
    if self.debuffs then
        self.debuffs:SetUnit((enemy and IsDuelOpponent(self.unit)) and "player" or "none", false)
    end
end

function AuraDisplay:Refresh(fresh)
    local want = Wanted()
    for _, spot in ipairs(spots) do
        local ok, err = pcall(spot.Follow, spot, want, fresh)
        if not ok then SA_Secret.Block("aura", err) end
    end
end

events:SetScript("OnEvent", function(_, event, unit)
    if not Wanted() then return end
    if event == "UNIT_FACTION" and unit ~= "target" and unit ~= "focus" and unit ~= "player" then return end
    AuraDisplay:Refresh(event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED")
end)

function AuraDisplay:Initialize()
    if self.initialized then return end
    for _, unit in ipairs(UNITS) do
        local spot = setmetatable({ unit = unit }, Spot)
        spot.frame = CreateFrame("Frame", nil, UIParent)
        spot.frame:SetSize(ICON_SIZE + 94, ICON_SIZE)
        spot.frame:EnableMouse(false)
        spot.buffs = NewFeed(spot, "buff")
        if unit == "target" then spot.debuffs = NewFeed(spot, "debuff") end
        spots[#spots + 1] = spot
    end
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_REGEN_ENABLED", "UNIT_FACTION", "DUEL_FINISHED" }) do
        events:RegisterEvent(event)
    end
    self.initialized = true
    self:Refresh(true)
end
