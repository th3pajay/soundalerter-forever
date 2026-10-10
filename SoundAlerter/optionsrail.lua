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

function Rail.Tree(parent, sections)
    local args = parent.args
    local built = {}
    local taken = {}

    for index, section in ipairs(sections) do
        local group
        if section.promote then
            group = args[section.promote]
            taken[section.promote] = true
            group.inline = false
        else
            group = { type = 'group', args = {} }
            for _, key in ipairs(section.from) do
                group.args[key] = args[key]
                taken[key] = true
            end
        end
        group.name = section.name
        group.icon = section.icon or group.icon
        group.order = section.order or index
        if section.desc then group.desc = section.desc end
        if section.hidden then group.hidden = section.hidden end
        built[section.key] = group
    end

    for key in pairs(taken) do args[key] = nil end
    for key, group in pairs(built) do args[key] = group end
    parent.childGroups = "tree"
    return parent
end
