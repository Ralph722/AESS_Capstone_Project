# Survey Editor (in-page panel of index 10) — Phase A audit · Phase B proposal · Phase C implementation · Phase D responsive review · Phase E functional review · Phase F completion report

Date: 2026-10-15. Parent: [`AESS_ADMIN_REDESIGN_AUDIT.md`](AESS_ADMIN_REDESIGN_AUDIT.md) §8–§9 (step 5). Builds on the closed [Surveys list](AESS_ADMIN_REDESIGN_SURVEYS.md) and Phase 0 components. Working mode: **UI-first** (progress doc).

Scope: `AdminSurveyEditorScreen` as opened from the Surveys list (Edit / publish, Duplicate, New survey, or "Edit" from Responses) — header, edit pane (Details · Schedule · Audience · Questions), question editor cards and visibility rules, action bar, live preview pane, and the dialogs it opens. **Out of scope:** Survey Responses panel (step 6), the alumni-side survey renderer used inside the preview (`ChedGtsForm`, `survey_take_ui.dart`).

Evidence: **code inspection only** (files in A2). No live session in this phase (UI-first mode); nothing opened, saved or published.

---

## A1. Purpose and user

Admins finish a survey before and after publishing: title/description, optional open/close window, audience (courses, batch years, auto-assign, AI helper for CHED), and — for custom surveys — the questions (type, options/scale, required, section, conditional visibility, order). They then **Publish** (draft) or **Re-assign alumni** (published), while a live preview shows what alumni will see.

## A2. Files

| File | Role | LOC |
|---|---|---:|
| `surveys/presentation/admin_survey_editor_page.dart` | State, load, autosave of questions, manual save of details, publish/re-assign, layout (side-by-side or stacked), dialogs | 1,249 |
| `surveys/widgets/survey_question_editor.dart` | `SurveyQuestionEditorCard` (collapsed summary + expanded form), `SurveyOptionsEditor`, `_VisibilityRuleEditor`, `_MiniChip` | 818 |
| `surveys/widgets/admin_survey_preview_sheet.dart` | `AdminSurveyPreviewPanel` (embedded pane) + `showAdminSurveyPreview` (overlay) | 240 |
| `surveys/widgets/admin_survey_ui.dart` (parts) | `SurveyInlinePanelHeader`, `SurveySectionCard`, `SurveyCallout`, `SurveyEditorScaffold`, `SurveyEditorContentWidth`, `SurveyStickyActionBar`, status/kind chips | — |
| Shared | `DirectoryDateFilterChip`, `DirectoryDateTimePickers` (roster UI), `AdminFormEditorSkeleton` (→ portal `SurveyFormSkeleton`), `AudienceTargeting`, `CourseConstants` (5 courses) | — |

No tests cover the Editor, the question card or the preview panel. **Discrepancy:** Audit §2 lists `admin_form_fields.dart` for this screen; the Editor does not use it (only the Event editor does).

## A3. Data and sources (must not change)

| Data | Source |
|---|---|
| Survey, questions, preset metadata | `getSurvey`, `getQuestions`, `getSurveyTemplateMeta` (only when `templateId` set) |
| Details / schedule / audience save | `updateSurvey(copyWith …)` on **Save details** (manual); validation: batch-year format (`AudienceTargeting`), close after open |
| Questions | Autosaved 400 ms after each change (`saveQuestion`); add (`saveQuestion`), duplicate / duplicate section / reorder (`saveQuestions`), delete (`deleteQuestion` + order save + visibility-rule pruning) |
| Visibility rules | Stored on the survey; saved 400 ms after change (`updateSurvey`) |
| Publish / re-assign | `countAudience` → confirmation → flush pending autosaves → `_saveMetadata` → `publishSurvey` → close editor (publish) or reload (re-assign) |
| Preview | Local snapshot of title/description/questions mirrored after every `setState` (post-frame) into `AdminSurveyPreviewPanel`; CHED surveys render the read-only `ChedGtsForm` |

## A4. Interactions (all preserved in any redesign)

- Header: back arrow (tooltip "Back to surveys" / "Back to responses"), title (falls back to "Edit survey"), subtitle "Edit / publish".
- Status + kind chips at the top of the form.
- Details: Title, Description. Schedule: Opens at / Closes at pickers with Clear buttons. Audience: 5 course filter chips, batch-years field (validated as you type), Auto-assign switch, AI answer helper switch (CHED only).
- Questions — CHED built-in: locked callout only. Preset: warning callout + editable list. Custom: Add, collapsed cards (number, prompt, type/Required/CHED standard/Conditional/validation/Saving chips), expand to edit (prompt, type, required, options or scale, section, visibility rule), Move up/down, Duplicate, Duplicate section, Delete (two different confirmations for CHED standard items vs others), drag-to-reorder.
- Action bar: **Save details** + **Publish** (draft, green) or **Re-assign alumni** (published); closed surveys show only Save details.
- Dialogs: delete question, remove CHED standard item ("Keep" / "Remove anyway"), publish / re-assign confirmation with audience count.

