local SoundAlerter = SoundAlerter

local EVENTS = {
    { "flagPickupAudio", "Pickups", "PICKUP", "Flag pickups", "A player picks up a flag." },
    { "flagDropAudio", "Drops", "DROP", "Flag drops", "A flag is dropped." },
    { "flagCaptureAudio", "Captures", "CAPTURE", "Flag captures", "A flag is captured." },
    { "flagReturnAudio", "Returns", "RETURN", "Flag returns", "A flag is returned to base." },
}
local TEAMS = { { "enemy", "Enemy team" }, { "friendly", "Friendly team" }, { "both", "Both teams" } }
local PREVIEW_CLASSES = {
    { "ROGUE", "Rogue" }, { "WARRIOR", "Warrior" }, { "MAGE", "Mage" }, { "PRIEST", "Priest" }, { "HUNTER", "Hunter" },
    { "DRUID", "Druid" }, { "PALADIN", "Paladin" }, { "WARLOCK", "Warlock" }, { "SHAMAN", "Shaman" },
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

local function TeamOf(settings)
    if settings.flagOnlyEnemyTeam then return "enemy" end
    if settings.flagOnlyFriendlyTeam then return "friendly" end
    return "both"
end

local function view()
    local active = flags()
    if not active then return nil end
    local settings = active:GetSettings()
    local shared = toasts()
    return {
        enabled = settings.battlegroundAlertsEnabled, f = settings, t = shared and shared:GetSettings(),
        team = TeamOf(settings), previewClass = active.previewClass or "ROGUE",
    }
end

local function write(key, value)
    local active = flags()
    if not active then return end
    if key == "enabled" then
        active:SetSetting("battlegroundAlertsEnabled", value)
        if SoundAlerter.UpdateMinimapButtonIcon then SoundAlerter:UpdateMinimapButtonIcon() end
        return
    end
    if key == "previewClass" then
        active.previewClass = value
        return
    end
    if key == "team" then
        active:SetSetting("flagOnlyEnemyTeam", value == "enemy")
        active:SetSetting("flagOnlyFriendlyTeam", value == "friendly")
        active:SetSetting("flagAllActions", value == "both")
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
    if name == "flagToasts.positionX" or name == "flagToasts.positionY" then
        active:UpdateFlagToastLayout()
    end
end

local function previewEvent(eventType)
    local active = flags()
    if active then active:Preview(eventType, active.previewClass or "ROGUE") end
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
            return { f = dbDefaults.profile, t = dbDefaults.profile.proximityToasts, team = TeamOf(dbDefaults.profile), previewClass = "ROGUE" }
        end,
        summary = summary,
        preview = FlagPreview,
        rows = {
            Page.Playable(Page.Toggle("f.flagPickupAudio", "Flag pickups", "A player picks up a flag.", false, "Flag events"), function() previewEvent("PICKUP") end),
            Page.Playable(Page.Toggle("f.flagDropAudio", "Flag drops", "A flag is dropped.", false, "Flag events"), function() previewEvent("DROP") end),
            Page.Playable(Page.Toggle("f.flagCaptureAudio", "Flag captures", "A flag is captured.", false, "Flag events"), function() previewEvent("CAPTURE") end),
            Page.Playable(Page.Toggle("f.flagReturnAudio", "Flag returns", "A flag is returned to base.", false, "Flag events"), function() previewEvent("RETURN") end),
            Page.Action("Play all", "Hear every flag event once, one after another, ignoring the switches.", function()
                local active = flags()
                if active then active:PreviewAll(active.previewClass or "ROGUE") end
            end, false, "Flag events"),
            Page.Select("previewClass", "Preview class", "The class voice the Play buttons use. Real alerts use the carrier's class. Not saved.", PREVIEW_CLASSES, false, "Flag events"),
            Page.Select("team", "Alert for", "Which team's flag events you hear.", TEAMS, false, "Flag events"),
            Page.Playable(Page.Toggle("f.flagToastsEnabled", "Show toast notifications", "A toast for each flag carrier, styled like Proximity Alerts.", false, "Visual alerts"), testToasts),
            Page.Toggle("f.flagChatEnabled", "Send chat messages", "Announce flag events in chat channels.", false, "Chat"),
            Page.When("f.flagToastsEnabled", Page.Toggle("t.rainbowBorder", "Rainbow border on toasts", "Animated rainbow border on toast notifications (shared with Proximity Alerts).", true, "Visual alerts")),
            Page.When("f.flagToastsEnabled", Page.Toggle("f.flagTeamBackgroundColors", "Team-based background colors", "Color-code the toast background: red marks an enemy flag carrier and green marks a friendly one, so you can tell which team picked up the flag without reading the toast.", true, "Visual alerts")),
            Page.When("f.flagTeamBackgroundColors", Page.Toggle("f.flagEnemyRedBackground", "Enemy team: red background", "Show a red transparent background when an enemy team member picks up the flag.", true, "Visual alerts")),
            Page.When("f.flagTeamBackgroundColors", Page.Toggle("f.flagFriendlyGreenBackground", "Friendly team: green background", "Show a green transparent background when a friendly team member picks up the flag.", true, "Visual alerts")),
            Page.When("f.flagTeamBackgroundColors", Page.Select("f.flagEnemyTexture", "Enemy team: background texture", "Texture pattern for enemy flag carrier toasts, combined with the red color.", TEXTURES, true, "Visual alerts")),
            Page.When("f.flagTeamBackgroundColors", Page.Select("f.flagFriendlyTexture", "Friendly team: background texture", "Texture pattern for friendly flag carrier toasts, combined with the green color.", TEXTURES, true, "Visual alerts")),
            Page.When("f.flagToastsEnabled", Page.Range("f.flagToasts.positionX", "Horizontal position", "0 is the center of the screen, negative is left, positive is right.", -600, 600, 10, true, "Visual alerts")),
            Page.When("f.flagToastsEnabled", Page.Range("f.flagToasts.positionY", "Vertical position", "0 is the top of the screen, negative is lower (recommended -200 to -400). Default -300, below the proximity alerts.", -800, 200, 10, true, "Visual alerts")),
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
