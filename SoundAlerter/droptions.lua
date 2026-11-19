local SoundAlerter = SoundAlerter

local ICON = "Interface\\Icons\\Ability_Rogue_KidneyShot"
local ROWS = { { unit = "player", title = "You" }, { unit = "target", title = "Target" }, { unit = "focus", title = "Focus" } }
local CARD = { HEAD = 30, PAD = 10, GAP = 4, STEP = 26, SPACE = 6 }
local open = { player = true }

local function tracker()
    return SoundAlerter.DRTracker
end

local function countOn(set)
    local on = 0
    if not set then return on end
    for _, category in ipairs(SA_DRModel.ORDER) do
        if set[category] then on = on + 1 end
    end
    return on
end

local function summary(settings)
    local units = {}
    for _, row in ipairs(ROWS) do
        if settings[row.unit] then units[#units + 1] = row.title:lower() end
    end
    return SoundAlerter.Page.Summary(settings, #units > 0 and table.concat(units, " + ") or "no rows", #SA_DRModel.ORDER .. " categories per row")
end

local function cardText(settings, unit)
    if not settings[unit] then return "off" end
    local cats = settings.cats and settings.cats[unit]
    local text = countOn(cats) .. " of " .. #SA_DRModel.ORDER .. " categories"
    if settings.say and settings.say[unit] then text = text .. " · says immune" end
    return text
end

local function newCard(state, frame, page, row)
    local Kit = SoundAlerter.Page.Kit
    local unit = row.unit
    local card = { unit = unit, actions = {}, cats = {} }
    local box = CreateFrame("Frame", nil, frame)
    local fill = Kit.Paint(box, Kit.COLOR.card)
    fill:SetAllPoints(box)
    Kit.Outline(box, Kit.COLOR.line)
    card.frame = box
    local head = CreateFrame("Button", nil, box)
    head:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
    head:SetHeight(CARD.HEAD)
    card.head = head
    local tint = Kit.Paint(head, Kit.COLOR.line, 0.35, "BORDER")
    tint:SetAllPoints(head)
    tint:Hide()
    SA_MenuFX.Hover(head, tint)
    card.title = Kit.Text(head, 12, Kit.COLOR.text)
    card.title:SetPoint("LEFT", head, "LEFT", CARD.PAD, 0)
    card.title:SetText(row.title)
    card.caret = Kit.Text(head, 12, Kit.COLOR.muted, "RIGHT")
    card.caret:SetPoint("RIGHT", head, "RIGHT", -CARD.PAD, 0)
    card.summary = Kit.Text(head, 11, Kit.COLOR.muted)
    card.summary:SetPoint("LEFT", card.title, "RIGHT", 10, 0)
    head:SetScript("OnClick", function()
        open[unit] = not open[unit]
        page:Refresh()
    end)
    local function set(key, value)
        page.spec.set(key, value)
        page:Refresh()
    end
    card.show = Kit.MakeChip(box, "Show this row", function() set(unit, not state.settings[unit]) end)
    card.say = Kit.MakeChip(box, "Say immune", function() set("say." .. unit, not (state.settings.say and state.settings.say[unit])) end)
    card.copy = Kit.MakeChip(box, "Copy to all rows", function()
        local active = tracker()
        if active then active:CopyRow(unit) end
        page:Refresh()
    end)
    card.actions[1], card.actions[2], card.actions[3] = card.show, card.say, card.copy
    for index, category in ipairs(SA_DRModel.ORDER) do
        local chip = Kit.MakeChip(box, SA_DRModel.CATEGORIES[category].name, function()
            local cats = state.settings.cats and state.settings.cats[unit]
            set("cats." .. unit .. "." .. category, not (cats and cats[category]))
        end)
        chip.category = category
        card.cats[index] = chip
    end
    return card
end

local function buildCards(frame, page)
    local state = { frame = frame, page = page, cards = {}, height = 0 }
    for index, row in ipairs(ROWS) do state.cards[index] = newCard(state, frame, page, row) end
    return state
end

local function signature(settings, width)
    local parts = { width }
    for _, row in ipairs(ROWS) do
        local unit = row.unit
        local cats = settings.cats and settings.cats[unit] or {}
        local bits = 0
        for index, category in ipairs(SA_DRModel.ORDER) do
            if cats[category] then bits = bits + 2 ^ (index - 1) end
        end
        parts[#parts + 1] = (settings[unit] and 1 or 0) .. (settings.say and settings.say[unit] and 1 or 0) .. (open[unit] and 1 or 0) .. bits
    end
    return table.concat(parts, "|")
end

local function setShown(list, shown)
    for _, chip in ipairs(list) do chip.frame:SetShown(shown) end
end

local function updateCards(state, settings, width)
    state.settings = settings
    local key = signature(settings, width)
    if key == state.key then return state.height end
    state.key = key
    state.layouts = (state.layouts or 0) + 1
    local Kit = SoundAlerter.Page.Kit
    local y = 0
    for _, card in ipairs(state.cards) do
        local unit = card.unit
        local isOpen = open[unit] and true or false
        card.summary:SetText(cardText(settings, unit))
        card.caret:SetText(isOpen and "v" or ">")
        Kit.Tint(card.caret, isOpen and Kit.COLOR.accent or Kit.COLOR.muted)
        local height = CARD.HEAD
        setShown(card.actions, isOpen)
        setShown(card.cats, isOpen)
        if isOpen then
            local cats = settings.cats and settings.cats[unit] or {}
            card.show:Set(settings[unit] and true or false)
            card.say:Set(settings.say and settings.say[unit] and true or false)
            card.copy:Set(false)
            for _, chip in ipairs(card.cats) do chip:Set(cats[chip.category] == true, settings[unit] and true or false) end
            local inner = width - CARD.PAD * 2
            local below = Kit.Flow(card.frame, card.actions, inner, CARD.GAP, CARD.PAD, CARD.HEAD, CARD.STEP)
            below = Kit.Flow(card.frame, card.cats, inner, CARD.GAP, CARD.PAD, below + 4, CARD.STEP)
            height = below + CARD.PAD - 4
        end
        card.frame:ClearAllPoints()
        card.frame:SetPoint("TOPLEFT", state.frame, "TOPLEFT", 0, -y)
        card.frame:SetSize(width, height)
        y = y + height + CARD.SPACE
    end
    state.height = y
    return y
end

function SoundAlerter:BuildDRTrackerOptions()
    local Page = SoundAlerter.Page
    local rows = {
        Page.Toggle("locked", "Lock position", "Unlock to drag each row anywhere on screen, then lock it again.", false, "General"),
        Page.Action("Reset position", "Put every row back at its starting spot.", function()
            local active = tracker()
            if active then active:ResetPositions() end
        end, false, "General"),
        Page.Action("Test", "Shows sample icons for a few seconds.", function()
            local active = tracker()
            if active then active:RunTest() end
        end, false, "General"),
        Page.Custom(CARD.HEAD * 3, buildCards, updateCards, false, "Rows"),
        Page.Range("size", "Icon size", "Size of each icon.", 24, 56, 1, false, "Layout", " px"),
        Page.Range("spacing", "Spacing", "Gap between icons.", 0, 10, 1, false, "Layout", " px"),
        Page.Toggle("numbers", "Countdown numbers", "Seconds left on the crowd control, then on the reset.", false, "Look"),
        Page.Toggle("tags", "Category tag", "The category letters in the corner of each icon.", false, "Look"),
    }

    return Page.Module({
        key = "DRTracker",
        title = "Diminishing Returns",
        icon = ICON,
        desc = "Crowd control diminishing returns on you, your target and focus.",
        blurb = "Experimental. Each crowd control category on you, your target and focus: the border shows how long the next one lasts (green half, yellow a quarter, red immune) and the countdown shows when it resets. Open a row below to choose its categories and whether it says \"immune\".",
        order = 2.94,
        module = tracker,
        defaults = function() return dbDefaults.profile.drTracker end,
        summary = summary,
        rows = rows,
    })
end
