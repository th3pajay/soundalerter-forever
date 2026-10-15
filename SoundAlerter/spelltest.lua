local SoundAlerter = SoundAlerter
local SpellTest = {}

local Model = SoundAlerter.SpellTestModel
local Plain = SA_COMPAT.Plain

local MAX_SECONDS = 1800
local EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_AURA",
}
local FIXED_KINDS = { player = true, target = true, focus = true, pet = true }
local PREFIX_KINDS = { { "^nameplate", "nameplate" }, { "^party", "party" }, { "^arena", "arena" }, { "^raid", "raid" } }

local function UnitKind(unit)
    if type(unit) ~= "string" or issecretvalue(unit) then return "other" end
    if FIXED_KINDS[unit] then return unit end
    for index = 1, #PREFIX_KINDS do
        if unit:find(PREFIX_KINDS[index][1]) then return PREFIX_KINDS[index][2] end
    end
    return "other"
end

local function SecretsActive()
    if not (C_Secrets and C_Secrets.ShouldAurasBeSecret) then return false end
    local ok, value = pcall(C_Secrets.ShouldAurasBeSecret)
    return ok and Plain(value) == true
end

local function Zone()
    local ok, inInstance, kind = pcall(IsInInstance)
    if not ok then return "unknown" end
    inInstance, kind = Plain(inInstance), Plain(kind)
    if inInstance and type(kind) == "string" then return kind end
    return "world"
end

local function Describe(sample, unit)
    if type(unit) ~= "string" or issecretvalue(unit) then return end
    local _, class = UnitClass(unit)
    sample.classReadable = type(Plain(class)) == "string"
    sample.isEnemy = Plain(UnitIsEnemy("player", unit)) == true
    sample.isPlayer = Plain(UnitIsPlayer(unit)) == true
end

local function ReadAura(sample, info)
    sample.payloadReadable = type(info) == "table" and not issecretvalue(info)
    if not sample.payloadReadable then return end
    local added = info.addedAuras
    if type(added) ~= "table" or issecretvalue(added) then return end
    local first = added[1]
    if type(first) ~= "table" or issecretvalue(first) then return end
    local id = first.spellId
    if type(id) == "number" and not issecretvalue(id) then
        sample.spellReadable, sample.spellID = true, id
    end
end

local function ReadCast(sample, ...)
    local _, spellID, extra = ...
    if type(spellID) == "number" and not issecretvalue(spellID) then
        sample.spellReadable, sample.spellID = true, spellID
    end
    sample.extraSeen = select("#", ...) >= 3
    sample.extraReadable = extra ~= nil and not issecretvalue(extra)
end

local function SpellName(id)
    local name = SA_COMPAT.GetSpellInfo(id)
    return Plain(name)
end

function SpellTest:OnEvent(event, unit, ...)
    local run = self.run
    if not run or run.stoppedAt then return end
    local sample = { event = event, unitKind = UnitKind(unit), zone = Zone(), secretsActive = SecretsActive() }
    Describe(sample, unit)
    if event == "UNIT_AURA" then
        ReadAura(sample, (...))
    else
        ReadCast(sample, ...)
    end
    if sample.spellID then sample.spellName = SpellName(sample.spellID) end
    Model.Record(run, sample)
end

function SpellTest:Now()
    return GetServerTime()
end

function SpellTest:Stop(message)
    if not self.run then return end
    Model.Stop(self.run, self:Now())
    self.frame:UnregisterAllEvents()
    self.frame:SetScript("OnUpdate", nil)
    if message then self.addon:Print("|cffFF7D0ASpell test|r: " .. message) end
end

function SpellTest:Start()
    if self.run and not self.run.stoppedAt then
        self.addon:Print("|cffFF7D0ASpell test|r: already running. Use /sa spelltest report or off.")
        return
    end
    local _, _, _, build = GetBuildInfo()
    self.run = Model.NewRun(self:Now(), build)
    self.addon.db1.global.spelltest = self.run
    local registered = 0
    for _, event in ipairs(EVENTS) do
        if pcall(self.frame.RegisterEvent, self.frame, event) then registered = registered + 1 end
    end
    self.elapsed = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 5 then return end
        self.elapsed = 0
        if self:Now() - self.run.startedAt >= MAX_SECONDS then self:Stop("stopped after 30 minutes. Use /sa spelltest report.") end
    end)
    self.addon:Print("|cffFF7D0ASpell test|r: recording " .. registered .. " event types for up to 30 minutes. Target or focus enemy players and let them cast. Use /sa spelltest report any time.")
end

function SpellTest:Report()
    local run = self.run or self.addon.db1.global.spelltest
    if not run then
        self.addon:Print("|cffFF7D0ASpell test|r: no data yet. Use /sa spelltest on.")
        return
    end
    for _, line in ipairs(Model.Report(run, self:Now())) do
        self.addon:Print(line)
    end
end

function SpellTest:Clear()
    self:Stop()
    self.run = nil
    self.addon.db1.global.spelltest = nil
    self.addon:Print("|cffFF7D0ASpell test|r: data cleared.")
end

function SpellTest:PrintHelp()
    self.addon:Print("  |cffFFFFFF/sa spelltest on|off|report|clear|r - Record what the client hands the addon for spell casts and auras (no player names are saved)")
end

function SpellTest:HandleCommand(input)
    local command = (input or ""):match("^(%S*)"):lower()
    if command == "on" then
        self:Start()
    elseif command == "off" then
        self:Stop("stopped.")
    elseif command == "report" then
        self:Report()
    elseif command == "clear" then
        self:Clear()
    else
        self:PrintHelp()
    end
end

function SpellTest:Initialize()
    if self.frame then return end
    self.addon = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
    self.frame = CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, unit, ...) SpellTest:OnEvent(event, unit, ...) end)
end

SoundAlerter.SpellTest = SpellTest
