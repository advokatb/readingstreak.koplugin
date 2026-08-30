-- Streak notification display helper for Reading Streak plugin

local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Notification = require("ui/widget/notification")

local StreakNotifications = {}

function StreakNotifications.show(text, settings, timeout)
    if settings.toast_notifications then
        UIManager:show(Notification:new{
            text = text,
            timeout = timeout or 3,
        })
    else
        UIManager:show(InfoMessage:new{
            text = text,
            timeout = timeout,
        })
    end
end

return StreakNotifications
