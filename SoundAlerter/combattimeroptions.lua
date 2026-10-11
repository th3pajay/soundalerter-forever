local SoundAlerter = SoundAlerter

local function timer()
    return SoundAlerter.CombatTimer
end

local function apply(key, value)
    local active = timer()
    if not active then return end
    active:SetSetting(key, value)
end

local function disabled()
    local active = timer()
    return not active or not active:GetSettings().enabled
end

local function range(order, name, desc, key, min, max, step)
    return {
        type = 'range',
        name = name,
        desc = desc,
        min = min,
        max = max,
        step = step,
        get = function() return timer():GetSettings()[key] end,
        set = function(_, value) apply(key, value) end,
        disabled = disabled,
        order = order,
    }
end

local function toggle(order, name, desc, key)
    return {
        type = 'toggle',
        name = name,
        desc = desc,
        get = function() return timer():GetSettings()[key] end,
        set = function(_, value) apply(key, value) end,
        disabled = disabled,
        width = "full",
        order = order,
    }
end

local function color(order, name, desc, key)
    return {
        type = 'color',
        name = name,
        desc = desc,
        get = function()
            local c = timer():GetSettings()[key]
            return c.r, c.g, c.b
        end,
        set = function(_, r, g, b) apply(key, { r = r, g = g, b = b }) end,
        disabled = disabled,
        order = order,
    }
end

function SoundAlerter:BuildCombatTimerOptions()
    local options = {
        type = 'group',
        name = "Combat Drop Timer",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        desc = "A thin line and tiny digits that count down to the moment you leave combat, so you know when you can drink, eat, mount or stealth.",
        order = 2.88,
        args = {
            description = {
                type = 'description',
                name = "|cffFFD700Combat Drop Timer|r\n\n" ..
                       "In PvP you leave combat a few seconds after your last hostile action. This shows how long is left, to the millisecond. " ..
                       "The game does not report every hit to addons, so the countdown is an estimate that snaps to the real moment combat ends. " ..
                       "Unlock to drag it into position. Disabled by default.\n",
                fontSize = "medium",
                order = 1,
            },

            initErrorWarning = {
                type = 'description',
                name = function()
                    return "|cffFF0000Combat Drop Timer failed to initialize this session:|r\n" ..
                           tostring(SoundAlerter.moduleInitErrors and SoundAlerter.moduleInitErrors.CombatTimer) ..
                           "\n\n|cffFFFFFFToggles below will not take effect until this is fixed and you /reload.|r\n"
                end,
                fontSize = "medium",
                order = 1.5,
                hidden = function() return SoundAlerter.CombatTimer ~= nil end,
            },

            generalGroup = {
                type = 'group',
                inline = true,
                name = "General",
                order = 2,
                args = {
                    enabled = {
                        type = 'toggle',
                        name = "Enable Combat Drop Timer",
                        get = function() return timer():GetSettings().enabled end,
                        set = function(_, value) apply("enabled", value) end,
                        width = "full",
                        order = 1,
                    },
                    locked = toggle(2, "Lock Position", "Unlock to drag the timer. A shaded outline and a preview mark it while unlocked.", "locked"),
                    onlyInPvP = toggle(3, "Only In PvP", "Only run in arenas, battlegrounds and while PvP flagged. Combat against creatures follows different rules.", "onlyInPvP"),
                    test = {
                        type = 'execute',
                        name = "Test",
                        desc = "Run a sample fight: a hit, a countdown and the drop.",
                        func = function()
                            if timer() then timer():RunTest() end
                        end,
                        disabled = disabled,
                        order = 4,
                    },
                    resetPosition = {
                        type = 'execute',
                        name = "Reset Position",
                        func = function()
                            if timer() then timer():ResetPosition() end
                        end,
                        disabled = disabled,
                        order = 5,
                    },
                },
            },

            timingGroup = {
                type = 'group',
                inline = true,
                name = "Timing",
                order = 3,
                args = {
                    windowSeconds = range(1, "Combat Window (seconds)", "Seconds without hostile action before the game drops combat. Measure it with /sa ctprobe in debug mode.", "windowSeconds", 3, 8, 0.5),
                    decimals = range(2, "Decimals", "Digits after the decimal point. The game only redraws once per frame, so the last digit blurs at 3.", "decimals", 0, 3, 1),
                },
            },

            appearanceGroup = {
                type = 'group',
                inline = true,
                name = "Appearance",
                order = 4,
                args = {
                    width = range(1, "Width", "Length of the line in pixels.", "width", 60, 400, 5),
                    thickness = range(2, "Thickness", "Height of the line in pixels.", "thickness", 1, 6, 1),
                    scale = range(3, "Scale", "Overall size.", "scale", 0.5, 3, 0.05),
                    showDigits = toggle(4, "Show Digits", "Show the remaining time under the line.", "showDigits"),
                    digitSize = range(5, "Digit Size", "Font size of the digits.", "digitSize", 8, 20, 1),
                    fadeWhenFree = toggle(6, "Fade When Free", "Fade out a moment after combat drops.", "fadeWhenFree"),
                    freeAlpha = range(7, "Opacity When Free", "How visible it stays once you are out of combat. 0 hides it.", "freeAlpha", 0, 1, 0.05),
                    animations = toggle(8, "Animations", "Pulse in the last second, a small bump when the countdown resets, and a flash when combat drops.", "animations"),
                    hotColor = color(9, "Early Color", "More than 2.5 seconds left.", "hotColor"),
                    warmColor = color(10, "Warning Color", "Between 1 and 2.5 seconds left.", "warmColor"),
                    coolColor = color(11, "Almost Free Color", "Under 1 second left, and while waiting for the game to confirm.", "coolColor"),
                    freeColor = color(12, "Free Color", "Out of combat.", "freeColor"),
                },
            },
        },
    }

    return SoundAlerter:RailCombatTimer(options)
end
