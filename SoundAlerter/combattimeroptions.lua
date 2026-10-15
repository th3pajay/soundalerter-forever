local SoundAlerter = SoundAlerter

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local FLAT = "Interface\\Buttons\\WHITE8X8"
local PREVIEW_WIDTH = 250
local FREE_SECONDS = 1.2

local function timer()
    return SoundAlerter.CombatTimer
end

local CombatPreview = { height = 74 }

function CombatPreview.build(stage)
    local state = { stage = stage }
    state.track = stage:CreateTexture(nil, "BACKGROUND")
    state.track:SetTexture(FLAT)
    state.track:SetVertexColor(0.227, 0.263, 0.322, 1)
    state.track:SetPoint("TOP", stage, "TOP", 0, -14)
    state.fill = stage:CreateTexture(nil, "ARTWORK")
    state.fill:SetTexture(FLAT)
    state.fill:SetPoint("LEFT", state.track, "LEFT", 0, 0)
    state.digits = stage:CreateFontString(nil, "OVERLAY")
    state.digits:SetPoint("TOP", state.track, "BOTTOM", 0, -4)
    state.digits:SetJustifyH("CENTER")
    state.started = 0
    stage:SetScript("OnUpdate", function(_, elapsed)
        state.started = state.started + elapsed
        CombatPreview.draw(state)
    end)
    return state
end

function CombatPreview.draw(state)
    local settings = state.settings
    if not settings then return end
    local window = settings.windowSeconds
    local cycle = state.started % (window + FREE_SECONDS)
    local left = math.max(0, window - cycle)
    local color = left > 2.5 and settings.hotColor or left > 1 and settings.warmColor or left > 0 and settings.coolColor or settings.freeColor
    local width = math.min(PREVIEW_WIDTH, settings.width * settings.scale)
    local height = math.max(2, settings.thickness * settings.scale * 1.3)
    local alpha = 1
    if left <= 0 and settings.fadeWhenFree then alpha = settings.freeAlpha end
    if settings.animations and left > 0 and left < 1 then alpha = 0.55 + 0.45 * math.abs(math.sin(state.started * 14)) end

    state.track:SetSize(width, height)
    state.track:SetAlpha(alpha)
    state.fill:SetHeight(height)
    state.fill:SetWidth(math.max(0.001, width * left / window))
    state.fill:SetVertexColor(color.r, color.g, color.b, 1)
    state.fill:SetAlpha(alpha)
    state.digits:SetShown(settings.showDigits)
    if settings.showDigits then
        state.digits:SetFont(FONT, math.min(22, settings.digitSize * settings.scale), "")
        state.digits:SetTextColor(color.r, color.g, color.b)
        state.digits:SetText(left > 0 and string.format("%." .. settings.decimals .. "f", left) or "")
        state.digits:SetAlpha(alpha)
    end
end

function CombatPreview.update(state, settings)
    if not state then return end
    state.settings = settings
    CombatPreview.draw(state)
end

function SoundAlerter:BuildCombatTimerOptions()
    local Page = SoundAlerter.Page
    return Page.Module({
        key = "CombatTimer",
        title = "Combat Drop Timer",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        desc = "A thin line and tiny digits that count down to the moment you leave combat, so you know when you can drink, eat, mount or stealth.",
        blurb = "A thin line counting down to the moment you leave combat, to the millisecond. The countdown is an estimate that snaps to the real moment combat ends.",
        order = 2.88,
        module = timer,
        defaults = function() return dbDefaults.profile.combatTimer end,
        summary = function(settings)
            return Page.Summary(settings,
                settings.onlyInPvP and "PvP only" or "everywhere",
                settings.windowSeconds .. " s window",
                settings.locked and "locked" or "unlocked, drag to move")
        end,
        preview = CombatPreview,
        rows = {
            Page.Toggle("locked", "Lock position", "Unlock to drag the timer. A shaded outline and a preview mark it while unlocked.", false, "General"),
            Page.Toggle("onlyInPvP", "Only in PvP", "Only run in arenas, battlegrounds and while PvP flagged. Combat against creatures follows different rules.", false, "General"),
            Page.Action("Test", "Run a sample fight: a hit, a countdown and the drop.", function()
                local active = timer()
                if active then active:RunTest() end
            end, false, "General"),
            Page.Range("width", "Width", "Length of the line in pixels.", 60, 400, 5, false, "Appearance", " px"),
            Page.Range("thickness", "Thickness", "Height of the line in pixels.", 1, 6, 1, false, "Appearance", " px"),
            Page.Toggle("showDigits", "Show digits", "Show the remaining time under the line.", false, "Appearance"),
            Page.Toggle("animations", "Animations", "Pulse in the last second, a small bump when the countdown resets, and a flash when combat drops.", false, "Appearance"),
            Page.Action("Reset position", "Put the timer back where it started.", function()
                local active = timer()
                if active then active:ResetPosition() end
            end, true, "General"),
            Page.Range("windowSeconds", "Combat window", "Seconds without hostile action before the game drops combat. Measure it with /sa ctprobe in debug mode.", 3, 8, 0.5, true, "Timing", " s"),
            Page.Range("decimals", "Decimals", "Digits after the decimal point. The game only redraws once per frame, so the last digit blurs at 3.", 0, 3, 1, true, "Timing", ""),
            Page.Range("scale", "Scale", "Overall size.", 0.5, 3, 0.05, true, "Appearance", "x"),
            Page.Range("digitSize", "Digit size", "Font size of the digits.", 8, 20, 1, true, "Appearance", " px"),
            Page.Toggle("fadeWhenFree", "Fade when free", "Fade out a moment after combat drops.", true, "Appearance"),
            Page.Range("freeAlpha", "Opacity when free", "How visible it stays once you are out of combat. 0 hides it.", 0, 1, 0.05, true, "Appearance", ""),
            Page.Color("hotColor", "Early color", "More than 2.5 seconds left.", true, "Colors"),
            Page.Color("warmColor", "Warning color", "Between 1 and 2.5 seconds left.", true, "Colors"),
            Page.Color("coolColor", "Almost free color", "Under 1 second left, and while waiting for the game to confirm.", true, "Colors"),
            Page.Color("freeColor", "Free color", "Out of combat.", true, "Colors"),
        },
    })
end
