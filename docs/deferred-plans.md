# Deferred plans

Status: decided "leave for now"; nothing implemented. Recorded on 2026-10-08.
Any database change listed here must be reported and approved before it is
applied.

## 1. Tracer email overwrites the roster contact email

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

**Recommendation.** The tracer is not the place to change the login email.
Add a **Change email** option in Profile settings using Supabase Auth's
built-in verified email change. Rules from the original spec still apply: no
second authentication mechanism, no passwords in app tables, no "admin changes
any user's password" feature.

Plan:

1. **Change email in Profile settings.** Call Supabase Auth's email change,
   which sends a confirmation to the new address; the email only changes after
   confirmation.
2. **Retired-inbox decision.** `supabase/config.toml` has
   `double_confirm_changes = true` (both old and new addresses must confirm).
   That blocks alumni whose old inbox is dead. Options:
   - Confirm only the new address, and require the current password and a
     recent login before allowing the change (recommended for this case).
   - Keep double confirmation and let the alumni office handle lost-inbox
     cases after checking identity.
3. **Alumni office fallback** for alumni who are logged out and lost their
   inbox: the office verifies identity offline and updates the email through a
   secure server function (Edge Function with the service role). Email only.
4. **Sync the new email everywhere (DB change, report first).**
   `sync_user_email_from_auth` already copies auth email changes to
   `users.email`, but not to `alumni_members.registered_email`, which
   messaging and admin views use. Extend the sync to update
   `registered_email`.
5. **Tracer tidy-up.** Keep the tracer email editable, pre-filled from the
   account email, and not copied to the roster (see section 1).

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

## 6. Notes on completed changes

- **Profile-only tracer prefill (done 2026-10-08).** Drafts saved before the
  change may still contain job answers pre-filled from the previous tracer,
  because draft answers win over the prefill.
- **Forgot password.** Supabase sends nothing for unknown emails (no account
  enumeration). The subtitle wording was reviewed and left as is.
