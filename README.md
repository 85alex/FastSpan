# ⏱️ FastSpan • Privacy-Focused Intermittent Fasting for iOS & watchOS

> A minimalist, privacy-first intermittent fasting tracker built natively with SwiftUI for iOS and Apple Watch. Features circular progress rings, flexible fasting schedules, 3-stage local notifications, an ActivityKit Dynamic Island milestone tracker, StoreKit 2 Pro monetization ($5 CAD one-time purchase), VoltSlide-style share cards, and RFC 4180 CSV export with private iCloud sync.

---

## ✨ Key Features

- **🔒 100% Privacy-First**: Zero third-party trackers, zero advertising SDKs, zero remote analytics. All data stays strictly on your device and inside your private Apple iCloud database.
- **⭕ Circular Visual Progress**: Vector progress indicator with gradient strokes, overtime halos, and real-time live countdowns.
- **⚡ Flexible Protocols & Custom Durations**:
  - `16:8 LeanGains` (Gold standard)
  - `18:6 Moderate`
  - `20:4 Warrior Diet`
  - `23:1 OMAD` (One Meal A Day)
  - `14:10 Gentle`
  - `12:12 Circadian Rhythm`
  - `36h Monk Fast`
  - Fully customizable fasting durations (1h–168h) & retroactive start time editing.
- **🔔 Tri-Stage Local Notifications**:
  1. **1 Hour Before Goal**: Friendly heads-up as you enter the final stretch.
  2. **Target Reached**: Celebration alert when hitting 100%.
  3. **1 Hour Overtime**: Gentle milestone reminder if continuing into extended fasting.
- **⌚ Apple Watch Companion App**: OLED circular gauge mirroring the iOS design with tactile start/stop controls, haptics, and watch face complications (`accessoryCircular`, `accessoryRectangular`, `accessoryCorner`, `accessoryInline`).
- **🏝️ Smart Dynamic Island & Lock Screen Live Activity (Pro)**: Automatically activates during the critical milestone window (1 hour before goal through 1 hour overtime) with live countdowns and quick actions.
- **🎨 7 Curated Visual Themes**:
  - *Slate Minimal* (Free)
  - *Solar Amber* (Free)
  - *Deep Midnight* (Pro)
  - *Emerald Zen* (Pro)
  - *Sunset Coral* (Pro)
  - *Cyber Neon* (Pro)
  - *Titanium Frost* (Pro)
- **📸 VoltSlide-Style Share Cards**: Dynamic graphical cards generated via `ImageRenderer` in Story (9:16) and Square (1:1) formats.
- **📊 Fasting History, Stats & CSV Export**: Streak tracking, weekly visual charts, 7-day free history / Pro unlimited lifetime logs, and RFC 4180 CSV export.
- **💎 StoreKit 2 Pro Monetization**:
  - **$5.00 CAD One-Time Purchase** (`com.antigravity.fastspan.pro.lifetime`).
  - Pay once, own forever — no subscription fatigue, Family Sharing enabled.

---

## 📁 Repository Structure

```
.
├── FastingApp/
│   ├── Shared/
│   │   ├── Models/
│   │   │   ├── FastingProtocol.swift         # Presets & custom schedules
│   │   │   ├── FastRecord.swift              # SwiftData @Model
│   │   │   ├── FastingState.swift            # Snapshot & timer engine
│   │   │   ├── FastingActivityAttributes.swift# ActivityKit attributes
│   │   │   └── AppTheme.swift                # 7 visual themes
│   │   ├── Store/
│   │   │   ├── StoreManager.swift            # StoreKit 2 controller
│   │   │   └── ProFeature.swift              # Pro feature definitions
│   │   ├── Services/
│   │   │   ├── FastingManager.swift          # Core @Observable coordinator
│   │   │   ├── NotificationManager.swift     # 3-stage local notifications
│   │   │   ├── LiveActivityManager.swift     # Dynamic Island coordinator
│   │   │   ├── CSVExportService.swift        # RFC 4180 CSV exporter
│   │   │   └── WatchSyncService.swift        # WCSession sync service
│   │   └── UI/
│   │       ├── Components/
│   │       │   ├── CircularProgressView.swift# Circular indicator & overtime ring
│   │       │   ├── MetricPillView.swift      # Elevated stats pill
│   │       │   ├── ProtocolPickerView.swift  # Protocol selector modal
│   │       │   └── ProBadgeView.swift        # Pro badge indicator
│   │       └── Themes/
│   │           └── ThemeEnvironment.swift    # SwiftUI theme environment key
│   ├── FastingApp_iOS/
│   │   ├── App/
│   │   │   └── FastingApp.swift              # FastSpan iOS @main entry point
│   │   ├── Views/
│   │   │   ├── MainTrackerView.swift         # Flagship home screen
│   │   │   ├── FastDetailSheet.swift         # Start/Edit/Complete sheet
│   │   │   ├── HistoryView.swift             # History, stats & CSV export
│   │   │   ├── SettingsThemeView.swift       # Theme switcher & toggles
│   │   │   ├── PaywallView.swift             # $5 CAD FastSpan Pro modal
│   │   │   └── Share/
│   │   │       ├── FastShareCardView.swift   # FastSpan share card template
│   │   │       └── ShareSheetModal.swift     # ImageRenderer share sheet
│   │   └── LiveActivity/
│   │       └── FastingLiveActivity.swift     # Dynamic Island widget
│   ├── FastingApp_Watch/
│   │   ├── App/
│   │   │   └── FastingWatchApp.swift         # FastSpan watchOS @main entry point
│   │   ├── Views/
│   │   │   ├── WatchTrackerView.swift        # OLED circular gauge & controls
│   │   │   └── WatchProtocolPicker.swift     # Schedule selector for watch
│   │   └── Complications/
│   │       └── FastingComplications.swift    # WidgetKit dial complications
│   ├── Configuration/
│   │   └── Products.storekit                 # StoreKit testing configuration
│   └── Tests/
│       └── TestMain.swift                    # Comprehensive test runner (28 tests)
└── Package.swift
```

---

## 🧪 Running the Tests

To run the full unit test suite:

```bash
swift run FastingTestRunner
```

---

## 📄 License

MIT License. Designed with privacy, precision, and focus.
