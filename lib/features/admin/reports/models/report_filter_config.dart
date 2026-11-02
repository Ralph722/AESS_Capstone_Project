import 'package:flutter/foundation.dart';

import 'package:alumni_system/features/admin/reports/models/report_catalog.dart';

/// Filter keys an institutional Downloads template may expose.
enum ReportFilterKey {
  /// Graduation batch / year.
  batchYear,

  /// Degree program / course.
  course,

  /// Single Official CHED wave (or “latest”).
  surveyWave,

  /// Two or more Official CHED waves (comparison).
  surveyWaves,

  /// Classic vs Official CHED vs all surveys.
  surveyType,

  /// Assignment / completion slice for participation reports.
  completionStatus,

  /// Present employment status (from CHED answers or employment extract).
  employmentStatus,

  /// Roster registration flag.
  registrationStatus,

  /// Tracer completion flag.
  tracerStatus,
}

extension ReportFilterKeyX on ReportFilterKey {
  String get label => switch (this) {
        ReportFilterKey.batchYear => 'Graduation batch',
        ReportFilterKey.course => 'Course / program',
        ReportFilterKey.surveyWave => 'CHED GTS wave',
        ReportFilterKey.surveyWaves => 'CHED GTS waves',
        ReportFilterKey.surveyType => 'Survey type',
        ReportFilterKey.completionStatus => 'Completion status',
        ReportFilterKey.employmentStatus => 'Employment status',
        ReportFilterKey.registrationStatus => 'Registration status',
        ReportFilterKey.tracerStatus => 'Tracer status',
      };
}

/// Declares which filters a report supports (schema only; UI comes later).
@immutable
class ReportFilterSchema {
  const ReportFilterSchema({
    required this.catalogId,
    required this.supported,
    this.requiredKeys = const {},
    this.notes,
  });

  final String catalogId;
  final Set<ReportFilterKey> supported;
  final Set<ReportFilterKey> requiredKeys;
  final String? notes;

  bool supports(ReportFilterKey key) => supported.contains(key);
}

/// Concrete filter values chosen for one export.
@immutable
class ReportFilterSelection {
  const ReportFilterSelection({
    this.batchYear,
    this.course,
    this.surveyId,
    this.surveyIds = const [],
    this.surveyType,
    this.completionStatus,
    this.employmentStatus,
    this.registrationStatus,
    this.tracerStatus,
  });

  final String? batchYear;
  final String? course;
  final String? surveyId;
  final List<String> surveyIds;
  final String? surveyType;
  final String? completionStatus;
  final String? employmentStatus;
  final String? registrationStatus;
  final String? tracerStatus;

  static const empty = ReportFilterSelection();

  bool get isEmpty =>
      batchYear == null &&
      course == null &&
      surveyId == null &&
      surveyIds.isEmpty &&
      surveyType == null &&
      completionStatus == null &&
      employmentStatus == null &&
      registrationStatus == null &&
      tracerStatus == null;

  ReportFilterSelection copyWith({
    String? batchYear,
    String? course,
    String? surveyId,
    List<String>? surveyIds,
    String? surveyType,
    String? completionStatus,
    String? employmentStatus,
    String? registrationStatus,
    String? tracerStatus,
    bool clearBatch = false,
    bool clearCourse = false,
    bool clearSurvey = false,
    bool clearSurveyIds = false,
  }) {
    return ReportFilterSelection(
      batchYear: clearBatch ? null : (batchYear ?? this.batchYear),
      course: clearCourse ? null : (course ?? this.course),
      surveyId: clearSurvey ? null : (surveyId ?? this.surveyId),
      surveyIds: clearSurveyIds ? const [] : (surveyIds ?? this.surveyIds),
      surveyType: surveyType ?? this.surveyType,
      completionStatus: completionStatus ?? this.completionStatus,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      tracerStatus: tracerStatus ?? this.tracerStatus,
    );
  }

  /// Keep only keys allowed by [schema] (hides irrelevant filters).
  ReportFilterSelection constrainedTo(ReportFilterSchema schema) {
    return ReportFilterSelection(
      batchYear: schema.supports(ReportFilterKey.batchYear) ? batchYear : null,
      course: schema.supports(ReportFilterKey.course) ? course : null,
      surveyId:
          schema.supports(ReportFilterKey.surveyWave) ? surveyId : null,
      surveyIds:
          schema.supports(ReportFilterKey.surveyWaves) ? surveyIds : const [],
      surveyType:
          schema.supports(ReportFilterKey.surveyType) ? surveyType : null,
      completionStatus: schema.supports(ReportFilterKey.completionStatus)
          ? completionStatus
          : null,
      employmentStatus: schema.supports(ReportFilterKey.employmentStatus)
          ? employmentStatus
          : null,
      registrationStatus: schema.supports(ReportFilterKey.registrationStatus)
          ? registrationStatus
          : null,
      tracerStatus:
          schema.supports(ReportFilterKey.tracerStatus) ? tracerStatus : null,
    );
  }

