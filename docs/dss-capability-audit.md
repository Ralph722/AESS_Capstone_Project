# Program Insights (DSS) capability audit and roadmap

Status: audit complete, nothing implemented. Audited on 2026-10-08.
Phase 0 re-inspection and the phased implementation plan (Phases 0 to 10) are
in Part 10; that plan replaces the original roadmap in Part 9.
Supersedes the open items in `dss-improvement-plan.md` (2026-10-02); several
of those (salary peer median excluding the cohort's course, roll-up of small
groups, wave-over-wave trend rule) are already implemented.

Any database change listed here must be reported and approved before it is
applied.

## Summary

The DSS is a sound deterministic flagger running with unsafe live settings.
It answers "is this course/batch over threshold X on rule Y, and how sure are
we?" well. It does not rank, compare or trend groups, so most "which group is
highest", "course vs course" and "over graduation years" questions are not
supported by the DSS. The Reports page answers some of them descriptively,
without detection or recommendations.

Most important findings:

1. All outcome rules have min responses = **1** in the live database (seeded
   at 20) and the response-rate threshold is **0**. All 9 live flags have a
   sample of 1. The sample-size protection exists in code but is disabled by
   configuration.
2. Resolved and dismissed flags are raised again on the next "Refresh
   insights" for the same wave. Live data shows `DATA_QUALITY_LOW` for one wave
   resolved, re-raised and resolved again. Old-wave flags also stay open next
   to new-wave flags for the same group.
3. "Unemployment" means "not presently employed": Q16 "No" includes alumni in
   further study, with family reasons, or not looking for work (Q17), which
   overstates labour-market unemployment.
4. The impact check ("did the intervention work?") recomputes the metric on
   the same wave that raised the flag, so for outcome rules it mostly measures
   late submissions, not real change.
5. Min responses is checked against the group's respondent count, not the
   number who answered the question. A group of 20 can raise a
   time-to-first-job flag from 3 answers.
6. Architecture: keep it, restructure in a targeted way. The missing piece is
   a server-side store of metric values per group, from which flags, rankings,
   comparisons and trends are all derived.

Live data at audit time: 8 roster alumni, 3 linked accounts, 3 courses,
1 graduation year; 5 published CHED waves all titled
"CHED Graduate Tracer Survey (GTS)", each with at most 1 response. New
capabilities must be tested with seeded data.

## Part 1: Architecture as implemented

