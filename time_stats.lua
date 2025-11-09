-- Time Statistics Manager for Reading Streak plugin

local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")
local SQ3 = require("lua-ljsqlite3/init")
local _ = require("readingstreak_gettext")
local T = require("ffi/util").template
local pcall = pcall

local TimeStats = {}

function TimeStats.formatTime(seconds)
    seconds = tonumber(seconds) or 0
    if seconds < 60 then
        return T(_("%1 seconds"), seconds)
    elseif seconds < 3600 then
        local minutes = math.floor(seconds / 60)
        return T(_("%1 minutes"), minutes)
    else
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        if minutes > 0 then
            return T(_("%1 hours %2 minutes"), hours, minutes)
        else
            return T(_("%1 hours"), hours)
        end
    end
end

function TimeStats.getWeekStartDate(reading_streak, date_str)
    local y, m, d = date_str:match("(%d+)%-(%d+)%-(%d+)")
    local t = os.time({year=y, month=m, day=d})
    local date = os.date("*t", t)
    local wday = date.wday == 1 and 7 or date.wday - 1
    local days_to_subtract = wday - 1
    local week_start = os.time({year=date.year, month=date.month, day=date.day}) - (days_to_subtract * 86400)
    local week_start_date = os.date("*t", week_start)
    return string.format("%04d-%02d-%02d", week_start_date.year, week_start_date.month, week_start_date.day)
end

function TimeStats.getWeekEndDate(reading_streak, date_str)
    local y, m, d = date_str:match("(%d+)%-(%d+)%-(%d+)")
    local t = os.time({year=y, month=m, day=d})
    local date = os.date("*t", t)
    local wday = date.wday == 1 and 7 or date.wday - 1
    local days_to_add = 7 - wday
    local week_end = os.time({year=date.year, month=date.month, day=date.day}) + (days_to_add * 86400)
    local week_end_date = os.date("*t", week_end)
    return string.format("%04d-%02d-%02d", week_end_date.year, week_end_date.month, week_end_date.day)
end

function TimeStats.getWeeklyReadingTime(reading_streak)
    local today = reading_streak:getTodayString()
    local week_start_date = TimeStats.getWeekStartDate(reading_streak, today)
    local week_end_date = TimeStats.getWeekEndDate(reading_streak, today)
    
    local total_time = 0
    
    -- Try to get weekly time from statistics database if available (more accurate)
    local db_location = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
    if lfs.attributes(db_location, "mode") == "file" then
        local ok, result = pcall(function()
            local conn = SQ3.open(db_location)
            if not conn then
                return nil
            end
            
            local sql_stmt = string.format([[
                SELECT SUM(duration) AS total_duration
                FROM page_stat
                WHERE strftime('%%Y-%%m-%%d', start_time, 'unixepoch', 'localtime') >= '%s'
                  AND strftime('%%Y-%%m-%%d', start_time, 'unixepoch', 'localtime') <= '%s'
            ]], week_start_date, week_end_date)
            
            local stmt = conn:prepare(sql_stmt)
            local row = stmt:step()
            local duration = 0
            if row then
                duration = tonumber(row[1]) or 0
            end
            stmt:close()
            conn:close()
            
            return duration
        end)
        
        if ok and result then
            total_time = result
        end
    end
    
    -- If database not available, use daily_progress for today only
    if total_time == 0 then
        reading_streak:ensureDailyProgressState()
        if reading_streak.settings.daily_progress and reading_streak.settings.daily_progress.date == today then
            total_time = reading_streak.settings.daily_progress.duration or 0
        end
    end
    
    return total_time
end

return TimeStats

