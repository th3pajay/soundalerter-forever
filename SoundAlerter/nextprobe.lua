local SoundAlerter = SoundAlerter

do
SA_NextProbe = {}

local Probe = SA_NextProbe

Probe.WATCH_SECONDS = 20
Probe.WATCH_STEP = 0.5
Probe.ROTATION_SHOWN = 6
Probe.PICKS_SHOWN = 8
Probe.CVARS = { "assistedCombatHighlight", "assistedCombatIconUpdateRate", "assistedCombatReduceHighlights" }
Probe.BINDINGS = { "ACTIONBUTTON1", "MULTIACTIONBAR1BUTTON1" }

function Probe.NewWatch()
    return { samples = 0, secret = 0, none = 0, changes = 0, picks = {}, order = {} }
end

function Probe.Sample(watch, value, isSecret)
    watch.samples = watch.samples + 1
    local key
    if value == nil then
        watch.none = watch.none + 1
        key = "none"
    elseif isSecret(value) then
        watch.secret = watch.secret + 1
        key = "secret"
    else
        key = tostring(value)
        if not watch.picks[key] then
            watch.picks[key] = 0
            watch.order[#watch.order + 1] = key
        end
        watch.picks[key] = watch.picks[key] + 1
    end
    if watch.last ~= nil and watch.last ~= key then watch.changes = watch.changes + 1 end
    watch.last = key
end

function Probe.WatchLines(watch, nameOf)
    local lines = {
        string.format("samples %d, distinct spells %d, changes %d, hidden %d, nothing %d",
            watch.samples, #watch.order, watch.changes, watch.secret, watch.none),
    }
    local parts = {}
    for index = 1, math.min(Probe.PICKS_SHOWN, #watch.order) do
        local key = watch.order[index]
        local name = nameOf and nameOf(tonumber(key))
        parts[#parts + 1] = key .. (name and (" " .. name) or "") .. " x" .. watch.picks[key]
    end
    lines[2] = #parts > 0 and ("picks: " .. table.concat(parts, ", ")) or "picks: none"
    if watch.secret > 0 then
        lines[3] = "verdict: the pick is hidden from addons, so the adaptive mode cannot work"
    elseif #watch.order == 0 then
        lines[3] = "verdict: no pick at all; check that assisted combat is available and that you were fighting"
    elseif watch.changes == 0 then
        lines[3] = "verdict: the pick never changed; fight a little longer and use a few abilities"
    else
        lines[3] = "verdict: the pick is readable and follows the fight, so the adaptive mode can work"
    end
    return lines
end

function Probe.Verdict(report)
    if not report.api then return "no assisted combat API on this client: the helper could only use your own rules" end
    if report.available == false then
        return "assisted combat is off for this character (" .. tostring(report.reason or "no reason given") .. "): the helper would be rules-only"
    end
    if report.nextSecret then return "the next spell is hidden from addons: the adaptive mode cannot work" end
    if report.available and report.nextSpell then return "Blizzard's pick is readable: the adaptive mode can work; run /sa nextprobe watch in a fight next" end
    if report.available then return "available but no pick right now: target a mob or dummy and run it again" end
    return "availability could not be read"
end
end

local function isSecret(value)
    return issecretvalue(value)
end

local function describe(value)
    return SA_DebugLog.Describe(value, isSecret)
end

local function plainNumber(value)
    if value == nil or isSecret(value) or type(value) ~= "number" then return nil end
    return value
end

local function spellName(spellID)
    if not spellID then return nil end
    return SA_COMPAT.GetSpellInfo(spellID)
end

local function result(ok, value)
    if not ok then return "error" end
    return value
end

local function count(list)
    if type(list) ~= "table" or isSecret(list) then return describe(list) end
    return tostring(#list)
end

local function store(self, key, lines)
    local global = self.db1 and self.db1.global
    if global then global[key] = { at = time(), lines = lines } end
end

function SoundAlerter:NextActionProbe(rest)
    if rest == "watch" then return self:NextActionWatch() end
    local lines = {}
    local function line(label, ...)
        local parts = {}
        for index = 1, select("#", ...) do parts[index] = describe((select(index, ...))) end
        local text = label .. ": " .. table.concat(parts, " ")
        lines[#lines + 1] = text
        self:Print("  " .. text)
    end
    self:Print("|cffFFD700=== Next action probe ===|r")
    local _, classToken = UnitClass("player")
    line("class, in combat, target", classToken, InCombatLockdown(), UnitExists("target"))

    local report = { api = C_AssistedCombat ~= nil }
    local assisted = C_AssistedCombat
    local nextSpell
    if not assisted then
        line("C_AssistedCombat", nil)
    else
        if assisted.IsAvailable then
            local ok, available, reason = pcall(assisted.IsAvailable)
            line("IsAvailable", result(ok, available), result(ok, reason))
            if ok and not isSecret(available) then report.available, report.reason = available, reason end
        end
        if assisted.GetNextCastSpell then
            for _, visible in ipairs({ false, true }) do
                local ok, spellID = pcall(assisted.GetNextCastSpell, visible)
                line("GetNextCastSpell(" .. tostring(visible) .. ")", result(ok, spellID), spellName(ok and plainNumber(spellID)))
                if ok and spellID ~= nil and isSecret(spellID) then report.nextSecret = true end
                if not visible and ok then nextSpell = plainNumber(spellID) end
            end
        end
        if assisted.GetActionSpell then
            local ok, spellID = pcall(assisted.GetActionSpell)
            line("GetActionSpell", result(ok, spellID), spellName(ok and plainNumber(spellID)))
        end
        if assisted.GetRotationSpells then
            local ok, list = pcall(assisted.GetRotationSpells)
            line("GetRotationSpells count", ok and count(list) or "error")
            if ok and type(list) == "table" and not isSecret(list) then
                local ids = {}
                for index = 1, math.min(SA_NextProbe.ROTATION_SHOWN, #list) do ids[index] = describe(list[index]) end
                lines[#lines + 1] = "rotation: " .. table.concat(ids, ", ")
                self:Print("  " .. lines[#lines])
            end
        end
    end
    report.nextSpell = nextSpell

    if C_CVar and C_CVar.GetCVar then
        for _, name in ipairs(SA_NextProbe.CVARS) do
            local ok, value = pcall(C_CVar.GetCVar, name)
            line("setting " .. name, result(ok, value))
        end
    else
        line("C_CVar", nil)
    end

    local bar = C_ActionBar
    if bar then
        if bar.HasAssistedCombatActionButtons then
            local ok, has = pcall(bar.HasAssistedCombatActionButtons)
            line("one-button rotation on your bars", result(ok, has))
        end
        if nextSpell and bar.FindSpellActionButtons then
            local ok, slots = pcall(bar.FindSpellActionButtons, nextSpell)
            local first
            if ok and type(slots) == "table" and not isSecret(slots) then first = slots[1] end
            line("action slots for the next spell", ok and count(slots) or "error", first)
        end
    else
        line("C_ActionBar", nil)
    end

    if nextSpell and C_Spell then
        if C_Spell.IsSpellUsable then line("next spell usable", pcall(C_Spell.IsSpellUsable, nextSpell)) end
        if C_Spell.IsSpellInRange then line("next spell in range", pcall(C_Spell.IsSpellInRange, nextSpell, "target")) end
        if C_Spell.SpellHasRange then line("next spell has range", pcall(C_Spell.SpellHasRange, nextSpell)) end
        if C_Spell.GetSpellCooldown then
            local ok, info = pcall(C_Spell.GetSpellCooldown, nextSpell)
            local start = info
            if ok and type(info) == "table" then start = info.startTime end
            line("next spell cooldown start", result(ok, start))
        end
    end

    line("target casting, channelling", (UnitCastingInfo("target")), (UnitChannelInfo("target")))
    line("target is a player", UnitIsPlayer("target"))
    line("power, power type", UnitPower("player"), (UnitPowerType("player")))
    if Enum and Enum.PowerType and Enum.PowerType.ComboPoints then
        line("combo points", UnitPower("player", Enum.PowerType.ComboPoints))
    end
    for _, command in ipairs(SA_NextProbe.BINDINGS) do
        line("key for " .. command, GetBindingKey(command))
    end

    local verdict = SA_NextProbe.Verdict(report)
    lines[#lines + 1] = "verdict: " .. verdict
    self:Print("|cffFFD700Verdict:|r " .. verdict)
    store(self, "nextProbe", lines)
    self:Print("Saved for the developer: /reload to write it to the saved file.")
end

function SoundAlerter:NextActionWatch()
    if self.nextProbeTicker then
        self.nextProbeTicker:Cancel()
        self.nextProbeTicker = nil
        self:Print("Next action watch stopped.")
        return
    end
    local assisted = C_AssistedCombat
    if not (assisted and assisted.GetNextCastSpell and C_Timer and C_Timer.NewTicker) then
        self:Print("Next action watch: this client has no assisted combat pick to watch.")
        return
    end
    local watch = SA_NextProbe.NewWatch()
    local total = math.floor(SA_NextProbe.WATCH_SECONDS / SA_NextProbe.WATCH_STEP)
    local done = 0
    self:Print(string.format("Watching Blizzard's next spell for %d s. Fight a mob or dummy and use your abilities. Run it again to stop early.", SA_NextProbe.WATCH_SECONDS))
    self.nextProbeTicker = C_Timer.NewTicker(SA_NextProbe.WATCH_STEP, function()
        local ok, spellID = pcall(assisted.GetNextCastSpell, false)
        if ok then SA_NextProbe.Sample(watch, spellID, isSecret) else SA_NextProbe.Sample(watch, nil, isSecret) end
        done = done + 1
        if done < total then return end
        self.nextProbeTicker = nil
        local lines = SA_NextProbe.WatchLines(watch, spellName)
        self:Print("|cffFFD700=== Next action watch ===|r")
        for _, text in ipairs(lines) do self:Print("  " .. text) end
        lines[#lines + 1] = "in combat at the end: " .. tostring(InCombatLockdown())
        store(self, "nextProbeWatch", lines)
        self:Print("Saved for the developer: /reload to write it to the saved file.")
    end, total)
end
