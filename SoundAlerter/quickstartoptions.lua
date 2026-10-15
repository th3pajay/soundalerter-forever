local SoundAlerter = SoundAlerter
local QuickStart = SA_QuickStart

local ADDON_NAME = "SoundAlerter"
local TEST_SOUND = "trinket.mp3"

local function profile()
    return SoundAlerter.db1 and SoundAlerter.db1.profile
end

local function volume()
    return tonumber(GetCVar("Sound_MasterVolume")) or 1
end

local function view()
    local current = profile()
    if not current then return nil end
    local active = QuickStart.ActivePreset(current)
    local heard = {}
    for _, category in ipairs(QuickStart.CATEGORIES) do
        heard[category.key] = QuickStart.Heard(current, category.key)
    end
    return {
        p = current,
        qs = { style = active and active.key or "custom", scope = QuickStart.Scope(current), heard = heard },
        sound = { master = volume() },
    }
end

local function write(key, value)
    local current = profile()
    if not current then return end
    local scope, name = key:match("^(%a+)%.(.+)$")
    if scope == "p" then
        current[name] = value
    elseif scope == "sound" and name == "master" then
        SetCVar("Sound_MasterVolume", tostring(value))
    elseif key == "qs.style" then
        QuickStart.ApplyPreset(current, value)
    elseif key == "qs.scope" then
        QuickStart.SetScope(current, value)
    elseif key:match("^qs%.heard%.") then
        QuickStart.SetHeard(current, key:match("^qs%.heard%.(.+)$"), value)
    end
end

local function styleOptions()
    local options = {}
    for _, preset in ipairs(QuickStart.PRESETS) do options[#options + 1] = { preset.key, preset.label } end
    options[#options + 1] = { "custom", "Custom" }
    return options
end

local function summary(settings)
    return QuickStart.Summary(settings.p, math.floor(settings.sound.master * 100 + 0.5))
end

function SoundAlerter:BuildQuickStartOptions()
    local Page = SoundAlerter.Page
    local rows = {
        Page.Select("qs.style", "Pick your style", "Sets the zones and who triggers alerts in one step. Adjust anything below afterwards, and the style shows Custom.", styleOptions(), false, "Style"),
    }
    for _, zone in ipairs(QuickStart.ZONES) do
        rows[#rows + 1] = Page.Toggle("p." .. zone.key, zone.label, zone.hint, false, "Where should it be active?")
    end
    rows[#rows + 1] = Page.Select("qs.scope", "Who triggers alerts?", "Recommended: target and focus for Arena, all enemies for Battlegrounds.", {
        { "myself", "Target and focus only" }, { "enemyinrange", "All enemies in range" },
    }, false, "Who triggers alerts?")
    rows[#rows + 1] = Page.Range("sound.master", "Master volume", "Sets the game's master volume so sound alerts can be louder or softer.", 0, 1, 0.1, false, "Sound")
    rows[#rows + 1] = Page.Action("Play test sound", "Plays a short alert so you know the volume is right.", function()
        SoundAlerter:PlayVoice(profile().sapath .. TEST_SOUND)
    end, false, "Sound")
    for _, category in ipairs(QuickStart.CATEGORIES) do
        rows[#rows + 1] = Page.Toggle("qs.heard." .. category.key, category.label, category.hint .. ". Fine-tune single spells on the Voice Alerts page.", false, "What do you want to hear?")
    end
    for _, entry in ipairs(QuickStart.GUIDE) do
        rows[#rows + 1] = Page.Action(entry.label, entry.hint .. ". Opens that page.", function()
            LibStub("AceConfigDialog-3.0"):SelectGroup(ADDON_NAME, entry.key)
        end, true, "Open a page")
    end

    local spec = Page.Spec({
        title = "Quick Start",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        blurb = "Get arena-ready in 60 seconds: pick your style, check the sound, choose what you want to hear. Type /sa anytime to reopen this menu.",
        master = false,
        get = view,
        set = write,
        defaults = function() return { p = dbDefaults.profile } end,
        summary = summary,
        rows = rows,
    })
    return Page.Options(spec, "Quick Start", "Interface\\Icons\\INV_Misc_Book_09", "Get arena-ready in 60 seconds. Pick your style, check the sound, choose what you want to hear. Advanced users can customize 450+ spells in Voice Alerts.", 0.5)
end
