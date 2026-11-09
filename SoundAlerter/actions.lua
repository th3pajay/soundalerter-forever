local SoundAlerter = SoundAlerter
local Actions = {}

local LOCKABLE = { "ResourceBar", "CastingBars", "SpellTracker", "CastFeed" }

local function profile()
    return SoundAlerter.db1.profile
end

local function say(text)
    SoundAlerter:Print(text)
end

local function onOff(value)
    return value and "|cff00FF00ON|r" or "|cffFF0000OFF|r"
end

local function openPage(key)
    local dialog = LibStub("AceConfigDialog-3.0")
    local open = dialog.OpenFrames and dialog.OpenFrames["SoundAlerter"]
    if not (open and open.frame and open.frame:IsVisible()) then SoundAlerter:ShowConfig() end
    pcall(dialog.SelectGroup, dialog, "SoundAlerter", key)
end

function Actions.Snoozed()
    local until_ = SoundAlerter.snoozeUntil
    return until_ and until_ > GetTime() or false
end

function Actions.Lockable()
    local modules, states = {}, {}
    for _, name in ipairs(LOCKABLE) do
        local module = SoundAlerter[name]
        if module and module.db and module.SetLocked then
            modules[#modules + 1] = module
            states[#states + 1] = module.db.locked
        end
    end
    return modules, states
end

local function cycleSet(delta)
    local menu = SoundAlerter.TrinketMenu
    if not (menu and menu.db and menu.buttons and menu.buttons.set) then return end
    menu:CycleSet(delta)
    say("Trinket set " .. menu.db.activeSet .. " selected.")
end

local function toggleProximity()
    local current = profile()
    current.proximityEnabled = not current.proximityEnabled
    local worldNote = ""
    if current.proximityEnabled and not current.proximityWorld then
        current.proximityWorld = true
        worldNote = " (World PvP switched on too)"
    end
    say("Proximity Alerts: " .. onOff(current.proximityEnabled) .. worldNote)
end

local function toggleBattleground()
    local current = profile()
    current.battlegroundAlertsEnabled = not current.battlegroundAlertsEnabled
    say("Battleground Alerts: " .. onOff(current.battlegroundAlertsEnabled))
end

local function toggleSnooze()
    if Actions.Snoozed() then SoundAlerter:Unsnooze() else SoundAlerter:Snooze() end
end

local function toggleChat()
    local current = profile()
    current.chatalerts = not current.chatalerts
    say("Chat alerts: " .. onOff(current.chatalerts))
end

local function toggleNotices()
    local notices = SoundAlerter.Notices
    if not (notices and notices.db) then return end
    notices:SetSetting("enabled", not notices.db.enabled)
    notices:LoadSettings()
    say("Notices: " .. onOff(notices.db.enabled))
end

local function toggleSightings()
    if not (SA_Messaging and SA_Messaging.Supported()) then
        say("Global sightings are not available on this client.")
        return
    end
    local current = profile()
    current.globalSightings = not current.globalSightings
    SoundAlerter:UpdateGlobalSight()
    say("Global sightings: " .. onOff(current.globalSightings))
end

local function testVoice()
    if not PlaySoundFile then return end
    pcall(PlaySoundFile, profile().sapath .. "detected.mp3", "Master")
    say("Playing a test voice.")
end

local function lockBars()
    local modules, states = Actions.Lockable()
    if #modules == 0 then return end
    local lock = SoundAlerter.MinimapButtonModel.AnyUnlocked(states)
    for _, module in ipairs(modules) do module:SetLocked(lock) end
    say("Bars and trackers " .. (lock and "locked" or "unlocked, drag them now") .. ".")
end

local function nextProfile()
    local db = SoundAlerter.db1
    local name = SoundAlerter.MinimapButtonModel.NextProfile(db:GetProfiles(), db:GetCurrentProfile())
    if not name or name == db:GetCurrentProfile() then return end
    db:SetProfile(name)
    say("Profile: " .. name)
end

local LIST = {
    { id = "trinkettop", group = "Trinket Menu", name = "Use top trinket", click = "SA_TrinketButton1:LeftButton" },
    { id = "trinketbottom", group = "Trinket Menu", name = "Use bottom trinket", click = "SA_TrinketButton2:LeftButton" },
    { id = "trinketset", group = "Trinket Menu", name = "Equip selected trinket set", click = "SA_TrinketSetButton:LeftButton" },
    { id = "trinketgear", group = "Trinket Menu", name = "Switch main and alternate gear set", click = "SA_TrinketGearButton:LeftButton" },
    { id = "trinketweapon", group = "Trinket Menu", name = "Switch DPS and healing weapons", click = "SA_TrinketWeaponButton:Keybind" },
    { id = "nextset", group = "Trinket Menu", name = "Select next trinket set", run = function() cycleSet(1) end },
    { id = "prevset", group = "Trinket Menu", name = "Select previous trinket set", run = function() cycleSet(-1) end },
    { id = "options", group = "Windows", name = "Open or close options", run = function() SoundAlerter:ShowConfig() end },
    { id = "finder", group = "Windows", name = "Open Spell Finder", run = function() openPage("FindSpell") end },
    { id = "stats", group = "Windows", name = "Open Statistics", run = function() openPage("Statistics") end },
    { id = "setup", group = "Windows", name = "Run the setup wizard", run = function() SoundAlerter:ShowQuickStartSetup() end },
    { id = "snooze", group = "Alerts", name = "Snooze or resume proximity alerts", run = toggleSnooze },
    { id = "proximity", group = "Alerts", name = "Proximity alerts on or off", run = toggleProximity, icon = true },
    { id = "battleground", group = "Alerts", name = "Battleground alerts on or off", run = toggleBattleground, icon = true },
    { id = "chat", group = "Alerts", name = "Chat alerts on or off", run = toggleChat },
    { id = "notices", group = "Alerts", name = "Notices on or off", run = toggleNotices },
    { id = "sightings", group = "Alerts", name = "Global sightings on or off", run = toggleSightings },
    { id = "test", group = "Alerts", name = "Play a test voice", run = testVoice },
    { id = "lockbars", group = "Layout and profiles", name = "Lock or unlock bars and trackers", run = lockBars, outOfCombat = true },
    { id = "profile", group = "Layout and profiles", name = "Switch to the next profile", run = nextProfile, outOfCombat = true, icon = true },
}

local BY_ID = {}

function Actions.Header(group)
    return "SOUNDALERTER_" .. group:upper():gsub("[^A-Z]+", "_")
end

for _, action in ipairs(LIST) do
    BY_ID[action.id] = action
    action.binding = action.click and ("CLICK " .. action.click) or ("SOUNDALERTER_" .. action.id:upper())
    _G["BINDING_NAME_" .. action.binding] = action.name
    _G["BINDING_HEADER_" .. Actions.Header(action.group)] = action.group
end

function Actions.List()
    return LIST
end

function Actions.Get(id)
    return BY_ID[id]
end

function Actions.Binding(id)
    local action = BY_ID[id]
    return action and action.binding
end

local SHORT = { { "ALT%-", "a" }, { "CTRL%-", "c" }, { "SHIFT%-", "s" }, { "MOUSEWHEELUP", "MwU" }, { "MOUSEWHEELDOWN", "MwD" }, { "BUTTON", "M" }, { "NUMPAD", "N" } }

local shortKeys = {}

function Actions.ShortKey(key)
    if not key then return "" end
    local short = shortKeys[key]
    if short then return short end
    short = key
    for index = 1, #SHORT do short = short:gsub(SHORT[index][1], SHORT[index][2]) end
    shortKeys[key] = short
    return short
end

local function finish(action)
    action.run()
    if not action.icon then return end
    local button = SoundAlerter.MinimapButton
    if button and button.UpdateIcon then button:UpdateIcon() end
end

local waiting, order = {}, {}
local events

local function flush()
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local due = order
    order = {}
    for index = 1, #due do
        local action = due[index]
        if waiting[action.id] then
            waiting[action.id] = nil
            finish(action)
        end
    end
end

local function queue(action)
    if waiting[action.id] then
        waiting[action.id] = nil
        for index = #order, 1, -1 do
            if order[index] == action then table.remove(order, index) end
        end
        if #order == 0 then events:UnregisterEvent("PLAYER_REGEN_ENABLED") end
        say(action.name .. ": cancelled.")
        return false
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", flush)
    end
    waiting[action.id] = true
    order[#order + 1] = action
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    say(action.name .. ": runs when combat ends. Press again to cancel.")
    return false
end

function Actions.Run(id)
    local action = BY_ID[id]
    if not (action and action.run) then return false end
    if action.outOfCombat and InCombatLockdown() then return queue(action) end
    finish(action)
    return true
end

SA_Actions = Actions
SoundAlerter.Actions = Actions
