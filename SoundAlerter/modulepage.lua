local SoundAlerter = SoundAlerter
local AceGUI = LibStub("AceGUI-3.0")

local Page = {}

local WIDGET = "SoundAlerterModulePage"
local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local PAGE_HEIGHT = 560
local HEADER_HEIGHT = 84
local RIGHT_WIDTH = 280
local ROW_WITH_HINT = 40
local ROW_PLAIN = 28
local SCROLL_STEP = 48

local COLOR = {
    card = { 0.09, 0.11, 0.145 },
    track = { 0.227, 0.263, 0.322 },
    line = { 0.165, 0.196, 0.251 },
    accent = { 1, 0.49, 0.04 },
    text = { 0.906, 0.918, 0.941 },
    muted = { 0.588, 0.627, 0.698 },
    on = { 0.239, 0.863, 0.592 },
    knob = { 0.95, 0.95, 0.95 },
    experimental = { 0.06, 0.12, 0.32 },
}

local cache = setmetatable({}, { __mode = "k" })

local function Paint(frame, color, alpha, layer)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetTexture(FLAT)
    texture:SetVertexColor(color[1], color[2], color[3], alpha or 1)
    return texture
end

local function Outline(frame, color)
    local top = Paint(frame, color, 1, "BORDER")
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    top:SetHeight(1)
    local bottom = Paint(frame, color, 1, "BORDER")
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)
    local left = Paint(frame, color, 1, "BORDER")
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    left:SetWidth(1)
    local right = Paint(frame, color, 1, "BORDER")
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)
end

local function Text(parent, size, color, justify)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, size, "")
    label:SetTextColor(color[1], color[2], color[3])
    label:SetJustifyH(justify or "LEFT")
    if label.SetWordWrap then label:SetWordWrap(false) end
    return label
end

local function Digits(step)
    local fraction = tostring(step):match("%.(%d+)")
    return fraction and #fraction or 0
end

local function Format(row, value)
    return string.format("%." .. Digits(row.step) .. "f", value) .. (row.unit or "")
end

local function Snap(row, value)
    local snapped = math.floor((value - row.min) / row.step + 0.5) * row.step + row.min
    return tonumber(string.format("%.4f", math.max(row.min, math.min(row.max, snapped))))
end

local function Resolve(settings, path)
    local value = settings
    for part in tostring(path):gmatch("[^.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
    end
    return value
end

Page.Resolve = Resolve

local function Row(kind, key, label, hint, advanced, group)
    return { kind = kind, key = key, label = label, hint = hint or "", advanced = advanced and true or false, group = group or "General" }
end

function Page.Toggle(key, label, hint, advanced, group)
    return Row("toggle", key, label, hint, advanced, group)
end

function Page.Range(key, label, hint, min, max, step, advanced, group, unit)
    local row = Row("range", key, label, hint, advanced, group)
    row.min, row.max, row.step, row.unit = min, max, step, unit or ""
    return row
end

function Page.Color(key, label, hint, advanced, group)
    return Row("color", key, label, hint, advanced, group)
end

function Page.Select(key, label, hint, options, advanced, group)
    local row = Row("select", key, label, hint, advanced, group)
    row.options = options
    return row
end

function Page.Action(label, hint, onClick, advanced, group)
    local row = Row("action", nil, label, hint, advanced, group)
    row.onClick = onClick
    return row
end

function Page.Text(key, label, hint, advanced, group, lines)
    local row = Row("text", key, label, hint, advanced, group)
    row.lines = lines or 1
    return row
end

function Page.Block(label, text, advanced, group)
    local row = Row("block", nil, label, "", advanced, group)
    row.text = text
    return row
end

function Page.Visible(predicate, row)
    row.visible = predicate
    return row
end

function Page.Playable(row, onPlay)
    row.play = onPlay
    return row
end

function Page.Selectable(row, onSelect, selected)
    row.onSelect = onSelect
    row.selected = selected
    return row
end

function Page.When(key, row)
    row.requires = key
    return row
end

function Page.Experimental(row)
    row.experimental = true
    return row
end

function Page.Spec(spec)
    return spec
end

function Page.Options(spec, name, icon, desc, order, fallback)
    return {
        type = 'group',
        name = name,
        icon = icon,
        desc = desc,
        order = order,
        args = {
            page = {
                type = 'description',
                name = fallback or (name .. " could not draw its page."),
                dialogControl = WIDGET,
                arg = spec,
                order = 1,
            },
        },
    }
end

function Page.Summary(settings, ...)
    local parts = {}
    if type(settings.enabled) == "boolean" then parts[1] = settings.enabled and "|cff3ddc97On|r" or "Off" end
    for index = 1, select("#", ...) do
        local part = select(index, ...)
        if part and part ~= "" then parts[#parts + 1] = part end
    end
    return table.concat(parts, " · ")
end

function Page.Guard(options, title, key, available)
    options.args.initErrorWarning = {
        type = 'description',
        name = function()
            return "|cffFF0000" .. title .. " failed to initialize this session:|r\n" ..
                   tostring(SoundAlerter.moduleInitErrors and SoundAlerter.moduleInitErrors[key]) ..
                   "\n\n|cffFFFFFFThe page below will not work until this is fixed and you /reload.|r\n"
        end,
        fontSize = "medium",
        order = 0.5,
        hidden = function() return available() ~= nil end,
    }
    return options
end

function Page.Module(config)
    local spec = Page.Spec({
        title = config.title,
        icon = config.icon,
        blurb = config.blurb,
        get = function()
            local active = config.module()
            return active and active:GetSettings()
        end,
        set = function(key, value)
            local active = config.module()
            if not active then return end
            if config.write then config.write(active, key, value) else active:SetSetting(key, value) end
        end,
        master = config.master,
        defaults = config.defaults,
        summary = function(settings) return config.summary(settings, config.module()) end,
        preview = config.preview,
        rows = config.rows,
    })
    local options = Page.Options(spec, config.title, config.icon, config.desc, config.order)
    Page.Guard(options, config.title, config.key, config.module)
    return options
end

local function MakeScrollbar(parent, onChange, inset, topInset)
    local strip = CreateFrame("Button", nil, parent)
    strip:SetWidth(10)
    strip:SetPoint("TOPRIGHT", parent, "TOPRIGHT", inset or 0, -(topInset or 0))
    strip:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", inset or 0, 0)
    strip:SetFrameLevel(parent:GetFrameLevel() + 20)
    local thumb = Paint(strip, COLOR.track, 1, "OVERLAY")
    thumb:SetWidth(4)
    local bar = { strip = strip, thumb = thumb, fraction = 0, size = 24 }

    local function clamp(value)
        return math.max(0, math.min(1, value))
    end

    local function cursor()
        local _, y = GetCursorPosition()
        return y / strip:GetEffectiveScale()
    end

    function bar:Update(fraction, ratio)
        local visible = ratio < 1
        strip:SetShown(visible)
        if not visible then return end
        local track = strip:GetHeight()
        self.size = math.max(24, track * ratio)
        self.fraction = clamp(fraction)
        thumb:SetHeight(self.size)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -3, -(track - self.size) * self.fraction)
    end

    local function stop()
        strip:SetScript("OnUpdate", nil)
    end

    strip:SetScript("OnMouseDown", function(_, button)
        if button and button ~= "LeftButton" then return end
        local travel = strip:GetHeight() - bar.size
        if travel <= 0 then return end
        local y = cursor()
        local thumbTop = strip:GetTop() - travel * bar.fraction
        if y > thumbTop or y < thumbTop - bar.size then
            bar.fraction = clamp((strip:GetTop() - y - bar.size / 2) / travel)
            onChange(bar.fraction)
        end
        local startY, startFraction = y, bar.fraction
        strip:SetScript("OnUpdate", function()
            onChange(clamp(startFraction + (startY - cursor()) / travel))
        end)
    end)
    strip:SetScript("OnMouseUp", stop)
    strip:SetScript("OnHide", stop)
    return bar
end

local function MakeToggle(parent, onChange)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(36, 18)
    local track = Paint(button, COLOR.track)
    track:SetAllPoints(button)
    local knob = Paint(button, COLOR.knob, 1, "ARTWORK")
    knob:SetSize(14, 14)
    local control = { frame = button }
    function control:Set(value)
        self.value = value and true or false
        local color = self.value and COLOR.on or COLOR.track
        track:SetVertexColor(color[1], color[2], color[3], 1)
        SA_MenuFX.Glide(knob, button, self.value and 20 or 2, self.animate)
    end
    button:SetScript("OnClick", function()
        control.animate = true
        onChange(not control.value)
        control.animate = false
    end)
    control:Set(false)
    return control
end

local function MakeRange(parent, row, onChange)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(210, 22)
    local slider = CreateFrame("Slider", nil, holder)
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("LEFT", holder, "LEFT", 0, 0)
    slider:SetSize(150, 14)
    slider:SetMinMaxValues(row.min, row.max)
    slider:SetValueStep(row.step)
    local track = Paint(slider, COLOR.track)
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(4)
    slider:SetThumbTexture(FLAT)
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(8, 14)
    thumb:SetVertexColor(COLOR.accent[1], COLOR.accent[2], COLOR.accent[3], 1)
    local readout = Text(holder, 11, COLOR.muted, "RIGHT")
    readout:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    readout:SetWidth(52)
    local control = { frame = holder, slider = slider, readout = readout }
    slider:SetScript("OnValueChanged", function(_, value)
        if control.updating then return end
        local snapped = Snap(row, value)
        readout:SetText(Format(row, snapped))
        onChange(snapped)
    end)
    function control:Set(value)
        self.updating = true
        slider:SetValue(value)
        readout:SetText(Format(row, value))
        self.updating = false
    end
    return control
end

local function OpenColorPicker(color, onChange)
    local r, g, b = color.r, color.g, color.b
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function() onChange(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function() onChange(r, g, b) end,
        })
        return
    end
    ColorPickerFrame.func = function() onChange(ColorPickerFrame:GetColorRGB()) end
    ColorPickerFrame.cancelFunc = function() onChange(r, g, b) end
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.previousValues = { r, g, b }
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
end

