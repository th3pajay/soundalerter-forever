SA_ProfileCleanup = {}

SA_ProfileCleanup.DEAD_KEYS = {
    "objectiveAlertsEnabled", "ArenaPartner", "prowlhenemy", "vanishalert", "enemyinterrupts",
    "PresenceofMind", "lavaburst", "sayspell", "saptextself", "blindtext", "blindtextfriend",
    "flagRainbowBorder", "persistentTeamCache",
}

function SA_ProfileCleanup.Run(saved)
    if type(saved) ~= "table" or type(saved.profiles) ~= "table" then return 0 end
    saved.global = saved.global or {}
    if saved.global.deadKeysRemoved then return 0 end

    local removed = 0
    for _, profile in pairs(saved.profiles) do
        if type(profile) == "table" then
            for _, key in ipairs(SA_ProfileCleanup.DEAD_KEYS) do
                if profile[key] ~= nil then
                    profile[key] = nil
                    removed = removed + 1
                end
            end
        end
    end
    saved.global.deadKeysRemoved = true
    return removed
end
