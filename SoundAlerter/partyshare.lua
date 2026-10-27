do
SA_PartyShare = {}

local VERSION = "1"
local KINDS = { S = true, P = true, W = true }
local MAX_LENGTH = 240
local MAX_NAME = 32
local BREAKER_LIMIT = 5
local BREAKER_RETRY = 60

SA_PartyShare.PREFIX = "SoundAlerter"

local function CleanName(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("[%c|]", "")
    text = text:match("^%s*(.-)%s*$")
    if text == "" then return nil end
    return text:sub(1, MAX_NAME)
end

local function IsGUID(guid)
    return type(guid) == "string" and guid:find("^Player%-%d+%-%x+$") ~= nil
end

SA_PartyShare.CleanName = CleanName
SA_PartyShare.IsGUID = IsGUID

function SA_PartyShare.Encode(kind, guid, spellID, class, level, name)
    if not KINDS[kind] or not IsGUID(guid) then return nil end
    spellID = spellID or 0
    if type(spellID) ~= "number" or spellID < 0 or spellID > 99999999 or spellID ~= math.floor(spellID) then return nil end
    if class ~= nil and (type(class) ~= "string" or not class:find("^%u+$")) then return nil end
    level = level or -1
    if type(level) ~= "number" or level < -1 or level > 200 or level ~= math.floor(level) then return nil end
    name = CleanName(name)
    if not name then return nil end
    local text = table.concat({ VERSION, kind, guid, spellID, class or "-", level, name }, "|")
    if #text > MAX_LENGTH then return nil end
    return text
end

function SA_PartyShare.Decode(text)
    if type(text) ~= "string" or #text > MAX_LENGTH then return nil end
    local version, kind, guid, spell, class, level, name = text:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
    if version ~= VERSION or not KINDS[kind] or not IsGUID(guid) then return nil end
    if not spell:find("^%d+$") or #spell > 8 then return nil end
    if class ~= "-" and not class:find("^%u+$") then return nil end
    if not level:find("^%-?%d+$") then return nil end
    level = tonumber(level)
    if level < -1 or level > 200 then return nil end
    name = CleanName(name)
    if not name then return nil end
    return {
        kind = kind,
        guid = guid,
        spellID = tonumber(spell),
        class = class ~= "-" and class or nil,
        level = level >= 0 and level or nil,
        name = name,
    }
end

function SA_PartyShare.IsSelf(sender, playerName, secondName)
    if type(sender) ~= "string" or type(playerName) ~= "string" then return false end
    if sender:match("^[^-]*") == playerName then return true end
    return type(secondName) == "string" and secondName ~= "" and sender == playerName .. " " .. secondName
end

function SA_PartyShare.NewBudget()
    return { windowStart = 0, count = 0 }
end

function SA_PartyShare.Allow(budget, now, perSecond)
    if now - budget.windowStart >= 1 then
        budget.windowStart = now
        budget.count = 0
    end
    if budget.count >= perSecond then return false end
    budget.count = budget.count + 1
    return true
end

function SA_PartyShare.NewBreaker()
    return { failures = 0, openedAt = nil, trips = 0 }
end

function SA_PartyShare.Record(breaker, success, now)
    if success then
        breaker.failures, breaker.openedAt = 0, nil
        return false
    end
    breaker.failures = breaker.failures + 1
    if breaker.failures < BREAKER_LIMIT then return false end
    breaker.openedAt = now or 0
    breaker.trips = breaker.trips + 1
    return breaker.failures == BREAKER_LIMIT
end

function SA_PartyShare.Open(breaker, now)
    if breaker.failures < BREAKER_LIMIT then return false end
    return not (now and breaker.openedAt and now - breaker.openedAt >= BREAKER_RETRY)
end

function SA_PartyShare.Succeeded(result, successValue)
    return result == nil or result == true or (successValue ~= nil and result == successValue)
end

function SA_PartyShare.Throttled(result)
    local results = Enum and Enum.SendAddonMessageResult
    local throttle = results and results.AddonMessageThrottle
    return throttle ~= nil and result == throttle
end

function SA_PartyShare.Api()
    local info = C_ChatInfo
    local register = info and info.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
    local send = info and info.SendAddonMessage or SendAddonMessage
    return register, send
end

function SA_PartyShare.Supported()
    local register, send = SA_PartyShare.Api()
    return register ~= nil and send ~= nil
end
end

do
local SoundAlerter = SoundAlerter

local Plain = SA_COMPAT.Plain

local PREFIX = SA_PartyShare.PREFIX
local playerName, playerSecondName = UnitName("player")
local SEND_SPACING = 10
local SEND_PER_SECOND = 4
local RECEIVE_PER_SECOND = 8
local SWEEP_AGE = 60
local SEND_CHANNELS = { "BATTLEGROUND", "RAID", "PARTY" }
local GROUP_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }

