local SoundAlerter = SoundAlerter
local Rail = SA_OptionsRail

local ICONS = {
    overview = "Interface\\Icons\\INV_Misc_Note_01",
    general = "Interface\\Icons\\INV_Misc_Gear_01",
    energy = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate",
    rage = "Interface\\Icons\\Ability_Warrior_Rampage",
    health = "Interface\\Icons\\Spell_Holy_FlashHeal",
    mana = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    combo = "Interface\\Icons\\Ability_Rogue_SliceDice",
    player = "Interface\\Icons\\Spell_Arcane_Blast",
    target = "Interface\\Icons\\Ability_Marksmanship",
    focus = "Interface\\Icons\\Ability_Hunter_MarkedForDeath",
    where = "Interface\\Icons\\INV_Misc_Map_01",
    alert = "Interface\\Icons\\INV_Misc_Bell_01",
    look = "Interface\\Icons\\INV_Misc_Spyglass_02",
    position = "Interface\\Icons\\INV_Misc_Compass_01",
    click = "Interface\\Icons\\Ability_Marksmanship",
    flag = "Interface\\Icons\\INV_BannerPVP_01",
    filter = "Interface\\Icons\\INV_Misc_Spyglass_03",
    chat = "Interface\\Icons\\INV_Letter_15",
    perf = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    appearance = "Interface\\Icons\\INV_Misc_Spyglass_02",
}

local FEED_UNITS = { "player", "target", "focus", "party1", "party2", "party3", "party4" }
local PREVIEW_WIDTH = 260
local CAST_PREVIEW_MAX = 360

local function profile()
    return SoundAlerter.db1 and SoundAlerter.db1.profile or {}
end

local function description(order, text)
    return {
        type = 'description',
        name = text,
        fontSize = "medium",
        width = "full",
        order = order,
    }
end

local function addPreview(group, getText)
    group.args.livePreview = description(0.1, getText)
    return group
end

local function addSummary(options, getText)
    options.args.summary = description(1.7, getText)
end

local function flagSettings()
    return SoundAlerter.FlagAlerts and SoundAlerter.FlagAlerts:GetSettings()
end

local function feedSettings()
    return SoundAlerter.CastFeed and SoundAlerter.CastFeed:GetSettings()
end

local function resourceSettings()
    return SoundAlerter.ResourceBar and SoundAlerter.ResourceBar:GetSettings()
end

local function castingSettings()
    return SoundAlerter.CastingBars and SoundAlerter.CastingBars:GetSettings()
end

local function colorOf(settings, key, fallback)
    local c = settings and settings[key]
    if c then return c.r, c.g, c.b end
    return fallback[1], fallback[2], fallback[3]
end

local function resourcePreview(prefix, fallback, heightKey)
    return function()
        local s = resourceSettings()
        if not s then return "" end
        local r, g, b = colorOf(s, prefix .. "Color", fallback)
        local scale = s[prefix .. "Scale"] or 1
        local height = heightKey and s[heightKey] or 14
        return "|cff8a93a3Live preview|r\n" .. Rail.Bar(PREVIEW_WIDTH * scale / 2, height, 0.7, r, g, b)
    end
end

local function comboPreview()
    local s = resourceSettings()
    if not s then return "" end
    local size = math.floor(16 * (s.comboScale or 1))
    local ar, ag, ab = colorOf(s, "comboActiveColor", { 1, 0.8, 0 })
    local mr, mg, mb = colorOf(s, "comboMaxColor", { 1, 0.2, 0.2 })
    local idle = { 0.16, 0.18, 0.22 }
    local dots = Rail.Dots(5, 4, size, { ar, ag, ab }, idle)
    local full = Rail.Dots(5, 5, size, { mr, mg, mb }, idle)
    return "|cff8a93a3Live preview, 4 points and at maximum|r\n" .. dots .. "\n" .. full
end

local function castingPreview(unit)
    return function()
        local s = castingSettings()
        local u = s and s[unit]
        if not u then return "" end
        local width = math.min(u.width or 250, CAST_PREVIEW_MAX) * 0.8
        local height = (u.height or 20) * 0.8
        local note = u.orientation == "vertical" and "  |cff8a93a3vertical bars preview as horizontal|r" or ""
        local fill = (u.fillDirection == "left" or u.fillDirection == "up") and "fills from the far side" or "fills from the near side"
        return "|cff8a93a3Live preview, " .. fill .. "|r" .. note .. "\n" .. Rail.Bar(width, height, 0.55, 1, 0.82, 0.29)
    end
end

