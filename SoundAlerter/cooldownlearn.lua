SA_CooldownLearn = {}

local Learn = SA_CooldownLearn

Learn.MIN_LENGTH = 1.7
Learn.AGREE = 0.4

local math_abs, math_floor = math.abs, math.floor

local function Tenths(value)
    return math_floor(value * 10 + 0.5) / 10
end

function Learn.Store(char)
    local store = char.learnedCooldowns
    if type(store) ~= "table" or type(store.cooldowns) ~= "table" or type(store.pending) ~= "table" then
        store = { cooldowns = {}, pending = {} }
        char.learnedCooldowns = store
    end
    return store
end

function Learn.Expected(store, spellID, known)
    return store.cooldowns[spellID] or known
end

function Learn.Read(spellID)
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if not ok or issecretvalue(info) or type(info) ~= "table" then return nil end
    local start, duration = info.startTime, info.duration
    if type(start) == "number" and type(duration) == "number"
        and not issecretvalue(start) and not issecretvalue(duration) then
        return "plain", duration
    end
    if issecretvalue(info.isActive) then return "flag", nil end
    local onGCD = info.isOnGCD
    if issecretvalue(onGCD) then onGCD = nil end
    return "flag", info.isActive, onGCD
end

function Learn.Note(store, spellID, length, exact, known)
    if not length or length <= Learn.MIN_LENGTH then return false end
    length = Tenths(length)
    local cooldowns, pending = store.cooldowns, store.pending
    if exact then
        cooldowns[spellID], pending[spellID] = length, nil
        return true
    end
    local reference = cooldowns[spellID] or known
    if reference and math_abs(length - reference) <= Learn.AGREE then
        pending[spellID] = nil
        return false
    end
    local waiting = pending[spellID]
    if reference and not (waiting and math_abs(length - waiting) <= Learn.AGREE) then
        pending[spellID] = length
        return false
    end
    cooldowns[spellID], pending[spellID] = length, nil
    return true
end

local watching

function Learn.Stop()
    if watching then
        SA_CooldownWatch.Cancel(watching)
        watching = nil
    end
end

function Learn.Start(spellID, store, known)
    Learn.Stop()
    local kind, value = Learn.Read(spellID)
    if kind == "plain" and value > Learn.MIN_LENGTH then
        Learn.Note(store, spellID, value, true, known)
        return
    end
    local at = GetTime()
    watching = spellID
    SA_CooldownWatch.Once(spellID, function(now)
        watching = nil
        Learn.Note(store, spellID, now - at, false, known)
    end)
end

SA_CooldownWatch = {}

