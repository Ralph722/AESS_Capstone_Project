# Phase 4 — Mandatory onboarding wizard

## What shipped

After registration or alumni login, users are routed through **`AlumniHomeGate`**, which checks `users.onboardingComplete` before showing `MainNavigation`.

### Four steps (`AlumniOnboardingScreen`)

1. **Welcome** — explains demographic + employment setup  
2. **Demographics** — required ID Tracer fields (course codes: BSIT, BFPT, BTLED-*)  
3. **Employment** — employment tracer (employed / unemployed)  
4. **Complete** — sets `onboardingComplete: true` and enters the portal  

### Grandfathering

Existing alumni who already have `tracerProfileComplete` and an `employment_records` row are auto-marked complete on first gate check (no forced re-entry).

### Files

| File | Role |
|------|------|
| `lib/services/onboarding_service.dart` | Completion check + flag |
| `lib/screens/alumni_home_gate.dart` | Routes onboarding vs main app |
| `lib/screens/alumni_onboarding_screen.dart` | Wizard UI |
| `lib/screens/login_screen.dart` | Alumni → gate |
| `lib/screens/register_screen.dart` | Post-register → gate |

## Firestore fields

- `users.onboardingComplete` (bool)  
- `users.onboardingCompletedAt` (timestamp, set on finish)  

## Next: Phase 5

Merge ID Tracer + demographic on one user screen; remove verification UI; keep fields editable.