local function MakeColor(parent, onChange)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(34, 20)
    local swatch = Paint(button, COLOR.text)
    swatch:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    swatch:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    Outline(button, COLOR.muted)
    local control = { frame = button, value = { r = 1, g = 1, b = 1 } }
    function control:Set(value)
        self.value = value
        swatch:SetVertexColor(value.r, value.g, value.b, 1)
    end
    button:SetScript("OnClick", function()
        OpenColorPicker(control.value, function(r, g, b) onChange({ r = r, g = g, b = b }) end)
    end)
    return control
end

local TEXT_LINE = 15
local TEXT_BAR = 12

local function MakeMultiText(parent, lines, onChange)
    local viewHeight = lines * TEXT_LINE + 10
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(380, viewHeight)
    local fill = Paint(holder, COLOR.line)
    fill:SetAllPoints(holder)

    local scroll = CreateFrame("ScrollFrame", nil, holder)
    scroll:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -TEXT_BAR, 0)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetAutoFocus(false)
    box:SetFont(FONT, 12, "")
    box:SetTextInsets(6, 6, 3, 3)
    box:SetMultiLine(true)
    box:SetSize(380 - TEXT_BAR, viewHeight)
    scroll:SetScrollChild(box)
    scroll:EnableMouseWheel(true)

    local measure = Text(holder, 12, COLOR.text)
    measure:SetWordWrap(true)
    measure:SetWidth(380 - TEXT_BAR - 12)
    measure:Hide()

    local bar
    local function range()
        return math.max(0, box:GetHeight() - viewHeight)
    end
    local function sync()
        local span = range()
        local offset = math.max(0, math.min(span, scroll:GetVerticalScroll()))
        scroll:SetVerticalScroll(offset)
        bar:Update(span > 0 and offset / span or 0, span > 0 and viewHeight / box:GetHeight() or 1)
    end
    local function resize()
        box:SetHeight(math.max(viewHeight, measure:GetStringHeight() + 6))
        sync()
    end
    bar = MakeScrollbar(holder, function(fraction)
        scroll:SetVerticalScroll(fraction * range())
        sync()
    end, 0)

    holder:SetScript("OnSizeChanged", function(_, width)
        local inner = math.max(1, width - TEXT_BAR)
        box:SetWidth(inner)
        measure:SetWidth(math.max(1, inner - 12))
        resize()
    end)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        scroll:SetVerticalScroll(math.max(0, math.min(range(), scroll:GetVerticalScroll() - delta * TEXT_LINE * 3)))
        sync()
    end)
    box:SetScript("OnTextChanged", function(self)
        measure:SetText(self:GetText())
        resize()
    end)
    box:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local top = -y
        local offset = scroll:GetVerticalScroll()
        if top < offset then
            scroll:SetVerticalScroll(top)
        elseif top + height > offset + viewHeight then
            scroll:SetVerticalScroll(top + height - viewHeight)
        end
        sync()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self) onChange(self:GetText()) end)

    local control = { frame = holder, box = box, bar = bar }
    function control:Set(value)
        if box:HasFocus() or box:GetText() == (value or "") then return end
        box:SetText(value or "")
        scroll:SetVerticalScroll(0)
        sync()
    end
    return control
