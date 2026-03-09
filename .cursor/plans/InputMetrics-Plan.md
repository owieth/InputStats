# InputMetrics

A lightweight macOS menu bar app that tracks mouse movements, clicks, and keyboard usage with beautiful visualizations.

---

## Overview

InputMetrics silently monitors your input activity and presents statistics through an elegant menu bar interface. Track how far your mouse travels (in meters, kilometers, and fun comparisons like "distance to the moon"), see which keys you use most, and visualize your patterns through heatmaps and time-series charts.

**Target:** macOS 15+ (Sequoia)  
**Tech Stack:** Swift, SwiftUI, SQLite (via GRDB.swift), CGEventTap  
**Storage:** Local only (`~/Library/Application Support/InputMetrics/`)

---

## Features

### Mouse Tracking
- **Distance traveled** — accumulated in pixels, converted to real-world units
  - Meters / Kilometers
  - Fun comparisons: "X% around the world", "X% to the moon"
- **Click counter** — total clicks (left, right, middle tracked separately)
- **Heatmap** — normalized 50×50 grid showing click density
  - Works across different screen sizes (16" laptop, 32" monitor)
  - Separate heatmaps per connected display

### Keyboard Tracking
- **Total keystroke count**
- **Per-key frequency** — stored as counts only (no sequences for privacy)
- **Visual keyboard heatmap** — QWERTZ layout with color-coded usage intensity
- **Modifier combinations** — track common shortcuts (⌘C, ⌘V, etc.)

### Charts & Statistics
- **Time range selector:** Week / Month / Year
- **Bar charts** showing daily aggregates
- **Separate views** for mouse and keyboard metrics
- Data aggregates from daily summaries (efficient queries for any time range)

### Settings
- Launch at login (toggle)
- Unit preference: Metric (default) / Imperial
- Heatmap resolution: Low / Medium / High (CPU vs accuracy tradeoff)
- Export data as CSV
- Reset all data

---

## Architecture

### Project Structure

```
InputMetrics/
├── InputMetricsApp.swift          # App entry point
├── AppDelegate.swift              # Menu bar setup, event tap lifecycle
│
├── Models/
│   ├── DailySummary.swift         # Daily aggregate model
│   ├── MouseHeatmapEntry.swift    # Heatmap bucket model
│   ├── KeyboardEntry.swift        # Per-key count model
│
├── Services/
│   ├── EventMonitor.swift         # CGEventTap wrapper for mouse/keyboard
│   ├── DatabaseManager.swift      # GRDB setup and migrations
│   ├── MouseTracker.swift         # Distance calculation, click counting
│   ├── KeyboardTracker.swift      # Keystroke aggregation
│   └── StatsCalculator.swift      # Unit conversions, fun comparisons
│
├── Views/
│   ├── MenuBarView.swift          # Popover with quick stats
│   ├── MainWindowView.swift       # Full dashboard container
│   ├── MouseStatsView.swift       # Mouse metrics + heatmap
│   ├── KeyboardStatsView.swift    # Keyboard metrics + heatmap
│   ├── ChartView.swift            # Time-series bar charts
│   ├── HeatmapView.swift          # Generic heatmap renderer
│   ├── KeyboardHeatmapView.swift  # QWERTZ keyboard visualization
│   └── SettingsView.swift         # Preferences panel
│
├── Utilities/
│   ├── Constants.swift            # Magic numbers, layout definitions
│   ├── DistanceConverter.swift    # Pixels → meters, fun comparisons
│   └── KeyCodeMapping.swift       # Virtual key codes → key names
│
└── Resources/
    └── Assets.xcassets            # App icon, colors
```

### Database Schema

```sql
-- Running daily totals (primary data source for charts)
CREATE TABLE daily_summary (
    date TEXT PRIMARY KEY,              -- "2025-01-16"
    mouse_distance_px REAL DEFAULT 0,   -- Total pixels traveled
    mouse_clicks_left INTEGER DEFAULT 0,
    mouse_clicks_right INTEGER DEFAULT 0,
    mouse_clicks_middle INTEGER DEFAULT 0,
    keystrokes INTEGER DEFAULT 0
);

-- Mouse click heatmap (bucketed by screen region)
CREATE TABLE mouse_heatmap (
    date TEXT,
    screen_id TEXT,                     -- Display identifier
    bucket_x INTEGER,                   -- 0-49 (normalized)
    bucket_y INTEGER,                   -- 0-49 (normalized)
    click_count INTEGER DEFAULT 0,
    PRIMARY KEY (date, screen_id, bucket_x, bucket_y)
);

-- Keyboard usage (per-key counts, no sequences)
CREATE TABLE keyboard_heatmap (
    date TEXT,
    key_code INTEGER,                   -- Virtual key code
    modifier_flags INTEGER DEFAULT 0,   -- For tracking combos
    count INTEGER DEFAULT 0,
    PRIMARY KEY (date, key_code, modifier_flags)
);

-- Indexes for chart queries
CREATE INDEX idx_daily_date ON daily_summary(date);
```

