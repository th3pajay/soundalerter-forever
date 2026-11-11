local SoundAlerter = SoundAlerter
local Model = SoundAlerter.MinimapButtonModel
local MinimapButton = {}

local BUTTON_SIZE = 24
local INITIAL_X = 5
local INITIAL_Y = -5
local ICON_TINT = { 0.5, 1.0, 1.0 }

local button

local function profile()
    return SoundAlerter.db1.profile
end

local function state()
    local current = profile()
    return {
        proximity = current.proximityEnabled and true or false,
        battleground = current.battlegroundAlertsEnabled and true or false,
        snoozed = SA_Actions.Snoozed(),
    }
end

function MinimapButton:GetSettings()
    return profile().minimapButton
end

function MinimapButton:SetSetting(key, value)
    if not Model.Assign(self:GetSettings(), key, value) then
        error("MinimapButton:SetSetting - bad setting '" .. tostring(key) .. "'", 2)
    end
end

function MinimapButton:UpdateIcon()
    if not button or not button.icon then return end
    local current = profile()
    local slot = Model.Slot(current.proximityEnabled, current.battlegroundAlertsEnabled)
    local path = Model.IconPath(Model.Icon(current.minimapButton.icons, slot))
    if button.iconPath == path then return end
    button.iconPath = path
    button.icon:SetTexture(path)
    button.icon:SetVertexColor(ICON_TINT[1], ICON_TINT[2], ICON_TINT[3])
end

function MinimapButton:Run(action, owner)
    if action == "menu" then
        self:ShowMenu(owner)
        return
    end
    SA_Actions.Run(action)
end

function MinimapButton:Click(buttonName, modifier, owner)
    local action = Model.Resolve(self:GetSettings().clicks, modifier, buttonName)
    if action then self:Run(action, owner) end
    return action
end

function MinimapButton:ShowMenu(owner)
    owner = owner or button
    if not (MenuUtil and MenuUtil.CreateContextMenu and owner) then
        SoundAlerter:Print("The quick menu is not available on this client; opening the options instead.")
        SoundAlerter:ShowConfig()
        return
    end
    local rows = {
        { "Proximity alerts", function() return profile().proximityEnabled end, "proximity" },
        { "Battleground alerts", function() return profile().battlegroundAlertsEnabled end, "battleground" },
        { "Snoozed", SA_Actions.Snoozed, "snooze" },
        { "Chat alerts", function() return profile().chatalerts end, "chat" },
        { "Notices", function() return SoundAlerter.Notices and SoundAlerter.Notices.db and SoundAlerter.Notices.db.enabled end, "notices" },
        { "Bars locked", function() local _, states = SA_Actions.Lockable() return not Model.AnyUnlocked(states) end, "lockbars" },
    }
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("SoundAlerter")
        for _, row in ipairs(rows) do
            root:CreateCheckbox(row[1], function() return row[2]() and true or false end, function() MinimapButton:Run(row[3]) end)
        end
        root:CreateDivider()
        root:CreateButton("Open options", function() SoundAlerter:ShowConfig() end)
    end)
end

function MinimapButton:CreateAnimations()
    if not button then return end

    button.hoverAnimGroup = button:CreateAnimationGroup()
    button.hoverAnimGroup:SetLooping("NONE")
    local hoverScale = button.hoverAnimGroup:CreateAnimation("Scale")
    hoverScale:SetScale(1.05, 1.05)
    hoverScale:SetDuration(0.15)
    hoverScale:SetSmoothing("OUT")

    button.unhoverAnimGroup = button:CreateAnimationGroup()
    button.unhoverAnimGroup:SetLooping("NONE")
    local unhoverScale = button.unhoverAnimGroup:CreateAnimation("Scale")
    unhoverScale:SetScale(0.952, 0.952)
    unhoverScale:SetDuration(0.15)
    unhoverScale:SetSmoothing("OUT")

    button.pressAnimGroup = button:CreateAnimationGroup()
    button.pressAnimGroup:SetLooping("NONE")
    local pressScale = button.pressAnimGroup:CreateAnimation("Scale")
    pressScale:SetScale(0.905, 0.905)
    pressScale:SetDuration(0.05)

    button.releaseAnimGroup = button:CreateAnimationGroup()
    button.releaseAnimGroup:SetLooping("NONE")
    local releaseScale = button.releaseAnimGroup:CreateAnimation("Scale")
    releaseScale:SetScale(1.105, 1.105)
    releaseScale:SetDuration(0.1)
    releaseScale:SetSmoothing("OUT")
