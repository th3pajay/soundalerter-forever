do
SA_PartyShare = {}

local VERSION = "1"
local KINDS = { S = true, P = true, W = true }
local MAX_LENGTH = 240
local MAX_NAME = 32

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

end

do
local SoundAlerter = SoundAlerter
local Messaging = SA_Messaging
local Plain = SA_COMPAT.Plain

local PREFIX = SA_PartyShare.PREFIX
local SEND_SPACING = 10
local RECEIVE_PER_SECOND = 8
local SWEEP_AGE = 60
local SEND_CHANNELS = { "BATTLEGROUND", "RAID", "PARTY" }
local CHATS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }

local sent, received = {}, {}

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
    if not self.db1.profile.shareAlertsSend then return end
    local now = GetTime()
    guid = Plain(guid)
    if not SA_Spacing.Ready(sent, kind, guid, now, SEND_SPACING) then return end
    local channel = GroupChannel()
    if not channel then return end
    local text = SA_PartyShare.Encode(kind, guid, spellID, Plain(class), Plain(level), Plain(name))
    if not text then return end
    SA_Spacing.Mark(sent, kind, guid, now)
    local success = Messaging.SendGroup(PREFIX, text, channel)
    if success then RecordParty("sent") end
    self:Debug("PartyShare", "sent %s to %s: %s", kind, channel, success and "ok" or "failed")
end

local function OnMessage(text, sender, _, now)
    local message = SA_PartyShare.Decode(text)
    if not message then return false end
    if not SA_Spacing.Ready(received, message.kind, message.guid, now, SEND_SPACING) then return true end
    SA_Spacing.Mark(received, message.kind, message.guid, now)
    local from = sender:match("^[^-]*")
    local handled
    if message.kind == "S" then
        handled = SoundAlerter:AlertSharedStealth(message.guid, message.spellID, message.name)
    elseif message.kind == "P" then
        handled = SoundAlerter:AlertSharedProximity(message.guid, message.class, message.name, message.level, from)
    else
        handled = SoundAlerter:AlertSharedWatch(message.guid, message.name, from)
    end
    if handled then RecordParty("received", from) end
    SoundAlerter:Debug("PartyShare", "received %s from %s: %s", message.kind, from, handled and "alerted" or "ignored")
    return true
end

function SoundAlerter:UpdatePartyShare()
    local listen = Messaging.Supported() and self.db1.profile.shareAlertsReceive
    if listen and not Messaging.Listening(PREFIX) then
        Messaging.Listen(PREFIX, { chats = CHATS, receive = RECEIVE_PER_SECOND, inCombat = true, handler = OnMessage })
    elseif not listen and Messaging.Listening(PREFIX) then
        Messaging.Stop(PREFIX)
    end
end

function SoundAlerter:SweepPartyShare(now)
    SA_Spacing.Sweep(sent, now, SWEEP_AGE)
    SA_Spacing.Sweep(received, now, SWEEP_AGE)
end
end
