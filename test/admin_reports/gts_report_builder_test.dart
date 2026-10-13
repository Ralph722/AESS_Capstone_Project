import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_tables.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_report_builder.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_report_preview.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

Survey wave(String id, String title) => Survey(
  id: id,
  title: title,
  description: '',
  status: SurveyStatus.published,
  createdBy: 'admin',
  createdAt: DateTime(2026),
  kind: 'ched_gts_builtin',
);

List<GtsRespondent> respondents(String surveyId) => [
  for (var i = 0; i < 8; i++)
    GtsRespondent(
      userId: '$surveyId-u$i',
      surveyId: surveyId,
      course: i.isEven ? 'BSIT' : 'BSCS',
      yearGraduated: '2024',
      onActiveRoster: true,
      answers: {'ched_16': i < 6 ? 'Yes' : 'No'},
    ),
];

void main() {
  final waves = [wave('w2', '2026 tracer'), wave('w1', '2025 tracer')];

  Future<List<List<String>>> pump(
    WidgetTester tester, {
    GtsReportConfig? initial,
    List<GtsReportConfig>? changes,
    Future<List<GtsRespondent>> Function(List<String>)? loader,
    List<Survey>? waveList,
  }) async {
    final calls = <List<String>>[];
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GtsReportBuilderPanel(
              waves: waveList ?? waves,
              initialConfig: initial,
              onConfigChanged: changes?.add,
              loadRespondents:
                  loader ??
                  (ids) async {
                    calls.add(ids);
                    return [for (final id in ids) ...respondents(id)];
                  },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return calls;
  }

  Future<void> openMoreOptions(WidgetTester tester) async {
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
  }

  Future<void> pickFromDropdown(
    WidgetTester tester,
    Finder dropdown,
    String item,
  ) async {
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the newest wave with employment and a preview', (
    tester,
  ) async {
    final changes = <GtsReportConfig>[];
    final calls = await pump(tester, changes: changes);
    expect(calls, [
      ['w2'],
    ]);
    expect(find.byType(GtsReportPreview), findsOneWidget);
    expect(find.textContaining('8 graduates'), findsOneWidget);
    expect(find.text('16. Presently employed'), findsWidgets);
    expect(find.text('Who to count'), findsNothing);
    expect(find.text('Calculation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the preview starts with one plain sentence', (tester) async {
    await pump(tester);
    final sentence = tester.widget<Text>(
      find.byKey(const ValueKey('gts-report-sentence')),
    );
    expect(
      sentence.data,
      'Share of graduates who answered item 16 (presently employed), '
      '2026 tracer.',
    );
  });

  testWidgets('comparing waves groups by wave and loads only the new wave', (
    tester,
  ) async {
    final changes = <GtsReportConfig>[];
    final calls = await pump(tester, changes: changes);
    await tester.tap(find.text('Compare waves'));
    await tester.pumpAndSettle();
    expect(changes.last.surveyIds, ['w2', 'w1']);
    expect(changes.last.groupBy, ['survey']);
    expect(calls.last, ['w1']);
    expect(find.textContaining('16 graduates'), findsOneWidget);
    // Two waves is the minimum while comparing.
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '2025 tracer'),
    );
    expect(chip.onSelected, isNull);

    await tester.tap(find.text('Compare waves'));
    await tester.pumpAndSettle();
    expect(changes.last.surveyIds, ['w2']);
    expect(changes.last.groupBy, isEmpty);
  });

  testWidgets('one wave cannot be compared', (tester) async {
    await pump(tester, waveList: [waves.first]);
    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Compare waves'),
    );
    expect(tile.onChanged, isNull);
  });

  testWidgets('settings errors replace the preview', (tester) async {
    await pump(
      tester,
      initial: const GtsReportConfig(
        surveyIds: ['w2'],
        measure: 'ched_16',
        population: GtsPopulation.rosterLinked,
        filters: [GtsReportFilter(field: 'course', values: [])],
      ),
    );
    expect(find.byType(GtsReportPreview), findsNothing);
    expect(find.textContaining('Choose at least one'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'BSIT'));
    await tester.pumpAndSettle();
    expect(find.byType(GtsReportPreview), findsOneWidget);
    expect(find.textContaining('4 graduates'), findsOneWidget);
    expect(find.text('Only graduates whose Course is BSIT.'), findsOneWidget);
  });

  testWidgets('charts that do not fit are greyed out with a reason', (
    tester,
  ) async {
    await pump(tester);
    InkWell tile(GtsChartType t) =>
        tester.widget<InkWell>(find.byKey(ValueKey('chart-${t.name}')));
    expect(tile(GtsChartType.line).onTap, isNull);
    expect(tile(GtsChartType.donut).onTap, isNotNull);
    expect(find.textContaining('Line: A line shows change'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chart-donut')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<GtsReportPreview>(find.byType(GtsReportPreview))
          .result
          .config
          .chart,
      GtsChartType.donut,
    );
  });

  testWidgets('a template card fills in the settings and keeps the wave', (
    tester,
  ) async {
    final changes = <GtsReportConfig>[];
    await pump(tester, changes: changes);
    await tester.tap(
      find.byKey(const ValueKey('template-card-employment_by_course')),
    );
    await tester.pumpAndSettle();
    final c = changes.last;
    expect(c.templateKey, 'employment_by_course');
    expect(c.surveyIds, ['w2']);
    expect(c.groupBy, ['course']);
    expect(c.population, GtsPopulation.rosterLinked);
    expect(c.chart, GtsChartType.stackedBar);
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Report name (optional)'),
          )
          .controller!
          .text,
      'Employment status by course',
    );
    expect(find.textContaining('You can change any setting'), findsOneWidget);
    expect(find.byType(GtsReportPreview), findsOneWidget);
  });

  testWidgets('the question picker searches and sets the question', (
    tester,
  ) async {
    final changes = <GtsReportConfig>[];
    await pump(tester, changes: changes);
    await tester.tap(find.byKey(const ValueKey('question-picker')));
    await tester.pumpAndSettle();
    expect(find.text('B. EDUCATIONAL BACKGROUND'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'employment status',
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('16. Presently employed'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('18. Present employment status'));
    await tester.pumpAndSettle();
    expect(changes.last.measure, 'ched_18');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('compare by course, then split by batch', (tester) async {
    final changes = <GtsReportConfig>[];
    await pump(tester, changes: changes);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Course'));
    await tester.pumpAndSettle();
    expect(changes.last.groupBy, ['course']);

    await openMoreOptions(tester);
    await pickFromDropdown(
      tester,
      find.widgetWithText(
        DropdownButtonFormField<String?>,
        'Then split each group by',
      ),
      'Graduation year (batch)',
    );
    expect(changes.last.groupBy, ['course', 'year_graduated']);

    await tester.tap(find.widgetWithText(ChoiceChip, 'None'));
    await tester.pumpAndSettle();
    expect(changes.last.groupBy, isEmpty);
  });

  testWidgets('compare by the answer to another question', (tester) async {
    final changes = <GtsReportConfig>[];
    await pump(tester, changes: changes);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Another question'));
    await tester.pumpAndSettle();
    final sex = GtsFieldDictionary.byKey('ched_7')!;
    await pickFromDropdown(
      tester,
      find.widgetWithText(
        DropdownButtonFormField<String>,
        'Compare by the answer to',
      ),
      sex.numberedLabel,
    );
    expect(changes.last.groupBy, ['ched_7']);
    final selected = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Another question'),
    );
    expect(selected.selected, isTrue);
  });

  testWidgets('numbers switch between percent and number of graduates', (
    tester,
  ) async {
    final changes = <GtsReportConfig>[];
    await pump(tester, changes: changes);
    await tester.tap(find.text('Number of graduates').first);
    await tester.pumpAndSettle();
    expect(changes.last.calculation, GtsCalculation.count);
    await tester.tap(find.text('Percent'));
    await tester.pumpAndSettle();
    expect(changes.last.calculation, GtsCalculation.shareOfAnswered);
  });

  testWidgets('the median is under More options for bracket questions', (
    tester,
  ) async {
    final ordinal = GtsFieldDictionary.chedFields.firstWhere(
      (f) => f.valueClass == GtsValueClass.ordinal,
    );
    final changes = <GtsReportConfig>[];
    await pump(
      tester,
      changes: changes,
      initial: GtsReportConfig(
        surveyIds: const ['w2'],
        measure: ordinal.key,
        population: GtsPopulation.rosterLinked,
        chart: GtsChartType.bar,
      ),
    );
    await openMoreOptions(tester);
    await tester.tap(find.text('Show the middle bracket (median)'));
    await tester.pumpAndSettle();
    expect(changes.last.calculation, GtsCalculation.medianBracket);
    expect(changes.last.chart, GtsChartType.table);

    await tester.tap(find.text('Percent'));
    await tester.pumpAndSettle();
    expect(changes.last.calculation, GtsCalculation.shareOfAnswered);
  });

  testWidgets('older saved settings are kept with a note and a switch', (
    tester,
  ) async {
    final changes = <GtsReportConfig>[];
    await pump(
      tester,
      changes: changes,
      initial: const GtsReportConfig(
        surveyIds: ['w2'],
        measure: 'ched_16',
        calculation: GtsCalculation.shareOfAllRespondents,
      ),
    );
    expect(find.byType(GtsReportPreview), findsOneWidget);
    expect(find.textContaining('counts every response'), findsOneWidget);
    expect(find.textContaining('"Share of all graduates"'), findsOneWidget);
    expect(changes, isEmpty);

    await tester.tap(find.text('Count roster graduates only'));
    await tester.pumpAndSettle();
    expect(changes.last.population, GtsPopulation.rosterLinked);
    expect(changes.last.calculation, GtsCalculation.shareOfAllRespondents);

    await tester.tap(find.text('Use Percent'));
    await tester.pumpAndSettle();
    expect(changes.last.calculation, GtsCalculation.shareOfAnswered);
    expect(find.textContaining('counts every response'), findsNothing);
    expect(find.textContaining('an older setting'), findsNothing);
  });

  testWidgets('load failures can be retried', (tester) async {
    var fail = true;
    await pump(
      tester,
      loader: (ids) async {
        if (fail) throw Exception('offline');
        return [for (final id in ids) ...respondents(id)];
      },
    );
    expect(find.textContaining('Could not load'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(GtsReportPreview), findsOneWidget);
  });

  testWidgets('no waves explains what to do', (tester) async {
    await pump(tester, waveList: const []);
    expect(find.textContaining('No published CHED'), findsOneWidget);
  });

  group('description sentence', () {
    final labels = {'w1': '2025 tracer', 'w2': '2026 tracer'};
    String sentence(GtsReportConfig c) => GtsReportTables.sentence(
      GtsReportEngine.run(c, [
        for (final id in c.surveyIds) ...respondents(id),
      ], waveLabels: labels),
    );

    test('describes the numbers, comparison, conditions and waves', () {
      expect(
        sentence(
          const GtsReportConfig(
            surveyIds: ['w2', 'w1'],
            measure: 'ched_16',
            population: GtsPopulation.rosterLinked,
            calculation: GtsCalculation.count,
            groupBy: ['survey', 'course'],
            filters: [
              GtsReportFilter(field: 'year_graduated', values: ['2024']),
            ],
          ),
        ),
        'Number of graduates by answer to item 16 (presently employed), by '
        'course, only graduates whose Graduation year (batch) is 2024, '
        'compared across 2026 tracer and 2025 tracer.',
      );
    });

    test('mentions older settings that change the numbers', () {
      expect(
        sentence(
          const GtsReportConfig(surveyIds: ['w1'], measure: 'course', topN: 5),
        ),
        'Share of graduates by course, counting every response, top 5 '
        'answers, 2025 tracer.',
      );
    });

    test('filter sentences join several values with "or"', () {
      expect(
        GtsReportTables.filterSentence(
          const GtsReportFilter(field: 'ched_16', values: ['No', 'Yes']),
          (id) => id,
        ),
        'Only graduates whose 16. Presently employed is No or Yes.',
      );
      expect(
        GtsReportTables.filterSentence(
          const GtsReportFilter(field: 'survey', values: ['w1', 'w2', 'w3']),
          (id) => labels[id] ?? id,
        ),
        'Only graduates whose Tracer wave is 2025 tracer, 2026 tracer or w3.',
      );
      expect(
        GtsReportTables.filterSentence(
          const GtsReportFilter(field: 'nope', values: []),
          (id) => id,
        ),
        isNull,
      );
    });
  });
}
