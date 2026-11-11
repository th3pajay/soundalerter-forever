
local Statistics = SoundAlerter:NewModule("Statistics", "AceEvent-3.0")
SoundAlerter.Statistics = Statistics
local GetSpellInfo = SA_COMPAT.GetSpellInfo
local Plain = SA_COMPAT.Plain
local Format = SA_StatsFormat
local Venn = SA_StatsVenn
local Debrief = SA_DebriefModel
local METER_DELAY = 0.5
local activeMatch, activeStore
local matchVersion = 0
local buildNumber

local function clientBuild()
	if buildNumber == nil then
		local _, build = GetBuildInfo()
		buildNumber = Plain(build) or false
	end
	return buildNumber or nil
end

local function GetDB()
	return SoundAlerter.db1 and SoundAlerter.db1.profile
end

local function resolveClass(guid, name)
	local _, class = GetPlayerInfoByGUID(guid)
	if class then return class end
	return SA_Scoreboard.ClassFor(SoundAlerter.scoreboardClasses, name)
end

local STATISTICS_KEYS = {
	enabled = true,
	overviewMode = true,
}

function Statistics:GetSettings()
	local db = GetDB()
	db.statistics = db.statistics or {}
	return db.statistics
end

function Statistics:SetSetting(key, value)
	if not STATISTICS_KEYS[key] then
		error("Statistics:SetSetting - unknown setting key '"..tostring(key).."'", 2)
	end
	self:GetSettings()[key] = value
end

local STATS_CONSTANTS = {
	MAX_TOP_SPELLS = 50,
	MAX_ENEMIES = 100,
	MAX_SESSION_HISTORY = 50,
	MAX_PARTY_SENDERS = 20,
	MAX_DISPLAY_ROWS = 20,

	TREND_INCREASE_THRESHOLD = 1.2,
	TREND_DECREASE_THRESHOLD = 0.8,
}

Format.ClassColor = function(class)
	local color = RAID_CLASS_COLORS[class]
	if color then
		return math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5)
	end
	return 255, 255, 255
end

local dataVersion = 0

local spellNameCache = {}

local statisticsSortState = {
	topSpells = { sortType = "count_desc" },
	enemies = { sortType = "alerts_desc" },
	classes = { sortType = "alerts_desc" }
}

local function GetCachedSpellName(spellID)
	if not spellNameCache[spellID] then
		spellNameCache[spellID] = GetSpellInfo(spellID) or "Unknown"
	end
	return spellNameCache[spellID]
end

local function FormatClassName(class)
	if not class or class == "UNKNOWN" then return "Unknown" end
	return class:sub(1,1):upper() .. class:sub(2):lower()
end

local function GetTopClass(byClass)
	if not byClass then return "N/A" end

	local topClass = nil
	local maxCount = 0

	for class, count in pairs(byClass) do
		if count > maxCount then
			maxCount = count
			topClass = class
		end
	end

	if not topClass then return "N/A" end
	return topClass:sub(1,1):upper() .. topClass:sub(2):lower()
end

local function GetTopZone(byZone)
	if not byZone then return "N/A" end

	local topZone = nil
	local maxCount = 0

	for zone, count in pairs(byZone) do
		if count > maxCount then
			maxCount = count
			topZone = zone
		end
	end

	if not topZone then return "N/A" end

	local zoneNames = {
		arena = "Arena",
		battleground = "BG",
		worldPvP = "World",
		sanctuary = "City"
	}

	return zoneNames[topZone] or topZone
end

local function SortDesc(field)
	return function(a, b) return a[field] > b[field] end
end

local function SortAsc(field)
	return function(a, b) return a[field] < b[field] end
end

local function SortComposite(primary, secondary, primaryDesc)
	return function(a, b)
		if a[primary] == b[primary] then
			return a[secondary] > b[secondary]
		end
		return primaryDesc and a[primary] > b[primary] or a[primary] < b[primary]
	end
end

local SortStrategies = {
	topSpells = {
		count_desc = SortDesc("count"),
		count_asc = SortAsc("count"),
		name_asc = SortAsc("name"),
		name_desc = SortDesc("name"),
		trend = function(a, b)
			local trendWeight = { increasing = 3, stable = 2, decreasing = 1 }
			local wa = trendWeight[a.trend] or 2
			local wb = trendWeight[b.trend] or 2
			if wa == wb then
				return a.count > b.count
			end
			return wa > wb
		end,
		class = SortComposite("topClass", "count", false),
		zone = SortComposite("topZone", "count", false),
		time = SortDesc("lastSeen")
	},
	enemies = {
		alerts_desc = SortDesc("alerts"),
		alerts_asc = SortAsc("alerts"),
		name_asc = SortAsc("name"),
		name_desc = SortDesc("name"),
		danger = SortDesc("danger"),
		class = SortComposite("class", "alerts", false),
		zone = SortComposite("topZone", "alerts", false),
		time = SortDesc("lastSeen")
	},
	classes = {
		alerts_desc = SortDesc("alerts"),
		alerts_asc = SortAsc("alerts"),
		class_asc = SortAsc("class"),
		players = SortDesc("players"),
		avg = SortDesc("avgPerPlayer")
	}
}

local function SortStatisticsList(list, tableType, sortType)
	local strategy = SortStrategies[tableType] and SortStrategies[tableType][sortType]
	if strategy then
		table.sort(list, strategy)
	end
end

