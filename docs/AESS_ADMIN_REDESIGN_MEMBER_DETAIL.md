# Alumni Member Detail (panel inside menu index 2) — Phases A–F

Date: 2026-10-14. Parent: [`AESS_ADMIN_REDESIGN_AUDIT.md`](AESS_ADMIN_REDESIGN_AUDIT.md) §8–§9 (step 3). Builds on Phase 0 ([0a](AESS_ADMIN_REDESIGN_PHASE0A_TOKENS.md), [0b](AESS_ADMIN_REDESIGN_PHASE0B_SHELL.md), [0c](AESS_ADMIN_REDESIGN_PHASE0C_COMPONENTS.md)), the closed [Dashboard](AESS_ADMIN_REDESIGN_DASHBOARD.md) and the closed [Alumni Directory](AESS_ADMIN_REDESIGN_DIRECTORY.md).

Scope: `AdminAlumniMemberDetailPanel` — header, three tabs (Profile info · Tracer responses · Activity logs), per-member CHED GTS PDF export and its pickers/dialog.

Evidence: **code inspection** of the files below, plus two live screenshots of the Phase E test record (unregistered member: Profile info and Activity logs tabs, 1366×768, `%TEMP%\aess_qa\e-detail.png`, `e-detail-logs.png`). **No registered member's detail was opened** — opening the panel writes to the database (see A3), and the QA policy so far avoids member detail views. Registered-member layouts (tracer sections, response snapshots, PDF export button) are described from code only.

---

## A1. Purpose and user

Admins open one roster entry to see: the official roster record; for registered alumni, the GTS tracer profile (general information, education, employment status) and photo; every submitted survey snapshot (official CHED GTS rendered as the read-only form); the member's audit history; and download a per-person auto-filled CHED GTS PDF. Typical tasks: verify identity/registration, check tracer completeness, review a submission, export the official form.

## A2. Files

| File | Role | LOC |
|---|---|---:|
| `features/admin/roster/presentation/admin_alumni_member_detail_page.dart` | Panel state, loading, mark-viewed, CHED PDF export flow, all three tabs; unused full-screen wrapper `AdminAlumniMemberDetailScreen` | 1,446 |
| `features/admin/roster/data/alumni_directory_detail_service.dart` | `loadDetail`, `markAdminViewed` | 114 |
| `features/admin/roster/widgets/alumni_directory_ui.dart` (from line 2158) | `MemberDetailSection`, `MemberDetailInfoRow`, `MemberDetailEmptyPanel` (used); `MemberDetailHeader`, `MemberDetailActivityTile`, `EmploymentStatusBanner` (**not used anywhere**) | ~700 of 2,871 |
| `features/admin/roster/presentation/admin_alumni_directory_page.dart` | Host: `_selectedMember` → panel replaces the whole page body (`ValueKey(member.id)`), `onMemberUpdated` keeps list/KPIs in sync | — |
| Shared: `admin_skeletons.dart` (`AdminMemberDetailSkeleton` → `FeedbackDetailSkeleton`, also used by Feedback detail), `admin_surface.dart` (`showAdminOptionPicker`), `surveys/ched_gts/ched_gts_form.dart` (`ChedGtsForm`, also used by the alumni wizard, admin survey preview and response detail), `ched_gts_pdf_export` | | |

## A3. Data and sources (must not change)

| Data | Source |
|---|---|
| Roster row | Passed in from the Directory; replaced by `loadDetail` result |
| Tracer profile, submitted responses, photo, audit logs (registered) | `loadDetail`: parallel `UserProfileService.getTracerProfile(uid)`, `SurveyService.getUserSubmittedResponses(uid)`, `users.profile_image_base64`, `AuditService.getRelatedAuditLogs(userId, 'AlumniMember', id)` |
| Audit logs (unregistered) | `getRelatedAuditLogs(userId: null, …)` — max **100** rows, errors return an empty list |
| Survey / questions for non-CHED snapshots | `SurveyService.getSurvey` / `getQuestions`, cached per panel |
| **Writes on open** | (1) `markAdminViewed` after first paint → `alumni_members.admin_viewed_at`, clears `has_profile_updates`; (2) if the tracer profile is complete but the roster flag is not → `tracer_profile_complete = true` |
| CHED PDF export | `ChedGtsPdfPersonExportService.buildOfficialPdf` (snapshot / merged / live fallback; print-ready or fillable) → web download → `logExportSuccess` / `logExportFailure` audit rows |

## A4. Interactions (all preserved in any redesign)

Header: **Close** (×, back to the list), **Download auto-filled CHED PDF** (registered + linked account only; "CHED PDF (web only)" off web; spinner while exporting), **Refresh**. Export flow: ≥ 2 CHED waves → wave picker (+ "Live profile only"); 1 wave → direct; 0 waves → "No CHED submission" confirm → live profile; then Print-Ready / Fillable picker; success/failure SnackBar. Tabs: Profile info (amber dot when tracer < 100 %), Tracer responses (count badge), Activity logs (count badge). Summary card: "N activities" chip jumps to the Activity tab. Tracer response cards expand (CHED → read-only `ChedGtsForm`; other surveys → question/answer list) with a per-wave "Auto-filled PDF" button. Error state "Could not load member details" + Try again.

## A5. Layout today

