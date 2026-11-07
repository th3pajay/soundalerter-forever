SA_ToastStyle = {}

SA_ToastStyle.STYLES = { "intel", "threat" }
SA_ToastStyle.DEFAULT = "intel"
SA_ToastStyle.NAME_GAP = 11
SA_ToastStyle.SECOND_NAME_MIN = 28

local BAND_RANK = { Close = 4, Nearby = 3, Medium = 2, Detected = 1 }
local BAND_PHRASE = { Close = "very close", Nearby = "close by", Medium = "in range", Detected = "far away" }
local CLASS_WEIGHT = {
    ROGUE = 3, DRUID = 3, MAGE = 2, HUNTER = 2, WARLOCK = 2, WARRIOR = 2, DEATHKNIGHT = 2,
    PALADIN = 1, PRIEST = 1, SHAMAN = 1,
}
local STEALTH = { ROGUE = true, DRUID = true }

function SA_ToastStyle.Normalize(style)
    for _, known in ipairs(SA_ToastStyle.STYLES) do
        if style == known then return style end
    end
    return SA_ToastStyle.DEFAULT
end

function SA_ToastStyle.BandRank(band)
    return BAND_RANK[band] or 0
end

function SA_ToastStyle.Threat(className, band, nearbyCount)
    local score = (CLASS_WEIGHT[className] or 1) + (BAND_RANK[band] or 1)
    if nearbyCount and nearbyCount > 2 then score = score + 1 end
    local level = "LOW"
    if score >= 6 then
        level = "HIGH"
    elseif score >= 4 then
        level = "MEDIUM"
    end
    local parts = {}
    if STEALTH[className] then parts[#parts + 1] = "Stealth class" end
    if BAND_PHRASE[band] then parts[#parts + 1] = BAND_PHRASE[band] end
    if nearbyCount and nearbyCount > 1 then parts[#parts + 1] = "group of " .. nearbyCount end
    local why = table.concat(parts, ", ")
    if why ~= "" then why = why:sub(1, 1):upper() .. why:sub(2) end
    return level, score, why
end

function SA_ToastStyle.NameFit(room, nameWidth, secondWidth)
    room = math.floor(room)
    local first = math.min(math.ceil(nameWidth) + 1, room)
    if not secondWidth then return first, nil end
    local left = room - first - SA_ToastStyle.NAME_GAP
    local second = math.ceil(secondWidth) + 1
    if second <= left then return first, second end
    if left >= SA_ToastStyle.SECOND_NAME_MIN then return first, left end
    return first, nil
end

function SA_ToastStyle.GroupText(nearbyCount)
    if nearbyCount and nearbyCount > 1 then return nearbyCount .. " nearby" end
    if nearbyCount == 1 then return "Solo" end
    return "-"
end

function SA_ToastStyle.LevelText(level)
    if not level then return "-" end
    if level == -1 then return "??" end
    return tostring(level)
end
