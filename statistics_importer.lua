-- Statistics Importer for Reading Streak plugin

local DataStorage = require("datastorage")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")
local SQ3 = require("lua-ljsqlite3/init")
local _ = require("readingstreak_gettext")
local T = require("ffi/util").template
local pcall = pcall

local StatisticsImporter = {}

function StatisticsImporter.importFromStatistics(reading_streak)
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
        
        for _, date_str in ipairs(reading_streak.settings.reading_history) do
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
        local thresholds_active = reading_streak:hasActiveThresholds()
        local page_threshold = tonumber(reading_streak.settings.daily_page_threshold) or 0
        local time_threshold = tonumber(reading_streak.settings.daily_time_threshold) or 0
        
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
            table.insert(reading_streak.settings.reading_history, date_str)
        end
        
        table.sort(reading_streak.settings.reading_history)
        
        reading_streak:cleanReadingHistory()
        reading_streak:recalculateStreakFromHistory()
        
        reading_streak:saveSettings()
        
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

return StatisticsImporter

