import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_tables.dart';
import 'package:alumni_system/features/admin/reports/data/gts_list_data_service.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_alumni_list_panel.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_builder_mode_switch.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

Survey _wave(String id, String title) => Survey(
  id: id,
  title: title,
  description: '',
  status: SurveyStatus.published,
  createdBy: 'admin',
  createdAt: DateTime(2026),
  kind: 'ched_gts_builtin',
);

final _waves = [_wave('w2', 'Tracer 2026'), _wave('w1', 'Tracer 2025')];

AlumniMember _member(
  String name, {
  String batch = '2023',
  String course = 'BSIT',
  String? uid,
  bool registered = true,
  String? yearGraduated,
}) => AlumniMember(
  id: 'm-$name',
  fullName: name,
  course: course,
  studentId: 'S-$name',
  authUid: uid,
  isRegisteredUser: registered,
  batchYear: batch,
  yearGraduated: yearGraduated,
  createdAt: DateTime(2020),
);

final _roster = [
  _member('Juan Dela Cruz', uid: 'u1'),
  _member('Maria Santos', uid: 'u2'),
  _member('Pedro Reyes', batch: '2024', course: 'BSCS', uid: 'u3'),
  _member('Ana Lopez', batch: '2024', course: 'BSCS', uid: 'u4'),
  _member('Jose Rizal', batch: '2024', registered: false),
];

GtsListResponse _response(
  String uid,
  String wave,
  Map<String, dynamic> answers,
) => GtsListResponse(
  userId: uid,
  surveyId: wave,
  responseId: '$uid-$wave',
  submittedAt: DateTime(2026, wave == 'w2' ? 6 : 1),
  answers: answers,
);

final _responses = [
  _response('u1', 'w2', {'ched_16': 'Yes', 'ched_19': 'AI engineer'}),
  _response('u2', 'w2', {'ched_16': 'No'}),
  _response('u3', 'w2', {'ched_16': 'Never Employed'}),
  _response('u4', 'w1', {'ched_16': 'Yes', 'ched_19': 'Nurse'}),
];

