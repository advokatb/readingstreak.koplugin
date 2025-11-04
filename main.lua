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

local DEFAULT_DAILY_PAGE_THRESHOLD = 0
local DEFAULT_DAILY_TIME_THRESHOLD = 0 -- seconds
local MAX_TRACKED_INTERVAL = 45 * 60

local ReadingStreak = WidgetContainer:extend{
    name = "readingstreak",
    is_doc_only = false,
}

function ReadingStreak:init()
    self.settings_file = DataStorage:getSettingsDir() .. "/reading_streak.lua"
    self:loadSettings()
    self.last_page_update_time = nil
    self.last_page_number = nil
    self:ensureDailyProgressState()

    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
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
    
end

function ReadingStreak:onReaderReady()
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
    local ok, stored = pcall(dofile, self.settings_file)
    if ok and stored then
        self.settings = stored
        local had_invalid = false
        if self.settings.reading_history then
            for _, date_str in ipairs(self.settings.reading_history) do
                if date_str == "%Y-%m-%d" or (date_str and type(date_str) == "string" and not date_str:match("^%d%d%d%d%-%d%d%-%d%d$")) then
                    had_invalid = true
                    break
                end
            end
        end
        if self.settings.first_read_date == "%Y-%m-%d" or (self.settings.first_read_date and not self.settings.first_read_date:match("^%d%d%d%d%-%d%d%-%d%d$")) then
            had_invalid = true
        end
        local had_cleanup = self:cleanReadingHistory()
        if not self.settings.reading_history then
            self.settings.reading_history = {}
        end
        if (had_invalid or had_cleanup) and #self.settings.reading_history > 0 then
            self:recalculateStreakFromHistory()
            self:saveSettings()
        elseif #self.settings.reading_history > 0 and not self.settings.current_streak then
            self:recalculateStreakFromHistory()
            self:saveSettings()
        end
        if not self.settings.streak_goal then
            self.settings.streak_goal = 7
        end
        if not self.settings.show_notifications then
            self.settings.show_notifications = true
        end
        if not self.settings.auto_track then
            self.settings.auto_track = true
        end
        if not self.settings.calendar_streak_display then
            self.settings.calendar_streak_display = "both"
        end
        if self.settings.daily_page_threshold == nil then
            self.settings.daily_page_threshold = DEFAULT_DAILY_PAGE_THRESHOLD
        end
        if self.settings.daily_time_threshold == nil then
            self.settings.daily_time_threshold = DEFAULT_DAILY_TIME_THRESHOLD
        end
        if not self.settings.daily_progress or type(self.settings.daily_progress) ~= "table" then
            self.settings.daily_progress = {}
        end
    else
        self.settings = {
            current_streak = 0,
            longest_streak = 0,
            current_week_streak = 0,
            longest_week_streak = 0,
            last_read_date = nil,
            first_read_date = nil,
            total_days = 0,
            streak_goal = 7,
            reading_history = {},
            show_notifications = true,
            auto_track = true,
            calendar_streak_display = "both",
            daily_page_threshold = DEFAULT_DAILY_PAGE_THRESHOLD,
            daily_time_threshold = DEFAULT_DAILY_TIME_THRESHOLD,
            daily_progress = {},
        }
    end
end

function ReadingStreak:saveSettings()
    local f = io.open(self.settings_file, "w")
    if f then
        local content = "return " .. self:serializeTable(self.settings)
        f:write(content)
        f:close()
    else
        logger.err("ReadingStreak: Failed to save settings", {file = self.settings_file})
    end
end

function ReadingStreak:serializeTable(tbl)
    local result = "{"
    for k, v in pairs(tbl) do
        local key = type(k) == "string" and string.format("%q", k) or tostring(k)
        local value
        if type(v) == "table" then
            value = self:serializeTable(v)
        elseif type(v) == "string" then
            value = string.format("%q", v)
        else
            value = tostring(v)
        end
        result = result .. "[" .. key .. "]=" .. value .. ","
    end
    result = result .. "}"
    return result
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

