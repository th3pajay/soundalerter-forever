local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
if not SoundAlerter then
    return
end

local ProximityToasts = {}
SoundAlerter.ProximityToasts = ProximityToasts

local AuraTiming = SA_COMPAT.AuraTiming

ProximityToasts.inCombat = false

local MAX_TOASTS = 5
local TOAST_WIDTH = 340
local TOAST_HEIGHT = 96
local VERTICAL_SPACING = 8
local MAX_AURA_ICONS = 3
local AURA_ICON_SIZE = 18
local AURA_ICON_SPACING = 4
local AURA_SCAN_MAX = 6
local INTEL_NAME_X = 54
local THREAT_NAME_X = 86
local TOAST_EDGE = 10
local STRIPE = { WIDTH = 360, HEIGHT = 26, ICON = 18, PAD = 6, INSET = 1, GLOW = 64, GLOW_ALPHA = 0.35, SLIDE = 44, NAME_SHARE = 0.55, GAP = 8 }
local CARD_INSET = 4
local NO_AURAS = {}
local NAME_CLEARANCE = 8
local SPELL_TEXT_WIDTH = 110
local SPELL_TEXT_RIGHT = 32
local SECOND_NAME_SIZE = 11
local SECOND_RULE_PAD = 5
local TEST_SECOND_NAME = "Ashwhisper"
local TRAP_NOTE = "Traps down 30s"
local TRAP_CASTS = {
    [1499] = true, [14310] = true, [14311] = true, [13809] = true,
    [13795] = true, [14302] = true, [14303] = true, [14304] = true, [14305] = true,
    [13813] = true, [14316] = true, [14317] = true,
}
local issecretvalue = _G.issecretvalue or function() return false end

local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local CLASS_ICONS = {
    WARRIOR = "Interface\\Icons\\ClassIcon_Warrior",
    PALADIN = "Interface\\Icons\\ClassIcon_Paladin",
    HUNTER = "Interface\\Icons\\ClassIcon_Hunter",
    ROGUE = "Interface\\Icons\\ClassIcon_Rogue",
    PRIEST = "Interface\\Icons\\ClassIcon_Priest",
    DEATHKNIGHT = "Interface\\Icons\\ClassIcon_DeathKnight",
    SHAMAN = "Interface\\Icons\\ClassIcon_Shaman",
    MAGE = "Interface\\Icons\\ClassIcon_Mage",
    WARLOCK = "Interface\\Icons\\ClassIcon_Warlock",
    DRUID = "Interface\\Icons\\ClassIcon_Druid",
}

local classColorCache = {}

ProximityToasts.lastToastTime = {}
ProximityToasts.initialized = false

local PROXIMITY_TOAST_PREVIEWABLE_KEYS = {}

function ProximityToasts:GetSettings()
    local db = SoundAlerter.db1.profile
    db.proximityToasts = db.proximityToasts or {}
    return db.proximityToasts
end

function ProximityToasts:Apply(changedKey)
    if changedKey == "toastStyle" then self:ApplyStyle() end
    if changedKey and self:GetSettings()[changedKey] and PROXIMITY_TOAST_PREVIEWABLE_KEYS[changedKey] then
        SoundAlerter:PlayVoice(SoundAlerter.db1.profile.sapath..changedKey..".mp3")
    end
end

local SafeUnitName = SA_COMPAT.SafeUnitName

local SanitizeMacroText = SA_ToastClick.Sanitize

local function ApplyFocusMacro(button, unitName)
    local hasTarget = UnitExists("target")
    local targetName = hasTarget and SafeUnitName("target") or nil
    local state = SA_ToastClick.TargetState(hasTarget, targetName, unitName)
    button:SetAttribute("shift-macrotext1", SA_ToastClick.FocusMacro(SanitizeMacroText(unitName), state))
end

local function GetClassColor(className)
    if not className then return 0.5, 0.5, 0.5 end

    if not classColorCache[className] then
        local classColor = RAID_CLASS_COLORS[className]
        if classColor then
            classColorCache[className] = {classColor.r * 0.35, classColor.g * 0.35, classColor.b * 0.35}
        else
            classColorCache[className] = {0.175, 0.175, 0.175}
        end
    end

    local cached = classColorCache[className]
    return cached[1], cached[2], cached[3]
end

local backdropConfig, stripeBackdrop

local function GetBackdropConfig(stripe)
    if stripe then
        if not stripeBackdrop then
            stripeBackdrop = {
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = STRIPE.INSET,
                insets = {left = STRIPE.INSET, right = STRIPE.INSET, top = STRIPE.INSET, bottom = STRIPE.INSET}
            }
        end
        return stripeBackdrop
    end
    if not backdropConfig then
        backdropConfig = {
            bgFile = SoundAlerter.BarUtils.BACKDROP_TEXTURES.Solid,
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4}
        }
    end
    return backdropConfig
end

local ACCENT = {1, 0.49, 0.04}
local THREAT_COLORS = {HIGH = {1, 0.3, 0.3}, MEDIUM = {1, 0.65, 0.2}, LOW = {0.7, 0.7, 0.7}}
local CELL_X = {10, 70, 190}
local CELL_LABELS = {"Level", "Distance", "Group"}
local PLAIN_TAG = {0.85, 0.87, 0.92}
local WATCH_RED = {1, 0.16, 0.16}
local WATCH_TAG = "WATCHED"
local BORDER_RED = {0.8, 0.2, 0.2}

local function PaintWatch(toast, view)
    local tint = view.watched and WATCH_RED or (view.style == "threat" and (THREAT_COLORS[view.threatLevel] or THREAT_COLORS.LOW)) or PLAIN_TAG
    toast.tagText:SetText(view.watched and WATCH_TAG or view.tag or "")
    toast.tagText:SetTextColor(tint[1], tint[2], tint[3])
end

local function PaintBorder(toast, view)
    if SoundAlerter.db1.profile.proximityToasts.rainbowBorder then return end
    local tint = view.watched and WATCH_RED or BORDER_RED
    toast:SetBackdropBorderColor(tint[1], tint[2], tint[3], 1)
end

local function ClassTextColor(className)
    local color = className and RAID_CLASS_COLORS[className]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

local function SpellTextWidth(toast)
    local width = toast.spellText:GetUnboundedStringWidth()
    if issecretvalue(width) then return SPELL_TEXT_WIDTH end
    return math.min(width, SPELL_TEXT_WIDTH)
end

local function FitStripe(toast, view)
    local width = toast.engine.config.width
    local tagWidth = view.watched and toast.tagText:GetUnboundedStringWidth() or 0
    local left = STRIPE.PAD + STRIPE.ICON + STRIPE.PAD
    local right = width - STRIPE.GAP - (tagWidth > 0 and (tagWidth + STRIPE.GAP) or 0)
    local room = right - left
    local name = math.min(math.ceil(toast.detailText:GetUnboundedStringWidth()) + 1, math.floor(room * STRIPE.NAME_SHARE))
    toast.detailText:SetWidth(math.max(1, name))
    toast.titleText:SetWidth(math.max(1, room - name - STRIPE.GAP))
    toast.secondText:Hide()
    toast.secondRule:Hide()
end

