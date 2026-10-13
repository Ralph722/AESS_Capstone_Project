/// What a reportable field holds. Drives which calculations, groupings and
/// filters are meaningful.
enum GtsValueClass {
  /// One unordered choice per respondent.
  categorical,

  /// One choice per respondent from ordered brackets (durations, earnings).
  ordinal,

  /// Several choices per respondent; shares can total over 100%.
  multiSelect,

  /// Checkbox grid (rows x columns).
  grid,

  /// Repeating rows of free text.
  table,

  /// Short or long open answer.
  freeText,

  date,

  /// Graduation year (batch).
  year,
}

/// Where a field's value comes from.
enum GtsFieldSource {
  /// A CHED GTS answer in `survey_responses.answers`.
  chedAnswer,

  /// The alumni roster (`alumni_members`).
  roster,

  /// The survey wave the response belongs to.
  wave,
}

enum GtsSensitivity {
  none,

  /// Aggregate only, with small groups suppressed.
  demographic,

  /// Directly identifies a person: person-level listings only, never
  /// grouped, filtered or sent to AI.
  personal,
}

enum GtsCalculation {
  /// Respondents per value (multi-select: per option picked).
  count,

  /// Count / respondents who answered the item.
  shareOfAnswered,

  /// Count / respondents the item was asked of (skip logic applied).
  shareOfEligible,

  /// Count / every respondent in scope.
  shareOfAllRespondents,

  /// Middle bracket of an ordinal field, "Others" excluded.
  medianBracket,

  /// Respondents with any answer (open text, tables, grids).
  answeredCount,
}

/// One entry of the controlled GTS field dictionary.
class GtsField {
  const GtsField({
    required this.key,
    required this.label,
    required this.valueClass,
    required this.source,
    this.chedNumber,
    this.prompt,
    this.section,
    this.options = const [],
    this.gridRows = const [],
    this.gridColumns = const [],
    this.tableColumns = const [],
    this.required = false,
    this.askedOf,
    this.sensitivity = GtsSensitivity.none,
    this.factColumn,
    this.factNote,
    this.othersOf,
  });

  /// Stable key: the CHED answer id (`ched_24a`) or a cohort key (`course`).
  final String key;

  /// Short report label, e.g. "First job related to course".
  final String label;

  final GtsValueClass valueClass;
  final GtsFieldSource source;

  /// Printed questionnaire number ("24" for `ched_24a`).
  final String? chedNumber;

  /// Official question wording.
  final String? prompt;

  /// Questionnaire section title.
  final String? section;

  /// Allowed values in questionnaire order (ordinal: bracket order).
  final List<String> options;

  final List<String> gridRows;
  final List<String> gridColumns;
  final List<String> tableColumns;
  final bool required;

  /// Who the item is shown to, when not everyone (e.g. "Item 22 = Yes").
  final String? askedOf;

  final GtsSensitivity sensitivity;

  /// Column in `gts_respondent_facts`, when the server already exposes it.
  final String? factColumn;

  /// How [factColumn] differs from the raw answer, if at all.
  final String? factNote;

  /// Parent item key for "Others, please specify" text.
  final String? othersOf;

  bool get isConditional => askedOf != null;

  bool get isPersonal => sensitivity == GtsSensitivity.personal;

  /// "24. First job related to course", or just the label off-questionnaire.
  String get numberedLabel =>
      chedNumber == null ? label : '$chedNumber. $label';

  /// Ordinal brackets in order, without "Others" (which has no rank).
  List<String> get brackets => valueClass == GtsValueClass.ordinal
      ? options.where((o) => !o.startsWith('Others')).toList()
      : const [];

  /// One value per respondent, so every respondent lands in one group.
  bool get groupable =>
      !isPersonal &&
      (valueClass == GtsValueClass.categorical ||
          valueClass == GtsValueClass.ordinal ||
          valueClass == GtsValueClass.year);

  bool get filterable =>
      groupable || (!isPersonal && valueClass == GtsValueClass.multiSelect);

  Set<GtsCalculation> get calculations {
    if (isPersonal) return const {};
    final shares = {
      GtsCalculation.count,
      GtsCalculation.shareOfAnswered,
      if (source == GtsFieldSource.chedAnswer) GtsCalculation.shareOfEligible,
      GtsCalculation.shareOfAllRespondents,
    };
    return switch (valueClass) {
      GtsValueClass.categorical ||
      GtsValueClass.year ||
      GtsValueClass.multiSelect => shares,
      GtsValueClass.ordinal => {...shares, GtsCalculation.medianBracket},
      GtsValueClass.grid => const {
        GtsCalculation.count,
        GtsCalculation.shareOfAnswered,
        GtsCalculation.answeredCount,
      },
      GtsValueClass.table ||
      GtsValueClass.freeText => const {GtsCalculation.answeredCount},
      GtsValueClass.date => const {},
    };
  }

  bool allows(GtsCalculation calculation) => calculations.contains(calculation);
}
