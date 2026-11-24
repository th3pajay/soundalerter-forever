local SoundAlerter = SoundAlerter

local DOT = "Interface\\AddOns\\SoundAlerter\\Textures\\circle.tga"
local FLAT = "Interface\\Buttons\\WHITE8X8"
local RUNE_P = "Interface\\AddOns\\SoundAlerter\\Textures\\poised_p"
local PREVIEW_WIDTH = 220
local PREVIEW_MARKS = 3
local PREVIEW_GOLD = { 1, 0.83, 0.42 }
local PREVIEW_UNLOCKED = { 1, 0.49, 0.04 }

local BAR_KEYS = { "energy", "rage", "health", "mana" }
local CELEBRATIONS = SoundAlerter.CPCelebration:Styles()
local QUALITIES = SoundAlerter.CPCelebration:Qualities()
local EXITS = SoundAlerter.CPCelebration:Exits()
local SQUARE_SHAPES = { square = true, bar = true }

local SHAPES = {
    { "circle", "Circle" }, { "ring", "Ring" }, { "pip", "Pip" }, { "diamond", "Diamond" }, { "hexagon", "Hexagon" }, { "star", "Star" },
    { "shield", "Shield" }, { "pill", "Pill" }, { "triangle", "Triangle" }, { "bar", "Segment Bar" }, { "square", "Square" },
}

