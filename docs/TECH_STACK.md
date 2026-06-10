# Tech Stack

[< Back to README](../README.md)

## Technology Stack

- **Language**: Swift 5
- **Framework**: SwiftUI (no UIKit views except `UIViewControllerRepresentable` wrappers)
- **Minimum iOS Version**: iOS 17.2+
- **Data Persistence**: CoreData (`NSPersistentCloudKitContainer`) with iCloud sync
- **Architecture**: MVVM with a Manager layer
- **Testing**: XCTest (unit tests) + XCUITest (UI tests)
- **External Dependencies**: Firebase iOS SDK (FirebaseCrashlytics only — Analytics was removed for privacy reasons)

## Architecture

### Layer Responsibilities

| Layer | Role |
|---|---|
| **Views** | Pure SwiftUI. No business logic. |
| **ViewModels** | Bridge between Managers and Views. Own `@Published` UI state. |
| **Managers** | All business logic and CoreData operations. |
| **Models** | CoreData entities + lightweight transfer objects (`WorkoutDetailInput`, `SetInput`, etc.) |
| **Protocols** | `WorkoutManaging` protocol enables dependency injection and in-memory test stores. |

### Key Classes

- **`WorkoutTrackerViewModel`** — Central view model for the workout tab. Owns `workoutDetails`, `workouts`, and session state. Passed as `@EnvironmentObject` throughout the workout flow.
- **`WorkoutManager`** (~1100 lines — split into smaller managers is planned for post-1.0) — All CoreData reads/writes for workouts, history, sessions, and sets.
- **`AppViewModel`** — Manages custom state-based navigation. Owns `currentView: ContentViewType`.
- **`AchievementManager`** — Evaluates and persists milestone achievements after each workout.
- **`RestTimerManager`** — Countdown timer for between-set rest periods. Published as an environment object.
- **`FocusManager`** — Tracks keyboard/focus state across exercise row fields. Used to drive scroll-to-focused-field behavior and hide/show bottom buttons.
- **`ColorManager`** — Randomly assigns colors to new workouts from the 15-color palette.
- **`HapticManager`** — Centralized haptic feedback (set completion, reorder, etc.).
- **`PersistenceController`** — CoreData stack singleton using `NSPersistentCloudKitContainer`. Shared static instance prevents duplicate `NSManagedObjectModel` registration in tests. The `forUITesting` path uses a plain `NSPersistentContainer` with an in-memory store so tests have no network dependency.
- **`LogCapture`** — Retains last 500 in-memory log entries for in-app diagnostics and bug report attachments. Strips user-entered content (wrapped in single quotes) from anything forwarded to Crashlytics or persisted to the support-email attachment.

### Navigation System

Navigation is **state-based**, not `NavigationStack`-based, managed by `AppViewModel`:

```swift
enum ContentViewType {
    case main
    case workoutOverview(UUID)
    case workoutActiveView(UUID)
    case workoutHistoryView
    case customizeCardView(UUID)
    case achievementsView
}
```

All navigation goes through `appViewModel.navigateTo()`. `WorkoutContentMainView` switches views based on `currentView`. Only `WorkoutContentMainView` wraps content in `NavigationView` — child views must not add their own or a white-screen bug occurs on back navigation.

### CoreData — Dual-State Pattern

| Entities | Purpose |
|---|---|
| `Workouts` → `WorkoutDetail` → `WorkoutSet` | Templates / plans (persistent) |
| `TemporaryWorkoutDetail` → `WorkoutSet` | Active workout state (ephemeral, deleted on completion) |
| `WorkoutSession` | Tracks the active session's start time for timer recovery |
| `WorkoutHistory` → `WorkoutDetail` → `WorkoutSet` | Completed workout snapshots (permanent record) |

When a workout starts, the template is copied to `TemporaryWorkoutDetail` entities. Users modify sets during the session without touching the template. On completion, the user is prompted to optionally update the template with any changes made.

### Logging

```swift
AppLogger.workout.debug("...")
AppLogger.coreData.error("...")
AppLogger.validation.warning("...")
// Categories: workout, coreData, ui, navigation, validation, lifecycle
```

Use `AppLogger` (not `print()`) throughout production code. `LogCapture.shared` taps into the OSLog stream and retains the last 500 entries in memory for the in-app log viewer and bug report attachments.

**PII scrubbing convention**: wrap any user-entered content (exercise names, workout titles, notes) in single quotes when interpolating into log messages — e.g., `AppLogger.workout.warning("Failed for '\(name)'")`. `LogCapture.scrubUserContent(_:)` strips anything between single quotes before logs leave the device (Crashlytics + persisted error file). The in-memory `logs` array stays unscrubbed for local debuggability.

### Input Validation

- Max length constraints enforced with live counters in the UI (30 chars for titles and exercise names)
- `validateAndSetInputInt` / `validateAndSetInputFloat` helpers in `ExerciseInputHelper`
- `FocusableField` enum drives `@FocusState` across all exercise row text fields

