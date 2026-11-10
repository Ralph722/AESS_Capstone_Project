import 'dart:convert';

import 'package:alumni_system/features/admin/forum/widgets/admin_forum_ui.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/presentation/forum_composer_page.dart';
import 'package:alumni_system/features/forum/presentation/forum_topic_page.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_shared/admin_test_harness.dart';

ForumTopic _topic({
  String id = 't-1',
  String title = 'Graduate Tracer Deadline Reminder',
  String body = 'Please complete your form.',
  String authorName = 'Juan Dela Cruz',
  String authorProgram = 'BSIT',
  String authorBatch = '2024',
  int replyCount = 2,
  int viewCount = 15,
  bool isLocked = false,
  bool isPinned = false,
  bool isSolved = false,
  bool isAnnouncement = false,
  List<ForumTag> tags = const [],
}) {
  return ForumTopic(
    id: id,
    title: title,
    body: body,
    authorUid: 'user-1',
    authorName: authorName,
    authorProgram: authorProgram,
    authorBatch: authorBatch,
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 2),
    lastReplyAt: replyCount > 0 ? DateTime(2026, 11, 3) : null,
    replyCount: replyCount,
    viewCount: viewCount,
    isLocked: isLocked,
    isPinned: isPinned,
    isSolved: isSolved,
    isAnnouncement: isAnnouncement,
    tags: tags,
  );
}

ForumReport _report({
  String id = 'rep-1',
  String? topicId = 't-1',
  String? postId = 'p-1',
  String status = 'open',
  String reason = 'Off-topic spam link posted in thread.',
  String? topicTitle = 'Alumni Homecoming',
  String? reporterName = 'Maria Santos',
}) {
  return ForumReport(
    id: id,
    reporterUid: 'user-2',
    topicId: topicId,
    postId: postId,
    reason: reason,
    status: status,
    createdAt: DateTime(2026, 11, 5, 14, 30),
    updatedAt: DateTime(2026, 11, 5, 14, 30),
    topicTitle: topicTitle,
    reporterName: reporterName,
  );
}

class _StubTopicService extends ForumService {
  _StubTopicService(this.topic) : super(supabase: Supabase.instance.client);

  final ForumTopic? topic;

  @override
  Stream<ForumTopic?> watchTopic(String topicId) => Stream.value(topic);

  @override
  Stream<List<ForumPost>> watchPosts(String topicId) =>
      Stream.value(const <ForumPost>[]);

  @override
  Future<void> incrementViews(String topicId) async {}
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

  group('forumFriendlyError', () {
    test('preserves readable error text and masks technical errors', () {
      expect(
        forumFriendlyError(
          Exception('Network timeout'),
          'Fallback message',
        ),
        'Network timeout',
      );
      expect(
        forumFriendlyError(
          Exception('PostgrestException: permission denied'),
          'Fallback message',
        ),
        'Fallback message',
      );
      expect(
        forumFriendlyError(
          Exception('Error deleting topic: constraint'),
          'Fallback message',
        ),
        'Fallback message',
      );
      expect(
        forumFriendlyError('', 'Fallback message'),
        'Fallback message',
      );
      expect(
        forumFriendlyError('x' * 170, 'Fallback message'),
        'Fallback message',
      );
    });
  });

