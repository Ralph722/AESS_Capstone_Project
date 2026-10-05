/// DSS recommendation models (rules, flags, notes).
library;

enum DssFlagStatus { open, inProgress, resolved, dismissed }

enum DssConfidence { ok, low }

enum DssSeverity { info, warning, critical }

enum DssRuleCategory { outcome, dataQuality, opportunity, trend }

/// Group a flag describes: one course × batch, a whole course (all batches)
/// or the whole institution.
enum DssCohortLevel { batch, course, institution }

extension DssCohortLevelX on DssCohortLevel {
  String get dbValue => name;

  String get label => switch (this) {
    DssCohortLevel.batch => 'Course & batch',
    DssCohortLevel.course => 'All batches',
    DssCohortLevel.institution => 'Whole institution',
  };

  static DssCohortLevel fromDb(String? raw) =>
      switch ((raw ?? '').trim().toLowerCase()) {
        'course' => DssCohortLevel.course,
        'institution' => DssCohortLevel.institution,
        _ => DssCohortLevel.batch,
      };
}

enum DssCertainty { confirmed, possible }

extension DssCertaintyX on DssCertainty {
  String get dbValue => name;

  String get label => switch (this) {
    DssCertainty.confirmed => 'Confirmed',
    DssCertainty.possible => 'Possible',
  };

  static DssCertainty? fromDb(String? raw) =>
      switch ((raw ?? '').trim().toLowerCase()) {
        'confirmed' => DssCertainty.confirmed,
        'possible' => DssCertainty.possible,
        _ => null,
      };
}

extension DssFlagStatusX on DssFlagStatus {
  String get dbValue => switch (this) {
    DssFlagStatus.open => 'open',
    DssFlagStatus.inProgress => 'in_progress',
    DssFlagStatus.resolved => 'resolved',
    DssFlagStatus.dismissed => 'dismissed',
  };

  String get label => switch (this) {
    DssFlagStatus.open => 'Open',
    DssFlagStatus.inProgress => 'In Progress',
    DssFlagStatus.resolved => 'Resolved',
    DssFlagStatus.dismissed => 'Dismissed',
  };

  static DssFlagStatus fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'in_progress':
        return DssFlagStatus.inProgress;
      case 'resolved':
        return DssFlagStatus.resolved;
      case 'dismissed':
        return DssFlagStatus.dismissed;
      default:
        return DssFlagStatus.open;
    }
  }
}

extension DssConfidenceX on DssConfidence {
  String get dbValue => this == DssConfidence.low ? 'low' : 'ok';

  static DssConfidence fromDb(String? raw) =>
      (raw ?? '').trim().toLowerCase() == 'low'
      ? DssConfidence.low
      : DssConfidence.ok;
}

extension DssSeverityX on DssSeverity {
  String get dbValue => name;

  static DssSeverity fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'critical':
        return DssSeverity.critical;
      case 'info':
        return DssSeverity.info;
      default:
        return DssSeverity.warning;
    }
  }
}

extension DssRuleCategoryX on DssRuleCategory {
  String get dbValue => switch (this) {
    DssRuleCategory.outcome => 'outcome',
    DssRuleCategory.dataQuality => 'data_quality',
    DssRuleCategory.opportunity => 'opportunity',
    DssRuleCategory.trend => 'trend',
  };

  static DssRuleCategory fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'data_quality':
        return DssRuleCategory.dataQuality;
      case 'opportunity':
        return DssRuleCategory.opportunity;
      case 'trend':
        return DssRuleCategory.trend;
      default:
        return DssRuleCategory.outcome;
    }
  }
}

class DssPlaybookStep {
  const DssPlaybookStep({required this.step});

  final String step;

