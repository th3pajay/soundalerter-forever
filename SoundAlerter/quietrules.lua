SA_QuietRules = {}

function SA_QuietRules.Reason(settings, state, now)
    if state.snoozeUntil and now < state.snoozeUntil then return "snoozed" end
    if settings.quietOnTaxi and state.onTaxi then return "taxi" end
    if settings.quietWhenDead and state.dead then return "dead" end
    if settings.quietOutsidePvPFlag and not state.pvpFlagged then return "not flagged" end
    return nil
end

function SA_QuietRules.SnoozeUntil(now, minutes)
    local length = tonumber(minutes)
    if not length or length <= 0 then length = 15 end
    return now + length * 60
end
