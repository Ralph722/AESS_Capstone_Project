import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/reports/data/gts_saved_report_service.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_report_builder.dart';
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

List<GtsRespondent> _respondents(String surveyId) => [
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

void main() {
  final waves = [_wave('w2', '2026 tracer'), _wave('w1', '2025 tracer')];

  group('GtsSavedReport', () {
    test('maps a database row and round-trips the settings', () {
      const config = GtsReportConfig(
        surveyIds: ['w1'],
        measure: 'ched_18',
        groupBy: ['course'],
        filters: [
          GtsReportFilter(field: 'ched_16', values: ['Yes']),
        ],
        title: 'Employment type by course',
      );
      final report = GtsSavedReport.fromRow({
        'id': 'abc',
        'name': 'Employment type by course',
        'config': config.toJson(),
        'updated_at': '2026-10-12T03:00:00Z',
      });
      expect(report.id, 'abc');
      expect(report.name, 'Employment type by course');
      expect(report.updatedAt, DateTime.utc(2026, 10, 12, 3));
      expect(report.settings.toJson(), config.toJson());
    });

    test('settings from a newer app version are refused', () {
      final report = GtsSavedReport.fromRow({
        'id': 'x',
        'name': 'Future',
        'config': {
          ...const GtsReportConfig(
            surveyIds: ['w1'],
            measure: 'ched_16',
          ).toJson(),
          'version': GtsReportConfig.currentVersion + 1,
        },
      });
      expect(() => report.settings, throwsFormatException);
    });
  });

  group('Builder saved reports', () {
    Future<void> pump(
      WidgetTester tester, {
      GtsSavedReportStore? store,
      List<GtsReportConfig>? changes,
    }) async {
      tester.view.physicalSize = const Size(1400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GtsReportBuilderPanel(
                waves: waves,
                savedReports: store,
                onConfigChanged: changes?.add,
                loadRespondents: (ids) async => [
                  for (final id in ids) ..._respondents(id),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openSaved(WidgetTester tester, String name) async {
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<String> &&
              w.key == const ValueKey('saved-null-1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    Future<void> nameAndSave(WidgetTester tester, String name) async {
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

    testWidgets('hidden when no store is given', (tester) async {
      await pump(tester);
      expect(find.text('Save report'), findsNothing);
      expect(find.text('Saved reports'), findsNothing);
    });

    testWidgets('saving asks for a name and stores the settings', (
      tester,
    ) async {
      final store = _FakeStore();
      final changes = <GtsReportConfig>[];
      await pump(tester, store: store, changes: changes);
      expect(find.text('No saved reports yet'), findsOneWidget);

      await tester.tap(find.text('Save report'));
      await tester.pumpAndSettle();
      await nameAndSave(tester, '  Employment 2026  ');

      expect(store.reports, hasLength(1));
      final saved = store.reports.single;
      expect(saved.name, 'Employment 2026');
      expect(saved.settings.measure, 'ched_16');
      expect(saved.settings.surveyIds, ['w2']);
      expect(saved.settings.title, 'Employment 2026');
      expect(changes.last.title, 'Employment 2026');
      expect(find.text('Saved "Employment 2026".'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Save as new'), findsOneWidget);
    });

    testWidgets('opening drops waves that are no longer available', (
      tester,
    ) async {
      final store = _FakeStore()
        ..add(
          'Old report',
          const GtsReportConfig(
            surveyIds: ['w2', 'gone'],
            measure: 'ched_18',
            title: 'Old report',
          ).toJson(),
        );
      final changes = <GtsReportConfig>[];
      await pump(tester, store: store, changes: changes);
      await openSaved(tester, 'Old report');

      expect(changes.last.surveyIds, ['w2']);
      expect(changes.last.measure, 'ched_18');
      expect(changes.last.title, 'Old report');
      expect(
        find.text(
          '1 tracer wave in this report is no longer available and was '
          'removed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings from a newer version are not applied', (
      tester,
    ) async {
      final store = _FakeStore()
        ..add('Future', {
          ...const GtsReportConfig(
            surveyIds: ['w2'],
            measure: 'ched_18',
          ).toJson(),
          'version': GtsReportConfig.currentVersion + 1,
        });
      final changes = <GtsReportConfig>[];
      await pump(tester, store: store, changes: changes);
      await openSaved(tester, 'Future');

      expect(changes, isEmpty);
      expect(find.textContaining('newer version of AESS'), findsOneWidget);
    });

    testWidgets('changes are saved to the opened report', (tester) async {
      final store = _FakeStore()
        ..add(
          'Mine',
          const GtsReportConfig(
            surveyIds: ['w2'],
            measure: 'ched_16',
            title: 'Mine',
          ).toJson(),
        );
      await pump(tester, store: store);
      await openSaved(tester, 'Mine');
      expect(find.text('Unsaved changes'), findsNothing);

      await tester.tap(find.text('Compare waves'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(store.reports, hasLength(1));
      expect(store.reports.single.settings.surveyIds, ['w2', 'w1']);
      expect(find.text('Unsaved changes'), findsNothing);
    });

    testWidgets('a name already in use is refused with a message', (
      tester,
    ) async {
      final store = _FakeStore()
        ..add(
          'Employment',
          const GtsReportConfig(surveyIds: ['w2'], measure: 'ched_16').toJson(),
        );
      await pump(tester, store: store);
      await tester.tap(find.text('Save report'));
      await tester.pumpAndSettle();
      await nameAndSave(tester, ' employment ');

      expect(store.reports, hasLength(1));
      expect(
        find.textContaining('A saved report named "employment" already exists'),
        findsOneWidget,
      );
      expect(find.text('Save report'), findsOneWidget);
    });

    testWidgets('delete asks first and then removes the report', (
      tester,
    ) async {
      final store = _FakeStore()
        ..add(
          'Mine',
          const GtsReportConfig(surveyIds: ['w2'], measure: 'ched_16').toJson(),
        );
      await pump(tester, store: store);
      await openSaved(tester, 'Mine');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete saved report?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.reports, hasLength(1));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(store.reports, isEmpty);
      expect(find.text('Deleted "Mine".'), findsOneWidget);
      expect(find.text('Save report'), findsOneWidget);
    });
  });
}