end

local TOOLTIP_COLORS = {
    title = { 1, 0.82, 0 },
    first = { 1, 1, 1 },
    row = { 0.8, 0.8, 0.8 },
    hint = { 0.6, 0.6, 0.6 },
    state = { 1, 0.82, 0 },
}

function MinimapButton:ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    for _, line in ipairs(Model.TooltipLines(self:GetSettings().clicks, state())) do
        local color = TOOLTIP_COLORS[line[2]]
        GameTooltip:AddLine(line[1], color[1], color[2], color[3])
    end
    GameTooltip:Show()
end

function MinimapButton:OnEnter()
    self:ShowTooltip(button)

    button.unhoverAnimGroup:Stop()
    button.hoverAnimGroup:Play()
    button.border:SetVertexColor(0.0, 0.8, 0.8, 1.0)
    UIFrameFadeIn(button.highlight, 0.15, button.highlight:GetAlpha(), 0.3)
end

function MinimapButton:OnLeave()
    GameTooltip:Hide()
    button.hoverAnimGroup:Stop()
    button.unhoverAnimGroup:Play()
    button.border:SetVertexColor(0.5, 0.5, 0.5, 0.8)
    UIFrameFadeOut(button.highlight, 0.15, button.highlight:GetAlpha(), 0)
end

function MinimapButton:OnMouseDown()
    button.releaseAnimGroup:Stop()
    button.pressAnimGroup:Play()
    button.icon:SetVertexColor(0.425, 0.85, 0.85)
    button.border:SetVertexColor(1.0, 1.0, 1.0, 1.0)

    local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
    button.originalOffset = { point, relativeTo, relativePoint, x, y }
    button:ClearAllPoints()
    button:SetPoint(point, relativeTo, relativePoint, x + 1, y - 1)
end

function MinimapButton:OnMouseUp()
    button.pressAnimGroup:Stop()
    button.releaseAnimGroup:Play()
    button.icon:SetVertexColor(ICON_TINT[1], ICON_TINT[2], ICON_TINT[3])
    button.border:SetVertexColor(0.0, 0.8, 0.8, 1.0)

    if button.originalOffset then
        local point, relativeTo, relativePoint, x, y = unpack(button.originalOffset)
        button:ClearAllPoints()
        button:SetPoint(point, relativeTo, relativePoint, x, y)
        button.originalOffset = nil
    end
end

function MinimapButton:OnClick(mouseButton, owner)
    local modifier = Model.Modifier(IsShiftKeyDown(), IsControlKeyDown(), IsAltKeyDown())
    local buttonName = Model.ButtonName(mouseButton)
    if buttonName then self:Click(buttonName, modifier, owner) end
end

function SoundAlerter_OnAddonCompartmentClick(_, mouseButton)
    MinimapButton:OnClick(mouseButton, AddonCompartmentFrame)
end

function SoundAlerter_OnAddonCompartmentEnter(_, menuButton)
    MinimapButton:ShowTooltip(menuButton or AddonCompartmentFrame)
end

function SoundAlerter_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

function MinimapButton:OnDragStop()
    button:StopMovingOrSizing()
    local minimapX, minimapY = Minimap:GetCenter()
    local buttonX, buttonY = button:GetCenter()
    profile().MinimapButtonPosition = { x = buttonX - minimapX, y = buttonY - minimapY }
end