Panel = white card (radius 16, elevation 8) filling the Directory body; Directory header/KPIs/toolbar hidden. Rows: header (× · name + "Member details" · export · refresh) → full-width tab bar → tab content (ListView, padding 16).

- **Profile info, registered (code):** summary card (photo/initial, name, course · ID, email, chips "Profile updated / In app / Active · 7d / N activities") → amber "Some tracer profile fields are still missing." banner (if incomplete) → section "A. General Information" (11 rows) → "B. Educational Background" (3–4 rows) → "Employment Status" (1 row) → "Official roster record" (if extra roster fields). One label/value column, label width 110–120 px.
- **Profile info, unregistered (live, 1366):** summary card → large empty panel "Not registered in the app" with the roster record section nested inside it.
- **Tracer responses (code):** summary card → one expandable card per submission (CHED cards with orange accent bar and "Official CHED" tag).
- **Activity logs (live):** list of cards (status icon, raw action code, description, date · user · status). No summary card when logs exist.
- At 1366 the panel is ~1070 px wide (live screenshot); label/value rows and activity cards stretch the full width (value column ~900 px); at 1920 more so (code: no max width).

## A6. Problems and opportunities

**Functional defects (pre-existing — fixing needs approval):**

1. **Endless spinner on a failed question load.** Non-CHED snapshot: if `getQuestions` throws, the `FutureBuilder` never gets data and shows a spinner forever (no error branch).
2. **Refresh hides the header actions and gives no progress.** `_load` sets `_loading`; the header shows Export/Refresh only when `!_loading`, so both buttons disappear during a refresh (layout jumps), and the body keeps old data with no busy indicator (same pattern as Directory F5).
3. **Raw error text:** load error shows `e.toString()` (e.g. "Exception: …"); export failure SnackBar "CHED GTS PDF export failed: $e".
4. **Activity tab can't tell "none" from "failed":** `getRelatedAuditLogs` returns `[]` on error → "No activity recorded". Also silently capped at 100 rows (no note).
5. **Non-CHED fallback shows raw keys:** when a survey has no questions, answers are labelled with their stored keys (ids).

**Information / consistency:**

6. **Deactivated status not shown.** The panel has no "Deactivated" indication (Directory shows a badge; F2 now lets admins open deactivated rows).
7. **"Active · 7d" vs Directory "Active (30d)"** — different windows for the same word.
8. **Batch in the roster section uses `batchYear` only**; Directory uses `effectiveBatchYear` (falls back to year graduated). A member can show a Batch in the list and none in the detail.
9. **Tracer completeness only as an amber dot / generic banner.** `completionPercent` is loaded but never shown as a number; the banner doesn't say which fields are missing, and empty fields are hidden (`MemberDetailInfoRow` returns nothing for empty values), so the admin can't see what's missing.
10. **Name repeated up to four times** (panel header, summary card, "Name" row, "Roster name" row). Summary card appears on Profile and Tracer tabs, and on Activity only when it is empty.
11. **Section numbering:** "A. General Information", "B. Educational Background", then un-numbered "Employment Status".
12. **Activity logs show raw action codes** (`UPDATE_ROSTER_MEMBER`, `DELETE_ROSTER`) — readable labels would need a wording map (approval).
13. Loaded but not shown: tracer `completedAt`, roster `lastActiveAt` (only as a 7-day chip), `adminViewedAt`, `updatedAt`, `tracerProfileComplete`.
14. Two export entry points with different labels: header "Download auto-filled CHED PDF" vs card "Auto-filled PDF".

**Visual / design-system:**

