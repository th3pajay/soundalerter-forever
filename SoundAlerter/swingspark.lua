local SoundAlerter = SoundAlerter
local Plain = SA_COMPAT.Plain

SA_SwingSpark = {}
local Model = SA_SwingSpark

Model.EDGE = { [0] = "TOP", [1] = "BOTTOM", [2] = "TOP" }
Model.POWER_BAR = { [0] = "mana", [1] = "rage", [3] = "energy" }
Model.BARS = { "energy", "rage", "mana", "health" }
Model.HANDS = { 0, 1, 2 }
Model.FADE = 0.3
Model.FLASH = 0.25
Model.FLASH_ALPHA = 0.9
Model.TAIL = 16
Model.CORE = 2
Model.GLOW = 10
Model.HOLDER = 12
Model.PREVIEW = 2.5

function Model.BarFor(powerType, db)
    local own = Model.POWER_BAR[powerType]
    if own and db[own .. "Enabled"] then return own end
    for _, key in ipairs(Model.BARS) do
        if db[key .. "Enabled"] then return key end
    end
    return nil
end

function Model.Valid(duration, hand)
    return type(duration) == "number" and duration > 0 and Model.EDGE[hand] ~= nil
end

local FLAT = "Interface\\Buttons\\WHITE8X8"
local GLOW = "Interface\\AddOns\\SoundAlerter\\Textures\\cb_spark"

local Spark = { sparks = {} }
SoundAlerter.SwingSpark = Spark

local eventFrame
local listening = false

local function pixel(frame)
    return SoundAlerter.BarUtils:Snap(1, frame)
end

local function newSpark(hand)
    local spark = { edge = Model.EDGE[hand] }
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetClipsChildren(true)
    holder:SetHeight(Model.HOLDER)
    spark.holder = holder

    local runner = CreateFrame("Frame", nil, holder)
    runner:SetSize(1, 1)
    runner:SetPoint("CENTER", holder, "LEFT", 0, 0)
    runner:Hide()
    spark.runner = runner

    local tail = runner:CreateTexture(nil, "OVERLAY")
    tail:SetTexture(FLAT)
    tail:SetWidth(Model.TAIL)
    tail:SetPoint("RIGHT", runner, "CENTER", 0, 0)
    if tail.SetGradient and CreateColor then
        tail:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.9))
    else
        tail:SetAlpha(0.45)
    end

    local glow = runner:CreateTexture(nil, "OVERLAY")
    glow:SetTexture(GLOW)
    glow:SetBlendMode("ADD")
    glow:SetSize(Model.GLOW, Model.GLOW)
    glow:SetPoint("CENTER", runner, "CENTER", 0, 0)

    local core = runner:CreateTexture(nil, "OVERLAY")
    core:SetTexture(FLAT)
    core:SetWidth(Model.CORE)
    core:SetPoint("CENTER", runner, "CENTER", 0, 0)

    local pass = runner:CreateAnimationGroup()
    local move = pass:CreateAnimation("Translation")
    move:SetOrder(1)
    move:SetSmoothing("NONE")
    local fade = pass:CreateAnimation("Alpha")
    fade:SetOrder(2)
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(Model.FADE)
    pass:SetScript("OnFinished", function() runner:Hide() end)
    spark.pass, spark.move, spark.fade = pass, move, fade

    local flash = holder:CreateTexture(nil, "OVERLAY")
    flash:SetTexture(FLAT)
    flash:SetPoint("LEFT", holder, "LEFT", 0, 0)
    flash:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    flash:Hide()
    local flashGroup = flash:CreateAnimationGroup()
    local flashFade = flashGroup:CreateAnimation("Alpha")
    flashFade:SetFromAlpha(Model.FLASH_ALPHA)
    flashFade:SetToAlpha(0)
    flashFade:SetDuration(Model.FLASH)
    flashGroup:SetScript("OnFinished", function() flash:Hide() end)
    spark.flash, spark.flashGroup = flash, flashGroup
    spark.tail, spark.core = tail, core
    return spark
end

local function attach(spark, bar, key)
    spark.bar, spark.barKey = bar, key
    local holder = spark.holder
    holder:SetParent(bar)
    holder:SetFrameLevel(bar:GetFrameLevel() + 3)
    holder:ClearAllPoints()
    holder:SetPoint("LEFT", bar, spark.edge .. "LEFT", 0, 0)
    holder:SetPoint("RIGHT", bar, spark.edge .. "RIGHT", 0, 0)
    local line = pixel(bar)
    spark.tail:SetHeight(line)
    spark.core:SetHeight(line)
    spark.flash:SetHeight(line)
