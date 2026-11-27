local SoundAlerter = SoundAlerter

local Preview = { height = 56 }
local PREVIEW_PAD = 16

local function Fit(state)
    local Strip = SoundAlerter.DamageMeterStrip
    local view, stage = state.view, state.stage
    local room, width = stage:GetWidth(), view.frame:GetWidth()
    if not room or room <= PREVIEW_PAD or not width or width <= 0 then return end
    view.frame:SetScale(math.min(1, (room - PREVIEW_PAD) / width))
    Strip.Fonts(view)
end
Preview.Fit = Fit

function Preview.build(stage)
    local Strip = SoundAlerter.DamageMeterStrip
    local view = Strip.Build(stage)
    view.frame:SetPoint("CENTER", stage, "CENTER", 0, 0)
    local state = { view = view, stage = stage }
    stage:HookScript("OnSizeChanged", function() Fit(state) end)
    return state
end

function Preview.update(state, settings)
    local Strip = SoundAlerter.DamageMeterStrip
    local view = state.view
    Strip.ShowTag(view, settings.showTag)
    Strip.SetKind(view, "run", "Deadmines")
    Strip.SetPlain(view, Strip.SAMPLE[1], Strip.SAMPLE[2], Strip.SAMPLE[3], Strip.SAMPLE_RATIOS)
    Fit(state)
end

local function meter()
    return SoundAlerter.DamageMeter
end

function SoundAlerter:BuildDamageMeterOptions()
    local Page = SoundAlerter.Page
    return Page.Module({
        key = "DamageMeter",
        title = "Damage Meter",
        icon = "Interface\\Icons\\Ability_Warrior_Cleave",
        desc = "Your damage, healing and damage taken, per fight and per session.",
        blurb = "A strip with your DPS, damage and healing. In combat the game shows the numbers but hides them from addons, so the lines compare you with the top of your group; after the fight they compare you with your own records. World, world PvP and dungeon runs are kept apart.",
        order = 2.96,
        module = meter,
        defaults = function() return dbDefaults.profile.damageMeter end,
        summary = function(settings)
            return Page.Summary(settings,
                settings.locked and "locked" or "unlocked, drag to move",
                settings.combatOnly and "shown in combat" or "always shown, shrinks to DPS when idle")
        end,
        preview = Preview,
        lock = {
            key = "locked",
            hint = "Unlocked: drag the strip. Example numbers show while unlocked. Locked: Shift-drag still moves it, and right-click opens this page.",
            reset = function()
                local active = meter()
                if active then active:ResetPosition() end
            end,
        },
        rows = {
            Page.Toggle("combatOnly", "Only in combat", "Show the strip in combat and for 10 seconds after. Off keeps it on screen; when idle it shrinks to your DPS until you hover it.", false, "General"),
            Page.Toggle("showTag", "Show where", "A small tag: World, World PvP or the dungeon's name.", false, "General"),
            Page.Range("scale", "Strip scale", "Size of the strip.", 0.6, 2, 0.05, false, "Look", "x"),
            Page.Range("windowScale", "Window scale", "Size of the window that opens when you click the strip.", 0.6, 1.6, 0.05, false, "Look", "x"),
            Page.Range("refresh", "Refresh", "How often the numbers update in combat. Slower costs less.", 0.25, 2, 0.25, true, "General", " s"),
        },
    })
end
