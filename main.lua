-- Reading Streak plugin for KOReader

local DataStorage = require("datastorage")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Screen = require("device").screen
local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")
local SQ3 = require("lua-ljsqlite3/init")
local _ = require("readingstreak_gettext")
local T = require("ffi/util").template
local SettingsManager = require("settings_manager")
local DailyProgress = require("daily_progress")
local StreakCalculator = require("streak_calculator")
local TimeStats = require("time_stats")
local StatisticsImporter = require("statistics_importer")
local Dispatcher = require("dispatcher")
local Menu = require("ui/widget/menu")
local PluginShare = require("pluginshare")


local ReadingStreak = WidgetContainer:extend{
    name = "readingstreak",
    is_doc_only = false,
}

function ReadingStreak:init()
    -- Log plugin version on load
    local version = self.version or "unknown"
    logger.info("ReadingStreak plugin v" .. version .. " loaded")
    
    self.settings_file = DataStorage:getSettingsDir() .. "/reading_streak.lua"
    self:loadSettings()
    self.last_page_update_time = nil
    self.last_page_number = nil
    self:ensureDailyProgressState()

    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
        self._menu_registered = true
    end

    local had_cleanup = self:cleanReadingHistory()
    if #self.settings.reading_history > 0 then
        local needs_recalc = had_cleanup
        if not self.settings.first_read_date or not self.settings.last_read_date then
            needs_recalc = true
        elseif self.settings.first_read_date == "%Y-%m-%d" or 
               (self.settings.first_read_date and not self.settings.first_read_date:match("^%d%d%d%d%-%d%d%-%d%d$")) then
            needs_recalc = true
        elseif not self.settings.current_streak or self.settings.current_streak == 0 then
            needs_recalc = true
        end
        if needs_recalc then
            self:recalculateStreakFromHistory()
            self:saveSettings()
        end
        local today = self:getTodayString()
        if self.settings.last_read_date ~= today then
            local found_today = false
            for _, date_str in ipairs(self.settings.reading_history) do
                if date_str == today then
                    found_today = true
                    break
                end
            end
            if found_today and self.settings.last_read_date then
                local days_diff = self:dateDiffDays(self.settings.last_read_date, today)
                if days_diff == 0 then
                    self.settings.last_read_date = today
                    self:saveSettings()
                end
            end
        end
    else
        self:checkStreak()
    end
    
    -- Register actions with dispatcher for gesture assignment
    self:onDispatcherRegisterActions()
    
    -- Initialize PluginShare API if enabled
    self:updatePluginShareAPI()
    
    -- Register Project Title integration if enabled
    if self.settings.export_to_projecttitle then
        local ok, ProjectTitleIntegration = pcall(require, "projecttitle_integration")
        if ok and ProjectTitleIntegration then
            ProjectTitleIntegration.register()
        else
            logger.warn("ReadingStreak: Failed to load Project Title integration", ProjectTitleIntegration)
        end
    end
end

