-- Daily Progress Manager for Reading Streak plugin

local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("readingstreak_gettext")
local os = os

local MAX_TRACKED_INTERVAL = 45 * 60

local DailyProgress = {}

function DailyProgress.hasActiveThresholds(reading_streak)
    local page_threshold = tonumber(reading_streak.settings.daily_page_threshold) or 0
    local time_threshold = tonumber(reading_streak.settings.daily_time_threshold) or 0
    return page_threshold > 0 or time_threshold > 0
end

function DailyProgress.resetDailyProgress(reading_streak, today)
    reading_streak.settings.daily_progress = {
        date = today,
        pages = 0,
        duration = 0,
        completed = false,
        notified = false,
        notified_date = nil,
    }
    reading_streak.last_page_update_time = os.time()
    reading_streak.last_page_number = nil
    reading_streak:saveSettings()
end

function DailyProgress.ensureDailyProgressState(reading_streak)
    local today = reading_streak:getTodayString()
    local progress = reading_streak.settings.daily_progress
    if type(progress) ~= "table" or progress.date ~= today then
        DailyProgress.resetDailyProgress(reading_streak, today)
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

function DailyProgress.updateDailyProgress(reading_streak, pageno)
    DailyProgress.ensureDailyProgressState(reading_streak)
    local progress = reading_streak.settings.daily_progress
    local now = os.time()
    local progress_changed = false

    if reading_streak.last_page_number and pageno and pageno ~= reading_streak.last_page_number then
        if reading_streak.last_page_update_time then
            local diff = now - reading_streak.last_page_update_time
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
        reading_streak.last_page_number = pageno
    end
    reading_streak.last_page_update_time = now

    if progress_changed and not progress.completed then
        reading_streak:saveSettings()
    end
end

function DailyProgress.hasMetDailyGoal(reading_streak)
    local progress = reading_streak.settings.daily_progress or {}
    local page_threshold = tonumber(reading_streak.settings.daily_page_threshold) or 0
    local time_threshold = tonumber(reading_streak.settings.daily_time_threshold) or 0

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

function DailyProgress.showDailyGoalAchievementMessage(reading_streak)
    if not DailyProgress.hasActiveThresholds(reading_streak) then
        return
    end
    if reading_streak.settings.show_notifications and not (reading_streak.settings.daily_progress and reading_streak.settings.daily_progress.notified) then
        UIManager:show(InfoMessage:new{
            text = _("Congratulations! You've met today's streak target!"),
            timeout = nil,
        })
        if reading_streak.settings.daily_progress then
            reading_streak.settings.daily_progress.notified = true
            reading_streak.settings.daily_progress.notified_date = reading_streak:getTodayString()
            reading_streak:saveSettings()
        end
    end
end

return DailyProgress

