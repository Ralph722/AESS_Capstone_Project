import 'package:flutter/material.dart';

/// Export format preferred by a custom report template.
enum CustomReportFormat { pdf, excel, csv }

extension CustomReportFormatX on CustomReportFormat {
  String get label => switch (this) {
        CustomReportFormat.pdf => 'PDF',
        CustomReportFormat.excel => 'Excel',
        CustomReportFormat.csv => 'CSV',
      };

  String get fileExtension => switch (this) {
        CustomReportFormat.pdf => 'pdf',
        CustomReportFormat.excel => 'xlsx',
        CustomReportFormat.csv => 'csv',
      };

  String get mimeType => switch (this) {
        CustomReportFormat.pdf => 'application/pdf',
        CustomReportFormat.excel =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        CustomReportFormat.csv => 'text/csv',
      };
}

/// Optional registration / tracer filters for roster-oriented sections.
enum CustomReportRegistrationFilter { all, registeredOnly, unregisteredOnly }

enum CustomReportTracerFilter { all, completeOnly, incompleteOnly }

enum CustomReportEmploymentFilter { all, employedOnly, unemployedOnly }

/// Sections that can be composed into a custom multi-source report.
enum CustomReportSectionId {
  executiveKpis,
  alumniRoster,
  employmentRecords,
  surveySummary,
  surveyParticipation,
  surveyQuestions,
  events,
  jobPostings,
  announcements,
  forumTopics,
}

extension CustomReportSectionIdX on CustomReportSectionId {
  String get label => switch (this) {
        CustomReportSectionId.executiveKpis => 'Executive KPIs',
        CustomReportSectionId.alumniRoster => 'Alumni roster',
        CustomReportSectionId.employmentRecords => 'Employment records',
        CustomReportSectionId.surveySummary => 'Survey summary',
        CustomReportSectionId.surveyParticipation =>
          'Survey participation & insights',
        CustomReportSectionId.surveyQuestions => 'Survey question summaries',
        CustomReportSectionId.events => 'Events',
        CustomReportSectionId.jobPostings => 'Job postings',
        CustomReportSectionId.announcements => 'Announcements',
        CustomReportSectionId.forumTopics => 'Forum topics',
      };

  String get description => switch (this) {
        CustomReportSectionId.executiveKpis =>
          'Portfolio snapshot: registration, tracer, employment, and survey KPIs.',
        CustomReportSectionId.alumniRoster =>
          'Active roster rows with course, batch, registration status, and date added.',
        CustomReportSectionId.employmentRecords =>
          'Deduped employment submissions for registered alumni.',
        CustomReportSectionId.surveySummary =>
          'Survey waves with assignment and response counts.',
        CustomReportSectionId.surveyParticipation =>
          'Participation funnel plus portfolio insights and recommendations.',
        CustomReportSectionId.surveyQuestions =>
          'Question-level rollups from top published waves with responses.',
        CustomReportSectionId.events => 'Alumni events with date, venue, and status.',
        CustomReportSectionId.jobPostings =>
          'Active job postings with company, type, and deadline.',
        CustomReportSectionId.announcements =>
          'Announcement titles, status, priority, and recipients.',
        CustomReportSectionId.forumTopics =>
          'Forum topics with author, replies, status, tags, and created date.',
      };

  IconData get icon => switch (this) {
        CustomReportSectionId.executiveKpis => Icons.insights_outlined,
        CustomReportSectionId.alumniRoster => Icons.school_outlined,
        CustomReportSectionId.employmentRecords => Icons.work_outline,
        CustomReportSectionId.surveySummary => Icons.poll_outlined,
        CustomReportSectionId.surveyParticipation => Icons.donut_large_outlined,
        CustomReportSectionId.surveyQuestions => Icons.quiz_outlined,
        CustomReportSectionId.events => Icons.event_outlined,
        CustomReportSectionId.jobPostings => Icons.business_center_outlined,
        CustomReportSectionId.announcements => Icons.campaign_outlined,
        CustomReportSectionId.forumTopics => Icons.forum_outlined,
      };

  /// Whether batch / course filters apply to this section.
  bool get supportsBatchCourse => switch (this) {
        CustomReportSectionId.alumniRoster ||
        CustomReportSectionId.events ||
        CustomReportSectionId.announcements =>
          true,
        _ => false,
      };

  bool get supportsRegistrationTracer =>
      this == CustomReportSectionId.alumniRoster;

  bool get supportsEmploymentStatus =>
      this == CustomReportSectionId.employmentRecords;

  bool get supportsDateRange => switch (this) {
        CustomReportSectionId.employmentRecords ||
        CustomReportSectionId.events ||
        CustomReportSectionId.jobPostings ||
        CustomReportSectionId.announcements ||
        CustomReportSectionId.forumTopics =>
          true,
        _ => false,
      };
}

/// Reusable filter set stored with a template.
class CustomReportFilters {
  const CustomReportFilters({
    this.batchYears = const [],
    this.courses = const [],
    this.registration = CustomReportRegistrationFilter.all,
    this.tracer = CustomReportTracerFilter.all,
    this.employment = CustomReportEmploymentFilter.all,
    this.dateStart,
    this.dateEnd,
  });

