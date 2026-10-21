# AESS Alumni User Application — Full Overview

Status: living overview of the **alumni (USER) Flutter app** only.  
Admin portal, DSS analytics, and staff tools are out of scope except where alumni touch the same backend.

Recorded: 2026-10-18.

---

## 1. What this app is

AESS (Alumni Engagement Support System) is the mobile/web portal for **registered USTP alumni**. Alumni sign in, complete onboarding, then use a six-tab shell for home, events, graduate tracer (CHED GTS), jobs, community, and profile.

| Layer | Technology |
|--------|------------|
| Client | Flutter (Android, iOS, Chrome/web) |
| Backend | Supabase (Auth, Postgres, Realtime, Storage, Edge Functions / RPCs) |
| Push | FCM / web push (`PushService`) |
| Branding | USTP navy & gold (`PortalTheme`) |

---

## 2. How someone gets in (auth & onboarding)

```
App start
  ├─ URL ?verify=<token>  →  Public alumni-card verify (no login)
  └─ AuthGate
       ├─ Not signed in     →  Login
       ├─ Admin role        →  Admin dashboard (not this overview)
       ├─ Alumni, incomplete onboarding  →  Onboarding wizard
       └─ Alumni ready      →  MainNavigation (6 tabs)
```

### Screens

| Screen | What it does |
|--------|----------------|
| **Login** | Email + password; optional “Remember me”; links to Register and Forgot password |
| **Register** | Roster eligibility check → create account → email verification code → home gate |
| **Forgot password** | Email verification code → set new password → back through AuthGate |
| **Onboarding** | Guided GTS-style profile (about you, contacts, education/work, optional photo, review) |

### Rules that matter

- Only alumni linked on the official roster (`alumni_members`) and not deactivated can use the user portal.
- Role comes from `users.role` (`user` vs `admin`).
- Onboarding must finish (`users.onboarding_complete`) before the main tabs appear.
- Password strength and email OTP policies are enforced in-app.

**Key files:** `lib/features/auth/presentation/`, `lib/features/onboarding/presentation/`, `lib/main.dart`

---

## 3. Main shell (navigation)

Six tabs (`PortalTabs` in `MainNavigation`):

| # | Tab | Root screen | Typical nested screens |
|---|-----|-------------|-------------------------|
| 0 | **Home** | Home dashboard | Announcements, My Surveys, survey take, forum topic, digital card, notifications panel |
| 1 | **Events** | Events list/calendar | Event detail, comments, RSVP, local reminders |
| 2 | **Tracer** | Graduate Tracer | CHED form, history, past responses, reminder sheet, link to My Surveys |
| 3 | **Jobs** | Job board | Job detail sheet, favorites, “Interested” |
| 4 | **Community** | Forum | Compose topic, topic thread, edit |
| 5 | **Profile** | Profile hub | Profile information, My Surveys, support messages, notifications, feedback, change password |

### Shell behavior

- **Phone:** frosted bottom navigation pill; content scrolls under it with bottom clearance.
- **Wide / desktop:** navigation rail instead of the bottom pill.
- Tabs are lazy-loaded (`IndexedStack` of visited tabs only).
- Deep links from push, local reminders, and Home open the right tab or push a screen.

**Key file:** `lib/features/shell/presentation/main_navigation.dart`

---

## 4. Features by area

### 4.1 Home

**Purpose:** Daily landing — identity, things that need action, and shortcuts into the rest of the app.

| Piece | Functionality |
|-------|----------------|
| Identity hero | Greeting, name, program, batch; tap opens **digital alumni card** |
| Needs attention | Open Tracer and/or assigned classic surveys; optional “due soon” styling and reminder dialog |
| Stat cards | Counts for announcements, community posts today, upcoming events (tappable) |
| Upcoming events | Carousel / cards into Events |
| Community preview | Recent forum topics |
| Important dates calendar | Events, survey/tracer deadlines, job deadlines |
| Notification bell | Unread count → notification panel |

**How it works:** Home loads sections in parallel (profile, events, announcements, community, survey attention, jobs for calendar). Stat card skeletons clear when their own data is ready; events archiving does not block the list.

**Key files:** `lib/features/home/presentation/home_page.dart`, `home_widgets.dart`

---

### 4.2 Graduate Tracer (CHED GTS)

**Purpose:** Official Commission on Higher Education Graduate Tracer Study — **only** the built-in CHED form on this tab.

| Screen / flow | Functionality |
|---------------|----------------|
| Tracer status | Not started / in progress / scheduled / completed |
| Start or continue | Opens CHED multi-section form (`ChedGtsTakeScreen`) |
| Draft & submit | Saves answers; submit syncs selected fields back to the live profile |
| Finish reminder | Optional date reminder + hourly follow-ups that day (until 9 PM, capped) |
| History | Past tracer waves / responses (read-only after submit) |
| Other surveys | Link to **My Surveys** when classic surveys are also assigned |

**How it works**

