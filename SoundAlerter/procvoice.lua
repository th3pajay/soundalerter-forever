local SoundAlerter = SoundAlerter
local Plain = SA_COMPAT.Plain

SA_ProcVoice = {}
local Proc = SA_ProcVoice

Proc.GAP = 3
Proc.MAX_SEEN = 40
Proc.seen = {}

local seenCount = 0
local bySpell = {}

function Proc.FileOf(name)
    if type(name) ~= "string" then return nil end
    local file = name:lower():gsub("[^%a%d]", "")
    if file == "" then return nil end
    return file .. ".mp3"
end

local function note(spellID, name, file)
    local entry = Proc.seen[name]
    if entry then return entry end
    if seenCount >= Proc.MAX_SEEN then return nil end
    entry = { spellID = spellID, file = file, at = -Proc.GAP }
    Proc.seen[name] = entry
    seenCount = seenCount + 1
    return entry
end

local function onGlow(spellID)
    spellID = Plain(spellID)
    local db = SoundAlerter.db1
    if type(spellID) ~= "number" or not db then return end
    local entry = bySpell[spellID]
    if not entry then
        local name = Plain((SA_COMPAT.GetSpellInfo(spellID)))
        local file = Proc.FileOf(name)
        if not file then return end
        entry = note(spellID, name, file)
        if not entry then return end
        bySpell[spellID] = entry
    end
    local profile = db.profile
    if not profile.procVoices or not SoundAlerter:IsAlertZoneAllowed() then return end
    local now = GetTime()
    if now - entry.at < Proc.GAP then return end
    entry.at = now
    local path = profile.sapath .. entry.file
    if entry.missing == path then return end
    local ok, willPlay = pcall(PlaySoundFile, path)
    entry.voiced = ok and willPlay and true or false
    entry.missing = not entry.voiced and path or nil
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, _, spellID) onGlow(spellID) end)
pcall(frame.RegisterEvent, frame, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")

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
