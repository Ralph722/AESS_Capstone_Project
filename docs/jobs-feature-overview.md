# AESS Jobs Feature — Full Overview

University career board (not ATS). Sourced from Flutter/Supabase  
(`lib/features/jobs/`, `lib/features/admin/jobs/`, home / archives / notifications).

---

## 1. What this feature is

Jobs is a **careers bulletin board**:

- **Admins** create/edit jobs (logo, category, program targeting, external apply URL), archive/restore/delete, view interested alumni, export CSV, see lightweight insights.
- **Alumni** browse active jobs, **Recommended** (program overlap), mark **Interested**, **Favorite**, open details (mailto / apply externally).
- Notifications: new job (all or targeted by program), updates/restores to interested+favorited, deadline reminders (3d/1d) on Home/Jobs open.
- **Out of scope:** ATS, resumes, interviews, employer portals, ML matching.

---

## 2. Entry points

### Admin
| Entry | Detail |
|--------|--------|
| Sidebar | **Careers → Job Postings** |
| Quick Action | **Post New Job** |
| Dashboard | Jobs KPI → Job Postings |
| Notifications | Type `job` → Job Postings |
| Archives | **Archives → Job Postings** (restore notifies interested/favorited) |

### Alumni
| Entry | Detail |
|--------|--------|
| Bottom nav | **Jobs** tab |
| Home | Featured jobs (logo + category) → Jobs tab; deadline reminders on load |
| Notifications | Type `job` → Jobs tab (listing; no deep-link to a specific job yet) |

---

## 3. Admin Job Postings

**File:** `lib/features/admin/jobs/presentation/admin_job_management_page.dart`  
**Chrome:** Directory-aligned (`AdminPageHeader`, `DirectoryStatsGrid`, `DirectoryToolbarCard`).

### Layout
1. Header — **Post new job**
2. KPIs — Total · Active · Expired · Archived · Interested (sum) · Avg interest/job
3. Toolbar — search + filters (status, category, type, experience, remote, sort) + reset
4. Cards — logo, company, title, category, type, location, remote, experience, salary, deadline, status, posted; Views / Interested / Favorites
5. Actions — Edit · Details drawer · Interested (N) · Archive/Activate · Delete
6. Pagination (20/page)
7. Quick insights — most viewed, most interested, by category, top companies

### Interested Alumni drawer
Avatar, name, course, batch, employment, email, interested date; search; sort A–Z / newest; Send Message (`MessageOpenBus`); **Export CSV**.

### Create / Edit (`AddJobDialog`)
Sections: General · Company (+ logo upload) · Details · Requirements / Benefits · Application (email + optional URL) · Targeting (multi-select course codes).

Validation: requireds, email format, deadline ≥ today on create, salary non-empty.

On create: upsert → `notifyNewJob` (all if no targets; else matching programs).  
On update: `notifyJobUpdated` (interested + favorited).  
On restore (admin or Archives): `notifyJobRestored`.

---

## 4. Alumni Jobs board

**File:** `lib/features/jobs/presentation/job_posting_page.dart`

- Sticky search / filter / sort bar (category, type, remote, recommended-only, saved)
- **Recommended for you** horizontal strip (program ∩ `targetPrograms`; fallback = latest openings)
- Cards: logo, title, company, category, salary, location, remote, deadline, posted; **View details** · **Interested** · **Favorite**; saved date when favorited
- Details sheet: Overview, Description, Requirements, Benefits, Contact (copy + mailto), Apply externally
- Pagination (20); empty states for no jobs / no results / no saved
- View count: incremented once per job per session when details open
- Auto-expire runs before listing so past-deadline jobs are not shown as active

---

## 5. Data model & storage

### Dart (`JobPosting`)
Core fields plus: `category`, `targetPrograms`, `applicationUrl`, `interestedCount`, `favoriteCount` (client-enriched).

New fields live primarily in **`jobs.data` JSON** with dual-write of title/company/location/description/status columns.

