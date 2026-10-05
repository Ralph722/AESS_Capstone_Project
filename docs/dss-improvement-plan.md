# Program Insights (DSS) improvements (plan)

Status: planned, not implemented. Reviewed on 2026-10-02.

## Current implementation (summary)

Code: `lib/features/admin/dss/` (evaluation, impact, AI, export, pages).
Tables: `dss_rules`, `dss_flags`, `dss_flag_notes`
(`supabase/migrations/20260911010000_dss_recommendations.sql`).

- Deterministic, configurable rules over CHED GTS answers, evaluated per
  cohort (course × batch) per published/closed CHED GTS wave
  (`DssEvaluationService.evaluateAll`):

  | Rule | Metric | Items | Default |
  |---|---|---|---|
  | `DATA_QUALITY_LOW` | response rate / sparse sample | roster vs responses | < 40% |
  | `UNEMPLOYMENT_HIGH` | No + Never Employed share | `ched_16` | ≥ 25%, min 20 |
  | `RELATEDNESS_LOW` | first job unrelated or curriculum not relevant | `ched_24a`, `ched_32` | ≥ 40%, min 20 |
  | `UNDEREMPLOYMENT` | Rank/Clerical among employed | `ched_30` | ≥ 35%, min 20 |
  | `TIME_TO_JOB_LONG` | 1+ year to first job | `ched_29` | ≥ 40%, min 20 |
  | `SALARY_STAGNATION` | median bracket gap vs wave | `ched_31` | ≥ 1 bracket, min 20 |
  | `RELATEDNESS_HIGH` | aligned share (opportunity) | `ched_24a`, `ched_32` | ≥ 75%, min 20 |

- Data-quality gating and low-confidence marking (sample < 20).
- Evidence per flag (counts, breakdowns, `ched_34` suggestion themes and
  samples), recommended action and playbook steps.
- Flag lifecycle `open` → `in_progress` → `resolved` / `dismissed` with notes
  and history; one active flag per rule × cohort × wave.
- Closed-loop impact check (`dss_impact.dart`): baseline vs follow-up metric,
  verdict Improved / Unchanged / Still flagged / Need more data, 7-day delay.
- AI (`dss_ai_service.dart`) only rephrases flags and suggests priority, with
  a non-AI fallback. Never invents rules or actions.

## Issues to fix

1. Salary peer median includes the cohort's own course. The comment says
   "other courses", but `allSalaries` contains every course in the wave.
   Exclude the cohort's course (or the cohort itself) from the peer median.
2. Course × batch cohorts are usually too small for the default min 20, so
   outcome rules rarely fire at a small school. Addressed by improvement 2.
3. Response-rate denominator counts every active roster alumnus (registered
   or not), while a comment says "registered preferred". Decide deliberately
   and label it on screen (e.g. "coverage of the whole roster").
4. Employment differed between screens. Resolved in the database audit
   (Phase 5): every screen now reads CHED GTS answers through
   `gts_employment_records` / `gts_metric`, and `employment_records` is gone.
5. Evaluation only runs when an admin presses Refresh, in the admin's
   browser. Addressed by improvement 5.

## Improvements (ordered by value)

Recommended first: 1, 2 and 4.

1. **Margin of error on every rate.** Wilson score interval (95%) per
   proportion metric. Show "28% (likely 18–41%)". Label flags "Confirmed"
   when the lower bound crosses the threshold (upper bound for `lt` rules),
   otherwise "Possible". Store bounds in `evidence`. Low effort.
2. **Automatic roll-up for small groups.** When a course × batch cohort is
   below the rule's minimum, evaluate the course across all batches, then the
   institution. Each flag records its level (`batch`, `course`,
   `institution`). Needs a level marker in `dss_flags` (e.g. use
   `batch_year = 'All'`, or a new column via migration) and the active-flag
   unique index to include it.
3. **Trends across tracer waves.** New rule category `trend` (e.g.
   unemployment up ≥ 10 points vs the previous wave for the same cohort).
   Reuse ordering logic from
   `lib/features/admin/reports/application/ched_wave_comparison.dart`.
   Category check constraint on `dss_rules` needs `trend` added.
4. **Targeted one-click actions.**
   - `DATA_QUALITY_LOW`: list the cohort's non-respondents and send them a
     reminder (existing notifications; server-side insert, never from the
     client).
   - `UNEMPLOYMENT_HIGH`: list unemployed respondents in the cohort and send
     matching active job postings (same course / line of business).
   - Log the action in `dss_flag_notes` and set the flag to `in_progress`, so
     the impact check closes the loop.
   Replaces the current text-only handoff in `dss_action_bridge.dart`.
5. **Automatic nightly evaluation with alerts.** Move evaluation to the
   database (SQL function or edge function), schedule with pg_cron (already
   used for notifications), and notify admins of new critical flags through
   the existing notification system. Largest effort; results no longer depend
   on who presses Refresh.
6. **AI theme summary of curriculum suggestions.** Group `ched_33` /
   `ched_34` free text into themes with counts and real quotes, replacing the
   fixed keyword list in `_themeHints`. Show only actual alumni text. Keep a
   non-AI fallback. Requires AI to be configured.
7. **Program report card.** One-page export per course: metrics vs
   institution average, trends, open and resolved flags, actions taken and
   impact verdicts. Useful for CHED and AACCUP reviews. Extend
   `dss_export_service.dart`.

## Testing

- Unit tests for the Wilson interval, roll-up selection, trend comparison and
  the corrected salary peer median.
- Use the demo data (`docs/demo-data-plan.md`): employment is varied by course
  so flags, roll-ups and confidence labels can be checked with real numbers.

## Related plans

- `docs/access-link-plan.md`
- `docs/demo-data-plan.md`
- Registration security fix (server-side email code, roster check, no
  reset/wipe of existing accounts): done in the database audit (Phase 1);
  registration now uses Supabase Auth email OTP and `link_alumni_registration`.