## A5. Layout today (from code; not viewed live)

Inline header bar → body padded 12 px. **≥ 900 px content width:** edit pane (white card, flex **4**) with its own scroll and action bar at the bottom, beside the preview pane (flex **6**). **< 900 px:** edit pane over preview, each half the height. At 1366×768 (content ≈ 1,086 px) the edit pane is ≈ 420 px wide and the preview ≈ 630 px; at that width the action bar is under its 520 px breakpoint, so **Save details and Publish stack as two full-width buttons**. Section cards: 12 px padding, 15 px titles, subtitle line. The non-embedded variant (AppBar, overlay preview, 880 px column) exists in code but **no caller uses it** (the list always passes `onClose`).

## A6. Problems and opportunities

**Functional defects (pre-existing — fixing needs approval):**

1. **Load failure has no handling.** `_load` has no try/catch: a failed first load leaves the skeleton forever; a missing survey (`null`) shows an empty form titled "Edit survey" with Save disabled and no message.
2. **Publish ignores a failed details check.** `_publish` calls `_saveMetadata()`, which only shows a SnackBar and returns when Close ≤ Open; `publishSurvey` then still runs with the previously saved dates.
3. **Save details** has no error handling (unhandled exception, no message) and no busy state.
4. **Publish / Re-assign** have no busy state after confirmation (flush + save + publish can take seconds) and can be started again; publishing also shows "Survey details saved" just before "Published to N".
5. **Unsaved changes are lost silently.** Details/schedule/audience need Save details, but Back closes without a prompt and nothing shows unsaved state; `dispose` cancels pending question autosave timers, so edits from the last ≈ 400 ms are dropped on Back.
6. **Publish does not check questions** — a custom survey can be published with no questions, empty prompts or choice questions with < 2 options (the cards already flag these). *(Adding a check changes behaviour — approval item.)*
7. **Delete question** has no error handling.
8. **Raw error text** (`'$e'`) in 7 SnackBars (visibility save, add, autosave, duplicate, duplicate section, reorder, publish).

**Information / usability:**

9. **Mixed save model is invisible:** questions autosave, details do not; only a small "Saving…" chip per question shows activity, and nothing says details are unsaved.
10. Status chip still uses the old constructor, so a published survey past its close date shows **"Scheduled"** (list now says "Window ended" — I1 from the Surveys list).
11. Header subtitle "Edit / publish" repeats the action; status, kind and window are inside the scrolling form rather than in the header.
12. No required marker on Title; empty titles can be saved/published (list shows "Untitled survey").
13. Schedule validation (close after open) appears only as a SnackBar at save time, not at the field.
14. Batch-year field validates on every keystroke, so a half-typed range ("2020-") shows an error immediately.
15. Audience size is only revealed in the publish confirmation (`countAudience` exists; showing it live would add read-only queries — approval item).
16. "Use Preview to test visibility rules" refers to a Preview button that the embedded editor does not have (the preview is the live pane).
17. Destructive confirmation "Remove anyway" is a plain text button; dialogs are default Material `AlertDialog`s (lavender M3 surface), not 0c.

**Visual / design-system:**

18. **Edit pane too narrow at laptop sizes** (≈ 420 px at 1366, 40 % of the width) while the preview takes 60 %; forms wrap tightly and the action bar stacks.
19. < 900 px: two half-height panes, each scrolling separately (cramped at 768×1024).
20. Section cards, callouts and the inline header predate 0c (`AdminText`, `AdminSurfaces`); preview header 18 px vs section titles 15 px; SnackBars use `Colors.red/green`.
21. Question action icons appear only when a card is expanded; Delete is an icon only (red) next to neutral icons.
22. Loading skeleton is the alumni-portal `SurveyFormSkeleton` (field blocks), not the two-pane layout.

**Code health (note only):** unused non-embedded path (AppBar, `_openPreviewOverlay`, `SurveyEditorContentWidth`); `admin_form_fields.dart` not used here.

## A7. Responsive notes (code inspection)

| Width | Expected |
|---|---|
| 1920 | Side-by-side; edit ≈ 650 px, preview ≈ 970 px |
| 1366 | Side-by-side; edit ≈ 420 px; action bar stacked |
| 1024 (rail) | Side-by-side just above 900; edit ≈ 360 px |
| 768 | Stacked halves |

Not verified live (UI-first).

## A8. Shared-component dependencies and risks