function ReadingStreak:onReaderReady()
    -- Ensure menu is registered in reader mode (in case it wasn't available during init)
    if self.ui and self.ui.menu and not self._menu_registered then
        self.ui.menu:registerToMainMenu(self)
        self._menu_registered = true
    end
    
    self:ensureDailyProgressState()
    self.last_page_update_time = os.time()
    self.last_page_number = nil
    if self.settings.auto_track ~= false then
        if not self:hasActiveThresholds() then
            self:checkStreak()
        end
    end
end

function ReadingStreak:onPageUpdate(pageno)
    if self.settings.auto_track ~= false then
        self:updateDailyProgress(pageno)
        self:checkStreak()
    end
end

function ReadingStreak:loadSettings()
    SettingsManager.loadSettings(self)
end

function ReadingStreak:saveSettings()
    SettingsManager.saveSettings(self)
end

function ReadingStreak:serializeTable(tbl)
    return SettingsManager.serializeTable(tbl)
end

function ReadingStreak:getTodayString()
    return os.date("%Y-%m-%d")
end

function ReadingStreak:dateDiffDays(date1, date2)
    local y1, m1, d1 = date1:match("(%d+)-(%d+)-(%d+)")
    local y2, m2, d2 = date2:match("(%d+)-(%d+)-(%d+)")
    local time1 = os.time({year=y1, month=m1, day=d1})
    local time2 = os.time({year=y2, month=m2, day=d2})
    return math.floor((time2 - time1) / 86400)
end

function ReadingStreak:getWeekNumber(date_str)
    local y, m, d = date_str:match("(%d+)%-(%d+)%-(%d+)")
    local t = os.time({year=y, month=m, day=d})
    local date = os.date("*t", t)
    local wday = date.wday == 1 and 7 or date.wday - 1
    local jan1 = os.time({year=date.year, month=1, day=1})
    local jan1date = os.date("*t", jan1)
    local jan1wday = jan1date.wday == 1 and 7 or jan1date.wday - 1
    local days_from_start = date.yday - 1
    local week_start_offset = (wday - jan1wday + 7) % 7
    local week_num = math.floor((days_from_start + week_start_offset) / 7) + 1
    return date.year .. "-W" .. string.format("%02d", week_num)
end

function ReadingStreak:formatTime(seconds)
    return TimeStats.formatTime(seconds)
end

function ReadingStreak:getWeeklyReadingTime()
    return TimeStats.getWeeklyReadingTime(self)
end

function ReadingStreak:getWeekStartDate(date_str)
    return TimeStats.getWeekStartDate(self, date_str)
end

function ReadingStreak:getWeekEndDate(date_str)
    return TimeStats.getWeekEndDate(self, date_str)
end

function ReadingStreak:hasActiveThresholds()
    return DailyProgress.hasActiveThresholds(self)
end

function ReadingStreak:resetDailyProgress(today)
    DailyProgress.resetDailyProgress(self, today)
end

function ReadingStreak:ensureDailyProgressState()
    DailyProgress.ensureDailyProgressState(self)
end

function ReadingStreak:updateDailyProgress(pageno)
    DailyProgress.updateDailyProgress(self, pageno)
    -- Update PluginShare API after progress update
    self:updatePluginShareAPI()
end

function ReadingStreak:hasMetDailyGoal()
    return DailyProgress.hasMetDailyGoal(self)
end

function ReadingStreak:showDailyGoalAchievementMessage()
    DailyProgress.showDailyGoalAchievementMessage(self)
end

function ReadingStreak:cleanReadingHistory()
    return StreakCalculator.cleanReadingHistory(self)
end

function ReadingStreak:recalculateStreakFromHistory()
    StreakCalculator.recalculateStreakFromHistory(self)
end

function ReadingStreak:checkStreak()
    StreakCalculator.checkStreak(self)
    -- Update PluginShare API after streak check
    self:updatePluginShareAPI()
end

function ReadingStreak:getStreakEmoji()
    local streak = self.settings.current_streak
    if streak >= 365 then
        return "[*]"
    elseif streak >= 100 then
        return "[+]"
    elseif streak >= 30 then
        return "[!]"
    elseif streak >= 7 then
        return "[*]"
    else
        return "[ ]"
    end
end

function ReadingStreak:showStreakInfo()
    local streak = self.settings.current_streak
    local longest = self.settings.longest_streak
    local week_streak = self.settings.current_week_streak
    local longest_week = self.settings.longest_week_streak
    local total = self.settings.total_days
    local goal = self.settings.streak_goal
    local emoji = self:getStreakEmoji()
    local progress = math.min(100, math.floor((streak / goal) * 100))
    local progress_bar = self:createProgressBar(progress)
    local day_text = streak == 1 and _("1 day") or T(_("%1 days"), streak)
    local longest_day_text = longest == 1 and _("1 day") or T(_("%1 days"), longest)
    local total_day_text = total == 1 and _("1 day") or T(_("%1 days"), total)
    local goal_day_text = goal == 1 and _("1 day") or T(_("%1 days"), goal)
    local week_streak_text = week_streak == 1 and _("1 week") or T(_("%1 weeks"), week_streak)
    local longest_week_text = longest_week == 1 and _("1 week") or T(_("%1 weeks"), longest_week)
    
    -- Get reading time and pages
    self:ensureDailyProgressState()
    local today_time = 0
    local today_pages = 0
    if self.settings.daily_progress and self.settings.daily_progress.date == self:getTodayString() then
        today_time = self.settings.daily_progress.duration or 0
        today_pages = self.settings.daily_progress.pages or 0
    end
    local today_time_text = self:formatTime(today_time)
    local today_pages_text = T(_("%1 pages"), today_pages)
    
    local weekly_time = self:getWeeklyReadingTime()
    local weekly_time_text = self:formatTime(weekly_time)
    
    local message = string.format(
        "%s %s: %s\n\n%s (%s):\n%s\n\n%s: %s\n%s: %s\n%s: %s\n%s: %s\n\n%s: %s\n%s: %s\n\n%s: %s\n%s: %s\n%s: %s",
        emoji,
        _("Current Streak"), day_text,
        _("Progress to goal"), goal_day_text, progress_bar,
        _("Longest Streak"), longest_day_text,
        _("Current Week Streak"), week_streak_text,
        _("Longest Week Streak"), longest_week_text,
        _("Total Days Read"), total_day_text,
        _("First Read"), self.settings.first_read_date or _("Never"),
        _("Last Read"), self.settings.last_read_date or _("Never"),
        _("Today's Pages Read"), today_pages_text,
        _("Today's Reading Time"), today_time_text,
        _("This Week's Reading Time"), weekly_time_text
    )

    UIManager:show(InfoMessage:new{
        text = message,
        timeout = 10,
    })
end

function ReadingStreak:createProgressBar(percentage)
    local bar_length = 20
    local filled = math.floor(bar_length * percentage / 100)
    local empty = bar_length - filled

    return "[" .. string.rep("=", filled) .. string.rep("-", empty) .. "] " .. percentage .. "%"
end

function ReadingStreak:showCalendar()
    local ok, err = pcall(function()
        local CalendarView = require("readingstreak_calendarview")
        local calendar = CalendarView:new{
            reading_streak = self,
            width = Screen:getWidth(),
            height = Screen:getHeight(),
        }
        UIManager:show(calendar)
    end)
    if not ok then
        logger.err("ReadingStreak: Error showing calendar", {error = tostring(err)})
        UIManager:show(InfoMessage:new{
            text = T(_("Error showing calendar: %1"), tostring(err)),
            timeout = 5,
        })
    end
end


function ReadingStreak:resetStreak()
    self.settings.current_streak = 0
    self.settings.longest_streak = 0
    self.settings.current_week_streak = 0
    self.settings.longest_week_streak = 0
    self.settings.last_read_date = nil
    self.settings.first_read_date = nil
    self.settings.total_days = 0
    self.settings.reading_history = {}
    self:saveSettings()

    UIManager:show(InfoMessage:new{
        text = _("Reading streak has been reset!"),
    })
end

function ReadingStreak:importFromStatistics()
    StatisticsImporter.importFromStatistics(self)
end

function ReadingStreak:addToMainMenu(menu_items)
    menu_items.reading_streak = {
        text = "⚡ " .. _("Reading Streak"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = _("View Streak"),
                callback = function()
                    self:showStreakInfo()
                end,
            },
            {
                text = _("Calendar View"),
                callback = function()
                    self:showCalendar()
                end,
            },
            {
                text = _("Settings"),
                sub_item_table_func = function()
                    local inline_settings = require("settings_inline")
                    return inline_settings.build(self)
                end,
            },
        }
    }
