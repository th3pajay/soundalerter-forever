SA_Interrupt = {}

local COOLDOWN = {
    [1766] = 10,
    [1767] = 10,
    [1768] = 10,
    [1769] = 10,
    [6552] = 10,
    [6554] = 10,
    [2139] = 30,
    [19647] = 24,
    [16979] = 15,
    [72] = 12,
    [8042] = 6,
}

function SA_Interrupt.Cooldown(spellID)
    return COOLDOWN[spellID]
end

function SA_Interrupt.PassesMinCast(minCast, startedAt, now)
    if not minCast or minCast <= 0 then return true end
    if not startedAt then return true end
    return now - startedAt >= minCast
end

function SA_Interrupt.EnemySound(unit, settings)
    if unit == "focus" and settings.interruptFocusVoice then
        return "focusinterrupted.mp3"
    end
    return "lockout.mp3"
end
