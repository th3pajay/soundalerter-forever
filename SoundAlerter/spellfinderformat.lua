local Format = {}

local WHITE = "|cffFFFFFF"
local GOLD = "|cffFFD100"
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
    return iconText(texture, 18) .. (selected and GOLD or WHITE) .. spell.baseName .. RESET ..
        "  " .. GREY .. Format.RankText(spell.rankNum) .. RESET ..
        "  " .. CYAN .. spell.spellID .. RESET .. tag
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

function Format.Status(count, databaseStatus, descriptionStatus)
    local parts = {}
    if count then
        parts[#parts + 1] = WHITE .. count .. " found" .. RESET
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
