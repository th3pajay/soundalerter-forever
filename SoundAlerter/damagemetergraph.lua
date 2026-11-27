local SoundAlerter = SoundAlerter
local Model = SA_MeterModel

local Graph = {}

Graph.LEFT = 26
Graph.TOP = 22
Graph.PLOT_H = 150
Graph.COLUMN_MIN = 6
Graph.COLUMNS = 60
Graph.PULL_MIN = 3
Graph.SEGMENT_CAP = 200
Graph.GRID = 4
Graph.RISE = 0.45
Graph.LINE_DELAY = 0.3
Graph.HOVER = 0.05
Graph.VIEWS = { { "time", "Session" }, { "pull", "Pulls" }, { "cmp", "Compare" } }
Graph.FLAT = "Interface\\Buttons\\WHITE8X8"
Graph.CIRCLE = "Interface\\AddOns\\SoundAlerter\\Textures\\circle"
Graph.HEAD, Graph.BEST, Graph.TREND_W = 5, 9, 1.2

local COLOR = {
    grid = { 1, 1, 1, 0.06 },
    band = { 1, 1, 1, 0.06 },
    pve = { 0.851, 0.467, 0.086, 1 },
    pvp = { 0.224, 0.529, 0.898, 1 },
    short = { 0.357, 0.396, 0.463, 1 },
    line = { 0.906, 0.918, 0.941, 1 },
    boss = { 1, 0.82, 0, 1 },
    death = { 0.835, 0.318, 0.506, 1 },
    track = { 1, 1, 1, 0.045 },
    average = { 0.906, 0.918, 0.941, 1 },
}
Graph.COLOR = COLOR

