# Testing

[< Back to README](../README.md)

## Automated Tests

Run the test suite:
```bash
xcodebuild -scheme Soleus -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' test
```

Or use Xcode's test runner (Cmd + U)

## Manual Testing Checklist

### 1. Workout Creation & Management

**Basic Workout Creation**
- [ ] Create a new workout with a unique title
- [ ] Add exercises of different types (Reps, Weight & Reps, Time, Distance)
- [ ] Add multiple sets to an exercise
- [ ] Verify "Add Set" pre-populates values from previous set
- [ ] Remove sets using swipe-to-delete
- [ ] Reorder exercises using up/down arrows
- [ ] Delete exercises using trash icon
- [ ] Save the workout successfully
- [ ] Verify workout appears on main screen

**Exercise Notes**
- [ ] Tap notebook icon on an exercise (should show gray icon)
- [ ] Add notes to an exercise
- [ ] Verify notebook icon changes to orange with badge
- [ ] Verify notes appear below exercise title
- [ ] Edit existing notes
- [ ] Clear notes (delete all text and save)
- [ ] Verify notebook icon returns to gray

**Workout Template Management**
- [ ] Edit an existing workout template
- [ ] Rename exercises using pencil icon
- [ ] Duplicate a workout (verify all exercises and sets copied)
- [ ] Customize workout card color
- [ ] Delete a workout template
- [ ] Enter reorder mode via ↑↓ nav button, long-press a card to lift it, drag to new position
- [ ] Verify cards shift to accommodate the dragged card
- [ ] With 8+ workout cards, drag a card to the bottom edge — verify the list auto-scrolls down
- [ ] With 8+ workout cards, drag a card to the top edge — verify the list auto-scrolls up
- [ ] Release and verify order is saved after exiting reorder mode
- [ ] Long-press and immediately release without dragging — card should not stay stuck

**Templates**
- [ ] Tap "Start from Template" and select a template
- [ ] Verify exercises and sets are pre-filled correctly
- [ ] Verify time-based and distance-based templates (Warmup, Cardio) load correct field types

**Import / Export**
- [ ] Long-press a card and select "Share Workout" — verify .soleus file is generated
- [ ] Import the file via Settings → Utilities → Import Workout — verify preview shows all exercises
- [ ] Confirm import and verify workout appears in library
- [ ] Import a workout with a duplicate name — verify "-copy" suffix is added
- [ ] Tap a `.soleus` file from Files or Mail — verify import preview opens automatically
- [ ] Tap a `soleus://import?data=...` link from Messages — verify import preview opens

**Generic JSON Import**
- [ ] Settings → Utilities → JSON Format Reference — verify example JSON and field reference display correctly
- [ ] Tap Copy on the example — verify the JSON is copied to clipboard
- [ ] Save the copied JSON as a `.json` file in Files, then import it — verify it loads correctly
- [ ] Import a minimal JSON (just `name` and one `exercises[].name`) — verify defaults are applied (Reps + Weight, 3 empty sets)
- [ ] Import a JSON with `quantifier: "Distance"` and `measurement: "Time"` — verify cardio exercise is created correctly
- [ ] Import an oversized file (>5 MB) — verify import is rejected silently with no crash
- [ ] Import a JSON with a 100+ character exercise name — verify name is clamped to 30 characters

**Active Workout Protection**
- [ ] Start a workout, then long-press the active workout's card — verify Edit, Delete, and Customize all show "in progress" alerts instead of acting

**Validation**
- [ ] Try to save workout with empty title (should show error)
- [ ] Try to save workout with no exercises (should show error)
- [ ] Try to create workout with duplicate title (should show error)
- [ ] Cancel workout creation with unsaved changes (should show warning dialog)
- [ ] Enter 31 characters in the workout title field — verify it truncates to 30
- [ ] Enter 31 characters in the exercise name field — verify it truncates to 30
- [ ] Verify character counter turns red at 30 characters

### 2. Active Workout Flow

**Starting a Workout**
- [ ] Tap play button on workout card
- [ ] Verify exercises and sets load correctly
- [ ] Tap "Start Workout" button (requires double confirmation)
- [ ] Verify timer starts and displays correctly
- [ ] Verify timer continues when app is backgrounded
- [ ] Verify active workout card shows pulsing ripple animation and LIVE badge

