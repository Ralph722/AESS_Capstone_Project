/// Display formatting for rates on Reports & Analytics (and matching Home KPIs).
///
/// [rate] is a 0–1 ratio. Always compute with full precision; round only here.
/// Whole percents omit the trailing decimal (`20%`); others keep one place (`66.7%`).
String formatReportPercent(double rate, {int fractionDigits = 1}) =>
    formatReportPercentPoints(rate * 100, fractionDigits: fractionDigits);

/// Same rules for values already expressed as percent points (e.g. 66.7).
String formatReportPercentPoints(double percent, {int fractionDigits = 1}) {
  final fixed = percent.toStringAsFixed(fractionDigits);
  if (fractionDigits <= 0) return '$fixed%';
  // Drop trailing ".0" / ".00" so exact wholes read as 20%, not 20.0%.
  final trimmed = fixed.replaceFirst(RegExp(r'\.0+$'), '');
  return '$trimmed%';
}