1. Assignments live in `survey_assignments`; CHED surveys are flagged as built-in GTS.
2. Prefill comes from the alumni’s live GTS profile (`users` / tracer profile).
3. On submit, answers are stored and profile fields (demographics, employment, etc.) are merged back.
4. Contact fields (email / mobile) that change in the tracer require **verification** before they stick.
5. Only the current (newest) open CHED assignment is treated as the active tracer (`CurrentTracer`).

**Not on this tab:** Office-assigned custom surveys — those are under **My Surveys**.

**Key files:** `lib/features/alumni/tracer/presentation/`, `lib/features/surveys/ched_gts/`

---

### 4.3 My Surveys (classic / assigned)

**Purpose:** Non-CHED surveys the alumni office assigns to you.

| Screen | Functionality |
|--------|----------------|
| My Surveys list | Sections: needs action, in progress, scheduled, closed, completed |
| Take / continue / view | Dynamic form from survey definition; draft and submit |

**Entry points:** Profile → My Surveys; Home attention / calendar; Tracer “other assigned surveys”.

**Rules:** Respect open/close schedule; CHED built-ins are hidden here; submitted responses are not editable.

**Key files:** `lib/features/surveys/presentation/user_surveys_page.dart`, `user_survey_take_page.dart`

---

### 4.4 Events

**Purpose:** Discover alumni events, RSVP, discuss, and get reminded.

| Capability | Details |
|------------|---------|
| Browse | Search, filters (All, This Week, Month, Newest, Going), list or month calendar |
| Detail | Theme, date/time, venue, description, cover |
| RSVP | Mark Going (and related states via RSVP service) |
| Comments | Threaded comments / replies |
| Reminders | Local device notifications when Going (mobile; limited on web) |

**Data:** `events`, `event_rsvps`, `event_comments` / replies via Event services.

**Key files:** `lib/features/events/presentation/events_page.dart`, related sheets/services

---

### 4.5 Jobs

**Purpose:** Browse openings posted for alumni.

| Capability | Details |
|------------|---------|
| Browse | Active jobs; search and filters |
| Saved | Favorites list |
| Recommended | Recommendation helper when applicable |
| Detail | Full posting sheet |
| Interest | “Interested” toggle for the office |

**Data:** job postings, `favorite_jobs`, `job_interests`.

**Key file:** `lib/features/jobs/presentation/job_posting_page.dart`

---

### 4.6 Announcements

**Purpose:** Official notices from the alumni office (targeted by program/batch where configured).

| Capability | Details |
|------------|---------|
| List | Important vs regular; search and date filters |
| Expand | Read full body in-place |

Opened from Home (and notification deep links). Not a main tab by itself.

**Key file:** `lib/features/announcements/presentation/user_announcements_page.dart`

---

### 4.7 Community (Forum)

**Purpose:** Alumni discussion board.

| Capability | Details |
|------------|---------|
| Topic list | Search; filters (Recent, Pinned, My Topics, Solved, Unanswered, Bookmarked, Announcements, …) |
| Compose | New topic |
| Thread | Replies, @mentions, report, bookmark; pin/lock when allowed |
| Edit | Own topic edits where permitted |

**Key files:** `lib/features/community/presentation/user_community_page.dart`, `lib/features/forum/presentation/`

---

### 4.8 Support messages

**Purpose:** Direct chat with the alumni office (not peer-to-peer DMs).

| Capability | Details |
|------------|---------|
| Thread | Text and image messages |
| Status | Delivery / retry for failed sends; reactions where supported |

**Entry:** Profile → Support messages; also notification deep links.

**Key file:** `lib/features/messages/presentation/user_messages_page.dart`

---

### 4.9 Notifications

**Purpose:** In-app inbox and optional push for office activity.

| Type (examples) | Typical destination |
|-----------------|---------------------|
| Event | Events tab / event |
| Job | Jobs |
| Survey / tracer | Tracer or My Surveys |
| Announcement | Announcements |
| Message | Support messages |
| Forum | Topic |
| Feedback | Feedback detail |
| System | Profile or generic |

**Also:** Notification preferences (per-type in-app / push toggles). Home shows a compact panel; Profile has the full list + settings.

**Key files:** `lib/features/notifications/`

---

### 4.10 Profile & account

| Screen / action | Functionality |
|-----------------|---------------|
| **Profile hub** | Digital card preview; account menu rows |
| **Profile information** | Edit live GTS demographics, education, employment, photo |
| **Change password** | Current + new password with policy meter |
| **My Surveys** | Same list as above |
| **Support messages** | Office chat |
| **Notifications** | Inbox + preferences |
| **Feedback** | Submit and track tickets (bug, feature, general, …) |
| **Sign out** | Ends session |

**Contact changes:** Changing email or mobile opens verification (one-time code). A verified email can become the **sign-in** email. Unverified changes are not kept.

