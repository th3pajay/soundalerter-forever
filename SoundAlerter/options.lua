local sadb
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SoundAlerter")
local self, SoundAlerter = SoundAlerter, SoundAlerter
local GetSpellInfo, GetSpellLink = SA_COMPAT.GetSpellInfo, SA_COMPAT.GetSpellLink

local voiceAlertSearchQueries = {
	spellauraApplied = "",
	spellAuraRemoved = "",
	spellCastStart = "",
	spellCastSuccess = "",
	enemydebuff = "",
	enemydebuffdown = ""
}

local spellTrackerAddForm = {
	spellID = "",
	unit = "player",
	auraType = "HELPFUL"
}

local spellTrackerSelectedIndex = nil

local function initOptions()
	if SoundAlerter.options.args.general then
		return
	end
	SoundAlerter:OnOptionsCreate()
	for k, v in SoundAlerter:IterateModules() do
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

local function createSearchBar(sectionKey)
	return {
		searchBarGroup = {
			type = 'group',
			inline = true,
			name = "|TInterface\\Icons\\INV_Misc_Spyglass_02:20|t  Search Spells",
			order = 1000,
			args = {
				searchInput = {
					type = 'input',
					name = "Search for spell names",
					desc = "Type to filter spells by name. Search is case-insensitive and shows only matching spells.",
					width = "full",
					order = 1,
					get = function()
						return voiceAlertSearchQueries[sectionKey] or ""
					end,
					set = function(info, value)
						voiceAlertSearchQueries[sectionKey] = value:lower()
						AceConfigDialog:Open("SoundAlerter")
					end,
				},
				clearButton = {
					type = 'execute',
					name = "Clear Search",
					desc = "Clear the search filter and show all spells",
					order = 2,
					width = "half",
					func = function()
						voiceAlertSearchQueries[sectionKey] = ""
						AceConfigDialog:Open("SoundAlerter")
					end,
					disabled = function()
						return not voiceAlertSearchQueries[sectionKey] or voiceAlertSearchQueries[sectionKey] == ""
					end,
				},
			},
		},
	}
end

local function shouldHideSpell(spellID, sectionKey)
	local query = voiceAlertSearchQueries[sectionKey]
	if not query or query == "" then
		return false
	end

	local spellName = GetSpellInfo(spellID)
	if not spellName then
		return true
	end

	return not string.find(spellName:lower(), query, 1, true)
end

local function listOption(spellList, listType, sectionKey, ...)
	local args = {}
	for k,v in pairs(spellList) do
		local key = SoundAlerter.spellList[listType] and SoundAlerter.spellList[listType][v]

		if key then
			local option = self:spellOptions(k, v)
			if option.type == 'toggle' and not option.desc then
				option.desc = function()
					if GetSpellLink(v) then
						GameTooltip:SetHyperlink(GetSpellLink(v));
					end
				end
				option.descStyle = "custom"
			end

			if sectionKey then
				option.hidden = function()
					return shouldHideSpell(v, sectionKey)
				end
			end

			rawset(args, key, option)
		else
			if sadb.debugmode then
				print("|cffFF7D0ASoundAlerter|r: Missing spell definition for ID:", v, "in list type:", listType)
			end
		end
	end
	return args
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

local function BuildStatBarRows(tableType, maxRows, baseOrder)
	local args = {}

	for i = 1, maxRows do
		args["barLabel" .. i] = {
			type = 'description',
			name = function()
				local Statistics = SoundAlerter:GetModule("Statistics")
				return Statistics:GetBarRowLabel(tableType, i)
			end,
			fontSize = "medium",
			order = baseOrder + (i * 2) - 1,
			hidden = function()
				local Statistics = SoundAlerter:GetModule("Statistics")
				return i > Statistics:GetBarRowCount(tableType)
			end,
		}
		args["bar" .. i] = {
			type = 'range',
			name = "",
			desc = "",
			min = 0,
			max = 100,
			step = 1,
			isPercent = true,
			width = "full",
			disabled = true,
			order = baseOrder + (i * 2),
			get = function()
				local Statistics = SoundAlerter:GetModule("Statistics")
				return Statistics:GetBarRowPercent(tableType, i)
			end,
			set = function() end,
			hidden = function()
				local Statistics = SoundAlerter:GetModule("Statistics")
				return i > Statistics:GetBarRowCount(tableType)
			end,
		}
	end

	args["emptyMessage"] = {
		type = 'description',
		name = function()
			local Statistics = SoundAlerter:GetModule("Statistics")
			return Statistics:GetBarRowErrorMessage(tableType) or ""
		end,
		fontSize = "medium",
		order = baseOrder - 1,
		hidden = function()
			local Statistics = SoundAlerter:GetModule("Statistics")
			return Statistics:GetBarRowCount(tableType) > 0
		end,
	}

	return args
end

function SoundAlerter:OnOptionsProfileChanged()
	sadb = self.db1.profile
	sadb.custom = sadb.custom or {}
	sadb.proximityToasts = sadb.proximityToasts or {}
end