| Component | Other users | Risk if changed |
|---|---|---|
| `SurveySectionCard` | Survey Responses page (2), analytics panel | Restyle shows in Responses (step 6) → approval, or Editor-local styling |
| `SurveyCallout` | Response detail sheet | Same |
| `SurveyInlinePanelHeader`, `SurveyEditorScaffold`, `SurveyStickyActionBar`, `SurveyQuestionEditorCard`, `AdminSurveyPreviewPanel` | Editor only | Safe to restyle |
| `ChedGtsForm`, `survey_take_ui.dart` (inside preview) | **Alumni app** | Do not edit |
| `AdminFormEditorSkeleton` → `SurveyFormSkeleton` | Announcements editor; alumni portal | Do not edit; Editor can get its own skeleton |
| `DirectoryDateFilterChip`, `DirectoryDateTimePickers` | ~10 admin screens | Use as is |
| `SurveyService`, `AudienceTargeting` | Many | Do not change |

Other risks: the autosave timers, flush-before-publish order, visibility-rule pruning and the `setState` override that feeds the preview must stay intact; reordering uses `ReorderableListView` inside a scroll view (keys = question ids).

## A9. Decisions needed before Phase B

1. **Functional fixes 1–8** into the proposal, each separately approvable?
2. **Unsaved changes (item 5/9):** (a) unsaved indicator + confirm on Back when details changed, and flush pending question saves on Back; (b) autosave details too (behaviour change); or (c) indicator only.
3. **Publish checks (item 6):** block publish with a list of question problems, warn but allow, or leave as is?
4. **Pane split (item 18):** e.g. edit 55 % / preview 45 % with a collapsible preview, or keep 40/60?
5. **Shared `SurveySectionCard` / `SurveyCallout`:** restyle globally (Responses changes too) or Editor-local styling until step 6?
6. **Live audience count (item 15):** allow extra read-only `countAudience` calls while editing, or keep it in the confirmation only?
7. Unused non-embedded path: leave untouched (recommended) or remove?

**Owner answers (2026-10-15):** Phase A **approved**; Phase B authorized. (1) All functional fixes go into the proposal, each separately approvable. (2) Unsaved indicator + confirm on Back when details changed; finish pending question saves on Back. (3) **Block** Publish and list question problems. (4) Wider edit pane (≈ 55/45) with a collapsible preview. (5) **Editor-local styling** now; shared `SurveySectionCard` / `SurveyCallout` stay as they are until step 6. (6) Live audience count allowed (debounced, read-only `countAudience`). (7) Unused non-embedded path left untouched.

---

## B. Redesign proposal (Phase B — no production code changed)

Builds on the signed-off patterns: 0c dialogs (`showAdminConfirmDialog`, `showAdminDialogSurface`), `AdminStateView`, `AdminButtonStyles`, `AdminText`/`AdminColors` tokens, the Directory badge look already used by `SurveyStatusChip` (SH1), and `SurveyStatusChip.fromSurvey` / `surveyWindowText` from the Surveys list. **No shared component used by another screen changes.** No `SurveyService`, model, schema or route changes.

### B1. Layout (1366×768, sidebar expanded, content ≈ 1,086 px)

```
┌ ← Alumni Homecoming Feedback   [Draft] [Custom]                         [◫ Hide preview] ┐
│   No window set                                                                           │
├──────────────────────────────────────────────┬────────────────────────────────────────────┤
│ DETAILS                                      │ Preview                                    │
│ Title shown to alumni.                       │ As alumni see it · answer to test rules    │
│ [Title *                                   ] │────────────────────────────────────────────│
│ [Description (optional)                    ] │  Alumni Homecoming Feedback                │
│──────────────────────────────────────────────│  …                                         │
│ SCHEDULE                                     │  1. How did you hear about the event? *    │
│ [Opens at: Immediately when published ▾]     │     ○ Facebook  ○ Email  ○ Friends         │
│ [Closes at: No automatic close        ▾]     │  2. …                                      │
│──────────────────────────────────────────────│                                            │
│ AUDIENCE                       ≈ 412 alumni  │                                            │
│ (BSIT)(BFPT)(BTLED-IA)(BTLED-ICT)(BTLED-HE)  │                                            │
│ [Target batch years  e.g. 2020-2027        ] │                                            │
│ Auto-assign new alumni                  [●]  │                                            │
│──────────────────────────────────────────────│                                            │
│ QUESTIONS (6)                       [+ Add]  │                                            │
│ ⋮⋮ ① How did you hear…  [Single choice][Req] │                                            │
│ EMPLOYMENT · 3 questions                     │                                            │
│ ⋮⋮ ② …                                       │                                            │
│ [+ Add question]                             │                                            │
├──────────────────────────────────────────────┤                                            │
│ ● Unsaved changes      [Save details] [Publish]│                                          │
└──────────────────────────────────────────────┴────────────────────────────────────────────┘
```

