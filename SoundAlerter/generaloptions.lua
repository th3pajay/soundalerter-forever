local SoundAlerter = SoundAlerter

local VOLUME_CVARS = { "Sound_MasterVolume", "Sound_AmbienceVolume", "Sound_SFXVolume", "Sound_MusicVolume" }

local function profile()
    return SoundAlerter.db1 and SoundAlerter.db1.profile
end

local function tracking()
    return SoundAlerter.MinimapTracking
end

local function view()
    local current = profile()
    if not current then return nil end
    local active = tracking()
    local volume = GetCVar and tonumber(GetCVar("Sound_MasterVolume")) or nil
    return { enabled = current.all, p = current, m = active and active:GetSettings(), sound = { master = volume } }
end

local function write(key, value)
    local current = profile()
    if not current then return end
    if key == "enabled" then
        current.all = value
        return
    end
    local scope, name = key:match("^(%a+)%.(.+)$")
    if scope == "p" then
        current[name] = value
    elseif scope == "m" then
        local active = tracking()
        if active then active:SetSetting(name, value) end
    elseif scope == "sound" and name == "master" then
        SetCVar("Sound_MasterVolume", tostring(value))
    end
end

local function addonSoundsOnly()
    SetCVar("Sound_AmbienceVolume", "0")
    SetCVar("Sound_SFXVolume", "0")
    SetCVar("Sound_MusicVolume", "0")
    SoundAlerter:Print("Addons will only be heard by your client. To undo this, use Reset volume options.")
end

local function resetVolume()
    for _, name in ipairs(VOLUME_CVARS) do SetCVar(name, "1") end
    SoundAlerter:Print("Sound options reset.")
end

local function exportAlerts()
    local current = profile()
    if current then current.exportbox = SA_CustomExport.Encode(current.custom) end
end

local function importAlerts()
    local current = profile()
    if not current then return end
    local parsed, message = SA_CustomExport.Decode(current.exportbox)
    if not parsed then
        SoundAlerter:Print(message)
        return
    end
    current.custom = parsed
    SoundAlerter:OnOptionsCreate()
end

local function summary(settings)
    local Page = SoundAlerter.Page
    local volume = settings.sound.master
    local text = Page.Summary(settings,
        volume and ("volume " .. math.floor(volume * 100 + 0.5) .. "%") or nil,
        settings.m and ("minimap tracking " .. (settings.m.enabled and "on" or "off")) or nil)
    if SoundAlerter.BlizzardAudioAlertsEnabled and SoundAlerter:BlizzardAudioAlertsEnabled() then
        text = text .. "\n|cffFF6600The game's own combat audio alerts are on, so spoken alerts may play twice.|r"
    end
    return text
end

function SoundAlerter:BuildGeneralOptions()
    local Page = SoundAlerter.Page
    local import = Page.Action("Import custom sound alerts", "Replace your custom sound alerts with the export text below. This removes your current ones.", importAlerts, true, "Import and export")
    import.confirm = "Click again to confirm"
    local spec = Page.Spec({
        title = "General",
        icon = "Interface\\Icons\\INV_Misc_Gear_01",
        blurb = "Turn the addon on, set the volume and the minimap tracking. Zones are set on the Quick Start page.",
        get = view,
        set = write,
        defaults = function()
            return { p = dbDefaults.profile, m = dbDefaults.profile.minimapTracking }
        end,
        summary = summary,
        rows = {
            Page.Range("sound.master", "Master volume", "Sets the game's master volume so sound alerts can be louder or softer.", 0, 1, 0.1, false, "Volume"),
            Page.Action("Addon sounds only", "Sets the other game sounds to minimum so you only hear the addon.", addonSoundsOnly, false, "Volume"),
            Page.Action("Reset volume options", "Resets the game's sound volumes to full.", resetVolume, false, "Volume"),
            Page.Toggle("m.enabled", "Track target and focus on the minimap", "Keeps target and focus on the minimap after every loading screen.", false, "Minimap tracking"),
            Page.When("m.enabled", Page.Toggle("m.target", "Track target", "", true, "Minimap tracking")),
            Page.When("m.enabled", Page.Toggle("m.focus", "Track focus", "", true, "Minimap tracking")),
            Page.Toggle("p.flatWindow", "Dark flat options window", "Restyle the options window in the same dark flat look as the pages. Turning it off fully applies after /reload.", true, "Window"),
            Page.When("p.debugmode", Page.Toggle("p.spelldebug", "Spell ID output debugging", "Print the spell ID of every spell the addon sees. Needs Debug Mode, set in Developer tools.", true, "Debug")),
            Page.When("p.debugmode", import),
            Page.When("p.debugmode", Page.Action("Export custom sound alerts", "Write your custom sound alerts into the export text below.", exportAlerts, true, "Import and export")),
            Page.When("p.debugmode", Page.Text("p.exportbox", "Export text", "Copy this to share your custom sound alerts, or paste an export here before importing.", true, "Import and export", 4)),
        },
    })
    return Page.Options(spec, "General", "Interface\\Icons\\INV_Misc_Gear_01", "General Options", 1)
end
