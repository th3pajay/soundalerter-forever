local SoundAlerter = SoundAlerter
local GetSpellInfo = SA_COMPAT.GetSpellInfo

local MAX_ICONS = 20
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ADD_ICON = "Interface\\PaperDollInfoFrame\\Character-Plus"
local ADDON_NAME = "SoundAlerter"

local addForm = {
    spellID = "",
    unit = "player",
    auraType = "HELPFUL",
}

local selectedIndex = nil

local function tracker()
    return SoundAlerter.SpellTracker
end

local function icons()
    local settings = SoundAlerter.db1.profile.spellTracker
    return settings and settings.icons or {}
end

local function iconConfig(index)
    return icons()[index]
end

local function selected()
    local list = icons()
    if selectedIndex and not list[selectedIndex] then
        selectedIndex = #list > 0 and #list or nil
    end
    if not selectedIndex and #list > 0 then
        selectedIndex = 1
    end
    return selectedIndex
end

local function refresh()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
end

local function badge(config)
    return (config.unit == "player" and "Player" or "Target") .. " " .. (config.auraType == "HELPFUL" and "Buff" or "Debuff")
end

local function spellIcon(spellID)
    return select(3, GetSpellInfo(spellID)) or UNKNOWN_ICON
end

local function noSelection()
    return selected() == nil
end

local function iconSetting(key, widget)
    widget.get = function() return tracker():GetIconSetting(selected(), key) end
    widget.set = function(info, value) tracker():SetIconSetting(selected(), key, value) end
    return widget
end

local function globalToggle(key, widget)
    widget.type = 'toggle'
    widget.width = "full"
    widget.get = function() return tracker():GetSettings()[key] end
    widget.set = function(info, value) tracker():SetSetting(key, value) end
    return widget
end

local function listSlot(index)
    return {
        type = 'execute',
        name = function()
            local config = iconConfig(index)
            if not config then return "" end
            local color = index == selectedIndex and "|cffFFD700" or (config.enabled and "|cffFFFFFF" or "|cff888888")
            return color .. (GetSpellInfo(config.spellID) or "Unknown") .. "|r\n|cff888888" .. badge(config) .. "|r"
        end,
        desc = function()
            local config = iconConfig(index)
            return config and ("Spell ID " .. config.spellID .. (config.enabled and "" or " (disabled)")) or ""
        end,
        image = function()
            local config = iconConfig(index)
            return config and spellIcon(config.spellID) or UNKNOWN_ICON
        end,
        imageWidth = 32,
        imageHeight = 32,
        width = 0.75,
        order = index,
        hidden = function() return iconConfig(index) == nil end,
        func = function()
            selectedIndex = index
            refresh()
        end,
    }
end

local function tryAddSpell()
    local spellID = tonumber(addForm.spellID)
    if not spellID or spellID <= 0 then
        SoundAlerter:Print("|cffff0000Invalid spell ID.|r")
        return
    end

    if not tracker() then
        return
    end

    if tracker():AddTrackedSpell(spellID, addForm.unit, addForm.auraType) then
        SoundAlerter:Print("|cff00ff00Added spell " .. spellID .. " to tracker.|r")
        addForm.spellID = ""
        selectedIndex = #icons()
        LibStub("AceConfigDialog-3.0"):SelectGroup(ADDON_NAME, "SpellTracker", "spells")
        refresh()
    end
end

