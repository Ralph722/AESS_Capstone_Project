import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_stats.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_prefill.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

/// A column an alumni list can show.
class GtsListColumn {
  const GtsListColumn({
    required this.key,
    required this.header,
    required this.group,
    required this.description,
    this.personal = false,
    this.item,
    this.searchText = '',
  });

  final String key;
  final String header;

  /// Extra words the column picker matches, such as a CHED item number.
  final String searchText;

  /// "Alumni information" or the CHED section title.
  final String group;

  /// Full question wording (CHED items) or where the value comes from.
  final String description;

  /// Identifies or contacts a graduate.
  final bool personal;

  /// The CHED item answered in this column; null for roster columns.
  final ChedGtsItem? item;

  bool get isAnswer => item != null;
}

/// Every column of an alumni list: roster details first, then each CHED
/// GTS item in form order. "Others, please specify" boxes are merged into
/// their question's column.
abstract final class GtsListColumns {
  static const alumniGroup = 'Alumni information';

  static const studentIdColumn = 'student_id';
  static const answeredOnColumn = 'answered_on';

  static const answeredLabel = 'Answered';

  static final List<GtsListColumn> all = List.unmodifiable([
    ..._rosterColumns,
    for (final item in ChedGtsBuiltin.items)
      if (!item.isOthersSpecify) _answerColumn(item),
  ]);

  /// Columns the admin can pick. Section A Name is the alumni Name column.
  static final List<GtsListColumn> pickable = List.unmodifiable([
    for (final c in all)
      if (c.key != GtsListConfig.sectionANameColumn) c,
  ]);

  static final Map<String, GtsListColumn> _byKey = {
    for (final c in all) c.key: c,
  };

  static GtsListColumn? byKey(String key) => _byKey[canonicalKey(key)];

  /// Group names in display order.
  static final List<String> groups = List.unmodifiable({
    for (final c in pickable) c.group,
  });

  static List<GtsListColumn> inGroup(String group) => [
    for (final c in pickable)
      if (c.group == group) c,
  ];

  /// Lookup key for a stored column id. Does not fold section A Name into
  /// the alumni Name column so [byKey] can still read item 1 answers.
  static String canonicalKey(String key) =>
      key == GtsListConfig.legacyNameColumn ? GtsListConfig.nameColumn : key;

  /// The columns to show, in [GtsListConfig.columns] order. Unknown keys are
  /// skipped. Saved `name` and section A `ched_1` become the Name column.
  static List<GtsListColumn> resolve(GtsListConfig config) {
    final seen = <String>{};
    final out = <GtsListColumn>[];
    for (final key in GtsListConfig.migrateColumns(config.columns)) {
      if (_byKey[key] case final c? when seen.add(key)) {
        out.add(c);
      }
    }
    return out;
  }

  /// Columns for the table, preview, and export (same as [resolve]).
  static List<GtsListColumn> displayColumns(GtsListConfig config) =>
      resolve(config);

  /// The column a sort uses.
  static GtsListColumn? sortColumn(GtsListConfig config) {
    final key = config.sortBy;
    if (key == null) return null;
    final canonical = GtsListConfig.migrateSort(key) ?? key;
    for (final c in displayColumns(config)) {
      if (c.key == canonical) return c;
    }
    return byKey(canonical);
  }

  /// Column keys in [config] that no longer exist.
  static List<String> unknownKeys(GtsListConfig config) {
    final out = <String>[];
    for (final key in config.columns) {
      final migrated = GtsListConfig.migrateColumns([key]);
      if (migrated.isEmpty || !_byKey.containsKey(migrated.first)) {
        out.add(key);
      }
    }
    return out;
  }

  static final _date = DateFormat('yyyy-MM-dd');

  /// The text shown in [column] for [row]. Answer columns: "Not asked"
  /// when the form never showed the item to this graduate, blank when it
  /// was left empty or the graduate has not answered.
  static String cell(
    GtsListColumn column,
    GtsListRow row, {
    Map<String, String> waveLabels = const {},
  }) {
    final item = column.item;
    if (item != null) return _answer(item, row);
    final member = row.member;
    return switch (column.key) {
      GtsListConfig.batchColumn => row.batch,
      GtsListConfig.nameColumn => _nameCell(row),
      GtsListConfig.courseColumn => row.course,
      GtsListConfig.statusColumn => row.status.columnLabel,
      studentIdColumn => member?.studentId.trim() ?? '',
      answeredOnColumn => switch (row.response?.submittedAt) {
        final at? => _date.format(at.toLocal()),
        null => '',
      },
      _ => '',
    };
  }

