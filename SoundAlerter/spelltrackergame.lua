local Game = {}

local SECRET_OBSERVATION = { kind = "secret" }

local function matchesAuraType(data, auraType)
    local isHarmful = data.isHarmful
    if isHarmful == nil or issecretvalue(isHarmful) then
        return true
    end
    return (auraType == "HARMFUL") == isHarmful
end

function Game.Readable(value)
    if value ~= nil and issecretvalue(value) then
        return nil
    end
    return value
end

local realObservation = { kind = "real" }

local function observe(data, spellID, auraType)
    if not data or not matchesAuraType(data, auraType) then
        return true
    end

    if issecretvalue(data.expirationTime) or issecretvalue(data.duration) then
        return true, SECRET_OBSERVATION, data.auraInstanceID
    end

    realObservation.spellID = spellID
    realObservation.expiration = data.expirationTime
    realObservation.duration = data.duration
    return true, realObservation, data.auraInstanceID
end

function Game.LookupAura(unit, spellID, auraType)
    local ok, data = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
    if not ok then
        return false
    end
    return observe(data, spellID, auraType)
end

function Game.LookupAuraByName(unit, name, spellID, auraType)
    local byName = C_UnitAuras.GetAuraDataBySpellName
    if not byName then return true end
    local ok, data = pcall(byName, unit, name, auraType)
    if not ok then
        return false
    end
    return observe(data, spellID, auraType)
end

function Game.AuraDelta(info)
    if info == nil or issecretvalue(info) then
        return false
    end
    local full, added, removed = info.isFullUpdate, info.addedAuras, info.removedAuraInstanceIDs
    if issecretvalue(full) or issecretvalue(added) or issecretvalue(removed) then
        return false
    end
    return true, added, removed
end

function Game.AddedAura(aura)
    if aura == nil or issecretvalue(aura) then
        return nil
    end
    return Game.Readable(aura.spellId), Game.Readable(aura.auraInstanceID)
end

local FINISHER_SPELLS = { 1079, 1943, 408, 22568, 8647, 2098, 26679, 22570 }
local finisherNames
local finisherByID = {}

function Game.ComboPoints()
    if not GetComboPoints then return nil end
    local ok, points = pcall(GetComboPoints, "player", "target")
    if not ok or points == nil or issecretvalue(points) then return nil end
    return points
end

function Game.IsFinisher(spellID)
    local known = finisherByID[spellID]
    if known ~= nil then return known end
    if not finisherNames then
        finisherNames = {}
        for _, id in ipairs(FINISHER_SPELLS) do
            local name = SA_COMPAT.GetSpellInfo(id)
            if name then finisherNames[name] = true end
        end
    end
    local name = SA_COMPAT.GetSpellInfo(spellID)
    if name == nil then return false end
    known = finisherNames[name] == true
    finisherByID[spellID] = known
    return known
end

function Game.ReadSpellCooldown(spellID, reading)
    local info = C_Spell.GetSpellCooldown(spellID)
    if not info or info.startTime == nil or info.duration == nil then
        return nil
    end

    if issecretvalue(info.startTime) or issecretvalue(info.duration) then
        reading.kind = "secret"
        reading.isActive = info.isActive
        reading.isOnGCD = info.isOnGCD
        reading.start = nil
        reading.duration = nil
    else
        reading.kind = "plain"
        reading.isActive = nil
        reading.isOnGCD = nil
        reading.start = info.startTime
        reading.duration = info.duration
    end
    return reading
end

function Game.AuraDurationObject(unit, auraInstanceID)
    if unit and auraInstanceID and C_UnitAuras.GetAuraDuration then
        return C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
    end
    return nil
end

function Game.SpellCooldownDurationObject(spellID)
    if C_Spell.GetSpellCooldownDuration then
        return C_Spell.GetSpellCooldownDuration(spellID, true)
    end
    return nil
end

Game.SECRET = SECRET_OBSERVATION

SA_TrackerGame = Game

do
local View = {}

View.POLL = 0.1
View.CVAR = "cooldownViewerEnabled"

