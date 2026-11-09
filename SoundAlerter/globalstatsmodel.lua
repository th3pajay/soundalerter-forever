SA_GlobalStatsModel = {}

local Model = SA_GlobalStatsModel

local string_byte, string_sub, string_format = string.byte, string.sub, string.format
local math_floor, math_max = math.floor, math.max
local tonumber = tonumber

Model.PREFIX = "SoundAlerterS"
Model.VERSION = "1"
Model.WINDOW_DAYS = 7
Model.DECOYS = 2
Model.MIN_PLAYERS = 2
Model.SIGMAS = 3
Model.DECOY_PERIOD = 7
Model.MAX_ENTRIES = 40
Model.MAX_TOKEN = 7
Model.MAX_SENDERS = 1000
Model.MAX_PER_SENDER = 160
Model.ZONE_BITS = { arena = 1, battleground = 2, worldPvP = 4 }
Model.ZONE_KEYS = { [1] = "arena", [2] = "battleground", [4] = "worldPvP" }

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local BITS = { 1, 2, 4 }

local function hasBit(mask, bit)
    return mask % (bit * 2) >= bit
end

local function base36(value)
    if value == 0 then return "0" end
    local out = ""
    while value > 0 do
        local digit = value % 36
        out = string_sub(DIGITS, digit + 1, digit + 1) .. out
        value = math_floor(value / 36)
    end
    return out
end

function Model.Token(spellID, mask)
    return base36(spellID * 8 + mask)
end

local function untoken(token)
    if #token == 0 or #token > Model.MAX_TOKEN then return nil end
    for index = 1, #token do
        local byte = string_byte(token, index)
        if not ((byte >= 48 and byte <= 57) or (byte >= 97 and byte <= 122)) then return nil end
    end
    local value = tonumber(token, 36)
    if not value then return nil end
    local mask = value % 8
    if mask == 0 then return nil end
    return (value - mask) / 8, mask
end

