# InputMetrics

A lightweight macOS menu bar app that tracks mouse movements, clicks, and keyboard usage with beautiful visualizations.

## Features

- **Mouse Tracking**: Distance traveled, click counter, heatmap visualization
- **Keyboard Tracking**: Keystroke counts, per-key frequency, QWERTZ heatmap
- **Charts**: Week/Month/Year time-series visualizations
- **Fun Comparisons**: Distance as % to the moon and around Earth
- **Privacy-First**: No keystroke sequences stored, all data stays local
- **Settings**: Launch at login, CSV export, data reset

## Requirements

- macOS 15.0 (Sequoia) or later
- Xcode 16.0 or later

## Quick Start

1. Open `InputMetrics/InputMetrics.xcodeproj` in Xcode
2. Build and run (⌘R)
3. Grant Accessibility permission when prompted
4. Click the menu bar icon to view stats

See [BUILD_INSTRUCTIONS.md](BUILD_INSTRUCTIONS.md) for detailed setup.

## Architecture

Built with Swift, SwiftUI, and SQLite:
- **Event Monitoring**: CGEventTap for passive listening
- **Database**: GRDB.swift for type-safe SQLite access
- **Charts**: SwiftUI Charts for visualizations
- **Heatmaps**: Canvas-based rendering with 50×50 grid

See [InputMetrics-Plan.md](InputMetrics-Plan.md) for complete technical specification.

## Roadmap

### Historical Browsing
- Date navigation to browse past days/weeks/months
- Week/Month/Year chart range picker
- Heatmaps and stats for any selected date

### Menu Bar Live Stats
- Show live keystroke/click count next to the menu bar icon (e.g. `1.2k · 340`)
- Toggle in Settings to enable/disable

### macOS Widgets
- WidgetKit extension with Small, Medium, and Large sizes
- Small: today's keystrokes + clicks
- Medium: today's stats + mini 7-day bar chart
- Shared App Group container for DB access between app and widget