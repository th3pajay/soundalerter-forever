local SoundAlerter = SoundAlerter

local ICON = "Interface\\Icons\\Ability_Rogue_KidneyShot"

local function tracker()
    return SoundAlerter.DRTracker
end

local function summary(settings)
    local units = {}
    if settings.target then units[#units + 1] = "target" end
    if settings.focus then units[#units + 1] = "focus" end
    local on = 0
    for _, category in ipairs(SA_DRModel.ORDER) do
        if settings.categories and settings.categories[category] then on = on + 1 end
    end
    return SoundAlerter.Page.Summary(settings,
        #units > 0 and table.concat(units, " + ") or "no units",
        on .. " of " .. #SA_DRModel.ORDER .. " categories")
end

function SoundAlerter:BuildDRTrackerOptions()
    local Page = SoundAlerter.Page
    local rows = {
        Page.Toggle("locked", "Lock position", "Unlock to drag each row anywhere on screen, then lock it again.", false, "General"),
        Page.Action("Reset position", "Put both rows back at their starting spots.", function()
            local active = tracker()
            if active then active:ResetPositions() end
        end, false, "General"),
        Page.Action("Test", "Shows sample icons for a few seconds.", function()
            local active = tracker()
            if active then active:RunTest() end
        end, false, "General"),
        Page.Toggle("target", "Track the target", "Counts crowd control on your target and shows its row.", false, "General"),
        Page.Toggle("focus", "Track the focus", "Counts crowd control on your focus and shows its row.", false, "General"),
        Page.Toggle("voice", "Say when the next one is immune", "Says \"immune\" when crowd control lands on your target or focus and the next one of that kind would do nothing.", false, "General"),
        Page.Range("size", "Icon size", "Size of each icon.", 24, 56, 1, false, "Layout", " px"),
        Page.Range("spacing", "Spacing", "Gap between icons.", 0, 10, 1, false, "Layout", " px"),
        Page.Toggle("numbers", "Countdown numbers", "Seconds left on the crowd control, then on the reset.", false, "Look"),
        Page.Toggle("tags", "Category tag", "The category letters in the corner of each icon.", false, "Look"),
    }
    for _, category in ipairs(SA_DRModel.ORDER) do
        local info = SA_DRModel.CATEGORIES[category]
        rows[#rows + 1] = Page.Toggle("categories." .. category, info.name, "Track " .. info.name:lower() .. " effects (tag " .. info.tag .. ").", false, "Categories")
    end

    return Page.Module({
        key = "DRTracker",
        title = "Diminishing Returns",
        icon = ICON,
        desc = "Crowd control diminishing returns on your target and focus.",
        blurb = "Experimental. Each crowd control category on your target and focus: the border shows how long the next one lasts (green half, yellow a quarter, red immune) and the countdown shows when it resets. Only crowd control seen on your target or focus is counted.",
        order = 2.94,
        module = tracker,
        defaults = function() return dbDefaults.profile.drTracker end,
        summary = summary,
        rows = rows,
    })
end
