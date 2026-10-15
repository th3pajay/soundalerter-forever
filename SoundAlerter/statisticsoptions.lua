local SoundAlerter = SoundAlerter

local SORT_OPTIONS = {
    topSpells = { { "count_desc", "Most alerts" }, { "trend", "Trend (rising first)" }, { "name_asc", "Name (A-Z)" }, { "time", "Most recent" } },
    enemies = { { "alerts_desc", "Most alerts" }, { "danger", "Danger" }, { "name_asc", "Name (A-Z)" }, { "time", "Most recent" } },
    classes = { { "alerts_desc", "Most alerts" }, { "players", "Most players" }, { "avg", "Alerts per player" }, { "class_asc", "Class (A-Z)" } },
}

local function statistics()
    return SoundAlerter:GetModule("Statistics", true)
end

local function view()
    local active = statistics()
    if not active then return nil end
    local on = active:GetSettings().enabled and true or false
    local data = { enabled = on, sort = {}, text = { kpi = "", overview = "", topSpells = "", enemies = "", classes = "", export = "" } }
    if not on then return data end
    local sorts = active:GetSortState()
    for key in pairs(SORT_OPTIONS) do data.sort[key] = sorts[key] and sorts[key].sortType end
    data.text.kpi = active:GetKpiText()
    data.text.overview = active:GetOverviewText()
    data.text.topSpells = active:GetListText("topSpells")
    data.text.enemies = active:GetListText("enemies")
    data.text.classes = active:GetListText("classes")
    data.text.export = active:GetExportText()
    return data
end

local function write(key, value)
    local active = statistics()
    if not active then return end
    if key == "enabled" then
        active:SetSetting("enabled", value)
        if value then
            active:InitializeStatistics()
            SoundAlerter:Print("Statistics tracking enabled")
        else
            SoundAlerter:Print("Statistics tracking disabled (existing data preserved)")
        end
        return
    end
    local table_ = key:match("^sort%.(.+)$")
    if table_ then active:SetSortState(table_, value) end
end

local function summary(settings)
    if not settings.enabled then
        return "Tracking is off. Turn it on to start counting alerts."
    end
    return settings.text.kpi
end

local function reportOn(settings)
    return settings.enabled
end

local function resetSession()
    local active = statistics()
    if not active then return end
    active:ResetSession()
    SoundAlerter:Print("Session statistics reset")
end

local function resetAllTime()
    local active = statistics()
    if not active then return end
    active:ResetAllTime()
    SoundAlerter:Print("|cffFF0000All statistics reset|r")
end

function SoundAlerter:BuildStatisticsOptions()
    local Page = SoundAlerter.Page

    local function block(label, group, getter)
        return Page.Visible(reportOn, Page.Block(label, getter, false, group))
    end

    local function sorter(key, label, group)
        return Page.Visible(reportOn, Page.Select("sort." .. key, "Sort by", "How the list below is ordered.", SORT_OPTIONS[key], false, group))
    end

    local exportRow = Page.Text("text.export", "Export", "Select all and copy to share or keep your numbers.", true, "Data", 8)
    local resetSessionRow = Page.Action("Reset session", "Reset this session's numbers. All-time statistics are kept.", resetSession, true, "Data")
    resetSessionRow.confirm = "Click again to reset"
    local resetAllRow = Page.Action("Reset all-time", "Delete all statistics for this profile, session and all-time. This cannot be undone.", resetAllTime, true, "Data")
    resetAllRow.confirm = "Click again to delete everything"

    local spec = Page.Spec({
        title = "Statistics",
        icon = "Interface\\Icons\\Spell_Holy_MindVision",
        blurb = "What triggered your alerts this session and all-time: which fired, from whom and where. Counting costs under 0.02 ms per alert.",
        get = view,
        set = write,
        summary = summary,
        rows = {
            Page.Visible(reportOn, Page.Action("Refresh", "Redraw the statistics with the latest numbers.", function() end, false, "Overview")),
            block("Overview", "Overview", function(settings) return settings.text.overview end),
            sorter("topSpells", "Sort by", "Spells"),
            block("Spells", "Spells", function(settings) return settings.text.topSpells end),
            sorter("enemies", "Sort by", "Enemies"),
            block("Enemies", "Enemies", function(settings) return settings.text.enemies end),
            sorter("classes", "Sort by", "Classes"),
            block("Classes", "Classes", function(settings) return settings.text.classes end),
            Page.Visible(reportOn, exportRow),
            Page.Visible(reportOn, resetSessionRow),
            Page.Visible(reportOn, resetAllRow),
        },
    })
    local options = Page.Options(spec, "Statistics", "Interface\\Icons\\Spell_Holy_MindVision", "Alert statistics for this profile.", 2.9)
    return Page.Guard(options, "Statistics", "Statistics", statistics)
end
