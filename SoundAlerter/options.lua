local sadb
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SoundAlerter")
local self, SoundAlerter = SoundAlerter, SoundAlerter
local GetSpellInfo, GetSpellLink = SA_COMPAT.GetSpellInfo, SA_COMPAT.GetSpellLink

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
        if opened and opened.frame and not opened.frame.saRemembersPage then
            opened.frame.saRemembersPage = true
            opened.frame:HookScript("OnHide", function()
                SA_OptionsNav.RememberPage(AceConfigDialog, sadb.ui)
            end)
        end
    end
end

local function setOption(info, value)
    local name = info[#info]
    sadb[name] = value
    if value then
        SoundAlerter:PlayVoice(sadb.sapath .. name .. ".mp3");
    end
end

local function getOption(info)
	local name = info[#info]
	return sadb[name]
end

local function SpellTexture(sid)
	local spellname,_,icon = GetSpellInfo(sid)
	if spellname ~= nil then
		return "\124T"..icon..":24\124t"
	end
	return ""
end
local function SpellTextureName(sid)
	local spellname,_,icon = GetSpellInfo(sid)
	if spellname ~= nil then
		return "\124T"..icon..":24\124t"..spellname
	end
	return "Unknown Spell ("..sid..")"
end

function SoundAlerter:OnOptionsProfileChanged()
	sadb = self.db1.profile
	sadb.custom = sadb.custom or {}
	sadb.proximityToasts = sadb.proximityToasts or {}
	sadb.ui = sadb.ui or {}
	sadb.ui.collapsed = sadb.ui.collapsed or {}
end

function SoundAlerter:BuildGeneralOptions()
	return {
		type = 'group',
		name = "General",
		icon = "Interface\\Icons\\INV_Misc_Gear_01",
		desc = "General Options",
		order = 1,
		args = {
			enableArea = {
				type = 'group',
				inline = true,
				name = "General options",
				set = setOption,
				get = getOption,
				args = {
					zoneNote = {
						type = 'description',
						name = "Configure zones in the |cff00FF00Quick Start|r tab.\n",
						fontSize = "small",
						order = 0,
					},
					blizzardAudioWarning = {
						type = 'description',
						name = "|cffFF6600Blizzard's own combat audio alerts are on.|r You may hear spoken alerts twice. Turn one of them off in the game's accessibility audio settings if that bothers you.\n",
						fontSize = "medium",
						hidden = function() return not SoundAlerter:BlizzardAudioAlertsEnabled() end,
						order = 0.5,
					},
					all = {
						type = 'toggle',
						name = "Enable Everything",
						desc = "Enables Sound Alerter for BGs, world and arena",
						order = 1,
					},
					volumecontrol = {
						type = 'group',
						inline = true,
						order = 10,
						name = "Volume Control",
						args = {
							volumn = {
								type = 'range',
								max = 1,
								min = 0,
								isPercent = true,
								step = 0.1,
								name = "Master Volume",
								desc = "Sets the master volume so sound alerts can be louder/softer",
								set = function (info, value) SetCVar ("Sound_MasterVolume",tostring (value)) end,
								get = function () return tonumber (GetCVar ("Sound_MasterVolume")) end,
								order = 1,
							},
							volumn2 = {
								type = 'execute',
								width = 'normal',
								name = "Addon sounds only",
								desc = "Sets other sounds to minimum, only hearing the addon sounds",
								func = function()
										SetCVar ("Sound_AmbienceVolume",tostring ("0")); SetCVar ("Sound_SFXVolume",tostring ("0")); SetCVar ("Sound_MusicVolume",tostring ("0"));
										print("|cffFF7D0ASoundAlerter|r: Addons will only be heard by your Client. To undo this, click the 'reset sound options' button.");
									end,
								order = 2,
							},
							volumn3 = {
								type = 'execute',
								width = 'normal',
								name = "Reset volume options",
								desc = "Resets sound options",
								func = function()
										SetCVar ("Sound_MasterVolume",tostring ("1")); SetCVar ("Sound_AmbienceVolume",tostring ("1")); SetCVar ("Sound_SFXVolume",tostring ("1")); SetCVar ("Sound_MusicVolume",tostring ("1"));
										print("|cffFF7D0ASoundAlerter|r: Sound options reset.");
									end,
								order = 3,
							},
						},
					},
					minimapTracking = {
						type = 'group',
						inline = true,
						name = "Minimap Tracking",
						order = 10.5,
						hidden = function() return not SoundAlerter.MinimapTracking end,
						args = {
							enabled = {
								type = 'toggle',
								name = "Track Target/Focus on Minimap",
								desc = "Keeps target and focus on the minimap after every loading screen.",
								get = function() return SoundAlerter.MinimapTracking:GetSettings().enabled end,
								set = function(_, val) SoundAlerter.MinimapTracking:SetSetting("enabled", val) end,
								width = "full",
								order = 1,
							},
							target = {
								type = 'toggle',
								name = "Track Target",
								get = function() return SoundAlerter.MinimapTracking:GetSettings().target end,
								set = function(_, val) SoundAlerter.MinimapTracking:SetSetting("target", val) end,
								disabled = function() return not SoundAlerter.MinimapTracking:GetSettings().enabled end,
								order = 2,
							},
							focus = {
								type = 'toggle',
								name = "Track Focus",
								get = function() return SoundAlerter.MinimapTracking:GetSettings().focus end,
								set = function(_, val) SoundAlerter.MinimapTracking:SetSetting("focus", val) end,
								disabled = function() return not SoundAlerter.MinimapTracking:GetSettings().enabled end,
								order = 3,
							},
						},
					},
					debugopts = {
						type = 'group',
						inline = true,
						order = 11,
						hidden = function() return not sadb.debugmode end,
						name = "Debug options",
						args = {
							cspell = {
							type = 'input',
							name = "Custom spells entry name",
							order = 1,
							},
							spelldebug = {
								type = 'toggle',
								name = "Spell ID output debugging",
								order = 2,
							},
							csname = {
								type = 'input',
								name = "Spell name",
								order = 2,
							},
						},
					},
					importexport = {
						type = 'group',
						inline = true,
						hidden = function() return not sadb.debugmode end,
						name = "Import/Export",
						desc = "Import or export custom sound alerts",
						order = 12,
						args = {
							import = {
								type = 'execute',
								name = "Import custom sound alerts",
								order = 1,
								confirm = true,
								confirmText = "Are you sure? This will remove all of your current sound alerts",
								func = function()
									local CUSTOM_EVENT_ORDER = {"SPELL_CAST_SUCCESS","SPELL_CAST_START","SPELL_AURA_APPLIED","SPELL_AURA_REMOVED","SPELL_INTERRUPT","SPELL_SUMMON"}
									local FS, ES = "\031", "\030"
									local str = sadb.exportbox
									if type(str) ~= "string" or str:sub(1,1) ~= "@" or str:sub(-1) ~= "#" then
										SoundAlerter:Print("Import failed: not a valid export string.")
										return
									end
									local body = str:sub(2, -2)
									local ok, parsed = pcall(function()
										local result = {}
										if body == "" then return result end
										for entry in (body..ES):gmatch("(.-)"..ES) do
											local fields = {}
											for field in (entry..FS):gmatch("(.-)"..FS) do
												fields[#fields+1] = field
											end
											if #fields ~= 15 then error("bad field count: "..#fields) end
											local name, spellid, soundfilepath, chatAlert, chatalerttext, acceptSpellName, spellname, bits, sourceuidfilter, destuidfilter, sourcetypefilter, desttypefilter, sourcecustomname, destcustomname, order = unpack(fields)
											if name == "" then error("empty alert name") end
											local eventtype = {}
											for i, ev in ipairs(CUSTOM_EVENT_ORDER) do
												eventtype[ev] = (bits:sub(i,i) == "1")
											end
											result[name] = {
												name = name,
												spellid = spellid,
												soundfilepath = soundfilepath,
												chatAlert = (chatAlert == "1"),
												chatalerttext = chatalerttext,
												acceptSpellName = (acceptSpellName == "1"),
												spellname = spellname,
												eventtype = eventtype,
												sourceuidfilter = sourceuidfilter,
												destuidfilter = destuidfilter,
												sourcetypefilter = tonumber(sourcetypefilter) or COMBATLOG_FILTER_EVERYTHING,
												desttypefilter = tonumber(desttypefilter) or COMBATLOG_FILTER_EVERYTHING,
												sourcecustomname = sourcecustomname,
												destcustomname = destcustomname,
												order = tonumber(order) or 0,
											}
										end
										return result
									end)
									if not ok or not parsed then
										SoundAlerter:Print("Import failed: malformed data, no changes made.")
										return
									end
									sadb.custom = parsed
									self:OnOptionsCreate()
								end,
							},
							export = {
								type = 'execute',
								name = "Export encapsulation",
								order = 2,
								func = function()
									if not sadb.custom or not next(sadb.custom) then sadb.exportbox = "@#" return end
									local CUSTOM_EVENT_ORDER = {"SPELL_CAST_SUCCESS","SPELL_CAST_START","SPELL_AURA_APPLIED","SPELL_AURA_REMOVED","SPELL_INTERRUPT","SPELL_SUMMON"}
									local FS, ES = "\031", "\030"
									local entries = {}
									for _, css in pairs(sadb.custom) do
										local bits = ""
										for _, ev in ipairs(CUSTOM_EVENT_ORDER) do
											bits = bits..(css.eventtype[ev] and "1" or "0")
										end
										local fields = {
											css.name or "",
											tostring(css.spellid or "0"),
											css.soundfilepath or "",
											css.chatAlert and "1" or "0",
											css.chatalerttext or "",
											css.acceptSpellName and "1" or "0",
											css.spellname or "",
											bits,
											css.sourceuidfilter or "any",
											css.destuidfilter or "any",
											tostring(css.sourcetypefilter or COMBATLOG_FILTER_EVERYTHING),
											tostring(css.desttypefilter or COMBATLOG_FILTER_EVERYTHING),
											css.sourcecustomname or "",
											css.destcustomname or "",
											tostring(css.order or 0),
										}
										entries[#entries+1] = table.concat(fields, FS)
									end
									sadb.exportbox = "@"..table.concat(entries, ES).."#"
								end,
							},
							exportbox = {
								type = 'input',
								name = "Export custom sound alerts",
								order = 3,
							},
						},
					}
				},
			},
		}
	}
end

function SoundAlerter:BuildStatisticsOptions()
	local function statistics()
		return SoundAlerter:GetModule("Statistics")
	end

	local function trackingOff()
		return not sadb.statistics or not sadb.statistics.enabled
	end

	local function refresh()
		LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter")
	end

	local function sortSelect(tableType, values)
		return {
			type = 'select',
			name = "Sort by",
			values = values,
			width = "double",
			order = 1,
			get = function() return statistics():GetSortState()[tableType].sortType end,
			set = function(info, value) statistics():SetSortState(tableType, value) end,
		}
	end

	local function textBlock(order, getter)
		return {
			type = 'description',
			name = getter,
			fontSize = "medium",
			width = "full",
			order = order,
		}
	end

	return {
		type = 'group',
		name = "Statistics",
		icon = "Interface\\Icons\\Spell_Holy_MindVision",
		desc = "Alert statistics for this profile.",
		order = 2.9,
		childGroups = 'tab',
		args = {
			enableTracking = {
				type = 'toggle',
				name = "Enable Statistics Tracking",
				desc = "Track alert statistics (minimal performance impact: <0.02ms per alert)",
				width = "double",
				order = 0.5,
				set = function(info, value)
					statistics():SetSetting("enabled", value)
					if value then
						statistics():InitializeStatistics()
						SoundAlerter:Print("Statistics tracking enabled")
					else
						SoundAlerter:Print("Statistics tracking disabled (existing data preserved)")
					end
				end,
				get = function() return statistics():GetSettings().enabled end,
			},

			refresh = {
				type = 'execute',
				name = "Refresh",
				desc = "Redraw the statistics with the latest numbers",
				width = "half",
				order = 0.6,
				hidden = trackingOff,
				func = refresh,
			},

			summary = {
				type = 'description',
				name = function() return statistics():GetKpiText() end,
				fontSize = "medium",
				width = "full",
				order = 1,
				hidden = trackingOff,
			},

			overview = {
				type = 'group',
				name = "Overview",
				order = 2,
				hidden = trackingOff,
				args = {
					mix = textBlock(1, function() return statistics():GetOverviewText() end),
				},
			},

			spells = {
				type = 'group',
				name = "Spells",
				order = 3,
				hidden = trackingOff,
				args = {
					sort = sortSelect("topSpells", {
						count_desc = "Most alerts",
						trend = "Trend (rising first)",
						name_asc = "Name (A-Z)",
						time = "Most recent",
					}),
					list = textBlock(2, function() return statistics():GetListText("topSpells") end),
				},
			},

			enemies = {
				type = 'group',
				name = "Enemies",
				order = 4,
				hidden = trackingOff,
				args = {
					sort = sortSelect("enemies", {
						alerts_desc = "Most alerts",
						danger = "Danger",
						name_asc = "Name (A-Z)",
						time = "Most recent",
					}),
					list = textBlock(2, function() return statistics():GetListText("enemies") end),
				},
			},

			classes = {
				type = 'group',
				name = "Classes",
				order = 5,
				hidden = trackingOff,
				args = {
					sort = sortSelect("classes", {
						alerts_desc = "Most alerts",
						players = "Most players",
						avg = "Alerts per player",
						class_asc = "Class (A-Z)",
					}),
					list = textBlock(2, function() return statistics():GetListText("classes") end),
				},
			},

			data = {
				type = 'group',
				name = "Data",
				order = 6,
				hidden = trackingOff,
				args = {
					export = {
						type = 'input',
						name = "Export (select all, copy)",
						multiline = 12,
						width = "full",
						order = 1,
						get = function() return statistics():GetExportText() end,
						set = function() end,
					},
					resetSession = {
						type = 'execute',
						name = "Reset session",
						desc = "Reset this session's numbers. All-time statistics are kept.",
						width = "normal",
						order = 2,
						confirm = true,
						confirmText = "Reset this session's statistics?",
						func = function()
							statistics():ResetSession()
							SoundAlerter:Print("Session statistics reset")
							refresh()
						end,
					},
					resetAllTime = {
						type = 'execute',
						name = "Reset all-time",
						desc = "Delete all statistics for this profile, session and all-time.",
						width = "normal",
						order = 3,
						confirm = function()
							local allTime = sadb.statistics and sadb.statistics.allTime
							return string.format("Delete all statistics?\n\nTotal alerts: %d\nTotal sessions: %d\n\n|cffFF0000This cannot be undone!|r",
								allTime and allTime.totalAlerts or 0, allTime and allTime.totalSessions or 0)
						end,
						func = function()
							statistics():ResetAllTime()
							SoundAlerter:Print("|cffFF0000All statistics reset|r")
							refresh()
						end,
					},
				},
			},
		},
	}
end

function SoundAlerter:BuildVoiceAlertOptions()
	local silenceGroup = {
		type = 'group',
		name = "Global Category Toggles",
		desc = "Master toggles to disable entire spell categories. Uncheck to silence all alerts in that category.",
		inline = true,
		set = setOption,
		get = getOption,
		order = -1,
		args = {
			globalNote = {
				type = 'description',
				name = "|cffFFD700Note:|r These toggles disable entire categories. Use per-spell toggles below for fine-grained control.\n",
				fontSize = "small",
				order = 0,
			},
			aruaApplied = {
				type = 'toggle',
				name = "Silence Buff Applied Alerts",
				desc = "When checked: Disables ALL sound notifications when enemy buffs are applied",
				order = 1,
			},
			auraRemoved = {
				type = 'toggle',
				name = "Silence Buff Removed Alerts",
				desc = "When checked: Disables ALL sound notifications when enemy buffs expire",
				order = 2,
			},
			castStart = {
				type = 'toggle',
				name = "Silence Spell Casting Alerts",
				desc = "When checked: Disables ALL notifications when enemies start casting spells",
				order = 3,
			},
			castSuccess = {
				type = 'toggle',
				name = "Silence Enemy Cooldown Alerts",
				desc = "When checked: Disables ALL sound notifications of enemy cooldown abilities",
				order = 4,
			},
			chatalerts = {
				type = 'toggle',
				name = "Silence Chat Alerts",
				desc = "When checked: Disables ALL chat notifications of special abilities",
				order = 5,
			},
			interrupt = {
				type = 'toggle',
				name = "Silence Interrupt Alerts",
				desc = "When checked: Disables notifications of friendly interrupted spells",
				order = 6,
			},
			dArenaPartner = {
				type = 'toggle',
				name = "Silence Arena Partner CC Alerts",
				desc = "When checked: Disables notifications when arena partners are CC'd",
				order = 7,
			},
			dSelfDebuff = {
				type = 'toggle',
				name = "Silence Self Debuff Alerts",
				desc = "When checked: Disables notifications when YOU are debuffed/CC'd",
				order = 8,
			},
			dEnemyDebuff = {
				type = 'toggle',
				name = "Silence Enemy Debuff Alerts",
				desc = "When checked: Disables notifications of enemy debuffs/CC",
				order = 9,
			},
			dEnemyDebuffDown = {
				type = 'toggle',
				name = "Silence Enemy Debuff Expired Alerts",
				desc = "When checked: Disables notifications when enemy debuffs/CC expire",
				order = 10,
			},
		},
	}
	return {
		type = 'group',
		name = "Voice Alerts",
		icon = "Interface\\Icons\\INV_Misc_Bell_01",
		desc = "Customize which enemy and friendly spells trigger voice alerts. Organized by strategic purpose to help you focus on what matters in PvP.",
		order = 2,
		childGroups = "tab",
		args = {
			alerts = SoundAlerter:BuildVoiceAlertPanel({
				silence = silenceGroup,
				setOption = setOption,
				getOption = getOption,
				spellTexture = SpellTexture,
			}),
			chatalerter = SoundAlerter:RailChat({
				type = 'group',
				name = "Chat Alerts",
				desc = "Alerts you and others via sending a chat message",
				disabled = function() return sadb.chatalerts end,
				set = setOption,
				get = getOption,
				order = 1,
				args = {
					caonlyTF = {
						type = 'toggle',
						name = L["Target and Focus only"],
						desc = L["Alerts you when your target or focus is applicable to a sound alert"],
						order = 1,
					},
					chatgroup = {
						type = 'group',
						order = 2,
						name = L["Chat Channels to Alert In"],
						inline = true,
						args = {
							NONE = {
								type = 'toggle',
								order = 0,
								name = L["None (Disable Chat Alerts)"],
								desc = L["Disables all chat alerts globally, overriding other selections."],
								set = function(info, value) sadb.chatgroups.NONE = value end,
								get = function(info) return sadb.chatgroups.NONE end,
							},
							SAY = {
								type = 'toggle',
								order = 1,
								name = L["Say"],
								set = function(info, value) sadb.chatgroups.SAY = value end,
								get = function(info) return sadb.chatgroups.SAY end,
							},
							PARTY = {
								type = 'toggle',
								order = 2,
								name = L["Party"],
								set = function(info, value) sadb.chatgroups.PARTY = value end,
								get = function(info) return sadb.chatgroups.PARTY end,
							},
							RAID = {
								type = 'toggle',
								order = 3,
								name = L["Raid"],
								set = function(info, value) sadb.chatgroups.RAID = value end,
								get = function(info) return sadb.chatgroups.RAID end,
							},
							BATTLEGROUND = {
								type = 'toggle',
								order = 4,
								name = L["Battleground"],
								set = function(info, value) sadb.chatgroups.BATTLEGROUND = value end,
								get = function(info) return sadb.chatgroups.BATTLEGROUND end,
							},
						},
					},
					spells = {
						type = 'group',
						inline = true,
						name = "Spells",
						order = 3,
						args = {
							stealthenemy = {
								type = 'toggle',
								name = SpellTextureName(1784),
								desc = function ()
									GameTooltip:SetHyperlink(GetSpellLink(1784));
								end,
								order = 1,
							},
							prowlenemy = {
                                type = 'toggle',
                                name = SpellTextureName(5215),
                                desc = function ()
                                    GameTooltip:SetHyperlink(GetSpellLink(5215));
                                end,
                                order = 2,
                            },
							blindenemy = {
								type = 'toggle',
								name = SpellTexture(2094).."Blind on Enemy",
								desc = "Enemies you blind will be alerted in chat",
								order = 3,
							},
							blindselffriend = {
								type = 'toggle',
								name = SpellTexture(2094).."Blind on Self/Friend",
								desc = "Enemies that have blinded you will be alerted",
								order = 4,
							},
							hexenemy = {
								type = 'toggle',
								name = SpellTexture(450600).."Hex on Enemy",
								desc = "Enemies you hex will be alerted in chat",
								order = 7,
							},
							hexselffriend = {
								type = 'toggle',
								name = SpellTexture(450600).."Hex on Self/Friend",
								desc = "Enemies you hex will be alerted in chat",
								order = 8,
							},
							fearenemy = {
								type = 'toggle',
								name = SpellTexture(5484).."Fear on Enemy",
								desc = "Enemies you fear will be alerted in chat",
								order = 9,
							},
							fearselffriend = {
								type = 'toggle',
								name = SpellTexture(5484).."Fear on Self/friend",
								desc = "Enemies you fear will be alerted in chat",
								order = 10,
							},
							sapenemy = {
								type = 'toggle',
								name = SpellTexture(6770).."Sap on Enemy",
								desc = "Enemies you sapped will be alerted",
								order = 11,
							},
							bubbleenemy = {
								type = 'toggle',
								name = SpellTextureName(642),
								desc = "Enemies that have casted Divine Shield will be alerted",
								order = 12,
							},
							polyenemy = {
								type = 'toggle',
								name = SpellTextureName(118),
								desc = "Enemies that have casted Polymorph will be alerted",
								order = 13,
							},
							vanishenemy = {
								type = 'toggle',
								name = SpellTextureName(1856),
								desc = "Enemies that have casted Vanish will be alerted",
								order = 13,
							},
							trinketalert = {
								type = 'toggle',
								name = SpellTextureName(1259718),
								desc = function ()
									local link = GetSpellLink(1259718)
									if link then GameTooltip:SetHyperlink(link) end
								end,
								order = 14,
							},
							interruptenemy = {
								type = 'toggle',
								name = "Interrupt on Enemy",
								desc = "Sends a chat message if you have interrupted an enemy's spell.",
								order = 15,
							},
							interruptemote = {
								type = 'toggle',
								name = "Roar on Interrupt",
								desc = "Plays the /roar emote when you interrupt an enemy's spell.",
								order = 15.5,
							},
							interruptself = {
								type = 'toggle',
								name = "Interrupt on Self",
								desc = "Sends a chat message if an enemy has interrupted you.",
								order = 16,
							},
							chatdownself = {
								type = 'toggle',
								name = "Alert enemy debuff down (from self)",
								desc = "Sends a chat message when an enemies debuff is down that came from yourself (eg. Hex down)",
								order = 17,
							},
							chatdownfriend = {
								type = 'toggle',
								name = "Alert enemy debuff down (from friend)",
								desc = "Sends a chat message when an enemies debuff is down that came from yourself (eg. Hex down)",
								order = 17,
							},
							chatauraApplied = {
								type = 'toggle',
								name = "Announce Enemy Defensives & Buffs",
								desc = "Sends a chat message when a tracked enemy uses a defensive cooldown or buff.",
								order = 18,
							},
							chatauraRemoved = {
								type = 'toggle',
								name = "Announce Enemy Defensives Expired",
								desc = "Sends a chat message when a tracked enemy's defensive cooldown or buff wears off.",
								order = 19,
							},
							chatcastStart = {
								type = 'toggle',
								name = "Announce Enemy Cast Start",
								desc = "Sends a chat message when a tracked enemy begins casting.",
								order = 20,
							},
						},
					},
					general = {
						type = "group",
						inline = true,
						name = "General Chat Alerts",
						args = {
							enemychat = {
								type = "input",
								name = "To Enemy",
								desc = "Example: '#spell# up on #enemy#' = [Blind] up on Enemyname",
								order = 1,
								width = "full",
							},
							friendchat = {
								type = "input",
								name = "From Enemy to friend",
								desc = "Example: '#enemy# casted #spell# on #target# = Enemyname casted [Blind] on FriendName",
								order = 2,
								width = "full",
							},
							selfchat = {
								type = "input",
								name = "From Enemy to self",
								desc = "Example: '#enemy# casted #spell# on #target# = Enemyname casted [Blind] on FriendName",
								order = 3,
								width = "full",
							},
							enemybuffchat = {
								type = "input",
								name = "Enemy buffs/cooldowns",
								desc = "Example: '#enemy# casted #spell#  = Enemyname casted [Stealth]",
								order = 4,
								width = "full",
							},
							auraRemovedChat = {
								type = "input",
								name = "Enemy defensives expired",
								desc = "Example: '#spell# wore off #enemy#' = [Ice Block] wore off Enemyname",
								order = 5,
								width = "full",
							},
							castStartChat = {
								type = "input",
								name = "Enemy cast start",
								desc = "Example: '#enemy# is casting #spell#' = Enemyname is casting [Polymorph]",
								order = 6,
								width = "full",
							},
						},
					},
					saptextfriendg = {
						type = "group",
						inline = true,
						hidden = function() if sadb.sapenemy then return false else return true end end,
						name = SpellTexture(6770).."Sap on self/friend",
						order = 13,
						args = {
							sapselftext = {
							type = "input",
							name = "Sap on Self (Avoid using '#enemy# due to unknown enemy when stealthed)",
							order = 1,
							width = "full",
							},
							sapfriendtext = {
							type = "input",
							name = "Sap on Friend (Avoid using '#enemy# due to unknown enemy when stealthed)",
							order = 1,
							width = "full",
							},
						},
					},
				trinketalerttextg = {
						type = "group",
						inline = true,
						hidden = function() if sadb.trinketalert then return false else return true end end,
						name = "PvP trinket text",
						order = 14,
						args = {
							trinketalerttext = {
							type = 'input',
							name = "Example: '#enemy# casted #spell#!' = Enemyname casted [PvP Trinket]!",
							order = 1,
							width = "full",
							},
						},
					},
				stealthalerttextg = {
						type = "group",
						inline = true,
						hidden = function() if sadb.stealthenemy then return false else return true end end,
						name = SpellTextureName(1784),
						order = 15,
						args = {
							stealthTF = {
							type = 'toggle',
							name = "Ignore target/focus",
							order = 2,
							},
						},
					},
				prowlalerttextg = {
						type = "group",
						inline = true,
						hidden = function() if sadb.prowlenemy then return false else return true end end,
						name = SpellTextureName(5215),
						order = 16,
						args = {
							prowlTF = {
							type = 'toggle',
							name = "Ignore target/focus",
							order = 3,
							},
						},
					},
				vanishalerttextg = {
						type = "group",
						inline = true,
						hidden = function() if sadb.vanishenemy then return false else return true end end,
						name = SpellTextureName(1856),
						order = 17,
						args = {
							vanishTF = {
							type = 'toggle',
							name = "Ignore target/focus",
							order = 4,
							},
						},
					},
			InterruptTextg = {
						type = "group",
						inline = true,
						name = "Interrupt Text",
						order = 18,
						args = {
							InterruptEnemyText = {
							name = "Interrupt on Enemy (eg. 'Interrupted #enemy#'s #interruptedspellname# with #spell#.')",
							hidden = function() if sadb.interruptenemy then return false else return true end end,
							type = "input",
							order = 1,
							width = "full",
							},
							InterruptSelfText = {
							name = "Interrupts from Enemy (eg. '#enemy# interrupted my #interruptedspellname# with #spell#.')",
							hidden = function() if sadb.interruptself then return false else return true end end,
							type = "input",
							order = 1,
							width = "full",
							},
						},
					},
				},
			}),
		},
	}
end

local function IsDatabaseBuilding()
	return SoundAlerter.spellDatabase.isBuilding
end

local LONG_SCAN_SECONDS = 30

local function ScanDurationText(seconds)
	if seconds >= 90 then
		return string.format("%d minutes", math.floor(seconds / 60 + 0.5))
	end
	return string.format("%d seconds", math.ceil(seconds))
end

function SoundAlerter:BuildSpellFinderOptions()
	local function devtools()
		return SoundAlerter.DevTools
	end

	local function refresh()
		devtools():Invalidate()
		LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter")
	end

	return {
		type = 'group',
		name = "Developer Tools",
		icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
		desc = "Spell Finder, spell database and debug tools.",
		order = 5,
		childGroups = 'tab',
		args = {
			status = {
				type = 'description',
				name = function() return devtools():GetStatusText() end,
				fontSize = "medium",
				width = "full",
				order = 1,
			},

			finder = {
				type = 'group',
				name = "Finder",
				order = 2,
				args = {
					openFinder = {
						type = 'execute',
						name = "|cff00D4FF[OPEN SPELL FINDER PANEL]|r",
						desc = "Open the spell search panel, docked beside this options window. Press Enter to search, hover results for tooltips.",
						width = "full",
						order = 1,
						func = function()
							if not SoundAlerter.findSpellFrame then
								SoundAlerter.findSpellFrame = SoundAlerter:CreateFindSpellFrame()
							end
							local finderFrame = SoundAlerter.findSpellFrame
							finderFrame:Show()

							local mainFrame = AceConfigDialog.OpenFrames["SoundAlerter"]
							if mainFrame and mainFrame.frame and finderFrame.frame then
								finderFrame.frame:ClearAllPoints()
								finderFrame.frame:SetPoint("TOPLEFT", mainFrame.frame, "TOPRIGHT", 6, 0)

								if not mainFrame.frame.soundAlerterFinderHideHooked then
									mainFrame.frame.soundAlerterFinderHideHooked = true
									mainFrame.frame:HookScript("OnHide", function()
										if SoundAlerter.findSpellFrame then
											SoundAlerter.findSpellFrame:Hide()
										end
									end)
								end
							end
							if finderFrame.frame then
								finderFrame.frame:Raise()
							end
						end,
					},
					searchScope = {
						type = 'select',
						name = "Search In",
						desc = "Names: spell names only (autocomplete and fuzzy apply). Names + descriptions: name matches first, then matches inside spell descriptions. Descriptions only: match the text inside descriptions, nothing else. Either description option builds an index of every spell's description while the Spell Finder window is open (loaded from the game in small batches, paused when the window closes, resumable, saved between sessions in SoundAlerterSpellDescDB, a few MB). Until it finishes, only the indexed part is searched. Description searches need 3+ characters.",
						values = {
							names = "Names",
							both = "Names + descriptions",
							descriptions = "Descriptions only",
						},
						sorting = {"names", "both", "descriptions"},
						width = "double",
						order = 2,
						get = function() return SoundAlerter:GetSearchScope() end,
						set = function(info, value)
							SoundAlerter:SetSearchScope(value)
							SoundAlerter:Print("Spell Finder search scope: " .. value)
						end,
					},
					fuzzy = {
						type = 'toggle',
						name = "Fuzzy Name Search",
						desc = "Typo-tolerant matching: substring anywhere in the name, then in-order letters (abbreviations like 'frstblt'), then one or two typos (e.g. 'forstbolt'; the first letter must be right). Results rank by closeness (sort by Relevance). Typo-heavy queries cost more than plain ones.",
						width = "full",
						order = 3,
						get = function() return SoundAlerter:GetFinderSettings().fuzzy or false end,
						set = function(info, value)
							SoundAlerter:SetFinderSetting("fuzzy", value)
							SoundAlerter:ClearSearchCache()
							SoundAlerter:Print(value and "|cFF00FF00Fuzzy search enabled|r" or "|cFFFF0000Fuzzy search disabled|r")
						end,
					},
					autocomplete = {
						type = 'toggle',
						name = "Autocomplete Spell Names",
						desc = "Show up to 8 spell-name suggestions under the search box while typing (minimum 2 characters, prefix match). Tab accepts the first or highlighted suggestion, Up/Down moves the highlight, click searches it.",
						width = "full",
						order = 4,
						get = function() return SoundAlerter:GetFinderSettings().autocomplete or false end,
						set = function(info, value)
							SoundAlerter:SetFinderSetting("autocomplete", value)
							SoundAlerter:Print(value and "|cFF00FF00Autocomplete enabled|r" or "|cFFFF0000Autocomplete disabled|r")
						end,
					},
					descriptionStatus = {
						type = 'description',
						name = function() return SoundAlerter:GetDescriptionStatus() end,
						fontSize = "medium",
						width = "full",
						order = 5,
					},
					clearDescriptions = {
						type = 'execute',
						name = "Clear Description Index",
						desc = "Stops indexing and deletes the saved description index (frees the SavedVariables space).",
						order = 6,
						func = function()
							SoundAlerter:ClearDescriptionIndex()
							SoundAlerter:Print("Spell description index cleared")
						end,
					},
				},
			},

			database = {
				type = 'group',
				name = "Database",
				order = 3,
				args = {
					info = {
						type = 'description',
						name = function() return devtools():GetDatabaseText() end,
						fontSize = "medium",
						width = "full",
						order = 1,
					},
					rebuild = {
						type = 'execute',
						name = "|cffFFAA00[REBUILD DATABASE]|r",
						desc = function()
							local maxID, seconds = SoundAlerter:GetSpellScanInfo()
							return string.format("Full rebuild of the spell database. Scans every spell ID from 1 to %d and takes at least %s.%s Only needed after a major game patch or if the database is corrupted.", maxID, ScanDurationText(seconds), seconds >= LONG_SCAN_SECONDS and " You will be asked to confirm twice." or "")
						end,
						width = "full",
						order = 2,
						disabled = IsDatabaseBuilding,
						confirm = function()
							local maxID, seconds = SoundAlerter:GetSpellScanInfo()
							return string.format("|cffFFAA00WARNING:|r indexing spell IDs 1 to %d takes at least %s and can make the game stutter while it runs. Do you want to continue?", maxID, ScanDurationText(seconds))
						end,
						func = function()
							local maxID, seconds = SoundAlerter:GetSpellScanInfo()
							local function startScan()
								devtools():Invalidate()
								SoundAlerter:RebuildSpellDatabase()
							end
							if seconds < LONG_SCAN_SECONDS then
								startScan()
								return
							end
							StaticPopupDialogs["SOUNDALERTER_CONFIRM_SPELL_SCAN"] = {
								text = string.format("|cffFF4040FINAL CONFIRMATION|r\n\nThis starts a full spell index (IDs 1 to %d). It takes at least %s and you may notice stuttering until it finishes. Start the scan now?", maxID, ScanDurationText(seconds)),
								button1 = "Start scan",
								button2 = CANCEL,
								OnAccept = startScan,
								timeout = 0,
								whileDead = true,
								hideOnEscape = true,
								preferredIndex = 3,
							}
							StaticPopup_Show("SOUNDALERTER_CONFIRM_SPELL_SCAN")
						end,
					},
				},
			},

			performance = {
				type = 'group',
				name = "Performance",
				order = 4,
				args = {
					timings = {
						type = 'description',
						name = function() return devtools():GetPerformanceText() end,
						fontSize = "medium",
						width = "full",
						order = 1,
					},
					refresh = {
						type = 'execute',
						name = "Refresh",
						desc = "Re-read the timings and memory now",
						width = "half",
						order = 2,
						func = refresh,
					},
				},
			},

			debug = {
				type = 'group',
				name = "Debug",
				order = 5,
				args = {
					debugmode = {
						type = 'toggle',
						name = "Debug Mode",
						desc = "Prints readable traces of alert decisions, skipped chat sends, secret-value fallbacks and timings to chat. Each line is tagged with time and module.",
						width = "full",
						order = 1,
						get = function() return sadb.debugmode end,
						set = function(info, value)
							sadb.debugmode = value
							devtools():Invalidate()
						end,
					},
				},
			},
		},
	}
end

function SoundAlerter:BuildCustomAlertOptions()
	return {
		type = 'group',
		name = "Advanced",
		icon = "Interface\\Icons\\INV_Misc_Wrench_01",
		desc = "Advanced customization: create custom alerts, configure event filters, and fine-tune addon behavior for power users.",
		order = 4,
		args = {
			newalert = {
				type = 'execute',
				name = function ()
							if sadb.custom[L["New Alert"]] then
								return L["Rename the New Alert entry"]
							else
								return L["New Alert"]
							end
						end,
				order = -1,
				func = function()
					sadb.custom[L["New Alert"]] = {
						name = L["New Alert"],
						soundfilepath = L["New Alert"]..".[ogg/mp3/wav]",
						sourceuidfilter = "any",
						destuidfilter = "any",
						eventtype = {
							SPELL_CAST_SUCCESS = true,
							SPELL_CAST_START = false,
							SPELL_AURA_APPLIED = false,
							SPELL_AURA_REMOVED = false,
							SPELL_INTERRUPT = false,
							SPELL_SUMMON = false,
						},
						sourcetypefilter = COMBATLOG_FILTER_EVERYTHING,
						desttypefilter = COMBATLOG_FILTER_EVERYTHING,
						order = 0,
					}
					self:OnOptionsCreate()
				end,
				disabled = function ()
					if sadb.custom[L["New Alert"]] then
						return true
					else
						return false
					end
				end,
			},
		}
	}
end

function SoundAlerter:OnOptionsCreate()
	sadb = self.db1.profile
	self:InvalidateTrackedAuraIDs()
	sadb.ui = sadb.ui or {}
	sadb.ui.collapsed = sadb.ui.collapsed or {}
	SA_OptionsRail.Store = function() return sadb.ui.collapsed end
	self:AddOption("profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db1))
	self.options.args.profiles.order = -1

	self:AddOption('QuickStart', self:BuildQuickStartOptions())

	self:AddOption('General', self:BuildGeneralOptions())

	self:AddOption('ProximityAlerts', self:BuildProximityOptions())

	self:AddOption('BattlegroundAlerts', self:BuildFlagOptions())

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
	local function makeoption(key)
		local keytemp = key
		self.options.args.custom.args[key] = {
			type = 'group',
			name = sadb.custom[key].name,
			set = function(info, value) local name = info[#info] sadb.custom[key][name] = value SoundAlerter:InvalidateTrackedAuraIDs() end,
			get = function(info) local name = info[#info] return sadb.custom[key][name] end,
			order = sadb.custom[key].order,
			args = {
				name = {
					name = L["Spell Entry Name"],
					desc = L["Menu entry for the spell (eg. Hex down on arena partner)"],
					type = 'input',
					set = function(info, value)
						if sadb.custom[value] then SoundAlerter:Print(L["same name already exists"]) return end
						sadb.custom[key].name = value
						sadb.custom[key].order = 100
						sadb.custom[value] = sadb.custom[key]
						sadb.custom[key] = nil
						self.options.args.custom.args[keytemp].name = value
						key = value
					end,
					order = 1,
				},
				spellname = {
					name = L["Spell Name"],
					type = 'input',
					order = 10,
					hidden = function() return not sadb.custom[key].acceptSpellName end,
				},
				spellid = {
					name = L["Spell ID"],
					desc = L["Visible in the spell tooltip when tooltip spell IDs are enabled"],
					set = function(info, value)
					local name = info[#info] sadb.custom[key][name] = value
						SoundAlerter:InvalidateTrackedAuraIDs()
						if GetSpellInfo(value) then
							sadb.custom[key].spellname = GetSpellInfo(value)
							self.options.args.custom.args[keytemp].spellname = GetSpellInfo(value)
						else
						sadb.custom[key].spellname = "Invalid Spell ID"
						self.options.args.custom.args[keytemp].spellname = "Invalid Spell ID"
						end
					end,
					type = 'input',
					order = 20,
					pattern = "%d+$",
				},
				remove = {
					type = 'execute',
					order = 25,
					name = L["Remove"],
					confirm = true,
					confirmText = L["Are you sure?"],
					func = function()
						sadb.custom[key] = nil
						SoundAlerter:InvalidateTrackedAuraIDs()
						self.options.args.custom.args[keytemp] = nil
					end,
				},
				acceptSpellName = {
					type = 'toggle',
					name = "Use specific spell name",
					desc = "Use this in case there are multiple ranks for this spell",
					order = 26,
				},
				chatAlert = {
					type = 'toggle',
					name = "Chat Alert",
					order = 27,
				},
				test = {
					type = 'execute',
					order = 28,
					name = L["Test"],
					desc = L["If you don't hear anything, try restarting WoW"],
					func = function() SoundAlerter:PlayVoice("Interface\\Addons\\SoundAlerter\\CustomSounds\\"..sadb.custom[key].soundfilepath) end,
					hidden = function() if sadb.custom[key].chatAlert then return true end end,
				},
				soundfilepath = {
					name = L["File Path"],
					desc = L["Place your ogg/mp3 custom sound in the CustomSounds folder in Interface/Addons/SoundAlerter/"],
					type = 'input',
					width = 'double',
					order = 27,
					hidden = function() if sadb.custom[key].chatAlert then return true end end,
				},
				chatalerttext = {
					name = "Chat Alert Text",
					desc = "eg. #enemy# casted #spell# on me! (Use '%t' if you're casting a spell on an enemy. )",
					type = 'input',
					width = 'double',
					order = 28,
					hidden = function() if not sadb.custom[key].chatAlert then return true end end,
				},
				eventtype = {
					type = 'multiselect',
					order = 50,
					name = L["Event type - it's best to have the least amount of event conditions"],
					values = self.SA_EVENT,
					get = function(info, k) return sadb.custom[key].eventtype[k] end,
					set = function(info, k, v) sadb.custom[key].eventtype[k] = v SoundAlerter:InvalidateTrackedAuraIDs() end,
				},
				sourceuidfilter = {
					type = 'select',
					order = 61,
					name = L["Source unit"],
					desc = L["Is the person who casted the spell your target/focus/mouseover?"],
					values = self.SA_UNIT,
				},
				sourcetypefilter = {
					type = 'select',
					order = 60,
					name = L["Source of the spell"],
					desc = L["Who casted the spell? Leave on 'any' if a spell got casted on you"],
					values = self.SA_TYPE,
				},
				sourcecustomname = {
					type= 'input',
					order = 62,
					name = L["Custom source name"],
					desc = L["Example: If the spell came from a specific player or boss"],
					disabled = function() return sadb.custom[key].sourceuidfilter ~= "custom" end,
				},
				destuidfilter = {
					type = 'select',
					order = 65,
					name = L["Spell destination unit"],
					desc = L["Was the spell destination towards your target/focus/mouseover? (Leave on 'player' if it's yourself)"],
					values = self.SA_UNIT,
				},
				desttypefilter = {
					type = 'select',
					order = 63,
					name = L["Spell Destination"],
					desc = L["Who was afflicted by the spell? Leave it on 'any' if it's a spell cast or a buff"],
					values = self.SA_TYPE,
				},
				destcustomname = {
					type= 'input',
					order = 68,
					name = L["Custom destination name"],
					disabled = function() return sadb.custom[key].destuidfilter ~= "custom" end,
				},
			}
		}
	end
	for key in pairs(sadb.custom) do
		makeoption(key)
	end
	SA_OptionsNav.Layout(self.options)
end
