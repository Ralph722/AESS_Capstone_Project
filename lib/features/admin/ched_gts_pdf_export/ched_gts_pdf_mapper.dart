import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_field_catalog.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_option_maps.dart';

/// Result of mapping CHED survey answers → AcroForm field values.
class ChedGtsPdfMappedFields {
  const ChedGtsPdfMappedFields({
    required this.values,
    required this.notes,
  });

  /// PDF field name → value.
  ///
  /// - Text / choice: plain [String]
  /// - Radio: export name with leading slash, e.g. `/employed`
  /// - Checkbox on: `/Yes` (see [ChedGtsPdfFieldDef.checkboxOn])
  /// - Checkbox off / unset: omitted (fill engine leaves `/Off`)
  final Map<String, String> values;

  /// Non-fatal mapping observations (truncated rows, unmapped options, etc.).
  final List<String> notes;
}

/// Transforms `survey_responses.answers` (`ched_*` keys) into PDF field values.
///
/// Phase 0 contract only — does not load or write PDF bytes.
abstract final class ChedGtsPdfMapper {
  /// Maps a CHED GTS answers map into AcroForm values for template v3.0.0.
  static ChedGtsPdfMappedFields mapAnswers(Map<String, dynamic> answers) {
    final out = <String, String>{};
    final notes = <String>[];

    void putText(String field, dynamic raw) {
      final s = _asTrimmedString(raw);
      if (s == null) return;
      out[field] = s;
    }

    void putMapped(
      String field,
      dynamic raw,
      Map<String, String> labelToExport, {
      String? answerKey,
    }) {
      final label = _asTrimmedString(raw);
      if (label == null) return;
      final export = labelToExport[label];
      if (export == null) {
        notes.add(
          'No PDF export for ${answerKey ?? field} value "$label"',
        );
        return;
      }
      out[field] = export;
    }

    void putMultiCheckboxes(
      dynamic raw,
      Map<String, String> optionToField,
    ) {
      final selected = _asStringList(raw);
      for (final label in selected) {
        final field = optionToField[label];
        if (field == null) {
          if (!_isOthersLabel(label)) {
            notes.add('No PDF checkbox for multi option "$label"');
          }
          continue;
        }
        out[field] = ChedGtsPdfFieldCatalog.byName[field]?.checkboxOn ?? '/Yes';
      }
    }

    // —— A ——
    putText('fullName', answers['ched_1']);
    putText('permanentAddress', answers['ched_2']);
    putText('email', answers['ched_3']);
    putText('contactNumber', answers['ched_4']);
    putText('mobileNumber', answers['ched_5']);
    putMapped(
      'civilStatus',
      answers['ched_6'],
      kChedGtsPdfCivilStatus,
      answerKey: 'ched_6',
    );
    putMapped('sex', answers['ched_7'], kChedGtsPdfSex, answerKey: 'ched_7');
    _putBirthParts(answers['ched_8'], out, notes);
    putMapped(
      'region',
      answers['ched_9'],
      kChedGtsPdfRegion,
      answerKey: 'ched_9',
    );
    putText('province', answers['ched_10']);
    putMapped(
      'residenceType',
      answers['ched_11'],
      kChedGtsPdfResidenceType,
      answerKey: 'ched_11',
    );

    // —— B tables / matrix ——
    _putEducationRow(answers['ched_12'], out, notes);
    _putExamRows(answers['ched_13'], out, notes);
    _putCourseReasons(answers['ched_14'], out, notes);

    // —— C ——
    _putTrainingRows(answers['ched_15a'], out, notes);
    putMapped(
      'advancedStudyReason',
      answers['ched_15b'],
      kChedGtsPdfAdvancedStudyReason,
      answerKey: 'ched_15b',
    );

    // —— D ——
    putMapped(
      'employmentStatus',
      answers['ched_16'],
      kChedGtsPdfEmploymentStatus,
      answerKey: 'ched_16',
    );
    putMultiCheckboxes(answers['ched_17'], kChedGtsPdfUnemployedReasonField);
    putText('unemployedReasonsOther', answers['ched_17_other']);
    putMapped(
      'presentEmploymentType',
      answers['ched_18'],
      kChedGtsPdfPresentEmploymentType,
      answerKey: 'ched_18',
    );
    putText('selfEmployedSkills', answers['ched_18_skills']);
    putText('occupation', answers['ched_19']);
    putMapped(
      'businessLine',
      answers['ched_20'],
      kChedGtsPdfBusinessLine,
      answerKey: 'ched_20',
    );
    putMapped(
      'placeOfWork',
      answers['ched_21'],
      kChedGtsPdfPlaceOfWork,
      answerKey: 'ched_21',
    );
    putMapped(
      'isFirstJob',
      answers['ched_22'],
      kChedGtsPdfYesNo,
      answerKey: 'ched_22',
    );
    putMultiCheckboxes(answers['ched_23'], kChedGtsPdfStayingReasonField);
    putText('stayingReasonsOther', answers['ched_23_other']);
    putMapped(
      'firstJobRelated',
      answers['ched_24a'],
      kChedGtsPdfYesNo,
      answerKey: 'ched_24a',
    );
    putMultiCheckboxes(answers['ched_24b'], kChedGtsPdfAcceptingReasonField);
    putText('acceptingReasonsOther', answers['ched_24b_other']);
    putMultiCheckboxes(answers['ched_25'], kChedGtsPdfChangingReasonField);
    putText('changingReasonsOther', answers['ched_25_other']);
    putMapped(
      'firstJobDuration',
      answers['ched_27'],
      kChedGtsPdfDuration,
      answerKey: 'ched_27',
    );
    putText('firstJobDurationOther', answers['ched_27_other']);
    putMapped(
      'howFoundFirstJob',
      answers['ched_28'],
      kChedGtsPdfHowFoundFirstJob,
      answerKey: 'ched_28',
    );
    putText('howFoundFirstJobOther', answers['ched_28_other']);
    putMapped(
      'timeToLandFirstJob',
      answers['ched_29'],
      kChedGtsPdfDuration,
      answerKey: 'ched_29',
    );
    putText('timeToLandFirstJobOther', answers['ched_29_other']);
    _putJobLevels(answers['ched_30'], out, notes);
    putMapped(
      'initialSalary',
      answers['ched_31'],
      kChedGtsPdfInitialSalary,
      answerKey: 'ched_31',
    );
    putMapped(
      'curriculumRelevant',
      answers['ched_32'],
      kChedGtsPdfYesNo,
      answerKey: 'ched_32',
    );
    putMultiCheckboxes(answers['ched_33'], kChedGtsPdfUsefulCompetencyField);
    putText('usefulCompetenciesOther', answers['ched_33_other']);
    putText('curriculumSuggestions', answers['ched_34']);

    // C others
    putText('advancedStudyOther', answers['ched_15b_other']);
    putText('courseReasonsOther', answers['ched_14_other']);

    return ChedGtsPdfMappedFields(values: out, notes: notes);
  }

