SA_ProfileCleanup = {}

SA_ProfileCleanup.PASS = 2

SA_ProfileCleanup.DEAD_KEYS = {
    "objectiveAlertsEnabled", "ArenaPartner", "prowlhenemy", "vanishalert", "enemyinterrupts",
    "PresenceofMind", "lavaburst", "sayspell", "saptextself", "blindtext", "blindtextfriend",
    "flagRainbowBorder", "persistentTeamCache", "cspell", "showAdvancedFlag", "showAdvancedProximity",
}

SA_ProfileCleanup.DEAD_RESOURCE_KEYS = {
    "energyTexture", "rageTexture", "healthTexture", "manaTexture",
    "energyLowColor", "rageLowColor", "manaLowColor",
    "lowEnergyThreshold", "lowRageThreshold", "lowManaThreshold",
    "showOverCapAlert", "showLowEnergyAlert", "showLowRageAlert", "showLowManaAlert",
    "smoothPower", "cpAnimations", "fullCPAnimation",
}

local function strip(target, keys)
    local removed = 0
    for _, key in ipairs(keys) do
        if target[key] ~= nil then
            target[key] = nil
            removed = removed + 1
        end
    end
    return removed
end

function SA_ProfileCleanup.Run(saved)
    if type(saved) ~= "table" or type(saved.profiles) ~= "table" then return 0 end
    saved.global = saved.global or {}
    if saved.global.deadKeysPass == SA_ProfileCleanup.PASS then return 0 end

    local removed = 0
    for _, profile in pairs(saved.profiles) do
        if type(profile) == "table" then
            removed = removed + strip(profile, SA_ProfileCleanup.DEAD_KEYS)
            if type(profile.resourceBar) == "table" then
                removed = removed + strip(profile.resourceBar, SA_ProfileCleanup.DEAD_RESOURCE_KEYS)
            end
        end
    end
    saved.global.deadKeysRemoved = nil
    saved.global.deadKeysPass = SA_ProfileCleanup.PASS
    return removed
end
