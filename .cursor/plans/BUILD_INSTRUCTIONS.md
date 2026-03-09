# InputMetrics - Build Instructions

## Overview

InputMetrics is a macOS 15+ menu bar app that tracks mouse and keyboard activity with privacy-first design.

## Prerequisites

- macOS 15.0 (Sequoia) or later
- Xcode 16.0 or later
- Swift 6.0

## Project Structure

```
InputStats/
├── InputMetrics/
│   └── InputMetrics/
│       ├── InputMetricsApp.swift          # App entry point
│       ├── AppDelegate.swift              # Menu bar setup
│       ├── Models/                        # Data models
│       ├── Services/                      # Core services
│       ├── Views/                         # SwiftUI views
│       └── Utilities/                     # Helper utilities
├── InputMetrics.xcodeproj/                # Xcode project
└── Package.swift                          # Swift Package Manager

```

## Building the App

### Option 1: Using Xcode

1. Open `InputMetrics/InputMetrics.xcodeproj` in Xcode
2. Wait for Swift Package Manager to resolve dependencies (GRDB.swift, LaunchAtLogin)
3. Select the "InputMetrics" scheme
4. Build and run (⌘R)

### Option 2: Using xcodebuild (Command Line)

```bash
cd InputMetrics
xcodebuild -project InputMetrics.xcodeproj -scheme InputMetrics -configuration Release
```

## Granting Permissions

On first launch, InputMetrics requires **Accessibility Permission** to monitor mouse and keyboard events:

1. The app will prompt for permission automatically
2. Open **System Settings** > **Privacy & Security** > **Accessibility**
3. Enable the toggle for "InputMetrics"
4. Restart the app

## Features

- **Mouse Tracking**: Distance traveled, clicks (L/R/M), 50×50 heatmap
- **Keyboard Tracking**: Total keystrokes, per-key counts, QWERTZ heatmap
- **Charts**: Week/Month/Year time-series visualizations
- **Fun Comparisons**: Distance as % to moon, % around Earth
- **Privacy**: No keystroke sequences stored, all data local
- **Settings**: Launch at login, CSV export, data reset

## Database

Data is stored in: `~/Library/Application Support/InputMetrics/metrics.db`

Schema includes:
- `daily_summary` - Daily aggregated metrics
- `mouse_heatmap` - 50×50 bucketed click locations
- `keyboard_heatmap` - Per-key counts with modifiers

## Development Notes

- **Event Monitoring**: Uses CGEventTap in `.listenOnly` mode
- **Persistence**: Auto-saves every 30 seconds
- **Multi-monitor**: Normalizes coordinates across all displays
- **QWERTZ Layout**: Hardcoded German keyboard layout
- **Distance Conversion**: Assumes ~110 DPI (4330 pixels/meter)

## Troubleshooting

### App doesn't track events
- Check Accessibility permission in System Settings
- Look for console logs: "Event monitoring started"

### Database errors
- Check file permissions: `~/Library/Application Support/InputMetrics/`
- Delete `metrics.db` to recreate fresh database

### Build errors
- Ensure macOS 15+ deployment target
- Clean build folder (⌘⇧K)
- Reset package cache: File > Packages > Reset Package Caches

## Implementation Status

All core features implemented:
- ✅ Database with GRDB migrations
- ✅ Event monitoring with CGEventTap
- ✅ Mouse/Keyboard trackers with 30s persistence
- ✅ Menu bar popover with live stats
- ✅ Main dashboard with charts
- ✅ Mouse heatmap (Canvas-based)
- ✅ Keyboard heatmap (QWERTZ layout)
- ✅ Settings with LaunchAtLogin, CSV export, reset

## Testing

1. Launch app, grant Accessibility permission
2. Move mouse and type to generate data
3. Click menu bar icon to view stats
4. Wait 30+ seconds, check database has data:
   ```bash
   sqlite3 ~/Library/Application\ Support/InputMetrics/metrics.db "SELECT * FROM daily_summary;"
   ```

## Privacy & Security

- No network access
- No keystroke sequences stored (only per-key counts)
- All data remains local
- User controls data export and deletion
