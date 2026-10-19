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