local function buildSpellsTab()
    local args = {
        empty = {
            type = 'description',
            name = "No tracked spells yet. Add one in the Add Spell tab.",
            fontSize = "medium",
            width = "full",
            order = 0.5,
            hidden = function() return #icons() > 0 end,
        },
        header = {
            type = 'description',
            name = function()
                local config = iconConfig(selected())
                if not config then return "" end
                return string.format("|T%s:24|t |cffFFD700%s|r  |cff888888ID %d  |  %s|r",
                    spellIcon(config.spellID), GetSpellInfo(config.spellID) or "Unknown", config.spellID, badge(config))
            end,
            fontSize = "large",
            width = "full",
            order = 50,
            hidden = noSelection,
        },
        tracking = {
            type = 'group',
            inline = true,
            name = "Tracking",
            order = 51,
            hidden = noSelection,
            args = {
                enabled = iconSetting("enabled", {
                    type = 'toggle',
                    name = "Enabled",
                    desc = "Enable tracking for this spell",
                    width = "half",
                    order = 1,
                }),
                unit = iconSetting("unit", {
                    type = 'select',
                    name = "Track On",
                    desc = "Which unit to track this aura on",
                    values = { player = "Player (Self)", target = "Target" },
                    width = "half",
                    order = 2,
                }),
                auraType = iconSetting("auraType", {
                    type = 'select',
                    name = "Aura Type",
                    desc = "Type of aura to track",
                    values = { HELPFUL = "Buff (Helpful)", HARMFUL = "Debuff (Harmful)" },
                    width = "half",
                    order = 3,
                }),
            },
        },
        icon = {
            type = 'group',
            inline = true,
            name = "Icon",
            order = 52,
            hidden = noSelection,
            args = {
                size = iconSetting("size", {
                    type = 'range',
                    name = "Icon Size",
                    desc = "Size of the spell tracker icon in pixels",
                    min = 24,
                    max = 80,
                    step = 4,
                    width = "double",
                    order = 1,
                }),
                showWhenInactive = iconSetting("showWhenInactive", {
                    type = 'toggle',
                    name = "Show When Inactive",
                    desc = "Display the icon (faded) even when the aura is not active",
                    width = "full",
                    order = 2,
                }),
            },
        },
        cooldown = {
            type = 'group',
            inline = true,
            name = "Cooldown",
            order = 53,
            hidden = noSelection,
            args = {
                trackCooldown = iconSetting("trackCooldown", {
                    type = 'toggle',
                    name = "Track Cooldown",
                    desc = "Show when this spell is ready to cast again (your own cooldown, independent of the aura). Does NOT track enemy cooldowns.",
                    width = "full",
                    order = 1,
                }),
                cooldownTextSize = iconSetting("cooldownTextSize", {
                    type = 'range',
                    name = "Cooldown Text Size",
                    desc = "Font size for the cooldown countdown text (in points). Only visible when 'Track Cooldown' is enabled.",
                    min = 8,
                    max = 32,
                    step = 1,
                    width = "double",
                    order = 2,
                }),
            },
        },
        combat = {
            type = 'group',
            inline = true,
            name = "In Combat",
            order = 54,
            hidden = noSelection,
            args = {
                auraDuration = iconSetting("auraDuration", {
                    type = 'range',
                    name = "Aura Duration (seconds)",
                    desc = "Used for the in-combat aura spiral and number when the game hides the aura. 0 = automatic: the duration is learned the last time the aura was visible out of combat. Set a value for spells that can only be used in combat.",
                    min = 0,
                    max = 180,
                    step = 0.5,
                    width = "double",
                    order = 1,
                }),
            },
        },
        delete = {
            type = 'execute',
            name = "Delete Spell",
            desc = "Remove this spell from the tracker",
            width = "full",
            order = 60,
            hidden = noSelection,
            confirm = true,
            confirmText = "Are you sure you want to delete this tracked spell?",
            func = function()
                local index = selected()
                local config = iconConfig(index)
                if not config then return end
                local spellName = GetSpellInfo(config.spellID) or "Unknown"
                tracker():RemoveTrackedSpell(index)
                SoundAlerter:Print("|cffff0000Removed " .. spellName .. " from tracker.|r")
                refresh()
            end,
        },
    }

    for index = 1, MAX_ICONS do
        args["spell" .. index] = listSlot(index)
    end

    args.addTile = {
        type = 'execute',
        name = "|cff00D4FFAdd spell|r",
        image = ADD_ICON,
        imageWidth = 32,
        imageHeight = 32,
        width = 0.75,
        order = MAX_ICONS + 1,
        hidden = function() return #icons() >= MAX_ICONS end,
        func = function()
            LibStub("AceConfigDialog-3.0"):SelectGroup(ADDON_NAME, "SpellTracker", "add")
        end,
    }

    return {
        type = 'group',
        name = function() return "Spells (" .. #icons() .. ")" end,
        order = 1,
        args = args,
    }
