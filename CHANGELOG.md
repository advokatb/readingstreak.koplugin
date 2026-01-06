# Changelog

All notable changes to this project will be documented in this file.

## [1.3.2] - 2026-01-06

### Added
- Lightning bolt icon (⚡) to the Reading Streak main menu entry for better visual distinction among tools.

### Changed
- Version log message format unified to `ReadingStreak plugin vX.Y.Z loaded` for easier debugging.

## [1.3.1] - 2025-12-17

### Changed
- PluginShare export logging is now **debug-only** to reduce log noise during normal use.

## [1.3.0] - 2025-11-26

### Added
- **UI Integration with Project Title** - Display reading streak directly in Project Title footer (requested by [@JoeBumm](https://github.com/JoeBumm) in [#3](https://github.com/advokatb/readingstreak.koplugin/issues/3))
  - Enable "Export to Project Title" in Settings → UI Integration
  - Streak widget appears automatically between footer text and pagination
  - Shows current streak with symbol (⚡) and day count
  - Updates automatically as you read
  - Uses same font and styling as Project Title footer for consistency

### Changed
- Settings menu completely reorganized into logical submenus:
  - **Goals**: Streak Goal, Daily Page Target, Daily Time Target
  - **Tracking**: Automatically track reading, Show streak notifications
  - **Display**: Calendar streak display
  - **UI Integration**: Export to Project Title
  - **Data Management**: Import from Statistics, Reset All Data
- Removed modal settings dialog - all settings now accessible via inline menu
- Removed `USE_INLINE_SETTINGS` variable - inline menu is now the only option

### Fixed
- Settings menu structure improved for better organization

## [1.2.2] - 2025-11-09

### Added
- Gesture support for quick access to plugin features during reading
  - "Reading Streak - View Streak" action available for gesture assignment
  - "Reading Streak - Calendar View" action available for gesture assignment
  - Actions can be assigned to any gesture in KOReader's gesture settings

### Changed
- Time formatting now uses compact format (h/m) instead of full words (hours/minutes)
  - Example: "1 h 30 m" instead of "1 hours 30 minutes"
- Added today's pages read count to streak info popup

## [1.2.1] - 2025-11-09

### Changed
- Refactored plugin code into logical modules for better maintainability
  - `settings_manager.lua` - Settings persistence and serialization
  - `daily_progress.lua` - Daily reading progress tracking
  - `streak_calculator.lua` - Streak calculation logic
  - `time_stats.lua` - Time statistics and formatting
  - `statistics_importer.lua` - Database import functionality

### Fixed
- Calendar day numbers now display correctly when using [SeriousHornet's KOReader.patches](https://github.com/SeriousHornet/KOReader.patches) (specifically `2--disable-all-PT-widgets.lua`)

## [1.2.0] - 2025-11-05

### Added
- Display reading time statistics in streak info popup
- Today's reading time display (from daily progress tracking)
- This week's reading time display (from statistics database or daily progress)
- Time formatting function (seconds/minutes/hours) with proper pluralization
- Weekly time calculation from statistics database when available

### Changed
- Enhanced streak info popup to show both daily and weekly reading time
- Improved time tracking accuracy by using statistics database for weekly totals

## [1.1.2] - 2025-02-06

### Fixed
- Settings dialog now automatically falls back to inline menu on devices where dialog fails to load ([#2](https://github.com/advokatb/readingstreak.koplugin/issues/2), reported by @apa-u)
- Improved settings dialog error handling with automatic fallback mechanism

### Added
- Inline settings menu with checkboxes and spinners (available via `USE_INLINE_SETTINGS = true` in main.lua)
- Option to use inline menu instead of dialog by setting `USE_INLINE_SETTINGS = true` in main.lua for users experiencing dialog issues

## [1.1.1] - 2025-02-04

### Changed
- Plugin menu now appears in Tools section

### Fixed
- Fixed calendar view module name conflict with built-in statistics plugin
- Fixed settings dialog require error (ReadingStreakSettings properly defined)

## [1.1.0] - 2025-11-04

### Added
- Daily reading targets with adjustable threshold. (by @omer-faruq in [#1])
- Turkish language support. (by @omer-faruq)

### Fixed
- `showSettingsDialog` is now properly defined and accessible.

## [1.0.0] - 2025-02-11

### Added
- Initial release
- Daily and weekly streak tracking
- Calendar view with month navigation
- Settings dialog with goals and notifications
- Localization support (English, Russian, Ukrainian)
- Automatic reading tracking
- Streak goal notifications
