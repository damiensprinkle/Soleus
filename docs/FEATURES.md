# Features

[< Back to README](../README.md)

## Workout Management

- **Create Custom Workouts**: Build personalized workout plans with multiple exercises
  - Add unlimited exercises to each workout
  - 30-character limit on workout titles and exercise names with live counter
  - Configure each exercise with a quantifier (Reps or Distance) and measurement (Weight or Time)
  - Support for strength training (reps/weight), cardio (distance/time), and timed exercises
  - Reorder exercises within a workout using up/down controls
  - Rename exercises via a dedicated dialog
  - Add per-exercise notes for form cues, personal records, or reminders
  - Auto-populated sets — new sets copy values from the previous set
  - Swipe-down dismiss protection — warns before discarding unsaved changes
  - Keyboard-aware form — auto-scrolls to the focused field so it is never hidden behind the keyboard

- **Start from Template**: Bootstrap a new workout from a built-in template
  - Templates include: Push, Pull, Legs, Chest, Back, Shoulders, Arms, Total Body I, Total Body II, Warmup, Cardio
  - Templates support all exercise types including time-based and distance-based exercises
  - Applying a template to a non-empty form requires explicit confirmation

- **Workout Template Management**:
  - Edit and update existing workout templates at any time
  - Duplicate workouts to create variations
  - Reorder workout cards on the main screen via long-press drag — drag near the top or bottom edge and the list auto-scrolls
  - Color-code workout cards — 15 color options available via the Customize Card menu
  - Active workouts cannot be edited, deleted, or have their card customized — all three guards enforce this consistently
  - Import workouts from native `.soleus` files (shared by other users) or generic `.json` files (created in any external tool)
  - Export and share workouts as `.soleus` files via AirDrop, Messages, or any share target
  - In-app **JSON Format Reference** (Settings → Utilities) documents the import schema for users building JSON externally

## Active Workout Tracking

- **Session Management**:
  - Real-time workout timer with automatic background time tracking
  - Single active session enforced — starting a new workout while one is active is blocked
  - Session persists through app backgrounding, force quit, and device restart
  - Resume banner appears on the main screen when a session is in progress
  - Active workout card shows a pulsing ripple animation and an "Active" badge for at-a-glance identification
  - Notes icon is disabled and dimmed until the workout has been started
  - First-time hints walk new users through the green completion toggle and the rest timer (each shown once, individually resettable from the developer menu)

- **Set Tracking**:
  - Toggle completion of individual sets with a checkmark
  - Auto-complete sets when both required fields are filled and modified (e.g., reps AND weight entered)
  - Rest timer auto-starts on set completion (configurable in Settings)

- **Edit Mode (during active workout)**:
  - Add new exercises mid-workout via the + nav button
  - Add or remove sets with pre-population from the previous set
  - Tap ··· on any exercise to rename it, move it up/down, or delete it
  - Tap the notes icon on any exercise to add or edit inline notes
  - Swipe-to-delete sets (only available in edit mode)
  - New exercises added mid-workout are permanently saved to the template immediately

- **Workout Completion**:
  - Double-confirmation required to end a workout
  - If the workout was modified during the session, a changes preview is shown before saving
  - User can choose to update the template with session changes or keep the original
  - Workout history is always saved regardless of template update choice
  - Navigate to Workout Overview on completion

## Progress Tracking

- **Workout History**:
  - View completed workouts filtered by month/year or all-time
  - Skeleton loading animation while history loads
  - Detailed workout summaries: total duration, total weight lifted, total reps, total cardio time, total distance
  - Expandable exercise details showing each set's values for every session
  - Delete individual history entries

- **Progress View**:
  - Switch between List and Progress views within workout history
  - Progress view groups sessions by workout name
  - Per-workout stats: average weight lifted, average duration, trend indicator (↑ / → / ↓)
  - Drill down to any exercise using exercise chips — shows max weight, total reps, and total volume trends across sessions
  - Last 5 sessions displayed per exercise with date, max weight, reps, and volume

- **Workout Overview (post-completion)**:
  - Confetti animation on workout completion
  - Stat cards for: reps completed, total weight lifted, cardio time, distance covered
  - Achievements unlocked during the session displayed as cards

## Achievements & Dashboard

- **Achievements**:
  - Milestone-based achievement system (Bronze, Silver, Gold, Platinum tiers)
  - Achievements tracked automatically based on workout history
  - Full achievements list accessible from the Dashboard tab
  - Newly unlocked achievements shown on the Workout Overview screen after each session

- **Dashboard**:
  - Dedicated dashboard tab showing fitness progress and achievements

## Data & Sync

- **iCloud Sync**:
  - Workouts, history, and settings sync automatically across all devices signed into the same iCloud account via CloudKit
  - No account or login required beyond the user's existing Apple ID
  - Data is stored in the user's personal iCloud — Soleus never accesses it

## Settings & Customization

- **Unit Preferences**:
  - Weight: lbs or kg
  - Distance: miles or km
  - Height: inches or cm

- **Appearance**:
  - Light, dark, or system appearance setting

- **Rest Timer**:
  - Auto-start rest timer on set completion (on/off)
  - Configurable default rest duration

- **User Profile**:
  - Set and update personal details

## Sharing & Community

- **Workout Import/Export**:
  - Export any workout as a `.soleus` file (zlib-compressed binary, contains a 4-byte magic header so messaging apps render it as a tappable file rather than inline text)
  - Import `.soleus` files from other users via the document picker, share sheet, or `soleus://` deep link
  - Import generic `.json` files from external tools — fields that don't apply default to sensible values
  - 5 MB import size cap and per-field length limits protect against malformed or hostile payloads
  - Duplicate workout names on import are auto-resolved with a `-copy` suffix
  - Import preview screen shows all exercises before confirming


## Support & Transparency

- **Contact Us**:
  - In-app bug report form (pre-filled with device/app info, optional log attachment)
  - In-app feature request form
  - Join Discord link
  - Responds within 48 hours

- **FAQ**: In-app answers to common questions

- **Privacy Policy**: Accessible within the app — discloses iCloud sync, Apple Health integration, Crashlytics crash reporting, and the absence of analytics, ads, and behavioral tracking

- **Privacy Controls**:
  - **Crash Reports** toggle (Settings → Privacy) — on by default, can be disabled at any time, takes effect immediately
  - User-entered content (workout names, exercise names, notes) is automatically scrubbed from any logs before they reach Crashlytics or get attached to a support email

- **Diagnostics**:
  - In-app log viewer (5-tap secret trigger in the About section of Settings)
  - Logs contain only in-app events — user content is scrubbed before persistence and remote upload
  - Optional log attachment on bug reports

## User Interface

- **Modern Design**:
  - Clean, intuitive SwiftUI interface
  - Full dark mode support with adaptive colors
  - Smooth animations and spring transitions throughout
  - Custom tab navigation: Workout, Dashboard, Settings
  - Responsive layout adapting to all iPhone screen sizes

- **Keyboard Handling**:
  - Auto-scroll to focused field in workout editor
  - "Done" button on all numeric keyboards
  - Swipe-to-dismiss keyboard in scroll views
  - Add Exercise and Start from Template buttons hide while keyboard is open

- **Accessibility**:
  - Accessibility identifiers on all interactive elements
  - Accessibility labels and hints on key controls
  - VoiceOver-compatible set completion toggles
