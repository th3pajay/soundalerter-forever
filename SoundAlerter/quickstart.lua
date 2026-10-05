local QuickStart = {}

local GOLD = "|cffFFD700"
local AMBER = "|cffFFAA00"
local GREY = "|cff888888"
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

QuickStart.GUIDE = {
    { key = "Spells", label = "Voice Alerts", hint = "Choose which spells you hear" },
    { key = "ProximityAlerts", label = "Proximity Alerts", hint = "Toasts when enemies come near" },
    { key = "BattlegroundAlerts", label = "Battleground Alerts", hint = "Flag and objective alerts" },
    { key = "ResourceBar", label = "Resource Management", hint = "Health, mana, energy and rage bars" },
    { key = "CastingBars", label = "Casting Bars", hint = "Your cast, target and focus bars" },
    { key = "CastFeed", label = "Cast Feed", hint = "A log of enemy casts" },
    { key = "SpellTracker", label = "Spell Tracker", hint = "Icons for buffs, debuffs and cooldowns" },
    { key = "Statistics", label = "Statistics", hint = "What triggered your alerts" },
    { key = "FindSpell", label = "Developer Tools", hint = "Find spell IDs, debug" },
    { key = "custom", label = "Advanced", hint = "Custom alerts" },
}

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

function QuickStart.PresetLabel(preset, active)
    if active then
        return GOLD .. preset.label .. RESET .. GREY .. " (active)" .. RESET
    end
    return WHITE .. preset.label .. RESET
end

function QuickStart.PresetStatus(profile)
    local preset = QuickStart.ActivePreset(profile)
    if preset then
        return GREY .. "Your setup matches the " .. RESET .. WHITE .. preset.label .. RESET .. GREY .. " style." .. RESET
    end
    return GREY .. "Custom setup: adjusted below." .. RESET
end

function QuickStart.Summary(profile, volumePercent)
    local zones = {}
    for _, zone in ipairs(QuickStart.ZONES) do
        if profile[zone.key] then
            zones[#zones + 1] = zone.label
        end
    end

    local heard = 0
    for _, category in ipairs(QuickStart.CATEGORIES) do
        if QuickStart.Heard(profile, category.key) then
            heard = heard + 1
        end
    end

    local zoneText = #zones > 0 and (WHITE .. table.concat(zones, ", ") .. RESET) or (AMBER .. "nowhere yet" .. RESET)
    local scopeText = QuickStart.Scope(profile) == "myself" and "Target and focus" or "All enemies in range"

    return "Active in " .. zoneText ..
        "     Scope " .. WHITE .. scopeText .. RESET ..
        "     Volume " .. WHITE .. volumePercent .. "%" .. RESET ..
        "     " .. WHITE .. heard .. RESET .. " of " .. #QuickStart.CATEGORIES .. " alert types on"
end

function QuickStart.GuideLabel(entry)
    return GOLD .. entry.label .. RESET .. "  " .. GREY .. entry.hint .. RESET
end

SA_QuickStart = QuickStart
