import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';

/// Course/batch targeting for surveys and announcements.
class AudienceTargeting {
  AudienceTargeting._();

  static String norm(String value) => value.trim().toLowerCase();

  static String profileBatchYear(TracerProfile profile) {
    final batch = profile.batchYear.trim();
    if (batch.isNotEmpty) return batch;
    return profile.yearGraduated.trim();
  }

  /// Extracts a 4-digit graduation year from profile batch text.
  static String? profileYearDigits(TracerProfile profile) {
    final m = RegExp(r'\d{4}').firstMatch(profileBatchYear(profile));
    return m?.group(0);
  }

  /// Parses `2020-2027`, `2024, 2025`, or `2020-2022, 2025`.
  static List<String> parseBatchYearInput(String input) {
    final result = <String>[];
    for (final part in input.split(',')) {
      result.addAll(_parseBatchYearToken(part.trim()));
    }
    return result;
  }

  /// Expands stored targets (may include `2020-2027` tokens).
  static List<String> expandBatchYearTargets(List<String> raw) {
    final years = <String>{};
    for (final item in raw) {
      years.addAll(_parseBatchYearToken(item.trim()));
    }
    return years.toList()..sort();
  }

  static List<String> _parseBatchYearToken(String token) {
    if (token.isEmpty) return const [];

    final range = RegExp(r'^(\d{4})\s*[-–]\s*(\d{4})$').firstMatch(token);
    if (range != null) {
      var start = int.parse(range.group(1)!);
      var end = int.parse(range.group(2)!);
      if (start > end) {
        final swap = start;
        start = end;
        end = swap;
      }
      const maxSpan = 60;
      if (end - start > maxSpan) {
        throw FormatException(
          'Year range too large (max $maxSpan years). Use a smaller range.',
        );
      }
      return [for (var y = start; y <= end; y++) '$y'];
    }

    if (RegExp(r'^\d{4}$').hasMatch(token)) {
      return [token];
    }

    throw FormatException(
      'Invalid batch year "$token". Use YYYY-YYYY (e.g. 2020-2027) or YYYY.',
    );
  }

  /// Validates batch input without throwing; returns error message or null.
  static String? validateBatchYearInput(String input) {
    if (input.trim().isEmpty) return null;
    try {
      parseBatchYearInput(input);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  /// Collapses consecutive years for display: `2020,2021,...,2027` → `2020-2027`.
  static String formatBatchYearsForDisplay(List<String> years) {
    if (years.isEmpty) return '';
    final ints = <int>[];
    for (final y in years) {
      final m = RegExp(r'^\d{4}$').firstMatch(y.trim());
      if (m != null) ints.add(int.parse(m.group(0)!));
    }
    if (ints.isEmpty) return years.join(', ');
    ints.sort();
    if (ints.length >= 2 && ints.last - ints.first + 1 == ints.length) {
      return '${ints.first}-${ints.last}';
    }
    return ints.join(', ');
  }

  static bool matches({
    required List<String> targetPrograms,
    required List<String> targetBatchYears,
    required TracerProfile profile,
  }) {
    final expandedBatches = expandBatchYearTargets(targetBatchYears);

    if (targetPrograms.isEmpty && expandedBatches.isEmpty) {
      return true;
    }

    if (targetPrograms.isNotEmpty) {
      if (!_courseMatches(targetPrograms, profile.program)) return false;
    }

    if (expandedBatches.isNotEmpty) {
      final year = profileYearDigits(profile);
      if (year == null || !expandedBatches.contains(year)) return false;
    }

    return true;
  }

  static int countMatches({
    required List<String> targetPrograms,
    required List<String> targetBatchYears,
    required Iterable<TracerProfile> profiles,
  }) {
    return profiles
        .where(
          (p) => matches(
            targetPrograms: targetPrograms,
            targetBatchYears: targetBatchYears,
            profile: p,
          ),
        )
        .length;
  }

  /// Normalizes roster course codes for comparison (e.g. BSIT, BTLED-HE).
  static List<String> normalizeCourseTargets(Iterable<String> raw) {
    final out = <String>{};
    for (final item in raw) {
      final normalized = CourseConstants.normalize(item);
      if (normalized != null && CourseConstants.isValid(normalized)) {
        out.add(normalized);
      }
    }
    return out.toList()..sort();
  }

  static bool _courseMatches(List<String> targets, String profileProgram) {
    if (profileProgram.trim().isEmpty) return false;
    final profileCourse =
        CourseConstants.normalize(profileProgram) ?? profileProgram.trim();
    for (final target in targets) {
      final targetCourse = CourseConstants.normalize(target) ?? target.trim();
      if (targetCourse == profileCourse) return true;
      if (norm(targetCourse) == norm(profileCourse)) return true;
    }
    return false;
  }
}