Edit pane ≈ 576 px (flex 11), preview ≈ 472 px (flex 9). **Hide preview** gives the edit pane the full width (form centred, max 880 px). Below 900 px content width: an **Edit | Preview** switch in the header shows one pane at full height instead of two half-height panes.

### B2. CURRENT DATA → CURRENT COMPONENT → PROPOSED COMPONENT

| Data | Current | Proposed |
|---|---|---|
| Back, title | `SurveyInlinePanelHeader` (title + "Edit / publish") | Same component (Editor-only), restyled with `AdminText`: title + status chip (`fromSurvey`) + kind chip in one row; subtitle = window text (`surveyWindowText`, "No window set"); trailing **Hide/Show preview** (wide) or **Edit · Preview** switch (< 900). Back tooltip unchanged |
| Status/kind chips at top of form | `Wrap` of chips inside the scroll | Moved to the header (I2) |
| Details / Schedule / Audience / Questions groups | `SurveySectionCard` (card inside the white pane card) | New Editor-only `SurveyEditorSection`: flat group — small-caps 12 px w700 heading, 12 px helper line, optional trailing (count/Add), divider between groups; no card-in-card. `SurveySectionCard` itself untouched |
| CHED lock / preset warning | `SurveyCallout` | Unchanged (shared with the response detail sheet) |
| Title, description, batch fields | `AdminSurveyTheme.fieldDecoration` | Same decoration; "Title *", "Description (optional)"; inline errors (FX9, I3, I4) |
| Opens / Closes | `DirectoryDateFilterChip` + Clear text buttons | Same chips; Clear becomes a small ✕ icon button inside the row (tooltip "Clear open time"/"Clear close time"); inline error under Closes at (I3) |
| Courses | Material `FilterChip`s | Same chips styled with tokens (navy text on info tint when selected, border otherwise) |
| Audience size | Only in the publish dialog | Live count at the Audience heading (I5) |
| Switches | `SwitchListTile.adaptive` with inline styles | Same widgets, `AdminText` styles |
| Question cards | `SurveyQuestionEditorCard` | Same widget (Editor-only) restyled: tokens, badge-look mini chips, expanded footer = icon actions left · red **Delete** text button right (V4) |
| Section labels | 13 px navy text | Small heading row "EMPLOYMENT · 3 questions" |
| Action bar | `SurveyStickyActionBar` (Editor-only): buttons only, stacks < 520 px | Save state on the left (U1), buttons right; stacks < 440 px; busy spinners (FX3/FX4) |
| Confirmations | Material `AlertDialog`s | `showAdminConfirmDialog` (delete/remove = destructive) |
| Unsaved-changes prompt | — | `showAdminDialogSurface` dialog (U2) |
| Publish problems | — | `showAdminDialogSurface` dialog (FX6) |
| Preview pane header | 18 px "Preview" + survey title | 14 px "Preview" + 12 px "As alumni see it · answer to test visibility rules" (built-in: "Official CHED form · read-only") |
| Loading | `AdminFormEditorSkeleton` (portal) | Editor-local two-pane skeleton (`Skeleton`/`ShimmerScope`) |
| Load failure / missing survey | Endless skeleton / blank form | `AdminStateView.error` (Try again · Back) / `AdminStateView.empty` "Survey not found" (Back) |
| SnackBars | `Colors.red` / `Colors.green` / none | `AdminColors.danger` / `success` tokens, friendly text (FX8) |

### B3. Save model (U1–U3, owner answer 2)

| ID | Item | Behaviour change |
|---|---|---|
| U1 | **Save state** in the action bar: "Unsaved changes" (amber dot) when title, description, schedule, courses, batch years or switches differ from the last saved survey; "Saving…" while any question/rule autosave runs; otherwise "All changes saved · questions save automatically" | Display only |
| U2 | **Back with unsaved details** opens "Unsaved changes" — *Keep editing* · *Discard* · *Save and close* (Save runs the same validation as Save details; stays open if it fails). No prompt when nothing is unsaved | New prompt |
| U3 | **Back finishes pending question/rule saves** (same flush as Publish) before closing; back button shows a spinner meanwhile; if a save fails the editor stays open with the error | Prevents the ≈ 400 ms data loss |

Note: switching sidebar menus keeps the editor mounted (dashboard `IndexedStack`), so nothing is lost there; a browser refresh/tab close is not covered (would need a web `beforeunload` hook — out of scope).

### B4. Approvable items

**Base (one approval):** B1 layout and 55/45 split (flex 11/9), Hide/Show preview (state only, not remembered), Edit · Preview switch below 900 px, B2 component mapping (header, `SurveyEditorSection`, field labels, Clear icons, course chip styling, preview header, skeleton, SnackBar tokens, action-bar layout).

