dbDefaults = {
	profile = {
		sapath = SA_LOCALEPATH[GetLocale()] or "Interface\\Addons\\SoundAlerter\\voice\\",
		debugmode = false,
		spelldebug = false,

		quickStartEnabled = false,
		showDeveloperTools = false,
		objectiveAlertsEnabled = false,

		findSpell = {
			autoSearch = false,
			sortMode = "name",
		},

		MinimapButtonPosition = nil,
		MinimapButtonHidden = false,

		all = false,
		arena = true,
		battleground = true,
		field = true,

		myself = true,
		ArenaPartner = false,
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
		cycloneenemy = true,
		fearenemy = true,
		hexenemy = true,
		polyenemy = true,
		sapenemy = true,

		bubbleenemy = true,
		stealthenemy = true,
		prowlhenemy = true,
		vanishalert = true,

		interruptenemy = true,
		enemyinterrupts = true,

		blindselffriend = true,
		cycloneselffriend = true,
		fearselffriend = true,
		hexselffriend = true,
		sapselffriend = true,

		caonlyTF = true,
		vanishTF = true,
		stealthTF = true,
		prowlTF = true,

		aruaApplied = false,
		auraRemoved = false,
		castStart = false,
		castSuccess = false,
		interrupt = false,

		PresenceofMind = false,
		starfire = false,
		lavaburst = false,

		chatdownfriend = false,
		chatdownself = true,
		interruptself = false,
		trinketalert = false,
		sayspell = true,
		chatgroups = {["SAY"] = false, ["PARTY"] = true, ["RAID"] = false, ["BATTLEGROUND"] = true, ["NONE"] = false,},

		InterruptEnemyText = "Interrupted #enemy#'s #interruptedspellname# with #spell#.",
		InterruptSelfText = "#enemy# interrupted my #interruptedspellname# with #spell#.",

		friendchat = "#enemy# casted #spell# on #friend#",
		selfchat = "#enemy# casted #spell# on me!",
		enemychat = "#spell# up on #enemy#",
		enemybuffchat = "#enemy# casted #spell#",

		sapselftext = "I'm Sapped!",
		saptextself = "I'm Sapped!",
		sapfriendtext = "#friend# is Sapped!",

		blindtext = "#enemy# blinded me!",
		blindtextfriend = "#friend# Is Blinded!",

		bubbleenemytext = "#enemy# bubbled!",
		trinketalerttext = "[#enemy#] Trinketted!",

		custom = {},
		cspell = "",

		proximityEnabled = false,
		proximityWorld = false,
		proximityBattleground = false,
		proximityArena = false,
		proximityCooldown = 60,
		proximityChat = false,
		proximityChatText = "[#class#] #player# detected nearby!",
		showAdvancedProximity = false,

		proximityToasts = {
			enabled = false,
			displayDuration = 3.0,
			showPlayerName = true,
			useClassColors = true,
			maxConcurrent = 3,
			positionX = 0,
			positionY = -200,

			clickEnabled = true,
			enableClickToTarget = true,
			enableFocusTarget = true,
			rainbowBorder = false,
		},

		resourceBar = {
			locked = false,

			energyEnabled = false,
			energyPositionX = 0,
			energyPositionY = -120,
			energyScale = 1.0,
			energyTexture = "Interface\\TargetingFrame\\UI-StatusBar",
			energyColor = {r = 1, g = 1, b = 0.2},
			energyLowColor = {r = 1, g = 0.3, b = 0},
			lowEnergyThreshold = 15,
			showOverCapAlert = true,
			showLowEnergyAlert = true,

			rageEnabled = false,
			ragePositionX = 0,
			ragePositionY = -120,
			rageScale = 1.0,
			rageTexture = "Interface\\TargetingFrame\\UI-StatusBar",
			rageColor = {r = 1, g = 0.2, b = 0.2},
			rageLowColor = {r = 0.8, g = 0.1, b = 0.1},
			lowRageThreshold = 20,
			showLowRageAlert = false,

			healthEnabled = false,
			healthPositionX = 0,
			healthPositionY = -140,
			healthScale = 1.0,
			healthHeight = 20,
			healthTexture = "Interface\\TargetingFrame\\UI-StatusBar",
			healthColor = {r = 0.2, g = 1, b = 0.2},

			manaEnabled = false,
			manaPositionX = 0,
			manaPositionY = -100,
			manaScale = 1.0,
			manaTexture = "Interface\\TargetingFrame\\UI-StatusBar",
			manaColor = {r = 0.2, g = 0.5, b = 1},
			manaLowColor = {r = 0.1, g = 0.3, b = 0.8},
			lowManaThreshold = 20,
			showLowManaAlert = false,

			comboEnabled = false,
			comboPositionX = 0,
			comboPositionY = -85,
			comboScale = 1.0,
			comboStyle = "circle",
			comboActiveColor = {r = 0.2, g = 1, b = 0.2},
			comboMaxColor = {r = 1, g = 0.8, b = 0.2},
			comboInactiveColor = {r = 0.25, g = 0.25, b = 0.25},

			comboTextEnabled = false,
			comboTextPositionX = 0,
			comboTextPositionY = -50,

			smoothPower = false,
			cpAnimations = true,
			fullCPAnimation = true,
			fullCPSound = false,

			barTexture = "default",
		},

		castingBars = {
			locked = false,
			barTexture = "default",
			timeFormat = "milliseconds",
			showSpellIcon = false,
			showLatency = false,

			player = {
				enabled = false,
				PositionX = 0,
				PositionY = -200,
				width = 280,
				height = 24,
			},

			target = {
				enabled = false,
				PositionX = 0,
				PositionY = -230,
				width = 280,
				height = 24,
			},

			focus = {
				enabled = false,
				PositionX = 0,
				PositionY = -260,
				width = 280,
				height = 24,
			},
		},

		spellTracker = {
			locked = false,
			showTimerText = true,
			showCooldownText = true,
			icons = {},
		},

		battlegroundAlertsEnabled = false,
		showAdvancedFlag = false,

		flagPickupAudio = true,
		flagDropAudio = true,
		flagCaptureAudio = true,
		flagReturnAudio = false,

		flagToastsEnabled = true,
		flagToastsUseClassIcons = true,
		flagToastDisplayDuration = 5.0,

		flagToasts = {
			positionX = 0,
			positionY = -300,
			maxConcurrent = 3,
		},

		flagRainbowBorder = true,

		flagTeamBackgroundColors = true,
		flagEnemyRedBackground = true,
		flagFriendlyGreenBackground = true,

		flagEnemyTexture = "Solid",
		flagFriendlyTexture = "Solid",

		flagChatEnabled = false,
		flagChatText = "#class# has the flag!",
		flagChatChannel = "SAY",

		flagOnlyEnemyTeam = true,
		flagOnlyFriendlyTeam = false,
		flagAllActions = false,

		persistentTeamCache = {},

		learnedClasses = {},
		learnedClassesEnabled = true,

		persistentClassCache = {},
		persistentCacheEnabled = true,
		persistentCacheMaxSize = 500,
		persistentCacheMaxAge = 2592000,
		learnedClassesMaxSize = 5000,
		negativeCacheEnabled = true,
		negativeCacheTTL = 5,

		showAdvancedStatistics = false,
		statistics = {
			enabled = true,

			session = {
				totalAlerts = 0,
				startTime = 0,
				sessionNumber = 0,
				byCategory = {
					spellAlerts = 0,
					proximityAlerts = 0,
					trinketAlerts = 0,
					flagAlerts = 0,
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
					flagAlerts = 0,
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
