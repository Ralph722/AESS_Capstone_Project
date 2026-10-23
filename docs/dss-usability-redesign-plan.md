# Program Insights (DSS) usability redesign — implementation plan

Saved 2026-10-22. Follows the DSS usability audit (same date). Goal: an admin
with no training can open a finding and know what to do, in what order, and
what happens next — without the click-by-click guide.

**Scope rule for every phase:** UI/UX only. No evaluation-logic, rule,
status-transition, or database-schema changes. The server evaluator
(`dss_evaluate_all`) and its in-app twin keep behaving exactly as today, so
`test/dss/*` logic suites (evaluator, finding sync, priority, outcomes,
server parity) must pass untouched after every phase.

## Current workflow (as built)

Refresh insights → open flag → **Start** (Update status card) → choose
**Intervention** (Intervention card) → act (Act in AESS card) → add **Proof**
(Proof card, *or* reminder draft, *or* "Other" + details) → note (Update
status card) → **Resolve** → coverage re-check (same wave) → next wave closes
→ **Check outcome** → **Decide** (Resolve / Continue / Modify / Escalate).

Pain points found in the audit (numbered for reference):

1. Resolve checklist lives in Update status; its items are completed in
   three other cards, in the other column on wide screens.
2. Intervention exists three times: flag dropdown, "Add plan details"
   (`dss_interventions`), Outcome card's Record/Decide dialogs. Resolving
   also silently auto-creates an intervention from the dropdown.
3. Proof exists three times (reminder draft / Proof entries / Other+details).
4. Ownership exists twice: Assign owner (Update status) vs Accountability
   card (office, person, 3 dates) — the card even cross-references the other.
5. Two verdict cards (coverage re-check vs intervention outcome) that admins
   conflate; two refreshes (list reload vs Refresh insights); cards reorder
   by stage, breaking spatial memory; no "when will the outcome be ready".
6. List has 5 dropdowns + More dialog + search, and the 4 KPI cards secretly
   filter too. Status filter and "Sample size" filter both contain Watch.
7. Jargon (Watch, Limited/Strong, Confirmed/Possible, cohort, roll-up,
   superseded) is never defined in place. Feature has three names:
   Program Insights (menu), DSS (docs), Findings (screens).

## Target detail-screen layout (fixed order, never reorders)

Wide: left column scrolls content, right column holds the **sticky action
panel**. Narrow: action panel sits directly under the stage strip.

1. Stage strip (existing — kept, becomes display-only)
2. **Action panel** (evolves from Update status): numbered steps, one
   primary button per stage, checklist rows that scroll to their card
3. What we found (existing finding card, notes trimmed)
4. **Plan** (merged Intervention + plan details + ownership — Phases 3–4)
5. Act in AESS (one-click actions; sidebar shortcuts removed)
6. What alumni suggest (unchanged)
7. **What happened** timeline (merged Action log + re-check + outcome —
   Phase 5)

---

## Phase 0 — Words, timing, signposts (quick wins)

**Done 2026-10-23.**

*Fixes pain point 5 (partially) and 7. Low risk, mostly strings.*