local sent, received = {}, {}
local sendBudget, receiveBudget = SA_PartyShare.NewBudget(), SA_PartyShare.NewBudget()
local breaker = SA_PartyShare.NewBreaker()
local prefixRegistered = false
local receiving = false

local function RecordParty(direction, sender)
    local statistics = SoundAlerter:GetModule("Statistics", true)
    if statistics then statistics:RecordParty(direction, sender) end
end

local function GroupChannel()
    local inInstance = IsInInstance()
    for _, name in ipairs(SEND_CHANNELS) do
        local channel = SoundAlerter.ResolveChatChannel(name, inInstance)
        if channel then return channel end
    end
    return nil
end

function SoundAlerter:ShareAlert(kind, guid, spellID, class, level, name)
    local profile = self.db1.profile
    local now = GetTime()
    if not profile.shareAlertsSend or SA_PartyShare.Open(breaker, now) then return end
    local _, send = SA_PartyShare.Api()
    if not send then return end
    guid = Plain(guid)
    if not SA_Spacing.Ready(sent, kind, guid, now, SEND_SPACING) then return end
    local channel = GroupChannel()
    if not channel then return end
    local text = SA_PartyShare.Encode(kind, guid, spellID, Plain(class), Plain(level), Plain(name))
    if not text then return end
    if not SA_PartyShare.Allow(sendBudget, now, SEND_PER_SECOND) then return end
    SA_Spacing.Mark(sent, kind, guid, now)
    local successValue = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success
    local ok, result = pcall(send, PREFIX, text, channel)
    local success = ok and SA_PartyShare.Succeeded(result, successValue)
    if not (ok and SA_PartyShare.Throttled(result)) and SA_PartyShare.Record(breaker, success, now) and breaker.trips == 1 then
        self:Print("Party sharing paused after repeated send failures; it retries every minute.")
    end
    if success then RecordParty("sent") end
    self:Debug("PartyShare", "sent %s to %s: %s (%s)", kind, channel, success and "ok" or "failed", tostring(result))
end

function SoundAlerter:OnAddonMessage(event, prefix, text, channel, sender)
    if Plain(prefix) ~= PREFIX then return end
    text, channel, sender = Plain(text), Plain(channel), Plain(sender)
    if not GROUP_CHANNELS[channel] or type(sender) ~= "string" then return end
    if not self.db1.profile.shareAlertsReceive then return end
    if SA_PartyShare.IsSelf(sender, playerName, playerSecondName) then return end
    local now = GetTime()
    if not SA_PartyShare.Allow(receiveBudget, now, RECEIVE_PER_SECOND) then return end
    local message = SA_PartyShare.Decode(text)
    if not message then return end
    if not SA_Spacing.Ready(received, message.kind, message.guid, now, SEND_SPACING) then return end
    SA_Spacing.Mark(received, message.kind, message.guid, now)
    local from = sender:match("^[^-]*")
    local handled
    if message.kind == "S" then
        handled = self:AlertSharedStealth(message.guid, message.spellID, message.name)
    elseif message.kind == "P" then
        handled = self:AlertSharedProximity(message.guid, message.class, message.name, message.level, from)
    else
        handled = self:AlertSharedWatch(message.guid, message.name, from)
    end
    if handled then RecordParty("received", from) end
    self:Debug("PartyShare", "received %s from %s: %s", message.kind, from, handled and "alerted" or "ignored")
end

function SoundAlerter:UpdatePartyShare()
    local profile = self.db1.profile
    local supported = SA_PartyShare.Supported()
    local wantsSend = supported and profile.shareAlertsSend
    local wantsReceive = supported and profile.shareAlertsReceive
    if (wantsSend or wantsReceive) and not prefixRegistered then
        local register = SA_PartyShare.Api()
        prefixRegistered = pcall(register, PREFIX)
    end
    local listen = wantsReceive and prefixRegistered
    if listen and not receiving then
        self:RegisterEvent("CHAT_MSG_ADDON", "OnAddonMessage")
    elseif not listen and receiving then
        self:UnregisterEvent("CHAT_MSG_ADDON")
    end
    receiving = listen and true or false
end

function SoundAlerter:SweepPartyShare(now)
    SA_Spacing.Sweep(sent, now, SWEEP_AGE)
    SA_Spacing.Sweep(received, now, SWEEP_AGE)
end
end