local function Paint(parent, color, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture(Graph.FLAT)
    texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    return texture
end

function Graph.NiceMax(value)
    if value <= 0 then return 40 end
    local step = 10 ^ math.floor(math.log10(value))
    for _, factor in ipairs({ 1, 2, 2.5, 4, 5, 8, 10 }) do
        if factor * step >= value then return factor * step end
    end
    return 10 * step
end

local function Take(pool, make)
    pool.used = pool.used + 1
    local item = pool[pool.used]
    if not item then
        item = make()
        pool[pool.used] = item
    end
    item:Show()
    return item
end

local function Release(pool)
    for i = 1, #pool do pool[i]:Hide() end
    pool.used = 0
end

function Graph.Build(window, body, width)
    local pane = CreateFrame("Frame", nil, body)
    pane:SetAllPoints(body)
    pane.window = window
    pane.views = {}
    for i, view in ipairs(Graph.VIEWS) do
        local button = CreateFrame("Button", nil, pane)
        button:SetSize(64, 15)
        button:SetPoint("TOPLEFT", pane, "TOPLEFT", (i - 1) * 68, 0)
        button.back = Paint(button, COLOR.track, "BACKGROUND")
        button.back:SetAllPoints()
        button.label = window:Text(button, 10, window.COLOR.muted, "CENTER")
        button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.label:SetText(view[2])
        button.view = view[1]
        button:SetScript("OnClick", function() Graph.Select(pane, view[1]) end)
        pane.views[i] = button
    end
    local plotW = width - Graph.LEFT
    pane.plotW = plotW
    local plot = CreateFrame("Frame", nil, pane)
    plot:SetPoint("TOPLEFT", pane, "TOPLEFT", Graph.LEFT, -Graph.TOP)
    plot:SetSize(plotW, Graph.PLOT_H)
    pane.plot = plot
    pane.grid, pane.gridLabels = {}, {}
    for i = 1, Graph.GRID do
        local line = Paint(plot, COLOR.grid, "BACKGROUND")
        line:SetHeight(1)
        line:SetWidth(plotW)
        pane.grid[i] = line
        local label = window:Text(pane, 10, window.COLOR.muted, "RIGHT")
        pane.gridLabels[i] = label
    end
    pane.marks = CreateFrame("Frame", nil, plot)
    pane.marks:SetAllPoints(plot)
    pane.band = Paint(plot, COLOR.band, "BACKGROUND")
    pane.band:SetHeight(Graph.PLOT_H)
    pane.band:Hide()
    pane.columns = { used = 0 }
    pane.heads = { used = 0 }
    pane.bestMark = pane.marks:CreateTexture(nil, "ARTWORK")
    pane.bestMark:SetTexture(Graph.CIRCLE)
    pane.bestMark:SetSize(Graph.BEST, Graph.BEST)
    pane.bestMark:SetVertexColor(COLOR.boss[1], COLOR.boss[2], COLOR.boss[3], 1)
    pane.bestMark:Hide()
    pane.lines = { used = 0 }
    pane.labels = { used = 0 }
    pane.first = window:Text(pane, 10, window.COLOR.muted, "LEFT")
    pane.first:SetPoint("TOPLEFT", plot, "BOTTOMLEFT", 0, -3)
    pane.last = window:Text(pane, 10, window.COLOR.muted, "RIGHT")
    pane.last:SetPoint("TOPRIGHT", plot, "BOTTOMRIGHT", 0, -3)
    pane.note = window:Text(pane, 10, window.COLOR.dim, "LEFT")
    pane.note:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -(Graph.TOP + Graph.PLOT_H + 20))
    pane.note:SetWidth(width - 250)
    pane.note:SetWordWrap(true)
    pane.empty = window:Text(pane, 11, window.COLOR.dim, "LEFT")
    pane.empty:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -(Graph.TOP + 10))
    pane.rise = pane.marks:CreateAnimationGroup()
    local grow = pane.rise:CreateAnimation("Scale")
    grow:SetScaleFrom(1, 0.02)
    grow:SetScaleTo(1, 1)
    grow:SetOrigin("BOTTOM", 0, 0)
    grow:SetDuration(Graph.RISE)
    if grow.SetSmoothing then grow:SetSmoothing("OUT") end
    pane.lineLayer = CreateFrame("Frame", nil, plot)
    pane.lineLayer:SetAllPoints(plot)
    pane.sweep = pane.lineLayer:CreateAnimationGroup()
    local fade = pane.sweep:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetStartDelay(Graph.LINE_DELAY)
    fade:SetDuration(Graph.RISE)
    pane.sweep:SetToFinalAlpha(true)
    pane.compare = {}
    for i = 1, 5 do
        local y = -(Graph.TOP + 8 + (i - 1) * 30)
        local row = { y = y }
        row.label = window:Text(pane, 11, window.COLOR.text, "LEFT")
        row.label:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, y)
        row.track = Paint(pane, COLOR.track, "BACKGROUND")
        row.track:SetPoint("TOPLEFT", pane, "TOPLEFT", 90, y + 1)
        row.track:SetSize(width - 160, 12)
        row.fill = Paint(pane, window.COLOR.accent)
        row.fill:SetPoint("TOPLEFT", pane, "TOPLEFT", 90, y - 2)
        row.fill:SetHeight(6)
        row.average = Paint(pane, COLOR.average, "OVERLAY")
        row.average:SetSize(2, 12)
        row.best = Paint(pane, COLOR.boss, "OVERLAY")
        row.best:SetSize(2, 16)
        row.value = window:Text(pane, 11, window.COLOR.white, "RIGHT")
        row.value:SetPoint("TOPRIGHT", pane, "TOPLEFT", width, y)
        pane.compare[i] = row
    end
    pane.trackW = width - 160
    local hover = CreateFrame("Frame", nil, pane)
    hover:SetAllPoints(plot)
    hover:EnableMouse(true)
    hover:SetScript("OnEnter", function() Graph.HoverStart(pane) end)
    hover:SetScript("OnLeave", function() Graph.HoverStop(pane) end)
    pane.hover = hover
    pane.view = nil
    return pane
end

function Graph.Buttons(pane)
    local window = pane.window
    for _, button in ipairs(pane.views) do
        local on = button.view == pane.view
        local back = on and window.COLOR.accent or COLOR.track
        button.back:SetVertexColor(back[1], back[2], back[3], back[4] or 1)
        local color = on and { 0.1, 0.07, 0.02 } or window.COLOR.muted
        button.label:SetTextColor(color[1], color[2], color[3])
    end
end

function Graph.Select(pane, view)
    pane.view = view
    pane.key = nil
    pane.window:Render()
end

function Graph.Grid(pane, top)
    local step = top / (Graph.GRID - 1)
    for i = 1, Graph.GRID do
        local value = step * (i - 1)
        local y = value / top * Graph.PLOT_H
        local line, label = pane.grid[i], pane.gridLabels[i]
        line:ClearAllPoints()
        line:SetPoint("BOTTOMLEFT", pane.plot, "BOTTOMLEFT", 0, y)
        label:ClearAllPoints()
        label:SetPoint("RIGHT", pane.plot, "BOTTOMLEFT", -4, y)
        label:SetText(SoundAlerter.DamageMeterWindow.Num(value))
        line:Show()
        label:Show()
    end
