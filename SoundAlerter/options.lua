local sadb
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local SoundAlerter = SoundAlerter

local CONFIG = "SoundAlerter"
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 940, 640
local built, restored = false, false

local function initOptions()
	if built then return end
	SoundAlerter:OnOptionsCreate()
	for _, v in SoundAlerter:IterateModules() do
		if type(v.OnOptionsCreate) == "function" then
			v:OnOptionsCreate()
		end
	end
	AceConfig:RegisterOptionsTable(CONFIG, SoundAlerter.options)
	built = true
end

local function windowStore()
	local global = SoundAlerter.db1 and SoundAlerter.db1.global
	if not global then return nil end
	global.optionsWindow = global.optionsWindow or {}
	return global.optionsWindow
end

local function restoreWindow()
	if restored then return end
	restored = true
	local status = AceConfigDialog:GetStatusTable(CONFIG)
	local store = windowStore()
	local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
	if not SA_OptionsNav.RestoreWindow(status, store, screenW, screenH) and not status.width then
		AceConfigDialog:SetDefaultSize(CONFIG, DEFAULT_WIDTH, DEFAULT_HEIGHT)
	end
end

local function onWindowHide()
	SA_OptionsNav.RememberPage(AceConfigDialog, sadb.ui)
	local store = windowStore()
	if store then SA_OptionsNav.SaveWindow(AceConfigDialog:GetStatusTable(CONFIG), store) end
end

function SoundAlerter:ShowConfig()
	initOptions()

    local widget = AceConfigDialog.OpenFrames[CONFIG]
    if widget and widget.frame and widget.frame:IsVisible() then
        widget:Hide()
    else
        SA_OptionsNav.RestorePage(AceConfigDialog, sadb.ui)
        restoreWindow()
	    AceConfigDialog:Open(CONFIG)
        local opened = AceConfigDialog.OpenFrames[CONFIG]
        if opened then pcall(SA_WindowSkin.Badge, opened) end
        if opened and sadb.flatWindow ~= false then pcall(SA_WindowSkin.Apply, opened) end
        if opened and opened.frame and not opened.frame.saRemembersPage then
            opened.frame.saRemembersPage = true
            opened.frame:HookScript("OnHide", onWindowHide)
        end
    end
end

function SoundAlerter:OnOptionsProfileChanged()
	sadb = self.db1.profile
	sadb.custom = sadb.custom or {}
	sadb.proximityToasts = sadb.proximityToasts or {}
	sadb.ui = sadb.ui or {}
	sadb.ui.collapsed = sadb.ui.collapsed or {}
end

function SoundAlerter:OnOptionsCreate()
	sadb = self.db1.profile
	self:InvalidateTrackedAuraIDs()
	sadb.ui = sadb.ui or {}
	sadb.ui.collapsed = sadb.ui.collapsed or {}
	SA_OptionsRail.Store = function() return sadb.ui.collapsed end
	self:AddOption("profiles", self:BuildProfileOptions())
	self.options.args.profiles.order = -1

	self:AddOption('QuickStart', self:BuildQuickStartOptions())

	self:AddOption('General', self:BuildGeneralOptions())

	self:AddOption('MinimapButton', self:BuildMinimapButtonOptions())

	self:AddOption('ProximityAlerts', self:BuildProximityOptions())

	self:AddOption('BattlegroundAlerts', self:BuildFlagOptions())

	self:AddOption('Notices', self:BuildNoticesOptions())

	self:AddOption('ResourceBar', self:BuildResourceBarOptions())

	self:AddOption('CastingBars', self:BuildCastingBarOptions())

	self:AddOption('CastFeed', self:BuildCastFeedOptions())

	self:AddOption('SpeedMeter', self:BuildSpeedMeterOptions())

	self:AddOption('Footsteps', self:BuildFootstepsOptions())

	self:AddOption('SpellTracker', self:BuildSpellTrackerOptions())

	self:AddOption('TrinketMenu', self:BuildTrinketMenuOptions())

	self:AddOption('DRTracker', self:BuildDRTrackerOptions())

	self:AddOption('Statistics', self:BuildStatisticsOptions())

	self:AddOption('Spells', self:BuildVoiceAlertOptions())
	self:AddOption('FindSpell', self:BuildSpellFinderOptions())
	self:AddOption('custom', self:BuildCustomAlertOptions())
	SA_OptionsNav.Layout(self.options)
end