  final List<String> batchYears;
  final List<String> courses;
  final CustomReportRegistrationFilter registration;
  final CustomReportTracerFilter tracer;
  final CustomReportEmploymentFilter employment;
  final DateTime? dateStart;
  final DateTime? dateEnd;

  bool get hasDateRange => dateStart != null || dateEnd != null;

  bool get isEmpty =>
      batchYears.isEmpty &&
      courses.isEmpty &&
      registration == CustomReportRegistrationFilter.all &&
      tracer == CustomReportTracerFilter.all &&
      employment == CustomReportEmploymentFilter.all &&
      !hasDateRange;

  CustomReportFilters copyWith({
    List<String>? batchYears,
    List<String>? courses,
    CustomReportRegistrationFilter? registration,
    CustomReportTracerFilter? tracer,
    CustomReportEmploymentFilter? employment,
    DateTime? dateStart,
    DateTime? dateEnd,
    bool clearDateRange = false,
  }) {
    return CustomReportFilters(
      batchYears: batchYears ?? this.batchYears,
      courses: courses ?? this.courses,
      registration: registration ?? this.registration,
      tracer: tracer ?? this.tracer,
      employment: employment ?? this.employment,
      dateStart: clearDateRange ? null : (dateStart ?? this.dateStart),
      dateEnd: clearDateRange ? null : (dateEnd ?? this.dateEnd),
    );
  }

  Map<String, dynamic> toJson() => {
        'batchYears': batchYears,
        'courses': courses,
        'registration': registration.name,
        'tracer': tracer.name,
        'employment': employment.name,
        'dateStart': dateStart?.toIso8601String(),
        'dateEnd': dateEnd?.toIso8601String(),
      };

  factory CustomReportFilters.fromJson(Map<String, dynamic> json) {
    return CustomReportFilters(
      batchYears: List<String>.from(json['batchYears'] as List? ?? const []),
      courses: List<String>.from(json['courses'] as List? ?? const []),
      registration: CustomReportRegistrationFilter.values.firstWhere(
        (e) => e.name == json['registration'],
        orElse: () => CustomReportRegistrationFilter.all,
      ),
      tracer: CustomReportTracerFilter.values.firstWhere(
        (e) => e.name == json['tracer'],
        orElse: () => CustomReportTracerFilter.all,
      ),
      employment: CustomReportEmploymentFilter.values.firstWhere(
        (e) => e.name == json['employment'],
        orElse: () => CustomReportEmploymentFilter.all,
      ),
      dateStart: _parseDate(json['dateStart']),
      dateEnd: _parseDate(json['dateEnd']),
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

/// Browser-local saved custom report template.
class CustomReportTemplate {
  const CustomReportTemplate({
    required this.id,
    required this.name,
    required this.sections,
    required this.format,
    required this.filters,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<CustomReportSectionId> sections;
  final CustomReportFormat format;
  final CustomReportFilters filters;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Returns null when valid; otherwise a short validation message.
  /// A name is only required when persisting the template ([forSave]);
  /// one-off exports and printing work without naming anything.
  String? validate({bool forSave = true}) {
    if (forSave && name.trim().isEmpty) return 'Enter a template name.';
    if (sections.isEmpty) return 'Select at least one section.';
    return null;
  }

  CustomReportTemplate copyWith({
    String? id,
    String? name,
    List<CustomReportSectionId>? sections,
    CustomReportFormat? format,
    CustomReportFilters? filters,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomReportTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      sections: sections ?? this.sections,
      format: format ?? this.format,
      filters: filters ?? this.filters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sections': sections.map((s) => s.name).toList(),
        'format': format.name,
        'filters': filters.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CustomReportTemplate.fromJson(Map<String, dynamic> json) {
    final sectionNames = List<String>.from(json['sections'] as List? ?? const []);
    final sections = <CustomReportSectionId>[
      for (final name in sectionNames)
        for (final id in CustomReportSectionId.values)
          if (id.name == name) id,
    ];
    return CustomReportTemplate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sections: sections,
      format: CustomReportFormat.values.firstWhere(
        (e) => e.name == json['format'],
        orElse: () => CustomReportFormat.excel,
      ),
      filters: CustomReportFilters.fromJson(
        Map<String, dynamic>.from(json['filters'] as Map? ?? const {}),
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Blank draft used when creating a new template.
  factory CustomReportTemplate.draft({
    required String id,
    DateTime? now,
  }) {
    final stamp = now ?? DateTime.now();
    return CustomReportTemplate(
      id: id,
      name: '',
      sections: const [
        CustomReportSectionId.executiveKpis,
        CustomReportSectionId.alumniRoster,
        CustomReportSectionId.surveySummary,
      ],
      format: CustomReportFormat.excel,
      filters: const CustomReportFilters(),
      createdAt: stamp,
      updatedAt: stamp,
    );
  }
}