  /// Every catalog PDF field is either produced by [mapAnswers] for some
  /// known path, or listed in [kChedGtsPdfTemplateOnlyFields].
  static final Set<String> coveredPdfFields = {
    ...ChedGtsPdfFieldCatalog.allNames,
  };

  static void _putBirthParts(
    dynamic raw,
    Map<String, String> out,
    List<String> notes,
  ) {
    final s = _asTrimmedString(raw);
    if (s == null) return;
    // Prefer ISO yyyy-MM-dd; also accept DateTime.toString() prefixes.
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (iso != null) {
      out['birthYear'] = iso.group(1)!;
      out['birthMonth'] = iso.group(2)!;
      out['birthDay'] = iso.group(3)!;
      return;
    }
    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
    if (slash != null) {
      out['birthMonth'] = slash.group(1)!.padLeft(2, '0');
      out['birthDay'] = slash.group(2)!.padLeft(2, '0');
      out['birthYear'] = slash.group(3)!;
      return;
    }
    notes.add('Unrecognized birthday format "$s"; birth fields left blank');
  }

  static void _putEducationRow(
    dynamic raw,
    Map<String, String> out,
    List<String> notes,
  ) {
    final rows = _asRowList(raw);
    if (rows.isEmpty) return;
    if (rows.length > 3) {
      notes.add(
        'ched_12 has ${rows.length} rows; PDF only has 3 education rows '
        '(extra rows omitted)',
      );
    }
    const suffixes = ['', '2', '3'];
    for (var i = 0; i < rows.length && i < 3; i++) {
      final row = rows[i];
      final s = suffixes[i];
      _putCell(out, 'degree$s', row[kChedGtsPdfEduDegreeCol]);
      _putCell(out, 'collegeUniversity$s', row[kChedGtsPdfEduCollegeCol]);
      _putCell(out, 'yearGraduated$s', row[kChedGtsPdfEduYearCol]);
      _putCell(out, 'honors$s', row[kChedGtsPdfEduHonorsCol]);
    }
  }

