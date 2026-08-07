import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

/// Paper-accurate visibility for the built-in CHED GTS form.
abstract final class ChedGtsVisibility {
  /// Returns item ids that should be shown for the current [answers].
  static Set<String> visibleItemIds(Map<String, dynamic> answers) {
    final visible = <String>{};

    void addCoreThrough16() {
      for (final item in ChedGtsBuiltin.items) {
        if (item.isOthersSpecify) continue;
        if (item.section == ChedGtsSection.a ||
            item.section == ChedGtsSection.b ||
            item.section == ChedGtsSection.c ||
            item.id == 'ched_16' ||
            item.id == 'ched_34') {
          visible.add(item.id);
        }
      }
    }

    addCoreThrough16();

    final employed = _str(answers['ched_16']);
    final isYes = employed == ChedGtsBuiltin.yes;
    final isNoOrNever = employed == ChedGtsBuiltin.no ||
        employed == ChedGtsBuiltin.neverEmployed;

    if (isNoOrNever) {
      visible.add('ched_17');
      _maybeOthers(
        visible,
        answers,
        parentId: 'ched_17',
        othersId: 'ched_17_other',
        triggerOptions: const ['Other reason(s), please specify'],
      );
    }

    if (isYes) {
      visible.addAll([
        'ched_18',
        'ched_19',
        'ched_20',
        'ched_21',
        'ched_22',
        'ched_27',
        'ched_28',
        'ched_29',
        'ched_30',
        'ched_31',
        'ched_32',
      ]);

      if (_str(answers['ched_18']) == ChedGtsBuiltin.selfEmployed) {
        visible.add('ched_18_skills');
      }

      final firstJob = _str(answers['ched_22']);
      if (firstJob == ChedGtsBuiltin.yes) {
        visible.add('ched_23');
        visible.add('ched_24a');
        _maybeOthers(
          visible,
          answers,
          parentId: 'ched_23',
          othersId: 'ched_23_other',
          triggerOptions: const ['Other reason(s), please specify'],
        );

        final related = _str(answers['ched_24a']);
        if (related == ChedGtsBuiltin.yes) {
          visible.add('ched_24b');
          _maybeOthers(
            visible,
            answers,
            parentId: 'ched_24b',
            othersId: 'ched_24b_other',
            triggerOptions: const ['Other reason(s), please specify'],
          );
        }
        // If related == No → skip 24b (paper: proceed toward 26/27).
      } else if (firstJob == ChedGtsBuiltin.no) {
        visible.add('ched_25');
        _maybeOthers(
          visible,
          answers,
          parentId: 'ched_25',
          othersId: 'ched_25_other',
          triggerOptions: const ['Other reason(s), please specify'],
        );
      }

      _maybeOthers(
        visible,
        answers,
        parentId: 'ched_27',
        othersId: 'ched_27_other',
        triggerOptions: const ['Others, please specify'],
        single: true,
      );
      _maybeOthers(
        visible,
        answers,
        parentId: 'ched_28',
        othersId: 'ched_28_other',
        triggerOptions: const ['Others, please specify'],
        single: true,
      );
      _maybeOthers(
        visible,
        answers,
        parentId: 'ched_29',
        othersId: 'ched_29_other',
        triggerOptions: const ['Others, please specify'],
        single: true,
      );

      if (_str(answers['ched_32']) == ChedGtsBuiltin.yes) {
        visible.add('ched_33');
        _maybeOthers(
          visible,
          answers,
          parentId: 'ched_33',
          othersId: 'ched_33_other',
          triggerOptions: const ['Other skills, please specify'],
        );
      }
    }

    // Section B/C others-specify
    _maybeMatrixOthers(
      visible,
      answers,
      matrixId: 'ched_14',
      othersId: 'ched_14_other',
      rowLabel: 'Others, please specify',
    );
    _maybeOthers(
      visible,
      answers,
      parentId: 'ched_15b',
      othersId: 'ched_15b_other',
      triggerOptions: const ['Others, please specify'],
      single: true,
    );

    return visible;
  }

  /// Drops answers for items that are not currently visible.
  static Map<String, dynamic> pruneHiddenAnswers(
    Map<String, dynamic> answers,
  ) {
    final visible = visibleItemIds(answers);
    return Map.fromEntries(
      answers.entries.where((e) => visible.contains(e.key)),
    );
  }

  /// Returns missing required item ids among currently visible items.
  static List<String> missingRequired(Map<String, dynamic> answers) {
    final visible = visibleItemIds(answers);
    final missing = <String>[];
    for (final item in ChedGtsBuiltin.items) {
      if (!visible.contains(item.id)) continue;
      if (!item.required) continue;
      if (!_hasAnswer(item, answers[item.id])) {
        missing.add(item.id);
      }
    }
    return missing;
  }

  /// Required gaps for a single section (wizard step validation).
  static List<String> missingRequiredInSection(
    Map<String, dynamic> answers,
    ChedGtsSection section,
  ) {
    return missingRequired(answers).where((id) {
      final item = ChedGtsBuiltin.byId(id);
      return item?.section == section;
    }).toList();
  }

  static bool _hasAnswer(ChedGtsItem item, dynamic value) {
    if (value == null) return false;
    switch (item.type) {
      case ChedGtsFieldType.multi:
        return value is List && value.isNotEmpty;
      case ChedGtsFieldType.matrix:
        if (value is! Map) return false;
        // At least one cell checked.
        for (final v in value.values) {
          if (v is Map && v.values.any((c) => c == true)) return true;
          if (v == true) return true;
        }
        return false;
      case ChedGtsFieldType.tableRows:
        if (value is! List || value.isEmpty) return false;
        for (final row in value) {
          if (row is Map) {
            final filled = row.values.any(
              (c) => c != null && c.toString().trim().isNotEmpty,
            );
            if (filled) return true;
          }
        }
        return false;
      case ChedGtsFieldType.text:
      case ChedGtsFieldType.longText:
      case ChedGtsFieldType.single:
      case ChedGtsFieldType.date:
        return value.toString().trim().isNotEmpty;
    }
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<String> _list(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static void _maybeOthers(
    Set<String> visible,
    Map<String, dynamic> answers, {
    required String parentId,
    required String othersId,
    required List<String> triggerOptions,
    bool single = false,
  }) {
    if (!visible.contains(parentId)) return;
    final triggers = triggerOptions.map((e) => e.toLowerCase()).toSet();
    if (single) {
      final v = _str(answers[parentId])?.toLowerCase();
      if (v != null && triggers.contains(v)) visible.add(othersId);
    } else {
      final selected = _list(answers[parentId])
          .map((e) => e.toLowerCase())
          .toSet();
      if (selected.any(triggers.contains)) visible.add(othersId);
    }
  }

  static void _maybeMatrixOthers(
    Set<String> visible,
    Map<String, dynamic> answers, {
    required String matrixId,
    required String othersId,
    required String rowLabel,
  }) {
    if (!visible.contains(matrixId)) return;
    final raw = answers[matrixId];
    if (raw is! Map) return;
    final row = raw[rowLabel];
    if (row is Map && row.values.any((c) => c == true)) {
      visible.add(othersId);
    }
  }
}
