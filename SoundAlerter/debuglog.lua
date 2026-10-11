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

function SA_DebugLog.State(value, isSecret)
    if value == nil then return "nil" end
    if isSecret and isSecret(value) then return "SECRET" end
    if type(value) == "boolean" then return tostring(value) end
    return "ok"
end

function SA_DebugLog.Describe(value, isSecret)
    if value == nil then return "nil" end
    if isSecret and isSecret(value) then return "SECRET" end
    return tostring(value)
end

function SA_DebugLog.NewProbe(isSecret, limit)
    local rows, order = {}, {}
    local capacity = limit or 200
    local probe = {}

    function probe.Record(base, ...)
        local parts = {}
        for index = 1, select("#", ...) do
            parts[index] = SA_DebugLog.State((select(index, ...)), isSecret)
        end
        local key = base .. " = " .. table.concat(parts, " ")
        local row = rows[key]
        if row then
            row.count = row.count + 1
            return false, key
        end
        if #order >= capacity then return false, key end
        rows[key] = { count = 1 }
        order[#order + 1] = key
        return true, key
    end

    function probe.Report()
        local lines = {}
        for index, key in ipairs(order) do
            lines[index] = key .. "  x" .. rows[key].count
        end
        return lines
    end

    function probe.Reset()
        rows, order = {}, {}
    end

    return probe
end