**Functional fixes (audit 1–8 + 12), each separately approvable:**

| ID | Fix | Behaviour change |
|---|---|---|
| FX1 | Load: first-load failure → error state with Try again/Back; missing survey → "Survey not found — it may have been deleted." with Back; failed reload after a save keeps the form and shows a SnackBar | Error states instead of endless skeleton/blank form |
| FX2 | **Pre-publish check before the confirmation**: title (FX9), batch years, close after open, questions (FX6), audience > 0 when filtered (existing). Publish stops on any failure — fixes publishing after a failed date check | Publish can no longer proceed with invalid details |
| FX3 | Save details: try/catch + friendly error, spinner in the button, disabled while saving; returns success so Publish/Save and close stop on failure | Errors shown; no double save |
| FX4 | Publish / Re-assign busy state: button spinner ("Publishing…"/"Re-assigning…"), Save, Publish and Back disabled while running; one success SnackBar (no extra "Survey details saved") | Prevents double start |
| FX5 | = U1–U3 | As B3 |
| FX6 | **Block Publish on question problems** (custom/preset only): no questions; empty question text; single/multiple choice with < 2 options (same rules as the card hint). Dialog "Fix before publishing" lists each problem ("Question 3 — Add question text"); **Go to question N** expands the first one. Re-assign is not blocked | Publish blocked until fixed (owner answer 3) |
| FX7 | Delete question: try/catch + friendly error; question stays in the list if the delete fails | Errors shown |
| FX8 | Friendly errors in the 7 raw `'$e'` places, with context ("Couldn't save question 3. ‹reason›"); same rule as the list (strip `Exception:`, fallback for long/technical text) | Text only |
| FX9 | Title required: "Title *", inline "Title is required" after editing/saving; Save details and Publish blocked while empty | Empty titles can no longer be saved |

**Information items, each separately approvable:**