local function PrepareTopSpellsData()
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.allTime or not sadb.statistics.allTime.topSpells then
		return nil, "|cffFF0000No spell data available|r"
	end

	local topSpells = sadb.statistics.allTime.topSpells
	local spellList = {}
	local totalAlerts = 0
	for _, data in pairs(topSpells) do
		totalAlerts = totalAlerts + (data.count or 0)
	end

	for spellID, data in pairs(topSpells) do
		table.insert(spellList, {
			id = spellID,
			name = data.name or GetCachedSpellName(spellID),
			count = data.count,
			trend = data.trend and data.trend.direction or "stable",
			topClass = GetTopClass(data.byClass),
			topZone = GetTopZone(data.byZone),
			lastSeen = data.lastSeen,
			percentage = totalAlerts > 0 and (data.count / totalAlerts) * 100 or 0
		})
	end

	SortStatisticsList(spellList, "topSpells", statisticsSortState.topSpells.sortType)

	return spellList
end

local function PrepareEnemiesData()
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.allTime or not sadb.statistics.allTime.playerTracking then
		return nil, "|cffFF0000No enemy data available|r"
	end

	local enemies = sadb.statistics.allTime.playerTracking.enemies
	local enemyList = {}
	local totalAlerts = 0

	for name, data in pairs(enemies) do
		local topSpell = nil
		local topSpellCount = 0
		for spellID, count in pairs(data.spellsUsed) do
			if count > topSpellCount then
				topSpellCount = count
				topSpell = GetCachedSpellName(spellID)
			end
		end

		totalAlerts = totalAlerts + (data.totalAlerts or 0)

		table.insert(enemyList, {
			name = name,
			class = data.class,
			alerts = data.totalAlerts,
			danger = data.dangerRating or 0,
			topSpell = topSpell or "N/A",
			topZone = GetTopZone(data.byZone),
			lastSeen = data.lastSeen
		})
	end

	for _, enemyData in ipairs(enemyList) do
		enemyData.percentage = totalAlerts > 0 and (enemyData.alerts / totalAlerts) * 100 or 0
	end

	SortStatisticsList(enemyList, "enemies", statisticsSortState.enemies.sortType)

	return enemyList
end

local function PrepareClassDistributionData()
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.allTime or not sadb.statistics.allTime.playerTracking then
		return nil, "|cffFF0000No class data available|r"
	end

	local classSummary = sadb.statistics.allTime.playerTracking.classSummary
	local classList = {}
	local totalAlerts = 0

	local playerCountByClass = {}
	for _, enemyData in pairs(sadb.statistics.allTime.playerTracking.enemies) do
		local class = enemyData.class
		if class then
			playerCountByClass[class] = (playerCountByClass[class] or 0) + 1
		end
	end

	for class, data in pairs(classSummary) do
		local uniquePlayers = playerCountByClass[class] or 0

		local topSpell = nil
		local topSpellCount = 0
		for spellID, count in pairs(data.topSpells) do
			if count > topSpellCount then
				topSpellCount = count
				topSpell = GetCachedSpellName(spellID)
			end
		end

		totalAlerts = totalAlerts + data.totalAlerts

		table.insert(classList, {
			class = class,
			alerts = data.totalAlerts,
			players = uniquePlayers,
			avgPerPlayer = uniquePlayers > 0 and (data.totalAlerts / uniquePlayers) or 0,
			topSpell = topSpell or "N/A"
		})
	end

	for _, classData in ipairs(classList) do
		classData.percentage = totalAlerts > 0 and (classData.alerts / totalAlerts) * 100 or 0
	end

	SortStatisticsList(classList, "classes", statisticsSortState.classes.sortType)

	return classList
end

local viewCache = {}

local function cachedText(key, source, version, variant, builder)
	local entry = viewCache[key]
	if entry and entry.source == source and entry.version == version and entry.variant == variant then
		return entry.text
	end

	if not entry then
		entry = {}
		viewCache[key] = entry
	end
	entry.source = source
	entry.version = version
	entry.variant = variant
	entry.text = builder(key)
	return entry.text
end

local kpiScratch = {}

local function buildKpi()
	local stats = GetDB().statistics
	local session = stats.session or {}
	local allTime = stats.allTime or {}
	local minutes = math.max(0, math.floor((GetTime() - (session.startTime or 0)) / 60))
	local sessions = allTime.totalSessions or 0

	kpiScratch.sessionTotal = session.totalAlerts or 0
	kpiScratch.minutes = minutes
	kpiScratch.perMinute = minutes > 0 and kpiScratch.sessionTotal / minutes or 0
	kpiScratch.allTimeTotal = allTime.totalAlerts or 0
	kpiScratch.sessions = sessions
	kpiScratch.avgPerSession = sessions > 0 and kpiScratch.allTimeTotal / sessions or 0
	return Format.Kpi(kpiScratch)
end

local function buildList(key)
	local rows = STATS_CONSTANTS.MAX_DISPLAY_ROWS
	if key == "topSpells" then
		return Format.SpellRows(PrepareTopSpellsData(), rows)
	elseif key == "enemies" then
		return Format.EnemyRows(PrepareEnemiesData(), rows)
	end
	return Format.ClassRows(PrepareClassDistributionData(), rows)
end

local function buildExport()
	return Statistics:BuildExportString()
end

local clockDay, clockHour, clockUntil = 0, 0, 0

local function LocalClock()
	local now = time()
	if now < clockUntil and now >= clockUntil - 3600 then
		return clockDay, clockHour
	end
	local fields = date("*t", now)
	local intoHour = fields.min * 60 + fields.sec
	clockDay = math.floor((now - (fields.hour * 3600 + intoHour)) / 86400 + 0.5)
	clockHour = fields.hour
	clockUntil = now + 3600 - intoHour
	return clockDay, clockHour
end

local PANEL_RIVALS = 6
local PANEL_SENDERS = 3
local panelEnemies, panelSenders = {}, {}
local panelNewest = {}

local function pushTop(list, limit, entry, before)
	local count = #list
	local at = count + 1
	for index = 1, count do
		if before(entry, list[index]) then
			at = index
			break
		end
	end
	if at > limit then return end
	local spare = count >= limit and list[count] or nil
	if spare then
		list[count] = nil
		count = count - 1
	end
	for index = count, at, -1 do list[index + 1] = list[index] end
	list[at] = entry
	return spare