Future<List<List<String>>> _pump(
  WidgetTester tester, {
  List<AlumniMember>? roster,
  GtsListConfig? initial,
  GtsListResponseLoader? loader,
  List<GtsListConfig>? changes,
}) async {
  final calls = <List<String>>[];
  tester.view.physicalSize = const Size(1600, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GtsAlumniListPanel(
            waves: _waves,
            roster: roster ?? _roster,
            initialConfig: initial,
            onConfigChanged: changes?.add,
            loadResponses:
                loader ??
                (ids) async {
                  calls.add(ids);
                  return [
                    for (final r in _responses)
                      if (ids.contains(r.surveyId)) r,
                  ];
                },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

Finder _inTable(String text) => find.descendant(
  of: find.byType(DataTable).first,
  matching: find.text(text),
);

void main() {
  group('settings', () {
    test('the chart choice round-trips; bars by default', () {
      const config = GtsListConfig(surveyId: 'w2', chart: GtsListChart.donut);
      expect(GtsListConfig.fromJson(config.toJson()).chart, GtsListChart.donut);
      expect(const GtsListConfig().chart, GtsListChart.bars);
      expect(
        GtsListConfig.fromJson(const {'mode': 'list'}).chart,
        GtsListChart.bars,
      );
    });

    test('batch falls back to year graduated, as the Tracer tab filter', () {
      final result = GtsAlumniList.build(
        const GtsListConfig(surveyId: 'w2', batches: ['2022']),
        roster: [
          _member('Old Record', batch: '', yearGraduated: '2022'),
          _member('No Year', batch: ''),
        ],
        responses: const [],
        waveIds: const ['w2'],
      );
      expect([for (final r in result.rows) r.batch], ['2022']);
    });
  });

  group('tally text', () {
    test('matches the plan example: 5 alumni, 3 answered, 1 employed', () {
      final result = GtsAlumniList.build(
        const GtsListConfig(surveyId: 'w2'),
        roster: _roster,
        responses: _responses,
        waveIds: const ['w2', 'w1'],
      );
      final lines = {
        for (final l in GtsListTables.tally(result.tally))
          l.label: '${l.count} | ${l.share}',
      };
      expect(lines, {
        'Employed': '1 | 20.0%',
        'Not employed': '1 | 20.0%',
        'Never employed': '1 | 20.0%',
        'Untracked – registered, not yet answered': '1 | 20.0%',
        'Untracked – not registered': '1 | 20.0%',
        GtsListTables.totalLabel: '5 | 100%',
        GtsListTables.responseRateLabel: '3 of 5 | 60.0%',
        GtsListTables.employmentRateLabel: '1 of 3 | 33.3%',
      });
    });

    test('an empty list has no shares', () {
      final result = GtsAlumniList.build(
        const GtsListConfig(surveyId: 'w2'),
        roster: const [],
        responses: const [],
        waveIds: const ['w2'],
      );
      final tally = GtsListTables.tally(result.tally);
      expect(tally.firstWhere((l) => l.isTotal).share, '–');
      expect(tally.where((l) => l.isRate).map((l) => l.share), ['–', '–']);
    });

    test('scope names the wave, or latest from any wave', () {
      GtsAlumniListResult build(GtsListConfig c) => GtsAlumniList.build(
        c,
        roster: const [],
        responses: const [],
        waveIds: const ['w2'],
        waveLabels: const {'w2': 'Tracer 2026'},
      );
      expect(
        GtsListTables.scope(build(const GtsListConfig(surveyId: 'w2'))),
        'Tracer 2026',
      );
      expect(
        GtsListTables.scope(build(const GtsListConfig())),
        GtsListTables.latestWave,
      );
      expect(
        GtsListTables.title(build(const GtsListConfig(title: '  '))),
        GtsListTables.defaultTitle,
      );
    });

    test('the status chart counts each tally line', () {
      GtsAlumniListResult build(GtsListChart chart) => GtsAlumniList.build(
        GtsListConfig(surveyId: 'w2', chart: chart),
        roster: _roster,
        responses: _responses,
        waveIds: const ['w2', 'w1'],
      );
      final bars = GtsListTables.chart(build(GtsListChart.bars))!;
      expect(bars.type, GtsChartType.horizontalBar);
      expect(bars.labels.first, 'Employed');
      expect(bars.series.single.values, [1, 1, 1, 1, 1]);
      expect(
        GtsListTables.chart(build(GtsListChart.donut))!.type,
        GtsChartType.donut,
      );
      expect(GtsListTables.chart(build(GtsListChart.none)), isNull);
    });
  });

  group('loading responses', () {
    test('rows become responses; incomplete rows are skipped', () {
      final list = GtsListDataService.responsesFromRows([
        {
          'id': 'r1',
          'survey_id': 'w2',
          'user_id': 'u1',
          'submitted_at': '2026-06-01T02:00:00Z',
          'answers': {'ched_16': 'Yes'},
        },
        {'id': 'r2', 'survey_id': 'w2', 'user_id': '', 'answers': {}},
        {'id': 'r3', 'survey_id': 'w2', 'user_id': 'u3', 'answers': null},
      ]);
      expect(list.map((r) => r.userId), ['u1', 'u3']);
      expect(list.first.answers, {'ched_16': 'Yes'});
      expect(list.first.submittedAt, DateTime.utc(2026, 6, 1, 2));
      expect(list.last.answers, isEmpty);
    });
  });

  group('panel', () {
    testWidgets('lists every alumnus with the default columns and tally', (
      tester,
    ) async {
      final calls = await _pump(tester);
      expect(calls, [
        ['w2'],
      ]);
      for (final header in ['Batch', 'Name', 'Course', 'Tracer status']) {
        expect(_inTable(header), findsOneWidget);
      }
      for (final name in [
        'Juan Dela Cruz',
        'Maria Santos',
        'Pedro Reyes',
        'Ana Lopez',
        'Jose Rizal',
      ]) {
        expect(_inTable(name), findsOneWidget);
      }
      expect(find.text(GtsListTables.totalLabel), findsOneWidget);
      expect(find.text('3 of 5'), findsOneWidget);
      expect(
        find.textContaining('Tracer 2026 · 5 alumni on the active roster'),
        findsOneWidget,
      );
    });

    testWidgets('latest from any wave loads every wave and adds the wave '
        'column', (tester) async {
      final changes = <GtsListConfig>[];
      final calls = await _pump(tester, changes: changes);
      await tester.tap(find.text('Tracer 2026').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(GtsListTables.latestWave).last);
      await tester.pumpAndSettle();
      expect(calls.last, ['w1']);
      expect(changes.last.latestFromAnyWave, isTrue);
      expect(_inTable('Wave answered'), findsOneWidget);
      expect(_inTable('Tracer 2025'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('columns are added from the picker and removed from the '
        'list', (tester) async {
      final changes = <GtsListConfig>[];
      await _pump(tester, changes: changes);
      await tester.tap(find.text('Add or remove columns'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'occupation');
      await tester.pumpAndSettle();
      await tester.tap(find.text('19. Present occupation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use these columns'));
      await tester.pumpAndSettle();
      expect(changes.last.columns.last, 'ched_19');
      expect(_inTable('19. Present occupation'), findsOneWidget);
      expect(_inTable('AI engineer'), findsOneWidget);
      expect(_inTable('Not asked'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Remove column').first);
      await tester.pumpAndSettle();
      expect(changes.last.columns.first, GtsListConfig.nameColumn);
      expect(_inTable('Batch'), findsNothing);
    });

    testWidgets('select all adds a whole section', (tester) async {
      final changes = <GtsListConfig>[];
      await _pump(tester, changes: changes);
      await tester.tap(find.text('Add or remove columns'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'training(s)/advance',
      );
      await tester.pumpAndSettle();
      expect(find.text('Select all'), findsOneWidget);
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(find.text('Clear section'), findsOneWidget);
      await tester.tap(find.text('Use these columns'));
      await tester.pumpAndSettle();
      expect(changes.last.columns.take(4), GtsListConfig.defaultColumns);
      expect(changes.last.columns, containsAll(['ched_15a', 'ched_15b']));
    });

    testWidgets('the status filter lists only the untracked', (tester) async {
      await _pump(tester);
      await tester.tap(
        find.widgetWithText(FilterChip, 'Untracked – not registered'),
      );
      await tester.pumpAndSettle();
      expect(_inTable('Jose Rizal'), findsOneWidget);
      expect(_inTable('Juan Dela Cruz'), findsNothing);
      expect(find.textContaining('(filtered)'), findsOneWidget);
    });

    testWidgets('subtotals by batch add a column per batch', (tester) async {
      await _pump(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'By batch'));
      await tester.pumpAndSettle();
      expect(find.text('Tracer status by batch'), findsOneWidget);
      expect(find.text('Overall'), findsOneWidget);
      expect(find.text('2 (100%)'), findsOneWidget);
      expect(find.text('3 (100%)'), findsOneWidget);
    });

    testWidgets('a failed load offers to try again', (tester) async {
      var fail = true;
      await _pump(
        tester,
        loader: (ids) async {
          if (fail) throw Exception('offline');
          return _responses;
        },
      );
      expect(
        find.textContaining('Could not load tracer responses'),
        findsOneWidget,
      );
      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(_inTable('Juan Dela Cruz'), findsOneWidget);
    });

    testWidgets('long lists show 200 rows at a time; the tally covers all', (
      tester,
    ) async {
      await _pump(
        tester,
        roster: [
          for (var i = 0; i < 450; i++)
            _member('Graduate ${i.toString().padLeft(3, '0')}'),
        ],
        loader: (ids) async => const [],
      );
      expect(find.text('Showing the first 200 of 450 alumni.'), findsOneWidget);
      expect(find.text('0 of 450'), findsOneWidget);
      await tester.ensureVisible(find.text('Show 200 more'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show 200 more'));
      await tester.pumpAndSettle();
      expect(find.text('Showing the first 400 of 450 alumni.'), findsOneWidget);
      expect(find.text('Show 50 more'), findsOneWidget);
    });

    testWidgets('a saved wave that no longer exists falls back to the newest', (
      tester,
    ) async {
      final calls = await _pump(
        tester,
        initial: const GtsListConfig(surveyId: 'gone'),
      );
      expect(calls, [
        ['w2'],
      ]);
    });
  });

  testWidgets('the mode switch names both purposes', (tester) async {
    GtsBuilderMode? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GtsBuilderModeSwitch(
            mode: GtsBuilderMode.list,
            onChanged: (m) => picked = m,
          ),
        ),
      ),
    );
    expect(find.text('Who answered and what they said'), findsOneWidget);
    await tester.tap(find.text('Summary & charts'));
    expect(picked, GtsBuilderMode.summary);
  });

  test('answer filters keep the report filter shape', () {
    const config = GtsListConfig(
      surveyId: 'w2',
      answerFilters: [
        GtsReportFilter(field: 'ched_16', values: ['Yes']),
      ],
    );
    expect(
      GtsListConfig.fromJson(config.toJson()).answerFilters.single.values,
      ['Yes'],
    );
  });
}
