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

local function addSummary(options, getText)
    options.args.summary = description(1.7, getText)
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
        { key = "channels", name = "Channels", from = { "caonlyTF", "chatgroup" }, icon = ICONS.chat, order = 2 },
        { key = "events", name = "What to announce", from = { "spells", "stealthalerttextg", "prowlalerttextg", "vanishalerttextg" }, icon = ICONS.alert, order = 3 },
        { key = "texts", name = "Message text", from = { "livePreview", "general", "saptextfriendg", "trinketalerttextg", "InterruptTextg" }, icon = ICONS.look, order = 4 },
    })
end
