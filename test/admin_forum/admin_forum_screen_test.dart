import 'dart:convert';

import 'package:alumni_system/features/admin/forum/presentation/admin_forum_page.dart';
import 'package:alumni_system/features/admin/forum/widgets/admin_forum_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/presentation/forum_topic_page.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_metric_ribbon.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_tabs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_toolbar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeForumService extends ForumService {
  _FakeForumService({
    required this.topics,
    required this.reports,
    this.postsByTopic = const {},
  }) : super(supabase: Supabase.instance.client);

  final List<ForumTopic> topics;
  final List<ForumReport> reports;
  final Map<String, List<ForumPost>> postsByTopic;

  bool throwOnGetTopics = false;
  bool throwOnGetReports = false;
  int getAllTopicsCalls = 0;

  final List<(String id, bool locked, String? reason)> lockCalls = [];
  final List<(String id, bool pinned)> pinCalls = [];
  final List<(String id, bool solved)> solveCalls = [];
  final List<(String id, String? reason)> deleteCalls = [];
  final List<(String id, String status)> reportStatusCalls = [];

  @override
  Future<List<ForumTopic>> getAllTopics() async {
    getAllTopicsCalls++;
    if (throwOnGetTopics) {
      throw Exception('Network timeout');
    }
    return List.of(topics);
  }

  @override
  Future<ForumTopic?> getTopic(String topicId) async {
    for (final t in topics) {
      if (t.id == topicId) return t;
    }
    return null;
  }

  @override
  Future<List<ForumPost>> getPosts(String topicId) async =>
      List.of(postsByTopic[topicId] ?? const []);

  @override
  Stream<ForumTopic?> watchTopic(String topicId) async* {
    yield await getTopic(topicId);
  }

  @override
  Stream<List<ForumPost>> watchPosts(String topicId) async* {
    yield await getPosts(topicId);
  }

  @override
  Future<void> incrementViews(String topicId) async {}

  @override
  Future<int> getOpenReportCount() async =>
      reports.where((r) => r.isOpen).length;

  @override
  Future<List<ForumReport>> getReports({String? status}) async {
    if (throwOnGetReports) {
      throw Exception('PostgrestException: permission error');
    }
    if (status == null || status == 'all') {
      return List.of(reports);
    }
    return reports.where((r) => r.status == status).toList();
  }

  @override
  Future<void> updateReportStatus(String reportId, String status) async {
    reportStatusCalls.add((reportId, status));
    final idx = reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      final prev = reports[idx];
      reports[idx] = ForumReport(
        id: prev.id,
        reporterUid: prev.reporterUid,
        topicId: prev.topicId,
        postId: prev.postId,
        reason: prev.reason,
        status: status,
        createdAt: prev.createdAt,
        updatedAt: DateTime(2026, 11, 11),
        topicTitle: prev.topicTitle,
        reporterName: prev.reporterName,
      );
    }
  }

  @override
  Future<void> setTopicLocked(
    String topicId,
    bool locked, {
    String? reason,
  }) async {
    lockCalls.add((topicId, locked, reason));
    final idx = topics.indexWhere((t) => t.id == topicId);
    if (idx != -1) {
      topics[idx] = topics[idx].copyWith(
        isLocked: locked,
        moderationReason: reason,
      );
    }
  }

  @override
  Future<void> setTopicPinned(String topicId, bool pinned) async {
    pinCalls.add((topicId, pinned));
    final idx = topics.indexWhere((t) => t.id == topicId);
    if (idx != -1) {
      topics[idx] = topics[idx].copyWith(isPinned: pinned);
    }
  }

  @override
  Future<void> setTopicSolved(String topicId, bool solved) async {
    solveCalls.add((topicId, solved));
    final idx = topics.indexWhere((t) => t.id == topicId);
    if (idx != -1) {
      topics[idx] = topics[idx].copyWith(isSolved: solved);
    }
  }

  @override
  Future<void> deleteTopic(String topicId, {String? reason}) async {
    deleteCalls.add((topicId, reason));
    topics.removeWhere((t) => t.id == topicId);
  }
}

