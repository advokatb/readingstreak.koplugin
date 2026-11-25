# UI Integration Guide

Reading Streak can show your current streak in the footer of [Project Title](https://github.com/joshuacant/ProjectTitle), the cover browser plugin for KOReader. It can also share its numbers with any other plugin through KOReader's `PluginShare`.

## Project Title footer

### Setup

1. Install Project Title and check that it is enabled.
2. In KOReader, go to **Tools** → **Reading Streak** → **Settings** → **UI Integration**.
3. Enable **Export to Project Title**.
4. Restart KOReader.

The streak then appears in the file browser footer, between the footer text and the page controls, as `⚡ 5 days`. It uses the same font as the footer: serif by default, or sans when Project Title's "replace footer text" option is on. The text updates whenever the page info in the footer is refreshed.

### If the streak does not show up

- **Your current streak is 0.** The widget is only filled in while you have a streak of at least one day. Read today and it will appear.
- **Project Title is not installed or not loaded.** Reading Streak looks for Project Title's `ptutil`, `bookinfomanager` and `covermenu` modules. If they are missing, it skips the integration and writes `ReadingStreak: Project Title not found, skipping integration` to `crash.log`.
- **KOReader was not restarted** after enabling the option. The footer is patched when the file browser is created, so restart KOReader once after turning the option on.
- **The option is off.** Check **Settings** → **UI Integration** → **Export to Project Title** again; it is off by default.

Other `ReadingStreak:` warnings in `crash.log` (for example `Project Title widget failed`) are worth including if you open an issue.

## PluginShare API (for plugin developers)

When an integration is enabled, Reading Streak publishes `PluginShare.readingstreak`. It is `nil` when every integration is off.

```lua
local PluginShare = require("pluginshare")
local rs = PluginShare.readingstreak
if rs then
    print(rs.getStreakText())   -- "No streak", "1 day", "5 days" (translated)
end
```

| Field | Description |
| --- | --- |
| `current_streak` | Current streak in days |
| `longest_streak` | Longest streak in days |
| `current_week_streak` | Current streak in weeks |
| `longest_week_streak` | Longest streak in weeks |
| `total_days` | Total days with reading |
| `streak_goal` | Streak goal in days |
| `today_pages` | Pages read today |
| `today_time` | Reading time today, in seconds |
| `weekly_time` | Reading time this week, in seconds |
| `getStreakText()` | Formatted streak, for example `5 days` |
| `getStreakEmoji()` | Emoji for the current streak |
| `getStreakNumber()` | Current streak as a number |

The values are a snapshot taken when the API is updated (at startup and when settings change), so read them again when you redraw rather than caching them.