function SoundAlerter:BuildQuickStartOptions()
	return {
		type = 'group',
		name = "Quick Start",
		icon = "Interface\\Icons\\INV_Misc_Book_09",
		desc = "Get arena-ready in 60 seconds. Select your PvP zones and essential alerts. Advanced users can customize 450+ spells in Voice Alerts.",
		order = 0.5,
		args = {
			enableZones = {
				type = 'group',
				inline = true,
				name = "1. Enable Zones",
				desc = "Select where you want SoundAlerter to be active",
				set = setOption,
				get = getOption,
				order = 2,
				args = {
					arena = {
						type = 'toggle',
						name = "Arena",
						desc = "Enable voice alerts in Arena matches, including Solo Shuffle (recommended for competitive PvP)",
						width = "full",
						order = 1,
					},
					battleground = {
						type = 'toggle',
						name = "Battleground",
						desc = "Enable voice alerts in Battlegrounds (recommended for large-scale PvP)",
						width = "full",
						order = 2,
					},
					field = {
						type = 'toggle',
						name = "World PvP",
						desc = "Enable voice alerts in open world PvP zones",
						width = "full",
						order = 3,
					},
				},
			},
			alertScope = {
				type = 'group',
				inline = true,
				name = "2. Alert Scope",
				desc = "Choose how many enemies trigger alerts",
				set = setOption,
				get = getOption,
				order = 3,
				args = {
					scopeDescription = {
						type = 'description',
						name = "|cffFFD700Recommended:|r Target/Focus for Arena, All Enemies for Battlegrounds\n",
						order = 1,
					},
					myself = {
						type = 'toggle',
						name = "Target and Focus Only",
						desc = "Only alert when your current target/focus casts spells, or when enemies cast spells on you (best for Arena)",
						disabled = function() return sadb.enemyinrange end,
						width = "full",
						order = 2,
					},
					enemyinrange = {
						type = 'toggle',
						name = "All Enemies in Range",
						desc = "Alert for enemy spells from any player whose nameplate is visible nearby, not just your target/focus (best for Battlegrounds)",
						disabled = function() return sadb.myself end,
						width = "full",
						order = 3,
					},
				},
			},
			essentialAlerts = {
				type = 'group',
				inline = true,
				name = "3. Essential Alerts (Pre-configured)",
				desc = "Critical spells that should always be announced",
				order = 4,
				args = {
					essentialDescription = {
						type = 'description',
						name = "|cff00FF00Enabled by default|r (edit in Voice Alerts):\n|cffFFFFFFDefensives:|r Divine Shield, Ice Block, Barkskin\n|cffFFFFFFCC:|r Polymorph, Blind, Fear, Hex\n|cffFFFFFFSelf CC alerts:|r Sap, Poly, etc. on you\n",
						fontSize = "medium",
						order = 1,
					},
				},
			},
			nextSteps = {
				type = 'group',
				inline = true,
				name = "Next Steps",
				order = 6,
				args = {
					nextStepsDescription = {
						type = 'description',
						name = "|cff00FF00You're all set!|r Type |cffFFD700/sa|r anytime to reopen this menu.\n",
						fontSize = "medium",
						order = 1,
					},
					authorCredit = {
						type = 'description',
						name = "\n|cff00FF00th|r|cff00D4FF3|r|cff00FF00pajay|r\n",
						fontSize = "medium",
						order = 2,
					},
				},
			},
		},
	}
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
									for k, css in pairs(sadb.custom) do
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
							sadb.proximityToasts.enabled = value
							if not value and SoundAlerter.ProximityToasts then
								SoundAlerter.ProximityToasts:OnDisable()
							end
						end,
						get = function(info)
							return sadb.proximityToasts.enabled
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
							sadb.proximityToasts.displayDuration = value
						end,
						get = function(info)
							return sadb.proximityToasts.displayDuration
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
							sadb.proximityToasts.maxConcurrent = value
						end,
						get = function(info)
							return sadb.proximityToasts.maxConcurrent
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
							sadb.proximityToasts.showPlayerName = value
						end,
						get = function(info)
							return sadb.proximityToasts.showPlayerName
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
							sadb.proximityToasts.useClassColors = value
						end,
						get = function(info)
							return sadb.proximityToasts.useClassColors
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
							sadb.proximityToasts.rainbowBorder = value
						end,
						get = function(info)
							return sadb.proximityToasts.rainbowBorder
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
							sadb.proximityToasts.positionX = value
							if SoundAlerter.ProximityToasts then
								SoundAlerter.ProximityToasts:UpdateLayout()
							end
						end,
						get = function(info)
							return sadb.proximityToasts.positionX
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
							sadb.proximityToasts.positionY = value
							if SoundAlerter.ProximityToasts then
								SoundAlerter.ProximityToasts:UpdateLayout()
							end
						end,
						get = function(info)
							return sadb.proximityToasts.positionY
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
							sadb.proximityToasts.clickEnabled = value
						end,
						get = function(info)
							return sadb.proximityToasts.clickEnabled
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
							sadb.proximityToasts.enableClickToTarget = value
						end,
						get = function(info)
							return sadb.proximityToasts.enableClickToTarget
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
							sadb.proximityToasts.enableFocusTarget = value
						end,
						get = function(info)
							return sadb.proximityToasts.enableFocusTarget
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
						get = function() return sadb.battlegroundAlertsEnabled end,
						set = function(_, val)
							sadb.battlegroundAlertsEnabled = val
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
						get = function() return sadb.flagPickupAudio end,
						set = function(_, val) sadb.flagPickupAudio = val end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 1,
					},
					flagDropAudio = {
						type = 'toggle',
						name = "Flag Drops",
						desc = "Alert when a flag is dropped",
						get = function() return sadb.flagDropAudio end,
						set = function(_, val) sadb.flagDropAudio = val end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 2,
					},
					flagCaptureAudio = {
						type = 'toggle',
						name = "Flag Captures",
						desc = "Alert when a flag is captured",
						get = function() return sadb.flagCaptureAudio end,
						set = function(_, val) sadb.flagCaptureAudio = val end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 3,
					},
					flagReturnAudio = {
						type = 'toggle',
						name = "Flag Returns",
						desc = "Alert when a flag is returned to base",
						get = function() return sadb.flagReturnAudio end,
						set = function(_, val) sadb.flagReturnAudio = val end,
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
						get = function() return sadb.flagToastsEnabled end,
						set = function(_, val) sadb.flagToastsEnabled = val end,
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
							sadb.proximityToasts.rainbowBorder = value
						end,
						get = function(info)
							return sadb.proximityToasts.rainbowBorder
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
						get = function() return sadb.flagTeamBackgroundColors end,
						set = function(_, val) sadb.flagTeamBackgroundColors = val end,
						disabled = function() return not sadb.battlegroundAlertsEnabled or not sadb.flagToastsEnabled end,
						width = "full",
						order = 4,
					},
					flagEnemyRedBackground = {
						type = 'toggle',
						name = "  Enemy Team: Red Background",
						desc = "Show a red transparent background when an enemy team member picks up the flag. " ..
						       "This provides instant visual recognition of threats.",
						get = function() return sadb.flagEnemyRedBackground end,
						set = function(_, val) sadb.flagEnemyRedBackground = val end,
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
						get = function() return sadb.flagFriendlyGreenBackground end,
						set = function(_, val) sadb.flagFriendlyGreenBackground = val end,
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
						get = function() return sadb.flagEnemyTexture or "Solid" end,
						set = function(_, val) sadb.flagEnemyTexture = val end,
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
						get = function() return sadb.flagFriendlyTexture or "Solid" end,
						set = function(_, val) sadb.flagFriendlyTexture = val end,
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
							if not sadb.flagToasts then
								sadb.flagToasts = {}
							end
							sadb.flagToasts.positionX = value
							if SoundAlerter.FlagAlerts then
								SoundAlerter.FlagAlerts:UpdateFlagToastLayout()
							end
						end,
						get = function(info)
							return sadb.flagToasts and sadb.flagToasts.positionX or 0
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
							if not sadb.flagToasts then
								sadb.flagToasts = {}
							end
							sadb.flagToasts.positionY = value
							if SoundAlerter.FlagAlerts then
								SoundAlerter.FlagAlerts:UpdateFlagToastLayout()
							end
						end,
						get = function(info)
							return sadb.flagToasts and sadb.flagToasts.positionY or -300
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
						get = function() return sadb.flagOnlyEnemyTeam end,
						set = function(_, val)
							sadb.flagOnlyEnemyTeam = val

							if val then
								sadb.flagOnlyFriendlyTeam = false
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
						get = function() return sadb.flagOnlyFriendlyTeam end,
						set = function(_, val)
							sadb.flagOnlyFriendlyTeam = val

							if val then
								sadb.flagOnlyEnemyTeam = false
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
						get = function() return sadb.flagAllActions end,
						set = function(_, val)
							sadb.flagAllActions = val

							if val then
								sadb.flagOnlyEnemyTeam = false
								sadb.flagOnlyFriendlyTeam = false
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
						get = function() return sadb.flagChatEnabled end,
						set = function(_, val) sadb.flagChatEnabled = val end,
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
						get = function() return sadb.flagChatText end,
						set = function(_, val) sadb.flagChatText = val end,
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
						get = function() return sadb.flagChatChannel end,
						set = function(_, val) sadb.flagChatChannel = val end,
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
						get = function() return SoundAlerter.db1.profile.resourceBar.locked end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.locked = value
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
					values = {
						default = "Default (WoW StatusBar)",
						solid = "Solid (Clean Fill)",
						transparent = "Transparent (Semi-Opaque)",
					},
					get = function() return SoundAlerter.db1.profile.resourceBar.barTexture end,
					set = function(info, value)
						SoundAlerter.db1.profile.resourceBar.barTexture = value
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
						get = function() return SoundAlerter.db1.profile.resourceBar.energyEnabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.energyEnabled = value
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
						get = function() return SoundAlerter.db1.profile.resourceBar.energyScale end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.energyScale = value
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.energyFrame then
								SoundAlerter.ResourceBar.energyFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.energyEnabled end,
						width = "full",
						order = 2,
					},
					energyColor = {
						type = 'color',
						name = "Energy Color",
						desc = "Color of the energy bar.",
						get = function()
							local c = SoundAlerter.db1.profile.resourceBar.energyColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.db1.profile.resourceBar.energyColor = {r = r, g = g, b = b}
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:CacheColors()
								SoundAlerter.ResourceBar:UpdateEnergyBar()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.energyEnabled end,
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
						get = function() return SoundAlerter.db1.profile.resourceBar.rageEnabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.rageEnabled = value
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
						get = function() return SoundAlerter.db1.profile.resourceBar.rageScale end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.rageScale = value
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.rageFrame then
								SoundAlerter.ResourceBar.rageFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.rageEnabled end,
						width = "full",
						order = 2,
					},
					rageColor = {
						type = 'color',
						name = "Rage Color",
						desc = "Color of the rage bar.",
						get = function()
							local c = SoundAlerter.db1.profile.resourceBar.rageColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.db1.profile.resourceBar.rageColor = {r = r, g = g, b = b}
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:CacheColors()
								SoundAlerter.ResourceBar:UpdateRageBar()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.rageEnabled end,
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
						get = function() return SoundAlerter.db1.profile.resourceBar.healthEnabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.healthEnabled = value
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
						get = function() return SoundAlerter.db1.profile.resourceBar.healthScale end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.healthScale = value
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.healthFrame then
								SoundAlerter.ResourceBar.healthFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.healthEnabled end,
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
						get = function() return SoundAlerter.db1.profile.resourceBar.healthHeight end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.healthHeight = value
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.healthEnabled end,
						width = "full",
						order = 3,
					},
					healthColor = {
						type = 'color',
						name = "Health Color",
						desc = "Color of the health bar.",
						get = function()
							local c = SoundAlerter.db1.profile.resourceBar.healthColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.db1.profile.resourceBar.healthColor = {r = r, g = g, b = b}
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:CacheColors()
								SoundAlerter.ResourceBar:UpdateHealthBar()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.healthEnabled end,
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
						get = function() return SoundAlerter.db1.profile.resourceBar.manaEnabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.manaEnabled = value
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
						get = function() return SoundAlerter.db1.profile.resourceBar.manaScale end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.manaScale = value
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.manaFrame then
								SoundAlerter.ResourceBar.manaFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.manaEnabled end,
						width = "full",
						order = 2,
					},
					manaColor = {
						type = 'color',
						name = "Mana Color",
						desc = "Color of the mana bar.",
						get = function()
							local c = SoundAlerter.db1.profile.resourceBar.manaColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.db1.profile.resourceBar.manaColor = {r = r, g = g, b = b}
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:CacheColors()
								SoundAlerter.ResourceBar:UpdateManaBar()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.manaEnabled end,
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
						get = function() return SoundAlerter.db1.profile.resourceBar.comboEnabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.comboEnabled = value
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
						get = function() return SoundAlerter.db1.profile.resourceBar.comboScale end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.comboScale = value
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.comboFrame then
								SoundAlerter.ResourceBar.comboFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.comboEnabled end,
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
					get = function() return SoundAlerter.db1.profile.resourceBar.comboStyle end,
					set = function(info, value)
						SoundAlerter.db1.profile.resourceBar.comboStyle = value
						if SoundAlerter.ResourceBar then
							SoundAlerter.ResourceBar:ApplyCPStyle()
						end
					end,
					disabled = function() return not SoundAlerter.db1.profile.resourceBar.comboEnabled end,
					width = "full",
					order = 2.5,
				},
					comboTextEnabled = {
						type = 'toggle',
						name = "Show Combo Text",
						desc = "Display combo points as text (e.g., '3/5').",
						get = function() return SoundAlerter.db1.profile.resourceBar.comboTextEnabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.comboTextEnabled = value
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateVisibility()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.comboEnabled end,
						width = "full",
						order = 3,
					},
					comboActiveColor = {
						type = 'color',
						name = "Active Combo Color",
						desc = "Color of active combo points (1-4).",
						get = function()
							local c = SoundAlerter.db1.profile.resourceBar.comboActiveColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.db1.profile.resourceBar.comboActiveColor = {r = r, g = g, b = b}
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:CacheColors()
								SoundAlerter.ResourceBar:RefreshComboColors()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.comboEnabled end,
						order = 4,
					},
					comboMaxColor = {
						type = 'color',
						name = "Max Combo Color",
						desc = "Color of combo points at maximum (5).",
						get = function()
							local c = SoundAlerter.db1.profile.resourceBar.comboMaxColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.db1.profile.resourceBar.comboMaxColor = {r = r, g = g, b = b}
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:CacheColors()
								SoundAlerter.ResourceBar:RefreshComboColors()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.comboEnabled end,
						order = 5,
					},
				fullCPSound = {
					type = 'toggle',
					name = "5 CP Sound",
					desc = "Play a satisfying chime when reaching 5 combo points.",
					get = function() return SoundAlerter.db1.profile.resourceBar.fullCPSound end,
					set = function(info, value)
						SoundAlerter.db1.profile.resourceBar.fullCPSound = value
					end,
					disabled = function() return not SoundAlerter.db1.profile.resourceBar.comboEnabled end,
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
						get = function() return SoundAlerter.db1.profile.castingBars.locked end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.locked = value
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
							local castingBars = SoundAlerter.db1.profile.castingBars
							castingBars.player.PositionX = 0
							castingBars.player.PositionY = -200
							castingBars.target.PositionX = -160
							castingBars.target.PositionY = -260
							castingBars.focus.PositionX = 160
							castingBars.focus.PositionY = -260
							if SoundAlerter.CastingBars then
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
						values = {
							default = "Default (WoW StatusBar)",
							solid = "Solid (Clean Fill)",
							transparent = "Transparent (Semi-Opaque)",
							banto = "Banto",
							halcyone = "Halcyone",
						},
						get = function() return SoundAlerter.db1.profile.castingBars.barTexture end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.barTexture = value
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
						get = function() return SoundAlerter.db1.profile.castingBars.timeFormat end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.timeFormat = value
						end,
						width = "full",
						order = 3,
					},
					showSpellIcon = {
						type = 'toggle',
						name = "Show Spell Icons",
						desc = "Display spell icons to the left of casting bars.",
						get = function() return SoundAlerter.db1.profile.castingBars.showSpellIcon end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.showSpellIcon = value
						end,
						width = "full",
						order = 4,
					},
					showLatency = {
						type = 'toggle',
						name = "Show Latency Shadow",
						desc = "Display a red shadow at the end of the player casting bar representing network latency. Helps predict when the spell will actually cast on the server.",
						get = function() return SoundAlerter.db1.profile.castingBars.showLatency end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.showLatency = value
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
						get = function() return SoundAlerter.db1.profile.castingBars.player.enabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.player.enabled = value
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
						get = function() return SoundAlerter.db1.profile.castingBars.player.width end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.player.width = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.player.enabled end,
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
						get = function() return SoundAlerter.db1.profile.castingBars.player.height end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.player.height = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.player.enabled end,
						width = "full",
						order = 3,
					},
					playerOrientation = {
						type = 'select',
						name = "Bar Orientation",
						desc = "Horizontal or vertical fill for the player casting bar.",
						values = { horizontal = "Horizontal", vertical = "Vertical" },
						get = function() return SoundAlerter.db1.profile.castingBars.player.orientation end,
						set = function(info, value)
							local unitDB = SoundAlerter.db1.profile.castingBars.player
							unitDB.orientation = value
							if value == "vertical" and unitDB.fillDirection ~= "up" and unitDB.fillDirection ~= "down" then
								unitDB.fillDirection = "up"
							elseif value == "horizontal" and unitDB.fillDirection ~= "left" and unitDB.fillDirection ~= "right" then
								unitDB.fillDirection = "right"
							end
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.player.enabled end,
						width = "full",
						order = 4,
					},
					playerFillDirection = {
						type = 'select',
						name = "Fill Direction",
						desc = "Direction the bar fills as the cast progresses.",
						values = function()
							if SoundAlerter.db1.profile.castingBars.player.orientation == "vertical" then
								return { up = "Up", down = "Down" }
							else
								return { right = "Right", left = "Left" }
							end
						end,
						get = function() return SoundAlerter.db1.profile.castingBars.player.fillDirection end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.player.fillDirection = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.player.enabled end,
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
						get = function() return SoundAlerter.db1.profile.castingBars.target.enabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.target.enabled = value
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
						get = function() return SoundAlerter.db1.profile.castingBars.target.width end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.target.width = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.target.enabled end,
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
						get = function() return SoundAlerter.db1.profile.castingBars.target.height end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.target.height = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.target.enabled end,
						width = "full",
						order = 3,
					},
					targetOrientation = {
						type = 'select',
						name = "Bar Orientation",
						desc = "Horizontal or vertical fill for the target casting bar.",
						values = { horizontal = "Horizontal", vertical = "Vertical" },
						get = function() return SoundAlerter.db1.profile.castingBars.target.orientation end,
						set = function(info, value)
							local unitDB = SoundAlerter.db1.profile.castingBars.target
							unitDB.orientation = value
							if value == "vertical" and unitDB.fillDirection ~= "up" and unitDB.fillDirection ~= "down" then
								unitDB.fillDirection = "up"
							elseif value == "horizontal" and unitDB.fillDirection ~= "left" and unitDB.fillDirection ~= "right" then
								unitDB.fillDirection = "right"
							end
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.target.enabled end,
						width = "full",
						order = 4,
					},
					targetFillDirection = {
						type = 'select',
						name = "Fill Direction",
						desc = "Direction the bar fills as the cast progresses.",
						values = function()
							if SoundAlerter.db1.profile.castingBars.target.orientation == "vertical" then
								return { up = "Up", down = "Down" }
							else
								return { right = "Right", left = "Left" }
							end
						end,
						get = function() return SoundAlerter.db1.profile.castingBars.target.fillDirection end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.target.fillDirection = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.target.enabled end,
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
						get = function() return SoundAlerter.db1.profile.castingBars.focus.enabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.focus.enabled = value
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
						get = function() return SoundAlerter.db1.profile.castingBars.focus.width end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.focus.width = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.focus.enabled end,
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
						get = function() return SoundAlerter.db1.profile.castingBars.focus.height end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.focus.height = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.focus.enabled end,
						width = "full",
						order = 3,
					},
					focusOrientation = {
						type = 'select',
						name = "Bar Orientation",
						desc = "Horizontal or vertical fill for the focus casting bar.",
						values = { horizontal = "Horizontal", vertical = "Vertical" },
						get = function() return SoundAlerter.db1.profile.castingBars.focus.orientation end,
						set = function(info, value)
							local unitDB = SoundAlerter.db1.profile.castingBars.focus
							unitDB.orientation = value
							if value == "vertical" and unitDB.fillDirection ~= "up" and unitDB.fillDirection ~= "down" then
								unitDB.fillDirection = "up"
							elseif value == "horizontal" and unitDB.fillDirection ~= "left" and unitDB.fillDirection ~= "right" then
								unitDB.fillDirection = "right"
							end
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.focus.enabled end,
						width = "full",
						order = 4,
					},
					focusFillDirection = {
						type = 'select',
						name = "Fill Direction",
						desc = "Direction the bar fills as the cast progresses.",
						values = function()
							if SoundAlerter.db1.profile.castingBars.focus.orientation == "vertical" then
								return { up = "Up", down = "Down" }
							else
								return { right = "Right", left = "Left" }
							end
						end,
						get = function() return SoundAlerter.db1.profile.castingBars.focus.fillDirection end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.focus.fillDirection = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.focus.enabled end,
						width = "full",
						order = 5,
					},
				},
			},
		},
	}
