# Batch vs Year Graduated — definition to confirm (deferred)

Status: **saved / deferred** — not implemented. Recorded 2026-10-21.
Waiting on the alumni office to confirm what "batch" means before any
change. Do not implement until the questions at the bottom are answered.

## The realization

Batch and year graduated may not be the same thing:

- CHED GTS only asks **year graduated** — there is no batch question.
- If a student enters in 2023 and graduates in 2027, "batch" could mean
  either 2023 (entry/admission year) or 2027 (graduating class).

## Current implementation (verified in code)

Batch is currently an alias of year graduated — deliberately:

| Place | Behavior |
|-------|----------|
| `lib/shared/widgets/gts/gts_profile_form.dart` | Onboarding/profile writes the same value to both `batchYear` and `yearGraduated` |
| `lib/features/alumni/tracer/models/tracer_profile_model.dart` | `fromSupabaseRow` sets `batchYear: yearGraduated` |
| `lib/features/admin/roster/models/alumni_member_model.dart` | Roster `batchYear` is read from `year_graduated`; `effectiveBatchYear` falls back to it |
| Digital alumni card | "Batch" meta shows that same value |
| Migration `20261005160000_phase7_legacy_cleanup.sql` | **Dropped** separate `batch_year` columns from `users` and `alumni_members`; comment: *"Batch is the graduation year (year_graduated)"* |

So a separate batch column existed once and was intentionally removed.
Reintroducing one needs a confirmed reason.

## Candidate definitions

| If "batch" means… | Consequence |
|-------------------|-------------|
| Graduating class (entered 2023, graduated 2027 → Batch 2027) | Current code is already correct. **Nothing to change.** |
| Year entered college (same student → Batch 2023) | Large change: new column + backfill, onboarding/roster logic, survey targeting, DSS cohorts, card display, filters/exports |

## Idea under consideration (only if batch = entry year)

Student IDs look like `2023303030`, where the first 4 digits (`2023`)
appear to encode the entry/admission year. Batch could be derived from
the student ID:

- Parse first 4 digits of `student_id` as the batch/entry year.
- Validate format (length, numeric, plausible year range); fall back to
  blank/manual value when unparseable.

**Risks of the ID-prefix assumption (unverified):**

- Breaks for transferees, shifters, second-degree students, irregular
  students whose ID year ≠ entry year into the program.
- Older or reissued IDs may use a different format.
- Silently wrong batch values would corrupt reports, survey targeting
  (`target_batch_years`), and DSS cohorts — the data the office relies on.

Validate first: sample real roster IDs where entry year is independently
known (registrar records) and check the prefix matches before trusting it.

## Rough implementation sketch (if confirmed = entry year)

1. Migration: re-add `batch_year` to `users` / `alumni_members` (or a
   computed derivation), guard rules like `year_graduated`.
2. Derive on registration/roster link from `student_id` prefix; admin can
   override on the roster.
3. Backfill existing rows from student IDs; flag unparseable ones.
4. Split `batchYear` from `yearGraduated` in `TracerProfile`,
   `AlumniMember`, Home header, digital card, directory filters/exports,
   survey targeting, DSS.
5. Onboarding keeps asking only year graduated; batch comes from the ID /
   roster, not a new user question.
6. Tests for ID parsing edge cases + targeting by the new batch.

## Questions to ask the alumni office (verbatim)

1. "For a student who entered in 2023 and graduated in 2027, what is their
   batch — 2023 or 2027?"
2. "Is the first 4 digits of the student ID always the year they entered,
   for all programs and all years (including transferees)?"
3. "Where do you use batch — reports, survey targeting, the alumni card —
   and what should it match: registrar graduation lists or admission
   records?"

Question 1 alone resolves the direction: 2027 → done, nothing to build;
2023 → implement the entry-year plan above.

## Recommendation

**Get the answers first.** Waiting costs nothing; guessing wrong means a
migration plus silently misclassified alumni. Record the answers here
when received, then scope the build.
