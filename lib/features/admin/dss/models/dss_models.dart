/// DSS recommendation models (rules, flags, notes).
library;

import 'dart:math' as math;

import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';

/// [watch]: 5–9 valid answers, monitored but not a finding. [superseded]:
/// a newer wave checked the same finding; final.
enum DssFlagStatus { open, inProgress, resolved, dismissed, watch, superseded }

/// How much the answers behind a finding can carry (Part 3 sample-size
/// policy): under 5 valid answers, 5–9, 10–29, 30 or more.
enum DssEvidenceStrength { insufficient, watch, limited, strong }

extension DssEvidenceStrengthX on DssEvidenceStrength {
  String get dbValue => name;

  String get label => switch (this) {
    DssEvidenceStrength.insufficient => 'Not enough data',
    DssEvidenceStrength.watch => 'Watch',
    DssEvidenceStrength.limited => 'Limited evidence',
    DssEvidenceStrength.strong => 'Strong evidence',
  };

  /// Watch and Not enough data are shown, but are not findings.
  bool get isFinding =>
      this == DssEvidenceStrength.limited || this == DssEvidenceStrength.strong;

  static DssEvidenceStrength? fromDb(String? raw) =>
      switch ((raw ?? '').trim().toLowerCase()) {
        'insufficient' => DssEvidenceStrength.insufficient,
        'watch' => DssEvidenceStrength.watch,
        'limited' => DssEvidenceStrength.limited,
        'strong' => DssEvidenceStrength.strong,
        _ => null,
      };
}

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
    DssFlagStatus.watch => 'watch',
    DssFlagStatus.superseded => 'superseded',
  };

  String get label => switch (this) {
    DssFlagStatus.open => 'Open',
    DssFlagStatus.inProgress => 'In Progress',
    DssFlagStatus.resolved => 'Resolved',
    DssFlagStatus.dismissed => 'Dismissed',
    DssFlagStatus.watch => 'Watch',
    DssFlagStatus.superseded => 'Superseded',
  };

  /// No further action: closed by an admin or replaced by a newer wave.
  bool get isClosed =>
      this == DssFlagStatus.resolved ||
      this == DssFlagStatus.dismissed ||
      this == DssFlagStatus.superseded;

  /// Unknown values read as open so a newer database never breaks parsing.
  static DssFlagStatus fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'in_progress':
        return DssFlagStatus.inProgress;
      case 'resolved':
        return DssFlagStatus.resolved;
      case 'dismissed':
        return DssFlagStatus.dismissed;
      case 'watch':
        return DssFlagStatus.watch;
      case 'superseded':
        return DssFlagStatus.superseded;
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

  String get label => switch (this) {
    DssSeverity.critical => 'Critical',
    DssSeverity.warning => 'Warning',
    DssSeverity.info => 'Info',
  };

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
  const DssPlaybookStep({required this.step, this.cause});

  final String step;

  /// Null: always shown. Otherwise shown only for that cause; `default`
  /// steps show when no cause was detected.
  final String? cause;

  factory DssPlaybookStep.fromJson(dynamic raw) {
    if (raw is Map) {
      final cause = raw['cause']?.toString().trim();
      return DssPlaybookStep(
        step: (raw['step'] ?? '').toString(),
        cause: cause == null || cause.isEmpty ? null : cause,
      );
    }
    return DssPlaybookStep(step: raw?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {'step': step, 'cause': ?cause};
}

/// Rule label shown in the app. `UNEMPLOYMENT_HIGH` keeps its stored name
/// and meaning (Q16 "No" or "Never Employed"); only its label changes.
String dssRuleDisplayName(String ruleId, String stored) => switch (ruleId) {
  'UNEMPLOYMENT_HIGH' => 'Not currently employed',
  _ => stored,
};

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

  /// Name shown in the app (the stored [name] is unchanged).
  String get displayName => dssRuleDisplayName(ruleId, name);

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
    this.evidenceStrengthRaw,
    this.supersededBy,
    this.supersededAt,
    this.ownerOffice,
    this.responsibleName,
    this.startDate,
    this.dueDate,
    this.reviewDate,
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

  /// `dss_flags.evidence_strength` (generated from the evidence); null on
  /// databases without the column and on older flags.
  final String? evidenceStrengthRaw;

  /// The newer wave's flag for the same finding; null when that wave no
  /// longer raised it.
  final String? supersededBy;
  final DateTime? supersededAt;

  /// Office acting on the finding and the person responsible (who may not
  /// have an account; [assignedTo] is the responsible admin).
  final String? ownerOffice;
  final String? responsibleName;

  /// Dates only (local midnight). [reviewDate] is the next progress check
  /// while the work is under way; [verifyDueAt] is the check after resolving.
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? reviewDate;

  /// Open or in progress with a due date before [now]'s day.
  bool isOverdue(DateTime now) {
    final due = dueDate;
    if (due == null || !_hasPlan) return false;
    return _dateOnly(due).isBefore(_dateOnly(now));
  }

  /// Days until the due date (0 = today); null without a due date or once
  /// the flag is closed or on Watch.
  int? daysUntilDue(DateTime now) {
    final due = dueDate;
    if (due == null || !_hasPlan) return null;
    return _dateOnly(due).difference(_dateOnly(now)).inDays;
  }

  bool get _hasPlan =>
      status == DssFlagStatus.open || status == DssFlagStatus.inProgress;

  String get findingKey =>
      dssFindingKey(ruleId, cohortLevel.dbValue, course, batchYear);

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
      evidenceStrength == DssEvidenceStrength.insufficient
      ? null
      : DssCertaintyX.fromDb(evidence['certainty']?.toString());

  bool get isTrend =>
      ruleCategory == DssRuleCategory.trend ||
      ruleId == 'UNEMPLOYMENT_TREND_UP';

  bool get isDataQuality =>
      ruleId == 'DATA_QUALITY_LOW' ||
      ruleCategory == DssRuleCategory.dataQuality;

  /// Valid answers to the flag's question (its own denominator, not the
  /// group size). Older flags stored it under per-rule keys.
  int get validAnswers {
    for (final key in const [
      'valid_answers',
      'answered',
      'employed_with_level',
    ]) {
      final v = evidence[key];
      if (v is num) return v.toInt();
    }
    final current = evidence['current_answered'];
    final previous = evidence['previous_answered'];
    if (current is num && previous is num) {
      return math.min(current, previous).toInt();
    }
    return sampleN;
  }

  /// Null for data-quality flags (they measure coverage, not outcomes).
  /// Flags raised before the policy existed get it from their stored counts.
  DssEvidenceStrength? get evidenceStrength {
    if (isDataQuality) return null;
    return DssEvidenceStrengthX.fromDb(
          (evidenceStrengthRaw ?? evidence['evidence_strength'])?.toString(),
        ) ??
        DssPolicy.strength(
          validAnswers,
          minN: ruleMinN ?? DssPolicy.findingMin,
        );
  }

  /// Counts as an institutional finding (not Watch or Not enough data).
  bool get isFinding =>
      status != DssFlagStatus.watch && (evidenceStrength?.isFinding ?? true);

  /// Open, in progress or Watch.
  bool get isActive =>
      status == DssFlagStatus.open ||
      status == DssFlagStatus.inProgress ||
      status == DssFlagStatus.watch;

  /// Response rate of the group when the outcome was measured.
  double? get groupResponseRate => _asDouble(evidence['response_rate']);

  bool get coverageWarning => evidence['coverage_warning'] == true;

  /// `current` when a closed wave's rate had to use today's roster.
  String? get rosterBasis => evidence['roster_basis']?.toString();

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
      evidenceStrengthRaw: row['evidence_strength']?.toString(),
      supersededBy: row['superseded_by']?.toString(),
      supersededAt: _asDate(row['superseded_at']),
      ownerOffice: _asText(row['owner_office']),
      responsibleName: _asText(row['responsible_name']),
      startDate: _asDay(row['start_date']),
      dueDate: _asDay(row['due_date']),
      reviewDate: _asDay(row['review_date']),
    );
  }
}

