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
end

function SoundAlerter:ShowConfig()
	initOptions()
    local configName = "SoundAlerter"

    local widget = AceConfigDialog.OpenFrames[configName]
    if widget and widget.frame and widget.frame:IsVisible() then
        widget:Hide()
    else
	    AceConfigDialog:Open(configName)
    end
end

local function setOption(info, value)
    local name = info[#info]
    sadb[name] = value
    if value then
        PlaySoundFile(sadb.sapath .. name .. ".mp3");
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

function SoundAlerter:BuildProximityOptions()
	return {
		type = 'group',
		name = "Proximity Alerts",
		icon = "Interface\\Icons\\Ability_Tracking",
		desc = "Detect enemy stealthed players nearby and get voice alerts. Perfect for spotting Rogues and Druids in stealth.",
		order = 2.5,
		args = {
			description = {
				type = 'description',
				name = "|cffFFD700Proximity Alerts|r detect hostile players nearby — useful for spotting ganks and stealthed Rogues/Druids as soon as they act.\n\n|cffFFFFFFTriggers:|r an enemy player's nameplate rendering nearby, or targeting / mousing over one. Stealthed enemies are only detected once they unstealth and their nameplate appears.\n",
				fontSize = "medium",
				order = 1,
			},

			initErrorWarning = {
				type = 'description',
				name = function()
					return "|cffFF0000Proximity Alerts failed to initialize this session:|r\n" ..
					       tostring(SoundAlerter.moduleInitErrors and SoundAlerter.moduleInitErrors.ProximityToasts) ..
					       "\n\n|cffFFFFFFToggles below will not take effect until this is fixed and you /reload.|r\n"
				end,
				fontSize = "medium",
				order = 1.2,
				hidden = function() return SoundAlerter.ProximityToasts ~= nil end,
			},
			showAdvancedProximity = {
				type = 'toggle',
				name = "Show Advanced Options",
				desc = "Reveal power-user settings (click-to-target interactions) at the bottom of this tab.",
				set = function(info, value) sadb.showAdvancedProximity = value end,
				get = function(info) return sadb.showAdvancedProximity end,
				width = "full",
				order = 1.5,
			},

			basicSetup = {
				type = 'group',
				inline = true,
				name = "1. Basic Setup",
				desc = "Core settings to enable and configure proximity detection",
				set = setOption,
				get = getOption,
				order = 2,
				args = {
					proximityEnabled = {
						type = 'toggle',
						name = "Enable Proximity Alerts",
						desc = "Master toggle for proximity detection system. Enable this first to activate all proximity features.",
						width = "full",
						order = 1,
					},
					spacer1 = {
						type = 'description',
						name = " ",
						order = 2,
					},
					zoneHeader = {
						type = 'header',
						name = "Active Zones",
						order = 3,
					},
					proximityWorld = {
						type = 'toggle',
						name = "World PvP",
						desc = "Enable proximity alerts in open world PvP zones",
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 5,
					},
					proximityBattleground = {
						type = 'toggle',
						name = "Battlegrounds",
						desc = "Enable proximity alerts in battlegrounds (useful for detecting flag carriers and node defenders)",
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 6,
					},
					proximityArena = {
						type = 'toggle',
						name = "Arena",
						desc = "Enable proximity alerts in arenas (less useful due to small arena size)",
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 7,
					},
					proximitySanctuary = {
						type = 'toggle',
						name = "Sanctuary",
						desc = "Enable proximity alerts in sanctuary zones (e.g. Moonglade) where PvP-flagged enemies can still attack you despite guards.",
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 8,
					},
					spacer2 = {
						type = 'description',
						name = " ",
						order = 9,
					},
					cooldownHeader = {
						type = 'header',
						name = "Alert Cooldown",
						order = 10,
					},
					proximityCooldown = {
						type = 'range',
						name = "Cooldown Duration (seconds)",
						desc = "Time before the same player can trigger another proximity alert. Prevents spam while still alerting to threats.",
						min = 5,
						max = 120,
						step = 5,
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 11,
					},
					spacer3 = {
						type = 'description',
						name = " ",
						order = 12,
					},
					nameplateHeader = {
						type = 'header',
						name = "Nameplate Range",
						order = 13,
					},
					overrideNameplateRange = {
						type = 'toggle',
						name = "Increase Nameplate Distance",
						desc = "Overrides your client's nameplate render distance to extend proximity detection range. Affects all nameplates (allies, NPCs, everything), not just enemies. Disabling this restores your client's default distance.",
						get = function() return sadb.overrideNameplateRange end,
						set = function(info, value)
							sadb.overrideNameplateRange = value
							SoundAlerter:ApplyNameplateRange()
						end,
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 14,
					},
					nameplateRange = {
						type = 'range',
						name = "Nameplate Distance (yards)",
						desc = "Distance to render nameplates. ~100 yards is effectively the practical ceiling - the client has no data on units beyond the server's own tracking range, so higher values have no further effect.",
						min = 20,
						max = 100,
						step = 5,
						get = function() return sadb.nameplateRange end,
						set = function(info, value)
							sadb.nameplateRange = value
							SoundAlerter:ApplyNameplateRange()
						end,
						disabled = function() return not sadb.proximityEnabled or not sadb.overrideNameplateRange end,
						width = "full",
						order = 15,
					},
				},
			},

			notificationMethods = {
				type = 'group',
				inline = true,
				name = "2. Notification Methods",
				desc = "Choose how you want to be alerted to nearby enemies",
				set = setOption,
				get = getOption,
				order = 3,
				args = {
					audioHeader = {
						type = 'header',
						name = "Audio Alerts",
						order = 2,
					},
					audioNote = {
						type = 'description',
						name = "|cff00FF00Enabled by default.|r Voice alerts are configured in the main Voice Alerts tab.\n",
						fontSize = "medium",
						order = 3,
					},
					chatHeader = {
						type = 'header',
						name = "Chat Alerts",
						order = 4,
					},
					proximityChat = {
						type = 'toggle',
						name = "Send Chat Messages",
						desc = "Announce proximity detections in chat (useful for alerting teammates)",
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 5,
					},
					proximityChatText = {
						type = 'input',
						name = "Chat Message Template",
						desc = "Customize the chat message. Available placeholders:\n#class# - Enemy class name\n#player# - Enemy player name\n\nExample: [#class#] #player# detected nearby!",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityChat end,
						width = 'full',
						order = 6,
					},
					toastHeader = {
						type = 'header',
						name = "Visual Toast Notifications",
						order = 7,
					},
					toastEnabled = {
						type = 'toggle',
						name = "Enable Toast Notifications",
						desc = "Show visual pop-up toasts when enemies are detected nearby. Additional customization options appear below when enabled.",
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 9,
						set = function(info, value)
							SoundAlerter.ProximityToasts:SetSetting("enabled", value)
							if not value and SoundAlerter.ProximityToasts then
								SoundAlerter.ProximityToasts:OnDisable()
							end
						end,
						get = function(info)
							return SoundAlerter.ProximityToasts:GetSettings().enabled
						end,
					},
					displayDuration = {
						type = 'range',
						name = "Display Duration (seconds)",
						desc = "How long the toast remains visible on screen",
						min = 2,
						max = 8,
						step = 0.5,
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 10,
						set = function(info, value)
							SoundAlerter.ProximityToasts:SetSetting("displayDuration", value)
						end,
						get = function(info)
							return SoundAlerter.ProximityToasts:GetSettings().displayDuration
						end,
					},
					maxConcurrent = {
						type = 'range',
						name = "Max Concurrent Toasts",
						desc = "Maximum number of toasts to show at once (older toasts fade out early if limit is exceeded)",
						min = 1,
						max = 5,
						step = 1,
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 11,
						set = function(info, value)
							SoundAlerter.ProximityToasts:SetSetting("maxConcurrent", value)
						end,
						get = function(info)
							return SoundAlerter.ProximityToasts:GetSettings().maxConcurrent
						end,
					},
				},
			},

			toastAppearance = {
				type = 'group',
				inline = true,
				name = "3. Visual Alerts",
				desc = "Customize the visual style of toast notifications",
				set = setOption,
				get = getOption,
				order = 4,
				args = {
					showPlayerName = {
						type = 'toggle',
						name = "Show Player Name",
						desc = "Display enemy player name in toast",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 2,
						set = function(info, value)
							SoundAlerter.ProximityToasts:SetSetting("showPlayerName", value)
						end,
						get = function(info)
							return SoundAlerter.ProximityToasts:GetSettings().showPlayerName
						end,
					},
					showAuraIcons = {
						type = 'toggle',
						name = "Show Buff/Debuff Icons",
						desc = "Display up to 3 active buff or debuff icons on the toast (defensive cooldowns, mount, existing debuffs)",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 2.5,
						set = function(info, value)
							SoundAlerter.ProximityToasts:SetSetting("showAuraIcons", value)
						end,
						get = function(info)
							return SoundAlerter.ProximityToasts:GetSettings().showAuraIcons
						end,
					},
					useClassColors = {
						type = 'toggle',
						name = "Use Class Colors",
						desc = "Color toast background based on enemy class (e.g., red for Warrior, purple for Warlock)",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 3,
						set = function(info, value)
							SoundAlerter.ProximityToasts:SetSetting("useClassColors", value)
						end,
						get = function(info)
							return SoundAlerter.ProximityToasts:GetSettings().useClassColors
						end,
					},
					rainbowBorder = {
						type = 'toggle',
						name = "Rainbow Border Animation",
						desc = "Enable smooth, slow rainbow color transitions on toast borders. Creates a visually distinct effect.",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 4,
						set = function(info, value)
							SoundAlerter.ProximityToasts:SetSetting("rainbowBorder", value)
						end,
						get = function(info)
							return SoundAlerter.ProximityToasts:GetSettings().rainbowBorder
						end,
					},
				},
			},

			toastPosition = {
				type = 'group',
				inline = true,
				name = "4. Toast Position & Testing",
				desc = "Adjust where toasts appear on screen and preview your settings",
				set = setOption,
				get = getOption,
				order = 5,
				args = {
					positionX = {
						type = 'range',
						name = "Horizontal Position",
						desc = "Adjust horizontal position on screen (0 = center, negative = left, positive = right)",
						min = -500,
						max = 500,
						step = 10,
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "normal",
						order = 2,
						set = function(info, value)
							SoundAlerter.ProximityToasts:SetSetting("positionX", value)
							if SoundAlerter.ProximityToasts then
								SoundAlerter.ProximityToasts:UpdateLayout()
							end
						end,
						get = function(info)
							return SoundAlerter.ProximityToasts:GetSettings().positionX
						end,
					},
					positionY = {
						type = 'range',
						name = "Vertical Position",
						desc = "Adjust vertical position on screen (0 = center, negative = down from top, positive = up from bottom)",
						min = -500,
						max = 500,
						step = 10,
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "normal",
						order = 3,
						set = function(info, value)
							SoundAlerter.ProximityToasts:SetSetting("positionY", value)
							if SoundAlerter.ProximityToasts then
								SoundAlerter.ProximityToasts:UpdateLayout()
							end
						end,
						get = function(info)
							return SoundAlerter.ProximityToasts:GetSettings().positionY
						end,
					},
					spacer = {
						type = 'description',
						name = " ",
						order = 4,
					},
					testButton = {
						type = 'execute',
						name = "Test Toast Notification",
						desc = "Show a test toast notification to preview the current settings (position, appearance, duration)",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 5,
						func = function()
							if SoundAlerter.ProximityToasts then
								SoundAlerter.ProximityToasts:ShowToast("TestEnemy", "ROGUE", nil, nil)
							end
						end,
					},
				},
			},

			clickInteractions = {
				type = 'group',
				inline = true,
				name = "5. Advanced: Click Interactions",
				desc = "Power user feature: Click toast notifications to target enemies",
				set = setOption,
				get = getOption,
				hidden = function() return not sadb.showAdvancedProximity end,
				order = 6,
				args = {
					advancedWarning = {
						type = 'description',
						name = "|cffFF6600Advanced:|r Click-to-target only works in World PvP — not arenas or battlegrounds.\n",
						fontSize = "medium",
						order = 1,
					},
					clickEnabled = {
						type = 'toggle',
						name = "Enable Click Interaction",
						desc = "Allow clicking toast notifications to interact with enemies (world PvP only). Enable this to unlock click-to-target features.",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 2,
						set = function(info, value)
							SoundAlerter.ProximityToasts:SetSetting("clickEnabled", value)
						end,
						get = function(info)
							return SoundAlerter.ProximityToasts:GetSettings().clickEnabled
						end,
					},
					spacer1 = {
						type = 'description',
						name = " ",
						order = 3,
					},
					clickOptionsHeader = {
						type = 'header',
						name = "Click Actions",
						order = 4,
					},
					enableClickToTarget = {
						type = 'toggle',
						name = "Left-Click: Target Enemy",
						desc = "Normal left-click on toast: Automatically target the detected enemy player",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled or not sadb.proximityToasts.clickEnabled end,
						width = "full",
						order = 5,
						set = function(info, value)
							SoundAlerter.ProximityToasts:SetSetting("enableClickToTarget", value)
						end,
						get = function(info)
							return SoundAlerter.ProximityToasts:GetSettings().enableClickToTarget
						end,
					},
					enableFocusTarget = {
						type = 'toggle',
						name = "Shift+Click: Set Focus Target",
						desc = "Hold Shift and click on toast: Target enemy and set as focus target (useful for tracking stealthers)",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled or not sadb.proximityToasts.clickEnabled end,
						width = "full",
						order = 6,
						set = function(info, value)
							SoundAlerter.ProximityToasts:SetSetting("enableFocusTarget", value)
						end,
						get = function(info)
							return SoundAlerter.ProximityToasts:GetSettings().enableFocusTarget
						end,
					},
				},
			},
		},
	}
end

function SoundAlerter:BuildFlagOptions()
	return {
		type = 'group',
		name = "Battleground Alerts",
		icon = "Interface\\Icons\\INV_BannerPVP_02",
		desc = "Track battlefield objectives: flag pickups, captures, base assaults, and more.",
		order = 2.7,
		args = {
			description = {
				type = 'description',
				name = "|cffFFD700Battleground Alerts|r track objective events.\n\n" ..
				       "|cffFFFFFFSupported:|r Warsong Gulch, Twin Peaks (incl. Blitz) — flag pickup, drop and capture. Eye of the Storm: pickup and drop only. Arathi Basin, Alterac Valley: |cffAAAAAAComing Soon|r.\n\n" ..
				       "|cffFF0000Note:|r Battlegrounds only.\n",
				fontSize = "medium",
				order = 1,
			},
			showAdvancedFlag = {
				type = 'toggle',
				name = "Show Advanced Options",
				desc = "Reveal power-user settings (performance metrics and debugging tools) at the bottom of this tab.",
				set = function(info, value) sadb.showAdvancedFlag = value end,
				get = function(info) return sadb.showAdvancedFlag end,
				width = "full",
				order = 1.5,
			},

			enableGroup = {
				type = 'group',
				inline = true,
				name = "1. Basic Setup",
				order = 2,
				args = {
					battlegroundAlertsEnabled = {
						type = 'toggle',
						name = "Enable Battleground Alerts",
						desc = "Master toggle for all battlefield objective alerts. Enable this first to activate all battleground features.",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().battlegroundAlertsEnabled end,
						set = function(_, val)
							SoundAlerter.FlagAlerts:SetSetting("battlegroundAlertsEnabled", val)
							if SoundAlerter.UpdateMinimapButtonIcon then
								SoundAlerter:UpdateMinimapButtonIcon()
							end
						end,
						width = "full",
						order = 1,
					},
				},
			},

			flagAlerts = {
				type = 'group',
				inline = true,
				name = "2. Flag Events (WSG, EOTS)",
				desc = "Audio alerts for flag pickups, drops, and captures",
				order = 3,
				args = {
					flagPickupAudio = {
						type = 'toggle',
						name = "Flag Pickups",
						desc = "Alert when a player picks up a flag (e.g., 'Rogue picked up flag')",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagPickupAudio end,
						set = function(_, val) SoundAlerter.FlagAlerts:SetSetting("flagPickupAudio", val) end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 1,
					},
					flagDropAudio = {
						type = 'toggle',
						name = "Flag Drops",
						desc = "Alert when a flag is dropped",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagDropAudio end,
						set = function(_, val) SoundAlerter.FlagAlerts:SetSetting("flagDropAudio", val) end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 2,
					},
					flagCaptureAudio = {
						type = 'toggle',
						name = "Flag Captures",
						desc = "Alert when a flag is captured",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagCaptureAudio end,
						set = function(_, val) SoundAlerter.FlagAlerts:SetSetting("flagCaptureAudio", val) end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 3,
					},
					flagReturnAudio = {
						type = 'toggle',
						name = "Flag Returns",
						desc = "Alert when a flag is returned to base",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagReturnAudio end,
						set = function(_, val) SoundAlerter.FlagAlerts:SetSetting("flagReturnAudio", val) end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 4,
					},
				},
			},

			toastIntegration = {
				type = 'group',
				inline = true,
				name = "3. Visual Alerts",
				desc = "Show toast notifications for flag events",
				order = 4,
				args = {
					flagToastsEnabled = {
						type = 'toggle',
						name = "Show Toast Notifications",
						desc = "Display visual toasts for flag carriers (uses proximity toast settings for appearance)",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagToastsEnabled end,
						set = function(_, val) SoundAlerter.FlagAlerts:SetSetting("flagToastsEnabled", val) end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 1,
					},
					rainbowBorder = {
						type = 'toggle',
						name = "Rainbow Border on Toasts",
						desc = "Animated rainbow-colored border effect on toast notifications (shared with Proximity Alerts)",
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 2,
						set = function(info, value)
							SoundAlerter.ProximityToasts:SetSetting("rainbowBorder", value)
						end,
						get = function(info)
							return SoundAlerter.ProximityToasts:GetSettings().rainbowBorder
						end,
					},
					spacer1 = {
						type = 'description',
						name = " ",
						order = 3,
					},
					flagTeamBackgroundColors = {
						type = 'toggle',
						name = "Team-based Background Colors",
						desc = "Enable color-coded backgrounds for flag alerts:\n" ..
						       "|cffFF5555• Red transparent background|r = Enemy team flag carrier\n" ..
						       "|cff55FF55• Green transparent background|r = Friendly team flag carrier\n\n" ..
						       "This helps you quickly identify which team picked up the flag without reading the toast.",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagTeamBackgroundColors end,
						set = function(_, val) SoundAlerter.FlagAlerts:SetSetting("flagTeamBackgroundColors", val) end,
						disabled = function() return not sadb.battlegroundAlertsEnabled or not sadb.flagToastsEnabled end,
						width = "full",
						order = 4,
					},
					flagEnemyRedBackground = {
						type = 'toggle',
						name = "  Enemy Team: Red Background",
						desc = "Show a red transparent background when an enemy team member picks up the flag. " ..
						       "This provides instant visual recognition of threats.",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagEnemyRedBackground end,
						set = function(_, val) SoundAlerter.FlagAlerts:SetSetting("flagEnemyRedBackground", val) end,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled or
							       not sadb.flagTeamBackgroundColors
						end,
						width = "full",
						order = 5,
					},
					flagFriendlyGreenBackground = {
						type = 'toggle',
						name = "  Friendly Team: Green Background",
						desc = "Show a green transparent background when a friendly team member picks up the flag. " ..
						       "Useful for tracking your team's flag carrier.",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagFriendlyGreenBackground end,
						set = function(_, val) SoundAlerter.FlagAlerts:SetSetting("flagFriendlyGreenBackground", val) end,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled or
							       not sadb.flagTeamBackgroundColors
						end,
						width = "full",
						order = 6,
					},
					flagEnemyTexture = {
						type = 'select',
						name = "  Enemy Team: Background Texture",
						desc = "Select the background texture pattern for enemy flag carrier toasts.\n\n" ..
						       "• |cffFFFFFFSolid|r - Clean, simple background (default)\n" ..
						       "• |cffFFFFFFDialog Box|r - Standard dialog texture\n\n" ..
						       "Texture is combined with the red color to help distinguish enemy flag carriers.",
						values = {
							["Solid"] = "Solid (Default)",
							["DialogBox"] = "Dialog Box",
						},
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagEnemyTexture or "Solid" end,
						set = function(_, val) SoundAlerter.FlagAlerts:SetSetting("flagEnemyTexture", val) end,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled or
							       not sadb.flagTeamBackgroundColors
						end,
						width = "full",
						order = 6.5,
					},
					flagFriendlyTexture = {
						type = 'select',
						name = "  Friendly Team: Background Texture",
						desc = "Select the background texture pattern for friendly flag carrier toasts.\n\n" ..
						       "• |cffFFFFFFSolid|r - Clean, simple background (default)\n" ..
						       "• |cffFFFFFFDialog Box|r - Standard dialog texture\n\n" ..
						       "Texture is combined with the green color to help identify friendly flag carriers.",
						values = {
							["Solid"] = "Solid (Default)",
							["DialogBox"] = "Dialog Box",
						},
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagFriendlyTexture or "Solid" end,
						set = function(_, val) SoundAlerter.FlagAlerts:SetSetting("flagFriendlyTexture", val) end,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled or
							       not sadb.flagTeamBackgroundColors
						end,
						width = "full",
						order = 6.6,
					},
					testTexturesButton = {
						type = 'execute',
						name = "Test Flag Alert Toasts",
						desc = "Shows test toasts with your selected textures and colors:\n" ..
						       "• Red enemy flag carrier toast (with your enemy texture)\n" ..
						       "• Green friendly flag carrier toast (with your friendly texture)\n\n" ..
						       "Test toasts appear at the EXACT position where real alerts will show.\n" ..
						       "Use the position sliders below to adjust placement.",
						func = function()
							if SoundAlerter.FlagAlerts then

								SoundAlerter.FlagAlerts:ShowFlagToast(
									"TestEnemy",
									"ROGUE",
									"PICKUP",
									"HORDE_TEAM"
								)

								SoundAlerter:ScheduleTimer(function()
									SoundAlerter.FlagAlerts:ShowFlagToast(
										"TestFriendly",
										"PALADIN",
										"PICKUP",
										"ALLIANCE_TEAM"
									)
								end, 1.2)

								DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00SoundAlerter:|r Test flag toasts displayed at actual alert position!")
							else
								DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000SoundAlerter:|r FlagAlerts module not loaded. Try /reload|r")
							end
						end,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled
						end,
						width = "full",
						order = 6.7,
					},
					spacer2 = {
						type = 'description',
						name = "\n|cffFFD700Toast Position:|r",
						fontSize = "medium",
						order = 6.8,
					},
					flagPositionX = {
						type = 'range',
						name = "Horizontal Position (X)",
						desc = "Adjust horizontal position of flag alert toasts.\n" ..
						       "0 = Center of screen\n" ..
						       "Negative = Left of center\n" ..
						       "Positive = Right of center",
						min = -600,
						max = 600,
						step = 10,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled
						end,
						width = "normal",
						order = 6.9,
						set = function(info, value)
							SoundAlerter.FlagAlerts:SetSetting("flagToasts.positionX", value)
							if SoundAlerter.FlagAlerts then
								SoundAlerter.FlagAlerts:UpdateFlagToastLayout()
							end
						end,
						get = function(info)
							local settings = SoundAlerter.FlagAlerts:GetSettings()
							return settings.flagToasts and settings.flagToasts.positionX or 0
						end,
					},
					flagPositionY = {
						type = 'range',
						name = "Vertical Position (Y)",
						desc = "Adjust vertical position of flag alert toasts.\n" ..
						       "0 = Top of screen\n" ..
						       "Negative = Lower on screen (recommended: -200 to -400)\n" ..
						       "Default: -300 (below proximity alerts)",
						min = -800,
						max = 200,
						step = 10,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled
						end,
						width = "normal",
						order = 6.95,
						set = function(info, value)
							SoundAlerter.FlagAlerts:SetSetting("flagToasts.positionY", value)
							if SoundAlerter.FlagAlerts then
								SoundAlerter.FlagAlerts:UpdateFlagToastLayout()
							end
						end,
						get = function(info)
							local settings = SoundAlerter.FlagAlerts:GetSettings()
							return settings.flagToasts and settings.flagToasts.positionY or -300
						end,
					},
					toastNote = {
						type = 'description',
						name = "\n|cffAAAAAANote: Flag alert toasts have their own position separate from Proximity Alerts.|r\n",
						fontSize = "small",
						order = 7,
					},
				},
			},

			filteringOptions = {
				type = 'group',
				inline = true,
				name = "4. Filtering Options",
				order = 5,
				args = {
					flagOnlyEnemyTeam = {
						type = 'toggle',
						name = "Only Enemy Team Events",
						desc = "Only alert for enemy flag pickups/captures (recommended for less spam). Automatically disabled when 'Alert All Flag Actions' is enabled.",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagOnlyEnemyTeam end,
						set = function(_, val)
							SoundAlerter.FlagAlerts:SetSetting("flagOnlyEnemyTeam", val)

							if val then
								SoundAlerter.FlagAlerts:SetSetting("flagOnlyFriendlyTeam", false)
							end
						end,
						disabled = function() return not sadb.battlegroundAlertsEnabled or sadb.flagAllActions end,
						width = "full",
						order = 1,
					},
					flagOnlyFriendlyTeam = {
						type = 'toggle',
						name = "Only Friendly Team Events",
						desc = "Only alert for friendly flag pickups/captures. Automatically disabled when 'Alert All Flag Actions' is enabled.",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagOnlyFriendlyTeam end,
						set = function(_, val)
							SoundAlerter.FlagAlerts:SetSetting("flagOnlyFriendlyTeam", val)

							if val then
								SoundAlerter.FlagAlerts:SetSetting("flagOnlyEnemyTeam", false)
							end
						end,
						disabled = function() return not sadb.battlegroundAlertsEnabled or sadb.flagAllActions end,
						width = "full",
						order = 2,
					},
					flagAllActions = {
						type = 'toggle',
						name = "Alert All Flag Actions",
						desc = "Alert for ALL flag events (pickup, drop, capture, return) for BOTH enemy and friendly teams. Enabling this will automatically disable team-specific filters above. May be spammy in active battlegrounds.",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagAllActions end,
						set = function(_, val)
							SoundAlerter.FlagAlerts:SetSetting("flagAllActions", val)

							if val then
								SoundAlerter.FlagAlerts:SetSetting("flagOnlyEnemyTeam", false)
								SoundAlerter.FlagAlerts:SetSetting("flagOnlyFriendlyTeam", false)
							end
						end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 3,
					},
				},
			},

			chatIntegration = {
				type = 'group',
				inline = true,
				name = "5. Chat Integration",
				order = 6,
				args = {
					flagChatEnabled = {
						type = 'toggle',
						name = "Send Chat Messages",
						desc = "Announce flag events in chat channels",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagChatEnabled end,
						set = function(_, val) SoundAlerter.FlagAlerts:SetSetting("flagChatEnabled", val) end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 1,
					},
					flagChatText = {
						type = 'input',
						name = "Chat Message Template",
						desc = "Customize the chat message. Available placeholders:\n" ..
						       "#class# - Enemy class name\n" ..
						       "#player# - Player name\n" ..
						       "#action# - Action (picked up flag, captured flag, etc.)\n\n" ..
						       "Example: [#class#] #player# #action#!",
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagChatText end,
						set = function(_, val) SoundAlerter.FlagAlerts:SetSetting("flagChatText", val) end,
						disabled = function() return not sadb.battlegroundAlertsEnabled or not sadb.flagChatEnabled end,
						width = 'full',
						order = 2,
					},
					flagChatChannel = {
						type = 'select',
						name = "Chat Channel",
						desc = "Which channel to send flag alerts to",
						values = {
							["SAY"] = "Say",
							["PARTY"] = "Party",
							["RAID"] = "Raid",
							["BATTLEGROUND"] = "Battleground",
						},
						get = function() return SoundAlerter.FlagAlerts:GetSettings().flagChatChannel end,
						set = function(_, val) SoundAlerter.FlagAlerts:SetSetting("flagChatChannel", val) end,
						disabled = function() return not sadb.battlegroundAlertsEnabled or not sadb.flagChatEnabled end,
						order = 3,
					},
				},
			},

			performanceSection = {
				type = 'group',
				inline = true,
				name = "6. Performance & Debugging",
				order = 7,
				hidden = function() return not sadb.showAdvancedFlag end,
				args = {
					metricsButton = {
						type = 'execute',
						name = "Show Performance Metrics",
						desc = "Display processing time, cache hit rate, and other performance data",
						func = function()
							if SoundAlerter.FlagAlerts then
								SoundAlerter.FlagAlerts:PrintMetrics()
							else
								SoundAlerter:Print("|cffFF0000Error: FlagAlerts module not loaded|r")
							end
						end,
						order = 1,
					},
					resetMetricsButton = {
						type = 'execute',
						name = "Reset Metrics",
						desc = "Clear performance tracking data",
						func = function()
							if SoundAlerter.FlagAlerts then
								SoundAlerter.FlagAlerts:ResetMetrics()
							else
								SoundAlerter:Print("|cffFF0000Error: FlagAlerts module not loaded|r")
							end
						end,
						order = 2,
					},
				},
			},

		},
	}
end

function SoundAlerter:BuildResourceBarOptions()
	return {
		type = 'group',
		name = "Resource Management",
		icon = "Interface\\Icons\\Spell_Nature_Regeneration",
		desc = "Unified resource tracking for Energy, Rage, Health, and Mana bars with Combo Points. Enable the bars you need and drag them into position.",
		order = 2.8,
		args = {
			description = {
				type = 'description',
				name = "|cffFFD700Resource Management|r\n\n" ..
				       "|cffFF0000Note:|r Unlock bars to drag them into position. Positions persist through /reload and client restarts.\n",
				fontSize = "medium",
				order = 1,
			},

			initErrorWarning = {
				type = 'description',
				name = function()
					return "|cffFF0000Resource Management failed to initialize this session:|r\n" ..
					       tostring(SoundAlerter.moduleInitErrors and SoundAlerter.moduleInitErrors.ResourceBar) ..
					       "\n\n|cffFFFFFFToggles below will not take effect until this is fixed and you /reload.|r\n"
				end,
				fontSize = "medium",
				order = 1.5,
				hidden = function() return SoundAlerter.ResourceBar ~= nil end,
			},

			generalGroup = {
				type = 'group',
				inline = true,
				name = "General Settings",
				order = 2,
				args = {
					lockToggle = {
						type = 'toggle',
						name = "Lock Bars",
						desc = "Lock all resource bars in place. Unlock to drag and reposition.",
						get = function() return SoundAlerter.ResourceBar:GetSettings().locked end,
						set = function(info, value)
							SoundAlerter.ResourceBar:SetSetting("locked", value)
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:SetLocked(value)
							end
						end,
						width = "full",
						order = 1,
					},
				barTexture = {
					type = 'select',
					name = "Bar Texture",
					desc = "Choose the visual texture for all resource bars (Health, Mana, Energy, Rage). This provides a unified look across all bars.",
					values = SoundAlerter.BarTexture:Values(),
					get = function() return SoundAlerter.ResourceBar:GetSettings().barTexture end,
					set = function(info, value)
						SoundAlerter.ResourceBar:SetSetting("barTexture", value)
						if SoundAlerter.ResourceBar then
							SoundAlerter.ResourceBar:ApplyBarTexture()
						end
					end,
					width = "full",
					order = 2,
				},
				},
			},

			energyGroup = {
				type = 'group',
				inline = true,
				name = "Energy Bar",
				order = 3,
				args = {
					energyEnabled = {
						type = 'toggle',
						name = "Show Energy Bar",
						desc = "Display energy bar (for Rogues, Druids in Cat Form).",
						get = function() return SoundAlerter.ResourceBar:GetSettings().energyEnabled end,
						set = function(info, value)
							SoundAlerter.ResourceBar:SetSetting("energyEnabled", value)
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateVisibility()
							end
						end,
						width = "full",
						order = 1,
					},
					energyScale = {
						type = 'range',
						name = "Energy Bar Scale",
						desc = "Adjust the size of the energy bar.",
						min = 0.5,
						max = 2.0,
						step = 0.05,
						get = function() return SoundAlerter.ResourceBar:GetSettings().energyScale end,
						set = function(info, value)
							SoundAlerter.ResourceBar:SetSetting("energyScale", value)
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.energyFrame then
								SoundAlerter.ResourceBar.energyFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.ResourceBar:GetSettings().energyEnabled end,
						width = "full",
						order = 2,
					},
					energyColor = {
						type = 'color',
						name = "Energy Color",
						desc = "Color of the energy bar.",
						get = function()
							local c = SoundAlerter.ResourceBar:GetSettings().energyColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.ResourceBar:SetSetting("energyColor", {r = r, g = g, b = b})
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:CacheColors()
								SoundAlerter.ResourceBar:UpdateEnergyBar()
							end
						end,
						disabled = function() return not SoundAlerter.ResourceBar:GetSettings().energyEnabled end,
						order = 3,
					},
				},
			},

			rageGroup = {
				type = 'group',
				inline = true,
				name = "Rage Bar",
				order = 4,
				args = {
					rageEnabled = {
						type = 'toggle',
						name = "Show Rage Bar",
						desc = "Display rage bar (for Warriors, Druids in Bear Form).",
						get = function() return SoundAlerter.ResourceBar:GetSettings().rageEnabled end,
						set = function(info, value)
							SoundAlerter.ResourceBar:SetSetting("rageEnabled", value)
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateVisibility()
							end
						end,
						width = "full",
						order = 1,
					},
					rageScale = {
						type = 'range',
						name = "Rage Bar Scale",
						desc = "Adjust the size of the rage bar.",
						min = 0.5,
						max = 2.0,
						step = 0.05,
						get = function() return SoundAlerter.ResourceBar:GetSettings().rageScale end,
						set = function(info, value)
							SoundAlerter.ResourceBar:SetSetting("rageScale", value)
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.rageFrame then
								SoundAlerter.ResourceBar.rageFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.ResourceBar:GetSettings().rageEnabled end,
						width = "full",
						order = 2,
					},
					rageColor = {
						type = 'color',
						name = "Rage Color",
						desc = "Color of the rage bar.",
						get = function()
							local c = SoundAlerter.ResourceBar:GetSettings().rageColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.ResourceBar:SetSetting("rageColor", {r = r, g = g, b = b})
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:CacheColors()
								SoundAlerter.ResourceBar:UpdateRageBar()
							end
						end,
						disabled = function() return not SoundAlerter.ResourceBar:GetSettings().rageEnabled end,
						order = 3,
					},
				},
			},

			healthGroup = {
				type = 'group',
				inline = true,
				name = "Health Bar",
				order = 5,
				args = {
					healthEnabled = {
						type = 'toggle',
						name = "Show Health Bar",
						desc = "Display health bar.",
						get = function() return SoundAlerter.ResourceBar:GetSettings().healthEnabled end,
						set = function(info, value)
							SoundAlerter.ResourceBar:SetSetting("healthEnabled", value)
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateVisibility()
							end
						end,
						width = "full",
						order = 1,
					},
					healthScale = {
						type = 'range',
						name = "Health Bar Scale",
						desc = "Adjust the size of the health bar.",
						min = 0.5,
						max = 2.0,
						step = 0.05,
						get = function() return SoundAlerter.ResourceBar:GetSettings().healthScale end,
						set = function(info, value)
							SoundAlerter.ResourceBar:SetSetting("healthScale", value)
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.healthFrame then
								SoundAlerter.ResourceBar.healthFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.ResourceBar:GetSettings().healthEnabled end,
						width = "full",
						order = 2,
					},
					healthHeight = {
						type = 'range',
						name = "Health Bar Height",
						desc = "Adjust the height of the health bar.",
						min = 10,
						max = 40,
						step = 1,
						get = function() return SoundAlerter.ResourceBar:GetSettings().healthHeight end,
						set = function(info, value)
							SoundAlerter.ResourceBar:SetSetting("healthHeight", value)
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.ResourceBar:GetSettings().healthEnabled end,
						width = "full",
						order = 3,
					},
					healthColor = {
						type = 'color',
						name = "Health Color",
						desc = "Color of the health bar.",
						get = function()
							local c = SoundAlerter.ResourceBar:GetSettings().healthColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.ResourceBar:SetSetting("healthColor", {r = r, g = g, b = b})
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:CacheColors()
								SoundAlerter.ResourceBar:UpdateHealthBar()
							end
						end,
						disabled = function() return not SoundAlerter.ResourceBar:GetSettings().healthEnabled end,
						order = 4,
					},
				},
			},

			manaGroup = {
				type = 'group',
				inline = true,
				name = "Mana Bar",
				order = 6,
				args = {
					manaEnabled = {
						type = 'toggle',
						name = "Show Mana Bar",
						desc = "Display mana bar (for casters).",
						get = function() return SoundAlerter.ResourceBar:GetSettings().manaEnabled end,
						set = function(info, value)
							SoundAlerter.ResourceBar:SetSetting("manaEnabled", value)
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateVisibility()
							end
						end,
						width = "full",
						order = 1,
					},
					manaScale = {
						type = 'range',
						name = "Mana Bar Scale",
						desc = "Adjust the size of the mana bar.",
						min = 0.5,
						max = 2.0,
						step = 0.05,
						get = function() return SoundAlerter.ResourceBar:GetSettings().manaScale end,
						set = function(info, value)
							SoundAlerter.ResourceBar:SetSetting("manaScale", value)
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.manaFrame then
								SoundAlerter.ResourceBar.manaFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.ResourceBar:GetSettings().manaEnabled end,
						width = "full",
						order = 2,
					},
					manaColor = {
						type = 'color',
						name = "Mana Color",
						desc = "Color of the mana bar.",
						get = function()
							local c = SoundAlerter.ResourceBar:GetSettings().manaColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.ResourceBar:SetSetting("manaColor", {r = r, g = g, b = b})
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:CacheColors()
								SoundAlerter.ResourceBar:UpdateManaBar()
							end
						end,
						disabled = function() return not SoundAlerter.ResourceBar:GetSettings().manaEnabled end,
						order = 3,
					},
				},
			},

			comboGroup = {
				type = 'group',
				inline = true,
				name = "Combo Points",
				order = 7,
				args = {
					comboEnabled = {
						type = 'toggle',
						name = "Show Combo Points",
						desc = "Display combo points (for Rogues, Druids in Cat Form).",
						get = function() return SoundAlerter.ResourceBar:GetSettings().comboEnabled end,
						set = function(info, value)
							SoundAlerter.ResourceBar:SetSetting("comboEnabled", value)
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateVisibility()
							end
						end,
						width = "full",
						order = 1,
					},
					comboScale = {
						type = 'range',
						name = "Combo Points Scale",
						desc = "Adjust the size of the combo points.",
						min = 0.5,
						max = 2.0,
						step = 0.05,
						get = function() return SoundAlerter.ResourceBar:GetSettings().comboScale end,
						set = function(info, value)
							SoundAlerter.ResourceBar:SetSetting("comboScale", value)
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.comboFrame then
								SoundAlerter.ResourceBar.comboFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.ResourceBar:GetSettings().comboEnabled end,
						width = "full",
						order = 2,
					},
				comboStyle = {
					type = 'select',
					name = "Combo Point Shape",
					desc = "Choose the visual shape for combo points.",
					values = {
						circle = "Circle",
						square = "Square",
					},
					get = function() return SoundAlerter.ResourceBar:GetSettings().comboStyle end,
					set = function(info, value)
						SoundAlerter.ResourceBar:SetSetting("comboStyle", value)
						if SoundAlerter.ResourceBar then
							SoundAlerter.ResourceBar:ApplyCPStyle()
						end
					end,
					disabled = function() return not SoundAlerter.ResourceBar:GetSettings().comboEnabled end,
					width = "full",
					order = 2.5,
				},
					comboTextEnabled = {
						type = 'toggle',
						name = "Show Combo Text",
						desc = "Display combo points as text (e.g., '3/5').",
						get = function() return SoundAlerter.ResourceBar:GetSettings().comboTextEnabled end,
						set = function(info, value)
							SoundAlerter.ResourceBar:SetSetting("comboTextEnabled", value)
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateVisibility()
							end
						end,
						disabled = function() return not SoundAlerter.ResourceBar:GetSettings().comboEnabled end,
						width = "full",
						order = 3,
					},
					comboActiveColor = {
						type = 'color',
						name = "Active Combo Color",
						desc = "Color of active combo points (1-4).",
						get = function()
							local c = SoundAlerter.ResourceBar:GetSettings().comboActiveColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.ResourceBar:SetSetting("comboActiveColor", {r = r, g = g, b = b})
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:CacheColors()
								SoundAlerter.ResourceBar:RefreshComboColors()
							end
						end,
						disabled = function() return not SoundAlerter.ResourceBar:GetSettings().comboEnabled end,
						order = 4,
					},
					comboMaxColor = {
						type = 'color',
						name = "Max Combo Color",
						desc = "Color of combo points at maximum (5).",
						get = function()
							local c = SoundAlerter.ResourceBar:GetSettings().comboMaxColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.ResourceBar:SetSetting("comboMaxColor", {r = r, g = g, b = b})
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:CacheColors()
								SoundAlerter.ResourceBar:RefreshComboColors()
							end
						end,
						disabled = function() return not SoundAlerter.ResourceBar:GetSettings().comboEnabled end,
						order = 5,
					},
				fullCPSound = {
					type = 'toggle',
					name = "5 CP Sound",
					desc = "Play a satisfying chime when reaching 5 combo points.",
					get = function() return SoundAlerter.ResourceBar:GetSettings().fullCPSound end,
					set = function(info, value)
						SoundAlerter.ResourceBar:SetSetting("fullCPSound", value)
					end,
					disabled = function() return not SoundAlerter.ResourceBar:GetSettings().comboEnabled end,
					width = "full",
					order = 6,
				},
				},
			},
		},
	}
end

function SoundAlerter:BuildCastingBarOptions()
	return {
		type = 'group',
		name = "Casting Bars",
		icon = "Interface\\Icons\\Spell_Arcane_Blast",
		desc = "Display casting and channeling progress for player, target, and focus with precise timing information.",
		order = 2.85,
		args = {
			description = {
				type = 'description',
				name = "|cffFFD700Casting Bars|r\n\n" ..
				       "|cffFF0000Note:|r Unlock bars to drag them into position. When locked, bars only appear during active casts. All bars are disabled by default.\n",
				fontSize = "medium",
				order = 1,
			},

			initErrorWarning = {
				type = 'description',
				name = function()
					return "|cffFF0000Casting Bars failed to initialize this session:|r\n" ..
					       tostring(SoundAlerter.moduleInitErrors and SoundAlerter.moduleInitErrors.CastingBars) ..
					       "\n\n|cffFFFFFFToggles below will not take effect until this is fixed and you /reload.|r\n"
				end,
				fontSize = "medium",
				order = 1.5,
				hidden = function() return SoundAlerter.CastingBars ~= nil end,
			},

			generalGroup = {
				type = 'group',
				inline = true,
				name = "General Settings",
				order = 2,
				args = {
					lockToggle = {
						type = 'toggle',
						name = "Lock Bars",
						desc = "Lock all casting bars in place. Unlock to drag and reposition.",
						get = function() return SoundAlerter.CastingBars:GetSettings().locked end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("locked", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:SetLocked(value)
							end
						end,
						width = "full",
						order = 1,
					},
					applyPyramidLayout = {
						type = 'execute',
						name = "Apply Pyramid Layout",
						desc = "Positions Player, Target, and Focus casting bars into a pyramid: Player centered on top, Target and Focus symmetrically below to the left and right. Bars remain draggable afterward.",
						func = function()
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:ApplyPyramidLayout()
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						width = "full",
						order = 1.5,
					},
					barTexture = {
						type = 'select',
						name = "Bar Texture",
						desc = "Choose the visual texture for all casting bars. Matches resource bar texture options for consistency.",
						values = SoundAlerter.BarTexture:Values(),
						get = function() return SoundAlerter.CastingBars:GetSettings().barTexture end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("barTexture", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:UpdateTexture()
							end
						end,
						width = "full",
						order = 2,
					},
					timeFormat = {
						type = 'select',
						name = "Time Format",
						desc = "Choose how cast time is displayed.\n\nSS.sss = Seconds with milliseconds (e.g., 02.450)\nSS.ss = Seconds with centiseconds (e.g., 02.45)",
						values = {
							milliseconds = "SS.sss (Milliseconds)",
							centiseconds = "SS.ss (Centiseconds)",
						},
						get = function() return SoundAlerter.CastingBars:GetSettings().timeFormat end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("timeFormat", value)
						end,
						width = "full",
						order = 3,
					},
					showSpellIcon = {
						type = 'toggle',
						name = "Show Spell Icons",
						desc = "Display spell icons to the left of casting bars.",
						get = function() return SoundAlerter.CastingBars:GetSettings().showSpellIcon end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("showSpellIcon", value)
						end,
						width = "full",
						order = 4,
					},
					showLatency = {
						type = 'toggle',
						name = "Show Latency Shadow",
						desc = "Display a red shadow at the end of the player casting bar representing network latency. Helps predict when the spell will actually cast on the server.",
						get = function() return SoundAlerter.CastingBars:GetSettings().showLatency end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("showLatency", value)
						end,
						width = "full",
						order = 5,
					},
				},
			},

			playerGroup = {
				type = 'group',
				inline = true,
				name = "Player Casting Bar",
				order = 3,
				args = {
					playerEnabled = {
						type = 'toggle',
						name = "Show Player Casting Bar",
						desc = "Display casting bar for your own spells. Shows casting time in mm:ss.SSS format.",
						get = function() return SoundAlerter.CastingBars:GetSettings().player.enabled end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("player.enabled", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						width = "full",
						order = 1,
					},
					playerWidth = {
						type = 'range',
						name = "Width",
						desc = "Width of the player casting bar.",
						min = 100,
						max = 500,
						step = 10,
						get = function() return SoundAlerter.CastingBars:GetSettings().player.width end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("player.width", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.CastingBars:GetSettings().player.enabled end,
						width = "full",
						order = 2,
					},
					playerHeight = {
						type = 'range',
						name = "Height",
						desc = "Height of the player casting bar.",
						min = 12,
						max = 50,
						step = 2,
						get = function() return SoundAlerter.CastingBars:GetSettings().player.height end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("player.height", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.CastingBars:GetSettings().player.enabled end,
						width = "full",
						order = 3,
					},
					playerOrientation = {
						type = 'select',
						name = "Bar Orientation",
						desc = "Horizontal or vertical fill for the player casting bar.",
						values = { horizontal = "Horizontal", vertical = "Vertical" },
						get = function() return SoundAlerter.CastingBars:GetSettings().player.orientation end,
						set = function(info, value)
							local unitDB = SoundAlerter.CastingBars:GetSettings().player
							SoundAlerter.CastingBars:SetSetting("player.orientation", value)
							if value == "vertical" and unitDB.fillDirection ~= "up" and unitDB.fillDirection ~= "down" then
								SoundAlerter.CastingBars:SetSetting("player.fillDirection", "up")
							elseif value == "horizontal" and unitDB.fillDirection ~= "left" and unitDB.fillDirection ~= "right" then
								SoundAlerter.CastingBars:SetSetting("player.fillDirection", "right")
							end
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.CastingBars:GetSettings().player.enabled end,
						width = "full",
						order = 4,
					},
					playerFillDirection = {
						type = 'select',
						name = "Fill Direction",
						desc = "Direction the bar fills as the cast progresses.",
						values = function()
							if SoundAlerter.CastingBars:GetSettings().player.orientation == "vertical" then
								return { up = "Up", down = "Down" }
							else
								return { right = "Right", left = "Left" }
							end
						end,
						get = function() return SoundAlerter.CastingBars:GetSettings().player.fillDirection end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("player.fillDirection", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.CastingBars:GetSettings().player.enabled end,
						width = "full",
						order = 5,
					},
				},
			},

			targetGroup = {
				type = 'group',
				inline = true,
				name = "Target Casting Bar",
				order = 4,
				args = {
					targetEnabled = {
						type = 'toggle',
						name = "Show Target Casting Bar",
						desc = "Display casting bar for your target's spells. Essential for PvP interrupt timing.",
						get = function() return SoundAlerter.CastingBars:GetSettings().target.enabled end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("target.enabled", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						width = "full",
						order = 1,
					},
					targetWidth = {
						type = 'range',
						name = "Width",
						desc = "Width of the target casting bar.",
						min = 100,
						max = 500,
						step = 10,
						get = function() return SoundAlerter.CastingBars:GetSettings().target.width end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("target.width", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.CastingBars:GetSettings().target.enabled end,
						width = "full",
						order = 2,
					},
					targetHeight = {
						type = 'range',
						name = "Height",
						desc = "Height of the target casting bar.",
						min = 12,
						max = 50,
						step = 2,
						get = function() return SoundAlerter.CastingBars:GetSettings().target.height end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("target.height", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.CastingBars:GetSettings().target.enabled end,
						width = "full",
						order = 3,
					},
					targetOrientation = {
						type = 'select',
						name = "Bar Orientation",
						desc = "Horizontal or vertical fill for the target casting bar.",
						values = { horizontal = "Horizontal", vertical = "Vertical" },
						get = function() return SoundAlerter.CastingBars:GetSettings().target.orientation end,
						set = function(info, value)
							local unitDB = SoundAlerter.CastingBars:GetSettings().target
							SoundAlerter.CastingBars:SetSetting("target.orientation", value)
							if value == "vertical" and unitDB.fillDirection ~= "up" and unitDB.fillDirection ~= "down" then
								SoundAlerter.CastingBars:SetSetting("target.fillDirection", "up")
							elseif value == "horizontal" and unitDB.fillDirection ~= "left" and unitDB.fillDirection ~= "right" then
								SoundAlerter.CastingBars:SetSetting("target.fillDirection", "right")
							end
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.CastingBars:GetSettings().target.enabled end,
						width = "full",
						order = 4,
					},
					targetFillDirection = {
						type = 'select',
						name = "Fill Direction",
						desc = "Direction the bar fills as the cast progresses.",
						values = function()
							if SoundAlerter.CastingBars:GetSettings().target.orientation == "vertical" then
								return { up = "Up", down = "Down" }
							else
								return { right = "Right", left = "Left" }
							end
						end,
						get = function() return SoundAlerter.CastingBars:GetSettings().target.fillDirection end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("target.fillDirection", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.CastingBars:GetSettings().target.enabled end,
						width = "full",
						order = 5,
					},
				},
			},

			focusGroup = {
				type = 'group',
				inline = true,
				name = "Focus Casting Bar",
				order = 5,
				args = {
					focusEnabled = {
						type = 'toggle',
						name = "Show Focus Casting Bar",
						desc = "Display casting bar for your focus target's spells. Perfect for arena focus target tracking.",
						get = function() return SoundAlerter.CastingBars:GetSettings().focus.enabled end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("focus.enabled", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						width = "full",
						order = 1,
					},
					focusWidth = {
						type = 'range',
						name = "Width",
						desc = "Width of the focus casting bar.",
						min = 100,
						max = 500,
						step = 10,
						get = function() return SoundAlerter.CastingBars:GetSettings().focus.width end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("focus.width", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.CastingBars:GetSettings().focus.enabled end,
						width = "full",
						order = 2,
					},
					focusHeight = {
						type = 'range',
						name = "Height",
						desc = "Height of the focus casting bar.",
						min = 12,
						max = 50,
						step = 2,
						get = function() return SoundAlerter.CastingBars:GetSettings().focus.height end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("focus.height", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.CastingBars:GetSettings().focus.enabled end,
						width = "full",
						order = 3,
					},
					focusOrientation = {
						type = 'select',
						name = "Bar Orientation",
						desc = "Horizontal or vertical fill for the focus casting bar.",
						values = { horizontal = "Horizontal", vertical = "Vertical" },
						get = function() return SoundAlerter.CastingBars:GetSettings().focus.orientation end,
						set = function(info, value)
							local unitDB = SoundAlerter.CastingBars:GetSettings().focus
							SoundAlerter.CastingBars:SetSetting("focus.orientation", value)
							if value == "vertical" and unitDB.fillDirection ~= "up" and unitDB.fillDirection ~= "down" then
								SoundAlerter.CastingBars:SetSetting("focus.fillDirection", "up")
							elseif value == "horizontal" and unitDB.fillDirection ~= "left" and unitDB.fillDirection ~= "right" then
								SoundAlerter.CastingBars:SetSetting("focus.fillDirection", "right")
							end
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.CastingBars:GetSettings().focus.enabled end,
						width = "full",
						order = 4,
					},
					focusFillDirection = {
						type = 'select',
						name = "Fill Direction",
						desc = "Direction the bar fills as the cast progresses.",
						values = function()
							if SoundAlerter.CastingBars:GetSettings().focus.orientation == "vertical" then
								return { up = "Up", down = "Down" }
							else
								return { right = "Right", left = "Left" }
							end
						end,
						get = function() return SoundAlerter.CastingBars:GetSettings().focus.fillDirection end,
						set = function(info, value)
							SoundAlerter.CastingBars:SetSetting("focus.fillDirection", value)
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.CastingBars:GetSettings().focus.enabled end,
						width = "full",
						order = 5,
					},
				},
			},
		},
	}
end

function SoundAlerter:BuildCastFeedOptions()
	local function Feed()
		return SoundAlerter.CastFeed
	end

	local function Apply(key, value)
		local feed = Feed()
		if not feed then return end
		feed:SetSetting(key, value)
		feed:LoadSettings()
	end

	local function Disabled()
		local feed = Feed()
		return not feed or not feed:GetSettings().enabled
	end

	local function Range(order, name, desc, key, min, max, step)
		return {
			type = 'range',
			name = name,
			desc = desc,
			min = min,
			max = max,
			step = step,
			get = function() return Feed():GetSettings()[key] end,
			set = function(info, value) Apply(key, value) end,
			disabled = Disabled,
			order = order,
		}
	end

	local rowUnits = { "player", "target", "focus", "party1", "party2", "party3", "party4" }
	local rowLabels = {
		player = "Player",
		target = "Target",
		focus = "Focus",
		party1 = "Party 1",
		party2 = "Party 2",
		party3 = "Party 3",
		party4 = "Party 4",
	}

	local selectedRow = "player"

	local function SelectedRow()
		return Feed():GetSettings().rows[selectedRow]
	end

	local function RowDisabled()
		return Disabled() or not SelectedRow().enabled
	end

	local function ApplyRow(field, value)
		local feed = Feed()
		if not feed then return end
		feed:SetSetting(selectedRow .. "." .. field, value)
		feed:LoadSettings()
	end

	local function CopyToAll()
		local feed = Feed()
		if not feed then return end
		local source = SelectedRow()
		for _, unit in ipairs(rowUnits) do
			feed:SetSetting(unit .. ".direction", source.direction)
			feed:SetSetting(unit .. ".scale", source.scale)
		end
		feed:LoadSettings()
	end

	return {
		type = 'group',
		name = "Cast Feed",
		icon = "Interface\\Icons\\Spell_Nature_Lightning",
		desc = "Icons of player, target, focus and party casts moving across the screen, one row per unit.",
		order = 2.86,
		args = {
			description = {
				type = 'description',
				name = "|cffFFD700Cast Feed|r\n\n" ..
				       "Every cast by you, your target, focus and party members becomes an icon that moves along that unit's own row. " ..
				       "Hover any icon to freeze its row and see the spell; leaving it speeds the row up until it is current again. " ..
				       "Unlock to drag the rows into position. Disabled by default.\n",
				fontSize = "medium",
				order = 1,
			},

			initErrorWarning = {
				type = 'description',
				name = function()
					return "|cffFF0000Cast Feed failed to initialize this session:|r\n" ..
					       tostring(SoundAlerter.moduleInitErrors and SoundAlerter.moduleInitErrors.CastFeed) ..
					       "\n\n|cffFFFFFFToggles below will not take effect until this is fixed and you /reload.|r\n"
				end,
				fontSize = "medium",
				order = 1.5,
				hidden = function() return SoundAlerter.CastFeed ~= nil end,
			},

			generalGroup = {
				type = 'group',
				inline = true,
				name = "General",
				order = 2,
				args = {
					enabled = {
						type = 'toggle',
						name = "Enable Cast Feed",
						get = function() return Feed():GetSettings().enabled end,
						set = function(info, value) Apply("enabled", value) end,
						width = "full",
						order = 1,
					},
					locked = {
						type = 'toggle',
						name = "Lock Position",
						desc = "Unlock to drag the rows. A shaded outline marks each row while unlocked.",
						get = function() return Feed():GetSettings().locked end,
						set = function(info, value) Apply("locked", value) end,
						disabled = Disabled,
						order = 2,
					},
					showInstants = {
						type = 'toggle',
						name = "Show Instant Casts",
						desc = "Include casts that have no cast time. The client hides other units' instant casts from addons, so these mostly appear only for units whose casts are readable.",
						get = function() return Feed():GetSettings().showInstants end,
						set = function(info, value) Apply("showInstants", value) end,
						disabled = Disabled,
						order = 4,
					},
					showGaps = {
						type = 'toggle',
						name = "Show Time Between Casts",
						desc = "Show the time between two casts (MM:SS:ms) between their icons. Icons spread out to make room.",
						get = function() return Feed():GetSettings().showGaps end,
						set = function(info, value) Apply("showGaps", value) end,
						disabled = Disabled,
						order = 4.5,
					},
					test = {
						type = 'execute',
						name = "Test",
						desc = "Spawn a few sample casts.",
						func = function()
							if Feed() then Feed():RunTest() end
						end,
						disabled = Disabled,
						order = 5,
					},
					resetPosition = {
						type = 'execute',
						name = "Reset Positions",
						func = function()
							if Feed() then Feed():ResetPositions() end
						end,
						disabled = Disabled,
						order = 6,
					},
				},
			},

			rowsGroup = {
				type = 'group',
				inline = true,
				name = "Rows",
				order = 3,
				args = {
					shown = {
						type = 'multiselect',
						name = "Show Rows",
						desc = "Each ticked unit gets its own row.",
						values = rowLabels,
						get = function(info, unit) return Feed():GetSettings().rows[unit].enabled end,
						set = function(info, unit, value) Apply(unit .. ".enabled", value) end,
						disabled = Disabled,
						width = "half",
						order = 1,
					},
					selected = {
						type = 'select',
						name = "Edit Row",
						desc = "Pick the row that Direction and Scale apply to.",
						values = rowLabels,
						sorting = rowUnits,
						get = function() return selectedRow end,
						set = function(info, value) selectedRow = value end,
						disabled = Disabled,
						order = 2,
					},
					direction = {
						type = 'select',
						name = "Direction",
						desc = "Direction the icons travel. New casts appear at the opposite edge.",
						values = {
							left = "Left",
							right = "Right",
							up = "Up",
							down = "Down",
						},
						sorting = { "left", "right", "up", "down" },
						get = function() return SelectedRow().direction end,
						set = function(info, value) ApplyRow("direction", value) end,
						disabled = RowDisabled,
						order = 3,
					},
					scale = {
						type = 'range',
						name = "Scale",
						desc = "Scales this row's icons, spacing and length together.",
						min = 0.5,
						max = 3,
						step = 0.05,
						get = function() return SelectedRow().scale end,
						set = function(info, value) ApplyRow("scale", value) end,
						disabled = RowDisabled,
						order = 4,
					},
					copyToAll = {
						type = 'execute',
						name = "Copy to All Rows",
						desc = "Give every row the selected row's direction and scale.",
						func = CopyToAll,
						disabled = RowDisabled,
						order = 5,
					},
				},
			},

			appearanceGroup = {
				type = 'group',
				inline = true,
				name = "Appearance (all rows)",
				order = 4,
				args = {
					iconSize = Range(1, "Icon Size", "Icon size before each row's scale.", "iconSize", 16, 64, 1),
					spacing = Range(2, "Spacing", "Minimum gap between icons.", "spacing", 0, 24, 1),
					length = Range(3, "Row Length", "Distance icons travel before they disappear.", "length", 100, 1000, 10),
					maxIcons = Range(4, "Max Icons", "Casts kept in each row; extra casts wait their turn.", "maxIcons", 3, 30, 1),
					speed = Range(5, "Speed", "Travel speed in pixels per second.", "speed", 20, 300, 5),
					catchUp = Range(6, "Catch-Up Speed", "How many times faster a row moves after you stop hovering, until it is current again.", "catchUp", 1.5, 10, 0.5),
						gapFontSize = Range(7, "Time Text Size", "Font size of the time between casts.", "gapFontSize", 8, 20, 1),
				},
			},
		},
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
			chatalerter = {
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
			},
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
	self:AddOption("profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db1))
	self.options.args.profiles.order = -1

	self:AddOption('QuickStart', self:BuildQuickStartOptions())

	self:AddOption('General', self:BuildGeneralOptions())

	self:AddOption('ProximityAlerts', self:BuildProximityOptions())

	self:AddOption('BattlegroundAlerts', self:BuildFlagOptions())

	self:AddOption('ResourceBar', self:BuildResourceBarOptions())

	self:AddOption('CastingBars', self:BuildCastingBarOptions())

	self:AddOption('CastFeed', self:BuildCastFeedOptions())

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
			set = function(info, value) local name = info[#info] sadb.custom[key][name] = value end,
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
					func = function() PlaySoundFile("Interface\\Addons\\SoundAlerter\\CustomSounds\\"..sadb.custom[key].soundfilepath) end,
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
					set = function(info, k, v) sadb.custom[key].eventtype[k] = v end,
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
end
