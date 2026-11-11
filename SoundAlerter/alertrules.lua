do
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
end

do
SA_Distance = {}

local RANK = { Close = 1, Nearby = 2, Medium = 3, Detected = 4 }

SA_Distance.BANDS = { "Close", "Nearby", "Medium", "Detected" }

function SA_Distance.Allows(maxBand, label)
    local limit = RANK[maxBand] or RANK.Detected
    if limit >= RANK.Detected then return true end
    local rank = label and RANK[label]
    return rank ~= nil and rank <= limit
end

function SA_Distance.IsRestricted(maxBand)
    return maxBand ~= nil and RANK[maxBand] ~= nil and RANK[maxBand] < RANK.Detected
end
end

do
SA_ZoneKind = {}

local WORLD_TYPES = { contested = true, hostile = true, friendly = true }

function SA_ZoneKind.Of(instanceType, pvpType, resting)
    if instanceType == "arena" or pvpType == "arena" then return "arena" end
    if instanceType == "pvp" then return "battleground" end
    if WORLD_TYPES[pvpType] then return "world" end
    if pvpType == "sanctuary" then return "sanctuary" end
    if (instanceType == nil or instanceType == "none") and not resting then return "world" end
    return "sanctuary"
end
end

do
SA_ChatTargets = {}

local COVERED_BY_INSTANCE = { PARTY = true, RAID = true }