/// Identity of a finding across waves: rule × level × course × batch
/// (`dss_flags.finding_key`).
String dssFindingKey(
  String ruleId,
  String cohortLevel,
  String course,
  String batchYear,
) => '$ruleId|$cohortLevel|$course|$batchYear';

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
  evidence,
  outcome,
}

extension DssNoteEventTypeX on DssNoteEventType {
  String get dbValue => name;

  String get label => switch (this) {
    DssNoteEventType.note => 'Note',
    DssNoteEventType.status => 'Status',
    DssNoteEventType.assign => 'Assigned',
    DssNoteEventType.impact => 'Coverage re-check',
    DssNoteEventType.announcement => 'Announcement',
    DssNoteEventType.reopen => 'Reopened',
    DssNoteEventType.action => 'Action',
    DssNoteEventType.evidence => 'Evidence',
    DssNoteEventType.outcome => 'Outcome',
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
      case 'evidence':
        return DssNoteEventType.evidence;
      case 'outcome':
        return DssNoteEventType.outcome;
      default:
        return DssNoteEventType.note;
    }
  }
}

/// Kind of offline evidence (`dss_flag_evidence.evidence_type`).
enum DssEvidenceType { meeting, event, communication, document, report, other }

extension DssEvidenceTypeX on DssEvidenceType {
  String get dbValue => name;

