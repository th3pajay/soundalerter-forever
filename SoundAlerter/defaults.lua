dbDefaults = {
	profile = {
		sapath = SA_LOCALEPATH[GetLocale()] or SA_LOCALEPATH.enUS,
		debugmode = false,
		spelldebug = false,

		flatWindow = true,
		menuAnimations = true,

		enemyFinder = {},

		findSpell = {
			autocomplete = false,
			fuzzy = false,
			sortMode = "name",
			sortDesc = false,
			rankFilter = "all",
		},

		MinimapButtonPosition = nil,
		MinimapButtonHidden = false,

		minimapButton = {
			clicks = {
				none = { left = "options", right = "menu", middle = "finder" },
				shift = { left = "proximity", right = "lockbars", middle = "none" },
				ctrl = { left = "battleground", right = "stats", middle = "none" },
				alt = { left = "snooze", right = "test", middle = "none" },
			},
			icons = {
				both = "ability_dualwield",
				prox = "ability_hunter_mastermarksman",
				bg = "achievement_bg_winwsg",
				none = "spell_holy_silence",
			},
		},

		minimapTracking = {
			enabled = false,
			target = true,
			focus = true,
		},

		all = false,
		arena = true,
		battleground = true,
		field = true,

		myself = true,
		enemyinrange = false,

		chatalerts = false,
		dArenaPartner = false,
		dSelfDebuff = false,
		dEnemyDebuff = false,
		dEnemyDebuffDown = false,
		prowlenemy = false,
		vanishenemy = false,

		trinket = true,
		drinking = true,
		class = true,

		blindenemy = true,
		fearenemy = true,
		hexenemy = true,
		polyenemy = true,
		sapenemy = true,

		bubbleenemy = true,
		thorns = false,
		recklessswings = false,
		aspectofthewild = false,
		stealthenemy = true,
		interruptenemy = true,
		interruptemote = false,
		blindselffriend = true,
		fearselffriend = true,
		hexselffriend = true,
		sapselffriend = true,
		polyselffriend = true,

		vanishTF = true,
		stealthTF = true,
		prowlTF = true,

		aruaApplied = false,
		auraRemoved = false,
		castStart = false,
		castSuccess = false,
		interrupt = false,

		starfire = false,
		bestialwrath = false,
		icebarrier = false,
		powerwordshield = false,
		amplifycurse = false,
		feldomination = false,
		soullink = false,
		holyshield = false,
		chatdownfriend = false,
		interruptself = false,
		trinketalert = false,
		chatAreaChannels = {
			spells = { SAY = false, PARTY = true, RAID = false, BATTLEGROUND = true },
			proximity = { SAY = false, PARTY = true, RAID = false, BATTLEGROUND = true },
			battleground = { SAY = false, PARTY = true, RAID = false, BATTLEGROUND = true },
			custom = { SAY = false, PARTY = true, RAID = false, BATTLEGROUND = true },
		},
		chatLayout = 0,

		chatauraApplied = false,
		chatauraRemoved = false,
		chatcastStart = false,

		InterruptEnemyText = "Interrupted #enemy#'s #interruptedspellname# with #spell#.",
		InterruptSelfText = "#enemy# interrupted my #interruptedspellname# with #spell#.",

		friendchat = "#enemy# casted #spell# on #friend#",
		selfchat = "#enemy# casted #spell# on me!",
		enemychat = "#spell# up on #enemy#",
		enemybuffchat = "#enemy# casted #spell#",
		auraRemovedChat = "#spell# wore off #enemy#",
		castStartChat = "#enemy# is casting #spell#",

		sapselftext = "I'm Sapped!",
		sapfriendtext = "#friend# is Sapped!",

		bubbleenemytext = "#enemy# bubbled!",
		ccDownChat = "#spell# down on #enemy#",
		trinketalerttext = "[#enemy#] Trinketted!",

		custom = {},

		proximityEnabled = false,
		proximityWorld = false,
		proximityBattleground = false,
		proximityArena = false,
		proximitySanctuary = false,
		proximityCooldown = 60,
		proximityChat = false,
		proximityChatText = "#class# #player# (#level# #race#) near #place#",
		overrideNameplateRange = false,
		nameplateRange = 60,
		proximityAllyVision = false,
		enemyTargetsYou = false,
		enemyTargetsYouCooldown = 8,
		enemyCastingAtYou = false,
		quietOnTaxi = true,
		quietWhenDead = true,
		quietOutsidePvPFlag = false,
		snoozeMinutes = 15,
		scoreboardClassFallback = true,
		proximityMaxBand = "Detected",
		stealthOnSight = false,
		stealthAnyEnemy = true,
		stealthKeepWatch = false,
		stealthWatchBand = "Nearby",
		stealthWatchGap = 4,
		shareAlertsSend = false,
		shareAlertsReceive = false,
		globalSightings = true,
		globalQuality = "normal",
		globalMapMarkers = false,
		globalMinimap = false,
		globalPanelExpanded = true,
		globalPanelZone = "strip",
		globalPanelWorld = "strip",
		interruptFocusVoice = false,
		interruptMinCast = 0,
		interruptPets = false,
		interruptReadyVoice = false,
		procVoices = false,
		updateNotice = true,
		welcomeLine = true,
		engineAuraSounds = false,
		battleVoices = true,
		hiddenSpells = true,
		showTotemPlates = false,
		watchlistEnabled = false,
		watchNamesText = "",
		watchGuildsText = "",
		lossOfControlVoice = false,
		lossOfControlDedupe = true,
		lossOfControlStun = true,
		lossOfControlFear = true,
		lossOfControlRoot = true,
		lossOfControlSilence = true,
		lossOfControlDisarm = true,
		lossOfControlIncapacitate = true,
		lossOfControlInterrupt = true,

		proximityToasts = {
			enabled = false,
			displayDuration = 3.0,
			showPlayerName = true,
			showAuraIcons = true,
			useClassColors = true,
			maxConcurrent = 3,
			positionX = 0,
			positionY = -200,

			clickEnabled = true,
			enableClickToTarget = true,
			enableFocusTarget = true,
			rainbowBorder = false,
			toastStyle = "intel",
			showLatestSpell = true,
			voice = true,
		},

		resourceBar = {
			locked = true,

			energyEnabled = false,
			energyPositionX = 0,
			energyPositionY = -120,
			energyScale = 1.0,
			energyColor = {r = 1, g = 1, b = 0.2},
			poisedGlow = true,

			rageEnabled = false,
			ragePositionX = 0,
			ragePositionY = -120,
			rageScale = 1.0,
			rageColor = {r = 1, g = 0.2, b = 0.2},
			rageFade = false,
			swingSpark = false,
			swingSparkFlash = true,

			healthEnabled = false,
			healthPositionX = 0,
			healthPositionY = -140,
			healthScale = 1.0,
			healthHeight = 20,
			healthColor = {r = 0.2, g = 1, b = 0.2},

			manaEnabled = false,
			manaPositionX = 0,
			manaPositionY = -100,
			manaScale = 1.0,
			manaColor = {r = 0.2, g = 0.5, b = 1},
			manaSweep = true,
			manaShiftMarks = true,

			comboEnabled = false,
			comboPositionX = 0,
			comboPositionY = -85,
			comboScale = 1.0,
			comboStyle = "circle",
			comboCelebration = "classic",
			comboAnimQuality = "normal",
			comboExit = "style",
			comboActiveColor = {r = 0.2, g = 1, b = 0.2},
			comboMaxColor = {r = 1, g = 0.8, b = 0.2},
			comboInactiveColor = {r = 0.25, g = 0.25, b = 0.25},

			comboTextEnabled = false,
			comboTextPositionX = 0,
			comboTextPositionY = -50,

			fullCPSound = false,

			barTexture = "default",
			barTextureQuality = "normal",
		},

		castingBars = {
			locked = true,
			barTexture = "default",
			barTextureQuality = "normal",
			roundCorners = "off",
			timeFormat = "milliseconds",
			showSpellIcon = false,
			showLatency = false,
			showLockIcon = true,
			hoverTooltip = true,
			animQuality = "normal",
			segments = true,
			channelPulse = true,

			player = {
				enabled = false,
				barTexture = "inherit",
				PositionX = 0,
				PositionY = -200,
				width = 280,
				height = 24,
				orientation = "horizontal",
				fillDirection = "right",
			},

			target = {
				enabled = false,
				barTexture = "inherit",
				PositionX = 0,
				PositionY = -230,
				width = 280,
				height = 24,
				orientation = "horizontal",
				fillDirection = "right",
			},

			focus = {
				enabled = false,
				barTexture = "inherit",
				PositionX = 0,
				PositionY = -260,
				width = 280,
				height = 24,
				orientation = "horizontal",
				fillDirection = "right",
			},
		},

		speedMeter = {
			enabled = false,
			locked = true,
			PositionX = 0,
			PositionY = -150,
			scale = 1,
			fontSize = 18,
			hideAtBaseline = false,
			tintMounted = false,
			boostColor = { r = 0.3, g = 1, b = 0.4 },
			slowColor = { r = 1, g = 0.3, b = 0.3 },
			baseColor = { r = 1, g = 1, b = 1 },
		},

		drTracker = {
			enabled = false,
			player = true,
			target = true,
			focus = true,
			size = 38,
			spacing = 3,
			numbers = true,
			tags = true,
			locked = true,
			say = { player = false, target = true, focus = true },
			cats = {
				player = { stun = true, kidney = true, incap = true, fear = true, silence = true, root = true, charm = true, procstun = true, procroot = true, horror = true },
				target = { stun = true, kidney = true, incap = true, fear = true, silence = true, root = true, charm = true, procstun = true, procroot = true, horror = true },
				focus = { stun = true, kidney = true, incap = true, fear = true, silence = true, root = true, charm = true, procstun = true, procroot = true, horror = true },
			},
			spots = {},
		},

		pulseDown = {
			enabled = false,
			locked = true,
			x = 0,
			y = 120,
			size = 56,
			alpha = 1,
			mode = "queue",
			showName = false,
			minCd = 2.5,
			ignore = "Hearthstone, 6948",
			inA = "pop",
			hold = "still",
			outA = "grow",
			tin = 0.3,
			thold = 0.9,
			tout = 0.6,
			shape = "rounded",
			style = "thin",
			banim = "drawin",
			color = "category",
			cats = { class = true, charges = true, racial = true, pet = true, profession = true, trinket = true, equipped = true, potion = true, healthstone = true, usable = true },
		},

		trinketMenu = {
			enabled = false,
			locked = true,
			PositionX = -300,
			PositionY = -120,
			orientation = "vertical",
			swapOrder = false,
			iconSize = 36,
			spacing = 4,
			showSet = true,
			flyout = true,
			tooltips = true,
			cooldownNumbers = true,
			fade = false,
			fadeAlpha = 0.25,
			fadeDelay = 3,
			collapse = false,
			activeSet = 1,
			sets = { {}, {}, {} },
			showGear = false,
			gearMain = "",
			gearAlt = "",
			showWeapon = false,
			weapons = { {}, {} },
			readyGlow = true,
		},

		notices = {
			enabled = false,
			flash = true,
			chat = true,
			duel = true,
			summon = true,
			resurrect = true,
			invite = true,
			queue = true,
			readyCheck = true,
			durability = true,
			durabilityThreshold = 20,
		},

		footsteps = {
			enabled = false,
			showMinimap = true,
			showWorldMap = true,
			rotation = "auto",
			dotSize = 4,
			spacing = 3,
			ageFade = true,
			color = { r = 1, g = 0.82, b = 0.2 },
		},

		castFeed = {
			enabled = false,
			locked = true,
			iconSize = 32,
			spacing = 4,
			speed = 60,
			catchUp = 4,
			length = 400,
			maxIcons = 12,
			showInstants = true,
			auraDisplay = false,
			showGaps = false,
			gapFontSize = 10,
			animQuality = "normal",
			baseline = true,
			showClass = true,
			rows = {
				player = { enabled = true, direction = "left", scale = 1, PositionX = 0, PositionY = -150 },
				target = { enabled = true, direction = "left", scale = 1, PositionX = 0, PositionY = -198 },
				focus = { enabled = true, direction = "left", scale = 1, PositionX = 0, PositionY = -246 },
				party1 = { enabled = true, direction = "left", scale = 1, PositionX = 0, PositionY = -294 },
				party2 = { enabled = true, direction = "left", scale = 1, PositionX = 0, PositionY = -342 },
				party3 = { enabled = true, direction = "left", scale = 1, PositionX = 0, PositionY = -390 },
				party4 = { enabled = true, direction = "left", scale = 1, PositionX = 0, PositionY = -438 },
				enemies = { enabled = false, direction = "left", scale = 1, PositionX = 0, PositionY = -486 },
			},
		},

		spellTracker = {
			locked = true,
			showTimerText = true,
			showBorderTimer = false,
			showCooldownText = true,
			showReadyText = false,
			deleteWithoutConfirm = false,
			animQuality = "normal",
			plateEnabled = false,
			plateSize = 24,
			plateSpacing = 3,
			plateOffset = 4,
			plateFollowScale = true,
			plateShowIdle = false,
			plateMax = 4,
			plateFallback = "screen",
			skullSize = 36,
			skullArt = "skull",
			skullPop = false,
			icons = {},
		},

		battlegroundAlertsEnabled = false,

		flagPickupAudio = true,
		flagDropAudio = true,
		flagCaptureAudio = true,
		flagReturnAudio = false,
		baseAssaultAudio = true,
		baseTakenAudio = true,
		baseDefendAudio = true,

		flagToastsEnabled = true,
		flagToastsUseClassIcons = true,
		flagToastDisplayDuration = 5.0,

		flagToasts = {
			positionX = 0,
			positionY = -300,
			maxConcurrent = 3,
		},

		flagTeamBackgroundColors = true,
		flagEnemyRedBackground = true,
		flagFriendlyGreenBackground = true,

		flagEnemyTexture = "Solid",
		flagFriendlyTexture = "Solid",

		flagChatEnabled = false,
		flagPickupChat = "#class# #player# has the flag!",
		flagDropChat = "#class# #player# dropped the flag",
		flagCaptureChat = "#player# captured the flag!",
		flagReturnChat = "#player# returned the flag",
		baseAssaultChat = "#base# #outcome# - #player#",
		baseTakenChat = "#base# #outcome#",
		baseDefendChat = "#base# #outcome# - #player#",

		flagOnlyEnemyTeam = true,
		flagOnlyFriendlyTeam = false,
		flagAllActions = false,

		persistentClassCache = {},
		persistentCacheEnabled = true,
		persistentCacheMaxSize = 500,
		persistentCacheMaxAge = 2592000,

		statistics = {
			enabled = true,
			overviewMode = "all",
			bgPill = true,
			bgDebrief = true,

			session = {
				totalAlerts = 0,
				startTime = 0,
				sessionNumber = 0,
				byCategory = {
					spellAlerts = 0,
					proximityAlerts = 0,
					trinketAlerts = 0,
					interruptAlerts = 0,
					flagAlerts = 0,
					awarenessAlerts = 0,
					lossOfControlAlerts = 0,
					watchlistAlerts = 0,
					chatAlerts = 0,
					noticeAlerts = 0,
				},
				byClass = {},
				enemiesEncountered = {},
				spellsThisSession = {},
			},

			allTime = {
				totalAlerts = 0,
				totalSessions = 0,

				topSpells = {},

				byCategory = {
					spellAlerts = 0,
					proximityAlerts = 0,
					trinketAlerts = 0,
					interruptAlerts = 0,
					flagAlerts = 0,
					awarenessAlerts = 0,
					lossOfControlAlerts = 0,
					watchlistAlerts = 0,
					chatAlerts = 0,
					noticeAlerts = 0,
				},

				byZone = {
					arena = 0,
					battleground = 0,
					worldPvP = 0,
				},

				playerTracking = {

					enemies = {},

					classSummary = {},
				},
			},

			maxTopSpells = 50,
			trackingStartTime = 0,
		},
	}
}

