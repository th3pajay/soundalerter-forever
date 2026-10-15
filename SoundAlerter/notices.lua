local SoundAlerter = SoundAlerter
local Notices = {}

local Model = SoundAlerter.NoticesModel
local Plain = SA_COMPAT.Plain

local SPACING = 2
local DEFAULT_THRESHOLD = 20
local EVENTS = {
    "DUEL_REQUESTED", "CONFIRM_SUMMON", "RESURRECT_REQUEST", "PARTY_INVITE_REQUEST", "UPDATE_BATTLEFIELD_STATUS",
    "LFG_PROPOSAL_SHOW", "READY_CHECK", "UPDATE_INVENTORY_DURABILITY",
}

local SETTING_KEYS = { enabled = true, flash = true, chat = true, durabilityThreshold = true }
for index = 1, #Model.NOTICES do SETTING_KEYS[Model.NOTICES[index].key] = true end

local function ReadDurability()
    local readings = {}
    if not GetInventoryItemDurability then return readings end
    for slot = 1, 18 do
        local ok, current, maximum = pcall(GetInventoryItemDurability, slot)
        if ok then
            current, maximum = Plain(current), Plain(maximum)
            if type(current) == "number" and type(maximum) == "number" then
                readings[#readings + 1] = { current, maximum }
            end
        end
    end
    return readings
end

local function ReadQueueStatuses()
    local statuses = {}
    if not (GetMaxBattlefieldID and GetBattlefieldStatus) then return statuses end
    local ok, limit = pcall(GetMaxBattlefieldID)
    limit = ok and Plain(limit) or nil
    if type(limit) ~= "number" then return statuses end
    for index = 1, limit do
        local readable, status = pcall(GetBattlefieldStatus, index)
        statuses[index] = readable and Plain(status) or "none"
    end
    return statuses
end

local function Name(value)
    value = Plain(value)
    if type(value) == "string" then return value end
    return nil
end

function Notices:GetSettings()
    return self.db
end

function Notices:SetSetting(key, value)
    if not SETTING_KEYS[key] then
        error("Notices:SetSetting - unknown setting key '"..tostring(key).."'", 2)
    end
    self.db[key] = value
    self:LoadSettings()
end

function Notices:Play(notice)
    if not PlaySoundFile then return false end
    local path = self.addon.db1.profile.sapath .. notice.file .. ".mp3"
    local ok, willPlay = pcall(PlaySoundFile, path, "Master")
    return ok and willPlay and true or false
end

function Notices:Fire(key, who, test)
    local notice = Model.Find(key)
    if not notice or not self.db then return false end
    if not test then
        if not self.db.enabled or not self.db[key] then return false end
        if not notice.always and self.addon:IsQuiet() then return false end
        if not Model.ShouldFire(self.fired, key, GetTime(), SPACING) then return false end
    end

    self:Play(notice)
    if self.db.flash and FlashClientIcon then pcall(FlashClientIcon) end
    if self.db.chat then self.addon:Print("|cffFF7D0ANotice|r: " .. Model.Message(notice, who)) end
    self.addon:RecordStat("noticeAlerts")
    return true
end

function Notices:CheckDurability()
    local percent = Model.LowestPercent(ReadDurability())
    if Model.DurabilityCrossing(self.durability, percent, self.db.durabilityThreshold or DEFAULT_THRESHOLD) then
        self:Fire("durability", nil)
    end
end

function Notices:CheckQueue()
    if Model.NewConfirmations(self.queue, ReadQueueStatuses()) > 0 then
        self:Fire("queue", nil)
    end
end

function Notices:OnEvent(event, ...)
    if event == "DUEL_REQUESTED" then
        self:Fire("duel", Name((...)))
    elseif event == "CONFIRM_SUMMON" then
        self:Fire("summon", nil)
    elseif event == "RESURRECT_REQUEST" then
        self:Fire("resurrect", Name((...)))
    elseif event == "PARTY_INVITE_REQUEST" then
        self:Fire("invite", Name((...)))
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        self:CheckQueue()
    elseif event == "LFG_PROPOSAL_SHOW" then
        self:Fire("queue", nil)
    elseif event == "READY_CHECK" then
        self:Fire("readyCheck", Name((...)))
    elseif event == "UPDATE_INVENTORY_DURABILITY" then
        self:CheckDurability()
    end
end

function Notices:LoadSettings()
    if not self.db or not self.frame then return end
    self.frame:UnregisterAllEvents()
    if not self.db.enabled then return end
    for _, event in ipairs(EVENTS) do
        pcall(self.frame.RegisterEvent, self.frame, event)
    end
    self.queue = {}
    Model.NewConfirmations(self.queue, ReadQueueStatuses())
    local percent = Model.LowestPercent(ReadDurability())
    self.durability = {}
    if percent then Model.DurabilityCrossing(self.durability, percent, self.db.durabilityThreshold or DEFAULT_THRESHOLD) end
end

function Notices:OnProfileChanged()
    local addon = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not addon then return end
    self.addon = addon
    self.db = addon.db1.profile.notices
    if self.initialized then self:LoadSettings() end
end

function Notices:Test(which)
    local sent = 0
    for _, notice in ipairs(Model.NOTICES) do
        if which == "all" or which == notice.key then
            self:Fire(notice.key, "Test", true)
            sent = sent + 1
        end
    end
    return sent
end

function Notices:PrintHelp()
    self.addon:Print("  |cffFFFFFF/sa notices test [name|all]|r / |cffFFFFFF/sa notices files|r - Try a notice, or list the voice files to record")
end

function Notices:HandleCommand(input)
    local command, rest = (input or ""):match("^(%S*)%s*(.-)$")
    command = command:lower()
    if command == "test" then
        local which = rest ~= "" and rest or "all"
        if Notices:Test(which) == 0 then
            self.addon:Print("|cffFF7D0ANotices|r: no notice called '" .. which .. "'. Names: duel, summon, resurrect, invite, queue, readyCheck, durability")
        end
    elseif command == "files" then
        self.addon:Print("|cffFF7D0ANotices|r: record these into the Voice folder. A notice stays silent until its file exists.")
        for _, line in ipairs(Model.FileLines()) do self.addon:Print("  " .. line) end
    else
        self:PrintHelp()
    end
end

function Notices:Initialize()
    if self.initialized then return end
    local addon = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    if not addon then
        error("Notices:Initialize() called before addon is ready")
        return
    end
    self.addon = addon
    self.db = addon.db1.profile.notices
    self.fired = {}
    self.queue = {}
    self.durability = {}
    self.frame = CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...) Notices:OnEvent(event, ...) end)
    self.initialized = true
    self:LoadSettings()
