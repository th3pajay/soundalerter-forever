local SoundAlerter = SoundAlerter

local ZONES = {
    { "proximityWorld", "World PvP" }, { "proximityBattleground", "Battlegrounds" },
    { "proximityArena", "Arena" }, { "proximitySanctuary", "Sanctuary" },
}
local BANDS = {
    { "Close", "Close (about 10 yd)" }, { "Nearby", "Nearby (about 28 yd)" },
    { "Medium", "Medium (about 35 yd)" }, { "Detected", "Detected (any nameplate)" },
}
local TOAST_STYLES = {
    { "intel", "Intel card" }, { "threat", "Threat card" },
}
local SIDE_EFFECTS = {
    overrideNameplateRange = "ApplyNameplateRange",
    nameplateRange = "ApplyNameplateRange",
    scoreboardClassFallback = "UpdateScoreboardTracking",
    showTotemPlates = "ApplyTotemPlates",
}
local SAMPLES = {
    { "Shadowstep", "Rogue", "Group of 3 - 12 yd", { 1, 0.96, 0.41 }, "Interface\\Icons\\Ability_Stealth", "ROGUE", "Close", 3 },
    { "Moonfang", "Druid", "Nearby - 28 yd", { 1, 0.49, 0.04 }, "Interface\\Icons\\Ability_Druid_CatForm", "DRUID", "Nearby", 1 },
}

local function profile()
    return SoundAlerter.db1 and SoundAlerter.db1.profile
end

local function toasts()
    return SoundAlerter.ProximityToasts
end

local function view()
    local current = profile()
    if not current then return nil end
    local active = toasts()
    return { enabled = current.proximityEnabled, p = current, t = active and active:GetSettings() }
end

local function write(key, value)
    local current = profile()
    if not current then return end
    if key == "enabled" then
        current.proximityEnabled = value
        if SoundAlerter.UpdateMinimapButtonIcon then SoundAlerter:UpdateMinimapButtonIcon() end
        return
    end
    local scope, name = key:match("^(%a+)%.(.+)$")
    if scope == "p" then
        current[name] = value
        local effect = SIDE_EFFECTS[name]
        if effect and SoundAlerter[effect] then SoundAlerter[effect](SoundAlerter) end
    elseif scope == "t" then
        local active = toasts()
        if not active then return end
        active:SetSetting(name, value)
        if name == "enabled" and not value then active:OnDisable() end
        if name == "positionX" or name == "positionY" then active:UpdateLayout() end
    end
end

local ProximityPreview = { height = 100 }

function ProximityPreview.build(stage)
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

function ProximityPreview.update(state, settings)
    if not state then return end
    local Page = SoundAlerter.Page
    local t = settings.t or {}
    local classColors = t.useClassColors
    state.note:SetText(t.enabled and "" or "Toasts are off. Alerts come through audio only.")
    for index, toast in ipairs(state.toasts) do
        local sample = SAMPLES[index]
        local color = sample[4]
        local sub = sample[2] .. " - " .. sample[3]
        if t.toastStyle == "threat" then
            local level, _, why = SA_ToastStyle.Threat(sample[6], sample[7], sample[8])
            sub = level .. " THREAT - " .. why
        end
        Page.Toast.Update(toast, {
            shown = t.enabled and index <= math.max(1, t.maxConcurrent or 1),
            name = t.showPlayerName and sample[1] or (sample[2] .. " nearby"),
            sub = sub,
            nameColor = classColors and color or nil,
            background = classColors and { color[1] * 0.28, color[2] * 0.28, color[3] * 0.28, 0.95 } or nil,
            showIcon = t.showAuraIcons,
            icon = sample[5],
            rainbow = t.rainbowBorder,
        })
    end
end

