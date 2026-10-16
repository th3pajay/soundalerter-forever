local SoundAlerter = SoundAlerter
local Model = SA_TrackerModel
local GetSpellInfo = SA_COMPAT.GetSpellInfo

local MAX_ICONS = 20
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local PREVIEW_MAX_SIZE = 40
local PREVIEW_LINES = 5

local CLASS_COLORS = {
    Druid = "FF7D0A", Hunter = "ABD473", Mage = "69CCF0", Paladin = "F58CBA", Priest = "FFFFFF",
    Rogue = "FFF569", Shaman = "0070DE", Warlock = "9482C9", Warrior = "C79C6E", Other = "7C8596",
}
local UNIT_OPTIONS = { { "player", "Player (self)" }, { "target", "Target" } }
local AURA_OPTIONS = { { "HELPFUL", "Buff" }, { "HARMFUL", "Debuff" } }
local ANIM_QUALITIES = { { "off", "Off" }, { "low", "Low" }, { "normal", "Normal" }, { "high", "High" } }

local addForm = { spellID = "", unit = "player", auraType = "HELPFUL" }
local selectedIndex = nil
local undoSnapshot = nil
local lastPreset = nil
local classLookup = nil
local flat = {}

local function tracker()
    return SoundAlerter.SpellTracker
end

local function profileSettings()
    return SoundAlerter.db1.profile.spellTracker or {}
end

local function icons()
    return profileSettings().icons or {}
end

local function lookup()
    if not classLookup then
        classLookup = Model.BuildLookup(SoundAlerter.spellList or SoundAlerterSpells, SoundAlerterSpellMeta)
    end
    return classLookup
end

local function classOfSpell(spellID)
    local _, token = UnitClass("player")
    return Model.ClassOf(spellID, lookup(), token)
end

local function spellIcon(spellID)
    return select(3, GetSpellInfo(spellID)) or UNKNOWN_ICON
end

local function spellName(spellID)
    return GetSpellInfo(spellID) or "Unknown"
end

local function setIcon(index, key, value)
    if tracker() then tracker():SetIconSetting(index, key, value) end
end

local function clearUndo()
    undoSnapshot = nil
    lastPreset = nil
end

local function orderedIndices()
    local list = icons()
    local groups = Model.Groups(list, classOfSpell)
    local ordered = {}
    for _, class in ipairs(Model.CLASS_ORDER) do
        for _, index in ipairs(groups[class]) do
            ordered[#ordered + 1] = { index = index, class = class }
        end
    end
    return ordered
end

local function view()
    local active = tracker()
    if not active then return nil end
    local list = icons()
    local ordered = orderedIndices()
    flat = {}

    local slots = {}
    local enabledCount = 0
    for slot = 1, MAX_ICONS do
        local entry = ordered[slot]
        local config = entry and list[entry.index]
        flat[slot] = entry and entry.index or nil
        local data = { present = config ~= nil, enabled = false, label = "", selected = false }
        if config then
            data.enabled = config.enabled and true or false
            data.selected = entry.index == selectedIndex
            data.label = "|cff" .. CLASS_COLORS[entry.class] .. entry.class .. "|r  |T" .. spellIcon(config.spellID) .. ":16|t " .. spellName(config.spellID) .. "  |cff8a93a3ID " .. config.spellID .. "|r"
            if data.enabled then enabledCount = enabledCount + 1 end
        end
        slots["slot" .. slot] = data
    end

    if not (selectedIndex and list[selectedIndex]) then
        selectedIndex = ordered[1] and ordered[1].index or nil
        for slot = 1, MAX_ICONS do
            if flat[slot] == selectedIndex and selectedIndex then slots["slot" .. slot].selected = true end
        end
    end
    local config = selectedIndex and list[selectedIndex]
    local selected = { valid = config ~= nil }
    if config then
        for _, key in ipairs({ "unit", "auraType", "size", "cooldownTextSize", "auraDuration", "trackCooldown", "showWhenInactive" }) do
            selected[key] = config[key]
        end
        selected.spellID = config.spellID
        selected.config = config
    end

    return {
        g = active:GetSettings(),
        slots = slots,
        sel = selected,
        add = addForm,
        undo = { available = undoSnapshot ~= nil },
        count = #list,
        enabledCount = enabledCount,
    }
end

local function write(key, value)
    local active = tracker()
    if not active then return end
    local scope, name = key:match("^(%a+)%.(.+)$")
    if scope == "g" then
        active:SetSetting(name, value)
    elseif scope == "slots" then
        local slot, field = name:match("^slot(%d+)%.(.+)$")
        local index = slot and flat[tonumber(slot)]
        if index then setIcon(index, field, value) end
    elseif scope == "sel" then
        if selectedIndex then setIcon(selectedIndex, name, value) end
    elseif scope == "add" then
        addForm[name] = value
    end
end

local function deleteSpell()
    local config = selectedIndex and icons()[selectedIndex]
    if not config or not tracker() then return end
    local name = spellName(config.spellID)
    tracker():RemoveTrackedSpell(selectedIndex)
    selectedIndex = nil
    clearUndo()
    SoundAlerter:Print("|cffff0000Removed " .. name .. " from tracker.|r")
end

local function tryAddSpell()
    local spellID = tonumber(addForm.spellID)
    if not spellID or spellID <= 0 then
        SoundAlerter:Print("|cffff0000Invalid spell ID.|r")
        return
    end
    if not tracker() then return end
    if tracker():AddTrackedSpell(spellID, addForm.unit, addForm.auraType) then
        SoundAlerter:Print("|cff00ff00Added spell " .. spellID .. " to tracker.|r")
        addForm.spellID = ""
        selectedIndex = #icons()
        clearUndo()
    end
end

local function applyPreset(preset)
    undoSnapshot = Model.Snapshot(icons())
    lastPreset = preset.name
    Model.ApplyPreset(icons(), preset.id, setIcon)
    SoundAlerter:Print("Preset applied: " .. preset.name)
end

local function undoPreset()
    if not undoSnapshot then return end
    Model.Restore(icons(), undoSnapshot, setIcon)
    clearUndo()
    SoundAlerter:Print("Preset undone")
end

local TrackerPreview = { height = 170 }

function TrackerPreview.build(stage)
    local state = { stage = stage, lines = {} }
    state.icon = stage:CreateTexture(nil, "ARTWORK")
    state.icon:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, 0)
    state.note = stage:CreateFontString(nil, "OVERLAY")
    state.note:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    state.note:SetTextColor(0.588, 0.627, 0.698)
    state.note:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, 0)
    state.note:SetWidth(240)
    for index = 1, PREVIEW_LINES do
        local line = stage:CreateFontString(nil, "OVERLAY")
        line:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        line:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, -(PREVIEW_MAX_SIZE + 8 + (index - 1) * 16))
        line:SetWidth(240)
        state.lines[index] = line
    end
    return state
