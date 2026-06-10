# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Soleus is an iOS workout tracking application built with SwiftUI and CoreData. Active development as of June 2026; preparing for App Store submission (previously on TestFlight).

## Build and Development Commands

```bash
# Build the project
xcodebuild -scheme Soleus -configuration Debug build

# Run tests
xcodebuild -scheme Soleus -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' test

# Clean build folder
xcodebuild clean -scheme Soleus
```

## Architecture Overview

### MVVM Pattern with Manager Layer

The app follows MVVM architecture with an additional Manager layer:
- **Views**: Pure SwiftUI views, no UIKit (except UIViewControllerRepresentable wrappers)
- **ViewModels**: `WorkoutTrackerViewModel` bridges Managers and Views, owns UI state via `@Published` properties (the `controller` variable name in `SoleusApp` is historical — the type is a ViewModel)
- **Managers**: `WorkoutManager` (~1100 lines — split is desirable post-launch but not in flight), `ColorManager`, `FocusManager`, `RestTimerManager`, `AchievementManager`
- **Models**: CoreData entities + lightweight transfer objects

### CoreData Persistence Architecture

**Dual-State Pattern** - Key architectural decision:
- `Workouts` → `WorkoutDetail` → `WorkoutSet` = Templates/Plans (persistent)
- `TemporaryWorkoutDetail` → `WorkoutSet` = Active workout state (ephemeral)

When a workout is started, the template is copied to temporary entities. Users can modify sets during the workout without affecting the template. On completion, they're prompted to update the template if changes were made.

**Session Persistence**:
- `WorkoutSession` entity tracks active workouts with `startTime` and `isActive`
- Enables workout timer recovery after app backgrounding
- Only one active workout allowed at a time

**History Snapshots**:
- `WorkoutHistory` stores complete workout snapshots on completion
- Includes all exercise details, sets, and aggregated metrics
- Retrieved monthly for history view

**CoreData Stack**:
- Managed by `PersistenceController` singleton
- Container name: "Model"
- `NSManagedObjectModel` is a shared static instance to prevent duplicate model registration errors in tests
- Context injected into Managers via property observers
- Manual save calls (no auto-save)
- Merge policy: `NSMergeByPropertyObjectTrumpMergePolicy`

### Custom Navigation System

Navigation is **state-based** (not NavigationStack), managed by `AppViewModel`:

```swift
@Published var currentView: ContentViewType = .main

enum ContentViewType {
    case main
    case workoutOverview(UUID)
    case workoutActiveView(UUID)
    case workoutHistoryView
    case customizeCardView(UUID)
}
```

All navigation happens through `appViewModel.navigateTo()`. The `WorkoutContentMainView` switches views based on `currentView` state. Back buttons manually call `appViewModel.resetToWorkoutMainView()`.

### Key View Hierarchy

```
HomeView (root)
└── CustomTabView
    ├── HomeContentView (placeholder)
    ├── WorkoutContentMainView
    │   └── NavigationView wraps switch statement:
    │       ├── WorkoutTrackerMainView (grid of workout cards)
    │       ├── ActiveWorkoutView (workout in progress)
    │       ├── WorkoutOverviewView (completion summary)
    │       ├── WorkoutHistoryView (past workouts)
    │       └── CustomizeCardView (color picker)
    └── SettingsView
        ├── DocumentPicker (sheet) → ImportWorkoutPreviewView
        ├── JSONReferenceView (sheet)
        ├── FAQView (sheet)
        ├── PrivacyPolicyView (sheet)
        ├── ContactUsView (sheet)
        └── DevMenuView (sheet, gated by hidden "Soleus Developer" workout)
```

**Critical Navigation Rule**: Only `WorkoutContentMainView` should have a `NavigationView`. Child views must not wrap themselves in `NavigationView` or navigation will break (white screen bug when returning from empty views).

### Dependency Injection Pattern

Environment objects injected from `SoleusApp`:
```swift
@StateObject private var persistenceController = PersistenceController.shared
@StateObject private var appViewModel = AppViewModel()
@StateObject private var workoutManager = WorkoutManager()
@StateObject private var controller = WorkoutTrackerViewModel(workoutManager: workoutManager)

// Views receive these via .environmentObject()
```

CoreData context is injected separately:
```swift
.environment(\.managedObjectContext, persistenceController.container.viewContext)
```

## Core Workflows

### Active Workout Flow (Critical Path)

1. User taps play button → `ActiveWorkoutView` loads
2. User confirms "Start Workout" → `WorkoutManager.setSessionStatus(isActive: true)`
3. `WorkoutSession` created with `startTime` for timer persistence
4. Template data copied to `TemporaryWorkoutDetail` entities
5. User edits sets → `saveOrUpdateSetsDuringActiveWorkout()` updates temporary entities
6. User taps "End Workout" (double confirmation required)
7. If modified → Prompt "Update Workout?"
8. `saveWorkoutHistory()` creates snapshot with aggregated metrics:
   - Total weight lifted
   - Reps completed
   - Cardio time and distance
