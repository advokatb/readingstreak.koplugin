-- Settings dialog

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local CheckButton = require("ui/widget/checkbutton")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local Font = require("ui/font")
local LineWidget = require("ui/widget/linewidget")
local MovableContainer = require("ui/widget/container/movablecontainer")
local Size = require("ui/size")
local SpinWidget = require("ui/widget/spinwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local Screen = require("device").screen
local _ = require("readingstreak_gettext")
local T = require("ffi/util").template

local ReadingStreakSettings = Widget:extend{
    reading_streak = nil,
}

function ReadingStreakSettings:showSettingsDialog()
    local logger = require("logger")
    
    local ok, err = pcall(function()
        local settings_dialog
        
        local screen_width = Screen:getWidth()
        local dialog_width = math.min(screen_width - 4*Size.padding.large, Screen:scaleBySize(600))
        local title_bar = require("ui/widget/titlebar"):new{
            width = dialog_width,
            title = _("Reading Streak Settings"),
            title_h_padding = Size.padding.default,
            close_callback = function()
                if settings_dialog then
                    UIManager:close(settings_dialog)
                end
            end,
        }
        
        local settings_content = VerticalGroup:new{
            align = "left",
        }
        
        -- Section: Goals and Tracking
        local section_title = TextWidget:new{
            text = _("Goals and Tracking"),
            face = Font:getFace("smallinfofontbold"),
        }
        table.insert(settings_content, section_title)
        table.insert(settings_content, VerticalSpan:new{ width = Size.padding.small })
        
        local goal_button = require("ui/widget/button"):new{
                text = T(_("Streak Goal: %1 days"), 
                (self.reading_streak and self.reading_streak.settings and self.reading_streak.settings.streak_goal) or 7),
            callback = function()
                local goal_spin = SpinWidget:new{
                    title_text = _("Streak Goal"),
                    value = (self.reading_streak and self.reading_streak.settings and self.reading_streak.settings.streak_goal) or 7,
                    value_min = 1,
                    value_max = 365,
                    default_value = 7,
                    callback = function(spin)
                        if self.reading_streak and self.reading_streak.settings and spin then
                            self.reading_streak.settings.streak_goal = spin.value
                            if self.reading_streak.saveSettings then
                                self.reading_streak:saveSettings()
                            end
                            if settings_dialog then
                                UIManager:close(settings_dialog)
                                -- Reopen with new value
                                UIManager:scheduleIn(0.1, function()
                                    self:showSettingsDialog()
                                end)
                            end
                        end
                    end,
                }
                UIManager:show(goal_spin)
            end,
        }
        table.insert(settings_content, goal_button)
        
        table.insert(settings_content, VerticalSpan:new{ width = Size.padding.default })

        local function thresholdText(value, unit)
            value = tonumber(value) or 0
            if value <= 0 then
                return _("Off")
            end
            if unit == "pages" then
                return T(_("%1 pages"), value)
            elseif unit == "minutes" then
                return T(_("%1 minutes"), value)
            end
            return tostring(value)
        end

        local daily_target_title = TextWidget:new{
            text = _("Daily Targets"),
            face = Font:getFace("smallinfofontbold"),
        }
        table.insert(settings_content, daily_target_title)
        table.insert(settings_content, VerticalSpan:new{ width = Size.padding.small })

        local current_page_target = (self.reading_streak and self.reading_streak.settings and self.reading_streak.settings.daily_page_threshold) or 0
        local page_target_button = require("ui/widget/button"):new{
            text = T(_("Daily page target: %1"), thresholdText(current_page_target, "pages")),
            callback = function()
                local page_spin = SpinWidget:new{
                    title_text = _("Daily Page Target"),
                    value = current_page_target,
                    value_min = 0,
                    value_max = 2000,
                    default_value = 0,
                    value_step = 1,
                    callback = function(spin)
                        if self.reading_streak and self.reading_streak.settings and spin then
                            self.reading_streak.settings.daily_page_threshold = spin.value
                            if self.reading_streak.ensureDailyProgressState then
                                self.reading_streak:ensureDailyProgressState()
                            end
                            if self.reading_streak.saveSettings then
                                self.reading_streak:saveSettings()
                            end
                            if settings_dialog then
                                UIManager:close(settings_dialog)
                                UIManager:scheduleIn(0.1, function()
                                    self:showSettingsDialog()
                                end)
                            end
                        end
                    end,
                }
                UIManager:show(page_spin)
            end,
        }
        table.insert(settings_content, page_target_button)

        local current_time_target_seconds = (self.reading_streak and self.reading_streak.settings and self.reading_streak.settings.daily_time_threshold) or 0
        local current_time_target_minutes = math.floor((current_time_target_seconds + 59) / 60)
        local time_target_button = require("ui/widget/button"):new{
            text = T(_("Daily time target: %1"), thresholdText(current_time_target_minutes, "minutes")),
            callback = function()
                local time_spin = SpinWidget:new{
                    title_text = _("Daily Time Target (minutes)"),
                    value = current_time_target_minutes,
                    value_min = 0,
                    value_max = 600,
                    default_value = 0,
                    value_step = 5,
                    callback = function(spin)
                        if self.reading_streak and self.reading_streak.settings and spin then
                            local new_seconds = spin.value * 60
                            self.reading_streak.settings.daily_time_threshold = new_seconds
                            if self.reading_streak.ensureDailyProgressState then
                                self.reading_streak:ensureDailyProgressState()
                            end
                            if self.reading_streak.saveSettings then
                                self.reading_streak:saveSettings()
                            end
                            if settings_dialog then
                                UIManager:close(settings_dialog)
                                UIManager:scheduleIn(0.1, function()
                                    self:showSettingsDialog()
                                end)
                            end
                        end
                    end,
                }
                UIManager:show(time_spin)
            end,
        }
        table.insert(settings_content, time_target_button)

        table.insert(settings_content, VerticalSpan:new{ width = Size.padding.default })

        local calendar_display_mode = (self.reading_streak and self.reading_streak.settings and self.reading_streak.settings.calendar_streak_display) or "both"
        local calendar_display_button = require("ui/widget/button"):new{
            text = T(_("Calendar streak display: %1"), 
                calendar_display_mode == "days" and _("Days") or
                calendar_display_mode == "weeks" and _("Weeks") or
                _("Both")),
            callback = function()
                local modes = {"days", "weeks", "both"}
                local current_index = 1
                for i, mode in ipairs(modes) do
                    if mode == calendar_display_mode then
                        current_index = i
                        break
                    end
                end
                local next_index = (current_index % #modes) + 1
                local new_mode = modes[next_index]
                
                if self.reading_streak and self.reading_streak.settings then
                    self.reading_streak.settings.calendar_streak_display = new_mode
                    if self.reading_streak.saveSettings then
                        self.reading_streak:saveSettings()
                    end
                end
                
                if settings_dialog then
                    UIManager:close(settings_dialog)
                    UIManager:scheduleIn(0.1, function()
                        self:showSettingsDialog()
                    end)
                end
            end,
        }
        table.insert(settings_content, calendar_display_button)
        
        table.insert(settings_content, VerticalSpan:new{ width = Size.padding.default })
        table.insert(settings_content, VerticalSpan:new{ width = Size.padding.default })
        local notifications_title = TextWidget:new{
            text = _("Notifications"),
            face = Font:getFace("smallinfofontbold"),
        }
        table.insert(settings_content, notifications_title)
        table.insert(settings_content, VerticalSpan:new{ width = Size.padding.small })
        
        local notifications_check = CheckButton:new{
            text = _("Show streak notifications"),
            checked = (self.reading_streak and self.reading_streak.settings) and (self.reading_streak.settings.show_notifications ~= false) or true,
            width = dialog_width - 2*Size.padding.default,
            callback = function()
                if self.reading_streak and self.reading_streak.settings then
                    self.reading_streak.settings.show_notifications = notifications_check.checked
                    if self.reading_streak.saveSettings then
                        self.reading_streak:saveSettings()
                    end
                end
            end,
        }
        table.insert(settings_content, notifications_check)
        
        local auto_track_check = CheckButton:new{
            text = _("Automatically track reading"),
            checked = (self.reading_streak and self.reading_streak.settings) and (self.reading_streak.settings.auto_track ~= false) or true,
            width = dialog_width - 2*Size.padding.default,
            callback = function()
                if self.reading_streak and self.reading_streak.settings then
                    self.reading_streak.settings.auto_track = auto_track_check.checked
                    if self.reading_streak.saveSettings then
                        self.reading_streak:saveSettings()
                    end
                end
            end,
        }
        table.insert(settings_content, auto_track_check)
        
        table.insert(settings_content, VerticalSpan:new{ width = Size.padding.large })
        local data_title = TextWidget:new{
            text = _("Data Management"),
            face = Font:getFace("smallinfofontbold"),
        }
        table.insert(settings_content, data_title)
        table.insert(settings_content, VerticalSpan:new{ width = Size.padding.small })
        
        local import_button = require("ui/widget/button"):new{
            text = _("Import from Statistics"),
            callback = function()
                if self.reading_streak and self.reading_streak.importFromStatistics then
                    self.reading_streak:importFromStatistics()
                end
            end,
        }
        table.insert(settings_content, import_button)
        
        table.insert(settings_content, VerticalSpan:new{ width = Size.padding.default })
        
        local reset_button = require("ui/widget/button"):new{
            text = _("Reset All Data"),
            callback = function()
                local ConfirmBox = require("ui/widget/confirmbox")
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to reset all reading streak data?"),
                    ok_text = _("Reset"),
                    ok_callback = function()
                        if self.reading_streak and self.reading_streak.resetStreak then
                            self.reading_streak:resetStreak()
                            UIManager:close(settings_dialog)
                            UIManager:show(InfoMessage:new{
                                text = _("All reading streak data has been reset."),
                                timeout = 3,
                            })
                        end
                    end,
                })
            end,
        }
        table.insert(settings_content, reset_button)
        
        local dialog_frame = FrameContainer:new{
            background = Blitbuffer.COLOR_WHITE,
            padding = Size.padding.default,
            bordersize = Size.border.thin,
            margin = 0,
            width = dialog_width,
            VerticalGroup:new{
                align = "left",
                title_bar,
                LineWidget:new{
                    dimen = Geom:new{ w = dialog_width - 2*Size.padding.default, h = Size.line.thick },
                },
                settings_content,
            }
        }
        
        settings_dialog = CenterContainer:new{
            dimen = Screen:getSize(),
            MovableContainer:new{
                dialog_frame,
            }
        }
        
        title_bar.show_parent = settings_dialog
        
        UIManager:show(settings_dialog)
    end)
    
    if not ok then
        logger.err("ReadingStreakSettings: Error showing dialog", {error = tostring(err), traceback = debug.traceback()})
        UIManager:show(InfoMessage:new{
            text = T(_("Error showing settings: %1"), tostring(err)),
            timeout = 5,
        })
    end
end

return ReadingStreakSettings
