# Deferred plans

Status: decided "leave for now". Recorded on 2026-10-08; sections 1, 3 and 7
were resolved on 2026-10-16. The rest is not implemented.
Any database change listed here must be reported and approved before it is
applied.

## 1. Tracer email overwrites the roster contact email

**Resolved 2026-10-16** by contact verification
([`contact-verification-plan.md`](contact-verification-plan.md)). The tracer
email is a separate `users.contact_email`, saved only after a code check and
copied to `alumni_members.email_address` by the server; the submit sync and
profile saves no longer write it. The original notes are kept below.

**Problem.** Editing the email in the CHED tracer (item 3) does not change the
login or the profile email, but it does overwrite
`alumni_members.email_address` through the roster sync after submit (the sync
uses the profile merged with the tracer answers). Effects:

- Custom report exports prefer `email_address`, so they show the tracer email.
- Saving from Profile settings resets `email_address` to the account email, so
  the value flips depending on which form was saved last.
- Messaging is unaffected (it prefers `registered_email`).
- The DB guard on `alumni_members` does not protect `email_address`.

**Plan (app only, no DB change).** Keep the tracer email editable, since the
CHED question asks for an email the alumni checks regularly, and keep it in
the survey answer. Stop passing the tracer email into the roster sync after
submit (`_syncProfileFromBuiltinChedGts` / `ChedGtsPrefill.mergeIntoProfile`
path). Optionally add a hint under the field: "To change your login email, go
to Profile settings."

## 2. Locking degree and year in the tracer

**Current behaviour.** Item 12 (degree, year) is editable in the tracer.
On submit the program is left untouched and the year is only filled when
blank, and the roster year wins anyway, so edits don't reach the record.
College and honors do get written back.

**Decision needed.** Either make degree and year read-only in the tracer
(shown from the roster), or leave them editable as a survey snapshot only.
No DB change either way.

## 3. Change email feature (Profile settings)

**Resolved 2026-10-16** by section 7 (verified email becomes the login email).
Email is changed in the tracer (Q3) or Profile information through the same
verification code; Auth login, profile and roster follow. Rules kept: no
second authentication mechanism, no passwords in app tables, no "admin
changes any user's password" feature. Roster `registered_email` sync is
included. Alumni-office lost-inbox fallback was not built (not needed for
the verified-email path while the user is signed in).

## 4. CHED question catalog help text

The app's `ched_1` help text now reads "Write your full name the way you
normally write it." The DB `gts_question_catalog` name help text was not
updated. Update it in a migration when convenient (DB change, report first).

## 5. Curriculum relevance and skills gaps

**Current coverage.** Q24 and Q32 (relevance) appear on the Reports page
("Curriculum relevant", "Career alignment"), in the wave comparison, and in
the DSS (`RELATEDNESS_LOW` / `RELATEDNESS_HIGH`). Q33 (useful competencies)
and Q34 (curriculum suggestions, themed) appear only on a DSS flag's detail
page and in the per-survey analytics panel.

**Gaps.** No question asks which skills were missing; Q33 is answered only by
alumni who said Yes to Q32; Q33/Q34 are not on the Reports page.

**Plan A: Reports "Curriculum & skills" card (existing data, no DB change).**
Per course: curriculum-relevance rate, Q33 skill ranking, top Q34 themes.

**Plan B: separate skills-gap survey (agreed approach).** Use a custom survey
instead of changing the official CHED form:

- Same skill list as Q33 (communication, human relations, entrepreneurial,
  IT, problem-solving, critical thinking, other) so "useful" and "lacking" can
  be compared.
- Ask everyone, including alumni who said the curriculum was not relevant.
- Add a free-text question: "What skills or tools did your job need that your
  course didn't teach?"
- Target by course and batch; read results in the survey analytics panel
  (course/batch filters).
- Trade-offs: lower response than the tracer (run it alongside or right after
  a tracer round), and results live outside Reports/DSS.

## 6. Digital alumni card (complete through Phase 4, 2026-10-16)

Adviser request: a digital alumni card opened from the Home identity card,
shown in a pop-up that flips front to back, for verification when the
physical card is left at home. Full plan and how-it-works:
[`digital-alumni-card-plan.md`](digital-alumni-card-plan.md).
Mockup: [`mockups/digital-alumni-card.html`](mockups/digital-alumni-card.html).
Shipped: card UI, `alumni_card_tokens` + QR, staff verify page, admin
**Verify card**, offline cache, shine animation, accessibility polish.

