# Reading Streak Plugin for KOReader

![GitHub release (latest by date)](https://img.shields.io/github/v/release/advokatb/readingstreak.koplugin?style=for-the-badge&color=orange) ![GitHub all releases](https://img.shields.io/github/downloads/advokatb/readingstreak.koplugin/total?style=for-the-badge&color=yellow) ![Platform](https://img.shields.io/badge/Platform-KOReader-success?style=for-the-badge&logo=koreader)

A plugin for tracking daily and weekly reading streaks, similar to Kindle Streak functionality.

## Features

1. **Localization** - Multi-language support (English, Russian, Ukrainian, Turkish, Hungarian)
2. **Daily Streaks** - Track consecutive days of reading
3. **Weekly Streaks** - Track consecutive weeks of reading
4. **Calendar View** - Visualize reading progress with monthly calendar navigation
5. **Date Tracking** - Display first and last reading dates
6. **Settings** - Comprehensive inline settings menu organized into logical submenus
7. **Goals** - Set streak goals and get notifications when achieved
8. **Notifications** - Optional notifications for reaching goals
9. **Statistics Import** - Import historical reading data from KOReader's `statistics.sqlite3` database
10. **UI Integration** - Display reading streak directly in Project Title footer

## Installation

Copy the `readingstreak.koplugin` folder to KOReader's `plugins` directory.

## Usage

### Automatic Tracking

The plugin automatically tracks reading when you open books (if "Automatically track reading" is enabled in settings). Simply open a book and the plugin will record that you've read on that day.

### Viewing Your Streak

Access your reading streak information via:
- **Tools** → **Reading Streak** → **View Streak**

Shows your current streak, progress toward goal, longest streak, weekly streaks, total days read, and first/last reading dates.

### Calendar View

View your reading history visually:
- **Tools** → **Reading Streak** → **Calendar View**

Displays a monthly calendar with:
  - Days you've read highlighted in gray
  - Current month's reading statistics (days read out of total days in month)
  - Current streak display (days and/or weeks, configurable in settings)
  - Navigation to previous/next months via swipe gestures or navigation buttons
  - Days of the week header

### Import from Statistics

If you've been using KOReader for a while, you can import your historical reading data:
- **Tools** → **Reading Streak** → **Settings** → **Data Management** → **Import from Statistics**
- This function reads KOReader's `statistics.sqlite3` database and imports all unique reading dates
- Only new dates (not already in your reading history) will be imported
- Your current streak will be recalculated after import

**Important:** If you plan to use daily reading targets (pages/minutes thresholds), you should configure these settings in **Goals and Tracking** → **Daily Targets** before importing statistics. The import will respect your configured thresholds when determining which reading sessions qualify for streak tracking.

The import feature is useful if you want to:
- Backfill your reading history with past reading sessions
- Recover reading data after reinstalling the plugin
- Sync reading data if you've been using KOReader's built-in statistics

## UI Integration

Display your reading streak directly in Project Title footer for constant motivation! 

**Quick Setup:**
1. Go to **Tools** → **Reading Streak** → **Settings** → **UI Integration**
2. Enable "Export to Project Title"
3. Restart KOReader
4. Your streak will appear automatically in Project Title footer!

For detailed instructions, see [UI Integration Guide](UI_INTEGRATION.md).

*This feature was requested by [@JoeBumm](https://github.com/JoeBumm) in [issue #3](https://github.com/advokatb/readingstreak.koplugin/issues/3).*

## Settings

Access settings via:
- **Tools** → **Reading Streak** → **Settings**

The settings menu is organized into submenus:

### Goals

- **Streak Goal** - Set your daily reading streak goal (1-365 days). When you reach this goal, you'll receive a congratulatory notification (if notifications are enabled).
- **Daily Page Target** - Configure optional daily minimum pages read. A day only counts toward the streak once the threshold is met.
- **Daily Time Target** - Configure optional daily minimum minutes spent reading. A day only counts toward the streak once the threshold is met.

### Tracking

- **Automatically track reading** - Enable/disable automatic tracking when books are opened. When enabled, the plugin automatically records reading activity when you open a book.
- **Show streak notifications** - Enable/disable notifications when you reach your streak goal. When enabled, you'll see a notification popup when your current streak equals your goal.

### Display

- **Calendar streak display** - Choose how the current streak is displayed in the calendar view:
  - **Days** - Show only daily streak (e.g., "Current streak: 33 days")
  - **Weeks** - Show only weekly streak (e.g., "Current week streak: 6 weeks")
  - **Both** - Show both daily and weekly streaks (default)

### UI Integration

- **Export to Project Title** - Display reading streak widget directly in Project Title footer.

### Data Management

- **Import from Statistics** - Import historical reading dates from KOReader's `statistics.sqlite3` database. See "Import from Statistics" section above for details.

- **Reset All Data** - Permanently delete all reading streak data including:
  - Reading history (all dates)
  - Current and longest streaks
  - Weekly streaks
  - Total days read
  - First and last read dates

  **Warning:** This action cannot be undone. You'll be asked to confirm before the reset is performed.

## Localization

To add new translations, create `.po` files in the `l10n/[language]/koreader.po` directory. Currently supported languages:
- English (en)
- Russian (ru)
- Ukrainian (ua)
- Turkish (tr)
- Hungarian (hu)

## Technical Details

The plugin stores data in `reading_streak.lua` in KOReader's settings directory. Reading dates are stored as `YYYY-MM-DD` format strings. The plugin integrates with KOReader's event system (`onReaderReady`, `onPageUpdate`) to automatically track reading activity.

Statistics import reads from `statistics.sqlite3` located in KOReader's settings directory. The import query extracts unique dates from the `page_stat` table where `start_time` is converted to local date format.
