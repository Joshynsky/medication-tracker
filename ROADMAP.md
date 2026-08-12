# MediTrack — Roadmap (not yet started, for reference only)

## Immediate priority (in progress)
1. Full test suite (unit → widget → integration) — Stage 2 of 3 in progress
2. Fix known bugs (see KNOWN_ISSUES.md) — after tests complete
3. Dogfood: use the app personally for 1-2 weeks before adding new scope

## Near-term candidates (after core is stable)
- Caregiver Mode (already stubbed in UI) — highest-leverage next feature; notify a family member on missed doses
- Adherence PDF/report export — data already computed for History calendar
- Refill reminders — quantity data already in schema
- Set up CI to run the test suite automatically on push/PR (suggested by Claude Code once the test suite existed — deferred to keep this session focused)

## Longer-term / exploratory
- Photo-based pill confirmation at dose-taking time
- Drug interaction / duplicate warnings (needs external data source)
- Wearable/voice reminders

## Positioning note
Global apps (Medisafe, MyTherapy) are available in Kenya but not localized to it. Gap identified: offline-first architecture (already true by default), low-data-usage design, and family/caregiver patterns suited to local care distribution — not "more features than Medisafe," but "fits local context better." Keep this in mind when designing future features (e.g. don't assume always-on connectivity when building Supabase sync); no urgent action needed now.