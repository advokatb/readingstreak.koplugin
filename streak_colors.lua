-- Shared colour helpers for Reading Streak (toast, calendar, …)
-- Colour e-ink / Android only; greyscale and night mode keep stock greys.

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local _ = require("lib/readingstreak_i18n").gettext
local Screen = Device.screen

local StreakColors = {}

-- Toast: nil = stock white Notification background
StreakColors.TOAST_COLORS = {
    { id = "white",  hex = nil,        label = _("White") },
    { id = "green",  hex = "#2E7D32",  label = _("Green") },
    { id = "teal",   hex = "#00796B",  label = _("Teal") },
    { id = "blue",   hex = "#1565C0",  label = _("Blue") },
    { id = "gold",   hex = "#F9A825",  label = _("Gold") },
    { id = "orange", hex = "#EF6C00",  label = _("Orange") },
    { id = "red",    hex = "#C62828",  label = _("Red") },
    { id = "gray",   hex = "#424242",  label = _("Gray") },
}

-- Calendar day fill: nil = stock COLOR_GRAY_4 (as on greyscale devices)
StreakColors.CALENDAR_COLORS = {
    { id = "gray",   hex = nil,        label = _("Gray") },
    { id = "green",  hex = "#2E7D32",  label = _("Green") },
    { id = "teal",   hex = "#00796B",  label = _("Teal") },
    { id = "blue",   hex = "#1565C0",  label = _("Blue") },
    { id = "gold",   hex = "#F9A825",  label = _("Gold") },
    { id = "orange", hex = "#EF6C00",  label = _("Orange") },
    { id = "red",    hex = "#C62828",  label = _("Red") },
}

function StreakColors.colorScreenEnabled()
    return Screen.isColorEnabled and Screen:isColorEnabled()
end

function StreakColors.shouldTint()
    if not StreakColors.colorScreenEnabled() then return false end
    if G_reader_settings and G_reader_settings:isTrue("night_mode") then return false end
    return true
end

function StreakColors.parseHex(hex)
    if type(hex) ~= "string" then return nil end
    hex = hex:match("^%s*(.-)%s*$") or ""
    if hex:sub(1, 1) == "#" then hex = hex:sub(2) end
    if #hex ~= 6 or not hex:match("^%x%x%x%x%x%x$") then return nil end
    return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

function StreakColors.fgForBg(r, g, b)
    local lum = 0.299 * r + 0.587 * g + 0.114 * b
    if lum > 160 then
        return Blitbuffer.COLOR_BLACK
    end
    return Blitbuffer.COLOR_WHITE
end

function StreakColors.colorLabel(presets, hex)
    if hex == false or hex == "" then hex = nil end
    for _, preset in ipairs(presets) do
        if preset.hex == hex then
            return preset.label
        end
    end
    return hex or presets[1].label
end

function StreakColors.toastLabel(hex)
    return StreakColors.colorLabel(StreakColors.TOAST_COLORS, hex)
end

function StreakColors.calendarLabel(hex)
    return StreakColors.colorLabel(StreakColors.CALENDAR_COLORS, hex)
end

-- Returns background (and optional fg override) for a read calendar day.
-- Stock greyscale / night / unset: COLOR_GRAY_4, no fg override (keeps black).
function StreakColors.calendarReadColors(settings)
    if not StreakColors.shouldTint() then
        return Blitbuffer.COLOR_GRAY_4, nil
    end
    local r, g, b = StreakColors.parseHex(settings and settings.calendar_fill_color)
    if not r then
        return Blitbuffer.COLOR_GRAY_4, nil
    end
    return Blitbuffer.ColorRGB32(r, g, b, 0xFF), StreakColors.fgForBg(r, g, b)
end

return StreakColors
