--[[
    Project Title Integration for Reading Streak

    This module patches Project Title to display the reading streak widget
    in the footer area, between the footer text and pagination.

    The integration is automatically enabled when "Export to Project Title"
    setting is enabled in Reading Streak plugin settings.
--]]

local logger = require("logger")
local userpatch = require("userpatch")
local PluginShare = require("pluginshare")
local TextWidget = require("ui/widget/textwidget")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local Geom = require("ui/geometry")

local ProjectTitleIntegration = {}

local is_registered = false
local is_unavailable = false

local function projectTitleAvailable()
    local ok_pt, ptutil = pcall(require, "ptutil")
    if not ok_pt or not ptutil then
        return false
    end
    local ok_bim, BookInfoManager = pcall(require, "bookinfomanager")
    if not ok_bim or not BookInfoManager then
        return false
    end
    return true
end

-- Helper function to create and insert the streak widget
local function createStreakWidget(menu_instance)
    if not menu_instance or not menu_instance.page_info or not menu_instance.inner_dimen then
        return
    end
    if menu_instance.reading_streak_widget then
        return
    end

    local ok_pt, ptutil = pcall(require, "ptutil")
    local ok_bim, BookInfoManager = pcall(require, "bookinfomanager")
    if not ok_pt or not ptutil or not ok_bim or not BookInfoManager then
        logger.warn("ReadingStreak: Project Title modules missing, skipping streak widget")
        return
    end

    -- Use same font and size as footer text
    local footer_font_face = ptutil.good_serif
    local footer_font_size = 20
    local ok_setting, replace_footer = pcall(function()
        return BookInfoManager:getSetting("replace_footer_text")
    end)
    if ok_setting and replace_footer then
        footer_font_face = ptutil.good_sans
        footer_font_size = 18
    end

    menu_instance.reading_streak_widget = TextWidget:new {
        text = "",
        face = Font:getFace(footer_font_face, footer_font_size),
        max_width = menu_instance.screen_w * 0.94,
    }

    local page_info_size = menu_instance.page_info:getSize()
    local streak_geom = Geom:new {
        w = menu_instance.screen_w * 0.94,
        h = page_info_size and page_info_size.h or 0,
    }

    local streak_container = CenterContainer:new {
        dimen = streak_geom,
        menu_instance.reading_streak_widget,
    }

    menu_instance.reading_streak_container = BottomContainer:new {
        dimen = menu_instance.inner_dimen:copy(),
        streak_container
    }

    -- Insert widget into footer OverlapGroup
    if menu_instance[1] and menu_instance[1][1] then
        local footer = menu_instance[1][1]
        if footer and footer.allow_mirroring == false then
            -- Find page_controls and insert before it
            local page_controls_index = nil
            for i, item in ipairs(footer) do
                if item and item.dimen and type(item[1]) == "table" then
                    local inner = item[1]
                    if inner and inner.dimen and inner.dimen.w == menu_instance.screen_w * 0.98 then
                        page_controls_index = i
                        break
                    end
                end
            end

            if page_controls_index then
                table.insert(footer, page_controls_index, menu_instance.reading_streak_container)
            else
                table.insert(footer, #footer, menu_instance.reading_streak_container)
            end
        end
    end

    -- Update widget text
    local function updateWidgetText()
        if menu_instance.reading_streak_widget and PluginShare and PluginShare.readingstreak then
            local rs = PluginShare.readingstreak
            if rs.current_streak and rs.current_streak > 0 then
                local symbol = "⚡"
                local text = rs.getStreakText and rs.getStreakText() or tostring(rs.current_streak) .. " days"
                menu_instance.reading_streak_widget:setText(symbol .. " " .. text)
                return true
            end
        end
        return false
    end

    if not updateWidgetText() then
        -- Schedule update after Reading Streak has loaded
        local UIManager = require("ui/uimanager")
        UIManager:nextTick(updateWidgetText)
    end
end

local function safeCreateStreakWidget(menu_instance)
    local ok, err = pcall(createStreakWidget, menu_instance)
    if not ok then
        logger.warn("ReadingStreak: Project Title widget failed", tostring(err))
    end
end

-- Register patch function for Project Title
function ProjectTitleIntegration.register()
    if is_registered or is_unavailable then
        return
    end

    if not projectTitleAvailable() then
        is_unavailable = true
        logger.warn("ReadingStreak: Project Title not found, skipping integration")
        return
    end

    logger.info("ReadingStreak: Registering Project Title integration")

    local function patchCoverBrowser(plugin)
        local ok_cm, CoverMenu = pcall(require, "covermenu")
        if not ok_cm or not CoverMenu or type(CoverMenu.menuInit) ~= "function" then
            logger.warn("ReadingStreak: CoverMenu not found, skipping Project Title patch")
            return
        end
        if not projectTitleAvailable() then
            logger.warn("ReadingStreak: Project Title not found, skipping CoverMenu patch")
            return
        end

        -- Patch CoverMenu.menuInit to add widget
        local _CoverMenu_menuInit_orig = CoverMenu.menuInit
        CoverMenu.menuInit = function(self)
            _CoverMenu_menuInit_orig(self)
            safeCreateStreakWidget(self)
        end

        -- Patch CoverMenu.updatePageInfo to update widget text
        if type(CoverMenu.updatePageInfo) == "function" then
            local _CoverMenu_updatePageInfo_orig = CoverMenu.updatePageInfo
            CoverMenu.updatePageInfo = function(self, is_pathchooser)
                _CoverMenu_updatePageInfo_orig(self, is_pathchooser)

                if self.reading_streak_widget and PluginShare and PluginShare.readingstreak then
                    local rs = PluginShare.readingstreak
                    if rs.current_streak and rs.current_streak > 0 then
                        local symbol = "⚡"
                        local text = rs.getStreakText and rs.getStreakText() or tostring(rs.current_streak) .. " days"
                        self.reading_streak_widget:setText(symbol .. " " .. text)
                    end
                end
            end
        end

        local Menu = require("ui/widget/menu")
        if Menu.init == _CoverMenu_menuInit_orig then
            Menu.init = CoverMenu.menuInit
        end

        local UIManager = require("ui/uimanager")
        UIManager:nextTick(function()
            local FileManager = require("apps/filemanager/filemanager")
            if FileManager.instance and FileManager.instance.file_chooser then
                local file_chooser = FileManager.instance.file_chooser
                if file_chooser[1] and file_chooser[1][1] and
                   file_chooser[1][1].allow_mirroring == false and
                   not file_chooser.reading_streak_widget then
                    safeCreateStreakWidget(file_chooser)
                    -- Force UI update
                    UIManager:setDirty(file_chooser.show_parent, "partial")
                    if file_chooser.updatePageInfo then
                        file_chooser:updatePageInfo()
                    end
                end
            end
        end)
    end

    userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
    is_registered = true
    logger.info("ReadingStreak: Project Title integration registered")

    local UIManager = require("ui/uimanager")
    UIManager:nextTick(function()
        local ok_pl, PluginLoader = pcall(require, "pluginloader")
        if not ok_pl or not PluginLoader or not PluginLoader.getPluginInstance then
            return
        end
        local plugin_instance = PluginLoader:getPluginInstance("coverbrowser")
        if plugin_instance then
            local ok, err = pcall(patchCoverBrowser, plugin_instance)
            if not ok then
                logger.warn("ReadingStreak: Project Title patch failed", tostring(err))
            end
        end
    end)
end

return ProjectTitleIntegration