**Completing Sets - Manual**
- [ ] Check off a set using the slider/toggle
- [ ] Verify set marks as complete
- [ ] Uncheck a completed set
- [ ] Check multiple sets in sequence

**Completing Sets - Auto-completion**
- [ ] For Weight & Reps exercise: Enter weight only (should NOT auto-complete)
- [ ] Enter reps only (should NOT auto-complete)
- [ ] Enter BOTH weight and reps (should auto-complete)
- [ ] Verify auto-completion only triggers when values are modified, not just pre-populated
- [ ] Test auto-completion for Time exercises
- [ ] Test auto-completion for Distance exercises

**Edit Mode - During Active Workout**
- [ ] Tap pencil icon to enter edit mode
- [ ] Verify pencil icon changes to green checkmark
- [ ] Verify "Add Set" button and ··· menu appear per exercise
- [ ] Add a new set (verify it pre-populates from last set)
- [ ] Delete a set using swipe-to-delete (only works in edit mode)
- [ ] Try to swipe-delete when NOT in edit mode (should not work)
- [ ] Tap ··· on an exercise → Move Down (verify order changes)
- [ ] Tap ··· on an exercise → Move Up (verify order changes)
- [ ] Tap ··· on an exercise → Rename Exercise (verify name updates inline)
- [ ] Tap ··· on an exercise → Delete Exercise → confirm alert (verify removed)
- [ ] Tap + nav button to add a new exercise during workout
- [ ] Tap notes icon on an exercise to add a note — verify note appears below title
- [ ] Exit edit mode (tap checkmark)

**Completing a Workout - No Changes**
- [ ] Complete a workout without making changes
- [ ] Tap "End Workout" (requires double-tap)
- [ ] Verify redirects to workout overview screen
- [ ] Verify confetti animation plays
- [ ] Verify workout stats are correct (weight, reps, time, distance)

**Completing a Workout - With Changes**
- [ ] Modify a workout during session (add/remove sets, add exercises, change values)
- [ ] Tap "End Workout"
- [ ] Verify workout changes preview appears
- [ ] Review the changes shown (added/removed exercises, modified sets)
- [ ] Choose "Update Workout" option
- [ ] Verify template is updated with changes
- [ ] Start the workout again and verify changes were saved

**Completing a Workout - Keep Original**
- [ ] Modify a workout during session
- [ ] Tap "End Workout"
- [ ] In preview, choose "Keep Original Values"
- [ ] Verify workout history is saved but template unchanged
- [ ] Start the workout again and verify original template intact

**Canceling a Workout**
- [ ] Start a workout
- [ ] Tap "Back" button
- [ ] Verify session is saved (can resume)
- [ ] Close and reopen app
- [ ] Verify workout resume banner appears
- [ ] Cancel the workout session

### 3. Workout History

**Viewing History**
- [ ] Tap clock icon to view history
- [ ] Change month/year picker
- [ ] Verify workouts for selected month appear
- [ ] Tap to expand workout details
- [ ] Verify all stats are correct
- [ ] Verify exercise details show correctly
- [ ] Collapse workout details

**Empty States**
- [ ] View a month with no workouts (should show empty state message)
- [ ] Verify no crashes or errors

**History Persistence**
- [ ] Delete a workout template
- [ ] Verify history for that workout is still preserved
- [ ] Verify stats/achievements remain accurate

### 4. Active Workout — Notes Icon

- [ ] Open an active workout before tapping "Start Workout"
- [ ] Verify the notes icon is dimmed and does not respond to taps
- [ ] Tap "Start Workout" and verify the notes icon becomes active and tappable

### 4a. Active Workout — First-Time Hints

(Requires resetting hints via Dev Menu first: Reset Active Workout Hints)

- [ ] Start a workout for the first time after reset — verify "Tap the green circle to mark a set complete" banner appears
- [ ] Tap the X on the banner — verify it dismisses
- [ ] Background the app and reopen — verify the dismissed banner does not reappear
- [ ] Reset hints again and start a workout — complete a set so the rest timer kicks in — verify "Rest timer started" banner appears
- [ ] Verify the rest timer banner is dismissed by tapping the X
- [ ] Dev Menu → Reset Active Workout Hints — verify both banners reappear on next active workout

### 5. Achievements & Dashboard

**Achievement Tracking**
- [ ] Complete workouts to unlock achievements
- [ ] Verify newly unlocked achievements appear on the Workout Overview screen
- [ ] Navigate to Dashboard tab and verify all unlocked achievements are listed
- [ ] Verify achievement progress counters update correctly

