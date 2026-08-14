# MediTrack — Known Issues

## Fixed

### 1. Multi-dose & custom schedules broken (architectural) — RESOLVED
`getExpectedDoseTimesToday` previously only received the `Medication` row, not the `ScheduleTimes` table where per-day times, custom days, and interval hours actually live. `multiple_times` schedules showed only 1 dose/day instead of several; `custom` day schedules ignored which days were configured. Fixed by changing the function signature to accept `(Medication med, List<ScheduleTime> scheduleTimes, DateTime now)` and implementing all 4 schedule types against real data.

### 2. Cross-medication window bug — RESOLVED
Dot-coloring logic used to reuse one medication's window size for ALL medications' dots. `computeTimeDots` now takes a `Map<int, List<ScheduleTime>>` and resolves each medication's own window internally.

### 3. Hardcoded interval in every_x_hours branch — RESOLVED
`getExpectedDoseTimesToday`'s `every_x_hours` branch hardcoded `intervalH = 4` instead of reading the medication's real configured interval. Fixed alongside #1 via the same `ScheduleTimes`-based rework; added `intervalHoursForEveryXHours()` helper.

### 4. once_daily used startDateTime instead of ScheduleTimes (found during #1–3 fix)
`once_daily` read its dose time from `med.startDateTime.hour/minute` — a wizard field independently set from (and able to silently disagree with) the actual "Take at" time configured in `ScheduleTimes`. All 4 schedule types now uniformly read hour/minute from `ScheduleTimes`. Covered by a dedicated test asserting the `ScheduleTimes` value wins when the two disagree.

### 5. Hero card's "next dose" window used a second hardcoded interval (found during #1–3 fix)
Separately from the `every_x_hours` branch fix, the dashboard hero card's own "next dose" window calculation hardcoded `intervalH = 12`. Now derives its real interval from that medication's `ScheduleTimes`, via the new `windowMinutesForMedication()` helper.

### Timer resource leak in Dashboard and Add Medication wizard
`dashboard_screen.dart`'s `_tick()` rescheduled itself via an uncancelled `Future.delayed(30s, _tick)`, silently continuing to run in the background forever after the widget was disposed. Same pattern in `step_three_quantity.dart`'s 4-second helper-text delay. Both converted to cancellable `Timer` fields, properly cancelled in `dispose()`. Found only because widget-testing forced the lifecycle issue to surface — `flutter analyze` doesn't catch this pattern.

### History not refreshing after dose confirmation
`historyProvider` (a non-autoDispose FutureProvider) only recomputed when `medicationRepositoryProvider` was invalidated — which only happened after `saveMedication`. Confirming/snoozing a dose or deleting a medication goes through a separate `dashboardProvider`/`DashboardNotifier`, which never triggered a History refresh. Fixed in `lib/providers/dashboard_provider.dart`: `DashboardNotifier` now calls `ref.invalidate(historyProvider)` in `confirmDose`, `snoozeDose`, and `deleteMedication`.

### Duplicated, inconsistent window-size formula
Two independent copies of the "on-time window" calculation existed — dashboard used `÷5`, `alarm_service.dart` used `÷6`, and they disagreed. Consolidated into a single shared `scheduleWindowMinutes()` function in `lib/shared/schedule_window.dart`, using the `÷5` value as the source of truth (deliberately more forgiving, given real-world caregiver/multi-medication use cases where strict windows risk falsely flagging honest lateness as "missed"). Per-medication configurable windows remains a known future improvement, not yet built.

### every_x_hours ignored its own "Starting at" time (found during physical-device manual testing, 2026-08-13)
`_getDoseTimes`'s `every_x_hours` branch anchored purely on `startDateTime` (date AND time-of-day), silently ignoring the wizard's "Starting at" time picker — which itself was pure decoration, not wired to anything. Meanwhile the dashboard's `getExpectedDoseTimesToday` already anchored on the configured time (`ScheduleTimes.hour/minute`), so the two disagreed. Fixed: the repository now anchors on `times[0]` (date from `startDateTime`, time-of-day from the configured time) like every other schedule type; "Starting at" is now a real, editable time picker; added quick preset chips (24h/12h/8h/6h) for common frequencies; trimmed the now-fully-unused time component off the "Start date" picker.