List<ForumTopic> _seedTopics() => [
  ForumTopic(
    id: 't-ann',
    title: 'Career Fair 2026 Schedule',
    body: 'Join the annual fair on campus.',
    authorUid: 'admin-1',
    authorName: 'AESS Admin',
    authorProgram: 'BSIT',
    authorBatch: '2024',
    createdAt: DateTime(2026, 11, 8),
    updatedAt: DateTime(2026, 11, 8),
    replyCount: 4,
    viewCount: 90,
    isAnnouncement: true,
    isPinned: true,
    tags: const [ForumTag(id: 'tag-1', slug: 'careers', label: 'Careers')],
  ),
  ForumTopic(
    id: 't-unans',
    title: 'Tracer Survey Help',
    body: 'Where can I update my employer name?',
    authorUid: 'u-1',
    authorName: 'Juan Dela Cruz',
    authorProgram: 'BSIT',
    authorBatch: '2023',
    createdAt: DateTime(2026, 11, 9),
    updatedAt: DateTime(2026, 11, 9),
    replyCount: 0,
    viewCount: 12,
  ),
  ForumTopic(
    id: 't-locked',
    title: 'Old Thread Archive',
    body: 'Moved to new batch group.',
    authorUid: 'u-2',
    authorName: 'Maria Santos',
    authorProgram: 'BSED',
    authorBatch: '2020',
    createdAt: DateTime(2026, 11, 3),
    updatedAt: DateTime(2026, 11, 4),
    lastReplyAt: DateTime(2026, 11, 5),
    replyCount: 3,
    viewCount: 44,
    isLocked: true,
  ),
];

