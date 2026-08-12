# MediTrack — Working Rules

## Process
1. All commits are made by the user (Josh), never auto-committed by Claude Code.
2. No direct commits to `main` — use feature/fix branches.
3. One task = one branch = one focused set of commits (don't mix a bugfix with a new feature).
4. Planning happens in chat with Claude (the "architect"); execution happens in Claude Code (the "builder").
5. For anything touching data models, storage, or navigation structure: explain the plan before writing code.
6. Before starting a new feature, the app should build and run cleanly.
7. New dependencies in pubspec.yaml must be flagged and agreed before adding — especially anything touching storage, notifications, or backend/cloud, given this is a medication app.
8. Any change touching a screen's layout gets a visual check (screenshot or live glance) before commit, not just a code-diff review.

## Design & UX
- Material 3, single blue seed color (0xFF2196F3) — no ad-hoc color systems.
- Friendly, approachable tone — emoji-prefixed labels for medication forms, warm not clinical.
- Permissive UX: never block navigation on incomplete/invalid input; degrade gracefully (e.g. empty name → "Unnamed medication") rather than erroring.
- No shared design-token file exists yet for spacing/color — until one exists, match the nearest existing local pattern rather than inventing new conventions.
- Before extracting a shared component, wait until a 3rd/4th screen duplicates the same pattern (currently: 5 screens reimplement a near-identical "icon + title + subtitle + chevron" card — flagged, not yet extracted).

## Testing
- Tests should express CORRECT behavior, even if that means they currently fail — a failing test is a documented bug, not an error to silence.
- Test order: unit (business logic) → widget (screen rendering) → integration (full user flows).