### Status
| Value | Meaning |
|--------|---------|
| `active` | Visible to alumni (if deadline not past) |
| `archived` | Hidden; Archives module |
| `expired` | Set automatically when `applicationDeadline` < now and was `active` |

### Tables
| Table | Role |
|--------|------|
| `jobs` | Postings |
| `favorite_jobs` | Saved bookmarks (`created_at` used for Saved polish) |
| `job_interests` | Interest roster (`user_id`, `job_id`, `created_at`) + RLS |

### Storage
Company logos: `images` bucket path `jobs/{jobId}/logo.jpg` via `ImageStorageService.uploadJobCompanyLogo`.

### Migration
`supabase/migrations/20260731120000_jobs_interests.sql`

---

## 6. Services / helpers

| File | Role |
|------|------|
| `job_service.dart` | CRUD, expire-on-read, view debounce, favorite counts |
| `job_interest_service.dart` | Toggle, counts, list alumni for job |
| `favorite_job_service.dart` | Favorites + saved dates stream |
| `job_recommendation.dart` | Pure program overlap (no AI) |
| `job_expiration.dart` | Deadline helpers |
| `job_deadline_reminders.dart` | Client reminders on Home/Jobs open |
| `notification_service.dart` | `notifyNewJob`, `notifyJobUpdated`, `notifyJobRestored`, `notifyJobDeadlineIfNeeded` |

---

## 7. Alumni vs admin

| Capability | Alumni | Admin |
|------------|--------|--------|
| Browse active | Yes | Yes (all statuses via filter) |
| Recommended | Yes | — |
| Interested | Yes | Roster + CSV export |
| Favorites | Yes | Counts on cards |
| Create / edit / logo | No | Yes |
| Archive / restore / delete | No | Yes |
| Insights / KPIs | No | Yes |
| Views | Increment on open | Shown on cards |

---

## 8. Process flows

### Create → notify → browse → interest
1. Admin posts job (optional targets + logo)  
2. Notifications to all or matching programs  
3. Alumni see Recommended / board; mark Interested / Favorite  
4. Admin opens Interested drawer / exports CSV  

### Expire
On admin list load and alumni `getActiveJobs`: past-deadline `active` → `expired`.

### Deadline reminders
On Home featured load and Jobs bootstrap: if deadline is in 1 or 3 days and user is interested ∪ favorited ∪ recommended match → insert notification (deduped).

---

## 9. Smoke checklist

- [ ] Create job with logo + category + target programs → alumni Recommended shows it  
- [ ] Interested toggle → admin drawer lists alumni → CSV export  
- [ ] Favorite → Saved filter shows saved date  
- [ ] Past deadline → status expired / hidden from alumni actives  
- [ ] Archive → restore → interested/favorited notified  
- [ ] Edit job → interested/favorited get update notification  
- [ ] Details: copy email, mailto, Apply externally when URL set  
- [ ] Home featured shows company logo  

---

## 10. Key files

```
lib/features/jobs/models/job_posting_model.dart
lib/features/jobs/models/job_interest_model.dart
lib/features/jobs/models/job_category_constants.dart
lib/features/jobs/data/job_service.dart
lib/features/jobs/data/job_interest_service.dart
lib/features/jobs/data/favorite_job_service.dart
lib/features/jobs/data/job_recommendation.dart
lib/features/jobs/application/job_expiration.dart
lib/features/jobs/application/job_deadline_reminders.dart
lib/features/jobs/widgets/job_ui.dart
lib/features/jobs/presentation/add_job_dialog.dart
lib/features/jobs/presentation/job_posting_page.dart
lib/features/admin/jobs/presentation/admin_job_management_page.dart
lib/features/admin/jobs/widgets/admin_job_ui.dart
lib/features/admin/archives/presentation/admin_archives_page.dart
lib/features/home/presentation/home_page.dart
lib/features/notifications/data/notification_service.dart
lib/features/messages/data/image_storage_service.dart
supabase/migrations/20260731120000_jobs_interests.sql
```
