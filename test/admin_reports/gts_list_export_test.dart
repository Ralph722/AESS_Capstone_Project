import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'
    show PdfDocument, PdfTextExtractor;
import 'package:alumni_system/core/utils/personal_data_notice.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_tables.dart';
import 'package:alumni_system/features/admin/reports/data/gts_list_export_service.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_alumni_list_panel.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'gts_report_qa_test.dart' show parseCsv;

AlumniMember _member(
  String name, {
  String batch = '2023',
  String? uid,
  bool registered = true,
}) => AlumniMember(
  id: 'm-$name',
  fullName: name,
  course: 'BSIT',
  studentId: 'S-$name',
  authUid: uid,
  isRegisteredUser: registered,
  batchYear: batch,
  createdAt: DateTime(2020),
);

GtsListResponse _response(String uid, Map<String, dynamic> answers) =>
    GtsListResponse(
      userId: uid,
      surveyId: 'w2',
      responseId: 'r-$uid',
      submittedAt: DateTime(2026, 6),
      answers: answers,
    );

final _roster = [
  _member('Juan Dela Cruz', uid: 'u1'),
  _member('Maria Santos', uid: 'u2'),
  _member('Pedro Reyes', batch: '2024', uid: 'u3'),
  _member('Ana Lopez', batch: '2024', uid: 'u4'),
  _member('Jose Rizal', batch: '2024', registered: false),
];

final _responses = [
  _response('u1', {
    'ched_16': 'Yes',
    'ched_19': 'AI engineer, team lead',
    'ched_20': 'Others, please specify',
    'ched_20_other': '=HYPERLINK("http://x","y")',
  }),
  _response('u2', {'ched_16': 'No'}),
  _response('u3', {'ched_16': 'Never Employed'}),
];

GtsAlumniListResult _build({
  GtsListConfig config = const GtsListConfig(
    surveyId: 'w2',
    columns: [
      'year_graduated',
      'name',
      'ched_16',
      'ched_19',
      'ched_20',
      'tracer_status',
    ],
  ),
  List<AlumniMember>? roster,
  List<GtsListResponse>? responses,
}) => GtsAlumniList.build(
  config,
  roster: roster ?? _roster,
  responses: responses ?? _responses,
  waveIds: const ['w2'],
  waveLabels: const {'w2': 'Tracer 2026'},
  now: DateTime(2026, 10, 14, 9),
);

List<List<String>> _trim(List<List<String>> rows) => [
  for (final r in rows) [...r.take(r.lastIndexWhere((c) => c.isNotEmpty) + 1)],
];

List<List<String>> _csv(GtsAlumniListResult r) =>
    _trim(parseCsv(GtsListExportService.toCsv(r)));

List<List<String>> _excel(
  GtsAlumniListResult r, [
  String sheet = 'Alumni list',
]) {
  final book = Excel.decodeBytes(GtsListExportService.toExcel(r));
  return _trim([
    for (final row in book.tables[sheet]!.rows)
      [for (final c in row) c?.value?.toString() ?? ''],
  ]);
}

Future<String> _pdfText(GtsAlumniListResult r) async {
  final doc = PdfDocument(inputBytes: await GtsListExportService.toPdf(r));
  final extractor = PdfTextExtractor(doc);
  final text = [
    for (var i = 0; i < doc.pages.count; i++)
      extractor.extractText(startPageIndex: i, endPageIndex: i),
  ].join(' ').replaceAll(RegExp(r'\s+'), ' ');
  doc.dispose();
  return text;
}