local function summary(settings)
    local Page = SoundAlerter.Page
    local zones = {}
    for _, zone in ipairs(ZONES) do
        if settings.p[zone[1]] then zones[#zones + 1] = zone[2] end
    end
    local t = settings.t or {}
    return Page.Summary(settings,
        #zones > 0 and table.concat(zones, ", ") or "no zones",
        "toasts " .. (t.enabled and "on" or "off"),
        "chat " .. (settings.p.proximityChat and "on" or "off"))
end

function SoundAlerter:BuildProximityOptions()
    local Page = SoundAlerter.Page
    local spec = Page.Spec({
        title = "Proximity Alerts",
        icon = "Interface\\Icons\\Ability_Tracking",
        blurb = "Detects hostile players nearby, useful for spotting ganks and stealthed Rogues and Druids as soon as they act. Voice alerts are set on the Voice Alerts page.",
        get = view,
        set = write,
        defaults = function()
            return { p = dbDefaults.profile, t = dbDefaults.profile.proximityToasts }
        end,
        summary = summary,
        preview = ProximityPreview,
        rows = {
            Page.Toggle("p.proximityWorld", "World PvP", "Enable proximity alerts in open world PvP zones.", false, "Where it works"),
            Page.Toggle("p.proximityBattleground", "Battlegrounds", "Enable proximity alerts in battlegrounds (useful for detecting flag carriers and node defenders).", false, "Where it works"),
            Page.Toggle("p.proximityArena", "Arena", "Enable proximity alerts in arenas (less useful due to small arena size).", false, "Where it works"),
            Page.Toggle("p.proximityChat", "Send chat messages", "Announce proximity detections in chat (useful for alerting teammates).", false, "How it alerts"),
            Page.Toggle("t.enabled", "Show toast notifications", "Show visual pop-up toasts when enemies are detected nearby. The toast options below apply when this is on.", false, "How it alerts"),
            Page.When("t.enabled", Page.Action("Test toast", "Show a test toast to preview the current settings (position, appearance, duration).", function()
                local active = toasts()
                if active then active:ShowToast("TestEnemy", "ROGUE", "Close", nil, 60, nil, nil, nil, 3) end
            end, false, "How it alerts")),
            Page.Toggle("p.proximitySanctuary", "Sanctuary", "Enable proximity alerts in sanctuary zones (e.g. Moonglade) where PvP-flagged enemies can still attack you despite guards.", true, "Where it works"),
            Page.Range("p.proximityCooldown", "Cooldown duration", "Time before the same player can trigger another proximity alert. Prevents spam while still alerting to threats.", 5, 120, 5, true, "Detection", " s"),
            Page.Select("p.proximityMaxBand", "Alert only within", "Only alert for enemies inside this band. Enemies are rechecked every second so they alert when they come in.", BANDS, true, "Detection"),
            Page.Toggle("p.overrideNameplateRange", "Increase nameplate distance", "Overrides your client's nameplate render distance to extend proximity detection range. Affects all nameplates (allies, NPCs, everything), not just enemies.", true, "Detection"),
            Page.When("p.overrideNameplateRange", Page.Range("p.nameplateRange", "Nameplate distance", "Distance to render nameplates. About 100 yards is the practical ceiling: the client has no data on units beyond the server's own tracking range.", 20, 100, 5, true, "Detection", " yd")),
            Page.Toggle("p.proximityAllyVision", "Alert on enemies your group targets", "Also alert for enemy players your party or raid members are targeting, even far outside your own nameplate range. They show as Spotted with no distance. Whether the game shares those units with the addon is still being tested: turn on Debug Mode and run /sa probe.", true, "Detection"),
            Page.When("p.proximityChat", Page.Text("p.proximityChatText", "Chat message template", "Customize the chat message. Placeholders: #class# is the enemy class name, #player# is the enemy player name. Example: [#class#] #player# detected nearby!", true, "How it alerts")),
            Page.When("t.enabled", Page.Range("t.displayDuration", "Display duration", "How long the toast remains visible on screen.", 2, 8, 0.5, true, "How it alerts", " s")),
            Page.When("t.enabled", Page.Range("t.maxConcurrent", "Max concurrent toasts", "Maximum number of toasts to show at once (older toasts fade out early if the limit is exceeded).", 1, 5, 1, true, "How it alerts")),
            Page.When("t.enabled", Page.Select("t.toastStyle", "Toast style", "Intel card shows level, distance with a meter and group size. Threat card shows how worried to be and why: stealth classes, how close, and group size.", TOAST_STYLES, false, "Toast look")),
            Page.When("t.enabled", Page.Toggle("t.showPlayerName", "Show player name", "Display the enemy player's name in the toast.", true, "Toast look")),
            Page.When("t.enabled", Page.Toggle("t.showAuraIcons", "Show buff and debuff icons", "Display up to 3 active buff or debuff icons on the toast (defensive cooldowns, mount, existing debuffs).", true, "Toast look")),
            Page.When("t.enabled", Page.Toggle("t.useClassColors", "Use class colors", "Color the toast background by enemy class (red for Warrior, purple for Warlock).", true, "Toast look")),
            Page.When("t.enabled", Page.Toggle("t.rainbowBorder", "Rainbow border animation", "Smooth, slow rainbow color transitions on the toast border.", true, "Toast look")),
            Page.When("t.enabled", Page.Range("t.positionX", "Horizontal position", "0 is the center of the screen, negative is left, positive is right.", -500, 500, 10, true, "Toast position")),
            Page.When("t.enabled", Page.Range("t.positionY", "Vertical position", "0 is the center, negative is down from the top, positive is up from the bottom.", -500, 500, 10, true, "Toast position")),
            Page.Toggle("p.enemyTargetsYou", "Enemy targets you", "Alert when a nearby enemy starts targeting you.", true, "Enemy awareness"),
            Page.When("p.enemyTargetsYou", Page.Range("p.enemyTargetsYouCooldown", "Targeting alert cooldown", "Delay before the same enemy can alert again.", 2, 30, 1, true, "Enemy awareness", " s")),
            Page.Toggle("p.enemyCastingAtYou", "Enemy casts while targeting you", "Alert when an enemy targeting you starts a cast.", true, "Enemy awareness"),
            Page.Toggle("p.quietOnTaxi", "Silent on flight paths", "Stay silent while on a flight path.", true, "Quiet rules"),
            Page.Toggle("p.quietWhenDead", "Silent while dead", "Stay silent while dead.", true, "Quiet rules"),
            Page.Toggle("p.quietOutsidePvPFlag", "Silent when not PvP flagged", "Stay silent while not PvP flagged.", true, "Quiet rules"),
            Page.Range("p.snoozeMinutes", "Snooze length", "Default length of /sa snooze.", 1, 60, 1, true, "Quiet rules", " min"),
            Page.Action("Snooze now", "Silence these alerts for a while.", function() SoundAlerter:Snooze() end, true, "Quiet rules"),
            Page.Action("Cancel snooze", "End the snooze early.", function() SoundAlerter:Unsnooze() end, true, "Quiet rules"),
            Page.Toggle("p.scoreboardClassFallback", "Use battleground scoreboard for class", "In battlegrounds, read a hidden class from the scoreboard.", true, "Identification"),
            Page.Toggle("p.showTotemPlates", "Show totem nameplates", "Show totems as nameplates. Your game settings are restored when off.", true, "Identification"),
            Page.Toggle("p.watchlistEnabled", "Enable watchlist", "Alert when a specific enemy player or guild shows up nearby. Also: /sa watch [guild] name.", true, "Watchlist"),
            Page.When("p.watchlistEnabled", Page.Text("p.watchNamesText", "Watched players", "Separate entries with commas.", true, "Watchlist", 4)),
            Page.When("p.watchlistEnabled", Page.Text("p.watchGuildsText", "Watched guilds", "Separate entries with commas.", true, "Watchlist", 4)),
            Page.When("t.enabled", Page.Toggle("t.clickEnabled", "Enable click interaction", "Allow clicking toast notifications to interact with enemies (world PvP only). Enable this to unlock the click options.", true, "Clicks")),
            Page.When("t.clickEnabled", Page.Toggle("t.enableClickToTarget", "Left-click: target enemy", "Left-click on a toast to target the detected enemy player.", true, "Clicks")),
            Page.When("t.clickEnabled", Page.Toggle("t.enableFocusTarget", "Shift+click: set focus target", "Hold Shift and click a toast to target the enemy and set it as your focus (useful for tracking stealthers).", true, "Clicks")),
        },
    })
    local options = Page.Options(spec, "Proximity Alerts", "Interface\\Icons\\Ability_Tracking", "Detect enemy stealthed players nearby and get voice alerts. Perfect for spotting Rogues and Druids in stealth.", 2.5)
    return Page.Guard(options, "Proximity Alerts", "ProximityToasts", toasts)
end