### 6. Settings & Customization

**Unit Preferences**
- [ ] Change weight units (lbs / kg)
- [ ] Verify unit change reflects in all views
- [ ] Change distance units (miles / km)
- [ ] Verify conversions are correct
- [ ] Change height units (inches / cm)

**Color Customization**
- [ ] Long-press a workout card
- [ ] Select "Customize Card"
- [ ] Change workout card color
- [ ] Verify color persists after app restart

**Dark Mode**
- [ ] Toggle device dark mode
- [ ] Verify all screens render correctly in dark mode
- [ ] Check that StaticWhite color remains white in dark mode
- [ ] Verify text contrast is sufficient

**Privacy Settings**
- [ ] Settings → Privacy → Crash Reports toggle is on by default for fresh installs
- [ ] Toggle off, force quit, reopen — verify the setting persists
- [ ] Toggle off, induce a non-fatal error (e.g., via Dev Menu if available, or trigger an import of malformed data) — verify nothing appears in Crashlytics for that session
- [ ] Toggle back on — verify subsequent errors are reported

**Privacy Policy view**
- [ ] Settings → Privacy Policy — verify the policy renders all seven sections (workouts stay with you, iCloud Sync, Apple Health, Crash Reports, No Analytics, Bug Reports, Your Control)
- [ ] Verify the "Last updated" date is current

### 7. Keyboard & Focus Behavior

- [ ] Open Add/Edit workout and tap a reps field — verify keyboard appears and the exercise card scrolls into view
- [ ] Tap a field near the bottom of a long workout — verify the card is not hidden behind the keyboard
- [ ] Switch between fields within the same exercise — verify the Add Exercise button does not flash visible between taps
- [ ] Swipe down on the keyboard — verify it dismisses
- [ ] Tap the "Done" button on the keyboard toolbar — verify keyboard dismisses
- [ ] With changes made, swipe down on the sheet — verify the unsaved changes warning appears
- [ ] With no changes, swipe down on the sheet — verify it dismisses without warning

### 8. Edge Cases & Error Handling

**Data Integrity**
- [ ] Create a workout with many exercises (15+)
- [ ] Create a workout with many sets per exercise (20+)
- [ ] Add very long exercise names
- [ ] Add very long notes (multiple paragraphs)
- [ ] Enter maximum weight values
- [ ] Enter maximum rep values
- [ ] Enter maximum time values (hours)

**App State Management**
- [ ] Start a workout and background the app for 1 minute
- [ ] Verify timer continues accurately
- [ ] Force quit app during active workout
- [ ] Reopen app and verify session can resume
- [ ] Test multiple workout sessions in same day

**UI Responsiveness**
- [ ] Test all interactions with keyboard open
- [ ] Verify keyboard dismisses when tapping outside text fields
- [ ] Test on different device sizes (iPhone SE, iPhone 15 Pro Max)
- [ ] Test in landscape orientation
- [ ] Verify all dialogs appear correctly
- [ ] Verify no UI elements are clipped or overlapping

### 9. Regression Tests

**Core Functionality Preservation**
- [ ] Verify old workouts (created before updates) still load correctly
- [ ] Verify old workout history entries display correctly
- [ ] Verify achievements earned before updates still show
- [ ] Test that all previous features still work after new updates

**Performance**
- [ ] App launches in under 3 seconds
- [ ] Workout list loads quickly (< 1 second)
- [ ] History view loads smoothly
- [ ] No lag when checking off sets during workout
- [ ] No lag when adding exercises or sets
- [ ] Smooth animations throughout the app

**Data Persistence**
- [ ] Create workout, force quit app, verify workout saved
- [ ] Complete workout, force quit app, verify history saved
- [ ] Modify settings, force quit app, verify settings saved
- [ ] Start workout, force quit app, verify session can resume

## Testing Notes

- **Testing Device**: Document which device/iOS version you tested on
- **Test Date**: Record the date of testing
- **Issues Found**: Document any bugs or unexpected behavior
- **Screenshots**: Consider taking screenshots of any issues
- **Performance**: Note any slowdowns or lag

## Regression Testing Schedule

It's recommended to run through this checklist:
- Before each release
- After major feature additions
- After bug fixes that touch core functionality
- Quarterly for general health check