| ID | Item |
|---|---|
| I1 | Status chip uses `SurveyStatusChip.fromSurvey` → "Window ended" for published surveys past their close date (as on the list) |
| I2 | Header shows status, kind and window; "Edit / publish" subtitle removed; chips leave the form |
| I3 | Schedule: inline "Close time must be after open time" under Closes at, live |
| I4 | Batch years: error shown after the field loses focus or on Save/Publish instead of on every keystroke (parsing for the count stays live) |
| I5 | **Live audience count** at the Audience heading: "≈ N alumni" / "All alumni · ≈ N" / "No alumni match" (warning colour); debounced 600 ms after course/batch changes, once on load; read-only `countAudience`; "Count unavailable" on error. The publish dialog still recounts |
| I6 | Copy: Questions helper "Click a question to edit · drag ⋮⋮ to reorder · answer in the preview to test visibility rules" (removes the reference to a Preview button that doesn't exist here) |
| I7 | "Add question" button also at the end of the question list (header Add kept) |

**Visual (in base unless declined):** V4 question card — tokens, badge-look mini chips (radius 6, 11 px), index badge on info tint, footer actions as above; V5 dialogs on 0c (Delete question / Remove standard CHED item destructive, confirm labels unchanged; Publish/Re-assign with icon, same message text); V6 preview header.

**Requires approval:**

| ID | Change | Recommendation |
|---|---|---|
| V3 | Publish button colour: today green (`success`); 0c confirm button is navy. Make Publish navy primary so bar and dialog match, or keep green | **Navy** (one primary colour across the admin) |

### B5. Responsive behaviour

| Width (content) | Behaviour |
|---|---|
| 1920 (≈ 1,640) | Side-by-side ≈ 880 / 720; action bar one row |
| 1366 (≈ 1,086) | Side-by-side ≈ 576 / 472; action bar one row (was stacked) |
| 1024 rail (≈ 950) | Side-by-side ≈ 500 / 410; action bar one row (breakpoint 440) |
| < 900 / 768 | Edit · Preview switch; one pane full height; action bar one row where ≥ 440, else stacked |
| Preview hidden | Edit form centred, max 880 px |

### B6. Unchanged

All `SurveyService` calls and arguments; autosave timing (400 ms) and the flush order before publish; visibility-rule saving and pruning; reordering (drag, move up/down) and duplicate/duplicate-section logic; question types and fields; CHED built-in lock and preset warning texts; publish/re-assign outcomes (close on publish, reload on re-assign); audience-zero block; `ChedGtsForm` read-only preview; panel switching and back targets; the unused non-embedded path.

### B7. Risks

- FX2, FX6, FX9 and U2 change behaviour (listed above); each can be declined.
- Dirty detection (U1) compares against the last loaded survey; batch years are compared in normalised form so reformatting alone doesn't count as a change.
- I5 adds read-only `countAudience` calls (debounced; at most one in flight).
- The `setState` override that feeds the preview and the question card's `didUpdateWidget` text syncing must stay intact; hidden preview keeps syncing (cheap) so showing it again is instant.

### B8. Phase C/D/E plan (UI-first mode)

- **C:** approved items only, in `admin_survey_editor_page.dart`, `survey_question_editor.dart`, `admin_survey_preview_sheet.dart` (embedded header only) and the Editor-only widgets in `admin_survey_ui.dart` (`SurveyInlinePanelHeader`, `SurveyStickyActionBar`, new `SurveyEditorSection`, skeleton). Checks: `flutter analyze` on the surveys feature; one small widget-test file (publish-problem rules, dirty detection, header/action bar without overflow at 768/1366/1920).
- **D:** code-level responsive review.
- **E:** code-level review; live checks deferred to the testing phase (no live writes).

**2026-10-15:** Phase B **approved in full** (base, FX1–FX9, I1–I7, V3 navy). Phase C authorized.

---

## C. Implementation (Phase C — 2026-10-15)

### C1. Implemented

All approved items: base layout (55/45 via flex 11/9, Hide/Show preview, Edit · Preview switch below 900 px, form max 880 px with preview hidden), header with status/kind chips and window subtitle (I1, I2), flat `SurveyEditorSection` groups, action bar with save state (U1) and busy spinners, U2 unsaved-changes dialog, U3 flush on Back, FX1–FX9, I3–I7, V3 (Publish navy), V4 question card, V5 0c dialogs, V6 preview header, editor skeleton, SnackBar tokens.

Files: `surveys/presentation/admin_survey_editor_page.dart` (rewrite of state/layout; service calls, autosave timers, flush order, rule pruning and the preview-feeding `setState` override kept), `surveys/widgets/survey_question_editor.dart` (restyle; new pure `surveyQuestionProblem` / `surveyPublishProblems` — the card hint and the publish check share one rule), `surveys/widgets/admin_survey_preview_sheet.dart` (embedded header text only), `surveys/widgets/admin_survey_ui.dart` (Editor-only: `SurveyInlinePanelHeader` gains `chips` / `backBusy` and hides an empty subtitle; `SurveyStickyActionBar` gains `leading`, stacks below 440 px, top border instead of a shadow; new `SurveyEditorSection`, `SurveyEditorSkeleton`, `surveyFriendlyError`). New test file `test/admin_surveys/survey_editor_widgets_test.dart` (14). No service, model, schema, route or other-screen files.

### C2. Judgment calls / deviations

1. **Publish also stops when finishing pending question saves fails** (the error is shown); before, publish went ahead regardless. Same flush is used by Back (U3).
2. Back is ignored while Save details or Publish is running (buttons are disabled anyway).
3. "Go to question N" also scrolls the question into view and switches the narrow layout to Edit.
4. Visibility-rule pruning after a question delete now has error handling too (it had none) — under FX7/FX8.
5. Batch-year error clears while typing and reappears on blur or Save/Publish (I4).
6. Audience count also runs for the Official CHED survey (same audience fields).
7. `surveyFriendlyError` is a public copy of the list's private helper; the signed-off list page was not edited.
8. The unused route-based layout was moved into `_buildStandalone()` with the same structure; because it shares the form builder it also shows the restyled groups and `fromSurvey` chips.
9. Overlay preview (unused) keeps its old header; only the embedded pane uses the new text sizes.

### C3. Checks actually performed

| Check | Result |
|---|---|
| `flutter analyze lib/features/admin/surveys test/admin_surveys` | No issues |
| `flutter test test/admin_surveys` | 32 passed (14 new: publish-problem rules, friendly errors, header at 768/1366/1920 with long title + chips, busy back, action bar one row at 576 px and stacked at 400 px, expanded question card footer at 420 px, skeleton at 768/1366; 18 existing list tests) |
| Live view / running app | **Not done** (UI-first) |
| Full test suite | Not run |

---

## D. Responsive review (Phase D — 2026-10-15, UI-first: code-level)

Method: source review against the breakpoints, one temporary widget-test measurement of the edit-pane pieces at pane widths 360 / 474 / 576 / 880 px (file deleted afterwards), and a scan of the owner's running `flutter run -d chrome` log. **No browser view or screenshots** (the running Chrome session is the owner's).

Pane widths (content width from the Surveys review; body padding 2 × 12, gap 14, flex 11/9):

| Viewport | Content | Layout | Edit pane | Preview |
|---|---|---|---|---|
| 1920 | ≈ 1,640 | Side-by-side | ≈ 880 | ≈ 720 |
| 1366 | ≈ 1,086 | Side-by-side | ≈ 576 | ≈ 472 |
| 1024 (rail) | ≈ 950 | Side-by-side | ≈ 500 | ≈ 410 |
| at 900 threshold | 900 | Side-by-side | ≈ 474 | ≈ 388 |
| 768 | < 900 | Edit · Preview switch | full width | full width |
| Preview hidden | any ≥ 900 | Form centred | ≤ 880 | — |