**Locked / office-managed fields (examples):** name (verified at registration; only changeable via the Tracer marriage flow — see `docs/marriage-name-change-plan.md`); year graduated once set; program from roster; login email shown as sign-in identity.

**Key files:** `lib/features/alumni/profile/presentation/`, `lib/features/contact_verification/`

---

### 4.11 Digital alumni card

**Purpose:** Show a verifiable digital ID when the physical card is not available.

| Mode | Behavior |
|------|----------|
| Live | Front/back card UI; status “Verified active alumnus”; issue short-lived QR / backup code |
| Offline | Last cached card can still display; QR verification needs network |
| Public verify | Anyone with `?verify=<token>` (or staff enter code) hits verify RPC — no alumni login required |

**Key files:** `lib/features/alumni/card/presentation/`, `AlumniCardService`, `AlumniCardCache`

---

### 4.12 Feedback

**Purpose:** Report bugs, request features, or send general notes to the office.

Flow: list → submit (category + details) → detail with status (submitted, in review, resolved, closed).

**Key files:** `lib/features/feedback/presentation/` (user screens)

---

## 5. Cross-cutting systems

### Contact verification

Used from **Profile information** and **Tracer** when email/mobile change. Codes go out by email (and mobile mock/demo until SMS is live). Recent sign-in may be required before login-email changes.

### Reminders

| Kind | Mechanism |
|------|-----------|
| Event “Going” | Local device notifications (`ReminderService`) |
| Tracer finish | Server-backed tracer reminders + optional hourly same-day nudges |
| Home attention | Soft dialog / snooze (`SurveyAttentionReminder`) |

### Push & deep links

`PushService` registers the device after sign-in. Taps route through `NotificationRouter` into the correct tab or screen. Shell signals `alumniShellReady` so cold-start taps wait for navigation.

### Shared UX

- **PortalTheme** — colors, type, buttons, motion  
- **Skeletons** — loading placeholders matched to real layouts  
- **PortalFrostedPill** — bottom nav  
- **Empty / error states** — retry patterns  
- **Breakpoints** — phone vs rail layout  

---

## 6. Data model (alumni-facing, simplified)

| Concept | Typical storage |
|---------|-----------------|
| Account | Supabase Auth + `users` |
| Roster link | `alumni_members` (official school record) |
| Live GTS profile | Columns on `users` (and mirrored demographics on roster where allowed) |
| Surveys / Tracer | `surveys`, `survey_assignments`, `survey_responses` |
| Events | `events`, `event_rsvps`, `event_comments` |
| Jobs | Job postings + `favorite_jobs`, `job_interests` |
| Forum | Topics / posts (forum tables) |
| Messages | Message threads with office |
| Notifications | Notification rows + preference rows |
| Alumni card | Tokens via RPC; optional local cache |
| Audit | `audit_logs` (admin-visible; coarse profile updates today) |

Security is enforced with RLS and DB guards (e.g. roster name locked for alumni self-edit; protected columns on `users`).

---

## 7. Screen map (quick reference)

```
Login / Register / Forgot password
        ↓
   Onboarding (if needed)
        ↓
   MainNavigation
   ├── Home
   │     ├── Digital card dialog
   │     ├── Announcements
   │     ├── My Surveys → Take survey
   │     ├── Forum topic (from carousel)
   │     └── Notifications panel
   ├── Events → Detail / Comments / RSVP
   ├── Tracer → CHED form / History / Reminder / My Surveys
   ├── Jobs → Detail / Favorite / Interest
   ├── Community → Compose / Topic thread
   └── Profile
         ├── Profile information (+ contact verify)
         ├── My Surveys
         ├── Support messages
         ├── Notifications + preferences
         ├── Feedback list / submit / detail
         ├── Change password
         └── Sign out

Public: /?verify=<token> → Alumni card verification
```

---

## 8. Related docs in this repo

| Doc | Topic |
|-----|--------|
| [`full-system-overview.md`](full-system-overview.md) | Broader system (incl. admin) |
| [`digital-alumni-card-plan.md`](digital-alumni-card-plan.md) | Card design & verify |
| [`contact-verification-plan.md`](contact-verification-plan.md) | Email/mobile codes & login email |
| [`marriage-name-change-plan.md`](marriage-name-change-plan.md) | Name lock / marriage rename (implemented 2026-10-21) |
| [`deferred-plans.md`](deferred-plans.md) | Parked product decisions |
| [`events-features-overview.md`](events-features-overview.md) | Events depth |
| [`jobs-feature-overview.md`](jobs-feature-overview.md) | Jobs depth |
| [`archive/USER_PORTAL_GUIDE.md`](archive/USER_PORTAL_GUIDE.md) | Older user guide (may be stale) |

---

## 9. What this overview intentionally excludes

- Admin dashboard modules (directory, survey builder, reports, DSS, etc.)
- Database migration runbooks and secret management
- Step-by-step developer setup (see project README / Supabase docs)

For implementation detail on a single feature, start from the **Key files** under that section and the matching service under `lib/features/*/data/`.
