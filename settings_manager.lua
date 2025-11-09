-- Settings Manager for Reading Streak plugin

local logger = require("logger")
local dofile = dofile
local io = io
local pcall = pcall

local DEFAULT_DAILY_PAGE_THRESHOLD = 0
local DEFAULT_DAILY_TIME_THRESHOLD = 0

local SettingsManager = {}

function SettingsManager.loadSettings(reading_streak)
    local ok, stored = pcall(dofile, reading_streak.settings_file)
    if ok and stored then
        reading_streak.settings = stored
        local had_invalid = false
        if reading_streak.settings.reading_history then
            for _, date_str in ipairs(reading_streak.settings.reading_history) do
                if date_str == "%Y-%m-%d" or (date_str and type(date_str) == "string" and not date_str:match("^%d%d%d%d%-%d%d%-%d%d$")) then
                    had_invalid = true
                    break
                end
            end
        end
        if reading_streak.settings.first_read_date == "%Y-%m-%d" or (reading_streak.settings.first_read_date and not reading_streak.settings.first_read_date:match("^%d%d%d%d%-%d%d%-%d%d$")) then
            had_invalid = true
        end
        local had_cleanup = reading_streak:cleanReadingHistory()
        if not reading_streak.settings.reading_history then
            reading_streak.settings.reading_history = {}
        end
        if (had_invalid or had_cleanup) and #reading_streak.settings.reading_history > 0 then
            reading_streak:recalculateStreakFromHistory()
            reading_streak:saveSettings()
        elseif #reading_streak.settings.reading_history > 0 and not reading_streak.settings.current_streak then
            reading_streak:recalculateStreakFromHistory()
            reading_streak:saveSettings()
        end
        if not reading_streak.settings.streak_goal then
            reading_streak.settings.streak_goal = 7
        end
        if not reading_streak.settings.show_notifications then
            reading_streak.settings.show_notifications = true
        end
        if not reading_streak.settings.auto_track then
            reading_streak.settings.auto_track = true
        end
        if not reading_streak.settings.calendar_streak_display then
            reading_streak.settings.calendar_streak_display = "both"
        end
        if reading_streak.settings.daily_page_threshold == nil then
            reading_streak.settings.daily_page_threshold = DEFAULT_DAILY_PAGE_THRESHOLD
        end
        if reading_streak.settings.daily_time_threshold == nil then
            reading_streak.settings.daily_time_threshold = DEFAULT_DAILY_TIME_THRESHOLD
        end
        if not reading_streak.settings.daily_progress or type(reading_streak.settings.daily_progress) ~= "table" then
            reading_streak.settings.daily_progress = {}
        end
    else
        reading_streak.settings = {
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

function SettingsManager.saveSettings(reading_streak)
    local f = io.open(reading_streak.settings_file, "w")
    if f then
        local content = "return " .. SettingsManager.serializeTable(reading_streak.settings)
        f:write(content)
        f:close()
    else
        logger.err("ReadingStreak: Failed to save settings", {file = reading_streak.settings_file})
    end
end

function SettingsManager.serializeTable(tbl)
    local result = "{"
    for k, v in pairs(tbl) do
        local key = type(k) == "string" and string.format("%q", k) or tostring(k)
        local value
        if type(v) == "table" then
            value = SettingsManager.serializeTable(v)
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

return SettingsManager

