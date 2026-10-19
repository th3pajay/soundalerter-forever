local PAGE = "SoundAlerterVoicePage"

local PREVIEWS = {
    arenaClass = function()
        SoundAlerter:PlayVoice(SoundAlerter.db1.profile.sapath .. "paladin.mp3")
        SoundAlerter:ScheduleTimer("PlayTrinket", 0.4)
    end,
    drinking = function()
        SoundAlerter:PlayVoice(SoundAlerter.db1.profile.sapath .. "drinking.mp3")
    end,
}

function SoundAlerter:BuildVoiceAlertOptions()
    local spec = self.voiceSpec or {
        db = function() return SoundAlerter.db1 and SoundAlerter.db1.profile end,
        defaults = function() return dbDefaults.profile end,
        spellList = function() return SoundAlerter.spellList or SoundAlerterSpells end,
        spellMeta = function() return SoundAlerterSpellMeta end,
        play = function(path) SoundAlerter:PlayVoice(path) end,
        print = function(text) SoundAlerter:Print(text) end,
        preview = function(kind)
            local play = PREVIEWS[kind]
            if play then play() end
        end,
        engineSupported = function() return SoundAlerter:EngineAuraSoundSupported() end,
    }
    self.voiceSpec = spec
    return {
        type = 'group',
        name = "Voice Alerts",
        icon = "Interface\\Icons\\INV_Misc_Bell_01",
        desc = "Choose which enemy and friendly spells trigger a voice alert, silence whole categories, and set up chat announcements.",
        order = 2,
        args = {
            page = {
                type = 'description',
                name = "Voice Alerts could not draw its page.",
                dialogControl = PAGE,
                arg = spec,
                order = 1,
            },
        },
    }
end
