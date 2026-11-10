import 'package:alumni_system/core/constants/event_category_constants.dart';
import 'package:alumni_system/features/admin/events/widgets/admin_event_ui.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/models/event_rsvp_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../admin_shared/admin_test_harness.dart';

AlumniEvent _makeEvent({
  String id = 'evt-1',
  String theme = 'Annual Alumni Homecoming',
  String batchYear = '2020',
  DateTime? date,
  String venue = 'USTP Gymnasium',
  String status = 'Active',
  int comments = 4,
  String startTime = '09:00',
  String endTime = '17:00',
  String category = EventCategoryConstants.homecoming,
  int? capacity = 100,
  int viewsCount = 42,
  bool cancelled = false,
  double? venueLatitude,
  double? venueLongitude,
}) {
  final now = DateTime.now();
  return AlumniEvent(
    id: id,
    theme: theme,
    batchYear: batchYear,
    date: date ?? DateTime(now.year, now.month, now.day).add(const Duration(days: 3)),
    venue: venue,
    status: status,
    comments: comments,
    startTime: startTime,
    endTime: endTime,
    category: category,
    capacity: capacity,
    viewsCount: viewsCount,
    cancelled: cancelled,
    venueLatitude: venueLatitude,
    venueLongitude: venueLongitude,
  );
}

void main() {
  group('event helpers', () {
    test('eventFriendlyError strips technical prefixes and long traces', () {
      expect(
        eventFriendlyError(Exception('Network timeout'), 'Fallback message'),
        'Network timeout',
      );
      expect(
        eventFriendlyError(
          Exception('PostgrestException: stack trace detail'),
          'Fallback message',
        ),
        'Fallback message',
      );
      expect(eventFriendlyError('', 'Fallback message'), 'Fallback message');
    });

    test('eventDaysUntil returns calendar day offsets', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 18, 0);
      final tomorrow = today.add(const Duration(days: 1));
      final yesterday = today.subtract(const Duration(days: 1));

      expect(eventDaysUntil(_makeEvent(date: today)), 0);
      expect(eventDaysUntil(_makeEvent(date: tomorrow)), 1);
      expect(eventDaysUntil(_makeEvent(date: yesterday)), -1);
    });
  });

  group('AdminEventStatusBadge & AdminEventCountdownBadge', () {
    testWidgets('renders derived statuses and countdown labels', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final past = today.subtract(const Duration(days: 5));
      final future = today.add(const Duration(days: 5));

      await pumpAdmin(
        tester,
        Wrap(
          spacing: 8,
          children: [
            AdminEventStatusBadge(event: _makeEvent(date: future)),
            AdminEventStatusBadge(event: _makeEvent(date: past)),
            AdminEventStatusBadge(
              event: _makeEvent(date: future, cancelled: true),
            ),
            AdminEventStatusBadge(
              event: _makeEvent(date: future, status: 'Archived'),
            ),
            const AdminEventCountdownBadge(daysUntil: 0),
            const AdminEventCountdownBadge(daysUntil: 1),
            const AdminEventCountdownBadge(daysUntil: 4),
          ],
        ),
      );

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Finished'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('In 4 days'), findsOneWidget);
    });
  });

  group('AdminEventDateRangeChip', () {
    testWidgets('displays default label, formatted range, and triggers callbacks',
        (tester) async {
      var tapped = 0;
      var cleared = 0;

      await pumpAdmin(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminEventDateRangeChip(
              from: null,
              to: null,
              onTap: () => tapped++,
              onClear: () => cleared++,
            ),
            const SizedBox(height: 8),
            AdminEventDateRangeChip(
              from: DateTime(2026, 6, 1),
              to: DateTime(2026, 6, 7),
              onTap: () => tapped++,
              onClear: () => cleared++,
            ),
          ],
        ),
      );

      expect(find.text('Date range'), findsOneWidget);
      await tester.tap(find.text('Date range'));
      expect(tapped, 1);

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(cleared, 1);
    });
  });

  group('AdminEventListCard & AdminEventsListSkeleton', () {
    testWidgets('renders across desktop, tablet, and narrow mobile widths without overflow',
        (tester) async {
      final event = _makeEvent(
        venueLatitude: 8.4859,
        venueLongitude: 124.6565,
      );

      for (final width in kAdminTestWidths) {
        var opened = false;
        String? selectedAction;

        await pumpAdmin(
          tester,
          AdminEventListCard(
            event: event,
            counts: const EventRsvpCounts(going: 25, notGoing: 3),
            onOpen: () => opened = true,
            onMenuSelected: (v) => selectedAction = v,
            menuItems: [
              adminEventMenuItem(
                value: 'edit',
                label: 'Edit event',
                icon: Icons.edit_outlined,
              ),
              adminEventMenuItem(
                value: 'delete',
                label: 'Delete permanently',
                icon: Icons.delete_outline,
                destructive: true,
              ),
            ],
          ),
          width: width,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Annual Alumni Homecoming'), findsWidgets);
        expect(find.text(EventCategoryConstants.homecoming), findsWidgets);
        expect(find.byIcon(Icons.pin_drop_outlined), findsOneWidget);
        if (width >= AdminEventListCard.zoneLayoutMinWidth) {
          expect(
            find.textContaining('25 / 100 going', findRichText: true),
            findsOneWidget,
          );
        } else {
          expect(find.text('25/100 going'), findsOneWidget);
        }

        await tester.tap(find.text('Annual Alumni Homecoming').last);
        await tester.pump();
        expect(opened, isTrue);

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit event').last);
        await tester.pumpAndSettle();
        expect(selectedAction, 'edit');
      }
    });

    testWidgets('compact card hides wide zone and renders concise counts',
        (tester) async {
      await pumpAdmin(
        tester,
        AdminEventListCard(
          event: _makeEvent(capacity: 50),
          counts: const EventRsvpCounts(going: 12),
          compact: true,
          onOpen: () {},
          onMenuSelected: (_) {},
          menuItems: [
            adminEventMenuItem(
              value: 'edit',
              label: 'Edit',
              icon: Icons.edit_outlined,
            ),
          ],
        ),
        width: 520,
      );

      expect(find.text('12/50 going'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('AdminEventsListSkeleton renders requested count inside ShimmerScope',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminEventsListSkeleton(count: 3),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ShimmerScope), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });
  });
}