local TABS = {
    { key = "bars", label = "Bars", groups = { "Energy", "Rage", "Health", "Mana" } },
    { key = "combo", label = "Combo points", groups = { "Combo points", "Combo animation" } },
    { key = "timers", label = "Timers & marks", groups = { "Poised rune", "Five-second rule", "Shift marks", "Swing timer" } },
    { key = "look", label = "Look", groups = { "Look" } },
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
end

local function shifter()
    local _, class = UnitClass("player")
    return class == "DRUID"
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
        local edge = stage:CreateTexture(nil, "BACKGROUND", nil, -1)
        edge:SetTexture(FLAT)
        edge:SetVertexColor(PREVIEW_UNLOCKED[1], PREVIEW_UNLOCKED[2], PREVIEW_UNLOCKED[3], 0.7)
        edge:SetPoint("TOPLEFT", track, "TOPLEFT", -2, 2)
        edge:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 2, -2)
        state.bars[index] = { key = key, track = track, fill = fill, edge = edge }
        state[key] = state.bars[index]
    end
    local energy, mana = state.energy.track, state.mana.track
    state.rune = stage:CreateTexture(nil, "OVERLAY")
    state.rune:SetTexture(RUNE_P)
    state.rune:SetVertexColor(PREVIEW_GOLD[1], PREVIEW_GOLD[2], PREVIEW_GOLD[3], 1)
    state.rune:SetSize(14, 14)
    state.rune:SetPoint("LEFT", energy, "RIGHT", 4, 0)
    state.spark = stage:CreateTexture(nil, "OVERLAY")
    state.spark:SetTexture(FLAT)
    state.spark:SetVertexColor(1, 0.97, 0.82, 1)
    state.spark:SetSize(8, 2)
    state.sweep = stage:CreateTexture(nil, "OVERLAY")
    state.sweep:SetTexture(FLAT)
    state.sweep:SetVertexColor(1, 1, 1, 0.9)
    state.sweep:SetWidth(1)
    state.sweep:SetPoint("TOP", mana, "TOPLEFT", 0, 0)
    state.sweep:SetPoint("BOTTOM", mana, "BOTTOMLEFT", 0, 0)
    state.marks = {}
    for index = 1, PREVIEW_MARKS do
        local mark = stage:CreateTexture(nil, "OVERLAY")
        mark:SetTexture(FLAT)
        mark:SetVertexColor(PREVIEW_GOLD[1], PREVIEW_GOLD[2], PREVIEW_GOLD[3], 1)
        mark:SetSize(2, 3)
        state.marks[index] = mark
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
        bar.edge:SetShown(enabled and not settings.locked)
        bar.width = width
    end
    local energy, mana = state.energy, state.mana
    state.rune:SetShown(settings.energyEnabled and settings.poisedGlow and true or false)
    local spark = settings.swingSpark and (settings.energyEnabled or settings.rageEnabled) and true or false
    state.spark:SetShown(spark)
    if spark then
        local host = settings.energyEnabled and energy or state.rage
        state.spark:ClearAllPoints()
        state.spark:SetPoint("BOTTOM", host.track, "TOPLEFT", host.width * 0.6, -1)
    end
    state.sweep:SetShown(settings.manaEnabled and settings.manaSweep and true or false)
    state.sweep:SetPoint("TOP", mana.track, "TOPLEFT", mana.width * 0.4, 0)
    state.sweep:SetPoint("BOTTOM", mana.track, "BOTTOMLEFT", mana.width * 0.4, 0)
    local marks = settings.manaEnabled and settings.manaShiftMarks and true or false
    for index, mark in ipairs(state.marks) do
        mark:SetShown(marks)
        if marks then
            mark:ClearAllPoints()
            mark:SetPoint("TOP", mana.track, "TOPLEFT", mana.width * index / (PREVIEW_MARKS + 1), 1)
        end
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
        tabs = TABS,
        lock = {
            key = "locked",
            hint = "Unlocked: drag any bar or the combo points. A shaded outline marks each one.",
            reset = function()
                local active = bars()
                if active then active:ResetPositions() end
            end,
        },
        rows = {
            Page.Select("barTexture", "Bar texture", "One texture for every resource bar: health, mana, energy and rage.", textureOptions(), false, "Look"),
            Page.Select("barTextureQuality", "Texture quality", "Low animates 15 times a second and drops the farthest layer. Normal is the full animation. High adds a fourth layer to Fire and Leaves. Only animated textures are affected.", TEXTURE_QUALITIES, false, "Look"),
            Page.Toggle("energyEnabled", "Show energy bar", "For rogues and druids in Cat Form.", false, "Energy"),
            Page.Toggle("rageEnabled", "Show rage bar", "Display rage bar (for Warriors, Druids in Bear Form). Out of Bear Form the bar reads empty, and rage starts fresh when you shift back.", false, "Rage"),
            Page.When("rageEnabled", Page.Toggle("rageFade", "Fade rage bar when empty", "Fade the rage bar out of view while you have no rage, and while a druid is out of Bear Form. Works while the bars are locked; unlock to see and move it.", false, "Rage")),
            Page.Toggle("healthEnabled", "Show health bar", "Your own health.", false, "Health"),
            Page.Toggle("manaEnabled", "Show mana bar", "For casters, and druids in any form.", false, "Mana"),
            Page.Toggle("comboEnabled", "Show combo points", "For rogues and druids in Cat Form.", false, "Combo points"),
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
            Page.When("energyEnabled", Page.Color("energyColor", "Colour", "Colour of the energy bar.", false, "Energy")),
            Page.When("energyEnabled", Page.Range("energyScale", "Scale", "How big the energy bar is.", 0.5, 2, 0.05, false, "Energy", "x")),
            Page.Visible(function() return poisedClass() end, Page.When("energyEnabled", Page.Toggle("poisedGlow", "Poised marker", "A gold rune P lights beside the energy bar when you are out of combat, in Cat Form or on a rogue, and your energy is full, so you know your Poised opener is ready. It pulls away the moment combat starts, you leave Cat Form or you spend energy. Its animation follows the combo point animation quality. Rogues from level 18, druids from level 32.", false, "Poised rune"))),
            Page.When("rageEnabled", Page.Color("rageColor", "Colour", "Colour of the rage bar.", false, "Rage")),
            Page.When("rageEnabled", Page.Range("rageScale", "Scale", "How big the rage bar is.", 0.5, 2, 0.05, false, "Rage", "x")),
            Page.When("healthEnabled", Page.Color("healthColor", "Colour", "Colour of the health bar.", false, "Health")),
            Page.When("healthEnabled", Page.Range("healthScale", "Scale", "How big the health bar is.", 0.5, 2, 0.05, false, "Health", "x")),
            Page.When("healthEnabled", Page.Range("healthHeight", "Height", "How tall the health bar is.", 10, 40, 1, false, "Health", " px")),
            Page.When("manaEnabled", Page.Color("manaColor", "Colour", "Colour of the mana bar.", false, "Mana")),
            Page.When("manaEnabled", Page.Range("manaScale", "Scale", "How big the mana bar is.", 0.5, 2, 0.05, false, "Mana", "x")),
            Page.When("manaEnabled", Page.Toggle("manaSweep", "Five-second rule", "After a spell that costs mana, a line runs across the mana bar for five seconds: the time until your spirit regen starts again. The next mana spell starts it over.", false, "Five-second rule")),
            Page.Visible(shifter, Page.When("manaEnabled", Page.Toggle("manaShiftMarks", "Shift marks", "Small gold notches on the top and bottom edge of the mana bar, one for each shift your mana pays for. Shifts you cannot afford stay as faint notches and light up as your mana returns. They breathe gently on Normal and glow on High, following the combo point animation quality.", false, "Shift marks"))),
            Page.When("manaEnabled", Page.When("manaSweep", Page.Action("Preview five-second rule", "Run one sweep on the mana bar.", function()
                if SoundAlerter.ManaSweep then SoundAlerter.ManaSweep:Preview() end
            end, false, "Five-second rule"))),
            Page.Visible(swingSupported, Page.Toggle("swingSpark", "Swing spark", "A small spark runs along the top border of the bar your form uses and reaches the end as your next swing lands. Off-hand runs along the bottom border. It shows only while you are swinging, and needs an energy, rage, mana or health bar shown.", false, "Swing timer")),
            Page.Visible(swingSupported, Page.When("swingSpark", Page.Toggle("swingSparkFlash", "Flash when the swing lands", "The bar's border flashes briefly each time a swing lands.", false, "Swing timer"))),
            Page.Visible(swingSupported, Page.When("swingSpark", Page.Action("Preview spark", "Run one pass on the bar your form uses.", function()
                if SoundAlerter.SwingSpark then SoundAlerter.SwingSpark:Preview() end
            end, false, "Swing timer"))),
        },
    })
end
