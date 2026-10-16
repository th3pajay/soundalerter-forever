local SoundAlerter = SoundAlerter
local Model = {}

Model.MODIFIERS = { "none", "shift", "ctrl", "alt" }
Model.BUTTONS = { "left", "right", "middle" }

Model.MODIFIER_LABELS = { none = "", shift = "Shift+", ctrl = "Ctrl+", alt = "Alt+" }
Model.BUTTON_LABELS = { left = "left click", right = "right click", middle = "middle click" }

Model.ACTIONS = {
    { "none", "Nothing" },
    { "options", "Open options" },
    { "menu", "Quick switch menu" },
    { "proximity", "Toggle proximity alerts" },
    { "battleground", "Toggle battleground alerts" },
    { "snooze", "Snooze alerts" },
    { "lockbars", "Lock / unlock bars" },
    { "chat", "Toggle chat alerts" },
    { "notices", "Toggle notices" },
    { "profile", "Next profile" },
    { "finder", "Open Spell Finder" },
    { "stats", "Open statistics" },
    { "test", "Play a test voice" },
}

Model.SLOTS = {
    { "both", "Proximity and battleground on" },
    { "prox", "Proximity only" },
    { "bg", "Battleground only" },
    { "none", "Both off" },
}

Model.ICONS = {
    none = { "ability_warrior_battleshout", "inv_misc_bell_01", "spell_holy_silence", "ability_stealth", "inv_misc_ear_human_01", "inv_banner_01", "spell_nature_slow", "inv_shield_05", "ability_creature_cursed_05", "inv_misc_drum_01", "ability_parry", "spell_arcane_arcane04" },
    prox = { "ability_hunter_snipershot", "ability_hunter_eagleeye", "inv_misc_eye_01", "ability_eyeoftheowl", "spell_nature_farsight", "spell_shadow_detectinvisibility", "inv_misc_spyglass_02", "ability_ambush", "inv_misc_horn_02", "spell_holy_mindvision", "ability_hunter_mastermarksman", "inv_misc_drum_02" },
    bg = { "inv_banner_02", "inv_bannerpvp_01", "inv_misc_tabardpvp_01", "achievement_bg_winwsg", "ability_warrior_rallyingcry", "ability_warrior_offensivestance", "inv_misc_tournaments_banner_orc", "achievement_pvp_a_01", "inv_misc_horn_04", "inv_misc_drum_03", "achievement_bg_captureflag_eos", "inv_misc_tournaments_banner_human" },
    both = { "ability_warrior_victoryrush", "ability_hunter_markedfordeath", "inv_misc_horn_03", "achievement_arena_2v2_1", "ability_warrior_commandingshout", "ability_warrior_warcry", "spell_holy_auramastery", "ability_whirlwind", "ability_dualwield", "inv_misc_drum_04", "spell_holy_devotionaura", "inv_bannerpvp_02" },
}

Model.DEFAULTS = {
    clicks = {
        none = { left = "options", right = "menu", middle = "finder" },
        shift = { left = "proximity", right = "lockbars", middle = "none" },
        ctrl = { left = "battleground", right = "stats", middle = "none" },
        alt = { left = "snooze", right = "test", middle = "none" },
    },
    icons = {
        both = "ability_dualwield",
        prox = "ability_hunter_mastermarksman",
        bg = "achievement_bg_winwsg",
        none = "spell_holy_silence",
    },
}

local ACTION_SET = {}
for index = 1, #Model.ACTIONS do ACTION_SET[Model.ACTIONS[index][1]] = Model.ACTIONS[index][2] end

local ICON_SET = {}
for slot, list in pairs(Model.ICONS) do
    ICON_SET[slot] = {}
    for index = 1, #list do ICON_SET[slot][list[index]] = true end
end

local MODIFIER_SET, BUTTON_SET = {}, {}
for index = 1, #Model.MODIFIERS do MODIFIER_SET[Model.MODIFIERS[index]] = true end
for index = 1, #Model.BUTTONS do BUTTON_SET[Model.BUTTONS[index]] = true end

local MOUSE_BUTTONS = { LeftButton = "left", RightButton = "right", MiddleButton = "middle" }

function Model.ActionLabel(action)
    return ACTION_SET[action]
end

function Model.ActionOptions()
    return Model.ACTIONS
end

function Model.Modifier(shift, ctrl, alt)
    if shift then return "shift" end
    if ctrl then return "ctrl" end
    if alt then return "alt" end
    return "none"
end

