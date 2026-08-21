enum SurveyStatus { draft, published, closed }

enum SurveyQuestionType {
  text,
  longText,
  singleChoice,
  multipleChoice,
  scale,
  date,
}

enum SurveyAssignmentStatus { notStarted, inProgress, completed }

enum SurveyResponseStatus { draft, submitted }

enum SurveyVisibilityOperator { equals, notEquals }

/// Classic-survey show-when rule (stored in `surveys.data.visibility_rules`).
class SurveyVisibilityRule {
  const SurveyVisibilityRule({
    required this.sourceQuestionId,
    required this.operator,
    required this.value,
  });

  final String sourceQuestionId;
  final SurveyVisibilityOperator operator;
  final String value;

  factory SurveyVisibilityRule.fromJson(Map<String, dynamic> json) {
    final opName = json['operator'] as String? ?? 'equals';
    return SurveyVisibilityRule(
      sourceQuestionId: json['sourceQuestionId']?.toString() ?? '',
      operator: SurveyVisibilityOperator.values.firstWhere(
        (e) => e.name == opName,
        orElse: () => SurveyVisibilityOperator.equals,
      ),
      value: json['value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'sourceQuestionId': sourceQuestionId,
        'operator': operator.name,
        'value': value,
      };

  SurveyVisibilityRule copyWith({
    String? sourceQuestionId,
    SurveyVisibilityOperator? operator,
    String? value,
  }) {
    return SurveyVisibilityRule(
      sourceQuestionId: sourceQuestionId ?? this.sourceQuestionId,
      operator: operator ?? this.operator,
      value: value ?? this.value,
    );
  }
}

class Survey {
  final String id;
  final String title;
  final String description;
  final SurveyStatus status;
  final List<String> targetPrograms;
  final List<String> targetBatchYears;
  final DateTime? openAt;
  final DateTime? closeAt;
  final String createdBy;
  /// Resolved from `users.display_name` (falls back to email when loaded).
  final String? createdByDisplayName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  /// Sticky first-publish time in `surveys.data.publishedAt` (not bumped on edits).
  final DateTime? publishedAt;
  final int assignmentCount;
  final int responseCount;
  final String? templateId;
  final String? templateVersion;
  /// e.g. `ched_gts_builtin` for the locked official GTS form.
  final String? kind;
  final String? templateKey;
  final String? schemaVersion;
  /// questionId → rule (classic surveys only; ignored for builtin CHED).
  final Map<String, SurveyVisibilityRule> visibilityRules;
  /// Soft-archive flag in `surveys.data` (no new status / migration).
  final bool archived;

  const Survey({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.targetPrograms = const [],
    this.targetBatchYears = const [],
    this.openAt,
    this.closeAt,
    required this.createdBy,
    this.createdByDisplayName,
    required this.createdAt,
    this.updatedAt,
    this.publishedAt,
    this.assignmentCount = 0,
    this.responseCount = 0,
    this.templateId,
    this.templateVersion,
    this.kind,
    this.templateKey,
    this.schemaVersion,
    this.visibilityRules = const {},
    this.archived = false,
  });

  String get createdByLabel {
    final display = createdByDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    return createdBy;
  }

  bool get isFromTemplate => templateId != null && templateId!.isNotEmpty;

  bool get isChedGtsBuiltin =>
      kind == 'ched_gts_builtin' || templateKey == 'ched_gts_builtin';

  /// Published and inside the optional open/close window.
  bool get isOpen {
    if (archived) return false;
    if (status != SurveyStatus.published) return false;
    final now = DateTime.now();
    if (openAt != null && now.isBefore(openAt!)) return false;
    if (closeAt != null && now.isAfter(closeAt!)) return false;
    return true;
  }

  /// Published but the open date is still in the future.
  bool get isNotYetOpen {
    if (archived || status != SurveyStatus.published) return false;
    if (openAt == null) return false;
    return DateTime.now().isBefore(openAt!);
  }

  /// Past the scheduled close time (if any).
  bool get isPastClose {
    if (closeAt == null) return false;
    return DateTime.now().isAfter(closeAt!);
  }

  /// Published but outside open/close window (or not yet open).
  bool get isScheduledWindow {
    if (archived || status != SurveyStatus.published) return false;
    if (openAt == null && closeAt == null) return false;
    return !isOpen;
  }

  /// Alumni may answer/submit only while [isOpen].
  bool get acceptsResponses => isOpen;

  static Map<String, SurveyVisibilityRule> _parseVisibilityRules(
    Map<String, dynamic> data,
  ) {
    final raw = data['visibility_rules'];
    if (raw is! Map) return const {};
    final out = <String, SurveyVisibilityRule>{};
    raw.forEach((key, value) {
      if (value is Map) {
        out[key.toString()] = SurveyVisibilityRule.fromJson(
          Map<String, dynamic>.from(value),
        );
      }
    });
    return out;
  }

  factory Survey.fromSupabaseRow(Map<String, dynamic> row) {
    final data = row['data'] is Map
        ? Map<String, dynamic>.from(row['data'] as Map)
        : <String, dynamic>{};
    return Survey(
      id: row['id']?.toString() ?? '',
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      status: SurveyStatus.values.firstWhere(
        (e) => e.name == (row['status'] as String? ?? 'draft'),
        orElse: () => SurveyStatus.draft,
      ),
      targetPrograms: List<String>.from(row['target_programs'] ?? []),
      targetBatchYears: List<String>.from(row['target_batch_years'] ?? []),
      openAt: row['open_at'] != null ? _parseDateTime(row['open_at']) : null,
      closeAt: row['close_at'] != null ? _parseDateTime(row['close_at']) : null,
      createdBy: row['created_by']?.toString() ?? '',
      createdAt: _parseDateTime(row['created_at']),
      updatedAt:
          row['updated_at'] != null ? _parseDateTime(row['updated_at']) : null,
      publishedAt: data['publishedAt'] != null
          ? _parseDateTime(data['publishedAt'])
          : null,
      assignmentCount: row['assignment_count'] as int? ?? 0,
      responseCount: row['response_count'] as int? ?? 0,
      templateId: row['template_id']?.toString(),
      templateVersion: row['template_version'] as String?,
      kind: data['kind'] as String?,
      templateKey: data['template_key'] as String?,
      schemaVersion: data['schema_version'] as String?,
      visibilityRules: _parseVisibilityRules(data),
      archived: data['archived'] == true,
    );
  }

  Map<String, dynamic> toSupabaseRow({
    required String createdBySupabaseId,
    String? templateSupabaseId,
    Map<String, dynamic> extra = const {},
  }) {
    final rulesJson = <String, dynamic>{
      for (final e in visibilityRules.entries) e.key: e.value.toJson(),
    };
    final data = <String, dynamic>{
      ...extra,
      if (kind != null) 'kind': kind,
      if (templateKey != null) 'template_key': templateKey,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (publishedAt != null)
        'publishedAt': publishedAt!.toUtc().toIso8601String(),
      // Always write so clearing rules replaces prior JSON (upsert merges data).
      'visibility_rules': rulesJson,
      'archived': archived,
    };
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.name,
      'target_programs': targetPrograms,
      'target_batch_years': targetBatchYears,
      'open_at': openAt?.toUtc().toIso8601String(),
      'close_at': closeAt?.toUtc().toIso8601String(),
      'created_by': createdBySupabaseId,
      'assignment_count': assignmentCount,
      'response_count': responseCount,
      if (templateSupabaseId != null) 'template_id': templateSupabaseId,
      'template_version': templateVersion ?? schemaVersion,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
  }

  Survey copyWith({
    String? title,
    String? description,
    SurveyStatus? status,
    List<String>? targetPrograms,
    List<String>? targetBatchYears,
    DateTime? openAt,
    DateTime? closeAt,
    bool clearOpenAt = false,
    bool clearCloseAt = false,
    DateTime? publishedAt,
    int? assignmentCount,
    int? responseCount,
    String? templateId,
    String? templateVersion,
    String? kind,
    String? templateKey,
    String? schemaVersion,
    Map<String, SurveyVisibilityRule>? visibilityRules,
    bool? archived,
    String? createdByDisplayName,
  }) {
    return Survey(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      targetPrograms: targetPrograms ?? this.targetPrograms,
      targetBatchYears: targetBatchYears ?? this.targetBatchYears,
      openAt: clearOpenAt ? null : (openAt ?? this.openAt),
      closeAt: clearCloseAt ? null : (closeAt ?? this.closeAt),
      createdBy: createdBy,
      createdByDisplayName: createdByDisplayName ?? this.createdByDisplayName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      assignmentCount: assignmentCount ?? this.assignmentCount,
      responseCount: responseCount ?? this.responseCount,
      templateId: templateId ?? this.templateId,
      templateVersion: templateVersion ?? this.templateVersion,
      kind: kind ?? this.kind,
      templateKey: templateKey ?? this.templateKey,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      visibilityRules: visibilityRules ?? this.visibilityRules,
      archived: archived ?? this.archived,
    );
  }
}

class SurveyQuestion {
  final String id;
  final String surveyId;
  final int order;
  final SurveyQuestionType type;
  final String prompt;
  final bool required;
  final List<String> options;
  final int? scaleMin;
  final int? scaleMax;
  final String? section;
  final String? chedItemNumber;
  final String? prefillKey;
  final bool isStandardItem;

  const SurveyQuestion({
    required this.id,
    required this.surveyId,
    required this.order,
    required this.type,
    required this.prompt,
    this.required = true,
    this.options = const [],
    this.scaleMin,
    this.scaleMax,
    this.section,
    this.chedItemNumber,
    this.prefillKey,
    this.isStandardItem = false,
  });

  String get sectionLabel {
    if (section == null || section!.isEmpty) return '';
    switch (section) {
      case 'C':
        return 'C. Training / Advance Studies';
      case 'D':
        return 'D. Employment Data';
      case 'C. TRAINING(S)/ADVANCE STUDIES ATTENDED AFTER COLLEGE':
        return section!;
      case 'D. EMPLOYMENT DATA':
        return section!;
      default:
        return 'Section $section';
    }
  }

  factory SurveyQuestion.fromSupabaseRow(
    Map<String, dynamic> row, {
    required String surveyId,
  }) {
    return SurveyQuestion(
      id: row['id']?.toString() ?? '',
      surveyId: surveyId,
      order: row['order'] as int? ?? 0,
      type: SurveyQuestionType.values.firstWhere(
        (e) => e.name == (row['type'] as String? ?? 'text'),
        orElse: () => SurveyQuestionType.text,
      ),
      prompt: row['prompt'] as String? ?? '',
      required: row['required'] as bool? ?? true,
      options: List<String>.from(row['options'] ?? []),
      scaleMin: row['scale_min'] as int?,
      scaleMax: row['scale_max'] as int?,
      section: row['section'] as String?,
      chedItemNumber: row['ched_item_number'] as String?,
      prefillKey: row['prefill_key'] as String?,
      isStandardItem: row['is_standard_item'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toSupabaseRow({required String surveySupabaseId}) {
    return {
      'id': id,
      'survey_id': surveySupabaseId,
      'order': order,
      'type': type.name,
      'prompt': prompt,
      'required': required,
      'options': options,
      'scale_min': scaleMin,
      'scale_max': scaleMax,
      'section': section,
      'ched_item_number': chedItemNumber,
      'prefill_key': prefillKey,
      'is_standard_item': isStandardItem,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  SurveyQuestion copyWith({
    String? id,
    String? surveyId,
    int? order,
    SurveyQuestionType? type,
    String? prompt,
    bool? required,
    List<String>? options,
    int? scaleMin,
    int? scaleMax,
    String? section,
    String? chedItemNumber,
    String? prefillKey,
    bool? isStandardItem,
    bool clearScale = false,
    bool clearSection = false,
  }) {
    return SurveyQuestion(
      id: id ?? this.id,
      surveyId: surveyId ?? this.surveyId,
      order: order ?? this.order,
      type: type ?? this.type,
      prompt: prompt ?? this.prompt,
      required: required ?? this.required,
      options: options ?? this.options,
      scaleMin: clearScale ? null : (scaleMin ?? this.scaleMin),
      scaleMax: clearScale ? null : (scaleMax ?? this.scaleMax),
      section: clearSection ? null : (section ?? this.section),
      chedItemNumber: chedItemNumber ?? this.chedItemNumber,
      prefillKey: prefillKey ?? this.prefillKey,
      isStandardItem: isStandardItem ?? this.isStandardItem,
    );
  }
}

class SurveyAssignment {
  final String id;
  final String surveyId;
  final String userId;
  final String surveyTitle;
  final SurveyAssignmentStatus status;
  final DateTime assignedAt;
  final DateTime? lastReminderAt;
  final int reminderCount;

  const SurveyAssignment({
    required this.id,
    required this.surveyId,
    required this.userId,
    required this.surveyTitle,
    required this.status,
    required this.assignedAt,
    this.lastReminderAt,
    this.reminderCount = 0,
  });

  bool get isPending => status != SurveyAssignmentStatus.completed;

  factory SurveyAssignment.fromSupabaseRow(Map<String, dynamic> row) {
    return SurveyAssignment(
      id: row['id']?.toString() ?? '',
      surveyId: row['survey_id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      surveyTitle: row['survey_title'] as String? ?? '',
      status: SurveyAssignmentStatus.values.firstWhere(
        (e) => e.name == (row['status'] as String? ?? 'notStarted'),
        orElse: () => SurveyAssignmentStatus.notStarted,
      ),
      assignedAt: Survey._parseDateTime(row['assigned_at']),
      lastReminderAt: row['last_reminder_at'] != null
          ? Survey._parseDateTime(row['last_reminder_at'])
          : null,
      reminderCount: row['reminder_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toSupabaseRow({
    required String surveySupabaseId,
    required String userSupabaseId,
  }) {
    return {
      'id': id,
      'survey_id': surveySupabaseId,
      'user_id': userSupabaseId,
      'survey_title': surveyTitle,
      'status': status.name,
      'assigned_at': assignedAt.toUtc().toIso8601String(),
      'last_reminder_at': lastReminderAt?.toUtc().toIso8601String(),
      'reminder_count': reminderCount,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

/// Assignment joined with alumni profile for admin response management.
class SurveyParticipant {
  final SurveyAssignment assignment;
  final String displayName;
  final String email;
  final String program;
  final String batchYear;
  final String? studentId;
  final String? profileImageUrl;
  final SurveyResponse? response;

  const SurveyParticipant({
    required this.assignment,
    required this.displayName,
    required this.email,
    required this.program,
    required this.batchYear,
    this.studentId,
    this.profileImageUrl,
    this.response,
  });

  bool get isPending => assignment.isPending;
}

enum SurveyResponseEventType { opened, draftSaved, submitted }

/// Append-only lifecycle event for a survey response.
class SurveyResponseEvent {
  const SurveyResponseEvent({
    required this.id,
    required this.surveyId,
    required this.userId,
    required this.eventType,
    required this.createdAt,
    this.deviceCategory,
    this.platformFamily,
    this.browserFamily,
  });

  final String id;
  final String surveyId;
  final String userId;
  final SurveyResponseEventType eventType;
  final DateTime createdAt;
  final String? deviceCategory;
  final String? platformFamily;
  final String? browserFamily;

  factory SurveyResponseEvent.fromSupabaseRow(Map<String, dynamic> row) {
    final typeName = row['event_type'] as String? ?? '';
    return SurveyResponseEvent(
      id: row['id']?.toString() ?? '',
      surveyId: row['survey_id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      eventType: parseEventType(typeName),
      createdAt: Survey._parseDateTime(row['created_at']),
      deviceCategory: row['device_category'] as String?,
      platformFamily: row['platform_family'] as String?,
      browserFamily: row['browser_family'] as String?,
    );
  }

  static SurveyResponseEventType parseEventType(String raw) {
    switch (raw) {
      case 'opened':
        return SurveyResponseEventType.opened;
      case 'draft_saved':
      case 'draftSaved':
        return SurveyResponseEventType.draftSaved;
      case 'submitted':
        return SurveyResponseEventType.submitted;
      default:
        return SurveyResponseEventType.opened;
    }
  }
}

class SurveyReminderResult {
  final int inAppSent;
  final int emailSent;
  final int emailSkippedNoAddress;
  final int emailSkippedNotConfigured;
  final List<String> failures;

  const SurveyReminderResult({
    this.inAppSent = 0,
    this.emailSent = 0,
    this.emailSkippedNoAddress = 0,
    this.emailSkippedNotConfigured = 0,
    this.failures = const [],
  });

  int get totalAttempted => inAppSent + emailSent + failures.length;
}

class SurveyResponse {
  final String surveyId;
  final String userId;
  final Map<String, dynamic> answers;
  final SurveyResponseStatus status;
  final DateTime? submittedAt;
  final DateTime updatedAt;
  final DateTime? openedAt;
  final DateTime? firstDraftAt;
  final String? deviceCategory;
  final String? platformFamily;
  final String? browserFamily;

  const SurveyResponse({
    required this.surveyId,
    required this.userId,
    required this.answers,
    required this.status,
    this.submittedAt,
    required this.updatedAt,
    this.openedAt,
    this.firstDraftAt,
    this.deviceCategory,
    this.platformFamily,
    this.browserFamily,
  });

  String get deviceSummary {
    final parts = [
      if (deviceCategory != null && deviceCategory!.isNotEmpty)
        _labelDeviceCategory(deviceCategory!),
      if (platformFamily != null && platformFamily!.isNotEmpty)
        _labelPlatformFamily(platformFamily!),
      if (browserFamily != null && browserFamily!.isNotEmpty)
        _labelBrowserFamily(browserFamily!),
    ];
    return parts.isEmpty ? 'Device not recorded' : parts.join(' · ');
  }

  static String _labelDeviceCategory(String value) {
    switch (value) {
      case 'mobile':
        return 'Mobile';
      case 'tablet':
        return 'Tablet';
      case 'desktop':
        return 'Desktop';
      default:
        return 'Other device';
    }
  }

  static String _labelPlatformFamily(String value) {
    switch (value) {
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      case 'web':
        return 'Web';
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'linux':
        return 'Linux';
      default:
        return 'Other platform';
    }
  }

  static String _labelBrowserFamily(String value) {
    switch (value) {
      case 'chrome':
        return 'Chrome';
      case 'safari':
        return 'Safari';
      case 'firefox':
        return 'Firefox';
      case 'edge':
        return 'Edge';
      case 'opera':
        return 'Opera';
      case 'native':
        return 'Native app';
      default:
        return 'Other browser';
    }
  }

  factory SurveyResponse.fromSupabaseRow(
    Map<String, dynamic> row, {
    required String surveyId,
  }) {
    return SurveyResponse(
      surveyId: surveyId,
      userId: row['user_id']?.toString() ?? '',
      answers: Map<String, dynamic>.from(row['answers'] ?? {}),
      status: SurveyResponseStatus.values.firstWhere(
        (e) => e.name == (row['status'] as String? ?? 'draft'),
        orElse: () => SurveyResponseStatus.draft,
      ),
      submittedAt: row['submitted_at'] != null
          ? Survey._parseDateTime(row['submitted_at'])
          : null,
      updatedAt: Survey._parseDateTime(row['updated_at']),
      openedAt: row['opened_at'] != null
          ? Survey._parseDateTime(row['opened_at'])
          : null,
      firstDraftAt: row['first_draft_at'] != null
          ? Survey._parseDateTime(row['first_draft_at'])
          : null,
      deviceCategory: row['device_category'] as String?,
      platformFamily: row['platform_family'] as String?,
      browserFamily: row['browser_family'] as String?,
    );
  }

  Map<String, dynamic> toSupabaseRow({
    required String surveySupabaseId,
    required String userSupabaseId,
  }) {
    return {
      'survey_id': surveySupabaseId,
      'user_id': userSupabaseId,
      'answers': answers,
      'status': status.name,
      'submitted_at': submittedAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      if (openedAt != null)
        'opened_at': openedAt!.toUtc().toIso8601String(),
      if (firstDraftAt != null)
        'first_draft_at': firstDraftAt!.toUtc().toIso8601String(),
      if (deviceCategory != null) 'device_category': deviceCategory,
      if (platformFamily != null) 'platform_family': platformFamily,
      if (browserFamily != null) 'browser_family': browserFamily,
    };
  }
}

/// Submitted response with survey title for history lists.
class SurveyResponseWithMeta {
  const SurveyResponseWithMeta({
    required this.response,
    required this.surveyTitle,
  });

  final SurveyResponse response;
  final String surveyTitle;
}
