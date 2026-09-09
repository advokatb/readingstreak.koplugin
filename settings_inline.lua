local UIManager = require("ui/uimanager")
local Device = require("device")
local SpinWidget = require("ui/widget/spinwidget")
local ConfirmBox = require("ui/widget/confirmbox")
local StreakColors = require("streak_colors")
local StreakNotifications = require("streak_notifications")
local _ = require("lib/readingstreak_i18n").gettext
local T = require("ffi/util").template
local Screen = Device.screen

local M = {}

local function thresholdText(value, unit)
    value = tonumber(value) or 0
    if value <= 0 then return _("Off") end
    if unit == "pages" then return T(_("%1 pages"), value) end
    if unit == "minutes" then return T(_("%1 minutes"), value) end
    return tostring(value)
end

local function buildColorItems(presets, get_current, set_current, on_preview)
    local items = {}
    for _, preset in ipairs(presets) do
        local hex = preset.hex
        table.insert(items, {
            text = preset.label,
            checked_func = function()
                local current = get_current()
                if not hex then
                    return current == nil or current == false or current == ""
                end
                return current == hex
            end,
            radio = true,
            keep_menu_open = true,
            check_callback_updates_menu = true,
            callback = function(menu_instance)
                set_current(hex or false)
                if on_preview then on_preview() end
                if menu_instance and menu_instance.updateItems then menu_instance:updateItems() end
            end,
        })
    end
    return items
end

function M.build(self)
    local items = {}

    -- Goals submenu
    table.insert(items, {
        text = _("Goals"),
        sub_item_table = {
            {
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
            },
            {
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
            },
            {
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
            },
        },
    })

    -- Tracking submenu
    table.insert(items, {
        text = _("Tracking"),
        sub_item_table = {
            {
                text = _("Automatically track reading"),
                checked_func = function() return self.settings.auto_track ~= false end,
                keep_menu_open = true,
                check_callback_updates_menu = true,
                callback = function(menu_instance)
                    self.settings.auto_track = not (self.settings.auto_track ~= false)
                    self:saveSettings()
                    if menu_instance and menu_instance.updateItems then menu_instance:updateItems() end
                end,
            },
            {
                text = _("Show streak notifications"),
                checked_func = function() return self.settings.show_notifications ~= false end,
                keep_menu_open = true,
                check_callback_updates_menu = true,
                callback = function(menu_instance)
                    self.settings.show_notifications = not (self.settings.show_notifications ~= false)
                    self:saveSettings()
                    if menu_instance and menu_instance.updateItems then menu_instance:updateItems() end
                end,
            },
            {
                text = _("Use toast notifications"),
                checked_func = function() return self.settings.toast_notifications == true end,
                keep_menu_open = true,
                check_callback_updates_menu = true,
                callback = function(menu_instance)
                    self.settings.toast_notifications = not (self.settings.toast_notifications == true)
                    self:saveSettings()
                    if menu_instance and menu_instance.updateItems then menu_instance:updateItems() end
                end,
            },
        },
    })

    -- Colors submenu (colour screens only)
    if Screen.isColorEnabled and Screen:isColorEnabled() then
        local toast_color_items = buildColorItems(
            StreakColors.TOAST_COLORS,
            function() return self.settings.toast_bg_color end,
            function(v)
                self.settings.toast_bg_color = v
                self:saveSettings()
            end,
            function() StreakNotifications.preview(self.settings) end
        )
        local calendar_color_items = buildColorItems(
            StreakColors.CALENDAR_COLORS,
            function() return self.settings.calendar_fill_color end,
            function(v)
                self.settings.calendar_fill_color = v
                self:saveSettings()
            end,
            nil
        )
        table.insert(items, {
            text = _("Colors"),
            help_text = _("Colour options for toast notifications and calendar. Colour screens only; greyscale and night mode keep stock colours."),
            sub_item_table = {
                {
                    text_func = function()
                        return T(_("Toast color: %1"), StreakColors.toastLabel(self.settings.toast_bg_color))
                    end,
                    help_text = _("Background color for toast notifications. Greyscale and night mode keep the stock white toast."),
                    sub_item_table = toast_color_items,
                },
                {
                    text_func = function()
                        return T(_("Calendar fill: %1"), StreakColors.calendarLabel(self.settings.calendar_fill_color))
                    end,
                    help_text = _("Fill color for days with a reading streak in the calendar. Greyscale and night mode keep the stock gray fill."),
                    sub_item_table = calendar_color_items,
                },
            },
        })
    end

    -- Display submenu
    table.insert(items, {
        text = _("Display"),
        sub_item_table = {
            {
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
            },
        },
    })

    -- UI Integration submenu
    table.insert(items, {
        text = _("UI Integration"),
        sub_item_table = {
            {
                text = _("Export to Project Title"),
                checked_func = function() return self.settings.export_to_projecttitle == true end,
                keep_menu_open = true,
                check_callback_updates_menu = true,
                callback = function(menu_instance)
                    self.settings.export_to_projecttitle = not (self.settings.export_to_projecttitle == true)
                    self:saveSettings()
                    self:updatePluginShareAPI()
                    if menu_instance and menu_instance.updateItems then menu_instance:updateItems() end
                end,
            },
        },
    })

    -- Data Management submenu
    table.insert(items, {
        text = _("Data Management"),
        sub_item_table = {
            {
                text = _("Import from Statistics"),
                callback = function() self:importFromStatistics() end,
            },
            {
                text = _("Reset All Data"),
                callback = function()
                    UIManager:show(ConfirmBox:new{
                        text = _("Are you sure you want to reset all reading streak data?"),
                        ok_text = _("Reset"),
                        ok_callback = function() self:resetStreak() end,
                    })
                end,
            },
        },
    })

    return items
end

return M