  static void _putExamRows(
    dynamic raw,
    Map<String, String> out,
    List<String> notes,
  ) {
    final rows = _asRowList(raw);
    if (rows.length > 3) {
      notes.add(
        'ched_13 has ${rows.length} rows; PDF only has 3 board-exam rows '
        '(extra rows omitted)',
      );
    }
    for (var i = 0; i < rows.length && i < 3; i++) {
      final n = i + 1;
      final row = rows[i];
      _putCell(out, 'boardExam${n}_examName', row[kChedGtsPdfExamNameCol]);
      _putCell(out, 'boardExam${n}_dateTaken', row[kChedGtsPdfExamDateCol]);
      _putCell(out, 'boardExam${n}_rating', row[kChedGtsPdfExamRatingCol]);
    }
  }

  static void _putTrainingRows(
    dynamic raw,
    Map<String, String> out,
    List<String> notes,
  ) {
    final rows = _asRowList(raw);
    if (rows.length > 3) {
      notes.add(
        'ched_15a has ${rows.length} rows; PDF only has 3 training rows '
        '(extra rows omitted)',
      );
    }
    for (var i = 0; i < rows.length && i < 3; i++) {
      final n = i + 1;
      final row = rows[i];
      _putCell(out, 'training${n}_title', row[kChedGtsPdfTrainingTitleCol]);
      _putCell(
        out,
        'training${n}_duration',
        row[kChedGtsPdfTrainingDurationCol],
      );
      _putCell(
        out,
        'training${n}_institution',
        row[kChedGtsPdfTrainingInstitutionCol],
      );
    }
  }

  static void _putCourseReasons(
    dynamic raw,
    Map<String, String> out,
    List<String> notes,
  ) {
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      final rowLabel = entry.key.toString();
      final cols = entry.value is Map
          ? Map<String, dynamic>.from(entry.value as Map)
          : const <String, dynamic>{};
      final ugField = kChedGtsPdfCourseReasonField[rowLabel];
      final gradField = kChedGtsPdfCourseReasonGradField[rowLabel];
      final ug = cols[kChedGtsPdfCourseReasonUgColumn] == true;
      final grad = cols[kChedGtsPdfCourseReasonGradColumn] == true;
      if (ug && ugField != null) {
        out[ugField] =
            ChedGtsPdfFieldCatalog.byName[ugField]?.checkboxOn ?? '/Yes';
      } else if (ug && ugField == null && !_isOthersLabel(rowLabel)) {
        notes.add('No PDF courseReasons field for row "$rowLabel"');
      }
      if (grad && gradField != null) {
        out[gradField] =
            ChedGtsPdfFieldCatalog.byName[gradField]?.checkboxOn ?? '/Yes';
      } else if (grad && gradField == null && !_isOthersLabel(rowLabel)) {
        notes.add('No PDF courseReasonsGrad field for row "$rowLabel"');
      }
    }
  }

  static void _putJobLevels(
    dynamic raw,
    Map<String, String> out,
    List<String> notes,
  ) {
    if (raw is! Map) return;
    String? first;
    String? current;
    for (final entry in raw.entries) {
      final levelLabel = entry.key.toString();
      final export = kChedGtsPdfJobLevel[levelLabel];
      if (export == null) continue;
      final cols = entry.value is Map
          ? Map<String, dynamic>.from(entry.value as Map)
          : const <String, dynamic>{};
      if (cols[kChedGtsPdfJobLevelFirstColumn] == true) {
        if (first != null) {
          notes.add('ched_30 multiple First Job levels; using last');
        }
        first = export;
      }
      if (cols[kChedGtsPdfJobLevelCurrentColumn] == true) {
        if (current != null) {
          notes.add('ched_30 multiple Current Job levels; using last');
        }
        current = export;
      }
    }
    if (first != null) out['firstJobLevel'] = first;
    if (current != null) out['currentJobLevel'] = current;
  }

  static void _putCell(
    Map<String, String> out,
    String field,
    dynamic raw,
  ) {
    final s = _asTrimmedString(raw);
    if (s == null) return;
    out[field] = s;
  }

  static String? _asTrimmedString(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<String> _asStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> _asRowList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  static bool _isOthersLabel(String label) {
    final lower = label.toLowerCase();
    return lower.contains('other') && lower.contains('specify');
  }
}
