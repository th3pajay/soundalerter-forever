SA_OptionsRail = {}

local Rail = SA_OptionsRail

local STRIP_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local EMPTY_COLOR = { 0.16, 0.18, 0.22 }

local function channel(value)
    return math.max(0, math.min(255, math.floor((value or 0) * 255 + 0.5)))
end

function Rail.Strip(width, height, r, g, b)
    width = math.max(1, math.floor(width))
    return string.format("|T%s:%d:%d:0:0:8:8:0:8:0:8:%d:%d:%d|t", STRIP_TEXTURE, math.floor(height), width, channel(r), channel(g), channel(b))
end

function Rail.Bar(width, height, fill, r, g, b)
    fill = math.max(0, math.min(1, fill or 1))
    local filled = math.floor(width * fill)
    local empty = math.floor(width) - filled
    local out = ""
    if filled > 0 then out = out .. Rail.Strip(filled, height, r, g, b) end
    if empty > 0 then out = out .. Rail.Strip(empty, height, EMPTY_COLOR[1], EMPTY_COLOR[2], EMPTY_COLOR[3]) end
    return out
end

function Rail.Dots(count, active, size, activeColor, idleColor)
    local out = {}
    for index = 1, count do
        local c = index <= active and activeColor or idleColor
        out[#out + 1] = Rail.Strip(size, size, c[1], c[2], c[3])
    end
    return table.concat(out, " ")
end

function Rail.ExpandChat(template, vars)
    if type(template) ~= "string" or template == "" then return "" end
    return (template:gsub("#(%w+)#", function(token)
        return vars[token] or ("#" .. token .. "#")
    end))
end

function Rail.ChatLine(channelName, template, vars)
    return "[" .. channelName .. "] " .. Rail.ExpandChat(template, vars)
end

function Rail.Status(label, items, none)
    local on = {}
    for _, item in ipairs(items) do
        if item[2] then on[#on + 1] = item[1] end
    end
    local value = #on > 0 and ("|cff4ccf72" .. table.concat(on, ", ") .. "|r") or ("|cff8a93a3" .. (none or "none") .. "|r")
    return "|cffffd100" .. label .. ":|r " .. value
end

local DEFAULT_OPEN_CARDS = 2
local HEADER_KEY = "cardHeader"
local HEADER_ORDER = 0
local ABOVE_HEADER = 0.0001

local weak = { __mode = "k" }
Rail.Cards = setmetatable({}, weak)
local hideState = setmetatable({}, weak)

local fallbackStore = {}
Rail.Store = function() return fallbackStore end

local function notifyChange()
    local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if registry then registry:NotifyChange("SoundAlerter") end
end

function Rail.IsCollapsed(card)
    local stored = Rail.Store()[card.key]
    if stored == nil then return card.defaultCollapsed end
    return stored
end

function Rail.SetCollapsed(key, collapsed)
    Rail.Store()[key] = collapsed
end

function Rail.CardTitle(group)
    local card = Rail.Cards[group]
    local marker = Rail.IsCollapsed(card) and "|cffffd100[+]|r " or "|cff8a93a3[-]|r "
    local icon = card.icon and ("|T" .. card.icon .. ":16|t ") or ""
    local tag = card.tag and card.tag() or ""
    return marker .. icon .. "|cffffd100" .. card.title .. "|r" .. tag
end

function Rail.HideWhen(node, predicate)
    local state = hideState[node]
    if not state then
        state = { base = node.hidden, predicates = {} }
        hideState[node] = state
        node.hidden = function(...)
            for _, hide in ipairs(state.predicates) do
                if hide() then return true end
            end
            if type(state.base) == "function" then return state.base(...) end
            return state.base
        end
    end
    state.predicates[#state.predicates + 1] = predicate
end

function Rail.HiddenRule(node)
    local state = hideState[node]
    if state then return state.base end
    return node.hidden
end

function Rail.Card(group, key, title, icon, defaultCollapsed)
    local card = { key = key, title = title, icon = icon, defaultCollapsed = defaultCollapsed }
    Rail.Cards[group] = card
    group.inline = true
    group.name = ""
    for _, child in pairs(group.args) do
        if type(child) == "table" then
            if child.order == 0 then child.order = ABOVE_HEADER end
            Rail.HideWhen(child, function() return Rail.IsCollapsed(card) end)
        end
    end
    group.args[HEADER_KEY] = {
        type = 'execute',
        name = function() return Rail.CardTitle(group) end,
        desc = group.desc,
        width = "full",
        order = HEADER_ORDER,
        func = function()
            Rail.SetCollapsed(key, not Rail.IsCollapsed(card))
            notifyChange()
        end,
    }
    return group
end

function Rail.Tree(parent, sections)
    local args = parent.args
    local built = {}
    local taken = {}
    local prefix = tostring(parent.name) .. "/"

    for index, section in ipairs(sections) do
        local group
        if section.promote then
            group = args[section.promote]
            taken[section.promote] = true
        else
            group = { type = 'group', args = {} }
            for _, key in ipairs(section.from) do
                group.args[key] = args[key]
                taken[key] = true
            end
        end
        group.order = section.order or index
        if section.desc then group.desc = section.desc end
        if section.hidden then group.hidden = section.hidden end
        Rail.Card(group, prefix .. section.key, section.name, section.icon or group.icon, index > DEFAULT_OPEN_CARDS)
        built[section.key] = group
    end

    for key in pairs(taken) do args[key] = nil end
    for key, group in pairs(built) do args[key] = group end
    parent.childGroups = nil
    return parent
end
