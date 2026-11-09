import 'package:flutter/material.dart';

/// Where a report appears in the Admin Portal.
enum ReportCatalogSurface {
  /// Published survey → Download / export (one survey ID).
  surveyExportModal,

  /// Reports & Analytics → Downloads (institutional / cross-survey).
  downloadsLibrary,

  /// Reports & Analytics → Builder (ad-hoc CHED analytics).
  reportBuilder,
}

/// Population the report is allowed to cover.
enum ReportScopeKind {
  /// Locked to the currently opened survey / wave.
  surveySpecific,

  /// Selected institutional scope (waves, cohorts, roster, etc.).
  institutional,
}

/// How identifiable the typical output is.
enum ReportPrivacyClass {
  /// Counts and distributions only.
  aggregated,

  /// Contains names, emails, or other personal fields.
  confidentialIdentifiable,

  /// Follow-up / operational lists meant for limited staff use.
  restrictedFollowUp,
}

/// Lifecycle of a catalog entry.
enum ReportCatalogStatus {
  /// Shown and exportable today.
  available,

  /// Catalogued but not yet offered as a Downloads card / download path.
  planned,
}

/// Purpose grouping (UI layout may use this in later phases).
enum ReportCatalogCategory {
  responseAndParticipation,
  surveyFindings,
  officialChed,
  detailedData,
  institutionalGts,
  comparisonsAndQuality,
  operations,
}

extension ReportCatalogCategoryX on ReportCatalogCategory {
  String get label => switch (this) {
        ReportCatalogCategory.responseAndParticipation =>
          'Response and participation',
        ReportCatalogCategory.surveyFindings => 'Survey findings',
        ReportCatalogCategory.officialChed => 'Official CHED outputs',
        ReportCatalogCategory.detailedData => 'Detailed data exports',
        ReportCatalogCategory.institutionalGts => 'Institutional GTS',
        ReportCatalogCategory.comparisonsAndQuality =>
          'Comparisons and data quality',
        ReportCatalogCategory.operations => 'Operations',
      };
}

/// One AESS report / export product (current or planned).
///
/// Phase 1 uses this as the single source of titles, descriptions, and scope
/// contracts. Generation logic still lives in existing services.
@immutable
class AessReportCatalogEntry {
  const AessReportCatalogEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.definition,
    required this.surface,
    required this.scope,
    required this.privacy,
    required this.category,
    required this.status,
    this.includeItems = const [],
    this.bestFor,
    this.limitation,
    this.scopeNote,
    this.fileNameStem,
    this.surveyExportKindName,
    this.downloadsPresetId,
    this.icon,
  });

  /// Stable catalog id (not user-facing).
  final String id;

  final String title;
  final String subtitle;
  final String definition;
  final ReportCatalogSurface surface;
  final ReportScopeKind scope;
  final ReportPrivacyClass privacy;
  final ReportCatalogCategory category;
  final ReportCatalogStatus status;
  final List<String> includeItems;
  final String? bestFor;
  final String? limitation;

  /// Short scope line for tooltips / details (e.g. "This survey only").
  final String? scopeNote;

  /// Safe filename stem without date, e.g. `AESS_GTS_Outcomes`.
  final String? fileNameStem;

  /// Matches `SurveyExportReportKind.name` when on the survey modal.
  final String? surveyExportKindName;

  /// Links to Downloads preset id (`executive`, `tracer`, …).
  final String? downloadsPresetId;

  final IconData? icon;

  bool get isAvailable => status == ReportCatalogStatus.available;
}

/// Controlled inventory of AESS reporting products.
///
/// Survey-specific and institutional reports are listed separately so the two
/// Admin surfaces stay complementary instead of duplicating the same export.
abstract final class AessReportCatalog {
  static const surveyScopeBadge = 'This survey only';
  static const institutionalScopeBadge = 'Institutional scope';

  static const surveyModalIntro =
      'Exports use only the survey you have open. Pick what you need, '
      'then choose how to save or print it.';

  static const downloadsIntro =
      'Institutional templates. Each card states which records it covers. '
      'Batch and course filters apply only where noted.';

