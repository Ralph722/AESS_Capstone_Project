import 'dart:math' as math;

import 'package:alumni_system/core/constants/audience_targeting.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Course and batch a respondent may count toward. [batch] is null when the
/// roster has no batch for them ("Batch not recorded").
typedef DssMemberGroup = ({String course, String? batch});

/// AESS DSS sample-size and group-mapping policy
/// (`docs/dss-capability-audit.md` Part 3). Evaluation, Settings, the UI,
/// exports and the SQL re-check all apply these same numbers.
abstract final class DssPolicy {
  /// Fewer valid answers than this: "Not enough data", no rate shown.
  static const notEnoughBelow = 5;

  /// Smallest number of valid answers for a substantive finding.
  static const findingMin = 10;

  /// From this many valid answers the evidence is "strong".
  static const strongFrom = 30;

  /// Outcome findings carry a coverage warning below this response rate.
  static const lowCoverageBelow = 0.30;

  /// Batch label for roster records without a batch (course level only).
  static const batchNotRecorded = 'Batch not recorded';

  /// Lowest `min_n` Settings accepts. Data-quality rules use it as the
  /// "too few responses" trigger, so 1 means "fire on zero responses".
  static int minNFloor(DssRuleCategory category) =>
      category == DssRuleCategory.dataQuality ? 1 : findingMin;

  /// The rule's minimum, never below the policy floor (rules saved before
  /// the floor existed may hold smaller values).
  static int ruleMin(DssRule rule) =>
      math.max(rule.minN, minNFloor(rule.category));

  /// Valid answers an outcome, opportunity or trend flag needs to count as
  /// a finding, given the rule's stored `min_n` (null when unknown).
  static int findingGate(int? minN) => math.max(minN ?? findingMin, findingMin);

  /// Evidence strength for [validAnswers] answers to the metric. [minN] is
  /// the rule's minimum; it can only raise the finding gate above 10.
  static DssEvidenceStrength strength(
    int validAnswers, {
    int minN = findingMin,
  }) {
    final gate = math.max(minN, findingMin);
    if (validAnswers < notEnoughBelow) return DssEvidenceStrength.insufficient;
    if (validAnswers < gate) return DssEvidenceStrength.watch;
    if (validAnswers < strongFrom) return DssEvidenceStrength.limited;
    return DssEvidenceStrength.strong;
  }

  /// Roster course and batch for [member]. Null when the respondent is not
  /// linked to an active roster record or the record has no course: they
  /// never count toward a course, a batch or (for now) institution totals.
  static DssMemberGroup? groupOf(AlumniMember? member) {
    if (member == null) return null;
    final course = member.course.trim();
    if (course.isEmpty) return null;
    final batch = member.batchYear.trim();
    return (course: course, batch: batch.isEmpty ? null : batch);
  }

  /// Batch key used in grouping maps; "Batch not recorded" when missing.
  static String batchLabel(String? batch) => batch ?? batchNotRecorded;

  /// Whether a roster group with zero responses is expected to answer
  /// [survey]: its batch is not newer than the wave and it matches the
  /// survey's course / batch targeting.
  static bool expectedToAnswer(
    Survey survey,
    DateTime waveDate,
    String course,
    String batch,
  ) {
    final year = int.tryParse(
      RegExp(r'\d{4}').firstMatch(batch)?.group(0) ?? '',
    );
    if (year == null || year > waveDate.year) return false;
    try {
      return AudienceTargeting.matches(
        targetPrograms: survey.targetPrograms,
        targetBatchYears: survey.targetBatchYears,
        profile: TracerProfile(
          uid: '',
          email: '',
          displayName: '',
          studentId: '',
          program: course,
          batchYear: batch,
          yearGraduated: batch,
        ),
      );
    } on FormatException {
      return true;
    }
  }

  /// Settings validation. [threshold] is a fraction for rate rules (0.4 =
  /// 40%), bracket steps for the salary gap. Null when the values are valid.
  static String? ruleEditError(
    DssRule rule, {
    required double threshold,
    required int minN,
  }) {
    final floor = minNFloor(rule.category);
    if (minN < floor) {
      return rule.category == DssRuleCategory.dataQuality
          ? 'Minimum responses must be at least $floor.'
          : 'Minimum answers must be at least $floor: the DSS never raises '
                'a finding from fewer than $floor valid answers.';
    }
    if (rule.ruleId == 'SALARY_STAGNATION') {
      if (threshold <= 0 || threshold > 5) {
        return 'Salary gap must be more than 0 and at most 5 brackets.';
      }
      return null;
    }
    if (threshold < 0 || threshold > 1) {
      return 'Threshold must be between 0% and 100%.';
    }
    return null;
  }
}