end

local function stop(spark)
    spark.pass:Stop()
    spark.runner:Hide()
    spark.flashGroup:Stop()
    spark.flash:Hide()
end

local function run(spark, duration, width, flash)
    if spark.duration ~= duration then
        spark.duration = duration
        spark.move:SetDuration(duration)
    end
    if spark.width ~= width then
        spark.width = width
        spark.move:SetOffset(width, 0)
    end
    spark.pass:Stop()
    spark.runner:Show()
    spark.pass:Play()
    if flash then
        spark.flashGroup:Stop()
        spark.flash:Show()
        spark.flashGroup:Play()
    end
end

local function onSwing(duration, hand)
    duration, hand = Plain(duration), Plain(hand)
    if not Model.Valid(duration, hand) then return false end
    local bars = SoundAlerter.ResourceBar
    local db = bars and bars.db
    if not db then return false end
    local key = Model.BarFor(Plain((UnitPowerType("player"))), db)
    local bar = key and bars[key .. "Bar"]
    if not bar then return false end
    local spark = Spark.sparks[hand]
    if not spark then
        spark = newSpark(hand)
        Spark.sparks[hand] = spark
    end
    if spark.bar ~= bar then attach(spark, bar, key) end
    run(spark, duration, bar:GetWidth(), db.swingSparkFlash)
    return true
end

local function setRangeChecks(on)
    if not C_SwingTimer or not C_SwingTimer.EnableRangeCheck then return end
    for _, hand in ipairs(Model.HANDS) do pcall(C_SwingTimer.EnableRangeCheck, hand, on) end
end

local function listen()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function(_, _, duration, hand) onSwing(duration, hand) end)
    end
    pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_SWING")
    setRangeChecks(true)
    listening = true
end

local function unlisten()
    pcall(eventFrame.UnregisterEvent, eventFrame, "PLAYER_SWING")
    setRangeChecks(false)
    listening = false
end

function Spark:Refresh()
    local bars = SoundAlerter.ResourceBar
    local db = bars and bars.db
    if not db then return end
    local want = db.swingSpark and C_SwingTimer ~= nil and Model.BarFor(nil, db) ~= nil
    if want and not listening then
        listen()
    elseif listening and not want then
        unlisten()
    end
    for _, spark in pairs(self.sparks) do
        if not (want and db[spark.barKey .. "Enabled"]) then stop(spark) end
    end
end

function Spark:Preview()
    if not onSwing(Model.PREVIEW, 0) then
        SoundAlerter:Print("Show an energy, rage, mana or health bar to see the swing spark.")
    end
end

SA_ManaSweep = {}
local SweepModel = SA_ManaSweep

SweepModel.DURATION = 5
SweepModel.FADE = 0.4
SweepModel.MANA = 0
SweepModel.NO_MANA = { WARRIOR = true, ROGUE = true, DEATHKNIGHT = true, DEMONHUNTER = true }
SweepModel.COLOR = { 0.55, 0.85, 1 }
SweepModel.LINE = 2
SweepModel.TAIL = 24
SweepModel.GLOW = 14
SweepModel.FREE_CASTS = { ["Clearcasting"] = true, ["Omen of Clarity"] = true, ["Arcane Concentration"] = true, ["Elemental Focus"] = true }

function SweepModel.FreeCast(stateOf)
    for name in pairs(SweepModel.FREE_CASTS) do
        if stateOf(name) == true then return true end
    end
    return false
end

function SweepModel.SpendsMana(costs)
    if type(costs) ~= "table" then return false end
    for index = 1, #costs do
        local entry = costs[index]
        if type(entry) == "table" and Plain(entry.type) == SweepModel.MANA then
            local cost = Plain(entry.cost)
            if type(cost) == "number" and cost > 0 then return true end
            local percent = Plain(entry.costPercent)
            if type(percent) == "number" and percent > 0 then return true end
        end
    end
    return false
end

local Sweep = { spends = {} }
SoundAlerter.ManaSweep = Sweep

local sweepFrame, sweepEvents
local sweepListening = false