function ReadingStreak:hasActiveThresholds()
    local page_threshold = tonumber(self.settings.daily_page_threshold) or 0
    local time_threshold = tonumber(self.settings.daily_time_threshold) or 0
    return page_threshold > 0 or time_threshold > 0
end

function ReadingStreak:resetDailyProgress(today)
    self.settings.daily_progress = {
        date = today,
        pages = 0,
        duration = 0,
        completed = false,
        notified = false,
        notified_date = nil,
    }
    self.last_page_update_time = os.time()
    self.last_page_number = nil
    self:saveSettings()
end

function ReadingStreak:ensureDailyProgressState()
    local today = self:getTodayString()
    local progress = self.settings.daily_progress
    if type(progress) ~= "table" or progress.date ~= today then
        self:resetDailyProgress(today)
        return
    end
    if progress.pages == nil then
        progress.pages = 0
    end
    if progress.duration == nil then
        progress.duration = 0
    end
    if progress.completed == nil then
        progress.completed = false
    end
    if progress.notified == nil then
        progress.notified = false
    end
    if progress.notified_date ~= today then
        progress.notified = false
        progress.notified_date = today
    end
end

function ReadingStreak:updateDailyProgress(pageno)
    self:ensureDailyProgressState()
    local progress = self.settings.daily_progress
    local now = os.time()
    local progress_changed = false

    if self.last_page_number and pageno and pageno ~= self.last_page_number then
        if self.last_page_update_time then
            local diff = now - self.last_page_update_time
            if diff > 0 then
                diff = math.min(diff, MAX_TRACKED_INTERVAL)
                progress.duration = (progress.duration or 0) + diff
                progress_changed = true
            end
        end
        progress.pages = (progress.pages or 0) + 1
        progress_changed = true
    end

    if pageno then
        self.last_page_number = pageno
    end
    self.last_page_update_time = now

    if progress_changed and not progress.completed then
        self:saveSettings()
    end
end

function ReadingStreak:hasMetDailyGoal()
    local progress = self.settings.daily_progress or {}
    local page_threshold = tonumber(self.settings.daily_page_threshold) or 0
    local time_threshold = tonumber(self.settings.daily_time_threshold) or 0

    if page_threshold > 0 then
        if (progress.pages or 0) < page_threshold then
            return false
        end
    end

    if time_threshold > 0 then
        if (progress.duration or 0) < time_threshold then
            return false
        end
    end

    return true
end

function ReadingStreak:showDailyGoalAchievementMessage()
    if not self:hasActiveThresholds() then
        return
    end
    if self.settings.show_notifications and not (self.settings.daily_progress and self.settings.daily_progress.notified) then
        UIManager:show(InfoMessage:new{
            text = _("Congratulations! You've met today's streak target!"),
            timeout = nil,
        })
        if self.settings.daily_progress then
            self.settings.daily_progress.notified = true
            self.settings.daily_progress.notified_date = self:getTodayString()
            self:saveSettings()
        end
    end
end

function ReadingStreak:cleanReadingHistory()
    if not self.settings.reading_history then
        return false
    end
    
    local original_count = #self.settings.reading_history
    local cleaned = {}
    for _, date_str in ipairs(self.settings.reading_history) do
        if date_str and type(date_str) == "string" and date_str:match("^%d%d%d%d%-%d%d%-%d%d$") then
            table.insert(cleaned, date_str)
        end
    end
    
    local had_changes = false
    if #cleaned ~= original_count then
        had_changes = true
    end
    
    self.settings.reading_history = cleaned
    table.sort(self.settings.reading_history)
    
    if self.settings.first_read_date == "%Y-%m-%d" or (self.settings.first_read_date and not self.settings.first_read_date:match("^%d%d%d%d%-%d%d%-%d%d$")) then
        had_changes = true
        if #self.settings.reading_history > 0 then
            self.settings.first_read_date = self.settings.reading_history[1]
        else
            self.settings.first_read_date = nil
        end
    end
    
    return had_changes