  /// All entries (available + planned). Prefer [available] / surface helpers
  /// for UI wiring.
  static const all = <AessReportCatalogEntry>[
    // —— Survey export modal (available) ——
    AessReportCatalogEntry(
      id: 'survey.submitted_responses',
      title: 'Submitted responses',
      subtitle:
          'Full answer spreadsheet for alumni who submitted this survey',
      definition:
          'Downloads a spreadsheet of alumni who already submitted this '
          'survey, with alumni list fields and their answers side by side.',
      surface: ReportCatalogSurface.surveyExportModal,
      scope: ReportScopeKind.surveySpecific,
      privacy: ReportPrivacyClass.confidentialIdentifiable,
      category: ReportCatalogCategory.detailedData,
      status: ReportCatalogStatus.available,
      surveyExportKindName: 'responses',
      icon: Icons.table_rows_outlined,
      fileNameStem: 'AESS_Survey_Responses',
      scopeNote: surveyScopeBadge,
      includeItems: [
        'Name, email, course, and batch year',
        'When they submitted',
        'Each survey answer (Official CHED uses tracer field columns)',
      ],
      bestFor: 'Reviewing answers in Excel or sharing raw results with staff.',
      limitation:
          'Data file, not a presentation. For Official CHED meetings, prefer '
          '“CHED outcomes summary” or the Excel pack. Official CHED exports use '
          'stable ched_* field columns from the builtin questionnaire.',
    ),
    AessReportCatalogEntry(
      id: 'survey.management_summary',
      title: 'Survey management summary',
      subtitle:
          'Invitations, completions, and question highlights for this survey',
      definition:
          'A ready-made summary of this survey for office review: how many '
          'were invited, how many finished, audience breakdowns, and '
          'highlights from the answers.',
      surface: ReportCatalogSurface.surveyExportModal,
      scope: ReportScopeKind.surveySpecific,
      privacy: ReportPrivacyClass.confidentialIdentifiable,
      category: ReportCatalogCategory.responseAndParticipation,
      status: ReportCatalogStatus.available,
      surveyExportKindName: 'management',
      icon: Icons.summarize_outlined,
      fileNameStem: 'AESS_Survey_Management_Summary',
      scopeNote: surveyScopeBadge,
      includeItems: [
        'Completion overview',
        'Results by course and batch',
        'Question summaries and short takeaways',
        'Respondent names in the response section',
      ],
      bestFor: 'Meetings, printouts, and quick status updates for this survey.',
      limitation:
          'For tracer employment and related CHED questions on this wave, '
          '“CHED outcomes summary” is clearer. Cross-wave analysis belongs in '
          'Reports & Analytics → Downloads.',
    ),
    AessReportCatalogEntry(
      id: 'survey.ched_outcomes',
      title: 'CHED outcomes summary',
      subtitle:
          'Employment and graduate outcomes from this CHED GTS survey only',
      definition:
          'A short tracer report for this survey that answers the main CHED '
          'questions offices care about. Percentages show how many people '
          'answered each item, so small groups are easy to spot.',
      surface: ReportCatalogSurface.surveyExportModal,
      scope: ReportScopeKind.surveySpecific,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.surveyFindings,
      status: ReportCatalogStatus.available,
      surveyExportKindName: 'chedOutcomes',
      icon: Icons.insights_outlined,
      fileNameStem: 'AESS_GTS_Outcomes',
      scopeNote: surveyScopeBadge,
      includeItems: [
        'How many finished the tracer',
        'Whether graduates are employed',
        'Why some are not employed',
        'Type of work, and local or abroad',
        'Whether the first job matches their course',
        'Time to first job, starting pay band, and curriculum relevance',
        'Reasons for further studies',
      ],
      bestFor:
          'School meetings and “what did this tracer find?” for this wave.',
      limitation:
          'Covers the current survey only. To compare waves or cohorts across '
          'the institution, use Reports & Analytics → Downloads.',
    ),
    AessReportCatalogEntry(
      id: 'survey.ched_excel_pack',
      title: 'CHED GTS Excel pack',
      subtitle:
          'Detailed tracer workbook (personal, school, and job sheets) for '
          'this survey',
      definition:
          'A detailed Excel workbook for this tracer wave, organized into '
          'sheets that follow the CHED Graduate Tracer Study sections.',
      surface: ReportCatalogSurface.surveyExportModal,
      scope: ReportScopeKind.surveySpecific,
      privacy: ReportPrivacyClass.confidentialIdentifiable,
      category: ReportCatalogCategory.officialChed,
      status: ReportCatalogStatus.available,
      surveyExportKindName: 'ched',
      icon: Icons.verified_outlined,
      fileNameStem: 'AESS_GTS_Excel_Pack',
      scopeNote: surveyScopeBadge,
      includeItems: [
        'Personal background',
        'Education history',
        'Employment information from this survey',
        'Survey answers arranged for office filing',
      ],
      bestFor: 'Registrar handoff, archiving, and detailed CHED data review.',
      limitation:
          'Workbook, not the official fillable PDF. Some background fields '
          'may use the live alumni profile when the wave snapshot is incomplete.',
    ),
    AessReportCatalogEntry(
      id: 'survey.ched_fillable_pdfs',
      title: 'Official fillable PDFs',
      subtitle:
          'One official CHED form per graduate who submitted this survey (ZIP)',
      definition:
          'Creates the official CHED tracer PDF form for each graduate who '
          'already submitted this survey, then downloads them in one ZIP.',
      surface: ReportCatalogSurface.surveyExportModal,
      scope: ReportScopeKind.surveySpecific,
      privacy: ReportPrivacyClass.confidentialIdentifiable,
      category: ReportCatalogCategory.officialChed,
      status: ReportCatalogStatus.available,
      surveyExportKindName: 'chedFillable',
      icon: Icons.picture_as_pdf_outlined,
      fileNameStem: 'AESS_GTS_Fillable_PDFs',
      scopeNote: surveyScopeBadge,
      includeItems: [
        'One filled form per submitted graduate',
        'Answers taken from this survey when available',
        'Missing blanks may be completed from their profile when available',
      ],
      bestFor:
          'Printing, filing, or submitting individual official tracer forms.',
      limitation:
          'Limited to 100 forms per download. Forms that cannot be filled '
          'are skipped.',
    ),
    AessReportCatalogEntry(
      id: 'survey.pending_assignments',
      title: 'Pending assignments',
      subtitle:
          'Alumni invited to this survey who have not finished yet',
      definition:
          'A contact list of alumni who were invited to this survey but still '
          'have not submitted.',
      surface: ReportCatalogSurface.surveyExportModal,
      scope: ReportScopeKind.surveySpecific,
      privacy: ReportPrivacyClass.restrictedFollowUp,
      category: ReportCatalogCategory.responseAndParticipation,
      status: ReportCatalogStatus.available,
      surveyExportKindName: 'pending',
      icon: Icons.person_off_outlined,
      fileNameStem: 'AESS_Survey_Pending_Assignments',
      scopeNote: surveyScopeBadge,
      includeItems: [
        'Name and email',
        'Course and batch year',
        'Invitation status',
        'When they were assigned',
        'How many reminders were sent',
      ],
      bestFor: 'Follow-ups, reminder messages, and improving response rates.',
      limitation:
          'People who already submitted are not included. Empty if everyone '
          'has finished.',
    ),

    // —— Downloads library (available) ——
    AessReportCatalogEntry(
      id: 'downloads.portal_executive_snapshot',
      title: 'Portal executive snapshot',
      subtitle:
          'Institution-wide portal KPIs, survey list, and employment records',
      definition:
          'Operations snapshot of the alumni portal: registration and tracer '
          'KPIs, a summary of surveys, and the latest employment records for '
          'registered alumni. This is not a CHED GTS findings report.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.confidentialIdentifiable,
      category: ReportCatalogCategory.operations,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'executive',
      icon: Icons.insights_outlined,
      fileNameStem: 'AESS_Portal_Executive_Snapshot',
      scopeNote:
          'KPIs and survey list cover the whole system. Batch/course filters '
          'apply only to employment rows.',
      includeItems: [
        'Executive KPIs',
        'Survey summary',
        'Employment records (filterable by batch/course)',
      ],
      bestFor: 'Quick portal health checks for administrators.',
      limitation:
          'Not a graduate outcomes report. For CHED findings across cohorts, '
          'use Downloads audience GTS templates or Builder.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.ched_portfolio_pack',
      title: 'CHED GTS portfolio pack',
      subtitle:
          'Portal KPIs, survey list, CHED question rollups, and employment '
          'records',
      definition:
          'Combined institutional pack with portal KPIs, survey summaries, '
          'Official CHED question rollups, and employment records. Mixed '
          'sources — not limited to a single wave.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.confidentialIdentifiable,
      category: ReportCatalogCategory.operations,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'ched',
      icon: Icons.verified_outlined,
      fileNameStem: 'AESS_GTS_Portfolio_Pack',
      scopeNote:
          'Question rollups use Official CHED waves. KPIs/survey list are '
          'portfolio-wide. Batch/course filters apply only to employment rows.',
      includeItems: [
        'Executive KPIs',
        'Survey summary',
        'Survey question summaries',
        'Employment records',
      ],
      bestFor:
          'Broad CHED-oriented office packets alongside dedicated institutional '
          'GTS templates.',
      limitation:
          'Overlaps the portal snapshot and participation pack. Prefer the '
          'audience Institutional GTS templates when you need wave-scoped '
          'outcomes.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.ched_wave_comparison',
      title: 'CHED wave comparison',
      subtitle:
          'Compare outcomes across two or more Official CHED GTS waves',
      definition:
          'Cross-sectional comparison of key CHED fields across selected '
          'published or closed Official CHED GTS waves with submissions.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.comparisonsAndQuality,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'ched_wave_compare',
      icon: Icons.compare_arrows_outlined,
      fileNameStem: 'AESS_GTS_Wave_Comparison',
      scopeNote:
          'You choose 2–8 compatible Official CHED waves after picking a '
          'format. Optional batch and course filters.',
      includeItems: [
        'Present employment',
        'Employment status and place of work',
        'First-job course relatedness',
        'Initial earnings band and curriculum relevance',
        'Wave-to-wave deltas on highlight rates',
      ],
      bestFor: 'Tracking tracer outcome changes across waves.',
      limitation:
          'Needs at least two Official CHED waves with responses. Do not '
          'treat waves as comparable if questionnaire or population differs '
          'without reading the coverage notes on the export.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.alumni_employment_records',
      title: 'Alumni employment records extract',
      subtitle:
          'Latest employment records for registered alumni (alumni list source)',
      definition:
          'Identifiable employment table built from stored employment records '
          'for registered alumni. This is an operational extract, not a CHED '
          'wave outcomes report.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.confidentialIdentifiable,
      category: ReportCatalogCategory.operations,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'tracer',
      icon: Icons.work_outline,
      fileNameStem: 'AESS_Alumni_Employment_Records',
      scopeNote: 'Honours batch and course filters from Reports filters.',
      includeItems: [
        'Name and email',
        'Employment status and type',
        'Occupation, industry, place of work',
        'Submitted / last updated date',
      ],
      bestFor: 'Staff who need the current employment table for registered alumni.',
      limitation:
          'Not wave-scoped CHED answers. For graduate employment findings from '
          'tracer responses, use survey “CHED outcomes summary” or Downloads '
          '“Institutional employment & employability overview”.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.survey_participation',
      title: 'Survey participation overview',
      subtitle: 'Assignment and response health across surveys and waves',
      definition:
          'Institutional view of survey assignment and response health, with '
          'funnel-style participation notes for the portfolio.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.comparisonsAndQuality,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'survey',
      icon: Icons.poll_outlined,
      fileNameStem: 'AESS_Survey_Participation',
      scopeNote:
          'Whole system. Batch and course filters do not apply to this pack.',
      includeItems: [
        'Survey summary by wave',
        'Participation funnel and insights',
      ],
      bestFor: 'Research office and survey coordinators monitoring coverage.',
      limitation:
          'Portfolio-level only. For one survey’s pending list or management '
          'summary, open that survey’s Download / export. Richer data-quality '
          'metrics are planned.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.active_roster_extract',
      title: 'Active alumni list extract',
      subtitle:
          'Active alumni list with registration and tracer completion status',
      definition:
          'Export of the active alumni list with registration and tracer '
          'completion status for administrative use.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.confidentialIdentifiable,
      category: ReportCatalogCategory.operations,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'roster',
      icon: Icons.groups_outlined,
      fileNameStem: 'AESS_Active_Alumni_List_Extract',
      scopeNote: 'Honours batch and course filters from Reports filters.',
      includeItems: [
        'Name, course, school ID, batch, email',
        'Registered flag',
        'Tracer complete flag',
        'Date added',
      ],
      bestFor: 'Directory extracts and registration follow-up.',
      limitation: 'Active alumni list only; no employment answer columns.',
    ),

    // —— Audience-focused Institutional GTS Downloads (T1–T5) ——
    AessReportCatalogEntry(
      id: 'downloads.employment_employability',
      title: 'Institutional employment & employability overview',
      subtitle:
          'Strategic employment metrics for board, president, and academic '
          'leadership',
      definition:
          'High-level employability pack: response rate, present employment, '
          'employment status, first-job relatedness, and time to first job. '
          'Filter by course/batch for program views.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.institutionalGts,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'employment_employability',
      icon: Icons.account_balance_outlined,
      fileNameStem: 'AESS_Employment_Employability_Overview',
      scopeNote: 'Selected Official CHED waves, batches, and courses only.',
      includeItems: [
        'Response rate for the selected scope',
        'Present employment (Q16) and employment status (Q18)',
        'Place of work — local vs abroad (Q21)',
        'First-job flag (Q22) and course relatedness (Q24)',
        'Time to land first job (Q29)',
      ],
      bestFor: 'Board of Trustees, University President, VP for Academic Affairs.',
      limitation:
          'Degree table (Q12) is not aggregated here; use course/batch filters '
          'for program scope. Not a substitute for a single-wave outcomes export.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.curriculum_competency',
      title: 'Program curriculum & competency audit',
      subtitle:
          'Curriculum relevance, competencies, and advance-studies reasons for '
          'deans and curriculum committees',
      definition:
          'Program-quality view from Official CHED answers: advance-studies '
          'reasons, first-job relatedness, curriculum relevance, and '
          'competencies graduates found useful.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.institutionalGts,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'curriculum_competency',
      icon: Icons.school_outlined,
      fileNameStem: 'AESS_Curriculum_Competency_Audit',
      scopeNote: 'Selected Official CHED waves, batches, and courses only.',
      includeItems: [
        'Reason for advance studies (Q15b)',
        'First-job relatedness (Q24)',
        'Curriculum relevance (Q32)',
        'Useful competencies (Q33)',
      ],
      bestFor: 'Deans, department chairs, and curriculum review committees.',
      limitation:
          'Q15b covers reasons among those who answered advance-studies, not a '
          'full enrollment rate. Course-reason matrix (Q14) and open curriculum '
          'suggestions (Q34) are not auto-summarized yet; use the single-survey '
          'Excel pack for qualitative review.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.industry_placement',
      title: 'Industry linkages & economic placement',
      subtitle:
          'Hiring sectors, work location, job channels, and salary bands',
      definition:
          'Labor-market outcomes for placement offices: industry sector, local '
          'vs abroad, how the first job was found, and initial earnings bands. '
          'Salary bands are never averaged by midpoint.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.institutionalGts,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'industry_placement',
      icon: Icons.business_center_outlined,
      fileNameStem: 'AESS_Industry_Economic_Placement',
      scopeNote: 'Selected Official CHED waves, batches, and courses only.',
      includeItems: [
        'Line of business / industry (Q20)',
        'Place of work (Q21)',
        'How first job was found (Q28)',
        'Initial gross monthly earnings (Q31)',
      ],
      bestFor:
          'Career center directors, placement officers, and industry partnership '
          'coordinators.',
      limitation:
          'Job-level matrix (Q30) is not charted in this version; use the CHED '
          'Excel pack on a single survey for that detail.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.career_mobility',
      title: 'Career mobility & diagnostic',
      subtitle:
          'Unemployment causes, job acceptance/retention drivers, and tenure',
      definition:
          'Diagnostic pack for counseling and alumni support: reasons not '
          'employed, reasons for staying or accepting a job, reasons for '
          'changing jobs, and length of stay in the first job.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.institutionalGts,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'career_mobility',
      icon: Icons.timeline_outlined,
      fileNameStem: 'AESS_Career_Mobility_Diagnostic',
      scopeNote: 'Selected Official CHED waves, batches, and courses only.',
      includeItems: [
        'Reasons not employed (Q17)',
        'Reasons for staying on the job (Q23)',
        'Reasons for accepting the job (Q25)',
        'Reasons for changing jobs (Q26)',
        'Length of stay in first job (Q27)',
      ],
      bestFor: 'Guidance counselors, Alumni Office, and Student Affairs.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.ched_compliance_master',
      title: 'CHED compliance & accreditation master summary',
      subtitle:
          'Audit-ready itemized choice summaries across CHED GTS sections',
      definition:
          'Compliance-oriented rollup of aggregatable CHED choice items '
          '(demographics, advance-studies reason, and employment Part D '
          'indicators) with counts and percentages for accreditation packets.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.institutionalGts,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'ched_compliance_master',
      icon: Icons.verified_outlined,
      fileNameStem: 'AESS_CHED_Compliance_Master_Summary',
      scopeNote: 'Selected Official CHED waves, batches, and courses only.',
      includeItems: [
        'Demographics (Q6, Q7, Q9–Q11)',
        'Advance-studies reason (Q15b)',
        'Employment and first-job choice items (Q16–Q33 where aggregatable)',
        'Response rate for the selected scope',
        'Batch or program comparison table (employment, relatedness, curriculum)',
      ],
      bestFor:
          'Accreditation teams (ALCUCOA, AACCUP, PAASCU) and quality assurance '
          'officers.',
      limitation:
          'Personal fields (Q1–Q5, Q8), tables (Q12, Q13, Q15a), matrices '
          '(Q14, Q30), occupation text (Q19), and open suggestions (Q34) are '
          'not in this rollup. For wave-to-wave deltas use CHED wave comparison; '
          'for filled forms use the survey fillable PDF / Excel pack.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.gts_participation_quality',
      title: 'GTS participation and data quality',
      subtitle:
          'Coverage, response rates, pending work, and missing answers',
      definition:
          'Survey coverage and data-quality view: assigned/submitted/pending, '
          'response rates with stated denominators, per-wave participation, and '
          'missing answers by key CHED outcome item among submitted respondents.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.comparisonsAndQuality,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'gts_participation_quality',
      icon: Icons.fact_check_outlined,
      fileNameStem: 'AESS_GTS_Participation_Data_Quality',
      scopeNote: 'Selected Official CHED waves, batches, and courses only.',
      limitation:
          'Assigned counts are wave assignment totals. Cohort filters apply to '
          'submitted respondents used for missing-answer rates. Skip-logic '
          'items can legitimately show high missing rates.',
    ),
  ];