  factory DssPlaybookStep.fromJson(dynamic raw) {
    if (raw is Map) {
      return DssPlaybookStep(step: (raw['step'] ?? '').toString());
    }
    return DssPlaybookStep(step: raw?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {'step': step};
}

class DssRule {
  const DssRule({
    required this.ruleId,
    required this.name,
    required this.description,
    required this.metricKey,
    required this.operator,
    required this.threshold,
    required this.minN,
    required this.enabled,
    required this.severity,
    required this.recommendedAction,
    required this.playbook,
    required this.category,
    required this.sortOrder,
  });

  final String ruleId;
  final String name;
  final String description;
  final String metricKey;
  final String operator;
  final double threshold;
  final int minN;
  final bool enabled;
  final DssSeverity severity;
  final String recommendedAction;
  final List<DssPlaybookStep> playbook;
  final DssRuleCategory category;
  final int sortOrder;

  factory DssRule.fromSupabaseRow(Map<String, dynamic> row) {
    final playbookRaw = row['playbook'];
    final steps = <DssPlaybookStep>[];
    if (playbookRaw is List) {
      for (final item in playbookRaw) {
        steps.add(DssPlaybookStep.fromJson(item));
      }
    }
    return DssRule(
      ruleId: (row['rule_id'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      metricKey: (row['metric_key'] ?? '').toString(),
      operator: (row['operator'] ?? 'gte').toString(),
      threshold: _asDouble(row['threshold']) ?? 0,
      minN: _asInt(row['min_n']) ?? 20,
      enabled: row['enabled'] == true,
      severity: DssSeverityX.fromDb(row['severity']?.toString()),
      recommendedAction: (row['recommended_action'] ?? '').toString(),
      playbook: steps,
      category: DssRuleCategoryX.fromDb(row['category']?.toString()),
      sortOrder: _asInt(row['sort_order']) ?? 100,
    );
  }

  Map<String, dynamic> toUpdateRow() => {
    'name': name,
    'description': description,
    'threshold': threshold,
    'min_n': minN,
    'enabled': enabled,
    'severity': severity.dbValue,
    'recommended_action': recommendedAction,
    'playbook': playbook.map((e) => e.toJson()).toList(),
  };

  DssRule copyWith({
    double? threshold,
    int? minN,
    bool? enabled,
    String? recommendedAction,
  }) {
    return DssRule(
      ruleId: ruleId,
      name: name,
      description: description,
      metricKey: metricKey,
      operator: operator,
      threshold: threshold ?? this.threshold,
      minN: minN ?? this.minN,
      enabled: enabled ?? this.enabled,
      severity: severity,
      recommendedAction: recommendedAction ?? this.recommendedAction,
      playbook: playbook,
      category: category,
      sortOrder: sortOrder,
    );
  }
}

class DssFlag {
  const DssFlag({
    required this.id,
    required this.ruleId,
    required this.course,
    required this.batchYear,
    this.cohortLevel = DssCohortLevel.batch,
    required this.surveyId,
    required this.surveyTitle,
    required this.metricValue,
    required this.thresholdSnapshot,
    required this.sampleN,
    this.eligibleN,
    required this.confidence,
    required this.status,
    required this.title,
    required this.body,
    required this.recommendedAction,
    required this.evidence,
    this.baselineValue,
    this.followupValue,
    this.followupAt,
    this.followupSampleN,
    this.interventionType,
    this.interventionDetail,
    this.assignedTo,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.verifyDueAt,
    this.impactVerdict,
    this.linkedAnnouncementId,
    this.ruleName,
    this.severity,
    this.playbook = const [],
    this.ruleOperator,
    this.ruleMinN,
    this.ruleCategory,
    this.recheckState,
    this.recheckValue,
    this.recheckSampleN,
    this.recheckedAt,
    this.recoveredSince,
  });

  final String id;
  final String ruleId;
  final String course;
  final String batchYear;
  final DssCohortLevel cohortLevel;
  final String surveyId;
  final String surveyTitle;
  final double metricValue;
  final double thresholdSnapshot;
  final int sampleN;
  final int? eligibleN;
  final DssConfidence confidence;
  final DssFlagStatus status;
  final String title;
  final String body;
  final String recommendedAction;
  final Map<String, dynamic> evidence;
  final double? baselineValue;
  final double? followupValue;
  final DateTime? followupAt;
  final int? followupSampleN;
  final String? interventionType;
  final String? interventionDetail;
  final String? assignedTo;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? verifyDueAt;
  final String? impactVerdict;
  final String? linkedAnnouncementId;

  /// Joined from rule when loaded with select embed.
  final String? ruleName;
  final DssSeverity? severity;
  final List<DssPlaybookStep> playbook;
  final String? ruleOperator;
  final int? ruleMinN;
  final DssRuleCategory? ruleCategory;

  /// Latest nightly server re-check (`dss_flag_checks`); null until it runs.
  /// One of `still_triggered`, `recovered`, `no_data`.
  final String? recheckState;
  final double? recheckValue;
  final int? recheckSampleN;
  final DateTime? recheckedAt;
  final DateTime? recoveredSince;

  bool get recheckRecovered => recheckState == 'recovered';

  String get cohortLabel {
    switch (cohortLevel) {
      case DssCohortLevel.institution:
        return 'Whole institution';
      case DssCohortLevel.course:
        return '${course.trim()} · All batches';
      case DssCohortLevel.batch:
        break;
    }
    final parts = <String>[
      if (course.trim().isNotEmpty) course.trim(),
      if (batchYear.trim().isNotEmpty) 'Batch ${batchYear.trim()}',
    ];
    return parts.isEmpty ? 'All cohorts' : parts.join(' · ');
  }

  /// 95% margin of error bounds (proportion rules only; null on older flags).
  double? get ciLow => _asDouble(evidence['ci_low']);
  double? get ciHigh => _asDouble(evidence['ci_high']);

  DssCertainty? get certainty =>
      DssCertaintyX.fromDb(evidence['certainty']?.toString());

  bool get isTrend => ruleCategory == DssRuleCategory.trend ||
      ruleId == 'UNEMPLOYMENT_TREND_UP';

  String get metricPercentLabel => metricLabelFor(metricValue);

  String metricLabelFor(double value) {
    if (ruleId == 'SALARY_STAGNATION') {
      return value.toStringAsFixed(1);
    }
    if (isTrend) return formatPoints(value);
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  factory DssFlag.fromSupabaseRow(Map<String, dynamic> row) {
    final evidenceRaw = row['evidence'];
    final evidence = <String, dynamic>{};
    if (evidenceRaw is Map) {
      evidence.addAll(Map<String, dynamic>.from(evidenceRaw));
    }

    String? ruleName;
    DssSeverity? severity;
    String? ruleOperator;
    int? ruleMinN;
    DssRuleCategory? ruleCategory;
    var playbook = <DssPlaybookStep>[];
    final embedded = row['dss_rules'];
    if (embedded is Map) {
      ruleName = embedded['name']?.toString();
      severity = DssSeverityX.fromDb(embedded['severity']?.toString());
      ruleOperator = embedded['operator']?.toString();
      ruleMinN = _asInt(embedded['min_n']);
      ruleCategory = DssRuleCategoryX.fromDb(embedded['category']?.toString());
      final pb = embedded['playbook'];
      if (pb is List) {
        playbook = pb.map(DssPlaybookStep.fromJson).toList();
      }
    }

    final checkRaw = row['dss_flag_checks'];
    final check = checkRaw is Map
        ? checkRaw
        : (checkRaw is List && checkRaw.isNotEmpty && checkRaw.first is Map)
            ? checkRaw.first as Map
            : null;

    return DssFlag(
      id: (row['id'] ?? '').toString(),
      ruleId: (row['rule_id'] ?? '').toString(),
      course: (row['course'] ?? '').toString(),
      batchYear: (row['batch_year'] ?? '').toString(),
      cohortLevel: DssCohortLevelX.fromDb(row['cohort_level']?.toString()),
      surveyId: (row['survey_id'] ?? '').toString(),
      surveyTitle: (row['survey_title'] ?? '').toString(),
      metricValue: _asDouble(row['metric_value']) ?? 0,
      thresholdSnapshot: _asDouble(row['threshold_snapshot']) ?? 0,
      sampleN: _asInt(row['sample_n']) ?? 0,
      eligibleN: _asInt(row['eligible_n']),
      confidence: DssConfidenceX.fromDb(row['confidence']?.toString()),
      status: DssFlagStatusX.fromDb(row['status']?.toString()),
      title: (row['title'] ?? '').toString(),
      body: (row['body'] ?? '').toString(),
      recommendedAction: (row['recommended_action'] ?? '').toString(),
      evidence: evidence,
      baselineValue: _asDouble(row['baseline_value']),
      followupValue: _asDouble(row['followup_value']),
      followupAt: _asDate(row['followup_at']),
      followupSampleN: _asInt(row['followup_sample_n']),
      interventionType: row['intervention_type']?.toString(),
      interventionDetail: row['intervention_detail']?.toString(),
      assignedTo: row['assigned_to']?.toString(),
      createdBy: row['created_by']?.toString(),
      updatedBy: row['updated_by']?.toString(),
      createdAt: _asDate(row['created_at']) ?? DateTime.now(),
      updatedAt: _asDate(row['updated_at']) ?? DateTime.now(),
      resolvedAt: _asDate(row['resolved_at']),
      verifyDueAt: _asDate(row['verify_due_at']),
      impactVerdict: row['impact_verdict']?.toString(),
      linkedAnnouncementId: row['linked_announcement_id']?.toString(),
      ruleName: ruleName,
      severity: severity,
      playbook: playbook,
      ruleOperator: ruleOperator,
      ruleMinN: ruleMinN,
      ruleCategory: ruleCategory,
      recheckState: check?['state']?.toString(),
      recheckValue: _asDouble(check?['metric_value']),
      recheckSampleN: _asInt(check?['sample_n']),
      recheckedAt: _asDate(check?['checked_at']),
      recoveredSince: _asDate(check?['recovered_since']),
    );
  }
}

class DssFlagNote {
  const DssFlagNote({
    required this.id,
    required this.flagId,
    this.authorId,
    required this.authorName,
    required this.note,
    this.statusFrom,
    this.statusTo,
    required this.createdAt,
    this.eventType = DssNoteEventType.note,
    this.metadata = const {},
  });

  final String id;
  final String flagId;
  final String? authorId;
  final String authorName;
  final String note;
  final String? statusFrom;
  final String? statusTo;
  final DateTime createdAt;
  final DssNoteEventType eventType;
  final Map<String, dynamic> metadata;

  String get preview {
    final t = note.trim();
    if (t.length <= 90) return t;
    return '${t.substring(0, 87).trimRight()}…';
  }

  factory DssFlagNote.fromSupabaseRow(Map<String, dynamic> row) {
    final metaRaw = row['metadata'];
    final metadata = <String, dynamic>{};
    if (metaRaw is Map) {
      metadata.addAll(Map<String, dynamic>.from(metaRaw));
    }
    return DssFlagNote(
      id: (row['id'] ?? '').toString(),
      flagId: (row['flag_id'] ?? '').toString(),
      authorId: row['author_id']?.toString(),
      authorName: (row['author_name'] ?? '').toString(),
      note: (row['note'] ?? '').toString(),
      statusFrom: row['status_from']?.toString(),
      statusTo: row['status_to']?.toString(),
      createdAt: _asDate(row['created_at']) ?? DateTime.now(),
      eventType: DssNoteEventTypeX.fromDb(row['event_type']?.toString()),
      metadata: metadata,
    );
  }
}

enum DssNoteEventType {
  note,
  status,
  assign,
  impact,
  announcement,
  reopen,
  action,
}

extension DssNoteEventTypeX on DssNoteEventType {
  String get dbValue => name;

  String get label => switch (this) {
    DssNoteEventType.note => 'Note',
    DssNoteEventType.status => 'Status',
    DssNoteEventType.assign => 'Assigned',
    DssNoteEventType.impact => 'Impact',
    DssNoteEventType.announcement => 'Announcement',
    DssNoteEventType.reopen => 'Reopened',
    DssNoteEventType.action => 'Action',
  };

  static DssNoteEventType fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'status':
        return DssNoteEventType.status;
      case 'assign':
        return DssNoteEventType.assign;
      case 'impact':
        return DssNoteEventType.impact;
      case 'announcement':
        return DssNoteEventType.announcement;
      case 'reopen':
        return DssNoteEventType.reopen;
      case 'action':
        return DssNoteEventType.action;
      default:
        return DssNoteEventType.note;
    }
  }
}

class DssActionResult {
  const DssActionResult({
    required this.selected,
    required this.eligible,
    required this.sent,
    required this.jobs,
  });

  final int selected;

  /// Selected people the server accepted (active alumni who still qualify).
  final int eligible;

  /// Notifications created (already reminded today is skipped).
  final int sent;
  final int jobs;
}

class DssHistoryStats {
  const DssHistoryStats({
    required this.raised,
    required this.resolved,
    required this.dismissed,
    required this.open,
    required this.inProgress,
    required this.avgResolutionDays,
    required this.byMonth,
    required this.byRule,
    required this.impactChecked,
    required this.impactImproved,
    required this.impactStillFlagged,
    required this.improvedPct,
    required this.impactByRule,
  });

  final int raised;
  final int resolved;
  final int dismissed;
  final int open;
  final int inProgress;
  final double? avgResolutionDays;
  final Map<String, int> byMonth;
  final Map<String, int> byRule;

  /// Resolved flags that have an impact verdict.
  final int impactChecked;
  final int impactImproved;
  final int impactStillFlagged;
  final double? improvedPct;

  /// ruleId → (checked, improved, stillFlagged)
  final Map<String, ({int checked, int improved, int stillFlagged})>
  impactByRule;
}

/// A change in share as signed percentage points, e.g. 0.12 → "+12 pts".
String formatPoints(double change, {int decimals = 0}) {
  final pts = change * 100;
  final sign = pts > 0 ? '+' : (pts < 0 ? '−' : '');
  return '$sign${pts.abs().toStringAsFixed(decimals)} pts';
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