List<ForumReport> _seedReports() => [
  ForumReport(
    id: 'rep-open',
    reporterUid: 'u-3',
    topicId: 't-unans',
    postId: 'p-1',
    reason: 'Off-topic promotional link posted.',
    status: 'open',
    createdAt: DateTime(2026, 11, 10, 9, 0),
    updatedAt: DateTime(2026, 11, 10, 9, 0),
    topicTitle: 'Tracer Survey Help',
    reporterName: 'Pedro Reyes',
  ),
];

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

  group('AdminForumScreen', () {
    testWidgets(
      'renders SaaS chrome and filters cached catalog via ribbon, dropdown, and search without refetching',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final service = _FakeForumService(
          topics: _seedTopics(),
          reports: _seedReports(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminForumScreen(service: service),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AdminCompactHeader), findsOneWidget);
        expect(find.byType(AdminSaaSTabs), findsOneWidget);
        expect(find.byType(AdminMetricRibbon), findsOneWidget);
        expect(find.byType(AdminSaaSToolbar), findsOneWidget);
        final header = tester.widget<AdminCompactHeader>(
          find.byType(AdminCompactHeader),
        );
        expect(header.title, 'Forum');
        expect(header.countBadge, isNull);
        expect(header.subtitle, isNull);
        expect(
          find.descendant(
            of: find.byType(AdminCompactHeader),
            matching: find.byIcon(Icons.info_outline_rounded),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AdminCompactHeader),
            matching: find.textContaining('topics'),
          ),
          findsNothing,
        );

        final headerRefresh = find.descendant(
          of: find.byType(AdminCompactHeader),
          matching: find.text('Refresh'),
        );
        final headerExport = find.descendant(
          of: find.byType(AdminCompactHeader),
          matching: find.text('Export'),
        );
        final headerNewAnnouncement = find.descendant(
          of: find.byType(AdminCompactHeader),
          matching: find.text('New announcement'),
        );
        expect(headerRefresh, findsOneWidget);
        expect(headerExport, findsOneWidget);
        expect(headerNewAnnouncement, findsOneWidget);
        expect(
          tester.getTopLeft(headerRefresh).dx,
          lessThan(tester.getTopLeft(headerExport).dx),
        );
        expect(
          tester.getTopLeft(headerExport).dx,
          lessThan(tester.getTopLeft(headerNewAnnouncement).dx),
        );

        final toolbar = tester.widget<AdminSaaSToolbar>(
          find.byType(AdminSaaSToolbar),
        );
        expect(toolbar.onRefresh, isNull);
        expect(
          find.descendant(
            of: find.byType(AdminSaaSToolbar),
            matching: find.byTooltip('Refresh discussions'),
          ),
          findsNothing,
        );
        expect(toolbar.filters, hasLength(6));
        for (var i = 0; i < 5; i++) {
          expect(toolbar.filters[i], isA<ForumToolbarFilterChip>());
        }
        expect(toolbar.filters[5], isA<DirectoryFilterField<String?>>());
        final lastChipDx = tester
            .getTopLeft(find.byType(ForumToolbarFilterChip).last)
            .dx;
        final programDropdownDx = tester
            .getTopLeft(find.byType(DirectoryFilterField<String?>))
            .dx;
        expect(lastChipDx, lessThan(programDropdownDx));
        expect(service.getAllTopicsCalls, 1);

        expect(find.text('Career Fair 2026 Schedule'), findsOneWidget);
        expect(find.text('Tracer Survey Help'), findsOneWidget);
        expect(find.text('Old Thread Archive'), findsOneWidget);

        // Filter via Unanswered toolbar chip without triggering a second fetch.
        await tester.tap(
          find.descendant(
            of: find.byType(AdminSaaSToolbar),
            matching: find.text('Unanswered'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Tracer Survey Help'), findsOneWidget);
        expect(find.text('Career Fair 2026 Schedule'), findsNothing);
        expect(service.getAllTopicsCalls, 1);

        // Toggle Locked toolbar chip.
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AdminSaaSToolbar),
            matching: find.text('Locked'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Old Thread Archive'), findsOneWidget);
        expect(find.text('Tracer Survey Help'), findsNothing);
        expect(service.getAllTopicsCalls, 1);

        // Reset via toolbar Reset button.
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();
        expect(find.text('Career Fair 2026 Schedule'), findsOneWidget);
        expect(find.text('Old Thread Archive'), findsOneWidget);

        // Filter by Program = BSED.
        await tester.tap(find.text('All programs'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('BSED').last);
        await tester.pumpAndSettle();
        expect(find.text('Old Thread Archive'), findsOneWidget);
        expect(find.text('Career Fair 2026 Schedule'), findsNothing);
        expect(service.getAllTopicsCalls, 1);

        // Clear via Reset.
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();

        // Debounced in-memory search.
        await tester.enterText(find.byType(TextField).first, 'Tracer');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.text('Tracer Survey Help'), findsOneWidget);
        expect(find.text('Old Thread Archive'), findsNothing);
        expect(service.getAllTopicsCalls, 1);
      },
    );

    testWidgets(
      'opens embedded ForumTopicScreen on card tap and returns cleanly via Back',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final service = _FakeForumService(
          topics: _seedTopics(),
          reports: const [],
          postsByTopic: {
            't-unans': [
              ForumPost(
                id: 'p-1',
                topicId: 't-unans',
                body: 'You can update your employer in Profile > Employment.',
                authorUid: 'admin-1',
                authorName: 'AESS Admin',
                createdAt: DateTime(2026, 11, 10),
              ),
            ],
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminForumScreen(service: service),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tracer Survey Help'));
        await tester.pumpAndSettle();

        expect(find.byType(ForumTopicScreen), findsOneWidget);
        expect(find.text('Back'), findsOneWidget);
        expect(find.text('Forum discussion'), findsOneWidget);
        expect(find.text('Replies (1)'), findsOneWidget);
        expect(
          find.text('You can update your employer in Profile > Employment.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminCompactHeader), findsOneWidget);
        expect(find.byType(ForumTopicScreen), findsNothing);
      },
    );

    testWidgets(
      'exports CSV dialog and executes pin, lock-with-reason, solve, and two-step delete moderation',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final service = _FakeForumService(
          topics: _seedTopics(),
          reports: const [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminForumScreen(service: service),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // CSV export dialog
        await tester.tap(find.text('Export'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminModalHeader), findsOneWidget);
        expect(find.text('Export discussions CSV'), findsOneWidget);
        expect(find.text('3 discussions in the current view.'), findsOneWidget);
        expect(find.text('Copy CSV'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        Finder menuFor(String title) => find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(AdminForumTopicCard),
          ),
          matching: find.byTooltip('Discussion actions'),
        );

        // Pin topic
        await tester.tap(menuFor('Tracer Survey Help'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pin to top'));
        await tester.pumpAndSettle();
        expect(service.pinCalls, [('t-unans', true)]);
        expect(find.text('Topic pinned'), findsOneWidget);

        // Lock topic with moderation reason dialog
        await tester.tap(menuFor('Tracer Survey Help'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lock topic'));
        await tester.pumpAndSettle();
        expect(find.text('Lock topic?'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, 'Duplicate thread');
        await tester.tap(find.text('Lock'));
        await tester.pumpAndSettle();
        expect(service.lockCalls, [('t-unans', true, 'Duplicate thread')]);
        expect(find.text('Topic locked'), findsOneWidget);

        // Mark solved
        await tester.tap(menuFor('Tracer Survey Help'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mark solved'));
        await tester.pumpAndSettle();
        expect(service.solveCalls, [('t-unans', true)]);
        expect(find.text('Marked as solved'), findsOneWidget);

        // Two-step Delete topic (moderation reason -> destructive AdminConfirmDialog)
        await tester.tap(menuFor('Tracer Survey Help'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete topic'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Spam content');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Permanently delete “Tracer Survey Help”'),
          findsOneWidget,
        );
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(service.deleteCalls, [('t-unans', 'Spam content')]);
        expect(find.text('Tracer Survey Help'), findsNothing);
      },
    );

    testWidgets('switches to Reports tab and resolves then reopens a report',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final service = _FakeForumService(
        topics: _seedTopics(),
        reports: _seedReports(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminForumScreen(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();

      final reportsHeader = tester.widget<AdminCompactHeader>(
        find.byType(AdminCompactHeader),
      );
      expect(reportsHeader.countBadge, isNull);
      expect(reportsHeader.subtitle, isNull);
      expect(
        find.descendant(
          of: find.byType(AdminCompactHeader),
          matching: find.text('Refresh'),
        ),
        findsOneWidget,
      );
      final reportsToolbar = tester.widget<AdminSaaSToolbar>(
        find.byType(AdminSaaSToolbar),
      );
      expect(reportsToolbar.onRefresh, isNull);
      expect(
        find.descendant(
          of: find.byType(AdminSaaSToolbar),
          matching: find.byTooltip('Refresh reports'),
        ),
        findsNothing,
      );

      expect(find.byType(AdminForumReportCard), findsOneWidget);
      expect(find.text('Off-topic promotional link posted.'), findsOneWidget);

      await tester.tap(find.text('Resolve'));
      await tester.pumpAndSettle();
      expect(service.reportStatusCalls, [('rep-open', 'resolved')]);
      expect(find.text('No open reports'), findsOneWidget);

      await tester.tap(find.text('Resolved'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminForumReportCard), findsOneWidget);

      await tester.tap(find.text('Reopen'));
      await tester.pumpAndSettle();
      expect(service.reportStatusCalls.last, ('rep-open', 'open'));
    });

    testWidgets(
      'displays error recovery on initial load failure and warning notice on silent refresh failure',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final service = _FakeForumService(
          topics: _seedTopics(),
          reports: const [],
        )..throwOnGetTopics = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminForumScreen(service: service),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AdminStateView), findsOneWidget);
        expect(find.text("Couldn't load forum discussions"), findsOneWidget);

        service.throwOnGetTopics = false;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text('Career Fair 2026 Schedule'), findsOneWidget);

        service.throwOnGetTopics = true;
        await tester.tap(
          find.descendant(
            of: find.byType(AdminCompactHeader),
            matching: find.text('Refresh'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Career Fair 2026 Schedule'), findsOneWidget);
        expect(
          find.text(
            "Couldn't refresh forum data. Showing the last loaded list.",
          ),
          findsOneWidget,
        );
      },
    );
  });
}

