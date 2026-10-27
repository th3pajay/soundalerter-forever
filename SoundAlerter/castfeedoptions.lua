local SoundAlerter = SoundAlerter

local ICON = "Interface\\Icons\\Spell_Nature_Lightning"
local PREVIEW_ICONS = 5

local UNITS = { "player", "target", "focus", "party1", "party2", "party3", "party4", "enemies" }
local LABELS = {
    player = "Player", target = "Target", focus = "Focus",
    party1 = "Party 1", party2 = "Party 2", party3 = "Party 3", party4 = "Party 4", enemies = "Enemies",
}
local ROW_HINTS = {
    enemies = "Casts of nearby enemy players, not your target or focus. Needs Show hidden enemy spells on (General).",
}
local DIRECTIONS = { { "left", "Left" }, { "right", "Right" }, { "up", "Up" }, { "down", "Down" } }

local function feed()
    return SoundAlerter.CastFeed
end

local function write(active, key, value)
    active:SetSetting((key:gsub("^rows%.", "")), value)
    active:LoadSettings()
    if key == "auraDisplay" and SoundAlerter.AuraDisplay then SoundAlerter.AuraDisplay:Refresh(true) end
end

local function copyToAll(unit)
    local active = feed()
    if not active then return end
    local source = active:GetSettings().rows[unit]
    for _, target in ipairs(UNITS) do
        active:SetSetting(target .. ".direction", source.direction)
        active:SetSetting(target .. ".scale", source.scale)
    end
    active:LoadSettings()
end

local FeedPreview = { height = 90 }

function FeedPreview.build(stage)
    local state = { stage = stage, icons = {} }
    for index = 1, PREVIEW_ICONS do
        local icon = stage:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(ICON)
        state.icons[index] = icon
    end
    state.caption = stage:CreateFontString(nil, "OVERLAY")
    state.caption:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
    state.caption:SetPoint("BOTTOM", stage, "BOTTOM", 0, 0)
    state.caption:SetTextColor(0.588, 0.627, 0.698)
    return state
end

function FeedPreview.update(state, settings)
    if not state then return end
    local row = settings.rows.player
    local size = math.max(10, math.min(34, settings.iconSize * row.scale * 0.55))
    local gap = size + math.max(2, settings.spacing * 0.5)
    local vertical = row.direction == "up" or row.direction == "down"
    local count = vertical and 3 or PREVIEW_ICONS
    local reverse = row.direction == "right" or row.direction == "down"
    for index = 1, PREVIEW_ICONS do
        local icon = state.icons[index]
        if index > count then
            icon:Hide()
        else
            local slot = reverse and (count - index) or (index - 1)
            local offset = (slot - (count - 1) / 2) * gap
            icon:SetSize(size, size)
            icon:ClearAllPoints()
            if vertical then
                icon:SetPoint("CENTER", state.stage, "CENTER", 0, -offset + 4)
            else
                icon:SetPoint("CENTER", state.stage, "CENTER", offset, 6)
            end
            icon:SetAlpha(1 - 0.12 * (index - 1))
            icon:Show()
        end
    end
    state.caption:SetText("Player row: icons travel " .. row.direction)
end

