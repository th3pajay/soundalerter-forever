
local Statistics = SoundAlerter:NewModule("Statistics", "AceEvent-3.0")
SoundAlerter.Statistics = Statistics
local GetSpellInfo = SA_COMPAT.GetSpellInfo

local function GetDB()
	return SoundAlerter.db1 and SoundAlerter.db1.profile
end

local STATS_CONSTANTS = {
	MAX_TOP_SPELLS = 50,
	MAX_ENEMIES = 100,
	MAX_SESSION_HISTORY = 50,
	MAX_DISPLAY_ROWS = 20,

	TREND_INCREASE_THRESHOLD = 1.2,
	TREND_DECREASE_THRESHOLD = 0.8,

	DANGER_HIGH = 5,
	DANGER_MEDIUM = 3,

	TABLE_BORDERS = {
		TOP    = "",
		HEADER = "|cff888888--------------------------|r",
		ROW    = "",
		BOTTOM = "",
		LEFT   = "",
		WIDTH  = 28
	}
}

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

local function TruncateString(str, maxLen)
	if not str then return "" end
	if string.len(str) <= maxLen then return str end
	return str:sub(1, maxLen - 2) .. ".."
end

local function FormatDanger(danger)
	local color = "ff00FF00"
	if danger > STATS_CONSTANTS.DANGER_HIGH then
		color = "ffFF0000"
	elseif danger > STATS_CONSTANTS.DANGER_MEDIUM then
		color = "ffFFD700"
	end
	return "|c" .. color .. string.format("%.1f", danger) .. "|r"
end

local function GetClassColorHex(class)
	local classColor = RAID_CLASS_COLORS[class]
	if classColor then
		return string.format("ff%02x%02x%02x",
			classColor.r * 255,
			classColor.g * 255,
			classColor.b * 255)
	end
	return "ffFFFFFF"
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