end

function TrackerPreview.update(state, settings)
    if not state then return end
    local sel = settings.sel
    state.note:SetShown(not sel.valid)
    state.icon:SetShown(sel.valid)
    if not sel.valid then
        state.note:SetText("Click a tracked spell in the list to see how its icon looks while it is idle, active, expiring and on cooldown.")
        for index = 1, PREVIEW_LINES do state.lines[index]:SetText("") end
        return
    end
    local size = math.min(sel.size or 48, PREVIEW_MAX_SIZE)
    state.icon:SetTexture(spellIcon(sel.spellID))
    state.icon:SetSize(size, size)
    local lines = Model.PreviewLines(sel.config, settings.g)
    for index = 1, PREVIEW_LINES do
        local line = lines[index]
        state.lines[index]:SetText(line and ("|cff" .. line.color .. line.label .. "|r  |cff8a93a3" .. line.detail .. "|r") or "")
    end
end

local function summary(settings)
    local Page = SoundAlerter.Page
    if settings.count == 0 then
        return "No tracked spells yet. Add one under Add a spell."
    end
    return Page.Summary(settings, settings.count .. " of " .. MAX_ICONS .. " tracked spells used",
        settings.enabledCount .. " shown", settings.g.locked and "icons locked" or "icons unlocked, drag to move")
end

