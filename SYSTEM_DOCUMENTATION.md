# AESS — USTP Alumni Engagement System
## Full System Documentation

> A Flutter + Supabase alumni portal for the University of Science and Technology of Southern Philippines (USTP).  
> Covers official roster management, graduate tracer studies, surveys, events, job postings, forum, messaging, and analytics.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture & Tech Stack](#2-architecture--tech-stack)
3. [Authentication & Access Control](#3-authentication--access-control)
4. [Admin Portal Features](#4-admin-portal-features)
5. [Alumni Portal Features](#5-alumni-portal-features)
6. [Database Structure](#6-database-structure)
7. [System Flows](#7-system-flows)
8. [Design System](#8-design-system)
9. [Shared Components & Libraries](#9-shared-components--libraries)
10. [File Reference](#10-file-reference)

---

## 1. Project Overview

### What It Is
AESS (Alumni Engagement System) is a web-first Flutter application that provides a unified platform for a university's alumni office and alumni community. It manages the official alumni roster, tracks graduate employment outcomes (CHED Graduate Tracer Study), handles surveys, events, job postings, announcements, and messaging.

### Key Capabilities
- **Alumni Roster**: Official list of graduates with registration, eligibility checks, and profile management
- **Graduate Tracer Study (CHED GTS)**: Compliance with CHED's mandatory tracer study form, including PDF export
- **Surveys**: Admin-created surveys with CHED GTS built-in template, skip logic, analytics, and export
- **Events**: Campus events with RSVP, comments, calendar, and reminders
- **Job Board**: Alumni job postings with recommendations, interests, and deadline reminders
- **Community Forum**: Moderated discussion board with tags, reports, and admin oversight
- **Messaging**: Direct admin-to-alumni communication with image attachments, reactions, and real-time
- **Announcements**: Priority-based announcements with audience targeting and email delivery
- **Feedback**: Alumni feedback submissions with admin response workflow
- **AI Assistant**: Gemini-powered chatbot for portal guidance
- **Reports & Analytics**: Custom report builder with PDF/Excel/CSV export, KPIs, CHED wave comparison
- **Audit Trail**: Full action logging for accountability

### Two User Roles
| Role | Access |
|------|--------|
| **Admin** | Dashboard, Roster, Events, Jobs, Announcements, Surveys, Reports, Activity Logs, Forum moderation, Feedback, Archives, CHED GTS export |
| **Alumni (User)** | Home, Events, Tracer/Surveys, Jobs, Community/Forum, Messages, Profile, Announcements, Feedback, AI Assistant |

---

## 2. Architecture & Tech Stack

### Tech Stack
| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart SDK ^3.9.2) |
| Backend | Supabase (PostgreSQL, Auth, Edge Functions, Storage, Realtime) |
| State | StatefulWidget + Stream-based reactivity |
| Auth | Supabase Auth (email/password, OTP) |
| PDF | pdf, syncfusion_flutter_pdf, printing packages |
| Charts | fl_chart |
| Maps | flutter_map + latlong2 |

### Feature-First Architecture
```
lib/
├── main.dart                          # Entry point, Supabase init, AuthGate
├── core/
│   ├── config/                        # Supabase, AI, email, migration config
│   ├── constants/                     # Courses, GTS fields, program constants
│   ├── services/                      # Email, audit, session, CHED export
│   └── utils/                         # Images, PDF, file I/O, platform helpers
├── features/
│   ├── auth/                          # Login, register, auth gate, shell
│   ├── onboarding/                    # First-time alumni wizard
│   ├── shell/                         # Main navigation (6-tab bottom nav)
│   ├── home/                          # Alumni dashboard
│   ├── events/                        # Events + RSVP + comments
│   ├── jobs/                          # Job postings + interests + recommendations
│   ├── forum/                         # Community forum (topics, replies, tags)
│   ├── messages/                      # Admin-alumni direct messaging
│   ├── announcements/                 # Admin announcements
│   ├── notifications/                 # In-app notification model + service
│   ├── surveys/                       # CHED GTS + custom surveys
│   ├── feedback/                      # Alumni feedback submissions
│   ├── ai/                            # Gemini AI chat assistant
│   ├── alumni/
│   │   ├── profile/                   # Alumni profile page
│   │   └── tracer/                    # Graduate tracer (employment records)
│   ├── community/                     # Community page (wraps forum)
│   └── admin/
│       ├── dashboard/                 # Admin overview + metrics + sidebar shell
│       ├── roster/                    # Alumni directory + member detail
│       ├── events/                    # Event CRUD + RSVP tracking + comments
│       ├── jobs/                      # Job management + insights + interested alumni
│       ├── announcements/             # Announcement CRUD + audience targeting
│       ├── surveys/                   # Survey editor + responses + analytics + export
│       ├── reports/                   # Custom report builder + KPIs + CHED comparison
│       ├── activity/                  # Audit log viewer
│       ├── forum/                     # Forum moderation
│       ├── feedback/                  # Feedback management
│       ├── archives/                  # Archived events/jobs/surveys
│       └── ched_gts_pdf_export/       # CHED GTS PDF template + fill engine
└── shared/
    └── widgets/
        ├── admin/                     # Reusable admin components (table, pagination, etc.)
        ├── user/                      # Portal theme, breakpoints, headers, skeletons
        ├── tracer/                    # Tracer profile checklist, demographic tab
        ├── onboarding/                # Onboarding step UI
        └── gts/                       # GTS profile form
```

### Key Design Principles
- **Token-driven theming**: `PortalTheme` defines all colors, typography, spacing, motion, button styles, and card shadows. Features never hardcode colors.
- **Feature isolation**: Each feature owns its own presentation/data/models/widgets. Cross-feature dependencies are minimal.
- **Shared admin shell**: `AdminDashboardWeb` provides sidebar navigation; feature pages render in the content area.
- **Shared user shell**: `MainNavigation` provides 6-tab bottom nav with lazy-loaded `IndexedStack` children.

---

## 3. Authentication & Access Control

### Auth Flow (Entry Point)
```
main.dart → Supabase.initialize() → AuthGate
```

**AuthGate** is the root resolver:
1. Shows loading splash ("Restoring your session...")
2. Checks `AppSession.currentSession` + `AppSession.currentUser`
3. If no session → `LoginScreen`
4. If session exists:
   - Calls `authService.ensureAccountAuthorized()` (validates roster link)
   - Calls `authService.getLoginRouting(userId)` → returns `{role, onboardingComplete}`
   - Routes to: Admin → `AdminDashboardWeb` | User (incomplete) → `AlumniOnboardingScreen` | User (ready) → `MainNavigation`
5. Listens to `AuthState` stream: on `signedOut` → Login; on `initialSession` → re-resolve
6. Has 20-second timeout with retry/fallback UI

### Login
1. Email + password form with "Remember me" (email only, never passwords)
2. `authService.loginWithEmailPassword()` → Supabase `signInWithPassword`
3. `_assertAccountStillAuthorized()` → validates user exists in `users` table + active roster link
4. `authService.getLoginRouting()` → gets role + onboarding status
5. Audit log: `LOGIN` action (SUCCESS or FAILED)
6. Route to appropriate destination

### Registration (3-Step Process)
| Step | What Happens |
|------|-------------|
| 1. Verify Alumni Status | Enter name, course, student ID → `AlumniEligibilityService.validate()` checks official roster |
| 2. Account Details | Set password (6+ chars) once verified |
| 3. Email OTP | Supabase Auth `signUp` sends a 6-digit code (Gmail SMTP) → `verifyOTP` confirms the email |
| 4. Link Account | RPC `link_alumni_registration` re-checks the roster, links `alumni_members.auth_uid` and creates the `users` row → audit log |

The link RPC refuses unconfirmed emails, roster mismatches, deactivated roster rows, and ID numbers already linked to another account.

### Role-Based Access Control
| Role | Onboarding | Destination |
|------|-----------|-------------|
| `admin` | — | `AdminDashboardWeb` |
| `user` | incomplete | `AlumniOnboardingScreen` |
| `user` | complete | `MainNavigation` |

- Roles stored in `public.users.role` column
- Enforced at database level via RLS (`is_admin()` function)
- Admin portal has its own dashboard shell; alumni portal uses 6-tab bottom nav

### Session Management
- **Supabase Auth** is the sole identity provider (Firebase fully removed)
- `AppSession` static wrapper: `currentUser`, `currentSession`, `userId`, `email`, `isSignedIn`, `onAuthStateChange` stream
- Cold-start session restore with 20-second timeout
- `LoginPreferencesService` persists email + remember-me via SharedPreferences (never passwords)

---

## 4. Admin Portal Features

The admin portal (`AdminDashboardWeb`) uses a collapsible navy sidebar with sectioned navigation.

### 4.1 Dashboard Overview
**File**: `lib/features/admin/dashboard/`

- **Metric cards**: rosterTotal, registeredOnRoster, tracerCompleteCount, employmentSubmissions, pendingSurveyAssignments, totalSurveyResponses, publishedSurveys, totalEvents, activeEventsCount, portalAccounts, totalJobs, activeJobs, unreadMessages, publishedAnnouncements, forumTopics, openFeedback
- **Computed KPIs**: registrationRate, tracerCompletionRate, surveyResponseRate, attentionCount, unclaimedRoster, registeredWithoutTracer
- **Activity trend chart**: 90-day daily activity buckets from audit logs with peak annotation
- **Quick actions**: Create Event, Create Survey, Create Announcement, Create Job
- **Global search**: Ctrl+K command palette with categories (recent, pages, commands, alumni, events, surveys, reports)

### 4.2 Alumni Roster / Directory
**File**: `lib/features/admin/roster/`

**Screens**:
- `admin_alumni_directory_page.dart` — Full alumni directory with search, multi-filter (registration status, active status, employment, batch, course), data table
- `admin_alumni_member_detail_page.dart` — Detailed profile: demographics, employment history, activity, survey answers, deactivation toggle, profile sync

**Operations**:
- Manual add member
- Bulk import from spreadsheet
- CSV export
- CHED GTS PDF bulk export (per-person filled PDFs in ZIP)
- Deactivate/reactivate members
- Delete registered member account
- Search by name, student ID, email

**Model** (`AlumniMember`): id, fullName, course, studentId, authUid, registeredEmail, isRegisteredUser, isDeactivated, batchYear, employmentStatus, gender, civilStatus, birthDate, yearGraduated, tracerProfileComplete, profileImageUrl, lastActiveAt

### 4.3 Events
**File**: `lib/features/admin/events/`

- **List view**: Status filters, search, list/calendar toggle
- **Create/edit**: Title, description, date/time, venue (with coordinates), capacity, image upload, agenda items, audience targeting
- **Detail panel**: RSVP tracking (going/not-going/maybe), attendee list, comments moderation
- **Auto-archive**: Past events auto-archived

**Model** (`AlumniEvent`): id, theme, batchYear, venue, status, date, startTime, endTime, description, coverImageUrl, category, capacity, agenda, commentsCount, viewsCount, cancelled, venueLatitude, venueLongitude

### 4.4 Job Postings
**File**: `lib/features/admin/jobs/`

- **Management page**: List with search/filters (category, type, status, remote-only)
- **Add/edit dialog**: Company, title, type, location, salary, description, requirements, benefits, deadline, target programs, application method
- **Insights dialog**: Top viewed, top interested, by category/status, top companies
- **Interested alumni drawer**: Roster with search, sort, CSV export, message shortcut
- **Details drawer**: Full job detail side panel

**Categories**: IT, Education, Business, Engineering, Architecture, Healthcare, Government, BPO, Freelance, Others

### 4.5 Announcements
**File**: `lib/features/admin/announcements/`

- **List**: Status filters (draft/published/archived), search, batch actions
- **Create/edit**: Title, content, priority (normal/important), audience targeting (batch/course/year), email delivery config, publish/draft/archive

**Model** (`Announcement`): id, title, body, status, publishedAt, data (priority, targetPrograms, targetBatchYears, notifyInApp, notifyEmail, createdBy, recipientCount)

### 4.6 Surveys
**File**: `lib/features/admin/surveys/`

**Screens**:
- `admin_surveys_page.dart` — Survey list with status/kind filters (all, draft, published, closed, CHED GTS)
- `admin_survey_editor_page.dart` — Survey editor: title, description, questions (add/edit/reorder), batch/audience targeting, publish/draft/archive
- `admin_survey_responses_page.dart` — Response viewer with analytics panel, export dialog, formal report dialog

**Features**:
- **CHED GTS built-in**: Official CHED GTS v3.0.0 template with skip logic, locked form
- **Analytics panel**: Per-survey analytics with batch/course filters, response funnel, question-level aggregates, CHED distribution charts (27 fields), most-skipped questions
- **Export dialog**: 6 report types × 4 formats (PDF, Excel, CSV, print)
- **Formal report**: AI-generated formal survey report with export to PDF/Word/print
- **Preview**: Read-only survey preview using actual survey take UI
- **Response timeline**: Lifecycle tracking (assigned → opened → started → submitted → viewed)

**Question Types**: text, longText, singleChoice, multipleChoice, scale, date

### 4.7 Reports & Analytics
**File**: `lib/features/admin/reports/`

**Multi-tab dashboard**:
- **Overview**: KPI cards with growth %, sparklines, status badges
- **Tracer**: Cohort filters, employment charts, CHED wave comparison (2-8 waves)
- **Survey**: Response rates, question-level rollups
- **Export**: Custom report builder with 11 section types, PDF/Excel/CSV/print
- **AI Insights**: Executive summary, key findings, recommendations

**Custom Report Builder**:
- 11 section types: executiveKpis, alumniRoster, employmentRecords, surveySummary, surveyParticipation, surveyQuestions, chedWaveComparison, events, jobPostings, announcements, forumTopics
- Filter by: batch years, courses, registration status, tracer completion, employment status, date range
- Save/load templates locally
- 6 preset download packs (executive brief, tracer pack, CHED GTS pack, wave comparison, survey participation, roster extract)

### 4.8 Forum Moderation
**File**: `lib/features/admin/forum/`

- **Discussions tab**: Topic search, status filters (all/open/locked/solved), locking/unlocking
- **Reports tab**: Report management (dismiss/remove reported topics/posts)

### 4.9 Feedback Management
**File**: `lib/features/admin/feedback/`

- **List**: Status filters (submitted/in review/resolved/closed), category filters, search, pagination
- **Detail**: Admin response form, status updates (submitted → in review → resolved → closed), response timeline

### 4.10 Archives
**File**: `lib/features/admin/archives/`

- Tabbed view of archived entities: Events, Jobs, Surveys with search within each tab

### 4.11 Activity Logs
**File**: `lib/features/admin/activity/`

- Audit log viewer: action/resource/status filters, date range picker, pagination, log detail expansion
- Logs every login, registration, profile change, survey submission, event RSVP, etc.

**Model** (`AuditLog`): id, userId, action, resource, resourceId, details (userName, userEmail, description, changes, ipAddress, status, userRole), createdAt

### 4.12 CHED GTS PDF Export
**File**: `lib/features/admin/ched_gts_pdf_export/`

- **Template registry**: v3.0.0 (legacy, 90 fields) and v3.1.0 (active, 130 fields)
- **Field catalog**: 130 field definitions (text/choice/radio/checkbox) covering all CHED GTS form fields
- **Fill engine**: Loads PDF template, sets AcroForm values, optional flattening, returns filled PDF bytes
- **Per-person export**: Assemble answers → fill template → audit trail
- **Batch export**: ZIP of filled PDFs (max 100) with progress callback
- **Text fitting**: Intelligent font shrinking (9pt to 5.5pt) with multiline wrapping

### 4.13 Messages (Admin)
**File**: `lib/features/messages/`

- **Inbox**: User list with search/filter/sort (all, unread, needs-reply, recent)
- **Conversation thread**: Message bubbles with image attachments, reactions, read receipts
- **Compose picker**: Select alumni to message
- **Profile panel**: Quick-view of user profile from conversation
- **Real-time**: Supabase Realtime subscription for live updates

---

## 5. Alumni Portal Features

The alumni portal (`MainNavigation`) uses 6-tab bottom navigation.

### 5.1 Home Dashboard
**File**: `lib/features/home/`

- **Greeting banner**: Time-based greeting + alumni name + avatar
- **Upcoming events**: Event cards with RSVP status
- **Important dates calendar**: Events + surveys + tracer deadlines in calendar view
- **Pending surveys**: Assigned surveys awaiting response
- **Recent forum topics**: Latest community discussions
- **Recent jobs**: Latest job postings
- **Announcements preview**: Recent announcements

### 5.2 Events
**File**: `lib/features/events/`

- **Calendar view**: Month calendar with event dots
- **List view**: Paginated event cards with cover images
- **RSVP**: Going / Interested / Can't attend
- **Comments**: View and add comments on events
- **Event detail**: Full event info, agenda, attendee count, status badge
- **Search**: Filter by category, date range
- **Reminders**: Local device reminders when Going, plus server day-before and day-of reminders (`run_event_reminders`, based on `events.starts_at`)

**Model** (`AlumniEvent`): id, theme, batchYear, venue, status, date, startTime, endTime, description, coverImageUrl, category, capacity, agenda, commentsCount, viewsCount

### 5.3 Graduate Tracer / Surveys
**File**: `lib/features/alumni/tracer/` + `lib/features/surveys/`

**Tracer page tabs**:
- **CHED GTS tab**: Official CHED GTS form with skip logic, section navigation, draft saving
- **Assigned surveys tab**: Custom surveys assigned by admin

**Survey take page**:
- Dynamic question rendering (text, longText, singleChoice, multipleChoice, scale, date)
- Skip logic (conditional field visibility)
- Draft saving (auto-saves progress)
- Submit with confirmation
- CHED GTS form rendering with section headers and compliance fields

**Employment status**: comes only from submitted CHED GTS answers. `IdTracerService` reads the view `gts_employment_records` (latest submission per alumnus); there is no separate employment form.

**Service**: `SurveyService` handles assignment loading, response saving, draft management, and submission

### 5.4 Job Board
**File**: `lib/features/jobs/`

- **Listing**: Search/filter (category, type, remote-only, recommended, saved), pagination
- **Job detail**: Full description, requirements, benefits, application method
- **Favorites**: Save/unsave jobs
- **Interest**: "I'm interested" toggle (notifies admin)
- **Recommendations**: Simple program-overlap matching
- **Deadline reminders**: Session-debounced 1-day and 3-day deadline reminders

**Model** (`JobPosting`): id, companyName, companyLogo, jobTitle, jobType, location, salaryRange, description, requirements, benefits, postedDate, applicationDeadline, contactEmail, applicationMethod, category, targetPrograms, isRemote, experienceLevel, status, views, applications

### 5.5 Community Forum
**File**: `lib/features/forum/`

- **Topic list**: Paginated, search/sort/filter (all/open/locked/solved)
- **Topic view**: Body, reply thread, bookmark, pin/solved/locked badges
- **Composer**: Create/edit topic with title, body, tag selection
- **Replies**: Threaded replies with quoting
- **Bookmarks**: Save topics for later
- **Content moderation**: Flagging, admin review

**Model** (`ForumTopic`): id, title, body, authorUid, authorName, authorProgram, authorBatch, replyCount, lastReplyAt, isLocked, isPinned, isSolved, isAnnouncement, viewCount, tags

### 5.6 Messages
**File**: `lib/features/messages/`

- **Thread view**: Reverse-chronological messages with admin
- **Image attachments**: Camera/gallery pick, compression, upload to Supabase Storage
- **Reactions**: Emoji reactions on messages
- **Read receipts**: Seen/unseen status
- **Pagination**: Load older messages on scroll
- **New message badge**: Unread count indicator
- **Typing indicators**: Real-time typing status
- **Real-time**: Supabase Realtime subscription

**Service**: `MessageService` manages CRUD, realtime subscriptions, notifications, image pipeline, and Storage cleanup

### 5.7 Announcements
**File**: `lib/features/announcements/`

- **List**: Published announcements with priority badges (normal/important)
- **Expandable**: Tap to read full content
- **Deep-link**: Support for navigating from notification to specific announcement

### 5.8 Feedback
**File**: `lib/features/feedback/`

- **Submit**: Category, subject, message, rating (1-5)
- **List**: Stream-based list of user's submissions
- **Detail**: View submission + admin response + status updates

### 5.9 Profile
**File**: `lib/features/alumni/profile/`

- **Avatar upload**: Image picker with compression
- **Menu**: Profile info, messages, surveys, feedback, logout
- **Profile info page**: GTS profile form fields, save to Supabase

### 5.10 AI Assistant
**File**: `lib/features/ai/`

- **Chat interface**: Google Gemini-powered chat
- **Suggestion chips**: Pre-built prompts for alumni (help with tracer, find jobs, etc.) and admin (analytics questions)
- **Model**: `AiChatMessage` (role: user/assistant, text, isError)

### 5.11 Notifications
**File**: `lib/features/notifications/`

- **Types**: event, job, message, announcement, survey, feedback, forum, system
- **Service**: CRUD, read/unread, bulk create, type-specific helpers
- **No dedicated screen**: Consumed via badges and popups in other features

### 5.12 Onboarding
**File**: `lib/features/onboarding/`

- **4-step wizard**: Welcome → Profile (GTS form) → Photo (avatar upload) → Done
- **Home gate**: After registration, routes to onboarding if incomplete, else to home

---

## 6. Database Structure

All tables are in Supabase PostgreSQL with Row-Level Security (RLS) enabled.
The tables below are a summary; the generated, always-current reference is in
[docs/database/](docs/database/) (columns, constraints, indexes, policies,
functions, triggers).

### Core Tables

#### `public.users` — Primary user profile (PK = Supabase Auth UUID)
| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid PK | FK → auth.users(id) on delete cascade |
| `role` | text | 'user' or 'admin' |
| `display_name` | text | Full name |
| `email` | text | |
| `student_id` | text | |
| `program` / `course` | text | Academic program |
| `year_graduated` | text | Graduation year = batch (follows the roster) |
| `gender`, `civil_status`, `birth_date` | text/date | |
| `contact_number`, `phone_number` | text | |
| `address` | text | |
| `employment_status` | text | Mirrored from employment records |
| `onboarding_complete` | boolean | Gates main app access |
| `tracer_profile_completion` | integer | 0-100% |
| `tracer_profile_complete` | boolean | |
| `profile_image_url` | text | |
| `last_active_at` | timestamptz | |
| `created_at`, `updated_at` | timestamptz | Auto-maintained by trigger |

#### `public.alumni_members` — Official alumni roster
| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid PK | |
| `full_name`, `course`, `student_id` | text | Core identity |
| `auth_uid` | uuid FK | Links to auth.users when registered |
| `registered_email` | text | |
| `is_registered_user` | boolean | |
| `is_deactivated` | boolean | |
| `year_graduated` | text | Graduation year = batch (source of truth) |
| `gender`, `civil_status`, `birth_date` | text/date | |
| `employment_status` | text | Legacy; current status comes from `gts_employment_records` |
| `profile_image_url` | text | |
| `last_active_at` | timestamptz | |
| `tracer_profile_complete` | boolean | |
| `created_at`, `updated_at` | timestamptz | |

#### `public.events` — Alumni events
| Column | Type |
|--------|------|
| `id` | uuid |
| `theme` | text |
| `batch_year`, `venue` | text |
| `status` | text |
| `date`, `start_time`, `end_time` | timestamptz/text |
| `starts_at`, `ends_at` | timestamptz (set by trigger from date + time text, Manila time; an end before the start means past midnight) |
| `description`, `cover_image_url`, `category` | text |
| `capacity` | int |
| `registration_deadline` | timestamptz |
| `agenda` | jsonb |
| `comments_count`, `views_count` | int |
| `cancelled` | boolean |
| `venue_latitude`, `venue_longitude` | double |

#### `public.event_rsvps`
| Column | Type |
|--------|------|
| `id` | uuid |
| `event_id` | uuid FK |
| `user_id` | uuid FK |
| `status` | text (going/interested/cant_attend) |
| `created_at`, `updated_at` | timestamptz |

#### `public.event_comments` / `public.event_replies`
| Column | Type |
|--------|------|
| `id` | uuid |
| `event_id` | uuid FK |
| `user_id` | uuid FK |
| `body` | text |
| `comment_id` | uuid (parent for replies) |
| `created_at`, `updated_at` | timestamptz |

#### `public.jobs` — Job postings
| Column | Type |
|--------|------|
| `id` | uuid |
| `title`, `company`, `location`, `description` | text |
| `status` | text |
| `data` | jsonb (all nested fields: companyName, companyLogo, jobType, salaryRange, requirements, benefits, applicationDeadline, contactEmail, applicationMethod, views, applications, isRemote, experienceLevel, category, targetPrograms, applicationUrl) |
| `updated_at` | timestamptz |

#### `public.job_interests`
| Column | Type |
|--------|------|
| `user_id` | uuid FK |
| `job_id` | uuid FK |
| `created_at` | timestamptz |

#### `public.surveys`
| Column | Type |
|--------|------|
| `id` | uuid |
| `title`, `description` | text |
| `status` | text (draft/published/closed) |
| `target_programs`, `target_batch_years` | text[] |
| `open_at`, `close_at` | timestamptz |
| `created_by` | uuid FK |
| `assignment_count`, `response_count` | int |
| `template_id`, `template_version` | text |
| `data` | jsonb (kind, template_key, schema_version, visibility_rules, archived) |
| `created_at`, `updated_at` | timestamptz |

#### `public.survey_questions`
| Column | Type |
|--------|------|
| `id` | uuid |
| `survey_id` | uuid FK |
| `order` | int |
| `type` | text (text/longText/singleChoice/multipleChoice/scale/date) |
| `prompt`, `section`, `ched_item_number`, `prefill_key` | text |
| `required` | boolean |
| `options` | text[] |
| `scale_min`, `scale_max` | int |
| `is_standard_item` | boolean |

#### `public.survey_assignments`
| Column | Type |
|--------|------|
| `id` | uuid |
| `survey_id`, `user_id` | uuid FK |
| `survey_title` | text |
| `status` | text (notStarted/inProgress/completed) |
| `assigned_at`, `last_reminder_at` | timestamptz |
| `reminder_count` | int |

#### `public.survey_responses`
| Column | Type |
|--------|------|
| `survey_id`, `user_id` | uuid FK |
| `answers` | jsonb |
| `status` | text (draft/submitted) |
| `submitted_at`, `updated_at`, `opened_at`, `first_draft_at` | timestamptz |
| `device_category`, `platform_family`, `browser_family` | text |

#### `public.survey_response_events` — Append-only lifecycle
| Column | Type |
|--------|------|
| `id` | uuid |
| `survey_id`, `user_id` | uuid FK |
| `event_type` | text |
| `device_category`, `platform_family`, `browser_family` | text |
| `created_at` | timestamptz |

#### `public.gts_employment_records` — Employment view (read-only)
Latest submitted CHED GTS response per alumnus.
| Column | Type |
|--------|------|
| `user_id` | uuid |
| `status` | text (Employed / Unemployed / Never Employed) |
| `position` | text (CHED item 19) |
| `data` | jsonb (source, surveyId, userName, userEmail, schoolId, contactNumber, industry, employmentType, jobLevel, salaryRange, placeOfWork, country) |
| `verification_status` | text (always `Submitted`) |

`gts_respondent_facts` (one typed row per submitted CHED response) and `gts_metric(...)` back the DSS metrics.

#### `public.forum_topics`
| Column | Type |
|--------|------|
| `id` | uuid |
| `title`, `body` | text |
| `author_uid`, `author_name`, `author_program`, `author_batch` | text |
| `reply_count` | int |
| `last_reply_at` | timestamptz |
| `is_locked`, `is_pinned`, `is_solved`, `is_announcement`, `is_featured` | boolean |
| `moderation_reason` | text |
| `view_count` | int |
| `edited_at`, `created_at`, `updated_at` | timestamptz |

#### `public.forum_posts`
| Column | Type |
|--------|------|
| `id` | uuid |
| `topic_id` | uuid FK |
| `body` | text |
| `author_uid`, `author_name` | text |
| `quoted_post_id`, `quoted_excerpt` | text |
| `edited_at`, `created_at`, `updated_at` | timestamptz |

#### `public.forum_tags` / `public.forum_topic_tags`
- Tags: `id`, `slug`, `label`, `sort_order`
- Junction: `topic_id`, `tag_id`

#### `public.forum_reports`
| Column | Type |
|--------|------|
| `id` | uuid |
| `reporter_uid` | uuid |
| `topic_id`, `post_id` | uuid FK |
| `reason` | text |
| `status` | text |
| `created_at`, `updated_at` | timestamptz |

#### `public.messages`
| Column | Type |
|--------|------|
| `id` | uuid |
| `sender_id`, `recipient_id` | uuid |
| `sender_doc_id`, `recipient_doc_id` | uuid |
| `sender_role`, `sender_name`, `sender_email` | text |
| `body` | text |
| `image_base64` | text |
| `is_read` | boolean |
| `reactions` | jsonb |
| `created_at`, `updated_at`, `edited_at` | timestamptz |

#### `public.announcements`
| Column | Type |
|--------|------|
| `id` | uuid |
| `title`, `body` | text |
| `status` | text (draft/published/archived) |
| `published_at` | timestamptz |
| `data` | jsonb (priority, targetPrograms, targetBatchYears, notifyInApp, notifyEmail, createdBy, recipientCount) |
| `created_at`, `updated_at` | timestamptz |

#### `public.user_notifications`
Created only by database triggers and server functions; alumni can read and mark their own as read.
| Column | Type |
|--------|------|
| `id` | uuid |
| `user_id` | uuid FK |
| `title`, `body` | text |
| `type` | text (event/job/message/announcement/survey/feedback/forum/system) |
| `priority`, `route`, `dedupe_key` | text |
| `is_read`, `read_at` | boolean / timestamptz |
| `data` | jsonb (relatedId) |
| `expires_at`, `created_at`, `updated_at` | timestamptz |

#### `public.notification_deliveries`
One log for push alerts (`channel = 'push'`, per device token) and emails (`channel = 'email'`, per recipient address). Admins can read it. See [docs/notifications.md](docs/notifications.md).

#### `public.feedback`
| Column | Type |
|--------|------|
| `id` | uuid |
| `user_id` | uuid FK |
| `status` | text (submitted/inReview/resolved/closed) |
| `message` | text |
| `admin_reply` | text |
| `data` | jsonb (userId, userName, category, rating) |
| `created_at`, `updated_at` | timestamptz |

#### `public.audit_logs`
| Column | Type |
|--------|------|
| `id` | uuid |
| `user_id` | uuid |
| `action` | text |
| `entity_type`, `entity_id` | text |
| `details` | jsonb (userName, userEmail, description, changes, ipAddress, status, userRole) |
| `created_at` | timestamptz |

### Row-Level Security (RLS) Policies
| Table | Policy |
|-------|--------|
| `users` | SELECT by owner OR admin; INSERT only self with role='user'; UPDATE self; DELETE admin only |
| `alumni_members` | Anon can SELECT unclaimed rows (registration eligibility); Authenticated can SELECT if admin/owner/unclaimed; INSERT/UPDATE/DELETE admin only |
| `surveys` | Admin full CRUD; users read published only |
| `survey_responses` | Users read/write own; admin read all |
| `forum_topics` | Authenticated read; author update/delete |
| `messages` | Sender/recipient read only |
| `events` | Authenticated read; admin CRUD |
| `announcements` | Authenticated read published; admin CRUD |

### Key Database Functions
| Function | Purpose |
|----------|---------|
| `is_admin()` | Returns true if current user has admin role |
| `is_signed_in()` | Returns true if user is authenticated |
| `set_updated_at()` | Trigger function — auto-sets updated_at on row change |
| `validate_alumni_eligibility()` | RPC — checks name/course/ID against roster |
| `link_alumni_registration()` | RPC — links auth user to alumni roster |

### Edge Functions
| Function | Purpose |
|----------|---------|
| `send-email` | Admin-only reminder emails via Gmail SMTP; logs each send in `notification_deliveries` |
| `send-push` | Sends queued push alerts (Web Push / Firebase Cloud Messaging) |
| `tracer-help` | AI suggestions for CHED GTS occupation (Q19) and line of business (Q20); alumni must accept them |

Removing an alumnus is the RPC `admin_remove_alumni_account` (deactivate + anonymize; tracer answers kept).

---

## 7. System Flows

### Registration Flow
```
RegisterScreen
  → Enter: name, course, student ID
  → Step 1: AlumniEligibilityService.validate() → RPC or local check
  → Step 2: Set password (6+ chars)
  → Step 3: Supabase Auth signUp → 6-digit OTP email via Gmail SMTP
  → Verify 6-digit code (verifyOTP)
  → eligibilityService.linkRegistration() → RPC link_alumni_registration links roster + creates users row
  → Audit log: REGISTER
  → AlumniHomeGate → AlumniOnboardingScreen (if incomplete)
  → 4-step wizard: Welcome → Profile → Photo → Done
  → MainNavigation (alumni portal)
```

### Login Flow
```
LoginScreen
  → Enter: email + password
  → authService.loginWithEmailPassword() → signInWithPassword
  → _assertAccountStillAuthorized() → validates roster link
  → authService.getLoginRouting() → {role, onboardingComplete}
  → Audit log: LOGIN
  → Route:
      admin → AdminDashboardWeb
      user (incomplete) → AlumniOnboardingScreen
      user (ready) → MainNavigation
```

### Survey Response Flow
```
UserSurveysPage
  → See assigned surveys (notStarted/inProgress/completed)
  → Tap survey → UserSurveyTakePage
  → Dynamic question rendering with skip logic
  → Auto-save drafts
  → Submit → SurveyService.submitResponse()
  → Response saved to survey_responses table
  → Survey_response_events lifecycle tracked
  → Audit log
```

### Event RSVP Flow
```
EventsPage
  → Browse events (calendar or list)
  → Tap event → Event detail
  → RSVP: Going / Interested / Can't attend
  → EventRsvpService updates event_rsvps table
  → Comment on event → EventCommentService
```

### Job Application Flow
```
JobPostingPage
  → Browse jobs with search/filter
  → Tap job → detail dialog
  → "I'm interested" → JobInterestService (notifies admin)
  → Save to favorites → FavoriteJobService
  → Apply via application method (email/URL)
```

### Message Flow
```
MessagesPage
  → Real-time thread with admin
  → Send text + image attachments
  → Image compression pipeline → Supabase Storage
  → Reactions, read receipts
  → Typing indicators via Supabase Realtime
```

### Admin Report Export Flow
```
ReportsPage
  → Select tab (Overview/Tracer/Survey/Export/AI)
  → Custom Report Builder
  → Pick sections (11 types)
  → Apply filters (batch, course, date)
  → Export to PDF / Excel / CSV / Print
  → Or use preset download packs
```

### CHED GTS PDF Export Flow
```
Admin Alumni Directory
  → Select members (bulk) or single member
  → ChedGtsPdfPersonExportService.assembleAnswers()
  → ChedGtsPdfFillEngine.fillMapped() with template v3.0.0 or v3.1.0
  → Returns filled PDF bytes
  → Batch: ZIP package via ChedGtsPdfBatchExportService
  → Audit log
```

---

## 8. Design System

### PortalTheme (`lib/shared/widgets/user/portal_theme.dart`)
All colors, typography, spacing, motion, and component styles are centralized here.

#### Brand Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `navy` | `#1A1851` | Primary brand color, buttons, headers |
| `navyDeep` | `#031C2E` | Deep secondary, gradients |
| `navyMid` | `#0D4A77` | Mid secondary, gradient end |
| `sky` | `#329DEA` | Soft accent, chips, links |
| `gold` | `#FCB315` | Accent (use sparingly), badges, hero highlights |
| `ember` | `#FF6418` | Warm accent |
| `amber` | `#FF9718` | Warm accent |

#### Surface Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `pageBg` | `#F4F6FA` | Page background (soft cool wash) |
| `surfaceMuted` | `#F1F3F5` | Muted surfaces |
| `card` | `#FFFFFF` | Card background |
| `border` | `#E1E5EA` | Default borders |
| `borderStrong` | `#D1D5DB` | Stronger borders |

#### Text Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `textPrimary` | `#1F2937` | Primary text |
| `textSecondary` | `#6B7280` | Secondary text |
| `textMuted` | `#9CA3AF` | Muted/caption text |
| `textOnNavy` | `#FFFFFF` | Text on dark surfaces |

#### Status Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `danger` | `#DC2626` | Errors, destructive actions |
| `success` | `#059669` | Success states |
| `warning` | `#D97706` | Warnings |
| `badge` | `#E11D48` | Notification badges |

#### Typography
| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| `display` | 28px | 800 | Page headlines |
| `pageTitle` | 18px | 700 | AppBar titles |
| `sectionTitle` | 20px | 800 | Section headings |
| `cardTitle` | 16px | 700 | Card headings |
| `body` | 14px | 400 | Body text |
| `bodySecondary` | 14px | 400 | Secondary body |
| `meta` | 12px | 500 | Metadata, timestamps |
| `caption` | 11px | 500 | Captions, badges |
| `button` | 14px | 700 | Button labels |

#### Geometry
| Token | Value |
|-------|-------|
| `radiusSm` | 8px |
| `radiusMd` | 12px |
| `radiusLg` | 16px |
| `radiusXl` | 20px |
| `radius2xl` | 24px |
| `space1` | 8px |
| `space2` | 12px |
| `space3` | 16px |
| `space4` | 20px |
| `space5` | 24px |
| `space6` | 32px |
| `space7` | 40px |

#### Motion
| Token | Value |
|-------|-------|
| `fast` | 150ms |
| `normal` | 250ms |
| `slow` | 350ms |
| `ease` | easeOutCubic |

#### Button Styles
- `primaryButton()` — Navy filled, radius 12, no elevation
- `secondaryButton()` — Outlined with border
- `ghostButton()` — Text button, navy foreground
- `goldAccentButton()` — Gold filled, navy text

#### Gradients
- `navyGradient` — navy → navyMid (diagonal)
- `heroGradient` — navy → navyDeep (diagonal)

#### Shadows
- `cardShadow` — Subtle navy-tinted, blur 16, offset (0,4)
- `elevatedShadow` — Stronger navy-tinted, blur 24, offset (0,8)
- `softShadow` — Very subtle, blur 8, offset (0,2)

### Responsive Breakpoints (`PortalBreakpoints`)
| Breakpoint | Width | Layout |
|------------|-------|--------|
| `compact` | < 600px | Phone: 1-column, bottom nav |
| `medium` | 600-899px | Tablet: 2-column grids, bottom nav |
| `expanded` | ≥ 900px | Desktop: NavigationRail sidebar, 3-column grids |

### Auth Shell (`AuthShell`)
- **Wide (≥ 960px)**: Split layout — 42% navy hero panel + 58% white form
- **Narrow**: Full-bleed white with compact brand mark above form (no card container)

---

## 9. Shared Components & Libraries

### Admin Widgets (`lib/shared/widgets/admin/`)
| Component | Purpose |
|-----------|---------|
| `AdminDataTable` | Data table chrome with sorting, selection |
| `AdminPaginationBar` | Page controls (showing X-Y of Z, prev/next, page size) |
| `AdminSearchField` | Toolbar search input |
| `AdminPageHeader` | Title + actions row, responsive layout |
| `AdminFormLayout` | Form field spacing and layout helpers |
| `AdminDensity` | Global spacing/sizing tokens for admin screens |
| `AdminSkeletons` | Loading placeholders (list, KPI, chart) |
| `AdminSurface` | Modal dialog + side panel containers |

### User Portal Widgets (`lib/shared/widgets/user/`)
| Component | Purpose |
|-----------|---------|
| `PortalTheme` | Complete design token system |
| `PortalAppBar` | Standard app bar (light/dark tones) |
| `PortalSectionHeader` | In-body section titles |
| `PortalPageIntro` | Soft page intro under app bar |
| `PortalChip` | Status/category chips (neutral, brand, gold, success, warning, danger) |
| `PortalHighlightPanel` | Primary CTA / needs-attention panels |
| `PortalCardShell` | Clipped Material card with elevation |
| `PortalBreakpoints` | Responsive breakpoint system |
| `PortalEmptyState` | Empty state placeholder |
| `PortalInlineError` | Error state display |
| `PortalSkeletons` | Loading skeletons for all tab screens |

### Core Services (`lib/core/services/`)
| Service | Purpose |
|---------|---------|
| `AppSession` | Static wrapper for Supabase Auth state |
| `AuditService` | Audit logging (CRUD, query, retention) |
| `EmailService` | OTP/reminder emails via Supabase Edge Function |
| `ChedGtsExportService` | Multi-sheet Excel export aligned with CHED format |
| `SupabaseUserBridge` | User ID validation against users table |

### Core Config (`lib/core/config/`)
| Config | Purpose |
|--------|---------|
| `SupabaseConfig` | URL + anon key (dart-define or defaults) |
| `SupabaseDefaults` | Fallback Supabase credentials |
| `EmailDeliveryConfig` | Email service toggle + function name |
| `AiConfig` / `AiDefaults` | Gemini API key + model settings |
| `MigrationConfig` | Schema migration flags |

### Core Utils (`lib/core/utils/`)
| Utility | Purpose |
|---------|---------|
| `AppImage` | Cached network image provider + decode cache |
| `AvatarImagePrepare` | Avatar crop/resize for upload |
| `ExportPlatform` | Platform-specific file export (web download vs mobile share) |
| `WebFileDownload` | Browser file download via anchor element |
| `WebFileUpload` | Browser file picker |
| `PdfSafeText` | PDF-safe text encoding (accent stripping) |
| `SafeExternalLink` | URL launcher with validation |
| `LocalId` | Local ID generation |
| `ClientContext` | Device/platform context for analytics |

---

## 10. File Reference

### Entry Points
| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, Supabase init, AuthGate |
| `lib/features/auth/presentation/auth_gate.dart` | Root session resolver + routing |
| `lib/features/shell/presentation/main_navigation.dart` | Alumni 6-tab shell |
| `lib/features/admin/dashboard/presentation/admin_dashboard_page.dart` | Admin shell |

### Auth
| File | Purpose |
|------|---------|
| `lib/features/auth/presentation/auth_shell.dart` | Shared responsive auth layout |
| `lib/features/auth/presentation/login_page.dart` | Login screen |
| `lib/features/auth/presentation/register_page.dart` | Registration screen (3-step) |
| `lib/features/auth/data/auth_service.dart` | Supabase Auth facade |
| `lib/features/auth/data/alumni_eligibility_service.dart` | Roster eligibility check |
| `lib/features/auth/data/login_preferences_service.dart` | Remember-me persistence |

### Key Models
| File | Model |
|------|-------|
| `lib/features/admin/roster/models/alumni_member_model.dart` | AlumniMember |
| `lib/features/events/models/event_model.dart` | AlumniEvent, EventRsvpModel, EventCommentModel |
| `lib/features/jobs/models/job_posting_model.dart` | JobPosting |
| `lib/features/surveys/models/survey_model.dart` | Survey, SurveyQuestion, SurveyAssignment, SurveyResponse |
| `lib/features/forum/models/forum_model.dart` | ForumTopic, ForumTag, ForumReply |
| `lib/features/messages/models/message_model.dart` | MessageModel, ConversationMessage, ConversationSummary |
| `lib/features/announcements/models/announcement_model.dart` | Announcement |
| `lib/features/feedback/models/feedback_model.dart` | FeedbackSubmission |
| `lib/features/notifications/models/notification_model.dart` | NotificationModel |
| `lib/features/admin/activity/models/audit_log_model.dart` | AuditLog |
| `lib/features/ai/models/ai_chat_message.dart` | AiChatMessage |
| `lib/features/admin/reports/models/custom_report_template.dart` | CustomReportTemplate |

### Key Services
| File | Service |
|------|---------|
| `lib/features/auth/data/auth_service.dart` | AuthService (login, register, role, routing) |
| `lib/features/admin/roster/data/alumni_member_service.dart` | AlumniMemberService (CRUD, import, export) |
| `lib/features/events/data/event_service.dart` | EventService |
| `lib/features/events/data/event_rsvp_service.dart` | EventRsvpService |
| `lib/features/jobs/data/job_service.dart` | JobService |
| `lib/features/surveys/data/survey_service.dart` | SurveyService |
| `lib/features/forum/data/forum_service.dart` | ForumService |
| `lib/features/messages/data/message_service.dart` | MessageService |
| `lib/features/announcements/data/announcement_service.dart` | AnnouncementService |
| `lib/features/feedback/data/feedback_service.dart` | FeedbackService |
| `lib/features/notifications/data/notification_service.dart` | NotificationService |
| `lib/features/ai/data/ai_assistant_service.dart` | AiAssistantService (Gemini) |
| `lib/core/services/audit_service.dart` | AuditService |
| `lib/core/services/email_service.dart` | EmailService |
| `lib/core/services/ched_gts_export_service.dart` | ChedGtsExportService |

### Migrations & Edge Functions
| File | Purpose |
|------|---------|
| `supabase/migrations/20260716100001_phase1_schema_rls.sql` | Phase 1 schema + RLS |
| `supabase/migrations/20261005*_phase*.sql` | Database audit phases 1–7 (integrity, RLS, performance, GTS analytics, notifications, legacy cleanup) |
| `supabase/functions/send-email/index.ts` | Email delivery Edge Function |
| `supabase/functions/send-push/index.ts` | Push alert Edge Function |
| `supabase/functions/tracer-help/index.ts` | CHED GTS AI help Edge Function |

---

*Generated from source code analysis. Last updated: August 2026.*
