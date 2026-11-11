import 'dart:async';
import 'dart:convert';

import 'package:alumni_system/core/services/audit_events.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/features/admin/activity/presentation/admin_activity_logs_page.dart';
import 'package:alumni_system/features/admin/activity/widgets/admin_activity_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:alumni_system/shared/widgets/admin/admin_metric_ribbon.dart';
import 'package:alumni_system/shared/widgets/admin/admin_pagination.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _LoggedActionCall {
  const _LoggedActionCall({
    required this.action,
    required this.resource,
    required this.description,
    this.changes,
  });

  final String action;
  final String resource;
  final String description;
  final Map<String, dynamic>? changes;
}

class _FakeAuditService extends AuditService {
  _FakeAuditService({required this.seedLogs})
      : super(supabase: Supabase.instance.client);

  List<AuditLog> seedLogs;
  bool throwOnQuery = false;
  bool throwOnStats = false;
  Completer<List<AuditLog>>? pendingQueryCompleter;

  final List<AuditLogQuery> recordedQueries = [];
  int statsCalls = 0;
  final List<_LoggedActionCall> loggedActions = [];

  List<AuditLog> _applyDateRange(
    List<AuditLog> input,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    return input.where((log) {
      if (startDate != null) {
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        if (log.timestamp.isBefore(start)) return false;
      }
      if (endDate != null) {
        final end = DateTime(endDate.year, endDate.month, endDate.day)
            .add(const Duration(days: 1));
        if (!log.timestamp.isBefore(end)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<({List<AuditLog> logs, int? totalHint})> queryAuditLogs(
    AuditLogQuery query,
  ) async {
    recordedQueries.add(query);
    if (throwOnQuery) {
      throw Exception('PostgrestException: connection reset');
    }
    final source = pendingQueryCompleter != null
        ? await pendingQueryCompleter!.future
        : seedLogs;

    var filtered = _applyDateRange(source, query.startDate, query.endDate);
    if (query.action != null &&
        query.action!.isNotEmpty &&
        query.action != 'All') {
      filtered = filtered.where((l) => l.action == query.action).toList();
    }
    if (query.resource != null &&
        query.resource!.isNotEmpty &&
        query.resource != 'All') {
      filtered = filtered.where((l) => l.resource == query.resource).toList();
    }
    if (query.module != null &&
        query.module!.isNotEmpty &&
        query.module != 'All') {
      filtered = filtered.where((l) => l.module == query.module).toList();
    }
    if (query.category != null &&
        query.category!.isNotEmpty &&
        query.category != 'All') {
      filtered = filtered.where((l) => l.category == query.category).toList();
    }
    if (query.status != null &&
        query.status!.isNotEmpty &&
        query.status != 'All') {
      filtered = filtered.where((l) => l.status == query.status).toList();
    }
    if (query.actorType != null &&
        query.actorType!.isNotEmpty &&
        query.actorType != 'All') {
      filtered =
          filtered.where((l) => l.actorType == query.actorType).toList();
    }
    final search = query.search?.trim().toLowerCase();
    if (search != null && search.isNotEmpty) {
      filtered = filtered
          .where(
            (l) =>
                l.description.toLowerCase().contains(search) ||
                l.userName.toLowerCase().contains(search) ||
                l.userEmail.toLowerCase().contains(search) ||
                l.action.toLowerCase().contains(search) ||
                l.resource.toLowerCase().contains(search) ||
                l.module.toLowerCase().contains(search) ||
                (l.targetLabel?.toLowerCase().contains(search) ?? false),
          )
          .toList();
    }
    if (filtered.length > query.limit) {
      filtered = filtered.sublist(0, query.limit);
    }
    return (logs: filtered, totalHint: null);
  }

  @override
  Future<AuditLogStats> getAuditLogStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    statsCalls++;
    if (throwOnStats) {
      throw Exception('SocketException: stats unreachable');
    }
    final logs = _applyDateRange(seedLogs, startDate, endDate);
    final now = DateTime.now();
    var today = 0;
    var adminActions = 0;
    var securityEvents = 0;
    var failed = 0;
    var systemEvents = 0;

    for (final log in logs) {
      if (log.timestamp.year == now.year &&
          log.timestamp.month == now.month &&
          log.timestamp.day == now.day) {
        today++;
      }
      if (log.userRole == 'admin' || log.actorType == AuditActorTypes.admin) {
        adminActions++;
      }
      if (log.category == AuditCategories.security) {
        securityEvents++;
      }
      if (log.status == AuditStatus.failed ||
          log.status == AuditStatus.rejected) {
        failed++;
      }
      if (log.actorType == AuditActorTypes.system) {
        systemEvents++;
      }
    }

    return AuditLogStats(
      total: logs.length,
      today: today,
      adminActions: adminActions,
      securityEvents: securityEvents,
      failed: failed,
      systemEvents: systemEvents,
    );
  }

  @override
  Future<void> logAction({
    required String action,
    required String resource,
    required String resourceId,
    required String description,
    Map<String, dynamic>? changes,
    String status = AuditStatus.success,
    String userRole = 'user',
    String module = '',
    String category = AuditCategories.activity,
    String? actorType,
    String? correlationId,
    String? targetLabel,
    Map<String, dynamic>? meta,
  }) async {
    loggedActions.add(
      _LoggedActionCall(
        action: action,
        resource: resource,
        description: description,
        changes: changes,
      ),
    );
  }
}

AuditLog _makeLog({
  required String id,
  required String action,
  String userName = 'AESS Admin',
  String actorType = AuditActorTypes.admin,
  String userRole = 'admin',
  String module = AuditModules.alumni,
  String category = AuditCategories.activity,
  String resource = 'RosterMember',
  String resourceId = 'mem-1',
  String? targetLabel,
  String status = AuditStatus.success,
  String description = 'Performed action',
  String? ipAddress,
  DateTime? timestamp,
}) {
  return AuditLog(
    id: id,
    userId: 'u-$id',
    userName: userName,
    userEmail: '$id@aess.edu',
    action: action,
    resource: resource,
    resourceId: resourceId,
    description: description,
    status: status,
    userRole: userRole,
    actorType: actorType,
    module: module,
    category: category,
    targetLabel: targetLabel,
    ipAddress: ipAddress,
    timestamp: timestamp ?? DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeAuditService service,
  ActivityCsvDownloader? csvDownloader,
  Size size = const Size(1366, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AdminActivityLogsScreen(
            service: service,
            csvDownloader: csvDownloader,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: MockClient((_) async {
        return http.Response(
          jsonEncode(<dynamic>[]),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  testWidgets('shows loading skeleton then renders SaaS header, metrics, and table',
      (tester) async {
    final completer = Completer<List<AuditLog>>();
    final logs = [
      _makeLog(
        id: '1',
        action: AuditActions.login,
        category: AuditCategories.security,
        module: AuditModules.auth,
        status: AuditStatus.rejected,
        targetLabel: 'Failed login',
        ipAddress: '10.0.0.4',
      ),
      _makeLog(
        id: '2',
        action: AuditActions.createRosterMember,
        category: AuditCategories.activity,
        module: AuditModules.alumni,
        targetLabel: 'Ana Santos',
      ),
      _makeLog(
        id: '3',
        action: AuditActions.expireJob,
        userName: '',
        actorType: AuditActorTypes.system,
        userRole: 'system',
        category: AuditCategories.activity,
        module: AuditModules.jobs,
        targetLabel: 'Senior Dev',
      ),
    ];

    final service = _FakeAuditService(seedLogs: logs)
      ..pendingQueryCompleter = completer;

    await _pumpScreen(tester, service: service);
    await tester.pump();
    expect(find.byType(AdminActivityLogSkeleton), findsOneWidget);

    service.pendingQueryCompleter = null;
    completer.complete(logs);
    await tester.pumpAndSettle();

    expect(find.byType(AdminActivityLogSkeleton), findsNothing);
    expect(find.byType(AdminCompactHeader), findsOneWidget);
    expect(find.text('Activity Logs'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);

    expect(find.byType(AdminMetricRibbon), findsOneWidget);
    expect(find.text('Total (range)'), findsOneWidget);
    expect(find.text('Admin actions'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
    // System actor still appears in the table; no System KPI card.
    expect(find.text('System'), findsOneWidget);

    expect(find.byType(AdminDataTable), findsOneWidget);
    expect(find.byType(AdminPaginationBar), findsOneWidget);
    expect(find.text('Showing 1–3 of 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'status filter, debounced search, reset, and scoped stats reload work',
      (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 2));
    final service = _FakeAuditService(
      seedLogs: [
        _makeLog(
          id: '1',
          action: AuditActions.updateRosterMember,
          description: 'Updated TOR verification record',
          category: AuditCategories.security,
          status: AuditStatus.failed,
          targetLabel: 'Maria Clara',
        ),
        _makeLog(
          id: '2',
          action: AuditActions.publishEvent,
          userName: 'Events Coord',
          actorType: AuditActorTypes.alumni,
          userRole: 'user',
          module: AuditModules.events,
          category: AuditCategories.activity,
          status: AuditStatus.success,
          targetLabel: 'Alumni Homecoming',
          timestamp: yesterday,
        ),
      ],
    );

    await _pumpScreen(tester, service: service);
    await tester.pumpAndSettle();
    expect(service.statsCalls, 1);

    // Status filter narrows results without re-querying date-range stats
    await tester.tap(find.byKey(const ValueKey('Status-All')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FAILED').last);
    await tester.pumpAndSettle();
    expect(service.recordedQueries.last.status, AuditStatus.failed);
    expect(service.statsCalls, 1);
    expect(find.text('Showing 1–1 of 1'), findsOneWidget);
    expect(find.text('Status: FAILED'), findsOneWidget);

    // Search debounce queries after 300ms and shows empty state when no match
    final searchField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Search actor, action, description…',
    );
    await tester.enterText(searchField, 'nonexistent-keyword');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(service.recordedQueries.last.search, 'nonexistent-keyword');
    expect(find.text('No matching activity logs'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 1–2 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'responsive desktop-split (960px), tablet (768px), and mobile (360px) render without overflow and open detail panel',
      (tester) async {
    final service = _FakeAuditService(
      seedLogs: [
        _makeLog(
          id: '1',
          action: AuditActions.roleChange,
          category: AuditCategories.security,
          status: AuditStatus.rejected,
          ipAddress: '172.16.0.8',
          targetLabel: 'Dean Account',
        ),
      ],
    );

    // Narrow desktop (>= AdminDensity.desktopSplitMin = 900px): uses table
    await _pumpScreen(tester, service: service, size: const Size(960, 900));
    await tester.pumpAndSettle();
    expect(find.byType(AdminDataTable), findsOneWidget);
    expect(find.byType(AdminActivityLogCard), findsNothing);
    expect(tester.takeException(), isNull);

    // Tap row -> opens side detail drawer
    await tester.tap(find.text(AuditActions.roleChange));
    await tester.pumpAndSettle();
    expect(find.byType(AdminActivityLogDetailPanel), findsOneWidget);
    expect(find.text('172.16.0.8'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminActivityLogDetailPanel), findsNothing);

    // Tablet (< 900px): switches cleanly to compact cards without overflow
    await _pumpScreen(tester, service: service, size: const Size(768, 900));
    await tester.pumpAndSettle();
    expect(find.byType(AdminDataTable), findsNothing);
    expect(find.byType(AdminActivityLogCard), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(AdminActivityLogCard));
    await tester.pumpAndSettle();
    expect(find.byType(AdminActivityLogDetailPanel), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // Mobile (360px): compact cards with zero overflow
    await _pumpScreen(tester, service: service, size: const Size(360, 800));
    await tester.pumpAndSettle();
    expect(find.byType(AdminDataTable), findsNothing);
    expect(find.byType(AdminActivityLogCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paginates across 30 logs and updates page size cleanly',
      (tester) async {
    final logs = List.generate(
      30,
      (i) => _makeLog(
        id: 'log-$i',
        action: 'ACTION_$i',
        targetLabel: 'Target $i',
      ),
    );
    final service = _FakeAuditService(seedLogs: logs);

    await _pumpScreen(tester, service: service);
    await tester.pumpAndSettle();

    expect(find.text('Showing 1–25 of 30'), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pump();
    expect(find.text('Showing 26–30 of 30'), findsOneWidget);
    expect(find.text('Page 2 of 2'), findsOneWidget);

    // Change Rows per page to 50
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50').last);
    await tester.pumpAndSettle();
    expect(find.text('Showing 1–30 of 30'), findsOneWidget);
    expect(find.text('Page 1 of 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Export CSV generates payload, calls downloader, and logs audit action',
      (tester) async {
    final service = _FakeAuditService(
      seedLogs: [
        _makeLog(id: '1', action: AuditActions.login),
        _makeLog(id: '2', action: AuditActions.createJob),
      ],
    );
    String? downloadedName;
    String? downloadedCsv;

    await _pumpScreen(
      tester,
      service: service,
      csvDownloader: ({
        required String content,
        required String fileName,
        String mimeType = 'text/plain',
      }) {
        downloadedCsv = content;
        downloadedName = fileName;
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export CSV'));
    await tester.pumpAndSettle();

    expect(downloadedName, startsWith('aess_activity_logs_'));
    expect(downloadedName, endsWith('.csv'));
    expect(downloadedCsv, contains('timestamp,actor,email'));
    expect(downloadedCsv, contains('CREATE_JOB'));
    expect(service.loggedActions.length, 1);
    expect(service.loggedActions.single.action, AuditActions.exportAuditLogs);
    expect(find.text('Exported 2 log(s).'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'handles initial error + Try again recovery and cached refresh warning banner',
      (tester) async {
    final service = _FakeAuditService(
      seedLogs: [
        _makeLog(id: '1', action: AuditActions.publishAnnouncement),
      ],
    )..throwOnQuery = true;

    await _pumpScreen(tester, service: service);
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load activity logs"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    // Recover from initial error
    service.throwOnQuery = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text(AuditActions.publishAnnouncement), findsOneWidget);
    expect(find.text("Couldn't load activity logs"), findsNothing);

    // Reload failure with cached logs shows warning banner instead of wiping table
    service.throwOnQuery = true;
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();

    expect(find.text(AuditActions.publishAnnouncement), findsOneWidget);
    expect(
      find.text("Couldn't refresh activity logs. Showing the last loaded list."),
      findsOneWidget,
    );

    service.throwOnQuery = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't refresh activity logs. Showing the last loaded list."),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

