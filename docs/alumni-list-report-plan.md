# Alumni List Report — Audit, Decisions and Implementation Plan

Status: **done** — all 7 phases complete (2026-10-14).

Progress:

- Phase 1 (list logic and tally): done. `GtsListConfig` +
  `GtsTracerStatus` (`models/gts_list_config.dart`), `GtsAlumniList.build`,
  `GtsListTally`, `GtsListGroup` (`application/gts_alumni_list.dart`); tests in
  `test/admin_reports/gts_alumni_list_test.dart` (tally = Tracer tab coverage
  funnel, Tracer tab employment rate and DSS not-employed rate).
- Phase 2 (columns and cell formatting): done. `GtsListColumns`
  (`application/gts_list_columns.dart`): 10 roster columns (batch, name,
  student ID, course, registration, email, contact number, tracer status, wave
  answered, date answered) and one column per CHED item (specify boxes merged
  as "Others: text"; only the exact "…please specify" choices are replaced).
  Cells: "Not asked" when the form hid the item, blank when skipped or
  untracked; multi-select joined with "; "; grids as "row (columns)"; table
  rows as "a | b | c" joined with "; ". "Wave answered" is always shown for
  latest-from-any-wave lists. Sorting works on any column (blanks and "Not
  asked" last). Tests in `test/admin_reports/gts_list_columns_test.dart`;
  answer shapes checked against demo data.
- Phase 3 (Builder UI): done. Builder tab opens on a mode switch
  (`gts_builder_mode_switch.dart`): "Alumni list" (default) or "Summary &
  charts" (unchanged builder). `GtsAlumniListPanel`
  (`widgets/gts_alumni_list_panel.dart`): wave or latest-from-any-wave,
  column list with drag-to-reorder and remove, column picker dialog (search,
  select all per section, personal-data icons), filters (tracer status,
  course, batch, CHED answers), sort column and direction, subtotals
  (overall / by batch / by course, shown as one tally column per group), chart
  (bars / donut / none). Preview: 200 rows at a time, untracked rows tinted,
  tally always in full. Responses load from `survey_responses`
  (`data/gts_list_data_service.dart`, existing admin RLS); the roster is the
  page's. Tally text in `application/gts_list_tables.dart` (shared with
  downloads). List batch now falls back to "year graduated" like the Tracer
  tab batch filter. List settings gained `chart` (additive JSON field). Tests
  in `test/admin_reports/gts_alumni_list_panel_test.dart`.
