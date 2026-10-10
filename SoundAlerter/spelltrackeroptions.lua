local SoundAlerter = SoundAlerter
local Model = SA_TrackerModel
local GetSpellInfo = SA_COMPAT.GetSpellInfo

local MAX_ICONS = 20
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ADDON_NAME = "SoundAlerter"
local PREVIEW_MAX_SIZE = 40

local CLASS_COLORS = {
    Druid = "FF7D0A", Hunter = "ABD473", Mage = "69CCF0", Paladin = "F58CBA", Priest = "FFFFFF",
    Rogue = "FFF569", Shaman = "0070DE", Warlock = "9482C9", Warrior = "C79C6E", Other = "7C8596",
}

local CLASS_ICONS = {
    Druid = "Interface\\Icons\\ClassIcon_Druid",
    Hunter = "Interface\\Icons\\ClassIcon_Hunter",
    Mage = "Interface\\Icons\\ClassIcon_Mage",
    Paladin = "Interface\\Icons\\ClassIcon_Paladin",
    Priest = "Interface\\Icons\\ClassIcon_Priest",
    Rogue = "Interface\\Icons\\ClassIcon_Rogue",
    Shaman = "Interface\\Icons\\ClassIcon_Shaman",
    Warlock = "Interface\\Icons\\ClassIcon_Warlock",
    Warrior = "Interface\\Icons\\ClassIcon_Warrior",
    Other = "Interface\\Icons\\INV_Misc_QuestionMark",
}

local addForm = {
    spellID = "",
    unit = "player",
    auraType = "HELPFUL",
}

local selectedIndex = nil
local undoSnapshot = nil
local lastPreset = nil
local classLookup = nil

local function tracker()
    return SoundAlerter.SpellTracker
end

local function settings()
    return SoundAlerter.db1.profile.spellTracker or {}
end

local function icons()
    return settings().icons or {}
end

local function iconConfig(index)
    return icons()[index]
end

local function refresh()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
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

local function groups()
    return Model.Groups(icons(), classOfSpell)
end

local function spellIcon(spellID)
    return select(3, GetSpellInfo(spellID)) or UNKNOWN_ICON
end

local function spellName(spellID)
    return GetSpellInfo(spellID) or "Unknown"
end

local function classLabel(class)
    return "|cff" .. CLASS_COLORS[class] .. class .. "|r"
end

local function setIcon(index, key, value)
    if tracker() then tracker():SetIconSetting(index, key, value) end
end

local function clearUndo()
    undoSnapshot = nil
    lastPreset = nil
end

local function globalToggle(key, widget)
    widget.type = 'toggle'
    widget.width = "full"
    widget.get = function() return tracker():GetSettings()[key] end
    widget.set = function(info, value) tracker():SetSetting(key, value) end
    return widget
end

local function slotIndex(class, slot)
    return groups()[class][slot]
end

local function slotToggle(class, slot, key, widget)
    widget.type = 'toggle'
    widget.width = "half"
    widget.get = function()
        local index = slotIndex(class, slot)
        return index and tracker():GetIconSetting(index, key)
    end
    return widget
end

local function chipSlot(class, slot)
    local function config()
        local index = slotIndex(class, slot)
        return index and iconConfig(index)
    end

    local enabled = slotToggle(class, slot, "enabled", {
        name = "Enabled",
        desc = "Track this spell. Off keeps its settings but hides the icon.",
        order = 1,
    })
    enabled.set = function(_, value) setIcon(slotIndex(class, slot), "enabled", value) refresh() end

    local unit = slotToggle(class, slot, "unit", {
        name = "On you",
        desc = "On: the aura is read from you. Off: from your target.",
        order = 2,
    })
    unit.get = function()
        local c = config()
        return c and c.unit == "player"
    end
    unit.set = function(_, value) setIcon(slotIndex(class, slot), "unit", value and "player" or "target") refresh() end

    local aura = slotToggle(class, slot, "auraType", {
        name = "Debuff",
        desc = "On: track a debuff. Off: track a buff.",
        order = 3,
    })
    aura.get = function()
        local c = config()
        return c and c.auraType == "HARMFUL"
    end
    aura.set = function(_, value) setIcon(slotIndex(class, slot), "auraType", value and "HARMFUL" or "HELPFUL") refresh() end

    local cooldown = slotToggle(class, slot, "trackCooldown", {
        name = "Cooldown",
        desc = "Show when this spell is ready to cast again. This is your own cooldown, not an enemy's.",
        order = 4,
    })
    cooldown.set = function(_, value) setIcon(slotIndex(class, slot), "trackCooldown", value) refresh() end

    local inactive = slotToggle(class, slot, "showWhenInactive", {
        name = "Show inactive",
        desc = "Keep the icon on screen, faded, while the aura is not active.",
        order = 5,
    })
    inactive.set = function(_, value) setIcon(slotIndex(class, slot), "showWhenInactive", value) refresh() end

    return {
        type = 'group',
        inline = true,
        order = 10 + slot,
        name = function()
            local c = config()
            if not c then return "" end
            return "|T" .. spellIcon(c.spellID) .. ":20|t " .. spellName(c.spellID) .. "  |cff8a93a3ID " .. c.spellID .. "|r"
        end,
        hidden = function() return config() == nil end,
        args = {
            enabled = enabled,
            unit = unit,
            aura = aura,
            cooldown = cooldown,
            inactive = inactive,
            edit = {
                type = 'execute',
                name = function()
                    return slotIndex(class, slot) == selectedIndex and "Close" or "Size and timing"
                end,
                desc = "Open the size, text and combat settings with a live preview.",
                order = 6,
                width = "normal",
                func = function()
                    local index = slotIndex(class, slot)
                    selectedIndex = (index ~= selectedIndex) and index or nil
                    refresh()
                end,
            },
        },
    }
