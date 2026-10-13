import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_chart.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_tables.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_templates.dart';
import 'package:alumni_system/features/admin/reports/data/gts_report_export_service.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_report_preview.dart';
import 'gts_fixtures.dart';

/// Minimal RFC 4180 reader: quoted fields, doubled quotes, CRLF rows.
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"' && i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else if (ch == '"') {
        quoted = false;
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
      i++;
    } else {
      cell.write(ch);
    }
  }
  return rows;
}

/// Comparable form of a table cell: numbers as doubles, blanks as null,
/// formula guards removed.
Object? norm(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  var s = v.toString();
  if (s.isEmpty) return null;
  if (s.length > 1 && s[0] == "'" && '=+-@\t\r'.contains(s[1])) {
    s = s.substring(1);
  }
  return s;
}

/// CSV has no types, so compare text: what the result holds, as written.
List<List<String>> csvText(Iterable<List<Object?>> rows) => [
  for (final r in rows)
    [for (final c in r) c is num ? '$c' : (norm(c) ?? '').toString()],
];

Object? excelCell(Data? c) {
  final v = c?.value;
  if (v == null) return null;
  if (v is num) return v;
  return v.toString();
}

List<List<Object?>> normRows(Iterable<List<Object?>> rows) => [
  for (final r in rows) [for (final c in r) norm(c)],
];

/// Data rows of [rows] after the header line that starts the results table.
List<List<Object?>> afterHeader(
  List<List<Object?>> rows,
  List<String> headers,
  int count,
) {
  final at = rows.indexWhere(
    (r) =>
        r.isNotEmpty &&
        r.first == headers.first &&
        r.length >= 2 &&
        r[1] == headers[1],
  );
  expect(at, isNonNegative, reason: 'results header not found');
  return [
    for (final r in rows.skip(at + 1).take(count))
      [for (var i = 0; i < headers.length; i++) i < r.length ? r[i] : null],
  ];
}

GtsReportResult runTemplate(GtsReportTemplate t, List<GtsRespondent> data) =>
    GtsReportEngine.run(t.forWaves(const ['w1']), data);

int pdfPages(List<int> bytes) =>
    RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

