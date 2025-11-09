# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
