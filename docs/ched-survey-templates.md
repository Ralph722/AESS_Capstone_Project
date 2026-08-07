# Built-in CHED Graduate Tracer Study (GTS)

## What it is

The official CHED GTS is a **locked, code-defined form** (`ched_gts_builtin` schema **v3.0.0**), not an editable clone of survey questions.

| Area | In app |
|------|--------|
| **A–D official items** | Built-in form with paper-accurate skip logic |
| **Prefill** | Profile (A + B.12) + employment record when available |
| **Alumni UX** | Form appears **inline on Tracer → Active** as a section wizard (A → B → C → D → Review) after publish |
| **Admin** | Title/description + audience (program/batch) + Publish only |

Custom blank surveys still use the generic question editor and separate take page.

## Skip rules (enforced)

| Trigger | Behavior |
|--------|----------|
| **16** = No / Never Employed | Show **17**; hide **18–33** |
| **16** = Yes | Hide **17**; show **18–22** and first-job block **27–32** |
| **18** = Self-employed | Show self-employed skills text |
| **22** = Yes | Show **23**, **24a**; hide **25** |
| **22** = No | Show **25**; hide **23/24**; continue to **27+** |
| **24a** = No | Skip **24b** (reasons for accepting) |
| **24a** = Yes | Show **24b** |
| **32** = No | Hide **33** |
| **32** = Yes | Show **33** |
| “Others, please specify” | Specify field only when that option is selected |

- Paper note: item **26** does not exist in the source template; numbering jumps **25 → 27**. Duplicate paper “24” is stored as **24a** / **24b**.
- Section E (referrals) is **not** included in the digital form.
- Optional items (e.g. **13**, **14**, **15a/15b**, **34**, and conditional “Others, please specify”) show an **Optional** badge; alumni may skip or write None / N/A.

## Admin workflow

1. **Surveys → Create survey → Official CHED GTS** (recommended card).
2. Set optional campus title/description and **target programs / batch years**.
3. **Publish** (or **Re-assign** later). No question list to edit.
4. Alumni in the audience see the form immediately on **Tracer**.

Legacy template packs remain available as “editable clone — no skip logic” for campuses that still need them.

- On **submit**, Section **A**, item **12** (education row), and item **16** (employment status) are written back to the live Profile so Profile stays in sync.

- `surveys.data.kind` = `ched_gts_builtin`
- `surveys.data.template_key` / `schema_version`
- `survey_responses.answers` keyed by stable ids (`ched_16`, `ched_24a`, …)

## Excel export

**Admin → Surveys → View responses → CHED GTS Excel pack**

Works for builtin and legacy clone surveys. Builtin sheets label columns by CHED item number from the schema.

## Code

| Path | Role |
|------|------|
| `lib/features/surveys/ched_gts/ched_gts_schema.dart` | Official items |
| `lib/features/surveys/ched_gts/ched_gts_visibility.dart` | Skip engine |
| `lib/features/surveys/ched_gts/ched_gts_form.dart` | Digitized UI |
| `lib/features/surveys/ched_gts/ched_gts_prefill.dart` | Profile/employment prefill |
| `lib/features/alumni/tracer/presentation/tracer_page.dart` | Inline take |
| `test/ched_gts/ched_gts_visibility_test.dart` | Skip-rule tests |
