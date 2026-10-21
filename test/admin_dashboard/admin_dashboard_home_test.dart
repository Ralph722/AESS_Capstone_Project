import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/features/admin/dashboard/application/admin_dashboard_metrics.dart';
import 'package:alumni_system/features/admin/dashboard/application/dashboard_activity_trend.dart';
import 'package:alumni_system/features/admin/dashboard/application/dashboard_insights.dart';
import 'package:alumni_system/features/admin/dashboard/presentation/admin_dashboard_home.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_dashboard_widgets.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/dashboard_engagement_chart.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _metrics = AdminDashboardMetrics(rosterTotal: 8, registeredOnRoster: 3);

final _now = DateTime(2026, 10, 14, 9);

DashboardInsights _insights({bool long = false, bool flagsLoaded = true}) {
  String t(String s) => long
      ? '$s — a very long title that keeps going well past the card width'
      : s;
  return DashboardInsights(
    registered: 3,
    tracerResponded: 1,
    currentTracerTitle: 'CHED GTS',
    currentTracerCloseAt: DateTime(2026, 11, 30),
    employmentRecords: 1,
    employed: 1,
    findingsOpen: flagsLoaded ? 2 : null,
    findingsInProgress: flagsLoaded ? 1 : null,
    findingsCritical: flagsLoaded ? 1 : null,
    actionsOverdue: flagsLoaded ? 1 : null,
    programs: [
      DashboardProgramStat(
        program: t('BSIT'),
        alumni: 5,
        registered: 2,
        tracerResponded: 1,
      ),
      const DashboardProgramStat(
        program: 'BTLED-ICT',
        alumni: 2,
        registered: 1,
        tracerResponded: 0,
      ),
      const DashboardProgramStat(
        program: 'BTLED-HE',
        alumni: 1,
        registered: 0,
        tracerResponded: 0,
      ),
    ],
    otherSurveys: DashboardSurveySummary(
      published: 7,
      drafts: 1,
      assigned: 19,
      submitted: 4,
      lowestTitle: t('Test 2'),
      lowestRate: 1 / 3,
    ),
    deadlines: [
      DashboardAgendaItem(
        kind: DashboardAgendaKind.insightDue,
        date: DateTime(2026, 10, 2),
        title: t('Low employment in BSIT 2024'),
        detail: 'Program Insights · action due',
        overdue: true,
      ),
      DashboardAgendaItem(
        kind: DashboardAgendaKind.survey,
        date: DateTime(2026, 10, 14, 17),
        title: t('Alumni satisfaction'),
        detail: 'Survey closes',
      ),
      DashboardAgendaItem(
        kind: DashboardAgendaKind.job,
        date: DateTime(2026, 10, 15),
        title: t('Junior developer'),
        detail: 'Application deadline · Acme',
      ),
    ],
  );
}

List<AlumniEvent> _events({bool longTitles = false}) => [
  for (var i = 0; i < 4; i++)
    AlumniEvent(
      id: 'e$i',
      theme: longTitles
          ? 'Grand alumni homecoming and career fair for every batch '
                'from 1990 to 2025, with a very long title number $i'
          : 'Event $i',
      batchYear: '2024',
      date: _now.add(Duration(days: i * 3 + 1)),
      venue: 'Gym',
      status: 'active',
      comments: 0,
    ),
];

List<AuditLog> _logs({bool long = false}) => [
  for (var i = 0; i < 8; i++)
    AuditLog(
      id: 'l$i',
      userId: 'u',
      userName: 'Admin',
      userEmail: 'admin@example.com',
      action: 'login',
      resource: 'auth',
      resourceId: '',
      description: long
          ? 'Admin updated the survey "CHED Graduate Tracer Survey" settings '
                'and republished it to every registered alumni $i'
          : 'Admin logged in $i',
      timestamp: _now.subtract(Duration(hours: i)),
      status: 'success',
    ),
];

final _trend = DashboardActivityTrend.fromAuditLogs([
  for (var d = 0; d < 90; d += 3)
    for (var k = 0; k < (d % 7) + 1; k++)
      AuditLog(
        id: 't$d$k',
        userId: 'u',
        userName: 'A',
        userEmail: 'a@b.c',
        action: 'x',
        resource: 'y',
        resourceId: '',
        description: '',
        timestamp: _now.subtract(Duration(days: d)),
        status: 'success',
      ),
]);

const _unset = Object();

