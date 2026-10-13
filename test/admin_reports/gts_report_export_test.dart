import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_tables.dart';
import 'package:alumni_system/features/admin/reports/data/gts_report_export_service.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';

GtsRespondent person(String id, String year, Map<String, dynamic> answers) =>
    GtsRespondent(
      userId: id,
      surveyId: 'w1',
      course: 'BSIT',
      yearGraduated: year,
      onActiveRoster: true,
      answers: answers,
    );

void main() {
  final when = DateTime(2026, 10, 12, 9, 30);
  final people = [
    for (var i = 0; i < 7; i++)
      person('u$i', '2024', {
        'ched_3': 'secret$i@example.com',
        'ched_16': i < 5 ? 'Yes' : 'No',
      }),
    person('v1', '2023', {'ched_16': 'Yes'}),
    person('v2', '2023', {'ched_16': 'Never Employed'}),
  ];

  GtsReportResult run(GtsReportConfig c, [List<GtsRespondent>? input]) =>
      GtsReportEngine.run(
        c,
        input ?? people,
        waveLabels: const {'w1': '2025 tracer'},
        now: when,
      );

  final grouped = run(
    const GtsReportConfig(
      title: 'Employment by batch',
      surveyIds: ['w1'],
      measure: 'ched_16',
      groupBy: ['year_graduated'],
      filters: [
        GtsReportFilter(field: 'survey', values: ['w1']),
      ],
    ),
  );

  group('layout', () {
    test('main table: one line per group and answer, all graduates last', () {
      final t = GtsReportTables.main(grouped);
      expect(t.headers, [
        'Graduation year (batch)',
        'Answer',
        'Count',
        'Base',
        'Share (%)',
        '95% range low (%)',
        '95% range high (%)',
        'Sample size',
      ]);
      expect(t.rows, hasLength(9));
      // 2 answers: count and base are hidden along with the share.
      expect(t.rows.first.take(5), ['2023', 'Yes', null, null, null]);
      expect(t.rows.first.last, 'Not enough data');

      final yes2024 = t.rows[3];
      expect(yes2024.take(5), ['2024', 'Yes', 5, 7, 71.4]);
      expect(yes2024[5], lessThan(71.4));
      expect(yes2024[6], greaterThan(71.4));
      expect(yes2024.last, 'Watch');

      expect(t.rows.last.take(5), [
        GtsReportTables.allGraduates,
        'Never Employed',
        1,
        9,
        11.1,
      ]);
    });

    test('crosstab puts groups in rows and answers in columns', () {
      final x = GtsReportTables.crosstab(grouped)!;
      expect(x.headers, [
        'Graduation year (batch)',
        'Base',
        'Yes (%)',
        'No (%)',
        'Never Employed (%)',
      ]);
      expect(x.rows[1], ['2024', 7, 71.4, 28.6, 0.0]);
      expect(x.rows.last.first, GtsReportTables.allGraduates);
      expect(
        GtsReportTables.crosstab(
          run(const GtsReportConfig(surveyIds: ['w1'], measure: 'ched_16')),
        ),
        isNull,
      );
    });

    test('about lists scope in plain words', () {
      final about = {for (final (k, v) in GtsReportTables.about(grouped)) k: v};
      expect(about['Report'], 'Employment by batch');
      expect(about['Question'], startsWith('16.'));
      expect(about['Calculation'], 'Share of graduates who answered');
      expect(about['Tracer waves'], '2025 tracer');
      expect(about['Filters'], 'Tracer wave: 2025 tracer');
      expect(about['Grouped by'], 'Graduation year (batch)');
      expect(about['Graduates in report'], '9');
      expect(about['Generated'], 'Oct 12, 2026 9:30 AM');
    });

    test('notes carry the denominator and small-group rule', () {
      final notes = GtsReportTables.notes(grouped);
      expect(notes, contains('Percent of graduates who answered item 16.'));
      expect(notes.any((n) => n.contains('Not enough data')), isTrue);
    });

    test('median and answer-count layouts', () {
      final median = GtsReportTables.main(
        run(
          const GtsReportConfig(
            surveyIds: ['w1'],
            measure: 'ched_31',
            calculation: GtsCalculation.medianBracket,
          ),
        ),
      );
      expect(median.headers, ['Median bracket', 'Answers', 'Sample size']);
      expect(median.rows.single, [
        'Not enough data',
        null,
        'Not enough data',
      ]);

      final text = GtsReportTables.main(
        run(
          const GtsReportConfig(
            surveyIds: ['w1'],
            measure: 'ched_34',
            calculation: GtsCalculation.answeredCount,
          ),
          [
            person('t1', '2024', {'ched_34': 'More internships'}),
            person('t2', '2024', {}),
          ],
        ),
      );
      expect(text.headers, ['Answered', 'Asked', 'Graduates']);
      // Only 2 graduates: the numbers are hidden.
      expect(text.rows.single, [null, null, null]);
    });
  });

  group('exports', () {
    test('CSV has the same lines as the table and no personal data', () {
      final csv = GtsReportExportService.toCsv(grouped);
      final table = GtsReportTables.main(grouped);
      expect(
        csv,
        contains('Graduation year (batch),Answer,Count,Base,Share (%)'),
      );
      expect(csv, contains('2024,Yes,5,7,71.4,'));
      expect(csv, contains('2023,Yes,,,,,,Not enough data'));
      expect(
        csv.split('\r\n').where((l) => l.startsWith('All graduates,')),
        hasLength(table.rows.where((r) => r.first == 'All graduates').length),
      );
      expect(csv, isNot(contains('example.com')));
      expect(csv, isNot(contains('u1')));
    });

    test('CSV text that looks like a formula is neutralised', () {
      final r = run(
        const GtsReportConfig(
          surveyIds: ['w1'],
          measure: 'ched_18',
          calculation: GtsCalculation.count,
        ),
        [
          for (var i = 0; i < 5; i++)
            person('f$i', '2024', {
              'ched_16': 'Yes',
              'ched_18': '=HYPERLINK("http://x","y")',
            }),
        ],
      );
      final csv = GtsReportExportService.toCsv(r);
      expect(csv, contains('"\'=HYPERLINK(""http://x"",""y"")",5'));
    });

    test('Excel has report, group and notes tabs with numeric cells', () {
      final bytes = GtsReportExportService.toExcel(grouped);
      final book = Excel.decodeBytes(bytes);
      expect(book.tables.keys, containsAll(['Report', 'By group', 'Notes']));

      Object? plain(Data? c) {
        final v = c?.value;
        return v is num ? v : v?.toString();
      }

      final rows = book.tables['Report']!.rows
          .map((r) => [for (final c in r) plain(c)])
          .toList();
      final header = rows.indexWhere(
        (r) => r.first == 'Graduation year (batch)',
      );
      expect(header, greaterThan(0));
      final yes2024 = rows[header + 4];
      expect(yes2024.take(5), ['2024', 'Yes', 5, 7, 71.4]);

      final notes = book.tables['Notes']!.rows
          .map((r) => plain(r.first))
          .toList();
      expect(notes, contains('Percent of graduates who answered item 16.'));
    });

    test('PDF renders', () async {
      final bytes = await GtsReportExportService.exportBytes(
        grouped,
        CustomReportFormat.pdf,
      );
      expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    });

    test('CSV bytes start with a UTF-8 marker for Excel', () async {
      final bytes = await GtsReportExportService.exportBytes(
        grouped,
        CustomReportFormat.csv,
      );
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    });

    test('file names are short and dated', () {
      expect(
        GtsReportExportService.fileName(grouped, CustomReportFormat.excel),
        'gts_employment_by_batch_20261012.xlsx',
      );
    });
  });
}