end

local function buildAddTab()
    return {
        type = 'group',
        name = "Add Spell",
        order = 2,
        args = {
            used = {
                type = 'description',
                name = function() return string.format("%d of %d tracked spells used", #icons(), MAX_ICONS) end,
                fontSize = "medium",
                width = "full",
                order = 1,
            },
            spellID = {
                type = 'input',
                name = "Spell ID",
                desc = "Enter the numeric spell ID and press Enter to add it. Use the Spell Finder in Developer Tools to look IDs up.",
                width = "half",
                order = 2,
                get = function() return addForm.spellID end,
                set = function(info, value)
                    addForm.spellID = value
                    tryAddSpell()
                end,
            },
            unit = {
                type = 'select',
                name = "Track On",
                desc = "Which unit to track this aura on",
                values = { player = "Player (Self)", target = "Target" },
                width = "half",
                order = 3,
                get = function() return addForm.unit end,
                set = function(info, value) addForm.unit = value end,
            },
            auraType = {
                type = 'select',
                name = "Aura Type",
                desc = "Type of aura to track",
                values = { HELPFUL = "Buff (Helpful)", HARMFUL = "Debuff (Harmful)" },
                width = "half",
                order = 4,
                get = function() return addForm.auraType end,
                set = function(info, value) addForm.auraType = value end,
            },
            add = {
                type = 'execute',
                name = "Add Spell",
                desc = "Add this spell to the tracker",
                width = "full",
                order = 5,
                func = tryAddSpell,
            },
        },
    }
end

local function buildDisplayTab()
    return {
        type = 'group',
        name = "Display",
        order = 3,
        args = {
            behaviour = {
                type = 'group',
                inline = true,
                name = "Behaviour",
                order = 1,
                args = {
                    locked = globalToggle("locked", {
                        name = "Lock Icons",
                        desc = "Lock all spell tracker icons in place. Unlock to drag and reposition individual icons.",
                        order = 1,
                    }),
                },
            },
            numbers = {
                type = 'group',
                inline = true,
                name = "Numbers",
                order = 2,
                args = {
                    showTimerText = globalToggle("showTimerText", {
                        name = "Show Aura Duration Numbers",
                        desc = "Display the aura duration countdown at the bottom of spell tracker icons. This shows how long the buff/debuff lasts.",
                        order = 1,
                    }),
                    showCooldownText = globalToggle("showCooldownText", {
                        name = "Show Spell Cooldown Numbers",
                        desc = "Display the spell cooldown countdown (gold) at the top center of spell tracker icons. Only affects spells with 'Track Cooldown' enabled.\n\n|cffFF7D0ANote:|r This tracks YOUR spell cooldowns (when the ability is ready to use again), not enemy cooldowns or aura durations.",
                        order = 2,
                    }),
                    showReadyText = globalToggle("showReadyText", {
                        name = "Show 'Ready!' When Cooldown Finished",
                        desc = "Display green 'Ready!' in the same spot as the cooldown numbers while the spell is off cooldown. Only affects spells with 'Track Cooldown' enabled.",
                        order = 3,
                    }),
                },
            },
        },
    }
end

function SoundAlerter:BuildSpellTrackerOptions()
    return {
        type = 'group',
        name = "Spell Tracker",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_02",
        desc = "Track important buffs and debuffs with cooldown overlays and countdown timers.",
        order = 2.87,
        childGroups = 'tab',
        args = {
            initErrorWarning = {
                type = 'description',
                name = function()
                    return "|cffFF0000Spell Tracker failed to initialize this session:|r\n" ..
                        tostring(SoundAlerter.moduleInitErrors and SoundAlerter.moduleInitErrors.SpellTracker) ..
                        "\n\n|cffFFFFFFToggles below will not take effect until this is fixed and you /reload.|r\n"
                end,
                fontSize = "medium",
                order = 0.5,
                hidden = function() return SoundAlerter.SpellTracker ~= nil end,
            },
            spells = buildSpellsTab(),
            add = buildAddTab(),
            display = buildDisplayTab(),
        },
    }
end