end

local function enemyFirst(a, b)
	if a.alerts ~= b.alerts then return a.alerts > b.alerts end
	return a.name < b.name
end

local function senderFirst(a, b)
	if a[2] ~= b[2] then return a[2] > b[2] end
	return a[1] < b[1]
end

local function buildPanel()
	local sadb = GetDB()
	local stats = sadb.statistics
	local session, allTime = stats.session or {}, stats.allTime or {}
	local minutes = math.max(0, math.floor((GetTime() - (session.startTime or 0)) / 60))
	local sessionTotal = session.totalAlerts or 0
	local data = {
		now = time(),
		sessionTotal = sessionTotal,
		minutes = minutes,
		perMinute = minutes > 0 and sessionTotal / minutes or 0,
		sessionNumber = session.sessionNumber or 0,
		sessions = allTime.totalSessions or 0,
		allTotal = allTime.totalAlerts or 0,
	}

	local spells = {}
	for _, spell in pairs(allTime.topSpells or {}) do
		local trend = spell.trend
		local direction = trend and trend.direction
		if direction == "increasing" or direction == "decreasing" then
			spells[#spells + 1] = { name = spell.name or "Unknown", direction = direction, last = trend.lastSessionCount, avg = trend.avgPerSession }
		end
	end
	data.spells = spells

	local enemies = panelEnemies
	for index = #enemies, 1, -1 do enemies[index] = nil end
	local spare, newest, newestAt = nil, panelNewest, -1
	for name, enemy in pairs((allTime.playerTracking or {}).enemies or {}) do
		local alerts = enemy.totalAlerts or 0
		local seen = enemy.lastSeen or 0
		if seen > newestAt then
			newestAt = seen
			newest.name, newest.class, newest.last = name, enemy.class, seen
		end
		local entry = spare or {}
		entry.name, entry.class, entry.alerts, entry.danger = name, enemy.class, alerts, enemy.dangerRating or 0
		entry.encounters, entry.last = enemy.encounterCount or 0, seen
		spare = pushTop(enemies, PANEL_RIVALS, entry, enemyFirst)
		if spare == nil and enemies[#enemies] ~= entry then spare = entry end
	end
	data.enemies = enemies
	data.lastEnemy = newestAt >= 0 and newest or nil

	local classes = {}
	for class, entry in pairs((allTime.playerTracking or {}).classSummary or {}) do
		classes[#classes + 1] = { class = class, alerts = entry.totalAlerts or 0, players = entry.uniquePlayers or 0 }
	end
	data.classes = classes

	local sessionParty, allParty = session.party or {}, allTime.party or {}
	local senders = panelSenders
	for index = #senders, 1, -1 do senders[index] = nil end
	local sparePair
	for name, count in pairs(allParty.bySender or {}) do
		local pair = sparePair or {}
		pair[1], pair[2] = name, count
		sparePair = pushTop(senders, PANEL_SENDERS, pair, senderFirst)
		if sparePair == nil and senders[#senders] ~= pair then sparePair = pair end
	end
	data.party = {
		sessionSent = sessionParty.sent or 0, sessionReceived = sessionParty.received or 0,
		allSent = allParty.sent or 0, allReceived = allParty.received or 0,
		senders = senders, sending = sadb.shareAlertsSend and true or false, receiving = sadb.shareAlertsReceive and true or false,
	}

	data.days = Format.ActivityDays(allTime.activity, (LocalClock()))
	data.hours = allTime.activity and allTime.activity.hours or {}
	return Format.PanelModel(data)
end

local function trackedStatistics()
	local sadb = GetDB()
	local stats = sadb and sadb.statistics
	if stats and stats.enabled and stats.session and stats.allTime then
		return stats
	end
	return nil
end

function Statistics:GetKpiText()
	local stats = trackedStatistics()
	if not stats then return "" end
	local minutes = math.floor((GetTime() - (stats.session.startTime or 0)) / 60)
	return cachedText("kpi", stats, dataVersion, minutes, buildKpi)
end

function Statistics:GetListText(tableType)
	local stats = trackedStatistics()
	if not stats then return "" end
	return cachedText(tableType, stats, dataVersion, statisticsSortState[tableType].sortType, buildList)
end

function Statistics:GetPanelModel()
	local stats = trackedStatistics()
	if not stats then return nil end
	local minutes = math.floor((GetTime() - (stats.session.startTime or 0)) / 60)
	return cachedText("panel", stats, dataVersion, minutes, buildPanel)
end

local vennPool = {}
local vennGeneration = 0

local function buildVenn()
	local allTime = GetDB().statistics.allTime or {}
	local entries = {}
	vennGeneration = vennGeneration + 1
	for spellID, spell in pairs(allTime.topSpells or {}) do
		local category = spell.spellCategory or "Other"
		local entry = vennPool[spellID]
		if not entry then
			entry = { id = spellID }
			vennPool[spellID] = entry
		end
		entry.generation = vennGeneration
		entry.name, entry.total, entry.category = spell.name or "Unknown Spell", spell.count or 0, category
		entry.mask, entry.group = Venn.MaskOf(spell.byZone), Venn.GroupOf(category)
		entry.byZone, entry.byClass = spell.byZone, spell.byClass
		entries[#entries + 1] = entry
	end
	for spellID, entry in pairs(vennPool) do
		if entry.generation ~= vennGeneration then vennPool[spellID] = nil end
	end
	return entries
end

function Statistics:GetVennData()
	local stats = trackedStatistics()
	if not stats then return nil end
	return cachedText("venn", stats, dataVersion, 0, buildVenn)
end

function Statistics:GetExportText()
	local stats = trackedStatistics()
	if not stats then return "" end
	return cachedText("export", stats, dataVersion, matchVersion, buildExport)
end

local matchLimit

local function buildMatches()
	local matches = GetDB().statistics.matches or {}
	return Debrief.Rows(matches.list, matches.open, time(), GetTime(), Format.Ago, matchLimit)
end

function Statistics:GetMatchText(limit)
	local stats = trackedStatistics()
	if not stats then return "" end
	matchLimit = limit
	return cachedText(limit and "matchesShort" or "matches", stats, dataVersion + matchVersion, math.floor(time() / 60), buildMatches)
end

function Statistics:GetMatchCount()
	local matches = GetDB().statistics.matches
	return matches and matches.list and #matches.list or 0
end

function Statistics:Version()
	return dataVersion, matchVersion
end

local function buildCounts()
	local allTime = GetDB().statistics.allTime or {}
	local tracking = allTime.playerTracking or {}
	local counts = { topSpells = 0, enemies = 0, classes = 0 }
	for _ in pairs(allTime.topSpells or {}) do counts.topSpells = counts.topSpells + 1 end
	for _ in pairs(tracking.enemies or {}) do counts.enemies = counts.enemies + 1 end
	for _ in pairs(tracking.classSummary or {}) do counts.classes = counts.classes + 1 end
	return counts
end

function Statistics:GetListCounts()
	local stats = trackedStatistics()
	if not stats then return nil end
	return cachedText("counts", stats, dataVersion, 0, buildCounts)
end

local dashboardMode = "all"

local function spellCountOf(spell)
	return spell.count
end

local function enemyCountOf(enemy)
	return enemy.totalAlerts
end

local function buildDashboard()
	local stats = GetDB().statistics
	local session, allTime = stats.session or {}, stats.allTime or {}
	local topSpells = allTime.topSpells or {}
	local enemies = (allTime.playerTracking or {}).enemies or {}
	local won, total = Debrief.Tally(stats.matches and stats.matches.list)
	return Format.Dashboard({
		mode = dashboardMode,
		session = { total = session.totalAlerts, byCategory = session.byCategory, byZone = session.byZone, spells = session.spellsThisSession, enemies = session.enemiesEncountered },
		allTime = { total = allTime.totalAlerts, byCategory = allTime.byCategory, byZone = allTime.byZone, spells = topSpells, enemies = enemies, spellCount = spellCountOf, enemyCount = enemyCountOf },
		sessions = allTime.totalSessions or 0,
		classOf = function(name) return enemies[name] and enemies[name].class end,
		spellName = function(spellID) return topSpells[spellID] and topSpells[spellID].name or GetCachedSpellName(spellID) end,
		record = total > 0 and { won = won, total = total } or nil,
	})
end

function Statistics:GetDashboard(mode)
	local stats = trackedStatistics()
	if not stats then return nil end
	dashboardMode = mode == "session" and "session" or "all"
	return cachedText("dashboard", stats, dataVersion + matchVersion, dashboardMode, buildDashboard)
end

local function spellNameOf(spellID)
	local allTime = GetDB().statistics.allTime
	local spell = allTime and allTime.topSpells and allTime.topSpells[spellID]
	return spell and spell.name or GetCachedSpellName(spellID)
end

local function meterSource(meterType)
	local guid = Plain(UnitGUID("player"))
	if not guid then return nil end
	local ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, Enum.DamageMeterSessionType.Overall, meterType, guid)
	if not ok then return nil end
	source = Plain(source)
	return type(source) == "table" and source or nil
end

local function meterAvailable()
	if not (C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable and C_DamageMeter.GetCombatSessionSourceFromType) then
		return false, "this client has no damage meter"
	end
	if not (Enum and Enum.DamageMeterSessionType and Enum.DamageMeterType) then
		return false, "this client has no damage meter"
	end
	local ok, available, reason = pcall(C_DamageMeter.IsDamageMeterAvailable)
	if not ok then return false, "the check failed" end
	return Plain(available) == true, Plain(reason)
end

local function readMeter()
	if InCombatLockdown() or not meterAvailable() then return nil end
	local damageSource = meterSource(Enum.DamageMeterType.DamageDone)
	local damage = damageSource and Plain(damageSource.totalAmount)
	if type(damage) ~= "number" then return nil end
	local healingSource = meterSource(Enum.DamageMeterType.HealingDone)
	local healing = healingSource and Plain(healingSource.totalAmount)
	local reading = { damage = damage, healing = type(healing) == "number" and healing or 0, spells = {} }
	local list = Plain(damageSource.combatSpells)
	if type(list) == "table" then
		for _, entry in ipairs(list) do
			entry = Plain(entry)
			local spellID = type(entry) == "table" and Plain(entry.spellID)
			local amount = spellID and Plain(entry.totalAmount)
			if type(spellID) == "number" and type(amount) == "number" then
				reading.spells[spellID] = (reading.spells[spellID] or 0) + amount
			end
		end
	end
	return reading
end

function Statistics:PrintMeter()
	local available, reason = meterAvailable()
	if not available then
		SoundAlerter:Print("Damage meter: not available" .. (reason and reason ~= "" and (" (" .. tostring(reason) .. ")") or ""))
		return
	end
	if InCombatLockdown() then
		SoundAlerter:Print("Damage meter: available. The numbers are hidden in combat, try again after the fight.")
		return
	end
	local reading = readMeter()
	if not reading then
		SoundAlerter:Print("Damage meter: available, but it has nothing readable for you yet.")
		return
	end
	local spells = 0
	for _ in pairs(reading.spells) do spells = spells + 1 end
	SoundAlerter:Print("Damage meter: damage " .. Debrief.Amount(reading.damage) .. " from " .. spells ..
		" spells, healing " .. Debrief.Amount(reading.healing) .. " this session.")
end

function Statistics:OnMeterCombatEnded()
	if self.meterPending then return end
	self.meterPending = true
	C_Timer.After(METER_DELAY, function()
		self.meterPending = false
		if activeMatch and Debrief.Meter(activeMatch, readMeter()) then matchVersion = matchVersion + 1 end
	end)
end

function Statistics:OnMatchComplete(_, winner, duration)
	local match = activeMatch
	if not match then return end
	winner, duration = Plain(winner), Plain(duration)
	local shuffle = C_PvP and C_PvP.IsSoloShuffle and select(2, pcall(C_PvP.IsSoloShuffle))
	local team = GetBattlefieldArenaFaction and Plain(GetBattlefieldArenaFaction())
	SoundAlerter:Debug("Statistics", "match complete: winner %s, your team %s, length %s", tostring(winner), tostring(team), tostring(duration))
	if Plain(shuffle) == true then winner = nil end
	if Debrief.Result(match, winner, team, duration) then matchVersion = matchVersion + 1 end
end

function Statistics:WatchControl(on)
	if on == (self.watchingControl or false) then return end
	self.watchingControl = on
	if on then
		pcall(self.RegisterEvent, self, "LOSS_OF_CONTROL_ADDED", "OnControlAdded")
		pcall(self.RegisterEvent, self, "LOSS_OF_CONTROL_UPDATE", "OnControlUpdate")
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnMeterCombatEnded")
		pcall(self.RegisterEvent, self, "PVP_MATCH_COMPLETE", "OnMatchComplete")
	else
		pcall(self.UnregisterEvent, self, "LOSS_OF_CONTROL_ADDED")
		pcall(self.UnregisterEvent, self, "LOSS_OF_CONTROL_UPDATE")
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		pcall(self.UnregisterEvent, self, "PVP_MATCH_COMPLETE")
	end
end

local function closeMatch(matches, now, clock)
	Debrief.Meter(matches.open, readMeter())
	local record = Debrief.Close(matches.open, now, clock, spellNameOf)
	if record then Debrief.Push(matches.list, record) end
	matches.open = nil
end

function Statistics:UpdateMatch()
	local stats = GetDB() and GetDB().statistics
	local now, clock = time(), GetTime()
	local previous = activeMatch
	if activeStore and activeStore.open and activeStore ~= (stats and stats.matches) then
		closeMatch(activeStore, now, clock)
	end
	activeMatch, activeStore = nil, nil
	if not trackedStatistics() then
		if stats and stats.matches then stats.matches.open = nil end
		self:WatchControl(false)
		if previous then matchVersion = matchVersion + 1 end
		return
	end
	local matches = stats.matches
	if not matches then
		matches = { list = {} }
		stats.matches = matches
	end
	local _, instanceType = IsInInstance()
	local kind = Debrief.KindOf(instanceType)
	local zone = kind and (GetInstanceInfo and Plain((GetInstanceInfo())) or Plain(GetRealZoneText())) or nil
	if matches.open and not Debrief.Continues(matches.open, kind, zone, now) then
		closeMatch(matches, now, clock)
	elseif matches.open then
		Debrief.Sync(matches.open, clock)
		if Debrief.ControlEnded(matches.open, clock) then matchVersion = matchVersion + 1 end
	end
	if kind and not matches.open then
		matches.open = Debrief.Open(kind, zone, now, clientBuild())
		Debrief.Meter(matches.open, readMeter())
	end
	activeMatch, activeStore = matches.open, matches
	self:WatchControl(activeMatch ~= nil)
	if activeMatch ~= previous then matchVersion = matchVersion + 1 end
end

function Statistics:ChangeProfile()
	self:UpdateMatch()
end

local function hardControlEntry(slot)
	local ok, data = pcall(C_LossOfControl.GetActiveLossOfControlData, slot)
	if not ok or type(data) ~= "table" then return nil end
	local locType = Plain(data.locType)
	if locType == nil then return nil, true end
	if not Debrief.HARD_CONTROL[SA_LossOfControl.Category(locType)] then return nil end
	return data
end

function Statistics:OnControlAdded(_, first, second)
	local match = activeMatch
	if not match or not C_LossOfControl then return end
	local slot = SA_LossOfControl.PlayerIndex(Plain(first), Plain(second))
	if not slot then return end
	local data = hardControlEntry(slot)
	if not data then return end
	Debrief.Control(match, GetTime(), Plain(data.timeRemaining), Plain(data.duration))
	matchVersion = matchVersion + 1
end

function Statistics:OnControlUpdate(_, unit)
	local match = activeMatch
	if not match or not C_LossOfControl or not SA_LossOfControl.ForPlayer(Plain(unit)) then return end
	local clock = GetTime()
	if match.cc.untilAt <= clock then return end
	local ok, count = pcall(C_LossOfControl.GetActiveLossOfControlDataCount)
	count = ok and Plain(count) or nil
	if type(count) ~= "number" then return end
	local latest = clock
	for slot = 1, count do
		local data, unknown = hardControlEntry(slot)
		if unknown then return end
		if data then
			local remaining = Plain(data.timeRemaining)
			if type(remaining) ~= "number" then return end
			if clock + remaining > latest then latest = clock + remaining end
		end
	end
	if Debrief.Trim(match, clock, latest) then matchVersion = matchVersion + 1 end
end

local function newSession(number)
	return {
		totalAlerts = 0,
		startTime = GetTime(),
		sessionNumber = number,
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
		byZone = {},
		enemiesEncountered = {},
		spellsThisSession = {},
		party = { sent = 0, received = 0, bySender = {} },
	}
end

local function newAllTime()
	return {
		totalAlerts = 0,
		totalSessions = 1,
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
		party = { sent = 0, received = 0, bySender = {} },
		activity = Format.NewActivity(),
	}
end

function Statistics:ResetSession()
	local sadb = GetDB()
	if not sadb or not sadb.statistics then return end
	local allTime = sadb.statistics.allTime
	sadb.statistics.session = newSession(allTime and allTime.totalSessions or 1)
	dataVersion = dataVersion + 1
end

function Statistics:ResetAllTime()
	local sadb = GetDB()
	if not sadb or not sadb.statistics then return end
	sadb.statistics.allTime = newAllTime()
	sadb.statistics.session = newSession(1)
	sadb.statistics.trackingStartTime = time()
	sadb.statistics.matches = nil
	dataVersion = dataVersion + 1
	self:UpdateMatch()
end

function Statistics:RecordAlert(category, spellID, sourceGUID, sourceName, spellSchool, sourceClass)
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.enabled then return end

	dataVersion = dataVersion + 1
	sadb.statistics.session.totalAlerts = (sadb.statistics.session.totalAlerts or 0) + 1
	sadb.statistics.session.byCategory[category] = (sadb.statistics.session.byCategory[category] or 0) + 1
	if activeMatch then Debrief.Record(activeMatch, category, category == "spellAlerts" and spellID or nil, sourceName, time()) end

	sadb.statistics.allTime.totalAlerts = (sadb.statistics.allTime.totalAlerts or 0) + 1
	sadb.statistics.allTime.byCategory[category] = (sadb.statistics.allTime.byCategory[category] or 0) + 1
	self:RecordActivity(sadb.statistics.allTime)

	local zoneType = self:GetCurrentZoneType()
	if zoneType then
		sadb.statistics.allTime.byZone[zoneType] = (sadb.statistics.allTime.byZone[zoneType] or 0) + 1
		local sessionZones = sadb.statistics.session.byZone
		if not sessionZones then
			sessionZones = {}
			sadb.statistics.session.byZone = sessionZones
		end
		sessionZones[zoneType] = (sessionZones[zoneType] or 0) + 1
	end

	if spellID and category == "spellAlerts" then
		self:UpdateTopSpells(spellID, sourceGUID, sourceName, spellSchool)
	end

	if sourceGUID and sourceName then
		self:TrackEnemyPlayer(sourceGUID, sourceName, spellID, sourceClass)
	end
end

function Statistics:RecordActivity(allTime)
	local activity = allTime.activity
	if not activity then
		activity = Format.NewActivity()
		allTime.activity = activity
	end
	local day, hour = LocalClock()
	Format.ActivityRecord(activity, day, hour)
end

local function CountSender(party, name)
	local senders = party.bySender
	if not senders then
		senders = {}
		party.bySender = senders
	end
	if senders[name] then
		senders[name] = senders[name] + 1
		return
	end
	local count, weakest, weakestCount = 0, nil, nil
	for key, value in pairs(senders) do
		count = count + 1
		if not weakestCount or value < weakestCount then weakest, weakestCount = key, value end
	end
	if count >= STATS_CONSTANTS.MAX_PARTY_SENDERS then senders[weakest] = nil end
	senders[name] = 1
end

local function CountParty(scope, direction, sender)
	local party = scope.party
	if not party then
		party = { sent = 0, received = 0, bySender = {} }
		scope.party = party
	end
	party[direction] = (party[direction] or 0) + 1
	if direction == "received" and sender then CountSender(party, sender) end
end

function Statistics:RecordParty(direction, sender)
	local stats = trackedStatistics()
	if not stats then return end
	dataVersion = dataVersion + 1
	CountParty(stats.session, direction, sender)
	CountParty(stats.allTime, direction, sender)
end

function Statistics:UpdateTopSpells(spellID, sourceGUID, sourceName, spellSchool)
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not spellID then return end

	local topSpells = sadb.statistics.allTime.topSpells
	local maxSpells = sadb.statistics.maxTopSpells or STATS_CONSTANTS.MAX_TOP_SPELLS
	local currentTime = time()
	local zoneType = self:GetCurrentZoneType()

	local sourceClass = sourceGUID and resolveClass(sourceGUID, sourceName) or nil
	if zoneType and SA_GlobalStats then SA_GlobalStats.Note(spellID, zoneType) end

	if topSpells[spellID] then
		local spell = topSpells[spellID]
		spell.count = spell.count + 1
		spell.lastSeen = currentTime

		if sourceClass then
			spell.byClass = spell.byClass or {}
			spell.byClass[sourceClass] = (spell.byClass[sourceClass] or 0) + 1
		end

		if zoneType then
			spell.byZone = spell.byZone or {}
			spell.byZone[zoneType] = (spell.byZone[zoneType] or 0) + 1
		end

		if spell.trend then
			spell.trend.currentSessionCount = spell.trend.currentSessionCount + 1
		end

	else

		local count = 0
		for _ in pairs(topSpells) do count = count + 1 end

		if count >= maxSpells then
			local lowestSpellID, lowestCount = nil, math.huge
			for sID, data in pairs(topSpells) do
				if data.count < lowestCount then
					lowestCount = data.count
					lowestSpellID = sID
				end
			end

			if lowestSpellID then
				topSpells[lowestSpellID] = nil
				SoundAlerter:Debug("Statistics", "top spells full, evicted spell %d (count %d)", lowestSpellID, lowestCount)
			end
		end

		local spellName = GetSpellInfo(spellID) or "Unknown Spell"
		topSpells[spellID] = {
			count = 1,
			name = spellName,
			lastSeen = currentTime,
			firstSeen = currentTime,
			trend = {
				lastSessionCount = 0,
				currentSessionCount = 1,
				avgPerSession = 0,
				direction = "stable"
			},
			byClass = sourceClass and { [sourceClass] = 1 } or {},
			byZone = zoneType and { [zoneType] = 1 } or {},
			spellSchool = self:SpellSchoolName(spellSchool),
			spellCategory = self:GetSpellCategory(spellID),
			sessionHistory = {}
		}
	end

	if sadb.statistics.session then
		sadb.statistics.session.spellsThisSession[spellID] = (sadb.statistics.session.spellsThisSession[spellID] or 0) + 1
	end
end

function Statistics:TrackEnemyPlayer(sourceGUID, sourceName, spellID, knownClass)
	local sadb = GetDB()
	if not sourceGUID or not sourceName then return end
	if not sadb or not sadb.statistics or not sadb.statistics.enabled then return end

	if not sadb.statistics.allTime.playerTracking then
		sadb.statistics.allTime.playerTracking = {
			enemies = {},
			classSummary = {}
		}
	end

	local playerTracking = sadb.statistics.allTime.playerTracking
	local enemies = playerTracking.enemies
	local currentTime = time()
	local zoneType = self:GetCurrentZoneType()

	local sourceClass = knownClass or resolveClass(sourceGUID, sourceName) or "UNKNOWN"

	if enemies[sourceName] then
		local enemy = enemies[sourceName]
		enemy.totalAlerts = enemy.totalAlerts + 1
		enemy.lastSeen = currentTime
		enemy.class = sourceClass

		if spellID then
			enemy.spellsUsed[spellID] = (enemy.spellsUsed[spellID] or 0) + 1
		end

		if zoneType then
			enemy.byZone[zoneType] = (enemy.byZone[zoneType] or 0) + 1
		end

		enemy.dangerRating = enemy.totalAlerts / math.max(1, enemy.encounterCount)

	else
		enemies[sourceName] = {
			totalAlerts = 1,
			class = sourceClass,
			lastSeen = currentTime,
			firstSeen = currentTime,
			spellsUsed = spellID and { [spellID] = 1 } or {},
			byZone = zoneType and { [zoneType] = 1 } or {},
			dangerRating = 1.0,
			encounterCount = 1
		}
	end

	if sourceClass and sourceClass ~= "UNKNOWN" then
		if not playerTracking.classSummary[sourceClass] then
			playerTracking.classSummary[sourceClass] = {
				totalAlerts = 0,
				uniquePlayers = 0,
				topSpells = {}
			}
		end

		local classSummary = playerTracking.classSummary[sourceClass]
		classSummary.totalAlerts = classSummary.totalAlerts + 1

		if spellID then
			classSummary.topSpells[spellID] = (classSummary.topSpells[spellID] or 0) + 1
		end
	end

	local met = sadb.statistics.session and sadb.statistics.session.enemiesEncountered
	local before = met and met[sourceName]
	if met then met[sourceName] = (type(before) == "number" and before or (before and 1 or 0)) + 1 end
	if met and not before then
		if enemies[sourceName] then
			enemies[sourceName].encounterCount = enemies[sourceName].encounterCount + 1
		end

		if sourceClass and sourceClass ~= "UNKNOWN" and playerTracking.classSummary[sourceClass] then
			playerTracking.classSummary[sourceClass].uniquePlayers = playerTracking.classSummary[sourceClass].uniquePlayers + 1
		end
	end

	if sadb.statistics.session then
		if sourceClass and sourceClass ~= "UNKNOWN" then
			sadb.statistics.session.byClass[sourceClass] = (sadb.statistics.session.byClass[sourceClass] or 0) + 1
		end
	end

	local enemyCount = 0
	for _ in pairs(playerTracking.enemies) do
		enemyCount = enemyCount + 1
		if enemyCount > STATS_CONSTANTS.MAX_ENEMIES then
			self:PruneEnemyTracking(STATS_CONSTANTS.MAX_ENEMIES, sourceName)
			break
		end
	end
end

local function weaker(aAlerts, aSeen, aName, bAlerts, bSeen, bName)
	if aAlerts ~= bAlerts then return aAlerts < bAlerts end
	if aSeen ~= bSeen then return aSeen < bSeen end
	return aName > bName
end

function Statistics:PruneEnemyTracking(maxEnemies, keepName)
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.allTime.playerTracking then return end

	local enemies = sadb.statistics.allTime.playerTracking.enemies

	local enemyCount = 0
	for _ in pairs(enemies) do enemyCount = enemyCount + 1 end

	if enemyCount > maxEnemies then
		for _ = 1, enemyCount - maxEnemies do
			local worstName, worstAlerts, worstSeen
			for name, data in pairs(enemies) do
				if name ~= keepName then
					local alerts, seen = data.totalAlerts, data.lastSeen or 0
					if worstName == nil or weaker(alerts, seen, name, worstAlerts, worstSeen, worstName) then
						worstName, worstAlerts, worstSeen = name, alerts, seen
					end
				end
			end
			if worstName == nil then break end
			enemies[worstName] = nil
		end

		SoundAlerter:Debug("Statistics", "pruned %d enemies, kept top %d", enemyCount - maxEnemies, maxEnemies)
	end
end

function Statistics:SaveSessionHistory()
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.enabled then return end
	if not sadb.statistics.allTime.topSpells then return end

	local session = sadb.statistics.session
	local topSpells = sadb.statistics.allTime.topSpells
	local sessionNum = session.sessionNumber or 1
	local currentTime = time()

	dataVersion = dataVersion + 1

	for _, data in pairs(topSpells) do
		if not data.trend then
			data.trend = {
				lastSessionCount = 0,
				currentSessionCount = 0,
				avgPerSession = 0,
				direction = "stable"
			}
		end

		local currentCount = data.trend.currentSessionCount or 0
		local lastCount = data.trend.lastSessionCount or 0

		if currentCount > lastCount * STATS_CONSTANTS.TREND_INCREASE_THRESHOLD then
			data.trend.direction = "increasing"
		elseif currentCount < lastCount * STATS_CONSTANTS.TREND_DECREASE_THRESHOLD and lastCount > 0 then
			data.trend.direction = "decreasing"
		else
			data.trend.direction = "stable"
		end

		if data.sessionHistory and #data.sessionHistory > 0 then
			local sum = currentCount
			for _, hist in ipairs(data.sessionHistory) do
				sum = sum + hist.count
			end
			data.trend.avgPerSession = sum / (#data.sessionHistory + 1)
		else
			data.trend.avgPerSession = currentCount
		end

		if not data.sessionHistory then
			data.sessionHistory = {}
		end

		if currentCount > 0 then
			table.insert(data.sessionHistory, 1, {
				sessionNum = sessionNum,
				count = currentCount,
				timestamp = currentTime
			})

			while #data.sessionHistory > STATS_CONSTANTS.MAX_SESSION_HISTORY do
				table.remove(data.sessionHistory)
			end
		end

		data.trend.lastSessionCount = currentCount
		data.trend.currentSessionCount = 0
	end
end

function Statistics:InitializeStatistics()
	local sadb = GetDB()
	if sadb and sadb.statistics and sadb.statistics.enabled then

		sadb.statistics.allTime.totalSessions = (sadb.statistics.allTime.totalSessions or 0) + 1

		sadb.statistics.session = newSession(sadb.statistics.allTime.totalSessions)
		dataVersion = dataVersion + 1

		if not sadb.statistics.allTime.playerTracking then
			sadb.statistics.allTime.playerTracking = {
				enemies = {},
				classSummary = {}
			}
		end

		if not sadb.statistics.trackingStartTime or sadb.statistics.trackingStartTime == 0 then
			sadb.statistics.trackingStartTime = time()
		end
	end
	self:UpdateMatch()
end

function Statistics:GetCurrentZoneType()
	local sadb = GetDB()
	local _, instanceType = IsInInstance()

	if instanceType == "arena" then
		return "arena"
	elseif instanceType == "pvp" then
		return "battleground"
	elseif sadb and sadb.field then
		return "worldPvP"
	end

	return nil
end

function Statistics:SpellSchoolName(school)
	if not school then return "Unknown" end

	local schools = {
		[0x01] = "Physical",
		[0x02] = "Holy",
		[0x04] = "Fire",
		[0x08] = "Nature",
		[0x10] = "Frost",
		[0x20] = "Shadow",
		[0x40] = "Arcane"
	}

	for mask, name in pairs(schools) do
		if bit.band(school, mask) > 0 then
			return name
		end
	end

	return "Unknown"
end

function Statistics:GetSpellCategory(spellID)
	return Venn.CategoryOf(SoundAlerterSpells, spellID)
end

function Statistics:OnInitialize()
end

function Statistics:OnEnable()
	local sadb = GetDB()
	if sadb then
		sadb.statsExportbox = nil
		sadb.showAdvancedStatistics = nil
	end
	self:InitializeStatistics()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateMatch")
end

function Statistics:GetSortState()
	return statisticsSortState
end

function Statistics:BuildExportString()
	local sadb = GetDB()
	if not sadb or not sadb.statistics then
		return "No statistics available."
	end

	local session = sadb.statistics.session or {}
	local allTime = sadb.statistics.allTime or {}
	local lines = {}

	lines[#lines + 1] = "SoundAlerter Statistics Export"
	lines[#lines + 1] = string.format("Session: %d alerts | All-Time: %d alerts across %d sessions",
		session.totalAlerts or 0, allTime.totalAlerts or 0, allTime.totalSessions or 0)
	lines[#lines + 1] = ""

	lines[#lines + 1] = "Top Spells:"
	local spellData = PrepareTopSpellsData()
	if spellData and #spellData > 0 then
		for i = 1, math.min(#spellData, STATS_CONSTANTS.MAX_DISPLAY_ROWS) do
			local spell = spellData[i]
			lines[#lines + 1] = string.format("%d. %s - %d (%.0f%%)", i, spell.name or "Unknown", spell.count or 0, spell.percentage or 0)
		end
	else
		lines[#lines + 1] = "(none tracked yet)"
	end
	lines[#lines + 1] = ""

	lines[#lines + 1] = "Class Distribution:"
	local classData = PrepareClassDistributionData()
	if classData and #classData > 0 then
		for _, cls in ipairs(classData) do
			lines[#lines + 1] = string.format("%s - %d alerts (%d players, %.0f%%)",
				FormatClassName(cls.class), cls.alerts or 0, cls.players or 0, cls.percentage or 0)
		end
	else
		lines[#lines + 1] = "(none tracked yet)"
	end
	lines[#lines + 1] = ""

	lines[#lines + 1] = "Top Enemies:"
	local enemyData = PrepareEnemiesData()
	if enemyData and #enemyData > 0 then
		for i = 1, math.min(#enemyData, STATS_CONSTANTS.MAX_DISPLAY_ROWS) do
			local enemy = enemyData[i]
			lines[#lines + 1] = string.format("%d. %s (%s) - %d alerts (%.0f%%), danger %.1f, top zone %s", i,
				enemy.name or "Unknown", FormatClassName(enemy.class), enemy.alerts or 0, enemy.percentage or 0,
				enemy.danger or 0, enemy.topZone or "N/A")
		end
	else
		lines[#lines + 1] = "(none tracked yet)"
	end
	lines[#lines + 1] = ""

	Debrief.ExportLines(lines, (sadb.statistics.matches or {}).list, Format.CATEGORIES)

	return table.concat(lines, "\n")
end

function Statistics:SetSortState(tableType, sortType)
	if statisticsSortState[tableType] then
		statisticsSortState[tableType].sortType = sortType
	end
end