local DATA_VIEWERS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }
local ALL_VIEWERS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer", "EssentialCooldownViewer", "UtilityCooldownViewer" }
local STACK_FIELDS = { "Applications", "Count", "ChargeCount", "StackCount" }
local SHOWN_CATEGORIES = { "Essential", "Utility", "TrackedBuff", "TrackedBar" }

local store
local wants, wanted, listeners, mirrors = {}, {}, {}, {}
local state, found = {}, {}
local frames, counts = {}, {}
local nameOfCid, stackRegion = {}, {}
local ticker, inCombat, configured = nil, false, false
local holder, parents = nil, {}
local events

local function Plain(value)
    if issecretvalue(value) then return nil end
    return value
end

local function SpellName(spellID)
    if type(spellID) ~= "number" then return nil end
    local ok, name = pcall(C_Spell.GetSpellName, spellID)
    return ok and Plain(name) or nil
end

local function NameOf(cid)
    local name = nameOfCid[cid]
    if name ~= nil then return name or nil end
    local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cid)
    if ok and type(info) == "table" then
        name = SpellName(Plain(info.overrideSpellID)) or SpellName(Plain(info.spellID))
    end
    nameOfCid[cid] = name or false
    return name
end

local function Pack(list, ...)
    for index = 1, select("#", ...) do list[#list + 1] = (select(index, ...)) end
end

local function Gather()
    for index = #frames, 1, -1 do frames[index] = nil end
    for index = 1, #DATA_VIEWERS do
        local viewer = _G[DATA_VIEWERS[index]]
        if viewer then
            counts[index] = viewer:GetNumChildren()
            Pack(frames, viewer:GetChildren())
        end
    end
end

local function ChildrenChanged()
    for index = 1, #DATA_VIEWERS do
        local viewer = _G[DATA_VIEWERS[index]]
        if viewer and viewer:GetNumChildren() ~= counts[index] then return true end
    end
    return false
end

local function CooldownID(frame)
    local cid = frame.cooldownID
    if cid == nil and frame.GetCooldownID then
        local ok, value = pcall(frame.GetCooldownID, frame)
        if ok then cid = value end
    end
    return Plain(cid)
end

local function AuraUp(frame)
    local aura = frame.auraInstanceID
    return issecretvalue(aura) or aura ~= nil
end

local function StackOf(frame)
    local region = stackRegion[frame]
    if region == nil then
        region = false
        for index = 1, #STACK_FIELDS do
            local field = STACK_FIELDS[index]
            local candidate = frame[field]
            if type(candidate) == "table" then
                local inner = candidate.GetText and candidate or candidate[field]
                if type(inner) == "table" and inner.GetText then
                    region = inner
                    break
                end
            end
        end
        stackRegion[frame] = region
    end
    return region or nil
end

local function Notify(name, on)
    for owner, fn in pairs(listeners) do
        local set = wants[owner]
        if set and set[name] then fn(name, on) end
    end
end

local function Poll()
    if ChildrenChanged() then Gather() end
    for name in pairs(wanted) do found[name] = nil end
    for index = 1, #frames do
        local frame = frames[index]
        local cid = CooldownID(frame)
        local name = cid and NameOf(cid)
        if name and wanted[name] then
            if AuraUp(frame) then
                found[name] = frame
            elseif not found[name] then
                found[name] = false
            end
        end
    end
    for name in pairs(wanted) do
        local hit = found[name]
        local on
        if hit then on = true elseif hit == false then on = false end
        local was = state[name]
        if was ~= on then
            state[name] = on
            if on or (on == false and was) then Notify(name, on) end
        end
        local text = mirrors[name]
        if text then
            local region = hit and StackOf(hit)
            if region then
                local ok, value = pcall(region.GetText, region)
                text:SetText(ok and value or "")
            elseif text.saCleared ~= true then
                text:SetText("")
            end
            text.saCleared = not region
        end
    end
end

local function ReadCVar()
    if C_CVar and C_CVar.GetCVar then
        local ok, value = pcall(C_CVar.GetCVar, View.CVAR)
        if ok then return value end
    end
    return nil
end

local function WriteCVar(value)
    if C_CVar and C_CVar.SetCVar then return (pcall(C_CVar.SetCVar, View.CVAR, value)) end
    return false
end

function View.Available()
    if not (C_CooldownViewer and C_CooldownViewer.IsCooldownViewerAvailable) then return false end
    local ok, available = pcall(C_CooldownViewer.IsCooldownViewerAvailable)
    return ok and Plain(available) == true
end

function View.Use()
    return store and store.use
end

function View.Live()
    return ticker ~= nil
end

local function ClearStates()
    for name, on in pairs(state) do
        state[name] = nil
        if on then Notify(name, nil) end
    end
    for _, text in pairs(mirrors) do
        if text.saCleared ~= true then
            text:SetText("")
            text.saCleared = true
        end
    end
end

local function Update()
    local want = configured and inCombat and next(wanted) ~= nil and store.use == true and ReadCVar() == "1"
    if want and not ticker then
        Gather()
        ticker = C_Timer.NewTicker(View.POLL, Poll)
        Poll()
    elseif ticker and not want then
        ticker:Cancel()
        ticker = nil
        ClearStates()
    end
end

local hiding, zeroing = false, false
local hooked, savedAlpha = {}, {}

local function Zero(viewer)
    zeroing = true
    viewer:SetAlpha(0)
    zeroing = false
end

local function OnViewerAlpha(viewer, alpha)
    if hiding and not zeroing and alpha ~= 0 then Zero(viewer) end
end

local function ApplyHide()
    local hide = store and store.use == true or false
    hiding = hide
    local calm = not InCombatLockdown()
    if hide and calm and not holder then
        holder = CreateFrame("Frame", nil, UIParent)
        holder:SetAllPoints(UIParent)
        holder:SetAlpha(0)
    end
    for index = 1, #ALL_VIEWERS do
        local viewer = _G[ALL_VIEWERS[index]]
        if viewer then
            if hide then
                if not hooked[viewer] and hooksecurefunc then
                    hooked[viewer] = true
                    hooksecurefunc(viewer, "SetAlpha", OnViewerAlpha)
                end
                if savedAlpha[viewer] == nil then savedAlpha[viewer] = viewer:GetAlpha() end
                if viewer:GetAlpha() ~= 0 then Zero(viewer) end
                if calm and not parents[viewer] then
                    parents[viewer] = viewer:GetParent()
                    viewer:SetParent(holder)
                end
            else
                if savedAlpha[viewer] ~= nil then
                    viewer:SetAlpha(savedAlpha[viewer])
                    savedAlpha[viewer] = nil
                end
                if calm and parents[viewer] then
                    viewer:SetParent(parents[viewer])
                    parents[viewer] = nil
                end
            end
        end
    end
end

local function Shown(category)
    local cats = Enum and Enum.CooldownViewerCategory
    if not cats then return true end
    for index = 1, #SHOWN_CATEGORIES do
        if category == cats[SHOWN_CATEGORIES[index]] then return true end
    end
    return false
end

local function Provider()
    local settings = _G.CooldownViewerSettings
    if not (settings and settings.GetDataProvider) then return nil end
    local ok, provider = pcall(settings.GetDataProvider, settings)
    if ok and type(provider) == "table" then return provider, settings end
    return nil
end

local function Save(provider, settings)
    local manager
    if provider.GetLayoutManager then
        local ok, value = pcall(provider.GetLayoutManager, provider)
        if ok then manager = value end
    end
    if type(manager) ~= "table" and settings.GetLayoutManager then
        local ok, value = pcall(settings.GetLayoutManager, settings)
        if ok then manager = value end
    end
    if type(manager) == "table" and manager.SaveLayouts then pcall(manager.SaveLayouts, manager) end
end

local function CategoryOf(provider, cid)
    if not provider.GetCooldownInfoForID then return nil end
    local ok, info = pcall(provider.GetCooldownInfoForID, provider, cid)
    return ok and type(info) == "table" and info.category or nil
end

local function HiddenAuraIDs(names, out)
    local cats = Enum and Enum.CooldownViewerCategory
    if not cats then return out end
    for _, value in pairs(cats) do
        if not Shown(value) then
            local ok, ids = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, value, true)
            if ok and type(ids) == "table" then
                for index = 1, #ids do
                    local cid = ids[index]
                    local okInfo, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cid)
                    if okInfo and type(info) == "table" and Plain(info.hasAura) then
                        local name = SpellName(Plain(info.overrideSpellID)) or SpellName(Plain(info.spellID))
                        if name and names[name] then out[#out + 1] = cid end
                    end
                end
            end
        end
    end
    return out
end

function View.ApplyAtLogout()
    if not store then return end
    if store.use == true then
        local cvar = ReadCVar()
        if cvar ~= "1" then
            if store.cvarBefore == nil then store.cvarBefore = cvar or "0" end
            WriteCVar("1")
        end
        if not next(store.wanted) then return end
        local provider, settings = Provider()
        if not provider or not provider.SetCooldownToCategory then return end
        local tracked = Enum.CooldownViewerCategory.TrackedBuff
        local changed = false
        for _, cid in ipairs(HiddenAuraIDs(store.wanted, {})) do
            local category = CategoryOf(provider, cid)
            if category ~= nil and not Shown(category) and pcall(provider.SetCooldownToCategory, provider, cid, tracked) then
                store.moved[cid] = category
                changed = true
            end
        end
        if changed then Save(provider, settings) end
    elseif store.use == false then
        if next(store.moved) then
            local provider, settings = Provider()
            if provider and provider.SetCooldownToCategory then
                for cid, category in pairs(store.moved) do
                    pcall(provider.SetCooldownToCategory, provider, cid, category)
                    store.moved[cid] = nil
                end
                Save(provider, settings)
            end
        end
        if store.cvarBefore ~= nil then
            WriteCVar(store.cvarBefore)
            store.cvarBefore = nil
        end
    end
end

local function OnEvent(_, event, name)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        ApplyHide()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        ApplyHide()
    elseif event == "PLAYER_ENTERING_WORLD" then
        inCombat = InCombatLockdown() and true or false
        ApplyHide()
    elseif event == "ADDON_LOADED" then
        if name ~= "Blizzard_CooldownViewer" then return end
        ApplyHide()
    elseif event == "COOLDOWN_VIEWER_DATA_LOADED" then
        for cid in pairs(nameOfCid) do nameOfCid[cid] = nil end
        for frame in pairs(stackRegion) do stackRegion[frame] = nil end
        for index in pairs(counts) do counts[index] = -1 end
        ApplyHide()
    elseif event == "PLAYER_LOGOUT" then
        View.ApplyAtLogout()
        return
    end
    Update()
end

function View.Configure(saved)
    store = saved
    store.wanted = store.wanted or {}
    store.moved = store.moved or {}
    if not configured then
        configured = true
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
        for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "ADDON_LOADED" }) do
            events:RegisterEvent(event)
        end
        pcall(events.RegisterEvent, events, "COOLDOWN_VIEWER_DATA_LOADED")
    end
    for name in pairs(wanted) do store.wanted[name] = true end
    inCombat = InCombatLockdown() and true or false
    ApplyHide()
    Update()
end

local function Rewant()
    for name in pairs(wanted) do wanted[name] = nil end
    for _, set in pairs(wants) do
        for name in pairs(set) do wanted[name] = true end
    end
    if store then
        for name in pairs(store.wanted) do
            if not wanted[name] then store.wanted[name] = nil end
        end
        for name in pairs(wanted) do store.wanted[name] = true end
    end
    for name in pairs(state) do
        if not wanted[name] then state[name] = nil end
    end
    Update()
end

function View.Want(owner, names)
    wants[owner] = names and next(names) and names or nil
    Rewant()
end

function View.Listen(owner, fn)
    listeners[owner] = fn
end

function View.State(name)
    return state[name]
end

function View.Mirror(name, text)
    local old = mirrors[name]
    if old and old ~= text and old.saCleared ~= true then
        old:SetText("")
        old.saCleared = true
    end
    mirrors[name] = text
end

function View.SetUse(use)
    if not store then return end
    store.use = use
    ApplyHide()
    Update()
end

SA_CooldownView = View
end
