import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';

/// Controlled dictionary of every field a GTS report may use.
///
/// CHED entries are generated from [ChedGtsBuiltin], so wording, options and
/// numbering cannot drift from the form; only report metadata (short label,
/// who is asked, sensitivity, server column) is added here.
abstract final class GtsFieldDictionary {
  static const course = 'course';
  static const yearGraduated = 'year_graduated';
  static const wave = 'survey';

  static final List<GtsField> fields = List.unmodifiable([
    ..._cohortFields,
    for (final item in ChedGtsBuiltin.items) _fromItem(item),
  ]);

  static final Map<String, GtsField> _byKey = {
    for (final f in fields) f.key: f,
  };

  static GtsField? byKey(String key) => _byKey[key];

  static Iterable<GtsField> get chedFields =>
      fields.where((f) => f.source == GtsFieldSource.chedAnswer);

  static Iterable<GtsField> get groupable => fields.where((f) => f.groupable);

  static Iterable<GtsField> get filterable => fields.where((f) => f.filterable);

  /// Whether [key] was shown to a respondent with these [answers].
  /// Cohort fields apply to everyone.
  static bool isAskedFor(String key, Map<String, dynamic> answers) {
    final field = _byKey[key];
    if (field == null) return false;
    if (field.source != GtsFieldSource.chedAnswer) return true;
    if (!field.isConditional) return true;
    return ChedGtsVisibility.visibleItemIds(answers).contains(key);
  }

  static const _cohortFields = [
    GtsField(
      key: course,
      label: 'Course',
      valueClass: GtsValueClass.categorical,
      source: GtsFieldSource.roster,
      factColumn: 'course',
      factNote: '"Unknown" when the roster has no course.',
    ),
    GtsField(
      key: yearGraduated,
      label: 'Graduation year (batch)',
      valueClass: GtsValueClass.year,
      source: GtsFieldSource.roster,
      factColumn: 'year_graduated',
      factNote: '"Unknown" when the roster has no graduation year.',
    ),
    GtsField(
      key: wave,
      label: 'Tracer wave',
      valueClass: GtsValueClass.categorical,
      source: GtsFieldSource.wave,
      factColumn: 'survey_id',
    ),
  ];

  static GtsField _fromItem(ChedGtsItem item) {
    final meta = _meta[item.id];
    if (meta == null) {
      throw StateError('No report metadata for CHED item ${item.id}');
    }
    final parent = item.isOthersSpecify ? _parentOf(item.id) : null;
    return GtsField(
      key: item.id,
      label: parent == null
          ? meta.label
          : '${_meta[parent]!.label}: other (specified)',
      valueClass: meta.valueClass ?? _classOf(item.type),
      source: GtsFieldSource.chedAnswer,
      chedNumber: item.chedNumber,
      prompt: item.prompt,
      section: item.sectionTitle,
      options: item.options,
      gridRows: item.matrixRows,
      gridColumns: item.matrixColumns,
      tableColumns: item.tableColumns,
      required: item.required,
      askedOf: parent == null
          ? meta.askedOf
          : 'Item ${item.chedNumber} = Others',
      sensitivity: meta.sensitivity,
      factColumn: meta.factColumn,
      factNote: meta.factNote,
      othersOf: parent,
    );
  }

  static String? _parentOf(String othersId) {
    for (final item in ChedGtsBuiltin.items) {
      if (item.othersSpecifyId == othersId) return item.id;
    }
    final base = othersId.replaceFirst(RegExp(r'_other$'), '');
    return ChedGtsBuiltin.byId(base) == null ? null : base;
  }

  static GtsValueClass _classOf(ChedGtsFieldType type) => switch (type) {
    ChedGtsFieldType.single => GtsValueClass.categorical,
    ChedGtsFieldType.multi => GtsValueClass.multiSelect,
    ChedGtsFieldType.matrix => GtsValueClass.grid,
    ChedGtsFieldType.tableRows => GtsValueClass.table,
    ChedGtsFieldType.text ||
    ChedGtsFieldType.longText => GtsValueClass.freeText,
    ChedGtsFieldType.date => GtsValueClass.date,
  };

  static const _employed = 'Item 16 = Yes';

