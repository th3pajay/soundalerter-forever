local QuickStart = {}

local AMBER = "|cffFFAA00"
local WHITE = "|cffFFFFFF"
local RESET = "|r"

QuickStart.ZONES = {
    { key = "arena", label = "Arena", hint = "Including Solo Shuffle" },
    { key = "battleground", label = "Battleground", hint = "Large-scale PvP" },
    { key = "field", label = "World PvP", hint = "Open world" },
}

QuickStart.PRESETS = {
    { key = "arena", label = "Arena player", hint = "Arena on, target and focus only", zones = { arena = true }, scope = "myself" },
    { key = "battleground", label = "Battleground player", hint = "Battlegrounds on, all enemies in range", zones = { battleground = true }, scope = "enemyinrange" },
    { key = "everything", label = "Everything", hint = "Arena, battlegrounds and world PvP, target and focus", zones = { arena = true, battleground = true, field = true }, scope = "myself" },
}

QuickStart.CATEGORIES = {
    { key = "aruaApplied", label = "Enemy defensives and buffs", hint = "Divine Shield, Ice Block, Barkskin" },
    { key = "castStart", label = "Enemy spell casts", hint = "Polymorph, Fear and other casts as they start" },
    { key = "castSuccess", label = "Enemy cooldowns", hint = "Trinket, Blind, Cyclone and similar" },
    { key = "dSelfDebuff", label = "Crowd control on you", hint = "Sap, Poly, Fear on you: know when to trinket" },
    { key = "dEnemyDebuff", label = "Crowd control on enemies", hint = "When your CC lands" },
    { key = "interrupt", label = "Interrupts", hint = "Friendly spells that were interrupted" },
    { key = "chatalerts", label = "Chat messages", hint = "Alerts also appear in chat" },
}

QuickStart.STEPS = {
    { key = "style", label = "Style", title = "Pick your style", hint = "Sets the zones and who triggers alerts in one step. Anything you change afterwards shows as Custom." },
    { key = "hear", label = "Hear", title = "What do you want to hear?", hint = "Fine-tune single spells later on the Voice Alerts page." },
    { key = "hud", label = "HUD", title = "On-screen helpers", hint = "Optional displays. Each has its own page for size, position and style." },
    { key = "aware", label = "Aware", title = "Awareness", hint = "Extra warnings beyond spell alerts." },
    { key = "party", label = "Party", title = "Share with your party", hint = "Experimental, off by default. Sends the enemies you see to your group over the addon channel, and nothing else." },
    { key = "done", label = "Done", title = "You're set", hint = "Type /sa anytime to reopen the menu. Run this setup again from the Quick Start page." },
}

local CAST_UNITS = { "player", "target", "focus" }
local RESOURCE_BARS = { "energyEnabled", "rageEnabled", "healthEnabled", "manaEnabled", "comboEnabled" }
local PROXIMITY_ZONES = { { "arena", "proximityArena" }, { "battleground", "proximityBattleground" }, { "field", "proximityWorld" } }

local function anyTrue(source, keys)
    for _, key in ipairs(keys) do
        if source[key] then return true end
    end
    return false
end

local function setAll(source, keys, value)
    for _, key in ipairs(keys) do source[key] = value end
end

local function hasIcons(profile)
    local tracker = profile.spellTracker
    return tracker and tracker.icons and #tracker.icons > 0 or false
end

local function supported(_, env)
    return env and env.supported and true or false
end

local function enableProximityZones(profile)
    for _, pair in ipairs(PROXIMITY_ZONES) do
        if profile[pair[2]] then return end
    end
    local zoned = false
    for _, pair in ipairs(PROXIMITY_ZONES) do
        if profile[pair[1]] then
            profile[pair[2]] = true
            zoned = true
        end
    end
    if not zoned then profile.proximityWorld = true end
end

