# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