end

local function MakeText(parent, row, onChange)
    if (row.lines or 1) > 1 then return MakeMultiText(parent, row.lines, onChange) end
    local box = CreateFrame("EditBox", nil, parent)
    box:SetAutoFocus(false)
    box:SetFont(FONT, 12, "")
    box:SetTextInsets(6, 6, 3, 3)
    box:SetMultiLine(false)
    box:SetSize(190, 22)
    local fill = Paint(box, COLOR.line)
    fill:SetAllPoints(box)
    local control = { frame = box }
    function control:Set(value)
        if box:HasFocus() then return end
        box:SetText(value or "")
    end
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self) onChange(self:GetText()) end)
    return control
end

local function MakeButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(22)
    local fill = Paint(button, COLOR.line)
    fill:SetAllPoints(button)
    local label = Text(button, 12, COLOR.text, "CENTER")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    label:SetText(text)
    button:SetWidth(math.max(70, label:GetStringWidth() + 24))
    button:SetScript("OnClick", onClick)
    SA_MenuFX.Press(button, fill, label)
    return { frame = button, label = label }
end

local function MakePlay(parent, onPlay)
    local control = MakeButton(parent, "Play", nil)
    local button, label = control.frame, control.label
    button:SetSize(54, 18)
    local press = 0
    button:SetScript("OnClick", function()
        press = press + 1
        if onPlay() ~= false then return end
        local mine = press
        label:SetText("No file")
        label:SetTextColor(1, 0.65, 0.2)
        if C_Timer and C_Timer.After then
            C_Timer.After(2, function()
                if press ~= mine then return end
                label:SetText("Play")
                label:SetTextColor(COLOR.text[1], COLOR.text[2], COLOR.text[3])
            end)
        end
    end)
    return button, label
end

local function MakeStepper(parent, row, onChange)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(210, 22)
    local control = { frame = holder, options = {}, index = 1 }
    local function arrow(side, symbol, direction)
        local button = CreateFrame("Button", nil, holder)
        button:SetSize(22, 22)
        button:SetPoint(side, holder, side, 0, 0)
        local fill = Paint(button, COLOR.line)
        fill:SetAllPoints(button)
        local label = Text(button, 13, COLOR.text, "CENTER")
        label:SetPoint("CENTER", button, "CENTER", 0, 0)
        label:SetText(symbol)
        button:SetScript("OnClick", function()
            local count = #control.options
            if count == 0 then return end
            local target = (control.index - 1 + direction) % count + 1
            onChange(control.options[target][1])
        end)
        SA_MenuFX.Press(button, fill, label)
        return button
    end
    arrow("LEFT", "<", -1)
    arrow("RIGHT", ">", 1)
    local name = Text(holder, 12, COLOR.text, "CENTER")
    name:SetPoint("LEFT", holder, "LEFT", 26, 0)
    name:SetPoint("RIGHT", holder, "RIGHT", -26, 0)
    control.name = name
    function control:SetOptions(options)
        self.options = options
    end
    function control:Set(value)
        for index = 1, #self.options do
            if self.options[index][1] == value then
                self.index = index
                self.name:SetText(self.options[index][2])
                return
            end
        end
        self.name:SetText(tostring(value))
    end
    local options = row.options
    if type(options) == "function" then options = options({}) end
    control:SetOptions(options or {})
    return control
end

local function MakeSelect(parent, row, onChange)
    local holder = CreateFrame("Frame", nil, parent)
    local buttons = {}
    local control = { frame = holder, buttons = buttons, count = 0 }
    local function acquire(index)
        local entry = buttons[index]
        if entry then return entry end
        local button = CreateFrame("Button", nil, holder)
        local fill = Paint(button, COLOR.line)
        fill:SetAllPoints(button)
        local label = Text(button, 11.5, COLOR.text, "CENTER")
        label:SetPoint("CENTER", button, "CENTER", 0, 0)
        entry = { frame = button, fill = fill, label = label }
        button:SetScript("OnClick", function() onChange(entry.value) end)
        SA_MenuFX.Press(button, fill, label)
        buttons[index] = entry
        return entry
    end
    function control:SetOptions(options)
        local parts = {}
        for index = 1, #options do parts[index] = tostring(options[index][1]) .. ":" .. tostring(options[index][2]) end
        local signature = table.concat(parts, "|")
        if signature == self.signature then return end
        self.signature = signature
        local width = 0
        for index = 1, #options do
            local entry = acquire(index)
            entry.value = options[index][1]
            entry.label:SetText(options[index][2])
            local buttonWidth = math.max(44, entry.label:GetStringWidth() + 18)
            entry.frame:SetSize(buttonWidth, 20)
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint("LEFT", holder, "LEFT", width, 0)
            entry.frame:Show()
            width = width + buttonWidth + 2
        end
        for index = #options + 1, #buttons do buttons[index].frame:Hide() end
        self.count = #options
        holder:SetSize(math.max(1, width), 20)
    end
    function control:Set(value)
        for index = 1, self.count do
            local button = buttons[index]
            local selected = button.value == value
            local color = selected and COLOR.accent or COLOR.line
            button.fill:SetVertexColor(color[1], color[2], color[3], 1)
            local textColor = selected and { 0.1, 0.07, 0.02 } or COLOR.text
            button.label:SetTextColor(textColor[1], textColor[2], textColor[3])
        end
    end
    local options = row.options
    if type(options) == "function" then options = options({}) end
    control:SetOptions(options or {})
    return control
end

local function Hue(position)
    local sector = (position % 1) * 6
    local index = math.floor(sector)
    local fraction = sector - index
    local steps = {
        { 1, fraction, 0 }, { 1 - fraction, 1, 0 }, { 0, 1, fraction },
        { 0, 1 - fraction, 1 }, { fraction, 0, 1 }, { 1, 0, 1 - fraction },
    }
    local color = steps[index % 6 + 1]
    return color[1], color[2], color[3]
end

Page.Toast = {}

