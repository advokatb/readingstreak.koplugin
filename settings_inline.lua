local UIManager = require("ui/uimanager")
local SpinWidget = require("ui/widget/spinwidget")
local ConfirmBox = require("ui/widget/confirmbox")
local _ = require("readingstreak_gettext")
local T = require("ffi/util").template

local M = {}

local function thresholdText(value, unit)
    value = tonumber(value) or 0
    if value <= 0 then return _("Off") end
    if unit == "pages" then return T(_("%1 pages"), value) end
    if unit == "minutes" then return T(_("%1 minutes"), value) end
    return tostring(value)
end

function M.build(self)
    local items = {}

    table.insert(items, {
        text_func = function()
            return T(_("Streak Goal: %1 days"), self.settings.streak_goal or 7)
        end,
        keep_menu_open = true,
        callback = function(menu_instance)
            local goal_spin = SpinWidget:new{
                title_text = _("Streak Goal"),
                value = self.settings.streak_goal or 7,
                value_min = 1,
                value_max = 365,
                default_value = 7,
                callback = function(spin)
                    if spin then
                        self.settings.streak_goal = spin.value
                        self:saveSettings()
                        if menu_instance and menu_instance.updateItems then menu_instance:updateItems() end
                    end
                end,
            }
            UIManager:show(goal_spin)
        end,
    })

    table.insert(items, { text = _("Daily Targets"), enabled = false })

    table.insert(items, {
        text_func = function()
            return T(_("Daily page target: %1"), thresholdText(self.settings.daily_page_threshold or 0, "pages"))
        end,
        keep_menu_open = true,
        callback = function(menu_instance)
            local page_spin = SpinWidget:new{
                title_text = _("Daily Page Target"),
                value = self.settings.daily_page_threshold or 0,
                value_min = 0,
                value_max = 2000,
                default_value = 0,
                value_step = 1,
                callback = function(spin)
                    if spin then
                        self.settings.daily_page_threshold = spin.value
                        self:ensureDailyProgressState()
                        self:saveSettings()
                        if menu_instance and menu_instance.updateItems then menu_instance:updateItems() end
                    end
                end,
            }
            UIManager:show(page_spin)
        end,
    })

    table.insert(items, {
        text_func = function()
            return T(_("Daily time target: %1"), thresholdText(math.floor(((self.settings.daily_time_threshold or 0) + 59) / 60), "minutes"))
        end,
        keep_menu_open = true,
        callback = function(menu_instance)
            local current_minutes = math.floor(((self.settings.daily_time_threshold or 0) + 59) / 60)
            local time_spin = SpinWidget:new{
                title_text = _("Daily Time Target (minutes)"),
                value = current_minutes,
                value_min = 0,
                value_max = 600,
                default_value = 0,
                value_step = 5,
                callback = function(spin)
                    if spin then
                        self.settings.daily_time_threshold = spin.value * 60
                        self:ensureDailyProgressState()
                        self:saveSettings()
                        if menu_instance and menu_instance.updateItems then menu_instance:updateItems() end
                    end
                end,
            }
            UIManager:show(time_spin)
        end,
    })

    table.insert(items, {
        text_func = function()
            return T(_("Calendar streak display: %1"),
                (self.settings.calendar_streak_display == "days" and _("Days")) or
                (self.settings.calendar_streak_display == "weeks" and _("Weeks")) or
                _("Both"))
        end,
        keep_menu_open = true,
        callback = function(menu_instance)
            local modes = {"days", "weeks", "both"}
            local current_index = 1
            for i, mode in ipairs(modes) do
                if mode == (self.settings.calendar_streak_display or "both") then current_index = i break end
            end
            local next_index = (current_index % #modes) + 1
            self.settings.calendar_streak_display = modes[next_index]
            self:saveSettings()
            if menu_instance and menu_instance.updateItems then menu_instance:updateItems() end
        end,
    })

    table.insert(items, { text = _("Notifications"), enabled = false })

    table.insert(items, {
        text = _("Show streak notifications"),
        checked_func = function() return self.settings.show_notifications ~= false end,
        keep_menu_open = true,
        check_callback_updates_menu = true,
        callback = function(menu_instance)
            self.settings.show_notifications = not (self.settings.show_notifications ~= false)
            self:saveSettings()
            if menu_instance and menu_instance.updateItems then menu_instance:updateItems() end
        end,
    })

    table.insert(items, {
        text = _("Automatically track reading"),
        checked_func = function() return self.settings.auto_track ~= false end,
        keep_menu_open = true,
        check_callback_updates_menu = true,
        callback = function(menu_instance)
            self.settings.auto_track = not (self.settings.auto_track ~= false)
            self:saveSettings()
            if menu_instance and menu_instance.updateItems then menu_instance:updateItems() end
        end,
    })

    table.insert(items, { text = _("Data Management"), enabled = false })

    table.insert(items, {
        text = _("Import from Statistics"),
        callback = function() self:importFromStatistics() end,
    })

    table.insert(items, {
        text = _("Reset All Data"),
        callback = function()
            UIManager:show(ConfirmBox:new{
                text = _("Are you sure you want to reset all reading streak data?"),
                ok_text = _("Reset"),
                ok_callback = function() self:resetStreak() end,
            })
        end,
    })

    return items
end

return M