local function FitName(toast, view)
    if SA_ToastStyle.IsStripe(view.style) then
        FitStripe(toast, view)
        return
    end
    local left, right = INTEL_NAME_X, TOAST_WIDTH - TOAST_EDGE
    if view.style == "threat" then
        left = THREAT_NAME_X
        right = right - toast.tagText:GetUnboundedStringWidth() - NAME_CLEARANCE
    elseif toast.spellText:IsShown() then
        right = TOAST_WIDTH - SPELL_TEXT_RIGHT - SpellTextWidth(toast) - NAME_CLEARANCE
    end
    local secondWidth = view.second and toast.secondText:GetUnboundedStringWidth() or nil
    local first, second = SA_ToastStyle.NameFit(right - left, toast.detailText:GetUnboundedStringWidth(), secondWidth)
    toast.detailText:SetWidth(first)
    if second then toast.secondText:SetWidth(second) end
    toast.secondText:SetShown(second ~= nil)
    toast.secondRule:SetShown(second ~= nil)
end

local function DrawSpell(toast, view)
    if SA_ToastStyle.IsStripe(view.style) then
        toast.spellText:Hide()
        toast.spellIcon:Hide()
        FitStripe(toast, view)
        return
    end
    local shown = view.spellName ~= nil and SA_Secret.Draw(toast.spellText, toast.spellIcon, view.spellName, view.spellIcon)
    toast.spellText:SetShown(shown)
    toast.spellIcon:SetShown(shown)
    FitName(toast, view)
end

local function TintGlow(texture, r, g, b, leftToRight)
    if texture.SetGradient and CreateColor then
        local strong, clear = CreateColor(r, g, b, STRIPE.GLOW_ALPHA), CreateColor(r, g, b, 0)
        if leftToRight then texture:SetGradient("HORIZONTAL", strong, clear) else texture:SetGradient("HORIZONTAL", clear, strong) end
    else
        texture:SetVertexColor(r, g, b, STRIPE.GLOW_ALPHA * 0.5)
    end
end

local function ApplyStripe(toast, view, r, g, b)
    toast.sideBlock:Hide()
    toast.icon:SetSize(STRIPE.ICON, STRIPE.ICON)
    toast.icon:SetPoint("LEFT", toast, "LEFT", STRIPE.PAD, 0)
    toast.levelText:SetText("")
    toast.detailText:SetFontObject(GameFontNormal)
    toast.detailText:SetTextColor(r, g, b)
    toast.detailText:SetPoint("LEFT", toast.icon, "RIGHT", STRIPE.PAD, 0)
    toast.titleText:SetPoint("LEFT", toast.detailText, "RIGHT", STRIPE.GAP, 0)
    toast.tagText:SetPoint("RIGHT", toast, "RIGHT", -STRIPE.GAP, 0)
    toast.auraIcons[1]:SetPoint("LEFT", toast, "LEFT", 0, 0)
    toast.spellIcon:SetPoint("RIGHT", toast, "RIGHT", -STRIPE.GAP, 0)
    for i = 1, 3 do
        toast.cellLabels[i]:Hide()
        toast.cellValues[i]:Hide()
    end
    for i = 1, 4 do toast.meterBars[i]:Hide() end
    TintGlow(toast.stripeLeft, r, g, b, true)
    TintGlow(toast.stripeRight, r, g, b, false)
    toast.stripeLeft:Show()
    toast.stripeRight:Show()
end

local function ApplyView(toast, view)
    local r, g, b = ClassTextColor(view.className)
    local threatStyle = view.style == "threat"
    local stripeStyle = SA_ToastStyle.IsStripe(view.style)

    toast.icon:SetTexture(view.iconTexture)
    toast.icon:ClearAllPoints()
    toast.icon:SetSize(36, 36)
    toast.titleText:ClearAllPoints()
    toast.detailText:ClearAllPoints()
    toast.levelText:ClearAllPoints()
    toast.tagText:ClearAllPoints()
    toast.auraIcons[1]:ClearAllPoints()
    toast.spellIcon:ClearAllPoints()

    toast.titleText:SetFontObject(GameFontNormalSmall)
    toast.titleText:SetTextColor(0.72, 0.74, 0.8)
    toast.titleText:SetText(view.title or "")
    toast.detailText:SetFontObject(GameFontNormalLarge)
    toast.detailText:SetTextColor(r, g, b)
    toast.detailText:SetText(view.primary or "")
    toast.secondText:SetText(view.second or "")

    if not stripeStyle then
        toast.stripeLeft:Hide()
        toast.stripeRight:Hide()
    end
    if stripeStyle then
        ApplyStripe(toast, view, r, g, b)
    elseif threatStyle then
        toast.sideBlock:ClearAllPoints()
        toast.sideBlock:SetPoint("TOPLEFT", toast, "TOPLEFT", 4, -4)
        toast.sideBlock:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 4, 4)
        toast.sideBlock:SetWidth(70)
        toast.sideBlock:SetVertexColor(r, g, b, 0.95)
        toast.sideBlock:Show()
        toast.icon:SetPoint("TOP", toast.sideBlock, "TOP", 0, -12)
        toast.levelText:SetPoint("BOTTOM", toast.sideBlock, "BOTTOM", 0, 12)
        toast.levelText:SetTextColor(0.08, 0.09, 0.1)
        toast.levelText:SetText(view.sideLabel or "")
        toast.detailText:SetPoint("TOPLEFT", toast, "TOPLEFT", THREAT_NAME_X, -12)
        toast.titleText:SetPoint("TOPLEFT", toast.detailText, "BOTTOMLEFT", 0, -4)
        toast.titleText:SetPoint("RIGHT", toast, "RIGHT", -10, 0)
        toast.tagText:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -10, -14)
        toast.auraIcons[1]:SetPoint("TOPLEFT", toast, "TOPLEFT", 86, -54)
        toast.spellIcon:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -TOAST_EDGE, -54)
        for i = 1, 3 do
            toast.cellLabels[i]:Hide()
            toast.cellValues[i]:Hide()
        end
        for i = 1, 4 do toast.meterBars[i]:Hide() end
    else
        toast.sideBlock:Hide()
        toast.icon:SetPoint("TOPLEFT", toast, "TOPLEFT", 10, -10)
        toast.levelText:SetText("")
        toast.titleText:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 8, 0)
        toast.titleText:SetPoint("RIGHT", toast, "RIGHT", -100, 0)
        toast.detailText:SetPoint("TOPLEFT", toast.titleText, "BOTTOMLEFT", 0, -2)
        toast.tagText:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -10, -12)
        toast.auraIcons[1]:SetPoint("TOPLEFT", toast, "TOPLEFT", 262, -52)
        toast.spellIcon:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -TOAST_EDGE, -30)
        local values = {view.levelShort or "-", view.band or "-", view.groupText or "-"}
        for i = 1, 3 do
            toast.cellLabels[i]:ClearAllPoints()
            toast.cellLabels[i]:SetPoint("TOPLEFT", toast, "TOPLEFT", CELL_X[i], -52)
            toast.cellLabels[i]:SetText(CELL_LABELS[i])
            toast.cellLabels[i]:Show()
            toast.cellValues[i]:ClearAllPoints()
            toast.cellValues[i]:SetPoint("TOPLEFT", toast.cellLabels[i], "BOTTOMLEFT", 0, -1)
            toast.cellValues[i]:SetText(values[i])
            toast.cellValues[i]:Show()
        end
        local rank = view.bandRank or 0
        for i = 1, 4 do
            local bar = toast.meterBars[i]
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", toast.cellValues[2], "BOTTOMLEFT", (i - 1) * 17, -3)
            if i <= rank then
                bar:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
            else
                bar:SetVertexColor(1, 1, 1, 0.2)
            end
            bar:SetShown(view.band ~= nil)
        end
    end
    PaintWatch(toast, view)

    local auras = (not stripeStyle and view.auras) or NO_AURAS
    for i = 1, MAX_AURA_ICONS do
        local aura = auras[i]
        if aura then
            toast.auraIcons[i]:SetTexture(aura.icon)
            toast.auraIcons[i]:Show()
            if aura.text then
                toast.auraDurationTexts[i]:SetText(aura.text)
                toast.auraDurationTexts[i]:Show()
            else
                toast.auraDurationTexts[i]:Hide()
            end
        else
            toast.auraIcons[i]:Hide()
            toast.auraDurationTexts[i]:Hide()
        end
    end

    DrawSpell(toast, view)
