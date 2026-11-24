local SoundAlerter = SoundAlerter

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local UNITS = { "player", "target", "focus" }
local LABELS = { player = "Player", target = "Target", focus = "Focus" }
local ORIENTATIONS = { { "horizontal", "Horizontal" }, { "vertical", "Vertical" } }
local TIME_FORMATS = { { "milliseconds", "SS.sss (Milliseconds)" }, { "centiseconds", "SS.ss (Centiseconds)" } }
local HORIZONTAL_FILLS = { { "right", "Right" }, { "left", "Left" } }
local VERTICAL_FILLS = { { "up", "Up" }, { "down", "Down" } }
local TEXTURE_QUALITIES = { { "low", "Low" }, { "normal", "Normal" }, { "high", "High" } }
local ANIM_QUALITIES = { { "off", "Off" }, { "low", "Low" }, { "normal", "Normal" }, { "high", "High" } }
local PREVIEW_LENGTH = 200

local function bars()
    return SoundAlerter.CastingBars
end

local function write(active, key, value)
    active:SetSetting(key, value)
end

local function fillOptions(unit)
    return function(settings)
        local row = settings[unit]
        if row and row.orientation == "vertical" then return VERTICAL_FILLS end
        return HORIZONTAL_FILLS
    end
end

local CORNERS = { { "off", "Square" }, { "small", "Small" }, { "medium", "Medium" }, { "large", "Large" } }

