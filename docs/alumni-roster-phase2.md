# Phase 2 — Gated registration (shipped)

## What changed

Alumni can only register if they appear on the **official roster** (`alumni_members`) with matching:

- **Full name** (exact, after normalizing spaces and case)
- **Course** (BSIT, BFPT, BTLED-IA, BTLED-ICT, BTLED-HE)
- **ID number**

### Registration flow

1. Full name, course, ID number, Gmail  
2. **Verify alumni status** → Cloud Function `validateAlumniEligibility`  
3. If not on roster → dialog: *Not an official alumni member*  
4. If valid → password + confirm → **Send OTP** → verify OTP  
5. Create Firebase Auth account → Cloud Function `linkAlumniRegistration`  
6. Links `alumni_members` (`authUid`, `isRegisteredUser`) and creates `users/{uid}`

## Firebase plan: Spark (free) vs Blaze

**Registration works on the free Spark plan** using Firestore rules + direct document lookup (no Cloud Functions required).

Cloud Functions need the **Blaze (pay-as-you-go)** plan. Blaze has a free monthly quota; you are only charged if you exceed it. Upgrade only if you want server-side validation later.

### Deploy Firestore rules (required on Spark)

```powershell
firebase deploy --only firestore:rules
```

### Optional: Cloud Functions (Blaze only)

```powershell
cd functions
npm install
cd ..
firebase deploy --only functions
```

| Name | Purpose |
|------|---------|
| `validateAlumniEligibility` | Server-side roster check |
| `linkAlumniRegistration` | Server-side link after sign-up |

The app uses Firestore first and calls functions only when deployed.

### Roster document IDs

New roster entries use ID format `{COURSE}_{IDNUMBER}` (e.g. `BSIT_2020-12345`) so registration can verify without listing the whole collection. **Re-add** any old roster rows created before Phase 2 if registration cannot find them.

## Flutter dependency

`cloud_functions` added to `pubspec.yaml`. Run:

```powershell
flutter pub get
```

## Testing

1. Admin adds a test row in **Alumni Directory** (name, course, ID).  
2. Register with **exact** same details and a Gmail you can read.  
3. Wrong name or ID → blocked with official alumni message.  
4. After success, admin directory shows **Registered** for that row.

## Next: Phase 3

Enhanced admin directory (activity tab, profile updates notification).