  /// Best available name for the Name column.
  ///
  /// Answered: submitted tracer name, else roster. Registered and not yet
  /// answered: profile name, else roster. Not registered: name on the alumni list.
  static String _nameCell(GtsListRow row) {
    final item = ChedGtsBuiltin.byId(GtsListConfig.sectionANameColumn);
    if (row.response != null) {
      if (item != null) {
        final answered = _answer(item, row);
        if (answered.isNotEmpty && answered != gtsNotAskedLabel) {
          return answered;
        }
      }
      return row.name;
    }
    if (item != null && (row.member?.isRegisteredUser ?? false)) {
      final fromProfile = _answer(item, row);
      if (fromProfile.isNotEmpty) return fromProfile;
    }
    return row.name;
  }

  /// Section A values for a registered alumnus who has not submitted.
  /// [rosterName] fills item 1 when the profile has no display name.
  /// Items in sections B, C, and D are never copied from the profile.
  static Map<String, dynamic> sectionAFromProfile(
    TracerProfile profile, {
    String rosterName = '',
  }) {
    final filled = ChedGtsPrefill.fromProfile(profile);
    final out = <String, dynamic>{};
    for (final item in ChedGtsBuiltin.items) {
      if (item.section != ChedGtsSection.a || item.isOthersSpecify) continue;
      final value = filled[item.id];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      out[item.id] = value;
    }
    if (_blank(out['ched_1']) && rosterName.trim().isNotEmpty) {
      out['ched_1'] = rosterName.trim();
    }
    return out;
  }

  /// Item 1 only, used when a registered alumnus has no profile row yet.
  static Map<String, dynamic> sectionANameOnly(String rosterName) {
    final name = rosterName.trim();
    return name.isEmpty ? const {} : {'ched_1': name};
  }

  static bool _blank(Object? value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return false;
  }

  static String _answer(ChedGtsItem item, GtsListRow row) {
    final respondent = row.respondent;
    if (respondent != null) {
      final visible = GtsStats.visibleItems(respondent);
      if (!visible.contains(item.id)) return gtsNotAskedLabel;
      final answers = respondent.answers;
      final othersId = item.othersSpecifyId;
      final others = othersId != null && visible.contains(othersId)
          ? DssMetrics.single(answers[othersId])
          : null;
      return formatAnswer(item, answers[item.id], others: others);
    }
    // Registered alumni who have not submitted still have section A on
    // their profile. Sections B–D stay blank, as do people who never
    // registered.
    if (item.section != ChedGtsSection.a) return '';
    final member = row.member;
    if (member == null || !member.isRegisteredUser || row.response != null) {
      return '';
    }
    if (!row.sectionA.containsKey(item.id)) return '';
    return formatAnswer(item, row.sectionA[item.id]);
  }

  /// Category labels for a percentage tally.
  ///
  /// Null when [column] is not a counted question for [row]: free text,
  /// a question the form did not show, or section B–D for someone who has
  /// not submitted. An empty list means the question was shown and left
  /// blank. Only alumni on the alumni list are counted by the tally;
  /// this method still returns labels for an off-roster row so the cell
  /// and the tally use one reading of the answer.
  static List<String>? tallyCategories(GtsListColumn column, GtsListRow row) {
    final item = column.item;
    if (item == null) return null;
    if (item.type != ChedGtsFieldType.single &&
        item.type != ChedGtsFieldType.multi) {
      return null;
    }
    final respondent = row.respondent;
    if (respondent != null) {
      final visible = GtsStats.visibleItems(respondent);
      if (!visible.contains(item.id)) return null;
      final othersId = item.othersSpecifyId;
      final others = othersId != null && visible.contains(othersId)
          ? DssMetrics.single(respondent.answers[othersId])
          : null;
      return choiceLabels(item, respondent.answers[item.id], others: others);
    }
    if (item.section != ChedGtsSection.a) return null;
    final member = row.member;
    if (member == null || !member.isRegisteredUser) return null;
    return choiceLabels(item, row.sectionA[item.id]);
  }

  /// One label per selected choice. "Others, please specify" becomes
  /// "Others: …" when the specify box has text, matching [formatAnswer].
  static List<String> choiceLabels(
    ChedGtsItem item,
    Object? value, {
    String? others,
  }) {
    String choice(String v) {
      final t = v.trim();
      if (t.isEmpty) return '';
      return others != null && _isOthersChoice(t) ? 'Others: $others' : t;
    }

    if (value == null) return const [];
    if (item.type == ChedGtsFieldType.multi) {
      final values = value is List ? value : [value];
      return [
        for (final v in values)
          if (choice(v.toString()) case final label when label.isNotEmpty)
            label,
      ];
    }
    if (item.type == ChedGtsFieldType.single) {
      final label = choice(DssMetrics.single(value) ?? '');
      return label.isEmpty ? const [] : [label];
    }
    return const [];
  }

