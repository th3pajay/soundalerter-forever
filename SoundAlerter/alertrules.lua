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
local INSTANCE_TYPES = { party = true, raid = true, scenario = true }
local current = {}

function SA_ZoneKind.Of(instanceType, pvpType, resting)
    if instanceType == "arena" or pvpType == "arena" then return "arena" end
    if instanceType == "pvp" then return "battleground" end
    if INSTANCE_TYPES[instanceType] then return "instance" end
    if WORLD_TYPES[pvpType] then return "world" end
    if pvpType == "sanctuary" then return "sanctuary" end
    if (instanceType == nil or instanceType == "none") and not resting then return "world" end
    return "sanctuary"
end

function SA_ZoneKind.Refresh()
    local Plain = SA_COMPAT.Plain
    local _, instanceType = IsInInstance()
    current.instanceType = Plain(instanceType)
    current.pvpType = Plain(SA_COMPAT.GetZonePVPInfo())
    local previous = current.kind
    current.kind = SA_ZoneKind.Of(current.instanceType, current.pvpType, Plain(IsResting()))
    return current.kind ~= previous
end

function SA_ZoneKind.Kind()
    if not current.kind then SA_ZoneKind.Refresh() end
    return current.kind
end

function SA_ZoneKind.Reported()
    return current.instanceType, current.pvpType
end
end

do
SA_ChatTargets = {}

local COVERED_BY_INSTANCE = { PARTY = true, RAID = true }
local seen, picked = {}, {}

function SA_ChatTargets.Pick(targets)
    if #targets <= 1 then return targets end
    local hasInstance = false
    for _, target in ipairs(targets) do
        if target == "INSTANCE_CHAT" then hasInstance = true end
    end
    for key in pairs(seen) do seen[key] = nil end
    for index = #picked, 1, -1 do picked[index] = nil end
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

local GROUP = {
    [450600] = "hex",
    [5782] = "fear", [6215] = "fear", [5484] = "fear", [17928] = "fear",
    [118] = "poly", [12826] = "poly", [28271] = "poly", [28272] = "poly",
    [2094] = "blind",
    [6770] = "sap", [11297] = "sap", [2070] = "sap",
}

local ENEMY = { hex = "hexenemy", fear = "fearenemy", poly = "polyenemy", blind = "blindenemy", sap = "sapenemy" }
local SELF_FRIEND = { hex = "hexselffriend", fear = "fearselffriend", poly = "polyselffriend", blind = "blindselffriend", sap = "sapselffriend" }

SA_CCChat.GROUP = GROUP
SA_CCChat.ENEMY = ENEMY
SA_CCChat.SELF_FRIEND = SELF_FRIEND

function SA_CCChat.Kind(spellID, settings)
    local group = GROUP[spellID]
    if not group or not settings[SELF_FRIEND[group]] then return nil end
    if group == "sap" then return "sap" end
    return "cc"
end

function SA_CCChat.OnEnemy(spellID, settings)
    local group = GROUP[spellID]
    return group ~= nil and settings[ENEMY[group]] and true or false
end
end

do
SA_ChatAreas = {}

local KEYS = { "SAY", "PARTY", "RAID", "BATTLEGROUND" }
local COUNT = #KEYS
local EMPTY = {}
local lists, signatures, sources = {}, {}, {}

SA_ChatAreas.KEYS = KEYS
SA_ChatAreas.AREAS = { "spells", "proximity", "battleground", "custom" }
SA_ChatAreas.rebuilds = 0

local function Fresh(slot, source)
    local signature = signatures[slot]
    if not signature or sources[slot] ~= source then return false end
    for index = 1, COUNT do
        if (source[KEYS[index]] and true or false) ~= signature[index] then return false end
    end
    return true
end

