import 'dart:convert';

import 'package:alumni_system/core/services/audit_events.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/features/admin/activity/widgets/admin_activity_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_shared/admin_test_harness.dart';

AuditLog _sampleLog({
  String id = 'log-1',
  String userId = 'u-admin',
  String userName = 'Admin User',
  String userEmail = 'admin@aess.edu',
  String action = AuditActions.updateRosterMember,
  String resource = 'RosterMember',
  String resourceId = 'mem-42',
  String description = 'Updated alumni batch year',
  Map<String, dynamic>? changes = const {
    'batch': {'from': '2020', 'to': '2021'},
    'status': 'active',
  },
  String status = AuditStatus.success,
  String userRole = 'admin',
  String module = AuditModules.alumni,
  String category = AuditCategories.security,
  String actorType = AuditActorTypes.admin,
  String? ipAddress = '192.168.1.15',
  String? correlationId = 'corr-9001',
  String? targetLabel = 'Ana Santos',
  DateTime? timestamp,
}) {
  return AuditLog(
    id: id,
    userId: userId,
    userName: userName,
    userEmail: userEmail,
    action: action,
    resource: resource,
    resourceId: resourceId,
    description: description,
    changes: changes,
    timestamp: timestamp ?? DateTime(2026, 11, 10, 14, 30),
    ipAddress: ipAddress,
    status: status,
    userRole: userRole,
    module: module,
    category: category,
    actorType: actorType,
    correlationId: correlationId,
    targetLabel: targetLabel,
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

  group('Activity UI pure helpers', () {
    test('auditFriendlyError surfaces safe text and masks technical errors', () {
      expect(
        auditFriendlyError(
          Exception('Request timed out'),
          'Fallback copy',
        ),
        'Request timed out',
      );
      expect(
        auditFriendlyError(
          'Exception: Exception: Audit query failed.',
          'Fallback copy',
        ),
        'Audit query failed.',
      );
      expect(
        auditFriendlyError(
          Exception('PostgrestException: relation error'),
          'Fallback copy',
        ),
        'Fallback copy',
      );
      expect(
        auditFriendlyError(
          Exception('Error loading audit_logs: permission denied'),
          'Fallback copy',
        ),
        'Fallback copy',
      );
      expect(
        auditFriendlyError(
          Exception('SocketException: host lookup failed'),
          'Fallback copy',
        ),
        'Fallback copy',
      );
      expect(auditFriendlyError('', 'Fallback copy'), 'Fallback copy');
      expect(auditFriendlyError('x' * 165, 'Fallback copy'), 'Fallback copy');
    });

    test('auditActorDisplayName handles named, system, and unknown actors', () {
      expect(auditActorDisplayName(_sampleLog(userName: '  Maria  ')), 'Maria');
      expect(
        auditActorDisplayName(
          _sampleLog(userName: '', actorType: AuditActorTypes.system),
        ),
        'System',
      );
      expect(
        auditActorDisplayName(
          _sampleLog(userName: '  ', actorType: AuditActorTypes.alumni),
        ),
        'Unknown',
      );
    });

    test('auditTargetSummary prefers targetLabel, then resource/id, then dash', () {
      expect(auditTargetSummary(_sampleLog(targetLabel: 'Ana')), 'Ana');
      expect(
        auditTargetSummary(
          _sampleLog(targetLabel: null, resource: 'Job', resourceId: 'j-9'),
        ),
        'Job · j-9',
      );
      expect(
        auditTargetSummary(
          _sampleLog(targetLabel: '', resource: 'Job', resourceId: ''),
        ),
        'Job',
      );
      expect(
        auditTargetSummary(
          _sampleLog(targetLabel: null, resource: '', resourceId: 'x'),
        ),
        '—',
      );
    });

    test('auditFormatChanges renders from -> to diffs and plain values', () {
      final text = auditFormatChanges({
        'batch': {'from': '2020', 'to': '2021'},
        'rowCount': 12,
      });
      expect(text, 'batch: 2020 → 2021\nrowCount: 12');
    });

    test('status badge tone and table colors distinguish SUCCESS/REJECTED/FAILED',
        () {
      expect(auditStatusBadgeTone(AuditStatus.success), AdminBadgeTone.success);
      expect(auditStatusBadgeTone(AuditStatus.rejected), AdminBadgeTone.warning);
      expect(auditStatusBadgeTone(AuditStatus.failed), AdminBadgeTone.danger);

      expect(
        auditStatusTableColors(AuditStatus.success).fg,
        AdminTableTheme.success,
      );
      expect(
        auditStatusTableColors(AuditStatus.rejected).fg,
        AdminTableTheme.warning,
      );
      expect(
        auditStatusTableColors(AuditStatus.failed).fg,
        AdminTableTheme.danger,
      );
    });
  });

  group('AdminActivityStatusBadge & AdminActivityLogCard', () {
    testWidgets('status badge renders SUCCESS, REJECTED, and FAILED',
        (tester) async {
      await pumpAdmin(
        tester,
        const Wrap(
          spacing: 8,
          children: [
            AdminActivityStatusBadge(status: AuditStatus.success),
            AdminActivityStatusBadge(status: AuditStatus.rejected),
            AdminActivityStatusBadge(status: AuditStatus.failed),
          ],
        ),
      );

      expect(find.text('SUCCESS'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.text('FAILED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final width in kAdminTestWidths) {
      testWidgets('AdminActivityLogCard renders without overflow at $width px',
          (tester) async {
        var tapped = false;
        await pumpAdmin(
          tester,
          AdminActivityLogCard(
            log: _sampleLog(),
            onTap: () => tapped = true,
          ),
          width: width,
        );

        expect(find.text(AuditActions.updateRosterMember), findsOneWidget);
        expect(find.text('Admin User (admin)'), findsOneWidget);
        expect(find.text(AuditModules.alumni), findsOneWidget);
        expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byType(AdminActivityLogCard));
        await tester.pump();
        expect(tapped, isTrue);
      });
    }
  });

  group('AdminActivityLogDetailPanel & showAdminActivityLogDetailPanel', () {
    testWidgets('displays structured details, IP, diff, and copies metadata',
        (tester) async {
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await pumpAdmin(
        tester,
        SizedBox(
          height: 680,
          child: AdminActivityLogDetailPanel(
            log: _sampleLog(status: AuditStatus.rejected),
          ),
        ),
        width: 480,
      );

      expect(find.text(AuditActions.updateRosterMember), findsOneWidget);
      // Badge + Result detail row both display 'REJECTED'.
      expect(find.text('REJECTED'), findsNWidgets(2));
      expect(find.text('security'), findsNWidgets(2));
      expect(find.text('192.168.1.15'), findsOneWidget);
      expect(find.text('mem-42'), findsOneWidget);
      expect(find.text('corr-9001'), findsOneWidget);

      await tester.tap(find.byTooltip('Copy target ID'));
      await tester.pump();
      expect(copied.last, 'mem-42');
      expect(find.text('Target ID copied'), findsOneWidget);

      await tester.tap(find.byTooltip('Copy correlation ID'));
      await tester.pump();
      expect(copied.last, 'corr-9001');
      expect(find.text('Correlation ID copied'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Updated alumni batch year'),
        120,
        scrollable: scrollable,
      );
      expect(find.text('Updated alumni batch year'), findsOneWidget);

      final metadataFinder = find.byWidgetPredicate(
        (w) =>
            w is SelectableText &&
            (w.data?.contains('batch: 2020 → 2021') ?? false),
      );
      await tester.scrollUntilVisible(
        metadataFinder,
        120,
        scrollable: scrollable,
      );
      expect(metadataFinder, findsOneWidget);

      await tester.tap(find.text('Copy metadata'));
      await tester.pumpAndSettle();
      expect(copied.last, 'batch: 2020 → 2021\nstatus: active');
      expect(find.text('Metadata copied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'showAdminActivityLogDetailPanel opens side panel on desktop and dialog on phone',
        (tester) async {
      for (final size in const [Size(1280, 800), Size(360, 720)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showAdminActivityLogDetailPanel(
                      context,
                      _sampleLog(id: 'log-${size.width.toInt()}'),
                    ),
                    child: const Text('Inspect log'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Inspect log'));
        await tester.pumpAndSettle();

        expect(find.byType(AdminActivityLogDetailPanel), findsOneWidget);
        expect(find.text(AuditActions.updateRosterMember), findsOneWidget);

        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminActivityLogDetailPanel), findsNothing);
        expect(tester.takeException(), isNull);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });
  });

  group('AdminActivityLogSkeleton', () {
    for (final width in kAdminTestWidths) {
      testWidgets(
          'renders in bounded and unbounded layouts without overflow ($width px)',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                child: AdminActivityLogSkeleton(count: 4),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminActivityLogSkeleton(count: 4),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