end

local function BuildContent(toast)
    toast.titleText:SetWordWrap(false)
    toast.detailText:SetWordWrap(false)

    toast.secondRule = toast:CreateTexture(nil, "ARTWORK")
    toast.secondRule:SetTexture("Interface\\Buttons\\WHITE8X8")
    toast.secondRule:SetVertexColor(1, 1, 1, 0.3)
    toast.secondRule:SetSize(1, 12)
    toast.secondRule:SetPoint("LEFT", toast.detailText, "RIGHT", SECOND_RULE_PAD, 0)
    toast.secondRule:Hide()

    toast.secondText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local _, _, secondFlags = toast.secondText:GetFont()
    SA_COMPAT.SetFont(toast.secondText, SECOND_NAME_SIZE, secondFlags)
    toast.secondText:SetPoint("BOTTOMLEFT", toast.detailText, "BOTTOMRIGHT", SA_ToastStyle.NAME_GAP, 1)
    toast.secondText:SetJustifyH("LEFT")
    toast.secondText:SetWordWrap(false)
    toast.secondText:SetTextColor(0.72, 0.74, 0.8)
    toast.secondText:Hide()

    toast.levelText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toast.levelText:SetPoint("BOTTOM", toast.icon, "BOTTOM", 0, 2)
    toast.levelText:SetTextColor(1, 0.82, 0)
    toast.levelText:SetShadowOffset(1, -1)
    toast.levelText:SetShadowColor(0, 0, 0, 1)

    toast.tagText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toast.sideBlock = toast:CreateTexture(nil, "BACKGROUND", nil, 1)
    toast.sideBlock:SetTexture("Interface\\Buttons\\WHITE8X8")
    toast.sideBlock:Hide()

    toast.cellLabels = {}
    toast.cellValues = {}
    for i = 1, 3 do
        toast.cellLabels[i] = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        toast.cellLabels[i]:SetTextColor(0.6, 0.63, 0.7)
        toast.cellValues[i] = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    end
    toast.meterBars = {}
    for i = 1, 4 do
        local bar = toast:CreateTexture(nil, "ARTWORK")
        bar:SetTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetSize(14, 3)
        toast.meterBars[i] = bar
    end

    toast.auraIcons = {}
    toast.auraDurationTexts = {}
    for i = 1, MAX_AURA_ICONS do
        local auraIcon = toast:CreateTexture(nil, "ARTWORK")
        auraIcon:SetSize(AURA_ICON_SIZE, AURA_ICON_SIZE)
        if i == 1 then
            auraIcon:SetPoint("TOPLEFT", toast.detailText, "BOTTOMLEFT", 0, -4)
        else
            auraIcon:SetPoint("LEFT", toast.auraIcons[i - 1], "RIGHT", AURA_ICON_SPACING, 0)
        end
        auraIcon:Hide()
        toast.auraIcons[i] = auraIcon

        local durationText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        local durationFont, _, durationFlags = durationText:GetFont()
        durationText:SetFont(durationFont, 8, durationFlags)
        durationText:SetPoint("TOP", auraIcon, "BOTTOM", 0, 0)
        durationText:SetTextColor(1, 1, 1)
        toast.auraDurationTexts[i] = durationText
    end

    toast.spellIcon = toast:CreateTexture(nil, "ARTWORK")
    toast.spellIcon:SetSize(18, 18)
    toast.spellIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    toast.spellIcon:Hide()
    toast.spellText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toast.spellText:SetPoint("RIGHT", toast.spellIcon, "LEFT", -4, 0)
    toast.spellText:SetWidth(110)
    toast.spellText:SetJustifyH("RIGHT")
    toast.spellText:SetWordWrap(false)
    toast.spellText:SetTextColor(1, 0.82, 0)
    toast.spellText:Hide()

    toast.stripeLeft = toast:CreateTexture(nil, "BORDER")
    toast.stripeLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    toast.stripeLeft:SetPoint("TOPLEFT", toast, "TOPLEFT", STRIPE.INSET, -STRIPE.INSET)
    toast.stripeLeft:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", STRIPE.INSET, STRIPE.INSET)
    toast.stripeLeft:SetWidth(STRIPE.GLOW)
    toast.stripeLeft:Hide()
    toast.stripeRight = toast:CreateTexture(nil, "BORDER")
    toast.stripeRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    toast.stripeRight:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -STRIPE.INSET, -STRIPE.INSET)
    toast.stripeRight:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -STRIPE.INSET, STRIPE.INSET)
    toast.stripeRight:SetWidth(STRIPE.GLOW)
    toast.stripeRight:Hide()
end

local function StyleFrame(toast)
    local stripe = SA_ToastStyle.IsStripe(toast.engine.config.style)
    local inset = stripe and STRIPE.INSET or CARD_INSET
    toast:SetBackdrop(GetBackdropConfig(stripe))
    toast:SetBackdropColor(0, 0, 0, 0.85)
    toast:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    local bar = toast.countdownBar
    if bar then
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", inset, inset)
        bar:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -inset, inset)
        bar:SetHeight(stripe and 2 or 3)
        for i = 1, #bar.segments do bar.segments[i]:SetHeight(stripe and 2 or 3) end
    end
    toast.inset = inset
end

local function Motion(toast, progress, phase)
    local view = toast.view
    if not view or view.style ~= "slide" then return false end
    local x, y = toast.layoutX, toast.currentY
    if not (x and y) or toast.isSliding or (toast.slideGroup and toast.slideGroup:IsPlaying()) then return true end
    local dx = SA_ToastStyle.SlideOffset(progress, phase, STRIPE.SLIDE)
    if dx ~= toast.motionX then
        toast.motionX = dx
        toast:SetPoint("TOP", UIParent, "TOP", x + dx, y)
    end
    return true
end

local function ToggleWatch(toast)
    local unitName = toast.userData and toast.userData.unitName
    if unitName then SoundAlerter:ToggleWatchName(unitName) end