  /// Human-readable active scope for export covers and UI chips.
  String scopeLabel({String allBatches = 'All batches', String allCourses = 'All courses'}) {
    final parts = <String>[
      batchYear ?? allBatches,
      course ?? allCourses,
    ];
    if (surveyId != null) parts.add('1 wave');
    if (surveyIds.isNotEmpty) parts.add('${surveyIds.length} waves');
    if (surveyType != null) parts.add(surveyType!);
    if (completionStatus != null) parts.add(completionStatus!);
    if (employmentStatus != null) parts.add(employmentStatus!);
    if (registrationStatus != null) parts.add(registrationStatus!);
    if (tracerStatus != null) parts.add(tracerStatus!);
    return parts.join(' · ');
  }
}

/// Filter schemas for Downloads catalog entries.
///
/// Surfaced by the per-card configure dialog on Downloads presets.
abstract final class ReportFilterSchemas {
  static const _batchCourse = {
    ReportFilterKey.batchYear,
    ReportFilterKey.course,
  };

  static const all = <ReportFilterSchema>[
    ReportFilterSchema(
      catalogId: 'downloads.portal_executive_snapshot',
      supported: _batchCourse,
      notes:
          'Batch/course currently apply only to employment rows. KPIs remain '
          'institution-wide.',
    ),
    ReportFilterSchema(
      catalogId: 'downloads.ched_portfolio_pack',
      supported: _batchCourse,
      notes:
          'Batch/course apply to employment rows. Question rollups are '
          'Official CHED portfolio-wide today.',
    ),
    ReportFilterSchema(
      catalogId: 'downloads.ched_wave_comparison',
      supported: {
        ReportFilterKey.batchYear,
        ReportFilterKey.course,
        ReportFilterKey.surveyWaves,
      },
      requiredKeys: {ReportFilterKey.surveyWaves},
      notes: 'Requires selecting 2–8 Official CHED waves.',
    ),
    ReportFilterSchema(
      catalogId: 'downloads.alumni_employment_records',
      supported: {
        ..._batchCourse,
        ReportFilterKey.employmentStatus,
      },
    ),
    ReportFilterSchema(
      catalogId: 'downloads.survey_participation',
      supported: {
        ReportFilterKey.surveyType,
        ReportFilterKey.surveyWave,
        ReportFilterKey.completionStatus,
      },
      notes:
          'Batch/course do not apply to the current portfolio participation '
          'pack. Richer filters arrive with the data-quality template.',
    ),
    ReportFilterSchema(
      catalogId: 'downloads.active_roster_extract',
      supported: {
        ..._batchCourse,
        ReportFilterKey.registrationStatus,
        ReportFilterKey.tracerStatus,
      },
    ),
    // Institutional GTS Downloads templates (Phase 5).
    ReportFilterSchema(
      catalogId: 'downloads.institutional_gts_summary',
      supported: {
        ReportFilterKey.batchYear,
        ReportFilterKey.course,
        ReportFilterKey.surveyWaves,
      },
      notes:
          'Select one or more Official CHED waves. Leave waves empty to include '
          'all published/closed Official CHED waves with submissions.',
    ),
    ReportFilterSchema(
      catalogId: 'downloads.graduate_employment',
      supported: {
        ReportFilterKey.batchYear,
        ReportFilterKey.course,
        ReportFilterKey.surveyWaves,
      },
    ),
    ReportFilterSchema(
      catalogId: 'downloads.curriculum_relevance',
      supported: {
        ReportFilterKey.batchYear,
        ReportFilterKey.course,
        ReportFilterKey.surveyWaves,
      },
    ),
    ReportFilterSchema(
      catalogId: 'downloads.first_job_salary',
      supported: {
        ReportFilterKey.batchYear,
        ReportFilterKey.course,
        ReportFilterKey.surveyWaves,
      },
    ),
    ReportFilterSchema(
      catalogId: 'downloads.educational_background',
      supported: {
        ReportFilterKey.batchYear,
        ReportFilterKey.course,
        ReportFilterKey.surveyWaves,
      },
    ),
    ReportFilterSchema(
      catalogId: 'downloads.alumni_demographics',
      supported: {
        ReportFilterKey.batchYear,
        ReportFilterKey.course,
        ReportFilterKey.surveyWaves,
      },
    ),
    ReportFilterSchema(
      catalogId: 'downloads.gts_participation_quality',
      supported: {
        ReportFilterKey.batchYear,
        ReportFilterKey.course,
        ReportFilterKey.surveyWaves,
      },
      notes:
          'Select Official CHED waves (empty = all with submissions). Cohort '
          'filters apply to submitted respondents; assigned remains wave totals.',
    ),
    ReportFilterSchema(
      catalogId: 'downloads.program_cohort_comparison',
      supported: {
        ReportFilterKey.batchYear,
        ReportFilterKey.course,
        ReportFilterKey.surveyWaves,
        ReportFilterKey.surveyType,
      },
      notes:
          'Use Survey type to choose compare-by: course or batch. Leave waves '
          'empty to include all Official CHED waves with submissions.',
    ),
  ];

  static ReportFilterSchema? byCatalogId(String catalogId) {
    for (final s in all) {
      if (s.catalogId == catalogId) return s;
    }
    return null;
  }

  static ReportFilterSchema? forDownloadsPreset(String presetId) {
    final entry = AessReportCatalog.byDownloadsPresetId(presetId);
    if (entry == null) return null;
    return byCatalogId(entry.id);
  }
}
