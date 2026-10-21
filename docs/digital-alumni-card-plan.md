# Digital Alumni Card — Audit and Implementation Plan

Status: **Complete through Phase 4 (2026-10-16).** Card UI, tokens/QR, staff
verify page, offline cache, shine, and a11y polish are in. Any further
database change must be reported and approved before it is applied.

Mockup: [`mockups/digital-alumni-card.html`](mockups/digital-alumni-card.html)
(open in a browser; tap the card or "Show back" to flip it). Names, ID, email
and campus in the mockup are sample data.

## Request (from the adviser)

A digital alumni card for verification when an alumnus forgets the physical
card at events or the school entrance. The alumnus signs in to the user
portal, taps the identity card on Home, and the card opens in a pop-up dialog
where it can be flipped between front and back.

## Audit

### What exists

| Item | Where | Notes |
|---|---|---|
| Home identity card | `HomeAlumniIdentityHero` in `lib/features/home/widgets/home_widgets.dart`, used by `_identityAndAttention` in `home_page.dart` | Shows first name, program, batch and photo. Tapping it opens the digital alumni card dialog. |
| Card data | `alumni_members` (`AlumniMember` model) and `users` | Full name, course, student ID, batch year, year graduated, photo, registered and deactivated flags. No new profile fields needed. |
| Profile load on Home | `_loadUserProfile` in `home_page.dart` | Reads `users.display_name`, `profile_image_base64` and the tracer profile (program, batch / year graduated). |
| Branding | `UstpColors`, `PortalTheme`, `assets/images/aess_emblem.png` | Navy `#1A1851`, gold `#FCB315`. |

### What is missing

- No QR package (`qr_flutter` or similar) in `pubspec.yaml`.
- No verification-token table or verify function in the database.
- No URL routing (no `routes`, `onGenerateRoute` or `go_router`), so a staff
  verification page needs a small check of the start-up URL.

### Risks to design for

- **Fakes.** A screenshot or edited image can look like a real card. Counter
  with a live ticking clock, a moving shine on the front, and a QR code that
  refreshes every 60 seconds and is checked against the database.
- **Eligibility.** Only registered, roster-matched, active alumni get a card.
  Unmatched or deactivated accounts see a message instead.
- **Privacy.** No birthday, address, phone number or civil status on the card.
- **No internet at the gate.** Phase 4 can show a saved copy marked "Offline";
  its QR code cannot be verified offline.

## What the card holds

### Front (navy, ID-card proportions 85.6 × 54 mm, ratio 1.586)

- AESS emblem, "USTP ALUMNI", "Alumni Engagement and Support System", gold
  "DIGITAL ID" label
- Profile photo with gold border (initials if no photo)
- Full name and program
- Student ID, batch, year graduated
- Green "Verified active alumnus" badge, checked live against the roster
- Live date and time with seconds, plus a moving shine, so a screenshot is
  easy to spot

### Back (off-white with a navy band)

- "SCAN TO VERIFY" band
- QR code refreshing every 60 seconds, a 6-character backup code (for example
  `K7Q-4MZ`) and a "Refreshes in 0:42" countdown
- Email, member since, card issued date, campus
- Notice: non-transferable; valid only while shown live in the app; staff may
  ask for a government ID; report misuse to the USTP Alumni Office

## Implementation plan

### Phase 1 — Card and pop-up (no database changes) ✅

- `AlumniDigitalCard` widget (front and back) and a `showAlumniCardDialog`
  pop-up. Flip by tapping the card or the "Show back" / "Show front" button,
  with a 3D flip animation (`Transform` with `rotateY` and perspective).
- Load card details from the roster for the signed-in alumnus.
- States: loading; "Your card will be available once the Alumni Office
  confirms your record" (unmatched); deactivated.
- Home identity card opens the alumni card and gets a small "Tap to show your
  alumni card" hint. Profile stays reachable from the avatar and the Profile
  tab.
- Widget tests (`test/alumni_card/alumni_card_test.dart`).
- Code: `lib/features/alumni/card/` (models, service, card, dialog);
  Home wired in `home_page.dart`. QR on the back is a placeholder until Phase 2.

### Phase 2 — Verification codes (one migration, one package) ✅

- Table `alumni_card_tokens` (token, short code, member id, expires_at).
- `issue_alumni_card_token()`: signed-in, active, roster-matched alumni only;
  returns a token and short code that expire after 60 seconds.
- `verify_alumni_card(token_or_code)`: callable without login; returns only
  name, photo, program, batch and status; expired or unknown codes return
  "not valid". Old rows cleaned up.
- Add `qr_flutter` (web-compatible). Show the QR code, backup code and
  countdown on the back of the card.
- Migration: `supabase/migrations/20261016050000_alumni_card_tokens.sql`
  (must be applied to the project DB). Client:
  `AlumniCardTokenService`, QR on `_CardBack`. Staff result UI is Phase 3.

### Phase 3 — Verification page for staff ✅

- Staff scan the QR code with any phone camera, which opens the app's web
  address with the code attached (for example `<app-url>/?verify=<token>`).
  The app shows a result screen without login: green "Verified" with photo
  and details, or red "Expired / Not valid".
- Optional "Verify alumni card" box in the admin portal for typing the backup
  code.
- `AlumniCardVerifyLaunch` reads `?verify=` in `main.dart` before AuthGate.
  Public UI: `AlumniCardVerifyPage`. Admin: **Verify card** on the dashboard
  header → `showAlumniCardVerifyDialog`.

### Phase 4 — Polish ✅

- Offline saved copy of the card, the moving shine animation, accessibility
  (screen-reader labels, larger text), documentation.
- Cache: `AlumniCardCache` (SharedPreferences). On network failure the dialog
  shows a saved copy marked **OFFLINE**; QR is not issued.
- Shine: looping gold/white sweep on the front; respects reduce-motion.
- Text scales with system font size (capped at 1.35×). Semantics on flip,
  photo, meta rows, and QR.

## How it works (shipped)

1. Alumnus opens Home → taps identity → dialog loads roster card (and caches it).
2. Front shows live clock + shine; back issues a 60s token and QR (`/?verify=`).
3. Staff camera opens the public verify page (no login), or admin uses
   **Verify card** and types the backup code.
4. Without network, the last cached card still opens as an offline identity
   copy; staff cannot verify the QR until the alumnus is online again.

## Default choices (confirm before Phase 1)

| Topic | Default | Open question |
|---|---|---|
| ID number on the card | Student ID | Does the physical USTP alumni card have its own alumni number? If so, add a field for it. |
| Home card tap | Opens the alumni card; Profile via avatar and Profile tab | — |
| QR verification | Included (Phases 2 and 3) | Without it the card is visual only, which staff can't fully trust. |
| Email on the back | Shown | Remove for a more minimal card? |
| Campus line | Shown | Correct campus name, or drop the line ("USTP Cagayan de Oro" in the mockup is a placeholder). |

Working mode when resumed: implement phase by phase and check in after each.
