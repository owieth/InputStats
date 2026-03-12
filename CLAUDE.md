# InputMetrics

macOS menu bar app for tracking mouse and keyboard input metrics.

## Tech Stack

- Swift 6, SwiftUI, macOS 14+
- GRDB (SQLite via Swift)
- Xcode project (not SPM-based app target)

## Architecture

- MVVM with @Observable ViewModels annotated @MainActor
- Singleton services: DatabaseManager, EventMonitor, MouseTracker, KeyboardTracker
- UserPreferences: @MainActor ObservableObject singleton using UserDefaults
- Menu bar app via NSPopover (AppDelegate manages status item)
- WindowManager handles dashboard/settings windows

## Database

- GRDB with DatabaseQueue, serial dispatch queue for writes
- Migrations: V1-V5 registered in DatabaseManager.migrator
- Tables: daily_summary, mouse_heatmap, keyboard_heatmap, hourly_summary
- Date format: "yyyy-MM-dd" (DateHelper.todayString())
- Models conform to Codable, FetchableRecord, PersistableRecord
- CodingKeys map camelCase properties to snake_case columns

## Conventions

- Conventional commits: type(scope): subject
- English only for code, comments, docs
- Use `rg` not `grep`, `fd` not `find`
- Self-documenting code over comments
- Prefer editing existing files over creating new ones

## Build

```sh
xcodebuild -project InputMetrics.xcodeproj -scheme InputMetrics -configuration Debug build
```

## Test

```sh
xcodebuild -project InputMetrics.xcodeproj -scheme InputMetrics -configuration Debug test
```
