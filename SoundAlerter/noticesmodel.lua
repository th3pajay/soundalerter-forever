local SoundAlerter = SoundAlerter
local Model = {}

local DURABILITY_REARM = 5

Model.NOTICES = {
    { key = "duel", label = "Duel request", file = "noticeduel", phrase = "Duel request", always = false },
    { key = "summon", label = "Summon", file = "noticesummon", phrase = "Summon", always = false },
    { key = "resurrect", label = "Resurrect request", file = "resurrection", phrase = "Resurrection", always = false },
    { key = "invite", label = "Group invite", file = "noticeinvite", phrase = "Group invite", always = false },
    { key = "queue", label = "Queue ready", file = "noticequeue", phrase = "Queue ready", always = true },
    { key = "readyCheck", label = "Ready check", file = "noticereadycheck", phrase = "Ready check", always = true },
    { key = "durability", label = "Low durability", file = "noticedurability", phrase = "Low durability", always = false },
}

local BY_KEY = {}
for index = 1, #Model.NOTICES do BY_KEY[Model.NOTICES[index].key] = Model.NOTICES[index] end

function Model.Find(key)
    return BY_KEY[key]
end

function Model.ShouldFire(state, key, now, spacing)
    local last = state[key]
    if last and now - last < spacing then return false end
    state[key] = now
    return true
end

function Model.Message(notice, who)
    if type(who) == "string" and who ~= "" then
        return notice.label .. " from " .. who
    end
    return notice.label
end

function Model.LowestPercent(readings)
    local lowest
    for index = 1, #readings do
        local current, maximum = readings[index][1], readings[index][2]
        if type(current) == "number" and type(maximum) == "number" and maximum > 0 then
            local percent = current / maximum * 100
            if not lowest or percent < lowest then lowest = percent end
        end
    end
    return lowest
end

function Model.DurabilityCrossing(state, percent, threshold)
    if type(percent) ~= "number" then return false end
    if percent >= threshold + DURABILITY_REARM then
        state.armed = true
        return false
    end
    if percent < threshold and state.armed ~= false then
        state.armed = false
        return true
    end
    return false
end

function Model.NewConfirmations(known, statuses)
    local fresh = 0
    for index = 1, #statuses do
        local status = statuses[index]
        if status == "confirm" and known[index] ~= "confirm" then fresh = fresh + 1 end
        known[index] = status
    end
    for index = #statuses + 1, #known do known[index] = nil end
    return fresh
end

function Model.FileLines()
    local lines = {}
    for index = 1, #Model.NOTICES do
        local notice = Model.NOTICES[index]
        lines[#lines + 1] = notice.file .. ".mp3 - say \"" .. notice.phrase .. "\""
    end
    return lines
end

SoundAlerter.NoticesModel = Model