15. Not on 0c components: header export (custom tonal `FilledButton`), Try again, per-wave button (vs `AdminButtonStyles`); tab bar (vs `AdminTabBar`); error/empty panels (vs `AdminStateView`); section titles 16 bold navy (vs `AdminText` / `AdminSectionHeader` 15); "No CHED submission" plain `AlertDialog`; SnackBars `Colors.green` / `Colors.red`.
16. Off-token colors: `Colors.grey.shade200/500/600`, `Colors.orange.shade200/800/900`, `Colors.red.shade300`, CHED orange literals `#FDBA74 / #C2410C / #FFF7ED`, shadow `#0F172A`, `#F8FAFC`, `Colors.white`.
17. Odd type sizes 13.5 / 12.5 / 10.5; mixed radii 16 / 12 / 10 / 8 / 6.
18. Wide-screen use: single label/value column ~900 px wide at 1366; empty panel for unregistered members is a large centered card with the roster record inside it (R7 label/value grid opportunity — two columns).
19. Amber tab dot is a color-only signal (no text/tooltip).
20. Skeleton is the Feedback detail skeleton (shape doesn't match this panel).

**Code health (note only, no change proposed without approval):** `MemberDetailHeader`, `MemberDetailActivityTile`, `EmploymentStatusBanner` and `AdminAlumniMemberDetailScreen` are unused.

## A7. Responsive notes (code)

No breakpoints inside the panel: it fills the Directory body at every width; tab bar full width; ListView padding 16. Label column fixed 110/120 px. Header export label is long ("Download auto-filled CHED PDF") next to a 1-line name — at narrow widths the name truncates first. Reference sizes 1366–1920 not yet measured live for a registered member.

## A8. Shared-component dependencies and risks

| Component | Other users | Risk if changed |
|---|---|---|
| `ChedGtsForm` | Alumni CHED GTS wizard, admin survey preview, admin response detail sheet | Must not change; panel only wraps it |
| `AdminMemberDetailSkeleton` / `FeedbackDetailSkeleton` | Feedback detail | Give Member Detail its own skeleton rather than editing the shared one |
| `showAdminOptionPicker` | Several admin screens | Use as is |
| `MemberDetailSection` / `InfoRow` / `EmptyPanel` | Member Detail only | Safe to restyle (feature-local) |
| `AlumniDirectoryDetailService` | Member Detail only | Do not change (writes on open) |
| Directory host (`_buildDirectoryBody`, `onMemberUpdated`) | Directory | Keep body replacement, `ValueKey`, update callback |

Other risks: write-on-open must stay exactly as is (post-frame, after load); no tests cover this panel today (Phase C would need widget tests with a fake detail, since the service talks to Supabase directly).

## A9. Decisions needed before Phase B

1. **Live QA of registered members:** opening a registered member's detail marks it viewed (clears "Profile updated") and may set the tracer-complete flag. Allow opening registered members' details during Phase D/E (screenshots kept local), or keep to code + test record only?
2. **Functional fixes 1–5:** include in the proposal (each separately approvable), or list as follow-ups?
3. **Information items 6–9 and 12** (deactivated badge, active-window wording, batch fallback, completeness %/missing fields, readable activity labels): include as approvable proposal items?
4. **Unused widgets** (code-health note): leave as is, or propose removal later?

**Owner answers (2026-10-14):** audit approved. (1) Opening registered members' details **allowed in Phases D/E** (screenshots kept local). (2) Functional fixes 1–5 go into the proposal, each separately approvable. (3) Information items 6–9 and 12 go into the proposal as approvable items. (4) Unused widgets left as is. **Phase B authorized** (proposal only).

---

## B. Proposal (2026-10-14) — approved in full, implemented in §C

### B1. Proposed layout (panel at 1366×768 and up, ~1070 px wide)

```
┌ Header (summary moves here; ~88 px) ─────────────────────────────────────┐
│ ×  (photo) Juan Miguel Santos                  [Download CHED GTS PDF] ⟳ │
│            BSIT · ID 2023304878 · Batch 2027 · phlarbauj@gmail.com       │
│            [Registered] [Active (30d)] [Tracer 93%] [Profile updated]    │
├ Profile info | Tracer responses (2) | Activity logs (12)   (AdminTabBar) ┤
│ ⓘ Tracer profile 93% complete — missing: Telephone number                │
│ ┌ A. General Information ───────────┐ ┌ B. Educational Background ─────┐ │
│ │ Name            Juan M. Santos    │ │ Degree …        BSIT           │ │
│ │ Permanent addr. …                 │ │ College …       USTP           │ │
│ │ Telephone       Not provided      │ │ Year graduated  2027           │ │
│ │ …                                 │ └────────────────────────────────┘ │
│ │                                   │ ┌ Employment Status ─────────────┐ │
│ │                                   │ └────────────────────────────────┘ │
│ └───────────────────────────────────┘ ┌ Official roster record ────────┐ │
│                                       └────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
```

- The summary card (photo, course · ID, email, chips) moves **into the panel header**, shown once for all tabs (today it repeats on Profile/Tracer and is missing on Activity). "Member details" subtitle is replaced by the course · ID · batch · email line.
- Profile sections in **two columns** when the tab content is ≥ 900 px wide (A on the left; B, Employment, Roster record stacked on the right); one column below.
- **Unregistered member:** header chip "Not registered"; Profile tab shows a slim info banner ("Not registered in the app — tracer data appears after the alumni registers and completes onboarding.", same text) and the **Official roster record** section as a normal section (no longer nested inside a large empty card).
- Tracer responses and Activity tabs start directly with their content.

### B2. CURRENT DATA → CURRENT COMPONENT → PROPOSED COMPONENT

| Data | Current | Proposed |
|---|---|---|
| Name, photo, course · ID, email | Panel header (name) + summary card per tab | Panel header only (name 16/w700, details line `AdminText.caption`) |
| Profile updated / In app / Active / N activities | `_InlineStatusChip` in summary card | Same chips in header (`AdminTableBadge`-style, token colors); "N activities" still jumps to the Activity tab |
| Tracer completeness | Amber dot on tab + generic banner | Header chip "Tracer N%" + banner naming missing fields (I4) |
| CHED PDF export | Tonal `FilledButton` "Download auto-filled CHED PDF" | `AdminButtonStyles.outlined()` "Download CHED GTS PDF" (W1); same flow, pickers and dialog |
| Refresh | `IconButton`, hidden while loading | Always visible; spinner while refreshing (FX2) |
| Tabs | Material `TabBar` + local badge | `AdminTabBar` (0c) with counts; left-aligned |
| Profile sections | `MemberDetailSection` (radius 16, shadow, 16 bold navy) + `MemberDetailInfoRow` (label 110/120 px, grey shades) | Same widgets restyled: radius 12, `AdminColors.border`, no shadow, title `AdminText.sectionTitle` (15), label 160 px `textSecondary` 13, value `textPrimary` 14; empty required values show "Not provided" (muted) instead of disappearing (I4) |
| Unregistered / no tracer | `MemberDetailEmptyPanel` (large card) | Slim info banner + roster section (same texts) |
| Tracer response cards | Custom container, literals, 13.5 / 10.5 sizes | Tokens (radius 12, `AdminColors.border`/`surface`), sizes 14 / 11; **CHED orange accent kept** (same literals as Surveys/Reports — revisit in the Surveys phase); per-wave button "Download PDF" (W2) |
| Read-only CHED form | `ChedGtsForm` | Unchanged (shared) |
| Activity logs | One card per entry, raw action code | Compact rows inside one bordered card, readable label (I5) with the code in a tooltip; description, time, user, status unchanged; note "Showing the latest 100 entries" when 100 (FX4) |
| Load error | Custom column with raw `e.toString()` | `AdminStateView.error` with friendly message, raw text under "Details" (FX3) |
| Empty tabs | `MemberDetailEmptyPanel` | `AdminStateView.empty` (same titles/messages) |
| "No CHED submission" | Plain `AlertDialog` | `showAdminConfirmDialog` (same title, message, labels) |
| SnackBars | `Colors.green` / `Colors.red` | `AdminColors.success` / `danger`; failure text friendly (FX3) |
| Loading | `AdminMemberDetailSkeleton` (Feedback shape) | New feature-local `MemberDetailSkeleton` (header + tabs + two columns); shared skeleton untouched (Feedback keeps it) |
| Panel surface | Material elevation 8, shadow `#0F172A` | `AdminSurfaces.card()` look (radius 16, border, `cardShadow`) |

### B3. Shared components

**None changed.** Reused as is: `AdminTabBar`, `AdminStateView`, `AdminButtonStyles`, `AdminText`, `AdminColors`/`AdminSurfaces`, `showAdminConfirmDialog`, `showAdminOptionPicker`, `ChedGtsForm`. `MemberDetailSection` / `InfoRow` / `EmptyPanel` are feature-local (only this panel uses them). `AdminMemberDetailSkeleton` stays for Feedback.

### B4. Functional fixes (each separately approvable)

| # | Fix | Detail |
|---|---|---|
| FX1 | Endless spinner on failed question load | Show "Couldn't load this survey's questions." + **Try again** (clears that cached future); CHED form path unchanged |
| FX2 | Refresh keeps actions | Header Export/Refresh stay visible while reloading; Refresh shows a spinner; Export disabled during refresh; body keeps showing current data |
| FX3 | Friendly errors | Load: "Couldn't load this member's details. Check your connection and try again." (raw text in expandable Details). Export failure SnackBar: "Couldn't create the CHED GTS PDF. Try again." — `logExportFailure` still records the raw error |
| FX4 | Activity tab limits | Note "Showing the latest 100 entries" when 100 rows are returned. **Telling "failed" from "none" is not proposed** — `AuditService.getRelatedAuditLogs` (shared core service) swallows errors; changing it is a service change (listed in B13) |
| FX5 | Raw answer keys | When a survey's questions are unavailable, label each answer "Answer N (question no longer available)" with the stored key in a tooltip |

### B5. Information items (each separately approvable)

| # | Item | Proposal |
|---|---|---|
| I1 | Deactivated not shown | Header chip "Deactivated" (danger colors), same rule as the Directory badge (`isDeactivated`) |
| I2 | "Active · 7d" vs Directory 30d | Use the Directory window: chip "Active (30d)" (registered + last active ≤ 30 days). Alternative: keep 7 days, label "Active (7d)" |
| I3 | Batch fallback | Roster section and header use `effectiveBatchYear` (batch, else year graduated) — same as the Directory |
| I4 | Completeness | Header chip "Tracer N%" (loaded `completionPercent`, rounded); banner lists missing required fields using the same field list as `TracerProfile.requiredFieldKeys`, labels from `GtsConstants`; required fields that are empty show "Not provided" in their section. Display only — no calculation or stored value changes. If the stored percentage and the live field check disagree, the % shown is the stored one (as today) |
| I5 | Readable activity labels | Display `UPDATE_ROSTER_MEMBER` as "Update roster member" (generic: underscores → spaces, sentence case); original code in a tooltip; no mapping table, stored data unchanged |

### B6. Wording — requires approval

- W1 Header export: "Download auto-filled CHED PDF" → **"Download CHED GTS PDF"** (off web: "CHED PDF (web only)" unchanged).
- W2 Per-wave button: "Auto-filled PDF" → **"Download PDF"**.
- W3 Header subtitle "Member details" → course · ID · batch · email line (information already in the summary card).
- Section letters kept: "A. General Information" / "B. Educational Background" mirror the official CHED GTS form; "Employment Status" stays unlettered (audit item 11 — no change recommended).

### B7. Potential content simplification — requires approval

- S1 Name appears 4 → 3 times (summary card merged into header). The GTS "Name" row and "Roster name" stay (they can differ). Recommend: accept.

### B8. Unchanged functionality

All loads and writes in A3 (incl. mark-viewed after first paint and the tracer-complete sync), CHED PDF flow (wave picker, live-only option, no-submission confirm, print-ready/fillable picker, web guard, success/failure logging), tab order and counts, "N activities" → Activity tab, Close, Directory body replacement, `ValueKey`, `onMemberUpdated`, `ChedGtsForm` rendering, survey/question caching.

### B9. Responsive behavior

1366–1920: two-column Profile; header on one row with chips wrapping under the details line. < 900 px tab content: one column. Header at < 700 px: export button shows icon only (tooltip keeps the full label). No new breakpoints beyond the 900 px column switch (= existing `AdminDensity.desktopSplitMin`).

### B10. Risks

- Moving the summary into the header must keep the "N activities" tap and the active/updated chips in sync after mark-viewed (`_member` update).
- Showing "Not provided" rows makes registered profiles longer when incomplete (intended — I4).
- No tests exist; the panel builds its service internally (Supabase). Plan: extract stateless pieces (header, profile sections, activity row, completeness banner) and widget-test them with sample `AlumniMember` / `TracerProfile` / `AuditLog` data; the stateful flow is verified live in D/E (registered members allowed).
- QA writes: opening details marks members viewed (owner-allowed for D/E).

### B11. Usability rationale

One header with identity and status for every tab; faster scanning with two columns on laptop screens; the admin sees exactly which tracer fields are missing; status words match the Directory; errors explain what to do; no endless spinners or disappearing buttons.

### B12. Files expected to change in Phase C (if approved)

`roster/presentation/admin_alumni_member_detail_page.dart` (layout, states, fixes), `roster/widgets/alumni_directory_ui.dart` (Member Detail widgets restyle + new local header/banner/activity row/skeleton). New tests: `test/admin_member_detail/`. No shared, service, model or schema files.

### B13. Future UX / feature recommendations (not proposed)

`AuditService` option to report load failures (shared service change); copy buttons for email/ID; jump from a tracer response to Survey Responses; Activity tab filters/paging beyond 100; showing tracer `completedAt` once it is populated (`TracerProfile.fromSupabaseRow` sets it to null today).

**Owner decision (2026-10-14):** all items approved — base layout B1/B2, FX1–FX5, I1–I5 (I2 = "Active (30d)"), W1–W3, S1. **Phase C authorized.**

---

## C. Implementation (2026-10-14)

Evidence: code + widget tests + `flutter analyze` / `flutter test`. **No live run yet** (Phase D).

### C1. What changed

| Item | Implementation |
|---|---|
| Panel surface | White card, radius 16, `AdminColors.border`, `AdminSurfaces.cardShadow` (was Material elevation 8) |
| Header (B1, S1, W3) | New `MemberDetailPanelHeader`: close · photo (48 px, green dot when active) · name 16/w700 · details line "course · ID … · Batch … · email" (empty parts skipped) · chips. Shown for all tabs and while the first load runs; summary card removed |
| Header chips | Deactivated (danger) **or** Registered (info) **or** Not registered (warning); Active (30d); Tracer N%; Profile updated; "N activities" (tap → Activity tab, tooltip "Open activity logs") |
| Tabs | `AdminTabBar` (left-aligned) with counts for Tracer responses / Activity logs; amber dot replaced by the header Tracer chip |
| Profile (registered) | `MemberDetailColumns`: A. General Information left; B. Educational Background, Employment Status, Official roster record right (≥ 900 px tab width); one column below |
| Profile (unregistered / no tracer profile) | `MemberDetailNotice` with the existing title and text + Official roster record as a normal section (left column at ≥ 900 px) |
| Sections / rows | `MemberDetailSection` restyled (radius 12, border, no shadow, `AdminText.sectionTitle`); `MemberDetailInfoRow` label 160 px `textSecondary` 13, value `textPrimary` 14, label stacks above value when the row is < 360 px; new `emptyText` option |
| Tracer responses | Cards on tokens (radius 12, sizes 14 / 11); CHED accent colors unchanged; expanded area `AdminColors.background`; empty states → `AdminStateView.empty` (same texts) |
| Activity logs | `MemberDetailActivityList`: one bordered card, compact rows (status icon, readable label, description, "date · user", status) |
| Loading | New feature-local `MemberDetailSkeleton` (two-column cards); shared `AdminMemberDetailSkeleton` untouched (Feedback still uses it) |
| Load error | `AdminStateView.error`: title "Could not load member details" (unchanged), message "Check your connection and try again.", raw text under "Show details", Try again |
| "No CHED submission" | `showAdminConfirmDialog` (same title, message, "Cancel" / "Export live profile") |
| SnackBars | `AdminColors.success` / `danger` |
| FX1 | Question load failure → compact error "Couldn't load this survey's questions." + Try again (drops that cached future and reloads) |
| FX2 | Export and Refresh stay visible during refresh; both disabled; Refresh shows a spinner (tooltip "Refreshing…"); body keeps current data |
| FX3 | Export failure SnackBar "Couldn't create the CHED GTS PDF. Try again."; `logExportFailure` still records the raw error |
| FX4 | "Showing the latest 100 entries" above the list when 100 rows are returned |
| FX5 | Questions unavailable → "Answer N (question no longer available)", stored key in a tooltip |
| I1–I3 | Deactivated chip; 30-day active window (same as Directory); `effectiveBatchYear` in header and roster section |
| I4 | Header "Tracer N%" (stored/loaded `completionPercent`, rounded); banner "Tracer profile N% complete" + "Missing: …" (GTS labels for `TracerProfile.missingRequiredKeys`; falls back to the old sentence if none are found); required empty fields show "Not provided" |
| I5 | `memberDetailActionLabel`: underscores → spaces, sentence case; raw code in a tooltip |
| W1 / W2 | "Download CHED GTS PDF" (`AdminButtonStyles.outlined`; icon-only with tooltip when the header is < 700 px) / "Download PDF" |

### C2. Judgment calls (for owner review)

1. **"In app" chip → "Registered" / "Not registered"**, following the B1 sketch and the Directory badges.
2. **Acronyms in activity labels** stay upper case (fixed list: CHED, GTS, PDF, DSS, FCM, SMS, ID) so `EXPORT_CHED_GTS_PDF` reads "Export CHED GTS PDF", not "Export ched gts pdf". Not a per-action mapping table.
3. **Load-error wording** split into title (existing) + message, instead of one sentence.
4. **Birthday row** now always shown ("Not provided" when empty); before it was hidden when missing — part of I4.
5. **Roster section for registered members** appears when only a year graduated exists (rule now uses `effectiveBatchYear`, I3).
6. **"N activities"** keeps its existing wording (e.g. "1 activities"); not changed without approval.
7. `MemberDetailEmptyPanel` is now unused; left in place (owner: leave unused widgets).

### C3. Unchanged (verified by reading the diff)

`_load` / `loadDetail` / `markAdminViewed` (post-frame) / tracer-complete sync, `didUpdateWidget` reset, survey/question caches, the whole CHED export flow (wave picker, live-only option, mode picker, web guard, download, success/failure logging, success SnackBar text), tab order, Close, `onMemberUpdated`, `ChedGtsForm` usage, `AdminAlumniMemberDetailScreen`. No service, model, schema or shared-widget file changed.

### C4. Files

- `roster/presentation/admin_alumni_member_detail_page.dart` (rewritten presentation; logic as above)
- `roster/widgets/alumni_directory_ui.dart`: `MemberDetailSection` / `MemberDetailInfoRow` restyled; new `MemberDetailChip`, `MemberDetailPanelHeader`, `MemberDetailNotice`, `memberDetailMissingTracerLabels`, `MemberDetailCompletenessBanner`, `MemberDetailColumns`, `memberDetailActionLabel`, `MemberDetailActivityList`, `MemberDetailAnswerList`, `MemberDetailSkeleton`
- New tests: `test/admin_member_detail/member_detail_widgets_test.dart` (20)

### C5. Tests

| Command | Result |
|---|---|
| `flutter test test/admin_member_detail` | 20 passed: header details line + batch fallback + all chips; 30-day window (20 d shown, 40 d hidden); deactivated / not registered; activities chip tap; no overflow at 320 / 768 / 1366; missing-field labels; banner text + fallback; "Not provided" rows; narrow label stacking; two-column switch at 900 px; action labels incl. acronyms; activity rows + raw-code tooltip + 100-limit note; answers by prompt / by position with key tooltip / empty |
| `flutter analyze` (admin scope + admin test folders incl. `test/admin_member_detail`) | 19 info, all pre-existing; changed files and new tests: no issues |
| `flutter test` (full suite) | 945 passed (925 + 20), 3 skipped, 0 failed |

Found while testing: header chips could overflow a very narrow header (test font) — chip text now ellipsizes.

**Not verified yet (Phase D/E):** live rendering at 1366–1920, registered members, the stateful panel flow (load, refresh, mark-viewed, export pickers), CHED form inside the new cards.

**Owner decision (2026-10-14):** Phase C accepted, including all §C2 judgment calls. **Phase D authorized.**

---

## D. Responsive QA (2026-10-14, live)

Setup: `flutter build web --release` of the current tree, served locally (127.0.0.1:8085), headless Chrome driven over the DevTools protocol, live Supabase, existing `admin@gmail.com` session (no new sign-in). Screenshots kept locally (`%TEMP%\aess_qa\md-d-*.png`), not in the repo.

Members opened: **Juan Miguel Santos, Catherine Jala, Ralph Jezron A. Juab** (registered) and **Christian Pedregosa** (not registered). Ralph has 5 submissions (3 CHED, 2 other surveys) and 100 activity rows, so he covers the response cards and the 100-row note.

### D1. Viewports

| Size | Result |
|---|---|
| 1920×1080 | Two columns; header on one row; no overflow. Space below the cards (content shorter than the panel) |
| 1600×900 | Two columns; no overflow |
| 1440×900 | Two columns; no overflow |
| 1366×768 | Two columns; header (name, details line, chips, Download CHED GTS PDF, Refresh) on one row; Tracer and Activity tabs; no overflow |
| 1024×768 | Sidebar collapses (shell behaviour) → panel < 900 px → one column, as designed; no overflow |
| 768×1024 | One column; export button icon-only (header < 700 px); no overflow |

### D2. Interactions checked (1366×768 unless noted)

| Check | Result |
|---|---|
| Header details line + chips (registered: Registered · Active (30d) · Tracer 100% · N activities; unregistered: Not registered · 1 activities) | Pass |
| Batch shown from roster (2027) in header and roster section | Pass |
| Tabs (shared tab bar) with counts 5 / 100 / 8 / 7 / 1 | Pass |
| "N activities" chip → Activity tab | Pass |
| Activity rows: readable labels (Login, Logout, Complete onboarding, Register, Create roster member); hover shows the raw code (e.g. `LOGOUT`) | Pass |
| "Showing the latest 100 entries" (Ralph, 100 rows) | Pass |
| Tracer responses: CHED cards (orange accent, "Official CHED", "Download PDF"); expanding one shows the read-only CHED form with the accent bar stretching; "Test 2" survey shows its questions and answers | Pass |
| Empty states (No submitted surveys; No tracer responses for unregistered) | Pass |
| Unregistered Profile: slim notice + roster record at half width | Pass |
| Refresh (FX2): buttons stay, export disabled, spinner on Refresh, data stays visible | Pass |
| Header export with 0 CHED submissions → shared "No CHED submission" dialog (same text) → Cancel | Pass; nothing exported |
| Header export with 3 CHED submissions → "Choose CHED GTS wave" (3 waves + Live profile only) → Esc | Pass; nothing exported |
| Load error (FX3): network switched off in the QA browser, Refresh → after ≈ 45 s "Could not load member details / Check your connection and try again." + Try again + Show details; network on → Try again reloads | Pass |
| Close (×) returns to the list (several times) | Pass |

### D3. Findings

1. **Header chips stay during a load error.** After a failed refresh the header still shows Tracer % and "N activities" (and the tabs their counts) from the last successful load, while the body shows the error. Before the redesign the tab counts behaved the same; the summary card was hidden. Options: keep, or hide the loaded-data chips while the error is shown.
2. **Long GTS labels wrap** onto two lines in the 160 px label column ("Telephone or Contact Number(s)", "Degree(s) & Specialization(s)", "Honor(s) or Award(s) Received") at every size. Readable; a wider column (≈ 200 px) would keep them on one line but narrows values.
3. Offline failure takes ≈ 45 s to appear (network client timeout; unchanged behaviour). The Refresh spinner is visible the whole time.

### D4. Not tested live

- Incomplete tracer profile (banner with missing fields, "Not provided" rows, amber Tracer N% chip): no member with an incomplete profile — widget tests only.
- Deactivated chip: no deactivated members — widget test only.
- "Profile updated" chip: no member had pending updates.
- FX1 (question load failure) and FX5 (answers without questions): not reproducible with current data — FX5 widget-tested; FX1 code inspection only.
- Actual PDF download, export-mode picker and success/failure SnackBars: not run (read-only; pickers cancelled).

### D5. Data written

Opening the four details ran the existing write-on-open (`admin_viewed_at` set; `has_profile_updates` already false). No other writes; nothing exported, edited or deleted. No new sign-in.

**Owner decisions (2026-10-14):** D3.1 hide the loaded-data chips while a load error is shown; D3.2 keep the 160 px label column. Phase E stays **read-only** (no real PDF export). Apply D3.1, quick re-check, then Phase E.

### D6. Follow-up fix

- `admin_alumni_member_detail_page.dart`: while `_error` is set, the header gets no Tracer % and no activity count (chips hidden). Tab counts unchanged.
- Re-check: `flutter analyze lib/features/admin/roster test/admin_member_detail` no issues; `flutter test test/admin_member_detail test/admin_directory` 51 passed; release rebuild; live (1366×768, Juan): offline Refresh → error with only Registered · Active (30d) chips; network on → Try again restores Tracer 100% · 8 activities.

---

## E. Functional regression (2026-10-14, live, read-only)

Same live setup as D (rebuilt after D6, service worker cleared). No PDF downloaded (owner: read-only).

### E1. Results

| Check | Result |
|---|---|
| Open detail from the list (registered and unregistered) | Pass |
| Data matches the Directory row (batch, registration, active, tracer) for all four members | Pass |
| Tabs and counts (Juan 0 / 8, Catherine 0 / 7, Ralph 5 / 100, Christian 0 / 1) | Pass |
| Switching members (Juan on Activity tab → close → Ralph) resets to Profile with Ralph's data | Pass |
| Export, 0 CHED submissions (Juan): "No CHED submission" → Export live profile → Print-Ready / Fillable picker → Esc | Pass; nothing downloaded, no SnackBar |
| Export, 3 submissions (Ralph): wave picker → first wave → mode picker → Esc | Pass |
| Export, Ralph: wave picker → Live profile only → mode picker → Esc | Pass |
| Per-wave "Download PDF" (Ralph, first CHED card) → mode picker → Esc | Pass |
| Expand CHED (read-only form) and non-CHED (questions + answers) submissions | Pass (D2) |
| Refresh: busy state, same data afterwards | Pass (D2) |
| Load error + Try again; chips hidden during error | Pass (D2, D6) |
| Close → list unchanged (KPIs 8 / 3 / 5 / 3, 8 rows) | Pass |
| `flutter test` (full suite, final code) | 945 passed, 3 skipped, 0 failed |
| `flutter analyze` (admin scope + admin test folders) | 19 info, all pre-existing; none in Member Detail files |

### E2. Not tested live

- Real PDF download (both modes), success / failure SnackBars and the `EXPORT_CHED_GTS_PDF` audit rows — owner kept E read-only; code path unchanged (C3).
- "Profile updated" → cleared after viewing and the list sync via `onMemberUpdated` — no member had pending updates (code unchanged).
- Incomplete tracer, deactivated member, failed question load, answers without questions — no such data (widget tests for all but the failed question load).
- Non-web "CHED PDF (web only)" label — web build only.

### E3. Data written

Existing write-on-open only (`admin_viewed_at` for Juan, Catherine, Ralph, Christian; repeated opens in D and E). Nothing exported, created, edited or deleted. No new sign-in. QA server and Chrome stopped.

**Owner decision (2026-10-14):** E reviewed; **Phase F authorized** (completion report).

---

## F. Completion report (2026-10-14) — signed off by owner 2026-10-14 (screen closed)

**Screen:** Alumni Member Detail panel (inside the Alumni Directory, menu index 2) — header, Profile info · Tracer responses · Activity logs tabs, per-member CHED GTS PDF export entry points and their dialogs.

### F1. Files changed

| File | Scope |
|---|---|
| `lib/features/admin/roster/presentation/admin_alumni_member_detail_page.dart` | Presentation rewritten (header, shared tab bar, two-column Profile, notices, response cards, activity list, states); FX1–FX5; chips hidden during a load error (D6). Load, mark-viewed and export logic unchanged |
| `lib/features/admin/roster/widgets/alumni_directory_ui.dart` | `MemberDetailSection` / `MemberDetailInfoRow` restyled (+ `emptyText`); new Member Detail widgets (C4) |
| `test/admin_member_detail/member_detail_widgets_test.dart` (new) | 20 tests |

No shared component, service, model, schema, route or Directory-list file changed.

### F2. Components reused / created

- **Reused (0c / existing):** `AdminTabBar`, `AdminStateView` (empty / error / loading), `AdminButtonStyles.outlined`, `showAdminConfirmDialog`, `showAdminOptionPicker`, `AdminColors` / `AdminSurfaces` / `AdminText`, `ChedGtsForm` (unchanged), `Skeleton` / `ShimmerScope`.
- **Created (feature-local):** `MemberDetailPanelHeader`, `MemberDetailChip`, `MemberDetailNotice`, `MemberDetailCompletenessBanner`, `memberDetailMissingTracerLabels`, `MemberDetailColumns`, `MemberDetailActivityList`, `memberDetailActionLabel`, `MemberDetailAnswerList`, `MemberDetailSkeleton`.
- **Shared components changed:** none. `AdminMemberDetailSkeleton` left for Feedback.

### F3. UI/UX changes

One header for every tab (photo, name, course · ID · batch · email, status chips, export, refresh); summary card removed (name shown 3× instead of 4×); shared tab bar with counts; two-column Profile at ≥ 900 px; slim notice for unregistered / no-profile members; tracer completeness as a chip plus a banner naming missing fields, "Not provided" for empty required fields; Deactivated chip; "Active (30d)" (Directory window); batch falls back to year graduated; compact activity rows with readable labels and the raw code on hover; "Showing the latest 100 entries" note; response cards on tokens with the CHED accent kept; shared empty / error / confirm components; friendly error texts; "Download CHED GTS PDF" / "Download PDF".

### F4. Responsive

1920 / 1600 / 1440 / 1366: two columns, header on one row. 1024 (sidebar collapsed): one column. 768: one column, icon-only export. Narrow rows stack label above value (< 360 px). Only new breakpoint values: 700 px (header export icon-only) and 360 px (row stacking); the column switch uses the existing `AdminDensity.desktopSplitMin` (900).

### F5. Functionality preserved

`loadDetail` (tracer, responses, photo, audit logs), write-on-open (`markAdminViewed` post-frame, tracer-complete sync), `onMemberUpdated`, `ValueKey` reset, survey/question caching, the full CHED export flow (wave picker, live-only option, no-submission confirm, Print-Ready/Fillable picker, web guard, download, success/failure logging and success text), tab order, "N activities" → Activity tab, Close. Approved behavior changes: FX1 retry for failed question loads, FX2 refresh keeps actions, FX3 friendly errors, FX4 100-row note, FX5 readable fallback answer labels, I1–I5 information changes, D6 chips hidden during a load error.

### F6. Tests actually performed

- `flutter test test/admin_member_detail`: 20 passed.
- `flutter test` (full suite, final code): **945 passed, 3 skipped, 0 failed**.
- `flutter analyze` (admin scope + admin test folders): 19 info, all pre-existing; Member Detail files and tests: **no issues**.
- Live browser QA (§D): 6 viewports; 3 registered + 1 unregistered member; offline error + retry.
- Live read-only regression (§E): data vs Directory, tab counts, member switching, all four export entry paths up to the mode picker (cancelled), list unchanged after close.

### F7. Issues found / remaining

- Not verified live (§D4, §E2): real PDF download + its SnackBars and audit rows (owner kept QA read-only); "Profile updated" clearing and list sync; incomplete tracer profile, deactivated member, failed question load, answers without questions (no such data — widget tests, except the failed question load: code inspection only).
- Long GTS labels wrap in the 160 px label column (kept by owner).
- Offline failure appears after ≈ 45 s (existing client timeout).
- Tab counts still show last-loaded values during a load error (as before the redesign).
- `MemberDetailEmptyPanel`, `MemberDetailHeader`, `MemberDetailActivityTile`, `EmploymentStatusBanner`, `AdminAlumniMemberDetailScreen` unused (left in place per owner).
- Future items: §B13 (AuditService failure reporting, copy buttons, link to Survey Responses, activity paging/filters beyond 100, tracer `completedAt`).

### F8. Approved deviations / judgment calls

§C2 (all accepted): "Registered" / "Not registered" instead of "In app"; acronyms kept upper case in activity labels; load-error wording split into title + message; Birthday row always shown; roster section shown when only year graduated exists; "N activities" wording unchanged. §D6: loaded-data chips hidden during a load error.

**Owner decision (2026-10-14):** Member Detail **signed off as implemented** — screen closed. Surveys Phase A audit authorized.