  static const Map<String, _Meta> _meta = {
    'ched_1': _Meta('Name', sensitivity: GtsSensitivity.personal),
    'ched_2': _Meta('Permanent address', sensitivity: GtsSensitivity.personal),
    'ched_3': _Meta('Email address', sensitivity: GtsSensitivity.personal),
    'ched_4': _Meta('Telephone number', sensitivity: GtsSensitivity.personal),
    'ched_5': _Meta('Mobile number', sensitivity: GtsSensitivity.personal),
    'ched_6': _Meta('Civil status', sensitivity: GtsSensitivity.demographic),
    'ched_7': _Meta('Sex', sensitivity: GtsSensitivity.demographic),
    'ched_8': _Meta('Birthday', sensitivity: GtsSensitivity.personal),
    'ched_9': _Meta('Region of origin'),
    'ched_10': _Meta('Province'),
    'ched_11': _Meta('Location of residence'),
    'ched_12': _Meta('Educational attainment'),
    'ched_13': _Meta('Professional exams passed'),
    'ched_14': _Meta('Reasons for taking the course'),
    'ched_14_other': _Meta(''),
    'ched_15a': _Meta('Trainings and advance studies'),
    'ched_15b': _Meta('Reason for advance studies'),
    'ched_15b_other': _Meta(''),
    'ched_16': _Meta('Presently employed', factColumn: 'presently_employed'),
    'ched_17': _Meta(
      'Reasons not employed',
      askedOf: 'Item 16 = No or Never Employed',
      factColumn: 'not_employed_reasons',
    ),
    'ched_17_other': _Meta(''),
    'ched_18': _Meta(
      'Present employment status',
      askedOf: _employed,
      factColumn: 'employment_type',
    ),
    'ched_18_skills': _Meta(
      'College skills used in self-employment',
      askedOf: 'Item 18 = Self-employed',
    ),
    'ched_19': _Meta(
      'Present occupation',
      askedOf: _employed,
      factColumn: 'occupation',
    ),
    'ched_20': _Meta(
      'Line of business',
      askedOf: _employed,
      factColumn: 'industry',
      factNote: 'Holds the specified text when "Others" was picked.',
    ),
    'ched_20_other': _Meta(''),
    'ched_21': _Meta(
      'Place of work',
      askedOf: _employed,
      factColumn: 'place_of_work',
    ),
    'ched_22': _Meta('First job after college', askedOf: _employed),
    'ched_23': _Meta(
      'Reasons for staying on the job',
      askedOf: 'Item 22 = Yes',
    ),
    'ched_23_other': _Meta(''),
    'ched_24a': _Meta(
      'First job related to course',
      askedOf: 'Item 22 = Yes',
      factColumn: 'first_job_related',
    ),
    'ched_24b': _Meta(
      'Reasons for accepting the job',
      askedOf: 'Item 24 = Yes',
    ),
    'ched_24b_other': _Meta(''),
    'ched_25': _Meta(
      'Reasons for changing job',
      askedOf: 'Item 22 = No, or item 24 = No',
    ),
    'ched_25_other': _Meta(''),
    'ched_27': _Meta(
      'Length of stay in first job',
      askedOf: _employed,
      valueClass: GtsValueClass.ordinal,
    ),
    'ched_27_other': _Meta(''),
    'ched_28': _Meta('How the first job was found', askedOf: _employed),
    'ched_28_other': _Meta(''),
    'ched_29': _Meta(
      'Time to land first job',
      askedOf: _employed,
      valueClass: GtsValueClass.ordinal,
      factColumn: 'time_to_first_job',
    ),
    'ched_29_other': _Meta(''),
    'ched_30': _Meta('Job level', askedOf: _employed),
    'ched_31': _Meta(
      'Initial gross monthly earning',
      askedOf: _employed,
      valueClass: GtsValueClass.ordinal,
      factColumn: 'initial_salary',
    ),
    'ched_32': _Meta(
      'Curriculum relevant to first job',
      askedOf: _employed,
      factColumn: 'curriculum_relevant',
    ),
    'ched_33': _Meta('Useful competencies', askedOf: 'Item 32 = Yes'),
    'ched_33_other': _Meta(''),
    'ched_34': _Meta('Curriculum suggestions'),
  };
}

class _Meta {
  const _Meta(
    this.label, {
    this.askedOf,
    this.valueClass,
    this.sensitivity = GtsSensitivity.none,
    this.factColumn,
    this.factNote,
  });

  /// Empty for "Others, please specify" items, which derive it from the parent.
  final String label;
  final String? askedOf;

  /// Overrides the class implied by the CHED field type.
  final GtsValueClass? valueClass;
  final GtsSensitivity sensitivity;
  final String? factColumn;
  final String? factNote;
}
