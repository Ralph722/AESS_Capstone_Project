# Phase 6 — Polish, indexes, docs & QA

## What shipped

### Documentation
- **[system-overview.md](system-overview.md)** updated for roster registration, onboarding gate, unified Alumni Tracer, and admin roster directory.
- **[alumni-roster-complete.md](alumni-roster-complete.md)** — index of all migration phases (1–6).

### Firestore indexes
Deployed composite indexes for:
- `alumni_members` — `studentId` + `course` (legacy admin lookups)
- `audit_logs` — `userId` + `timestamp` (member activity tab)
- `audit_logs` — `resource` + `resourceId` + `timestamp` (roster audit)
- `employment_records` — `verificationStatus` + `submittedAt` (admin filtered list)

```powershell
firebase deploy --only firestore:indexes
```

### UI copy
- Alumni bottom nav label: **Tracer**
- Home quick link: **Alumni Tracer**
- Onboarding completion text points to Tracer tab

### QA checklist (manual)

| # | Test | Expected |
|---|------|----------|
| 1 | Admin: add roster row (BSIT + ID) | Appears in directory |
| 2 | Register new alumni (name + course + ID match) | Success → onboarding wizard |
| 3 | Onboarding step 2 Save | No permission error; advances |
| 4 | Onboarding step 3 employment + finish | `onboardingComplete: true`; Home loads |
| 5 | Alumni: Tracer → Demographics save | `users` + roster sync; admin notification icon |
| 6 | Alumni: Tracer → Employment save | `employment_records` updated |
| 7 | Admin: View alumni → Profile / Employment / Activity tabs | Data visible |
| 8 | Admin: open view | Notification icon clears |
| 9 | Returning login (completed onboarding) | Skips wizard → Home |
| 10 | Admin login | Dashboard (not onboarding) |

### Deploy checklist (production)

```powershell
firebase deploy --only firestore:rules,firestore:indexes
flutter build web
firebase deploy --only hosting
```

### Optional (Blaze plan)
- Cloud Functions: `validateAlumniEligibility`, `linkAlumniRegistration` — see [alumni-roster-phase2.md](alumni-roster-phase2.md)

## Migration complete

Phases **1–6** of the official roster / Grad Tracker alignment are done. Future work (not in scope): admin ticket queue, CHED survey packs, deeper analytics exports.