end

local function HookSecureButton(secureButton, toast)
    secureButton:SetAttribute("ctrl-type1", "sawatch")
    secureButton:SetScript("PreClick", function(self)
        if IsControlKeyDown() then
            if not IsShiftKeyDown() then ToggleWatch(toast) end
            return
        end
        if InCombatLockdown() or not IsShiftKeyDown() then return end
        local unitName = toast.userData and toast.userData.unitName
        if unitName and SoundAlerter.db1.profile.proximityToasts.enableFocusTarget then
            ApplyFocusMacro(self, unitName)
        end
    end)
end

local function ReleaseContent(toast)
    toast.view = nil
    toast.motionX = nil
    toast.levelText:SetText("")
    toast.tagText:SetText("")
    toast.sideBlock:Hide()
    toast.secondText:SetText("")
    toast.secondText:Hide()
    toast.secondRule:Hide()
    toast.spellText:SetText("")
    toast.spellText:Hide()
    toast.spellIcon:SetTexture(nil)
    toast.spellIcon:Hide()
end

local function ArmSecureButton(button, unitName)
    local safeUnitName = SanitizeMacroText(unitName)
    button:SetAttribute("type1", "macro")
    button:SetAttribute("macrotext1", "/target " .. safeUnitName)

    if SoundAlerter.db1.profile.proximityToasts.enableFocusTarget then
        button:SetAttribute("shift-type1", "macro")
        ApplyFocusMacro(button, unitName)
    end

    button:SetAlpha(1)
    button:Show()
end

local function CopyContent(oldFrame, newFrame)
    newFrame.view = oldFrame.view
    if newFrame.view then
        ApplyView(newFrame, newFrame.view)
    end

    if newFrame.secureButton and oldFrame.userData.unitName then
        if not InCombatLockdown() then
            ArmSecureButton(newFrame.secureButton, oldFrame.userData.unitName)
        else
            SoundAlerter:Debug("ProximityToasts", "CopyToastData skipped the secure config, in combat (should not happen)")
        end
    end
end

local function CurrentPosition()
    local settings = ProximityToasts:GetSettings()
    return settings.positionX or 0, settings.positionY or -200
end

local function CanDismissOnClick()
    if InCombatLockdown() then
        return false
    end
    local settings = SoundAlerter.db1.profile.proximityToasts
    return settings and settings.clickEnabled
end

local function TickBorder(toast, now)
    if SoundAlerter.db1.profile.proximityToasts.rainbowBorder then
        local r, g, b = SA_Toast.RainbowColor(now)
        toast:SetBackdropBorderColor(r, g, b, 1)
    elseif toast.view and toast.view.high and not toast.view.watched then
        local pulse = 0.55 + 0.45 * math.abs(math.sin(now * 3))
        toast:SetBackdropBorderColor(1, 0.25 * pulse, 0.2 * pulse, 1)
    end
end

local engine = SA_Toast.New({
    label = "ProximityToasts",
    prefix = "SoundAlerter",
    swapLabel = "Proximity",
    swapBudgetMs = 6.0,
    maxToasts = MAX_TOASTS,
    width = TOAST_WIDTH,
    height = TOAST_HEIGHT,
    spacing = VERTICAL_SPACING,
    slide = true,
    manageMouse = false,
    mirrorSecureAlpha = false,
    secureAttributes = {"macrotext1", "shift-macrotext1"},
    userFields = {"unitName", "guid", "className", "unitToken"},
    backdropFile = function() return "Interface\\Tooltips\\UI-Tooltip-Background" end,
    segmentWidth = function(toast, duration) return (toast.engine.config.width - 2 * (toast.inset or CARD_INSET)) / duration end,
    position = CurrentPosition,
    canDismissOnClick = CanDismissOnClick,
    tickBorder = TickBorder,
    buildContent = BuildContent,
    onSecureCreated = HookSecureButton,
    onModifiedClick = ToggleWatch,
    onRelease = ReleaseContent,
    copyContent = CopyContent,
    styleFrame = StyleFrame,
    motion = Motion,
})

local function StyleSize(style)
    if SA_ToastStyle.IsStripe(style) then return STRIPE.WIDTH, STRIPE.HEIGHT end
    return TOAST_WIDTH, TOAST_HEIGHT
end

function ProximityToasts:ApplyStyle()
    local style = SA_ToastStyle.Normalize(self:GetSettings().toastStyle)
    local width, height = StyleSize(style)
    if not engine.initialized then
        engine.config.width, engine.config.height, engine.config.style = width, height, style
        return true
    end
    return engine:Resize(width, height, style)
end
ProximityToasts.engine = engine


function ProximityToasts:Initialize()
    if self.initialized then
        return
    end
    self.inCombat = InCombatLockdown() and true or false

    local sadb = SoundAlerter.db1.profile
    if not sadb.proximityToasts then
        sadb.proximityToasts = {}
    end

    if sadb.proximityToasts.clickEnabled == nil then
        sadb.proximityToasts.clickEnabled = true
    end
    if sadb.proximityToasts.enableClickToTarget == nil then
        sadb.proximityToasts.enableClickToTarget = true
    end
    if sadb.proximityToasts.enableFocusTarget == nil then
        sadb.proximityToasts.enableFocusTarget = true
    end

    self:ApplyStyle()
    engine:Initialize()

    local combatFrame = CreateFrame("Frame")
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            ProximityToasts.inCombat = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            ProximityToasts.inCombat = false
            engine:FlushDeferred()
            if engine.secureCreationPending then
                local ok, err = pcall(engine.CreateSecurePool, engine)
                if not ok then
                    SoundAlerter:Print("|cffFF7D0ASoundAlerter|r: ProximityToasts secure pool creation failed — "..tostring(err))
                end
            end
            engine:SwapToSecure()
        end
    end)

    self.initialized = true
    self:StartCleanupTimer()
    self:SubscribeCasts()

end

function ProximityToasts:NoteTraps(guid, spellID)
    for _, toast in ipairs(engine.active) do
        local view = toast.view
        if view and toast.userData and toast.userData.guid == guid then
            view.spellName, view.spellIcon = TRAP_NOTE, SA_Secret.Icon(spellID) or view.spellIcon
            DrawSpell(toast, view)
            return
        end
    end
end

function ProximityToasts:OnTrapLanded(guid, spellID)
    if #engine.active == 0 then return end
    local settings = self:GetSettings()
    if settings.enabled and settings.showLatestSpell then self:NoteTraps(guid, spellID) end
end

function ProximityToasts:ShowSpell(guid, spellID)
    if not issecretvalue(spellID) and TRAP_CASTS[spellID] then
        self:NoteTraps(guid, spellID)
        return
    end
    for _, toast in ipairs(engine.active) do
        local view = toast.view
        if view and toast.userData and toast.userData.guid == guid then
            local name, icon = SA_Secret.Name(spellID), SA_Secret.Icon(spellID)
            if name ~= nil or icon ~= nil then
                view.spellName, view.spellIcon = name, icon
                DrawSpell(toast, view)
            end
            return
        end
    end
end

