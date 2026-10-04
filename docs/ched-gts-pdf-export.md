# Official CHED GTS PDF export (admin)

Export filled copies of the official CHED Graduate Tracer Study AcroForm PDF
from the **Alumni Directory** (web admin only).

## Where to find it

| Action | Location |
|--------|----------|
| One alumni | Member detail panel → PDF icon in the header, or on a CHED response card |
| Many alumni | Directory checkboxes → **Download official GTS PDFs (ZIP)** |

Existing Excel / management report exports are unchanged.

## Data source

1. Prefer the newest **submitted** built-in CHED GTS response (`ched_*` answers)
2. Fill empty gaps from live profile + employment
3. If no submission exists, export from live profile (after confirm)

## Template version

- **Active:** `CHED-GTS-v3.1.0-fillable.pdf` (A4, official-aligned numbering and fields)
- Schema alignment: `ChedGtsBuiltin.schemaVersion` `3.0.0`
- **Legacy (kept):** `CHED-GTS-v3.0.0-fillable.pdf` (condensed Letter digital copy)
- **Paper reference (read-only):** `CHED-GTS-official-reference.pdf`
- **Markdown transcription:** `docs/ched-gts-official-reference.md`
- Generator: `tool/ched_gts_pdf/generate_v3_1_0_fillable.py`

### v3.1.0 coverage vs official CHED

- Items **1–34** with printed numbers; the paper's duplicate **24** and missing **26** are renumbered as **24** (first job related), **25** (reasons for accepting) and **26** (reasons for changing job)
- Graduate + undergraduate columns for item **14**
- **Others, please specify** checkboxes/radios + text destinations
- Education **3** rows, exams **3** rows, trainings **3** rows
- **Header left blank** (not presented as an official CHED letterhead)
- **Section E** (alumni referrals) omitted by design
- Improved vertical spacing so labels and AcroForm fields do not overlap

## Export modes

| Mode | Behavior |
|------|----------|
| **Print-Ready PDF** | Fields flattened after fill (recommended for packets) |
| **Fillable PDF** | Editable AcroForm retained |

## Batch limits

- Soft warning at **25** selected
- Hard cap at **100** per ZIP (browser fill is CPU-heavy) — export in chunks for larger cohorts
- Unregistered roster rows are skipped

## Audit

- Per person: `EXPORT_CHED_GTS_PDF`
- Batch: `EXPORT_CHED_GTS_PDF_BATCH` (includes success/failure counts and template version)
