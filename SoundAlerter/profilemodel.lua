SA_ProfileModel = {}

local Model = SA_ProfileModel

Model.NAME_LIMIT = 48
Model.ARM_SECONDS = 4

local function trim(text)
    return ((text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Model.Clean(name)
    return trim(name)
end

function Model.Validate(name, existing)
    local clean = trim(name)
    if clean == "" then
        return false, "Type a name for the new profile."
    end
    if #clean > Model.NAME_LIMIT then
        return false, "Use at most " .. Model.NAME_LIMIT .. " characters."
    end
    if existing[clean] then
        return false, "That profile already exists. Use it from the list."
    end
    return true, nil, clean
end

function Model.NewCharacterDefault(saved)
    if type(saved) ~= "table" then return nil end
    local name = saved.newCharacterProfile
    if type(name) ~= "string" or name == "" then return nil end
    if type(saved.profiles) ~= "table" or type(saved.profiles[name]) ~= "table" then return nil end
    return name
end

function Model.SetNewCharacterDefault(saved, name)
    if type(saved) ~= "table" then return end
    saved.newCharacterProfile = name
end

function Model.ForgetDefault(saved, deleted)
    if type(saved) == "table" and saved.newCharacterProfile == deleted then
        saved.newCharacterProfile = nil
    end
end

function Model.Sorted(names, into)
    local list = into or {}
    for index = #list, 1, -1 do list[index] = nil end
    for _, name in ipairs(names) do list[#list + 1] = name end
    table.sort(list, function(a, b)
        local left, right = a:lower(), b:lower()
        if left ~= right then return left < right end
        return a < b
    end)
    return list
end

function Model.Set(names)
    local set = {}
    for _, name in ipairs(names) do set[name] = true end
    return set
end

local function effective(profile, defaults, key)
    local value = profile[key]
    if value == nil then value = defaults[key] end
    return value and true or false
end

function Model.Summary(profile, defaults, voiceModel, into)
    local summary = into or {}
    local custom = 0
    if type(profile.custom) == "table" then
        for _ in pairs(profile.custom) do custom = custom + 1 end
    end
    local on, total = 0, 0
    for _, spell in ipairs(voiceModel.spells) do
        for _, event in ipairs(spell.events) do
            total = total + 1
            local all = true
            for _, key in ipairs(spell.eventKeys[event]) do
                if not effective(profile, defaults, key) then
                    all = false
                    break
                end
            end
            if all then on = on + 1 end
        end
    end
    summary.custom, summary.on, summary.total = custom, on, total
    return summary
end

function Model.SummaryText(summary)
    return summary.custom .. (summary.custom == 1 and " custom alert" or " custom alerts") .. " \194\183 " .. summary.on .. " of " .. summary.total .. " spell alerts on"
end

function Model.CanDelete(name, current)
    return name ~= current
end

function Model.HeaderText(current, count)
    return "Active: " .. current .. " \194\183 " .. count .. (count == 1 and " profile" or " profiles")
end

do
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
end