  group('AdminForumTopicStatusBadges', () {
    testWidgets('renders AdminBadges and suppresses redundant Pinned on announcement',
        (tester) async {
      await pumpAdmin(
        tester,
        AdminForumTopicStatusBadges(
          topic: _topic(
            isAnnouncement: true,
            isPinned: true,
            isLocked: true,
            replyCount: 0,
          ),
        ),
      );

      expect(find.byType(AdminBadge), findsNWidgets(2));
      expect(find.text('Announcement'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
      expect(find.text('Pinned'), findsNothing);
    });

    testWidgets('renders Pinned, Solved, and Needs response when applicable',
        (tester) async {
      await pumpAdmin(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminForumTopicStatusBadges(
              topic: _topic(isPinned: true, isSolved: true),
            ),
            const SizedBox(height: 8),
            AdminForumTopicStatusBadges(
              topic: _topic(replyCount: 0),
            ),
          ],
        ),
      );

      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('Solved'), findsOneWidget);
      expect(find.text('Needs response'), findsOneWidget);
    });
  });

  group('AdminForumTopicCard', () {
    final menuItems = [
      adminForumMenuItem(
        value: 'view',
        label: 'Open discussion',
        icon: Icons.open_in_new_rounded,
      ),
      adminForumMenuItem(
        value: 'pin',
        label: 'Pin to top',
        icon: Icons.push_pin_outlined,
      ),
    ];

    for (final width in kAdminTestWidths) {
      testWidgets('renders cleanly across widths ($width px)', (tester) async {
        final tags = List.generate(
          4,
          (i) => ForumTag(
            id: 'tag-$i',
            slug: 'tag-$i',
            label: 'Tag ${i + 1}',
          ),
        );
        await pumpAdmin(
          tester,
          AdminForumTopicCard(
            topic: _topic(tags: tags, isPinned: true),
            menuItems: menuItems,
            onMenuSelected: (_) {},
            onOpen: () {},
          ),
          width: width,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Graduate Tracer Deadline Reminder'), findsOneWidget);
        expect(find.text('Juan Dela Cruz · BSIT · Batch 2024'), findsOneWidget);
        expect(find.text('Tag 1'), findsOneWidget);
        expect(find.text('Tag 3'), findsOneWidget);
        expect(find.text('Tag 4'), findsNothing);
        expect(
          find.text('ENGAGEMENT & ACTIVITY'),
          width >= AdminForumTopicCard.zoneLayoutMinWidth
              ? findsOneWidget
              : findsNothing,
        );
      });
    }

    testWidgets('fires onOpen/onMenuSelected and shows spinner when busy',
        (tester) async {
      var opened = false;
      String? picked;

      await pumpAdmin(
        tester,
        AdminForumTopicCard(
          topic: _topic(),
          menuItems: menuItems,
          onMenuSelected: (v) => picked = v,
          onOpen: () => opened = true,
        ),
      );

      await tester.tap(find.text('Graduate Tracer Deadline Reminder'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);

      await tester.tap(find.byTooltip('Discussion actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pin to top'));
      await tester.pumpAndSettle();
      expect(picked, 'pin');

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1366, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: AdminForumTopicCard(
                topic: _topic(),
                menuItems: menuItems,
                busy: true,
                onMenuSelected: (_) {},
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });
  });

  group('AdminForumReportCard', () {
    for (final width in kAdminTestWidths) {
      testWidgets('renders open report cleanly at $width px', (tester) async {
        await pumpAdmin(
          tester,
          AdminForumReportCard(
            report: _report(),
            onOpenTopic: () {},
            onResolve: () {},
          ),
          width: width,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Alumni Homecoming'), findsOneWidget);
        expect(find.text('Open'), findsNWidgets(2));
        expect(find.text('Reply report'), findsOneWidget);
        expect(find.text('Resolve'), findsOneWidget);
      });
    }

    testWidgets('renders resolved report & spinner when busy', (tester) async {
      await pumpAdmin(
        tester,
        AdminForumReportCard(
          report: _report(postId: null, status: 'resolved'),
          onOpenTopic: () {},
          onReopen: () {},
        ),
      );

      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Topic report'), findsOneWidget);
      expect(find.text('Reopen'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminForumReportCard(
              report: _report(),
              busy: true,
              onOpenTopic: () {},
              onResolve: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AdminForumListSkeleton & admin forum panels', () {
    testWidgets('AdminForumListSkeleton renders across desktop and mobile widths',
        (tester) async {
      for (final width in [320.0, 1366.0]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 500,
                child: AdminForumListSkeleton(count: 3),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(Skeleton), findsWidgets);
      }
    });

    testWidgets('ForumComposerPage(asSidePanel: true) renders admin header & footer',
        (tester) async {
      await pumpAdmin(
        tester,
        const SizedBox(
          width: 560,
          height: 620,
          child: ForumComposerPage(
            asSidePanel: true,
            initialAsAnnouncement: true,
          ),
        ),
        width: 1280,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('New announcement'), findsOneWidget);
      expect(
        find.text('Pinned announcement for all alumni'),
        findsOneWidget,
      );
      expect(find.text('Write'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Post'), findsOneWidget);
    });

    testWidgets('ForumTopicScreen(embedded: true) shows Back button on wide and tooltip on narrow',
        (tester) async {
      final stub = _StubTopicService(
        _topic(isAnnouncement: true, title: 'Career Fair Schedule'),
      );
      var closed = false;

      await pumpAdmin(
        tester,
        SizedBox(
          height: 560,
          child: ForumTopicScreen(
            topicId: 't-1',
            embedded: true,
            service: stub,
            onClose: () => closed = true,
          ),
        ),
        width: 1024,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Announcement thread'), findsOneWidget);
      expect(find.text('Career Fair Schedule'), findsWidgets);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);

      await pumpAdmin(
        tester,
        SizedBox(
          height: 560,
          child: ForumTopicScreen(
            topicId: 't-1',
            embedded: true,
            service: stub,
            onClose: () {},
          ),
        ),
        width: 360,
      );

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Back to forum list'), findsOneWidget);
    });
  });
}