  String get label => switch (this) {
    DssEvidenceType.meeting => 'Meeting / consultation',
    DssEvidenceType.event => 'Event / activity',
    DssEvidenceType.communication => 'Communication sent',
    DssEvidenceType.document => 'Document / memo',
    DssEvidenceType.report => 'Report / data',
    DssEvidenceType.other => 'Other',
  };

  static DssEvidenceType fromDb(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return DssEvidenceType.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => DssEvidenceType.other,
    );
  }
}

/// One offline evidence entry on a flag. Removed entries stay in the table
/// with [removedAt] set and are hidden from the list.
class DssFlagEvidence {
  const DssFlagEvidence({
    required this.id,
    required this.flagId,
    required this.type,
    required this.title,
    required this.date,
    this.description = '',
    this.link,
    this.createdByName = '',
    required this.createdAt,
    this.removedAt,
  });

  final String id;
  final String flagId;
  final DssEvidenceType type;
  final String title;
  final DateTime date;
  final String description;
  final String? link;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? removedAt;

  bool get isRemoved => removedAt != null;

  factory DssFlagEvidence.fromSupabaseRow(Map<String, dynamic> row) =>
      DssFlagEvidence(
        id: (row['id'] ?? '').toString(),
        flagId: (row['flag_id'] ?? '').toString(),
        type: DssEvidenceTypeX.fromDb(row['evidence_type']?.toString()),
        title: (row['title'] ?? '').toString(),
        date: _asDay(row['evidence_date']) ?? DateTime.now(),
        description: (row['description'] ?? '').toString(),
        link: _asText(row['link']),
        createdByName: (row['created_by_name'] ?? '').toString(),
        createdAt: _asDate(row['created_at']) ?? DateTime.now(),
        removedAt: _asDate(row['removed_at']),
      );
}

/// Next-wave outcome of an intervention (`dss_interventions.outcome_status`).
enum DssOutcomeStatus {
  notEvaluated,
  pendingFollowup,
  successful,
  partiallySuccessful,
  unsuccessful,
  inconclusive,
  noComparableData,
}

extension DssOutcomeStatusX on DssOutcomeStatus {
  String get dbValue => switch (this) {
    DssOutcomeStatus.notEvaluated => 'not_evaluated',
    DssOutcomeStatus.pendingFollowup => 'pending_followup',
    DssOutcomeStatus.successful => 'successful',
    DssOutcomeStatus.partiallySuccessful => 'partially_successful',
    DssOutcomeStatus.unsuccessful => 'unsuccessful',
    DssOutcomeStatus.inconclusive => 'inconclusive',
    DssOutcomeStatus.noComparableData => 'no_comparable_data',
  };