### Adding a medication silently duplicated instead of creating fresh entries (found during physical-device manual testing, 2026-08-13)
`AddMedicationScreen`'s wizard fields are backed by app-lifetime Riverpod `StateProvider`s with no reset logic — reopening "Add Medication" after a save (or a cancel) silently reused the previous session's data, which read to the user as the app "editing an existing medication" instead of adding a new one. Compounded by the Save button having no re-entrancy guard, so a nervous re-tap while the (stale-looking) screen sat unchanged created near-duplicate rows. On one test device this produced 4 duplicate "Amoxicillin" entries, each scheduling its own set of alarms. Fixed: `resetAddMedicationState()` is now called before every push of `AddMedicationScreen`; the Save button disables itself (with a spinner) while a save is in flight.

### Missing battery-optimization exemption request — likely cause of a real missed notification (found during physical-device manual testing, 2026-08-13)
A dose scheduled for a specific time produced no visible notification despite the underlying alarm firing correctly (confirmed via `adb dumpsys alarm`, `exactAllowReason=policy_permission`) — the device (MIUI/Xiaomi) was not on the battery-optimization exemption whitelist (`dumpsys deviceidle whitelist`), so the OS killed the app's background process before it could post the notification. Added `AlarmService.requestBatteryOptimizationExemption()` (via `permission_handler`), requested alongside notification/exact-alarm permissions in onboarding and from More > Notification Settings. Does not cover OEM-specific extras like MIUI's separate "Autostart" toggle — no standard Android API exists for those.

### No way to edit a saved medication
Only Add and Delete existed; changing a dosage time meant re-adding (which, combined with the wizard-reset bug above, is exactly how the duplicate-medication issue was first noticed). Added a real edit flow: a pencil icon on the medication detail screen pre-fills the same wizard, and `MedicationRepository.updateMedication()` updates the row in place, regenerates only the *pending* dose events against the edited schedule (already-taken doses and the pill count they consumed are preserved as history), and reschedules alarms.

### Dashboard hero card could get permanently stuck on a stale missed dose (found during physical-device manual testing, 2026-08-13)
`nextDose` selection picked the first dose satisfying `status == 'pending' && (now - scheduledTime) < 60 minutes` -- a flat, hardcoded 60-minute check that predates the proportional window sizes above (as small as 5-30 min). A dose well past its own (now much smaller) window could still satisfy the loose 60-minute check, so it kept winning over a later, more relevant dose -- including one that had since become due and been confirmed taken. Reproduced live: a 5:45 dose stayed pinned on the hero card as "Missed" even after a separate 6:45 dose was added, became due, and was marked taken; the 6:45 dose never appeared on the card at any point. Replaced with `_selectNextDose()` in `dashboard_screen.dart`: prefers the earliest pending dose currently within its *own* medication's window, then the soonest upcoming pending dose, then the most recently-overdue pending dose, then any dose at all.

### Notification window/timing model was unrealistic and didn't scale with dosing frequency
The on-time window was a flat per-schedule-type constant (120 min for once-daily, 60 min default) with no relationship to how far apart doses actually were — a once-daily dose had a window open 2 hours before and staying open until 2 hours after (4 hours total), while a "4 times a day" (every-6-hours) schedule got a proportionally huge window relative to its own dosing interval. There was also no "coming up soon" reminder shortly before the due time, and the "closing soon" notification wasn't cancelled if the dose was already confirmed taken, so a stale "hurry up"/"missed" notification could still show up after the fact. Redesigned (2026-08-13) around `lib/shared/schedule_window.dart`: window size and a new "coming up" reminder offset now both scale off the actual gap between doses (`scheduleCycleMinutes`), capped at 30/10 minutes respectively so a once-daily dose doesn't get an unrealistic multi-hour window. Three notifications per dose: window opens, coming up (inside the window, close to the due time), and missed (fires when the window closes, cancelled via `AlarmService.cancelDoseAlarms` if the dose is confirmed taken first). Alarm ids now derive from the dose's own database id (`doseId*4 + notifIndex`) instead of a running counter seeded from `medicationId*1000`, so each dose's notifications are individually cancellable and medications with many doses can no longer collide with the reserved snooze-id range.

