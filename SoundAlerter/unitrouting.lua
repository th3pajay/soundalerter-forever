do
SA_Plates = {}

local issecretvalue = _G.issecretvalue or function() return false end

local enemies = {}
local pending = {}
local count = 0

function SA_Plates.Add(unit, guid)
    if guid == nil then return end
    if enemies[unit] == nil then count = count + 1 end
    enemies[unit] = guid
end

function SA_Plates.Remove(unit)
    local guid = enemies[unit]
    if guid == nil then return end
    pending[guid] = nil
    enemies[unit] = nil
    count = count - 1
end

function SA_Plates.Reset()
    for unit in pairs(enemies) do enemies[unit] = nil end
    for guid in pairs(pending) do pending[guid] = nil end
    count = 0
end

function SA_Plates.MarkPending(guid, now)
    if guid ~= nil then pending[guid] = now end
end

function SA_Plates.ClearPending(guid)
    pending[guid] = nil
end

function SA_Plates.IsPending(guid)
    return guid ~= nil and pending[guid] ~= nil
end

function SA_Plates.PrunePending(cutoff)
    for guid, markedAt in pairs(pending) do
        if markedAt < cutoff then pending[guid] = nil end
    end
end

function SA_Plates.IsEnemy(unit)
    return enemies[unit] ~= nil
end

function SA_Plates.GUID(unit)
    return enemies[unit]
end

function SA_Plates.Count()
    return count
end

function SA_Plates.Enemies()
    return enemies
end

local ENEMY_UNIT = {}

local function Kind(unit)
    local kind = ENEMY_UNIT[unit]
    if kind == nil then
        if unit:find("^nameplate%d+$") then
            kind = "nameplate"
        elseif unit:find("^arena%d$") then
            kind = "arena"
        else
            kind = false
        end
        ENEMY_UNIT[unit] = kind
    end
    return kind
end

function SA_Plates.IsEnemyUnit(unit)
    local kind = Kind(unit)
    if kind == "nameplate" then return enemies[unit] ~= nil end
    if kind == "arena" then
        local isEnemy, isPlayer = UnitIsEnemy("player", unit), UnitIsPlayer(unit)
        return not issecretvalue(isEnemy) and not issecretvalue(isPlayer) and isEnemy and isPlayer and true or false
    end
    return false
end
end

do
SA_CastDispatch = {}

local issecretvalue = _G.issecretvalue or function() return false end

local frame = CreateFrame("Frame")
local order = {}
local handlersOf = {}
local byEvent = {}
local registered = {}
local wanted = {}

local function Wanted(unit)
    local want = wanted[unit]
    if want == nil then
        want = unit == "player" or unit == "pet" or unit == "target" or unit == "focus" or unit == "mouseover"
            or unit:find("^nameplate%d+$") ~= nil or unit:find("^arena%d$") ~= nil
        wanted[unit] = want
    end
    return want
end

local function Rebuild()
    byEvent = {}
    for _, name in ipairs(order) do
        for event, fn in pairs(handlersOf[name]) do
            local list = byEvent[event]
            if not list then
                list = {}
                byEvent[event] = list
            end
            list[#list + 1] = fn
        end
    end
    for event in pairs(registered) do
        if not byEvent[event] then
            frame:UnregisterEvent(event)
            registered[event] = nil
        end
    end
    for event in pairs(byEvent) do
        if not registered[event] then
            frame:RegisterEvent(event)
            registered[event] = true
        end
    end
end

function SA_CastDispatch.Subscribe(name, handlers)
    if not handlersOf[name] then order[#order + 1] = name end
    handlersOf[name] = handlers
    Rebuild()
end

function SA_CastDispatch.Unsubscribe(name)
    if not handlersOf[name] then return end
    handlersOf[name] = nil
    for index, entry in ipairs(order) do
        if entry == name then
            table.remove(order, index)
            break
        end
    end
    Rebuild()
end

function SA_CastDispatch.Subscribed(name)
    return handlersOf[name] ~= nil
end

frame:SetScript("OnEvent", function(_, event, unit, ...)
    local list = byEvent[event]
    if not list or type(unit) ~= "string" or issecretvalue(unit) or not Wanted(unit) then return end
    for index = 1, #list do
        local ok, err = pcall(list[index], unit, ...)
        if not ok then geterrorhandler()(err) end
    end
end)
end

do
SA_TargetToken = setmetatable({}, {
    __index = function(cache, unit)
        local token = unit .. "target"
        cache[unit] = token
        return token
    end,
})
end