function SoundAlerter:RailResourceBars(options)
    local args = options.args
    addSummary(options, function()
        local s = resourceSettings()
        if not s then return "" end
        return Rail.Status("Bars shown", {
            { "Energy", s.energyEnabled }, { "Rage", s.rageEnabled }, { "Health", s.healthEnabled },
            { "Mana", s.manaEnabled }, { "Combo points", s.comboEnabled },
        }) .. "\n" .. Rail.Status("Positions", { { "unlocked, drag to move", not s.locked } }, "locked")
    end)
    addPreview(args.energyGroup, resourcePreview("energy", { 0.9, 0.85, 0.2 }))
    addPreview(args.rageGroup, resourcePreview("rage", { 0.85, 0.26, 0.18 }))
    addPreview(args.healthGroup, resourcePreview("health", { 0.25, 0.8, 0.4 }, "healthHeight"))
    addPreview(args.manaGroup, resourcePreview("mana", { 0.25, 0.5, 0.88 }))
    addPreview(args.comboGroup, comboPreview)
    return Rail.Tree(options, {
        { key = "generalGroup", promote = "generalGroup", name = "General", icon = ICONS.general, order = 2 },
        { key = "energyGroup", promote = "energyGroup", name = "Energy bar", icon = ICONS.energy, order = 3 },
        { key = "rageGroup", promote = "rageGroup", name = "Rage bar", icon = ICONS.rage, order = 4 },
        { key = "healthGroup", promote = "healthGroup", name = "Health bar", icon = ICONS.health, order = 5 },
        { key = "manaGroup", promote = "manaGroup", name = "Mana bar", icon = ICONS.mana, order = 6 },
        { key = "comboGroup", promote = "comboGroup", name = "Combo points", icon = ICONS.combo, order = 7 },
    })
end

function SoundAlerter:RailCastingBars(options)
    local args = options.args
    addSummary(options, function()
        local s = castingSettings()
        if not s then return "" end
        return Rail.Status("Bars shown", {
            { "Player", s.player and s.player.enabled }, { "Target", s.target and s.target.enabled }, { "Focus", s.focus and s.focus.enabled },
        }) .. "\n" .. Rail.Status("Positions", { { "unlocked, drag to move", not s.locked } }, "locked")
    end)
    addPreview(args.playerGroup, castingPreview("player"))
    addPreview(args.targetGroup, castingPreview("target"))
    addPreview(args.focusGroup, castingPreview("focus"))
    return Rail.Tree(options, {
        { key = "generalGroup", promote = "generalGroup", name = "General", icon = ICONS.general, order = 2 },
        { key = "playerGroup", promote = "playerGroup", name = "Player bar", icon = ICONS.player, order = 3 },
        { key = "targetGroup", promote = "targetGroup", name = "Target bar", icon = ICONS.target, order = 4 },
        { key = "focusGroup", promote = "focusGroup", name = "Focus bar", icon = ICONS.focus, order = 5 },
    })
end

local function toastPreview()
    local s = profile()
    return "|cff8a93a3Live preview|r\n" ..
        "|cffffd100Close|r  |cffe0e4ec Rogue|r\n" ..
        "|cff8a93a3Group of 3  ·  12 yards|r\n" ..
        "|TInterface\\Icons\\Ability_Stealth:24|t |TInterface\\Icons\\Ability_Rogue_Sprint:24|t |TInterface\\Icons\\Spell_Shadow_ShadowWordDominate:24|t"
end

function SoundAlerter:RailProximity(options)
    local args = options.args
    addSummary(options, function()
        local s = profile()
        return Rail.Status("Proximity alerts", { { "on", s.proximityEnabled } }, "off") .. "\n" .. Rail.Status("Active in", {
            { "World PvP", s.proximityWorld }, { "Battlegrounds", s.proximityBattleground },
            { "Arena", s.proximityArena }, { "Sanctuary", s.proximitySanctuary },
        })
    end)
    addPreview(args.toastAppearance, toastPreview)
    return Rail.Tree(options, {
        { key = "basicSetup", promote = "basicSetup", name = "Where it works", icon = ICONS.where, order = 2 },
        { key = "notificationMethods", promote = "notificationMethods", name = "How it alerts", icon = ICONS.alert, order = 3 },
        { key = "toastAppearance", promote = "toastAppearance", name = "Toast look", icon = ICONS.look, order = 4 },
        { key = "toastPosition", promote = "toastPosition", name = "Position and test", icon = ICONS.position, order = 5 },
        { key = "clickInteractions", promote = "clickInteractions", name = "Clicks", icon = ICONS.click, order = 6 },
    })
end