local function RenderStatsTable(config)
	if not config.data or #config.data == 0 then
		return config.emptyMessage or "|cffFFFFFFNo data available.|r"
	end

	local parts = {}
	local borders = STATS_CONSTANTS.TABLE_BORDERS

	parts[#parts + 1] = "|cffFFD700" .. (config.title or "STATISTICS") .. "|r\n"
	parts[#parts + 1] = borders.HEADER
	parts[#parts + 1] = "\n"

	local maxDisplay = math.min(config.maxRows or STATS_CONSTANTS.MAX_DISPLAY_ROWS, #config.data)

	for i = 1, maxDisplay do
		local row = config.data[i]

		if config.rowRenderer then
			local rowText = config.rowRenderer(row, i)
			parts[#parts + 1] = rowText
		end

		if i < maxDisplay then
			parts[#parts + 1] = borders.ROW
			parts[#parts + 1] = "\n"
		end
	end

	parts[#parts + 1] = borders.BOTTOM

	if #config.data > maxDisplay then
		parts[#parts + 1] = "\n\n|cff888888... and "
		parts[#parts + 1] = tostring(#config.data - maxDisplay)
		parts[#parts + 1] = " more entries|r"
	end

	return table.concat(parts)
end

local function PrepareTopSpellsData()
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.allTime or not sadb.statistics.allTime.topSpells then
		return nil, "|cffFF0000No spell data available|r"
	end

	local topSpells = sadb.statistics.allTime.topSpells
	local spellList = {}
	local totalAlerts = sadb.statistics.allTime.totalAlerts or 1

	for spellID, data in pairs(topSpells) do
		table.insert(spellList, {
			id = spellID,
			name = data.name or GetCachedSpellName(spellID),
			count = data.count,
			trend = data.trend and data.trend.direction or "stable",
			topClass = GetTopClass(data.byClass),
			topZone = GetTopZone(data.byZone),
			lastSeen = data.lastSeen,
			percentage = (data.count / totalAlerts) * 100
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

	for name, data in pairs(enemies) do
		local topSpell = nil
		local topSpellCount = 0
		for spellID, count in pairs(data.spellsUsed) do
			if count > topSpellCount then
				topSpellCount = count
				topSpell = GetCachedSpellName(spellID)
			end
		end

		table.insert(enemyList, {
			name = name,
			class = data.class,
			alerts = data.totalAlerts,
			danger = data.dangerRating or 0,
			topSpell = topSpell or "N/A",
			lastSeen = data.lastSeen
		})
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
	for name, enemyData in pairs(sadb.statistics.allTime.playerTracking.enemies) do
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

local barRowCache = {
	topSpells = { data = nil, errorMsg = nil, computedAt = 0 },
	classes = { data = nil, errorMsg = nil, computedAt = 0 },
}
local BAR_CACHE_TTL = 1

local function GetBarRowSource(tableType)
	local cache = barRowCache[tableType]
	if cache.data and (GetTime() - cache.computedAt) < BAR_CACHE_TTL then
		return cache.data, cache.errorMsg
	end

	local data, errorMsg
	if tableType == "topSpells" then
		data, errorMsg = PrepareTopSpellsData()
	elseif tableType == "classes" then
		data, errorMsg = PrepareClassDistributionData()
	end

	cache.data = data
	cache.errorMsg = errorMsg
	cache.computedAt = GetTime()
	return data, errorMsg
end

function Statistics:InvalidateBarRowCache()
	barRowCache.topSpells.computedAt = 0
	barRowCache.classes.computedAt = 0
end

function Statistics:GetBarRowCount(tableType)
	local data = GetBarRowSource(tableType)
	if not data then return 0 end
	local maxRows = tableType == "topSpells" and STATS_CONSTANTS.MAX_DISPLAY_ROWS or #data
	return math.min(maxRows, #data)
end

function Statistics:GetBarRowErrorMessage(tableType)
	local data, errorMsg = GetBarRowSource(tableType)
	if data then return nil end
	return errorMsg or "|cffFF0000No data available|r"
end

function Statistics:GetBarRowLabel(tableType, n)
	local data = GetBarRowSource(tableType)
	local row = data and data[n]
	if not row then return "" end

	if tableType == "topSpells" then
		return string.format("|cff888888#%d|r |cffFFFFFF%s|r  |cff00FF00%d|r (%.0f%%)",
			n, TruncateString(row.name or "Unknown", 24), row.count or 0, row.percentage or 0)
	else
		local classHex = GetClassColorHex(row.class)
		return string.format("|c%s%s|r  |cff00FF00%d|r (%.0f%%)",
			classHex, FormatClassName(row.class), row.alerts or 0, row.percentage or 0)
	end
end

function Statistics:GetBarRowPercent(tableType, n)
	local data = GetBarRowSource(tableType)
	local row = data and data[n]
	return (row and row.percentage) or 0
end

local function GenerateEnemiesTable()
	local data, errorMsg = PrepareEnemiesData()
	if not data then return errorMsg end

	return RenderStatsTable({
		title = "TOP ENEMIES",
		data = data,
		maxRows = STATS_CONSTANTS.MAX_DISPLAY_ROWS,
		emptyMessage = "|cffFFFFFFNo enemies tracked yet.|r",
		rowRenderer = function(enemy, rank)
			local borders = STATS_CONSTANTS.TABLE_BORDERS
			local parts = {}

			local classHex = GetClassColorHex(enemy.class)
			parts[#parts + 1] = borders.LEFT
			parts[#parts + 1] = "|cff888888#"
			parts[#parts + 1] = string.format("%2d", rank)
			parts[#parts + 1] = "|r |c"
			parts[#parts + 1] = classHex
			parts[#parts + 1] = TruncateString(enemy.name or "Unknown", 18)
			parts[#parts + 1] = "|r\n"

			local dangerText = FormatDanger(enemy.danger)
			parts[#parts + 1] = borders.LEFT
			parts[#parts + 1] = " |cff00FF00"
			parts[#parts + 1] = tostring(enemy.alerts)
			parts[#parts + 1] = "|r danger:"
			parts[#parts + 1] = dangerText
			parts[#parts + 1] = "\n"

			return table.concat(parts)
		end
	})
end

function Statistics:RecordAlert(category, spellID, sourceGUID, sourceName)
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.enabled then return end

	sadb.statistics.session.totalAlerts = (sadb.statistics.session.totalAlerts or 0) + 1
	sadb.statistics.session.byCategory[category] = (sadb.statistics.session.byCategory[category] or 0) + 1

	sadb.statistics.allTime.totalAlerts = (sadb.statistics.allTime.totalAlerts or 0) + 1
	sadb.statistics.allTime.byCategory[category] = (sadb.statistics.allTime.byCategory[category] or 0) + 1

	local zoneType = self:GetCurrentZoneType()
	if zoneType then
		sadb.statistics.allTime.byZone[zoneType] = (sadb.statistics.allTime.byZone[zoneType] or 0) + 1
	end

	if spellID and category == "spellAlerts" then
		self:UpdateTopSpells(spellID, sourceGUID, sourceName)
	end

	if sourceGUID and sourceName then
		self:TrackEnemyPlayer(sourceGUID, sourceName, spellID)
	end

	if sadb.debugmode then
		print(string.format("<SA> STATS: Recorded %s alert (Total: %d)", category, sadb.statistics.session.totalAlerts))
	end
end

function Statistics:UpdateTopSpells(spellID, sourceGUID, sourceName)
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not spellID then return end

	local topSpells = sadb.statistics.allTime.topSpells
	local maxSpells = sadb.statistics.maxTopSpells or STATS_CONSTANTS.MAX_TOP_SPELLS
	local currentTime = time()
	local zoneType = self:GetCurrentZoneType()

	local sourceClass = nil
	if sourceGUID then
		local _, class = GetPlayerInfoByGUID(sourceGUID)
		if not class and sourceName then

			sourceClass = SoundAlerter:ArenaClass(sourceGUID)
		else
			sourceClass = class
		end
	end

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
				if sadb.debugmode then
					print(string.format("<SA> STATS: Evicted spell %d (lowest count: %d)", lowestSpellID, lowestCount))
				end
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
			spellSchool = self:GetSpellSchool(spellID),
			spellCategory = self:GetSpellCategory(spellID),
			sessionHistory = {}
		}
	end

	if sadb.statistics.session then
		sadb.statistics.session.spellsThisSession[spellID] = (sadb.statistics.session.spellsThisSession[spellID] or 0) + 1
	end
end

function Statistics:TrackEnemyPlayer(sourceGUID, sourceName, spellID)
	local sadb = GetDB()
	if not sourceGUID or not sourceName then return end
	if not sadb or not sadb.statistics or not sadb.statistics.enabled then return end

	if not CombatLog_Object_IsA(sourceGUID, COMBATLOG_FILTER_HOSTILE_PLAYERS) then
		return
	end

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

	local _, sourceClass = GetPlayerInfoByGUID(sourceGUID)
	if not sourceClass then
		sourceClass = SoundAlerter:ArenaClass(sourceGUID) or "UNKNOWN"
	end

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

	if sadb.statistics.session and not sadb.statistics.session.enemiesEncountered[sourceName] then
		sadb.statistics.session.enemiesEncountered[sourceName] = true

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
			self:PruneEnemyTracking(STATS_CONSTANTS.MAX_ENEMIES)
			break
		end
	end
end

function Statistics:PruneEnemyTracking(maxEnemies)
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.allTime.playerTracking then return end

	local enemies = sadb.statistics.allTime.playerTracking.enemies

	local enemyCount = 0
	for _ in pairs(enemies) do enemyCount = enemyCount + 1 end

	if enemyCount > maxEnemies then
		local enemyList = {}
		for name, data in pairs(enemies) do
			table.insert(enemyList, { name = name, alerts = data.totalAlerts })
		end

		table.sort(enemyList, function(a, b) return a.alerts > b.alerts end)

		for i = maxEnemies + 1, #enemyList do
			enemies[enemyList[i].name] = nil
		end

		if sadb.debugmode then
			print(string.format("<SA> STATS: Pruned %d enemies (kept top %d)", enemyCount - maxEnemies, maxEnemies))
		end
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

	for spellID, data in pairs(topSpells) do
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

	if sadb.debugmode then
		SoundAlerter:Print("Session history saved for statistics")
	end
end

function Statistics:InitializeStatistics()
	local sadb = GetDB()
	if sadb and sadb.statistics and sadb.statistics.enabled then

		sadb.statistics.allTime.totalSessions = (sadb.statistics.allTime.totalSessions or 0) + 1

		sadb.statistics.session = {
			totalAlerts = 0,
			startTime = GetTime(),
			sessionNumber = sadb.statistics.allTime.totalSessions,
			byCategory = {
				spellAlerts = 0,
				proximityAlerts = 0,
				trinketAlerts = 0,
				flagAlerts = 0,
			},
			byClass = {},
			enemiesEncountered = {},
			spellsThisSession = {}
		}

		if not sadb.statistics.allTime.playerTracking then
			sadb.statistics.allTime.playerTracking = {
				enemies = {},
				classSummary = {}
			}
		end

		if not sadb.statistics.trackingStartTime or sadb.statistics.trackingStartTime == 0 then
			sadb.statistics.trackingStartTime = time()
		end

		if sadb.debugmode then
			SoundAlerter:Print(string.format("Statistics initialized (Session #%d)", sadb.statistics.allTime.totalSessions))
		end
	end
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

function Statistics:GetSpellSchool(spellID)
	local _, _, _, _, _, _, _, school = GetSpellInfo(spellID)

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
	if not SoundAlerterSpells then return "Other" end

	if SoundAlerterSpells.friendCCs and SoundAlerterSpells.friendCCs[spellID] then
		return "CC"
	end
	if SoundAlerterSpells.enemyDebuffs and SoundAlerterSpells.enemyDebuffs[spellID] then
		return "CC"
	end
	if SoundAlerterSpells.friendCCenemy and SoundAlerterSpells.friendCCenemy[spellID] then
		return "CC"
	end
	if SoundAlerterSpells.friendCCSuccess and SoundAlerterSpells.friendCCSuccess[spellID] then
		return "CC"
	end

	if SoundAlerterSpells.auraApplied and SoundAlerterSpells.auraApplied[spellID] then
		return "Defensive"
	end

	if SoundAlerterSpells.interruptFriend and SoundAlerterSpells.interruptFriend[spellID] then
		return "Interrupt"
	end

	if SoundAlerterSpells.enemyDebuffdown and SoundAlerterSpells.enemyDebuffdown[spellID] then
		return "Debuff Removal"
	end
	if SoundAlerterSpells.enemyDebuffdownAP and SoundAlerterSpells.enemyDebuffdownAP[spellID] then
		return "Debuff Removal"
	end

	if SoundAlerterSpells.auraRemoved and SoundAlerterSpells.auraRemoved[spellID] then
		return "Buff Removal"
	end

	if SoundAlerterSpells.castStart and SoundAlerterSpells.castStart[spellID] then
		return "Cast"
	end

	if SoundAlerterSpells.castSuccess and SoundAlerterSpells.castSuccess[spellID] then
		return "Instant"
	end

	if SoundAlerterSpells.selfDebuff and SoundAlerterSpells.selfDebuff[spellID] then
		return "Debuff on Self"
	end

	return "Other"
end

function Statistics:OnInitialize()
end

function Statistics:OnEnable()
	self:InitializeStatistics()
end

function Statistics:GetEnemiesTable()
	return GenerateEnemiesTable()
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
			lines[#lines + 1] = string.format("%d. %s (%s) - %d alerts, danger %.1f", i,
				enemy.name or "Unknown", FormatClassName(enemy.class), enemy.alerts or 0, enemy.danger or 0)
		end
	else
		lines[#lines + 1] = "(none tracked yet)"
	end

	return table.concat(lines, "\n")
end

function Statistics:SetSortState(tableType, sortType)
	if statisticsSortState[tableType] then
		statisticsSortState[tableType].sortType = sortType
		self:InvalidateBarRowCache()
	end
end
