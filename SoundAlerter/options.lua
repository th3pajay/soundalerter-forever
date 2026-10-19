local sadb
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SoundAlerter")
local self, SoundAlerter = SoundAlerter, SoundAlerter
local GetSpellInfo = SA_COMPAT.GetSpellInfo

local function initOptions()
	if SoundAlerter.options.args.general then
		return
	end
	SoundAlerter:OnOptionsCreate()
	for _, v in SoundAlerter:IterateModules() do
		if type(v.OnOptionsCreate) == "function" then
			v:OnOptionsCreate()
		end
	end
	AceConfig:RegisterOptionsTable("SoundAlerter", SoundAlerter.options)
	AceConfigDialog:SetDefaultSize("SoundAlerter", 940, 640)
end

function SoundAlerter:ShowConfig()
	initOptions()
    local configName = "SoundAlerter"

    local widget = AceConfigDialog.OpenFrames[configName]
    if widget and widget.frame and widget.frame:IsVisible() then
        widget:Hide()
    else
        SA_OptionsNav.RestorePage(AceConfigDialog, sadb.ui)
	    AceConfigDialog:Open(configName)
        local opened = AceConfigDialog.OpenFrames[configName]
        if opened then pcall(SA_WindowSkin.Badge, opened) end
        if opened and sadb.flatWindow ~= false then pcall(SA_WindowSkin.Apply, opened) end
        if opened and opened.frame and not opened.frame.saRemembersPage then
            opened.frame.saRemembersPage = true
            opened.frame:HookScript("OnHide", function()
                SA_OptionsNav.RememberPage(AceConfigDialog, sadb.ui)
            end)
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

	self:AddOption('CombatTimer', self:BuildCombatTimerOptions())

	self:AddOption('SpeedMeter', self:BuildSpeedMeterOptions())

	self:AddOption('Footsteps', self:BuildFootstepsOptions())

	self:AddOption('SpellTracker', self:BuildSpellTrackerOptions())

	self:AddOption('Statistics', self:BuildStatisticsOptions())

	self:AddOption('Spells', self:BuildVoiceAlertOptions())
	self:AddOption('FindSpell', self:BuildSpellFinderOptions())
	self:AddOption('custom', self:BuildCustomAlertOptions())
	SA_OptionsNav.Layout(self.options)
end