end

function SoundAlerter:BuildSpellTrackerOptions()
	return {
		type = 'group',
		name = "Spell Tracker",
		icon = "Interface\\Icons\\INV_Misc_PocketWatch_02",
		desc = "Track important buffs and debuffs with cooldown overlays and countdown timers.",
		order = 2.87,
		args = {
			description = {
				type = 'description',
				name = "|cffFFD700Spell Tracker|r\n\n" ..
				       "|cffFF0000Usage:|r Pick '+ Add New Spell' from the dropdown below to track a new spell. Enter the spell ID and configure its settings.\n",
				fontSize = "medium",
				order = 1,
			},

			initErrorWarning = {
				type = 'description',
				name = function()
					return "|cffFF0000Spell Tracker failed to initialize this session:|r\n" ..
					       tostring(SoundAlerter.moduleInitErrors and SoundAlerter.moduleInitErrors.SpellTracker) ..
					       "\n\n|cffFFFFFFToggles below will not take effect until this is fixed and you /reload.|r\n"
				end,
				fontSize = "medium",
				order = 1.5,
				hidden = function() return SoundAlerter.SpellTracker ~= nil end,
			},

			generalGroup = {
				type = 'group',
				inline = true,
				name = "General Settings",
				order = 2,
				args = {
					lockToggle = {
						type = 'toggle',
						name = "Lock Icons",
						desc = "Lock all spell tracker icons in place. Unlock to drag and reposition individual icons.",
						get = function() return SoundAlerter.db1.profile.spellTracker.locked end,
						set = function(info, value)
							SoundAlerter.db1.profile.spellTracker.locked = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:SetLocked(value)
							end
						end,
						width = "full",
						order = 1,
					},
					showTimerText = {
						type = 'toggle',
						name = "Show Aura Duration Numbers",
						desc = "Display aura duration countdown (SS.ss format) at bottom of spell tracker icons. This shows how long the buff/debuff lasts.",
						get = function() return SoundAlerter.db1.profile.spellTracker.showTimerText end,
						set = function(info, value)
							SoundAlerter.db1.profile.spellTracker.showTimerText = value
						end,
						width = "full",
						order = 2,
					},
					showCooldownText = {
						type = 'toggle',
						name = "Show Spell Cooldown Numbers",
						desc = "Display spell cooldown countdown (integer seconds) at center of spell tracker icons. " ..
						       "Only affects spells with 'Track Cooldown' enabled.\n\n" ..
						       "|cffFF7D0ANote:|r This tracks YOUR spell cooldowns (when the ability is ready to use again), " ..
						       "not enemy cooldowns or aura durations.",
						get = function() return SoundAlerter.db1.profile.spellTracker.showCooldownText end,
						set = function(info, value)
							SoundAlerter.db1.profile.spellTracker.showCooldownText = value
						end,
						width = "full",
						order = 3,
					},
				},
			},

			trackedSpellsHeader = {
				type = 'header',
				name = "Tracked Spells",
				order = 4,
			},
		},
	}
