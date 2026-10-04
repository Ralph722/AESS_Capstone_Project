# Tracer AI Helper — Implementation Plan

Status: **Built 2026-10-05.** Differences from the original plan below:

- AI button only on **Q19**; one request returns an occupation title and a line of business. After a suggestion is used, the pill reads "Ask again" (per app session). If only the Q19 suggestion was used (and Q19 still matches it), Q20's note becomes a recommendation ("Based on your job, your line of business may be…", marked as possibly wrong) with a "Use this" button. Otherwise Q20 shows "Not sure? Tap Help me answer on question 19." If the description doesn't say what the company does and the job is ambiguous, the reason says it depends on the employer. Q18, Q28 and Q30 rely on written help.
- Written help added to 32 questions (Civil Status, Sex, Birthday and the "please specify" follow-ups have none).
- Admin switch: **AI answer helper** per CHED survey (`surveys.data.aiHelpEnabled`, default on), also enforced by the Edge Function.
- Function also checks the survey is published and assigned to the caller; a failed AI call refunds the day's request.
- Usage: `tracer_help_usage` + `tracer_help_consume` / `tracer_help_refund` (migration `20261005010000_tracer_help.sql`).
- Model: `gemini-2.5-flash`, falling back to `gemini-3.5-flash-lite` (override with the `GEMINI_MODEL` secret).
- Files: `supabase/functions/tracer-help/index.ts`, `lib/features/surveys/ched_gts/ched_gts_help_service.dart`, `ched_gts_help_sheet.dart`.

## Decisions already made

| Decision | Choice |
|----------|--------|
| Scope | **Part 1** (written help on all questions) **+ Part 2** (AI helper on selected questions) |
| Where the AI call runs | **Supabase Edge Function** with the Gemini key stored as a Supabase secret (safe for the web version) |
| Daily limit | **20** help requests per alumnus per day |

## Why it's worth adding

- Addresses the adviser's concern that alumni get confused by some CHED GTS questions.
- Strong capstone demo with clear answers to panel questions on accuracy and privacy.
- Most pieces already exist: Gemini is used by the AI assistant and forum moderation, three Edge Functions exist, Supabase CLI v2.105 is installed.
- If time is short, Part 1 alone delivers most of the value with zero AI risk.

## Part 1 — Written help on every question (no AI)

- Use the `helpText` field on `ChedGtsItem` (added for Q20) in `lib/features/surveys/ched_gts/ched_gts_schema.dart`.
- One short plain-language explanation per question (1–34), with an example answer where useful.
  - Example Q22: *"Answer Yes if this is the first job you had after graduating. Answer No if you worked somewhere else before this job."*
- Official CHED wording and option labels stay unchanged.
- Drafts to be reviewed by the team and adviser before release.
- Already rendered by the form (`ched_gts_form.dart` shows `helpText` under the prompt).

## Part 2 — "Help me answer" AI button (confusing questions only)

| Question | Why it's confusing | Helper returns |
|----------|--------------------|----------------|
| 18 Present employment status | Regular vs contractual vs casual | Explanation + suggested option |
| 19 Present occupation | How to phrase a job title | Suggested occupation title |
| 20 Major line of business | Official categories are abstract | Suggested category, or "please specify" text |
| 28 How did you find your first job | Overlapping options | Suggested option, or "please specify" text |
| 30 Job level position | Rank vs professional vs managerial | Explanation + suggested level per column (alumni tick themselves) |

### Alumni flow

1. Tap **Help me answer** on the question card (hidden in read-only mode).
2. Bottom sheet (phone) / dialog (wide screens) opens.
3. Alumnus describes their situation, e.g. *"I drive a delivery truck for a logistics company."*
4. Helper returns:
   - plain-language explanation of the question,
   - suggested option with a one-line reason,
   - or suggested text for the "please specify" field.
5. Each suggestion has a **Use this** button. Nothing is filled in automatically.

### Server — `supabase/functions/tracer-help/`

- Requires a signed-in user (verify JWT; reject anonymous).
- **Allowlist:** only accepts the five item ids above. Question wording and official options for those items live in the function (e.g. `items.ts`), so it cannot be used as a general chatbot.
- Calls Gemini with a fixed JSON response shape:
  `{ explanation, suggestedOption, specifyText, confidence }`
- Drops any `suggestedOption` not in that item's official option list.
- Input capped at 300 characters.
- Rate limit via a `tracer_help_usage` table (`user_id`, `used_on` date, `count`), service-role only, 20/day.
- The alumnus's description is **not stored** — only the daily count.

### App

- `ChedGtsHelpService` — calls the Edge Function via `supabase.functions.invoke('tracer-help', ...)`.
- `ChedGtsHelpSheet` — the help UI (input, result card, Use this buttons, disclaimer).
- Hook into `_ItemCard` in `ched_gts_form.dart` for eligible items only.

## Guardrails

- **Key safety:** Gemini key stored as a Supabase secret, never bundled in the app (bundled keys are readable in a web build).
- **Auth:** only signed-in alumni can call the function.
- **Rate limit:** 20 requests per alumnus per day.
- **Privacy (Data Privacy Act):** only the item id + the alumnus's description are sent; profile and saved answers are never sent; description not stored. Notice in the sheet: *"Your description is sent to Google Gemini to generate help. Don't include your name or contact details."*
- **Suggestion only:** every result labelled *"Suggestion only — you choose the final answer."* Prompt instructs the model to explain and suggest, never decide.
- **Fallback:** if AI is unavailable or out of quota, show a friendly message; written help (Part 1) still works.

## One-time setup

```powershell
supabase secrets set GEMINI_API_KEY=your_key_here
supabase functions deploy tracer-help
supabase db push   # applies the tracer_help_usage migration
```

## Verification

- Unit tests: app service and the option-allowlist check.
- Layout check of the help sheet on phone and wide sizes.
- Analyzer issue count stays at the current baseline (26).

## Not affected

Stored answers, answer keys, schema version, PDF export, reports, and the existing AI assistant page.

## Open for further discussion

- Final list of questions that get the AI button.
- Help text wording (team + adviser review).
- Whether admins need an on/off switch for the helper.
