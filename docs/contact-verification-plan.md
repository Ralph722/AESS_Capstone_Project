# Contact verification (tracer Q3/Q5 and Profile information)

Alumni can change their email and mobile number in the CHED GTS tracer
(Q3, Q5) and in Profile information. A changed contact is saved only after a
one-time code is checked. A verified **email** also becomes the sign-in
email.

## Decisions

- **Verified email becomes the login email.** `users.contact_email` is
  verified with a code, then `apply_email` sets the Auth login email so they
  stay the same. A contact email equal to the login email counts as verified.
  Mobile numbers do not affect sign-in.
- **Verified:** Q3 email and Q5 mobile. Q4 telephone is not verified (often a
  landline).
- **Email codes** go out through the existing Gmail SMTP account. The code
  email says the address will become how you sign in; the old address gets a
  one-time "sign-in email was changed" notice.
- **Mobile codes** go out through Semaphore when `SMS_MODE=live` (or
  `semaphore`): `mobile_verification_method = 'sms'` and
  `mobile_verified_at` is set. Local/demo may use `SMS_MODE=mock` (on-screen
  `demoCode`, method `mock`, `mobile_verified_at` stays null). Unset/disabled
  returns `sms_unavailable`. Philippine mobiles only for live SMS.
- **Recent sign-in.** If the last sign-in was over 24 hours ago, the app asks
  for the current password before changing the login email. The server also
  refuses `apply_email` without a recent sign-in.
- **Revert rule:** only unverified changes are undone, and only when the
  alumnus leaves (closes the tracer or the Profile sheet). Moving back inside
  the tracer keeps them.
- **Profile information** uses a bottom sheet on every screen size (like the
  Help sheet) that opens on Save when a contact changed. Other fields save
  first. The form shows one Email field (also used to sign in).
- Unchanged contacts never need a code; older unverified numbers are not
  forced.

## Server pieces

| Piece | Where |
| --- | --- |
| Columns, code table, functions, guard | `supabase/migrations/20261016010000_contact_verification.sql` |
| Normaliser not callable by anon | `supabase/migrations/20261016020000_contact_normalize_grant.sql` |
| Direct contact writes closed, users-to-roster mirror | `supabase/migrations/20261016030000_contact_verification_enforce.sql` |
| Login email from verified contact | `supabase/migrations/20261016040000_login_email_from_contact.sql` |
| Send, check, apply_email | `supabase/functions/contact-verify/index.ts` |
| Database tests | `supabase/regression/phase19_contact_verification.sql`, `phase20_contact_enforcement.sql`, `phase21_login_email.sql` |
| Edge Function misuse tests | `supabase/regression/edge_functions.ps1` |

Flow: the app calls `contact-verify` with `action: "send"`, then
`action: "verify"` with the code. **Mobile** is saved with
`apply_verified_contact`. **Email** is saved with `action: "apply_email"`,
which changes Auth login, then `service_apply_verified_contact`. A
verification is valid for 30 minutes and can be used once.

Limits: 6-digit codes, 10 minute expiry, 5 wrong tries, 60 seconds between
codes, 5 codes per channel per hour. Codes are stored as an HMAC. An address
already used by another account returns `email_in_use` (409).

Function settings: `GMAIL_USER`, `GMAIL_APP_PASSWORD`, `GMAIL_SENDER_NAME`
(already set). For live SMS: `SEMAPHORE_API_KEY`, `SEMAPHORE_SENDER_NAME`,
`SMS_MODE=live`. Optional: `CONTACT_OTP_SECRET` (HMAC key; defaults to the
service role key). Use `SMS_MODE=mock` only for local/demo.

Deploy:

```
supabase db push
supabase functions deploy contact-verify
.\supabase\regression\run_all.ps1 -Edge
```

## Phases (contact verification)

1. Database and `contact-verify` function. **Done (2026-10-16).**
2. Tracer verify step. **Done (2026-10-16).** Shared pieces:
   `lib/features/contact_verification/`. Q3 prefills from the contact email;
   submit sync no longer copies Q3/Q5 directly.
3. Profile information sheet. **Done (2026-10-16).** Then enforce migration
   `20261016030000` (phase 19 32/32, phase 20 9/9).
4. Admin badges, accessibility, docs, QA. **Done (2026-10-16).**
   `ContactVerificationBadge`: Verified / Demo code / Not verified.
5. Live Semaphore SMS + optional onboarding “Confirm mobile” step (skip allowed).
   **Done (2026-10-26).**
6. Automated survey SMS (week-1 + closing-in-3-days) via `send-scheduled-sms`.
   **Done (2026-10-26).**

## Part 2: verified email becomes the login email

Decided 2026-10-16 instead of ID-number login. **Done (2026-10-16).**

1. Server (**applied**): migration `20261016040000_login_email_from_contact.sql`,
   function redeployed. Phase 19 32/32, phase 20 9/9, phase 21 12/12; Edge
   27/27. Auth sync updates `registered_email` and `email_address`;
   `contact_email_taken`; `service_apply_verified_contact`; alumni
   `apply_verified_contact` is mobile-only; `apply_email` + old-address
   notice + audit `LOGIN_EMAIL_CHANGE`.
2. App (**done**): `saveVerified` uses `apply_email` for email; password
   dialog when last sign-in is over 24 hours; tracer and Profile say "From
   now on, sign in with …"; Profile shows one Email field.
3. Docs and QA (**done**): deferred plans §3 and §7 closed; checklist below
   updated; wording reviewed (code email, old-address notice, Profile helper,
   tracer verify step).

## QA checklist

Alumnus (tracer):
- Change Q3 to a new Gmail: verify step appears; code email says it becomes
  the sign-in email; after Verify + Submit, dialog says "From now on, sign in
  with …"; old Gmail gets the change notice; new address signs in.
- Change Q3 to an email already used by another account: send fails with a
  clear message.
- If last sign-in was over 24 hours ago: password dialog before the email is
  saved.
- Change Q5: SMS arrives; Verify + Submit works; Profile shows verified
  mobile (not demo).
- Change a contact, close the tracer: leave dialog warns; old value comes
  back in the draft.
- Change nothing: no verify step.

Alumnus (Profile information):
- One Email field with "also how you sign in" helper.
- Edit address only: saves with no sheet.
- Edit email and address: address saves, sheet opens; after verify, snack
  says "From now on, sign in with …"; Leave without verifying keeps the old
  email.
- "Verify" on an older unverified number works without editing it.

Admin:
- Member details show Verified / Demo code / Not verified badges.
- After an email change, contact and login match (no separate login row).
- Admin edit to a number clears verification (Not verified).

Limits: sixth code in an hour, wrong code five times, resend before 60 s.
