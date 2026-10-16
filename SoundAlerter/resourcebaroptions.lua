local SoundAlerter = SoundAlerter

local DOT = "Interface\\AddOns\\SoundAlerter\\Textures\\circle.tga"
local FLAT = "Interface\\Buttons\\WHITE8X8"
local PREVIEW_WIDTH = 220

local BAR_KEYS = { "energy", "rage", "health", "mana" }
local BAR_FRAMES = { energyScale = "energyFrame", rageScale = "rageFrame", healthScale = "healthFrame", manaScale = "manaFrame", comboScale = "comboFrame" }
local COLOR_UPDATES = { energyColor = "UpdateEnergyBar", rageColor = "UpdateRageBar", healthColor = "UpdateHealthBar", manaColor = "UpdateManaBar" }
local VISIBILITY = { energyEnabled = true, rageEnabled = true, healthEnabled = true, manaEnabled = true, comboEnabled = true, comboTextEnabled = true }
local COMBO_COLORS = { comboActiveColor = true, comboMaxColor = true }
local CELEBRATIONS = SoundAlerter.CPCelebration:Styles()
local QUALITIES = SoundAlerter.CPCelebration:Qualities()
local SQUARE_SHAPES = { square = true, bar = true }

local SHAPES = {
    { "circle", "Circle" }, { "ring", "Ring" }, { "pip", "Pip" }, { "diamond", "Diamond" }, { "hexagon", "Hexagon" }, { "star", "Star" },
    { "shield", "Shield" }, { "pill", "Pill" }, { "triangle", "Triangle" }, { "bar", "Segment Bar" }, { "square", "Square" },
}

local function bars()
    return SoundAlerter.ResourceBar
end

local function write(active, key, value)
    active:SetSetting(key, value)
    if key == "locked" then
        active:SetLocked(value)
    elseif key == "barTexture" then
        active:ApplyBarTexture()
    elseif VISIBILITY[key] then
        active:UpdateVisibility()
    elseif BAR_FRAMES[key] then
        local frame = active[BAR_FRAMES[key]]
        if frame then frame:SetScale(value) end
    elseif key == "healthHeight" then
        active:LoadSettings()
    elseif COLOR_UPDATES[key] then
        active:CacheColors()
        active[COLOR_UPDATES[key]](active)
    elseif key == "comboCelebration" or key == "comboAnimQuality" then
        active:ApplyCelebration()
    elseif key == "comboStyle" then
        active:ApplyCPStyle()
    elseif COMBO_COLORS[key] then
        active:CacheColors()
        active:RefreshComboColors()
    end
end

