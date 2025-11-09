-- Streak Calculator for Reading Streak plugin

local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("readingstreak_gettext")
local T = require("ffi/util").template

local StreakCalculator = {}

function StreakCalculator.cleanReadingHistory(reading_streak)
    if not reading_streak.settings.reading_history then
        return false
    end
    
    local original_count = #reading_streak.settings.reading_history
    local cleaned = {}
    for _, date_str in ipairs(reading_streak.settings.reading_history) do
        if date_str and type(date_str) == "string" and date_str:match("^%d%d%d%d%-%d%d%-%d%d$") then
            table.insert(cleaned, date_str)
        end
    end
    
    local had_changes = false
    if #cleaned ~= original_count then
        had_changes = true
    end
    
    reading_streak.settings.reading_history = cleaned
    table.sort(reading_streak.settings.reading_history)
    
    if reading_streak.settings.first_read_date == "%Y-%m-%d" or (reading_streak.settings.first_read_date and not reading_streak.settings.first_read_date:match("^%d%d%d%d%-%d%d%-%d%d$")) then
        had_changes = true
        if #reading_streak.settings.reading_history > 0 then
            reading_streak.settings.first_read_date = reading_streak.settings.reading_history[1]
        else
            reading_streak.settings.first_read_date = nil
        end
    end
    
    return had_changes
end

function StreakCalculator.recalculateStreakFromHistory(reading_streak)
    if not reading_streak.settings.reading_history or #reading_streak.settings.reading_history == 0 then
        reading_streak.settings.current_streak = 0
        reading_streak.settings.longest_streak = 0
        reading_streak.settings.current_week_streak = 0
        reading_streak.settings.longest_week_streak = 0
        reading_streak.settings.first_read_date = nil
        reading_streak.settings.last_read_date = nil
        reading_streak.settings.total_days = 0
        return
    end
    
    local history = reading_streak.settings.reading_history
    table.sort(history)
    
    reading_streak.settings.first_read_date = history[1]
    reading_streak.settings.last_read_date = history[#history]
    reading_streak.settings.total_days = #history
    
    local longest_streak = 1
    local temp_streak = 1
    
    for i = 2, #history do
        local days_diff = reading_streak:dateDiffDays(history[i-1], history[i])
        if days_diff == 1 then
            temp_streak = temp_streak + 1
            longest_streak = math.max(longest_streak, temp_streak)
        else
            temp_streak = 1
        end
    end
    
    local current_streak = 1
    local last_date = history[#history]
    local today = reading_streak:getTodayString()
    local days_since_last = reading_streak:dateDiffDays(last_date, today)
    
    if days_since_last == 0 then
        temp_streak = 1
        for i = #history, 2, -1 do
            local days_diff = reading_streak:dateDiffDays(history[i-1], history[i])
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
            local days_diff = reading_streak:dateDiffDays(history[i-1], history[i])
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
    
    reading_streak.settings.current_streak = current_streak
    reading_streak.settings.longest_streak = longest_streak
    
    local week_streaks = {}
    for i = 1, #history do
        local week = reading_streak:getWeekNumber(history[i])
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
        local today_week = reading_streak:getWeekNumber(today)
        local today_week_year, today_week_num = today_week:match("(%d+)-W(%d+)")
        
        last_week_year = tonumber(last_week_year)
        last_week_num = tonumber(last_week_num)
        today_week_year = tonumber(today_week_year)
        today_week_num = tonumber(today_week_num)
        
        local days_since_last = reading_streak:dateDiffDays(history[#history], today)
        
        if days_since_last == 0 or days_since_last == 1 then
            local current_week_streak = temp_week_streak
            if (today_week_year == last_week_year and today_week_num == last_week_num + 1) or
               (today_week_year == last_week_year + 1 and today_week_num == 1 and last_week_num >= 52) then
                current_week_streak = current_week_streak + 1
            end
            reading_streak.settings.current_week_streak = math.max(1, current_week_streak)
        else
            reading_streak.settings.current_week_streak = 0
        end
        
        reading_streak.settings.longest_week_streak = longest_week_streak
    else
        reading_streak.settings.current_week_streak = 0
        reading_streak.settings.longest_week_streak = 0
    end
end

function StreakCalculator.checkStreak(reading_streak)
    local today = reading_streak:getTodayString()

    reading_streak:ensureDailyProgressState()
    if reading_streak.settings.daily_progress and reading_streak.settings.daily_progress.completed then
        return
    end

    if reading_streak.settings.last_read_date == today then
        if reading_streak.settings.daily_progress then
            reading_streak.settings.daily_progress.completed = true
        end
        return
    end

    local found_today = false
    for _, date_str in ipairs(reading_streak.settings.reading_history) do
        if date_str == today then
            found_today = true
            break
        end
    end

    if not found_today then
        if not reading_streak:hasMetDailyGoal() then
            return
        end
        table.insert(reading_streak.settings.reading_history, today)
        table.sort(reading_streak.settings.reading_history)
        StreakCalculator.recalculateStreakFromHistory(reading_streak)
        reading_streak.settings.last_read_date = today
        if reading_streak.settings.daily_progress then
            reading_streak.settings.daily_progress.completed = true
            if reading_streak.settings.show_notifications ~= false and not reading_streak.settings.daily_progress.notified then
                reading_streak:showDailyGoalAchievementMessage()
            end
        else
            if reading_streak.settings.show_notifications ~= false then
                reading_streak:showDailyGoalAchievementMessage()
            end
        end
        reading_streak:saveSettings()

        if reading_streak.settings.show_notifications and reading_streak.settings.current_streak == reading_streak.settings.streak_goal then
            UIManager:show(InfoMessage:new{
                text = T(_("Congratulations! You've reached your streak goal of %1 days!"), reading_streak.settings.streak_goal),
                timeout = 5,
            })
        end
    else
        if reading_streak.settings.daily_progress then
            reading_streak.settings.daily_progress.completed = true
            if reading_streak.settings.show_notifications ~= false and not reading_streak.settings.daily_progress.notified then
                reading_streak.settings.daily_progress.notified = true
            end
        end
    end
end

return StreakCalculator

