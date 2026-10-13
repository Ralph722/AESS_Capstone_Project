import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_chart.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_tables.dart';
import 'package:alumni_system/features/admin/reports/application/gts_stats.dart';
import 'package:alumni_system/features/admin/reports/data/gts_report_export_service.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_report_builder.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_report_preview.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

import 'gts_fixtures.dart';

/// [groups] courses with [perGroup] graduates each.
List<GtsRespondent> _manyCourses(int groups, {int perGroup = 5}) => gtsFixtures(
  count: groups * perGroup,
  courses: [
    for (var i = 0; i < groups; i++) 'C${i.toString().padLeft(3, '0')}',
  ],
);

GtsReportResult _byCourse(
  List<GtsRespondent> data, {
  GtsChartType chart = GtsChartType.bar,
}) => GtsReportEngine.run(
  GtsReportConfig(
    surveyIds: const ['w1'],
    measure: 'ched_16',
    groupBy: const ['course'],
    population: GtsPopulation.rosterLinked,
    chart: chart,
  ),
  data,
);

bool _isTotal(List<Object?> row) =>
    row.isNotEmpty && row.first == GtsReportTables.allGraduates;

void main() {
  test('remembered visibility matches the questionnaire rules', () {
    for (final r in gtsFixtures()) {
      expect(
        GtsStats.visibleItems(r),
        ChedGtsVisibility.visibleItemIds(r.answers),
      );
      expect(
        identical(GtsStats.visibleItems(r), GtsStats.visibleItems(r)),
        isTrue,
      );
    }
    final field = GtsFieldDictionary.byKey('ched_22')!;
    final employed = gtsFixtures().firstWhere(
      (r) => r.answers['ched_16'] == 'Yes',
    );
    final notEmployed = gtsFixtures().firstWhere(
      (r) => r.answers['ched_16'] != 'Yes',
    );
    expect(GtsStats.read(field, employed).isAnswered, isTrue);
    expect(GtsStats.read(field, notEmployed).state, GtsAnswerState.notAsked);
  });

  test('retitled keeps every number', () {
    final result = _byCourse(gtsFixtures());
    final renamed = result.retitled('Employment by course');
    expect(renamed.config.title, 'Employment by course');
    expect(
      GtsReportTables.main(renamed).rows,
      GtsReportTables.main(result).rows,
    );
    expect(renamed.generatedAt, result.generatedAt);
  });

  group('chart label cap', () {
    test('charts stop at ${GtsChartData.maxLabels} labels in table order', () {
      final result = _byCourse(_manyCourses(55));
      final chart = GtsChartData.of(result)!;
      expect(chart.labels, hasLength(GtsChartData.maxLabels));
      expect(chart.labels.first, 'C000');
      expect(chart.omitted, 15);
      for (final s in chart.series) {
        expect(s.values, hasLength(GtsChartData.maxLabels));
      }
      expect(
        chart.omittedNote,
        'The chart shows the first 40 of 55; the table lists every line.',
      );
      expect(
        GtsReportTables.main(result).rows.where((r) => r.first == 'C054'),
        isNotEmpty,
      );
    });

    test('small charts are unchanged', () {
      final chart = GtsChartData.of(_byCourse(_manyCourses(12)))!;
      expect(chart.labels, hasLength(12));
      expect(chart.omitted, 0);
      expect(chart.omittedNote, isNull);
    });

    test('the PDF builds with a capped chart', () async {
      final bytes = await GtsReportExportService.toPdf(
        _byCourse(_manyCourses(55)),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('preview table', () {
    Future<void> pumpPreview(WidgetTester tester, GtsReportResult r) async {
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: GtsReportPreview(result: r)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    int shownRows(WidgetTester tester) =>
        tester.widget<DataTable>(find.byType(DataTable)).rows.length;

    testWidgets('shows ${GtsReportPreview.rowStep} group lines at a time', (
      tester,
    ) async {
      final result = _byCourse(_manyCourses(90), chart: GtsChartType.table);
      final table = GtsReportTables.main(result);
      final groupLines = table.rows.where((r) => !_isTotal(r)).length;
      final totals = table.rows.length - groupLines;
      expect(groupLines, greaterThan(GtsReportPreview.rowStep));
      expect(groupLines, lessThan(2 * GtsReportPreview.rowStep));

      await pumpPreview(tester, result);
      expect(shownRows(tester), GtsReportPreview.rowStep + totals);
      expect(
        find.textContaining(
          'Showing the first ${GtsReportPreview.rowStep} of $groupLines',
        ),
        findsOneWidget,
      );

      final more = find.text(
        'Show ${groupLines - GtsReportPreview.rowStep} more',
      );
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(shownRows(tester), table.rows.length);
      expect(find.textContaining('Showing the first'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('short tables show every line without a note', (tester) async {
      final result = _byCourse(gtsFixtures(), chart: GtsChartType.table);
      await pumpPreview(tester, result);
      expect(shownRows(tester), GtsReportTables.main(result).rows.length);
      expect(find.textContaining('Showing the first'), findsNothing);
    });

    testWidgets('a capped chart says so on screen', (tester) async {
      await pumpPreview(tester, _byCourse(_manyCourses(55)));
      expect(
        find.text(
          'The chart shows the first 40 of 55; the table lists every line.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('builder', () {
    final waves = [
      Survey(
        id: 'w1',
        title: '2026 tracer',
        description: '',
        status: SurveyStatus.published,
        createdBy: 'admin',
        createdAt: DateTime(2026),
        kind: 'ched_gts_builtin',
      ),
    ];

    Future<List<List<String>>> pumpBuilder(
      WidgetTester tester, {
      Map<String, List<GtsRespondent>>? cache,
    }) async {
      final calls = <List<String>>[];
      tester.view.physicalSize = const Size(1400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GtsReportBuilderPanel(
                waves: waves,
                respondentCache: cache,
                loadRespondents: (ids) async {
                  calls.add(ids);
                  return gtsFixtures();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return calls;
    }

    testWidgets('a cache kept by the page is reused and filled', (
      tester,
    ) async {
      final cache = <String, List<GtsRespondent>>{};
      expect(await pumpBuilder(tester, cache: cache), [
        ['w1'],
      ]);
      expect(cache.keys, ['w1']);

      await tester.pumpWidget(const SizedBox());
      expect(await pumpBuilder(tester, cache: cache), isEmpty);
      expect(find.byType(GtsReportPreview), findsOneWidget);

      await tester.tap(find.byTooltip('Reload responses'));
      await tester.pumpAndSettle();
      expect(cache.keys, ['w1']);
    });

    testWidgets('renaming updates the preview title', (tester) async {
      await pumpBuilder(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Report name (optional)'),
        'Employment check',
      );
      await tester.pumpAndSettle();
      expect(find.text('Employment check'), findsWidgets);
      // New reports count roster-linked graduates (40 of the 42).
      expect(find.textContaining('40 graduates'), findsOneWidget);
    });
  });
}