void main() {
  final data = gtsFixtures();

  group('every template prints the same numbers everywhere', () {
    for (final t in GtsReportTemplates.all) {
      test('${t.key}: CSV and Excel equal the result table', () {
        final r = runTemplate(t, data);
        final table = GtsReportTables.main(r);
        final expected = normRows(table.rows);

        final csv = parseCsv(GtsReportExportService.toCsv(r));
        final csvRows = afterHeader(csv, table.headers, table.rows.length);
        expect(csvText(csvRows), csvText(table.rows), reason: 'CSV');

        final book = Excel.decodeBytes(GtsReportExportService.toExcel(r));
        final sheet = book.tables['Report']!.rows
            .map((row) => [for (final c in row) excelCell(c)])
            .toList();
        final xlsRows = afterHeader(sheet, table.headers, table.rows.length);
        expect(normRows(xlsRows), expected, reason: 'Excel');
        expect(book.tables.keys.toSet(), containsAll(['Report', 'Notes']));
      });

      testWidgets('${t.key}: preview shows the result table', (tester) async {
        final r = runTemplate(t, data);
        tester.view.physicalSize = const Size(1400, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GtsReportPreview(
                  result: r.config.showTable
                      ? r
                      : GtsReportEngine.run(
                          r.config.copyWith(showTable: true),
                          data,
                        ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final grid = tester.widget<DataTable>(find.byType(DataTable));
        final table = GtsReportTables.main(r);
        expect([
          for (final c in grid.columns) (c.label as Text).data,
        ], table.headers);
        expect(
          [
            for (final row in grid.rows)
              [for (final c in row.cells) (c.child as Text).data],
          ],
          [
            for (final row in table.rows)
              [for (final c in row) GtsReportTables.display(c)],
          ],
        );
        expect(tester.takeException(), isNull);
      });

      test('${t.key}: PDF renders', () async {
        final bytes = await GtsReportExportService.toPdf(runTemplate(t, data));
        expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
        expect(pdfPages(bytes), greaterThanOrEqualTo(1));
      });
    }
  });

  test('saving and reopening a report gives the same tables', () {
    for (final t in GtsReportTemplates.all) {
      final config = t.forWaves(const ['w1']);
      final reopened = GtsReportConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      );
      final a = GtsReportEngine.run(config, data);
      final b = GtsReportEngine.run(reopened, data);
      expect(GtsReportTables.main(b).rows, GtsReportTables.main(a).rows);
      expect(GtsReportTables.about(b), GtsReportTables.about(a));
      expect(GtsReportTables.notes(b), GtsReportTables.notes(a));
    }
  });

  test('item 24 denominators follow the skip logic for each calculation', () {
    final extra = [
      ...data,
      // Asked item 24 (first job) but left it blank.
      const GtsRespondent(
        userId: 'blank-24',
        surveyId: 'w1',
        course: 'BSIT',
        onActiveRoster: true,
        answers: {'ched_16': 'Yes', 'ched_22': 'Yes'},
      ),
    ];
    final everyone = extra.length;
    final asked = extra
        .where((r) => GtsFieldDictionary.isAskedFor('ched_24a', r.answers))
        .length;
    final answered = extra
        .where((r) => (r.answers['ched_24a'] ?? '').toString().isNotEmpty)
        .length;
    expect(answered, lessThan(asked));
    expect(asked, lessThan(everyone));

    int denominator(GtsCalculation c) => GtsReportEngine.run(
      GtsReportConfig(
        surveyIds: const ['w1'],
        measure: 'ched_24a',
        calculation: c,
      ),
      extra,
    ).total.denominator;
    expect(denominator(GtsCalculation.shareOfAnswered), answered);
    expect(denominator(GtsCalculation.shareOfEligible), asked);
    expect(denominator(GtsCalculation.shareOfAllRespondents), everyone);
  });

  test('groups under 5 answers hide counts and bases in every output', () {
    final mixed = [
      ...gtsFixtures(count: 20, courses: const ['BSCS']),
      for (var i = 0; i < 3; i++)
        GtsRespondent(
          userId: 'small$i',
          surveyId: 'w1',
          course: 'BSMath',
          yearGraduated: '2024',
          onActiveRoster: true,
          answers: const {'ched_16': 'Yes'},
        ),
    ];
    for (final calc in [
      GtsCalculation.count,
      GtsCalculation.shareOfAnswered,
    ]) {
      final r = GtsReportEngine.run(
        GtsReportConfig(
          surveyIds: const ['w1'],
          measure: 'ched_16',
          population: GtsPopulation.rosterLinked,
          calculation: calc,
          groupBy: const [GtsFieldDictionary.course],
          chart: GtsChartType.groupedBar,
        ),
        mixed,
      );
      final small = r.rows.singleWhere((x) => x.groupValues.single == 'BSMath');
      expect(small.isSmall, isTrue);
      expect(r.total.isSmall, isFalse);

      bool numbersHidden(List<Object?> row) =>
          row.whereType<num>().isEmpty;
      final table = GtsReportTables.main(r);
      final smallLines = table.rows.where((x) => x.first == 'BSMath');
      expect(smallLines, isNotEmpty);
      expect(smallLines.every(numbersHidden), isTrue, reason: '$calc');
      expect(
        table.rows.where((x) => x.first == 'BSCS').any(numbersHidden),
        isFalse,
        reason: '$calc keeps numbers for large groups',
      );
      final crosstab = GtsReportTables.crosstab(r);
      if (crosstab != null) {
        expect(
          numbersHidden(crosstab.rows.firstWhere((x) => x.first == 'BSMath')),
          isTrue,
        );
      }

      final csvLines = parseCsv(GtsReportExportService.toCsv(r))
          .where((x) => x.isNotEmpty && x.first == 'BSMath');
      for (final line in csvLines) {
        expect(line.where((c) => num.tryParse(c) != null), isEmpty);
      }

      final chart = GtsChartData.of(r)!;
      final at = chart.labels.indexOf('BSMath');
      for (final s in chart.series) {
        expect(s.values[at], isNull, reason: '$calc ${s.name}');
      }
    }
  });

  group('awkward text', () {
    const courses = [
      'BS "Info", Tech',
      'Line\nBreak course',
      '=HYPERLINK("http://x")',
      'Parañaque – Campus',
    ];
    final tricky = gtsFixtures(count: 40, courses: courses);
    final config = GtsReportTemplates.byKey(
      'employment_by_course',
    )!.forWaves(const ['w1']);

    test('CSV quotes, escapes and neutralises course names', () {
      final r = GtsReportEngine.run(config, tricky);
      final text = GtsReportExportService.toCsv(r);
      expect(text, contains('"BS ""Info"", Tech"'));
      expect(text, contains("'=HYPERLINK"));
      expect(text, isNot(contains('\n=HYPERLINK')));
      final table = GtsReportTables.main(r);
      final rows = afterHeader(
        parseCsv(text),
        table.headers,
        table.rows.length,
      );
      expect(csvText(rows), csvText(table.rows));
    });

    test('Excel keeps the names as text cells', () {
      final r = GtsReportEngine.run(config, tricky);
      final book = Excel.decodeBytes(GtsReportExportService.toExcel(r));
      final firstColumn = book.tables['Report']!.rows
          .map((row) => row.isEmpty ? null : excelCell(row.first))
          .whereType<String>()
          .toSet();
      expect(firstColumn, containsAll(courses));
    });

    test('PDF renders long and non-ASCII names', () async {
      final r = GtsReportEngine.run(
        config.copyWith(title: 'Employment status by course ' * 8),
        tricky,
      );
      final bytes = await GtsReportExportService.toPdf(r);
      expect(pdfPages(bytes), greaterThanOrEqualTo(1));
    });
  });

  test(
    'a large two-level report spills onto several landscape pages',
    () async {
      final courses = [
        for (var i = 0; i < 25; i++)
          'Bachelor of Science in a Very Long Program Name Number $i',
      ];
      final big = gtsFixtures(count: 500, courses: courses);
      final r = GtsReportEngine.run(
        GtsReportConfig(
          surveyIds: const ['w1'],
          measure: 'ched_20',
          groupBy: const [
            GtsFieldDictionary.course,
            GtsFieldDictionary.yearGraduated,
          ],
        ),
        big,
      );
      expect(r.categories.length, greaterThanOrEqualTo(18));
      final table = GtsReportTables.main(r);
      expect(table.headers.length, greaterThan(7));
      final bytes = await GtsReportExportService.toPdf(r);
      expect(pdfPages(bytes), greaterThan(5));
      expect(
        latin1.decode(bytes),
        matches(RegExp(r'/MediaBox\s*\[\s*0\s+0\s+841\.8')),
      );
    },
  );

  test('past the PDF line limit the PDF still renders, with totals', () async {
    final big = gtsFixtures(
      count: 2000,
      courses: [for (var i = 0; i < 25; i++) 'Course $i'],
      years: [for (var y = 2005; y < 2025; y++) '$y'],
    );
    final r = GtsReportEngine.run(
      GtsReportConfig(
        surveyIds: const ['w1'],
        measure: 'ched_20',
        groupBy: const [
          GtsFieldDictionary.course,
          GtsFieldDictionary.yearGraduated,
        ],
      ),
      big,
    );
    final rows = GtsReportTables.main(r).rows;
    expect(rows.length, greaterThan(GtsReportExportService.pdfRowLimit));
    final bytes = await GtsReportExportService.toPdf(r);
    expect(pdfPages(bytes), inInclusiveRange(20, 200));
    final csvLines = parseCsv(GtsReportExportService.toCsv(r));
    expect(csvLines.length, greaterThan(rows.length));
  });

  test('a bar chart with many groups continues on the next page', () async {
    final courses = [for (var i = 0; i < 25; i++) 'Program $i'];
    final r = GtsReportEngine.run(
      GtsReportConfig(
        surveyIds: const ['w1'],
        measure: 'ched_16',
        population: GtsPopulation.rosterLinked,
        groupBy: const [
          GtsFieldDictionary.course,
          GtsFieldDictionary.yearGraduated,
        ],
        chart: GtsChartType.groupedBar,
        showTable: false,
      ),
      gtsFixtures(count: 600, courses: courses),
    );
    expect(r.rows.length, 50);
    final bytes = await GtsReportExportService.toPdf(r);
    expect(pdfPages(bytes), greaterThan(1));
  });

  test('questionnaire wording survives the PDF font without "?"', () {
    int marks(String s) => '?'.allMatches(s).length;
    for (final f in GtsFieldDictionary.fields) {
      for (final text in [f.label, f.prompt ?? '', ...f.options]) {
        expect(
          marks(PdfSafeText.sanitize(text)),
          marks(text),
          reason: '${f.key}: $text',
        );
      }
    }
  });
}