end

local function HideGrid(pane)
    for i = 1, Graph.GRID do
        pane.grid[i]:Hide()
        pane.gridLabels[i]:Hide()
    end
end

local function Column(pane)
    return Take(pane.columns, function() return Paint(pane.marks, COLOR.pve) end)
end

local function Head(pane)
    return Take(pane.heads, function()
        local head = pane.marks:CreateTexture(nil, "OVERLAY")
        head:SetTexture(Graph.CIRCLE)
        head:SetSize(Graph.HEAD, Graph.HEAD)
        return head
    end)
end

local function Line(pane)
    return Take(pane.lines, function()
        local line = pane.lineLayer:CreateLine(nil, "OVERLAY")
        line:SetThickness(Graph.TREND_W)
        return line
    end)
end

local function Label(pane)
    return Take(pane.labels, function() return pane.window:Text(pane.lineLayer, 10, COLOR.boss, "CENTER") end)
end

local points, trend = {}, {}

function Graph.DrawTimeline(pane, session)
    local count, top = Model.Timeline(session, Graph.COLUMNS, points, trend)
    if count == 0 then return false end
    top = Graph.NiceMax(top)
    Graph.Grid(pane, top)
    local step = pane.plotW / math.max(count, pane.plotW / (Graph.COLUMN_MIN * 4))
    local width = math.max(2, step - 2)
    local color = session.kind == "pvp" and COLOR.pvp or pane.window.COLOR.accent
    local px, py
    local best, bestDps = nil, 0
    for i = 1, count do
        local fight = points[i]
        local dps = Model.FightDps(fight)
        local short = fight.seconds < Model.MIN_SECONDS
        local c = short and COLOR.short or color
        local cx, h = (i - 1) * step + width / 2, math.max(1, dps / top * Graph.PLOT_H)
        local stem = Column(pane)
        stem:SetVertexColor(c[1], c[2], c[3], 0.6)
        stem:ClearAllPoints()
        stem:SetPoint("BOTTOMLEFT", pane.plot, "BOTTOMLEFT", cx - 0.5, 0)
        stem:SetSize(1, h)
        local head = Head(pane)
        head:SetVertexColor(c[1], c[2], c[3], 1)
        head:ClearAllPoints()
        head:SetPoint("CENTER", pane.plot, "BOTTOMLEFT", cx, h)
        if not short and dps > bestDps then best, bestDps = i, dps end
        local x, y = cx, trend[i] / top * Graph.PLOT_H
        if px and trend[i] > 0 then
            local line = Line(pane)
            line:SetColorTexture(COLOR.line[1], COLOR.line[2], COLOR.line[3], 0.6)
            line:SetStartPoint("BOTTOMLEFT", pane.plot, px, py)
            line:SetEndPoint("BOTTOMLEFT", pane.plot, x, y)
        end
        if trend[i] > 0 then px, py = x, y end
    end
    if best then
        pane.bestMark:ClearAllPoints()
        pane.bestMark:SetPoint("CENTER", pane.plot, "BOTTOMLEFT", (best - 1) * step + width / 2, math.max(1, bestDps / top * Graph.PLOT_H))
        pane.bestMark:Show()
    end
    pane.step, pane.count = step, count
    pane.first:SetText("first fight")
    pane.last:SetText("last fight")
    pane.note:SetText(session.kind == "pvp" and "DPS per world PvP fight. The line is your running average, the gold ring your best fight; grey fights are under 5 s and do not count." or "DPS per fight. The line is your running average, the gold ring your best fight; grey fights are under 5 s and do not count.")
    return true
end

local pulls = {}