end

local function module()
    return SoundAlerter.Notices
end

local function apply(key, value)
    local active = module()
    if active then active:SetSetting(key, value) end
end

local function disabled()
    local active = module()
    return not active or not active:GetSettings().enabled
end

local function toggle(order, name, desc, key)
    return {
        type = 'toggle',
        name = name,
        desc = desc,
        get = function() return module():GetSettings()[key] end,
        set = function(_, value) apply(key, value) end,
        disabled = disabled,
        order = order,
    }
end

function SoundAlerter:BuildNoticesOptions()
    local options = {
        type = 'group',
        name = "Notices",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        desc = "Short cues for things that cost you time when you miss them: duel requests, summons, resurrections, group invites, queue pops, ready checks and low durability.",
        order = 2.55,
        args = {
            description = {
                type = 'description',
                name = "|cffFFD700Notices|r\n\n" ..
                       "Short cues for things that cost you time when you miss them. Each one can play a voice line, flash the taskbar icon while the game is in the background, and print a line in chat. " ..
                       "A notice stays silent until its voice file exists in the Voice folder; |cffFFFFFF/sa notices files|r lists the files and what to say. " ..
                       "Queue pops and ready checks ignore the quiet rules. Disabled by default.\n",
                fontSize = "medium",
                order = 1,
            },
            initErrorWarning = {
                type = 'description',
                name = function()
                    return "|cffFF0000Notices failed to initialize this session:|r\n" ..
                           tostring(SoundAlerter.moduleInitErrors and SoundAlerter.moduleInitErrors.Notices) ..
                           "\n\n|cffFFFFFFToggles below will not take effect until this is fixed and you /reload.|r\n"
                end,
                fontSize = "medium",
                order = 1.5,
                hidden = function() return SoundAlerter.Notices ~= nil end,
            },
            generalGroup = {
                type = 'group',
                inline = true,
                name = "General",
                order = 2,
                args = {
                    enabled = {
                        type = 'toggle',
                        name = "Enable Notices",
                        get = function() return module():GetSettings().enabled end,
                        set = function(_, value) apply("enabled", value) end,
                        width = "full",
                        order = 1,
                    },
                    flash = toggle(2, "Flash The Taskbar Icon", "Flash the game's taskbar icon when a notice fires, for when the game is in the background.", "flash"),
                    chat = toggle(3, "Print A Chat Line", "Print a short line in your chat window when a notice fires.", "chat"),
                    testAll = {
                        type = 'execute',
                        name = "Test All",
                        desc = "Fire every notice once, ignoring the switches below.",
                        func = function()
                            if module() then module():Test("all") end
                        end,
                        disabled = disabled,
                        order = 4,
                    },
                },
            },
            noticeGroup = {
                type = 'group',
                inline = true,
                name = "Notices",
                order = 3,
                args = {},
            },
            durabilityGroup = {
                type = 'group',
                inline = true,
                name = "Durability",
                order = 4,
                args = {
                    durabilityThreshold = {
                        type = 'range',
                        name = "Warn Below (percent)",
                        desc = "Warn once when your most worn item drops below this. It warns again after you repair above this plus 5 percent.",
                        min = 5,
                        max = 50,
                        step = 5,
                        get = function() return module():GetSettings().durabilityThreshold end,
                        set = function(_, value) apply("durabilityThreshold", value) end,
                        disabled = disabled,
                        order = 1,
                    },
                },
            },
        },
    }

    for index, notice in ipairs(Model.NOTICES) do
        options.args.noticeGroup.args[notice.key] = toggle(index * 2 - 1, notice.label, "Say \"" .. notice.phrase .. "\" from " .. notice.file .. ".mp3 when this happens." .. (notice.always and " Ignores the quiet rules." or ""), notice.key)
        options.args.noticeGroup.args[notice.key .. "Test"] = {
            type = 'execute',
            name = "Test",
            func = function()
                if module() then module():Test(notice.key) end
            end,
            disabled = disabled,
            width = "half",
            order = index * 2,
        }
    end

    return options
end

SoundAlerter.Notices = Notices
