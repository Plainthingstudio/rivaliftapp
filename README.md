# Rivalift

**Lift with your friends. Win the week.**

Rivalift is an iOS gym log with weekly leagues between friends. Scores reward consistency
and personal records instead of absolute weight, so every level can compete. See
[`docs/PRD.md`](docs/PRD.md) for the full product spec.

## Getting started

Requirements: Xcode 16+, iOS 17+ simulator, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open Rivalift.xcodeproj
```

Pick an iPhone simulator and run. To run on a device or to test iCloud sync, set your
team in *Signing & Capabilities* and make sure the `iCloud.app.rivalift.ios` container
exists in your developer account. Without iCloud the app falls back to a local store.

Run the tests with `⌘U`, or from the command line (see `CLAUDE.md`).

## What works today (M0–M2)

- Offline workout logging: templates, empty workouts, "repeat last", set table with a
  *previous* column, warm-up/drop/failure sets, per-dumbbell weights, bodyweight and timed
  exercises, notes, reordering, crash-safe active session, stale-session handling
- Rest timer that survives backgrounding (absolute end time plus a local notification),
  with −15 s / +15 s / skip
- 132 built-in exercises, custom exercises (archived rather than deleted once used),
  built-in programs (Full Body 3×, Upper/Lower 4×, PPL 6×, 5×5) and user templates
- Personal records (heaviest, Epley e1RM, reps at weight, session volume) with live
  badges, first-log baseline and kg/lb tolerance
- Rule-based next-weight suggestions (increase / same / deload)
- History list and calendar, session detail, exercise charts, weekly target and streak
- Onboarding, kg/lb switching, rest defaults, notification toggles, CSV export
- League scoring engines for Consistency, Strength and Custom modes, checked by shared
  scoring vectors

Leagues, accounts and sync (M4–M6) come next. The Leagues tab explains the format and
shows an estimate of this week's Consistency score.
