SA_AuraSound = {}

function SA_AuraSound.Desired(selfDebuffList, settings)
    local desired = {}
    if not (settings.engineAuraSounds and not settings.dSelfDebuff and selfDebuffList) then
        return desired
    end
    for spellID, key in pairs(selfDebuffList) do
        if settings[key] then
            desired[spellID] = settings.sapath .. key .. ".mp3"
        end
    end
    return desired
end

function SA_AuraSound.Diff(registered, desired)
    local add, remove = {}, {}
    for spellID, file in pairs(desired) do
        local entry = registered[spellID]
        if not entry or entry.file ~= file then
            add[#add + 1] = spellID
        end
    end
    for spellID, entry in pairs(registered) do
        if desired[spellID] ~= entry.file then
            remove[#remove + 1] = spellID
        end
    end
    return add, remove
end
