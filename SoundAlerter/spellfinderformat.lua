local Format = {}

local WHITE = "|cffFFFFFF"
local GOLD = "|cffFFD100"
local GREEN = "|cff00FF00"
local GREY = "|cff888888"
local CYAN = "|cff00FFFF"
local AMBER = "|cffFFAA00"
local RED = "|cffFF4040"
local RESET = "|r"

function Format.RankText(rankNum)
    if rankNum and rankNum > 0 then
        return "Rank " .. rankNum
    end
    return "No rank"
end

local function iconText(texture, size)
    if not texture then return "" end
    return "|T" .. texture .. ":" .. size .. "|t "
end

function Format.Row(spell, texture, selected)
    local tag = spell.inDescription and ("  " .. AMBER .. "description" .. RESET) or ""
    if spell.idMatch then tag = "  " .. CYAN .. "ID match" .. RESET end
    return iconText(texture, 18) .. (selected and GOLD or WHITE) .. spell.baseName .. RESET ..
        "  " .. GREY .. Format.RankText(spell.rankNum) .. RESET ..
        "  " .. CYAN .. spell.spellID .. RESET .. tag
end

function Format.Tokens(searchLower)
    local tokens = {}
    for word in string.gmatch(searchLower, "%S+") do
        tokens[#tokens + 1] = word
    end
    return tokens
end

function Format.NameScore(lowerName, query, tokens)
    local firstPos
    for index, token in ipairs(tokens) do
        local pos = string.find(lowerName, token, 1, true)
        if not pos then return nil end
        if index == 1 then firstPos = pos end
    end
    if lowerName == query then return 0 end
    if firstPos == 1 then return 1 end
    if string.sub(lowerName, firstPos - 1, firstPos - 1) == " " then return 2 end
    return 3
end

function Format.CastTime(milliseconds)
    if not milliseconds then return "unknown" end
    if milliseconds <= 0 then return "Instant" end
    local text = string.format("%.2f", milliseconds / 1000):gsub("0+$", ""):gsub("%.$", "")
    return text .. " s"
end

function Format.Range(minRange, maxRange)
    if not maxRange or maxRange <= 0 then return "none" end
    if minRange and minRange > 0 then
        return string.format("%g-%g yd", minRange, maxRange)
    end
    return string.format("%g yd", maxRange)
end

function Format.Facts(info)
    if not info then return " " end
    return GREY .. "Cast " .. WHITE .. Format.CastTime(info.castTime) .. RESET ..
        "   " .. GREY .. "Range " .. WHITE .. Format.Range(info.minRange, info.maxRange) .. RESET ..
        "   " .. GREY .. "Icon ID " .. WHITE .. (info.iconID and tostring(info.iconID) or "none") .. RESET
end

local function titleCase(word)
    return string.upper(string.sub(word, 1, 1)) .. string.lower(string.sub(word, 2))
end

function Format.Costs(costs)
    if not costs then return nil end
    if #costs == 0 then return "none" end
    local parts = {}
    for _, entry in ipairs(costs) do
        parts[#parts + 1] = string.format("%g %s", entry.cost, titleCase(entry.name))
    end
    return table.concat(parts, ", ")
end

function Format.Properties(props)
    if not props then return " " end
    local parts = {}
    if props.passive == true then
        parts[#parts + 1] = AMBER .. "Passive" .. RESET
    elseif props.passive == false then
        parts[#parts + 1] = WHITE .. "Active" .. RESET
    end
    if props.known == true then
        parts[#parts + 1] = GREEN .. "Known" .. RESET
    elseif props.known == false then
        parts[#parts + 1] = GREY .. "Not known" .. RESET
    end
    local cost = Format.Costs(props.costs)
    if cost then
        parts[#parts + 1] = GREY .. "Cost " .. WHITE .. cost .. RESET
    end
    if props.maxCharges and props.maxCharges > 1 then
        parts[#parts + 1] = GREY .. "Charges " .. WHITE .. string.format("%g", props.maxCharges) .. RESET
    end
    if #parts == 0 then return " " end
    return table.concat(parts, "   ")
end

function Format.PassesFilters(props, kind, known)
    if kind == "passive" and props.passive ~= true then return false end
    if kind == "active" and props.passive == true then return false end
    if known == "known" and props.known ~= true then return false end
    if known == "unknown" and props.known == true then return false end
    return true
end

function Format.Title(spell, texture)
    return iconText(texture, 32) .. GOLD .. spell.baseName .. RESET
end

function Format.Subtitle(spell)
    local text = GREY .. Format.RankText(spell.rankNum) .. RESET
    if spell.inDescription then
        text = text .. "   " .. AMBER .. "matched in description" .. RESET
    end
    return text
end

function Format.Description(description, loading)
    if description then
        return description
    end
    if loading then
        return GREY .. "Loading description..." .. RESET
    end
    return GREY .. "No description available for this spell." .. RESET
end

function Format.NoSelection()
    return GREY .. "Select a spell to see its details." .. RESET
end

local DEFAULT_CHAT_LIMIT = 255
local MIN_DESCRIPTION_CHARS = 12

local function plainText(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|n", " ")
    text = text:gsub("%c+", " ")
    text = text:gsub("%s+", " ")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

Format.PlainText = plainText

function Format.ChatText(spell, description, limit)
    local text = string.format("%s (%s) - ID: %d", spell.baseName, Format.RankText(spell.rankNum), spell.spellID)
    if not description then
        return text, false
    end

    local cleaned = plainText(description)
    if cleaned == "" then
        return text, false
    end

    local full = text .. ": " .. cleaned
    if not limit or #full <= limit then
        return full, false
    end

    local available = limit - #text - 2 - 3
    if available < MIN_DESCRIPTION_CHARS then
        return text, true
    end

    local cut = cleaned:sub(1, available)
    cut = cut:match("^(.*)%s%S*$") or cut
    return text .. ": " .. cut .. "...", true
end

Format.DEFAULT_CHAT_LIMIT = DEFAULT_CHAT_LIMIT

function Format.Empty(context)
    if context.building then
        return AMBER .. "Database still building." .. RESET .. " Please wait and try again."
    end
    if not context.term or context.term == "" then
        return "Type a spell name. Add " .. WHITE .. "r2" .. RESET .. " or " .. WHITE .. "rank:2" .. RESET ..
            " to filter by rank, e.g. " .. WHITE .. "frostbolt r2" .. RESET .. "."
    end
    if context.hiddenByFilters and context.hiddenByFilters > 0 then
        return RED .. "No spells shown." .. RESET .. " The Type or Known filter hid " .. WHITE .. context.hiddenByFilters ..
            RESET .. " matching spells. Set them to All to see them."
    end
    if context.scope == "descriptions" and #context.term < 3 then
        return AMBER .. "Description search needs at least 3 characters." .. RESET
    end
    if context.scope ~= "names" then
        return RED .. "No spells found for '" .. context.term .. "'." .. RESET ..
            " Only the indexed part of the descriptions is searched; see the index status above."
    end
    return RED .. "No spells found for '" .. context.term .. "'." .. RESET ..
        " Try a different term" .. (context.fuzzy and "" or " or turn on Fuzzy") .. "."
end

function Format.Status(count, databaseStatus, descriptionStatus, unfiltered)
    local parts = {}
    if count then
        local text = WHITE .. count .. " found" .. RESET
        if unfiltered and unfiltered > count then
            text = text .. GREY .. " of " .. unfiltered .. " before filters" .. RESET
        end
        parts[#parts + 1] = text
    end
    parts[#parts + 1] = databaseStatus
    if descriptionStatus then
        parts[#parts + 1] = descriptionStatus
    end
    return table.concat(parts, GREY .. "  |  " .. RESET)
end

function Format.More(shown, total)
    return AMBER .. string.format("Showing the first %d of %d. Refine your search to narrow it down.", shown, total) .. RESET
end

SA_FinderFormat = Format
