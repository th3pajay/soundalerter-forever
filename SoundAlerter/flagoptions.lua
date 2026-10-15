local SoundAlerter = SoundAlerter

local EVENTS = {
    { "flagPickupAudio", "Pickups" }, { "flagDropAudio", "Drops" },
    { "flagCaptureAudio", "Captures" }, { "flagReturnAudio", "Returns" },
}
local TEXTURES = { { "Solid", "Solid (Default)" }, { "DialogBox", "Dialog Box" } }
local CHANNELS = { { "SAY", "Say" }, { "PARTY", "Party" }, { "RAID", "Raid" }, { "BATTLEGROUND", "Battleground" } }
local ENEMY_RED = { 0.35, 0.05, 0.05, 0.95 }
local FRIENDLY_GREEN = { 0.05, 0.3, 0.08, 0.95 }

local function flags()
    return SoundAlerter.FlagAlerts
end

local function toasts()
    return SoundAlerter.ProximityToasts
end

local function view()
    local active = flags()
    if not active then return nil end
    local settings = active:GetSettings()
    local shared = toasts()
    return { enabled = settings.battlegroundAlertsEnabled, f = settings, t = shared and shared:GetSettings() }
end

local function write(key, value)
    local active = flags()
    if not active then return end
    if key == "enabled" then
        active:SetSetting("battlegroundAlertsEnabled", value)
        if SoundAlerter.UpdateMinimapButtonIcon then SoundAlerter:UpdateMinimapButtonIcon() end
        return
    end
    local scope, name = key:match("^(%a+)%.(.+)$")
    if scope == "t" then
        local shared = toasts()
        if shared then shared:SetSetting(name, value) end
        return
    end
    if scope ~= "f" then return end
    active:SetSetting(name, value)
    if name == "flagOnlyEnemyTeam" and value then
        active:SetSetting("flagOnlyFriendlyTeam", false)
    elseif name == "flagOnlyFriendlyTeam" and value then
        active:SetSetting("flagOnlyEnemyTeam", false)
    elseif name == "flagAllActions" and value then
        active:SetSetting("flagOnlyEnemyTeam", false)
        active:SetSetting("flagOnlyFriendlyTeam", false)
    elseif name == "flagToasts.positionX" or name == "flagToasts.positionY" then
        active:UpdateFlagToastLayout()
    end
end

local function testToasts()
    local active = flags()
    if not active then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000SoundAlerter:|r FlagAlerts module not loaded. Try /reload|r")
        return
    end
    active:ShowFlagToast("TestEnemy", "ROGUE", "PICKUP", "HORDE_TEAM")
    SoundAlerter:ScheduleTimer(function()
        active:ShowFlagToast("TestFriendly", "PALADIN", "PICKUP", "ALLIANCE_TEAM")
    end, 1.2)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00SoundAlerter:|r Test flag toasts displayed at actual alert position!")
end

local FlagPreview = { height = 100 }

function FlagPreview.build(stage)
    local Page = SoundAlerter.Page
    local state = { toasts = { Page.Toast.Build(stage, 1), Page.Toast.Build(stage, 2) }, started = 0 }
    state.note = stage:CreateFontString(nil, "OVERLAY")
    state.note:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    state.note:SetTextColor(0.588, 0.627, 0.698)
    state.note:SetPoint("CENTER", stage, "CENTER", 0, 0)
    stage:SetScript("OnUpdate", function(_, elapsed)
        state.started = state.started + elapsed
        for _, toast in ipairs(state.toasts) do Page.Toast.Tick(toast, state.started) end
    end)
    return state
end

function FlagPreview.update(state, settings)
    if not state then return end
    local Page = SoundAlerter.Page
    local f = settings.f
    local t = settings.t or {}
    state.note:SetText(f.flagToastsEnabled and "" or "Flag toasts are off. Alerts come through audio only.")
    local teamColors = f.flagTeamBackgroundColors
    local samples = {
        { "Shadowstep", "picked up the flag", { 1, 0.96, 0.41 }, teamColors and f.flagEnemyRedBackground and ENEMY_RED or nil, "Interface\\Icons\\INV_BannerPVP_01" },
        { "Lightbringer", "captured the flag", { 0.96, 0.55, 0.73 }, teamColors and f.flagFriendlyGreenBackground and FRIENDLY_GREEN or nil, "Interface\\Icons\\INV_BannerPVP_02" },
    }
    for index, toast in ipairs(state.toasts) do
        local sample = samples[index]
        Page.Toast.Update(toast, {
            shown = f.flagToastsEnabled,
            name = sample[1],
            sub = sample[2],
            nameColor = sample[3],
            background = sample[4],
            icon = sample[5],
            rainbow = t.rainbowBorder,
        })
    end
end

