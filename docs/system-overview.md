# Alumni System — Features, Functions & Processes

> **Prefer the current doc:** [full-system-overview.md](full-system-overview.md)  
> This file is retained for history. Parts of it still describe the old **Firebase** stack; the live app uses **Supabase**.

**USTP Alumni / Graduate Tracer Platform**  
Readable overview from first launch through daily use (alumni and admin).

**Full rebuild reference (all screens, features, flows):** [full-system-overview.md](full-system-overview.md) · [complete-system-inventory.md](complete-system-inventory.md)

For the completed roster migration (Phases 1–6), see [alumni-roster-complete.md](alumni-roster-complete.md).  
For earlier tracer/survey work, see [grad-tracker-migration.md](grad-tracker-migration.md).

---

## 1. Purpose of the system

The Alumni System helps a college or university:

- Stay connected with **graduates (alumni)** across **all programs**
- Collect **graduate tracer study** data (demographics + employment)
- Run **custom surveys** with cohort targeting and follow-up reminders
- Share **announcements** and host an alumni **forum**
- Manage **events**, **job postings**, and **messages** in one place

It is built as a **Flutter** app (primarily **web** for admin) on **Firebase** (Authentication + Cloud Firestore).

---

## 2. User roles

| Role | How they get access | Main experience |
|------|---------------------|-----------------|
| **Alumni (user)** | Roster-verified registration or existing account | Bottom navigation: Home, Events, Messages, Jobs, **Tracer**, Profile |
| **Admin** | Account with `role: admin` in Firestore `users/{uid}` | Admin web dashboard (sidebar menu) |

There is **no hidden admin mode** on login. Role is read from Firestore after Firebase sign-in.

---

## 3. Technology overview

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Dart) |
| Authentication | Firebase Auth (email/password) |
| Database | Cloud Firestore |
| File / hosting | Firebase Hosting (web build) |
| Email (OTP, reminders) | EmailJS (optional; configured at build/run time) |
| Registration OTP | Email verification via EmailJS |

---

## 4. End-to-end process (start to finish)

### 4.1 First-time setup (developer / school IT)

1. Configure Firebase project (Auth, Firestore, Hosting).
2. Deploy Firestore security rules: `firebase deploy --only firestore:rules`
3. Run or build the app with EmailJS keys if email is needed (registration OTP, survey/announcement reminders).
4. Create at least one **admin** user in Firestore (`users/{uid}` with `role: admin`) or promote via your process.

### 4.2 New alumni registration (roster-gated)

1. User opens app → **Register**.
2. Enters **full name**, **course** (BSIT, BFPT, BTLED-*), **ID number**, and **Gmail**.
3. System verifies the person exists on the **official roster** (`alumni_members`) with exact name + course + ID match.
4. If not on roster → blocked with a clear message.
5. If valid → password + **OTP to email** (EmailJS).
6. User enters OTP → **Firebase Auth** account created; roster row linked (`authUid`, `isRegisteredUser`).
7. Firestore `users/{uid}` created with `role: user`, `onboardingComplete: false`.
8. User enters **mandatory onboarding** (demographics → employment → done).
9. After onboarding → **Home** (main navigation).

Works on **Firebase Spark** (free) using Firestore rules + direct roster doc lookup. Optional Cloud Functions on Blaze — see [alumni-roster-phase2.md](alumni-roster-phase2.md).

### 4.3 Returning alumni login

1. User opens **Login** → email + password.
2. Optional **Remember me** (saves email locally only, not password).
3. System checks Firestore role:
   - **Admin** → Admin dashboard
   - **User** → If `onboardingComplete` → Home; else **onboarding wizard**

### 4.4 Alumni daily journey (typical)

```text
Login
  → Home (dashboard, notifications, tracer progress, announcements, forum link)
  → Alumni Tracer tab (Demographics + Employment) — update tracer any time
  → Complete assigned Surveys (Home → Graduate Tracer Study / My Surveys)
  → Read Announcements, join Forum discussions
  → Browse Events, Jobs; message Admin
```

### 4.5 Admin daily journey (typical)

```text
Login (admin account)
  → Dashboard (counts, recent activity)
  → Alumni Directory (official roster: search, filters, import/export, member detail)
  → ID Tracer (review / verify employment records — admin only)
  → Surveys (create → publish → view responses → send reminders)
  → Announcements (draft → publish to cohorts)
  → Forum (moderate: lock, pin, delete)
  → Events, Jobs, Messages, Archives, Activity Logs, Reports
```

---

## 5. Alumni features (by tab)

### 5.1 Home

| Function | Description |
|----------|-------------|
| Welcome / profile summary | Shows user name and profile image when available |
| Notifications | Bell icon: events, jobs, messages, surveys, announcements |
| Graduate Tracer Study card | Progress: tracer profile %, employment submitted, pending surveys |
| Announcements preview | Latest targeted announcements; **See all** |
| Alumni Forum link | Opens public forum |
| Quick stats | Shortcuts to Events, Messages, Jobs |

