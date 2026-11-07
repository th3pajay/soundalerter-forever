local SoundAlerter = SoundAlerter
local Plain = SA_COMPAT.Plain

SA_UpdateCheck = {}
local Check = SA_UpdateCheck

Check.PREFIX = "SoundAlerterV"
Check.NOTICE = "A newer SoundAlerter is available. Update it through CurseForge."
Check.MAX_STEPS = 200
Check.MAX_RELEASE = 9999
Check.MAX_FAILED = 32
Check.MAX_LENGTH = 200
Check.GAP = 30
Check.GROUP_GAP = 60
Check.FIRST_DELAY = 30
Check.FIRST_JITTER = 15
Check.REPEAT = 3600
Check.REPEAT_JITTER = 300
Check.QUIET = 3000

local band, bor, bxor, bnot, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.bnot, bit.lshift, bit.rshift
local string_byte, string_char, string_format, string_rep, string_sub = string.byte, string.char, string.format, string.rep, string.sub

local WRAP = 4294967296
local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}
local words = {}

local function rotate(value, count)
    return bor(rshift(value, count), lshift(value, 32 - count)) % WRAP
end

local function digestBlock(state, text, start)
    for index = 0, 15 do
        local a, b, c, d = string_byte(text, start + index * 4, start + index * 4 + 3)
        words[index + 1] = a * 16777216 + b * 65536 + c * 256 + d
    end
    for index = 17, 64 do
        local w15, w2 = words[index - 15], words[index - 2]
        local s0 = bxor(rotate(w15, 7), rotate(w15, 18), rshift(w15, 3)) % WRAP
        local s1 = bxor(rotate(w2, 17), rotate(w2, 19), rshift(w2, 10)) % WRAP
        words[index] = (words[index - 16] + s0 + words[index - 7] + s1) % WRAP
    end
    local a, b, c, d, e, f, g, h = state[1], state[2], state[3], state[4], state[5], state[6], state[7], state[8]
    for index = 1, 64 do
        local s1 = bxor(rotate(e, 6), rotate(e, 11), rotate(e, 25)) % WRAP
        local choice = bxor(band(e, f), band(bnot(e), g)) % WRAP
        local first = h + s1 + choice + K[index] + words[index]
        local s0 = bxor(rotate(a, 2), rotate(a, 13), rotate(a, 22)) % WRAP
        local majority = bxor(band(a, b), band(a, c), band(b, c)) % WRAP
        h, g, f, e, d, c, b, a = g, f, e, (d + first) % WRAP, c, b, a, (first + s0 + majority) % WRAP
    end
    state[1], state[2], state[3], state[4] = (state[1] + a) % WRAP, (state[2] + b) % WRAP, (state[3] + c) % WRAP, (state[4] + d) % WRAP
    state[5], state[6], state[7], state[8] = (state[5] + e) % WRAP, (state[6] + f) % WRAP, (state[7] + g) % WRAP, (state[8] + h) % WRAP
end