function Model.Encode(day, spells)
    local tokens = {}
    for index = 1, math.min(#spells, Model.MAX_ENTRIES) do
        local item = spells[index]
        tokens[index] = Model.Token(item.id, item.mask)
    end
    if #tokens == 0 then return nil end
    return Model.VERSION .. "|" .. day .. "|" .. table.concat(tokens, ",")
end

function Model.Decode(text, today, isKnown, ids, masks)
    if type(text) ~= "string" or #text > 255 then return nil end
    local version, dayText, body = text:match("^(%d+)|(%d+)|([%w,]+)$")
    if version ~= Model.VERSION then return nil end
    local day = tonumber(dayText)
    if not day or day > today or day < today - 1 then return nil end
    local count, invalid = 0, 0
    for token in body:gmatch("[^,]+") do
        if count + invalid >= Model.MAX_ENTRIES then return nil end
        local id, mask = untoken(token)
        if id and isKnown(id) then
            count = count + 1
            ids[count], masks[count] = id, mask
        else
            invalid = invalid + 1
        end
    end
    for index = count + 1, #ids do ids[index], masks[index] = nil, nil end
    if count == 0 or invalid > count then return nil end
    return day, count
end

function Model.Period(day)
    return math_floor(day / Model.DECOY_PERIOD)
end

function Model.Decoys(digest, universe, count, out)
    for index = #out, 1, -1 do out[index] = nil end
    local size = #universe
    if size == 0 or type(digest) ~= "string" then return out end
    for index = 1, count do
        local chunk = tonumber(string_sub(digest, (index - 1) * 8 + 1, index * 8), 16)
        if not chunk then break end
        local id = universe[chunk % size + 1]
        local bit = BITS[math_floor(chunk / size) % 3 + 1]
        out[#out + 1] = { id = id, mask = bit }
    end
    return out
end

function Model.Report(mine, decoys)
    local byId, order = {}, {}
    local function add(id, bit)
        local mask = byId[id]
        if not mask then
            mask = 0
            order[#order + 1] = id
        end
        if not hasBit(mask, bit) then mask = mask + bit end
        byId[id] = mask
    end
    for pair in pairs(mine) do
        local bit = pair % 8
        add((pair - bit) / 8, bit)
    end
    for _, decoy in ipairs(decoys) do add(decoy.id, decoy.mask) end
    table.sort(order)
    local spells = {}
    for index, id in ipairs(order) do spells[index] = { id = id, mask = byId[id] } end
    return spells
end

function Model.NewStore()
    return { senders = {}, count = 0, version = 0 }
end

local function evictOldest(store)
    local oldestKey, oldestDay = nil, math.huge
    for key, sender in pairs(store.senders) do
        if sender.last < oldestDay then oldestKey, oldestDay = key, sender.last end
    end
    if oldestKey then
        store.senders[oldestKey] = nil
        store.count = store.count - 1
    end
end

function Model.Merge(store, key, day, ids, masks, count)
    local sender = store.senders[key]
    if not sender then
        if store.count >= Model.MAX_SENDERS then evictOldest(store) end
        sender = { last = day, days = {}, e = {}, n = 0 }
        store.senders[key] = sender
        store.count = store.count + 1
    end
    sender.last = math_max(sender.last, day)
    sender.days[day] = true
    local changed = false
    for index = 1, count do
        local id, mask = ids[index], masks[index]
        for _, bit in ipairs(BITS) do
            if hasBit(mask, bit) then
                local pair = id * 8 + bit
                local seen = sender.e[pair]
                if seen == nil then
                    if sender.n < Model.MAX_PER_SENDER then
                        sender.e[pair] = day
                        sender.n = sender.n + 1
                        changed = true
                    end
                elseif seen < day then
                    sender.e[pair] = day
                    changed = true
                end
            end
        end
    end
    if changed then store.version = store.version + 1 end
    return changed
end

function Model.Prune(store, today)
    local first = today - Model.WINDOW_DAYS + 1
    local removed = 0
    for key, sender in pairs(store.senders) do
        for day in pairs(sender.days) do
            if day < first then sender.days[day] = nil end
        end
        for pair, day in pairs(sender.e) do
            if day < first then
                sender.e[pair] = nil
                sender.n = sender.n - 1
                removed = removed + 1
            end
        end
        if sender.last < first or not next(sender.days) then
            store.senders[key] = nil
            store.count = store.count - 1
        end
    end
    if removed > 0 then store.version = store.version + 1 end
    return removed
end

local function estimate(observed, expectedDecoys, players)
    if players <= 0 then return 0 end
    local share = expectedDecoys / players
    if share >= 1 then return 0 end
    local value = math_max(0, (observed - expectedDecoys) / (1 - share))
    if value < Model.SIGMAS * math.sqrt(expectedDecoys) then return 0 end
    return value
end

function Model.Aggregate(store, today, universeSize)
    local first = today - Model.WINDOW_DAYS + 1
    local zoneSeen, anySeen = {}, {}
    local players, dayWeight = 0, 0
    for _, sender in pairs(store.senders) do
        if sender.last >= first then
            players = players + 1
            local periods, low, high = 0, nil, nil
            for day in pairs(sender.days) do
                if day >= first then
                    local period = Model.Period(day)
                    if period ~= low and period ~= high then
                        periods = periods + 1
                        if not low then low = period else high = period end
                    end
                end
            end
            dayWeight = dayWeight + periods
            local touched = {}
            for pair, day in pairs(sender.e) do
                if day >= first then
                    zoneSeen[pair] = (zoneSeen[pair] or 0) + 1
                    local bit = pair % 8
                    local id = (pair - bit) / 8
                    if not touched[id] then
                        touched[id] = true
                        anySeen[id] = (anySeen[id] or 0) + 1
                    end
                end
            end
        end
    end
    local spells = {}
    if players == 0 or universeSize <= 0 then return spells, players end
    local perPair = dayWeight * Model.DECOYS / (3 * universeSize)
    local perSpell = dayWeight * Model.DECOYS / universeSize
    for id, observed in pairs(anySeen) do
        local byZone, top = {}, 0
        for bit, zone in pairs(Model.ZONE_KEYS) do
            local seen = zoneSeen[id * 8 + bit]
            if seen then
                local value = math_floor(estimate(seen, perPair, players) + 0.5)
                if value >= Model.MIN_PLAYERS then
                    byZone[zone] = value
                    if value > top then top = value end
                end
            end
        end
        local overall = top > 0 and math_floor(estimate(observed, perSpell, players) + 0.5) or 0
        if overall >= Model.MIN_PLAYERS then
            spells[#spells + 1] = { id = id, total = math_max(top, overall), byZone = byZone }
        end
    end
    table.sort(spells, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.id < b.id
    end)
    return spells, players
end

Model.EXPORT_PREFIX = "SAG1."
Model.EXPORT_VERSION = 1
Model.FACTION_CODE = { Horde = 1, Alliance = 2 }
Model.FACTION_NAME = { [1] = "Horde", [2] = "Alliance" }

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local B64_INDEX = {}
for index = 1, 64 do B64_INDEX[string_byte(B64, index)] = index - 1 end

local function putVarint(out, value)
    value = math_floor(value)
    while value >= 128 do
        out[#out + 1] = value % 128 + 128
        value = math_floor(value / 128)
    end
    out[#out + 1] = value
end

local function fletcher(bytes, count)
    local a, b = 0, 0
    for index = 1, count do
        a = (a + bytes[index]) % 255
        b = (b + a) % 255
    end
    return b * 256 + a
end

local function toBase64(bytes)
    local parts = {}
    for index = 1, #bytes, 3 do
        local b1, b2, b3 = bytes[index], bytes[index + 1], bytes[index + 2]
        local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
        local c1, c2 = math_floor(n / 262144) % 64, math_floor(n / 4096) % 64
        local c3, c4 = math_floor(n / 64) % 64, n % 64
        local chunk = string_sub(B64, c1 + 1, c1 + 1) .. string_sub(B64, c2 + 1, c2 + 1)
        if b2 then chunk = chunk .. string_sub(B64, c3 + 1, c3 + 1) end
        if b3 then chunk = chunk .. string_sub(B64, c4 + 1, c4 + 1) end
        parts[#parts + 1] = chunk
    end
    return table.concat(parts)
end

local function fromBase64(text)
    local bytes = {}
    local length = #text
    if length % 4 == 1 then return nil end
    for index = 1, length, 4 do
        local n, count = 0, 0
        for offset = 0, 3 do
            local byte = string_byte(text, index + offset)
            if byte then
                local value = B64_INDEX[byte]
                if not value then return nil end
                n = n * 64 + value
                count = count + 1
            else
                n = n * 64
            end
        end
        bytes[#bytes + 1] = math_floor(n / 65536) % 256
        if count >= 3 then bytes[#bytes + 1] = math_floor(n / 256) % 256 end
        if count >= 4 then bytes[#bytes + 1] = n % 256 end
    end
    return bytes
end

function Model.Export(info, entries)
    local out = { Model.EXPORT_VERSION }
    putVarint(out, info.day or 0)
    putVarint(out, info.players or 0)
    local realm = string_sub(tostring(info.realm or ""), 1, 64)
    out[#out + 1] = #realm
    for index = 1, #realm do out[#out + 1] = string_byte(realm, index) end
    out[#out + 1] = Model.FACTION_CODE[info.faction] or 0
    local sorted = {}
    for _, entry in ipairs(entries) do
        if type(entry.id) == "number" and entry.id > 0 then sorted[#sorted + 1] = entry end
    end
    table.sort(sorted, function(a, b) return a.id < b.id end)
    putVarint(out, #sorted)
    local last = 0
    for _, entry in ipairs(sorted) do
        putVarint(out, entry.id - last)
        last = entry.id
        putVarint(out, math_max(0, entry.total or 0))
        local byZone = entry.byZone or {}
        local mask = 0
        for _, bit in ipairs(BITS) do
            local value = byZone[Model.ZONE_KEYS[bit]]
            if value and value > 0 then mask = mask + bit end
        end
        out[#out + 1] = mask
        for _, bit in ipairs(BITS) do
            local value = byZone[Model.ZONE_KEYS[bit]]
            if value and value > 0 then putVarint(out, value) end
        end
    end
    local sum = fletcher(out, #out)
    out[#out + 1] = math_floor(sum / 256)
    out[#out + 1] = sum % 256
    return Model.EXPORT_PREFIX .. toBase64(out)
end

function Model.Import(text)
    if type(text) ~= "string" or string_sub(text, 1, #Model.EXPORT_PREFIX) ~= Model.EXPORT_PREFIX then return nil end
    local bytes = fromBase64(string_sub(text, #Model.EXPORT_PREFIX + 1))
    if not bytes or #bytes < 8 then return nil end
    local count = #bytes - 2
    if fletcher(bytes, count) ~= bytes[count + 1] * 256 + bytes[count + 2] then return nil end
    local position = 1
    local function byte()
        if position > count then error("truncated") end
        position = position + 1
        return bytes[position - 1]
    end
    local function varint()
        local value, scale = 0, 1
        for _ = 1, 8 do
            local b = byte()
            value = value + (b % 128) * scale
            if b < 128 then return value end
            scale = scale * 128
        end
        error("varint")
    end
    local ok, result = pcall(function()
        if byte() ~= Model.EXPORT_VERSION then error("version") end
        local info = { day = varint(), players = varint() }
        local chars = {}
        for index = 1, byte() do chars[index] = string.char(byte()) end
        info.realm = table.concat(chars)
        info.faction = Model.FACTION_NAME[byte()]
        local spells, id = {}, 0
        for index = 1, varint() do
            id = id + varint()
            local total = varint()
            local mask, byZone = byte(), {}
            for _, bit in ipairs(BITS) do
                if hasBit(mask, bit) then byZone[Model.ZONE_KEYS[bit]] = varint() end
            end
            spells[index] = { id = id, total = total, byZone = byZone }
        end
        if position ~= count + 1 then error("trailing") end
        info.spells = spells
        return info
    end)
    if ok then return result end
    return nil
end

Model.SORTS = { "total", "arena", "battleground", "worldPvP" }

local sortValue = setmetatable({}, { __mode = "k" })

local function byValue(a, b)
    local av, bv = sortValue[a], sortValue[b]
    if av ~= bv then return av > bv end
    if a.total ~= b.total then return a.total > b.total end
    return a.id < b.id
end

function Model.Rows(entries, sortKey, off, out)
    for index = #out, 1, -1 do out[index] = nil end
    local peak, byTotal = 0, sortKey == "total"
    for _, entry in ipairs(entries) do
        if not off[entry.group] then
            local zones = entry.byZone
            local value = byTotal and entry.total or (zones[sortKey] or 0)
            if value > 0 then
                out[#out + 1] = entry
                sortValue[entry] = value
                local sum = (zones.arena or 0) + (zones.battleground or 0) + (zones.worldPvP or 0)
                if sum > peak then peak = sum end
            end
        end
    end
    table.sort(out, byValue)
    return out, peak
end

function Model.ClampOffset(offset, count, visible)
    local most = math_max(0, count - visible)
    if offset < 0 then return 0 end
    if offset > most then return most end
    return math_floor(offset)
end

function Model.SenderKey(hash, sender)
    if type(sender) ~= "string" or sender == "" then return nil end
    return string_sub(hash("SAS1" .. sender), 1, 12)
end

function Model.SecretValid(secret)
    return type(secret) == "string" and #secret == 32 and secret:match("^%x+$") ~= nil
end

function Model.NewSecret(random)
    local parts = {}
    for index = 1, 8 do parts[index] = string_format("%04x", random(0, 65535)) end
    return table.concat(parts)
end