  static final _othersChoices = {
    ChedGtsBuiltin.othersSpecify.toLowerCase(),
    ChedGtsBuiltin.otherReasonsSpecify.toLowerCase(),
    ChedGtsBuiltin.otherSkillsSpecify.toLowerCase(),
  };

  static bool _isOthersChoice(String value) =>
      _othersChoices.contains(value.trim().toLowerCase());

  /// One-line text for a stored answer to [item]. [others] is the
  /// "please specify" text; it replaces the "Other…" choice.
  static String formatAnswer(
    ChedGtsItem item,
    Object? value, {
    String? others,
  }) {
    String choice(String v) {
      final t = v.trim();
      return others != null && _isOthersChoice(t) ? 'Others: $others' : t;
    }

    if (value == null) return '';
    switch (item.type) {
      case ChedGtsFieldType.multi:
        return choiceLabels(item, value, others: others).join('; ');
      case ChedGtsFieldType.matrix:
        if (value is! Map) return value.toString().trim();
        final parts = <String>[];
        final rows = [
          ...item.matrixRows,
          for (final k in value.keys)
            if (!item.matrixRows.contains(k.toString())) k.toString(),
        ];
        for (final rowLabel in rows) {
          final cols = value[rowLabel];
          final label = choice(rowLabel);
          if (cols == true) {
            parts.add(label);
          } else if (cols is Map) {
            final checked = [
              for (final c in [
                ...item.matrixColumns,
                for (final k in cols.keys)
                  if (!item.matrixColumns.contains(k.toString())) k.toString(),
              ])
                if (cols[c] == true) c,
            ];
            if (checked.isNotEmpty) parts.add('$label (${checked.join(', ')})');
          }
        }
        return parts.join('; ');
      case ChedGtsFieldType.tableRows:
        if (value is! List) return value.toString().trim();
        return [
          for (final r in value.whereType<Map>())
            [
              for (final c in [
                ...item.tableColumns,
                for (final k in r.keys)
                  if (!item.tableColumns.contains(k.toString())) k.toString(),
              ])
                if ((r[c]?.toString().trim() ?? '').isNotEmpty)
                  r[c].toString().trim(),
            ].join(' | '),
        ].where((s) => s.isNotEmpty).join('; ');
      case ChedGtsFieldType.single:
        return choiceLabels(item, value, others: others).join('; ');
      case ChedGtsFieldType.text:
      case ChedGtsFieldType.longText:
      case ChedGtsFieldType.date:
        return (DssMetrics.single(value) ?? '').replaceAll(
          RegExp(r'\s*\n\s*'),
          ' ',
        );
    }
  }

  static GtsListColumn _answerColumn(ChedGtsItem item) {
    final field = GtsFieldDictionary.byKey(item.id)!;
    return GtsListColumn(
      key: item.id,
      header: field.label,
      group: item.sectionTitle,
      description: item.prompt,
      personal: field.isPersonal,
      item: item,
      searchText: item.chedNumber,
    );
  }

  static const _rosterColumns = [
    GtsListColumn(
      key: GtsListConfig.nameColumn,
      header: 'Name',
      group: alumniGroup,
      description:
          'Best available name for each alumnus: the name on the tracer '
          'when they have answered, otherwise the profile or name on the alumni list.',
      personal: true,
    ),
    GtsListColumn(
      key: GtsListConfig.batchColumn,
      header: 'Batch',
      group: alumniGroup,
      description: 'Graduation year on the alumni list.',
    ),
    GtsListColumn(
      key: GtsListConfig.courseColumn,
      header: 'Course',
      group: alumniGroup,
      description: 'Course on the alumni list.',
    ),
    GtsListColumn(
      key: studentIdColumn,
      header: 'Student ID',
      group: alumniGroup,
      description: 'Student ID on the alumni list.',
      personal: true,
    ),
    GtsListColumn(
      key: answeredOnColumn,
      header: 'Date answered',
      group: alumniGroup,
      description: 'When the tracer was submitted.',
    ),
    GtsListColumn(
      key: GtsListConfig.statusColumn,
      header: 'Tracer status',
      group: alumniGroup,
      description:
          'Answered, once the tracer is submitted, or why the alumnus '
          'is still untracked. Employment is item 16, not this column.',
    ),
  ];
}