function ProximityToasts:OnCastSeen(unit, castGUID, spellID)
    if #engine.active == 0 then return end
    local settings = self:GetSettings()
    if not (settings.enabled and settings.showLatestSpell) then return end
    local guid = SA_Plates.GUID(unit)
    if not guid and (unit == "target" or unit == "focus") then guid = SA_COMPAT.Plain(UnitGUID(unit)) end
    if not guid then return end
    self:ShowSpell(guid, spellID)
end

function ProximityToasts:SubscribeCasts()
    local function seen(unit, castGUID, spellID) self:OnCastSeen(unit, castGUID, spellID) end
    SA_CastDispatch.Subscribe("toasts", {
        UNIT_SPELLCAST_START = seen,
        UNIT_SPELLCAST_CHANNEL_START = seen,
        UNIT_SPELLCAST_SUCCEEDED = seen,
    })
end

function ProximityToasts:UpdateLayout()
    engine:UpdateLayout()
end

function ProximityToasts:ShouldShowToast(guid)
    if not guid then return true end

    local now = GetTime()
    local cooldown = 0.5
    local lastTime = self.lastToastTime[guid] or 0

    if now - lastTime < cooldown then
        return false
    end

    self.lastToastTime[guid] = now
    return true
end

function ProximityToasts:CleanupHistory()
    local now = GetTime()
    for guid, time in pairs(self.lastToastTime) do
        if now - time > 30 then
            self.lastToastTime[guid] = nil
        end
    end
end

local AURA_FILTERS = {"HARMFUL", "HELPFUL"}

local function FormatAuraDuration(remaining)
    if remaining >= 60 then
        return math.floor(remaining / 60) .. "m"
    end
    return tostring(math.ceil(remaining))
end

local function CollectAuras(unitToken)
    local list = {}
    if unitToken and UnitExists(unitToken) then
        for _, filter in ipairs(AURA_FILTERS) do
            for i = 1, AURA_SCAN_MAX do
                if #list >= MAX_AURA_ICONS then return list end
                local found, icon, duration, expirationTime = AuraTiming(unitToken, i, filter)
                if not found then break end
                local remaining = duration and duration > 0 and expirationTime and (expirationTime - GetTime())
                list[#list + 1] = {
                    icon = icon,
                    text = remaining and remaining > 0 and FormatAuraDuration(remaining) or nil,
                }
            end
        end
    end
    return list
end

function ProximityToasts:RefreshWatched()
    local active = engine.active
    for i = 1, #active do
        local toast = active[i]
        local view, data = toast.view, toast.userData
        if view and data then
            local watched = (SoundAlerter:IsWatchedGuid(data.guid) or SoundAlerter:IsWatchedName(data.unitName)) and true or false
            if watched ~= (view.watched or false) then
                view.watched = watched
                PaintWatch(toast, view)
                PaintBorder(toast, view)
                FitName(toast, view)
            end
        end
    end
end

