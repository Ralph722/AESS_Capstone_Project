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
          'survey, with roster fields and their answers side by side.',
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
          'use Downloads “CHED GTS institutional summary” or Builder.',
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
          'Overlaps the portal snapshot and participation pack. Prefer '
          'institutional GTS templates when you need wave-scoped outcomes.',
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
          'Latest employment records for registered alumni (roster source)',
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
          '“Graduate employment report”.',
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
      title: 'Active roster extract',
      subtitle:
          'Active alumni roster with registration and tracer completion status',
      definition:
          'Export of the active alumni roster with registration and tracer '
          'completion status for administrative use.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.confidentialIdentifiable,
      category: ReportCatalogCategory.operations,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'roster',
      icon: Icons.groups_outlined,
      fileNameStem: 'AESS_Active_Roster_Extract',
      scopeNote: 'Honours batch and course filters from Reports filters.',
      includeItems: [
        'Name, course, school ID, batch, email',
        'Registered flag',
        'Tracer complete flag',
        'Date added',
      ],
      bestFor: 'Directory extracts and registration follow-up.',
      limitation: 'Active roster only; no employment answer columns.',
    ),

    // —— Institutional GTS Downloads templates (Phase 5) ——
    AessReportCatalogEntry(
      id: 'downloads.institutional_gts_summary',
      title: 'CHED GTS institutional summary',
      subtitle:
          'Consolidated graduate outcomes for the selected institutional scope',
      definition:
          'Concise overview of graduate outcomes for selected cohorts and/or '
          'Official CHED waves: response rate, employment, relatedness, '
          'curriculum relevance, time to first job, and salary bands.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.institutionalGts,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'institutional_gts',
      icon: Icons.account_balance_outlined,
      fileNameStem: 'AESS_Institutional_GTS_Summary',
      scopeNote: 'Selected Official CHED waves, batches, and courses only.',
      includeItems: [
        'Response rate for the selected scope',
        'Employment status and related CHED outcome distributions',
        'First-job relatedness, time to first job, salary bands',
        'Curriculum relevance',
      ],
      bestFor:
          'University administrators, research office, and CHED coordination.',
      limitation:
          'Aggregated Official CHED answers only. Not a substitute for the '
          'survey-specific outcomes export of a single wave.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.graduate_employment',
      title: 'Graduate employment report',
      subtitle: 'Employment status and characteristics from CHED GTS answers',
      definition:
          'Employment conditions from Official CHED answers: presently employed, '
          'reasons not employed, employment status, line of business, and place '
          'of work.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.institutionalGts,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'graduate_employment',
      icon: Icons.work_outline,
      fileNameStem: 'AESS_Graduate_Employment_Report',
      scopeNote: 'Selected Official CHED waves, batches, and courses only.',
      limitation:
          'Free-text occupation and job-level matrix fields are not charted in '
          'this version; use the CHED Excel pack on a single survey for those.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.curriculum_relevance',
      title: 'Curriculum relevance report',
      subtitle:
          'Course relatedness, curriculum relevance, and useful competencies',
      definition:
          'How graduates evaluate college education relative to work: first-job '
          'relatedness, curriculum relevance, and useful competencies.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.institutionalGts,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'curriculum_relevance',
      icon: Icons.school_outlined,
      fileNameStem: 'AESS_Curriculum_Relevance_Report',
      scopeNote: 'Selected Official CHED waves, batches, and courses only.',
      limitation:
          'Open curriculum suggestions (item 34) are not auto-summarized; export '
          'single-survey responses for qualitative review.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.first_job_salary',
      title: 'First-job and salary report',
      subtitle:
          'First-job transition, job-finding, duration, and salary bands',
      definition:
          'First-job experiences and initial gross monthly earnings bands from '
          'Official CHED answers. Salary bands are never averaged by midpoint.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.institutionalGts,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'first_job_salary',
      icon: Icons.trending_up_outlined,
      fileNameStem: 'AESS_First_Job_Salary_Report',
      scopeNote: 'Selected Official CHED waves, batches, and courses only.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.educational_background',
      title: 'Educational background report',
      subtitle: 'Advance-studies reasons from Official CHED answers',
      definition:
          'Aggregated reasons for pursuing advance studies (item 15b). Matrix '
          'and training-table items remain available in the single-survey Excel '
          'pack.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.institutionalGts,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'educational_background',
      icon: Icons.menu_book_outlined,
      fileNameStem: 'AESS_Educational_Background_Report',
      scopeNote: 'Selected Official CHED waves, batches, and courses only.',
      limitation:
          'Item 14 (UG vs graduate reason matrix) and training tables are not '
          'yet aggregated here.',
    ),
    AessReportCatalogEntry(
      id: 'downloads.alumni_demographics',
      title: 'Alumni demographics report',
      subtitle:
          'Aggregated civil status, sex, and geographic distribution of '
          'respondents',
      definition:
          'Aggregated demographic and geographic profile of responding alumni. '
          'Contact details are excluded.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.institutionalGts,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'alumni_demographics',
      icon: Icons.public_outlined,
      fileNameStem: 'AESS_Alumni_Demographics_Report',
      scopeNote: 'Selected Official CHED waves, batches, and courses only.',
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
    AessReportCatalogEntry(
      id: 'downloads.program_cohort_comparison',
      title: 'Program and cohort comparison',
      subtitle:
          'Compare employment and relatedness across programs or batches',
      definition:
          'Side-by-side graduate outcomes by program or graduation cohort '
          'within a selected Official CHED scope, with answered denominators.',
      surface: ReportCatalogSurface.downloadsLibrary,
      scope: ReportScopeKind.institutional,
      privacy: ReportPrivacyClass.aggregated,
      category: ReportCatalogCategory.comparisonsAndQuality,
      status: ReportCatalogStatus.available,
      downloadsPresetId: 'program_cohort_comparison',
      icon: Icons.table_chart_outlined,
      fileNameStem: 'AESS_Program_Cohort_Comparison',
      scopeNote:
          'Choose compare-by course or batch in the configure dialog, then '
          'optional waves and cohort filters.',
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