function SoundAlerter:RailFlag(options)
    addSummary(options, function()
        local s = flagSettings()
        if not s then return "" end
        return Rail.Status("Battleground alerts", { { "on", s.battlegroundAlertsEnabled } }, "off") .. "\n" .. Rail.Status("Flag events", {
            { "Pickups", s.flagPickupAudio }, { "Drops", s.flagDropAudio },
            { "Captures", s.flagCaptureAudio }, { "Returns", s.flagReturnAudio },
        })
    end)
    return Rail.Tree(options, {
        { key = "enableGroup", promote = "enableGroup", name = "Basic setup", icon = ICONS.general, order = 2 },
        { key = "flagAlerts", promote = "flagAlerts", name = "Flag events", icon = ICONS.flag, order = 3 },
        { key = "toastIntegration", promote = "toastIntegration", name = "Toast look", icon = ICONS.look, order = 4 },
        { key = "filteringOptions", promote = "filteringOptions", name = "Filtering", icon = ICONS.filter, order = 5 },
        { key = "chatIntegration", promote = "chatIntegration", name = "Chat", icon = ICONS.chat, order = 6 },
        { key = "performanceSection", promote = "performanceSection", name = "Performance", icon = ICONS.perf, order = 7 },
    })
end

local CHAT_SAMPLE = {
    enemy = "Cutthroat", target = "Starmistx", spell = "[Polymorph]",
    interruptedspellname = "[Polymorph]", interruptedspell = "[Polymorph]",
}

local function chatPreviewText()
    local s = profile()
    local lines = {
        { "To enemy", s.enemychat },
        { "Enemy to friend", s.friendchat },
        { "Enemy to you", s.selfchat },
        { "Enemy cooldown", s.enemybuffchat },
        { "Defensive expired", s.auraRemovedChat },
        { "Cast start", s.castStartChat },
        { "You interrupt", s.InterruptEnemyText },
        { "You are interrupted", s.InterruptSelfText },
    }
    local out = { "|cff8a93a3What your channels will read|r" }
    for _, line in ipairs(lines) do
        local text = Rail.ExpandChat(line[2], CHAT_SAMPLE)
        if text ~= "" then
            out[#out + 1] = "|cff8a93a3" .. line[1] .. ":|r " .. text
        end
    end
    return table.concat(out, "\n")
end

local CHAT_EVENT_KEYS = {
    "stealthenemy", "prowlenemy", "blindenemy", "blindselffriend", "hexenemy", "hexselffriend", "fearenemy", "fearselffriend",
    "sapenemy", "bubbleenemy", "polyenemy", "vanishenemy", "trinketalert", "interruptenemy", "interruptself",
    "chatdownself", "chatdownfriend", "chatauraApplied", "chatauraRemoved", "chatcastStart",
}

function SoundAlerter:RailChat(options)
    addSummary(options, function()
        local s = profile()
        local groups = s.chatgroups or {}
        local on = 0
        for _, key in ipairs(CHAT_EVENT_KEYS) do
            if s[key] then on = on + 1 end
        end
        return Rail.Status("Sending to", {
            { "Say", groups.SAY }, { "Party", groups.PARTY }, { "Raid", groups.RAID }, { "Battleground", groups.BATTLEGROUND },
        }, groups.NONE and "nothing, chat alerts are off" or "your own chat only") .. "\n|cff8a93a3Announcing|r " .. on .. " of " .. #CHAT_EVENT_KEYS .. " events"
    end)
    options.args.livePreview = description(0.1, chatPreviewText)
    return Rail.Tree(options, {
        { key = "channels", name = "Channels", from = { "caonlyTF", "chatgroup" }, icon = ICONS.chat, order = 1 },
        { key = "events", name = "What to announce", from = { "spells", "stealthalerttextg", "prowlalerttextg", "vanishalerttextg" }, icon = ICONS.alert, order = 2 },
        { key = "texts", name = "Message text", from = { "livePreview", "general", "saptextfriendg", "trinketalerttextg", "InterruptTextg" }, icon = ICONS.look, order = 3 },
    })
end

function SoundAlerter:RailCastFeed(options)
    addSummary(options, function()
        local s = feedSettings()
        if not s then return "" end
        local items = {}
        for _, unit in ipairs(FEED_UNITS) do
            local row = s.rows and s.rows[unit]
            items[#items + 1] = { unit, row and row.enabled }
        end
        return Rail.Status("Cast feed", { { "on", s.enabled } }, "off") .. "\n" .. Rail.Status("Rows shown", items)
    end)
    local sections = {
        { key = "generalGroup", promote = "generalGroup", name = "General", icon = ICONS.general, order = 2 },
    }
    for index, unit in ipairs(FEED_UNITS) do
        local key = "row_" .. unit
        local row = options.args[key]
        if row then
            sections[#sections + 1] = { key = key, promote = key, name = row.name, icon = ICONS[unit] or ICONS.player, order = 2 + index }
        end
    end
    sections[#sections + 1] = { key = "appearanceGroup", promote = "appearanceGroup", name = "Appearance", icon = ICONS.appearance, order = 20 }
    return Rail.Tree(options, sections)
end