function Model.ButtonName(mouseButton)
    return MOUSE_BUTTONS[mouseButton]
end

function Model.Resolve(clicks, modifier, button)
    local row = clicks and clicks[modifier]
    local action = row and row[button]
    if action == nil or action == "none" or not ACTION_SET[action] then return nil end
    return action
end

function Model.Slot(proximity, battleground)
    if proximity and battleground then return "both" end
    if proximity then return "prox" end
    if battleground then return "bg" end
    return "none"
end

function Model.Icon(icons, slot)
    local chosen = icons and icons[slot]
    if chosen and ICON_SET[slot] and ICON_SET[slot][chosen] then return chosen end
    return Model.DEFAULTS.icons[slot]
end

function Model.IconPath(name)
    return "Interface\\ICONS\\" .. name
end

function Model.IconLabel(name)
    local text = name:gsub("^ability_", ""):gsub("^achievement_", ""):gsub("^inv_", ""):gsub("^spell_", ""):gsub("_", " ")
    return (text:gsub("(%a)(%w*)", function(first, rest) return first:upper() .. rest end))
end

function Model.IconOptions(slot)
    local options = {}
    for index, name in ipairs(Model.ICONS[slot] or {}) do
        options[index] = { name, "|T" .. Model.IconPath(name) .. ":16|t " .. Model.IconLabel(name) }
    end
    return options
end

function Model.IsValidKey(key)
    local scope, a, b = tostring(key):match("^(%a+)%.(%a+)%.?(%a*)$")
    if scope == "clicks" then
        return MODIFIER_SET[a] == true and BUTTON_SET[b] == true
    elseif scope == "icons" then
        return ICON_SET[a] ~= nil and b == ""
    end
    return false
end

function Model.IsValidValue(key, value)
    local scope, a = tostring(key):match("^(%a+)%.(%a+)")
    if scope == "clicks" then return ACTION_SET[value] ~= nil end
    if scope == "icons" then return ICON_SET[a] ~= nil and ICON_SET[a][value] == true end
    return false
end

function Model.Assign(settings, key, value)
    if not Model.IsValidKey(key) or not Model.IsValidValue(key, value) then return false end
    local scope, a, b = key:match("^(%a+)%.(%a+)%.?(%a*)$")
    settings[scope] = settings[scope] or {}
    if scope == "clicks" then
        settings.clicks[a] = settings.clicks[a] or {}
        settings.clicks[a][b] = value
    else
        settings.icons[a] = value
    end
    return true
end

function Model.CanOpenOptions(clicks)
    for _, modifier in ipairs(Model.MODIFIERS) do
        for _, button in ipairs(Model.BUTTONS) do
            local action = Model.Resolve(clicks, modifier, button)
            if action == "options" or action == "menu" then return true end
        end
    end
    return false
end

function Model.ClickLabel(modifier, button)
    local text = Model.MODIFIER_LABELS[modifier] .. Model.BUTTON_LABELS[button]
    if modifier == "none" then return text:sub(1, 1):upper() .. text:sub(2) end
    return Model.MODIFIER_LABELS[modifier] .. Model.BUTTON_LABELS[button]
end

function Model.TooltipLines(clicks, state)
    local lines = { { "SoundAlerter", "title" } }
    local first = true
    for _, modifier in ipairs(Model.MODIFIERS) do
        for _, button in ipairs(Model.BUTTONS) do
            local action = Model.Resolve(clicks, modifier, button)
            if action then
                lines[#lines + 1] = { Model.ClickLabel(modifier, button) .. ": " .. ACTION_SET[action], first and "first" or "row" }
                first = false
            end
        end
    end
    lines[#lines + 1] = { "Drag to move", "hint" }
    if state then
        local text = "Proximity: " .. (state.proximity and "ON" or "off") .. "  |  Battleground: " .. (state.battleground and "ON" or "off")
        if state.snoozed then text = text .. "  |  Snoozed" end
        lines[#lines + 1] = { text, "state" }
    end
    return lines
end

function Model.NextProfile(names, current)
    if type(names) ~= "table" or #names == 0 then return nil end
    local sorted = {}
    for index = 1, #names do sorted[index] = names[index] end
    table.sort(sorted)
    for index = 1, #sorted do
        if sorted[index] == current then return sorted[index % #sorted + 1] end
    end
    return sorted[1]
end

function Model.AnyUnlocked(states)
    for index = 1, #states do
        if states[index] == false then return true end
    end
    return false
end

SoundAlerter.MinimapButtonModel = Model
