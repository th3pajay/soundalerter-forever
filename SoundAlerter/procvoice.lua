local SoundAlerter = SoundAlerter
local Plain = SA_COMPAT.Plain

SA_ProcVoice = {}
local Proc = SA_ProcVoice

Proc.GAP = 3
Proc.MAX_SEEN = 40
Proc.seen = {}
Proc.BUFFS = {
    ["Clearcasting"] = "clearcasting.mp3",
    ["Omen of Clarity"] = "clearcasting.mp3",
    ["Arcane Concentration"] = "clearcasting.mp3",
    ["Elemental Focus"] = "clearcasting.mp3",
    ["Nature's Grace"] = "naturesgrace.mp3",
    ["Shadow Trance"] = "shadowtrance.mp3",
    ["Nightfall"] = "shadowtrance.mp3",
}

local seenCount = 0
local bySpell = {}

function Proc.FileOf(name)
    if type(name) ~= "string" then return nil end
    local file = name:lower():gsub("[^%a%d]", "")
    if file == "" then return nil end
    return file .. ".mp3"
end

local function note(spellID, name, file, always)
    local entry = Proc.seen[name]
    if entry then return entry end
    if seenCount >= Proc.MAX_SEEN and not always then return nil end
    entry = { spellID = spellID, file = file, at = -Proc.GAP }
    Proc.seen[name] = entry
    seenCount = seenCount + 1
    return entry
end

local function play(entry)
    local db = SoundAlerter.db1
    if not db then return end
    local profile = db.profile
    if not profile.procVoices or not SoundAlerter.Emitter:Open("proc") then return end
    local now = GetTime()
    if now - entry.at < Proc.GAP then return end
    entry.at = now
    local path = profile.sapath .. entry.file
    if entry.missing == path then return end
    local context = SoundAlerter.Emitter:Context("proc")
    context.sound = entry.file
    local _, played = SoundAlerter.Emitter:Emit(context)
    entry.voiced = played and true or false
    entry.missing = not entry.voiced and path or nil
end

local function onGlow(spellID)
    spellID = Plain(spellID)
    if type(spellID) ~= "number" then return end
    local entry = bySpell[spellID]
    if not entry then
        local name = Plain((SA_COMPAT.GetSpellInfo(spellID)))
        local file = Proc.FileOf(name)
        if not file then return end
        entry = note(spellID, name, file)
        if not entry then return end
        bySpell[spellID] = entry
    end
    play(entry)
end

local byBuff = {}

local function onBuff(name)
    local file = Proc.BUFFS[name]
    if not file then return end
    local entry = byBuff[file]
    if entry == nil then
        entry = note(0, name, file, true) or false
        byBuff[file] = entry
    end
    if entry then play(entry) end
end

function Proc.OnAura(info)
    if type(info) ~= "table" then return end
    local added = info.addedAuras
    if issecretvalue(added) or type(added) ~= "table" then return end
    for index = 1, #added do
        local aura = added[index]
        local spellID = type(aura) == "table" and not issecretvalue(aura) and Plain(aura.spellId) or nil
        if type(spellID) == "number" then
            local name = Plain((SA_COMPAT.GetSpellInfo(spellID)))
            if name and Proc.BUFFS[name] then onBuff(name) end
        end
    end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, a, b)
    if event == "UNIT_AURA" then
        Proc.OnAura(b)
    elseif event == "PLAYER_LOGIN" then
        frame:UnregisterEvent("PLAYER_LOGIN")
        Proc.Refresh()
    else
        onGlow(a)
    end
end)
frame:RegisterEvent("PLAYER_LOGIN")

local listening = false
local wantedBuffs = {}
for name in pairs(Proc.BUFFS) do wantedBuffs[name] = true end

function Proc.Refresh()
    local db = SoundAlerter.db1
    local want = db and db.profile.procVoices and true or false
    if want == listening then return end
    listening = want
    local View = SA_CooldownView
    if want then
        pcall(frame.RegisterEvent, frame, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        frame:RegisterUnitEvent("UNIT_AURA", "player")
        if View then
            View.Listen("procs", function(name, on) if on then onBuff(name) end end)
            View.Want("procs", wantedBuffs)
        end
    else
        pcall(frame.UnregisterEvent, frame, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        frame:UnregisterEvent("UNIT_AURA")
        if View then View.Want("procs", nil) end
    end
end

function SoundAlerter:ProcList()
    if next(Proc.seen) == nil then
        self:Print("No procs seen since you logged in. Play for a while and run /sa procs again.")
        return
    end
    local names = {}
    for name in pairs(Proc.seen) do names[#names + 1] = name end
    table.sort(names)
    self:Print("Procs seen since you logged in:")
    for _, name in ipairs(names) do
        local entry = Proc.seen[name]
        local state = entry.file .. " plays"
        if entry.voiced == nil then
            state = "not played yet, turn on Say my procs (" .. entry.file .. ")"
        elseif not entry.voiced then
            state = "no voice, add " .. entry.file .. " to your voice folder"
        end
        self:Print("  " .. name .. ": " .. state)
    end
end
