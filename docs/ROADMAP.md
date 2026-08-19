# Soleus — Product Roadmap

[< Back to README](../README.md)

This document outlines all planned features for Soleus, organized by priority tier and tagged as **Free** or **Pro**. The core workout experience will always remain free. Pro is intended as a low-cost upgrade (one-time purchase or annual subscription) for users who want advanced analytics, integrations, and platform extensions.

---

## Tier 1 — Near Term (High Impact, Low Effort)

These features build directly on existing infrastructure and can be shipped quickly.

---

### Enhanced Workout Overview `Free`

**Problem:** The workout completion screen feels repetitive when no achievements are unlocked — the user just sees stat cards and a Proceed button with nothing to make the session feel meaningful.

**Solution:**
- Always show elapsed time prominently at the top of the overview regardless of workout type
- Add a "Best Set" callout — highlight the single heaviest or highest-volume set from the session (e.g., "New best: Bench Press 185 lbs × 5")
- Add a motivational summary line that varies based on session data (e.g., "Great session — 12,400 lbs moved in 48 minutes")
- Surface Personal Records detected during this workout as a distinct banner, separate from the achievements section, so PRs appear even when no achievement milestone is crossed
- Ensure the screen never feels empty — if no stats, achievements, or PRs are present, show an encouraging message with workout duration

---

### Personal Records (PRs) `Free`

**Problem:** Users have no way to know when they hit a new max weight, rep count, or volume for a given exercise. This is one of the most motivating pieces of feedback in strength training.

**Solution:**
- After each workout completes, compare completed sets against the entire history for each exercise
- Detect three types of PR: max weight lifted (single set), max reps at a given weight, and highest total volume (sets × reps × weight) in a session
- Store PRs in CoreData alongside workout history so they persist and can be queried
- Display newly broken PRs on the Workout Overview screen with a distinct badge
- Show the current PR for each exercise in the exercise detail / history drill-down view
- PRs update automatically as history grows — no manual entry required

---

## Tier 2 — Medium Term (High Impact, Moderate Effort)

These features require new screens or data models but no external dependencies.

### Weekly Workout Schedule `Free`

**Problem:** Users have workout templates but no way to plan which workouts happen on which days. There is no structure to guide their week.

**Solution:**
- Add a schedule screen (accessible from the Dashboard or Settings) where users can assign any workout template to one or more days of the week
- Days can have zero, one, or multiple workouts assigned
- The Dashboard shows "Today's Workout" — a card showing the scheduled workout for today with a quick-start button
- If no workout is scheduled for today, the dashboard shows a rest day message
- Schedule is stored locally in CoreData and does not require an account
- Integrates with streak tracking — a scheduled day counts toward the streak only if the scheduled workout (or any workout) is completed


### Progressive Overload Suggestions `Pro`

**Problem:** Users must manually remember what they lifted last session and decide whether to increase weight or reps. There is no guidance for progression.

**Solution:**
- When the user opens an active workout, compare the current template weights and reps against the most recent completed session for each exercise
- If the previous session's sets were all completed and form looked strong (all sets checked off), suggest a small increase — typically +5 lbs for upper body, +10 lbs for lower body, or +1-2 reps
- Suggestions appear as a subtle banner above each exercise card during the active workout ("Last time: 135 × 8 — try 140 today?")
- User can dismiss individual suggestions or disable the feature entirely in Settings
- Suggestions are conservative — only trigger after a fully completed session, never after a partial one
- Requires the PRs feature (Tier 1) to be built first as it shares the same history query infrastructure

---

### Enhanced dashboard widgets will be pro features


### Workout Insights `Pro`

**Problem:** Users have raw history data but no synthesized analysis of their training patterns. There is no way to answer questions like "Am I training each muscle group consistently?" or "Which day of the week do I perform best?"

**Solution:**
- Add an Insights tab or section within the Dashboard available to Pro users
- Initial insight cards include:
  - **Training Frequency** — workouts per week over the past 4, 8, and 12 weeks with a trend arrow
  - **Most Trained Exercises** — top 5 exercises by session frequency over the selected period
  - **Best Day of the Week** — which weekday has the most completed workouts (and highest average volume)
  - **Longest Streak** — all-time longest consecutive workout streak vs. current streak
  - **Volume Trend** — total weight lifted per week as a bar chart for the past 8 weeks
- Insights are computed on-device from CoreData history — no server required
- Data is filtered by a configurable time range: last 30 days, 90 days, or all time
- Each insight card includes a brief plain-language interpretation (e.g., "You've been most consistent on Tuesdays — 80% completion rate")

