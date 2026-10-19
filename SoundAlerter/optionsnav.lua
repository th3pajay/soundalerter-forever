SA_OptionsNav = {}

local Nav = SA_OptionsNav
local Rail = SA_OptionsRail

local APP = "SoundAlerter"
local MAX_HITS = 40
local MAX_DEPTH = 3
local SKIPPED = { searchBox = true, searchResults = true, cardHeader = true }
local SEARCHABLE = { toggle = true, range = true, select = true, color = true, input = true }
local INFO_FIELDS = { "get", "set", "validate", "confirm" }

Nav.query = ""
Nav.resultGroups = {}

local searchWrapped = setmetatable({}, { __mode = "k" })

Nav.Sections = {
    { name = "Setup", order = 0, keys = { QuickStart = 1, General = 2, MinimapButton = 3 } },
    { name = "Alerts", order = 10, sorted = true, keys = { Spells = 11, ProximityAlerts = 12, BattlegroundAlerts = 13, Notices = 15 } },
    { name = "Displays", order = 20, sorted = true, keys = { ResourceBar = 21, CastingBars = 22, CastFeed = 23, CombatTimer = 24, SpeedMeter = 25, Footsteps = 26, SpellTracker = 27 } },
    { name = "Tools", order = 30, sorted = true, keys = { Statistics = 31, FindSpell = 32, custom = 33 } },
    { name = "Profile", order = 40, keys = { profiles = 41 } },
}

Nav.SearchFamilies = {}

local function notifyChange()
    local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if registry then registry:NotifyChange(APP) end
end

function Nav.Searching()
    return Nav.query ~= ""
end

function Nav.Heading(name, order)
    return {
        type = 'group',
        name = "|cff8a93a3" .. string.upper(name) .. "|r",
        disabled = true,
        order = order,
        args = {},
    }
end

function Nav.SortKey(node)
    local name = node and node.name
    if type(name) == "function" then
        local ok, value = pcall(name)
        name = ok and value or ""
    end
    name = tostring(name or "")
    name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
    name = string.gsub(name, "|r", "")
    name = string.gsub(name, "|T.-|t", "")
    return string.lower((string.gsub(name, "^%s+", "")))
end