end

function ReadingStreak:recalculateStreakFromHistory()
    if not self.settings.reading_history or #self.settings.reading_history == 0 then
        self.settings.current_streak = 0
        self.settings.longest_streak = 0
        self.settings.current_week_streak = 0
        self.settings.longest_week_streak = 0
        self.settings.first_read_date = nil
        self.settings.last_read_date = nil
        self.settings.total_days = 0
        return
    end
    
    local history = self.settings.reading_history
    table.sort(history)
    
    self.settings.first_read_date = history[1]
    self.settings.last_read_date = history[#history]
    self.settings.total_days = #history
    
    local longest_streak = 1
    local temp_streak = 1
    
    for i = 2, #history do
        local days_diff = self:dateDiffDays(history[i-1], history[i])
        if days_diff == 1 then
            temp_streak = temp_streak + 1
            longest_streak = math.max(longest_streak, temp_streak)
        else
            temp_streak = 1
        end
    end
    
    local current_streak = 1
    local last_date = history[#history]
    local today = self:getTodayString()
    local days_since_last = self:dateDiffDays(last_date, today)
    
    if days_since_last == 0 then
        temp_streak = 1
        for i = #history, 2, -1 do
            local days_diff = self:dateDiffDays(history[i-1], history[i])
            if days_diff == 1 then
                temp_streak = temp_streak + 1
            else
                break
            end
        end
        current_streak = temp_streak
    elseif days_since_last == 1 then
        temp_streak = 1
        for i = #history, 2, -1 do
            local days_diff = self:dateDiffDays(history[i-1], history[i])
            if days_diff == 1 then
                temp_streak = temp_streak + 1
            else
                break
            end
        end
        current_streak = temp_streak
    else
        current_streak = 0
    end
    
    self.settings.current_streak = current_streak
    self.settings.longest_streak = longest_streak
    
    local week_streaks = {}
    for i = 1, #history do
        local week = self:getWeekNumber(history[i])
        week_streaks[week] = (week_streaks[week] or 0) + 1
    end
    
    local sorted_weeks = {}
    for week, _ in pairs(week_streaks) do
        table.insert(sorted_weeks, week)
    end
    table.sort(sorted_weeks)
    
    if #sorted_weeks > 0 then
        local longest_week_streak = 1
        local temp_week_streak = 1
        
        for i = 2, #sorted_weeks do
            local last_year, last_num = sorted_weeks[i-1]:match("(%d+)-W(%d+)")
            local this_year, this_num = sorted_weeks[i]:match("(%d+)-W(%d+)")
            
            last_year = tonumber(last_year)
            last_num = tonumber(last_num)
            this_year = tonumber(this_year)
            this_num = tonumber(this_num)
            
            if (this_year == last_year and this_num == last_num + 1) or
               (this_year == last_year + 1 and this_num == 1 and last_num >= 52) then
                temp_week_streak = temp_week_streak + 1
                longest_week_streak = math.max(longest_week_streak, temp_week_streak)
            else
                temp_week_streak = 1
            end
        end
        
        local last_week = sorted_weeks[#sorted_weeks]
        local last_week_year, last_week_num = last_week:match("(%d+)-W(%d+)")
        local today_week = self:getWeekNumber(today)
        local today_week_year, today_week_num = today_week:match("(%d+)-W(%d+)")
        
        last_week_year = tonumber(last_week_year)
        last_week_num = tonumber(last_week_num)
        today_week_year = tonumber(today_week_year)
        today_week_num = tonumber(today_week_num)
        
        local days_since_last = self:dateDiffDays(history[#history], today)
        
        if days_since_last == 0 or days_since_last == 1 then
            local current_week_streak = temp_week_streak
            if (today_week_year == last_week_year and today_week_num == last_week_num + 1) or
               (today_week_year == last_week_year + 1 and today_week_num == 1 and last_week_num >= 52) then
                current_week_streak = current_week_streak + 1
            end
            self.settings.current_week_streak = math.max(1, current_week_streak)
        else
            self.settings.current_week_streak = 0
        end
        
        self.settings.longest_week_streak = longest_week_streak
    else
        self.settings.current_week_streak = 0
        self.settings.longest_week_streak = 0
    end
end

function ReadingStreak:checkStreak()
    local today = self:getTodayString()

    self:ensureDailyProgressState()
    if self.settings.daily_progress and self.settings.daily_progress.completed then
        return
    end

    if self.settings.last_read_date == today then
        if self.settings.daily_progress then
            self.settings.daily_progress.completed = true
        end
        return
    end

    local found_today = false
    for _, date_str in ipairs(self.settings.reading_history) do
        if date_str == today then
            found_today = true
            break
        end
    end

    if not found_today then
        if not self:hasMetDailyGoal() then
            return
        end
        table.insert(self.settings.reading_history, today)
        table.sort(self.settings.reading_history)
        self:recalculateStreakFromHistory()
        self.settings.last_read_date = today
        if self.settings.daily_progress then
            self.settings.daily_progress.completed = true
            if self.settings.show_notifications ~= false and not self.settings.daily_progress.notified then
                self:showDailyGoalAchievementMessage()
            end
        else
            if self.settings.show_notifications ~= false then
                self:showDailyGoalAchievementMessage()
            end
        end
        self:saveSettings()

        if self.settings.show_notifications and self.settings.current_streak == self.settings.streak_goal then
            UIManager:show(InfoMessage:new{
                text = T(_("Congratulations! You've reached your streak goal of %1 days!"), self.settings.streak_goal),
                timeout = 5,
            })
        end
    else
        if self.settings.daily_progress then
            self.settings.daily_progress.completed = true
            if self.settings.show_notifications ~= false and not self.settings.daily_progress.notified then
                self.settings.daily_progress.notified = true
            end
        end
    end
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
    
    local message = string.format(
        "%s %s: %s\n\n%s (%s):\n%s\n\n%s: %s\n%s: %s\n%s: %s\n%s: %s\n\n%s: %s\n%s: %s",
        emoji,
        _("Current Streak"), day_text,
        _("Progress to goal"), goal_day_text, progress_bar,
        _("Longest Streak"), longest_day_text,
        _("Current Week Streak"), week_streak_text,
        _("Longest Week Streak"), longest_week_text,
        _("Total Days Read"), total_day_text,
        _("First Read"), self.settings.first_read_date or _("Never"),
        _("Last Read"), self.settings.last_read_date or _("Never")
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
        local CalendarView = require("calendarview")
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

function ReadingStreak:showSettings()
    local ok, err = pcall(function()
        local ReadingStreakSettings = require("settings")
        local settings_dialog = ReadingStreakSettings:new{
            reading_streak = self,
        }
        settings_dialog:showSettingsDialog()
    end)
    if not ok then
        logger.err("ReadingStreak: Error showing settings", {error = tostring(err)})
        UIManager:show(InfoMessage:new{
            text = T(_("Error showing settings: %1"), tostring(err)),
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
    local db_location = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
    
    if lfs.attributes(db_location, "mode") ~= "file" then
        UIManager:show(InfoMessage:new{
            text = _("Statistics database not found."),
            timeout = 3,
        })
        return
    end
    
    local ok, err = pcall(function()
        local conn = SQ3.open(db_location)
        if not conn then
            error("Failed to open statistics database")
        end
        
        local sql_stmt = [[
            SELECT date,
                   COUNT(*) AS page_count,
                   SUM(duration) AS total_duration
            FROM (
                SELECT strftime('%Y-%m-%d', start_time, 'unixepoch', 'localtime') AS date,
                       id_book,
                       page,
                       SUM(duration) AS duration
                FROM page_stat
                GROUP BY date, id_book, page
            )
            GROUP BY date
            ORDER BY date ASC
        ]]

        local stmt = conn:prepare(sql_stmt)
        local stats_rows = {}
        while true do
            local row = stmt:step()
            if not row then
                break
            end
            local date_str = row[1]
            if date_str then
                local pages = tonumber(row[2]) or 0
                local duration = tonumber(row[3]) or 0
                table.insert(stats_rows, {
                    date = date_str,
                    pages = pages,
                    duration = duration,
                })
            end
        end
        stmt:close()

        local imported_dates = {}
        local existing_dates = {}
        
        for _, date_str in ipairs(self.settings.reading_history) do
            if date_str and type(date_str) == "string" and date_str:match("^%d%d%d%d%-%d%d%-%d%d$") then
                existing_dates[date_str] = true
            end
        end
        
        if #stats_rows == 0 then
            conn:close()
            UIManager:show(InfoMessage:new{
                text = _("No reading statistics found in database."),
                timeout = 3,
            })
            return
        end
        
        local new_dates_count = 0
        local skipped_threshold_count = 0
        local thresholds_active = self:hasActiveThresholds()
        local page_threshold = tonumber(self.settings.daily_page_threshold) or 0
        local time_threshold = tonumber(self.settings.daily_time_threshold) or 0
        
        for i = 1, #stats_rows do
            local date_entry = stats_rows[i]
            local date_str = date_entry.date
            local matches = date_str and type(date_str) == "string" and date_str:match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil
            
            if date_str and type(date_str) == "string" and matches and not existing_dates[date_str] then
                local meets_threshold = true
                if thresholds_active then
                    if page_threshold > 0 and (date_entry.pages or 0) < page_threshold then
                        meets_threshold = false
                    end
                    if time_threshold > 0 and (date_entry.duration or 0) < time_threshold then
                        meets_threshold = false
                    end
                end

                if meets_threshold then
                    table.insert(imported_dates, date_str)
                    existing_dates[date_str] = true
                    new_dates_count = new_dates_count + 1
                elseif thresholds_active then
                    skipped_threshold_count = skipped_threshold_count + 1
                end
            end
        end
        
        conn:close()
        
        if new_dates_count == 0 then
            local message
            if thresholds_active and skipped_threshold_count > 0 then
                message = _("No days met the configured daily targets.")
            else
                message = _("No new reading statistics found in database.")
            end
            UIManager:show(InfoMessage:new{
                text = message,
                timeout = 3,
            })
            return
        end
        
        for _, date_str in ipairs(imported_dates) do
            table.insert(self.settings.reading_history, date_str)
        end
        
        table.sort(self.settings.reading_history)
        
        self:cleanReadingHistory()
        self:recalculateStreakFromHistory()
        
        self:saveSettings()
        
        local info_text
        if thresholds_active and skipped_threshold_count > 0 then
            info_text = T(_("Imported %1 reading days; skipped %2 days below daily targets."), new_dates_count, skipped_threshold_count)
        else
            info_text = T(_("Imported %1 reading days from statistics database."), new_dates_count)
        end
        UIManager:show(InfoMessage:new{
            text = info_text,
            timeout = 5,
        })
    end)
    
    if not ok then
        logger.err("ReadingStreak: Error importing statistics", {error = tostring(err)})
        UIManager:show(InfoMessage:new{
            text = T(_("Error importing statistics: %1"), tostring(err)),
            timeout = 5,
        })
    end
end

function ReadingStreak:addToMainMenu(menu_items)
    menu_items.reading_streak = {
        text = _("Reading Streak"),
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
                callback = function()
                    self:showSettings()
                end,
            },
        }
    }
end

function ReadingStreak:addToFileManagerMenu(menu_items)
    self:addToMainMenu(menu_items)
end

return ReadingStreak