function Graph.DrawPulls(pane, store, session)
    local run = Model.LastRun(store, session)
    if not run then return false end
    Model.Pulls(run, pulls)
    if #pulls == 0 then return false end
    local span, top = Model.PullLayout(pulls, pane.plotW, Graph.PULL_MIN)
    top = Graph.NiceMax(top)
    Graph.Grid(pane, top)
    local Window = SoundAlerter.DamageMeterWindow
    local segments = 0
    for _, pull in ipairs(pulls) do
        local y = 0
        local party = pull.party
        if party and #party > 0 then
            for _, member in ipairs(party) do
                if segments >= Graph.SEGMENT_CAP then break end
                segments = segments + 1
                local h = member[3] / top * Graph.PLOT_H
                local column = Column(pane)
                local r, g, b = Window.ClassColor(member[2])
                column:SetVertexColor(r, g, b, 1)
                column:ClearAllPoints()
                column:SetPoint("BOTTOMLEFT", pane.plot, "BOTTOMLEFT", pull.x, y)
                column:SetSize(pull.w, math.max(1, h - 1))
                y = y + h
            end
        else
            segments = segments + 1
            local column = Column(pane)
            local accent = pane.window.COLOR.accent
            column:SetVertexColor(accent[1], accent[2], accent[3], 1)
            column:ClearAllPoints()
            column:SetPoint("BOTTOMLEFT", pane.plot, "BOTTOMLEFT", pull.x, 0)
            y = math.max(1, pull.d / top * Graph.PLOT_H)
            column:SetSize(pull.w, y)
        end
        if pull.boss or pull.deaths then
            local label = Label(pane)
            local c = pull.boss and COLOR.boss or COLOR.death
            label:SetTextColor(c[1], c[2], c[3])
            label:SetText(pull.boss or "death")
            label:ClearAllPoints()
            label:SetPoint("BOTTOM", pane.plot, "BOTTOMLEFT", pull.x + pull.w / 2, math.min(Graph.PLOT_H, y) + 3)
        end
    end
    pane.first:SetText("0:00")
    pane.last:SetText(Model.Clock(span))
    pane.note:SetText((run.name or "Dungeon") .. ": damage per pull, stacked by member. Width is how long the pull lasted; gaps are walking or resting.")
    return true
end

local rows = {}

function Graph.DrawCompare(pane, store, session)
    local list, count = Model.CompareRows(store, session, rows)
    local Window = SoundAlerter.DamageMeterWindow
    for i, row in ipairs(pane.compare) do
        local item = list[i]
        local shown = item ~= nil
        row.label:SetShown(shown) row.track:SetShown(shown) row.fill:SetShown(shown) row.value:SetShown(shown)
        row.average:SetShown(shown and item.average ~= nil)
        row.best:SetShown(shown and item.best ~= nil)
        if shown then
            local top = math.max(item.now, item.average or 0, item.best or 0) * 1.08
            if top <= 0 then top = 1 end
            local function X(value) return 90 + value / top * pane.trackW end
            row.label:SetText(item.label)
            local good = item.average == nil or ((item.now <= item.average) == (item.lower == true))
            local c = good and pane.window.COLOR.accent or COLOR.short
            row.fill:SetVertexColor(c[1], c[2], c[3], 1)
            row.fill:SetWidth(math.max(1, item.now / top * pane.trackW))
            local y = row.y
            if item.average then
                row.average:ClearAllPoints()
                row.average:SetPoint("TOPLEFT", pane, "TOPLEFT", X(item.average) - 1, y + 1)
            end
            if item.best then
                row.best:ClearAllPoints()
                row.best:SetPoint("TOPLEFT", pane, "TOPLEFT", X(item.best) - 1, y + 3)
            end
            local text = item.label == "Run time" and Model.Clock(item.now) or Window.Num(item.now)
            row.value:SetText(text)
        end
    end
    pane.first:SetText("")
    pane.last:SetText("")
    local what = session.kind == "run" and ("your earlier runs of " .. (session.name or "this dungeon")) or "your earlier sessions"
    pane.note:SetText(count > 0 and ("Bar is now, white tick your average of " .. what .. ", gold tick your best.") or ("Nothing to compare with yet: this is your first " .. (session.kind == "run" and "run here." or "session of this kind.")))
    return true
end

local function HideCompare(pane)
    for _, row in ipairs(pane.compare) do
        row.label:Hide() row.track:Hide() row.fill:Hide() row.average:Hide() row.best:Hide() row.value:Hide()
    end
end

function Graph.Key(pane, store, session)
    local run = pane.view == "pull" and Model.LastRun(store, session)
    local source = run or session
    return table.concat({ pane.view, tostring(source), source and source.count or 0, source and source.lastAt or 0 }, ":")
end

