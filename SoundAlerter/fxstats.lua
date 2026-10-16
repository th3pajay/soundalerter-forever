local FxStats = {}

local function rate(count, seconds)
    if not seconds or seconds <= 0 then return 0 end
    return count / seconds
end

function FxStats.CastingLine(stats)
    return string.format(
        "Casting bars (%s): %.1f redraws/s, %.1f fill writes/s, %.1f throttled/s, %d bar(s) casting",
        stats.quality, rate(stats.updates, stats.seconds), rate(stats.writes, stats.seconds), rate(stats.throttled, stats.seconds), stats.active or 0)
end

function FxStats.TrackerLine(stats)
    local idle = rate(stats.idle, stats.seconds)
    return string.format(
        "Spell tracker (%s): %.1f timer ticks/s, %.1f icons visited/s, %.1f border shifts/s, %.1f cooldown ticks/s, %.0f idle frames/s, %d timed icon(s)",
        stats.quality, rate(stats.ticks, stats.seconds), rate(stats.visited, stats.seconds), rate(stats.shifts, stats.seconds), rate(stats.cooldownTicks, stats.seconds), idle, stats.timed or 0)
end

function SoundAlerter:ShowFxStats(argument)
    local reset = argument == "reset"
    local shown = false
    if self.CastingBars and self.CastingBars.GetFxStats then
        local stats = self.CastingBars:GetFxStats(reset)
        self:Print(FxStats.CastingLine(stats))
        shown = true
    end
    if self.SpellTracker and self.SpellTracker.GetFxStats then
        local stats = self.SpellTracker:GetFxStats(reset)
        self:Print(FxStats.TrackerLine(stats))
        shown = true
    end
    if not shown then
        self:Print("No animated modules are loaded.")
    elseif reset then
        self:Print("Animation counters reset.")
    end
end

SoundAlerter.FxStats = FxStats