do
    local Watch = SA_CooldownWatch
    local Plain = SA_COMPAT.Plain
    local GetTime, pcall, pairs, type, next, wipe = GetTime, pcall, pairs, type, next, wipe
    local string_lower = string.lower
    local issecretvalue, debugprofilestop = issecretvalue, debugprofilestop
    local GetSpellCooldown, GetSpellCooldownDuration = C_Spell.GetSpellCooldown, C_Spell.GetSpellCooldownDuration
    local GetSpellCharges, GetSpellChargeDuration, GetSpellName = C_Spell.GetSpellCharges, C_Spell.GetSpellChargeDuration, C_Spell.GetSpellName

    Watch.CATEGORIES = { "class", "charges", "racial", "pet", "profession", "trinket", "equipped", "potion", "healthstone", "usable" }
    Watch.ITEM_CATEGORY = { trinket = true, equipped = true, potion = true, healthstone = true, usable = true }
    Watch.SHARED = { potion = true, healthstone = true }
    Watch.NO_COOLDOWN_AFTER = 3
    Watch.PET_SLOTS = 10
    Watch.HEALTHSTONES = {
        [5509] = true, [5510] = true, [5511] = true, [5512] = true, [9421] = true,
        [19004] = true, [19005] = true, [19006] = true, [19007] = true, [19008] = true,
        [19009] = true, [19010] = true, [19011] = true, [19012] = true, [19013] = true,
        [22103] = true, [22104] = true, [22105] = true,
    }

    local CLASS_CONSUMABLE, SUB_POTION, SUB_BANDAGE, CLASS_RECIPE = 0, 1, 7, 9
    local TRINKET_SLOTS = { [13] = true, [14] = true }
    local LAST_SLOT, LAST_BAG = 19, 4

    local subscribers, subscriberCount = {}, 0
    local onceFn = {}
    local mask = {}
    local minimum = 2.5
    local ignoreIDs, ignoreNames = {}, {}
    local spellIgnored = {}
    local armed = { spell = {}, charge = {}, item = {}, slot = {}, pet = {}, shared = {}, once = {} }
    local pool, made = {}, 0
    local lineOf = {}
    local isCharge, chargeList = {}, {}
    local noCount, seenCooldown = {}, {}
    local items, slotList, bagList, noUse, seen = {}, {}, {}, {}, {}
    local sharedDone = {}
    local bookSize
    local dirtySlots, dirtyBags = true, true
    local scannedAt
    local counts = { arms = 0, rejects = 0, reads = 0, ready = 0, events = 0, ms = 0 }
    local ARMED_KINDS = { "spell", "charge", "item", "slot", "pet", "shared" }
    local wanted = {}
    Watch.counts = counts
    Watch.armed = armed

    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(1, 1)
    holder:SetPoint("CENTER")
    holder:SetAlpha(0)
    local events = CreateFrame("Frame")

    local function Release(cd)
        local list = cd.kind and armed[cd.kind]
        if list and list[cd.id] == cd then list[cd.id] = nil end
        cd.kind, cd.id, cd.category, cd.ends, cd.item = nil, nil, nil, nil, nil
        pool[#pool + 1] = cd
    end

    local function Done(cd)
        local kind, id, category, since, item = cd.kind, cd.id, cd.category, cd.since, cd.item
        if not kind then return end
        Release(cd)
        local now = GetTime()
        if kind == "once" then
            local fn = onceFn[id]
            onceFn[id] = nil
            if fn then fn(now) end
            Watch.Listen()
            return
        end
        if now - since < minimum then return end
        if kind == "shared" then
            if not item then return end
            kind, id = "item", item
        end
        counts.ready = counts.ready + 1
        for _, fn in pairs(subscribers) do fn(kind, id, category) end
    end

    local function Acquire(kind, id, category)
        local list = armed[kind]
        local cd = list[id]
        if cd then return cd end
        local count = #pool
        if count > 0 then
            cd = pool[count]
            pool[count] = nil
        else
            cd = CreateFrame("Cooldown", nil, holder)
            cd:SetSize(1, 1)
            cd:SetPoint("CENTER")
            cd:SetDrawSwipe(false)
            cd:SetDrawEdge(false)
            cd:SetDrawBling(false)
            cd:SetHideCountdownNumbers(true)
            cd:SetScript("OnCooldownDone", Done)
            made = made + 1
        end
        cd.kind, cd.id, cd.category, cd.since = kind, id, category, GetTime()
        list[id] = cd
        counts.arms = counts.arms + 1
        return cd
    end

    local function Drop(kind, id)
        local cd = armed[kind][id]
        if not cd then return end
        Release(cd)
        cd:Clear()
    end

    local function ArmDuration(kind, id, category, object)
        local cd = Acquire(kind, id, category)
        cd:SetCooldownFromDurationObject(object, true)
    end

    local function ArmPlain(kind, id, category, start, duration)
        local ends = start + duration
        if ends <= GetTime() then return nil end
        local cd = armed[kind][id]
        if cd and cd.ends == ends then return cd end
        cd = Acquire(kind, id, category)
        cd.ends = ends
        cd:SetCooldown(start, duration)
        return cd
    end

    local function Ignored(spellID)
        local known = spellIgnored[spellID]
        if known ~= nil then return known end
        local name = GetSpellName and Plain(GetSpellName(spellID))
        known = ignoreIDs[spellID] == true or (name ~= nil and ignoreNames[string_lower(name)] == true)
        spellIgnored[spellID] = known
        return known
    end

    local function Once(spellID)
        local ok, object = pcall(GetSpellCooldownDuration, spellID, true)
        if ok and object then ArmDuration("once", spellID, nil, object) end
    end

    local function Spell(spellID)
        if isCharge[spellID] or Ignored(spellID) then return end
        local category = lineOf[spellID] or "class"
        if not mask[category] then return end
        if not seenCooldown[spellID] and (noCount[spellID] or 0) >= Watch.NO_COOLDOWN_AFTER then
            counts.rejects = counts.rejects + 1
            return
        end
        counts.reads = counts.reads + 1
        local ok, info = pcall(GetSpellCooldown, spellID)
        if not ok or issecretvalue(info) or type(info) ~= "table" then return end
        local start, duration = Plain(info.startTime), Plain(info.duration)
        local real
        if start and duration then
            real = start > 0 and duration > minimum
        else
            local active, onGCD = Plain(info.isActive), Plain(info.isOnGCD)
            if active == false then real = false elseif active == true then real = onGCD ~= true end
        end
        if real == false then
            if not seenCooldown[spellID] then noCount[spellID] = (noCount[spellID] or 0) + 1 end
            local cd = armed.spell[spellID]
            if cd then Done(cd) cd:Clear() end
            return
        end
        if real then seenCooldown[spellID] = true end
        local okD, object = pcall(GetSpellCooldownDuration, spellID, true)
        if okD and object then
            ArmDuration("spell", spellID, category, object)
        elseif start then
            ArmPlain("spell", spellID, category, start, duration)
        end
    end

    local function Charges()
        if not mask.charges then return end
        for index = 1, #chargeList do
            local spellID = chargeList[index]
            if not Ignored(spellID) then
                local ok, info = pcall(GetSpellCharges, spellID)
                if ok and type(info) == "table" and not issecretvalue(info) then
                    local current, most = Plain(info.currentCharges), Plain(info.maxCharges)
                    if current and most and current >= most then
                        Drop("charge", spellID)
                    else
                        local okD, object = pcall(GetSpellChargeDuration, spellID)
                        if okD and object then ArmDuration("charge", spellID, "charges", object) end
                    end
                end
            end
        end
    end

    local function ItemCooldown(entry)
        if entry.slot then return SA_COMPAT.InventoryCooldown(entry.slot) end
        return SA_COMPAT.ItemCooldown(entry.id)
    end

    local function ArmItems(list)
        for index = 1, #list do
            local entry = list[index]
            local category = entry.category
            if mask[category] and not entry.ignored then
                local shared = Watch.SHARED[category]
                if not (shared and sharedDone[category]) then
                    local ok, start, duration = pcall(ItemCooldown, entry)
                    if ok and start and duration and start > 0 and duration > minimum then
                        if shared then
                            sharedDone[category] = true
                            local cd = ArmPlain("shared", category, category, start, duration)
                            if cd then cd.item = entry.id end
                        elseif entry.slot then
                            ArmPlain("slot", entry.slot, category, start, duration)
                        else
                            ArmPlain("item", entry.id, category, start, duration)
                        end
                    end
                end
            end
        end
    end

    local function Items()
        local now = GetTime()
        if now == scannedAt then return end
        scannedAt = now
        wipe(sharedDone)
        ArmItems(slotList)
        ArmItems(bagList)
    end

    local function Pets()
        if not mask.pet or not GetPetActionCooldown then return end
        for slot = 1, Watch.PET_SLOTS do
            local ok, start, duration = pcall(GetPetActionCooldown, slot)
            start, duration = ok and Plain(start), ok and Plain(duration)
            if start and duration and start > 0 and duration > minimum then
                ArmPlain("pet", slot, "pet", start, duration)
            end
        end
    end

    local function BookSize(api)
        local ok, lines = pcall(api.GetNumSpellBookSkillLines)
        local total = 0
        for line = 1, ok and Plain(lines) or 0 do
            local okL, info = pcall(api.GetSpellBookSkillLineInfo, line)
            total = total * 31 + (okL and type(info) == "table" and Plain(info.numSpellBookItems) or 0)
        end
        return total
    end

    local function ScanBook(force)
        local api = C_SpellBook
        if not (api and api.GetNumSpellBookSkillLines and api.GetSpellBookSkillLineInfo and api.GetSpellBookItemInfo) then return end
        local size = BookSize(api)
        if size == bookSize and not force then return end
        bookSize = size
        wipe(lineOf)
        wipe(isCharge)
        wipe(chargeList)
        wipe(noCount)
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local function Mark(first, count, category)
            for index = first, first + count - 1 do
                local ok, item = pcall(api.GetSpellBookItemInfo, index, bank)
                local spellID = ok and type(item) == "table" and Plain(item.spellID)
                if spellID then
                    lineOf[spellID] = category
                    local most = SA_COMPAT.GetSpellMaxCharges(spellID)
                    if most and most > 1 and not isCharge[spellID] then
                        isCharge[spellID] = true
                        chargeList[#chargeList + 1] = spellID
                    end
                end
            end
        end
        local ok, lines = pcall(api.GetNumSpellBookSkillLines)
        for line = 1, ok and Plain(lines) or 0 do
            local okL, info = pcall(api.GetSpellBookSkillLineInfo, line)
            if okL and type(info) == "table" then
                local offset, count = Plain(info.itemIndexOffset), Plain(info.numSpellBookItems)
                if offset and count then Mark(offset + 1, count, line == 1 and "racial" or "class") end
            end
        end
        if GetProfessions and GetProfessionInfo then
            local okP, a, b, c, d, e = pcall(GetProfessions)
            if okP then
                for _, index in pairs({ a, b, c, d, e }) do
                    local okI, _, _, _, _, count, offset = pcall(GetProfessionInfo, index)
                    count, offset = okI and Plain(count), okI and Plain(offset)
                    if count and offset then Mark(offset + 1, count, "profession") end
                end
            end
        end
    end

    local function NoteItem(list, itemID, slot)
        if not itemID or noUse[itemID] then return end
        local key = slot and -slot or itemID
        local entry = items[key]
        if entry and entry.id == itemID then
            list[#list + 1] = entry
            return
        end
        local getSpell = C_Item and C_Item.GetItemSpell
        if not getSpell then return end
        local ok, spellName, spellID = pcall(getSpell, itemID)
        if not ok or not Plain(spellID) then
            noUse[itemID] = true
            return
        end
        local info = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
        local okI, _, _, _, _, icon, classID, subClassID = pcall(info, itemID)
        classID, subClassID = okI and Plain(classID), okI and Plain(subClassID)
        if not slot and classID == CLASS_RECIPE then
            noUse[itemID] = true
            return
        end
        local category
        if slot then
            category = TRINKET_SLOTS[slot] and "trinket" or "equipped"
        elseif Watch.HEALTHSTONES[itemID] or (type(spellName) == "string" and spellName:find("Healthstone")) or (classID == CLASS_CONSUMABLE and subClassID == SUB_BANDAGE) then
            category = "healthstone"
        elseif classID == CLASS_CONSUMABLE and subClassID == SUB_POTION then
            category = "potion"
        else
            category = "usable"
        end
        if not entry then
            entry = {}
            items[key] = entry
        end
        entry.id, entry.slot, entry.category, entry.icon = itemID, slot, category, okI and Plain(icon) or nil
        local name = SA_COMPAT.ItemName(itemID)
        entry.ignored = ignoreIDs[itemID] == true or ignoreIDs[Plain(spellID)] == true or (name ~= nil and ignoreNames[string_lower(name)] == true)
        list[#list + 1] = entry
    end

    local function ScanSlots()
        if InCombatLockdown() then
            dirtySlots = true
            return
        end
        dirtySlots = false
        wipe(slotList)
        for slot = 1, LAST_SLOT do NoteItem(slotList, SA_COMPAT.InventoryItemID(slot), slot) end
        scannedAt = nil
    end

    local function ScanBags()
        if InCombatLockdown() then
            dirtyBags = true
            return
        end
        dirtyBags = false
        wipe(bagList)
        wipe(seen)
        for bag = 0, LAST_BAG do
            for index = 1, SA_COMPAT.ContainerSlots(bag) do
                local itemID = SA_COMPAT.ContainerItemID(bag, index)
                if itemID and not seen[itemID] then
                    seen[itemID] = true
                    NoteItem(bagList, itemID, nil)
                end
            end
        end
        scannedAt = nil
    end

    local function ScanItems()
        ScanSlots()
        ScanBags()
    end

    local ON = {}

    function ON.SPELL_UPDATE_COOLDOWN(spellID)
        spellID = Plain(spellID)
        if spellID then
            if onceFn[spellID] then Once(spellID) end
            if subscriberCount > 0 then Spell(spellID) end
            return
        end
        for id in pairs(onceFn) do Once(id) end
        if subscriberCount > 0 then
            for id in pairs(armed.spell) do Spell(id) end
        end
    end

    ON.SPELL_UPDATE_CHARGES = Charges
    ON.BAG_UPDATE_COOLDOWN = Items
    ON.PET_BAR_UPDATE_COOLDOWN = Pets

    function ON.SPELLS_CHANGED()
        ScanBook()
    end

    ON.BAG_UPDATE_DELAYED = ScanBags
    ON.PLAYER_EQUIPMENT_CHANGED = ScanSlots

    function ON.PLAYER_REGEN_ENABLED()
        if dirtySlots then ScanSlots() end
        if dirtyBags then ScanBags() end
    end

    function ON.UNIT_PET()
        Watch.Listen()
    end

    function ON.PLAYER_ENTERING_WORLD()
        ScanBook(true)
        ScanItems()
    end

    events:SetScript("OnEvent", function(_, event, ...)
        local started = debugprofilestop()
        counts.events = counts.events + 1
        ON[event](...)
        counts.ms = counts.ms + debugprofilestop() - started
    end)

    local function Want(event, on, unit)
        on = on == true
        if wanted[event] == on then return end
        wanted[event] = on
        if not on then
            events:UnregisterEvent(event)
        elseif unit then
            events:RegisterUnitEvent(event, unit)
        else
            events:RegisterEvent(event)
        end
    end

    function Watch.Listen()
        local any = subscriberCount > 0
        local anyItem = false
        if any then
            for category in pairs(Watch.ITEM_CATEGORY) do anyItem = anyItem or mask[category] == true end
        end
        Want("SPELL_UPDATE_COOLDOWN", any or next(onceFn) ~= nil)
        Want("SPELLS_CHANGED", any)
        Want("PLAYER_ENTERING_WORLD", any)
        Want("SPELL_UPDATE_CHARGES", any and mask.charges == true)
        local petWatch = any and mask.pet == true
        local petOut = petWatch and UnitExists("pet") == true
        Want("UNIT_PET", petWatch, "player")
        Want("PET_BAR_UPDATE_COOLDOWN", petOut)
        Want("BAG_UPDATE_COOLDOWN", anyItem)
        Want("BAG_UPDATE_DELAYED", anyItem)
        Want("PLAYER_EQUIPMENT_CHANGED", anyItem)
        Want("PLAYER_REGEN_ENABLED", anyItem)
        if not any then
            for index = 1, #ARMED_KINDS do
                local kind = ARMED_KINDS[index]
                for id in pairs(armed[kind]) do Drop(kind, id) end
            end
        elseif not petOut then
            for id in pairs(armed.pet) do Drop("pet", id) end
        end
    end

    function Watch.Subscribe(owner, fn)
        if not subscribers[owner] then subscriberCount = subscriberCount + 1 end
        subscribers[owner] = fn
        if subscriberCount == 1 then
            ScanBook(true)
            ScanItems()
        end
        Watch.Listen()
    end

    function Watch.Unsubscribe(owner)
        if not subscribers[owner] then return end
        subscribers[owner] = nil
        subscriberCount = subscriberCount - 1
        Watch.Listen()
    end

    function Watch.SetMask(set)
        for _, category in pairs(Watch.CATEGORIES) do mask[category] = set[category] == true end
        for kind, category in pairs({ charge = "charges", pet = "pet" }) do
            if not mask[category] then
                for id in pairs(armed[kind]) do Drop(kind, id) end
            end
        end
        Watch.Listen()
    end

    function Watch.SetMinimum(seconds)
        minimum = tonumber(seconds) or minimum
    end

    function Watch.SetIgnore(text)
        wipe(ignoreIDs)
        wipe(ignoreNames)
        wipe(spellIgnored)
        for token in tostring(text or ""):gmatch("[^,\n]+") do
            token = token:match("^%s*(.-)%s*$")
            local id = tonumber(token) or tonumber(token:match("[Hh]item:(%d+)") or token:match("[Hh]spell:(%d+)"))
            if id then
                ignoreIDs[id] = true
            elseif token ~= "" then
                ignoreNames[string_lower(token:match("%[(.-)%]") or token)] = true
            end
        end
        wipe(items)
        wipe(noUse)
        if subscriberCount > 0 then ScanItems() end
    end

    function Watch.Once(spellID, fn)
        onceFn[spellID] = fn
        Watch.Listen()
        Once(spellID)
    end

    function Watch.Cancel(spellID)
        onceFn[spellID] = nil
        Drop("once", spellID)
        Watch.Listen()
    end

    function Watch.Describe(kind, id, wantName)
        if kind == "spell" or kind == "charge" then
            return C_Spell.GetSpellTexture(id), wantName and C_Spell.GetSpellName(id) or nil
        end
        if kind == "pet" then
            local name, texture = GetPetActionInfo(id)
            return texture, wantName and name or nil
        end
        local itemID = id
        if kind == "slot" then
            itemID = SA_COMPAT.InventoryItemID(id)
        elseif kind == "shared" then
            local cd = armed.shared[id]
            itemID = cd and cd.item
        end
        if not itemID then return nil end
        local _, icon = SA_COMPAT.ItemBasics(itemID)
        return icon, wantName and SA_COMPAT.ItemName(itemID) or nil
    end

    function Watch.Stats()
        local live = 0
        for _, list in pairs(armed) do
            for _ in pairs(list) do live = live + 1 end
        end
        return counts, live, made
    end
end