  String get label => switch (this) {
    DssOutcomeStatus.notEvaluated => 'Not evaluated',
    DssOutcomeStatus.pendingFollowup => 'Pending follow-up',
    DssOutcomeStatus.successful => 'Successful',
    DssOutcomeStatus.partiallySuccessful => 'Partially successful',
    DssOutcomeStatus.unsuccessful => 'Unsuccessful',
    DssOutcomeStatus.inconclusive => 'Inconclusive',
    DssOutcomeStatus.noComparableData => 'No comparable data',
  };

  /// The next wave has been judged; a decision can be recorded.
  bool get isFinal =>
      this != DssOutcomeStatus.notEvaluated &&
      this != DssOutcomeStatus.pendingFollowup;

  static DssOutcomeStatus fromDb(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return DssOutcomeStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => DssOutcomeStatus.notEvaluated,
    );
  }

  static DssOutcomeStatus? tryFromDb(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final s in DssOutcomeStatus.values) {
      if (s.dbValue == value) return s;
    }
    return null;
  }
}

/// What the admin decided after an outcome (`dss_interventions.decision`).
enum DssOutcomeDecision { resolve, continueWork, modify, escalate }

extension DssOutcomeDecisionX on DssOutcomeDecision {
  String get dbValue => switch (this) {
    DssOutcomeDecision.resolve => 'resolve',
    DssOutcomeDecision.continueWork => 'continue',
    DssOutcomeDecision.modify => 'modify',
    DssOutcomeDecision.escalate => 'escalate',
  };

  String get label => switch (this) {
    DssOutcomeDecision.resolve => 'Resolve',
    DssOutcomeDecision.continueWork => 'Continue',
    DssOutcomeDecision.modify => 'Modify',
    DssOutcomeDecision.escalate => 'Escalate',
  };

  static DssOutcomeDecision? fromDb(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final d in DssOutcomeDecision.values) {
      if (d.dbValue == value) return d;
    }
    return null;
  }
}

/// One intervention on a finding with its success test, baseline and
/// next-wave outcome. Outcomes are written only by the server.
class DssIntervention {
  const DssIntervention({
    required this.id,
    required this.flagId,
    required this.findingKey,
    required this.ruleId,
    this.continuesId,
    required this.interventionType,
    this.description = '',
    this.expectedOutcome = '',
    required this.successMetric,
    required this.successOperator,
    required this.successTarget,
    required this.startedOn,
    this.baselineSurveyTitle = '',
    this.baselineValue,
    this.baselineN,
    this.followupSurveyId,
    this.followupSurveyTitle,
    this.followupValue,
    this.followupN,
    this.outcomeStatus = DssOutcomeStatus.notEvaluated,
    this.evaluationNote,
    this.evaluatedAt,
    this.decision,
    this.decisionNote,
    this.escalatedTo,
    this.decidedByName,
    this.decidedAt,
    this.createdByName = '',
    required this.createdAt,
  });

  final String id;
  final String flagId;
  final String findingKey;
  final String ruleId;
  final String? continuesId;
  final String interventionType;
  final String description;
  final String expectedOutcome;
  final String successMetric;
  final String successOperator;
  final double successTarget;
  final DateTime startedOn;
  final String baselineSurveyTitle;
  final double? baselineValue;
  final int? baselineN;
  final String? followupSurveyId;
  final String? followupSurveyTitle;
  final double? followupValue;
  final int? followupN;
  final DssOutcomeStatus outcomeStatus;
  final String? evaluationNote;
  final DateTime? evaluatedAt;
  final DssOutcomeDecision? decision;
  final String? decisionNote;
  final String? escalatedTo;
  final String? decidedByName;
  final DateTime? decidedAt;
  final String createdByName;
  final DateTime createdAt;

  bool get isDecided => decision != null;