SA_Modules = {}

do
	local Modules = SA_Modules
	local entries, byKey, byModule = {}, {}, {}
	local profile, addon
	local listeners, pending = {}, {}
	local batching = 0

	local function IsEnabledPath(entry, path)
		local set = entry.enabledSet
		if not set then
			set = {}
			local list = entry.enabled
			if list then
				for i = 1, #list do set[list[i]] = true end
			end
			entry.enabledSet = set
		end
		return set[path]
	end

	local function Notify(key, on)
		for i = 1, #listeners do listeners[i](key, on) end
	end

	local function Flatten(source, prefix, parts, out)
		for name, value in pairs(source) do
			local path = prefix and (prefix .. "." .. tostring(name)) or tostring(name)
			local here = {}
			for i = 1, #parts do here[i] = parts[i] end
			here[#here + 1] = name
			out[path] = here
			if type(value) == "table" then Flatten(value, path, here, out) end
		end
	end

	local function Paths(entry)
		local paths = entry.paths
		if paths then return paths end
		paths = {}
		local source = dbDefaults and dbDefaults.profile or {}
		if entry.flat then
			for i = 1, #entry.flat do
				local name = entry.flat[i]
				local value = source[name]
				paths[name] = { name }
				if type(value) == "table" then Flatten(value, name, { name }, paths) end
			end
		else
			Flatten(source[entry.db] or {}, nil, {}, paths)
		end
		entry.paths = paths
		return paths
	end

	local function Bind(entry)
		local root = profile
		if not entry.flat then root = profile[entry.db] end
		entry.module.db = root
		return root
	end

	local function SetSetting(module, path, value)
		local entry = byModule[module]
		local parts = Paths(entry)[path]
		if not parts then
			error(entry.key .. ":SetSetting - unknown setting key '" .. tostring(path) .. "'", 2)
		end
		if entry.check and not entry.check(path, value) then
			error(entry.key .. ":SetSetting - bad setting '" .. tostring(path) .. "'", 2)
		end
		local node = module.db or Bind(entry)
		local last = #parts
		for i = 1, last - 1 do
			local key = parts[i]
			local child = node[key]
			if child == nil then
				child = {}
				node[key] = child
			end
			node = child
		end
		node[parts[last]] = value
		if entry.started then
			if batching > 0 then
				pending[entry] = true
			else
				module:Apply(path)
			end
		end
		if IsEnabledPath(entry, path) then Notify(entry.key, value) end
	end
	Modules.SetSetting = SetSetting

	function Modules.Owns(module, path)
		local entry = byModule[module]
		return entry ~= nil and (entry.db ~= nil or entry.flat ~= nil) and Paths(entry)[path] ~= nil
	end

	function Modules.Batch(fn)
		batching = batching + 1
		local ok, err = pcall(fn)
		batching = batching - 1
		if batching == 0 then
			for i = 1, #entries do
				local entry = entries[i]
				if pending[entry] then
					pending[entry] = nil
					if entry.started then entry.module:Apply(nil) end
				end
			end
		end
		if not ok then error(err, 0) end
	end

	function Modules.OnEnabledChanged(fn)
		if type(fn) ~= "function" then error("SA_Modules.OnEnabledChanged needs a function", 2) end
		listeners[#listeners + 1] = fn
	end

	function Modules.Register(entry)
		local key, module = entry.key, entry.module
		if type(key) ~= "string" or type(module) ~= "table" then error("SA_Modules.Register needs a key and a module", 2) end
		if byKey[key] then error("SA_Modules.Register - '" .. key .. "' is registered twice", 2) end
		entries[#entries + 1] = entry
		byKey[key] = entry
		byModule[module] = entry
		if entry.db or entry.flat then module.SetSetting = SetSetting end
		return module
	end

	function Modules.Bind(current, owner)
		profile = current
		if owner then addon = owner end
	end

	local function Fail(entry, err)
		local message = tostring(err)
		entry.started, entry.dropped = false, true
		if addon then
			if addon.Print then addon:Print("|cffFF7D0ASoundAlerter|r: " .. entry.key .. " failed to initialize and has been disabled for this session — " .. message) end
			if addon.moduleInitErrors then addon.moduleInitErrors[entry.key] = message end
			if addon[entry.key] == entry.module then addon[entry.key] = nil end
		end
	end

	local function Run(entry, hook)
		local module = entry.module
		if addon then module.addon = addon end
		if entry.db or entry.flat then Bind(entry) end
		local ok, err = pcall(hook, module)
		if not ok then Fail(entry, err) end
		return ok
	end

	local function Initialize(module)
		module:Initialize()
		module:Apply(nil)
	end

	local function Reapply(module)
		module:Apply(nil)
	end

	function Modules.Start(current, owner)
		Modules.Bind(current, owner)
		for i = 1, #entries do
			local entry = entries[i]
			if not entry.dropped and not entry.started then
				entry.started = Run(entry, entry.start or Initialize)
			end
		end
	end

	function Modules.ApplyProfile(current)
		profile = current
		for i = 1, #entries do
			local entry = entries[i]
			if entry.started then Run(entry, entry.profile or Reapply) end
		end
		Notify(nil, nil)
	end

	function Modules.Entries()
		return entries
	end

	function Modules.Entry(key)
		return byKey[key]
	end
end
