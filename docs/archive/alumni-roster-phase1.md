# Phase 1 — Official Alumni Roster (shipped)

## What changed

- **Admin → Alumni Directory** is now a single roster screen (no Registered / Manual tabs).
- Admins add members with **Full name**, **Course** (BSIT, BFPT, BTLED-IA, BTLED-ICT, BTLED-HE), and **ID number**.
- **Search**, **filters** (course, registration, activity 7/30/90 days, inactive), and **sort**.
- **Import / export Excel** (columns: Full Name, Course, ID Number).
- **Deactivate** or **delete** roster rows (both supported for registered alumni).
- Firestore rules: only **admins** can read the full roster (Phase 2 Cloud Function for registration validation).

## Files

| File | Role |
|------|------|
| `lib/core/course_constants.dart` | Program codes |
| `lib/models/alumni_member_model.dart` | Roster model |
| `lib/services/alumni_member_service.dart` | CRUD, filters, duplicate check |
| `lib/services/alumni_roster_import_service.dart` | Excel import |
| `lib/screens/admin/admin_alumni_directory_screen.dart` | Admin UI |

## Deploy rules

```bash
firebase deploy --only firestore:rules
```

## Next: Phase 2

- Registration whitelist (name + course + ID + Gmail)
- Cloud Function `validateAlumniEligibility`
- Link `authUid` on successful sign-up