---

## Tier 3 — Longer Term (Significant Effort or External Dependencies)

---

### Universal Links / Server-Backed Workout Sharing `Pro`

**Problem:** The current `.soleus` file sharing works but requires the recipient to manually open a file. There is no way to share a workout as a link that opens directly in the app.

**Solution:**
- Set up a lightweight serverless backend (e.g., AWS Lambda + S3, or Cloudflare Workers + R2) to host workout JSON payloads
- When a user shares a workout, the app uploads the serialized `ShareableWorkout` JSON to the backend and receives a short URL (e.g., `https://soleus.app/w/abc123`)
- The URL is copied to clipboard or passed to the share sheet alongside the existing `.soleus` file option
- Implement Associated Domains in the app so that tapping the link on any iOS device opens Soleus directly and triggers the existing import flow
- Links expire after 30 days to limit storage costs
- Free users retain the existing `.soleus` file sharing — Pro users get the shareable link
- Requires: a registered domain, SSL certificate, Associated Domains entitlement, and a minimal backend

---


## Tier 4 — Platform Expansion

These are independent platform targets and should be built after the core app is feature-complete and stable.

---

### Home Screen Widget `Pro`

**Problem:** Users must open the app to see today's scheduled workout or their recent stats. A widget would surface this information passively.

**Solution:**
- Implement a WidgetKit extension with two widget sizes:
  - **Small**: today's streak count and scheduled workout name
  - **Medium**: today's scheduled workout with a summary of last session's stats
- Widget reads from a shared App Group container (CoreData store must be migrated to an App Group to be accessible from the extension)
- Tapping the widget deep-links to the relevant workout in the app
- Requires the Weekly Workout Schedule (Tier 2) to be completed first — without a schedule there is nothing meaningful to show
- Widget timeline refreshes after each completed workout and at midnight (new day)

---

### Apple Watch Companion App `Pro`

**Problem:** Tracking sets during a workout requires the user to keep their phone accessible at all times. A Watch app would let users log sets, view the rest timer, and control the workout from their wrist.

**Solution:**
- Create a separate WatchKit App target within the Xcode project
- Use `WatchConnectivity` (`WCSession`) to pass the active workout's exercise list and set state between iPhone and Watch in real time
- Watch UI shows:
  - Current exercise name and set number
  - A checkmark button to mark the current set complete
  - Rest timer countdown with haptic feedback when complete
  - A "Next Exercise" button
  - Workout elapsed time in a complication
- Set completions on the Watch sync immediately to the iPhone via `WCSession.transferUserInfo`
- If the phone is out of range, the Watch queues changes and syncs when reconnected
- Watch-only sessions (without the phone) are out of scope for the initial version
- Requires: WatchKit target, WatchConnectivity implementation, a simplified Watch-optimized data model, and separate UI design for the small screen
- This is the most development-intensive item on the roadmap

---

## Summary

| Feature | Tier | Free / Pro |
|---|---|---|
| iCloud Sync | ✓ Shipped | Free |
| Enhanced Workout Overview | 1 | Free |
| Personal Records | 1 | Free |
| My Exercises + Exercise-Specific Rest Timer | 2 | Free |
| Weekly Workout Schedule | 2 | Free |
| Workout History Calendar View | 2 | Free |
| Progress Charts (Exercise History Graphs) | 2 | Pro |
| Progressive Overload Suggestions | 2 | Pro |
| Customizable Dashboard | 2 | Pro |
| Workout Insights | 2 | Pro |
| Universal Links / Server Sharing | 3 | Pro |
| Workout Recap Shareable Card | 3 | Pro |
| Home Screen Widget | 4 | Pro |
| Apple Watch Companion App | 4 | Pro |

---

## Notes on Monetization

The free tier covers the complete core workout loop — creating workouts, tracking sessions, viewing history, scheduling, notifications, Health integration, and sync. A user who never pays gets a fully functional fitness tracker that works across all their devices.

Pro is positioned as an analytics and convenience upgrade:
- **Analytics**: Progress Charts, Progressive Overload Suggestions, Workout Insights, PRs (free, but Pro builds on them)
- **Convenience**: Widget, Watch app
- **Social**: Shareable Card, Universal Links

Recommended pricing: **$2.99/year** or **$4.99 one-time**. Given the utility nature of the app, a low-friction one-time purchase may convert better than a subscription for an early-stage user base.
