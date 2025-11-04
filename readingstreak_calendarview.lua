-- Calendar view showing reading history

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local FocusManager = require("ui/widget/focusmanager")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local OverlapGroup = require("ui/widget/overlapgroup")
local datetime = require("datetime")
local Input = Device.input
local Screen = Device.screen
local _ = require("readingstreak_gettext")
local T = require("ffi/util").template
local Size = require("ui/size")

local CalendarDay = InputContainer:extend{
    daynum = nil,
    filler = false,
    width = nil,
    height = nil,
    border = 0,
    is_future = false,
    is_read = false,
    font_face = "xx_smallinfofont",
    font_size = nil,
}

function CalendarDay:init()
    self.dimen = Geom:new{w = self.width, h = self.height}
    if self.filler then
        return
    end
    
    local fgcolor = self.is_future and Blitbuffer.COLOR_GRAY or Blitbuffer.COLOR_BLACK
    local bgcolor = self.is_read and Blitbuffer.COLOR_GRAY_4 or Blitbuffer.COLOR_WHITE
    
    self.daynum_w = TextWidget:new{
        text = " " .. tostring(self.daynum),
        face = Font:getFace(self.font_face, self.font_size),
        fgcolor = fgcolor,
        padding = 0,
        bold = true,
    }
    
    self[1] = FrameContainer:new{
        padding = 0,
        color = fgcolor,
        bordersize = self.border,
        background = bgcolor,
        width = self.width,
        height = self.height,
        focusable = true,
        focus_border_color = Blitbuffer.COLOR_GRAY,
        CenterContainer:new{
            dimen = { w = self.width - 2*self.border, h = self.height - 2*self.border },
            self.daynum_w,
        }
    }
end

local CalendarView = FocusManager:extend{
    reading_streak = nil,
    start_day_of_week = 2, -- Monday
    width = nil,
    height = nil,
    cur_month = nil,
    weekdays = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
}

function CalendarView:init()
    self.dimen = Geom:new{
        w = self.width or Screen:getWidth(),
        h = self.height or Screen:getHeight(),
    }
    
    if self.dimen.w == Screen:getWidth() and self.dimen.h == Screen:getHeight() then
        self.covers_fullscreen = true
    end
    
    if Device:hasKeys() then
        self.key_events.Close = { { Input.group.Back } }
        self.key_events.NextMonth = { { Input.group.PgFwd } }
        self.key_events.PrevMonth = { { Input.group.PgBack } }
    end
    
    if Device:isTouchDevice() then
        self.ges_events.Swipe = {
            GestureRange:new{
                ges = "swipe",
                range = self.dimen,
            }
        }
    end
    
    self.outer_padding = Size.padding.large
    self.inner_padding = Size.padding.small
    self.day_width = math.floor((self.dimen.w - 2*self.outer_padding - 6*self.inner_padding) * (1/7))
    self.outer_padding = math.floor((self.dimen.w - 7*self.day_width - 6*self.inner_padding) * (1/2))
    
    local now_ts = os.time()
    if not self.cur_month then
        self.cur_month = os.date("%Y-%m", now_ts)
    end
    
    -- Navigation buttons
    local chevron_left = "chevron.left"
    local chevron_right = "chevron.right"
    if BD.mirroredUILayout() then
        chevron_left, chevron_right = chevron_right, chevron_left
    end
    
    self.page_info_left = Button:new{
        icon = chevron_left,
        callback = function() self:prevMonth() end,
        bordersize = 0,
        show_parent = self,
    }
    self.page_info_right = Button:new{
        icon = chevron_right,
        callback = function() self:nextMonth() end,
        bordersize = 0,
        show_parent = self,
    }
    self.page_info = HorizontalGroup:new{
        self.page_info_left,
        HorizontalSpan:new{ width = Size.padding.default },
        self.page_info_right,
    }
    
    self.title_bar = TitleBar:new{
        fullscreen = true,
        width = self.dimen.w,
        align = "left",
        title = "",
        title_h_padding = self.outer_padding,
        close_callback = function() self:onClose() end,
        show_parent = self,
    }
    
    local footer = BottomContainer:new{
        dimen = Geom:new{w = self.dimen.w, h = self.dimen.h},
        self.page_info,
    }
    
    self.day_names = HorizontalGroup:new{}
    table.insert(self.day_names, HorizontalSpan:new{ width = self.outer_padding })
    for i = 0, 6 do
        local dayname = TextWidget:new{
            text = datetime.shortDayOfWeekTranslation[self.weekdays[(self.start_day_of_week-1+i)%7 + 1]],
            face = Font:getFace("xx_smallinfofont"),
            bold = true,
        }
        table.insert(self.day_names, FrameContainer:new{
            padding = 0,
            bordersize = 0,
            CenterContainer:new{
                dimen = Geom:new{ w = self.day_width, h = dayname:getSize().h },
                dayname,
            }
        })
        if i < 6 then
            table.insert(self.day_names, HorizontalSpan:new{ width = self.inner_padding })
        end
    end
    
    local title_height = self.title_bar:getHeight()
    local page_info_height = self.page_info:getSize().h
    local day_names_height = self.day_names:getSize().h
    local estimated_stats_height = Screen:scaleBySize(40)
    local reserved_height = title_height + page_info_height + day_names_height + estimated_stats_height
    local available_height = self.dimen.h - reserved_height
    local max_week_height = math.floor((available_height - 6*self.inner_padding) * (1/6))
    self.week_height = math.min(self.day_width, max_week_height)
    self.week_height = math.max(30, self.week_height)
    
    self.day_border = Size.border.default
    self.span_font_size = 12
    
    self.main_content = VerticalGroup:new{}
    self:_populateItems()
    
    local content = VerticalGroup:new{
        align = "left",
        self.title_bar,
        self.day_names,
        HorizontalGroup:new{
            HorizontalSpan:new{ width = self.outer_padding },
            self.main_content,
        },
    }
    
    self[1] = FrameContainer:new{
        width = self.dimen.w,
        height = self.dimen.h,
        padding = 0,
        margin = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        OverlapGroup:new{
            dimen = self.dimen:copy(),
            content,
            footer,
        }
    }