| Layer | Files / objects |
|---|---|
| Rules and flags (DB) | `dss_rules`, `dss_flags`, `dss_flag_notes`, `dss_flag_checks`; unique active-flag index on `(rule_id, cohort_level, course, batch_year, survey_id)` where status is open / in_progress |
| Server logic (DB) | `gts_respondent_facts` view, `gts_metric()`, `dss_recheck_open_flags()` (cron 03:15 Manila), `dss_update_flag_status()`, `dss_run_flag_action()`, status-transition guard trigger |
| Engine (Dart, runs in the admin's browser) | `dss_evaluation_service.dart`, `dss_metrics.dart`, `dss_rollup.dart`, `dss_impact.dart` |
| Copy / AI / actions / exports | `dss_copy.dart`, `dss_ai_service.dart`, `dss_suggestion_themes.dart`, `dss_action_service.dart`, `dss_export_service.dart` (CSV), `dss_report_card*.dart` (program PDF) |
| UI | `admin_dss_page.dart`, `admin_dss_detail_page.dart`, `admin_dss_history_page.dart`, `admin_dss_settings_page.dart` |
| Tests | `test/dss_evaluation_test.dart` |

Data flow:

```text
DATABASE   survey_responses (answers jsonb, unique per survey+user, submitted only)
           surveys (template_key = ched_gts_builtin, published/closed, not archived)
           alumni_members (course, year_graduated = "batch", auth_uid, is_deactivated)
RETRIEVAL  "Refresh insights" → browser loads all roster rows, all surveys,
           then responses per CHED wave (deduped by user)
TRANSFORM  response.user_id → roster member via auth_uid → course / batch
           (no match or blank → "Unknown"); bucket per wave × course × batch
ANALYSIS   DssMetrics: shares (hits/total) + 95% Wilson interval;
           salary = median bracket rank
RULES      DssRollup: groups below a rule's min responses pool into the course,
           then the institution; crosses(operator, value, threshold);
           certainty = "confirmed" when the interval's favourable end still
           crosses, else "possible"
INSIGHT    upsertActiveFlag → dss_flags (title, body with value + n, evidence JSON)
RECOMMEND  rule.recommended_action + playbook steps + per-rule interventions
UI         list (counts, filter, sort, search, CSV) → detail (why, range,
           certainty, roll-up note, source, Q33/Q34 themes, one-click actions,
           notes, owner, status, impact) → history → rules → report card PDF
SERVER     nightly dss_recheck_open_flags → still_triggered / recovered /
           no_data (never auto-resolves, never raises new flags)
```

Tracer items used by the DSS: Q16, Q24 (`ched_24a`), Q29, Q30 (current job,
falling back to first job), Q31 (initial first-job salary), Q32, Q33/Q34
(display only), and roster `course` / `year_graduated`.

Collected but unused: Q13 exams, Q14 reasons for course, Q15a/b training and
advanced studies, Q17 reasons not employed, Q18 employment type, Q19
occupation, Q20 industry, Q21 local/abroad, Q22 first job?, Q23/Q25/Q26
reasons (staying, accepting, changing), Q27 time in first job, Q28 how the
first job was found, Section A (sex, civil status, province, region,
residence).

Time reference: Q16–Q21 describe the present job; Q22–Q29, Q31 and Q32
describe the first job.

## Part 2: Capability matrix

Legend: ✅ fully supported, 🟡 partially, ❌ not supported, ⚠️ supported but
potentially incorrect. **DSS** = flag engine and report card PDF.
**Reports** = descriptive Reports page with course/batch filters.

### Employment

| # | Question | DSS | Reports | Why |
|---|---|---|---|---|
| 1 | Overall unemployment rate | ⚠️ | ⚠️ | Report card shows institution "not employed" per wave; Reports has an employment-rate KPI. Both count further study / not looking as not employed. The engine only computes the institution group when a roll-up happens. |
| 2–3 | Batch with highest / lowest rate | ❌ | 🟡 | DSS flags only over a fixed threshold, no ranking. Reports "Employment by batch" lists the rates. |
| 4–5 | Course with highest / lowest | ❌ | 🟡 | Same; Reports "Employment by course" and "Course comparison". |
| 6 | Worst course + batch | 🟡 | 🟡 | Engine evaluates every course × batch but reports only those over threshold, unranked. Reports needs one filter per course. |
| 7–8 | Unemployed count per batch / course | ❌ | 🟡 | DSS stores counts only inside flags. Reports shows employed/answered. |
| 9 | Trend over graduation years | ❌ | 🟡 | No batch-ordered trend logic; the by-batch chart is visual only. |
| 10 | Recent batches unusually high | 🟡 | ❌ | Fixed threshold, not "unusual" relative to peers or years since graduation. |
| 11 | Courses consistently high across batches | ❌ | ❌ | No persistence rule. |
| 12 | Course with most unemployed (count) | ❌ | 🟡 | DSS works in rates only. |
| 13 | Small-sample context | ⚠️ | 🟡 | Code has min responses, Wilson intervals, certainty, low confidence below 20, roll-up. Live min = 1, and the check uses group size, not question answers. Reports only shows "Small sample" below 5. |

### Employment type (Q18)

| # | Question | DSS | Reports | Why |
|---|---|---|---|---|
| 14 | Batch with most regular/permanent | ❌ | 🟡 | Q18 collected; Reports donut per filter. |
| 15 | Course with most contractual | ❌ | 🟡 | Same. |
| 16 | Course with most self-employed | ❌ | 🟡 | Q18 and Q30 both have "Self-employed". |
| 17 | Course with most part-time | ❌ | ❌ | No data: Q18 has no part-time option ("Casual" is nearest). |
| 18 | Groups with largest unemployed share | 🟡 | 🟡 | Only through threshold flags. |
| 19 | Types changing across batches | ❌ | 🟡 | Wave comparison covers Q18 across waves, not batches. |

### Degree alignment

| # | Question | DSS | Reports | Why |
|---|---|---|---|---|
| 20–21 | Course / batch with highest mismatch | 🟡 | 🟡 | `RELATEDNESS_LOW` per course × batch, unranked. Metric is Q24 = No **or** Q32 = No and describes the first job. |
| 22–23 | Highest / lowest alignment | 🟡 | 🟡 | `RELATEDNESS_HIGH` flags ≥ 75%; no ranking. |
| 24 | Alignment trend over graduation years | ❌ | ❌ | |
| 25 | Industries employing out-of-field alumni | ❌ | ❌ | Q20 is the present job, Q24 the first job; a cross-tab is only valid where Q22 = Yes. |
| 26 | Courses where most work out of field | 🟡 | 🟡 | Threshold 40% is "many", not "most"; configurable. |

### Time to first job (Q29, categorical)

| # | Question | DSS | Reports | Why |
|---|---|---|---|---|
| 27 | Average time | ❌ | 🟡 | Brackets, so an average isn't defensible; a median bracket is. Reports shows the distribution. |
| 28–29 | Slowest batch / course | 🟡 | 🟡 | `TIME_TO_JOB_LONG` (1+ years share) above threshold only. |
| 30 | Fastest course | ❌ | 🟡 | |
| 31 | Newer batches faster or slower | ❌ | ❌ | Also biased: recent graduates can't have waited 3 years yet, and never-employed alumni have no Q29 answer. |
| 32 | Long waits concentrated in courses | 🟡 | 🟡 | Via flags. |

Q29 "Others, please specify" counts in the denominator but never as a long
wait.

### Salary (Q31 = initial first-job salary, brackets)

| # | Question | DSS | Reports | Why |
|---|---|---|---|---|
| 33 | Most common range | 🟡 | ✅ | Report card shows the median bracket; Reports shows the distribution. |
| 34 | Course with highest median | 🟡 | 🟡 | `SALARY_STAGNATION` uses median bracket ranks (defensible, no means) but only to flag gaps. |
| 35 | Course with lowest | 🟡 | 🟡 | Flags groups 1+ bracket below other courses. |
| 36 | Batch with highest | ❌ | 🟡 | Batch groups are compared with other courses, not other batches. |
| 37 | Salary improving over years | ❌ | ❌ | Feasible as an entry-salary trend by batch (inflation caveat). |
| 38 | Related jobs pay more? | ❌ | ❌ | Q24 and Q31 both describe the first job, so this cross-tab is well-founded. |
| 39 | Out of field **and** lower salary | ❌ | ❌ | Two separate flags; nothing combines them. |

"Stagnation" is a misnomer: the rule is a peer gap at one point in time.

### Industry, location, further studies

| # | Question | DSS | Reports | Why |
|---|---|---|---|---|
| 40 | Top industry | ❌ | ✅ | Reports "Industry (employed)". |
| 41 | Growing industries in newer batches | ❌ | ❌ | |
| 42 | Courses per industry | ❌ | 🟡 | One course filter at a time. |
| 43–44 | Industry mismatch; unrelated industries per course | ❌ | ❌ | Time-reference problem as #25; no course-to-industry mapping. |
| 45 | High demand, poor outcomes | ❌ | ❌ | No labour-demand data besides internal job postings. |
| 46 | Where employed | ❌ | ✅ | Only Local vs Abroad (Q21). |
| 47 | Geographic concentration | ❌ | 🟡 | Residence province (Q10) exists; Reports "Graduate location" mostly falls back to country. |
| 48 | Courses working outside the region | ❌ | 🟡 | Only Abroad vs Local; no workplace region collected. |
| 49 | Migration trend across batches | ❌ | ❌ | |
| 50 | Unemployed concentrated geographically | ❌ | ❌ | Q10 × Q16 feasible (residence, not workplace). |
| 51 | % pursued further studies | ❌ | 🟡 | No direct question. Proxies: Q15b answered, Q15a rows (mixes trainings and degrees), Q17 "further study". Reports shows only Q15b reasons. |
| 52–53, 55 | By course / batch / trend | ❌ | ❌ | |
| 54 | Types of further study | ❌ | ❌ | Q15a titles are free text. |
| 56 | Further study vs employment | ❌ | ❌ | Further-study alumni are counted as "not employed" in the DSS. |

### Comparisons, trends, detection

| # | Capability | DSS | Notes |
|---|---|---|---|
| 57 | Course vs course | 🟡 | Salary peer gap and report card (program vs institution). Reports course table covers employment only. |
| 58–60 | Batch vs batch; course within batch; batch within course | ❌ | Reports 🟡 through filters, employment only. |
| 61–65 | Recent vs older; employed vs unemployed; related vs not; further study vs not; industry vs industry | ❌ | |
| 66 | Increasing unemployment | ✅ | `UNEMPLOYMENT_TREND_UP`, wave over wave, same group, Newcombe interval, min 10 in both waves. Waves are cross-sectional, so change can reflect who answered. |
| 67 | Decreasing unemployment | ❌ | Rises only; Settings can't change the operator. |
| 68–71, 73 | Mismatch, alignment, salary, type, time-to-job trends | ❌ | Descriptive only (report card wave table, CHED wave comparison export). |
| 72, 74, 75 | Further-study, industry, geographic trends | ❌ | |
| 76 | High unemployment | ✅ | `UNEMPLOYMENT_HIGH` (definition caveat). |
| 77, 79 | High mismatch / low alignment | ✅ | `RELATEDNESS_LOW` (composite, first job). |
| 78 | Long time to first job | ✅ | `TIME_TO_JOB_LONG` (caveats above). |
| 80 | Salary concerns | 🟡 | First-job salary peer gap only; skipped at institution level. |
| 81 | Significant decline | ✅ | Trend rule. |
| 82 | Significant change between batches | ❌ | |
| 83–84 | Unemployment concentrated in a course / batch | 🟡 | Absolute threshold per group, not "significantly above the institution". Course-level flags appear only on roll-up. |
| 85 | Other | ✅ | `DATA_QUALITY_LOW`, `UNDEREMPLOYMENT`, `RELATEDNESS_HIGH`. |

### Rules (seed → live values at audit time)

| Rule | Metric and formula | Threshold | Comparison | Min n | Severity | Recommendation (static) |
|---|---|---|---|---|---|---|
| `DATA_QUALITY_LOW` | Submissions ÷ whole current roster of the group; also fires when submissions < min n | < 0.40 → **< 0** | Absolute; course × batch only | 0 → 2 | warning | Reminder campaign (text varies: sparse / low rate / both) |
| `UNEMPLOYMENT_HIGH` | Q16 ∈ {No, Never Employed} ÷ Q16 answered | ≥ 0.25 → **≥ 0.20** | Absolute | 20 → **1** | critical | Career Center job fairs, counselling, job-board outreach |
| `RELATEDNESS_LOW` | (Q24 = No or Q32 = No) ÷ answered either | ≥ 0.40 | Absolute | 20 → **1** | warning | Curriculum committee review with Q34 themes |
| `RELATEDNESS_HIGH` | 1 − the above | ≥ 0.75 | Absolute | 20 → **1** | info | Document and share practices |
| `UNDEREMPLOYMENT` | Rank/Clerical ÷ employed with a Q30 level (current job, else first job) | ≥ 0.35 | Absolute | 20 → **1** | warning | Career-path / curriculum pathway review |
| `TIME_TO_JOB_LONG` | Q29 in 1–4-year brackets ÷ Q29 answered | ≥ 0.40 | Absolute | 20 → **1** | warning | OJT partnerships, earlier counselling |
| `SALARY_STAGNATION` | Median Q31 rank of other courses − group median | ≥ 1 bracket | Other courses, same wave | 20 → **1** | info | Industry alignment, employer partnerships |
| `UNEMPLOYMENT_TREND_UP` | Current − previous wave not-employed rate, same group | ≥ +0.10 | Previous wave | 10 | warning | Investigate the change and start support |

Shared behaviour:

- Trigger: value crosses the threshold and the group's respondent count is at
  least min n.
- Upsert: updates an existing open/in-progress flag for the same rule, group
  and wave; otherwise inserts a new one.
- Status: Open → In Progress (Start or a one-click action) → Resolved or
  Dismissed; Reopen available. Resolve requires In Progress, an intervention,
  a note and "proof".
- Nightly re-check marks flags recovered without closing them. Resolving
  computes an impact verdict and sets a 7-day re-check date.

## Part 3: Sample size and data quality

| Concern | Handled? | Detail |
|---|---|---|
| Respondent counts | ✅ | `sample_n`, `eligible_n` (whole roster) and registered count stored and shown. |
| Small samples | ⚠️ | Good logic, but: live min = 1; Settings has no floor; min is checked against group size, not the question denominator; nightly re-check ignores min for outcome rules; severity and sorting ignore certainty. (The existing "AI prioritize" button also ignores it; it is retired in Phase 5, and priority becomes deterministic.) |
| Null / missing answers | 🟡 | Excluded from denominators (correct), but item non-response is never surfaced. |
| Incomplete responses | ✅ | Submitted only. |
| Duplicate responses | ✅ | Unique (survey_id, user_id) plus dedup by user in code. |
| Multiple waves | ⚠️ | Each wave evaluated independently (no double counting), but all published waves are evaluated, old-wave flags stay open, and identical titles make waves indistinguishable. |
| Respondents not on the roster | ⚠️ | Bucketed as "Unknown" and can produce an "Unknown · Batch Unknown" flag. Dart counts them in the institution group; the SQL re-check excludes them. |
| Roster at wave time | ❌ | Response rates use the current roster. |
| Alumni without employment info | 🟡 | Excluded per metric. Never-employed alumni are excluded from time-to-job, so long waits look rarer. |
| Privacy | ⚠️ | A 1-respondent flag reveals that person's employment status to every admin. |

### AESS DSS sample-size policy (final, authoritative)

The AESS DSS does not generate substantive institutional findings from fewer
than 10 valid answers to the relevant metric.

"Valid answers" always means the denominator of the specific question or
metric (`share.total`), never the group's total respondent count. Example: if
20 alumni belong to a cohort but only 3 answered Q29, the Q29 metric has
n = 3 and cannot generate a substantive Q29 finding.

| Valid answers to the metric | State | Behaviour |
|---|---|---|
| Fewer than 5 | Not enough data | No substantive rate is calculated or shown for decision support; no finding is created. |
| 5–9 | Watch | Shown to admins with an explicit small-sample warning. Not an active substantive finding and not treated as a normal institutional finding. |
| 10–29 | Finding allowed (limited evidence) | Normal finding evaluation, with evidence strength and confidence always visible. |
| 30 or more | Finding allowed (strong evidence) | Normal behaviour. |

Minimums per rule category:

- **Outcome / problem rules:** at least 10 valid answers to the metric.
- **Opportunity / success rules:** at least 10 valid answers to the metric.
- **Trend rules:** at least 10 valid answers in each wave being compared.
- **Data-quality rules (the exception):** these measure survey coverage
  against the roster, not institutional outcomes. They may fire at any
  response count, including zero, provided the group has at least 1 roster
  member. Their `min_n` acts as the "too few responses" trigger, not as a
  gate.

Evidence strength stored on each finding: `insufficient` (under 5), `watch`
(5–9), `limited` (10–29), `strong` (30 or more).

When the response rate is below 30%, a coverage warning is attached to every
outcome finding for that group.

The policy is enforced the same way in the Dart reference calculations, the
SQL calculations, the DSS rules and Settings, server-side and scheduled
evaluation, manual Refresh, the UI, exports and tests.

### AESS DSS group-mapping policy (final, authoritative)

A respondent may contribute to a course or batch finding only when the
corresponding roster information is reliably known. Course and batch come
from the linked roster record (`alumni_members`), never from guesses.

| Case | Course | Batch | Rule |
|---|---|---|---|
| 1 | Known | Known | May contribute to course × batch metrics and findings. |
| 2 | Known | Missing or unmatched | Batch labelled "Batch not recorded". May contribute to the course-level metric where the metric is defined at course level. Must not contribute to any specific batch finding. |
| 3 | Missing or unmatched | Known | Must not be assigned to a course and must not generate a course-specific finding. May contribute to institution-level metrics only where the metric definition explicitly permits it. |
| 4 | Missing or unmatched | Missing or unmatched | Classified as "Unclassified" (batch "Batch not recorded"). Must not generate course-level or batch-level findings. May contribute to institution-level metrics only where the metric definition explicitly permits it. |

General rule: never infer, guess or assign a respondent to a course or batch
that cannot be reliably established from roster data. This prevents false
course or batch findings, misleading "Unknown · Batch Unknown" findings, and
Dart/SQL discrepancies. Dart and SQL / server-side calculations must use this
same policy.

## Part 4: Recommendation quality

| Check | Result |
|---|---|
| Data-driven trigger | ✅ Every flag traces to rule, threshold, value, n, interval and wave. |
| Specific about group and value | ✅ e.g. "25.0% of 20 respondents in BSIT · Batch 2025 are not presently employed", with the threshold shown. |
| Actionable | 🟡 Playbook steps, intervention menus, two one-click actions (reminders, job matches). Recommendation text is static per rule. |
| Who should act | 🟡 Text names a role, but the owner is only an admin user: no office, no due date before resolution. |
| Explains why | ✅ `whyFlagged`, `certaintyHint`, `thresholdLabel`, `sourceLabel`, `rollupNote`. `sourceLabel` is stale ("the dashboard uses employment records"; that data now comes from the CHED tracer). |
| Status workflow | ✅ Open / In Progress / Resolved / Dismissed / Reopen with a DB guard. |
| Action history | ✅ Typed notes plus audit log. |
| Resolution tracking | ⚠️ Impact verdict computed on the same wave. |
| Duplicates / repeats | ⚠️ Closed flags re-raise; old-wave flags remain open; batch and roll-up flags can overlap; `RELATEDNESS_LOW` and `RELATEDNESS_HIGH` both open for the same group across waves. |
| Workflow friction | ⚠️ Resolve needs a linked announcement or "Other" + description. Offline actions and completed one-click job matches don't count as proof. |
| Cause-specific advice | ❌ Q17 reasons ignored; all unemployment gets job-fair advice. |

Overall: medium strength. Strong form needs Q17-aware advice, an owner office
and a due date.

## Part 5: Additional questions the data supports

| Question | Data | Available? | Calculation | Value | Priority |
|---|---|---|---|---|---|
| Of those not employed, how many are seeking work? | Q16 + Q17 | ✅ | Exclude further study / family / not looking | Fixes the core metric | Critical |
| Why are alumni not employed, per group? | Q17 | ✅ | Reason shares | Right intervention | Critical |
| Which courses rely on contractual/casual work? | Q18 | ✅ | Share among employed | Job quality | High |
| Does a degree-related first job pay more? | Q24 × Q31 | ✅ | Median bracket by relatedness | Curriculum value | High |
| Do alumni move up from clerical first jobs? | Q30 both columns | ✅ | First → current transitions | Career mobility | High |
| Is the placement office used? | Q28 | ✅ | Share via school placement / job fair | Career Center effectiveness | High |
| Is a group significantly worse than the institution? | Existing metrics | ✅ | Newcombe interval, group − rest | Relative detection | High |
| Did flagged groups improve in the next wave? | Flags + next wave | ✅ | Same metric, next wave | True impact | High |
| Abroad share per course | Q21 | ✅ | Share | Out-migration | Medium |
| Early first-job exits and why | Q27 + Q26 | ✅ | Short-tenure share, reasons | Retention | Medium |
| Licensure pass counts per board program | Q13 | 🟡 free text | Count named exams | Accreditation | Medium |
| Transitions among repeat respondents | Same user across waves | ✅ | Unemployed → employed rates | Better trends | Medium |
| Competencies that matter per course | Q33 + Q34 | ✅ | Ranked picks, themes | Curriculum input | Medium |

## Part 6: Feature gaps

| Capability | Current status | Data? | Logic? | UI? | Priority |
|---|---|---|---|---|---|
| Enforced sample-size floors | Configurable, set to 1 | ✅ | Partial | Settings, no floor | Critical |
| Suppress repeats of closed / old-wave flags | Missing | ✅ | ❌ | ❌ | Critical |
| Seeking-work unemployment (Q17) | Missing | ✅ | ❌ | ❌ | Critical |
| Min check on the question denominator | Wrong basis | ✅ | Partial | n/a | Critical |
| Next-wave impact evaluation | Same wave only | ✅ | Partial | Partial | High |
| Ranked course × batch tables per metric | Missing | ✅ | Metrics exist | ❌ | High |
| Group vs institution significance rules | Missing | ✅ | Wilson/Newcombe exist | ❌ | High |
| Employment-type, abroad, Q17-reason metrics | Missing | ✅ | ❌ | Reports only | High |
| Severity / priority score | Static severity | ✅ | ❌ | Sort by severity | High |
| Owner office + due date | Admin user only | ✅ | ❌ | Partial | High |
| Server-side scheduled evaluation | Manual, in browser | ✅ | Re-check only | ❌ | High |
| Single metric definition (Dart vs SQL) | Duplicated, small drift | ✅ | Both | n/a | Medium |
| Trends for other metrics, both directions | Missing | ✅ | Pattern exists | ❌ | Medium |
| Graduation-year trends | Missing | ✅ | ❌ | Reports (visual) | Medium |
| Cross-tabs | Missing | ✅ (time-reference caveat) | ❌ | ❌ | Medium |
| Cause-specific recommendations | Missing | ✅ | ❌ | ❌ | Medium |
| Institution-wide DSS report export | Flags CSV + program PDF | ✅ | Partial | Partial | Medium |
| Distinct wave labels | All waves share one title | ✅ | ❌ | ❌ | Medium |
| Further-study metrics | Proxies only | 🟡 | ❌ | Reasons only | Low |
| Industry demand vs outcomes | No demand data | ❌ | ❌ | ❌ | Low |

## Part 7: Recommended next features (in order)

1. Correctness guardrails: the sample-size policy in Part 3 (at least 10
   valid answers to the metric for substantive findings, Watch at 5–9, "Not
   enough data" below 5), no re-raising of resolved/dismissed flags for
   the same wave, superseding old-wave flags.
2. Seeking-work unemployment and Q17 reason breakdown (keep "not employed"
   visible; use "unemployed and seeking" as the rule metric).
3. Server-side metric layer: per wave × course × batch × metric, store hits,
   total and interval. Flags, rankings and the report card read from it; ends
   the Dart/SQL duplication.
4. Ranked group views with n, likely range and suppression (answers 2–8,
   14–16, 20–23, 28–30, 34–36).
5. Relative and trend rules: group vs rest (significance-based), wave-over-wave
   both directions for all metrics, persistence across batches/waves.
6. Priority score: rule weight × distance past threshold × certainty ×
   affected count; used for deterministic sorting and prioritization of
   findings.
7. Recommendation management: owner office, due date, cause-specific text,
   one grouped finding per group.
8. Next-wave impact check and outcomes by intervention type in History.
9. Institution DSS report export (PDF: top findings, actions, outcomes).
10. AI explanation of the deterministic tables (narrative only).

## Part 8: AI's role

AI is used only for facts-based explanations and narrative summaries of
findings that have already been produced by the deterministic DSS. Today that
means the flag briefing (facts-only input, deterministic fallback) and Q34
suggestion grouping (verbatim quotes, invalid indexes dropped, tested). The
existing "AI prioritize" button is retired in Phase 5; priority is
deterministic.

AI must not create, detect, close or resolve findings, prioritize or rank
them, override DSS priority, determine severity, or decide whether an
intervention succeeded. Keep this boundary: pass only computed values and n,
and require the output to restate them.

Decision flow: data → metrics → deterministic DSS rules → finding →
deterministic priority → recommendation → intervention → outcome → admin
decision → optional AI explanation.

## Part 9: Final report

1. **Current capabilities:** eight deterministic rules per CHED wave and
   course × batch with roll-up; Wilson intervals with certainty; wave-over-wave
   unemployment trend; status workflow with notes, owners, impact verdicts and
   nightly re-checks; two one-click actions; CSV export; program report card
   PDF; history statistics; editable thresholds.
2. **Answerable now:** whether a group crosses the unemployment, mismatch,
   clerical, long-wait or salary-gap threshold, and how certain; rising
   unemployment between waves; program vs institution per wave; coverage
   problems; basic distributions on the Reports page.
3. **Not answerable:** rankings, comparisons, graduation-year trends;
   employment-type, industry, location and further-study analysis; cross-tabs;
   improving trends; next-wave intervention effect; part-time work (no data).
4. **Incorrect or risky analysis:** live min = 1; repeated and stale flags;
   further study / not looking counted as unemployed; same-wave impact check;
   min checked on group size; Q29 "Others" and never-employed handling;
   "salary stagnation" naming and batch groups compared with other courses;
   current-roster denominators; "Unknown" groups; Dart/SQL drift; identical
   wave titles; single-respondent privacy exposure.
5. **Missing data and relationships:** no part-time option; no workplace
   region; no direct further-study question; no course-to-industry map; no
   roster snapshot per wave; `gts_respondent_facts` lacks Q17, Q22, Q28, Q15,
   first/current Q30, province and sex.
6. **Missing calculations:** seeking-work rate; Q17/Q18/Q21/Q28 shares; median
   time-to-job bracket; group-vs-rest differences; cross-tabs; persistence;
   priority score.
7. **Missing rules:** relative-to-institution, improving trends, persistence,
   non-unemployment trends, contractual work, abroad share, placement usage.
8. **Missing UI and workflow:** ranked explorer and comparison views; Watch
   state; owner office and due date; one-click actions and offline
   interventions accepted as proof; finding grouping; institution report;
   scheduled server evaluation.
9. **Recommended next features:** Part 7.
10. **Roadmap:** replaced by the Phase 0 to 10 plan in Part 10. Analysis
    ideas from the original roadmap that are not part of that plan are kept
    as deferred items in section 10.10.

## Part 10: Phase 0 re-inspection and implementation plan (Phases 0 to 10)

Status: plan only, nothing applied. Phase 0 re-inspection done on 2026-10-08
with read-only database queries. Each later phase waits for "PROCEED TO NEXT
PHASE", and each phase's database changes must be approved before they are
applied.

The plan rests on three findings:

- **Two metric engines.** The DSS page computes metrics in Dart in the
  admin's browser (`DssMetrics`). The nightly re-check uses separate SQL
  (`gts_metric` / `gts_respondent_facts`). The Flutter app never calls the
  SQL layer, and the two already disagree on who counts in the
  institution-level group.
- **Findings are only created on "Refresh insights".** No scheduled job
  raises new findings.
- **The schema blocks several spec goals.** The finding status check, the
  active-flag unique index and the minimum-responses setting all need
  additive changes.

### 10.1 Confirmed architecture

| # | Area | Confirmed state |
|---|---|---|
| 1 | Tables | `dss_rules` (15 columns), `dss_flags` (32), `dss_flag_notes`, `dss_flag_checks`. Source data comes from `survey_responses` (one per survey and user), `surveys` (dates in `open_at`/`close_at`; published/archived stored in `data` jsonb) and `alumni_members` (current roster only, no history). Views: `gts_respondent_facts`, `gts_employment_records`. |
| 2 | Rules | 8 live rules. Live minimum responses (`min_n`) are 1, 2 and 10, not the original seed values of 20. The database doesn't enforce any `min_n` limit, and the Settings page only checks that the value is a number (0 or negative values save). |
| 3 | Metric calculations | Dart (`DssMetrics`) is used by Refresh; SQL (`gts_metric`) is used only by the nightly check. SQL limits counts to active roster members, while Dart also includes non-roster respondents in the institution group. Q29 "Others" counts in the denominator. Q17 is unused. |
| 4 | Sample size | `maybeRaise` compares the group size, not the number who actually answered the item. Below 20, a finding is marked "low confidence" but still raised. There is no "Not enough data" state and no privacy cut-off. |
| 5 | Flag lifecycle | Statuses: open, in_progress, resolved, dismissed, plus reopen. A trigger blocks closed-to-closed changes. The unique index only covers open/in_progress, so after a close the next Refresh inserts a new flag for the same rule, group and wave (confirmed live). Flags on old waves never close themselves. |
| 6 | Recommendations | One fixed text and playbook per rule (`dss_rules.recommended_action`, `playbook` jsonb) plus `DssCopy`. Not cause-specific. AI only rephrases. |
| 7 | Owner | `assigned_to` (admin user accounts only) and a "mine" filter. No office, no responsible person outside the system, no due or review dates. |
| 8 | Action / proof | Intervention type and detail, a linked announcement, and `dss_run_flag_action` (survey reminder for data quality, job matches for unemployment). Offline work can only be recorded as "Other" plus text. |
| 9 | Impact | `recomputeMetricForFlag` re-checks the same wave, so it measures coverage, not before/after. The verdict is set 7 days later. The nightly `dss_flag_checks` records still_triggered / recovered / no_data, never auto-resolves, and ignores `min_n` for outcome rules. |
| 10 | Scheduled jobs | Only `aess-dss-recheck` runs nightly, at 19:15 UTC. No scheduled evaluation creates findings. |
| 11 | Reports | Employment rate uses each alumnus's latest answer across waves; other charts combine waves. Calculated separately from DSS, so the numbers can disagree. |
| 12 | GTS data model | Answers are jsonb keyed `ched_N`. The facts view omits Q17, Q22 and Q28. All 7 CHED waves have the same title. |
| 13 | RLS | All DSS tables are admin-only through `is_admin()` plus `active_caller_only`. `dss_flag_checks` is read-only for admins and written by the service role. `survey_responses` is visible only to its owner or an admin. |
| 14 | Admin permissions | A single role (`users.role = 'admin'`) with 1 admin live. No office-level roles. All SECURITY DEFINER functions check `is_admin()`. |
| 15 | Tests | `test/dss_evaluation_test.dart` covers pure functions. `supabase/regression/phase5_gts_analytics.sql` has a baseline. There are no DSS page widget tests and no lifecycle or re-raise tests. |

Live data at inspection time: 9 flags, all BSIT 2027, each based on 1
respondent. There are 5 submitted responses across 7 CHED waves, so real
statistics can't be tested; seeded test data is required.

Other confirmed details:

- Edge Functions: `send-push`, `send-email` and `tracer-help`; none touch DSS.
- DSS triggers: `set_updated_at` on rules and flags, the status-transition
  guard on `dss_flags`, and author stamping on `dss_flag_notes`.
- DSS indexes: the active-cohort unique index, plus status / rule /
  verify-due / assigned / note indexes. `survey_responses` has a
  (survey_id, status) index.

### 10.2 Dependency map

Every rule follows the same path:

1. The `dss_rules` row.
2. `DssEvaluationService.evaluateAll`, running in the browser.
3. `DssRepository.upsertActiveFlag`.
4. A `dss_flags` row.

From there:

- the DSS list and detail pages display it;
- recommendations come from `recommended_action` / `playbook` plus `DssCopy`;
- interventions go through `dss_update_flag_status`, `dss_run_flag_action`
  or `linkAnnouncement`;
- status changes pass the guard trigger;
- history lands in `dss_flag_notes`, the nightly `dss_flag_checks`, the CSV
  export and the program PDF.

| Rule | Metric (Dart → SQL key) | Source answers | Built-in action |
|---|---|---|---|
| `DATA_QUALITY_LOW` | response rate → `response_rate` | submissions ÷ current roster (batch only) | survey reminder |
| `UNEMPLOYMENT_HIGH` | `unemployment` → `unemployment_rate` | Q16 No / Never Employed ÷ answered Q16 | job matches |
| `RELATEDNESS_LOW` | `relatedness` → `unrelated_or_irrelevant_rate` | Q24a No or Q32 No (Q34 suggestions as evidence) | none |
| `UNDEREMPLOYMENT` | `clerical` → `clerical_among_employed_rate` | Q16 Yes + Q30 Rank or Clerical | none |
| `TIME_TO_JOB_LONG` | `longTimeToFirstJob` → `long_time_to_first_job_rate` | Q29 ≥ 1 year (Others in denominator) | none |
| `SALARY_STAGNATION` | `salaryGap` → `salary_peer_gap` | Q31 bracket, cohort median vs peer median | none |
| `RELATEDNESS_HIGH` | `relatedness` → `related_and_relevant_rate` | Q24a / Q32 | none (opportunity) |
| `UNEMPLOYMENT_TREND_UP` | trend → `unemployment_change_pts` | Q16 across two waves | none |

### 10.3 Implementation dependencies

- The sample-size policy and the group-mapping policy in Part 3 apply to
  every phase. Dart and SQL / server-side calculations must use the same
  policies.
- **Phase 1** (sample guardrails) can be done in Dart first. The database
  `min_n` constraint can only be added after the live `min_n` values are
  raised, which is a production data change.
- **Phase 2** (Q17) needs Q17 added to the facts view as well as to Dart;
  otherwise we create a third copy of the definitions.
- **Phase 3** (one server metric layer) underpins Phases 4, 7 and 8.
  Recommendation: keep the spec's order, but add each Phase 1 and 2
  definition change to SQL at the same time as Dart, so Phase 3 becomes a
  switch-over rather than a rewrite.
- **Phase 4** (finding identity, superseded) needs stable wave ordering.
  Titles are identical, so ordering must come from `open_at` / `close_at` /
  published date.
- **Phase 5** deterministic priority needs Phase 1's evidence strength and
  Phase 4's Watch state. It also retires the existing "AI prioritize"
  button, because the spec does not allow AI to prioritize findings.
- **Phase 6** owner and dates are mostly independent; cause-specific
  playbooks need Phase 2.
- **Phase 7** outcomes need Phase 3 (per-wave metrics on the server), Phase 4
  (wave lineage) and Phase 6 (baseline captured when the intervention
  starts).
- **Phase 8** (server evaluation) needs Phases 3, 4 and 5. **Phase 9** needs
  Phase 7. **Phase 10** (AI) goes last.

Evidence that Phase 8 is necessary (the spec says not to replace the engine
without evidence):

- findings only appear when an admin opens a browser and clicks Refresh;
- two metric implementations already disagree;
- concurrent Refreshes have no lock.

The plan therefore keeps the Dart engine as a fallback until parity tests
pass.

### 10.4 Proposed database changes

All changes are additive and each needs approval before it is applied. Items
marked ⚠ change existing constraints, functions or data.

**Phase 1: guardrails**

- `dss_flags.evidence_strength` (`insufficient` / `watch` / `limited` /
  `strong`, matching the Part 3 sample-size policy), a new nullable column.
- A new table `dss_wave_cohort_snapshots` (survey, course, batch, roster
  count, captured date). It stores counts only, not a copy of personal data.
- A new check constraint enforcing a minimum `min_n` per category, added
  `NOT VALID` first.
- ⚠ Raise the live `min_n` values (data update), then validate the
  constraint. Floors: at least 10 for outcome, opportunity and trend rules
  (trend: per wave); at least 1 for data quality, where `min_n` is the "too
  few responses" trigger. The value 5 is only the lower Watch boundary, not
  a rule minimum.
- Unknown and unmatched respondents: no database change. The evaluation
  applies the Part 3 group-mapping policy. A missing batch is labelled "Batch
  not recorded" and never contributes to a batch finding; a missing course is
  never assigned to a course; institution-level metrics include unmatched
  respondents only where the metric definition explicitly permits it.

**Phase 2: Q17**

- `gts_respondent_facts`: add a `not_employed_reasons text[]` column at the
  end of the view.
- ⚠ New keys in `gts_metric`.
- New rule row `SEEKING_WORK_HIGH`, inserted disabled.
- `UNEMPLOYMENT_HIGH` keeps its meaning; only its display label changes to
  "Not currently employed".

**Phase 3: metric layer**

- A new function `dss_cohort_metrics(p_survey_id)` returning, per level,
  course, batch and metric: hits, answered, non-response, eligible and roster
  counts, plus a metric version.
- It applies the Part 3 sample-size and group-mapping policies, so the
  server and the Dart reference produce the same groups and states.
- It checks `is_admin()` and is not callable by anonymous users.

**Phase 4: finding identity**

- `dss_flags` columns: `finding_key`, `superseded_by`, `superseded_at`,
  `suppression_reason` (with a check).
- One new table, `dss_evaluation_events` (run id, trigger, finding key, wave,
  outcome, reason, timestamp). Every raise, update, suppression or supersede
  is logged with its reason, which makes suppression auditable. A separate
  runs table is not needed.
- Finding grouping (`group_id`) is deferred (see 10.10).
- ⚠ Widen the status check to add `watch` and `superseded`. This also
  requires updating the guard trigger (superseded is final), the allowed
  values in `dss_update_flag_status`, and rebuilding
  `uq_dss_flags_active_cohort` to include `watch` (only to prevent duplicate
  Watch rows; Watch is never counted as an active substantive finding). The
  table has 9 rows, so the rebuild is trivial.
- ⚠ Fill in `finding_key` for the 9 existing rows (non-destructive).
  Old-wave flags are not automatically marked superseded; the first logged
  run does that.

**Phase 5: priority**

- No database change. Deterministic priority (Critical / High / Medium / Low
  / Watch) is calculated on the fly from facts the flag already holds: rule severity,
  evidence strength, answered count, how far past the threshold, and how long
  it has been open. Each priority shows its reasons. Rule `severity` stays
  unchanged.
- Stored priority columns are only added in Phase 8, when the server
  evaluates.

**Phase 6: accountability**

- `dss_flags` columns: `owner_office` (plain text; the UI offers a few
  suggested office names), `responsible_name`, `start_date`, `due_date`,
  `review_date`. `assigned_to` stays as the responsible admin. No offices
  lookup table.
- A `dss_flag_evidence` table (type, title, date, description, link). No file
  uploads for now.
- ⚠ Widen the note event types to include `evidence`.
- Playbooks stay in `dss_rules.playbook` jsonb, now keyed by cause.

**Phase 7: outcomes**

- A `dss_interventions` table with:
  - the expected outcome and success metric / operator / target;
  - the baseline value, count and wave;
  - the follow-up wave, value and count;
  - one of 7 outcome statuses (Not evaluated, Pending follow-up, Successful,
    Partially successful, Unsuccessful, Inconclusive, No comparable data);
  - evaluation note and date;
  - the admin's decision after the outcome: resolve, continue, modify or
    escalate, with a required note.
- Past occurrences and earlier interventions are linked through
  `finding_key`, so no separate "previous intervention" link is needed.
- Existing flag fields stay; older flags show "Not evaluated (legacy)". For
  new findings, the old impact verdict only appears as "Coverage Re-check",
  so admins never see two different "did it work?" answers.

**Phase 8: server evaluation**

- A `dss_evaluate_all(p_trigger)` function. It uses an advisory lock so
  concurrent runs don't collide, and is idempotent through `finding_key` and
  the run log.
- A new cron job `aess-dss-evaluate` scheduled after the existing check.
  Manual Refresh calls the same function. Both apply the Part 3 sample-size
  and group-mapping policies.
- `dss_flags` columns `priority` and `priority_reasons` jsonb, written by the
  server using the same priority logic as Phase 5.

**Phase 9: history**

- No new database objects. The History tab and an institution section added
  to the existing program report PDF read the existing tables.

**Phase 10: AI**

- No database change. AI only explains findings that the deterministic rules
  have already produced; it never detects, prioritizes, ranks or closes
  findings, and never judges whether an intervention succeeded.

**RLS for every new table:** RLS enabled, `active_caller_only` plus
`admin_all`, anonymous access revoked, and the service role only where cron
needs it.

### 10.5 Proposed code changes (by file)

- **`dss_evaluation_service.dart`:**
  - check `share.total` (answered) instead of group size, using the Part 3
    sample-size policy (Not enough data under 5, Watch at 5–9, findings from
    10);
  - set evidence strength (`insufficient` / `watch` / `limited` / `strong`);
  - apply the Part 3 group-mapping policy: "Batch not recorded" never feeds
    a batch finding, and a missing course is never assigned to a course
    (replaces the current literal `'Unknown'` groups from `_courseOf` /
    `_batchOf`);
  - Phase 4: closed-repeat check and superseding;
  - Phase 8: becomes a thin wrapper over the RPC, with the Dart engine as
    fallback.
- **`dss_metrics.dart`:** exclude Q29 Others from the denominator, add
  non-response counts and Q17 classification. It stays as the reference for
  parity tests.
- **`dss_copy.dart`:**
  - "Not enough data" and "Watch" wording;
  - fix the outdated `sourceLabel`;
  - "Coverage Re-check" label;
  - non-causal outcome wording;
  - cause-specific text.
- **`dss_models.dart` / `dss_repository.dart`:** parse the new fields with
  safe defaults. This ships before any database status change, so older app
  code never crashes on an unknown status.
- **`admin_dss_page.dart`:** filters for Watch, priority, office and overdue
  items. Phase 5 replaces the "AI prioritize" button with the rule-based
  priority sort (approved in the 2026-10-08 plan review).
- **`admin_dss_detail_page.dart`:**
  - evidence-strength banner, small-group hiding and non-response display;
  - owner and date fields, evidence list, outcome panel;
  - decision buttons after an outcome: resolve, continue, modify, escalate.
- **`admin_dss_settings_page.dart`:** `min_n` limits per category (at least
  10 for outcome, opportunity and trend; at least 1 for data quality),
  threshold limited to 0–100%, and editing playbooks by cause.
- **`dss_impact.dart`:** keep the verdicts; relabel same-wave checks.
- **`dss_export_service.dart`, `dss_report_card*.dart`:** new CSV columns are
  appended only, groups under 5 valid answers show "Not enough data" with no
  rate, Watch rows are labelled as such, and Phase 9 adds an institution
  report section.
- **`dss_ai_service.dart`:** Phase 5 stops using `prioritizeFlags`. Phase 10
  keeps only explanation: it receives facts only, is labeled "AI
  explanation", and cannot create, close, resolve, prioritize or rank
  findings, or decide whether an intervention succeeded.
- **Reports page:** wording alignment only. Its calculations stay as they are.

### 10.6 Migration order

1. Phase 1 schema (constraint `NOT VALID`), then ⚠ the `min_n` data update,
   then validate the constraint.
2. Phase 2: facts view and new rule.
3. Phase 3: `dss_cohort_metrics`.
4. Phase 4: Dart parsing ships first, then the status, index and trigger
   changes, then the evaluation-events table.
5. Phase 5: no migration (priority is calculated in the app).
6. Phase 6: ownership columns and the evidence table.
7. Phase 7: interventions.
8. Phase 8: evaluation function and priority columns, then cron (cron
   enabled only after parity passes).
9. Phase 9: no migration.

Each migration gets a matching `supabase/regression/phase12_dss_*.sql` script
with a baseline, run through `run_all.ps1`.

### 10.7 Risks

- **The DSS page will look mostly empty after Phase 1.** All 9 current flags
  rest on 1 respondent and will become "Not enough data", and no substantive
  finding appears until a group has at least 10 valid answers to the metric.
  That is correct behaviour, but expect it.
- **Status widening touches four places at once:** the check constraint, the
  trigger, the status RPC and the unique index. A mismatch here would break
  existing transitions.
- **Duplicate flags during the move to server evaluation.** Old cached web
  sessions may keep writing through the old Dart path; `finding_key` and the
  unique index guard against this.
- **Historical response rates use today's roster.** There is no roster
  history, so snapshots only start from Phase 1. Older waves will be marked
  "rate uses current roster".
- **Waves have identical titles**, so the UI must show dates to tell them
  apart.
- **Porting the statistics to SQL** (Wilson / Newcombe intervals) can produce
  small numeric differences; parity tests will catch these.
- **Cron runs with elevated rights.** The new functions must re-check access
  and never be exposed to anonymous users.
- **The CSV export currently includes groups of 1** (privacy). Reports and
  DSS numbers may also still differ for admins.
- **Retiring "AI prioritize" removes a visible button.** It is replaced by
  the rule-based priority sort in the same phase, so admins keep a way to
  rank findings.

### 10.8 Test strategy (the spec's 25 categories)

- **Dart unit tests** cover:
  - tiny, medium and large samples (1/3/5/10/20/30 respondents) (1–3),
    plus the policy boundaries at 4, 5, 9, 10, 29 and 30 valid answers;
  - the metric denominator rule (a 20-member cohort where only 3 answered
    Q29 gives no Q29 finding);
  - data-quality findings firing with zero responses when the roster is not
    empty;
  - missing answers (4) and duplicates (5);
  - multiple waves and the same group across waves (6–7);
  - Q17 recommendations (12) and success criteria (15);
  - before/after values and next-wave evaluation (16–17);
  - failed, successful and insufficient follow-up (18–20);
  - deterministic priority calculation and its reasons;
  - the four group-mapping cases (course and batch known / batch missing /
    course missing / both missing).
- **Widget tests** cover:
  - Not enough data, Watch and privacy hiding (21);
  - Settings validation;
  - owner and due dates (13–14);
  - resolve with offline evidence;
  - the resolve / continue / modify / escalate decision;
  - export columns (23).
- **SQL regression tests** run seeded fixtures inside a rolled-back
  transaction. They cover:
  - resolved and dismissed findings not re-raising (8–9);
  - Refresh run twice producing identical results (10);
  - scheduled evaluation (11);
  - RLS: non-admin and anonymous access denied (22);
  - a Dart-vs-SQL parity check on a shared fixture, covering sample-size
    states and group mapping.
- **Compatibility checks (24–25):** existing baselines, the full
  `flutter test` suite (258 tests at inspection time), `flutter analyze`, and
  the regression list (rules, flag creation, notes, owner, transitions, CSV,
  PDF, AI briefing, nightly check, Reports, GTS data).

### 10.9 Open decisions (needed when the relevant phase starts)

- Which Q17 reasons mean "seeking work" (Phase 2).
- Which metric definitions explicitly permit unmatched respondents in
  institution-level totals (Phase 3, under the Part 3 group-mapping policy;
  this replaces the current Dart vs SQL difference).
- Whether existing old-wave flags may be marked superseded (Phase 4).
- The suggested office names (Phase 6).

Resolved by the final plan corrections: the `min_n` numbers per category and
the small-group display cut-off (Part 3 sample-size policy).

### 10.10 Deferred (not in the Phase 0 to 10 plan)

Kept from the original roadmap and the plan review; none of these are
required by the spec.

- Insights explorer tab with ranked tables and drill-down.
- Extra metrics: employment-type shares (Q18), abroad share (Q21), job
  placement usage (Q28), relatedness × salary.
- Group-vs-rest significance rules and course-vs-course comparison screens.
- Trend rule generalised to any metric and both directions; graduation-year
  trends; persistence rule.
- Finding grouping (`group_id`) into one card per group.
- An offices lookup table with its own admin screen.
- A separate institution DSS report and history views (Phase 9 extends the
  existing PDF instead).
- AI summaries of Q17 "other" reasons and Q34 free text.

### 10.11 Plan review (2026-10-08)

Changes after checking the plan against the spec:

- Simplified: one evaluation-events table instead of two; priority calculated
  in the app until Phase 8; owner office as plain text; earlier
  interventions linked through `finding_key`; Phase 9 extends the existing
  PDF instead of adding a report and views.
- Deferred: finding grouping and the offices table.
- Fixed a conflict: the existing "AI prioritize" button is retired in Phase 5
  because the spec does not allow AI to prioritize findings.
- Added missing spec items: the resolve / continue / modify / escalate
  decision (Phase 7) and Unknown-group handling (Phase 1).
- Clean-ups: the old impact verdict only shows as "Coverage Re-check" for new
  findings; the original Part 9 roadmap is collapsed into 10.10.

Final plan corrections before Phase 1:

- Removed remaining AI-prioritization language (Parts 3, 7 and 8);
  deterministic DSS priority is authoritative and AI is explanation-only.
- Reconciled the sample-size policy: 10+ valid answers to the metric for
  substantive findings (outcome, opportunity, and trend per wave), 5–9 as
  Watch, fewer than 5 as Not enough data, always on the metric's own
  denominator. Data-quality rules are the exception: they measure coverage
  against the roster and may fire at any response count, including zero.
  Evidence strength now has four levels (`insufficient` / `watch` /
  `limited` / `strong`).
- Clarified unknown/unmatched respondent aggregation (Part 3 group-mapping
  policy, four cases) so no respondent is assigned to an unreliable course or
  batch, with Dart and SQL / server-side calculations using the same policy.
- Fixed a stale reference: migration step 4 now names the single
  evaluation-events table.