function ProximityToasts:ShowToast(unitName, className, distance, guid, level, unitToken, customTitle, nearbyCount, secondName, watched)
    local sadb = SoundAlerter.db1.profile

    if not self.initialized then
        SoundAlerter:Debug("ProximityToasts", "toast blocked: not initialized")
        return
    end

    if not sadb.proximityToasts or not sadb.proximityToasts.enabled then
        SoundAlerter:Debug("ProximityToasts", "toast blocked: toasts disabled in options (%s)", tostring(unitName))
        return
    end

    if not unitName then
        SoundAlerter:Debug("ProximityToasts", "toast blocked: no unit name (class %s)", tostring(className))
        return
    end

    if guid and not self:ShouldShowToast(guid) then
        SoundAlerter:Debug("ProximityToasts", "toast blocked: %s is on the toast cooldown", unitName)
        return
    end

    local maxConcurrent = sadb.proximityToasts.maxConcurrent or 3
    if #engine.active >= maxConcurrent then
        local oldest = engine.active[1]
        if oldest then engine:Release(oldest) end
    end

    local toast = engine:Acquire(self.inCombat)
    if not toast then
        SoundAlerter:Debug("ProximityToasts", "toast blocked: no free toast frame for %s", unitName)
        return
    end

    SoundAlerter:Debug("ProximityToasts", "showing toast for %s (%s), %d/%d active", unitName, className or "UNKNOWN", #engine.active, maxConcurrent)

    if sadb.proximityToasts.useClassColors and className then

        local r, g, b = GetClassColor(className)
        toast:SetBackdropColor(r, g, b, 0.85)
    else

        toast:SetBackdropColor(0, 0, 0, 0.85)
    end

    if nearbyCount == 0 then nearbyCount = 1 end

    local Style = SA_ToastStyle
    local style = engine.config.style or Style.Normalize(sadb.proximityToasts.toastStyle)
    local classLabel = className and (className:sub(1, 1) .. className:sub(2):lower()) or "Enemy"
    local view = {
        style = style,
        className = className,
        iconTexture = CLASS_ICONS[className] or "Interface\\Icons\\Ability_Rogue_Ambush",
        primary = (sadb.proximityToasts.showPlayerName and unitName) or classLabel,
        second = sadb.proximityToasts.showPlayerName and secondName ~= "" and secondName or nil,
        band = distance,
        bandRank = Style.BandRank(distance),
        levelShort = Style.LevelText(level),
        groupText = Style.GroupText(nearbyCount),
        tag = "NEARBY",
        sideLabel = className and className:upper() or "ENEMY",
        auras = sadb.proximityToasts.showAuraIcons and CollectAuras(unitToken) or {},
        watched = watched and true or false,
    }
    if style == "threat" then
        local threatLevel, _, why = Style.Threat(className, distance, nearbyCount)
        view.threatLevel = threatLevel
        view.tag = threatLevel .. " THREAT"
        if customTitle then
            view.title = customTitle
        else
            local lead = level and (level == -1 and "Lv ??" or ("Lv " .. level)) or nil
            if why == "" then why = "Enemy player nearby" end
            view.title = lead and (lead .. "  " .. why) or why
        end
        view.high = threatLevel == "HIGH"
    elseif Style.IsStripe(style) then
        view.tag = ""
        view.title = customTitle or Style.StripeText(classLabel, distance, view.levelShort, view.groupText)
    else
        view.title = customTitle or (className and (className .. " NEARBY!") or "ENEMY NEARBY!")
    end
    toast.view = view
    ApplyView(toast, view)
    PaintBorder(toast, view)

    if toast.userData then
        toast.userData.unitName = unitName
        toast.userData.guid = guid
        toast.userData.className = className
        toast.userData.unitToken = unitToken
    end

    if toast.secureButton and unitName then
        if not (self.inCombat or InCombatLockdown()) then
            ArmSecureButton(toast.secureButton, unitName)
        else
            SoundAlerter:Debug("ProximityToasts", "secure button config skipped, in combat")
        end
    end

    engine:Start(toast, sadb.proximityToasts.displayDuration or 3.0)
end

local function SwitchProfile(module)
    for _, toast in ipairs(engine.active) do
        engine:Release(toast)
    end
    wipe(module.lastToastTime)
    module:ApplyStyle()
end

function ProximityToasts:OnDisable()
    if self.cleanupTimer then
        SoundAlerter:CancelTimer(self.cleanupTimer)
        self.cleanupTimer = nil
    end

    engine:ReleaseAll()
end

function ProximityToasts:StartCleanupTimer()
    if not self.cleanupTimer then
        self.cleanupTimer = SoundAlerter:ScheduleRepeatingTimer(function()
            ProximityToasts:CleanupHistory()
        end, 60)
    end
end

local SA_DEBUG_GATE_NOTE = "Debug mode is off — enable it in /sa options to use developer/testing commands."

function SoundAlerter.ProximityToasts:HandleCommand(msg)
    local command, args = msg:match("^(%S*)%s*(.-)$")
    local sadb = SoundAlerter.db1.profile

    if command == "test" then
        if not sadb.debugmode then
            DEFAULT_CHAT_FRAME:AddMessage(SA_DEBUG_GATE_NOTE)
            return
        end
        local wasDisabled = not sadb.proximityToasts.enabled
        if wasDisabled then
            sadb.proximityToasts.enabled = true
        end

        if sadb.sapath then
            SoundAlerter:PlayVoice(sadb.sapath .. "ROGUE.mp3", "Master")
            SoundAlerter:ScheduleTimer(function()
                SoundAlerter:PlayVoice(sadb.sapath .. "detected.mp3", "Master")
            end, 0.8)
        end

        local duration = tonumber(args)
        if duration and duration > 0 then
            local savedDuration = sadb.proximityToasts.displayDuration
            sadb.proximityToasts.displayDuration = duration
            self:ShowToast("TestEnemy", "ROGUE", nil, nil, 80, nil, nil, nil, TEST_SECOND_NAME)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Test toast displayed with " .. duration .. "s duration.|r")
            sadb.proximityToasts.displayDuration = savedDuration
        else
            self:ShowToast("TestEnemy", "ROGUE", nil, nil, 80, nil, nil, nil, TEST_SECOND_NAME)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Test toast displayed.|r")
        end

        if wasDisabled then
            sadb.proximityToasts.enabled = false
        end
    elseif command == "multi" then
        if not sadb.debugmode then
            DEFAULT_CHAT_FRAME:AddMessage(SA_DEBUG_GATE_NOTE)
            return
        end
        local count = tonumber(args) or 3
        local wasDisabled = not sadb.proximityToasts.enabled
        if wasDisabled then
            sadb.proximityToasts.enabled = true
        end

        local classes = {"WARRIOR", "PALADIN", "ROGUE", "MAGE", "WARLOCK"}
        for i = 1, math.min(count, 5) do
            self:ShowToast("TestEnemy"..i, classes[i], nil, nil, 80, nil, nil, nil, TEST_SECOND_NAME)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Created " .. count .. " test toasts.|r")

        if wasDisabled then
            sadb.proximityToasts.enabled = false
        end
    elseif command == "countdown" then
        if not sadb.debugmode then
            DEFAULT_CHAT_FRAME:AddMessage(SA_DEBUG_GATE_NOTE)
            return
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF=== Countdown Debug ===|r")
        for i, toast in ipairs(engine.active) do
            if toast.cachedSegmentData then
                local elapsed = GetTime() - toast.startTime - toast.pauseState.totalTime
                local displayElapsed = math.max(0, elapsed - SA_Toast.FADE_IN_DURATION)
                DEFAULT_CHAT_FRAME:AddMessage("Toast " .. i .. ":")
                DEFAULT_CHAT_FRAME:AddMessage("  Duration: " .. toast.displayDuration .. "s")
                DEFAULT_CHAT_FRAME:AddMessage("  Segments: " .. toast.cachedSegmentData.duration)
                DEFAULT_CHAT_FRAME:AddMessage("  Elapsed: " .. string.format("%.2f", displayElapsed) .. "s")
                DEFAULT_CHAT_FRAME:AddMessage("  Paused: " .. tostring(toast.pauseState.active))
                DEFAULT_CHAT_FRAME:AddMessage("  Total Pause Time: " .. string.format("%.2f", toast.pauseState.totalTime) .. "s")
            end
        end
    elseif command == "init" then
        self:Initialize()
    elseif command == "enable" then
        sadb.proximityToasts.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Toasts enabled|r")
    elseif command == "enableclick" then
        if not sadb.proximityToasts then
            sadb.proximityToasts = {}
        end
        sadb.proximityToasts.clickEnabled = true
        sadb.proximityToasts.enableClickToTarget = true
        sadb.proximityToasts.enableFocusTarget = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Click-to-target enabled|r")
    elseif command == "testcustom" then
        if not sadb.debugmode then
            DEFAULT_CHAT_FRAME:AddMessage(SA_DEBUG_GATE_NOTE)
            return
        end
        local wasDisabled = not sadb.proximityToasts.enabled
        if wasDisabled then
            sadb.proximityToasts.enabled = true
        end

        if sadb.sapath then
            SoundAlerter:PlayVoice(sadb.sapath .. "ROGUE.mp3", "Master")
            SoundAlerter:ScheduleTimer(function()
                SoundAlerter:PlayVoice(sadb.sapath .. "FlagPickup.mp3", "Master")
            end, 0.8)
        end

        self:ShowToast("TestCarrier", "ROGUE", nil, "Player-Test-FLAG", 80, nil, "FLAG CARRIER!")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Test toast with custom title displayed.|r")

        if wasDisabled then
            sadb.proximityToasts.enabled = false
        end
    elseif command == "swapmetrics" then
        if not sadb.debugmode then
            DEFAULT_CHAT_FRAME:AddMessage(SA_DEBUG_GATE_NOTE)
            return
        end
        local m = engine.swapMetrics
        if not m or m.count == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700=== Frame Swap Metrics ===|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF6B6BNo swap data collected yet|r")
            return
        end

        local avgTime = m.totalTime / m.count
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700=== Frame Swap Performance Metrics ===|r")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Total swaps: |cffFFFFFF%d|r", m.count))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Avg time: |cffFFFFFF%.2fms|r", avgTime))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Max time: |cffFFFFFF%.2fms|r", m.maxTime))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Total time: |cffFFFFFF%.2fms|r", m.totalTime))
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Frame Count Distribution]|r")
        for frameCount, count in pairs(m.histogram) do
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %d frames: |cffFFFFFF%d|r swaps", frameCount, count))
        end
    elseif command == "status" then
        local PT = self

        local securePoolSize = #engine.securePool
        local insecurePoolSize = #engine.insecurePool
        local activeCount = #engine.active
        local activePoolType = PT.inCombat and "Insecure (Combat)" or "Secure (Non-Combat)"
        local utilization = (PT.inCombat and insecurePoolSize > 0) and (activeCount / insecurePoolSize * 100) or
                           (not PT.inCombat and securePoolSize > 0) and (activeCount / securePoolSize * 100) or 0

        local historyCount = 0
        for _ in pairs(PT.lastToastTime) do
            historyCount = historyCount + 1
        end

        local statusColor = PT.initialized and "|cff00FF00" or "|cffFF6B6B"
        local statusText = PT.initialized and "Online" or "Offline"

        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700=== Proximity Alerts - Performance Metrics ===|r")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[System Status]|r")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Status: %s%s|r", statusColor, statusText))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Initialized: |cffFFFFFF%s|r", tostring(PT.initialized)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  In Combat: |cffFFFFFF%s|r", tostring(PT.inCombat)))
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Click Settings]|r")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Click Enabled: |cffFFFFFF%s|r", tostring(sadb.proximityToasts and sadb.proximityToasts.clickEnabled or false)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Click-to-Target: |cffFFFFFF%s|r", tostring(sadb.proximityToasts and sadb.proximityToasts.enableClickToTarget or false)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Focus Target: |cffFFFFFF%s|r", tostring(sadb.proximityToasts and sadb.proximityToasts.enableFocusTarget or false)))
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Toast Pool]|r")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Active Pool: |cffFFFFFF%s|r", activePoolType))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Secure Pool Size: |cffFFFFFF%d|r frames", securePoolSize))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Insecure Pool Size: |cffFFFFFF%d|r frames", insecurePoolSize))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Active Toasts: |cffFFFFFF%d|r", activeCount))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Utilization: |cffFFFFFF%.1f%%|r", utilization))
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Alert History]|r")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Tracked Players: |cffFFFFFF%d|r", historyCount))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Cooldown Window: |cffFFFFFF30|r seconds"))
    else
        self:PrintHelp()
    end
