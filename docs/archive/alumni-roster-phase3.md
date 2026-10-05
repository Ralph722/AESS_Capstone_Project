# Phase 3 — Admin alumni directory (detail view)

## What shipped

### Directory cards (existing, refined)

- Search, course filter, registration filter, activity filter (7 / 30 / 90 days + inactive), sort
- Cards: avatar, green border + **Active** badge when registered and active within the selected window
- **Not registered** chip for roster-only rows
- Orange notification icon when `hasProfileUpdates` is true
- Delete / deactivate / reactivate roster actions

### Full member view

Open **View** on a card → `AdminAlumniMemberDetailScreen` with tabs:

| Tab | Content |
|-----|---------|
| **Profile** | Demographics from `users/{uid}` (ID Tracer / `TracerProfile`) |
| **Employment** | `employment_records` for linked user |
| **Activity** | Merged audit logs (`userId` + roster `resourceId`) |

- Opening the view calls `markAdminViewed` → clears `hasProfileUpdates`, sets `adminViewedAt`
- Not-yet-registered alumni see roster snapshot + guidance text

### Profile update notifications

When an alumni saves tracer profile or employment record:

- `alumni_members.hasProfileUpdates` → `true`
- Admin directory shows notification icon until they open the member view

### Activity tracking

On each visit to main app navigation (alumni role only):

- `alumni_members.lastActiveAt` and `users.lastActiveAt` updated
- Powers **Active** filters and green card border (7-day window on cards when filter is “all” or 7d)

## Files

| File | Role |
|------|------|
| `lib/screens/admin/admin_alumni_member_detail_screen.dart` | Detail UI |
| `lib/services/alumni_directory_detail_service.dart` | Load tracer + employment + audits |
| `lib/services/alumni_member_service.dart` | `markAdminViewed`, `flagProfileUpdatedForAuthUid`, `recordLastActiveForAuthUid` |
| `lib/services/user_profile_service.dart` | Sync roster without clearing notification flags |
| `lib/services/id_tracer_service.dart` | Flag roster on employment save |

## Deploy indexes (optional but recommended for Activity tab)

```powershell
firebase deploy --only firestore:indexes
```

If indexes are still building, the Activity tab may be empty until Firebase finishes; roster/user actions still work.

## Next: Phase 4

Mandatory onboarding wizard (4 steps) and gate `MainNavigation` until `users.onboardingComplete == true`.