QuickStart.ITEMS = {
    hud = {
        {
            key = "castbars", label = "Casting Bars", hint = "Your, target and focus cast bars",
            get = function(profile)
                for _, unit in ipairs(CAST_UNITS) do
                    if profile.castingBars[unit].enabled then return true end
                end
                return false
            end,
            set = function(profile, value)
                for _, unit in ipairs(CAST_UNITS) do profile.castingBars[unit].enabled = value end
            end,
        },
        {
            key = "tracker", label = "Spell Tracker", hint = "Icons for buffs, debuffs and cooldowns", available = hasIcons,
            get = function(profile)
                for _, icon in ipairs(profile.spellTracker.icons) do
                    if icon.enabled then return true end
                end
                return false
            end,
            set = function(profile, value)
                for _, icon in ipairs(profile.spellTracker.icons) do icon.enabled = value end
            end,
        },
        {
            key = "castfeed", label = "Cast Feed", hint = "A scrolling log of casts",
            get = function(profile) return profile.castFeed.enabled and true or false end,
            set = function(profile, value) profile.castFeed.enabled = value end,
        },
        {
            key = "resource", label = "Resource Bar", hint = "Health, mana, energy, rage and combo points",
            get = function(profile) return anyTrue(profile.resourceBar, RESOURCE_BARS) end,
            set = function(profile, value) setAll(profile.resourceBar, RESOURCE_BARS, value) end,
        },
    },
    aware = {
        {
            key = "proximity", label = "Proximity toasts", hint = "A toast when enemies come near",
            get = function(profile) return profile.proximityEnabled and true or false end,
            set = function(profile, value)
                profile.proximityEnabled = value
                if value then enableProximityZones(profile) end
            end,
        },
        {
            key = "flags", label = "Battleground flag alerts", hint = "Flag and objective voice alerts",
            get = function(profile) return profile.battlegroundAlertsEnabled and true or false end,
            set = function(profile, value) profile.battlegroundAlertsEnabled = value end,
        },
        {
            key = "stealth", label = "Stealth alert", hint = "Voice when a rogue or druid goes into stealth",
            get = function(profile) return profile.stealthenemy and true or false end,
            set = function(profile, value) profile.stealthenemy = value end,
        },
        {
            key = "sightings", label = "Global sightings", hint = "Experimental: enemies other users report show on your world map", available = supported,
            get = function(profile) return profile.globalSightings and true or false end,
            set = function(profile, value) profile.globalSightings = value end,
        },
    },
    party = {
        {
            key = "party", label = "Party sharing", hint = "Share what you see with your party and hear what they see", available = supported,
            get = function(profile) return profile.shareAlertsSend and profile.shareAlertsReceive and true or false end,
            set = function(profile, value)
                profile.shareAlertsSend = value
                profile.shareAlertsReceive = value
            end,
        },
    },
}

function QuickStart.Items(stepKey, profile, env)
    local items = {}
    for _, item in ipairs(QuickStart.ITEMS[stepKey] or {}) do
        if not item.available or item.available(profile, env) then items[#items + 1] = item end
    end
    return items
end

function QuickStart.ActiveSteps(profile, env)
    local steps = {}
    for _, step in ipairs(QuickStart.STEPS) do
        if not QuickStart.ITEMS[step.key] or #QuickStart.Items(step.key, profile, env) > 0 then
            steps[#steps + 1] = step
        end
    end
    return steps
end

function QuickStart.Seed(global, existing)
    if global.quickStartDone == nil then global.quickStartDone = existing and true or false end
end

function QuickStart.NeedsSetup(global)
    return global.quickStartDone == false
end

function QuickStart.Scope(profile)
    return profile.enemyinrange and "enemyinrange" or "myself"
end

function QuickStart.SetScope(profile, value)
    profile.myself = value == "myself"
    profile.enemyinrange = value == "enemyinrange"
end

function QuickStart.Heard(profile, key)
    return not profile[key]
end

function QuickStart.SetHeard(profile, key, heard)
    profile[key] = not heard
end

function QuickStart.ActivePreset(profile)
    for _, preset in ipairs(QuickStart.PRESETS) do
        local matches = QuickStart.Scope(profile) == preset.scope
        for _, zone in ipairs(QuickStart.ZONES) do
            if (profile[zone.key] == true) ~= (preset.zones[zone.key] == true) then
                matches = false
            end
        end
        if matches then
            return preset
        end
    end
    return nil
end

function QuickStart.ApplyPreset(profile, key)
    for _, preset in ipairs(QuickStart.PRESETS) do
        if preset.key == key then
            for _, zone in ipairs(QuickStart.ZONES) do
                profile[zone.key] = preset.zones[zone.key] == true
            end
            QuickStart.SetScope(profile, preset.scope)
            return true
        end
    end
    return false
end

local function enabledLabels(profile, stepKey, env)
    local labels = {}
    for _, item in ipairs(QuickStart.Items(stepKey, profile, env)) do
        if item.get(profile) then labels[#labels + 1] = item.label end
    end
    return #labels > 0 and table.concat(labels, ", ") or "none"
end

function QuickStart.SummaryRows(profile, volumePercent, env)
    local zones = {}
    for _, zone in ipairs(QuickStart.ZONES) do
        if profile[zone.key] then zones[#zones + 1] = zone.label end
    end
    local heard = 0
    for _, category in ipairs(QuickStart.CATEGORIES) do
        if QuickStart.Heard(profile, category.key) then heard = heard + 1 end
    end
    local rows = {
        { "Active in", #zones > 0 and (WHITE .. table.concat(zones, ", ") .. RESET) or (AMBER .. "nowhere yet" .. RESET) },
        { "Who triggers alerts", QuickStart.Scope(profile) == "myself" and "Target and focus" or "All enemies in range" },
        { "Volume", volumePercent .. "%" },
        { "Alert types", heard .. " of " .. #QuickStart.CATEGORIES .. " on" },
        { "On-screen", enabledLabels(profile, "hud", env) },
        { "Awareness", enabledLabels(profile, "aware", env) },
    }
    if #QuickStart.Items("party", profile, env) > 0 then
        rows[#rows + 1] = { "Party sharing", QuickStart.ITEMS.party[1].get(profile) and "on" or "off" }
    end
    return rows
end

SA_QuickStart = QuickStart