- Phase 4 (downloads): done. `GtsListExportService`
  (`data/gts_list_export_service.dart`): Excel (tabs "Alumni list" and
  "Columns" with each column's full question), CSV (`CsvSafe`, UTF-8 BOM) and
  PDF (A4 landscape, status chart, list capped at 1,000 rows with a note,
  small print and a note past 10 columns, RA 10173 footer on every page). All
  three print the same `GtsListTables` layout: about lines (wave, alumni,
  filters, order, generated, privacy notice), the list, one blank row, then
  the tally blocks (one per batch/course when subtotalled, overall last).
  Downloads ask for the existing personal-data confirmation first; the
  preview warns when a list is wider than 10 columns. Tests in
  `test/admin_reports/gts_list_export_test.dart` (CSV = Excel, PDF text).
- Phase 5 (templates and saved reports): done. Four ready-made lists
  (`application/gts_list_templates.dart`): employment status of all alumni,
  untracked alumni for follow-up, employed alumni job details, not employed
  with reasons; picked from "Start from a ready-made list" and editable
  afterwards (the chosen wave is kept). Saved lists use the existing
  `report_definitions` table (`mode: 'list'` in the config JSON; no
  database change). Open/save/save as new/delete moved into a shared
  `GtsSavedReportsBar` used by both modes; each mode lists both kinds and
  opening the other kind switches mode. Opening a list whose wave is gone
  uses the newest wave; missing columns are reported. Tests in
  `test/admin_reports/gts_list_saved_reports_test.dart`.
- Phase 6 (friendlier Summary & charts, clean-up): done. Settings now read:
  ready-made report cards, report name, tracer wave (one dropdown plus a
  "Compare waves" switch), 1. What do you want to know? (question picker by
  section with search), 2. Compare by (None / Course / Batch / Another
  question), 3. Only include (conditions written as sentences), 4. Show as
  (chart picture buttons, greyed out with the reason; Numbers: Percent or
  Number of graduates). "More options" (collapsed) holds the grid job,
  answer order, top-N, the median for bracket questions and a second
  split. The preview opens with one plain sentence describing the report
  (`GtsReportTables.sentence`). "Who to count" is gone: new reports and all
  six templates count roster-linked graduates (the "Employment type" and
  "Industry" templates previously counted every response). Older saved
  reports keep their settings (every response, share of those asked, share
  of all graduates, number of answers) with a note and a one-click switch,
  so their numbers do not change. Engine unchanged. Deleted the unused
  `custom_report_builder.dart` and `CustomReportTemplateService`; their
  export-service tests moved to
  `test/admin_reports/custom_report_export_service_test.dart`. Builder tests
  in `test/admin_reports/gts_report_builder_test.dart`.
- Phase 7 (QA and docs): done. Demo comparison (read-only, pseudonymised
  export, deleted afterwards): for each of the three demo waves and for
  latest-from-any-wave, the list tally (238 on the roster; answered,
  untracked registered / not registered, off-roster, employed / not /
  never) equals independent SQL counts, the Tracer tab coverage funnel and
  employment card, the DSS employment rate, and the Summary & charts
  employment template. All 46 columns on all 238 alumni format cleanly;
  CSV, Excel and PDF build at that size (PDF about 6 s in tests).
  `SYSTEM_DOCUMENTATION.md` describes both Builder modes, list saved
  reports and the new Summary settings. Full suite: 815 passed, 3 skipped;
  analyze: no issues in the reports area.

## 1. What the owner asked for

A custom report in which the admin picks any field from every section of the
CHED GTS (items 1–34, including names) as table columns, one row per alumnus.
Example: Batch, Name, item 16 "Are you presently employed?", item 19 "Present
occupation", and more as needed. The last rows of the table give the overall
tally: employed, not employed, never employed, and the **untracked** alumni who
did not answer. Untracked alumni are listed in the table too, so admins can see
who needs attention. The current Builder stays (templates and charts kept);
options that are no longer useful are removed.

## 2. Audit findings (2026-10-12)

- **The current Builder cannot produce this table.** It reads
  `gts_report_facts`, which strips the personal items (name, address, email,
  phone, birthday — items 1–5 and 8) and contains only people who submitted a
  tracer, so untracked alumni can never appear. Its output is always counts or
  percentages per group (`GtsReportEngine`), never one row per person; the
  validator deliberately rejects personal fields.
- **The data is already readable by admins under existing RLS.**
  - Roster (`alumni_members`): full name, student ID, course, batch, registered
    or not, email, contact number, linked account (`auth_uid`), deactivated.
  - Tracer answers (`survey_responses`, admin-or-owner policy), including
    personal items.
  - Sizes (2026-10-12): demo 238 active roster records (192 registered), 221
    submitted CHED responses over 3 waves, 0 responders off the roster; live 8
    roster records, 3 registered, 3 responses, 0 off the roster. Building the
    list in the browser is fine.
- **"Untracked" already has a definition.** `buildTracerCoverage`
  (`tracer_coverage.dart`) splits the active roster into not registered,
  registered without a tracer, and took the tracer. The new tally must use the
  same definitions so the Tracer tab and the list never disagree.
- **Nothing existing does this.**
  - CHED filing workbook (`ChedGtsExportService`): every item per person, but
    respondents only and fixed columns.
  - Old custom report (`custom_report_template.dart`,
    `custom_report_export_service.dart`): whole fixed sections (roster,
    employment records…), no per-field columns. Its builder screen
    `custom_report_builder.dart` (with `CustomReportTemplateService`,
    SharedPreferences) is not used anywhere — dead code. The export service is
    still used by the Downloads presets.
- **No database change is expected.** If one turns out to be needed, stop and
  report it before applying anything.

## 3. Decisions (owner, 2026-10-12)

| Topic | Decision |
|---|---|
| Untracked categories | Two: "Untracked – registered, not yet answered" and "Untracked – not registered" |
| Which answers | One wave at a time (newest by default), plus optional "latest answer from any wave" with a "Wave answered" column |
| Tally | Overall tally at the bottom, plus optional subtotals per batch or course |
| Clean-up | Simplify Summary & charts, and delete the unused old custom-report builder screen |
| Tracer status column | Added automatically to new lists; admin can move or remove it; tally always shown |
| Current Builder | Kept as "Summary & charts"; phase 6 makes its settings screen easier to use |

## 4. Design

### 4.1 Two modes in one Builder

- **Alumni list** (new): one row per alumnus, columns picked by the admin.
- **Summary & charts** (current Builder): counts, percentages and charts.

Both modes share templates and saved reports.

### 4.2 Who is in the list

Everyone on the **active roster** (deactivated records excluded, as on the
Tracer tab), within the batch/course filters. For the chosen wave, a person is
"tracked" if they submitted it (latest submission wins). In "latest answer from
any wave" mode, each person's newest submitted answer from any CHED wave is
used and a "Wave answered" column is added.

Anyone who answered without being on the active roster is listed on a separate
tally line, shown only if there are any (none on demo or live today).

### 4.3 Tracer status and tally

| Tally line | Who |
|---|---|
| Employed | Answered the wave, item 16 = Yes |
| Not employed | Item 16 = No |
| Never employed | Item 16 = Never Employed |
| Untracked – registered, not yet answered | Portal account linked to the roster, no answer for the wave |
| Untracked – not registered | On the roster, no portal account |
| **Total alumni** | Active roster in scope |
| Response rate | Answered ÷ total |
| Employment rate | Employed ÷ those who answered item 16 (the Tracer tab figure, = 100% − DSS not-employed rate) |

- Each line shows count and share of the total.
- If an answered response leaves item 16 blank (required, so not expected), it
  appears on an "Answered, status not given" line.
- The tally follows the filters. With "subtotals by batch/course", the same
  lines appear under each group, with the overall tally last.
- No existing metric is redefined; definitions match the Tracer tab coverage
  funnel and the DSS.

### 4.4 Columns

- **Alumni info (from the roster, works for untracked people too):** name,
  student ID, course, batch, registration status, email, contact number.
  Contact columns start unticked.
- **Every CHED item 1–34 by section** (A General, B Education, C Trainings,
  D Employment), including items 1–5 and 8 as answered in the tracer.
- **Tracer status** column added automatically to new lists (movable,
  removable).
- Picker: grouped by section, search box, select-all per section, reordering.
- Headers: CHED number + short label, e.g. "16. Presently employed?"; the full
  question wording goes in "About this report".

Cell rules:

- "Others (please specify)" text merged into the parent question's cell, e.g.
  "Others: Freelance".
- Multiple answers joined with "; ".
- Exams and trainings tables shown as short text.
- "Not asked" when the form never showed the question to that graduate
  (e.g. occupation when item 16 is No); blank when asked but left empty.
- Untracked rows: answer columns empty.
- Item 16 column holds only real CHED answers (never "Untracked").

### 4.5 Example

Columns picked: Batch, Name, item 16, item 19 (Tracer status added
automatically).

| Batch | Name | 16. Presently employed? | 19. Present occupation | Tracer status |
|---|---|---|---|---|
| 2023 | Juan Dela Cruz | Yes | AI engineer | Employed |
| 2023 | Maria Santos | No | Not asked | Not employed |
| 2024 | Pedro Reyes | Never Employed | Not asked | Never employed |
| 2024 | Ana Lopez | | | Untracked – registered, not yet answered |
| 2024 | Jose Rizal | | | Untracked – not registered |

| Tally | Alumni | Share |
|---|---|---|
| Employed | 1 | 20.0% |
| Not employed | 1 | 20.0% |
| Never employed | 1 | 20.0% |
| Untracked – registered, not yet answered | 1 | 20.0% |
| Untracked – not registered | 1 | 20.0% |
| **Total alumni** | **5** | 100% |
| Response rate (answered ÷ total) | 3 of 5 | 60.0% |
| Employment rate (employed ÷ answered item 16) | 1 of 3 | 33.3% |

Default sort: batch, then name (admin can change).

### 4.6 Filters and sorting

Batch, course, tracer status (multi-select), and any single-choice CHED answer
(e.g. item 16 = Yes). Sort by any picked column.

### 4.7 Privacy

- Personal-data report: reuses the existing download confirmation and the
  "Contains personal data … RA 10173" PDF footer (`personal_data_notice.dart`,
  `personal_data_export_dialog.dart`).
- Small-group hiding (< 5) does not apply to the list (names are visible);
  Summary & charts keeps it.
- Saved reports store only columns and filters, never names or answers.

### 4.8 Downloads and chart

- Excel (best for wide lists), CSV and PDF from one result.
- Tally below the table after one blank row: label, count, share. In the PDF, a
  small table under the list.
- PDF landscape; warns when more than about 10 columns; existing 1,000-row PDF
  cap applies (Excel/CSV always complete). CSV through `CsvSafe`.
- Chart in list mode: bar or donut of the tracer-status tally (including the
  untracked groups), using the existing chart code.
- On-screen preview: 200 rows at a time, tally rows always visible.

### 4.9 Templates

- Keep the 6 Summary templates.
- Add 4 list templates:
  1. Employment status of all alumni (including untracked)
  2. Untracked alumni for follow-up (name, batch, course, registration, email,
     contact)
  3. Employed alumni job details (occupation, line of business, place of work,
     employment status)
  4. Not employed, with reasons

### 4.10 Summary & charts stays; make it easier to use (approved)

The current Builder is **kept** as the "Summary & charts" mode: it answers
"how many / what share" (percentages and charts, no names), while the Alumni
list answers "who". Only the settings screen changes; the engine and every
number stay the same.

Friendlier settings, in this order:

1. **What do you want to know?** Pick a CHED question shown with its number
   and wording (e.g. "16. Are you presently employed?"), grouped by section,
   with search.
2. **Compare by:** chips — None, Course, Batch, Tracer wave (replaces "Group
   by").
3. **Only include:** filters written as sentences, e.g. "Only graduates whose
   16. Presently employed is Yes" (replaces "Filters").
4. **Show as:** chart picture buttons; charts that do not fit are greyed out
   with the reason.

Also:

- Templates shown as cards at the top ("Start from a ready-made report").
- Numbers: one switch, "Percent" or "Number of graduates" (replaces the
  calculation list).
- One plain sentence above the preview describing what is shown, e.g. "Share
  of graduates who answered item 16, by course, 2026 tracer."
- Waves: one dropdown, newest by default, plus a "Compare waves" switch.
- "More options" (collapsed): answer order, top-N, grid column.
- Mode switch at the top: "Alumni list — who answered and what they said" /
  "Summary & charts — how many and what share".

### 4.11 Clean-up (approved)

- Summary & charts: remove from the screen the calculation choices "% of those
  asked, including blank", "% of all graduates" and "number who answered";
  remove "Who to count" (always roster-linked, as the DSS). Move answer order
  and top-N under "More options". The engine keeps all of these, so no numbers
  change and older saved reports still open.
- Delete the unused `custom_report_builder.dart`, `CustomReportTemplateService`
  and their tests. Keep `custom_report_export_service.dart` (Downloads
  presets).

## 5. Implementation phases (pause after each)

1. **List logic, no UI.** Pure function: roster + one wave's responses (or
   latest from any wave) → rows with tracer status, and the tally (overall and
   per batch/course). List settings model stored in `report_definitions.config`
   (settings only; no database change). Tests: tally equals the Tracer tab
   coverage funnel and employment rate.
2. **Columns and cell formatting.** Roster columns plus all CHED items with the
   merging, "Not asked" and table rules. Tests on Others, multi-select, tables,
   conditional questions.
3. **Builder UI.** "Alumni list | Summary & charts" switch, column picker by
   section, filters, sorting, optional subtotals, 200-row preview with tally
   rows, status chart.
4. **Downloads.** Excel, CSV and PDF from the same result, tally at the bottom,
   personal-data confirmation and footer. Parity tests across formats.
5. **Templates and saved reports.** The 4 list templates; saving and opening in
   both modes.
6. **Make Summary & charts easier to use.** The friendlier settings screen
   (section 4.10), including the trimming, and the old builder deletion
   (section 4.11). No engine or number changes; existing saved reports still
   open.
7. **QA.** Demo comparison against the Tracer tab funnel, docs updates
   (`SYSTEM_DOCUMENTATION.md`), full test suite and analyze.

## 6. Standing constraints

- Demo (`ogxyvjjkgjtzfmsaeeir`) for any database checks; live only with
  explicit approval.
- No database change without reporting it first.
- Do not redefine metrics or change CHED question meanings.
- Format only new files; do not commit unless asked.