function Check.Sha256(text)
    local bits = #text * 8
    local padded = text .. "\128" .. string_rep("\0", (55 - #text) % 64) .. "\0\0\0\0" ..
        string_char(math.floor(bits / 16777216) % 256, math.floor(bits / 65536) % 256, math.floor(bits / 256) % 256, bits % 256)
    local state = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }
    for start = 1, #padded, 64 do digestBlock(state, padded, start) end
    return string_format("%08x%08x%08x%08x%08x%08x%08x%08x", state[1], state[2], state[3], state[4], state[5], state[6], state[7], state[8])
end

function Check.Hash(token)
    return string_sub(Check.Sha256(token), 1, 32)
end

function Check.Encode(release, token)
    return string_format("1|%d|%s", release, token)
end

function Check.Decode(text)
    if type(text) ~= "string" or #text > Check.MAX_LENGTH then return nil end
    local release, token, rest = text:match("^1|(%d%d?%d?%d?)|(%x+)(.*)$")
    if not release or #token ~= 32 or token ~= token:lower() then return nil end
    if rest ~= "" and string_sub(rest, 1, 1) ~= "|" then return nil end
    return tonumber(release), token
end

function Check.Proves(token, steps, anchor)
    for _ = 1, steps do token = Check.Hash(token) end
    return token == anchor
end

function Check.Works()
    if Check.works == nil then
        local ok, digest = pcall(Check.Sha256, "abc")
        Check.works = ok and digest == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    end
    return Check.works
end

function Check.NewState(release, token)
    return { best = { release = release, token = token }, failed = {}, failedCount = 0, nextCheck = 0 }
end

function Check.Consider(state, release, token, now)
    local best = state.best
    if release <= best.release or release - best.release > Check.MAX_STEPS then return false end
    if state.failed[token] or now < state.nextCheck then return false end
    state.nextCheck = now + Check.GAP
    if Check.Proves(token, release - best.release, best.token) then
        best.release, best.token = release, token
        return true
    end
    if state.failedCount >= Check.MAX_FAILED then
        state.failed, state.failedCount = {}, 0
    end
    state.failed[token] = true
    state.failedCount = state.failedCount + 1
    return false
end

local Updates = {}
SoundAlerter.UpdateCheck = Updates

local frame
local state
local listening, prefixRegistered, told, pendingNotice = false, false, false, false
local schedule = 0
local lastGroupSize, nextGroupSend = 0, 0
local heard = {}
local ownRelease

local function global()
    return SoundAlerter.db1 and SoundAlerter.db1.global
end

local function send(text, distribution, target)
    local _, sender = SA_PartyShare.Api()
    if sender then pcall(sender, Check.PREFIX, text, distribution, target) end
end

local function canAnnounce()
    local kind = SoundAlerter.cachedInstanceType
    return state and state.best.release > 0 and not InCombatLockdown() and kind ~= "arena" and kind ~= "pvp"
end

local function groupChannel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

local function sendUnlessHeard(text, distribution, target, now)
    local at = heard[distribution]
    if at and now - at < Check.QUIET then return end
    send(text, distribution, target)
end

local function announce()
    if not canAnnounce() then return end
    local text = Check.Encode(state.best.release, state.best.token)
    local now = GetTime()
    if IsInGuild() then sendUnlessHeard(text, "GUILD", nil, now) end
    local group = groupChannel()
    if group then sendUnlessHeard(text, group, nil, now) end
    local channel = SoundAlerter:GlobalSightChannelId()
    if channel then sendUnlessHeard(text, "CHANNEL", channel, now) end
end

local function notify()
    if told then return end
    told = true
    SoundAlerter:Print(Check.NOTICE)
end

local function tick(current)
    if current ~= schedule then return end
    if pendingNotice then
        pendingNotice = false
        notify()
    end
    announce()
    C_Timer.After(Check.REPEAT + math.random(-Check.REPEAT_JITTER, Check.REPEAT_JITTER), function() tick(current) end)
end

local function save()
    local saved = global()
    if saved then saved.updateSeen = { release = state.best.release, token = state.best.token } end
end

local function onMessage(prefix, text, distribution)
    if Plain(prefix) ~= Check.PREFIX or InCombatLockdown() then return end
    local release, token = Check.Decode(Plain(text))
    if not release then return end
    local now = GetTime()
    distribution = Plain(distribution)
    if Check.Consider(state, release, token, now) then
        save()
        notify()
        heard[distribution or ""] = now
    elseif release == state.best.release and token == state.best.token then
        heard[distribution or ""] = now
    end
end

local function onRoster()
    local size = GetNumGroupMembers()
    local grew = size > lastGroupSize
    lastGroupSize = size
    local now = GetTime()
    if not grew or now < nextGroupSend or not canAnnounce() then return end
    nextGroupSend = now + Check.GROUP_GAP
    local group = groupChannel()
    if group then send(Check.Encode(state.best.release, state.best.token), group) end
end

local function restoreSaved(stamp)
    local saved = global()
    local seen = saved and saved.updateSeen
    if not seen then return end
    local steps = type(seen.release) == "number" and seen.release - stamp.release
    if type(seen.token) == "string" and steps and steps > 0 and steps <= Check.MAX_STEPS and Check.Proves(seen.token, steps, stamp.token) then
        state.best.release, state.best.token = seen.release, seen.token
        pendingNotice = true
    else
        saved.updateSeen = nil
    end
end

local function start(stamp)
    local register = SA_PartyShare.Api()
    if not prefixRegistered then prefixRegistered = pcall(register, Check.PREFIX) end
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event, ...)
            if event == "CHAT_MSG_ADDON" then onMessage(...) else onRoster() end
        end)
    end
    pcall(frame.RegisterEvent, frame, "CHAT_MSG_ADDON")
    pcall(frame.RegisterEvent, frame, "GROUP_ROSTER_UPDATE")
    ownRelease = stamp.release
    state = Check.NewState(stamp.release, stamp.token)
    restoreSaved(stamp)
    lastGroupSize = GetNumGroupMembers()
    listening = true
    schedule = schedule + 1
    local current = schedule
    C_Timer.After(Check.FIRST_DELAY + math.random(0, Check.FIRST_JITTER), function() tick(current) end)
end

local function stop()
    pcall(frame.UnregisterEvent, frame, "CHAT_MSG_ADDON")
    pcall(frame.UnregisterEvent, frame, "GROUP_ROSTER_UPDATE")
    schedule = schedule + 1
    state = nil
    listening = false
    heard = {}
end

function Updates:Refresh()
    local profile = SoundAlerter.db1 and SoundAlerter.db1.profile
    local stamp = SA_ReleaseStamp
    local want = profile and profile.updateNotice and stamp and SA_PartyShare.Supported() and Check.Works()
    if want and not listening then
        start(stamp)
    elseif listening and not want then
        stop()
    end
end

function Updates:Reset()
    if listening then stop() end
    told, pendingNotice, prefixRegistered, nextGroupSend = false, false, false, 0
    Check.works = nil
end

function Updates:Status()
    if not state then
        SoundAlerter:Print("Update notice is off.")
        return
    end
    SoundAlerter:Print(string_format("Update notice: your copy is release %d, newest proven release %d, told this session: %s.", ownRelease, state.best.release, tostring(told)))
end