local function Build(slot, source)
    if Fresh(slot, source) then return lists[slot] end
    local signature = signatures[slot] or {}
    local list = lists[slot] or {}
    for index = #list, 1, -1 do list[index] = nil end
    for index = 1, COUNT do
        local key = KEYS[index]
        local on = source[key] and true or false
        signature[index] = on
        if on then list[#list + 1] = key end
    end
    signatures[slot], lists[slot], sources[slot] = signature, list, source
    SA_ChatAreas.rebuilds = SA_ChatAreas.rebuilds + 1
    return list
end

function SA_ChatAreas.Channels(settings, area)
    local all = settings.chatAreaChannels
    local own = all and all[area]
    if type(own) ~= "table" then return EMPTY end
    return Build(area, own)
end

local OLD_FLAG_TEXT = "#class# has the flag!"
local OLD_GROUPS = { PARTY = true, BATTLEGROUND = true }
SA_ChatAreas.LAYOUT = 3

function SA_ChatAreas.Migrate(profile)
    local layout = profile.chatLayout or 0
    if layout >= SA_ChatAreas.LAYOUT then return false end
    if layout < 2 then
        local flagText = profile.flagChatText
        if type(flagText) == "string" and flagText ~= "" and flagText ~= OLD_FLAG_TEXT then
            profile.flagPickupChat = flagText
        end
        if profile.polyenemy == false then profile.polyselffriend = false end
        profile.flagChatText, profile.flagChatChannel, profile.caonlyTF = nil, nil, nil
    end
    local groups = rawget(profile, "chatgroups")
    if type(groups) ~= "table" then groups = OLD_GROUPS end
    if groups.NONE then profile.chatalerts = true end
    local all = profile.chatAreaChannels
    if type(all) ~= "table" then
        all = {}
        profile.chatAreaChannels = all
    end
    for _, area in ipairs(SA_ChatAreas.AREAS) do
        if type(rawget(all, area)) ~= "table" then
            local own = {}
            for index = 1, COUNT do own[KEYS[index]] = groups[KEYS[index]] and true or false end
            all[area] = own
        end
    end
    profile.chatgroups = nil
    profile.chatLayout = SA_ChatAreas.LAYOUT
    return true
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

local function Deliver(message, localLine, area)
    local sent = send(message, area)
    if Present(localLine) then
        local ok, shown = pcall(showLocal, localLine)
        if ok and shown then return end
    end
    if sent == false then printPlain(message) end
end

function SA_AlertText.Ready(enabled)
    if not enabled then return false end
    return not settingsOf().chatalerts
end

function SA_AlertText.Render(template, values)
    return (SentLine(SA_AlertText.Pieces(template), values))
end

function SA_AlertText.Send(message, area)
    if not message or message == "" or not SA_AlertText.Ready(true, area) then return end
    Deliver(message, nil, area)
end

function SA_AlertText.Say(template, values, area)
    if not template or not SA_AlertText.Ready(true, area) then return end
    local pieces = SA_AlertText.Pieces(template)
    local sent, hidden = SentLine(pieces, values)
    local localLine
    if hidden then
        local ok, line = pcall(LocalLine, pieces, values)
        if ok then localLine = line end
    end
    Deliver(sent, localLine, area)
end
end

do
SA_ProxChat = {}

local MAX_CLASSES = 5
local line = {}

function SA_ProxChat.Clean(text)
    text = text:gsub("%(%s+", "("):gsub("%s+%)", ")"):gsub("%s*%(%)", ""):gsub("%s%s+", " ")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+%-$", ""))
end

function SA_ProxChat.Place(subzone, zone, x, y)
    local name = (type(subzone) == "string" and subzone ~= "") and subzone or ((type(zone) == "string" and zone ~= "") and zone or nil)
    if not name then return "" end
    if type(x) == "number" and type(y) == "number" and (x > 0 or y > 0) then
        return name .. " " .. math.floor(x * 100 + 0.5) .. "," .. math.floor(y * 100 + 0.5)
    end
    return name
end

function SA_ProxChat.Group(entries, used, total, place, className)
    for index = #line, 1, -1 do line[index] = nil end
    line[1] = total .. " enemies"
    if place ~= "" then line[2] = " near " .. place end
    line[#line + 1] = ": "
    local shown = math.min(used, MAX_CLASSES)
    for index = 1, shown do
        if index > 1 then line[#line + 1] = ", " end
        line[#line + 1] = className(entries[index].class)
    end
    if total > shown then line[#line + 1] = " +" .. (total - shown) end
    return table.concat(line)
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

function SA_Scoreboard.ClassFor(map, name, second)
    if type(second) == "string" and second ~= "" and type(name) == "string" then
        local full = Key(name .. " " .. second)
        local class = full and map[full]
        if class then return class end
    end
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

SA_Rearm.CASTERS = 64

function SA_Rearm.WaitFor(stamps, key, who, seconds, now)
    local byWho = stamps[key]
    if type(byWho) ~= "table" then
        byWho = { size = 0 }
        stamps[key] = byWho
    end
    local last = byWho[who]
    if last and now - last < seconds then return seconds - (now - last) end
    if not last then
        if byWho.size >= SA_Rearm.CASTERS then
            for name in pairs(byWho) do byWho[name] = nil end
            byWho.size = 0
        end
        byWho.size = byWho.size + 1
    end
    byWho[who] = now
    return nil
end
end

do
SA_SpellAlerts = {}

local Alerts = {}
Alerts.__index = Alerts

local EMPTY = {}
local ROLE_SET = { player = "player", ally = "ally", watched = "enemy", nearby = "enemy" }
local TRAP_KEYS = { freezingtrap = true, frosttrap = true }
local BUBBLE = 642
local TRINKET = 1259718
local QUIET_NEARBY_CAST = 1245940
local AURA_LISTS = { "selfDebuff", "enemyDebuffs", "enemyDebuffdown", "friendCCenemy", "friendCCSuccess", "enemyDebuffdownAP", "auraApplied", "auraRemoved" }
local partyCache = {}

local function clear(t)
    for k in pairs(t) do t[k] = nil end
end

local function isParty(unit)
    local cached = partyCache[unit]
    if cached == nil then
        cached = type(unit) == "string" and unit:match("^party%d$") ~= nil
        partyCache[unit] = cached
    end
    return cached
end

local function scope(db, role)
    return (db.myself and role == "watched") or (db.enemyinrange and role == "nearby")
end

local function stealthScope(db, role)
    return (db.myself and role == "watched") or ((db.enemyinrange or db.stealthAnyEnemy) and role == "nearby") or false
end

function SA_SpellAlerts.New(out, game)
    return setmetatable({
        out = out, game = game,
        maps = {}, counts = {}, used = {}, had = {}, sources = {}, fresh = {}, fields = {},
        stealth = SA_StealthWatch.New(),
        db = EMPTY, lists = EMPTY, pets = EMPTY,
    }, Alerts)
end

function Alerts:Use(settings, lists, pets)
    self.db = settings or EMPTY
    self.lists = lists or EMPTY
    self.pets = pets or EMPTY
    self.sets = nil
    self.custom = nil
end

function Alerts:Forget(unit)
    if unit then
        self.maps[unit], self.counts[unit], self.used[unit] = nil, nil, nil
    else
        clear(self.maps)
        clear(self.counts)
        clear(self.used)
    end
end

local function keep(set, list, db, gate)
    if not list then return end
    for id, key in pairs(list) do
        if gate or db[key] then set[id] = true end
    end
end

local function buildSets(self)
    local db, lists, game = self.db, self.lists, self.game
    local player, ally, enemy = {}, {}, {}
    if not db.dSelfDebuff then
        keep(player, lists.selfDebuff, db, true)
    else
        for id, key in pairs(lists.selfDebuff or EMPTY) do
            if TRAP_KEYS[key] then player[id] = true end
        end
    end
    if not db.dArenaPartner then
        keep(ally, lists.friendCCSuccess, db)
        keep(ally, lists.enemyDebuffdownAP, db)
        keep(enemy, lists.friendCCenemy, db)
    end
    if not db.dEnemyDebuff then keep(enemy, lists.enemyDebuffs, db) end
    if not db.dEnemyDebuffDown then keep(enemy, lists.enemyDebuffdown, db) end
    local applied = lists.auraApplied or EMPTY
    local appliedVoice, appliedChat = not db.aruaApplied, db.chatauraApplied
    for id, key in pairs(applied) do
        if appliedChat or SA_StealthWatch.IsGroup(key) or (appliedVoice and db[key]) then enemy[id] = true end
    end
    local removedVoice, removedChat = not db.auraRemoved, db.chatauraRemoved
    for id, key in pairs(lists.auraRemoved or EMPTY) do
        if removedChat or (removedVoice and db[key]) then enemy[id] = true end
    end
    if db.bubbleenemy and applied[BUBBLE] then enemy[BUBBLE] = true end
    for id, group in pairs(SA_CCChat.GROUP) do
        if db[SA_CCChat.SELF_FRIEND[group]] then player[id], ally[id] = true, true end
        if db[SA_CCChat.ENEMY[group]] then enemy[id] = true end
    end
    local names
    for _, css in pairs(db.custom or EMPTY) do
        local events = css.eventtype
        if events and (events.SPELL_AURA_APPLIED or events.SPELL_AURA_REMOVED) and css.spellid then
            local id = tonumber(css.spellid)
            if id then player[id], ally[id], enemy[id] = true, true, true end
            if css.acceptSpellName and css.spellname then
                names = names or {}
                names[css.spellname] = true
            end
        end
    end
    if names then
        local seen = {}
        local function scan(list)
            for id in pairs(list or EMPTY) do
                if not seen[id] then
                    seen[id] = true
                    local name = game.SpellName(id)
                    if name and names[name] then player[id], ally[id], enemy[id] = true, true, true end
                end
            end
        end
        for i = 1, #AURA_LISTS do scan(lists[AURA_LISTS[i]]) end
        scan(SA_CCChat.GROUP)
    end
    local sets = { player = player, ally = ally, enemy = enemy }
    self.sets = sets
    return sets
end

function Alerts:Tracked(role)
    return (self.sets or buildSets(self))[ROLE_SET[role]] or EMPTY
end

local function link(self, spellID)
    return self.game.Link(spellID) or "Unknown Spell"
end

local function say(self, template, area, spell, enemy, friend, target)
    local fields = self.fields
    fields.spell, fields.enemy, fields.friend, fields.target = spell, enemy, friend, target
    self.out.Say(template, fields, area)
    fields.spell, fields.enemy, fields.friend, fields.target = nil, nil, nil, nil
end

local function customIndex(self)
    local index = self.custom
    if index then return index end
    index = { ids = {}, names = {} }
    for _, css in pairs(self.db.custom or EMPTY) do
        local events = css.eventtype
        if events then
            local id = tonumber(css.spellid)
            for event, on in pairs(events) do
                if on then
                    if id then
                        local byEvent = index.ids[event]
                        if not byEvent then byEvent = {} index.ids[event] = byEvent end
                        local bucket = byEvent[id]
                        if not bucket then bucket = {} byEvent[id] = bucket end
                        bucket[#bucket + 1] = css
                    end
                    if css.acceptSpellName then
                        local named = index.names[event]
                        if not named then named = {} index.names[event] = named end
                        named[#named + 1] = css
                    end
                end
            end
        end
    end
    self.custom = index
    return index
end

local function fire(self, css, event, source, dest, spellID)
    local game, out = self.game, self.out
    if not (game.MatchUnit(dest, css.destuidfilter, css.destcustomname)
        and game.MatchUnit(source, css.sourceuidfilter, css.sourcecustomname)
        and game.MatchType(dest, css.desttypefilter)
        and game.MatchType(source, css.sourcetypefilter)) then return end
    local debug = self.db.debugmode
    if debug then
        out.Debug("CustomSound", "%s matched on %s (spell %s, source %s -> dest %s)", tostring(css.name), event, tostring(spellID), tostring(source and game.Name(source)), tostring(dest and game.Name(dest)))
    end
    if not css.chatAlert then
        out.CustomSound(css.soundfilepath)
    elseif out.Ready(true, "custom") then
        local enemy = ""
        if event ~= "SPELL_CAST_START" then
            enemy = (dest and game.Name(dest)) or (source and game.Name(source)) or ""
        end
        say(self, css.chatalerttext, "custom", link(self, spellID), enemy)
    end
end

local function custom(self, event, source, dest, spellID)
    local all = self.db.custom
    if not all or not next(all) then return end
    local game = self.game
    if game.Secret(spellID) then return end
    local index = customIndex(self)
    local byEvent = index.ids[event]
    local bucket = byEvent and byEvent[spellID]
    if bucket then
        for i = 1, #bucket do fire(self, bucket[i], event, source, dest, spellID) end
    end
    local named = index.names[event]
    if named then
        local spellName = game.SpellName(spellID)
        if spellName then
            for i = 1, #named do
                local css = named[i]
                if tonumber(css.spellid) ~= spellID and css.spellname == spellName then
                    fire(self, css, event, source, dest, spellID)
                end
            end
        end
    end
end

function Alerts:Custom(event, source, dest, spellID)
    custom(self, event, source, dest, spellID)
end

local function stealthChat(self, group, spellID, name, role)
    local db = self.db
    local isVanish, isStealth, isProwl = group == "vanish", group == "stealth", group == "prowl"
    local wanted = ((db.vanishenemy and isVanish) or (db.stealthenemy and isStealth) or (db.prowlenemy and isProwl))
        and (role == "watched" or ((db.vanishTF and isVanish) or (db.stealthTF and isStealth) or (db.prowlTF and isProwl)))
    if self.out.Ready(wanted, "spells") then
        say(self, db.enemychat, "spells", link(self, spellID), name)
    end
end

local function stealthAlert(self, unit, role, spellID, kind, source, name, guid)
    local db, out, game = self.db, self.out, self.game
    local debug = db.debugmode
    if not stealthScope(db, role) then
        if debug then out.Log("%s %d %s dropped: scope (target and focus %s, enemies in range %s)", unit, spellID, kind, tostring(db.myself), tostring(db.enemyinrange)) end
        return
    end
    if (source == "castSuccess" and db.castSuccess) or (source == "auraApplied" and db.aruaApplied) then
        if debug then out.Log("%s %d %s dropped: %s alerts are muted", unit, spellID, kind, source) end
        return
    end
    local list = self.lists[source] or EMPTY
    local band = db.stealthKeepWatch and game.Range(unit) or nil
    if not SA_StealthWatch.Decide(self.stealth, guid, kind, band, db, game.Now(), spellID, source) then
        if debug then out.Log("%s %d %s dropped: already alerted, or first sight with on-sight off", unit, spellID, kind) end
        return
    end
    local played = not (source == "auraApplied" and game.BattleVoices()) and out.Play(list, spellID, unit, guid, name)
    if debug then out.Log("%s %d %s band %s: voice %s (%s)", unit, spellID, kind, tostring(band), played and "played" or "not played", tostring(list[spellID])) end
    stealthChat(self, list[spellID], spellID, name, role)
    if db.shareAlertsSend then out.Share(unit, guid, spellID, name) end
    if SA_StealthWatch.Watching(self.stealth) > 0 then out.Watch() end
end

local function applied(self, unit, role, spellID, source, firstSight)
    local db, lists, out, game = self.db, self.lists, self.out, self.game
    if not firstSight then custom(self, "SPELL_AURA_APPLIED", source, unit, spellID) end

    if role == "ally" then
        if firstSight then return end
        if not db.dArenaPartner then out.Play(lists.friendCCSuccess or EMPTY, spellID, unit) end
        local kind = SA_CCChat.Kind(spellID, db)
        if kind and out.Ready(true, "spells") then
            local enemy = source and game.Name(source) or "An enemy"
            say(self, kind == "sap" and db.sapfriendtext or db.friendchat, "spells", link(self, spellID), enemy, game.Name(unit) or "a friend")
        end
        return
    end

    if role == "player" then
        if firstSight then return end
        local selfList = lists.selfDebuff or EMPTY
        if not db.dSelfDebuff and (game.Engine("player", "Added", spellID) or out.Play(selfList, spellID, unit)) then
            out.SelfDebuff()
        end
        if source and TRAP_KEYS[selfList[spellID]] then out.TrapLanded(source, spellID) end
        local kind = SA_CCChat.Kind(spellID, db)
        if kind and out.Ready(true, "spells") then
            if kind == "cc" then
                say(self, db.selfchat, "spells", link(self, spellID), source and game.Name(source) or "An enemy", nil, "me")
            else
                say(self, db.sapselftext, "spells", link(self, spellID))
            end
        end
        return
    end

    local name = game.Name(unit)
    if not name then return end
    local guid = game.GUID(unit)
    if not guid then return end

    local appliedList = lists.auraApplied or EMPTY
    if SA_StealthWatch.IsGroup(appliedList[spellID]) then
        stealthAlert(self, unit, role, spellID, firstSight and "sight" or "added", "auraApplied", name, guid)
        return
    end
    if firstSight then return end

    if source ~= nil and isParty(source) and not db.dArenaPartner then
        out.Play(lists.friendCCenemy or EMPTY, spellID, unit)
    elseif not db.dEnemyDebuff and not game.Engine(unit, "Added", spellID) then
        out.Play(lists.enemyDebuffs or EMPTY, spellID, unit, guid, name)
    end

    if out.Ready(true, "spells") then
        if SA_CCChat.OnEnemy(spellID, db) then say(self, db.enemychat, "spells", link(self, spellID), name) end
        if db.bubbleenemy and spellID == BUBBLE then say(self, db.bubbleenemytext, "spells", nil, name) end
    end

    if scope(db, role) then
        if not db.aruaApplied and not game.BattleVoices() then out.Play(appliedList, spellID, unit) end
        if out.Ready(db.chatauraApplied and appliedList[spellID], "spells") then
            say(self, db.enemybuffchat, "spells", link(self, spellID), name)
        end
    end
end

local function removed(self, unit, role, spellID)
    local db, lists, out, game = self.db, self.lists, self.out, self.game
    custom(self, "SPELL_AURA_REMOVED", nil, unit, spellID)
    if role == "ally" then
        if not db.dArenaPartner then out.Play(lists.enemyDebuffdownAP or EMPTY, spellID, unit) end
        return
    end
    if role == "player" then return end
    if SA_StealthWatch.IsGroup((lists.auraApplied or EMPTY)[spellID]) then
        SA_StealthWatch.Clear(self.stealth, game.GUID(unit))
    end
    local name = game.Name(unit)
    if not name then return end
    if not db.dEnemyDebuffDown and not game.Engine(unit, "Removed", spellID) then
        out.Play(lists.enemyDebuffdown or EMPTY, spellID, unit)
    end
    if out.Ready(db.chatdownfriend and SA_CCChat.OnEnemy(spellID, db), "spells") then
        say(self, db.ccDownChat, "spells", link(self, spellID), name)
    end
    local removedList = lists.auraRemoved or EMPTY
    if not db.auraRemoved then out.Play(removedList, spellID, unit) end
    if out.Ready(db.chatauraRemoved and removedList[spellID], "spells") then
        say(self, db.auraRemovedChat, "spells", link(self, spellID), name)
    end
end

local function track(self, unit, instance, spellID)
    local map, count = self.maps[unit], self.counts[unit]
    if map[instance] then return false end
    map[instance] = spellID
    local n = (count[spellID] or 0) + 1
    count[spellID] = n
    return n == 1
end

local function untrack(self, unit, instance)
    local map, count = self.maps[unit], self.counts[unit]
    local spellID = map[instance]
    if not spellID then return nil end
    map[instance] = nil
    local n = count[spellID] - 1
    if n > 0 then
        count[spellID] = n
        return nil
    end
    count[spellID] = nil
    return spellID
end

local function resync(self, unit, role, tracked, secretAdded, fresh)
    local had, sources, maps, counts = self.had, self.sources, self.maps, self.counts
    clear(had)
    clear(sources)
    local previous = counts[unit]
    local firstSight = previous == nil
    local before = self.used[unit]
    if before == tracked then before = nil end
    self.used[unit] = tracked
    if previous then
        for spellID in pairs(previous) do had[spellID] = true end
        clear(previous)
        clear(maps[unit])
    else
        maps[unit], counts[unit] = {}, {}
    end
    local game, probed = self.game, 0
    for spellID in pairs(tracked) do
        probed = probed + 1
        local found, instance, source = game.Aura(unit, spellID)
        if found then
            track(self, unit, instance or ("spell" .. spellID), spellID)
            sources[spellID] = source
        end
    end
    self.out.Probed(probed, secretAdded)
    local now = counts[unit]
    for spellID in pairs(now) do
        if not had[spellID] then
            local quiet = firstSight or (before ~= nil and not before[spellID])
            if quiet and fresh and fresh[spellID] then quiet = false end
            applied(self, unit, role, spellID, sources[spellID], quiet)
        end
    end
    for spellID in pairs(had) do
        if not now[spellID] and tracked[spellID] then removed(self, unit, role, spellID) end
    end
end

function Alerts:Resync(unit, role, secretAdded)
    resync(self, unit, role, self:Tracked(role), secretAdded)
end

function Alerts:Aura(unit, role, info, petOnly)
    local game = self.game
    local tracked = petOnly and self.pets or self:Tracked(role)
    local secret = game.Secret
    if not self.maps[unit] then
        local fresh = self.fresh
        clear(fresh)
        if info ~= nil and not secret(info) then
            local full, added = info.isFullUpdate, info.addedAuras
            if not (full ~= nil and secret(full)) and not full and added ~= nil and not secret(added) then
                for _, aura in ipairs(added) do
                    local spellID = aura.spellId
                    if spellID ~= nil and not secret(spellID) and tracked[spellID] then fresh[spellID] = true end
                end
            end
        end
        resync(self, unit, role, tracked, nil, fresh)
        return "first"
    end
    if info == nil or secret(info) then return "unreadable", "unreadable" end
    local full, added, gone = info.isFullUpdate, info.addedAuras, info.removedAuraInstanceIDs
    if (full ~= nil and secret(full)) or (added ~= nil and secret(added)) or (gone ~= nil and secret(gone)) or full then
        return "unreadable", "unreadable"
    end
    local needs = false
    if added then
        local debug, appliedList = self.db.debugmode, self.lists.auraApplied or EMPTY
        for _, aura in ipairs(added) do
            local spellID, instance = aura.spellId, aura.auraInstanceID
            if spellID == nil or secret(spellID) or (instance ~= nil and secret(instance)) then
                needs = true
            elseif tracked[spellID] and track(self, unit, instance, spellID) then
                if debug and SA_StealthWatch.IsGroup(appliedList[spellID]) then
                    self.out.Log("%s %d seen in a UNIT_AURA delta", unit, spellID)
                end
                local source = aura.sourceUnit
                if source ~= nil and secret(source) then source = nil end
                applied(self, unit, role, spellID, source, false)
            end
        end
    end
    if gone then
        for _, instance in ipairs(gone) do
            if instance ~= nil and secret(instance) then
                needs = true
            else
                local spellID = untrack(self, unit, instance)
                if spellID then removed(self, unit, role, spellID) end
            end
        end
    end
    return "delta", needs and "secret" or nil
end

function Alerts:Cast(unit, role, kind, spellID)
    local db, lists, out, game = self.db, self.lists, self.out, self.game
    if kind == "start" then
        custom(self, "SPELL_CAST_START", unit, nil, spellID)
        if not scope(db, role) then return end
        local key = (lists.castStart or EMPTY)[spellID]
        if not key or (not db.chatcastStart and (db.castStart or not db[key])) then return end
        local guid = game.GUID(unit)
        local name = guid and game.Name(unit)
        if not name then return end
        if not db.castStart then out.Play(lists.castStart, spellID, unit, guid, name) end
        if out.Ready(db.chatcastStart and key, "spells") then
            say(self, db.castStartChat, "spells", link(self, spellID), name)
        end
        return
    end
    local guid = game.GUID(unit)
    local name = guid and game.Name(unit)
    if not name then return end
    out.EnemyCast(spellID, name)
    custom(self, "SPELL_CAST_SUCCESS", unit, nil, spellID)
    if out.Ready(db.trinketalert and spellID == TRINKET, "spells") then
        say(self, db.trinketalerttext, "spells", nil, name)
    end
    if spellID == TRINKET and db.trinket then
        out.Trinket(unit, guid, name)
    elseif scope(db, role) and not db.castSuccess then
        local list = lists.castSuccess or EMPTY
        if SA_StealthWatch.IsGroup(list[spellID]) then
            stealthAlert(self, unit, role, spellID, "added", "castSuccess", name, guid)
        elseif not (role == "nearby" and db.enemyinrange and spellID == QUIET_NEARBY_CAST) then
            out.Play(list, spellID, unit, guid, name)
        end
    end
end

function Alerts:SharedStealth(guid, spellID, name)
    local db, game = self.db, self.game
    local list = self.lists.auraApplied or EMPTY
    if not SA_StealthWatch.IsGroup(list[spellID]) or db.aruaApplied or not game.ZoneAllowed() then return false end
    if not SA_StealthWatch.Decide(self.stealth, guid, "added", nil, db, game.Now(), spellID, "auraApplied") then return false end
    local played = self.out.Play(list, spellID, nil, guid, name)
    if db.debugmode then self.out.Log("shared %d from the group: voice %s", spellID, played and "played" or "not played") end
    return played and true or false
end

function Alerts:Tick()
    local db, stealth, game = self.db, self.stealth, self.game
    if not db.stealthKeepWatch then SA_StealthWatch.Reset(stealth) end
    if SA_StealthWatch.Watching(stealth) == 0 then return false end
    if not game.ZoneAllowed() then return true end
    local now = game.Now()
    for guid, entry in SA_StealthWatch.NextWatching, stealth, nil do
        local unit = game.FindWatched(guid)
        if unit and SA_StealthWatch.Decide(stealth, guid, "tick", game.Range(unit), db, now) then
            self.out.Play(self.lists[entry.source] or EMPTY, entry.spellID, unit, guid, game.Name(unit))
        end
    end
    SA_StealthWatch.Sweep(stealth, now)
    return true
end
end
