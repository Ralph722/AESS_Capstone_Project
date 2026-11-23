import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';

/// Progress % for the built-in CHED GTS intro card and wizard top bar.
///
/// Prefill (especially Unemployed / Never Employed collapsing Section D) can
/// make every required visible item look filled before the alumni opens the
/// form. Display progress therefore:
/// - stays at 0% on the intro until a draft exists
/// - caps below 100% until Review / Verify so 100% means ready to submit
abstract final class ChedGtsProgress {
  /// Highest % shown while still answering sections (Review/Submit reserved).
  static const int beforeReviewCap = 95;

  /// Share of required visible items that already have answers (0–100).
  static int requiredFillPercent(Map<String, dynamic> answers) {
    final visible = ChedGtsVisibility.visibleItemIds(answers);
    final requiredCount = ChedGtsBuiltin.items
        .where((i) => i.required && visible.contains(i.id))
        .length;
    if (requiredCount == 0) return 0;
    final missing = ChedGtsVisibility.missingRequired(answers).length;
    return (((requiredCount - missing) / requiredCount) * 100).round().clamp(
      0,
      100,
    );
  }

  /// Intro hero: 0% until a draft exists; never 100% (submit is still ahead).
  static int introPercent(
    Map<String, dynamic> answers, {
    required bool hasDraft,
  }) {
    if (!hasDraft) return 0;
    final fill = requiredFillPercent(answers);
    if (fill >= 100) return beforeReviewCap;
    return fill;
  }

  /// Wizard top bar: 100% only on Review/Verify with nothing required missing.
  static int wizardPercent(
    Map<String, dynamic> answers, {
    required bool onReviewOrVerify,
  }) {
    final fill = requiredFillPercent(answers);
    if (onReviewOrVerify && fill >= 100) return 100;
    if (fill >= beforeReviewCap) return beforeReviewCap;
    return fill;
  }
}
