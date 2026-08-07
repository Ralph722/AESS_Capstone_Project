# Alumni roster migration — complete (Phases 1–6)

Official **USTP alumni roster** + gated registration + admin directory + onboarding + unified tracer.

## Phase index

| Phase | Doc | Summary |
|-------|-----|---------|
| 1 | [alumni-roster-phase1.md](alumni-roster-phase1.md) | Admin official roster CRUD, Excel import/export, filters |
| 2 | [alumni-roster-phase2.md](alumni-roster-phase2.md) | Gated registration (roster match + OTP) |
| 3 | [alumni-roster-phase3.md](alumni-roster-phase3.md) | Admin member detail (demographics, employment, activity) |
| 4 | [alumni-roster-phase4.md](alumni-roster-phase4.md) | Mandatory onboarding wizard |
| 5 | [alumni-roster-phase5.md](alumni-roster-phase5.md) | Unified Alumni Tracer (demographics + employment tabs) |
| 6 | [alumni-roster-phase6.md](alumni-roster-phase6.md) | Polish, indexes, QA, deploy checklist |

## Course codes (roster + registration)

`BSIT`, `BFPT`, `BTLED-IA`, `BTLED-ICT`, `BTLED-HE`

Roster document IDs: `{COURSE}_{STUDENTID}` (e.g. `BSIT_2023304877`)

## Key collections

| Collection | Purpose |
|------------|---------|
| `alumni_members` | Official roster + link to app user |
| `users` | App profile, `onboardingComplete`, tracer fields |
| `employment_records` | Employment tracer |
| `audit_logs` | Admin activity + user actions |

## Related docs

- [system-overview.md](system-overview.md) — full product overview
- [restore-admin-account.md](restore-admin-account.md) — recover admin after Auth wipe
- [grad-tracker-migration.md](grad-tracker-migration.md) — earlier tracer/survey work