### Accessibility

All interactive elements used in UI tests carry `.accessibilityIdentifier(AccessibilityID.someKey)`. The `AccessibilityID` struct (app target) and `TestID` struct (UI test target) must be kept in sync. Both live at:
- `Soleus/Helpers/AccessibilityIdentifiers.swift`
- `SoleusUITests/TestAccessibilityIDs.swift`

## External Dependencies

| Package | Products Used | Purpose |
|---|---|---|
| [firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk) | FirebaseCrashlytics | Crash reporting |

The Firebase SDK pulls in transitive dependencies at the SPM resolution level. Only the Crashlytics product is linked into the app binary — Analytics, Firestore, and ad-related packages are resolved but not included.

Crash reporting is **opt-out** via Settings → Privacy → Crash Reports. The toggle persists to `UserDefaults` (`crashReportingEnabled`, defaults to `true`) and is applied at launch in `AppDelegate.didFinishLaunchingWithOptions` via `Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(...)`. Toggling at runtime takes effect immediately — when disabled, breadcrumbs, non-fatals, and queued crash reports are all dropped.

## Privacy & App Store Compliance

The app's data-collection story is described in four places that must stay in sync — modifying one requires updating the others:

| Surface | Path |
|---|---|
| Privacy manifest | `Soleus/PrivacyInfo.xcprivacy` — declares Crash Data, Performance Data, Other Diagnostic Data (all linked, no tracking) plus three required-reason API entries |
| App Store Connect | "App Privacy" questionnaire — must mirror the manifest |
| User-facing policy | `Soleus/Views/Main/PrivacyPolicyView.swift` — plain-English summary of what's collected and what isn't |
| App config | `Soleus/Info.plist` — includes `ITSAppUsesNonExemptEncryption=false` and `LSApplicationCategoryType=public.app-category.healthcare-fitness` |

Adding any SDK that collects data, reintroducing Firebase Analytics, or starting to log new categories of user content requires updating all four surfaces simultaneously.

## Project Structure

```
Soleus/
├── ViewModels/
│   ├── WorkoutTrackerViewModel.swift  # Central workout tab view model
│   ├── ActiveWorkoutViewModel.swift   # Active session state
│   └── AppViewModel.swift             # Navigation state
├── Models/
│   ├── CoreData/             # Auto-generated CoreData entity classes
│   ├── WorkoutTemplates.swift # Built-in workout templates
│   └── Transfer objects      # WorkoutDetailInput, SetInput, ShareableWorkout, etc.
├── Views/
│   ├── Main/                 # HomeView, CustomTabView, FAQView, ReleaseNotesView, etc.
│   ├── Settings/             # SettingsView, DevMenuView, LogViewerView
│   ├── WorkoutTracker/
│   │   ├── ModifyWorkout/    # AddWorkoutView, AddExerciseDialog, TemplatePickerView
│   │   ├── Shared/           # ExerciseRow, ExerciseRowActive, SetHeaders, etc.
│   │   └── Components/       # RestTimerView, ConfettiEffect
│   ├── Cards/                # CardView, WorkoutHistoryCardView, DataCardView
│   └── Components/           # Shared UI: DocumentPicker, MailComposer, DatePickerView, etc.
├── Managers/
│   ├── WorkoutManager.swift  # All CoreData workout operations (~1100 lines)
│   ├── AchievementManager.swift
│   ├── RestTimerManager.swift
│   ├── FocusManager.swift
│   ├── ColorManager.swift
│   ├── HapticManager.swift
│   ├── HealthKitManager.swift
│   └── NotificationManager.swift
├── Controllers/
│   └── PersistenceController.swift   # CloudKit-backed CoreData stack
├── Protocols/
│   └── WorkoutManaging.swift         # Protocol for WorkoutManager (enables test injection)
├── Enums/                    # ModalType, WorkoutSaveError, etc.
├── Helpers/
│   ├── AccessibilityIdentifiers.swift
│   ├── TimeHelper.swift
│   ├── ExerciseInputHelper.swift
│   └── LogCapture.swift
├── Utilities/
│   └── AppLogger.swift
└── Assets.xcassets/          # 15 custom colors + app icons
```

## Build Commands

```bash
# Build
xcodebuild -scheme Soleus -configuration Debug build

# Run all tests
xcodebuild -scheme Soleus -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' test

# Clean
xcodebuild clean -scheme Soleus
```

## Testing Architecture

- **`SoleusTests`** — Unit tests using `PersistenceController.forUITesting` (in-memory store). Always delete test data in `tearDown`.
- **`SoleusUITests`** — UI tests using `SoleusUITestBase`. Launches with `--uitesting` arg. Test data injected via `launchEnvironment` keys (`UI_TEST_IMPORT_WORKOUT`, `UI_TEST_PRE_CREATE_WORKOUT`).
- Coverage: ~35% on production code, ~98% self-coverage on test helpers.