function SA_ChatTargets.Pick(targets)
    if #targets <= 1 then return targets end
    local hasInstance = false
    for _, target in ipairs(targets) do
        if target == "INSTANCE_CHAT" then hasInstance = true end
    end
    local seen, picked = {}, {}
    for _, target in ipairs(targets) do
        if not seen[target] and not (hasInstance and COVERED_BY_INSTANCE[target]) then
            seen[target] = true
            picked[#picked + 1] = target
        end
    end
    return picked
end

end

do
SA_CCChat = {}

local SPELLS = {
    [450600] = "hexselffriend",
    [6215] = "fearselffriend", [5484] = "fearselffriend", [17928] = "fearselffriend",
    [118] = "polyenemy", [12826] = "polyenemy", [28271] = "polyenemy", [28272] = "polyenemy",
    [2094] = "blindselffriend",
    [6770] = "sapselffriend", [11297] = "sapselffriend", [2070] = "sapselffriend",
}

SA_CCChat.SPELLS = SPELLS

function SA_CCChat.Kind(spellID, settings)
    local switch = SPELLS[spellID]
    if not switch or not settings[switch] then return nil end
    if switch == "sapselffriend" then return "sap" end
    return "cc"
end
end

do
SA_AlertText = {}

local isHidden = issecretvalue or function() return false end
local POSSESSIVE = "'s "
local CACHE_MAX = 64
local cache, cached = {}, 0
local buffer = {}
local send, showLocal, printPlain, settingsOf

local function Strip(text)
    return (text:gsub("\\", ""))
end

local function Present(value)
    return isHidden(value) or value ~= nil
end

function SA_AlertText.Attach(sendFn, showLocalFn, printPlainFn, settingsFn)
    send, showLocal, printPlain, settingsOf = sendFn, showLocalFn, printPlainFn, settingsFn
end

function SA_AlertText.Hidden(hidden, fallback)
    return { hidden = hidden, fallback = fallback }
end

function SA_AlertText.Pieces(template)
    local pieces = cache[template]
    if pieces then return pieces end
    pieces = {}
    local at = 1
    while true do
        local first, last = template:find("#%l+#", at)
        if not first then break end
        local text = template:sub(at, first - 1)
        local possessive = text:sub(-3) == POSSESSIVE
        if possessive then text = text:sub(1, -4) end
        if text ~= "" then pieces[#pieces + 1] = Strip(text) end
        pieces[#pieces + 1] = { tag = template:sub(first + 1, last - 1), raw = template:sub(first, last), possessive = possessive }
        at = last + 1
    end
    if at <= #template then pieces[#pieces + 1] = Strip(template:sub(at)) end
    if cached >= CACHE_MAX then cache, cached = {}, 0 end
    cache[template], cached = pieces, cached + 1
    return pieces
end

local function PlainPart(piece, value)
    local lead = piece.possessive and POSSESSIVE or ""
    if value == nil then return lead .. piece.raw end
    if type(value) == "table" then
        if piece.possessive then return "" end
        return Strip(value.fallback or "")
    end
    return lead .. Strip(value)
end

local function SentLine(pieces, values)
    for i = #buffer, 1, -1 do buffer[i] = nil end
    local hidden = false
    for i = 1, #pieces do
        local piece = pieces[i]
        if type(piece) == "string" then
            buffer[#buffer + 1] = piece
        else
            local value = values[piece.tag]
            buffer[#buffer + 1] = PlainPart(piece, value)
            hidden = hidden or (type(value) == "table" and Present(value.hidden))
        end
    end
    return table.concat(buffer), hidden
end

local function LocalLine(pieces, values)
    local line = ""
    for i = 1, #pieces do
        local piece = pieces[i]
        if type(piece) == "string" then
            line = line .. piece
        else
            local value = values[piece.tag]
            if type(value) == "table" and Present(value.hidden) then
                if piece.possessive then line = line .. POSSESSIVE end
                line = line .. value.hidden
            else
                line = line .. PlainPart(piece, value)
            end
        end
    end
    return line
end

local function Deliver(message, localLine)
    local sent = send(message)
    if Present(localLine) then
        local ok, shown = pcall(showLocal, localLine)
        if ok and shown then return end
    end
    if not sent then printPlain(message) end
end

function SA_AlertText.Ready(enabled)
    if not enabled then return false end
    local settings = settingsOf()
    if settings.chatgroups.NONE then return false end
    return not settings.chatalerts
end

function SA_AlertText.Say(template, values)
    if not template or not SA_AlertText.Ready(true) then return end
    local pieces = SA_AlertText.Pieces(template)
    local sent, hidden = SentLine(pieces, values)
    local localLine
    if hidden then
        local ok, line = pcall(LocalLine, pieces, values)
        if ok then localLine = line end
    end
    Deliver(sent, localLine)
end
end

do
SA_Interrupt = {}

local COOLDOWN = {
    [1766] = 10, [1767] = 10, [1768] = 10, [1769] = 10,
    [6552] = 10, [6554] = 10,
    [72] = 12, [1671] = 12, [1672] = 12,
    [2139] = 30,
    [19244] = 30, [19647] = 30,
    [8042] = 6, [8044] = 6, [8045] = 6, [8046] = 6, [10412] = 6, [10413] = 6, [10414] = 6,
    [408681] = 6, [408683] = 6, [408685] = 6, [408687] = 6, [408688] = 6, [408689] = 6, [408690] = 6,
    [1220744] = 6, [1220746] = 6, [1220747] = 6, [1220748] = 6, [1220749] = 6, [1220750] = 6, [1220751] = 6,
    [16979] = 15, [1238122] = 15, [410176] = 10,
    [425609] = 15,
    [15487] = 45,
}

SA_Interrupt.COOLDOWN = COOLDOWN

function SA_Interrupt.Cooldown(spellID)
    return COOLDOWN[spellID]
end

local isSecret = issecretvalue or function() return false end
local WINDOW = 0.6
SA_Interrupt.WINDOW = WINDOW

function SA_Interrupt.IsInterrupt(spellID)
    return not isSecret(spellID) and COOLDOWN[spellID] ~= nil
end

local function EnemyName(name, unit)
    if name then return name end
    if unit == "focus" then return "focus" end
    return "target"
end

local function PassesMinCast(minCast, startedAt, now)
    if not minCast or minCast <= 0 then return true end
    if not startedAt then return true end
    return now - startedAt >= minCast
end

local Tracker = {}
Tracker.__index = Tracker

function SA_Interrupt.New()
    return setmetatable({ castSpell = {}, castAt = {}, pending = {} }, Tracker)
end

function Tracker:CastStarted(unit, spellID, now)
    self.castSpell[unit] = spellID
    self.castAt[unit] = now
end

function Tracker:Forget(unit)
    self.castSpell[unit] = nil
    self.castAt[unit] = nil
end

local function Announce(kind, name, ability, spell, hidden, unit)
    return { kind = kind, name = name, ability = ability, spell = spell, hidden = hidden, unit = unit }
end

function Tracker:Cast(who, spellID, now, name)
    if not SA_Interrupt.IsInterrupt(spellID) then return nil end
    if who == "enemy" then
        self.kickSpell, self.kickName, self.kickAt = spellID, name, now
        return nil
    end
    local pending = self.pending
    if self.waiting and now - pending.at <= WINDOW then
        self.waiting, self.mineAt = false, nil
        return Announce("enemy", pending.name, spellID, pending.spell, pending.hidden, pending.unit)
    end
    self.mineSpell, self.mineAt = spellID, now
    return nil
end

function Tracker:MineLive(now)
    return self.mineAt ~= nil and now - self.mineAt <= WINDOW
end

function Tracker:Interrupted(facts, now, settings)
    local unit = facts.unit
    if unit == "player" then
        local kickAt = self.kickAt
        if not kickAt or now - kickAt > WINDOW then return nil, facts.spellID end
        return Announce("self", self.kickName, self.kickSpell, facts.spellID, nil, unit), facts.spellID
    end
    local spell = facts.spellID
    if isSecret(facts.hidden) then spell = self.castSpell[unit] end
    if now == self.lastAt then return nil, spell, "same frame" end
    if not facts.isEnemy then return nil, spell, "not an enemy" end
    self.lastAt = now
    if not PassesMinCast(settings.interruptMinCast, self.castAt[unit], now) then return nil, spell, "min cast" end
    local byPlayer = facts.byPlayer
    if byPlayer == false then return nil, spell, "someone else" end
    local name = EnemyName(facts.name, unit)
    local live = self:MineLive(now)
    if byPlayer or live then
        local ability = live and self.mineSpell or nil
        self.waiting, self.mineAt = false, nil
        return Announce("enemy", name, ability, spell, facts.hidden, unit), spell
    end
    local pending = self.pending
    pending.name, pending.spell, pending.hidden, pending.unit, pending.at = name, spell, facts.hidden, unit, now
    self.waiting = true
    return nil, spell, "waiting"
end

function SA_Interrupt.EnemySound(unit, settings)
    if unit == "focus" and settings.interruptFocusVoice then
        return "focusinterrupted.mp3"
    end
    return "lockout.mp3"
end
end

do
SA_Scoreboard = {}

local function Key(name)
    if type(name) ~= "string" or name == "" then return nil end
    local base = name:match("^([^-]+)") or name
    return base:lower()
end

function SA_Scoreboard.Fill(map, count, getRow)
    for key in pairs(map) do
        map[key] = nil
    end
    local filled = 0
    for index = 1, count do
        local name, classToken = getRow(index)
        local key = Key(name)
        if key and type(classToken) == "string" and classToken ~= "" then
            map[key] = classToken
            filled = filled + 1
        end
    end
    return filled
end

function SA_Scoreboard.ClassFor(map, name)
    local key = Key(name)
    return key and map[key] or nil
end

function SA_Scoreboard.Clear(map)
    for key in pairs(map) do
        map[key] = nil
    end
end
end

do
SA_LossOfControl = {}

local CATEGORY = {
    STUN = "stun",
    STUN_MECHANIC = "stun",
    FEAR = "fear",
    FEAR_MECHANIC = "fear",
    HORROR = "fear",
    ROOT = "root",
    SILENCE = "silence",
    PACIFYSILENCE = "silence",
    DISARM = "disarm",
    PACIFY = "disarm",
    CONFUSE = "incapacitate",
    DISORIENT = "incapacitate",
    INCAPACITATE = "incapacitate",
    SAP = "incapacitate",
    POLYMORPH = "incapacitate",
    BANISH = "incapacitate",
    CHARM = "incapacitate",
    POSSESS = "incapacitate",
    SCHOOL_INTERRUPT = "interrupt",
}

local VOICE = {
    stun = "stunned.mp3",
    fear = "fear.mp3",
    root = "roots.mp3",
    silence = "silence.mp3",
    disarm = "disarm.mp3",
    incapacitate = "incapacitated.mp3",
    interrupt = "lockout.mp3",
}

local SETTING = {
    stun = "lossOfControlStun",
    fear = "lossOfControlFear",
    root = "lossOfControlRoot",
    silence = "lossOfControlSilence",
    disarm = "lossOfControlDisarm",
    incapacitate = "lossOfControlIncapacitate",
    interrupt = "lossOfControlInterrupt",
}

local SPEAK_SPACING = 2
local DEDUPE_WINDOW = 1

function SA_LossOfControl.Category(locType)
    if type(locType) ~= "string" then return nil end
    return CATEGORY[locType:upper()]
end

function SA_LossOfControl.PlayerIndex(first, second)
    if type(first) == "number" then return first end
    if first == "player" and type(second) == "number" then return second end
    return nil
end

function SA_LossOfControl.ForPlayer(unit)
    return unit == nil or unit == "player"
end

function SA_LossOfControl.Voice(category)
    return VOICE[category]
end

function SA_LossOfControl.ShouldSpeak(settings, state, category, now)
    if not settings.lossOfControlVoice then return false end
    local key = SETTING[category]
    if not key or settings[key] == false then return false end
    if settings.lossOfControlDedupe ~= false and state.lastSelfDebuffAt and now - state.lastSelfDebuffAt < DEDUPE_WINDOW then
        return false
    end
    local last = state.lastSpoken[category]
    if last and now - last < SPEAK_SPACING then return false end
    return true
end
end

do
SA_NameplateRange = {}

function SA_NameplateRange.Plan(enabled, requested, current, backup)
    if enabled then
        if backup == nil then backup = current end
        return requested, backup
    end
    if backup ~= nil then return backup, nil end
    return nil, nil
end
end

do
SA_FlagCache = {}

SA_FlagCache.EPOCH_FLOOR = 1000000000

function SA_FlagCache.Prune(cache, now, window)
    local removed = 0
    for name, entry in pairs(cache) do
        local live = false
        for _, at in pairs(entry) do
            if now - at < window then
                live = true
                break
            end
        end
        if not live then
            cache[name] = nil
            removed = removed + 1
        end
    end
    return removed
end

function SA_FlagCache.Normalize(lastSeen, now)
    if lastSeen == nil or lastSeen < SA_FlagCache.EPOCH_FLOOR then return now end
    return lastSeen
end
end

do
SA_Spacing = {}

function SA_Spacing.Ready(map, kind, key, now, spacing)
    local byKey = map[kind]
    if not byKey then return true end
    local last = byKey[key]
    return last == nil or now - last >= spacing
end

function SA_Spacing.Mark(map, kind, key, now)
    local byKey = map[kind]
    if not byKey then
        byKey = {}
        map[kind] = byKey
    end
    byKey[key] = now
end

function SA_Spacing.Sweep(map, now, maxAge)
    local removed = 0
    for _, byKey in pairs(map) do
        for key, at in pairs(byKey) do
            if now - at > maxAge then
                byKey[key] = nil
                removed = removed + 1
            end
        end
    end
    return removed
end
end

do
SA_StealthWatch = {}

local GROUP = { stealth = true, prowl = true, vanish = true, shadowmeld = true, invisibility = true }
local RANK = { Close = 1, Nearby = 2, Medium = 3, Detected = 4 }
local ALERT_COOLDOWN = 3
local DEFAULT_GAP = 4
local ENTRY_MAX_AGE = 60
local SWEEP_ABOVE = 40

function SA_StealthWatch.IsGroup(name)
    return name ~= nil and GROUP[name] == true
end

function SA_StealthWatch.New()
    return { byGUID = {}, count = 0, watching = 0 }
end

function SA_StealthWatch.Reset(state)
    for guid in pairs(state.byGUID) do state.byGUID[guid] = nil end
    state.count = 0
    state.watching = 0
end

local function Retire(state, entry)
    if entry.watching then
        entry.watching = false
        state.watching = state.watching - 1
    end
end

function SA_StealthWatch.Sweep(state, now)
    for guid, entry in pairs(state.byGUID) do
        local last = entry.seenAt > entry.alertAt and entry.seenAt or entry.alertAt
        if now - last > ENTRY_MAX_AGE then
            Retire(state, entry)
            state.byGUID[guid] = nil
            state.count = state.count - 1
        end
    end
end

function SA_StealthWatch.Watching(state)
    return state.watching
end

function SA_StealthWatch.Clear(state, guid)
    local entry = state.byGUID[guid]
    if entry then Retire(state, entry) end
end

function SA_StealthWatch.NextWatching(state, guid)
    local entry
    repeat
        guid, entry = next(state.byGUID, guid)
    until guid == nil or entry.watching
    return guid, entry
end

local function Begin(state, guid, now)
    local entry = state.byGUID[guid]
    if not entry then
        if state.count >= SWEEP_ABOVE then SA_StealthWatch.Sweep(state, now) end
        entry = { alertAt = now, seenAt = now, watching = false }
        state.byGUID[guid] = entry
        state.count = state.count + 1
    end
    return entry
end

local function Announce(state, entry, band, watch, now, spellID, source)
    entry.alertAt = now
    entry.seenAt = now
    entry.rank = band and RANK[band] or nil
    entry.spellID = spellID
    entry.source = source
    if watch and not entry.watching then
        entry.watching = true
        state.watching = state.watching + 1
    elseif not watch then
        Retire(state, entry)
    end
end

function SA_StealthWatch.Decide(state, guid, kind, band, settings, now, spellID, source)
    if guid == nil then return false end
    local watch = settings.stealthKeepWatch == true

    if kind == "added" or kind == "sight" then
        if kind == "sight" and not (settings.stealthOnSight == true or watch) then return false end
        local entry = state.byGUID[guid]
        if entry and now - entry.alertAt < ALERT_COOLDOWN then
            entry.seenAt = now
            return false
        end
        entry = Begin(state, guid, now)
        Announce(state, entry, band, watch, now, spellID, source)
        return true, entry
    end

    if kind ~= "tick" then return false end
    local entry = state.byGUID[guid]
    if not (watch and entry and entry.watching) then return false end
    entry.seenAt = now

    local current = band and RANK[band]
    if not current then return false end
    local previous = entry.rank
    if previous == nil or current > previous then
        entry.rank = current
        return false
    end
    if current == previous then return false end
    if not SA_Distance.Allows(settings.stealthWatchBand, band) then
        entry.rank = current
        return false
    end
    local gap = tonumber(settings.stealthWatchGap) or DEFAULT_GAP
    if now - entry.alertAt < gap then return false end
    entry.rank = current
    entry.alertAt = now
    return true, entry
end
end

do
SA_ToastClick = {}

local RESTORE = {
    none = "\n/focus target\n/cleartarget",
    other = "\n/focus target\n/targetlasttarget",
}

function SA_ToastClick.Sanitize(text)
    if type(text) ~= "string" then return "" end
    return (text:gsub("[%z\r\n]", ""))
end

function SA_ToastClick.TargetMacro(name)
    return "/target " .. SA_ToastClick.Sanitize(name)
end

function SA_ToastClick.TargetState(hasTarget, targetName, unitName)
    if not hasTarget then return "none" end
    if targetName ~= nil and targetName == unitName then return "same" end
    return "other"
end

function SA_ToastClick.FocusMacro(safeName, targetState)
    if targetState == "same" then return "/focus target" end
    return "/target " .. safeName .. (RESTORE[targetState] or RESTORE.other)
end
end

do
SA_Rearm = {}

function SA_Rearm.Wait(stamps, key, seconds, now)
    local last = stamps[key]
    if last and now - last < seconds then return seconds - (now - last) end
    stamps[key] = now
    return nil
end
end