### Notification action button read awkwardly ("I took them")
Didn't match the dashboard's own "Take" button wording, and read oddly for a single dose. Changed to "Take" everywhere it appears: the three per-dose notifications, the snooze-reschedule notification, and the developer-screen test-notification button (`notification_service.dart`, `alarm_service.dart`).

## Found but not yet fixed (2026-08-13)

### Multiple medications sharing an exact dose time collapse into one dashboard dot
The hero ("next dose") card itself handles this correctly -- it lists each co-scheduled medication as its own row with its own taken/pending indicator. But the smaller horizontal time-dots row (`computeTimeDots` in `dashboard_logic.dart`) keys purely by formatted time-of-day string, so 3 medications at the same time share one dot. Once *any* of them is confirmed taken, that dot shows solid "taken" green and stays that way regardless of the other two's status (the code only guards against downgrading *away* from taken, not against a false-positive taken from a different medication at the same slot). Not reproduced live yet, found by code inspection while answering a question about same-time medications -- worth a real multi-med test before fixing.

### New medication with a start time already passed today generates a "phantom missed" dose
Confirmed via code trace, not yet fixed (discussion paused before a decision): if you add a medication today with e.g. "starting at 8:00am" after 8am has already passed, dose generation still creates today's 8:00am `DoseEvent` (the loop starts at midnight of the start date, no "is this already in the past" check) — it just never gets a notification scheduled (that check exists separately, in `AlarmService.scheduleMedicationAlarms`). Net effect: the dashboard shows an immediate "missed" dose for a dose the medication didn't even exist for at the time it was due. Proposed fix (not yet implemented): skip straight to the first future occurrence when generating a brand-new medication's doses, for all schedule types, rather than generating an already-dead slot for today.

### Duplicate `users`/`patients` rows possible on first launch
`ensureDefaultUserAndPatient()` checks "does a user row exist yet, if not create one" without a transaction/lock -- if called concurrently by two code paths during startup, both can see "no user yet" and both insert, leaving 2 rows instead of 1. Observed once (2 users, 2 patients) after a fresh install. Not investigated further since the rest of the app keys off whichever `patientId` was actually used for the active session's medications, so it hasn't caused a visible symptom -- but worth a fix (wrap in a transaction, or an `INSERT OR IGNORE`-style guard) if it starts causing problems.

### "Groups of 4" time-of-day bucket display -- designed, not built
Referenced from memory during this session and confirmed still true: `ROADMAP.md` already has this planned (Morning 5–11am / Afternoon 11am–5pm / Evening 5–9pm / Night 9pm–5am, reusing the dashboard's existing time-of-day theming boundaries), explicitly to make a multi-medication morning/day legible at a glance. Bucket boundaries agreed, nothing else designed or implemented yet. The same-time-dot-collapsing issue above is a related but distinct problem (exact-time collapsing vs. broader time-of-day grouping) -- worth considering together if either gets built.

## Housekeeping-tier (not urgent)
- `go_router` installed but unused (left in place per decision, revisit later).
- No shared component library — 5+ screens duplicate the same "icon + title + subtitle + chevron" card pattern.
- 27 pre-existing `flutter analyze` info-level notices (deprecated `value:` param, missing curly braces, `use_build_context_synchronously`) — out of scope of housekeeping pass, not yet addressed.

## Test-writing gotchas (for future reference, not app bugs)
- Default Flutter test surface (800×600) is too short for `ListView`-heavy screens — off-screen content in a non-`.builder` `ListView` isn't built into the element tree, so `find.text()` silently finds nothing below the fold. Use `tester.binding.setSurfaceSize` for a taller surface when needed.
- `find.widgetWithIcon(FilledButton, ...)` doesn't match buttons built via the `FilledButton.icon(...)` factory — Flutter's type-based finders use exact-type equality, not subtype checks.