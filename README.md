# InputMetrics

A lightweight macOS menu bar app that tracks mouse movements, clicks, and keyboard usage with beautiful visualizations.

## Download

[**Download the latest release**](https://github.com/owieth/InputMetrics/releases/latest) — signed and notarized for macOS.

### Installation

1. Download `InputMetrics-vX.X.X.zip` from the latest release
2. Extract the ZIP and drag `InputMetrics.app` to `/Applications`
3. Launch the app — it appears in your menu bar
4. Grant **Accessibility** and **Input Monitoring** permissions when prompted

## Features

- **Mouse Tracking**: Distance traveled, click counter, heatmap visualization
- **Keyboard Tracking**: Keystroke counts, per-key frequency, keyboard heatmap
- **Charts**: Week/Month/Year time-series visualizations
- **Scroll Tracking**: Vertical and horizontal scroll distance
- **Active Time**: Daily first/last activity timestamps, idle detection
- **App Usage**: Per-application input breakdown
- **Goals**: Daily keystroke and distance goals with streak tracking
- **Fun Comparisons**: Distance as % to the moon and around Earth
- **Privacy-First**: No keystroke sequences stored, all data stays local
- **Settings**: Launch at login, CSV/JSON export, database backup/restore

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 |
| UI | SwiftUI with AppKit bridging |
| Charts | Swift Charts |
| Event Capture | CGEventTap (listen-only) |
| Database | SQLite via [GRDB.swift](https://github.com/groue/GRDB.swift) |
| Login Item | [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) |
| Architecture | MVVM with @Observable ViewModels |
| Minimum macOS | 15.0 (Sequoia) |

## Building from Source

### Requirements

- macOS 15.0 (Sequoia) or later
- Xcode 16.0 or later

### Steps

1. Clone the repository
2. Open `InputMetrics/InputMetrics.xcodeproj` in Xcode
3. Build and run (⌘R)
4. Grant Accessibility and Input Monitoring permissions when prompted

## Release Process

Releases are automated via GitHub Actions:

1. **CI**: Every push to `main` runs build + test
2. **Auto-tag**: After CI passes on `main`, a semver tag is created from conventional commits (`feat:` = minor, `fix:` = patch)
3. **Release**: When a GitHub Release is published from a tag, the release workflow builds a signed and Apple-notarized `.app`, packages it as a ZIP, and uploads it as a release asset

## Roadmap

### Historical Browsing
- Date navigation to browse past days/weeks/months
- Week/Month/Year chart range picker
- Heatmaps and stats for any selected date

### macOS Widgets
- WidgetKit extension with Small, Medium, and Large sizes
- Small: today's keystrokes + clicks
- Medium: today's stats + mini 7-day bar chart
- Shared App Group container for DB access between app and widget
