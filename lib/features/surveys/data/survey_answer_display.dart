/// Human-readable rendering of stored survey answer values.
///
/// CHED GTS answers can be scalars, lists, or maps:
/// - multi-field items (e.g. Educational Attainment) store `{field: value}`;
/// - matrix checkboxes (e.g. reasons) store `{row: {column: bool}}`.
/// This flattens them into readable lines instead of raw `{...}` dumps.
String formatSurveyAnswerValue(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is List) {
    return value
        .map(formatSurveyAnswerValue)
        .where((s) => s.isNotEmpty)
        .join(', ');
  }
  if (value is Map) {
    final lines = <String>[];
    value.forEach((key, v) {
      final label = key.toString().trim();
      if (v is Map) {
        final checked = <String>[];
        var hasNonBool = false;
        v.forEach((columnKey, columnValue) {
          if (columnValue == true) {
            checked.add(columnKey.toString().trim());
          } else if (columnValue is! bool) {
            hasNonBool = true;
          }
        });
        if (checked.isNotEmpty) {
          lines.add('$label (${checked.join(', ')})');
        } else if (hasNonBool) {
          final inner = formatSurveyAnswerValue(v);
          if (inner.isNotEmpty) {
            lines.add('$label: ${inner.replaceAll('\n', '; ')}');
          }
        }
      } else if (v is bool) {
        if (v) lines.add(label);
      } else {
        final text = v?.toString().trim() ?? '';
        if (text.isNotEmpty) lines.add('$label: $text');
      }
    });
    return lines.join('\n');
  }
  return value.toString().trim();
}

/// True when a stored answer has no meaningful content
/// (null, blank string, empty list, or map with nothing filled/checked).
bool isSurveyAnswerEmpty(dynamic value) =>
    formatSurveyAnswerValue(value).isEmpty;