function MinimapButton:Create()
    local db = profile()

    button = CreateFrame("Button", "SoundAlerterMinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    button.border:SetSize(BUTTON_SIZE + 4, BUTTON_SIZE + 4)
    button.border:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.border:SetVertexColor(0.5, 0.5, 0.5, 0.8)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.highlight:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button.highlight:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.highlight:SetBlendMode("ADD")
    button.highlight:SetVertexColor(0.0, 0.8, 0.8)
    button.highlight:SetAlpha(0)

    self:CreateAnimations()

    button:SetScript("OnEnter", function() MinimapButton:OnEnter() end)
    button:SetScript("OnLeave", function() MinimapButton:OnLeave() end)
    button:SetScript("OnMouseDown", function() MinimapButton:OnMouseDown() end)
    button:SetScript("OnMouseUp", function() MinimapButton:OnMouseUp() end)
    button:SetScript("OnClick", function(_, mouseButton) MinimapButton:OnClick(mouseButton) end)
    button:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
    button:SetScript("OnDragStop", function() MinimapButton:OnDragStop() end)

    if db.MinimapButtonPosition then
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", db.MinimapButtonPosition.x, db.MinimapButtonPosition.y)
    else
        button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", INITIAL_X, INITIAL_Y)
    end

    if db.MinimapButtonHidden then
        button:Hide()
    else
        button:Show()
    end

    self:UpdateIcon()
end

function SoundAlerter:CreateMinimapButton()
    MinimapButton:Create()
end

function SoundAlerter:UpdateMinimapButtonIcon()
    MinimapButton:UpdateIcon()
end

local Preview = { height = 56 }

function Preview.build(stage)
    local view = { icons = {} }
    for index = 1, #Model.SLOTS do
        local texture = stage:CreateTexture(nil, "ARTWORK")
        texture:SetSize(32, 32)
        texture:SetPoint("LEFT", stage, "LEFT", (index - 1) * 44, 0)
        view.icons[index] = texture
    end
    return view
end

function Preview.update(view, settings)
    if not view then return end
    for index, slot in ipairs(Model.SLOTS) do
        view.icons[index]:SetTexture(Model.IconPath(Model.Icon(settings.icons, slot[1])))
        view.icons[index]:SetVertexColor(ICON_TINT[1], ICON_TINT[2], ICON_TINT[3])
    end
end

local GROUPS = { none = "Plain clicks", shift = "Shift clicks", ctrl = "Ctrl clicks", alt = "Alt clicks" }

local function module()
    return SoundAlerter.MinimapButton
end

local function write(active, key, value)
    active:SetSetting(key, value)
    active:UpdateIcon()
end

local function summary(settings)
    local Page = SoundAlerter.Page
    local assigned = 0
    for _, modifier in ipairs(Model.MODIFIERS) do
        for _, buttonName in ipairs(Model.BUTTONS) do
            if Model.Resolve(settings.clicks, modifier, buttonName) then assigned = assigned + 1 end
        end
    end
    return Page.Summary(settings, assigned .. " of 12 clicks assigned")
end

function SoundAlerter:BuildMinimapButtonOptions()
    local Page = SoundAlerter.Page
    local rows = {}
    for _, modifier in ipairs(Model.MODIFIERS) do
        for _, buttonName in ipairs(Model.BUTTONS) do
            local label = Model.ClickLabel(modifier, buttonName)
            rows[#rows + 1] = Page.Select("clicks." .. modifier .. "." .. buttonName, label, "What " .. label:lower() .. " on the minimap button does. The tooltip lists every assigned click.", Model.ActionOptions(), false, GROUPS[modifier])
        end
    end
    rows[#rows + 1] = Page.Visible(function(settings) return not Model.CanOpenOptions(settings.clicks) end,
        Page.Block("Nothing opens the options", function() return "No click opens the options or the quick menu, so the button cannot open this window. /sa still works." end, false, "Plain clicks"))
    for _, slot in ipairs(Model.SLOTS) do
        rows[#rows + 1] = Page.Select("icons." .. slot[1], slot[2], "Icon shown on the minimap button when " .. slot[2]:lower() .. ".", Model.IconOptions(slot[1]), false, "Icons")
    end
    return Page.Module({
        key = "MinimapButton",
        title = "Minimap Button",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        desc = "Choose what each click on the minimap button does and which icon it shows for each proximity and battleground state.",
        blurb = "Every combination of Shift, Ctrl, Alt and the left, right and middle buttons can run an action. The icon follows proximity and battleground alerts, and the tooltip always lists what is assigned.",
        order = 2.2,
        master = false,
        module = module,
        write = write,
        defaults = function() return dbDefaults.profile.minimapButton end,
        summary = summary,
        preview = Preview,
        rows = rows,
    })
end

SoundAlerter.MinimapButton = MinimapButton