Widget _home({
  ValueChanged<int>? onMenu,
  Future<void> Function()? onRefresh,
  bool metricsLoaded = true,
  bool metricsFailed = false,
  bool feedsFailed = false,
  Object? insights = _unset,
  bool insightsFailed = false,
  List<AlumniEvent>? events,
  List<AuditLog>? logs,
  DashboardActivityTrend? trend,
}) {
  return AdminDashboardHome(
    isLoading: false,
    metrics: _metrics,
    activeEvents: events ?? _events(),
    recentActivity: logs ?? _logs(),
    activityTrend: trend ?? _trend,
    onMenuSelected: onMenu ?? (_) {},
    onRefresh: onRefresh ?? () async {},
    metricsLoaded: metricsLoaded,
    metricsFailed: metricsFailed,
    feedsFailed: feedsFailed,
    insights: identical(insights, _unset)
        ? _insights()
        : insights as DashboardInsights?,
    insightsFailed: insightsFailed,
    now: _now,
  );
}

/// Pumps [child] in a box the size of the shell content area for a viewport.
Future<void> _pumpContent(
  WidgetTester tester,
  Widget child, {
  required Size content,
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(content.width + 40, content.height + 40);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: content.width,
            height: content.height,
            child: child,
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Content area = viewport − sidebar − header (50) − shell padding.
const _contentSizes = <String, Size>{
  '1366x768': Size(1366 - 264 - 32, 768 - 50 - 32),
  '1440x900': Size(1440 - 264 - 32, 900 - 50 - 32),
  '1600x900': Size(1600 - 264 - 32, 900 - 50 - 32),
  '1920x1080': Size(1920 - 264 - 32, 1080 - 50 - 32),
  '1024x768 (rail)': Size(1024 - 72 - 24, 768 - 50 - 24),
  '768x1024 (rail)': Size(768 - 72 - 24, 1024 - 50 - 24),
};

Finder _inPanel(String panel, Finder finder) => find.descendant(
  of: find.ancestor(of: find.text(panel), matching: find.byType(DashboardPanel)),
  matching: finder,
);

void main() {
  group('layout', () {
    for (final entry in _contentSizes.entries) {
      testWidgets('no overflow at ${entry.key}', (tester) async {
        await _pumpContent(tester, _home(), content: entry.value);
        expect(tester.takeException(), isNull);
        await _pumpContent(
          tester,
          _home(
            events: _events(longTitles: true),
            logs: _logs(long: true),
            insights: _insights(long: true),
          ),
          content: entry.value,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('single-screen grid at 1366x768 fits without page scroll', (
      tester,
    ) async {
      await _pumpContent(tester, _home(), content: _contentSizes['1366x768']!);
      final outer = tester.widgetList<ListView>(find.byType(ListView)).first;
      expect(outer.physics, isA<NeverScrollableScrollPhysics>());
      // Content box spans y = 20 … 706 inside the 726px test view.
      for (final panel in tester.elementList(find.byType(DashboardPanel))) {
        final box = panel.renderObject! as RenderBox;
        final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
        expect(bottom, lessThanOrEqualTo(706.5));
      }
    });

    testWidgets('1024 rail width uses the scrolling layout', (tester) async {
      await _pumpContent(
        tester,
        _home(),
        content: _contentSizes['1024x768 (rail)']!,
      );
      final outer = tester.widgetList<ListView>(find.byType(ListView)).first;
      expect(outer.physics, isA<AlwaysScrollableScrollPhysics>());
    });
  });

  group('content', () {
    testWidgets('KPI row: registration, tracer, employment, insights', (
      tester,
    ) async {
      await _pumpContent(tester, _home(), content: _contentSizes['1440x900']!);

      expect(find.text('Alumni registered'), findsOneWidget);
      expect(find.text('38%'), findsOneWidget);
      expect(find.text('3 of 8 on the roster'), findsOneWidget);

      expect(find.text('Tracer response'), findsOneWidget);
      expect(find.text('1 of 3 registered alumni'), findsOneWidget);
      expect(find.text('Closes Nov 30'), findsOneWidget);

      expect(find.text('Employment rate'), findsOneWidget);
      expect(find.text('1 of 1 with employment info'), findsOneWidget);

      expect(find.text('Program Insights findings'), findsOneWidget);
      expect(find.text('2 open · 1 in progress'), findsOneWidget);
      expect(find.text('1 overdue'), findsOneWidget);
    });

    testWidgets('removed: title chips, old KPIs, Community, Shortcuts', (
      tester,
    ) async {
      await _pumpContent(tester, _home(), content: _contentSizes['1440x900']!);
      for (final gone in [
        'Roster',
        'Registered',
        'Surveys',
        'Alumni roster',
        'Tracer complete',
        'Survey completion',
        'Employment records',
        'Community',
        'Shortcuts',
        'Upcoming events',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
    });

    testWidgets('programs, other surveys and unchanged panels', (
      tester,
    ) async {
      await _pumpContent(tester, _home(), content: _contentSizes['1440x900']!);

      expect(find.text('Programs at a glance'), findsOneWidget);
      for (final p in ['BSIT', 'BTLED-ICT', 'BTLED-HE']) {
        expect(find.text(p), findsOneWidget, reason: p);
      }
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('REGISTERED'), findsOneWidget);

      expect(find.text('Other surveys'), findsOneWidget);
      expect(_inPanel('Other surveys', find.text('7')), findsOneWidget);
      expect(_inPanel('Other surveys', find.text('21%')), findsOneWidget);
      expect(_inPanel('Other surveys', find.text('4 of 19')), findsOneWidget);
      expect(find.text('Lowest: Test 2'), findsOneWidget);

      expect(find.text('Portal activity'), findsOneWidget);
      expect(find.textContaining('Max: '), findsOneWidget);
      expect(find.text('Recent activity'), findsOneWidget);
      expect(find.text('Admin logged in 0'), findsOneWidget);
    });

    testWidgets('agenda: overdue first, then events and deadlines by date', (
      tester,
    ) async {
      await _pumpContent(tester, _home(), content: _contentSizes['1920x1080']!);
      expect(find.text('Upcoming & deadlines'), findsOneWidget);
      expect(find.text('Next 30 days'), findsOneWidget);

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      final order = [
        'Low employment in BSIT 2024',
        'Alumni satisfaction',
        'Junior developer',
        'Event 0',
      ];
      for (var k = 1; k < order.length; k++) {
        expect(top(order[k - 1]), lessThan(top(order[k])), reason: order[k]);
      }
      expect(
        find.text('Overdue since Oct 2 · Program Insights · action due'),
        findsOneWidget,
      );
    });

    testWidgets('narrow layout keeps 4 activity rows and 5 agenda rows', (
      tester,
    ) async {
      await _pumpContent(
        tester,
        _home(),
        content: _contentSizes['768x1024 (rail)']!,
      );
      expect(find.textContaining('Admin logged in'), findsNWidgets(4));
      expect(find.textContaining('Event '), findsNWidgets(2));
      expect(find.text('Event 2'), findsNothing);
    });
  });

  group('navigation', () {
    final cases = <String, int>{
      'Alumni registered': 2,
      'Tracer response': 9,
      'Employment rate': 9,
      'Program Insights findings': 15,
    };
    for (final c in cases.entries) {
      testWidgets('KPI ${c.key} → ${c.value}', (tester) async {
        final taps = <int>[];
        await _pumpContent(
          tester,
          _home(onMenu: taps.add),
          content: _contentSizes['1366x768']!,
        );
        await tester.tap(find.text(c.key));
        expect(taps, [c.value]);
      });
    }

    testWidgets('card links and rows', (tester) async {
      final taps = <int>[];
      await _pumpContent(
        tester,
        _home(onMenu: taps.add),
        content: _contentSizes['1920x1080']!,
      );
      await tester.tap(find.bySemanticsLabel('View program figures in Reports'));
      await tester.tap(find.bySemanticsLabel('View all surveys'));
      await tester.tap(find.text('Published'));
      await tester.tap(find.bySemanticsLabel('View all activity'));
      expect(taps, [9, 10, 10, 7]);

      taps.clear();
      for (final title in [
        'Low employment in BSIT 2024',
        'Alumni satisfaction',
        'Junior developer',
        'Event 0',
      ]) {
        await tester.tap(find.text(title));
      }
      expect(taps, [15, 10, 5, 1]);
    });

    testWidgets('chart Reports link → 9', (tester) async {
      final taps = <int>[];
      await _pumpContent(
        tester,
        _home(onMenu: taps.add),
        content: _contentSizes['1366x768']!,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(DashboardEngagementTrendChart),
          matching: find.text('Reports'),
        ),
      );
      expect(taps, [9]);
    });
  });

  group('states', () {
    testWidgets('placeholders while metrics and insights load', (
      tester,
    ) async {
      await _pumpContent(
        tester,
        _home(metricsLoaded: false, insights: null),
        content: _contentSizes['1440x900']!,
        settle: false,
      );
      expect(find.text('Loading…'), findsNWidgets(4));
      expect(find.text('38%'), findsNothing);
      expect(find.text('BSIT'), findsNothing);
      // Events still show while survey/job/insight dates load.
      expect(find.text('Event 0'), findsOneWidget);
    });

    testWidgets('failed insights say so, with retry', (tester) async {
      var refreshes = 0;
      await _pumpContent(
        tester,
        _home(
          insights: null,
          insightsFailed: true,
          onRefresh: () async => refreshes++,
        ),
        content: _contentSizes['1440x900']!,
      );
      expect(find.text("Couldn't load"), findsNWidgets(3));
      expect(find.text("Couldn't load figures"), findsNWidgets(2));
      expect(
        find.text("Couldn't load survey, job and insight dates."),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again').first);
      expect(refreshes, 1);
    });

    testWidgets('Program Insights unavailable on its own', (tester) async {
      await _pumpContent(
        tester,
        _home(insights: _insights(flagsLoaded: false)),
        content: _contentSizes['1440x900']!,
      );
      expect(find.text("Couldn't load"), findsOneWidget);
      expect(find.text('Tracer response'), findsOneWidget);
      expect(find.text('1 of 3 registered alumni'), findsOneWidget);
    });

    testWidgets('failed feeds show errors with retry, not "empty"', (
      tester,
    ) async {
      await _pumpContent(
        tester,
        _home(
          feedsFailed: true,
          events: const [],
          logs: const [],
          trend: const DashboardActivityTrend(),
        ),
        content: _contentSizes['1440x900']!,
      );
      expect(find.text("Couldn't load recent activity"), findsOneWidget);
      expect(find.text("Couldn't load activity trend"), findsOneWidget);
      expect(find.text("Couldn't load events."), findsOneWidget);
      expect(find.text('No activity yet'), findsNothing);
    });

    testWidgets('empty states', (tester) async {
      await _pumpContent(
        tester,
        _home(
          events: const [],
          logs: const [],
          trend: DashboardActivityTrend.fromAuditLogs(const []),
          insights: const DashboardInsights(),
        ),
        content: _contentSizes['1440x900']!,
      );
      expect(find.text('No activity yet'), findsOneWidget);
      expect(find.text('No activity recorded yet'), findsOneWidget);
      expect(find.text('No alumni on the roster yet'), findsOneWidget);
      expect(find.text('Nothing due in the next 30 days'), findsOneWidget);
      expect(find.text('No tracer open'), findsOneWidget);
      expect(find.text('No employment information yet'), findsOneWidget);
    });

    testWidgets('header shows a Live badge instead of a Refresh button', (
      tester,
    ) async {
      await _pumpContent(
        tester,
        _home(),
        content: _contentSizes['1366x768']!,
      );
      expect(find.text('Refresh'), findsNothing);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
      expect(find.text('Live'), findsOneWidget);
      expect(find.byType(DashboardLiveIndicator), findsOneWidget);
    });
  });

  test('Live badge tooltip says when figures last updated', () {
    expect(
      DashboardLiveIndicator.message(null),
      'Figures update automatically.',
    );
    expect(
      DashboardLiveIndicator.message(DateTime(2026, 10, 15, 22, 42)),
      'Figures update automatically. Last updated 10:42 PM.',
    );
  });

  test('bottom row height: 45% clamped to 200–260, at most half', () {
    expect(AdminDashboardHome.bottomRowHeight(497), closeTo(223.65, 0.01));
    expect(AdminDashboardHome.bottomRowHeight(800), 260);
    expect(AdminDashboardHome.bottomRowHeight(300), 150);
  });

  group('chart x-axis labels', () {
    test('last tick shown; colliding previous tick hidden', () {
      bool show(int i) => DashboardEngagementTrendChart.showXLabel(i, 89, 14);
      expect(show(89), isTrue);
      expect(show(84), isFalse);
      expect(show(70), isTrue);
      expect(show(0), isTrue);
      expect(show(13), isFalse);
    });

    test('short series label every point', () {
      for (var i = 0; i <= 10; i++) {
        expect(DashboardEngagementTrendChart.showXLabel(i, 10, 1), isTrue);
      }
    });
  });

  testWidgets('spoken labels for KPIs, programs, agenda and chart', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpContent(tester, _home(), content: _contentSizes['1440x900']!);
    expect(
      find.bySemanticsLabel('Alumni registered, 38%, 3 of 8 on the roster'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'BSIT: 5 alumni, 40% registered, 50% tracer response',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Junior developer, Application deadline')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Portal activity, last 90 days, peak')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