- Rename **Refresh insights → Re-run analysis** on the list, the empty
  state, and the Rules hint banner ("If you changed Rules, click Re-run
  analysis…"). The toolbar reload icon keeps tooltip "Reload list".
- Glossary tooltips on the Evidence / Certainty / Priority chips in
  `admin_dss_ui.dart` (text from `dss_copy.dart`, e.g. "Limited evidence —
  10–29 valid answers; treat as indicative"), and on Watch wherever it
  appears as a status.
- "When" line: resolved findings show, in the stage-strip hint and the
  outcome area, *"Outcome is judged when the next CHED GTS wave closes ·
  verify due <date>"* using `flag.verifyDueAt`. Check outcome explains
  provisional results before running, not after.
- Rules tab subtitle already explains thresholds; add one line that changes
  apply on the next re-run (the return banner exists — keep).

Files: `admin_dss_page.dart`, `admin_dss_detail_page.dart`,
`widgets/admin_dss_ui.dart`, `application/dss_copy.dart`.
Tests: update any string assertions; add chip-tooltip widget test.

## Phase 1 — List becomes a work queue + refresh summary

**Done 2026-10-23.**

*Fixes pain points 5 and 6.*

- New default status filter **Queue** (Open + In progress) — add
  `_DssStatusFilter.queue`, make it the initial value and the Reset target.
- KPI cards (Open / In progress / Resolved / Watch) get a visible selected
  state (accent ring/label) and behave as the primary quick filters.
- Move Rule, Priority, Sample size, and Sort dropdowns **into** the More
  dialog (extend `_MoreFiltersDialog` with those fields; badge count
  includes them). Toolbar keeps: search, Status select, More button.
- Delete `_DssEvidenceFilter` (its Findings/Watch split duplicates Status —
  Watch KPI now sets Status = Watch). One less concept, same reach.
- **Re-run summary banner:** snapshot `flagId → status` before a re-run;
  after reload, diff and show a `DssInsightBanner`:
  *"2 new findings · 1 moved to Watch · 1 superseded"* with chips that set
  the matching filter. Pure diff function, unit-tested. No service changes —
  the diff is computed from list state the page already has.

Files: `presentation/admin_dss_page.dart` (toolbar, filters, banner).
Tests: queue-default filtering, More-dialog round-trip, diff-summary unit
tests.

## Phase 2 — One action panel, frozen layout

*Fixes pain points 1 and 5. The structural core.*

- Replace `_stageAwareBody` reordering with the fixed order above. The
  stage strip stays first; a **"Next step"** badge marks the card that owns
  the current step (derived from the same stage logic in
  `DssStageStrip.stageOf`).
- Rebuild `_statusCard` as the action panel:
  - Numbered steps (Start → Plan → Proof → Resolve, then Outcome → Decide)
    with done/current/upcoming states, reusing `_resolveChecklist` data.
  - Exactly **one primary button** per stage: Start / Resolve finding /
    Check outcome / Decide / Reopen. Dismiss and Add note become secondary
    text actions; Watch and Superseded panels already have their own shells
    and keep them.
  - Checklist/step rows are tappable and scroll the owning card into view
    (`GlobalKey` anchors + `Scrollable.ensureVisible`; main column gets the
    `ScrollController`). Disabled Resolve keeps its plain-language reason.
- Extract the "what is the next action" decision into one helper
  (`dssNextAction(flag, …)` in `widgets/admin_dss_ui.dart`) used by the
  stage strip hint *and* the panel, so they can never disagree.
- Remove the sidebar-shortcut buttons (Open Surveys / Reports / Directory /
  Jobs, `_jump(9/10/2/5)`) from Act in AESS; keep the one-click actions and
  Draft announcement. (`onOpenAdminMenu` stays for the one-click flows if
  they need it.)

Files: `presentation/admin_dss_detail_page.dart` (build, `_statusCard`,
`_actCard`), `widgets/admin_dss_ui.dart` (stage helper).
Tests: widget tests — primary button per status (open/in-progress/resolved/
watch/superseded), checklist tap scrolls (smoke), layout order stable across
statuses.

## Phase 3 — Merge the three interventions into one Plan

*Fixes pain point 2. UI merge only — both stores stay, one face.*

- `_interventionCard` becomes **Plan**: the intervention dropdown *is* the
  plan type (one field). Optional plan fields (description, expected
  outcome, target, started date — today only in `_InterventionDialog`) sit
  inline under it, collapsed behind "Add plan details" as now, but editing
  happens in place, not in a second dialog.
- Saving rules (explicit, no silent behaviour change): Start saves plan
  fields if filled; Resolve keeps today's auto-record
  (`recordIntervention` from the dropdown) but now also carries the inline
  plan fields; an explicit **Save plan** button appears when fields are
  dirty. The undecided intervention (`_undecidedIntervention`) pre-fills
  the card, replacing the read-only "Plan on record" box.
- `DssOutcomeCard`: "Record intervention" / "Edit plan" buttons are removed;
  **Edit plan** scrolls to the Plan card instead. Check outcome and Decide
  stay (they move to the panel in Phase 5, card retires then).
- `showDssDecisionDialog` (`widgets/dss_action_dialogs.dart`) pre-fills
  type/description/expected outcome/target from the plan record instead of
  opening blank.
- Resolve gating unchanged: intervention required; "Other" still requires
  the detail text (which remains the offline-proof path).

Files: `presentation/admin_dss_detail_page.dart` (`_interventionCard`,
`_setStatus`, `_outcomeCards`), `widgets/dss_outcome_card.dart`,
`widgets/dss_action_dialogs.dart`, repository calls unchanged
(`recordIntervention`, `decideIntervention`).
Tests: plan pre-fill from undecided intervention; resolve records inline
plan fields; decision dialog pre-fill. `test/dss/dss_outcomes_test.dart`
must pass unchanged (logic untouched).

## Phase 4 — Merge ownership and proof

*Fixes pain points 3 and 4.*

- `DssAccountabilityCard` becomes **Owner & schedule**: gains the Admin
  owner dropdown (admins list passed from the detail page; today it loads
  in `_statusCard`), above office / responsible person / dates. Assign
  owner is deleted from the action panel; the checklist "assigned" step is
  satisfied by admin owner **or** office/person, and its label says so.
- `DssEvidenceCard` is renamed **Proof** (class + title). A linked reminder
  draft renders as a proof entry row ("Reminder announcement drafted —
  counts as proof", with the date), so all three proof kinds are visible in
  one list. Act in AESS keeps creating drafts; the "counts as proof" note
  moves here.
- "Other + describe offline action" stays in Plan (Phase 3) and is listed
  in Proof as an entry when present.

Files: `widgets/dss_accountability_cards.dart`,
`presentation/admin_dss_detail_page.dart` (panel checklist, `_actCard`
note), possible rename fallout in `test/dss/dss_accountability_test.dart`.
Tests: owner saved via card satisfies checklist; proof list shows draft
entry.

## Phase 5 — One "What happened" timeline; outcome moves to the panel

*Fixes pain point 5 (verdict confusion).*

- New timeline card merging: Action log notes (`_notesCard` — already fed
  by `dss_flag_notes`, including status changes and one-click actions),
  the coverage re-check verdict (from `_impactCard` data, rendered as a
  dated entry: "Coverage re-check — Improved"),
...[truncated 3396 chars]