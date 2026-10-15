SA_WindowSkin = {}

local Skin = SA_WindowSkin

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local HEADER_TEXTURE = 131080

local COLOR = {
    window = { 0.059, 0.071, 0.094, 0.98 },
    panel = { 0.09, 0.11, 0.145, 1 },
    line = { 0.165, 0.196, 0.251, 1 },
    accent = { 1, 0.49, 0.04 },
    text = { 0.906, 0.918, 0.941 },
    muted = { 0.588, 0.627, 0.698 },
}

local BACKDROP = {
    bgFile = FLAT,
    edgeFile = FLAT,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function try(fn, ...)
    local ok = pcall(fn, ...)
    return ok
end

local function flatBackdrop(frame, background, border)
    if not (frame and frame.SetBackdrop) then return end
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(background[1], background[2], background[3], background[4] or 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function hideTextures(object)
    if not object or not object.GetRegions then return end
    for _, region in ipairs({ object:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
end

local function flattenButton(button)
    if not button then return end
    hideTextures(button)
    for _, name in ipairs({ "Left", "Middle", "Right", "Center" }) do
        local piece = button[name]
        if piece and piece.SetAlpha then piece:SetAlpha(0) end
    end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        if button[getter] then
            local texture = button[getter](button)
            if texture and texture.SetAlpha then texture:SetAlpha(0) end
        end
    end
    if not button.saFill then
        local fill = button:CreateTexture(nil, "BACKGROUND")
        fill:SetTexture(FLAT)
        fill:SetVertexColor(COLOR.line[1], COLOR.line[2], COLOR.line[3], 1)
        fill:SetAllPoints(button)
        button.saFill = fill
        button:HookScript("OnEnter", function() fill:SetVertexColor(COLOR.accent[1], COLOR.accent[2], COLOR.accent[3], 0.6) end)
        button:HookScript("OnLeave", function() fill:SetVertexColor(COLOR.line[1], COLOR.line[2], COLOR.line[3], 1) end)
    end
    local label = button.GetFontString and button:GetFontString()
    if label then label:SetTextColor(COLOR.text[1], COLOR.text[2], COLOR.text[3]) end
end

local function skinTreeButtons(tree)
    for _, button in ipairs(tree.buttons or {}) do
        if button.text and button.text.SetTextColor then
            if button.selected then
                button.text:SetTextColor(COLOR.accent[1], COLOR.accent[2], COLOR.accent[3])
            else
                button.text:SetTextColor(COLOR.text[1], COLOR.text[2], COLOR.text[3])
            end
        end
    end
end

local function skinTree(tree)
    if tree.saSkinned then return end
    tree.saSkinned = true
    try(flatBackdrop, tree.treeframe, COLOR.panel, COLOR.line)
    try(flatBackdrop, tree.border, COLOR.window, COLOR.line)
    if tree.RefreshTree and hooksecurefunc then
        try(hooksecurefunc, tree, "RefreshTree", function() try(skinTreeButtons, tree) end)
    end
    try(skinTreeButtons, tree)
end

function Skin.Apply(widget)
    if type(widget) ~= "table" or not widget.frame then return false end
    local frame = widget.frame

    if not widget.saSkinned then
        widget.saSkinned = true
        try(flatBackdrop, frame, COLOR.window, COLOR.line)

        try(function()
            for _, region in ipairs({ frame:GetRegions() }) do
                if region.IsObjectType and region:IsObjectType("Texture") then
                    local texture = region:GetTexture()
                    if texture == HEADER_TEXTURE or (type(texture) == "string" and texture:find("UI%-DialogBox%-Header")) then
                        region:SetAlpha(0)
                    end
                end
            end
        end)

        try(function()
            if widget.titletext then
                widget.titletext:ClearAllPoints()
                widget.titletext:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -9)
                widget.titletext:SetFont(FONT, 14, "")
                widget.titletext:SetTextColor(COLOR.accent[1], COLOR.accent[2], COLOR.accent[3])
            end
        end)

        try(function()
            for _, child in ipairs({ frame:GetChildren() }) do
                if child.IsObjectType and child:IsObjectType("Button") then
                    if child.GetText and child:GetText() == CLOSE then
                        try(flattenButton, child)
                    elseif child.SetBackdropColor then
                        try(flatBackdrop, child, COLOR.panel, COLOR.line)
                    end
                end
            end
        end)

        try(function()
            if widget.statustext then widget.statustext:SetTextColor(COLOR.muted[1], COLOR.muted[2], COLOR.muted[3]) end
        end)
    end

    for _, child in ipairs(widget.children or {}) do
        if child.type == "TreeGroup" then skinTree(child) end
    end
    return true
end

function Skin.Remove(widget)
    return widget ~= nil
end
