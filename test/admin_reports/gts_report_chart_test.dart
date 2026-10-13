import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_chart.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_validator.dart';
import 'package:alumni_system/features/admin/reports/data/gts_report_export_service.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_report_preview.dart';

GtsRespondent person(String id, String year, String q16, {String? q20}) =>
    GtsRespondent(
      userId: id,
      surveyId: 'w1',
      course: id.startsWith('a') ? 'BSIT' : 'BSCS',
      yearGraduated: year,
      onActiveRoster: true,
      answers: {'ched_16': q16, 'ched_20': ?q20},
    );

void main() {
  const industries = [
    'Education',
    'Manufacturing',
    'Financial Intermediation',
    'Construction',
  ];
  final people = [
    for (var i = 0; i < 12; i++)
      person(
        'a$i',
        '2024',
        i < 9 ? 'Yes' : 'No',
        q20: i < 9 ? industries[i % 4] : null,
      ),
    for (var i = 0; i < 8; i++)
      person(
        'b$i',
        '2023',
        i < 4 ? 'Yes' : 'Never Employed',
        q20: i < 4 ? industries[0] : null,
      ),
    person('c1', '2022', 'Yes', q20: industries[1]),
  ];

  GtsReportResult run(GtsReportConfig c) =>
      GtsReportEngine.run(c, people, now: DateTime(2026, 10, 12));

  const base = GtsReportConfig(surveyIds: ['w1'], measure: 'ched_16');

  group('chart data', () {
    test('ungrouped shares: one series over the answers', () {
      final d = GtsChartData.of(run(base.copyWith(chart: GtsChartType.donut)))!;
      expect(d.isPercent, isTrue);
      expect(d.labels, ['Yes', 'No', 'Never Employed']);
      expect(d.series.single.values, [66.7, 14.3, 19.0]);
      expect(d.format(66.7), '66.7%');
    });

    test('grouped: answers are series, groups run along the axis', () {
      final d = GtsChartData.of(
        run(
          base.copyWith(
            groupBy: ['year_graduated'],
            chart: GtsChartType.groupedBar,
          ),
        ),
      )!;
      expect(d.labels, ['2022', '2023', '2024']);
      expect(d.series.map((s) => s.name), ['Yes', 'No', 'Never Employed']);
      expect(d.series.first.values, [null, 50.0, 75.0]);
      expect(d.hasHiddenValues, isTrue, reason: '2022 has one answer');
      expect(d.format(null), 'Not enough data');
    });

    test('two group-bys combine labels', () {
      final d = GtsChartData.of(
        run(
          base.copyWith(
            groupBy: ['course', 'year_graduated'],
            chart: GtsChartType.stackedBar,
          ),
        ),
      )!;
      expect(d.labels, ['BSCS / 2022', 'BSCS / 2023', 'BSIT / 2024']);
    });

    test('counts are not percentages', () {
      final d = GtsChartData.of(
        run(
          base.copyWith(
            calculation: GtsCalculation.count,
            chart: GtsChartType.bar,
          ),
        ),
      )!;
      expect(d.isPercent, isFalse);
      expect(d.series.single.values, [14.0, 3.0, 4.0]);
      expect(d.format(14), '14');
    });

    test('answer counts chart answered, blank and not asked', () {
      final d = GtsChartData.of(
        run(
          const GtsReportConfig(
            surveyIds: ['w1'],
            measure: 'ched_19',
            calculation: GtsCalculation.answeredCount,
            chart: GtsChartType.bar,
          ),
        ),
      )!;
      expect(d.labels, ['Answered', 'Left blank', 'Not asked']);
      expect(d.series.single.values, [0.0, 14.0, 7.0]);
    });

    test('tables and medians have no chart', () {
      expect(GtsChartData.of(run(base)), isNull);
      expect(
        GtsChartData.of(
          run(
            const GtsReportConfig(
              surveyIds: ['w1'],
              measure: 'ched_31',
              calculation: GtsCalculation.medianBracket,
            ),
          ),
        ),
        isNull,
      );
    });

    test('lines follow a single group-by', () {
      final v = GtsReportValidator.validate(
        base.copyWith(
          groupBy: ['year_graduated', 'course'],
          chart: GtsChartType.line,
        ),
      );
      expect(v.has('chart_invalid'), isTrue);
    });
  });

  final configs = <String, GtsReportConfig>{
    'bar': base.copyWith(chart: GtsChartType.bar),
    'horizontal': const GtsReportConfig(
      surveyIds: ['w1'],
      measure: 'ched_20',
      chart: GtsChartType.horizontalBar,
    ),
    'donut': base.copyWith(chart: GtsChartType.donut),
    'line': base.copyWith(
      groupBy: ['year_graduated'],
      chart: GtsChartType.line,
    ),
    'grouped': base.copyWith(
      groupBy: ['year_graduated'],
      chart: GtsChartType.groupedBar,
    ),
    'stacked': base.copyWith(
      groupBy: ['course'],
      chart: GtsChartType.stackedBar,
    ),
    'counts': base.copyWith(
      calculation: GtsCalculation.count,
      groupBy: ['year_graduated'],
      chart: GtsChartType.groupedBar,
    ),
  };

  group('PDF charts', () {
    for (final MapEntry(:key, :value) in configs.entries) {
      test('$key renders', () async {
        final bytes = await GtsReportExportService.toPdf(run(value));
        expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
      });
    }

    test('one-wave line and all-hidden charts still render', () async {
      final few = [person('z1', '2024', 'Yes'), person('z2', '2024', 'No')];
      for (final c in [
        base.copyWith(groupBy: ['year_graduated'], chart: GtsChartType.line),
        base.copyWith(chart: GtsChartType.donut),
        base.copyWith(groupBy: ['course'], chart: GtsChartType.stackedBar),
      ]) {
        final r = GtsReportEngine.run(c, few);
        final bytes = await GtsReportExportService.toPdf(r);
        expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
      }
    });
  });

  group('preview', () {
    Future<void> pump(WidgetTester tester, GtsReportResult r) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: GtsReportPreview(result: r),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final MapEntry(:key, :value) in configs.entries) {
      testWidgets('$key shows without layout errors', (tester) async {
        final r = run(value);
        await pump(tester, r);
        expect(tester.takeException(), isNull);
        expect(find.byType(GtsReportChartView), findsOneWidget);
        expect(find.byType(DataTable), findsOneWidget);
        if (r.isGrouped) expect(find.text('All graduates'), findsWidgets);
      });
    }

    testWidgets('warnings are shown and the table can be hidden', (
      tester,
    ) async {
      final r = run(
        base.copyWith(
          measure: 'ched_20',
          chart: GtsChartType.bar,
          showTable: false,
        ),
      );
      await pump(tester, r);
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      expect(find.byType(DataTable), findsNothing);
    });

    testWidgets('a table-only report always shows the table', (tester) async {
      await pump(tester, run(base.copyWith(showTable: false)));
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byType(GtsReportChartView), findsNothing);
    });

    testWidgets('empty scope says so', (tester) async {
      await pump(tester, GtsReportEngine.run(base, const []));
      expect(find.text('No graduates matched this report.'), findsOneWidget);
    });
  });
}