9. `deleteAllTemporaryWorkoutDetails()` cleans up temporary state
10. `setSessionStatus(isActive: false)` clears session
11. Navigate to `WorkoutOverviewView` with confetti animation

**State Management During Workouts**:
- `workoutController.hasActiveSession` indicates if any workout is active
- `workoutController.activeWorkoutId` stores the active workout UUID
- Active workouts show animated green icon on card
- Active workouts cannot be edited, deleted, or customized — all three guards live in `CardView.swift` context menu, plus a defensive guard in `AddWorkoutView` save button as a backstop
- Resume banner appears on main view if session exists

### Workout Template Management

**WorkoutTrackerViewModel State**:
- `workoutDetails`: Editable in-memory state (array of `WorkoutDetailInput`)
- `originalWorkoutDetails`: Immutable copy for change detection
- Dirty checking on save determines if confirmation dialog needed

**Adding Exercises**:
- `AddExerciseDialog` modal for exercise name input
- Exercise added with default 3 sets
- Sets configured with: reps, weight, time, or distance
- `exerciseQuantifier` enum determines which fields are active

**Saving Changes**:
- `WorkoutManager.addWorkoutDetail()` or `updateWorkoutDetail()`
- Validation in controller before persistence
- Result<Void, WorkoutSaveError> pattern for error handling

### Workout Import/Export

- `ShareableWorkout` is the codable transfer object. Native `.soleus` files are 4-byte magic header (`SLSE`) + zlib-compressed JSON. Generic `.json` files are also accepted via a lenient secondary decode path (`GenericWorkoutJSON`) that defaults missing fields.
- `DocumentPicker` accepts both `.soleus` and `.json` content types
- `ShareableWorkout.import(from:)` enforces a **5 MB raw-payload cap** at the single chokepoint — protects all import paths (file picker, `.soleus` file association, `soleus://` deep link) against zip-bomb / oversized payloads
- `ImportWorkoutPreviewView` is presented as a sheet to confirm name and preview exercises before importing
- Duplicate workout names are auto-resolved with a `-copy` suffix
- The in-app "JSON Format Reference" sheet (Settings → Utilities) documents the generic JSON schema for users importing from external tools

### Contact Us

- `ContactUsView` is a sheet accessible from Settings
- Bug reports open `MFMailComposeViewController` pre-filled with device/app info and optionally attach `soleus-logs.txt` from `LogCapture.shared`. User-entered content (workout names, exercise names, notes) is scrubbed from the attachment by `LogCapture.scrubUserContent(_:)` before it's added.
- Feature requests open a pre-filled email template (no logs attached)
- On simulator `canSendMail()` returns false — a "Mail Not Available" alert is shown instead
- Support email: `SoleusApp@gmail.com` (defined as `ContactUsView.supportEmail`)

## Important Conventions

### File Organization
- CoreData entity files: Auto-generated pairs (Class + Properties extensions)
- Helpers in global scope: `TimeHelper`, `ExerciseInputHelper`
- Shared UI components: `Views/SharedComponents/`
- Settings subviews: `Views/Main/`

### Navigation Bar Items
**Always combine multiple trailing items in HStack**:
```swift
.navigationBarItems(trailing: HStack(spacing: 20) {
    Button(...) { }
    Button(...) { }
})
```
Never use multiple `.navigationBarItems(trailing:)` calls - only the last one will render.

### Color System
15 custom colors defined in Assets.xcassets:
- MyBlue, MyBabyBlue, MyLightBlue, MyGreyBlue
- MyPurple, MyOrchid
- MyBrown, MyLightBrown, MyTan
- MyGreen, MyRed
- MyBlack, MyWhite, MyGrey, StaticWhite

`ColorManager` randomly assigns colors to new workouts. Users can customize via `CustomizeCardView`.

### Logging
- Use `AppLogger` (not `print()`) throughout production code
- `LogCapture.shared` holds the last 500 in-memory log entries
- In-app log viewer accessible via 5-tap secret trigger in the About section of Settings
- Logs are categorized: workout, coreData, ui, navigation, validation, lifecycle
- **PII scrubbing convention**: when interpolating user-entered content (exercise names, workout titles, notes) into any log message, wrap the value in single quotes — e.g., `AppLogger.workout.warning("Failed for '\(name)'")`. `LogCapture.scrubUserContent(_:)` strips anything between single quotes before logs reach Crashlytics or the persisted-error file that's attached to support emails. The in-memory `logs` array (dev-menu viewer only) stays unscrubbed for debuggability. Debug/info-level logs aren't forwarded to Crashlytics, so they don't strictly need the convention — but following it everywhere makes promotion to warning/error safe.