function SoundAlerter:BuildSpellTrackerOptions()
    local Page = SoundAlerter.Page
    local rows = {}

    for slot = 1, MAX_ICONS do
        local name = "slot" .. slot
        local row = Page.Toggle("slots." .. name .. ".enabled", function(settings) return settings.slots[name].label end,
            "Track this spell. Off keeps its settings but hides the icon. Click the name to edit its details below.", false, "Tracked spells")
        Page.Visible(function(settings) return settings.slots[name].present end, row)
        Page.Selectable(row, function()
            selectedIndex = flat[slot]
        end, function(settings) return settings.slots[name].selected end)
        rows[#rows + 1] = row
    end

    for _, setting in ipairs({
        { "g.locked", "Lock icons", "Lock all spell tracker icons in place. Unlock to drag and reposition individual icons.", false },
        { "g.showTimerText", "Show aura duration numbers", "Display the aura duration countdown at the bottom of spell tracker icons.", false },
        { "g.showBorderTimer", "Depleting border timer", "Draw a colored border around the icon that shrinks as the buff or debuff runs out. On your buffs it also shifts from green through amber to red as time runs low.", false },
        { "g.showCooldownText", "Show spell cooldown numbers", "Display the spell cooldown countdown (gold) at the top center of icons. Only affects spells with Cooldown on. This tracks YOUR spell cooldowns, not enemy cooldowns.", false },
        { "g.showReadyText", "Show Ready! when the cooldown is finished", "Display green Ready! where the cooldown numbers were while the spell is off cooldown. Only affects spells with Cooldown on.", false },
        { "g.deleteWithoutConfirm", "Delete without confirmation", "Skip the confirmation step when you delete a tracked spell. Deleting is immediate and cannot be undone.", true },
    }) do
        rows[#rows + 1] = Page.Toggle(setting[1], setting[2], setting[3], setting[4], "Display")
    end
    rows[#rows + 1] = Page.Select("g.animQuality", "Animation quality", "Off turns every icon animation off. Low keeps the icon effects minimal and updates timers 10 times a second. Normal adds the full pop-in, colour shift, red tint and shine. High adds extra rings and shines and updates every frame.", ANIM_QUALITIES, true, "Display")

    rows[#rows + 1] = Page.Text("add.spellID", "Spell ID", "Enter the numeric spell ID, then press Add spell. Use Find Spell in Developer Tools to look IDs up.", false, "Add a spell")
    rows[#rows + 1] = Page.Select("add.unit", "Track on", "Which unit to read this aura from.", UNIT_OPTIONS, false, "Add a spell")
    rows[#rows + 1] = Page.Select("add.auraType", "Aura type", "Whether to track a buff or a debuff.", AURA_OPTIONS, false, "Add a spell")
    rows[#rows + 1] = Page.Action("Add spell", "Add this spell to the tracker. It is listed under its class.", tryAddSpell, false, "Add a spell")

    local function editor(row)
        return Page.Visible(function(settings) return settings.sel.valid end, row)
    end
    rows[#rows + 1] = editor(Page.Select("sel.unit", "Track on", "Which unit to read this aura from.", UNIT_OPTIONS, false, "Selected spell"))
    rows[#rows + 1] = editor(Page.Select("sel.auraType", "Aura type", "Whether this tracks a buff or a debuff.", AURA_OPTIONS, false, "Selected spell"))
    rows[#rows + 1] = editor(Page.Toggle("sel.trackCooldown", "Track cooldown", "Show when this spell is ready to cast again. This is your own cooldown, not an enemy's.", false, "Selected spell"))
    rows[#rows + 1] = editor(Page.Toggle("sel.showWhenInactive", "Show when inactive", "Keep the icon on screen, faded, while the aura is not active.", false, "Selected spell"))
    rows[#rows + 1] = editor(Page.Range("sel.size", "Icon size", "Size of the spell tracker icon in pixels.", 24, 80, 4, false, "Selected spell", " px"))
    rows[#rows + 1] = editor(Page.Range("sel.cooldownTextSize", "Cooldown text size", "Font size for the cooldown countdown text. Only visible when Cooldown is on.", 8, 32, 1, false, "Selected spell", " pt"))
    rows[#rows + 1] = editor(Page.Range("sel.auraDuration", "Aura duration in combat", "Used for the in-combat aura spiral and number when the game hides the aura. 0 means automatic: the duration is learned the last time the aura was visible out of combat. Set a value for spells that can only be used in combat.", 0, 180, 0.5, false, "Selected spell", " s"))
    local delete = editor(Page.Action("Delete spell", "Remove the selected spell from the tracker.", deleteSpell, false, "Selected spell"))
    delete.confirm = function(settings)
        if settings.g.deleteWithoutConfirm then return nil end
        return "Click again to delete"
    end
    rows[#rows + 1] = delete

    for _, preset in ipairs(Model.PRESETS) do
        local row = Page.Action(preset.name, preset.note .. ". You can undo it once.", function() applyPreset(preset) end, true, "Presets")
        row.confirm = "Click again to apply"
        rows[#rows + 1] = Page.Visible(function(settings) return settings.count > 0 end, row)
    end
    rows[#rows + 1] = Page.When("undo.available", Page.Action(function() return lastPreset and ("Undo " .. lastPreset) or "Undo" end, "Restore Enabled and Cooldown from before the last preset.", undoPreset, true, "Presets"))

    local groupOrder = { "Tracked spells", "Selected spell", "Display", "Add a spell", "Presets" }
    local sorted = {}
    for _, group in ipairs(groupOrder) do
        for _, row in ipairs(rows) do
            if row.group == group then sorted[#sorted + 1] = row end
        end
    end
    rows = sorted

    local spec = Page.Spec({
        title = "Spell Tracker",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_02",
        blurb = "Track important buffs and debuffs with cooldown overlays and countdown timers. Click a tracked spell to edit it.",
        master = false,
        get = view,
        set = write,
        defaults = function() return { g = dbDefaults.profile.spellTracker } end,
        summary = summary,
        preview = TrackerPreview,
        rows = rows,
    })
    local options = Page.Options(spec, "Spell Tracker", "Interface\\Icons\\INV_Misc_PocketWatch_02", "Track important buffs and debuffs with cooldown overlays and countdown timers.", 2.87)
    return Page.Guard(options, "Spell Tracker", "SpellTracker", tracker)
end
