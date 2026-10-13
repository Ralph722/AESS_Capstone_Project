import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_stats.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
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
  });

  final String key;
  final String header;

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
  static const registrationColumn = 'registration';
  static const emailColumn = 'email';
  static const contactColumn = 'contact';
  static const waveColumn = 'wave';
  static const answeredOnColumn = 'answered_on';

  static const registered = 'Registered';
  static const notRegistered = 'Not registered';
  static const notOnRoster = 'Not on active roster';

  static final List<GtsListColumn> all = List.unmodifiable([
    ..._rosterColumns,
    for (final item in ChedGtsBuiltin.items)
      if (!item.isOthersSpecify) _answerColumn(item),
  ]);

  static final Map<String, GtsListColumn> _byKey = {
    for (final c in all) c.key: c,
  };

  static GtsListColumn? byKey(String key) => _byKey[key];

  /// Group names in display order.
  static final List<String> groups = List.unmodifiable({
    for (final c in all) c.group,
  });

  static List<GtsListColumn> inGroup(String group) => [
    for (final c in all)
      if (c.group == group) c,
  ];

  /// The columns to show, in [GtsListConfig.columns] order. Unknown keys are
  /// skipped; "Wave answered" is added when answers come from any wave.
  static List<GtsListColumn> resolve(GtsListConfig config) {
    final seen = <String>{};
    final out = [
      for (final key in config.columns)
        if (_byKey[key] case final c? when seen.add(key)) c,
    ];
    if (config.latestFromAnyWave && !seen.contains(waveColumn)) {
      out.add(_byKey[waveColumn]!);
    }
    return out;
  }

  /// Column keys in [config] that no longer exist.
  static List<String> unknownKeys(GtsListConfig config) => [
    for (final key in config.columns)
      if (!_byKey.containsKey(key)) key,
  ];

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
    final answers = row.response?.answers ?? const <String, dynamic>{};
    String fromAnswer(String id) => DssMetrics.single(answers[id]) ?? '';
    return switch (column.key) {
      GtsListConfig.batchColumn => row.batch,
      GtsListConfig.nameColumn => row.name,
      GtsListConfig.courseColumn => row.course,
      GtsListConfig.statusColumn => row.status.label,
      studentIdColumn => member?.studentId.trim() ?? '',
      registrationColumn =>
        member == null
            ? notOnRoster
            : member.isRegisteredUser
            ? registered
            : notRegistered,
      emailColumn =>
        member == null
            ? fromAnswer('ched_3')
            : _firstNonEmpty([member.registeredEmail, member.emailAddress]),
      contactColumn =>
        member == null
            ? _firstNonEmpty([fromAnswer('ched_5'), fromAnswer('ched_4')])
            : member.contactNumber.trim(),
      waveColumn =>
        row.response == null
            ? ''
            : waveLabels[row.response!.surveyId] ?? row.response!.surveyId,
      answeredOnColumn => switch (row.response?.submittedAt) {
        final at? => _date.format(at.toLocal()),
        null => '',
      },
      _ => '',
    };
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      final t = v?.trim() ?? '';
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  static String _answer(ChedGtsItem item, GtsListRow row) {
    final respondent = row.respondent;
    if (respondent == null) return '';
    final visible = GtsStats.visibleItems(respondent);
    if (!visible.contains(item.id)) return gtsNotAskedLabel;
    final answers = respondent.answers;
    final othersId = item.othersSpecifyId;
    final others = othersId != null && visible.contains(othersId)
        ? DssMetrics.single(answers[othersId])
        : null;
    return formatAnswer(item, answers[item.id], others: others);
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
        final values = value is List ? value : [value];
        return [
          for (final v in values)
            if (v.toString().trim().isNotEmpty) choice(v.toString()),
        ].join('; ');
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
        return choice(DssMetrics.single(value) ?? '');
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
      header: '${item.chedNumber}. ${field.label}',
      group: item.sectionTitle,
      description: item.prompt,
      personal: field.isPersonal,
      item: item,
    );
  }

  static const _rosterColumns = [
    GtsListColumn(
      key: GtsListConfig.batchColumn,
      header: 'Batch',
      group: alumniGroup,
      description: 'Graduation year on the roster.',
    ),
    GtsListColumn(
      key: GtsListConfig.nameColumn,
      header: 'Name',
      group: alumniGroup,
      description:
          'Full name on the roster (item 1 for graduates not on the '
          'roster).',
      personal: true,
    ),
    GtsListColumn(
      key: studentIdColumn,
      header: 'Student ID',
      group: alumniGroup,
      description: 'Student ID on the roster.',
      personal: true,
    ),
    GtsListColumn(
      key: GtsListConfig.courseColumn,
      header: 'Course',
      group: alumniGroup,
      description: 'Course on the roster.',
    ),
    GtsListColumn(
      key: registrationColumn,
      header: 'Registration',
      group: alumniGroup,
      description: 'Whether the graduate has a portal account.',
    ),
    GtsListColumn(
      key: emailColumn,
      header: 'Email',
      group: alumniGroup,
      description: 'Account or roster email (item 3 if not on the roster).',
      personal: true,
    ),
    GtsListColumn(
      key: contactColumn,
      header: 'Contact number',
      group: alumniGroup,
      description: 'Roster contact number (items 5 or 4 if not on the roster).',
      personal: true,
    ),
    GtsListColumn(
      key: GtsListConfig.statusColumn,
      header: 'Tracer status',
      group: alumniGroup,
      description:
          'Employed, not employed or never employed (item 16), or why the '
          'graduate is untracked.',
    ),
    GtsListColumn(
      key: waveColumn,
      header: 'Wave answered',
      group: alumniGroup,
      description: 'Tracer wave the answers come from.',
    ),
    GtsListColumn(
      key: answeredOnColumn,
      header: 'Date answered',
      group: alumniGroup,
      description: 'When the answers were submitted.',
    ),
  ];
}
