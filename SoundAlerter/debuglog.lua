SA_DebugLog = {}

local GREY = "|cff888888"
local AMBER = "|cffFF7D0A"
local RESET = "|r"

function SA_DebugLog.Format(now, module, fmt, ...)
    local ok, text = pcall(string.format, fmt, ...)
    if not ok then
        text = tostring(fmt) .. " (unprintable values)"
    end
    return string.format("%s%.1f%s %s[%s]%s %s", GREY, now or 0, RESET, AMBER, module or "SA", RESET, text)
end