### Chart Aggregation Strategy

All charts query from `daily_summary`, which makes Week/Month/Year views efficient:

```swift
// Week: Last 7 days, show each day
SELECT date, mouse_distance_px, keystrokes 
FROM daily_summary 
WHERE date >= date('now', '-7 days')
ORDER BY date;

// Month: Last 30 days, show each day
SELECT date, mouse_distance_px, keystrokes 
FROM daily_summary 
WHERE date >= date('now', '-30 days')
ORDER BY date;

// Year: Last 365 days, aggregate by week or month
SELECT strftime('%Y-%W', date) as week,
       SUM(mouse_distance_px) as distance,
       SUM(keystrokes) as keys
FROM daily_summary 
WHERE date >= date('now', '-365 days')
GROUP BY week
ORDER BY week;
```

---

## Technical Details

### Event Monitoring (CGEventTap)

```swift
// Requires Accessibility permission
let eventMask = (1 << CGEventType.mouseMoved.rawValue) |
                (1 << CGEventType.leftMouseDown.rawValue) |
                (1 << CGEventType.rightMouseDown.rawValue) |
                (1 << CGEventType.otherMouseDown.rawValue) |
                (1 << CGEventType.keyDown.rawValue)

let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,        // Don't modify events
    eventsOfInterest: CGEventMask(eventMask),
    callback: eventCallback,
    userInfo: pointer
)
```

### Distance Calculation

```swift
// On each mouseMoved event:
let currentPoint = event.location
let dx = currentPoint.x - lastPoint.x
let dy = currentPoint.y - lastPoint.y
let distancePx = sqrt(dx*dx + dy*dy)
accumulatedDistance += distancePx
lastPoint = currentPoint

// Conversion constants (assuming ~110 DPI average)
let pixelsPerMeter: Double = 4330  // ~110 DPI
let earthCircumference: Double = 40_075_000  // meters
let moonDistance: Double = 384_400_000  // meters
```

### Heatmap Normalization

```swift
// Convert screen coordinates to 50x50 grid bucket
func bucketForPoint(_ point: CGPoint, screenBounds: CGRect) -> (x: Int, y: Int) {
    let normalizedX = (point.x - screenBounds.minX) / screenBounds.width
    let normalizedY = (point.y - screenBounds.minY) / screenBounds.height
    let bucketX = min(49, max(0, Int(normalizedX * 50)))
    let bucketY = min(49, max(0, Int(normalizedY * 50)))
    return (bucketX, bucketY)
}
```

### QWERTZ Keyboard Layout

```swift
let qwertzLayout: [[String]] = [
    ["^", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "ß", "´", "⌫"],
    ["⇥", "Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P", "Ü", "+", ""],
    ["⇪", "A", "S", "D", "F", "G", "H", "J", "K", "L", "Ö", "Ä", "'", "↵"],
    ["⇧", "<", "Y", "X", "C", "V", "B", "N", "M", ",", ".", "-", "⇧", ""],
    ["fn", "⌃", "⌥", "⌘", "        Space        ", "⌘", "⌥", "←", "↑↓", "→"]
]
```

---

## UI Design

### Menu Bar Popover (Quick View)

```
┌─────────────────────────────────┐
│  InputMetrics            ⚙️  ⤢  │
├─────────────────────────────────┤
│                                 │
│  🖱️ Mouse         ⌨️ Keyboard   │
│                                 │
│  2.4 km            48,392       │
│  today             keystrokes   │
│                                 │
│  ────────────────────────────── │
│                                 │
│  🌍 0.00006% around the world   │
│  🌙 0.000001% to the moon       │
│                                 │
│  Clicks: 1,247 L | 89 R | 12 M  │
│                                 │
└─────────────────────────────────┘
```

### Main Window (Dashboard)

