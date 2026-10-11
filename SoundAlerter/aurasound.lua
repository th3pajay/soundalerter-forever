local SoundAlerter = SoundAlerter

local registered = {}
local TEST_UNITS = { "player", "target", "focus", "nameplate1", "arena1", "party1", "mouseover" }
local TEST_SPELL = 2825

function SoundAlerter:EngineAuraSoundSupported()
    return C_UnitAuras and C_UnitAuras.AddAuraSound and C_UnitAuras.RemoveAuraSound
        and Enum and Enum.UnitAuraSoundTrigger and true or false
end

function SoundAlerter:HasEngineAuraSound(spellID)
    return registered[spellID] ~= nil
end

local function SavedIDs(self)
    local global = self.db1.global
    global.auraSoundIDs = global.auraSoundIDs or {}
    return global.auraSoundIDs
end

function SoundAlerter:ClearStaleAuraSounds()
    local ids = SavedIDs(self)
    if C_UnitAuras and C_UnitAuras.RemoveAuraSound then
        for _, id in pairs(ids) do
            pcall(C_UnitAuras.RemoveAuraSound, id)
        end
    end
    wipe(ids)
end

function SoundAlerter:RemoveAllAuraSounds()
    if not self:EngineAuraSoundSupported() then return end
    local ids = SavedIDs(self)
    for spellID, entry in pairs(registered) do
        pcall(C_UnitAuras.RemoveAuraSound, entry.id)
        registered[spellID] = nil
        ids[spellID] = nil
    end
end

function SoundAlerter:SyncAuraSounds()
    local profile = self.db1.profile
    if not self:EngineAuraSoundSupported() then return end
    local ids = SavedIDs(self)
    local desired = SA_AuraSound.Desired(self.spellList.selfDebuff, profile)
    local add, remove = SA_AuraSound.Diff(registered, desired)
    for _, spellID in ipairs(remove) do
        pcall(C_UnitAuras.RemoveAuraSound, registered[spellID].id)
        registered[spellID] = nil
        ids[spellID] = nil
    end
    for _, spellID in ipairs(add) do
        local file = desired[spellID]
        local ok, id = pcall(C_UnitAuras.AddAuraSound, Enum.UnitAuraSoundTrigger.Added, {
            unitToken = "player",
            spellID = spellID,
            soundFileName = file,
            throttleSeconds = 1,
        })
        if ok and type(id) == "number" then
            registered[spellID] = { id = id, file = file }
            ids[spellID] = id
        else
            self:Debug("AuraSound", "spell %d not registered: %s", spellID, tostring(id))
        end
    end
    if #add > 0 or #remove > 0 then
        self:Debug("AuraSound", "synced: %d added, %d removed", #add, #remove)
    end
end

function SoundAlerter:RunAuraSoundSync()
    self.auraSoundSyncTimer = nil
    self:SyncAuraSounds()
end

function SoundAlerter:OnConfigTableChange(event, appName)
    if appName ~= "SoundAlerter" or self.auraSoundSyncTimer then return end
    self.auraSoundSyncTimer = self:ScheduleTimer("RunAuraSoundSync", 0.5)
end

function SoundAlerter:StartAuraSounds()
    self:ClearStaleAuraSounds()
    LibStub("AceConfigRegistry-3.0").RegisterCallback(self, "ConfigTableChange", "OnConfigTableChange")
    self:SyncAuraSounds()
end

function SoundAlerter:AuraSoundSelfTest()
    if not self:EngineAuraSoundSupported() then
        self:Print("C_UnitAuras.AddAuraSound is not available on this client.")
        return
    end
    local file = self.db1.profile.sapath .. "detected.mp3"
    self:Print("|cffFFD700=== Engine aura sound test (registers and removes at once) ===|r")
    for _, unit in ipairs(TEST_UNITS) do
        local ok, id = pcall(C_UnitAuras.AddAuraSound, Enum.UnitAuraSoundTrigger.Added, {
            unitToken = unit,
            spellID = TEST_SPELL,
            soundFileName = file,
            throttleSeconds = 1,
        })
        if ok and type(id) == "number" then
            self:Print("  " .. unit .. ": accepted, id " .. id)
            pcall(C_UnitAuras.RemoveAuraSound, id)
        else
            self:Print("  " .. unit .. ": " .. (ok and "no id returned" or ("error: " .. tostring(id))))
        end
    end
end
