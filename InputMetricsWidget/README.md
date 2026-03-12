# InputMetrics Widget Setup

To complete the widget integration:

1. **Add Widget Extension Target**
   - In Xcode, File > New > Target > Widget Extension
   - Name: InputMetricsWidget
   - Uncheck "Include Configuration App Intent"

2. **Configure App Group**
   - Add App Group capability to both main app and widget targets
   - Use group identifier: `group.com.inputmetrics.shared`

3. **Move Database to Shared Container**
   - Update DatabaseManager to use the shared container path:
     ```swift
     let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.inputmetrics.shared")
     ```

4. **Replace Widget Source**
   - Replace generated widget code with `InputMetricsWidget.swift`
   - Update the timeline provider to read from the shared database

5. **Build and Test**
   - Build the widget scheme
   - Add widget to desktop via Widget Gallery