end

function CalendarView:_populateItems()
    self.main_content:clear()
    
    local month_start_ts = os.time({
        year = self.cur_month:sub(1,4),
        month = self.cur_month:sub(6),
        day = 1,
    })
    
    local month_name = os.date("%B", month_start_ts)
    local month_text = (datetime.longMonthTranslation[month_name] or month_name) .. os.date(" %Y", month_start_ts)
    self.title_bar:setTitle(month_text)
    local reading_history = {}
    if self.reading_streak and self.reading_streak.settings and self.reading_streak.settings.reading_history then
        reading_history = self.reading_streak.settings.reading_history
    end
    local reading_days = {}
    for _, date_str in ipairs(reading_history) do
        reading_days[date_str] = true
    end
    
    table.insert(self.main_content, VerticalSpan:new{ width = self.inner_padding })
    
    local month_days_read = 0
    local month_total_days = 0
    for _, date_str in ipairs(reading_history) do
        if date_str:sub(1, 7) == self.cur_month then
            month_days_read = month_days_read + 1
        end
    end
    local year = tonumber(self.cur_month:sub(1,4))
    local month = tonumber(self.cur_month:sub(6, 7))
    local month_end_ts = os.time({
        year = year,
        month = month + 1,
        day = 0,
    })
    month_total_days = os.date("*t", month_end_ts).day
    
    local cur_ts = month_start_ts
    local cur_date = os.date("*t", cur_ts)
    local this_month = cur_date.month
    local cur_week
    local today_s = os.date("%Y-%m-%d", os.time())
    
    while true do
        cur_date = os.date("*t", cur_ts)
        if cur_date.month ~= this_month then
            break
        end
        
        if not cur_week or cur_date.wday == self.start_day_of_week then
            if cur_week then
                table.insert(self.main_content, VerticalSpan:new{ width = self.inner_padding })
            end
            
            cur_week = HorizontalGroup:new{
                dimen = Geom:new{ w = self.dimen.w - 2*self.outer_padding, h = self.week_height },
            }
            table.insert(self.main_content, cur_week)
            
            if cur_date.wday ~= self.start_day_of_week then
                local day = self.start_day_of_week
                while day ~= cur_date.wday do
                    table.insert(cur_week, CalendarDay:new{
                        filler = true,
                        height = self.week_height,
                        width = self.day_width,
                        border = self.day_border,
                        font_face = self.weekdays[1],
                        font_size = self.span_font_size,
                    })
                    if #cur_week > 1 then
                        table.insert(cur_week, HorizontalSpan:new{ width = self.inner_padding })
                    end
                    day = day + 1
                    if day == 8 then day = 1 end
                end
            end
        end
        
        local day_s = os.date("%Y-%m-%d", cur_ts)
        local is_future = day_s > today_s
        local is_read = reading_days[day_s] == true
        
        local calendar_day = CalendarDay:new{
            daynum = cur_date.day,
            height = self.week_height,
            width = self.day_width,
            border = self.day_border,
            is_future = is_future,
            is_read = is_read,
            font_face = "xx_smallinfofont",
            font_size = self.span_font_size,
        }
        
        if #cur_week > 0 then
            table.insert(cur_week, HorizontalSpan:new{ width = self.inner_padding })
        end
        table.insert(cur_week, calendar_day)
        
        cur_ts = cur_ts + 86400
    end
    
    if cur_week then
        local days_in_week = 0
        for i = 1, #cur_week do
            local item = cur_week[i]
            if type(item) == "table" and (item.daynum ~= nil or item.filler) then
                days_in_week = days_in_week + 1
            end
        end
        
        local days_to_complete = 7 - days_in_week
        
        if days_to_complete > 0 then
            for i = 1, days_to_complete do
                if #cur_week > 0 then
                    table.insert(cur_week, HorizontalSpan:new{ width = self.inner_padding })
                end
                table.insert(cur_week, CalendarDay:new{
                    filler = true,
                    height = self.week_height,
                    width = self.day_width,
                    border = self.day_border,
                    font_face = self.weekdays[1],
                    font_size = self.span_font_size,
                })
            end
        end
    end
    
    table.insert(self.main_content, VerticalSpan:new{ width = self.inner_padding * 2 })
    
    local stats_text = T(_("%1 days read out of %2"), month_days_read, month_total_days)
    local stats_widget = TextWidget:new{
        text = stats_text,
        face = Font:getFace("smallinfofont"),
        bold = true,
    }
    
    local stats_frame = FrameContainer:new{
        padding = Size.padding.default,
        bordersize = Size.border.thin,
        background = Blitbuffer.COLOR_GRAY_E,
        CenterContainer:new{
            dimen = Geom:new{ w = self.dimen.w - 2*self.outer_padding, h = stats_widget:getSize().h + 2*Size.padding.default },
            stats_widget,
        }
    }
    table.insert(self.main_content, stats_frame)
    
    local display_mode = "both"
    if self.reading_streak and self.reading_streak.settings and self.reading_streak.settings.calendar_streak_display then
        display_mode = self.reading_streak.settings.calendar_streak_display
    end
    
    local current_streak = (self.reading_streak and self.reading_streak.settings and self.reading_streak.settings.current_streak) or 0
    local current_week_streak = (self.reading_streak and self.reading_streak.settings and self.reading_streak.settings.current_week_streak) or 0
    
    if display_mode == "days" or display_mode == "both" then
        table.insert(self.main_content, VerticalSpan:new{ width = Size.padding.default })
        local day_text = current_streak == 1 and _("1 day") or T(_("%1 days"), current_streak)
        local streak_days_widget = TextWidget:new{
            text = T(_("Current streak: %1"), day_text),
            face = Font:getFace("smallinfofont"),
            bold = true,
        }
        
        local streak_days_frame = FrameContainer:new{
            padding = Size.padding.default,
            bordersize = Size.border.thin,
            background = Blitbuffer.COLOR_GRAY_E,
            CenterContainer:new{
                dimen = Geom:new{ w = self.dimen.w - 2*self.outer_padding, h = streak_days_widget:getSize().h + 2*Size.padding.default },
                streak_days_widget,
            }
        }
        table.insert(self.main_content, streak_days_frame)
    end
    
    if display_mode == "weeks" or display_mode == "both" then
        table.insert(self.main_content, VerticalSpan:new{ width = Size.padding.default })
        local week_text = current_week_streak == 1 and _("1 week") or T(_("%1 weeks"), current_week_streak)
        local streak_weeks_widget = TextWidget:new{
            text = T(_("Current week streak: %1"), week_text),
            face = Font:getFace("smallinfofont"),
            bold = true,
        }
        
        local streak_weeks_frame = FrameContainer:new{
            padding = Size.padding.default,
            bordersize = Size.border.thin,
            background = Blitbuffer.COLOR_GRAY_E,
            CenterContainer:new{
                dimen = Geom:new{ w = self.dimen.w - 2*self.outer_padding, h = streak_weeks_widget:getSize().h + 2*Size.padding.default },
                streak_weeks_widget,
            }
        }
        table.insert(self.main_content, streak_weeks_frame)
    end
    
    local footer_height = self.page_info:getSize().h
    table.insert(self.main_content, VerticalSpan:new{ width = footer_height + Size.padding.default })
    
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function CalendarView:nextMonth()
    local year = tonumber(self.cur_month:sub(1,4))
    local month = tonumber(self.cur_month:sub(6))
    month = month + 1
    if month > 12 then
        month = 1
        year = year + 1
    end
    self.cur_month = string.format("%04d-%02d", year, month)
    self:_populateItems()
    UIManager:setDirty(self, "full")
end

function CalendarView:prevMonth()
    local year = tonumber(self.cur_month:sub(1,4))
    local month = tonumber(self.cur_month:sub(6))
    month = month - 1
    if month < 1 then
        month = 12
        year = year - 1
    end
    self.cur_month = string.format("%04d-%02d", year, month)
    self:_populateItems()
    UIManager:setDirty(self, "full")
end

function CalendarView:onNextMonth()
    self:nextMonth()
    return true
end

function CalendarView:onPrevMonth()
    self:prevMonth()
    return true
end

function CalendarView:onSwipe(arg, ges_ev)
    local direction = BD.flipDirectionIfMirroredUILayout(ges_ev.direction)
    if direction == "west" then
        self:nextMonth()
        return true
    elseif direction == "east" then
        self:prevMonth()
        return true
    elseif direction == "south" then
        self:onClose()
    end
end

function CalendarView:onClose()
    UIManager:close(self)
    UIManager:setDirty(nil, "full")
    return true
end

return CalendarView

