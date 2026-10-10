local Border = {}

Border.EXPIRING_SECONDS = 3

Border.COLORS = {
    IDLE = { 0.42, 0.45, 0.5 },
    HELPFUL = { 0.24, 0.86, 0.52 },
    HARMFUL = { 1, 0.35, 0.3 },
}

Border.GLOWS = {
    applied = { 1, 1, 1, mode = "flash" },
    expiring = { 1, 0.35, 0.3, mode = "pulse" },
    ready = { 0.24, 0.86, 0.52, mode = "pulse" },
    cooldown = { 0.35, 0.66, 1, mode = "steady" },
}

function Border.BorderKey(auraType, active)
    if active and Border.COLORS[auraType] then
        return auraType
    end
    return "IDLE"
end

function Border.TimerMode(enabled, decision)
    if not enabled or not decision then
        return nil
    end
    if decision.expiration and decision.duration and decision.expiration - decision.duration > 0 then
        return "plain"
    end
    if not decision.expiration and decision.secret then
        return "secret"
    end
    return nil
end

function Border.TimerColor(auraType)
    return Border.COLORS[Border.BorderKey(auraType, true)]
end

function Border.GlowKey(active, remaining, readout)
    if active and remaining and remaining > 0 and remaining <= Border.EXPIRING_SECONDS then
        return "expiring"
    end
    if readout then
        if readout.ready and not active then
            return "ready"
        end
        if readout.numbers ~= "clear" then
            return "cooldown"
        end
    end
    return nil
end

SA_TrackerBorder = Border
