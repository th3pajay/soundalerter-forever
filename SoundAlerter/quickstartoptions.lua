local SoundAlerter = SoundAlerter
local QuickStart = SA_QuickStart

local ADDON_NAME = "SoundAlerter"
local TEST_SOUND = "trinket.mp3"

local function profile()
    return SoundAlerter.db1.profile
end

local function refresh()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
end

local function volumePercent()
    return math.floor((tonumber(GetCVar("Sound_MasterVolume")) or 1) * 100 + 0.5)
end

local function presetButton(index, preset)
    return {
        type = 'execute',
        name = function() return QuickStart.PresetLabel(preset, QuickStart.ActivePreset(profile()) == preset) end,
        desc = preset.hint,
        width = 1,
        order = index,
        func = function()
            QuickStart.ApplyPreset(profile(), preset.key)
            refresh()
        end,
    }
end

local function buildPresets()
    local args = {
        status = {
            type = 'description',
            name = function() return QuickStart.PresetStatus(profile()) end,
            fontSize = "medium",
            width = "full",
            order = 10,
        },
    }
    for index, preset in ipairs(QuickStart.PRESETS) do
        args[preset.key] = presetButton(index, preset)
    end
    return {
        type = 'group',
        inline = true,
        name = "Pick your style, then fine-tune",
        order = 2,
        args = args,
    }
end

local function buildZones()
    local args = {}
    for index, zone in ipairs(QuickStart.ZONES) do
        args[zone.key] = {
            type = 'toggle',
            name = zone.label,
            desc = zone.hint,
            width = "full",
            order = index,
            get = function() return profile()[zone.key] end,
            set = function(info, value) profile()[zone.key] = value end,
        }
    end
    return {
        type = 'group',
        inline = true,
        name = "Where should it be active?",
        order = 3,
        args = args,
    }
end

local function buildScope()
    return {
        type = 'group',
        inline = true,
        name = "Who triggers alerts?",
        order = 4,
        args = {
            hint = {
                type = 'description',
                name = "|cffFFD700Recommended:|r target and focus for Arena, all enemies for Battlegrounds.",
                width = "full",
                order = 1,
            },
            scope = {
                type = 'select',
                style = 'radio',
                name = "",
                values = {
                    myself = "Target and focus only",
                    enemyinrange = "All enemies in range",
                },
                sorting = { "myself", "enemyinrange" },
                width = "full",
                order = 2,
                get = function() return QuickStart.Scope(profile()) end,
                set = function(info, value) QuickStart.SetScope(profile(), value) end,
            },
        },
    }
end

local function buildSound()
    return {
        type = 'group',
        inline = true,
        name = "Sound",
        order = 5,
        args = {
            volume = {
                type = 'range',
                name = "Master volume",
                desc = "Sets the game's master volume so sound alerts can be louder or softer",
                min = 0,
                max = 1,
                step = 0.1,
                isPercent = true,
                width = "double",
                order = 1,
                get = function() return tonumber(GetCVar("Sound_MasterVolume")) or 1 end,
                set = function(info, value) SetCVar("Sound_MasterVolume", tostring(value)) end,
            },
            test = {
                type = 'execute',
                name = "|cff00D4FFPlay test sound|r",
                desc = "Plays a short alert so you know the volume is right",
                width = "normal",
                order = 2,
                func = function() PlaySoundFile(profile().sapath .. TEST_SOUND) end,
            },
        },
    }
end

local function buildCategories()
    local args = {}
    for index, category in ipairs(QuickStart.CATEGORIES) do
        args[category.key] = {
            type = 'toggle',
            name = category.label,
            desc = category.hint .. "\n\nFine-tune single spells in the Voice Alerts tab.",
            width = "full",
            order = index,
            get = function() return QuickStart.Heard(profile(), category.key) end,
            set = function(info, value) QuickStart.SetHeard(profile(), category.key, value) end,
        }
    end
    return {
        type = 'group',
        inline = true,
        name = "What do you want to hear?",
        order = 6,
        args = args,
    }
end

local function buildGuide()
    local args = {}
    for index, entry in ipairs(QuickStart.GUIDE) do
        args[entry.key] = {
            type = 'execute',
            name = QuickStart.GuideLabel(entry),
            desc = "Open the " .. entry.label .. " tab",
            width = "double",
            order = index,
            func = function()
                LibStub("AceConfigDialog-3.0"):SelectGroup(ADDON_NAME, entry.key)
            end,
        }
    end
    return {
        type = 'group',
        inline = true,
        name = "Tabs at a glance",
        order = 7,
        args = args,
    }
end

function SoundAlerter:BuildQuickStartOptions()
    return {
        type = 'group',
        name = "Quick Start",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        desc = "Get arena-ready in 60 seconds. Pick your style, check the sound, choose what you want to hear. Advanced users can customize 450+ spells in Voice Alerts.",
        order = 0.5,
        args = {
            summary = {
                type = 'description',
                name = function() return QuickStart.Summary(profile(), volumePercent()) end,
                fontSize = "medium",
                width = "full",
                order = 1,
            },
            presets = buildPresets(),
            zones = buildZones(),
            scope = buildScope(),
            sound = buildSound(),
            categories = buildCategories(),
            guide = buildGuide(),
            nextSteps = {
                type = 'group',
                inline = true,
                name = "Next Steps",
                order = 8,
                args = {
                    nextStepsDescription = {
                        type = 'description',
                        name = "|cff00FF00You're all set!|r Type |cffFFD700/sa|r anytime to reopen this menu.\n",
                        fontSize = "medium",
                        order = 1,
                    },
                    authorCredit = {
                        type = 'description',
                        name = "\n|cff00FF00th|r|cff00D4FF3|r|cff00FF00pajay|r\n",
                        fontSize = "medium",
                        order = 2,
                    },
                },
            },
        },
    }
end