end

function SoundAlerter:BuildStatisticsOptions()
	return {
		type = 'group',
		name = "Statistics",
		icon = "Interface\\Icons\\Spell_Holy_MindVision",
		desc = "View alert statistics and performance metrics. Statistics are saved per profile.",
		order = 2.9,
		args = {
			showAdvancedStatistics = {
				type = 'toggle',
				name = "Show Advanced Options",
				desc = "Reveal power-user tools (reset session/all-time stats) at the bottom of this tab.",
				set = function(info, value) sadb.showAdvancedStatistics = value end,
				get = function(info) return sadb.showAdvancedStatistics end,
				width = "full",
				order = 0.5,
			},

			enableTracking = {
				type = 'toggle',
				name = "Enable Statistics Tracking",
				desc = "Track alert statistics (minimal performance impact: <0.02ms per alert)",
				width = "full",
				order = 0.5,
				set = function(info, value)
					sadb.statistics.enabled = value
					if value then
						local Statistics = SoundAlerter:GetModule("Statistics")
						if Statistics then
							Statistics:InitializeStatistics()
						end
						SoundAlerter:Print("Statistics tracking enabled")
					else
						SoundAlerter:Print("Statistics tracking disabled (existing data preserved)")
					end
				end,
				get = function() return sadb.statistics and sadb.statistics.enabled end,
			},

			sessionStats = {
				type = 'group',
				inline = true,
				name = "Session Statistics",
				desc = "Statistics for this play session (resets on logout/reload)",
				order = 1,
				hidden = function() return not sadb.statistics or not sadb.statistics.enabled end,
				args = {
					sessionDisplay = {
						type = 'description',
						name = function()
							if not sadb.statistics or not sadb.statistics.session then
								return "|cffFF0000No session data available|r"
							end

							local session = sadb.statistics.session
							local elapsed = GetTime() - (session.startTime or 0)
							local minutes = math.floor(elapsed / 60)
							local hours = math.floor(minutes / 60)
							local remainingMinutes = minutes % 60

							local timeStr
							if hours > 0 then
								timeStr = string.format("%dh %dm", hours, remainingMinutes)
							else
								timeStr = string.format("%d min", minutes)
							end

							local alertsPerMin = minutes > 0 and (session.totalAlerts / minutes) or 0

							local byCategory = session.byCategory or {}
							return string.format(
								"|cff00FF00 Session Active:|r %s\n" ..
								"|cff00FF00 Total Alerts:|r %d\n" ..
								"|cff00FF00 Alerts/Minute:|r %.1f\n\n" ..
								"|cff00FF00Category Breakdown:|r\n" ..
								"  Spell Alerts: %d\n" ..
								"  Proximity Alerts: %d\n" ..
								"  Trinket Alerts: %d\n" ..
								"  Flag Alerts: %d",
								timeStr,
								session.totalAlerts or 0,
								alertsPerMin,
								byCategory.spellAlerts or 0,
								byCategory.proximityAlerts or 0,
								byCategory.trinketAlerts or 0,
								byCategory.flagAlerts or 0
							)
						end,
						fontSize = "medium",
						order = 1,
					},
				},
			},

			allTimeStats = {
				type = 'group',
				inline = true,
				name = "All-Time Statistics",
				desc = "Lifetime statistics for this profile",
				order = 2,
				hidden = function() return not sadb.statistics or not sadb.statistics.enabled end,
				args = {
					allTimeDisplay = {
						type = 'description',
						name = function()
							if not sadb.statistics or not sadb.statistics.allTime then
								return "|cffFF0000No all-time data available|r"
							end

							local allTime = sadb.statistics.allTime
							local avgPerSession = (allTime.totalSessions or 0) > 0 and
								((allTime.totalAlerts or 0) / allTime.totalSessions) or 0

							local byCategory = allTime.byCategory or {}
							local byZone = allTime.byZone or {}

							return string.format(
								"|cffFFD700 Total Alerts:|r %d\n" ..
								"|cffFFD700 Total Sessions:|r %d\n" ..
								"|cffFFD700 Avg/Session:|r %.1f\n\n" ..
								"|cffFFD700Category Totals:|r\n" ..
								"  Spell Alerts: %d\n" ..
								"  Proximity Alerts: %d\n" ..
								"  Trinket Alerts: %d\n" ..
								"  Flag Alerts: %d\n\n" ..
								"|cffFFD700Zone Distribution:|r\n" ..
								"  Arena: %d\n" ..
								"  Battleground: %d\n" ..
								"  World PvP: %d",
								allTime.totalAlerts or 0,
								allTime.totalSessions or 0,
								avgPerSession,
								byCategory.spellAlerts or 0,
								byCategory.proximityAlerts or 0,
								byCategory.trinketAlerts or 0,
								byCategory.flagAlerts or 0,
								byZone.arena or 0,
								byZone.battleground or 0,
								byZone.worldPvP or 0
							)
						end,
						fontSize = "medium",
						order = 1,
					},
				},
			},

			topSpellsTable = {
				type = 'group',
				inline = true,
				name = "Top 20 Alerted Spells",
				desc = "Most frequently alerted spells with detailed analytics",
				order = 3,
				hidden = function() return not sadb.statistics or not sadb.statistics.enabled end,
				args = (function()
					local args = {
						sortDropdown = {
							type = 'select',
							name = "Sort By",
							desc = "Choose how to sort the spell list",
							values = {
								count_desc = "Most Alerts (High to Low)",
								count_asc = "Fewest Alerts (Low to High)",
								name_asc = "Spell Name (A-Z)",
								name_desc = "Spell Name (Z-A)",
								trend = "Trend (Increasing First)",
								class = "Top Class",
								zone = "Top Zone",
								time = "Most Recent"
							},
							width = "full",
							order = 1,
							set = function(info, value)
								local Statistics = SoundAlerter:GetModule("Statistics")
								Statistics:SetSortState("topSpells", value)
							end,
							get = function()
								local Statistics = SoundAlerter:GetModule("Statistics")
								local sortState = Statistics:GetSortState()
								return sortState.topSpells.sortType or "count_desc"
							end
						},

						refreshButton = {
							type = 'execute',
							name = "Refresh",
							desc = "Refresh the statistics display",
							width = "normal",
							func = function()
								local Statistics = SoundAlerter:GetModule("Statistics")
								Statistics:InvalidateBarRowCache()
								LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter")
							end,
							order = 2
						},
					}

					for k, v in pairs(BuildStatBarRows("topSpells", 20, 10)) do
						args[k] = v
					end

					return args
				end)(),
			},

			enemiesTable = {
				type = 'group',
				inline = true,
				name = "Top 20 Encountered Enemies",
				desc = "Players who trigger the most alerts",
				order = 4,
				hidden = function() return not sadb.statistics or not sadb.statistics.enabled end,
				args = {
					sortDropdown = {
						type = 'select',
						name = "Sort By",
						values = {
							alerts_desc = "Most Alerts (High to Low)",
							alerts_asc = "Fewest Alerts (Low to High)",
							name_asc = "Name (A-Z)",
							name_desc = "Name (Z-A)",
							danger = "Danger Rating (High to Low)",
							class = "Class",
							zone = "Top Zone",
							time = "Most Recent"
						},
						width = "full",
						order = 1,
						set = function(info, value)
							local Statistics = SoundAlerter:GetModule("Statistics")
							Statistics:SetSortState("enemies", value)
						end,
						get = function()
							local Statistics = SoundAlerter:GetModule("Statistics")
							local sortState = Statistics:GetSortState()
							return sortState.enemies.sortType or "alerts_desc"
						end
					},

					tableDisplay = {
						type = 'description',
						name = function()
							local Statistics = SoundAlerter:GetModule("Statistics")
							return Statistics:GetEnemiesTable()
						end,
						fontSize = "medium",
						order = 2
					}
				}
			},

			classDistributionTable = {
				type = 'group',
				inline = true,
				name = "Class Distribution Analysis",
				desc = "Alert breakdown by enemy class",
				order = 5,
				hidden = function() return not sadb.statistics or not sadb.statistics.enabled end,
				args = (function()
					local args = {
						sortDropdown = {
							type = 'select',
							name = "Sort By",
							values = {
								alerts_desc = "Most Alerts (High to Low)",
								alerts_asc = "Fewest Alerts (Low to High)",
								class_asc = "Class Name (A-Z)",
								players = "Most Players",
								avg = "Highest Avg/Player"
							},
							width = "full",
							order = 1,
							set = function(info, value)
								local Statistics = SoundAlerter:GetModule("Statistics")
								Statistics:SetSortState("classes", value)
							end,
							get = function()
								local Statistics = SoundAlerter:GetModule("Statistics")
								local sortState = Statistics:GetSortState()
								return sortState.classes.sortType or "alerts_desc"
							end
						},
					}

					for k, v in pairs(BuildStatBarRows("classes", 13, 10)) do
						args[k] = v
					end

					return args
				end)(),
			},

			management = {
				type = 'group',
				inline = true,
				name = "Management",
				desc = "Reset statistics or export data",
				order = 99,
				hidden = function() return not sadb.showAdvancedStatistics or not sadb.statistics or not sadb.statistics.enabled end,
				args = {
					resetSession = {
						type = 'execute',
						name = "Reset Session Stats",
						desc = "Reset statistics for this session only (all-time stats preserved)",
						width = "normal",
						func = function()
							if sadb.statistics then
								sadb.statistics.session = {
									totalAlerts = 0,
									startTime = GetTime(),
									byCategory = {
										spellAlerts = 0,
										proximityAlerts = 0,
										trinketAlerts = 0,
										flagAlerts = 0,
									},
								}
								SoundAlerter:Print("Session statistics reset")
							end
						end,
						order = 1,
					},

					resetAllTime = {
						type = 'execute',
						name = "Reset All-Time Stats",
						desc = "Reset all statistics including session and all-time data",
						width = "normal",
						confirm = function()
							if not sadb.statistics or not sadb.statistics.allTime then
								return false
							end

							return string.format(
								"Delete all statistics?\n\n" ..
								"Total alerts: %d\n" ..
								"Total sessions: %d\n" ..
								"Top spells tracked: %d\n\n" ..
								"|cffFF0000This cannot be undone!|r",
								sadb.statistics.allTime.totalAlerts or 0,
								sadb.statistics.allTime.totalSessions or 0,
								sadb.statistics.allTime.topSpells and
									(function()
										local count = 0
										for _ in pairs(sadb.statistics.allTime.topSpells) do count = count + 1 end
										return count
									end)() or 0
							)
						end,
						func = function()
							if sadb.statistics then
								sadb.statistics.session = {
									totalAlerts = 0,
									startTime = GetTime(),
									byCategory = {
										spellAlerts = 0,
										proximityAlerts = 0,
										trinketAlerts = 0,
										flagAlerts = 0,
									},
								}

								sadb.statistics.allTime = {
									totalAlerts = 0,
									totalSessions = 1,
									topSpells = {},
									byCategory = {
										spellAlerts = 0,
										proximityAlerts = 0,
										trinketAlerts = 0,
										flagAlerts = 0,
									},
									byZone = {
										arena = 0,
										battleground = 0,
										worldPvP = 0,
									},
								}

								sadb.statistics.trackingStartTime = time()

								SoundAlerter:Print("|cffFF0000All statistics reset|r")
							end
						end,
						order = 2,
					},

					spacer = {
						type = 'description',
						name = " ",
						order = 3,
					},

					exportStats = {
						type = 'execute',
						name = "Export Statistics",
						desc = "Builds a plain-text summary of your session/all-time stats below, for copying out",
						width = "normal",
						order = 4,
						func = function()
							local Statistics = SoundAlerter:GetModule("Statistics")
							sadb.statsExportbox = Statistics:BuildExportString()
						end,
					},

					statsExportbox = {
						type = 'input',
						name = "Exported Statistics (select all, copy)",
						multiline = 12,
						width = "full",
						order = 5,
						get = function() return sadb.statsExportbox or "" end,
						set = function(info, value) sadb.statsExportbox = value end,
					},

					info = {
						type = 'description',
						name = "|cffAAAAAA Statistics are saved per profile. Each character/spec can have separate tracking.|r",
						fontSize = "small",
						order = 6,
					},
				},
			},
		},
	}
