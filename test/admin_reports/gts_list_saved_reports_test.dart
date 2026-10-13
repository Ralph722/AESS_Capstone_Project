import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_columns.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_templates.dart';
import 'package:alumni_system/features/admin/reports/data/gts_saved_report_service.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_alumni_list_panel.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_report_builder.dart';
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

final _roster = [
  AlumniMember(
    id: 'm1',
    fullName: 'Juan Dela Cruz',
    course: 'BSIT',
    studentId: 'S-1',
    authUid: 'u1',
    isRegisteredUser: true,
    batchYear: '2023',
    createdAt: DateTime(2020),
  ),
];

/// In-memory store with the database's name rule (case and spaces ignored).
class _FakeStore implements GtsSavedReportStore {
  final reports = <GtsSavedReport>[];
  var _next = 0;

  static String _key(String name) => name.trim().toLowerCase();

  GtsSavedReport add(String name, Map<String, dynamic> config) {
    final r = GtsSavedReport(id: 'r${_next++}', name: name, config: config);
    reports.add(r);
    return r;
  }

  @override
  Future<List<GtsSavedReport>> list() async =>
      [...reports]..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<GtsSavedReport> save({
    String? id,
    required String name,
    required Map<String, dynamic> settings,
  }) async {
    final trimmed = name.trim();
    if (reports.any((r) => r.id != id && _key(r.name) == _key(trimmed))) {
      throw GtsSavedReportNameTaken(trimmed);
    }
    final saved = GtsSavedReport(
      id: id ?? 'r${_next++}',
      name: trimmed,
      config: settings,
    );
    reports
      ..removeWhere((r) => r.id == saved.id)
      ..add(saved);
    return saved;
  }

  @override
  Future<void> delete(String id) async =>
      reports.removeWhere((r) => r.id == id);
}

Map<String, dynamic> _summaryJson(String title) => GtsReportConfig(
  surveyIds: const ['w2'],
  measure: 'ched_16',
  title: title,
).toJson();

