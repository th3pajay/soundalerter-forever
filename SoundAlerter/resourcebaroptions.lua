local SoundAlerter = SoundAlerter

local DOT = "Interface\\AddOns\\SoundAlerter\\Textures\\circle.tga"
local FLAT = "Interface\\Buttons\\WHITE8X8"
local PREVIEW_WIDTH = 220

local BAR_KEYS = { "energy", "rage", "health", "mana" }
local BAR_FRAMES = { energyScale = "energyFrame", rageScale = "rageFrame", healthScale = "healthFrame", manaScale = "manaFrame", comboScale = "comboFrame" }
local COLOR_UPDATES = { energyColor = "UpdateEnergyBar", rageColor = "UpdateRageBar", healthColor = "UpdateHealthBar", manaColor = "UpdateManaBar" }
local VISIBILITY = { swingSpark = true, energyEnabled = true, rageEnabled = true, rageFade = true, healthEnabled = true, manaEnabled = true, comboEnabled = true, comboTextEnabled = true }
local COMBO_COLORS = { comboActiveColor = true, comboMaxColor = true, comboInactiveColor = true }
local CELEBRATIONS = SoundAlerter.CPCelebration:Styles()
local QUALITIES = SoundAlerter.CPCelebration:Qualities()
local EXITS = SoundAlerter.CPCelebration:Exits()
local SQUARE_SHAPES = { square = true, bar = true }

local SHAPES = {
    { "circle", "Circle" }, { "ring", "Ring" }, { "pip", "Pip" }, { "diamond", "Diamond" }, { "hexagon", "Hexagon" }, { "star", "Star" },
    { "shield", "Shield" }, { "pill", "Pill" }, { "triangle", "Triangle" }, { "bar", "Segment Bar" }, { "square", "Square" },
}

local function bars()
    return SoundAlerter.ResourceBar
end

local function poisedClass()
    local active = bars()
    return active ~= nil and active.poisedInfo ~= nil
end

local function write(active, key, value)
    active:SetSetting(key, value)
    if key == "locked" then
        active:SetLocked(value)
    elseif key == "barTexture" or key == "barTextureQuality" then
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
    elseif key == "comboCelebration" or key == "comboAnimQuality" or key == "comboExit" then
        active:ApplyCelebration()
    elseif key == "poisedGlow" then
        active:UpdatePoisedTracking()
    elseif key == "comboStyle" then
        active:ApplyCPStyle()
    elseif COMBO_COLORS[key] then
        active:CacheColors()
        active:RefreshComboColors()
    end
end

local function swingSupported()
    return C_SwingTimer ~= nil
end