local function sortedKeys(root, section)
    local list = {}
    for key in pairs(section.keys) do
        if root.args[key] then list[#list + 1] = { key = key, label = Nav.SortKey(root.args[key]) } end
    end
    table.sort(list, function(a, b)
        if a.label ~= b.label then return a.label < b.label end
        return a.key < b.key
    end)
    return list
end

function Nav.Layout(root)
    for _, section in ipairs(Nav.Sections) do
        root.args["navHeading" .. section.name] = Nav.Heading(section.name, section.order)
        if section.sorted then
            for index, entry in ipairs(sortedKeys(root, section)) do
                root.args[entry.key].order = section.order + index
            end
        else
            for key, order in pairs(section.keys) do
                if root.args[key] then root.args[key].order = order end
            end
        end
    end
    Nav.resultGroups = {}
    Nav.Finalize(root)
    for _, path in ipairs(Nav.SearchFamilies) do
        local group = Nav.Resolve(root, path)
        if group then Nav.AttachSearch(root, path, group) end
    end
    return root
end

function Nav.Resolve(root, path)
    local node = root
    for _, key in ipairs(path) do
        node = node.args and node.args[key]
        if type(node) ~= "table" then return nil end
    end
    return node
end

local function chainOf(root, path)
    local chain = { root }
    local node = root
    for _, key in ipairs(path) do
        node = node.args[key]
        chain[#chain + 1] = node
    end
    return chain
end

local function firstOf(chain, field)
    for index = #chain, 1, -1 do
        local value = chain[index][field]
        if value ~= nil then return value end
    end
end

function Nav.Info(root, path, option)
    local info = {
        [0] = APP,
        appName = APP,
        options = root,
        option = option,
        arg = option.arg,
        type = option.type,
        uiType = "dialog",
        uiName = "AceConfigDialog-3.0",
    }
    for index, key in ipairs(path) do info[index] = key end
    return info
end

local function evaluate(value, root, path, option, ...)
    if type(value) == "function" then
        local ok, result = pcall(value, Nav.Info(root, path, option), ...)
        if ok then return result end
        return nil
    end
    return value
end

local function blocked(chain, root, path, field)
    for index = 2, #chain do
        local node = chain[index]
        local value = node[field]
        if field == "hidden" then value = Rail.HiddenRule(node) end
        if evaluate(value, root, path, node) then return true end
    end
    return false
end

local function extend(path, key)
    local copy = { unpack(path) }
    copy[#copy + 1] = key
    return copy
end

local function count(root, path, group)
    local chain = chainOf(root, path)
    local get = firstOf(chain, "get")
    local on, total = 0, 0
    for key, option in pairs(group.args) do
        if type(option) == "table" and option.type == 'toggle' then
            local read = option.get or get
            if type(read) == "function" then
                total = total + 1
                local ok, value = pcall(read, Nav.Info(root, extend(path, key), option))
                if ok and value then on = on + 1 end
            end
        end
    end
    return on, total
end

function Nav.Finalize(root)
    local function visit(node, path, depth)
        if depth > MAX_DEPTH or type(node.args) ~= "table" then return end
        for key, child in pairs(node.args) do
            if type(child) == "table" and child.type == 'group' then
                local childPath = extend(path, key)
                if Rail.Cards[child] then
                    Rail.Cards[child].tag = function()
                        local on, total = count(root, childPath, child)
                        if total == 0 then return "" end
                        return "  |cff8a93a3" .. on .. "/" .. total .. " on|r"
                    end
                end
                visit(child, childPath, depth + 1)
            end
        end
    end
    visit(root, {}, 1)
end

local function matches(text, query)
    return text ~= nil and string.find(string.lower(text), query, 1, true) ~= nil
end

function Nav.Hits(root, query)
    local hits = {}
    query = string.lower(query)
    for _, familyPath in ipairs(Nav.SearchFamilies) do
        local family = Nav.Resolve(root, familyPath)
        if family then
            local moduleName = Nav.Resolve(root, { familyPath[1] }).name
            local function walk(node, path, cardTitle)
                local keys = {}
                for key in pairs(node.args) do keys[#keys + 1] = key end
                table.sort(keys, function(a, b)
                    return (node.args[a].order or 100) < (node.args[b].order or 100) or
                        ((node.args[a].order or 100) == (node.args[b].order or 100) and a < b)
                end)
                for _, key in ipairs(keys) do
                    local option = node.args[key]
                    if #hits >= MAX_HITS then return end
                    if type(option) == "table" and not SKIPPED[key] then
                        local optionPath = extend(path, key)
                        if option.type == 'group' and option.args then
                            local card = Rail.Cards[option]
                            local title = card and card.title or cardTitle
                            walk(option, optionPath, title)
                        elseif SEARCHABLE[option.type] then
                            local label = evaluate(option.name, root, optionPath, option)
                            if type(label) == "string" and (matches(label, query) or matches(cardTitle, query) or matches(moduleName, query)) then
                                hits[#hits + 1] = { option = option, path = optionPath, module = moduleName, card = cardTitle, family = familyPath }
                            end
                        end
                    end
                end
            end
            walk(family, familyPath, nil)
        end
    end
    return hits
end

local function wrap(fn, root, path, option)
    return function(_, ...)
        return fn(Nav.Info(root, path, option), ...)
    end
end

function Nav.Proxy(root, hit)
    local option, path = hit.option, hit.path
    local chain = chainOf(root, path)
    local proxy = {}
    for key, value in pairs(option) do proxy[key] = value end
    for key, value in pairs(proxy) do
        if type(value) == "function" then proxy[key] = wrap(value, root, path, option) end
    end
    for _, field in ipairs(INFO_FIELDS) do
        if proxy[field] == nil then
            local inherited = firstOf(chain, field)
            if type(inherited) == "function" then proxy[field] = wrap(inherited, root, path, option) end
        end
    end
    proxy.disabled = function() return blocked(chain, root, path, "disabled") end
    proxy.hidden = function() return blocked(chain, root, path, "hidden") end
    return proxy
end

local function jump(root, hit)
    return function()
        for length = 1, #hit.path - 1 do
            local ancestor = Nav.Resolve(root, { unpack(hit.path, 1, length) })
            local card = ancestor and Rail.Cards[ancestor]
            if card then Rail.SetCollapsed(card.key, false) end
        end
        Nav.query = ""
        Nav.Refresh(root)
        local dialog = LibStub and LibStub("AceConfigDialog-3.0", true)
        if dialog then dialog:SelectGroup(APP, unpack(hit.family)) end
        notifyChange()
    end
end

function Nav.Refresh(root)
    local hits = Nav.Searching() and Nav.Hits(root, Nav.query) or {}
    for _, group in ipairs(Nav.resultGroups) do
        group.args = {}
        if #hits == 0 then
            group.args.empty = { type = 'description', name = "|cff8a93a3No alert settings match.|r", width = "full", order = 1 }
        end
        for index, hit in ipairs(hits) do
            local where = hit.module .. (hit.card and (" > " .. hit.card) or "")
            group.args["hitLink" .. index] = {
                type = 'execute',
                name = "|cff8a93a3" .. where .. "|r",
                desc = "Go to this section",
                width = "full",
                order = index * 2,
                func = jump(root, hit),
            }
            group.args["hit" .. index] = Nav.Proxy(root, hit)
            group.args["hit" .. index].order = index * 2 + 1
        end
    end
end

function Nav.SetQuery(root, value)
    Nav.query = string.lower((string.gsub(value or "", "^%s*(.-)%s*$", "%1")))
    Nav.Refresh(root)
    notifyChange()
end

function Nav.AttachSearch(root, path, group)
    local results = {
        type = 'group',
        inline = true,
        name = function() return "Results for \"" .. Nav.query .. "\"" end,
        hidden = function() return not Nav.Searching() end,
        order = 0.2,
        args = {},
    }
    for _, child in pairs(group.args) do
        if type(child) == "table" and not searchWrapped[child] then
            searchWrapped[child] = true
            Rail.HideWhen(child, Nav.Searching)
        end
    end
    group.args.searchBox = {
        type = 'input',
        name = "Search alert settings",
        desc = "Type part of a setting name, then press Enter. Searches Proximity, Battleground and Chat alerts.",
        width = "full",
        order = 0,
        get = function() return Nav.query end,
        set = function(_, value) Nav.SetQuery(root, value) end,
    }
    group.args.searchResults = results
    Nav.resultGroups[#Nav.resultGroups + 1] = results
end

function Nav.RememberPage(dialog, store)
    local ok, status = pcall(dialog.GetStatusTable, dialog, APP)
    if ok and status and status.groups and status.groups.selected then
        store.lastPage = status.groups.selected
    end
end

function Nav.RestorePage(dialog, store)
    if not store.lastPage then return end
    local ok, status = pcall(dialog.GetStatusTable, dialog, APP)
    if ok and status then
        status.groups = status.groups or {}
        status.groups.selected = store.lastPage
    end
end