local function buildSweep(bar)
    local holder = CreateFrame("Frame", nil, bar)
    holder:SetClipsChildren(true)
    holder:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    holder:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    holder:SetFrameLevel(bar:GetFrameLevel() + 2)

    local runner = CreateFrame("Frame", nil, holder)
    runner:SetWidth(1)
    runner:SetPoint("TOP", holder, "TOPLEFT", 0, 0)
    runner:SetPoint("BOTTOM", holder, "BOTTOMLEFT", 0, 0)
    runner:Hide()

    local r, g, b = SweepModel.COLOR[1], SweepModel.COLOR[2], SweepModel.COLOR[3]
    local tail = runner:CreateTexture(nil, "OVERLAY")
    tail:SetTexture(FLAT)
    tail:SetWidth(SweepModel.TAIL)
    tail:SetPoint("TOPRIGHT", runner, "TOP", 0, 0)
    tail:SetPoint("BOTTOMRIGHT", runner, "BOTTOM", 0, 0)
    if tail.SetGradient and CreateColor then
        tail:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.35))
    else
        tail:SetVertexColor(r, g, b, 0.2)
    end

    local glow = runner:CreateTexture(nil, "OVERLAY")
    glow:SetTexture(GLOW)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(r, g, b, 0.8)
    glow:SetWidth(SweepModel.GLOW)
    glow:SetPoint("TOP", runner, "TOP", 0, 0)
    glow:SetPoint("BOTTOM", runner, "BOTTOM", 0, 0)

    local core = runner:CreateTexture(nil, "OVERLAY")
    core:SetTexture(FLAT)
    core:SetVertexColor(r, g, b, 1)
    core:SetWidth(SoundAlerter.BarUtils:Snap(SweepModel.LINE, bar))
    core:SetPoint("TOP", runner, "TOP", 0, 0)
    core:SetPoint("BOTTOM", runner, "BOTTOM", 0, 0)

    local pass = runner:CreateAnimationGroup()
    local move = pass:CreateAnimation("Translation")
    move:SetOrder(1)
    move:SetSmoothing("NONE")
    move:SetDuration(SweepModel.DURATION)
    local fade = pass:CreateAnimation("Alpha")
    fade:SetOrder(2)
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(SweepModel.FADE)
    pass:SetScript("OnFinished", function() runner:Hide() end)

    return { bar = bar, holder = holder, runner = runner, pass = pass, move = move }
end

local function runSweep()
    local bars = SoundAlerter.ResourceBar
    local bar = bars and bars.manaBar
    if not bar then return false end
    if not sweepFrame or sweepFrame.bar ~= bar then sweepFrame = buildSweep(bar) end
    local width = bar:GetWidth()
    if sweepFrame.width ~= width then
        sweepFrame.width = width
        sweepFrame.move:SetOffset(width, 0)
    end
    sweepFrame.pass:Stop()
    sweepFrame.runner:Show()
    sweepFrame.pass:Play()
    return true
end

local function stopSweep()
    if not sweepFrame then return end
    sweepFrame.pass:Stop()
    sweepFrame.runner:Hide()
end

local function onSpellcast(spellID)
    spellID = Plain(spellID)
    if type(spellID) ~= "number" then return end
    local spends = Sweep.spends[spellID]
    if spends == nil then
        local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
        spends = ok and SweepModel.SpendsMana(costs) or false
        Sweep.spends[spellID] = spends
    end
    if not spends then return end
    local View = SA_CooldownView
    if View and SweepModel.FreeCast(View.State) then return end
    runSweep()
end

local function sweepListen()
    if not sweepEvents then
        sweepEvents = CreateFrame("Frame")
        sweepEvents:SetScript("OnEvent", function(_, event, _, _, spellID)
            if event == "SPELLS_CHANGED" then
                wipe(Sweep.spends)
            else
                onSpellcast(spellID)
            end
        end)
    end
    sweepEvents:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    sweepEvents:RegisterEvent("SPELLS_CHANGED")
    sweepListening = true
    if SA_CooldownView then SA_CooldownView.Want("sweep", SweepModel.FREE_CASTS) end
end

local function sweepUnlisten()
    sweepEvents:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    sweepEvents:UnregisterEvent("SPELLS_CHANGED")
    wipe(Sweep.spends)
    sweepListening = false
    stopSweep()
    if SA_CooldownView then SA_CooldownView.Want("sweep", nil) end
end

function Sweep:Refresh()
    local bars = SoundAlerter.ResourceBar
    local db = bars and bars.db
    if not db then return end
    local _, class = UnitClass("player")
    local want = db.manaSweep and db.manaEnabled and not SweepModel.NO_MANA[class] and C_Spell ~= nil and C_Spell.GetSpellPowerCost ~= nil
    if want and not sweepListening then
        sweepListen()
    elseif sweepListening and not want then
        sweepUnlisten()
    end
end

function Sweep:Preview()
    if not runSweep() then
        SoundAlerter:Print("Show the mana bar to see the five-second sweep.")
    end
end
