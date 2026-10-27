local SoundAlerter = SoundAlerter

function SoundAlerter:BuildQuickStartOptions()
    return {
        type = 'group',
        name = "Quick Start",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        desc = "Set up SoundAlerter in a minute: pick your style, check the sound, choose what you want to hear and which helpers to show. Run it again any time.",
        order = 0.5,
        args = {
            page = {
                type = 'description',
                name = "Quick Start could not draw its page.",
                dialogControl = SoundAlerter.QuickStartWizard.Widget,
                arg = {},
                order = 1,
            },
        },
    }
end