end

function SoundAlerter.ProximityToasts:PrintHelp()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Proximity Toasts]|r")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast status|r - Show performance metrics and system status")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast swapmetrics|r - Show frame swap performance data")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast enable|r - Enable toast notifications")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast enableclick|r - Enable click-to-target functionality")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFFCtrl-click a toast|r - Watch or unwatch that player, also in combat")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast init|r - Manually initialize toast system")
    if SoundAlerter.db1.profile.debugmode then
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast test [duration]|r - [debug] Show test toast (optional duration in seconds)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast testcustom|r - [debug] Test custom title (FLAG CARRIER!)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast multi [count]|r - [debug] Create multiple test toasts (default: 3)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffFFFFFF/sa toast countdown|r - [debug] Show countdown debug info for active toasts")
    else
        DEFAULT_CHAT_FRAME:AddMessage("  |cffAAAAAA4 developer commands hidden — enable debug mode in /sa options to see them.|r")
    end
end

local Proximity = {}
SoundAlerter.Proximity = Proximity

local Plain = SA_COMPAT.Plain
local ZONING_WINDOW = 10
local DEFAULT_COOLDOWN = 60
local DETECTED_DELAY = 0.8
local RESCAN_EVERY = 1
local CLEANUP_EVERY = 30
local RETRY_KEEP = 60
local IDENTITY_RETRY_DELAY = 0.1
local IDENTITY_RETRY_SPACING = 5
local CHAT_WINDOW = 1.5
local CHAT_POOL = 10
local ZONE_SETTING = { arena = "proximityArena", battleground = "proximityBattleground", world = "proximityWorld", sanctuary = "proximitySanctuary", instance = "proximitySanctuary" }
local CLASS_NAMES = LOCALIZED_CLASS_NAMES_MALE or {}

local alerted, retryAt = {}, {}
local chatMapID
local rescanTicker, cleanupTicker
local batch = { used = 0, total = 0, pending = false, entries = {} }
for index = 1, CHAT_POOL do batch.entries[index] = {} end
local chatValues = {}

local function settings()
    return SoundAlerter.db1.profile
end

local function cooledDown(p, guid, now)
    local last = alerted[guid]
    return not last or now - last >= (p.proximityCooldown or DEFAULT_COOLDOWN)
end

local function bandAllows(p, band)
    local max = p.proximityMaxBand
    return not SA_Distance.IsRestricted(max) or SA_Distance.Allows(max, band)
end

local function zoneAllows(p)
    return p[ZONE_SETTING[SA_ZoneKind.Kind()]] and true or false
end

local function open(p, now)
    if not p.proximityEnabled then return false end
    if now - SoundAlerter.enterWorldTime < ZONING_WINDOW then
        local diag = SoundAlerter.diag
        diag.zoningSkips = diag.zoningSkips + 1
        return false
    end
    return zoneAllows(p) and SoundAlerter.Emitter:Open("proximity")
end

local function className(token)
    if not token then return "Enemy" end
    return CLASS_NAMES[token] or token
end

local function chatPlace()
    local mapID = chatMapID
    if mapID == nil then
        local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
        mapID = ok and Plain(id) or false
        chatMapID = mapID
    end
    local x, y
    if mapID then
        local ok, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
        if ok and position then
            local okXY, px, py = pcall(position.GetXY, position)
            if okXY then x, y = Plain(px), Plain(py) end
        end
    end
    return SA_ProxChat.Place(Plain(GetSubZoneText()), Plain(GetRealZoneText()), x, y)
end

local function flushChat()
    local used, total = batch.used, batch.total
    batch.used, batch.total, batch.pending = 0, 0, false
    local p = settings()
    if used == 0 or not SA_AlertText.Ready(p.proximityChat and p.proximityChatText, "proximity") then return end
    local place = chatPlace()
    local line
    if total == 1 then
        local entry = batch.entries[1]
        chatValues.class = className(entry.class)
        chatValues.player = entry.name
        chatValues.level = entry.level or ""
        chatValues.race = entry.race or ""
        chatValues.place = place ~= "" and place or "you"
        line = SA_ProxChat.Clean(SA_AlertText.Render(p.proximityChatText, chatValues))
    else
        local diag = SoundAlerter.diag
        diag.chatMerged = diag.chatMerged + total
        line = SA_ProxChat.Group(batch.entries, used, total, place, className)
    end
    SA_AlertText.Send(line, "proximity")
end

local function noteChat(unit, unitName, unitClass, unitLevel)
    batch.total = batch.total + 1
    if batch.used < CHAT_POOL then
        batch.used = batch.used + 1
        local entry = batch.entries[batch.used]
        entry.name = unitName
        entry.class = unitClass
        entry.level = (type(unitLevel) == "number" and unitLevel > 0) and tostring(unitLevel) or nil
        local race = Plain((UnitRace(unit)))
        entry.race = type(race) == "string" and race ~= "" and race or nil
    end
    if not batch.pending then
        batch.pending = true
        C_Timer.After(CHAT_WINDOW, flushChat)
    end
end

local classFiles = {}

local function classFile(name)
    local file = classFiles[name]
    if not file then
        file = name .. ".mp3"
        classFiles[name] = file
    end
    return file
end

local function playDetected()
    local emitter = SoundAlerter.Emitter
    local context = emitter:Context("proximity")
    context.sound, context.channel = "detected.mp3", "Master"
    emitter:Emit(context)
end