void main() {
  group('one layout in every format', () {
    test('CSV and Excel hold the same rows', () {
      final r = _build();
      expect(_excel(r), _csv(r));
    });

    test('the list follows the about lines, then the tally', () {
      final r = _build();
      final rows = _csv(r);
      expect(rows.first, ['Report', GtsListTables.defaultTitle]);
      expect(rows, contains(equals(['Answers from', 'Tracer 2026'])));
      expect(rows, contains(equals(['Privacy', personalDataNotice])));
      final headers = GtsListTables.headers(r);
      final header = rows.indexWhere(
        (row) => row.join('\u0000') == headers.join('\u0000'),
      );
      expect(header, greaterThan(0));
      expect(rows[header - 1], isEmpty);
      expect(rows.sublist(header + 1, header + 6), GtsListTables.rows(r));
      expect(rows[header + 6], isEmpty);
      expect(rows[header + 7], ['Tally']);
      expect(rows[header + 8], GtsListTables.tallyHeaders);
      expect(rows.sublist(header + 9), [
        ['Employed', '1', '20.0%'],
        ['Not employed', '1', '20.0%'],
        ['Never employed', '1', '20.0%'],
        ['Untracked – registered, not yet answered', '1', '20.0%'],
        ['Untracked – not registered', '1', '20.0%'],
        [GtsListTables.totalLabel, '5', '100%'],
        [GtsListTables.responseRateLabel, '3 of 5', '60.0%'],
        [GtsListTables.employmentRateLabel, '1 of 3', '33.3%'],
      ]);
    });

    test('the example row reads as on screen', () {
      final rows = _csv(_build());
      expect(
        rows,
        contains(
          equals([
            '2023',
            'Juan Dela Cruz',
            'Yes',
            'AI engineer, team lead',
            'Others: =HYPERLINK("http://x","y")',
            'Employed',
          ]),
        ),
      );
      expect(
        rows,
        contains(
          equals([
            '2024',
            'Jose Rizal',
            '',
            '',
            '',
            'Untracked – not registered',
          ]),
        ),
      );
    });

    test('tally counts are numbers in Excel', () {
      final book = Excel.decodeBytes(GtsListExportService.toExcel(_build()));
      final rows = book.tables['Alumni list']!.rows;
      final total = rows.firstWhere(
        (r) => r.first?.value?.toString() == GtsListTables.totalLabel,
      );
      expect(total[1]?.value, isA<num>());
      expect(total[1]?.value, 5);
    });

    test('Excel explains every column with its question', () {
      final notes = _excel(_build(), 'Columns');
      expect(notes.first, ['Column', 'Question or source']);
      expect(
        notes,
        contains(
          equals(['16. Presently employed', 'Are you presently employed?']),
        ),
      );
    });

    test('subtotals print one block per group, overall last', () {
      final r = _build(
        config: const GtsListConfig(
          surveyId: 'w2',
          subtotalBy: GtsListSubtotal.batch,
        ),
      );
      final headings = [
        for (final row in _csv(r))
          if (row.length == 1 &&
              (row.first.startsWith('Batch ') || row.first == 'Overall'))
            row.first,
      ];
      expect(headings, ['Batch 2023', 'Batch 2024', 'Overall']);
      expect(_excel(r), _csv(r));
    });

    test('PDF has the rows, the tally and the privacy footer', () async {
      final text = await _pdfText(_build());
      for (final s in [
        'Juan Dela Cruz',
        'Jose Rizal',
        'AI engineer, team lead',
        'Untracked - not registered',
        'Total alumni',
        '3 of 5',
        '33.3%',
        'Contains personal data',
        'RA 10173',
      ]) {
        expect(text, contains(s), reason: s);
      }
    });

    test('the PDF is landscape', () async {
      final bytes = await GtsListExportService.toPdf(_build());
      expect(
        latin1.decode(bytes),
        matches(RegExp(r'/MediaBox\s*\[\s*0\s+0\s+841\.8')),
      );
    });
  });

  group('safety and limits', () {
    test('CSV text never runs as a spreadsheet formula', () {
      final r = _build(
        responses: [
          _response('u1', {'ched_16': 'Yes', 'ched_19': '=SUM(A1)'}),
        ],
      );
      expect(GtsListExportService.toCsv(r), contains("'=SUM(A1)"));
    });

    test('past 1000 rows the PDF says so; CSV has everyone', () async {
      final r = _build(
        roster: [
          for (var i = 0; i < 1100; i++)
            _member('Graduate ${i.toString().padLeft(4, '0')}'),
        ],
        responses: const [],
        config: const GtsListConfig(surveyId: 'w2', chart: GtsListChart.none),
      );
      final csv = _csv(r);
      expect(
        csv.where((row) => row.length > 1 && row[1].startsWith('Graduate ')),
        hasLength(1100),
      );
      final text = await _pdfText(r);
      expect(text, contains('The PDF shows the'));
      expect(text, contains('1100'));
    });

    test('wide lists warn in the PDF', () async {
      final r = _build(
        config: GtsListConfig(
          surveyId: 'w2',
          columns: ['name', for (var i = 1; i <= 12; i++) 'ched_$i'],
        ),
      );
      expect(await _pdfText(r), contains('Excel is easier to read'));
    });

    test('off-roster responders are explained', () {
      final r = _build(
        responses: [
          ..._responses,
          _response('u9', {'ched_16': 'Yes', 'ched_1': 'Off Roster'}),
        ],
      );
      final text = GtsListExportService.toCsv(r);
      expect(text, contains('Answered – not on active roster'));
      expect(text, contains(GtsListTables.offRosterNote));
    });

    test('file names', () {
      final excel = CustomReportFormat.excel;
      expect(
        GtsListExportService.fileName(_build(), excel),
        'alumni_list_20261014.xlsx',
      );
      expect(
        GtsListExportService.fileName(
          _build(
            config: const GtsListConfig(
              surveyId: 'w2',
              title: 'Employment status: all alumni!',
            ),
          ),
          CustomReportFormat.pdf,
        ),
        'alumni_list_employment_status_all_alumni_20261014.pdf',
      );
    });

    test('about lines name the filters and the order', () {
      final about = {
        for (final (k, v) in GtsListTables.about(
          _build(
            config: const GtsListConfig(
              surveyId: 'w2',
              statuses: [GtsTracerStatus.untrackedNotRegistered],
              batches: ['2024'],
              sortBy: 'name',
              sortDescending: true,
            ),
          ),
        ))
          k: v,
      };
      expect(
        about['Filters'],
        'Tracer status: Untracked – not registered; Batch: 2024',
      );
      expect(about['Order'], 'Name (Z to A)');
      expect(about['Alumni'], '1 on the active roster');
    });
  });

  testWidgets('downloads ask for the personal-data confirmation first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GtsAlumniListPanel(
              waves: [
                Survey(
                  id: 'w2',
                  title: 'Tracer 2026',
                  description: '',
                  status: SurveyStatus.published,
                  createdBy: 'admin',
                  createdAt: DateTime(2026),
                  kind: 'ched_gts_builtin',
                ),
              ],
              roster: _roster,
              loadResponses: (ids) async => _responses,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(CustomReportFormat.excel.label));
    await tester.pumpAndSettle();
    expect(find.text('This file contains personal data'), findsOneWidget);
    expect(
      find.textContaining('This alumni list lists graduates'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('This file contains personal data'), findsNothing);
  });
}
