# MediTrack — Known Issues

## Bugs (confirmed via failing tests, test/unit/dashboard_logic_test.dart)

### 1. Multi-dose & custom schedules broken (architectural)
`getExpectedDoseTimesToday(Medication med)` only receives the `Medication` row, but per-day times, custom days, and interval hours actually live in the separate `ScheduleTimes` table, which this function never sees.
- `multiple_times` schedules only ever show 1 dose/day instead of several.
- `custom` day schedules ignore which days are actually configured.
- Real fix requires a signature change: pass in `ScheduleTimes`, not just `Medication`.

### 2. Cross-medication window bug
Dot-coloring logic reuses one medication's window size (`schedType`/`intervalH` from the "next dose" medication) for ALL medications' dots, instead of each dose using its own medication's schedule type. Can misjudge one medication's dose as on-time/missed using another medication's window.

### 3. Hardcoded interval in every_x_hours branch
`getExpectedDoseTimesToday`'s `every_x_hours` branch hardcodes `intervalH = 4` — never reads the medication's actual configured interval. Same root cause as #1 (data lives in `ScheduleTimes`, not `Medication`).

## Fixed (found during test-writing, not part of original scope)

### Timer resource leak in Dashboard and Add Medication wizard
`dashboard_screen.dart`'s `_tick()` rescheduled itself via an uncancelled `Future.delayed(30s, _tick)`, silently continuing to run in the background forever after the widget was disposed. Same pattern in `step_three_quantity.dart`'s 4-second helper-text delay. Both converted to cancellable `Timer` fields, properly cancelled in `dispose()`. Found only because widget-testing forced the lifecycle issue to surface — `flutter analyze` doesn't catch this pattern.

### History not refreshing after dose confirmation
`historyProvider` (a non-autoDispose FutureProvider) only recomputed when `medicationRepositoryProvider` was invalidated — which only happened after `saveMedication`. Confirming/snoozing a dose or deleting a medication goes through a separate `dashboardProvider`/`DashboardNotifier`, which never triggered a History refresh. Since `MainShell` keeps all tabs alive via `IndexedStack`, there's no tab-switch remount to mask it either — a real user confirming a dose and checking History would see stale numbers. Fixed in `lib/providers/dashboard_provider.dart`: `DashboardNotifier` now calls `ref.invalidate(historyProvider)` in `confirmDose`, `snoozeDose`, and `deleteMedication`.

### Duplicated, inconsistent window-size formula (RESOLVED)
Two independent copies of the "on-time window" calculation existed — dashboard used `÷5`, `alarm_service.dart` used `÷6`, and they disagreed. Consolidated into a single shared `scheduleWindowMinutes()` function in `lib/shared/schedule_window.dart`, using the `÷5` value as the source of truth (chosen deliberately as the more forgiving option, given real-world caregiver/multi-medication use cases where strict windows risk falsely flagging honest lateness as "missed"). `alarm_service.dart` now calls the shared function instead of its own copy. Per-medication configurable windows (e.g. stricter for time-critical medications) remains a known future improvement, not yet built.

## Housekeeping-tier (not urgent)
- `go_router` installed but unused (left in place per decision, revisit later).
- No shared component library — 5+ screens duplicate the same "icon + title + subtitle + chevron" card pattern.
- 27 pre-existing `flutter analyze` info-level notices (deprecated `value:` param, missing curly braces, `use_build_context_synchronously`) — out of scope of housekeeping pass, not yet addressed.

## Test-writing gotchas (for future reference, not app bugs)
- Default Flutter test surface (800×600) is too short for `ListView`-heavy screens — off-screen content in a non-`.builder` `ListView` isn't built into the element tree, so `find.text()` silently finds nothing below the fold. Use `tester.binding.setSurfaceSize` for a taller surface when needed.
- `find.widgetWithIcon(FilledButton, ...)` doesn't match buttons built via the `FilledButton.icon(...)` factory — Flutter's type-based finders use exact-type equality, not subtype checks.