  /// An outcome is known and nothing was decided yet.
  bool get canDecide => !isDecided && outcomeStatus.isFinal;

  /// The plan can change until the outcome is known.
  bool get canEditPlan => !isDecided && !outcomeStatus.isFinal;

  factory DssIntervention.fromSupabaseRow(Map<String, dynamic> row) =>
      DssIntervention(
        id: (row['id'] ?? '').toString(),
        flagId: (row['flag_id'] ?? '').toString(),
        findingKey: (row['finding_key'] ?? '').toString(),
        ruleId: (row['rule_id'] ?? '').toString(),
        continuesId: _asText(row['continues_id']),
        interventionType: (row['intervention_type'] ?? '').toString(),
        description: (row['description'] ?? '').toString(),
        expectedOutcome: (row['expected_outcome'] ?? '').toString(),
        successMetric: (row['success_metric'] ?? '').toString(),
        successOperator: (row['success_operator'] ?? 'lt').toString(),
        successTarget: _asDouble(row['success_target']) ?? 0,
        startedOn: _asDay(row['started_on']) ?? _dateOnly(DateTime.now()),
        baselineSurveyTitle: (row['baseline_survey_title'] ?? '').toString(),
        baselineValue: _asDouble(row['baseline_value']),
        baselineN: _asInt(row['baseline_n']),
        followupSurveyId: _asText(row['followup_survey_id']),
        followupSurveyTitle: _asText(row['followup_survey_title']),
        followupValue: _asDouble(row['followup_value']),
        followupN: _asInt(row['followup_n']),
        outcomeStatus: DssOutcomeStatusX.fromDb(
          row['outcome_status']?.toString(),
        ),
        evaluationNote: _asText(row['evaluation_note']),
        evaluatedAt: _asDate(row['evaluated_at']),
        decision: DssOutcomeDecisionX.fromDb(row['decision']?.toString()),
        decisionNote: _asText(row['decision_note']),
        escalatedTo: _asText(row['escalated_to']),
        decidedByName: _asText(row['decided_by_name']),
        decidedAt: _asDate(row['decided_at']),
        createdByName: (row['created_by_name'] ?? '').toString(),
        createdAt: _asDate(row['created_at']) ?? DateTime.now(),
      );
}

/// Result of `dss_evaluate_intervention`. While the follow-up wave still
/// accepts responses, [provisional] is true and [previewStatus] is what the
/// outcome would be today; nothing final is stored.
class DssOutcomeCheck {
  const DssOutcomeCheck({
    required this.outcomeStatus,
    this.previewStatus,
    this.provisional = false,
    this.followupSurveyTitle,
    this.followupValue,
    this.followupN,
    this.note,
  });

  final DssOutcomeStatus outcomeStatus;
  final DssOutcomeStatus? previewStatus;
  final bool provisional;
  final String? followupSurveyTitle;
  final double? followupValue;
  final int? followupN;
  final String? note;

  factory DssOutcomeCheck.fromJson(Map<String, dynamic> json) =>
      DssOutcomeCheck(
        outcomeStatus: DssOutcomeStatusX.fromDb(
          json['outcome_status']?.toString(),
        ),
        previewStatus: DssOutcomeStatusX.tryFromDb(
          json['preview_status']?.toString(),
        ),
        provisional: json['provisional'] == true,
        followupSurveyTitle: _asText(json['followup_survey_title']),
        followupValue: _asDouble(json['followup_value']),
        followupN: _asInt(json['followup_n']),
        note: _asText(json['note']),
      );
}

/// `YYYY-MM-DD` for a date column.
String dssDateValue(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

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
    this.superseded = 0,
  });

  /// Flags raised as findings (Watch items are not counted).
  final int raised;
  final int resolved;
  final int dismissed;
  final int open;
  final int inProgress;

  /// Replaced by a newer wave of the same finding.
  final int superseded;
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

/// A date column as local midnight.
DateTime? _asDay(dynamic v) {
  final d = _asDate(v);
  return d == null ? null : _dateOnly(d);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String? _asText(dynamic v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}
