
local MinimapTracking = {}

local FILTER_KEYS = { "target", "focus" }
local ENUM_NAMES = { target = "Target", focus = "Focus" }
local SETTING_KEYS = { enabled = true, target = true, focus = true }
local REAPPLY_DELAY = 3

local pcall = pcall
local ipairs = ipairs

local function ShowAll()
	return C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("minimapTrackingShowAll") or false
end

local function FindIndex(key)
	local filters = Enum and Enum.MinimapTrackingFilter
	local filterID = filters and filters[ENUM_NAMES[key]]
	if not filterID or not C_Minimap or not C_Minimap.GetNumTrackingTypes then return nil end

	for index = 1, C_Minimap.GetNumTrackingTypes() do
		local filter = C_Minimap.GetTrackingFilter(index)
		if filter and filter.filterID == filterID then
			return index
		end
	end
	return nil
end

local function IsActive(key)
	local index = FindIndex(key)
	local info = index and C_Minimap.GetTrackingInfo(index)
	return info ~= nil and info.active == true
end

local function SetActive(key, active)
	local index = FindIndex(key)
	if index and IsActive(key) ~= active then
		C_Minimap.SetTracking(index, active)
	end
end

function MinimapTracking:GetSettings()
	return self.db
end

function MinimapTracking:SetSetting(key, value)
	if not SETTING_KEYS[key] then
		error("MinimapTracking:SetSetting - unknown setting key '"..tostring(key).."'", 2)
	end
	self.db[key] = value
	self:Apply()
end

function MinimapTracking:Apply()
	local db = self.db
	if not db or not db.enabled or ShowAll() then return end

	for _, key in ipairs(FILTER_KEYS) do
		pcall(SetActive, key, db[key] == true)
	end
end

function MinimapTracking:OnEnterWorld()
	self:Apply()
	C_Timer.After(REAPPLY_DELAY, function()
		MinimapTracking:Apply()
	end)
end

function MinimapTracking:OnProfileChanged()
	self.db = self.addon.db1.profile.minimapTracking
	self:Apply()
end

function MinimapTracking:BuildMenu(rootDescription)
	local db = self.db
	if not db or not db.enabled or ShowAll() then return end

	local entries = {}
	for _, key in ipairs(FILTER_KEYS) do
		local index = FindIndex(key)
		local info = index and C_Minimap.GetTrackingInfo(index)
		if info and info.name then
			entries[#entries + 1] = { key = key, name = info.name }
		end
	end
	if #entries == 0 then return end

	rootDescription:CreateDivider()
	for _, entry in ipairs(entries) do
		rootDescription:CreateCheckbox(entry.name,
			function(key) return MinimapTracking.db[key] == true end,
			function(key) MinimapTracking:SetSetting(key, not MinimapTracking.db[key]) end,
			entry.key)
	end
end

function MinimapTracking:RegisterMenu()
	if self.menuRegistered or not Menu or not Menu.ModifyMenu then return end
	self.menuRegistered = true

	pcall(Menu.ModifyMenu, "MENU_MINIMAP_TRACKING", function(_, rootDescription)
		pcall(MinimapTracking.BuildMenu, MinimapTracking, rootDescription)
	end)
end

function MinimapTracking:Initialize()
	if self.initialized then return end

	local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
	if not SoundAlerter then
		error("MinimapTracking:Initialize() called before addon is ready")
		return
	end

	self.addon = SoundAlerter
	self.db = SoundAlerter.db1.profile.minimapTracking
	self:RegisterMenu()
	self.initialized = true
end

SoundAlerter.MinimapTracking = MinimapTracking
