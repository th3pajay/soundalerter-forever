SA_Secret = {}

local hasSecrets = type(_G.issecretvalue) == "function"
local issecretvalue = _G.issecretvalue or function() return false end

local FAILURE_LIMIT = 5
local SELFTEST_SPELL = 133

local enabled = true
local scratch

local function NameSupported()
    return hasSecrets and type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function"
end

local function IconSupported()
    return hasSecrets and type(C_Spell) == "table" and type(C_Spell.GetSpellTexture) == "function"
end

local function SinkSupported()
    return hasSecrets
end

local function AuraSupported()
    return hasSecrets and type(AuraContainerSortMethod) == "table" and type(AuraContainerSortMethod.AuraInstanceIDOnly) == "number"
        and type(AuraContainerSortDirection) == "table" and type(AuraContainerSortDirection.Reverse) == "number"
        and type(AnchorUtil) == "table" and type(AnchorUtil.FlowLayoutAxis) == "table"
        and type(AnchorUtil.FlowDirection) == "table"
end

local routes = {
    name = { label = "Spell name", supported = NameSupported },
    icon = { label = "Spell icon", supported = IconSupported },
    sink = { label = "Text and texture display", supported = SinkSupported },
    aura = { label = "Aura display", supported = AuraSupported },
}
local ORDER = { "name", "icon", "sink", "aura" }

for _, route in pairs(routes) do
    route.fails = 0
    route.blocked = false
    route.verified = false
end

local function Usable(route)
    return enabled and not route.blocked and route.supported()
end

local function Record(route, ok, err)
    if ok then
        route.fails = 0
        return
    end
    route.fails = route.fails + 1
    route.lastError = tostring(err):sub(1, 120)
    if route.fails >= FAILURE_LIMIT then route.blocked = true end
end

local function SpellName(spellID) return C_Spell.GetSpellName(spellID) end
local function SpellTexture(spellID) return C_Spell.GetSpellTexture(spellID) end

local function Lookup(route, fn, spellID)
    if spellID == nil or not Usable(route) then return nil end
    local ok, value = pcall(fn, spellID)
    Record(route, ok, value)
    if not ok then return nil end
    if value ~= nil and issecretvalue(value) then route.verified = true end
    return value
end

function SA_Secret.Name(spellID) return Lookup(routes.name, SpellName, spellID) end

function SA_Secret.Icon(spellID) return Lookup(routes.icon, SpellTexture, spellID) end

local function DrawPair(text, texture, name, icon)
    if text and name ~= nil then text:SetText(name) end
    if texture and icon ~= nil then texture:SetTexture(icon) end
end

function SA_Secret.Draw(text, texture, name, icon)
    local route = routes.sink
    if not Usable(route) then return false end
    local ok, err = pcall(DrawPair, text, texture, name, icon)
    Record(route, ok, err)
    if ok and ((name ~= nil and issecretvalue(name)) or (icon ~= nil and issecretvalue(icon))) then route.verified = true end
    return ok
end

function SA_Secret.Usable(routeName)
    local route = routes[routeName]
    return route ~= nil and Usable(route)
end

function SA_Secret.Block(routeName, err)
    local route = routes[routeName]
    if not route then return end
    route.fails = FAILURE_LIMIT
    route.blocked = true
    route.lastError = tostring(err):sub(1, 120)
end

function SA_Secret.Succeed(routeName, secret)
    local route = routes[routeName]
    if not route then return end
    Record(route, true)
    if secret then route.verified = true end
end

function SA_Secret.SetEnabled(flag)
    enabled = flag ~= false
end

function SA_Secret.Reset()
    for _, route in pairs(routes) do
        route.fails = 0
        route.blocked = false
        route.lastError = nil
    end
end

function SA_Secret.Supported()
    return NameSupported() and IconSupported() and SinkSupported()
end

function SA_Secret.Status()
    if not SA_Secret.Supported() then return "unavailable" end
    if not enabled then return "off" end
    for _, route in pairs(routes) do
        if route.blocked then return "blocked" end
    end
    if routes.name.verified and routes.sink.verified then return "working" end
    return "ready"
end

local STATUS_WORDS = {
    working = "Hidden-spell display: working",
    ready = "Hidden-spell display: ready, no hidden spell seen yet",
    blocked = "Hidden-spell display: a route was blocked by the client, see /sa secrets",
    off = "Hidden-spell display: switched off",
    unavailable = "Hidden-spell display: not available on this client",
}

function SA_Secret.StatusText()
    return STATUS_WORDS[SA_Secret.Status()]
end

local function SelfTest()
    if not scratch then
        scratch = CreateFrame("Frame")
        scratch.text = scratch:CreateFontString()
        scratch.text:SetFontObject(GameFontNormal)
        scratch.texture = scratch:CreateTexture()
    end
    local name = Lookup(routes.name, SpellName, SELFTEST_SPELL)
    local icon = Lookup(routes.icon, SpellTexture, SELFTEST_SPELL)
    SA_Secret.Draw(scratch.text, scratch.texture, name, icon)
end

function SA_Secret.Report()
    if SA_Secret.Supported() then pcall(SelfTest) end
    local lines = { STATUS_WORDS[SA_Secret.Status()] }
    for _, key in ipairs(ORDER) do
        local route = routes[key]
        local state
        if not route.supported() then
            state = "not available on this client"
        elseif route.blocked then
            state = "blocked after " .. route.fails .. " errors: " .. (route.lastError or "unknown")
        elseif route.verified and key == "aura" then
            state = "container built and running"
        elseif route.verified then
            state = "working, confirmed with a hidden value"
        elseif key == "aura" then
            state = "available, built on demand"
        else
            state = "works for readable values, no hidden value seen yet"
        end
        lines[#lines + 1] = route.label .. ": " .. state
    end
    return lines
end
