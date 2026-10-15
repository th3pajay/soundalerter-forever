local SoundAlerter = SoundAlerter

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local UNITS = { "player", "target", "focus" }
local LABELS = { player = "Player", target = "Target", focus = "Focus" }
local ORIENTATIONS = { { "horizontal", "Horizontal" }, { "vertical", "Vertical" } }
local TIME_FORMATS = { { "milliseconds", "SS.sss (Milliseconds)" }, { "centiseconds", "SS.ss (Centiseconds)" } }
local HORIZONTAL_FILLS = { { "right", "Right" }, { "left", "Left" } }
local VERTICAL_FILLS = { { "up", "Up" }, { "down", "Down" } }
local PREVIEW_LENGTH = 200

local function bars()
    return SoundAlerter.CastingBars
end

local function write(active, key, value)
    active:SetSetting(key, value)
    local unit = key:match("^(%a+)%.")
    if key == "locked" then
        active:SetLocked(value)
    elseif key == "barTexture" then
        active:UpdateTexture()
    elseif unit then
        if key:match("%.orientation$") then
            local fill = active:GetSettings()[unit].fillDirection
            if value == "vertical" and fill ~= "up" and fill ~= "down" then
                active:SetSetting(unit .. ".fillDirection", "up")
            elseif value == "horizontal" and fill ~= "left" and fill ~= "right" then
                active:SetSetting(unit .. ".fillDirection", "right")
            end
        end
        active:LoadSettings()
    end
end

local function fillOptions(unit)
    return function(settings)
        local row = settings[unit]
        if row and row.orientation == "vertical" then return VERTICAL_FILLS end
        return HORIZONTAL_FILLS
    end
end

local function textureOptions()
    local values = SoundAlerter.BarTexture and SoundAlerter.BarTexture:Values() or {}
    local list = {}
    for key, label in pairs(values) do list[#list + 1] = { key, label } end
    table.sort(list, function(a, b) return a[2] < b[2] end)
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

function SoundAlerter:BuildCastingBarOptions()
    local Page = SoundAlerter.Page
    local rows = {
        Page.Toggle("locked", "Lock bars", "Lock all casting bars in place. Unlock to drag and reposition.", false, "General"),
        Page.Action("Apply pyramid layout", "Positions Player, Target, and Focus casting bars into a pyramid: Player centered on top, Target and Focus symmetrically below to the left and right.", function()
            local active = bars()
            if active then
                active:ApplyPyramidLayout()
                active:LoadSettings()
            end
        end, false, "General"),
        Page.Select("barTexture", "Bar texture", "Choose the visual texture for all casting bars. Matches resource bar texture options for consistency.", textureOptions(), false, "General"),
        Page.Toggle("showSpellIcon", "Show spell icons", "Display spell icons to the left of casting bars.", false, "General"),
        Page.Toggle("showLatency", "Show latency shadow", "Display a red shadow at the end of the player casting bar representing network latency. Helps predict when the spell will actually cast on the server.", false, "General"),
        Page.Select("timeFormat", "Time format", "Choose how cast time is displayed. SS.sss shows seconds with milliseconds (02.450), SS.ss shows seconds with centiseconds (02.45).", TIME_FORMATS, true, "General"),
    }
    for _, unit in ipairs(UNITS) do
        rows[#rows + 1] = Page.Toggle(unit .. ".enabled", "Show " .. LABELS[unit] .. " casting bar", "Display a casting bar for " .. (unit == "player" and "your own spells." or "your " .. unit .. "'s spells."), false, "Bars")
    end
    for _, unit in ipairs(UNITS) do
        local group = LABELS[unit] .. " casting bar"
        local enabledKey = unit .. ".enabled"
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
        rows = rows,
    })
end