function Page.Toast.Build(stage, index)
    local toast = { edges = {} }
    local frame = CreateFrame("Frame", nil, stage)
    frame:SetSize(236, 38)
    frame:SetPoint("TOP", stage, "TOP", 0, -((index - 1) * 44))
    toast.frame = frame
    toast.fill = Paint(frame, COLOR.card)
    toast.fill:SetAllPoints(frame)
    for edge = 1, 4 do toast.edges[edge] = Paint(frame, COLOR.accent, 1, "BORDER") end
    toast.edges[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    toast.edges[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    toast.edges[1]:SetHeight(2)
    toast.edges[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    toast.edges[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    toast.edges[2]:SetHeight(2)
    toast.edges[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    toast.edges[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    toast.edges[3]:SetWidth(2)
    toast.edges[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    toast.edges[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    toast.edges[4]:SetWidth(2)
    toast.icon = frame:CreateTexture(nil, "ARTWORK")
    toast.icon:SetSize(28, 28)
    toast.icon:SetPoint("LEFT", frame, "LEFT", 6, 0)
    toast.name = Text(frame, 12.5, COLOR.text)
    toast.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, -6)
    toast.sub = Text(frame, 10.5, COLOR.muted)
    toast.sub:SetPoint("TOPLEFT", toast.name, "BOTTOMLEFT", 0, -2)
    return toast
end

function Page.Toast.Update(toast, options)
    local background = options.background or { 0.05, 0.06, 0.08, 0.95 }
    toast.fill:SetVertexColor(background[1], background[2], background[3], background[4] or 1)
    toast.icon:SetTexture(options.icon or "Interface\\Icons\\Ability_Stealth")
    toast.icon:SetShown(options.showIcon ~= false)
    toast.name:ClearAllPoints()
    toast.name:SetPoint("TOPLEFT", toast.frame, "TOPLEFT", options.showIcon == false and 8 or 40, -6)
    toast.name:SetText(options.name or "")
    local color = options.nameColor or COLOR.text
    toast.name:SetTextColor(color[1], color[2], color[3])
    toast.sub:SetText(options.sub or "")
    toast.rainbow = options.rainbow and true or false
    local border = options.border or COLOR.accent
    for edge = 1, 4 do toast.edges[edge]:SetVertexColor(border[1], border[2], border[3], 1) end
    toast.frame:SetShown(options.shown ~= false)
end

function Page.Toast.Tick(toast, seconds)
    if not toast.rainbow then return end
    local r, g, b = Hue(seconds * 0.25)
    for edge = 1, 4 do toast.edges[edge]:SetVertexColor(r, g, b, 1) end
end

local Methods = {}

function Methods:SetInfo(row)
    if not row then
        self.infoTitle:SetText("Hover or focus a setting")
        self.infoBody:SetText("Its description shows here, next to the preview, so you never have to leave the page to understand it.")
        return
    end
    local title = row.label
    if type(title) == "function" then title = title(self.settings or {}) end
    self.infoTitle:SetText(title)
    local body = row.hint ~= "" and row.hint or "No extra description for this one."
    if row.advanced then body = body .. "\n\n|cff96a0b2Advanced setting|r" end
    self.infoBody:SetText(body)
end

function Methods:Change(key, value)
    self.spec.set(key, value)
    self:Refresh()
    for index = 1, #self.rows do
        local entry = self.rows[index]
        if entry.spec.key == key then
            SA_MenuFX.Flash(entry.flash)
            break
        end
    end
end

function Methods:Reset()
    local defaults = self.spec.defaults and self.spec.defaults()
    if not defaults then return end
    for index = 1, #self.rows do
        local row = self.rows[index].spec
        local value = row.key and Resolve(defaults, row.key)
        if value ~= nil then
            if type(value) == "table" then value = { r = value.r, g = value.g, b = value.b } end
            self.spec.set(row.key, value)
        end
    end
    self:Refresh()
end

function Methods:Visibility(settings)
    local bits = {}
    for index = 1, #self.rows do
        local entry = self.rows[index]
        local row = entry.spec
        entry.visible = not row.visible or (row.visible(settings) and true or false)
        bits[index] = (entry.visible and "1" or "0") .. (row.kind == "block" and tostring(entry.height) or "")
    end
    return table.concat(bits)
end

function Methods:Layout(settings)
    local signature = self:Visibility(settings)
    if signature == self.layoutSignature then return end
    self.layoutSignature = signature

    local y = 0
    for _, item in ipairs(self.layout) do
        if item.kind == "heading" then
            local show = false
            for _, entry in ipairs(item.members) do
                if entry.visible then show = true break end
            end
            item.frame:SetShown(show)
            if show then
                if y > 0 then y = y + 10 end
                item.frame:ClearAllPoints()
                item.frame:SetPoint("TOPLEFT", self.child, "TOPLEFT", 4, -y)
                y = y + 18
            end
        elseif item.kind == "divider" then
            local show = false
            for _, entry in ipairs(item.members) do
                if entry.visible then show = true break end
            end
            item.line:SetShown(show)
            item.caption:SetShown(show)
            if show then
                y = y + 14
                item.line:ClearAllPoints()
                item.line:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -y)
                item.line:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", 0, -y)
                y = y + 6
                item.caption:ClearAllPoints()
                item.caption:SetPoint("TOPLEFT", self.child, "TOPLEFT", 4, -y)
                y = y + 20
            end
        else
            local entry = item.entry
            entry.frame:SetShown(entry.visible)
            if entry.visible then
                entry.frame:ClearAllPoints()
                entry.frame:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -y)
                entry.frame:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", 0, -y)
                y = y + entry.height
            end
        end
    end
    self.child:SetHeight(y + 12)
    self.contentHeight = y + 12
    if self.scroll then self:UpdateScroll() end
end

function Methods:Refresh()
    local settings = self.spec.get()
    if not settings then return end
    self.settings = settings

    local hasMaster = self.spec.master ~= false
    local enabled = true
    if hasMaster then
        enabled = settings.enabled and true or false
        self.master:Set(enabled)
        self.masterLabel:SetText(enabled and "Enabled" or "Disabled")
        local tint = enabled and COLOR.on or COLOR.muted
        self.masterLabel:SetTextColor(tint[1], tint[2], tint[3])
    end
    self.summary:SetText(self.spec.summary and self.spec.summary(settings) or "")

    for index = 1, #self.rows do
        local entry = self.rows[index]
        local row = entry.spec
        if row.kind == "select" and type(row.options) == "function" then
            entry.control:SetOptions(row.options(settings))
        end
        if row.key then
            local value = Resolve(settings, row.key)
            if value ~= nil then entry.control:Set(value) end
        end
        if row.kind == "block" then
            entry.blockText:SetWidth(math.max(60, self.child:GetWidth() - 8))
            entry.blockText:SetText(row.text(settings) or "")
            entry.height = math.max(24, entry.blockText:GetStringHeight() + 14)
            entry.frame:SetHeight(entry.height)
        end
        if type(row.label) == "function" then
            if entry.labelText then
                entry.labelText:SetText(row.label(settings))
            elseif row.kind == "action" and not entry.control.armed then
                entry.control.label:SetText(row.label(settings))
                entry.control.frame:SetWidth(math.max(70, entry.control.label:GetStringWidth() + 24))
            end
        end
        if entry.highlight then entry.highlight:SetShown(row.selected and row.selected(settings) and true or false) end
        local met = true
        if row.requires then
            local negate = row.requires:sub(1, 1) == "!"
            local value = Resolve(settings, negate and row.requires:sub(2) or row.requires)
            met = (value and true or false) ~= negate
        end
        local active = enabled and met
        entry.frame:SetAlpha(active and 1 or 0.45)
        entry.control.frame:EnableMouse(active)
    end

    self:Layout(settings)
    if self.spec.preview then self.spec.preview.update(self.previewState, settings) end
end

function Methods:AddRow(row, advanced)
    local multiline = row.kind == "text" and (row.lines or 1) > 1
    local height = row.hint ~= "" and ROW_WITH_HINT or ROW_PLAIN
    if multiline then height = 30 + row.lines * 15 + 14 end
    if row.kind == "block" then height = 30 end
    local frame = CreateFrame("Frame", nil, self.child)
    frame:SetHeight(height)
    frame:EnableMouse(true)
    if row.experimental then
        local experimental = Paint(frame, COLOR.experimental, 0.55)
        experimental:SetAllPoints(frame)
    end
    local highlight = Paint(frame, COLOR.accent, 0.12)
    highlight:SetAllPoints(frame)
    highlight:Hide()
    local tint = Paint(frame, COLOR.line, 0.5)
    tint:SetAllPoints(frame)
    tint:Hide()
    local flash = Paint(frame, COLOR.accent, 0.3, "BORDER")
    flash:SetAllPoints(frame)
    flash:Hide()
    local rule = Paint(frame, COLOR.line, 0.55)
    rule:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)

    local control
    local page = self
    if row.kind == "toggle" then
        control = MakeToggle(frame, function(value) page:Change(row.key, value) end)
    elseif row.kind == "range" then
        control = MakeRange(frame, row, function(value) page:Change(row.key, value) end)
    elseif row.kind == "color" then
        control = MakeColor(frame, function(value) page:Change(row.key, value) end)
    elseif row.kind == "block" then
        control = { frame = frame }
    elseif row.kind == "text" then
        control = MakeText(frame, row, function(value) page:Change(row.key, value) end)
    elseif row.kind == "select" then
        local options = type(row.options) == "function" and row.options({}) or row.options
        local characters = 0
        for index = 1, options and #options or 0 do characters = characters + #tostring(options[index][2]) end
        if options and (#options > 4 or characters > 36) then
            control = MakeStepper(frame, row, function(value) page:Change(row.key, value) end)
        else
            control = MakeSelect(frame, row, function(value) page:Change(row.key, value) end)
        end
    else
        local armed = false
        local function labelNow()
            if type(row.label) == "function" then return row.label(page.settings or {}) end
            return row.label
        end
        control = MakeButton(frame, type(row.label) == "function" and "" or row.label, function()
            local question = row.confirm
            if type(question) == "function" then question = question(page.settings or {}) end
            if question and not armed then
                armed = true
                control.armed = true
                control.label:SetText(question)
                control.frame:SetWidth(math.max(control.frame:GetWidth(), control.label:GetStringWidth() + 24))
                if C_Timer and C_Timer.After then
                    C_Timer.After(5, function()
                        if armed then
                            armed = false
                            control.armed = false
                            control.label:SetText(labelNow())
                        end
                    end)
                end
                return
            end
            if armed then
                armed = false
                control.armed = false
                control.label:SetText(labelNow())
            end
            if row.onClick and row.onClick() == false then SA_MenuFX.Shake(control.frame) end
            page:Refresh()
        end)
    end

    local entry = { spec = row, frame = frame, control = control, height = height, highlight = highlight, flash = flash }
    if row.kind == "block" then
        local block = Text(frame, 12, COLOR.text)
        block:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
        block:SetJustifyV("TOP")
        if block.SetWordWrap then block:SetWordWrap(true) end
        entry.blockText = block
    elseif row.kind == "action" then
        control.frame:SetPoint("LEFT", frame, "LEFT", 4, 0)
        local hint = Text(frame, 10.5, COLOR.muted)
        hint:SetPoint("LEFT", control.frame, "RIGHT", 10, 0)
        hint:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
        hint:SetText(row.hint)
    elseif multiline then
        local label = Text(frame, 12.5, advanced and COLOR.muted or COLOR.text)
        label:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
        label:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
        label:SetText(type(row.label) == "function" and "" or row.label)
        entry.labelText = label
        control.frame:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
        control.frame:SetPoint("TOPRIGHT", label, "BOTTOMRIGHT", 0, -6)
    else
        control.frame:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
        local edge = control.frame
        if row.play then
            local playButton, playLabel = MakePlay(frame, row.play)
            playButton:SetPoint("RIGHT", control.frame, "LEFT", -8, 0)
            edge = playButton
            entry.playButton, entry.playLabel = playButton, playLabel
        end
        local label = Text(frame, 12.5, advanced and COLOR.muted or COLOR.text)
        label:SetPoint("LEFT", frame, "LEFT", 4, row.hint ~= "" and 7 or 0)
        label:SetPoint("RIGHT", edge, "LEFT", -10, 0)
        label:SetText(type(row.label) == "function" and "" or row.label)
        entry.labelText = label
        if row.hint ~= "" then
            local hint = Text(frame, 10.5, COLOR.muted)
            hint:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
            hint:SetPoint("RIGHT", edge, "LEFT", -10, 0)
            hint:SetText(row.hint)
        end
    end

    local function hover() page:SetInfo(row) end
    frame:SetScript("OnEnter", hover)
    control.frame:HookScript("OnEnter", hover)
    SA_MenuFX.Hover(frame, tint, control.frame)
    if row.onSelect then
        frame:SetScript("OnMouseUp", function()
            row.onSelect()
            page:Refresh()
        end)
    end
    self.rows[#self.rows + 1] = entry
    return entry
end

function Methods:Populate()
    self.layout = {}
    local function block(advanced)
        local order, seen = {}, {}
        for index = 1, #self.spec.rows do
            local row = self.spec.rows[index]
            if row.advanced == advanced then
                if not seen[row.group] then seen[row.group] = {}; order[#order + 1] = row.group end
                local list = seen[row.group]
                list[#list + 1] = row
            end
        end
        local members = {}
        for index = 1, #order do
            local heading = Text(self.child, 11, COLOR.accent)
            heading:SetText(order[index])
            local item = { kind = "heading", frame = heading, members = {} }
            self.layout[#self.layout + 1] = item
            local list = seen[order[index]]
            for position = 1, #list do
                local entry = self:AddRow(list[position], advanced)
                item.members[#item.members + 1] = entry
                members[#members + 1] = entry
                self.layout[#self.layout + 1] = { kind = "row", entry = entry }
            end
        end
        return members
    end
    block(false)
    local hasAdvanced = false
    for index = 1, #self.spec.rows do
        if self.spec.rows[index].advanced then hasAdvanced = true break end
    end
    if hasAdvanced then
        local line = Paint(self.child, COLOR.line)
        line:SetHeight(1)
        local caption = Text(self.child, 10.5, COLOR.muted)
        caption:SetText("MORE OPTIONS")
        local divider = { kind = "divider", line = line, caption = caption, members = {} }
        self.layout[#self.layout + 1] = divider
        local members = block(true)
        for _, entry in ipairs(members) do divider.members[#divider.members + 1] = entry end
    end
    self.contentHeight = 0
    self.child:SetHeight(12)
end

function Methods:UpdateScroll()
    local range = math.max(0, self.contentHeight - self.scroll:GetHeight())
    local offset = math.min(self.scroll:GetVerticalScroll(), range)
    self.scroll:SetVerticalScroll(offset)
    self.bar:Update(range > 0 and offset / range or 0, range > 0 and self.scroll:GetHeight() / self.contentHeight or 1)
end

local function BuildPage(spec)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    local page = { frame = frame, spec = spec, rows = {} }
    for name, method in pairs(Methods) do page[name] = method end

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -2)
    icon:SetTexture(spec.icon)
    local title = Text(frame, 20, COLOR.accent)
    title:SetFont(FONT, 20, "")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -1)
    title:SetText(spec.title)
    local blurb = Text(frame, 11.5, COLOR.muted)
    blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    blurb:SetPoint("RIGHT", frame, "RIGHT", -150, 0)
    blurb:SetText(spec.blurb or "")

    page.master = MakeToggle(frame, function(value) page:Change("enabled", value) end)
    page.master.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    page.masterLabel = Text(frame, 12.5, COLOR.on, "RIGHT")
    page.masterLabel:SetPoint("RIGHT", page.master.frame, "LEFT", -8, 0)
    page.masterLabel:SetWidth(70)
    if spec.master == false then
        page.master.frame:Hide()
        page.masterLabel:Hide()
    end

    local reset = CreateFrame("Button", nil, frame)
    reset:SetSize(130, 16)
    reset:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -28)
    local resetLabel = Text(reset, 11, COLOR.muted, "RIGHT")
    resetLabel:SetAllPoints(reset)
    resetLabel:SetText("Reset to defaults")
    reset:SetScript("OnClick", function() page:Reset() end)
    reset:SetScript("OnEnter", function() resetLabel:SetTextColor(COLOR.accent[1], COLOR.accent[2], COLOR.accent[3]) end)
    reset:SetScript("OnLeave", function() resetLabel:SetTextColor(COLOR.muted[1], COLOR.muted[2], COLOR.muted[3]) end)

    page.summary = Text(frame, 11.5, COLOR.muted)
    page.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -56)
    page.summary:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    page.summary:SetHeight(28)
    page.summary:SetJustifyV("TOP")
    if page.summary.SetWordWrap then page.summary:SetWordWrap(true) end

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -HEADER_HEIGHT)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(RIGHT_WIDTH + 22), 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    child:SetSize(400, 100)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    page.scroll, page.child = scroll, child
    page.bar = MakeScrollbar(scroll, function(fraction)
        local range = math.max(0, page.contentHeight - scroll:GetHeight())
        scroll:SetVerticalScroll(fraction * range)
        page:UpdateScroll()
    end, 12)
    page.thumb = page.bar.strip
    scroll:SetScript("OnSizeChanged", function(_, width)
        child:SetWidth(math.max(1, width))
        page:UpdateScroll()
    end)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local range = math.max(0, page.contentHeight - scroll:GetHeight())
        scroll:SetVerticalScroll(math.max(0, math.min(range, scroll:GetVerticalScroll() - delta * SCROLL_STEP)))
        page:UpdateScroll()
    end)

    local right = CreateFrame("Frame", nil, frame)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -HEADER_HEIGHT)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(RIGHT_WIDTH)

    local previewHeight = spec.preview and spec.preview.height or 0
    if spec.preview then
        local card = CreateFrame("Frame", nil, right)
        card:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
        card:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, 0)
        card:SetHeight(previewHeight + 30)
        local fill = Paint(card, COLOR.card)
        fill:SetAllPoints(card)
        Outline(card, COLOR.line)
        local caption = Text(card, 10, COLOR.muted)
        caption:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
        caption:SetText(spec.preview.caption or "LIVE PREVIEW")
        local stage = CreateFrame("Frame", nil, card)
        stage:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -24)
        stage:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 6)
        page.previewState = spec.preview.build(stage)
    end

    local info = CreateFrame("Frame", nil, right)
    info:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -(previewHeight > 0 and previewHeight + 42 or 0))
    info:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -(previewHeight > 0 and previewHeight + 42 or 0))
    info:SetHeight(130)
    local infoFill = Paint(info, COLOR.card)
    infoFill:SetAllPoints(info)
    Outline(info, COLOR.line)
    page.infoTitle = Text(info, 13, COLOR.text)
    page.infoTitle:SetPoint("TOPLEFT", info, "TOPLEFT", 10, -10)
    page.infoTitle:SetPoint("RIGHT", info, "RIGHT", -10, 0)
    page.infoBody = Text(info, 11.5, COLOR.muted)
    page.infoBody:SetPoint("TOPLEFT", page.infoTitle, "BOTTOMLEFT", 0, -6)
    page.infoBody:SetWidth(RIGHT_WIDTH - 20)
    if page.infoBody.SetWordWrap then page.infoBody:SetWordWrap(true) end
    page.infoBody:SetJustifyV("TOP")

    page:Populate()
    page:SetInfo(nil)
    return page
end

function Page.Get(spec)
    local page = cache[spec]
    if not page then
        page = BuildPage(spec)
        cache[spec] = page
    end
    return page
end

local WidgetMethods = {}

function WidgetMethods:OnAcquire()
    self.frame:SetHeight(PAGE_HEIGHT)
    self.frame:Show()
end

function WidgetMethods:OnRelease()
    local page = self.page
    if page then
        page.frame:Hide()
        page.frame:SetParent(UIParent)
    end
    self.page = nil
end

function WidgetMethods:SetText() end
function WidgetMethods:SetFontObject() end

function WidgetMethods:SetCustomData(spec)
    if type(spec) ~= "table" or not spec.get then return end
    local page = Page.Get(spec)
    self.page = page
    page.frame:SetParent(self.frame)
    page.frame:ClearAllPoints()
    page.frame:SetAllPoints(self.frame)
    page.frame:Show()
    page:Refresh()
    page:UpdateScroll()
    SA_MenuFX.SlideIn(page.frame, self.frame)
    Page.Kit.FitWidget(self)
end

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetHeight(PAGE_HEIGHT)
    local widget = { type = WIDGET, frame = frame }
    frame.obj = widget
    for name, method in pairs(WidgetMethods) do widget[name] = method end
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(WIDGET, Constructor, 1)

local function Tint(region, color, alpha)
    if region.SetTextColor then
        region:SetTextColor(color[1], color[2], color[3], alpha or 1)
    else
        region:SetVertexColor(color[1], color[2], color[3], alpha or 1)
    end
end

local function Flow(parent, items, width, gap, x, y, step)
    local cursor = 0
    for _, item in ipairs(items) do
        local size = item.frame:GetWidth()
        if cursor > 0 and cursor + size > width then
            cursor = 0
            y = y + step
        end
        item.frame:ClearAllPoints()
        item.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x + cursor, -y)
        cursor = cursor + size + gap
    end
    return y + step
end

local function MakeChip(parent, label, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(22)
    local fill = Paint(button, COLOR.line)
    fill:SetAllPoints(button)
    local text = Text(button, 12, COLOR.muted, "CENTER")
    text:SetPoint("CENTER", button, "CENTER", 0, 0)
    text:SetText(label)
    button:SetWidth(text:GetStringWidth() + 24)
    button:SetScript("OnClick", onClick)
    SA_MenuFX.Press(button, fill, text)
    local chip = { frame = button, label = text }
    function chip:SetLabel(value)
        text:SetText(value)
        button:SetWidth(text:GetStringWidth() + 24)
    end
    function chip:Set(on, active)
        Tint(fill, on and COLOR.on or COLOR.line, on and 0.3 or 1)
        Tint(text, on and COLOR.on or COLOR.muted)
        button:SetAlpha(active == false and 0.45 or 1)
    end
    return chip
end

local CARD_TITLE = 30

local function NewView(parent)
    local view = { height = 0 }
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetAllPoints(frame)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    child:SetSize(400, 100)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    view.frame, view.scroll, view.child = frame, scroll, child
    view.bar = MakeScrollbar(scroll, function(fraction)
        view:ScrollTo(fraction * math.max(0, view.height - scroll:GetHeight()))
    end, 0)
    view.thumb = view.bar.strip

    function view:UpdateScroll()
        local range = math.max(0, self.height - scroll:GetHeight())
        local offset = math.min(scroll:GetVerticalScroll(), range)
        scroll:SetVerticalScroll(offset)
        self.bar:Update(range > 0 and offset / range or 0, range > 0 and scroll:GetHeight() / self.height or 1)
    end

    function view:SetContentHeight(height)
        self.height = height
        child:SetHeight(height)
        self:UpdateScroll()
    end

    function view:ScrollTo(offset)
        local range = math.max(0, self.height - scroll:GetHeight())
        scroll:SetVerticalScroll(math.max(0, math.min(range, offset)))
        self:UpdateScroll()
    end

    scroll:SetScript("OnMouseWheel", function(_, delta)
        view:ScrollTo(scroll:GetVerticalScroll() - delta * SCROLL_STEP)
    end)
    scroll:SetScript("OnSizeChanged", function(_, width)
        local usable = math.max(1, width - 12)
        child:SetWidth(usable)
        if view.onWidth then view.onWidth(usable) end
        view:UpdateScroll()
    end)
    return view
end

local function NewHeading(parent, text)
    local label = Text(parent, 11, COLOR.accent)
    label:SetText(text)
    return label
end

local function NewLink(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    local label = Text(button, 11, COLOR.muted, "RIGHT")
    label:SetAllPoints(button)
    label:SetText(text)
    button:SetSize(label:GetStringWidth() + 6, 16)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function() Tint(label, COLOR.accent) end)
    button:SetScript("OnLeave", function() Tint(label, COLOR.muted) end)
    return { frame = button, label = label }
end

local function NewDivider(parent, caption)
    local line = Paint(parent, COLOR.line)
    line:SetHeight(1)
    local label = Text(parent, 10.5, COLOR.muted)
    label:SetText(caption)
    return { line = line, label = label }
end

local function PlaceDivider(divider, parent, width, y)
    divider.line:ClearAllPoints()
    divider.line:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    divider.line:SetPoint("TOPRIGHT", parent, "TOPLEFT", width, -y)
    divider.label:ClearAllPoints()
    divider.label:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -(y + 8))
    return y + 28
end

local function NewCard(parent, title, columns)
    local frame = CreateFrame("Frame", nil, parent)
    local fill = Paint(frame, COLOR.card)
    fill:SetAllPoints(frame)
    Outline(frame, COLOR.line)
    local caption = Text(frame, 12, COLOR.text)
    caption:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    caption:SetText(title)
    return { frame = frame, rows = {}, columns = columns or 1, title = caption }
end

local function PlaceCard(card, parent, x, y, width)
    local columns = card.columns
    local columnWidth = (width - 16 - (columns - 1) * 16) / columns
    local bottom = CARD_TITLE
    if columns == 1 then
        for _, row in ipairs(card.rows) do
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 8, -bottom)
            row.frame:SetWidth(columnWidth)
            bottom = bottom + row.height
        end
    else
        for index, row in ipairs(card.rows) do
            local column = (index - 1) % columns
            local line = math.floor((index - 1) / columns)
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", card.frame, "TOPLEFT", 8 + column * (columnWidth + 16), -(CARD_TITLE + line * ROW_PLAIN))
            row.frame:SetWidth(columnWidth)
            bottom = CARD_TITLE + (line + 1) * ROW_PLAIN
        end
    end
    if card.content then bottom = card.content(card, width, bottom) end
    local height = bottom + 8
    card.frame:ClearAllPoints()
    card.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    card.frame:SetSize(width, height)
    return height
