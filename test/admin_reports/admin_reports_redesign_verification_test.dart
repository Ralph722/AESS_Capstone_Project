import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/data/gts_saved_report_service.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_alumni_list_panel.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_builder_mode_switch.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_report_preview.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_saved_reports_bar.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_bento.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_downloads_panel.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';

class _FakeStore implements GtsSavedReportStore {
  final reports = <GtsSavedReport>[];
  var _next = 0;

  @override
  Future<List<GtsSavedReport>> list() async => [...reports];

  @override
  Future<GtsSavedReport> save({
    String? id,
    required String name,
    required Map<String, dynamic> settings,
  }) async {
    final saved = GtsSavedReport(
      id: id ?? 'r${_next++}',
      name: name,
      config: settings,
    );
    reports.add(saved);
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    reports.removeWhere((r) => r.id == id);
  }
}

void main() {
  group('Reports & Analytics Redesign Verification (Phase 5)', () {
    testWidgets('ReportsSegmentedToggle renders options and triggers onChanged', (tester) async {
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ReportsSegmentedToggle(
                options: const ['Outcomes', 'Career path', 'Cohorts & waves'],
                selected: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Outcomes'), findsOneWidget);
      expect(find.text('Career path'), findsOneWidget);
      expect(find.text('Cohorts & waves'), findsOneWidget);

      await tester.tap(find.text('Career path'));
      await tester.pumpAndSettle();
      expect(selected, 1);

      await tester.tap(find.text('Cohorts & waves'));
      await tester.pumpAndSettle();
      expect(selected, 2);
    });

    testWidgets('ReportsStatCard renders metric value, pill badge, and breakdown rows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportsStatCard(
              label: 'Tracer reach',
              value: '85%',
              icon: Icons.school_outlined,
              accent: const Color(0xFF1E3A8A),
              pillLabel: 'Healthy',
              pillColor: const Color(0xFF10B981),
              rows: const [
                ReportsStatRow('Took tracer', '340'),
                ReportsStatRow('Registered, no tracer', '60'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('TRACER REACH'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
      expect(find.text('Healthy'), findsOneWidget);
      expect(find.text('Took tracer'), findsOneWidget);
      expect(find.text('340'), findsOneWidget);
      expect(find.text('Registered, no tracer'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
    });

    testWidgets('ReportsDownloadsPanel renders scope bar, presets, and export buttons', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final downloads = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportsDownloadsPanel(
                filterLabel: 'Batch 2024 · BSIT',
                chedWaveCount: 2,
                rowCounts: const {
                  CustomReportSectionId.executiveKpis: 1,
                  CustomReportSectionId.surveySummary: 2,
                  CustomReportSectionId.employmentRecords: 45,
                  CustomReportSectionId.alumniRoster: 100,
                },
                onDownload: (preset, {required format, required printPreview}) async {
                  downloads.add('${preset.id}:${format.name}:$printPreview');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Exports use: Batch 2024 · BSIT'), findsOneWidget);
      expect(find.text('CHED GTS institutional summary'), findsOneWidget);
      expect(find.text('Graduate employment report'), findsOneWidget);
      expect(find.text('Curriculum relevance report'), findsOneWidget);
      expect(find.text('First-job and salary report'), findsOneWidget);
      expect(find.text('Program and cohort comparison'), findsOneWidget);
      expect(find.text('GTS participation and data quality'), findsOneWidget);
      expect(find.text('Portal executive snapshot'), findsOneWidget);
      expect(find.text('CHED wave comparison'), findsOneWidget);
      expect(find.text('Active roster extract'), findsOneWidget);
      expect(find.text('INSTITUTIONAL GTS'), findsOneWidget);
      expect(find.text('COMPARISONS AND DATA QUALITY'), findsOneWidget);
      expect(find.text('OPERATIONS'), findsOneWidget);

      // Verify format buttons exist (PDF, Excel, CSV, Print)
      expect(find.text('PDF'), findsWidgets);
      expect(find.text('Excel'), findsWidgets);
      expect(find.text('CSV'), findsWidgets);
      expect(find.text('Print'), findsWidgets);

      // Tap PDF on first card (Institutional GTS summary).
      await tester.tap(find.text('PDF').first);
      await tester.pump();
      expect(downloads.first, 'institutional_gts:pdf:false');
    });

    testWidgets(
        'ReportsDownloadsPanel lays out with fitHeight inside unbounded scroll',
        (tester) async {
      // Mirrors the live page: SliverToBoxAdapter/scroll parent + fitHeight
      // budget. Expanded without a bounded SizedBox used to leave the Column
      // with size MISSING and a blank Downloads tab.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportsDownloadsPanel(
                fitHeight: 720,
                filterLabel: 'All batches · All courses',
                chedWaveCount: 2,
                rowCounts: const {},
                onDownload: (preset, {required format, required printPreview}) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('CHED GTS institutional summary'), findsOneWidget);
      expect(find.text('GTS participation and data quality'), findsOneWidget);
    });

    testWidgets('GtsBuilderModeSwitch switches between Summary and List modes', (tester) async {
      var mode = GtsBuilderMode.summary;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => GtsBuilderModeSwitch(
                mode: mode,
                onChanged: (m) => setState(() => mode = m),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Summary & charts'), findsOneWidget);
      expect(find.text('Alumni list'), findsOneWidget);

      await tester.tap(find.text('Alumni list'));
      await tester.pumpAndSettle();
      expect(mode, GtsBuilderMode.list);

      await tester.tap(find.text('Summary & charts'));
      await tester.pumpAndSettle();
      expect(mode, GtsBuilderMode.summary);
    });

    testWidgets('GtsSavedReportsBar shows unsaved changes and action buttons', (tester) async {
      final store = _FakeStore();
      final saved = GtsSavedReport(
        id: 'r1',
        name: 'Batch 2024 Summary',
        config: const {'question': 'ched_16'},
      );
      store.reports.add(saved);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GtsSavedReportsBar(
              store: store,
              isList: false,
              open: saved,
              name: 'Batch 2024 Summary',
              settingsNamed: (name) => {'question': 'ched_16', 'name': name},
              canSave: true,
              unsavedChanges: true,
              onOpen: (r) {},
              onSaved: (r) {},
              onDeleted: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Save as new'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('ReportsBentoGrid adapts between wide, medium, and mobile widths', (tester) async {
      // 1. Wide viewport (>= 1000px)
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportsBentoGrid(
              kpis: const [
                Text('KPI 1'),
                Text('KPI 2'),
              ],
              rows: [
                ReportsBentoRow(
                  flex: const [1, 1],
                  naturalHeight: 200,
                  children: const [
                    Text('Card A'),
                    Text('Card B'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('KPI 1'), findsOneWidget);
      expect(find.text('KPI 2'), findsOneWidget);
      expect(find.text('Card A'), findsOneWidget);
      expect(find.text('Card B'), findsOneWidget);

      // 2. Medium viewport (800px)
      tester.view.physicalSize = const Size(800, 800);
      await tester.pumpAndSettle();
      expect(find.text('Card A'), findsOneWidget);

      // 3. Mobile viewport (400px)
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();
      expect(find.text('Card A'), findsOneWidget);
    });

    testWidgets('GtsReportPreview renders horizontal Scrollbar for wide tables', (tester) async {
      final people = [
        GtsRespondent(
          userId: 'u1',
          surveyId: 'w1',
          course: 'BSIT',
          yearGraduated: '2024',
          onActiveRoster: true,
          answers: const {'ched_16': 'Yes'},
        ),
      ];
      final res = GtsReportEngine.run(
        const GtsReportConfig(surveyIds: ['w1'], measure: 'ched_16'),
        people,
        now: DateTime(2026, 10, 12),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GtsReportPreview(result: res),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsOneWidget);
    });

    testWidgets('GtsAlumniListPreview renders horizontal Scrollbar for list and tally', (tester) async {
      final roster = [
        AlumniMember(
          id: 'm1',
          fullName: 'Juan Dela Cruz',
          studentId: 'S-2024-001',
          course: 'BSIT',
          batchYear: '2024',
          createdAt: DateTime(2024),
        ),
      ];
      final listRes = GtsAlumniList.build(
        const GtsListConfig(surveyId: 'w1'),
        roster: roster,
        responses: const [],
        waveIds: const ['w1'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GtsAlumniListPreview(result: listRes),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsAtLeastNWidgets(2));
    });
  });
}