end

function SoundAlerter:BuildVoiceAlertOptions()
	return {
		type = 'group',
		name = "Voice Alerts",
		icon = "Interface\\Icons\\INV_Misc_Bell_01",
		desc = "Customize which enemy and friendly spells trigger voice alerts. Organized by strategic purpose to help you focus on what matters in PvP.",
		order = 2,
		childGroups = "tab",
		args = {
			spellGeneral = {
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
			},
			spellauraApplied = {
				type = 'group',
				name = "Enemy Defensives & Buffs",
				desc = "Alert when enemies use defensive cooldowns or gain important buffs. Track when to pressure or wait out immunities. Use the search bar below to quickly find specific spells.",
				set = setOption,
				get = getOption,
				disabled = function() return sadb.aruaApplied end,
				order = 2,
				args = {
					class = {
						type = 'toggle',
						name = "Alert Class calling for trinketing in Arena",
						desc = "Alert when an enemy class trinkets in arena",
						confirm = function() PlaySoundFile(sadb.sapath.."paladin.mp3"); self:ScheduleTimer("PlayTrinket", 0.4); end,
						order = 2,
					},
					drinking = {
						type = 'toggle',
						name = "Alert Drinking in Arena",
						desc = "Alert when an enemy drinks in arena",
						order = 3,
					},
					general = {
						type = 'group',
						inline = true,
						name = "General spells",
						order = 4,
						args = {
							trinket = {
								type = 'toggle',
								name = SpellTexture(42292).."PvP Trinket/Every Man for Himself",
								desc = function ()
									local link = GetSpellLink(42292)
									if link then GameTooltip:SetHyperlink(link) end
								end,
								descStyle = "custom",
								order = 1,
							},
						}
					},
					druid = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Druid:20|t  |cffFF7D0ADruid|r",
						order = 5,
						args = listOption({29166,22812,17116,22842,1850},"auraApplied","spellauraApplied"),
					},
					dk	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_DeathKnight:20|t  |cffC41F3BDeath Knight|r",
						order = 6,
						args = listOption({},"auraApplied","spellauraApplied"),
					},
					hunter = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Hunter:20|t  |cffABD473Hunter|r",
						order = 7,
						args = listOption({19263},"auraApplied","spellauraApplied"),
					},
					mage = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Mage:20|t  |cff69CCF0Mage|r",
						order = 8,
						args = listOption({12042,12472,12043,28682},"auraApplied","spellauraApplied"),
					},
					paladin = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Paladin:20|t  |cffF58CBAPaladin|r",
						order = 9,
						args = listOption({10278,1044,6940,498,64205},"auraApplied","spellauraApplied")
					},
					priest	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Priest:20|t  |cffFFFFFFPriest|r",
						order = 10,
						args = listOption({33206,10060,6346,47585,14751},"auraApplied","spellauraApplied")
					},
					rogue = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Rogue:20|t  |cffFFF569Rogue|r",
						order = 11,
						args = listOption({11305,14177,31224,13750,26669},"auraApplied","spellauraApplied")
					},
					shaman	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Shaman:20|t  |cff0070DEShaman|r",
						order = 12,
						args = listOption({30823,379,57960},"auraApplied","spellauraApplied"),
					},
					warrior	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Warrior:20|t  |cffC79C6EWarrior|r",
						order = 13,
						args = listOption({1719,55694,871,12975,18499,20230,23920,12328,9632,12292},"auraApplied","spellauraApplied")
					},
					warlock	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Warlock:20|t  |cff9482C9Warlock|r",
						order = 14,
						args = listOption({17941},"auraApplied","spellauraApplied"),
						},
					races = {
						type = 'group',
						inline = true,
						name = "|cffFFFFFFGeneral Races|r",
						order = 15,
						args = listOption({1259799,20594,7744,20577,1259686,20554},"auraApplied","spellauraApplied"),
					},

					searchBarGroup = createSearchBar("spellauraApplied").searchBarGroup,
					}
				},
			spellAuraRemoved = {
				type = 'group',
				name = "Enemy Defensives Expired",
				desc = "Alert when enemy defensive cooldowns expire. Know when it's safe to go offensive again. Use the search bar below to quickly find specific spells.",
				set = setOption,
				get = getOption,
				disabled = function() return sadb.auraRemoved end,
				order = 3,
				args = {
					druid = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Druid:20|t  |cffFF7D0ADruid|r",
						order = 1,
						args = listOption({20687},"auraRemoved","spellAuraRemoved"),
					},
					dk = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_DeathKnight:20|t  |cffC41F3BDeath Knight|r",
						order = 2,
						args = listOption({},"auraRemoved","spellAuraRemoved"),
					},
					hunter = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Hunter:20|t  |cffABD473Hunter|r",
						order = 3,
						args = listOption({19263,34471},"auraRemoved","spellAuraRemoved"),
					},
					mage = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Mage:20|t  |cff69CCF0Mage|r",
						order = 4,
						args = listOption({},"auraRemoved","spellAuraRemoved"),
					},
					paladin = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Paladin:20|t  |cffF58CBAPaladin|r",
						order = 5,
						args = listOption({498,10278,11642},"auraRemoved","spellAuraRemoved"),
					},
					priest	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Priest:20|t  |cffFFFFFFPriest|r",
						order = 6,
						args = listOption({},"auraRemoved","spellAuraRemoved"),
					},
					rogue = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Rogue:20|t  |cffFFF569Rogue|r",
						order = 7,
						args = listOption({13750,5277},"auraRemoved","spellAuraRemoved"),
					},
					warrior = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Warrior:20|t  |cffC79C6EWarrior|r",
						order = 8,
						args = listOption({1719,871,12292,46924},"auraRemoved","spellAuraRemoved"),
					},

				searchBarGroup = createSearchBar("spellAuraRemoved").searchBarGroup,
				}
			},
			spellCastStart = {
				type = 'group',
				name = "Enemy Crowd Control (Cast Start)",
				desc = "Alert when enemies start casting CC spells like Polymorph, Cyclone, or Fear. Gives you time to interrupt or react. Use the search bar below to quickly find specific spells.",
				disabled = function() return sadb.castStart end,
				set = setOption,
				get = getOption,
				order = 4,
				args = {
					general = {
						type = 'group',
						inline = true,
						name = "General Spells",
						order = 2,
						args = {
							bigHeal = {
								type = 'toggle',
								name = SpellTexture(48782).."Big Heals",
								desc = "Heal, Holy Light, Healing Wave, Healing Touch",
								order = 1,
							},
							resurrection = {
								type = 'toggle',
								name = SpellTexture(20609).."Resurrection spells",
								desc = "Ancestral Spirit, Redemption, etc",
								order = 2,
							},
						}
					},
					druid = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Druid:20|t  |cffFF7D0ADruid|r",
						order = 3,
						args = listOption({2637,21668,740},"castStart","spellCastStart"),
					},
					hunter = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Hunter:20|t  |cffABD473Hunter|r",
						order = 4,
						args = listOption({982,14327},"castStart","spellCastStart"),
					},
					mage = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Mage:20|t  |cff69CCF0Mage|r",
						order = 5,
						args = listOption({118},"castStart","spellCastStart"),
					},
					paladin = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Paladin:20|t  |cffF58CBAPaladin|r",
						order = 6,
						args = listOption({10326},"castStart","spellCastStart"),
					},
					priest	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Priest:20|t  |cffFFFFFFPriest|r",
						order = 7,
						args = listOption({8129,9484,605},"castStart","spellCastStart"),
					},
					shaman	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Shaman:20|t  |cff0070DEShaman|r",
						order = 8,
						args = listOption({},"castStart","spellCastStart"),
						},

					warlock	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Warlock:20|t  |cff9482C9Warlock|r",
						order = 9,
						args = listOption({6215,17928,710,11712},"castStart","spellCastStart"),
					},

				searchBarGroup = createSearchBar("spellCastStart").searchBarGroup,
				},
			},
			spellCastSuccess = {
				type = 'group',
				name = "Enemy Offensive Cooldowns",
				desc = "Alert when enemies use major offensive cooldowns. Know when burst damage windows are active and when to play defensively. Use the search bar below to quickly find specific spells.",
				disabled = function() return sadb.castSuccess end,
				set = setOption,
				get = getOption,
				order = 5,
				args = {
					druid = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Druid:20|t  |cffFF7D0ADruid|r",
						order = 1,
						args = listOption({5215},"castSuccess","spellCastSuccess"),
					},
					dk	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_DeathKnight:20|t  |cffC41F3BDeath Knight|r",
						order = 2,
						args = listOption({},"castSuccess","spellCastSuccess"),
					},
					hunter = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Hunter:20|t  |cffABD473Hunter|r",
						order = 3,
						args = listOption({23989,24335,14311,13810,1310687},"castSuccess","spellCastSuccess"),
					},
					mage = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Mage:20|t  |cff69CCF0Mage|r",
						order = 4,
						args = listOption({12051,11958,2139,66,11366},"castSuccess","spellCastSuccess"),
					},
					paladin = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Paladin:20|t  |cffF58CBAPaladin|r",
						order = 5,
						args = listOption({20066,10308,31884},"castSuccess","spellCastSuccess"),
					},
					priest	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Priest:20|t  |cffFFFFFFPriest|r",
						order = 6,
						args = listOption({10890,34433},"castSuccess","spellCastSuccess"),
					},
					rogue = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Rogue:20|t  |cffFFF569Rogue|r",
						order = 7,
						args = listOption({11297,2094,1766,14185,27617,13877,1784},"castSuccess","spellCastSuccess"),
					},
					shaman	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Shaman:20|t  |cff0070DEShaman|r",
						order = 8,
						args = listOption({8143,16190,2484,8177},"castSuccess","spellCastSuccess"),
					},
					warrior	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Warrior:20|t  |cffC79C6EWarrior|r",
						order = 9,
						args = listOption({2457,2458,71,676,65930,6552,72},"castSuccess","spellCastSuccess"),
					},
					warlock = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Warlock:20|t  |cff9482C9Warlock|r",
						order = 10,
						args = listOption({5138,19647,17926,6358,17925},"castSuccess","spellCastSuccess"),
					},

				searchBarGroup = createSearchBar("spellCastSuccess").searchBarGroup,
				},
			},
			enemydebuff = {
				type = 'group',
				name = "Your CC on Enemies",
				desc = "Alert when you or your arena partner successfully land crowd control on enemies. Confirms CC application for coordination. Use the search bar below to quickly find specific spells.",
				disabled = function() return sadb.dEnemyDebuff end,
				set = setOption,
				get = getOption,
				order = 6,
				args = {
						fromself = {
						type = 'group',
						inline = true,
						name = "|cffFFF569From Self|r",
						order = 1,
						args = listOption({2094,12826,118},"enemyDebuffs","enemydebuff"),
					},
					fromarenapartner = {
						type = 'group',
						inline = true,
						name = "|cffFFF569From Arena Partner or affecting your Target|r",
						order = 2,
						args = listOption({2094,12826,118},"friendCCenemy","enemydebuff"),
					},

					searchBarGroup = createSearchBar("enemydebuff").searchBarGroup,
				},
			},
			enemydebuffdown = {
				type = 'group',
				name = "Your CC Expired on Enemies",
				desc = "Alert when your crowd control effects on enemies expire. Know when enemies are free and can act again. Use the search bar below to quickly find specific spells.",
				disabled = function() return sadb.dEnemyDebuffDown end,
				set = setOption,
				get = getOption,
				order = 7,
				args = {
					fromself = {
						type = 'group',
						inline = true,
						name = "|cffFFF569From Self|r",
						order = 1,
						args = listOption({2094,12826,118},"enemyDebuffdown","enemydebuffdown"),
					},
					fromarenapartner = {
						type = 'group',
						inline = true,
						name = "|cffFFF569From Arena Partner or affecting your Target|r",
						desc = "Alerts you if your arena partner casts a spell or your target gets afflicted by a spell",
						order = 2,
						args = listOption({2094,51724,12826,118,},"enemyDebuffdownAP","enemydebuffdown"),
					},

					searchBarGroup = createSearchBar("enemydebuffdown").searchBarGroup,
				},
			},
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
							cycloneenemy = {
								type = 'toggle',
								name = SpellTexture(33786).."Cyclone on Enemy",
								desc = "Enemies you cyclone will be alerted in chat",
								order = 5,
							},
							cycloneselffriend = {
								type = 'toggle',
								name = SpellTexture(33786).."Cyclone on Self/Friend",
								desc = "Enemies you cyclone will be alerted in chat",
								order = 6,
							},
							hexenemy = {
								type = 'toggle',
								name = SpellTexture(51514).."Hex on Enemy",
								desc = "Enemies you hex will be alerted in chat",
								order = 7,
							},
							hexselffriend = {
								type = 'toggle',
								name = SpellTexture(51514).."Hex on Self/Friend",
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
								name = SpellTextureName(26889),
								desc = "Enemies that have casted Vanish will be alerted",
								order = 13,
							},
							trinketalert = {
								type = 'toggle',
								name = SpellTextureName(42292),
								desc = function ()
									local link = GetSpellLink(42292)
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
						name = SpellTextureName(26889),
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
			FriendDebuff = {
				type = 'group',
				name = "Arena Partner Under Attack",
				desc = "Alert when enemies cast spells targeting your arena partner. React quickly to peel or assist your teammate.",
				disabled = function() return sadb.dArenaPartner end,
				set = setOption,
				get = getOption,
				order = 8,
				args = listOption({118,6215},"friendCCs"),
			},
			FriendDebuffSuccess = {
			type = 'group',
			name = "Arena Partner CC'd",
			desc = "Alert when your arena partner gets crowd controlled. Coordinate defensive cooldowns or peels to protect your teammate.",
			disabled = function() return sadb.dArenaPartner end,
			set = setOption,
			get = getOption,
			order = 9,
			args = listOption({14309,2094,10308,12826,6215,2139,51724},"friendCCSuccess"),
			},
			selfDebuffs = {
				type = 'group',
				name = "CC on You",
				desc = "Alert when you get crowd controlled by enemies. Know immediately when to trinket or call for help from teammates.",
				disabled = function() return sadb.dSelfDebuff end,
				set = setOption,
				get = getOption,
				order = 10,
				args = listOption({118,6215,14309,13809,65930,17928,2094,51724,10308,17926,115138,20066,34490,19434,47476,19386,6358},"selfDebuff"),
			},
		},
	}
