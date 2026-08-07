# Phase 5 — Unified Alumni Tracer screen

## What shipped

### One screen for alumni

**Alumni Tracer** (`IdTracerScreen`) has two tabs:

| Tab | Content |
|-----|---------|
| **Demographics** | Full name, ID, course, batch, contact, address, gender, etc. → `users/{uid}` |
| **Employment** | Employed / unemployed tracer → `employment_records` |

- Bottom nav **Tracer** opens this screen (embedded, no back button).
- Profile → **Alumni Tracer** and Home tracer checklist open the same screen (with back button).
- **Verification status UI removed** for alumni (no pending/verified badges on employment view).
- Admin ID Tracer still supports verification workflows.

### Deprecated

- `TracerProfileScreen` redirects to `IdTracerScreen` (demographics tab) for any old links.

## Files

| File | Role |
|------|------|
| `lib/widgets/tracer/demographic_tracer_tab.dart` | Demographics form |
| `lib/screens/id_tracer_screen.dart` | Tab shell + employment form |
| `lib/screens/tracer_profile_screen.dart` | Thin redirect |

## Next: Phase 6

Polish, Firestore indexes, system docs update, QA pass.
