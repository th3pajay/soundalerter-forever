SA_TrackerModel = {}

local Model = SA_TrackerModel

Model.CLASS_ORDER = { "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior", "Other" }

Model.PRESETS = {
    { id = "enableAll", name = "Enable all", note = "Turns every tracked spell on" },
    { id = "disableAll", name = "Disable all", note = "Turns every tracked spell off" },
    { id = "cooldowns", name = "Only cooldowns", note = "Turns every spell on and tracks its cooldown" },
    { id = "auras", name = "Only auras", note = "Turns every spell on and stops tracking cooldowns" },
}

local CLASS_KNOWN = {}
for _, class in ipairs(Model.CLASS_ORDER) do CLASS_KNOWN[class] = true end

function Model.BuildLookup(spells, meta)
    local lookup = {}
    if not spells or not meta then return lookup end
    for _, entries in pairs(spells) do
        if type(entries) == "table" then
            for spellID, key in pairs(entries) do
                local entry = meta[key]
                local class = entry and entry[1]
                if type(spellID) == "number" and class and CLASS_KNOWN[class] and class ~= "Other" and not lookup[spellID] then
                    lookup[spellID] = class
                end
            end
        end
    end
    return lookup
end

function Model.NormalizeClass(token)
    if type(token) ~= "string" or token == "" then return "Other" end
    local class = token:sub(1, 1):upper() .. token:sub(2):lower()
    return CLASS_KNOWN[class] and class or "Other"
end

function Model.ClassOf(spellID, lookup, playerToken)
    return (lookup and lookup[spellID]) or Model.NormalizeClass(playerToken)
end

function Model.Groups(icons, classOf)
    local groups = {}
    for _, class in ipairs(Model.CLASS_ORDER) do groups[class] = {} end
    for index, config in ipairs(icons) do
        local class = classOf(config.spellID)
        local list = groups[class] or groups.Other
        list[#list + 1] = index
    end
    return groups
end

function Model.Count(icons, indices)
    local on = 0
    for _, index in ipairs(indices) do
        if icons[index] and icons[index].enabled then on = on + 1 end
    end
    return on, #indices
end

function Model.Snapshot(icons)
    local snapshot = {}
    for index, config in ipairs(icons) do
        snapshot[index] = { enabled = config.enabled, trackCooldown = config.trackCooldown }
    end
    return snapshot
end

function Model.Restore(icons, snapshot, set)
    for index, saved in ipairs(snapshot) do
        if icons[index] then
            set(index, "enabled", saved.enabled)
            set(index, "trackCooldown", saved.trackCooldown)
        end
    end
end

function Model.ApplyPreset(icons, presetID, set)
    for index = 1, #icons do
        if presetID == "enableAll" then
            set(index, "enabled", true)
        elseif presetID == "disableAll" then
            set(index, "enabled", false)
        elseif presetID == "cooldowns" then
            set(index, "enabled", true)
            set(index, "trackCooldown", true)
        elseif presetID == "auras" then
            set(index, "enabled", true)
            set(index, "trackCooldown", false)
        end
    end
end

function Model.PreviewLines(config, display)
    local lines = {}
    local helpful = config.auraType == "HELPFUL"
    local auraName = helpful and "Buff" or "Debuff"
    local auraColor = helpful and "3DDB85" or "FF594D"
    lines[#lines + 1] = {
        label = "Idle", color = "9AA4B5",
        detail = config.showWhenInactive and "faded icon with a grey border" or "hidden until the aura is active",
    }
    lines[#lines + 1] = {
        label = auraName, color = auraColor,
        detail = (helpful and "green" or "red") .. " border" .. (display.showTimerText and ", duration numbers in gold" or ", duration numbers are off"),
    }
    lines[#lines + 1] = { label = "Expiring", color = "FF8A3D", detail = "border pulses red in the last seconds" }
    if config.trackCooldown then
        lines[#lines + 1] = {
            label = "Cooldown", color = "FFD100",
            detail = display.showCooldownText and ("gold countdown, text size " .. tostring(config.cooldownTextSize or 14)) or "cooldown numbers are off in Display",
        }
        lines[#lines + 1] = {
            label = "Ready!", color = "33FF33",
            detail = display.showReadyText and "green text inside the icon, shrinks to fit small icons" or "turned off in Display",
        }
    else
        lines[#lines + 1] = { label = "Ready!", color = "6B7380", detail = "not shown, Cooldown is off for this spell" }
    end
    return lines
end
