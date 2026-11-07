SA_CooldownLearn = {}

local Learn = SA_CooldownLearn

Learn.STEP = 0.1
Learn.MAX_WATCH = 300
Learn.MIN_LENGTH = 1.7
Learn.START_GRACE = 1
Learn.END_GAP = 0.25
Learn.AGREE = 0.4

local math_abs, math_floor = math.abs, math.floor

local function Tenths(value)
    return math_floor(value * 10 + 0.5) / 10
end

function Learn.Store(char)
    local store = char.learnedCooldowns
    if type(store) ~= "table" or type(store.cooldowns) ~= "table" or type(store.pending) ~= "table" then
        store = { cooldowns = {}, pending = {} }
        char.learnedCooldowns = store
    end
    return store
end

function Learn.Expected(store, spellID, known)
    return store.cooldowns[spellID] or known
end

function Learn.Read(spellID)
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if not ok or issecretvalue(info) or type(info) ~= "table" then return nil end
    local start, duration = info.startTime, info.duration
    if type(start) == "number" and type(duration) == "number"
        and not issecretvalue(start) and not issecretvalue(duration) then
        return "plain", duration
    end
    if issecretvalue(info.isActive) then return "flag", nil end
    local onGCD = info.isOnGCD
    if issecretvalue(onGCD) then onGCD = nil end
    return "flag", info.isActive, onGCD
end

function Learn.Step(watch, now, kind, value, onGCD)
    local age = now - watch.at
    if not kind or age >= Learn.MAX_WATCH then return true end
    if kind == "plain" then
        if value > Learn.MIN_LENGTH then return true, value, true end
        return age >= Learn.START_GRACE
    end
    if value == true then
        if onGCD ~= true then watch.seen = now end
        return false
    end
    if value == false then
        if watch.seen and now - watch.seen <= Learn.END_GAP then
            return true, (now + watch.seen) / 2 - watch.at, false
        end
        return watch.seen ~= nil or age >= Learn.START_GRACE
    end
    return false
end

function Learn.Note(store, spellID, length, exact, known)
    if not length or length <= Learn.MIN_LENGTH then return false end
    length = Tenths(length)
    local cooldowns, pending = store.cooldowns, store.pending
    if exact then
        cooldowns[spellID], pending[spellID] = length, nil
        return true
    end
    local reference = cooldowns[spellID] or known
    if reference and math_abs(length - reference) <= Learn.AGREE then
        pending[spellID] = nil
        return false
    end
    local waiting = pending[spellID]
    if reference and not (waiting and math_abs(length - waiting) <= Learn.AGREE) then
        pending[spellID] = length
        return false
    end
    cooldowns[spellID], pending[spellID] = length, nil
    return true
end

local ticker

function Learn.Stop()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

function Learn.Start(spellID, store, known)
    Learn.Stop()
    local watch = { at = GetTime() }
    ticker = C_Timer.NewTicker(Learn.STEP, function()
        local kind, value, onGCD = Learn.Read(spellID)
        local done, length, exact = Learn.Step(watch, GetTime(), kind, value, onGCD)
        if done then
            Learn.Stop()
            Learn.Note(store, spellID, length, exact, known)
        end
    end)
end
