# Usage Guide

[< Back to README](../README.md)

## Creating a Workout

1. Navigate to the **Workout** tab
2. Tap the **+** button in the top-right navigation bar
3. Enter a workout title (up to 30 characters)
4. Tap **Add Exercise**, enter an exercise name, and choose:
   - **Track By**: Reps or Distance
   - **Measure With**: Weight or Time
5. Tap **Add Exercise** to confirm — the exercise is added with one default set
6. Tap **Add Set** on any exercise card to add more sets
7. Enter target values (reps, weight, time, or distance) for each set
8. Tap **Save** to create the workout template

**Tips:**
- Use **Start from Template** to pre-fill a workout from a built-in plan (Push, Pull, Legs, Cardio, etc.)
- Tap the **⋯** menu on any exercise to rename, reorder, delete, or add notes
- Swipe down on the sheet to dismiss — if there are unsaved changes, you will be warned first

---

## Editing a Workout

1. Long-press any workout card on the main screen
2. Select **Edit** from the context menu
3. Make changes to the title, exercises, or sets
4. Tap **Save** to apply changes

---

## Reordering Workout Cards

1. Tap the **↑↓** button in the top-right navigation bar to enter reorder mode
2. Long-press any card to lift it
3. Drag it to the desired position — other cards shift to make room
4. Drag toward the top or bottom edge of the screen to auto-scroll if you have many cards
5. Release to drop, then tap the **✓** button to exit reorder mode

---

## Starting a Workout

1. Tap the **play button** on any workout card
2. Review the exercises and sets on the active workout screen
3. Tap **Start Workout** to begin — the timer starts and sets become editable
4. Enter your actual values (weight, reps, time, or distance) for each set
5. Toggle the checkmark on each set to mark it complete
   - Sets can also auto-complete when both required fields are filled and modified
6. The rest timer starts automatically after each completed set (if enabled in Settings)

---

## Editing During a Workout

1. Tap the **pencil icon** in the top-right to enter edit mode
2. Available actions in edit mode:
   - Add new exercises via the **+** nav button
   - Add sets with the **Add Set** button on each exercise
   - Swipe left on a set row to delete it
   - Tap **···** on any exercise to rename it, move it up/down, or delete it
   - Tap the **notes icon** next to any exercise to add or edit an inline note
3. Tap the **green checkmark** to exit edit mode

---

## Completing a Workout

1. Tap **End Workout** (requires a second tap to confirm)
2. If you modified anything during the session, a **Changes Preview** appears:
   - **Update Workout** — saves your session changes back to the template
   - **Keep Original** — saves history but leaves the template unchanged
3. The **Workout Overview** screen appears with your session stats and any achievements unlocked
4. Tap **Proceed** to return to the main screen

---

## Cancelling a Workout

- Tap the **back arrow** while a workout is in progress — this backgrounds the session (timer keeps running, session can be resumed)
- To fully cancel, return to the active workout via the **resume banner** and tap **Cancel Workout**

---

## Viewing Workout History

1. Tap the **clock icon** in the Workout tab navigation bar
2. Use **Monthly / All Time** to filter the date range
3. For monthly view, use the month/year picker to navigate
4. Tap any workout card to expand and view per-exercise set details
5. Swipe left on a history card to delete that entry

---

## Viewing Progress Charts

1. Open **Workout History** (clock icon)
2. Tap **Progress** in the view mode selector (only visible when history exists)
3. Each workout group shows average weight, duration, and trend direction
4. Tap an exercise chip to drill down into that exercise's session history — showing max weight, reps, and volume trends across sessions

---

## Importing a Workout

Soleus accepts two file formats:
- **`.soleus`** — the native format produced by exporting a workout from this app
- **`.json`** — a plain JSON file produced by any external tool (see Settings → Utilities → JSON Format Reference for the schema)

**From Settings:**
1. Open **Settings → Utilities → Import Workout**
2. Pick either a `.soleus` or `.json` file from the file picker
3. Review the workout name and exercises on the import preview screen — edit the name if needed
4. Tap **Import** to add the workout to your library

**From a share sheet, AirDrop, or Messages link:**
- Tapping a `.soleus` file from Messages, Mail, AirDrop, or Files will open Soleus and trigger the import preview automatically
- Tapping a `soleus://import?data=...` link sent over iMessage opens the import preview directly

**Notes:**
- The import preview always shows your name field as editable — if the imported name is long, it's trimmed to 30 characters for display
- Duplicate workout names are auto-resolved with a `-copy` suffix

---

## Exporting / Sharing a Workout

1. Long-press any workout card
2. Select **Share Workout** from the context menu
3. Choose a share destination (AirDrop, Messages, Files, etc.)

---

## Customizing a Workout Card Color

1. Long-press any workout card
2. Select **Customize Card**
3. Choose from 15 available colors
4. Tap **Save** — the card updates immediately

---

## Dashboard & Achievements

- Navigate to the **Dashboard** tab (bar chart icon) to view your fitness stats and achievements
- Tap any achievement to see its description and progress
- Newly unlocked achievements also appear on the **Workout Overview** screen immediately after a session

---

## Settings

Navigate to the **Settings** tab (gear icon) to configure:

| Setting | Options |
|---|---|
| Weight units | lbs / kg |
| Distance units | Miles / km |
| Height units | Inches / cm |
| Appearance | Light / Dark / System |
| Auto-start rest timer | On / Off |
| Default rest duration | Configurable in seconds |
| Crash Reports | On / Off (on by default — sends anonymous crash data to help fix bugs; user content is stripped before sending) |

---

## Contact & Support

Navigate to **Settings → Contact Us** to:
- Submit a bug report (optionally attaches diagnostic logs)
- Request a new feature