function Graph.Render(pane, session, store)
    if not pane.view then
        pane.view = (session and session.kind == "run") and "pull" or "time"
    end
    Graph.Buttons(pane)
    local key = Graph.Key(pane, store, session)
    if key == pane.key then return "same" end
    pane.key = key
    Release(pane.columns)
    Release(pane.heads)
    pane.bestMark:Hide()
    Release(pane.lines)
    Release(pane.labels)
    HideGrid(pane)
    pane.count = 0
    local drawn
    if pane.view == "cmp" then
        pane.plot:Hide()
        drawn = session ~= nil and Graph.DrawCompare(pane, store, session)
    else
        pane.plot:Show()
        HideCompare(pane)
        if pane.view == "pull" then
            drawn = Graph.DrawPulls(pane, store, session)
        else
            drawn = session ~= nil and Graph.DrawTimeline(pane, session)
        end
    end
    pane.empty:SetShown(not drawn)
    pane.note:SetShown(drawn and true or false)
    pane.first:SetShown(drawn and true or false)
    pane.last:SetShown(drawn and true or false)
    if not drawn then
        pane.empty:SetText(pane.view == "pull" and "No dungeon run yet. Pulls show here after your first one." or "No fights yet this session.")
        HideCompare(pane)
    elseif pane.view ~= "cmp" then
        pane.rise:Play()
        pane.lineLayer:SetAlpha(0)
        pane.sweep:Play()
    end
    return "drawn"
end

function Graph.HoverStart(pane)
    pane.hoverWait = 0
    pane.hoverFn = pane.hoverFn or function(_, elapsed) Graph.HoverTick(pane, elapsed) end
    pane.hover:SetScript("OnUpdate", pane.hoverFn)
end

function Graph.HoverStop(pane)
    pane.hover:SetScript("OnUpdate", nil)
    pane.hoverIndex = nil
    pane.band:Hide()
    if GameTooltip then GameTooltip:Hide() end
end

function Graph.HoverIndex(pane, cursorX)
    if pane.view ~= "time" or not pane.count or pane.count == 0 then return nil end
    local left = pane.plot:GetLeft()
    if not left then return nil end
    local index = math.floor((cursorX - left) / pane.step) + 1
    if index < 1 or index > pane.count then return nil end
    return index
end

function Graph.HoverTick(pane, elapsed)
    pane.hoverWait = pane.hoverWait - elapsed
    if pane.hoverWait > 0 then return end
    pane.hoverWait = Graph.HOVER
    local x = GetCursorPosition() / pane.plot:GetEffectiveScale()
    local index = Graph.HoverIndex(pane, x)
    if index == pane.hoverIndex then return end
    pane.hoverIndex = index
    if not index then
        pane.band:Hide()
        GameTooltip:Hide()
        return
    end
    pane.band:ClearAllPoints()
    pane.band:SetPoint("BOTTOMLEFT", pane.plot, "BOTTOMLEFT", (index - 1) * pane.step, 0)
    pane.band:SetWidth(pane.step)
    pane.band:Show()
    local fight = points[index]
    local Window = SoundAlerter.DamageMeterWindow
    local gold = Window.COLOR.gold
    GameTooltip:SetOwner(pane.hover, "ANCHOR_CURSOR")
    GameTooltip:AddLine(fight.name or ("Fight " .. index), 1, 1, 1)
    if fight.boss then GameTooltip:AddLine("Boss", gold[1], gold[2], gold[3]) end
    GameTooltip:AddDoubleLine("DPS", Window.Num(Model.FightDps(fight)), gold[1], gold[2], gold[3], 1, 1, 1)
    GameTooltip:AddDoubleLine("Damage", Window.Num(fight.damage), gold[1], gold[2], gold[3], 1, 1, 1)
    GameTooltip:AddDoubleLine("Length", Model.Clock(fight.seconds), gold[1], gold[2], gold[3], 1, 1, 1)
    if fight.deaths and fight.deaths > 0 then GameTooltip:AddDoubleLine("Deaths", tostring(fight.deaths), gold[1], gold[2], gold[3], 1, 1, 1) end
    if fight.seconds < Model.MIN_SECONDS then GameTooltip:AddLine("Under 5 s: counts in totals only", 0.6, 0.65, 0.72) end
    GameTooltip:Show()
end

SoundAlerter.DamageMeterGraph = Graph
