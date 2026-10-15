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

local function summary(settings)
    local Page = SoundAlerter.Page
    local on = 0
    for index = 1, #Model.NOTICES do
        if settings[Model.NOTICES[index].key] then on = on + 1 end
    end
    return Page.Summary(settings, on .. " of " .. #Model.NOTICES .. " notices on",
        "flash " .. (settings.flash and "on" or "off"), "chat " .. (settings.chat and "on" or "off"))
end

function SoundAlerter:BuildNoticesOptions()
    local Page = SoundAlerter.Page
    local rows = {
        Page.Toggle("flash", "Flash the taskbar icon", "Flash the game's taskbar icon when a notice fires, for when the game is in the background.", false, "How it alerts"),
        Page.Toggle("chat", "Print a chat line", "Print a short line in your chat window when a notice fires.", false, "How it alerts"),
    }
    for _, notice in ipairs(Model.NOTICES) do
        rows[#rows + 1] = Page.Toggle(notice.key, notice.label, "Say \"" .. notice.phrase .. "\" from " .. notice.file .. ".mp3 when this happens." .. (notice.always and " Ignores the quiet rules." or ""), false, "Notices")
    end
    rows[#rows + 1] = Page.When("durability", Page.Range("durabilityThreshold", "Warn below", "Warn once when your most worn item drops below this. It warns again after you repair above this plus 5 percent.", 5, 50, 5, true, "Durability", " %"))
    rows[#rows + 1] = Page.Action("Test all", "Fire every notice once, ignoring the switches.", function()
        local active = module()
        if active then active:Test("all") end
    end, true, "Test")
    for _, notice in ipairs(Model.NOTICES) do
        rows[#rows + 1] = Page.Action("Test " .. notice.label:lower(), "Fire just this notice.", function()
            local active = module()
            if active then active:Test(notice.key) end
        end, true, "Test")
    end

    return Page.Module({
        key = "Notices",
        title = "Notices",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        desc = "Short cues for things that cost you time when you miss them: duel requests, summons, resurrections, group invites, queue pops, ready checks and low durability.",
        blurb = "Short cues for things that cost you time when missed. A notice stays silent until its voice file exists; /sa notices files lists them. Queue pops and ready checks ignore the quiet rules.",
        order = 2.55,
        module = module,
        defaults = function() return dbDefaults.profile.notices end,
        summary = summary,
        rows = rows,
    })
end

SoundAlerter.Notices = Notices