end

function ReadingStreak:addToFileManagerMenu(menu_items)
    self:addToMainMenu(menu_items)
end

function ReadingStreak:onDispatcherRegisterActions()
    Dispatcher:registerAction("readingstreak_view", {
        category = "none",
        event = "ShowReadingStreakView",
        title = _("Reading Streak") .. " - " .. _("View Streak"),
        general = true,
        reader = true,
        separator = false,
    })
    Dispatcher:registerAction("readingstreak_calendar", {
        category = "none",
        event = "ShowReadingStreakCalendar",
        title = _("Reading Streak") .. " - " .. _("Calendar View"),
        general = true,
        reader = true,
        separator = true,
    })
end

function ReadingStreak:onShowReadingStreakView()
    self:showStreakInfo()
end

function ReadingStreak:onShowReadingStreakCalendar()
    self:showCalendar()
end

-- PluginShare API for integration with other plugins
function ReadingStreak:updatePluginShareAPI()
    logger.dbg("ReadingStreak: updatePluginShareAPI called", {
        has_pluginShare = PluginShare ~= nil,
        export_to_projecttitle = self.settings.export_to_projecttitle,
        export_to_coverbrowser = self.settings.export_to_coverbrowser
    })
    
    if not PluginShare then
        logger.warn("ReadingStreak: PluginShare not available")
        return
    end
    
    -- Only export if at least one integration is enabled
    if not self.settings.export_to_projecttitle and not self.settings.export_to_coverbrowser then
        PluginShare.readingstreak = nil
        logger.dbg("ReadingStreak: No integrations enabled, clearing PluginShare")
        return
    end
    
    -- Register Project Title integration based on setting
    if self.settings.export_to_projecttitle then
        local ok, ProjectTitleIntegration = pcall(require, "projecttitle_integration")
        if ok and ProjectTitleIntegration then
            ProjectTitleIntegration.register()
        end
    end
    
    self:ensureDailyProgressState()
    local today_time = 0
    local today_pages = 0
    if self.settings.daily_progress and self.settings.daily_progress.date == self:getTodayString() then
        today_time = self.settings.daily_progress.duration or 0
        today_pages = self.settings.daily_progress.pages or 0
    end
    
    PluginShare.readingstreak = {
        current_streak = self.settings.current_streak or 0,
        longest_streak = self.settings.longest_streak or 0,
        current_week_streak = self.settings.current_week_streak or 0,
        longest_week_streak = self.settings.longest_week_streak or 0,
        total_days = self.settings.total_days or 0,
        streak_goal = self.settings.streak_goal or 7,
        today_pages = today_pages,
        today_time = today_time,
        weekly_time = self:getWeeklyReadingTime(),
        -- Formatted strings for easy display
        getStreakText = function()
            local streak = self.settings.current_streak or 0
            if streak == 0 then
                return _("No streak")
            elseif streak == 1 then
                return _("1 day")
            else
                return T(_("%1 days"), streak)
            end
        end,
        getStreakEmoji = function()
            return self:getStreakEmoji()
        end,
        -- Raw values for custom formatting
        getStreakNumber = function()
            return self.settings.current_streak or 0
        end,
    }
    
    logger.dbg("ReadingStreak: PluginShare data exported", {
        current_streak = PluginShare.readingstreak.current_streak,
        has_getStreakText = PluginShare.readingstreak.getStreakText ~= nil,
        has_getStreakEmoji = PluginShare.readingstreak.getStreakEmoji ~= nil
    })
end

return ReadingStreak