local function summary(settings)
    local Page = SoundAlerter.Page
    local events = {}
    for _, event in ipairs(EVENTS) do
        if settings.f[event[1]] then events[#events + 1] = event[2] end
    end
    return Page.Summary(settings,
        #events > 0 and table.concat(events, ", ") or "no flag events",
        "toasts " .. (settings.f.flagToastsEnabled and "on" or "off"),
        "chat " .. (settings.f.flagChatEnabled and "on" or "off"))
end

function SoundAlerter:BuildFlagOptions()
    local Page = SoundAlerter.Page
    local spec = Page.Spec({
        title = "Battleground Alerts",
        icon = "Interface\\Icons\\INV_BannerPVP_02",
        blurb = "Tracks battleground objectives. Supported: Warsong Gulch and Twin Peaks (flag pickup, drop and capture), Eye of the Storm (pickup and drop only). Arathi Basin and Alterac Valley are coming soon. Battlegrounds only.",
        get = view,
        set = write,
        defaults = function()
            return { f = dbDefaults.profile, t = dbDefaults.profile.proximityToasts }
        end,
        summary = summary,
        preview = FlagPreview,
        rows = {
            Page.Toggle("f.flagPickupAudio", "Flag pickups", "Alert when a player picks up a flag (for example 'Rogue picked up flag').", false, "Flag events"),
            Page.Toggle("f.flagDropAudio", "Flag drops", "Alert when a flag is dropped.", false, "Flag events"),
            Page.Toggle("f.flagCaptureAudio", "Flag captures", "Alert when a flag is captured.", false, "Flag events"),
            Page.Toggle("f.flagReturnAudio", "Flag returns", "Alert when a flag is returned to base.", false, "Flag events"),
            Page.Toggle("f.flagToastsEnabled", "Show toast notifications", "Display visual toasts for flag carriers (uses the proximity toast settings for appearance).", false, "Visual alerts"),
            Page.When("f.flagToastsEnabled", Page.Action("Test flag toasts", "Shows an enemy and a friendly flag carrier toast with your textures and colors, at the position real alerts use.", testToasts, false, "Visual alerts")),
            Page.Toggle("f.flagOnlyEnemyTeam", "Only enemy team events", "Only alert for enemy flag pickups and captures (recommended for less spam). Not available while 'Alert all flag actions' is on.", false, "Filtering"),
            Page.Toggle("f.flagChatEnabled", "Send chat messages", "Announce flag events in chat channels.", false, "Chat"),
            Page.When("f.flagToastsEnabled", Page.Toggle("t.rainbowBorder", "Rainbow border on toasts", "Animated rainbow border on toast notifications (shared with Proximity Alerts).", true, "Visual alerts")),
            Page.When("f.flagToastsEnabled", Page.Toggle("f.flagTeamBackgroundColors", "Team-based background colors", "Color-code the toast background: red marks an enemy flag carrier and green marks a friendly one, so you can tell which team picked up the flag without reading the toast.", true, "Visual alerts")),
            Page.When("f.flagTeamBackgroundColors", Page.Toggle("f.flagEnemyRedBackground", "Enemy team: red background", "Show a red transparent background when an enemy team member picks up the flag.", true, "Visual alerts")),
            Page.When("f.flagTeamBackgroundColors", Page.Toggle("f.flagFriendlyGreenBackground", "Friendly team: green background", "Show a green transparent background when a friendly team member picks up the flag.", true, "Visual alerts")),
            Page.When("f.flagTeamBackgroundColors", Page.Select("f.flagEnemyTexture", "Enemy team: background texture", "Texture pattern for enemy flag carrier toasts, combined with the red color.", TEXTURES, true, "Visual alerts")),
            Page.When("f.flagTeamBackgroundColors", Page.Select("f.flagFriendlyTexture", "Friendly team: background texture", "Texture pattern for friendly flag carrier toasts, combined with the green color.", TEXTURES, true, "Visual alerts")),
            Page.When("f.flagToastsEnabled", Page.Range("f.flagToasts.positionX", "Horizontal position", "0 is the center of the screen, negative is left, positive is right.", -600, 600, 10, true, "Visual alerts")),
            Page.When("f.flagToastsEnabled", Page.Range("f.flagToasts.positionY", "Vertical position", "0 is the top of the screen, negative is lower (recommended -200 to -400). Default -300, below the proximity alerts.", -800, 200, 10, true, "Visual alerts")),
            Page.When("!f.flagAllActions", Page.Toggle("f.flagOnlyFriendlyTeam", "Only friendly team events", "Only alert for friendly flag pickups and captures. Not available while 'Alert all flag actions' is on.", true, "Filtering")),
            Page.Toggle("f.flagAllActions", "Alert all flag actions", "Alert for every flag event (pickup, drop, capture, return) for both teams. Turning this on switches the team-specific filters off.", true, "Filtering"),
            Page.When("f.flagChatEnabled", Page.Text("f.flagChatText", "Chat message template", "Placeholders: #class# is the enemy class name, #player# is the player name, #action# is the action (picked up flag, captured flag, and so on). Example: [#class#] #player# #action#!", true, "Chat")),
            Page.When("f.flagChatEnabled", Page.Select("f.flagChatChannel", "Chat channel", "Which channel to send flag alerts to.", CHANNELS, true, "Chat")),
            Page.Action("Show performance metrics", "Display processing time, cache hit rate and other performance data.", function()
                local active = flags()
                if active then
                    active:PrintMetrics()
                else
                    SoundAlerter:Print("|cffFF0000Error: FlagAlerts module not loaded|r")
                end
            end, true, "Performance"),
            Page.Action("Reset metrics", "Clear performance tracking data.", function()
                local active = flags()
                if active then
                    active:ResetMetrics()
                else
                    SoundAlerter:Print("|cffFF0000Error: FlagAlerts module not loaded|r")
                end
            end, true, "Performance"),
        },
    })
    local options = Page.Options(spec, "Battleground Alerts", "Interface\\Icons\\INV_BannerPVP_02", "Track battlefield objectives: flag pickups, captures, base assaults, and more.", 2.7)
    return Page.Guard(options, "Battleground Alerts", "FlagAlerts", flags)
end
