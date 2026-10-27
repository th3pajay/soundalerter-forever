local SoundAlerter = SoundAlerter

local ICON = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01"
local PREVIEW_ICONS = {
    "Interface\\Icons\\INV_Jewelry_TrinketPVP_01",
    "Interface\\Icons\\INV_Misc_Gem_Pearl_04",
    "Interface\\Icons\\INV_Misc_QuestionMark",
    "Interface\\Icons\\INV_Chest_Plate06",
}
local TRINKET_COLOR = { 0.66, 0.77, 0.9 }
local SET_COLOR = { 0.24, 0.84, 0.78 }
local GEAR_COLOR = { 0.74, 0.58, 0.96 }
local BUTTON_COLORS = { TRINKET_COLOR, TRINKET_COLOR, SET_COLOR, GEAR_COLOR }

local function menu()
    return SoundAlerter.TrinketMenu
end

local function setName(set, slot)
    local id = set and set[slot]
    if not id then return "empty" end
    return SA_COMPAT.ItemName(id) or ("item " .. id)
end

local function setsText(settings)
    local lines = {}
    for index = 1, SA_TrinketModel.SET_COUNT do
        local set = settings.sets[index]
        local marker = index == settings.activeSet and "|cff3dd6c6>|r " or "   "
        if SA_TrinketModel.SetFilled(set) then
            lines[index] = marker .. "Set " .. index .. ": " .. setName(set, 13) .. " + " .. setName(set, 14)
        else
            lines[index] = marker .. "Set " .. index .. ": empty"
        end
    end
    return table.concat(lines, "\n")
end

