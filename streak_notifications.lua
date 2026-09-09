-- Streak notification display helper for Reading Streak plugin

local Blitbuffer = require("ffi/blitbuffer")
local InfoMessage = require("ui/widget/infomessage")
local Notification = require("ui/widget/notification")
local StreakColors = require("streak_colors")
local UIManager = require("ui/uimanager")
local _ = require("lib/readingstreak_i18n").gettext

local StreakNotifications = {}

StreakNotifications.TOAST_COLORS = StreakColors.TOAST_COLORS
StreakNotifications.colorScreenEnabled = StreakColors.colorScreenEnabled
StreakNotifications.colorLabel = StreakColors.toastLabel

-- Stock Notification hardcodes a white FrameContainer. On colour screens
-- FrameContainer already paints ColorRGB32 via paintRoundedRectRGB32, so
-- retint the frame (and the inner TextWidget) after init.
local function tintToast(notif, settings)
    if not StreakColors.shouldTint() then return end
    if not notif.frame then return end
    local r, g, b = StreakColors.parseHex(settings and settings.toast_bg_color)
    if not r then return end
    notif.frame.background = Blitbuffer.ColorRGB32(r, g, b, 0xFF)
    local text_widget = notif.frame[1] and notif.frame[1][1]
    if text_widget then
        text_widget.fgcolor = StreakColors.fgForBg(r, g, b)
    end
end

function StreakNotifications.show(text, settings, timeout)
    if settings.toast_notifications then
        local notif = Notification:new{
            text = text,
            timeout = timeout or 3,
        }
        tintToast(notif, settings)
        UIManager:show(notif)
    else
        UIManager:show(InfoMessage:new{
            text = text,
            timeout = timeout,
        })
    end
end

function StreakNotifications.preview(settings)
    local notif = Notification:new{
        text = _("Toast color preview"),
        timeout = 2,
    }
    tintToast(notif, settings)
    UIManager:show(notif)
end

return StreakNotifications