local TEXTURE_QUALITIES = { { "low", "Low" }, { "normal", "Normal" }, { "high", "High" } }

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
        if not active then color = settings.comboInactiveColor or color end
        pip:SetVertexColor(color.r, color.g, color.b, 1)
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
            Page.Toggle("locked", "Lock position", "Unlock to drag each bar. A shaded outline marks it while unlocked.", false, "General"),
            Page.Action("Reset position", "Put every bar and the combo points back where they started.", function()
                local active = bars()
                if active then active:ResetPositions() end
            end, false, "General"),
            Page.Select("barTexture", "Bar texture", "Choose the visual texture for all resource bars (Health, Mana, Energy, Rage). This provides a unified look across all bars.", textureOptions(), false, "General"),
            Page.Select("barTextureQuality", "Texture quality", "Low animates 15 times a second and drops the farthest layer. Normal is the full animation. High adds a fourth layer to Fire and Leaves. Only animated textures are affected.", TEXTURE_QUALITIES, true, "General"),
            Page.Toggle("energyEnabled", "Show energy bar", "Display energy bar (for Rogues, Druids in Cat Form).", false, "Bars"),
            Page.Toggle("rageEnabled", "Show rage bar", "Display rage bar (for Warriors, Druids in Bear Form). Out of Bear Form the bar reads empty, and rage starts fresh when you shift back.", false, "Bars"),
            Page.When("rageEnabled", Page.Toggle("rageFade", "Fade rage bar when empty", "Fade the rage bar out of view while you have no rage, and while a druid is out of Bear Form. Works while the bars are locked; unlock to see and move it.", false, "Bars")),
            Page.Toggle("healthEnabled", "Show health bar", "Display health bar.", false, "Bars"),
            Page.Toggle("manaEnabled", "Show mana bar", "Display mana bar (for casters).", false, "Bars"),
            Page.Toggle("comboEnabled", "Show combo points", "Display combo points (for Rogues, Druids in Cat Form).", false, "Bars"),
            Page.When("comboEnabled", Page.Select("comboStyle", "Shape", "The shape of each combo point.", SHAPES, false, "Combo points")),
            Page.When("comboEnabled", Page.Range("comboScale", "Size", "How big the combo points are.", 0.5, 2, 0.05, false, "Combo points", "x")),
            Page.When("comboEnabled", Page.Color("comboActiveColor", "Colour (1-4)", "Colour of the points while you build up to five.", true, "Combo points")),
            Page.When("comboEnabled", Page.Color("comboMaxColor", "Colour at 5", "Colour of all five points at maximum.", true, "Combo points")),
            Page.When("comboEnabled", Page.Color("comboInactiveColor", "Empty colour", "Colour of the points you don't have yet.", true, "Combo points")),
            Page.When("comboEnabled", Page.Toggle("comboTextEnabled", "Show 3/5 text", "The count as text, for example 3/5. Unlock to move it.", true, "Combo points")),
            Page.When("comboEnabled", Page.Toggle("fullCPSound", "Chime at 5", "A short chime when you reach five combo points.", true, "Combo points")),
            Page.When("comboEnabled", Page.Select("comboCelebration", "Celebration", "What plays when points reach 5, are spent with a finisher or are lost when the target changes or dies. Gains light up from a dim core and lost points drain away, for every style.", CELEBRATIONS, false, "Combo animation")),
            Page.When("comboEnabled", Page.Select("comboExit", "Fade out", "How the points leave when you drop from 5. Style's own uses the exit of the celebration style. Sweep out dims them left to right. Collapse to centre slides them into the middle, with a flash when spent and slowly when lost.", EXITS, false, "Combo animation")),
            Page.When("comboEnabled", Page.Select("comboAnimQuality", "Animation quality", "Low keeps scale and fade only. Normal adds rings. High adds sparks, arcs and a second pulse. Everything runs on the game's animation engine, so even High costs almost no script time.", QUALITIES, true, "Combo animation")),
            Page.When("comboEnabled", Page.Action("Preview spend", "Run 0 to 5 combo points on the live bar, then spend them with a finisher.", function() if bars() then bars():PreviewCelebration("spent") end end, false, "Combo animation")),
            Page.When("comboEnabled", Page.Action("Preview loss", "Run 0 to 5 combo points on the live bar, then lose them as if the target died.", function() if bars() then bars():PreviewCelebration("lost") end end, false, "Combo animation")),
            Page.When("energyEnabled", Page.Color("energyColor", "Energy color", "Color of the energy bar.", true, "Energy bar")),
            Page.When("energyEnabled", Page.Range("energyScale", "Energy bar scale", "Adjust the size of the energy bar.", 0.5, 2, 0.05, true, "Energy bar", "x")),
            Page.Visible(function() return poisedClass() end, Page.When("energyEnabled", Page.Toggle("poisedGlow", "Poised marker", "Gold edge and a Poised tag on the energy bar while Poised is up, so you know your next energy ability costs less. Rogues from level 18, druids from level 32.", true, "Energy bar"))),
            Page.When("rageEnabled", Page.Color("rageColor", "Rage color", "Color of the rage bar.", true, "Rage bar")),
            Page.When("rageEnabled", Page.Range("rageScale", "Rage bar scale", "Adjust the size of the rage bar.", 0.5, 2, 0.05, true, "Rage bar", "x")),
            Page.When("healthEnabled", Page.Color("healthColor", "Health color", "Color of the health bar.", true, "Health bar")),
            Page.When("healthEnabled", Page.Range("healthScale", "Health bar scale", "Adjust the size of the health bar.", 0.5, 2, 0.05, true, "Health bar", "x")),
            Page.When("healthEnabled", Page.Range("healthHeight", "Health bar height", "Adjust the height of the health bar.", 10, 40, 1, true, "Health bar", " px")),
            Page.When("manaEnabled", Page.Color("manaColor", "Mana color", "Color of the mana bar.", true, "Mana bar")),
            Page.When("manaEnabled", Page.Range("manaScale", "Mana bar scale", "Adjust the size of the mana bar.", 0.5, 2, 0.05, true, "Mana bar", "x")),
            Page.Visible(swingSupported, Page.Toggle("swingSpark", "Swing spark", "A small spark runs along the top border of the bar your form uses and reaches the end as your next swing lands. Off-hand runs along the bottom border. It shows only while you are swinging, and needs an energy, rage, mana or health bar shown.", false, "Swing timer")),
            Page.Visible(swingSupported, Page.When("swingSpark", Page.Toggle("swingSparkFlash", "Flash when the swing lands", "The bar's border flashes briefly each time a swing lands.", false, "Swing timer"))),
            Page.Visible(swingSupported, Page.When("swingSpark", Page.Action("Preview spark", "Run one pass on the bar your form uses.", function()
                if SoundAlerter.SwingSpark then SoundAlerter.SwingSpark:Preview() end
            end, false, "Swing timer"))),
        },
    })
end