local function textureOptions()
    local values = SoundAlerter.BarTexture and SoundAlerter.BarTexture:Values() or {}
    local list = {}
    for key, label in pairs(values) do list[#list + 1] = { key, label } end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    return list
end

local ResourcePreview = { height = 130 }

function ResourcePreview.build(stage)
    local state = { stage = stage, bars = {}, pips = {} }
    for index, key in ipairs(BAR_KEYS) do
        local track = stage:CreateTexture(nil, "BACKGROUND")
        track:SetTexture(FLAT)
        track:SetVertexColor(0.227, 0.263, 0.322, 1)
        track:SetPoint("TOP", stage, "TOP", 0, -((index - 1) * 20))
        local fill = stage:CreateTexture(nil, "ARTWORK")
        fill:SetTexture(FLAT)
        fill:SetPoint("LEFT", track, "LEFT", 0, 0)
        state.bars[index] = { key = key, track = track, fill = fill }
    end
    for index = 1, 5 do
        local pip = stage:CreateTexture(nil, "ARTWORK")
        pip:SetPoint("BOTTOM", stage, "BOTTOM", (index - 3) * 22, 2)
        state.pips[index] = pip
    end
    return state
end

function ResourcePreview.update(state, settings)
    if not state then return end
    for _, bar in ipairs(state.bars) do
        local color = settings[bar.key .. "Color"]
        local enabled = settings[bar.key .. "Enabled"]
        local scale = settings[bar.key .. "Scale"]
        local height = bar.key == "health" and math.max(6, settings.healthHeight * 0.55) or 12
        local width = PREVIEW_WIDTH * math.min(1, scale / 1.5 + 0.4)
        bar.track:SetSize(width, height)
        bar.track:SetAlpha(enabled and 1 or 0.2)
        bar.fill:SetSize(width * 0.7, height)
        bar.fill:SetVertexColor(color.r, color.g, color.b, 1)
        bar.fill:SetAlpha(enabled and 1 or 0.2)
    end
    local square = SQUARE_SHAPES[settings.comboStyle]
    local size = 12 * math.max(0.7, math.min(1.4, settings.comboScale))
    for index, pip in ipairs(state.pips) do
        local color = index == 5 and settings.comboMaxColor or settings.comboActiveColor
        local active = index <= 4
        pip:SetTexture(square and FLAT or DOT)
        pip:SetSize(size, size)
        if active then
            pip:SetVertexColor(color.r, color.g, color.b, 1)
        else
            pip:SetVertexColor(0.227, 0.263, 0.322, 1)
        end
        pip:SetAlpha(settings.comboEnabled and 1 or 0.2)
    end
end

local function summary(settings)
    local Page = SoundAlerter.Page
    local shown = 0
    for _, key in ipairs(BAR_KEYS) do
        if settings[key .. "Enabled"] then shown = shown + 1 end
    end
    if settings.comboEnabled then shown = shown + 1 end
    return Page.Summary(settings, shown .. " of 5 shown", settings.locked and "locked" or "unlocked, drag to move")
end

function SoundAlerter:BuildResourceBarOptions()
    local Page = SoundAlerter.Page
    return Page.Module({
        key = "ResourceBar",
        title = "Resource Management",
        icon = "Interface\\Icons\\Spell_Nature_Regeneration",
        desc = "Unified resource tracking for Energy, Rage, Health, and Mana bars with Combo Points. Enable the bars you need and drag them into position.",
        blurb = "Energy, Rage, Health and Mana bars with combo points. Unlock to drag a bar into position; positions persist through /reload.",
        order = 2.8,
        master = false,
        module = bars,
        write = write,
        defaults = function() return dbDefaults.profile.resourceBar end,
        summary = summary,
        preview = ResourcePreview,
        rows = {
            Page.Toggle("locked", "Lock bars", "Lock all resource bars in place. Unlock to drag and reposition.", false, "General"),
            Page.Select("barTexture", "Bar texture", "Choose the visual texture for all resource bars (Health, Mana, Energy, Rage). This provides a unified look across all bars.", textureOptions(), false, "General"),
            Page.Toggle("energyEnabled", "Show energy bar", "Display energy bar (for Rogues, Druids in Cat Form).", false, "Bars"),
            Page.Toggle("rageEnabled", "Show rage bar", "Display rage bar (for Warriors, Druids in Bear Form).", false, "Bars"),
            Page.Toggle("healthEnabled", "Show health bar", "Display health bar.", false, "Bars"),
            Page.Toggle("manaEnabled", "Show mana bar", "Display mana bar (for casters).", false, "Bars"),
            Page.Toggle("comboEnabled", "Show combo points", "Display combo points (for Rogues, Druids in Cat Form).", false, "Bars"),
            Page.When("comboEnabled", Page.Select("comboStyle", "Combo point shape", "Choose the visual shape for combo points.", SHAPES, false, "Bars")),
            Page.When("comboEnabled", Page.Select("comboCelebration", "Combo celebration", "Animation when combo points are gained, reach 5, are spent with a finisher or are lost when the target changes or dies. Every style has its own spend and loss exit.", CELEBRATIONS, false, "Bars")),
            Page.When("comboEnabled", Page.Select("comboAnimQuality", "Animation quality", "Low keeps the lightest version of each effect (fewer sparks and arcs, nothing spinning). High adds more sparks, arcs and a second pulse. Persistent effects run on the game's animation engine, so even High costs almost no script time.", QUALITIES, true, "Combo points")),
            Page.When("comboEnabled", Page.Action("Preview spend", "Run 0 to 5 combo points on the live bar, then spend them with the chosen spend animation.", function() if bars() then bars():PreviewCelebration("spent") end end, false, "Bars")),
            Page.When("comboEnabled", Page.Action("Preview loss", "Run 0 to 5 combo points on the live bar, then lose them as if the target died.", function() if bars() then bars():PreviewCelebration("lost") end end, false, "Bars")),
            Page.When("energyEnabled", Page.Color("energyColor", "Energy color", "Color of the energy bar.", true, "Energy bar")),
            Page.When("energyEnabled", Page.Range("energyScale", "Energy bar scale", "Adjust the size of the energy bar.", 0.5, 2, 0.05, true, "Energy bar", "x")),
            Page.When("rageEnabled", Page.Color("rageColor", "Rage color", "Color of the rage bar.", true, "Rage bar")),
            Page.When("rageEnabled", Page.Range("rageScale", "Rage bar scale", "Adjust the size of the rage bar.", 0.5, 2, 0.05, true, "Rage bar", "x")),
            Page.When("healthEnabled", Page.Color("healthColor", "Health color", "Color of the health bar.", true, "Health bar")),
            Page.When("healthEnabled", Page.Range("healthScale", "Health bar scale", "Adjust the size of the health bar.", 0.5, 2, 0.05, true, "Health bar", "x")),
            Page.When("healthEnabled", Page.Range("healthHeight", "Health bar height", "Adjust the height of the health bar.", 10, 40, 1, true, "Health bar", " px")),
            Page.When("manaEnabled", Page.Color("manaColor", "Mana color", "Color of the mana bar.", true, "Mana bar")),
            Page.When("manaEnabled", Page.Range("manaScale", "Mana bar scale", "Adjust the size of the mana bar.", 0.5, 2, 0.05, true, "Mana bar", "x")),
            Page.When("comboEnabled", Page.Range("comboScale", "Combo points scale", "Adjust the size of the combo points.", 0.5, 2, 0.05, true, "Combo points", "x")),
            Page.When("comboEnabled", Page.Toggle("comboTextEnabled", "Show combo text", "Display combo points as text (e.g., '3/5').", true, "Combo points")),
            Page.When("comboEnabled", Page.Color("comboActiveColor", "Active combo color", "Color of active combo points (1-4).", true, "Combo points")),
            Page.When("comboEnabled", Page.Color("comboMaxColor", "Max combo color", "Color of combo points at maximum (5).", true, "Combo points")),
            Page.When("comboEnabled", Page.Toggle("fullCPSound", "5 CP sound", "Play a satisfying chime when reaching 5 combo points.", true, "Combo points")),
        },
    })
end