### 5.2 Events

| Function | Description |
|----------|-------------|
| View active events | List/calendar of school/alumni events |
| Event details | Theme, date, venue, description |
| Comments | Comment on events (where enabled) |

### 5.3 Messages

| Function | Description |
|----------|-------------|
| Chat with admin | Send text and images to administration |
| Read admin replies | Thread-style messaging |

### 5.4 Jobs

| Function | Description |
|----------|-------------|
| Browse job postings | Posted by admin |
| View job details | Company, requirements, contact, etc. |
| Favorite jobs | Save jobs for later (per user) |

### 5.5 Alumni Tracer (demographics + employment)

Single screen with two tabs (bottom nav **Tracer**):

| Tab | Description |
|-----|-------------|
| **Demographics** | Graduate tracer profile: name, ID, course, batch, contact, address, gender, etc. → `users/{uid}` |
| **Employment** | Employed / unemployed tracer → `employment_records` |

Alumni can save and update either tab anytime. Verification status is **admin-only** (not shown to alumni).

### 5.6 Profile

| Function | Description |
|----------|-------------|
| Profile photo | Upload/update display image |
| Account info | Name and related profile fields |
| **Alumni Tracer** | Opens unified tracer screen (demographics tab) |
| **Surveys** | List of assigned surveys; open and submit |
| Completion % | Shown on Home tracer card when demographics incomplete |

---

## 6. Graduate tracer study (alumni)

Three pillars admins and accreditors care about:

| Step | Where | What happens |
|------|--------|----------------|
| 1. Demographics | Tracer → Demographics (or onboarding) | Required tracer fields; completion % updates |
| 2. Employment | Tracer → Employment (or onboarding) | Employment record; admin may verify in admin ID Tracer |
| 3. Surveys | Home / Profile → Surveys | Admin-published surveys assigned by program/batch |

**Survey taking (alumni):**

1. Admin publishes survey → assignment created per matched alumnus.
2. Alumni receives **in-app notification** (and email if admin enabled EmailJS on announcements; surveys notify on publish).
3. Alumni opens **My Surveys** → selects survey → answers questions (text, choice, scale, date).
4. Can save draft or **submit**; assignment status becomes completed.

---

## 7. Admin dashboard features (by menu)

| Menu | Main functions |
|------|----------------|
| **Dashboard** | Total events, users, jobs, messages; recent events and activity |
| **Events** | Create, edit, delete events; batch year, venue; notify users; comments |
| **Alumni Directory** | Official roster (`alumni_members`): add/edit/import, search, course & activity filters, member detail (profile + employment + audit), profile-update notifications |
| **Job Postings** | CRUD jobs; manage listings |
| **Messages** | Read/reply to alumni messages; unread counts |
| **Activity Logs** | Audit trail of user actions |
| **ID Tracer** | All employment records; filter; verify/reject; export (web) |
| **Reports & Analytics** | Tracer-focused KPIs, `fl_chart` (employment, industry, surveys, roster), survey question summaries, Excel/PDF including **Tracer & Survey KPIs** |
| **Surveys** | List surveys; create; edit questions; publish; re-assign; view responses |
| **Announcements** | List; create; edit; publish with targeting; archive |
| **Forum** | Moderate topics: view, lock/unlock, pin/unpin, delete |
| **Archives** | Archived events management |

---

## 8. Surveys — admin process (detailed)

| Step | Action |
|------|--------|
| 1 | **Surveys** → **New survey** (title/description) |
| 2 | Open editor → add **questions** (types: text, single/multi choice, scale, date) |
| 3 | Set **audience**: program chips and/or batch years (`2020-2027` range or `2024, 2025, 2026`) |
| 4 | Preview shows how many alumni **match** the range |
| 5 | **Publish** → assignments created; in-app notifications sent |
| 6 | **View responses** → Overview / **Pending** / **Submitted** |
| 7 | Send **reminders** (in-app, email, or both) to pending alumni |
| 8 | **Export CSV** of submitted responses (web) |
| 9 | Optional: **Re-assign** if cohort filters change |

**Assignment statuses:** not started → in progress → completed.

---

## 9. Announcements — admin process (detailed)

| Step | Action |
|------|--------|
| 1 | **Announcements** → **New** |
| 2 | Edit title, body, priority (normal / important) |
| 3 | Set program/batch audience (empty = all alumni) |
| 4 | Toggle **in-app notification** and/or **email** (EmailJS reminder template) |
| 5 | **Publish** → matched alumni notified; appears on Home feed |
| 6 | Can **archive** or **delete** later |

---

## 10. Forum — process (all alumni)

| Actor | Process |
|-------|---------|
| **Alumni** | Home → **Alumni Forum** → **New topic** or open thread → read/reply |
| **Alumni** | Can delete **own** topics |
| **Admin** | **Forum** menu → lock topic (no new replies), pin to top, delete any topic |