local function gearOptions()
    local options = { { "", "None" } }
    for _, set in ipairs(SA_COMPAT.GearSets()) do options[#options + 1] = { set.name, set.name } end
    return options
end

local function gearText()
    if not SA_COMPAT.GearAvailable() then return "This client has no equipment sets, so the gear button stays hidden." end
    local sets = SA_COMPAT.GearSets()
    if #sets == 0 then return "No equipment sets yet. Make them in the character panel, then pick them here." end
    local names = {}
    for index, set in ipairs(sets) do
        names[index] = set.equipped and ("|cffbd94f5" .. set.name .. "|r (worn)") or set.name
    end
    return "Your sets: " .. table.concat(names, ", ")
end

local TrinketPreview = { height = 96 }

function TrinketPreview.build(stage)
    local state = { stage = stage, icons = {} }
    for index = 1, #PREVIEW_ICONS do
        local edge = stage:CreateTexture(nil, "BORDER")
        local icon = stage:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(PREVIEW_ICONS[index])
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon:SetPoint("TOPLEFT", edge, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -2, 2)
        local color = BUTTON_COLORS[index]
        edge:SetColorTexture(color[1], color[2], color[3], 1)
        state.icons[index] = { edge = edge, icon = icon }
    end
    state.caption = stage:CreateFontString(nil, "OVERLAY")
    state.caption:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
    state.caption:SetPoint("BOTTOM", stage, "BOTTOM", 0, 0)
    state.caption:SetTextColor(0.588, 0.627, 0.698)
    return state
end

function TrinketPreview.update(state, settings)
    if not state then return end
    local size = math.max(14, math.min(26, settings.iconSize * 0.6))
    local spacing = math.max(2, settings.spacing * 0.6)
    local offsets, width, height = SA_TrinketModel.Layout(settings.orientation, settings.swapOrder, settings.showSet, settings.showGear, size, spacing)
    local keys = { 13, 14, "set", "gear" }
    for index, key in ipairs(keys) do
        local parts = state.icons[index]
        local offset = offsets[key]
        parts.edge:ClearAllPoints()
        if offset then
            parts.edge:SetSize(size, size)
            parts.edge:SetPoint("TOPLEFT", state.stage, "CENTER", offset[1] - width / 2, offset[2] + height / 2 + 6)
            parts.edge:Show()
            parts.icon:Show()
        else
            parts.edge:Hide()
            parts.icon:Hide()
        end
    end
    state.caption:SetText((settings.orientation == "horizontal" and "Horizontal" or "Vertical") .. (settings.showSet and ", set button" or "") .. (settings.showGear and ", gear button" or ""))
end

local function gearSummary(settings)
    if not settings.showGear then return nil end
    local main, alt = SA_TrinketModel.Named(settings.gearMain), SA_TrinketModel.Named(settings.gearAlt)
    if not main then return "gear button, no set picked" end
    return "gear " .. main .. (alt and (" / " .. alt) or "")
end

local function summary(settings)
    local Page = SoundAlerter.Page
    return Page.Summary(settings,
        settings.orientation == "horizontal" and "horizontal" or "vertical",
        settings.locked and "locked" or "unlocked, drag to move",
        "set " .. settings.activeSet,
        gearSummary(settings))
end

local function saveAction(index)
    return SoundAlerter.Page.Action("Save set " .. index, "Save the two trinkets you are wearing as set " .. index .. ".", function()
        local active = menu()
        if not active then return false end
        return active:SaveSet(index)
    end, false, "Sets")
end

function SoundAlerter:BuildTrinketMenuOptions()
    local Page = SoundAlerter.Page
    local rows = {
        Page.Experimental(Page.Block("Experimental", function()
            return "Click a trinket to use it, right-click to swap top and bottom, hover for the trinkets in your bags. The gear button switches between your main and alternate equipment set, right-click it for all sets. Swaps made in combat wait until combat ends. Keys: Options > Key Bindings > AddOns > SoundAlerter."
        end, false, "General")),
        Page.Toggle("locked", "Lock position", "Unlock to drag the bar. A shaded outline marks it while unlocked. Moving waits until combat ends.", false, "General"),
        Page.Toggle("flyout", "Bag trinkets on hover", "Hovering a trinket opens the trinkets in your bags. Click one to equip it into that slot.", false, "General"),
        Page.Toggle("tooltips", "Tooltips", "Show the item tooltip and the click hints on hover.", false, "General"),
        Page.Action("Test", "Show a sample cooldown and the waiting glow.", function()
            local active = menu()
            if active then active:RunTest() end
        end, false, "General"),
        Page.Select("orientation", "Orientation", "Stack the buttons top to bottom or left to right.", SA_TrinketModel.ORIENTATIONS, false, "Look"),
        Page.Toggle("swapOrder", "Bottom trinket first", "Put the bottom trinket slot first on the bar.", false, "Look"),
        Page.Toggle("showSet", "Set button", "A third button in its own colour that equips one of your three saved sets.", false, "Look"),
        Page.Toggle("cooldownNumbers", "Cooldown numbers", "Seconds left in the corner of each trinket.", false, "Look"),
        Page.Range("iconSize", "Icon size", "Size of each button.", 20, 64, 1, false, "Look", " px"),
        Page.Range("spacing", "Spacing", "Gap between the buttons.", 0, 16, 1, true, "Look", " px"),
        Page.Toggle("fade", "Fade when idle", "Fade the bar after a while without the mouse over it.", false, "Look"),
        Page.When("fade", Page.Range("fadeAlpha", "Faded opacity", "How visible the bar stays once faded.", 0, 0.9, 0.05, true, "Look")),
        Page.When("fade", Page.Range("fadeDelay", "Fade after", "Seconds without the mouse before the bar fades.", 1, 15, 0.5, true, "Look", " s")),
        Page.Toggle("collapse", "Collapse to a diamond", "Show a small diamond instead of the bar. Hover the diamond to open the bar, also in combat.", false, "Look"),
        Page.Block("Saved sets", setsText, false, "Sets"),
        saveAction(1),
        saveAction(2),
        saveAction(3),
        Page.Toggle("showGear", "Gear set button", "A fourth button that switches between two of your equipment sets, for example damage and healing gear. Swaps in combat wait until combat ends.", false, "Gear"),
        Page.When("showGear", Page.Stepper(Page.Select("gearMain", "Main set", "The set you wear most. A click goes back to it.", gearOptions, false, "Gear"))),
        Page.When("showGear", Page.Stepper(Page.Select("gearAlt", "Alternate set", "The set a click switches to from the main set.", gearOptions, false, "Gear"))),
        Page.Block("Equipment sets", gearText, false, "Gear"),
        Page.Action("Reset position", "Put the bar back where it started.", function()
            local active = menu()
            if active then active:ResetPosition() end
        end, true, "General"),
    }

    return Page.Module({
        key = "TrinketMenu",
        title = "Trinket Menu",
        icon = ICON,
        desc = "Your two trinkets with cooldowns, a bag flyout for swapping, three saved sets and a gear set switch.",
        blurb = "Experimental. Your trinkets on a small bar: use them, swap them from your bags, switch between three saved sets and between two equipment sets. Swaps wait until combat ends.",
        order = 2.92,
        module = menu,
        defaults = function() return dbDefaults.profile.trinketMenu end,
        summary = summary,
        preview = TrinketPreview,
        rows = rows,
    })
end
