import 'package:alumni_system/features/admin/announcements/widgets/admin_announcement_ui.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../admin_shared/admin_test_harness.dart';

Announcement _announcement({
  String id = 'ann-1',
  String title = 'Graduate Tracer Survey Reminder',
  String body = 'Please complete your graduate tracer form this week.',
  AnnouncementStatus status = AnnouncementStatus.published,
  AnnouncementPriority priority = AnnouncementPriority.important,
  List<String> programs = const ['BSIT'],
  List<String> batches = const ['2024'],
  bool notifyInApp = true,
  bool notifyPush = true,
  bool notifyEmail = false,
  bool urgent = true,
  int recipientCount = 42,
}) {
  return Announcement(
    id: id,
    title: title,
    body: body,
    status: status,
    priority: priority,
    targetPrograms: programs,
    targetBatchYears: batches,
    notifyInApp: notifyInApp,
    notifyPush: notifyPush,
    notifyEmail: notifyEmail,
    urgent: urgent,
    createdBy: 'admin-1',
    createdAt: DateTime(2026, 11, 1),
    publishedAt: status == AnnouncementStatus.published
        ? DateTime(2026, 11, 2)
        : null,
    recipientCount: recipientCount,
  );
}

void main() {
  group('announcement helpers', () {
    test('announcementFriendlyError masks technical exceptions', () {
      expect(
        announcementFriendlyError(
          Exception('Network timeout'),
          'Fallback message',
        ),
        'Network timeout',
      );
      expect(
        announcementFriendlyError(
          Exception('PostgrestException: relation error'),
          'Fallback message',
        ),
        'Fallback message',
      );
      expect(
        announcementFriendlyError(
          Exception('Error creating announcement: RLS'),
          'Fallback message',
        ),
        'Fallback message',
      );
      expect(
        announcementFriendlyError('', 'Fallback message'),
        'Fallback message',
      );
    });

    test('announcementAudienceSummary & announcementDeliveryChannels format cleanly',
        () {
      expect(
        announcementAudienceSummary(
          _announcement(programs: const [], batches: const []),
        ),
        'All alumni',
      );
      expect(
        announcementAudienceSummary(
          _announcement(programs: const ['BSIT'], batches: const ['2024']),
        ),
        'BSIT · Batch 2024',
      );
      expect(
        announcementAudienceSummary(
          _announcement(
            programs: const ['BSIT', 'BFPT'],
            batches: const ['2023', '2024'],
          ),
        ),
        '2 courses · 2 batches',
      );
      expect(
        announcementDeliveryChannels(
          _announcement(
            notifyInApp: true,
            notifyPush: true,
            notifyEmail: true,
          ),
        ),
        ['In-app', 'Push', 'Email'],
      );
      expect(
        announcementDeliveryChannels(
          _announcement(
            notifyInApp: false,
            notifyPush: true,
            notifyEmail: false,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('Announcement badges & card', () {
    testWidgets('status and priority chips render AdminBadge', (tester) async {
      await pumpAdmin(
        tester,
        const Wrap(
          spacing: 8,
          children: [
            AnnouncementStatusChip(status: AnnouncementStatus.draft),
            AnnouncementStatusChip(status: AnnouncementStatus.published),
            AnnouncementStatusChip(status: AnnouncementStatus.archived),
            AnnouncementPriorityChip(priority: AnnouncementPriority.important),
            AnnouncementPriorityChip(priority: AnnouncementPriority.normal),
          ],
        ),
      );

      expect(find.byType(AdminBadge), findsNWidgets(4));
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Important'), findsOneWidget);
    });

    testWidgets(
        'AnnouncementListCard renders across desktop, tablet, and mobile without overflow',
        (tester) async {
      final item = _announcement();

      for (final width in kAdminTestWidths) {
        var opened = false;
        String? selectedAction;

        await pumpAdmin(
          tester,
          AnnouncementListCard(
            announcement: item,
            onOpen: () => opened = true,
            onMenuSelected: (v) => selectedAction = v,
            menuItems: [
              adminAnnouncementMenuItem(
                value: 'edit',
                label: 'Open details',
                icon: Icons.edit_outlined,
              ),
              adminAnnouncementMenuItem(
                value: 'delete',
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
                destructive: true,
              ),
            ],
          ),
          width: width,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Graduate Tracer Survey Reminder'), findsOneWidget);
        expect(find.text('Published'), findsOneWidget);
        expect(find.text('Important'), findsOneWidget);
        expect(find.text('Urgent'), findsOneWidget);

        if (width >= AnnouncementListCard.zoneLayoutMinWidth) {
          expect(find.text('AUDIENCE & DELIVERY'), findsOneWidget);
          expect(find.text('REACH & TIMELINE'), findsOneWidget);
          expect(find.text('42 alumni reached'), findsOneWidget);
        } else {
          expect(find.text('42 reached'), findsOneWidget);
        }

        await tester.tap(find.text('Graduate Tracer Survey Reminder'));
        await tester.pump();
        expect(opened, isTrue);

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open details').last);
        await tester.pumpAndSettle();
        expect(selectedAction, 'edit');
      }
    });

    testWidgets('busy state shows progress indicator instead of menu',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementListCard(
              announcement: _announcement(),
              busy: true,
              onMenuSelected: (_) {},
              menuItems: const [],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('AdminAnnouncementsListSkeleton renders inside ShimmerScope',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminAnnouncementsListSkeleton(count: 3),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ShimmerScope), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });
  });
}