end

local function FormatThousands(n)
	local s = string.format("%d", n or 0):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return s
end

local function Plural(n, unit)
	return n .. " " .. unit .. (n == 1 and "" or "s")
end

local function FormatAge(seconds)
	if seconds < 60 then
		return "|cff00FF00", "just now"
	elseif seconds < 3600 then
		return "|cff88FF88", Plural(math.floor(seconds / 60), "minute") .. " ago"
	elseif seconds < 86400 then
		return "|cffFFD700", Plural(math.floor(seconds / 3600), "hour") .. " ago"
	end
	return "|cffFFAA00", Plural(math.floor(seconds / 86400), "day") .. " ago"
end

local function StatLine(label, value)
	return "|cffFFFFFF● " .. label .. ":|r " .. value .. "\n"
end

local function IsDatabaseBuilding()
	return SoundAlerter.spellDatabase.isBuilding
end

function SoundAlerter:BuildSpellFinderOptions()
	return {
		type = 'group',
		name = "Developer Tools",
		icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
		desc = "Advanced tools for addon developers and power users. Find spell IDs, rebuild database, and access debug features.",
		order = 5,
		args = {
			finderSection = {
				type = 'group',
				inline = true,
				name = "|TInterface\\Icons\\INV_Misc_Spyglass_02:20|t  Spell Database Search",
				order = 1,
				args = {
					finderDescription = {
						type = 'description',
						name = "|cffFFFFFFSearch the spell database.|r\n",
						fontSize = "medium",
						order = 1,
					},
					openFinder = {
						type = 'execute',
						name = "|cff00D4FF[OPEN SPELL FINDER PANEL]|r",
						desc = "Open the spell search panel, docked beside this options window",
						width = "full",
						order = 2,
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
					quickTip = {
						type = 'description',
						name = "\n|cffFFD700Quick Tip:|r Press |cffFFFFFFEnter|r to search, hover results for tooltips\n",
						fontSize = "small",
						order = 3,
					},
					autoSearch = {
						type = 'toggle',
						name = "Auto-Search As You Type",
						desc = "Enable auto-search with 200ms debounce. When enabled, searches automatically as you type (minimum 2 characters). Press Enter to search immediately.",
						width = "full",
						order = 4,
						get = function(info)
							return SoundAlerter.db1.profile.findSpell and SoundAlerter.db1.profile.findSpell.autoSearch or false
						end,
						set = function(info, value)
							if not SoundAlerter.db1.profile.findSpell then
								SoundAlerter.db1.profile.findSpell = {}
							end
							SoundAlerter.db1.profile.findSpell.autoSearch = value
							SoundAlerter:Print(value and "|cFF00FF00Auto-search enabled|r" or "|cFFFF0000Auto-search disabled|r")
						end,
					},
				},
			},

			databaseSection = {
				type = 'group',
				inline = true,
				name = "|TInterface\\Icons\\INV_Misc_Book_09:20|t  Spell Database",
				order = 2,
				args = {
					status = {
						type = 'description',
						name = function()
							local stats = SoundAlerter:GetDatabaseStats()
							if not stats.isBuilding then
								return StatLine("Status", "|cFF00FF00READY|r |cff00FF00✓|r")
									.. StatLine("Spells Indexed", "|cffFFD700" .. FormatThousands(stats.totalSpells) .. "|r spells")
							end

							local filledBlocks = math.floor(stats.progress / 5)
							local bar = {}
							for i = 1, 20 do
								bar[i] = i <= filledBlocks and "|cffFFAA00█|r" or "|cff444444█|r"
							end

							return StatLine("Status", "|cFFFFAA00BUILDING DATABASE|r")
								.. StatLine("Progress", string.format("%.1f%% complete", stats.progress))
								.. StatLine("Visual", table.concat(bar))
								.. StatLine("Scanned", FormatThousands(stats.totalScanned) .. " / " .. FormatThousands(stats.maxSpellID) .. " spell IDs")
						end,
						fontSize = "medium",
						order = 1,
					},
					contentsHeader = {
						type = 'header',
						name = "Contents",
						order = 2,
						hidden = IsDatabaseBuilding,
					},
					contents = {
						type = 'description',
						name = function()
							local stats = SoundAlerter:GetDatabaseStats()
							local density = stats.maxSpellID > 0 and (stats.totalSpells / stats.maxSpellID) * 100 or 0
							local ranked = stats.totalSpells > 0 and (stats.rankedSpells / stats.totalSpells) * 100 or 0
							return StatLine("Unique Names", FormatThousands(stats.uniqueNames))
								.. StatLine("Ranked Spells", string.format("%s |cff888888(%.1f%%)|r", FormatThousands(stats.rankedSpells), ranked))
								.. StatLine("Scan Range", string.format("1 – %s |cff888888(%.1f%% of IDs are spells)|r", FormatThousands(stats.maxSpellID), density))
						end,
						fontSize = "medium",
						order = 3,
						hidden = IsDatabaseBuilding,
					},
					freshnessHeader = {
						type = 'header',
						name = "Freshness",
						order = 4,
						hidden = IsDatabaseBuilding,
					},
					freshness = {
						type = 'description',
						name = function()
							local stats = SoundAlerter:GetDatabaseStats()
							local text = ""

							if stats.lastUpdate > 0 then
								local age = time() - stats.lastUpdate
								local ageColor, ageText = FormatAge(age)
								text = text .. StatLine("Last Updated", ageColor .. ageText .. "|r")
								local daysLeft = math.max(0, math.ceil((stats.maxAge - age) / 86400))
								text = text .. StatLine("Auto-Rebuild", "in " .. Plural(daysLeft, "day") .. " |cff888888(or on game patch)|r")
							end

							if stats.source == "built" then
								text = text .. StatLine("Source", string.format("Built this session in %.1fs", stats.buildSeconds or 0))
							elseif stats.source == "loaded" then
								text = text .. StatLine("Source", "Loaded from saved cache")
							end

							if stats.builtOnVersion then
								if stats.builtOnVersion == stats.currentVersion then
									text = text .. StatLine("Game Build", stats.builtOnVersion .. " |cff00FF00(current)|r")
								else
									text = text .. StatLine("Game Build", stats.builtOnVersion .. " |cffFF5555(current: " .. stats.currentVersion .. ")|r")
								end
							end

							return text
						end,
						fontSize = "medium",
						order = 5,
						hidden = IsDatabaseBuilding,
					},
					performanceHeader = {
						type = 'header',
						name = "Performance",
						order = 6,
						hidden = IsDatabaseBuilding,
					},
					performance = {
						type = 'description',
						name = function()
							local stats = SoundAlerter:GetDatabaseStats()
							local text

							local sp50, sp95, sp99, spMax, spCount = SoundAlerter:GetSearchPercentiles()
							if sp50 then
								text = StatLine("Search Timing", string.format("p50 %.3fms  p95 %.3fms  p99 %.3fms  max %.3fms |cff888888(last %d)|r",
									sp50, sp95, sp99, spMax, spCount))
							else
								text = StatLine("Search Timing", "|cff888888no searches yet this session|r")
							end

							text = text .. StatLine("Result Cache", stats.cacheEntries .. " / " .. stats.cacheMax .. " entries")
							text = text .. StatLine("Prefix Index", FormatThousands(stats.prefixBuckets) .. " buckets")

							UpdateAddOnMemoryUsage()
							local memKB = GetAddOnMemoryUsage("SoundAlerter")
							local memColor = memKB > 10240 and "|cffFFAA00" or "|cff00FF00"
							text = text .. StatLine("Addon Memory", string.format("%s%.1f MB|r |cff888888(total)|r", memColor, memKB / 1024))

							return text
						end,
						fontSize = "medium",
						order = 7,
						hidden = IsDatabaseBuilding,
					},
					rebuildNote = {
						type = 'description',
						name = "\n|cff888888Rebuilding is only needed if the database is corrupted or after a major game patch.|r\n",
						fontSize = "medium",
						order = 8,
					},
					rebuild = {
						type = 'execute',
						name = "|cffFFAA00[REBUILD DATABASE]|r",
						desc = "Perform a full database rebuild. This will scan all spell IDs and may cause a brief frame stutter.",
						width = "full",
						order = 9,
						disabled = IsDatabaseBuilding,
						confirm = true,
						confirmText = "This will rebuild the spell database and take 3-4 seconds. Continue?",
						func = function()
							SoundAlerter:RebuildSpellDatabase()
						end,
					},
				},
			},

			debugSection = {
				type = 'group',
				inline = true,
				name = "|TInterface\\Icons\\INV_Misc_Spyglass_03:20|t  Debug Mode",
				order = 5,
				args = {
					debugDescription = {
						type = 'description',
						name = "|cffFFFFFFEnable debug logging across all addon modules.|r\n\n" ..
							   "|cffFFAA00Warning:|r Prints combat log events, search timings, and module state changes to chat. Chatty by design.\n",
						fontSize = "medium",
						order = 1,
					},
					debugmode = {
						type = 'toggle',
						name = "Debug Mode",
						desc = "Enable debug logging",
						width = "full",
						order = 2,
						get = function() return sadb.debugmode end,
						set = function(info, value) sadb.debugmode = value end,
					},
				},
			},
		}
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

	local RebuildSpellTrackerOptions

	local function BuildAddSpellPanel()
		local function TryAddTrackedSpell()
			local spellID = tonumber(spellTrackerAddForm.spellID)
			if not spellID or spellID <= 0 then
				SoundAlerter:Print("|cffff0000Invalid spell ID.|r")
				return
			end

			if SoundAlerter.SpellTracker then
				local success = SoundAlerter.SpellTracker:AddTrackedSpell(
					spellID, spellTrackerAddForm.unit, spellTrackerAddForm.auraType)
				if success then
					SoundAlerter:Print("|cff00ff00Added spell " .. spellID .. " to tracker.|r")
					spellTrackerAddForm.spellID = ""
					RebuildSpellTrackerOptions()
					LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter")
				end
			end
		end

		return {
			addDescription = {
				type = 'description',
				name = "Add a new spell to track. Enter the spell ID and press Enter, or type it and click Add Spell.",
				fontSize = "medium",
				order = 1,
			},
			addSpellID = {
				type = 'input',
				name = "Spell ID",
				desc = "Enter numeric spell ID and press Enter",
				get = function() return spellTrackerAddForm.spellID end,
				set = function(info, value)
					spellTrackerAddForm.spellID = value
					TryAddTrackedSpell()
				end,
				width = "half",
				order = 2,
			},
			addUnit = {
				type = 'select',
				name = "Track On",
				desc = "Which unit to track this aura on",
				values = { player = "Player (Self)", target = "Target" },
				get = function() return spellTrackerAddForm.unit end,
				set = function(info, value) spellTrackerAddForm.unit = value end,
				width = "half",
				order = 3,
			},
			addAuraType = {
				type = 'select',
				name = "Aura Type",
				desc = "Type of aura to track",
				values = { HELPFUL = "Buff (Helpful)", HARMFUL = "Debuff (Harmful)" },
				get = function() return spellTrackerAddForm.auraType end,
				set = function(info, value) spellTrackerAddForm.auraType = value end,
				width = "half",
				order = 4,
			},
			addButton = {
				type = 'execute',
				name = "Add Spell",
				desc = "Add this spell to the tracker",
				func = TryAddTrackedSpell,
				width = "full",
				order = 5,
			},
		}
	end

	local function BuildConfigPanel()
		if not spellTrackerSelectedIndex then
			return {
				type = 'group',
				inline = true,
				name = "Add New Spell",
				order = 6,
				args = BuildAddSpellPanel(),
			}
		end

		local i = spellTrackerSelectedIndex
		local config = SoundAlerter.db1.profile.spellTracker.icons[i]
		if not config then
			return {
				type = 'group',
				inline = true,
				name = "Error",
				order = 6,
				args = {
					errorMsg = {
						type = 'description',
						name = "|cffff0000Selected spell not found.|r",
						order = 1,
					}
				}
			}
		end

		local spellName = GetSpellInfo(config.spellID) or "Unknown"
		local _, _, icon = GetSpellInfo(config.spellID)

		return {
			type = 'group',
			inline = true,
			name = "Configure: " .. spellName,
			order = 6,
			args = {
				spellHeader = {
					type = 'description',
					name = string.format("|T%s:24|t |cffFFD700%s|r\nSpell ID: %d",
						icon or "Interface\\Icons\\INV_Misc_QuestionMark",
						spellName,
						config.spellID),
					fontSize = "large",
					order = 1,
				},
				enabled = {
					type = 'toggle',
					name = "Enabled",
					desc = "Enable tracking for this spell",
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.enabled
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.enabled = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "half",
					order = 2,
				},
				unit = {
					type = 'select',
					name = "Track On",
					desc = "Which unit to track this aura on",
					values = { player = "Player (Self)", target = "Target" },
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.unit or "player"
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.unit = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "half",
					order = 3,
				},
				auraType = {
					type = 'select',
					name = "Aura Type",
					desc = "Type of aura to track",
					values = { HELPFUL = "Buff (Helpful)", HARMFUL = "Debuff (Harmful)" },
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.auraType or "HELPFUL"
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.auraType = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "half",
					order = 4,
				},
				size = {
					type = 'range',
					name = "Icon Size",
					desc = "Size of the spell tracker icon in pixels",
					min = 24,
					max = 80,
					step = 4,
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.size or 48
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.size = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "half",
					order = 5,
				},
				showWhenInactive = {
					type = 'toggle',
					name = "Show When Inactive",
					desc = "Display icon (faded) even when aura is not active",
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.showWhenInactive
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.showWhenInactive = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "half",
					order = 5.5,
				},
				trackCooldown = {
					type = 'toggle',
					name = "Track Cooldown",
					desc = "Display spell cooldown timer (integer seconds) at icon center.\n\n" ..
						   "|cffFF0000Limitation:|r Only tracks YOUR cooldowns (spells on your action bars). " ..
						   "Does NOT track enemy cooldowns.\n\n" ..
						   "Shows when the spell is ready to cast again (independent from aura duration).",
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.trackCooldown or false
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.trackCooldown = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "half",
					order = 6,
				},
				cooldownTextSize = {
					type = 'range',
					name = "Cooldown Text Size",
					desc = "Font size for the cooldown countdown text (in points). Only visible when 'Track Cooldown' is enabled.",
					min = 8,
					max = 32,
					step = 1,
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.cooldownTextSize or 14
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.cooldownTextSize = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "full",
					order = 6.5,
				},
				deleteButton = {
					type = 'execute',
					name = "Delete Spell",
					desc = "Remove this spell from the tracker",
					func = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if SoundAlerter.SpellTracker and iconConfig then
							local spellName = GetSpellInfo(iconConfig.spellID) or "Unknown"
							SoundAlerter.SpellTracker:RemoveTrackedSpell(i)
							SoundAlerter:Print("|cffff0000Removed " .. spellName .. " from tracker.|r")
							spellTrackerSelectedIndex = nil
							RebuildSpellTrackerOptions()
							LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter")
						end
					end,
					confirm = true,
					confirmText = "Are you sure you want to delete this tracked spell?",
					width = "full",
					order = 10,
				},
			}
		}
	end

	RebuildSpellTrackerOptions = function()
		local spellTrackerTab = SoundAlerter.options.args['SpellTracker']
		if not spellTrackerTab then return end

		for key in pairs(spellTrackerTab.args) do
			if key:match("^spell_%d+$") or key == "spellListGroup" or key == "configPanelGroup" then
				spellTrackerTab.args[key] = nil
			end
		end

		spellTrackerTab.args.spellListGroup = {
			type = 'group',
			inline = true,
			name = "Tracked Spells",
			order = 5,
			args = {
				spellSelect = {
					type = 'select',
					name = "Select Spell",
					desc = "Choose a tracked spell to configure, or add a new one.",
					values = function()
						local vals = { ["__new__"] = "+ Add New Spell" }
						if SoundAlerter.db1.profile.spellTracker.icons then
							for i, config in ipairs(SoundAlerter.db1.profile.spellTracker.icons) do
								local spellName = GetSpellInfo(config.spellID) or "Unknown"
								local statusText = config.enabled and "[ON]" or "[OFF]"
								local unitText = config.unit == "player" and "P" or "T"
								local typeText = config.auraType == "HELPFUL" and "Buff" or "Debuff"
								vals[tostring(i)] = string.format("%s %s (%d) - %s/%s",
									statusText, spellName, config.spellID, unitText, typeText)
							end
						end
						return vals
					end,
					get = function()
						return spellTrackerSelectedIndex and tostring(spellTrackerSelectedIndex) or "__new__"
					end,
					set = function(info, value)
						spellTrackerSelectedIndex = (value ~= "__new__") and tonumber(value) or nil
						RebuildSpellTrackerOptions()
						LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter")
					end,
					width = "full",
					order = 1,
				},
			},
		}

		spellTrackerTab.args.configPanelGroup = BuildConfigPanel()
	end

	self:AddOption('SpellTracker', self:BuildSpellTrackerOptions())

	RebuildSpellTrackerOptions()

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
	for key, v in pairs(sadb.custom) do
		makeoption(key)
	end
end