local function summary(settings)
    local Page = SoundAlerter.Page
    local shown = {}
    for _, unit in ipairs(UNITS) do
        if settings.rows[unit].enabled then shown[#shown + 1] = LABELS[unit] end
    end
    return Page.Summary(settings,
        #shown > 0 and table.concat(shown, ", ") or "no rows shown",
        settings.locked and "locked" or "unlocked, drag to move")
end

function SoundAlerter:BuildCastFeedOptions()
    local Page = SoundAlerter.Page
    local rows = {
        Page.Toggle("locked", "Lock position", "Unlock to drag the rows. A shaded outline marks each row while unlocked.", false, "General"),
        Page.Toggle("showInstants", "Show instant casts", "Include casts that have no cast time. The client sends no cast event for most enemy instants, so only readable ones appear here (yours and your group's). The enemy buff and duel debuff option below is the way to see enemy instants.", false, "General"),
        Page.Visible(SA_Secret.Supported, Page.Toggle("auraDisplay", "Enemy buffs, duel debuffs", "Experimental. Flashes new buffs on your target and focus, and in duels new debuffs on you, beside their rows. Needs Show hidden enemy spells on (General).", false, "Experimental")),
        Page.Toggle("showGaps", "Show time between casts", "Show the time between two casts (such as 1.4s) between their icons. Icons spread out to make room.", false, "General"),
        Page.Action("Test", "Spawn a few sample casts.", function()
            local active = feed()
            if active then active:RunTest() end
        end, false, "General"),
        Page.Range("iconSize", "Icon size", "Icon size before each row's scale.", 16, 64, 1, false, "Look", " px"),
    }
    for _, unit in ipairs(UNITS) do
        local toggle = Page.Toggle("rows." .. unit .. ".enabled", LABELS[unit], ROW_HINTS[unit] or "Give this unit its own row.", false, "Rows")
        if unit == "enemies" then toggle = Page.Visible(SA_Secret.Supported, toggle) end
        rows[#rows + 1] = toggle
    end
    rows[#rows + 1] = Page.Range("spacing", "Spacing", "Minimum gap between icons.", 0, 24, 1, true, "Look", " px")
    rows[#rows + 1] = Page.Range("length", "Row length", "Distance icons travel before they disappear.", 100, 1000, 10, true, "Look", " px")
    rows[#rows + 1] = Page.Range("maxIcons", "Max icons", "Casts kept in each row; extra casts wait their turn.", 3, 30, 1, true, "Look")
    rows[#rows + 1] = Page.Range("speed", "Speed", "Travel speed in pixels per second.", 20, 300, 5, true, "Look", " px/s")
    rows[#rows + 1] = Page.Range("catchUp", "Catch-up speed", "How many times faster a row moves after you stop hovering, until it is current again.", 1.5, 10, 0.5, true, "Look", "x")
    rows[#rows + 1] = Page.Toggle("baseline", "Baseline", "A faint line the icons ride along while a row has casts.", true, "Look")
    rows[#rows + 1] = Page.Toggle("showClass", "Class marker", "A small class-coloured dot on casts by your target, focus, party and nearby enemies.", true, "Look")
    rows[#rows + 1] = Page.Select("animQuality", "Animation quality", "Low turns every icon animation off. Normal adds the fade-in, the cast sweep and the fade at the row's end. High adds a settle on arrival, a pulse on success and a shake on interrupt.", SA_CastFeedModel.QUALITIES, true, "Look")
    rows[#rows + 1] = Page.Range("gapFontSize","Time text size", "Font size of the time between casts.", 8, 20, 1, true, "Look", " px")
    rows[#rows + 1] = Page.Action("Reset positions", "Put every row back where it started.", function()
        local active = feed()
        if active then active:ResetPositions() end
    end, true, "General")
    for _, unit in ipairs(UNITS) do
        local group = LABELS[unit] .. " row"
        local enabledKey = "rows." .. unit .. ".enabled"
        local group_rows = {
            Page.When(enabledKey, Page.Select("rows." .. unit .. ".direction", "Direction", "Direction the icons travel. New casts appear at the opposite edge.", DIRECTIONS, true, group)),
            Page.When(enabledKey, Page.Range("rows." .. unit .. ".scale", "Scale", "Scales this row's icons, spacing and length together.", 0.5, 3, 0.05, true, group, "x")),
            Page.When(enabledKey, Page.Action("Copy to all rows", "Give every row this row's direction and scale.", function() copyToAll(unit) end, true, group)),
        }
        for _, row in ipairs(group_rows) do
            if unit == "enemies" then row = Page.Visible(SA_Secret.Supported, row) end
            rows[#rows + 1] = row
        end
    end

    return Page.Module({
        key = "CastFeed",
        title = "Cast Feed",
        icon = "Interface\\Icons\\Spell_Nature_Lightning",
        desc = "Icons of player, target, focus, party and nearby enemy casts moving across the screen, one row per unit.",
        blurb = "Every cast by you, your target, focus and party becomes an icon moving along that unit's own row. Hover an icon to freeze its row.",
        order = 2.86,
        module = feed,
        write = write,
        defaults = function() return dbDefaults.profile.castFeed end,
        summary = summary,
        preview = FeedPreview,
        rows = rows,
    })
end