```
┌──────────────────────────────────────────────────────────────────┐
│  InputMetrics                                        ─  □  ✕    │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [Mouse]  [Keyboard]                      [Week] [Month] [Year]  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                                                             │ │
│  │                     Bar Chart Area                          │ │
│  │            (Daily totals for selected range)                │ │
│  │                                                             │ │
│  │   ▁▃▅▇▅▃▁▂▄▆▄▂▁▃▅▇▅▃▁▂▄▆▄▂▁▃▅▇                             │ │
│  │   M T W T F S S M T W T F S S M T W T F S S M T W T F S S   │ │
│  │                                                             │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌──────────────────────────┐  ┌─────────────────────────────┐  │
│  │                          │  │  All-Time Stats             │  │
│  │    Heatmap               │  │                             │  │
│  │    (50x50 grid)          │  │  Distance: 847.3 km         │  │
│  │                          │  │  Clicks: 892,461            │  │
│  │    ░░▒▒▓▓██▓▓▒▒░░       │  │  Keystrokes: 4,201,847      │  │
│  │    ░░▒▒▓▓██▓▓▒▒░░       │  │                             │  │
│  │                          │  │  🌍 2.1% around the world   │  │
│  │                          │  │  🌙 0.2% to the moon        │  │
│  └──────────────────────────┘  └─────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Keyboard Heatmap View

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│   ┌──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬─────┐                │
│   │^ │1 │2 │3 │4 │5 │6 │7 │8 │9 │0 │ß │´ │ ⌫   │                │
│   ├──┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬────┤                │
│   │ ⇥ │Q │W │E │R │T │Z │U │I │O │P │Ü │+ │    │                │
│   ├───┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┐ ↵ │                │
│   │ ⇪  │A │S │D │F │G │H │J │K │L │Ö │Ä │' │   │                │
│   ├────┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴┬─┴──┴───┤                │
│   │ ⇧   │Y │X │C │V │B │N │M │, │. │- │   ⇧    │                │
│   ├───┬─┴─┬┴──┼──┴──┴──┴──┴──┴┬─┴─┬┴──┼───┬────┤                │
│   │fn │ ⌃ │ ⌥ │ ⌘ │           │ ⌘ │ ⌥ │ ← │ →  │                │
│   └───┴───┴───┴───┴───────────┴───┴───┴───┴────┘                │
│                                                                  │
│   Color intensity = usage frequency (darker = more used)         │
│                                                                  │
│   Top Keys Today:  E (4,521)  N (3,892)  Space (3,104)  ...     │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Foundation
- [ ] Create Xcode project with menu bar app template
- [ ] Set up GRDB.swift dependency (Swift Package Manager)
- [ ] Implement DatabaseManager with schema migrations
- [ ] Create basic AppDelegate with menu bar icon
- [ ] Add Accessibility permission request flow

### Phase 2: Event Monitoring
- [ ] Implement EventMonitor with CGEventTap
- [ ] Create MouseTracker (distance accumulation, click counting)
- [ ] Create KeyboardTracker (keystroke counting, no sequences)
- [ ] Wire up real-time updates to in-memory state
- [ ] Implement periodic database persistence (every 30 seconds)

### Phase 3: Menu Bar UI
- [ ] Build MenuBarView popover with live stats
- [ ] Implement StatsCalculator for unit conversions
- [ ] Add fun comparisons (world, moon percentages)
- [ ] Show today's stats + all-time totals

### Phase 4: Main Dashboard
- [ ] Create MainWindowView container
- [ ] Build ChartView with SwiftUI Charts
- [ ] Implement Week/Month/Year aggregation queries
- [ ] Add tab switching between Mouse and Keyboard views

### Phase 5: Heatmaps
- [ ] Create generic HeatmapView (Canvas-based rendering)
- [ ] Implement mouse heatmap with multi-monitor support
- [ ] Build KeyboardHeatmapView with QWERTZ layout
- [ ] Add color gradient based on frequency

### Phase 6: Settings & Polish
- [ ] Implement SettingsView
- [ ] Add LaunchAtLogin functionality
- [ ] Build CSV export feature
- [ ] Add reset data confirmation flow
- [ ] Performance optimization (throttle UI updates)
- [ ] App icon design

---

## Dependencies

```swift
// Package.swift or Xcode SPM
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
    .package(url: "https://github.com/sindresorhus/LaunchAtLogin.git", from: "5.0.0")
]
```

---

## Privacy & Security Notes

1. **No keystroke sequences stored** — only per-key counts
2. **All data local** — nothing leaves the device
3. **Accessibility permission required** — user must explicitly grant
4. **No network calls** — app works completely offline
5. **Data export is manual** — user controls when/where data goes

---

## Future Ideas (v2+)

- [ ] Typing speed tracking (WPM)
- [ ] Break reminders based on activity thresholds
- [ ] iCloud sync for multi-Mac users
- [ ] Widgets for desktop/notification center
- [ ] Historical trends and insights
- [ ] Custom keyboard layout support
- [ ] Scroll distance tracking
- [ ] Per-application breakdown (which apps you type most in)
