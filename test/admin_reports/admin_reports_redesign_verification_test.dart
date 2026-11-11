import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:alumni_system/core/constants/ustp_colors.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/data/gts_saved_report_service.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/reports/models/reports_dashboard_filters.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_filter_bar.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_header.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_alumni_list_panel.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_builder_mode_switch.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_report_preview.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_saved_reports_bar.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_bento.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_downloads_panel.dart';
import 'package:alumni_system/features/admin/reports/widgets/tracer_outcome_extras.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

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
                options: const ['Outcomes', 'Waves'],
                selected: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Outcomes'), findsOneWidget);
      expect(find.text('Waves'), findsOneWidget);
      expect(find.text('Career path'), findsNothing);
      expect(find.text('Cohorts & waves'), findsNothing);

      await tester.tap(find.text('Waves'));
      await tester.pumpAndSettle();
      expect(selected, 1);

      await tester.tap(find.text('Outcomes'));
      await tester.pumpAndSettle();
      expect(selected, 0);
    });

    testWidgets('ReportsStatCard is read-only and renders metric value, dense pill badge, and breakdown rows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportsStatCard(
              label: 'Tracer reach',
              value: '85%',
              icon: Icons.school_outlined,
              accent: UstpColors.blue,
              pillLabel: 'Healthy',
              pillColor: AdminColors.success,
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
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.descendant(of: find.byType(ReportsStatCard), matching: find.byType(InkWell)), findsNothing);
      expect(find.text('Took tracer'), findsOneWidget);
      expect(find.text('340'), findsOneWidget);
      expect(find.text('Registered, no tracer'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);

      final pillText = tester.widget<Text>(find.text('Healthy'));
      expect(pillText.style?.fontSize, 10.5);
      expect(pillText.style?.height, 1.15);
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
      expect(
        find.text('Institutional employment & employability overview'),
        findsOneWidget,
      );
      expect(
        find.text('Program curriculum & competency audit'),
        findsOneWidget,
      );
      expect(
        find.text('Industry linkages & economic placement'),
        findsOneWidget,
      );
      expect(find.text('Career mobility & diagnostic'), findsOneWidget);
      expect(
        find.text('CHED compliance & accreditation master summary'),
        findsOneWidget,
      );
      expect(find.text('GTS participation and data quality'), findsOneWidget);
      expect(find.text('Portal executive snapshot'), findsOneWidget);
      expect(find.text('CHED wave comparison'), findsOneWidget);
      expect(find.text('Active alumni list extract'), findsOneWidget);
      expect(find.text('INSTITUTIONAL GTS'), findsOneWidget);
      expect(find.text('COMPARISONS AND DATA QUALITY'), findsOneWidget);
      expect(find.text('OPERATIONS'), findsOneWidget);

      // Verify format buttons exist (PDF, Excel, CSV, Print)
      expect(find.text('PDF'), findsWidgets);
      expect(find.text('Excel'), findsWidgets);
      expect(find.text('CSV'), findsWidgets);
      expect(find.text('Print'), findsWidgets);

      // Tap PDF on first card (employment & employability overview).
      await tester.tap(find.text('PDF').first);
      await tester.pump();
      expect(downloads.first, 'employment_employability:pdf:false');
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
      expect(
        find.text('Institutional employment & employability overview'),
        findsOneWidget,
      );
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

  group('Reports Overview Chrome & Palette Verification', () {
    test('ReportsBentoPalette uses USTP primary/neutral system palette', () {
      expect(ReportsBentoPalette.series, const <Color>[
        UstpColors.blue,
        UstpColors.midBlue,
        UstpColors.gold,
        UstpColors.skyBlue,
        UstpColors.darkNavy,
        AdminColors.textSecondary,
        Color(0xFFCBD5E1),
      ]);
    });

    testWidgets('ReportsPageHeader matches 36px AdminDensity height and renders Live chip', (tester) async {
      expect(ReportsPageHeader.height, AdminDensity.buttonHeight);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              child: ReportsPageHeader(
                updatedAt: DateTime.now(),
                onRefresh: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Reports & Analytics'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final width in const <double>[768, 1366]) {
      testWidgets('AdminReportsSkeleton renders inside SingleChildScrollView at ${width.toInt()}px', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: AdminReportsSkeleton(),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AdminReportsSkeleton), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('ReportsDonutBreakdown expands legend across available card width without dead right space', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 420,
                height: 220,
                child: ReportsDonutBreakdown(
                  centerValue: '11',
                  centerLabel: 'Alumni',
                  entries: const [
                    ReportsDonutEntry(label: 'BSIT', value: 8, color: UstpColors.blue),
                    ReportsDonutEntry(label: 'BTLED-ICT', value: 2, color: UstpColors.midBlue),
                    ReportsDonutEntry(label: 'BTLED-HE', value: 1, color: UstpColors.gold),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('BSIT'), findsOneWidget);
      expect(find.text('BTLED-ICT'), findsOneWidget);
      expect(find.text('BTLED-HE'), findsOneWidget);
      expect(find.text('73%'), findsOneWidget);
      expect(find.text('18%'), findsOneWidget);
      expect(find.text('9%'), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));

      final legendRect = tester.getRect(find.byType(SingleChildScrollView));
      expect(legendRect.right, closeTo(420.0, 2.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ReportsTrendChart and ReportsColumnChart fit tooltips inside chart bounds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  width: 360,
                  height: 200,
                  child: ReportsTrendChart(
                    labels: const ['Oct 26', 'Nov 26'],
                    series: const [
                      ReportsTrendSeries(
                        label: 'Alumni list',
                        color: UstpColors.blue,
                        values: [4, 11],
                      ),
                      ReportsTrendSeries(
                        label: 'Registered',
                        color: UstpColors.gold,
                        values: [2, 8],
                        filled: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 320,
                  height: 180,
                  child: ReportsColumnChart(
                    labels: ['2024', '2025'],
                    values: [6, 5],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineTouchData.touchTooltipData.fitInsideHorizontally, isTrue);
      expect(lineChart.data.lineTouchData.touchTooltipData.fitInsideVertically, isTrue);

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      expect(barChart.data.barTouchData.touchTooltipData.fitInsideHorizontally, isTrue);
      expect(barChart.data.barTouchData.touchTooltipData.fitInsideVertically, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('Reports Tracer Tab Verification', () {
    for (final width in const <double>[768, 1280]) {
      testWidgets('ReportsCohortFilterBar renders 12px card frame and active count badge at ${width.toInt()}px', (tester) async {
        ReportsDashboardFilters current = const ReportsDashboardFilters(batchYear: '2024');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: width,
                  child: StatefulBuilder(
                    builder: (context, setState) => ReportsCohortFilterBar(
                      filters: current,
                      surveys: const [],
                      batchYears: const ['2024', '2025'],
                      onChanged: (next) => setState(() => current = next),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Filters'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('Reset'), findsOneWidget);

        final container = tester.widget<Container>(find.byType(Container).first);
        final dec = container.decoration! as BoxDecoration;
        expect(dec.borderRadius, BorderRadius.circular(AdminSurfaces.radiusMd));

        await tester.tap(find.text('Reset'));
        await tester.pump();
        expect(current.batchYear, isNull);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('TracerLongitudinalPanel renders dense status pills and opens respondent dialog callback', (tester) async {
      TracerLongitudinalRow? opened;
      final row = TracerLongitudinalRow(
        userId: 'u1',
        displayName: 'Maria Santos',
        points: [
          TracerWaveStatusPoint(
            waveLabel: 'CHED 2024',
            waveDate: DateTime(2024, 5, 10),
            status: 'Yes',
          ),
          TracerWaveStatusPoint(
            waveLabel: 'CHED 2025',
            waveDate: DateTime(2025, 6, 12),
            status: 'No',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: TracerLongitudinalPanel(
                rows: [row],
                onOpenPerson: (r) => opened = r,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('2 waves'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      final wavesBadge = tester.widget<Text>(find.text('2 waves'));
      expect(wavesBadge.style?.fontSize, 10.5);
      expect(wavesBadge.style?.height, 1.15);

      await tester.tap(find.text('Maria Santos'));
      await tester.pump();
      expect(opened, row);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ReportsGroupedBarChart keeps tooltips inside chart bounds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 200,
              child: ReportsGroupedBarChart(
                labels: const ['Wave 1', 'Wave 2'],
                series: const [
                  ReportsBarSeries(
                    label: 'Answers',
                    color: UstpColors.blue,
                    values: [20, 30],
                  ),
                  ReportsBarSeries(
                    label: 'Employed',
                    color: UstpColors.gold,
                    values: [16, 25],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      expect(barChart.data.barTouchData.touchTooltipData.fitInsideHorizontally, isTrue);
      expect(barChart.data.barTouchData.touchTooltipData.fitInsideVertically, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('Reports Survey Tab Verification', () {
    testWidgets('ReportsProgressList renders textSecondary chevron cue and triggers onTap cleanly', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 310,
              height: 220,
              child: ReportsProgressList(
                items: [
                  ReportsProgressItem(
                    label: 'Annual Alumni Satisfaction Survey 2026',
                    detail: '12/40',
                    fraction: 0.30,
                    color: AdminColors.warning,
                    onTap: () => tapped = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Annual Alumni Satisfaction Survey 2026'), findsOneWidget);
      expect(find.text('12/40'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);

      final chevron = tester.widget<Icon>(find.byIcon(Icons.chevron_right_rounded));
      expect(chevron.color, AdminColors.textSecondary);

      await tester.tap(find.text('Annual Alumni Satisfaction Survey 2026'));
      await tester.pump();
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ReportsDonutBreakdown renders Survey Response Split with USTP palette', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              height: 220,
              child: ReportsDonutBreakdown(
                centerValue: '75%',
                centerLabel: 'responded',
                entries: [
                  ReportsDonutEntry(
                    label: 'Submitted',
                    value: 75,
                    color: UstpColors.blue,
                  ),
                  ReportsDonutEntry(
                    label: 'Pending',
                    value: 25,
                    color: UstpColors.gold,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('75%'), findsNWidgets(2));
      expect(find.text('responded'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