| Area | Finding |
|---|---|
| Header | Title + chips in a `Wrap` (title capped to the available width, chips wrap below); subtitle one line + ellipsis; Hide preview / Edit · Preview switch fixed width. Widget tests: no overflow at 768/1366/1920 with a long title |
| Sections | Heading row = expanded title + trailing (count "All alumni · ≈ 12,345", Add button); no overflow at 360–880 px (measured) |
| Schedule rows | Picker expands, ✕ icon fixed; no overflow at 360 px |
| Course chips | `Wrap`; 5 chips wrap to 2 lines below ≈ 450 px |
| Question cards | Collapsed: long prompt 2 lines + ellipsis, chips wrap (measured with 5 chips at 360 px); expanded footer = wrapping icon group + Delete (tested at 420 px) |
| Action bar | One row from 440 px pane width (all side-by-side widths), stacked below. **Finding D1:** the save-state text "All changes saved · questions save automatically" needs ≈ 300 px in the real font but gets ≈ 300 px at 1366 and ≈ 200 px at 474 → it would be cut off |
| Hidden preview | `Align` + max 880 px; edit pane keeps full height (bounded) |
| States | Skeleton uses the same 900 px rule; error / not-found views centred, max 420 px, scrollable |
| Dialogs | Unsaved changes 460 px, publish problems 480 px (max 8 lines + "+ N more"), 0c confirmations 440 px; all scrollable, buttons wrap |
| Keyboard/focus | Unsaved dialog focuses *Save and close*; problems dialog focuses *Go to question N* (or *Close*); destructive confirms focus Cancel (0c); Edit · Preview segments are focusable buttons with selected state |
| Running-app log | 4 "RenderFlex overflowed" entries (6.8 / 8.8 / 110 px right, 100 px bottom) right after a fresh `flutter run` launch and before a sign-out; the log has no widget names, so they **cannot be attributed** (opening the Editor needs several navigation steps, so it's unlikely to be the source). Flagged for the testing phase |

**D1 fixed:** the save-state label measures its text and falls back to "All changes saved" (full text in a tooltip and in the semantics label) when the full line doesn't fit. `flutter analyze lib/features/admin/surveys test/admin_surveys`: no issues; `flutter test test/admin_surveys`: 32 passed.

**Deferred to the testing phase:** live look at 1920/1600/1440/1366/1024/768 (header wrap, pane proportions, real save-state fit), and tracing the 4 log overflows to a screen.

---

## E. Functional review (Phase E — 2026-10-15, UI-first: code-level)

Method: comparison of the original page (`git show HEAD:…/admin_survey_editor_page.dart`, 1,249 lines) with the new one, plus a flow-by-flow code review. **No live regression, no data written.**

| Area | Result |
|---|---|
| Service calls | Same calls and arguments as HEAD (`getSurvey`, `getQuestions`, `getSurveyTemplateMeta`, `updateSurvey` ×3, `saveQuestion` ×2, `saveQuestions` ×3, `deleteQuestion`, `countAudience`, `publishSurvey`); **one extra read-only `countAudience`** for the approved live count (I5). Saved lists are now copies (same values) |
| Load | Same queries and field mapping; first-load failure → error view with Try again; missing survey → not-found view; failed reload keeps the form + SnackBar |
| Save details | Same `updateSurvey(copyWith …)`; now blocked by title/batch/schedule validation (FX9, FX2), errors caught (FX3), success SnackBar green, reload as before |
| Questions | Add, autosave (400 ms), duplicate, duplicate section, move, drag-reorder, delete + order save + rule pruning: same calls and order. Delete failure keeps the question and re-queues its pending save; pruning and all other failures show friendly text (FX7, FX8) |
| Visibility rules | Same 400 ms save of the survey; failures friendly |
| Publish / Re-assign | Order unchanged: batch sync → `countAudience` → audience-zero block (same text) → confirm (same message text, 0c) → flush autosaves → save details → `publishSurvey` → close (publish) / reload (re-assign). New: pre-checks before counting (FX2), question problems block Publish only (FX6), busy state (FX4), stop if a flush or the details save fails, one success SnackBar |
| Back | Unsaved details → Keep editing / Discard / Save and close; then pending question/rule saves are flushed; closes via the same `onClose` (back to surveys or responses). No prompt when nothing changed |
| Panels / routes | `onClose`, `backTooltip`, `ValueKey('editor-$id')` in the list page untouched; unused route layout keeps the AppBar, overlay preview and bottom bar |
| Preview | Same snapshot feed (`setState` override) and `AdminSurveyPreviewPanel`; CHED built-in still `ChedGtsForm` read-only |

**Findings (both fixed):**

- **E1 — false "Unsaved changes" on open.** Stored batch targets may be range tokens (`"2020-2027"`; `expandBatchYearTargets` exists for this). The unsaved check compared the parsed field (8 years) with the raw stored list, so such a survey would show "Unsaved changes" and prompt on Back without any edit. Fixed with `surveyBatchInputChanged`: equal display text → unchanged; otherwise parsed years vs expanded stored years. 4 unit tests.
- **E2 — edit pane lost scroll position/focus** when Hide/Show preview was used or the window crossed 900 px (the pane moved to a different spot in the tree). Fixed with a `GlobalKey` on the edit pane so it is moved, not rebuilt.

Checks after the fixes: `flutter analyze lib/features/admin/surveys test/admin_surveys` — no issues; `flutter test test/admin_surveys` — 36 passed.

**Deferred to the testing phase (live, needs a QA survey — writes data):** load error/not-found views, Save details with invalid fields, unsaved prompt (all three choices), Back flush, publish blocked by question problems + Go to question, publish/re-assign busy states and SnackBars, delete-question failure, live audience count values vs the publish dialog, preview toggle/switch, keyboard order in the new dialogs, full test suite.

---

## F. Completion report (Phase F — 2026-10-15)

**Screen:** Survey Editor (in-page panel of Surveys, menu index 10; opened from the list or from Responses). **Status:** visually complete for the manuscript (UI-first mode); responsive and functional checks were **code-level only**; live QA and regression **outstanding** (later testing phase). Awaiting owner sign-off.

| Item | Summary |
|---|---|
| Files changed | `surveys/presentation/admin_survey_editor_page.dart`, `surveys/widgets/survey_question_editor.dart`, `surveys/widgets/admin_survey_preview_sheet.dart` (embedded header text), `surveys/widgets/admin_survey_ui.dart` (Editor-only widgets); new test `test/admin_surveys/survey_editor_widgets_test.dart` (18) |
| Reused | `showAdminConfirmDialog`, `showAdminDialogSurface`, `AdminStateView` (error/empty), `AdminButtonStyles`, `AdminColors`/`AdminSurfaces`/`AdminText`, `SurveyStatusChip.fromSurvey`, `SurveyKindChip`, `surveyWindowText`, `SurveyCallout` (unchanged), `DirectoryDateFilterChip`, `DirectoryDateTimePickers`, `Skeleton`/`ShimmerScope` |
| Created (feature-local) | `SurveyEditorSection`, `SurveyEditorSkeleton`, `surveyFriendlyError`, `surveyQuestionProblem`, `surveyPublishProblems` / `SurveyPublishProblem`, `surveyBatchInputChanged`; private `_PaneSwitch`, `_UnsavedChangesDialog`, `_PublishProblemsDialog`. Extended (Editor-only): `SurveyInlinePanelHeader` (`chips`, `backBusy`), `SurveyStickyActionBar` (`leading`, 440 px stack) |
| UI/UX changes | §C1: 55/45 split with Hide/Show preview and Edit · Preview switch below 900 px; header with status/kind chips and window; flat sections; required title, inline schedule/batch errors; live audience count; restyled question cards (badge chips, footer actions, red Delete); section headings with counts; extra Add question; save-state line; navy Publish; 0c dialogs; editor-shaped skeleton; error/not-found views; token SnackBars |
| Fixes | FX1–FX9 (§B4) + D1 save-state fit (§D) + E1 false "Unsaved changes" for range-stored batch years, E2 edit-pane state on layout switch (§E) |
| Responsive | Side-by-side ≥ 900 px (edit ≈ 576 px at 1366), one pane with a switch below; action bar one row ≥ 440 px pane width; form max 880 px with preview hidden (§D) |
| Preserved | All service calls and arguments (+ one approved read-only `countAudience`), autosave timing and flush order, rule pruning, reorder/duplicate logic, publish/re-assign outcomes and texts, back targets, CHED read-only preview, unused route layout (§E) |
| Tests performed | `flutter analyze` (surveys + tests): no issues; `flutter test test/admin_surveys`: 36 passed (18 Editor + 18 list); temporary pane measurement (deleted); running-app log scan. **Not run:** full suite, browser view, live actions |
| Approved deviations / open | §C2 judgment calls (publish stops if pending question saves fail; Back ignored while saving/publishing; Go to question also scrolls; audience count also for Official CHED; public copy of the list's error helper; unused route layout shares the restyled form) |
| Remaining | Live verification list in §E; 4 unattributed overflow entries in the running-app log (§D); browser refresh/tab close with unsaved details not protected; shared `SurveySectionCard` / `SurveyCallout` restyle deferred to step 6 (Responses) |