  static List<AessReportCatalogEntry> get available =>
      all.where((e) => e.isAvailable).toList(growable: false);

  static List<AessReportCatalogEntry> get planned => all
      .where((e) => e.status == ReportCatalogStatus.planned)
      .toList(growable: false);

  static List<AessReportCatalogEntry> forSurface(ReportCatalogSurface surface) =>
      all.where((e) => e.surface == surface).toList(growable: false);

  static AessReportCatalogEntry? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  static AessReportCatalogEntry? bySurveyExportKindName(String kindName) {
    for (final e in all) {
      if (e.surveyExportKindName == kindName) return e;
    }
    return null;
  }

  static AessReportCatalogEntry? byDownloadsPresetId(String presetId) {
    for (final e in all) {
      if (e.downloadsPresetId == presetId) return e;
    }
    return null;
  }

  /// Titles/descriptions for the survey export modal, in display order.
  static List<AessReportCatalogEntry> surveyModalEntries({
    required bool isChedGts,
  }) {
    const order = <String>[
      'responses',
      'management',
      'chedOutcomes',
      'ched',
      'chedFillable',
      'pending',
    ];
    const chedOnly = {'chedOutcomes', 'ched', 'chedFillable'};
    final out = <AessReportCatalogEntry>[];
    for (final kindName in order) {
      final entry = bySurveyExportKindName(kindName);
      if (entry == null || !entry.isAvailable) continue;
      if (chedOnly.contains(kindName) && !isChedGts) continue;
      out.add(entry);
    }
    return out;
  }
}