local function fire(p, guid, unitName, unitClass, unitLevel, band, unitToken, nearbyCount, title, shared, secondName)
    local watched = SoundAlerter:IsWatchedGuid(guid)
    local toastSettings = ProximityToasts:GetSettings()
    local silent = toastSettings.enabled and toastSettings.voice == false
    local emitter = SoundAlerter.Emitter
    local context = emitter:Context("proximity")
    context.channel, context.category, context.guid, context.name, context.class = "Master", "proximityAlerts", guid, unitName, unitClass
    if shared and not silent then
        context.sound = "sharedintel.mp3"
    elseif not shared and not silent and not (watched and SoundAlerter:WatchFiredNow(guid)) then
        local classAudioFile = unitClass == nil and "enemy" or SoundAlerter.CLASS_AUDIO_MAP[unitClass]
        if classAudioFile then context.sound = classFile(classAudioFile) end
        C_Timer.After(DETECTED_DELAY, playDetected)
    end
    emitter:Emit(context)
    if ProximityToasts:GetSettings().enabled then
        ProximityToasts:ShowToast(unitName, unitClass, band, guid, unitLevel, unitToken, title, nearbyCount, secondName, watched)
    end
end

local function retryIdentity(unit, guid, allySpotted, now)
    SA_Plates.MarkPending(guid, now)
    local last = retryAt[guid]
    if last and now - last < IDENTITY_RETRY_SPACING then return end
    retryAt[guid] = now
    SoundAlerter:Debug("Proximity", "%s identity unreadable, retrying in %.1fs", unit, IDENTITY_RETRY_DELAY)
    C_Timer.After(IDENTITY_RETRY_DELAY, function()
        if SA_Plates.UnitKey(unit) == guid then
            Proximity:Consider(unit, allySpotted)
        end
    end)
end

function Proximity:Consider(unit, allySpotted)
    local p = settings()
    if allySpotted and not p.proximityAllyVision then return false end
    local now = GetTime()
    if not open(p, now) then return false end
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsEnemy("player", unit) then return false end
    if not allySpotted and not UnitIsVisible(unit) then return false end

    local guid, byName = SA_Plates.UnitKey(unit)
    if not guid then return false end
    if not byName and not guid:find("^Player%-") then return false end
    if not cooledDown(p, guid, now) then return false end

    local unitName, secondName = UnitName(unit)
    local _, unitClass = UnitClass(unit)
    local unitLevel = UnitLevel(unit)

    if not Plain(unitClass) and p.scoreboardClassFallback then
        local mapped = SA_Scoreboard.ClassFor(SoundAlerter.scoreboardClasses, Plain(unitName), Plain(secondName))
        if mapped then
            SoundAlerter:Debug("Scoreboard", "%s class taken from the scoreboard: %s", unit, mapped)
            unitClass = mapped
        end
    end

    if not Plain(unitName) then
        retryIdentity(unit, guid, allySpotted, now)
        return false
    end
    if not Plain(unitClass) then
        if not (byName and retryAt[guid]) then
            retryIdentity(unit, guid, allySpotted, now)
            return false
        end
        unitClass = nil
    end
    local diag = SoundAlerter.diag
    if issecretvalue(unitLevel) then
        diag.levelHidden = diag.levelHidden + 1
        unitLevel = -1
    end

    local band = SoundAlerter:GetApproxRange(unit) or (allySpotted and "Spotted" or nil)
    if not bandAllows(p, band) then return false end

    alerted[guid] = now
    SA_Plates.ClearPending(guid)
    if byName then diag.nameKeyed = diag.nameKeyed + 1 end

    fire(p, guid, unitName, unitClass, unitLevel, band, not allySpotted and unit or nil, SA_Plates.Count(), nil, nil, Plain(secondName))

    if SA_AlertText.Ready(p.proximityChat and p.proximityChatText, "proximity") then
        noteChat(unit, unitName, unitClass, unitLevel)
    end
    if not allySpotted and not byName then
        SoundAlerter:ShareAlert("P", guid, 0, unitClass, unitLevel, unitName)
    end
    return true
end

function Proximity:ConsiderShared(guid, unitClass, unitName, unitLevel, sender)
    local p = settings()
    local now = GetTime()
    if not open(p, now) or not bandAllows(p, "Spotted") or not cooledDown(p, guid, now) then return false end
    alerted[guid] = now
    SA_Plates.ClearPending(guid)
    fire(p, guid, unitName, unitClass, unitLevel or -1, "Spotted", nil, nil, "Spotted by " .. sender, true)
    return true
end

local function rescan()
    local p = settings()
    local now = GetTime()
    if now - SoundAlerter.enterWorldTime < ZONING_WINDOW or not zoneAllows(p) then return end
    for unit, guid in pairs(SA_Plates.Enemies()) do
        if cooledDown(p, guid, now) then Proximity:Consider(unit) end
    end
end

local function cleanup()
    local now = GetTime()
    local cooldown = settings().proximityCooldown or DEFAULT_COOLDOWN
    for guid, at in pairs(alerted) do
        if now - at > cooldown then alerted[guid] = nil end
    end
    for guid, at in pairs(retryAt) do
        if now - at > RETRY_KEEP then retryAt[guid] = nil end
    end
    SA_Plates.PrunePending(now - RETRY_KEEP)
end

function Proximity:Refresh()
    local p = settings()
    local on = p.proximityEnabled and true or false
    local restricted = on and SA_Distance.IsRestricted(p.proximityMaxBand)
    if on and not cleanupTicker then
        cleanupTicker = C_Timer.NewTicker(CLEANUP_EVERY, cleanup)
    elseif not on and cleanupTicker then
        cleanupTicker:Cancel()
        cleanupTicker = nil
        wipe(alerted)
        wipe(retryAt)
    end
    if restricted and not rescanTicker then
        rescanTicker = C_Timer.NewTicker(RESCAN_EVERY, rescan)
    elseif not restricted and rescanTicker then
        rescanTicker:Cancel()
        rescanTicker = nil
    end
end

function Proximity:ZoneChanged()
    chatMapID = nil
end

local PROXIMITY_SETTINGS = {
    "proximityEnabled", "proximityWorld", "proximityBattleground", "proximityArena", "proximitySanctuary",
    "proximityCooldown", "proximityChat", "proximityChatText", "proximityAllyVision", "proximityMaxBand",
}
local ZONES_FROM_ALERTS = { { "arena", "proximityArena" }, { "battleground", "proximityBattleground" }, { "field", "proximityWorld" } }

local function anyZone(p)
    for index = 1, #ZONES_FROM_ALERTS do
        if p[ZONES_FROM_ALERTS[index][2]] then return true end
    end
    return false
end

function Proximity:Initialize()
end

function Proximity:Apply(changedKey)
    if changedKey == "proximityEnabled" then
        local p = settings()
        if p.proximityEnabled and not anyZone(p) then
            local zoned = false
            for index = 1, #ZONES_FROM_ALERTS do
                local pair = ZONES_FROM_ALERTS[index]
                if p[pair[1]] then
                    self:SetSetting(pair[2], true)
                    zoned = true
                end
            end
            if not zoned then self:SetSetting("proximityWorld", true) end
        end
        self:Refresh()
    elseif changedKey == nil or changedKey == "proximityMaxBand" then
        self:Refresh()
    end
end

SA_Modules.Register({ key = "Proximity", module = Proximity, flat = PROXIMITY_SETTINGS, title = "Proximity", enabled = { "proximityEnabled" } })

SA_Modules.Register({ key = "ProximityToasts", module = ProximityToasts, db = "proximityToasts", title = "Toasts", enabled = { "enabled" }, profile = SwitchProfile })