Posts are stored under `forum_topics/{id}/posts/{id}`.

---

## 11. Notifications

| Type | Trigger examples |
|------|------------------|
| Event | New event created |
| Job | New job posted |
| Message | New message from admin/alumni |
| Survey | Survey published; reminder sent |
| Announcement | Announcement published |
| System | General system notices |

Alumni open notifications from **Home**; tapping can navigate to the related screen (event, job, survey, announcement, etc.).

---

## 12. Email (EmailJS)

| Use | When |
|-----|------|
| Registration OTP | New account verification |
| Survey/announcement reminders | Admin sends from survey responses or on publish (announcements) |

Configured in `lib/config/emailjs_defaults.dart` (loaded on every run). Optional `--dart-define=EMAILJS_*` overrides for other environments.

In-app features work without email configuration.

---

## 13. Main data stored (Firestore)

| Collection / path | Used for |
|-------------------|----------|
| `users/{uid}` | Auth profile, role, tracer fields, notifications subcollection |
| `alumni_members/{id}` | Official roster (`{COURSE}_{STUDENTID}`); registration link; activity flags |
| `employment_records` | ID Tracer / employment tracer |
| `events` (+ `comments`) | Events |
| `jobs` | Job postings |
| `messages` | Alumni–admin messaging |
| `surveys`, `questions`, `responses` | Custom surveys |
| `survey_assignments` | Per-user survey assignment |
| `announcements` | Announcements |
| `forum_topics`, `posts` | Forum |
| `audit_logs` | Activity logging |

---

## 14. Security highlights

- Firebase **security rules** enforce role and ownership (e.g. users edit own tracer data; admins manage surveys and forum moderation).
- Employment **verification** fields cannot be changed by alumni after admin sets them.
- EmailJS IDs are in `lib/config/emailjs_defaults.dart` (EmailJS public key is safe to expose client-side).
- Alumni can **get** roster doc for registration; **update** own row when `authUid` matches (registration claim + tracer sync).
- Roster list/query is **admin-only**; alumni use direct doc ID (no collection queries).

---

## 15. Comparison to Grad Tracker scope (summary)

| Grad Tracker–style capability | In this system |
|------------------------------|----------------|
| Official roster + gated registration | Yes — Phases 1–2 |
| Tracer demographics | Yes — Alumni Tracer (Demographics tab) |
| Employment tracer | Yes — Alumni Tracer (Employment tab) + admin verification |
| Alumni directory | Yes — official roster with admin detail view |
| Onboarding gate | Yes — mandatory wizard after first login |
| Surveys | Yes — custom, targeted, assignments |
| Reminders | Yes — in-app + email, pending tracking |
| Announcements | Yes — targeted, priority |
| Forum | Yes — public + moderation |
| **Plus (beyond typical Grad Tracker)** | Events, jobs, messaging, archives, activity logs, web admin dashboard |

---

## 16. Completed roster migration (Phases 1–6)

| Phase | Delivered |
|-------|-----------|
| 1 | Admin official roster (CRUD, Excel, filters) |
| 2 | Gated registration (name + course + ID + OTP) |
| 3 | Admin member detail + activity log + update notifications |
| 4 | Mandatory onboarding wizard |
| 5 | Unified Alumni Tracer (demographics + employment) |
| 6 | Docs, indexes, QA checklist — see [alumni-roster-phase6.md](alumni-roster-phase6.md) |

### Future enhancements (not yet built)

| Item | Description |
|------|-------------|
| Admin request queue | Tickets from alumni |
| Deeper analytics | Optional: cohort dashboards, CHED template packs (see Phase 7 in `grad-tracker-migration.md`) |
| Bulk backup / export | System-wide data export |
| CHED survey preset packs | Standard question templates |
| Optional AI | Insights dashboard (assistive only) |

---

## 17. Quick reference — where to find things

| I want to… | Go to… |
|------------|--------|
| Register (official alumni only) | Register → verify roster → OTP |
| Log in | Login screen |
| Complete first-time setup | Onboarding wizard after register/login |
| Fill / edit demographics | Tracer → Demographics |
| Submit / edit employment | Tracer → Employment |
| Take a survey | Profile → Surveys or Home tracer card |
| Read announcements | Home → See all |
| Use forum | Home → Alumni Forum |
| Manage official roster | Admin → Alumni Directory |
| View alumni tracer detail | Admin → Directory → View |
| Verify employment (admin) | Admin → ID Tracer |
| Create a survey | Admin → Surveys |
| Remind non-responders | Admin → Surveys → View responses → Pending |
| Post announcement | Admin → Announcements |
| Moderate forum | Admin → Forum |
| Restore admin after Auth wipe | [restore-admin-account.md](restore-admin-account.md) |

---

*Document version: Phases 1–6 (roster migration) complete. See [alumni-roster-complete.md](alumni-roster-complete.md).*