## 7. Verified email becomes the login email (saved 2026-10-16)

**Resolved 2026-10-16.** Follow-up to contact verification, chosen instead of
ID-number login. When an alumnus verifies a new email with a code, the server
also changes their Supabase Auth login email; the profile and roster emails
follow, and the old address gets a notice. A password re-check is asked if
the last sign-in was over 24 hours ago. Closes section 3. Full write-up:
"Part 2" in [`contact-verification-plan.md`](contact-verification-plan.md).

## 8. Notes on completed changes

- **Profile-only tracer prefill (done 2026-10-08).** Drafts saved before the
  change may still contain job answers pre-filled from the previous tracer,
  because draft answers win over the prefill.
- **Forgot password.** Supabase sends nothing for unknown emails (no account
  enumeration). The subtitle wording was reviewed and left as is.
- **Contact verification + login email (done 2026-10-16).** See
  [`contact-verification-plan.md`](contact-verification-plan.md). Sections 1,
  3 and 7 above.

## 9. Marriage-gated name change (saved 2026-10-17)

**Implemented 2026-10-21** — code plus migration
`20261021040000_marriage_name_change.sql` (applied to Supabase same day).
Name locked on live profile/onboarding; optional rename only in Tracer when
civil status becomes Married; updates both `users.display_name` and
`alumni_members.full_name`; `NAME_CHANGE` audit for admin. No alumni
name-correction request flow in v1. Full plan:
[`marriage-name-change-plan.md`](marriage-name-change-plan.md).

## 10. Batch vs year graduated (saved 2026-10-21)

**Not implemented — waiting on the alumni office.** Batch currently equals
year graduated everywhere (separate `batch_year` columns were dropped in
phase 7). If the office means *entry year* instead, batch could be derived
from the student-ID prefix (e.g. `2023…`), but that assumption is unverified
(transferees, old ID formats). Three questions to ask are recorded in the
plan. Full write-up:
[`batch-vs-year-graduated-plan.md`](batch-vs-year-graduated-plan.md).

## 11. Directory Updates tab + profile-change timeline (saved 2026-10-22)

**Implemented 2026-10-22** — code plus migration
`20261022010000_directory_updates_tab.sql` (applied to Supabase same day).
The Alumni Directory now has tabs — All alumni · Updates (count) ·
Deactivated (count) — replacing the "Show deactivated" checkbox; the
conditional 5th "Profile updates" KPI card and the "pending review" pill
were removed, so the Updates tab badge is the single indicator. Opening a
member only records `admin_viewed_at`; the flag clears via the explicit
**Mark as reviewed** button in the member detail header. Profile saves now
write field-level `PROFILE_UPDATE` audit diffs tagged by source
(`profile` / `tracer` / `survey` / `onboarding`; photo = changed marker, no
data), rendered in the member Activity tab as an expandable timeline with
source filter chips; `NAME_CHANGE` and `LOGIN_EMAIL_CHANGE` render in the
same timeline. While a member is unreviewed, fields from the latest diff
get a "changed" dot in Profile info. No historical backfill — old values
were never stored before this. Photo changes are exempt from the review
flag (timeline entry only); saving a profile with no actual field changes
no longer flags the member either.

## 12. Directory CHED GTS column (implemented 2026-10-22)

The directory table's old **TRACER** column (live-profile completeness —
fields only; the profile photo never counted toward it) was replaced by a
**CHED GTS** column tracking wave completion per member: `submitted /
assigned` waves (amber), **Complete** when every assigned CHED GTS wave is
submitted, `—` when none are assigned or the member is not registered. A
submitted response without an assignment counts both ways, and a completed
assignment counts as submitted. The member cards show the same as a
"CHED complete / CHED x/y" badge. Live-profile completeness itself is
unchanged — it still lives in the member detail banner and in Reports.

## 13. Program Insights (DSS) usability redesign (saved 2026-10-22)

**Phases 0–6 implemented 2026-10-23.** Wording, Queue list, sticky action
panel, Plan / Owner & schedule / Proof merges, What happened timeline, and
learnability (How this works strip, example finding preview, Rules-save
confirm). Full plan:
[`dss-usability-redesign-plan.md`](dss-usability-redesign-plan.md).
