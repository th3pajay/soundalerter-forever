local Model = SA_VoiceModel

local CLASS_COLORS = {
    Druid = "FF7D0A", Hunter = "ABD473", Mage = "69CCF0", Paladin = "F58CBA", Priest = "FFFFFF",
    Rogue = "FFF569", Shaman = "0070DE", Warlock = "9482C9", Warrior = "C79C6E", Races = "9AA4B5", Other = "7C8596",
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
    Races = "Interface\\Icons\\INV_Misc_Head_Human_01",
    Other = "Interface\\Icons\\INV_Misc_QuestionMark",
}

local EVENT_HELP = {
    ["Gained"] = "An enemy gains this buff or cooldown.",
    ["Faded"] = "The buff or cooldown ends.",
    ["Cast start"] = "An enemy starts casting this spell.",
    ["Cast"] = "An enemy casts this spell.",
    ["On you"] = "This lands on you.",
    ["On friend"] = "This lands on your arena partner or a friend.",
    ["On enemy"] = "This lands on an enemy because of you or your partner.",
    ["CC faded"] = "Your crowd control on an enemy ends.",
    ["Interrupts you"] = "You are interrupted.",
}

function SoundAlerter:BuildVoiceAlertPanel(ctx)
    local function db()
        return SoundAlerter.db1.profile
    end

    local function notify()
        local registry = LibStub("AceConfigRegistry-3.0")
        if registry then registry:NotifyChange("SoundAlerter") end
    end

    local model = Model.Build(SoundAlerter.spellList or SoundAlerterSpells, SoundAlerterSpellMeta)
    local query = ""
    local undoSnapshot = nil
    local lastPreset = nil

    local function classLabel(class)
        return "|cff" .. CLASS_COLORS[class] .. class .. "|r"
    end

    local function spellTitle(spell)
        local icon = ctx.spellTexture and ctx.spellTexture(spell.iconSpellID) or ""
        return icon .. spell.name
    end

    local function chipGroup(spell, order, hidden)
        local args = {}
        for index, event in ipairs(spell.events) do
            local keys = spell.eventKeys[event]
            args[event] = {
                type = 'toggle',
                name = event,
                desc = (EVENT_HELP[event] or event) .. "\nSound: " .. table.concat(keys, ", "),
                order = index,
                width = "half",
                disabled = function() return db()[Model.SILENCE_FLAG[event]] and true or false end,
                get = function() return Model.ChipOn(db(), spell, event) end,
                set = function(_, value)
                    Model.SetChip(db(), spell, event, value)
                    if value then PlaySoundFile(db().sapath .. keys[1] .. ".mp3") end
                    notify()
                end,
            }
        end
        return {
            type = 'group',
            inline = true,
            name = spellTitle(spell),
            order = order,
            hidden = hidden,
            args = args,
        }
    end

    local classGroups = {}
    for index, group in ipairs(model.classes) do
        local args = {
            allOn = {
                type = 'execute',
                name = "All on",
                desc = "Turn on every alert for " .. group.name .. ".",
                order = 1,
                width = "half",
                func = function() Model.SetAll(db(), group.spells, true) notify() end,
            },
            allOff = {
                type = 'execute',
                name = "All off",
                desc = "Turn off every alert for " .. group.name .. ".",
                order = 2,
                width = "half",
                func = function() Model.SetAll(db(), group.spells, false) notify() end,
            },
        }
        for rowIndex, spell in ipairs(group.spells) do
            args["spell" .. rowIndex] = chipGroup(spell, 10 + rowIndex)
        end
        classGroups[group.name:lower()] = {
            type = 'group',
            name = function()
                local on, total = Model.Count(db(), group.spells)
                return classLabel(group.name) .. "  |cff8a93a3" .. on .. "/" .. total .. "|r"
            end,
            icon = CLASS_ICONS[group.name],
            order = 10 + index,
            args = args,
        }
    end

    local searchArgs = {
        input = {
            type = 'input',
            name = "Search spells",
            desc = "Type a spell name or a sound key, for example hex, stun or shield. Results show every class.",
            order = 1,
            width = "full",
            get = function() return query end,
            set = function(_, value) query = (value or ""):lower():gsub("^%s+", ""):gsub("%s+$", "") notify() end,
        },
        clear = {
            type = 'execute',
            name = "Clear search",
            order = 2,
            width = "half",
            disabled = function() return query == "" end,
            func = function() query = "" notify() end,
        },
        hint = {
            type = 'description',
            name = "Type above to search across every class.",
            order = 3,
            hidden = function() return query ~= "" end,
        },
        none = {
            type = 'description',
            name = "No spell matches.",
            order = 4,
            hidden = function()
                if query == "" then return true end
                for _, spell in ipairs(model.spells) do
                    if Model.Matches(spell, query) then return true end
                end
                return false
            end,
        },
    }
    for rowIndex, spell in ipairs(model.spells) do
        searchArgs["spell" .. rowIndex] = chipGroup(spell, 10 + rowIndex, function()
            return query == "" or not Model.Matches(spell, query)
        end)
    end

    local presetArgs = {
        note = {
            type = 'description',
            name = "A preset replaces every spell alert toggle in one click. You can undo the last preset.",
            order = 0,
            fontSize = "medium",
        },
    }
    for index, preset in ipairs(Model.PRESETS) do
        presetArgs[preset.id] = {
            type = 'execute',
            name = preset.name,
            desc = preset.note,
            order = index,
            width = "normal",
            confirm = function()
                return "Apply the " .. preset.name .. " preset?\n\n" .. preset.note .. ".\nThis overwrites all of your spell alert toggles. You can undo it once."
            end,
            func = function()
                undoSnapshot = Model.Snapshot(db(), model)
                lastPreset = preset.name
                Model.ApplyPreset(db(), model, preset.id)
                SoundAlerter:Print("Preset applied: " .. preset.name)
                notify()
            end,
        }
    end
    presetArgs.undo = {
        type = 'execute',
        name = function() return lastPreset and ("Undo " .. lastPreset) or "Undo" end,
        desc = "Restore the toggles from before the last preset.",
        order = 20,
        width = "normal",
        disabled = function() return undoSnapshot == nil end,
        func = function()
            Model.Restore(db(), undoSnapshot)
            undoSnapshot = nil
            lastPreset = nil
            SoundAlerter:Print("Preset undone")
            notify()
        end,
    }

    local overviewArgs = {
        extras = {
            type = 'group',
            inline = true,
            name = "Arena extras",
            order = 2,
            args = {
                class = {
                    type = 'toggle',
                    name = "Alert Class calling for trinketing in Arena",
                    desc = "Alert when an enemy class trinkets in arena",
                    order = 1,
                    get = function() return db().class end,
                    set = function(_, value) db().class = value end,
                    confirm = function()
                        PlaySoundFile(db().sapath .. "paladin.mp3")
                        SoundAlerter:ScheduleTimer("PlayTrinket", 0.4)
                    end,
                },
                drinking = {
                    type = 'toggle',
                    name = "Alert Drinking in Arena",
                    desc = "Alert when an enemy drinks in arena",
                    order = 2,
                    get = function() return db().drinking end,
                    set = function(_, value)
                        db().drinking = value
                        if value then PlaySoundFile(db().sapath .. "drinking.mp3") end
                    end,
                },
            },
        },
    }
    if ctx.silence then
        ctx.silence.order = 3
        overviewArgs.silence = ctx.silence
    end

    local args = {
        presetsHeader = { type = 'header', name = "Presets", order = 0.5 },
        overview = {
            type = 'group',
            name = "Arena extras and silencing",
            icon = "Interface\\Icons\\INV_Misc_Bell_01",
            order = 1,
            args = overviewArgs,
        },
        search = {
            type = 'group',
            name = "Search",
            icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
            order = 2,
            args = searchArgs,
        },
    }
    for key, widget in pairs(presetArgs) do args["preset_" .. key] = widget end
    for name, group in pairs(classGroups) do args[name] = group end

    return {
        type = 'group',
        name = "Spell Alerts",
        desc = "Choose which enemy and friendly spells trigger a voice alert. Pick a class on the left, then switch each event on or off.",
        order = 2,
        childGroups = "tree",
        args = args,
    }
end
