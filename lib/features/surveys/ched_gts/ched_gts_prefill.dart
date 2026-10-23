import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/alumni/tracer/data/survey_prefill_helper.dart';
import 'package:intl/intl.dart';

/// Prefills built-in CHED GTS answers from live profile / employment.
abstract final class ChedGtsPrefill {
  /// Pre-filled profile items that often change between tracer rounds, so
  /// alumni are prompted to re-check them: contact details, civil status,
  /// province and type of residence, and whether they are employed. Region
  /// of origin stays out: it is where the alumni is from.
  static const Set<String> mayChangeIds = {
    'ched_2',
    'ched_3',
    'ched_4',
    'ched_5',
    'ched_6',
    'ched_10',
    'ched_11',
    'ched_16',
    'ched_17',
    'ched_17_other',
    'ched_18',
    'ched_19',
  };

  /// Whether [itemId] still shows its pre-filled profile value and is one
  /// that may be out of date.
  static bool showsProfileNote(
    String itemId,
    dynamic answer,
    Map<String, dynamic> prefilled,
  ) {
    if (!mayChangeIds.contains(itemId)) return false;
    final original = prefilled[itemId];
    if (!_hasValue(original) || !_hasValue(answer)) return false;
    if (original is List && answer is List) {
      if (original.length != answer.length) return false;
      final setA = original.map((e) => e.toString().trim()).toSet();
      final setB = answer.map((e) => e.toString().trim()).toSet();
      return setA.length == setB.length && setA.containsAll(setB);
    }
    return original.toString().trim() == answer.toString().trim();
  }

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
    put('ched_3', profile.preferredEmail);
    put('ched_4', profile.telephoneNumber);
    put('ched_5', profile.mobileNumber);
    put('ched_6', _match(profile.civilStatus, GtsConstants.civilStatuses));
    put('ched_7', _match(profile.gender, GtsConstants.sexOptions));
    if (profile.birthDate != null) {
      put('ched_8', DateFormat('yyyy-MM-dd').format(profile.birthDate!));
    }
    put('ched_9', _match(profile.regionOfOrigin, GtsConstants.regionsOfOrigin));
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

    final status = profile.employmentStatus.trim().toLowerCase();
    if (status == GtsConstants.employed.toLowerCase()) {
      final q18Options =
          ChedGtsBuiltin.byId('ched_18')?.options ?? GtsConstants.employmentTypes;
      put('ched_18', _match(profile.employmentType, q18Options));
      put('ched_19', profile.employmentOccupation);
    } else if (status == GtsConstants.unemployed.toLowerCase() ||
        status == GtsConstants.neverEmployed.toLowerCase()) {
      if (profile.notEmployedReasons.isNotEmpty) {
        out['ched_17'] = List<String>.from(profile.notEmployedReasons);
      }
      put('ched_17_other', profile.notEmployedReasonOther);
    }

    if (employment != null) {
      final empValues = SurveyPrefillHelper.valuesFromEmployment(employment);
      put('ched_16', empValues['employment.presentlyEmployed']);
      put('ched_18', empValues['employment.employmentStatus']);
      put('ched_19', empValues['employment.position']);
      final industry = empValues['employment.industry']?.toString();
      if (industry != null && industry.trim().isNotEmpty) {
        final item = ChedGtsBuiltin.byId('ched_20');
        final matched = SurveyPrefillHelper.matchOption(
          industry,
          item?.options ?? const [],
        );
        if (matched != null) {
          put('ched_20', matched);
        } else {
          put('ched_20', ChedGtsBuiltin.othersSpecify);
          put('ched_20_other', industry.trim());
        }
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

  /// Merge submitted CHED answers into the live profile (Section A + B.12 + item 16-19).
  /// Program stays as the roster has it; the year only fills a blank profile.
  /// Q3 email and Q5 mobile are left out: a changed contact is saved only
  /// after verification (`ContactVerificationService.saveVerified`).
  static TracerProfile mergeIntoProfile({
    required TracerProfile current,
    required Map<String, dynamic> answers,
    bool allowNameChange = false,
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
        final uni = firstFilled['College or University']?.toString().trim();
        final year = firstFilled['Year Graduated']?.toString().trim();
        final award = firstFilled['Honor(s) or Award(s) Received']
            ?.toString()
            .trim();
        if (uni != null && uni.isNotEmpty) college = uni;
        if (yearGraduated.trim().isEmpty && year != null && year.isNotEmpty) {
          yearGraduated = year;
        }
        if (award != null) honors = award;
      }
    }

    final employment = GtsConstants.fromChedPresentlyEmployed(text('ched_16'));
    final newStatus = employment ?? current.employmentStatus;
    final isEmployed =
        newStatus.trim().toLowerCase() == GtsConstants.employed.toLowerCase();
    final isNotEmployed =
        newStatus.trim().toLowerCase() == GtsConstants.unemployed.toLowerCase() ||
        newStatus.trim().toLowerCase() == GtsConstants.neverEmployed.toLowerCase();

    final q18Answer = text('ched_18');
    final q19Answer = text('ched_19');

    final q17Raw = answers['ched_17'];
    final List<String> q17Reasons;
    if (q17Raw is List) {
      q17Reasons = q17Raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (q17Raw is String && q17Raw.trim().isNotEmpty) {
      q17Reasons = [q17Raw.trim()];
    } else {
      q17Reasons = const [];
    }
    final q17Other = text('ched_17_other');

    final nextEmploymentType = isEmployed
        ? (q18Answer ?? current.employmentType)
        : '';
    final nextOccupation = isEmployed
        ? (q19Answer ?? current.employmentOccupation)
        : '';
    final nextReasons = isNotEmployed
        ? (answers.containsKey('ched_17')
            ? q17Reasons
            : current.notEmployedReasons)
        : const <String>[];
    final nextReasonOther = isNotEmployed
        ? (answers.containsKey('ched_17_other')
            ? (q17Other ?? '')
            : current.notEmployedReasonOther)
        : '';

    return current.copyWith(
      // Name only follows ched_1 after the marriage opt-in; otherwise the
      // verified profile name wins even if a legacy draft edited ched_1.
      displayName: allowNameChange
          ? (text('ched_1') ?? current.displayName)
          : current.displayName,
      address: text('ched_2') ?? current.address,
      telephoneNumber: text('ched_4') ?? current.telephoneNumber,
      civilStatus: text('ched_6') ?? current.civilStatus,
      gender: text('ched_7') ?? current.gender,
      birthDate: birthday ?? current.birthDate,
      regionOfOrigin: text('ched_9') ?? current.regionOfOrigin,
      province: text('ched_10') ?? current.province,
      locationOfResidence: text('ched_11') ?? current.locationOfResidence,
      collegeUniversity: college,
      yearGraduated: yearGraduated,
      batchYear: yearGraduated,
      honorsAwards: honors,
      employmentStatus: newStatus,
      employmentType: nextEmploymentType,
      employmentOccupation: nextOccupation,
      notEmployedReasons: nextReasons,
      notEmployedReasonOther: nextReasonOther,
      employmentSource: 'ched_gts',
      employmentUpdatedAt: DateTime.now().toUtc(),
    ).normalizedEmployment();
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
