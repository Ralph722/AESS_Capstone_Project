import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/alumni/tracer/data/survey_prefill_helper.dart';
import 'package:intl/intl.dart';

/// Prefills built-in CHED GTS answers from live profile / employment.
abstract final class ChedGtsPrefill {
  static Map<String, dynamic> fromProfile(
    TracerProfile profile, {
    EmploymentRecord? employment,
  }) {
    final out = <String, dynamic>{};

    void put(String id, dynamic value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      out[id] = value is String ? value.trim() : value;
    }

    put('ched_1', profile.displayName);
    put('ched_2', profile.address);
    put('ched_3', profile.email);
    put('ched_4', profile.telephoneNumber);
    put('ched_5', profile.mobileNumber);
    put('ched_6', _match(profile.civilStatus, GtsConstants.civilStatuses));
    put('ched_7', _match(profile.gender, GtsConstants.sexOptions));
    if (profile.birthDate != null) {
      put('ched_8', DateFormat('yyyy-MM-dd').format(profile.birthDate!));
    }
    put(
      'ched_9',
      _match(profile.regionOfOrigin, GtsConstants.regionsOfOrigin),
    );
    put('ched_10', profile.province);
    put(
      'ched_11',
      _match(
        profile.locationOfResidence,
        GtsConstants.locationOfResidenceOptions,
      ),
    );

    if (profile.program.trim().isNotEmpty ||
        profile.collegeUniversity.trim().isNotEmpty ||
        profile.yearGraduated.trim().isNotEmpty) {
      out['ched_12'] = [
        {
          'Degree(s) & Specialization(s)': profile.program,
          'College or University': profile.collegeUniversity.isNotEmpty
              ? profile.collegeUniversity
              : GtsConstants.defaultCollegeUniversity,
          'Year Graduated': profile.yearGraduated.isNotEmpty
              ? profile.yearGraduated
              : profile.batchYear,
          'Honor(s) or Award(s) Received': profile.honorsAwards,
        },
      ];
    }

    final employed = GtsConstants.toChedPresentlyEmployed(
      profile.employmentStatus,
    );
    put('ched_16', employed);

    if (employment != null) {
      final empValues = SurveyPrefillHelper.valuesFromEmployment(employment);
      put('ched_16', empValues['employment.presentlyEmployed']);
      put('ched_18', empValues['employment.employmentStatus']);
      put('ched_19', empValues['employment.position']);
      final industry = empValues['employment.industry']?.toString();
      if (industry != null) {
        final item = ChedGtsBuiltin.byId('ched_20');
        put('ched_20', _match(industry, item?.options ?? const []));
      }
      put('ched_21', empValues['employment.placeOfWork']);
      final salary = empValues['employment.salaryRange']?.toString();
      if (salary != null) {
        final item = ChedGtsBuiltin.byId('ched_31');
        put('ched_31', _match(salary, item?.options ?? const []));
      }
    }

    return out;
  }

  /// Merge submitted CHED answers into the live profile (Section A + B.12 + item 16).
  static TracerProfile mergeIntoProfile({
    required TracerProfile current,
    required Map<String, dynamic> answers,
  }) {
    String? text(String id) {
      final v = answers[id];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    DateTime? birthday;
    final rawDate = text('ched_8');
    if (rawDate != null) {
      birthday = DateTime.tryParse(rawDate);
    }

    var program = current.program;
    var college = current.collegeUniversity;
    var yearGraduated = current.yearGraduated;
    var honors = current.honorsAwards;
    final edu = answers['ched_12'];
    if (edu is List && edu.isNotEmpty) {
      Map<String, dynamic>? firstFilled;
      for (final row in edu) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final hasValue = map.values.any(
          (c) => c != null && c.toString().trim().isNotEmpty,
        );
        if (hasValue) {
          firstFilled = map;
          break;
        }
      }
      if (firstFilled != null) {
        final degree =
            firstFilled['Degree(s) & Specialization(s)']?.toString().trim();
        final uni = firstFilled['College or University']?.toString().trim();
        final year = firstFilled['Year Graduated']?.toString().trim();
        final award =
            firstFilled['Honor(s) or Award(s) Received']?.toString().trim();
        if (degree != null && degree.isNotEmpty) program = degree;
        if (uni != null && uni.isNotEmpty) college = uni;
        if (year != null && year.isNotEmpty) yearGraduated = year;
        if (award != null) honors = award;
      }
    }

    final employment = GtsConstants.fromChedPresentlyEmployed(text('ched_16'));

    return current.copyWith(
      displayName: text('ched_1') ?? current.displayName,
      address: text('ched_2') ?? current.address,
      email: text('ched_3') ?? current.email,
      telephoneNumber: text('ched_4') ?? current.telephoneNumber,
      mobileNumber: text('ched_5') ?? current.mobileNumber,
      civilStatus: text('ched_6') ?? current.civilStatus,
      gender: text('ched_7') ?? current.gender,
      birthDate: birthday ?? current.birthDate,
      regionOfOrigin: text('ched_9') ?? current.regionOfOrigin,
      province: text('ched_10') ?? current.province,
      locationOfResidence: text('ched_11') ?? current.locationOfResidence,
      program: program,
      collegeUniversity: college,
      yearGraduated: yearGraduated,
      batchYear: yearGraduated.isNotEmpty ? yearGraduated : current.batchYear,
      honorsAwards: honors,
      employmentStatus: employment ?? current.employmentStatus,
    );
  }

  /// Merge prefill under existing draft answers (draft wins).
  static Map<String, dynamic> merge({
    required Map<String, dynamic> existing,
    required Map<String, dynamic> prefill,
  }) {
    final out = Map<String, dynamic>.from(prefill);
    for (final e in existing.entries) {
      if (_hasValue(e.value)) out[e.key] = e.value;
    }
    return out;
  }

  static bool _hasValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  static String? _match(String raw, List<String> options) {
    if (raw.trim().isEmpty || options.isEmpty) {
      return raw.trim().isEmpty ? null : raw.trim();
    }
    return SurveyPrefillHelper.matchOption(raw, options) ?? raw.trim();
  }
}