Future<void> _pumpList(
  WidgetTester tester, {
  required _FakeStore store,
  List<GtsListConfig>? changes,
  List<GtsSavedReport?>? opened,
  List<GtsSavedReport>? others,
}) async {
  tester.view.physicalSize = const Size(1600, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GtsAlumniListPanel(
            waves: _waves,
            roster: _roster,
            loadResponses: (_) async => const <GtsListResponse>[],
            savedReports: store,
            onConfigChanged: changes?.add,
            onOpenChanged: opened?.add,
            onOpenSummary: others?.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _savedDropdown() => find.byWidgetPredicate(
  (w) =>
      w is DropdownButtonFormField<String> &&
      (w.key as ValueKey<String>?)?.value.startsWith('saved-') == true,
);

Future<void> _openSaved(WidgetTester tester, String name) async {
  await tester.tap(_savedDropdown());
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _nameAndSave(WidgetTester tester, String name) async {
  final dialog = find.byType(AlertDialog);
  await tester.enterText(
    find.descendant(of: dialog, matching: find.byType(TextField)),
    name,
  );
  await tester.pump();
  await tester.tap(
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(FilledButton, 'Save'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('templates', () {
    test('every template uses known columns and a unique key', () {
      final keys = <String>{};
      for (final t in GtsListTemplates.all) {
        expect(keys.add(t.key), isTrue, reason: t.key);
        expect(t.config.templateKey, t.key);
        expect(t.config.title, t.name);
        expect(t.config.description, isNotEmpty);
        expect(GtsListColumns.unknownKeys(t.config), isEmpty, reason: t.key);
        expect(t.config.columns, isNotEmpty);
        expect(GtsListTemplates.byKey(t.key), same(t));
      }
      expect(GtsListTemplates.byKey('nope'), isNull);
      expect(GtsListTemplates.byKey(null), isNull);
    });

    test('forWave picks one wave or the latest from any wave', () {
      final t = GtsListTemplates.all.first;
      expect(t.forWave('w1').surveyId, 'w1');
      expect(t.forWave('w1').latestFromAnyWave, isFalse);
      expect(t.forWave(null).latestFromAnyWave, isTrue);
      expect(t.forWave('w1').columns, t.config.columns);
    });

    test('the follow-up template lists only untracked alumni', () {
      final t = GtsListTemplates.byKey('list_untracked_follow_up')!;
      expect(t.config.statuses, {
        GtsTracerStatus.untrackedRegistered,
        GtsTracerStatus.untrackedNotRegistered,
      });
      expect(t.config.columns, contains(GtsListColumns.emailColumn));
    });
  });

  group('GtsSavedReport kinds', () {
    test('a saved list round-trips and is not read as a summary', () {
      final config = GtsListTemplates.all.first.forWave('w2');
      final report = GtsSavedReport.fromRow({
        'id': 'a',
        'name': 'List',
        'config': config.toJson(),
      });
      expect(report.isList, isTrue);
      expect(report.listSettings.toJson(), config.toJson());
      expect(() => report.settings, throwsFormatException);
    });

    test('a saved summary report is not a list', () {
      final report = GtsSavedReport.fromRow({
        'id': 'b',
        'name': 'Summary',
        'config': _summaryJson('Summary'),
      });
      expect(report.isList, isFalse);
      expect(report.settings.measure, 'ched_16');
    });
  });

  group('alumni list saved reports', () {
    testWidgets('saving stores list settings under the given name', (
      tester,
    ) async {
      final store = _FakeStore();
      final changes = <GtsListConfig>[];
      final opened = <GtsSavedReport?>[];
      await _pumpList(tester, store: store, changes: changes, opened: opened);
      expect(find.text('No saved reports yet'), findsOneWidget);

      await tester.tap(find.text('Save report'));
      await tester.pumpAndSettle();
      await _nameAndSave(tester, '  Batch 2023 list ');

      final saved = store.reports.single;
      expect(saved.name, 'Batch 2023 list');
      expect(saved.isList, isTrue);
      expect(saved.listSettings.surveyId, 'w2');
      expect(saved.listSettings.title, 'Batch 2023 list');
      expect(changes.last.title, 'Batch 2023 list');
      expect(opened.last?.id, saved.id);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('opening applies the settings; edits show unsaved changes', (
      tester,
    ) async {
      final store = _FakeStore()
        ..add(
          'Job details',
          GtsListTemplates.byKey(
            'list_employed_job_details',
          )!.forWave('w1').copyWith(title: 'Job details').toJson(),
        );
      final changes = <GtsListConfig>[];
      await _pumpList(tester, store: store, changes: changes);
      await _openSaved(tester, 'Job details');

      expect(changes.last.surveyId, 'w1');
      expect(changes.last.columns, contains('ched_19'));
      expect(changes.last.title, 'Job details');
      expect(find.text('Unsaved changes'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Report name (optional)'),
        'Renamed',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'BSIT').first);
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(store.reports, hasLength(1));
      expect(store.reports.single.name, 'Renamed');
      expect(store.reports.single.listSettings.courses, ['BSIT']);
      expect(find.text('Unsaved changes'), findsNothing);
    });

    testWidgets('a missing wave falls back to the newest with a message', (
      tester,
    ) async {
      final store = _FakeStore()
        ..add(
          'Old list',
          const GtsListConfig(surveyId: 'gone', title: 'Old list').toJson(),
        );
      final changes = <GtsListConfig>[];
      await _pumpList(tester, store: store, changes: changes);
      await _openSaved(tester, 'Old list');

      expect(changes.last.surveyId, 'w2');
      expect(
        find.textContaining('no longer available; the newest wave'),
        findsOneWidget,
      );
      expect(find.text('Unsaved changes'), findsOneWidget);
    });

    testWidgets('a template fills in the settings and keeps the wave', (
      tester,
    ) async {
      final changes = <GtsListConfig>[];
      await _pumpList(tester, store: _FakeStore(), changes: changes);
      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Start from a ready-made list',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Untracked alumni for follow-up').last);
      await tester.pumpAndSettle();

      final t = GtsListTemplates.byKey('list_untracked_follow_up')!;
      expect(changes.last.templateKey, t.key);
      expect(changes.last.surveyId, 'w2');
      expect(changes.last.columns, t.config.columns);
      expect(changes.last.statuses, t.config.statuses);
      expect(find.textContaining(t.summary), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Report name (optional)'),
            )
            .controller!
            .text,
        t.name,
      );
    });

    testWidgets('summary reports are listed and handed to the other mode', (
      tester,
    ) async {
      final store = _FakeStore()
        ..add('A summary', _summaryJson('A summary'))
        ..add('A list', const GtsListConfig(surveyId: 'w2').toJson());
      final others = <GtsSavedReport>[];
      final changes = <GtsListConfig>[];
      await _pumpList(tester, store: store, others: others, changes: changes);
      await _openSaved(tester, 'A summary');

      expect(others.single.name, 'A summary');
      expect(changes, isEmpty);
    });

    testWidgets('summary reports are hidden without the other mode', (
      tester,
    ) async {
      final store = _FakeStore()
        ..add('A summary', _summaryJson('A summary'))
        ..add('A list', const GtsListConfig(surveyId: 'w2').toJson());
      await _pumpList(tester, store: store);
      await tester.tap(_savedDropdown());
      await tester.pumpAndSettle();
      expect(find.text('A list'), findsWidgets);
      expect(find.text('A summary'), findsNothing);
    });
  });

  group('summary builder', () {
    Future<void> pump(
      WidgetTester tester,
      _FakeStore store, {
      ValueChanged<GtsSavedReport>? onOpenList,
    }) async {
      tester.view.physicalSize = const Size(1400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GtsReportBuilderPanel(
                waves: _waves,
                savedReports: store,
                onOpenList: onOpenList,
                loadRespondents: (_) async => const <GtsRespondent>[],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists are opened in the alumni list mode', (tester) async {
      final store = _FakeStore()
        ..add('A summary', _summaryJson('A summary'))
        ..add('A list', const GtsListConfig(surveyId: 'w2').toJson());
      final lists = <GtsSavedReport>[];
      await pump(tester, store, onOpenList: lists.add);
      await _openSaved(tester, 'A list');
      expect(lists.single.isList, isTrue);
    });

    testWidgets('lists are hidden without the list mode', (tester) async {
      final store = _FakeStore()
        ..add('A summary', _summaryJson('A summary'))
        ..add('A list', const GtsListConfig(surveyId: 'w2').toJson());
      await pump(tester, store);
      await tester.tap(_savedDropdown());
      await tester.pumpAndSettle();
      expect(find.text('A summary'), findsWidgets);
      expect(find.text('A list'), findsNothing);
    });
  });
}