local function textureOptions()
    local values = SoundAlerter.BarTexture and SoundAlerter.BarTexture:Values(true) or {}
    local list = {}
    for key, label in pairs(values) do list[#list + 1] = { key, label } end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    return list
end

local function unitTextureOptions()
    local list = { { "inherit", "Same as all bars" } }
    for _, option in ipairs(textureOptions()) do list[#list + 1] = option end
    return list
end

local CastPreview = { height = 110 }

function CastPreview.build(stage)
    local state = { stage = stage }
    state.track = stage:CreateTexture(nil, "BACKGROUND")
    state.track:SetTexture(FLAT)
    state.track:SetVertexColor(0.227, 0.263, 0.322, 1)
    state.track:SetPoint("CENTER", stage, "CENTER", 12, 6)
    state.fill = stage:CreateTexture(nil, "ARTWORK")
    state.fill:SetTexture(FLAT)
    state.fill:SetVertexColor(1, 0.7, 0, 1)
    state.latency = stage:CreateTexture(nil, "OVERLAY")
    state.latency:SetTexture(FLAT)
    state.latency:SetVertexColor(0.9, 0.15, 0.15, 0.7)
    state.icon = stage:CreateTexture(nil, "ARTWORK")
    state.icon:SetTexture("Interface\\Icons\\Spell_Fire_FlameBolt")
    state.time = stage:CreateFontString(nil, "OVERLAY")
    state.time:SetFont(FONT, 11, "OUTLINE")
    state.time:SetTextColor(1, 1, 1)
    return state
end

function CastPreview.update(state, settings)
    if not state then return end
    local unit = settings.player
    local vertical = unit.orientation == "vertical"
    local long = math.max(40, math.min(PREVIEW_LENGTH, unit.width * 0.42))
    local short = math.max(10, math.min(34, unit.height * 0.7))
    local width, height = long, short
    if vertical then width, height = short, math.min(long, 90) end
    local progress = 0.6
    state.track:SetSize(width, height)
    state.track:SetAlpha(unit.enabled and 1 or 0.25)
    state.fill:ClearAllPoints()
    state.latency:ClearAllPoints()
    local fill, shadow = state.fill, state.latency
    local direction = unit.fillDirection
    if vertical then
        fill:SetSize(width, height * progress)
        shadow:SetSize(width, height * 0.1)
        if direction == "down" then
            fill:SetPoint("TOP", state.track, "TOP", 0, 0)
            shadow:SetPoint("TOP", fill, "BOTTOM", 0, 0)
        else
            fill:SetPoint("BOTTOM", state.track, "BOTTOM", 0, 0)
            shadow:SetPoint("BOTTOM", fill, "TOP", 0, 0)
        end
    else
        fill:SetSize(width * progress, height)
        shadow:SetSize(width * 0.1, height)
        if direction == "left" then
            fill:SetPoint("RIGHT", state.track, "RIGHT", 0, 0)
            shadow:SetPoint("RIGHT", fill, "LEFT", 0, 0)
        else
            fill:SetPoint("LEFT", state.track, "LEFT", 0, 0)
            shadow:SetPoint("LEFT", fill, "RIGHT", 0, 0)
        end
    end
    fill:SetAlpha(unit.enabled and 1 or 0.25)
    shadow:SetShown(settings.showLatency and unit.enabled)
    state.icon:SetSize(height, height)
    state.icon:ClearAllPoints()
    state.icon:SetPoint("RIGHT", state.track, "LEFT", -3, 0)
    state.icon:SetShown(settings.showSpellIcon)
    state.time:ClearAllPoints()
    state.time:SetPoint("CENTER", state.track, "CENTER", 0, 0)
    state.time:SetText(settings.timeFormat == "centiseconds" and "1.48" or "1.482")
end

local function summary(settings)
    local Page = SoundAlerter.Page
    local shown = {}
    for _, unit in ipairs(UNITS) do
        if settings[unit].enabled then shown[#shown + 1] = LABELS[unit] end
    end
    return Page.Summary(settings,
        #shown > 0 and table.concat(shown, ", ") or "no bars shown",
        settings.locked and "locked" or "unlocked, drag to move")
end

local function castTabs()
    local bars = { "Bars", "Layout" }
    for _, unit in ipairs(UNITS) do bars[#bars + 1] = LABELS[unit] .. " casting bar" end
    return {
        { key = "bars", label = "Bars", groups = bars },
        { key = "look", label = "Look", groups = { "Look", "On the bar" } },
        { key = "animations", label = "Animations", groups = { "Animations" } },
    }
end

function SoundAlerter:BuildCastingBarOptions()
    local Page = SoundAlerter.Page
    local rows = {
        Page.Action("Apply pyramid layout", "Positions Player, Target, and Focus casting bars into a pyramid: Player centered on top, Target and Focus symmetrically below to the left and right.", function()
            local active = bars()
            if active then
                active:ApplyPyramidLayout()
                active:Apply()
            end
        end, false, "Layout"),
        Page.Select("barTexture", "Bar texture", "The texture every casting bar uses unless it picks its own below. Long grass and Dead gnomes are casting bar only.", textureOptions(), false, "Look"),
        Page.Select("roundCorners", "Rounded corners", "Rounds the corners of every casting bar, its fill, background and animated texture included. Small, Medium and Large are 4, 7 and 11 pixels, made smaller on bars too thin for them.", CORNERS, false, "Look"),
        Page.Select("barTextureQuality", "Texture quality", "Low animates 15 times a second and drops the farthest layer. Normal is the full animation. High adds a fourth layer to Fire, Leaves, Long grass and Dead gnomes. Only animated textures are affected.", TEXTURE_QUALITIES, true, "Look"),
        Page.Toggle("showSpellIcon", "Show spell icons", "Display spell icons to the left of casting bars.", false, "On the bar"),
        Page.Toggle("showLockIcon", "Show a lock on casts you cannot interrupt", "Draws a small padlock on the bar while the cast cannot be interrupted. Works on enemy casts too: the game decides whether the lock shows, because the addon is not allowed to read that flag for enemies.", false, "On the bar"),
        Page.Toggle("hoverTooltip", "Spell tooltip on hover", "Mouse over the target or focus bar during a cast to see the full spell tooltip (rank, cost, cast time, description), even when the game hides the spell. While a cast is up the bar catches the mouse, so clicks on it stop there.", false, "On the bar"),
        Page.Toggle("showLatency", "Show latency shadow", "Display a red shadow at the end of the player casting bar representing network latency. Helps predict when the spell will actually cast on the server.", false, "On the bar"),
        Page.Select("timeFormat", "Time format", "Choose how cast time is displayed. SS.sss shows seconds with milliseconds (02.450), SS.ss shows seconds with centiseconds (02.45).", TIME_FORMATS, true, "On the bar"),
        Page.Toggle("segments", "Segmented bars", "Draw faint tick marks along the bar so progress is easy to read at a glance.", false, "Animations"),
        Page.Toggle("channelPulse", "Channel pulses", "Flash the bar at the quarter points of a channelled spell. These are evenly spaced pulses, not the spell's real damage ticks, which the game does not expose.", false, "Animations"),
        Page.Select("animQuality", "Animation quality", "Off turns every animation off. Low keeps the effects minimal and redraws the fill 15 times a second, Normal adds the full animations, High adds gloss, extra rings and sub-pixel fill. Applies to every casting bar.", ANIM_QUALITIES, true, "Animations"),
    }
    for _, unit in ipairs(UNITS) do
        rows[#rows + 1] = Page.Toggle(unit .. ".enabled", "Show " .. LABELS[unit] .. " casting bar", "Display a casting bar for " .. (unit == "player" and "your own spells." or "your " .. unit .. "'s spells."), false, "Bars")
    end
    for _, unit in ipairs(UNITS) do
        local group = LABELS[unit] .. " casting bar"
        local enabledKey = unit .. ".enabled"
        rows[#rows + 1] = Page.When(enabledKey, Page.Select(unit .. ".barTexture", "Texture", "This bar's own texture. Same as all bars uses the Bar texture above.", unitTextureOptions(), false, group))
        rows[#rows + 1] = Page.When(enabledKey, Page.Range(unit .. ".width", "Width", "Width of the " .. unit .. " casting bar.", 100, 500, 10, true, group, " px"))
        rows[#rows + 1] = Page.When(enabledKey, Page.Range(unit .. ".height", "Height", "Height of the " .. unit .. " casting bar.", 12, 50, 2, true, group, " px"))
        rows[#rows + 1] = Page.When(enabledKey, Page.Select(unit .. ".orientation", "Bar orientation", "Horizontal or vertical fill for the " .. unit .. " casting bar.", ORIENTATIONS, true, group))
        rows[#rows + 1] = Page.When(enabledKey, Page.Select(unit .. ".fillDirection", "Fill direction", "Direction the bar fills as the cast progresses.", fillOptions(unit), true, group))
    end

    return Page.Module({
        key = "CastingBars",
        title = "Casting Bars",
        icon = "Interface\\Icons\\Spell_Arcane_Blast",
        desc = "Display casting and channeling progress for player, target, and focus with precise timing information.",
        blurb = "Casting bars for you, your target and your focus, with their own textures, sizes and fill directions.",
        order = 2.85,
        master = false,
        module = bars,
        write = write,
        defaults = function() return dbDefaults.profile.castingBars end,
        summary = summary,
        preview = CastPreview,
        lock = {
            key = "locked",
            hint = "Unlocked: drag any bar. A shaded outline marks each one.",
        },
        tabs = castTabs(),
        rows = rows,
    })
end