end

local function ShowTip(owner, title, body)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if body and body ~= "" then GameTooltip:AddLine(body, 0.6, 0.65, 0.7, true) end
    GameTooltip:Show()
end

local function HideTip()
    GameTooltip:Hide()
end

local function RowHeight(row)
    if row.height then return row.height end
    if row.kind == "select" and row.stack then return 56 end
    if row.kind == "text" and row.full then return 52 end
    if row.hint then return 38 end
    return 28
end

local function AddRow(card, row, after)
    local height = RowHeight(row)
    local frame = CreateFrame("Frame", nil, card.frame)
    frame:SetHeight(height)
    frame:EnableMouse(true)
    local tint = Paint(frame, COLOR.line, 0.5)
    tint:SetAllPoints(frame)
    tint:Hide()
    local flash = Paint(frame, COLOR.accent, 0.3, "BORDER")
    flash:SetAllPoints(frame)
    flash:Hide()
    local rule = Paint(frame, COLOR.line, 0.55)
    rule:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)

    local entry = { frame = frame, height = height, flash = flash, row = row }
    local label = Text(frame, 12.5, COLOR.text)
    label:SetText(row.label or "")
    entry.labelText = label

    local function changed(value)
        row.set(value)
        if after then after(entry, value) end
        SA_MenuFX.Flash(flash)
    end

    local control
    local rightEdge
    if row.kind == "select" then
        local options = row.options
        control = (#options > 4 and MakeStepper or MakeSelect)(frame, { options = options }, changed)
        if row.stack then
            label:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -6)
            control.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -28)
        else
            control.frame:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
            rightEdge = control.frame
        end
    elseif row.kind == "text" then
        control = MakeText(frame, row, changed)
        if row.full then
            label:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -5)
            control.frame:ClearAllPoints()
            control.frame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 4)
            control.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
            control.frame:SetHeight(22)
        else
            control.frame:SetWidth(row.width or 190)
            if row.button then
                local button = MakeButton(frame, row.button.label, function() row.button.onClick(entry) end)
                button.frame:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
                control.frame:SetPoint("RIGHT", button.frame, "LEFT", -6, 0)
                entry.button = button
            else
                control.frame:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
            end
            rightEdge = control.frame
        end
    elseif row.kind == "button" then
        local button = MakeButton(frame, row.button, function() row.onClick(entry) end)
        button.frame:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
        entry.button = button
        control = button
        rightEdge = button.frame
    else
        control = MakeToggle(frame, changed)
        control.frame:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
        rightEdge = control.frame
    end
    entry.control = control

    if rightEdge then
        label:SetPoint("LEFT", frame, "LEFT", row.indent or 4, row.hint and 7 or 0)
        label:SetPoint("RIGHT", rightEdge, "LEFT", -8, 0)
    end
    if row.hint and not row.stack and not row.full then
        local hint = Text(frame, 10.5, COLOR.muted)
        hint:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
        hint:SetPoint("RIGHT", rightEdge or frame, rightEdge and "LEFT" or "RIGHT", rightEdge and -8 or -90, 0)
        hint:SetText(row.hint)
        entry.hintText = hint
    end

    function entry:SetHint(text, color)
        if self.hintText then
            self.hintText:SetText(text or "")
            Tint(self.hintText, color or COLOR.muted)
        end
    end

    function entry:SetActive(active)
        frame:SetAlpha(active and 1 or 0.45)
        if control.frame then control.frame:EnableMouse(active and true or false) end
    end

    local function enter() ShowTip(frame, row.label or "", row.tip or row.hint) end
    frame:SetScript("OnEnter", enter)
    frame:SetScript("OnLeave", HideTip)
    SA_MenuFX.Hover(frame, tint)
    card.rows[#card.rows + 1] = entry
    return entry
end

local function FlattenSlider(bar)
    for _, child in ipairs({ bar:GetChildren() }) do child:Hide() end
    for _, region in ipairs({ bar:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
    bar:SetThumbTexture(FLAT)
    local thumb = bar:GetThumbTexture()
    thumb:SetVertexColor(COLOR.track[1], COLOR.track[2], COLOR.track[3], 1)
    thumb:SetSize(6, 28)
    local back = Paint(bar, COLOR.line, 0.4)
    back:SetPoint("TOP", bar, "TOP", 0, 0)
    back:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
    back:SetWidth(2)
end

local flattened = setmetatable({}, { __mode = "k" })

local function FitNow(widget)
    local frame = widget.frame
    if not frame then return end
    local content = frame:GetParent()
    local scroll = content and content.GetParent and content:GetParent()
    local height = scroll and scroll.GetHeight and scroll:GetHeight()
    local target = PAGE_HEIGHT
    if type(height) == "number" and height > 200 then target = math.max(300, math.floor(height) - 26) end
    if math.abs(frame:GetHeight() - target) > 1 then
        frame:SetHeight(target)
        if widget.parent and widget.parent.DoLayout then widget.parent:DoLayout() end
    end
    local ace = scroll and scroll.obj
    local bar = ace and ace.scrollbar
    if bar and not flattened[bar] then
        flattened[bar] = true
        pcall(FlattenSlider, bar)
    end
end

local function FitWidget(widget)
    FitNow(widget)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if widget.page then FitNow(widget) end
        end)
    end
end

Page.Kit = {
    COLOR = COLOR,
    FLAT = FLAT,
    FONT = FONT,
    PAGE_HEIGHT = PAGE_HEIGHT,
    SCROLL_STEP = SCROLL_STEP,
    Paint = Paint,
    Outline = Outline,
    Text = Text,
    MakeToggle = MakeToggle,
    MakeScrollbar = MakeScrollbar,
    FitWidget = FitWidget,
    MakeRange = MakeRange,
    MakeText = MakeText,
    MakeButton = MakeButton,
    MakeSelect = MakeSelect,
    MakeStepper = MakeStepper,
    AddRow = AddRow,
    ShowTip = ShowTip,
    HideTip = HideTip,
    MakeChip = MakeChip,
    Tint = Tint,
    Flow = Flow,
    CARD_TITLE = CARD_TITLE,
    NewView = NewView,
    NewHeading = NewHeading,
    NewLink = NewLink,
    NewDivider = NewDivider,
    PlaceDivider = PlaceDivider,
    NewCard = NewCard,
    PlaceCard = PlaceCard,
}

SoundAlerter.Page = Page