### First-Time User Hints
One-shot tooltips/hints use `@AppStorage("hasSeen<Name>Hint")` flags, default `false`. Current keys:
- `hasSeenLongPressTooltip` — long-press affordance on workout cards (`WorkoutTrackerMainView`)
- `hasSeenSetToggleHint` — explains the green completion toggle on first active workout (`ActiveWorkoutView`)
- `hasSeenRestTimerHint` — explains the rest timer controls the first time it appears (`ActiveWorkoutView`)

All three are pre-set to `true` during UI testing (`SoleusApp.init`) so they don't block automation, and all three are individually resettable + reset-all from `DevMenuView`. New hints should follow this pattern and use the shared `firstTimeHint(icon:title:subtitle:onDismiss:)` ViewBuilder in `ActiveWorkoutView` for style consistency.

### Input Validation
- Regex patterns for form validation
- Max length constraints (typically 10 for numeric inputs)
- `FocusManager` handles keyboard state

### Accessibility Identifiers
- All interactive elements used in UI tests must have `.accessibilityIdentifier(AccessibilityID.someKey)`
- `AccessibilityID` (app target) and `TestID` (UI test target) must be kept in sync
- Both files live at `Soleus/Helpers/AccessibilityIdentifiers.swift` and `SoleusUITests/TestAccessibilityIDs.swift`

## Testing

### Test Targets
- `SoleusTests` — unit tests (~35 coverage on production code, ~98% self-coverage)
- `SoleusUITests` — UI tests using `SoleusUITestBase`

### CoreData in Unit Tests
- Use `PersistenceController.forUITesting` (static `let`, not computed var) to avoid duplicate `NSManagedObjectModel` registration errors
- Always delete test data in `tearDown` and save the context

### UI Test Patterns
- Base class: `SoleusUITestBase` — launches with `--uitesting` arg, provides `tapTab()`, `tapNavBarButton()`, `waitForElement()`
- Inject test data via `launchEnvironment`: `UI_TEST_IMPORT_WORKOUT` (JSON), `UI_TEST_PRE_CREATE_WORKOUT` (name)
- Toggles in Forms: use `coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()` to avoid hitting the cell row instead of the switch handle

## Dependencies

**Firebase iOS SDK** (via SPM) — Crashlytics only
- FirebaseAnalytics was removed (privacy: it derives coarse location from IP server-side, which forced declaring location collection). All `AnalyticsManager` call sites were deleted along with the manager itself.
- FirebaseCrashlytics is the only Firebase product linked; requires a Run Script build phase pointing to `firebase-ios-sdk/Crashlytics/run`
- Users can disable crash reporting entirely via Settings → Privacy → Crash Reports (on by default). The toggle persists to `UserDefaults` key `crashReportingEnabled` and is applied at launch in `AppDelegate.didFinishLaunchingWithOptions` and immediately via `onChange` in `SettingsView`.
- dSYM upload warnings for pre-compiled binary frameworks during App Store distribution are non-blocking and don't affect symbolication

## Privacy / App Store Submission

Four surfaces must stay in sync — changes to one require updating the others:
1. **`Soleus/PrivacyInfo.xcprivacy`** — currently declares only Crash Data, Performance Data, Other Diagnostic Data (all linked-to-user, no tracking, purpose: App Functionality), plus three required-reason API entries (FileTimestamp, UserDefaults, DiskSpace).
2. **App Store Connect → App Privacy questionnaire** — answers must match the manifest.
3. **`Soleus/Views/Main/PrivacyPolicyView.swift`** — user-facing policy. Includes sections covering local storage, CloudKit, HealthKit, Crashlytics (with scrubbing disclosure), and the no-analytics/no-ads claim.
4. **`Soleus/Info.plist`** — includes `ITSAppUsesNonExemptEncryption=false` (skips export-compliance prompt) and `LSApplicationCategoryType=public.app-category.healthcare-fitness`.

If you add any SDK that collects data, add Firebase products back, or start logging new categories of user data, update all four.

## Known Issues and Patterns

### Empty State Handling
Views must handle empty states explicitly:
- Empty workout list: Show grid anyway
- Empty history: Show placeholder message with icon
- Empty sets: Show "Add Set" button

### Timer Persistence
Timer is **calculated** not stored:
```swift
let elapsed = Date().timeIntervalSince(session.startTime)
```
This ensures timer remains accurate after app backgrounding.

## Data Model Relationships

```
Workouts (1) ←→ (many) WorkoutDetail
    ↓                       ↓
WorkoutSession (1:1)   WorkoutSet (many)

Workouts (1) ←→ (many) WorkoutHistory
                            ↓
                      WorkoutDetail snapshot
                            ↓
                      WorkoutSet snapshot
```

`TemporaryWorkoutDetail` mirrors `WorkoutDetail` structure but exists only during active workouts.

## Project Status

- Active development as of June 2026
- Targeting App Store submission (previously released via TestFlight)
- Nutrition tracking feature was removed (see commit 3e42e7b)
- Home tab is currently a placeholder — a meaningful welcome / dashboard is a known gap for new users
- CI pipeline: GitHub Actions on `macos-26`, scheme `Soleus`, posts coverage report to PRs