end

local function previewText(config)
    local size = math.min(config.size or 48, PREVIEW_MAX_SIZE)
    local texture = "|T" .. spellIcon(config.spellID) .. ":" .. size .. "|t"
    local out = {}
    for _, line in ipairs(Model.PreviewLines(config, settings())) do
        out[#out + 1] = texture .. "  |cff" .. line.color .. line.label .. "|r  |cff8a93a3" .. line.detail .. "|r"
    end
    return table.concat(out, "\n")
end

local function editorGroup(class)
    local function selectedConfig()
        if not selectedIndex then return nil end
        local config = iconConfig(selectedIndex)
        if config and classOfSpell(config.spellID) == class then return config end
        return nil
    end

    local function bound(key, widget)
        widget.get = function() return selectedIndex and tracker():GetIconSetting(selectedIndex, key) end
        widget.set = function(_, value) setIcon(selectedIndex, key, value) refresh() end
        return widget
    end

    return {
        type = 'group',
        inline = true,
        order = 100,
        name = function()
            local config = selectedConfig()
            if not config then return "" end
            return "Size and timing  |cff8a93a3" .. spellName(config.spellID) .. "|r"
        end,
        hidden = function() return selectedConfig() == nil end,
        args = {
            preview = {
                type = 'description',
                name = function()
                    local config = selectedConfig()
                    return config and previewText(config) or ""
                end,
                fontSize = "medium",
                width = "full",
                order = 1,
            },
            size = bound("size", {
                type = 'range',
                name = "Icon Size",
                desc = "Size of the spell tracker icon in pixels",
                min = 24,
                max = 80,
                step = 4,
                width = "double",
                order = 2,
            }),
            cooldownTextSize = bound("cooldownTextSize", {
                type = 'range',
                name = "Cooldown Text Size",
                desc = "Font size for the cooldown countdown text (in points). Only visible when Cooldown is on. Ready! shrinks to fit small icons.",
                min = 8,
                max = 32,
                step = 1,
                width = "double",
                order = 3,
            }),
            auraDuration = bound("auraDuration", {
                type = 'range',
                name = "Aura Duration in Combat (seconds)",
                desc = "Used for the in-combat aura spiral and number when the game hides the aura. 0 = automatic: the duration is learned the last time the aura was visible out of combat. Set a value for spells that can only be used in combat.",
                min = 0,
                max = 180,
                step = 0.5,
                width = "double",
                order = 4,
            }),
            delete = {
                type = 'execute',
                name = "Delete Spell",
                desc = "Remove this spell from the tracker",
                width = "normal",
                order = 5,
                confirm = function()
                    local config = selectedConfig()
                    return "Delete " .. (config and spellName(config.spellID) or "this spell") .. " from the tracker?"
                end,
                func = function()
                    local index = selectedIndex
                    local config = index and iconConfig(index)
                    if not config then return end
                    local name = spellName(config.spellID)
                    tracker():RemoveTrackedSpell(index)
                    selectedIndex = nil
                    clearUndo()
                    SoundAlerter:Print("|cffff0000Removed " .. name .. " from tracker.|r")
                    refresh()
                end,
            },
        },
    }
end

local function buildClassGroup(class, order)
    local args = {}
    for slot = 1, MAX_ICONS do
        args["spell" .. slot] = chipSlot(class, slot)
    end
    args.editor = editorGroup(class)

    return {
        type = 'group',
        name = function()
            local on, total = Model.Count(icons(), groups()[class])
            return classLabel(class) .. "  |cff8a93a3" .. on .. "/" .. total .. "|r"
        end,
        icon = CLASS_ICONS[class],
        order = order,
        hidden = function() return #groups()[class] == 0 end,
        args = args,
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
        clearUndo()
        LibStub("AceConfigDialog-3.0"):SelectGroup(ADDON_NAME, "SpellTracker", classOfSpell(spellID):lower())
        refresh()
    end
end

local function buildOverviewTab()
    local presetArgs = {
        note = {
            type = 'description',
            name = function()
                return string.format("%d of %d tracked spells used. A preset changes every spell at once, and you can undo the last one.", #icons(), MAX_ICONS)
            end,
            order = 0,
            fontSize = "medium",
        },
        empty = {
            type = 'description',
            name = "No tracked spells yet. Open Add spell on the left.",
            order = 0.5,
            fontSize = "medium",
            hidden = function() return #icons() > 0 end,
        },
    }
    for index, preset in ipairs(Model.PRESETS) do
        presetArgs[preset.id] = {
            type = 'execute',
            name = preset.name,
            desc = preset.note,
            order = index,
            width = "normal",
            disabled = function() return #icons() == 0 end,
            confirm = function()
                return "Apply the " .. preset.name .. " preset?\n\n" .. preset.note .. ".\nYou can undo it once."
            end,
            func = function()
                undoSnapshot = Model.Snapshot(icons())
                lastPreset = preset.name
                Model.ApplyPreset(icons(), preset.id, setIcon)
                SoundAlerter:Print("Preset applied: " .. preset.name)
                refresh()
            end,
        }
    end
    presetArgs.undo = {
        type = 'execute',
        name = function() return lastPreset and ("Undo " .. lastPreset) or "Undo" end,
        desc = "Restore Enabled and Cooldown from before the last preset.",
        order = 20,
        width = "normal",
        disabled = function() return undoSnapshot == nil end,
        func = function()
            Model.Restore(icons(), undoSnapshot, setIcon)
            clearUndo()
            SoundAlerter:Print("Preset undone")
            refresh()
        end,
    }

    return {
        type = 'group',
        name = "Overview and presets",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_02",
        order = 1,
        args = {
            presets = {
                type = 'group',
                inline = true,
                name = "Presets",
                order = 1,
                args = presetArgs,
            },
        },
    }
end

local function buildAddTab()
    return {
        type = 'group',
        name = "|cff00D4FFAdd spell|r",
        icon = "Interface\\PaperDollInfoFrame\\Character-Plus",
        order = 40,
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
                desc = "Add this spell to the tracker. It is listed under its class on the left.",
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
        icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
        order = 41,
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
                name = "Timers",
                order = 2,
                args = {
                    showTimerText = globalToggle("showTimerText", {
                        name = "Show Aura Duration Numbers",
                        desc = "Display the aura duration countdown at the bottom of spell tracker icons. This shows how long the buff/debuff lasts.",
                        order = 1,
                    }),
                    showBorderTimer = globalToggle("showBorderTimer", {
                        name = "Depleting Border Timer",
                        desc = "Draw a colored border around the icon that shrinks as the buff/debuff runs out.",
                        order = 1.5,
                    }),
                    showCooldownText = globalToggle("showCooldownText", {
                        name = "Show Spell Cooldown Numbers",
                        desc = "Display the spell cooldown countdown (gold) at the top center of spell tracker icons. Only affects spells with Cooldown on.\n\n|cffFF7D0ANote:|r This tracks YOUR spell cooldowns (when the ability is ready to use again), not enemy cooldowns or aura durations.",
                        order = 2,
                    }),
                    showReadyText = globalToggle("showReadyText", {
                        name = "Show 'Ready!' When Cooldown Finished",
                        desc = "Display green 'Ready!' in the same spot as the cooldown numbers while the spell is off cooldown. Only affects spells with Cooldown on.",
                        order = 3,
                    }),
                },
            },
        },
    }
end

function SoundAlerter:BuildSpellTrackerOptions()
    local warning = {
        type = 'description',
        name = function()
            return "|cffFF0000Spell Tracker failed to initialize this session:|r\n" ..
                tostring(SoundAlerter.moduleInitErrors and SoundAlerter.moduleInitErrors.SpellTracker) ..
                "\n\n|cffFFFFFFToggles below will not take effect until this is fixed and you /reload.|r\n"
        end,
        fontSize = "medium",
        order = 0.5,
        hidden = function() return SoundAlerter.SpellTracker ~= nil end,
    }

    local args = {
        add = buildAddTab(),
        display = buildDisplayTab(),
        initErrorWarning = warning,
        presetsHeader = { type = 'header', name = "Presets", order = 0.9 },
    }
    warning.order = 0
    for key, widget in pairs(buildOverviewTab().args.presets.args) do
        args[key] = widget
    end
    for index, class in ipairs(Model.CLASS_ORDER) do
        args[class:lower()] = buildClassGroup(class, 10 + index)
    end

    return {
        type = 'group',
        name = "Spell Tracker",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_02",
        desc = "Track important buffs and debuffs with cooldown overlays and countdown timers. Pick a class on the left, then switch what each spell tracks.",
        order = 2.87,
        childGroups = 'tree',
        args = args,
    }
end
