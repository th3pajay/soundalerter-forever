local Settings = {}

Settings.DEFAULT_ICON_SIZE = 48

local ICON_KEYS = {
    enabled = { default = true, reload = true },
    unit = { default = "player", reload = true },
    auraType = { default = "HELPFUL", reload = true },
    size = { default = Settings.DEFAULT_ICON_SIZE, reload = true },
    showWhenInactive = { default = false, reload = true },
    trackCooldown = { default = false, reload = true },
    cooldownTextSize = { default = 14, reload = true },
    auraDuration = { default = 0, reload = false },
}

local GLOBAL_KEYS = {
    locked = true,
    showTimerText = true,
    showCooldownText = true,
    showReadyText = true,
}

function Settings.IsGlobalKey(key)
    return GLOBAL_KEYS[key] == true
end

function Settings.IconDefault(key)
    local spec = ICON_KEYS[key]
    return spec and spec.default
end

function Settings.NewIcon(fields)
    local icon = {}
    for key, spec in pairs(ICON_KEYS) do
        icon[key] = spec.default
    end
    for key, value in pairs(fields) do
        icon[key] = value
    end
    return icon
end

function Settings.Backfill(icon)
    for key, spec in pairs(ICON_KEYS) do
        if icon[key] == nil then
            icon[key] = spec.default
        end
    end
    return icon
end

function Settings.SetIcon(icon, key, value)
    local spec = ICON_KEYS[key]
    if not spec then
        error("SpellTracker icon setting - unknown key '" .. tostring(key) .. "'", 2)
    end
    icon[key] = value
    return spec.reload
end

SA_TrackerSettings = Settings
