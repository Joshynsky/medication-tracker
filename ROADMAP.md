# MediTrack — Roadmap (not yet started, for reference only)

## Immediate priority (in progress)
1. Full test suite (unit → widget → integration) — Stage 2 of 3 in progress
2. Fix known bugs (see KNOWN_ISSUES.md) — after tests complete
3. Dogfood: use the app personally for 1-2 weeks before adding new scope

## Near-term candidates (after core is stable)
- Caregiver Mode (already stubbed in UI) — highest-leverage next feature; notify a family member on missed doses

### Caregiver Mode — Export/Import Design (fleshed out, not yet built)

**Core model:** No live cloud sync for v1. Caregiver exports a file, next caregiver/patient imports it. Fits the app's existing offline-first architecture; avoids building accounts/auth/backend for v1.

**What's exported:** The PATIENT's data only — full medication list, schedules, and dose history. Never the caregiver's own account/identity data. A caregiver who's stepping back exports the patient's record to hand off; they don't export anything of their own.

**Merge behavior (on import):**
- **Dose events:** naturally merge-friendly — discrete, timestamped facts, combined by unique ID, duplicates by ID dropped.
- **Medications/schedules:** use a dosage/schedule CHANGE LOG per medication, not a single "current value" — each entry records the date of change, the new dosage/schedule, and who made it (doctor / caregiver / patient self-edit), with an optional note for why. Merging two records = combining their change lists by date, not last-write-wins on a single field. This lets two caregivers make different valid changes at different times without either being silently overwritten.
- **Discontinued medications:** never hard-delete a medication row when a prescription ends — mark it with a `discontinuedAt` date instead. This lets "ended" merge naturally the same way any other dated change does, with no special-case logic needed.

**Open questions for when this gets built:**
- Exact file format for export/import (JSON, likely, given existing Drift/JSON patterns elsewhere in the app)
- Whether patient "picks up" tracking themselves needs its own guided flow, or just resumes normal use with the imported data already in place
- UI for browsing/understanding the dosage change log (a history view per medication)

**Origin note:** Design shaped directly by a real caregiving scenario (multiple lifetime + time-limited medications, up to ~12 pills in one morning dose, care handed between multiple people/facilities) — not speculative. Worth revisiting this real scenario when actually building the UI, especially for how a large multi-pill dose cluster is displayed.

**Grouping doses for display (fixed time-of-day buckets, not dynamic clustering):**
Morning 5–11am / Afternoon 11am–5pm / Evening 5–9pm / Night 9pm–5am. Reuses the dashboard's existing time-of-day theming boundaries. Purpose: make a busy multi-medication morning/day legible at a glance (e.g. several meds staggered 7:00/7:30/8:00am, or a large same-time cluster) without requiring exact-time visual clutter. Not yet designed in detail — just the bucket boundaries agreed so far.

- Adherence PDF/report export — data already computed for History calendar
- Refill reminders — quantity data already in schema
- Set up CI to run the test suite automatically on push/PR (suggested by Claude Code once the test suite existed — deferred to keep this session focused)

## Longer-term / exploratory
- Photo-based pill confirmation at dose-taking time
- Drug interaction / duplicate warnings (needs external data source)
- Wearable/voice reminders

## Positioning note
Global apps (Medisafe, MyTherapy) are available in Kenya but not localized to it. Gap identified: offline-first architecture (already true by default), low-data-usage design, and family/caregiver patterns suited to local care distribution — not "more features than Medisafe," but "fits local context better." Keep this in mind when designing future features (e.g. don't assume always-on connectivity when building Supabase sync); no urgent action needed now.