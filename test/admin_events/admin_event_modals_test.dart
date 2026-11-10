import 'dart:async';
import 'dart:convert';

import 'package:alumni_system/core/constants/event_category_constants.dart';
import 'package:alumni_system/features/admin/events/presentation/admin_event_comments_dialog.dart';
import 'package:alumni_system/features/admin/events/presentation/admin_event_detail_panel.dart';
import 'package:alumni_system/features/admin/events/presentation/admin_event_editor_dialog.dart';
import 'package:alumni_system/features/events/data/event_comment_service.dart';
import 'package:alumni_system/features/events/data/event_rsvp_service.dart';
import 'package:alumni_system/features/events/data/event_service.dart';
import 'package:alumni_system/features/events/models/event_agenda_item.dart';
import 'package:alumni_system/features/events/models/event_comment_model.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/models/event_rsvp_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_tab_bar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

AlumniEvent _sampleEvent({
  String id = 'evt-1',
  String theme = 'Engineering Alumni Summit',
  String batchYear = '2021',
  DateTime? date,
  int? capacity = 100,
  List<EventAgendaItem> agenda = const [],
}) {
  return AlumniEvent(
    id: id,
    theme: theme,
    batchYear: batchYear,
    date: date ?? DateTime(2026, 8, 15),
    venue: 'USTP Auditorium',
    status: 'Active',
    comments: 2,
    startTime: '09:00',
    endTime: '16:00',
    description: 'Annual department alumni gathering.',
    category: EventCategoryConstants.conference,
    capacity: capacity,
    viewsCount: 88,
    agenda: agenda,
  );
}

class _FakeEventCommentService extends EventCommentService {
  _FakeEventCommentService({required this.comments})
      : super(supabase: Supabase.instance.client);

  final List<EventComment> comments;
  final Map<String, List<EventComment>> repliesByComment = {};
  final List<String> deletedIds = [];
  final List<String> sentReplies = [];
  late final StreamController<List<EventComment>> _commentsController =
      StreamController<List<EventComment>>.broadcast();

  @override
  Stream<List<EventComment>> getCommentsStream(String eventId) async* {
    yield List.of(comments);
    yield* _commentsController.stream;
  }

  @override
  Stream<List<EventComment>> getRepliesStream(
    String eventId,
    String commentId,
  ) =>
      Stream.value(repliesByComment[commentId] ?? const []);

  @override
  Future<EventComment> createReply({
    required String eventId,
    required String commentId,
    required String reply,
    required EventComment originalComment,
  }) async {
    sentReplies.add(reply.trim());
    return EventComment(
      id: 'rep-1',
      eventId: eventId,
      userId: 'admin-1',
      userDocId: 'admin-1',
      userName: 'Admin',
      userEmail: 'admin@ustp.edu.ph',
      comment: reply.trim(),
      createdAt: DateTime(2026, 8, 10, 10),
      parentCommentId: commentId,
    );
  }

  @override
  Future<void> deleteComment({
    required String eventId,
    required String commentId,
  }) async {
    deletedIds.add(commentId);
    comments.removeWhere((c) => c.id == commentId);
    _commentsController.add(List.of(comments));
  }

  void dispose() {
    _commentsController.close();
  }
}

class _FakeEventRsvpService extends EventRsvpService {
  _FakeEventRsvpService({
    this.counts = const EventRsvpCounts(going: 30, notGoing: 10),
    this.rsvps = const [],
  }) : super(supabase: Supabase.instance.client);

  final EventRsvpCounts counts;
  final List<EventRsvp> rsvps;

  @override
  Stream<void> watchEventChanges(String eventId) => const Stream<void>.empty();

  @override
  Future<EventRsvpCounts> getCounts(String eventId) async => counts;

  @override
  Future<List<EventRsvp>> listForEvent(
    String eventId, {
    EventRsvpStatus? status,
  }) async =>
      status == null
          ? rsvps
          : rsvps.where((r) => r.status == status).toList();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: MockClient((request) async {
        const json = {'content-type': 'application/json'};
        return http.Response(jsonEncode(<dynamic>[]), 200, headers: json);
      }),
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  group('AdminEventCommentsDialog', () {
    EventComment makeComment() => EventComment(
          id: 'c1',
          eventId: 'evt-1',
          userId: 'u1',
          userDocId: 'u1',
          userName: 'Maria Santos',
          userEmail: 'maria@example.com',
          comment: 'Will parking be open?',
          createdAt: DateTime(2026, 8, 10, 9),
        );

    testWidgets('standalone shows AdminModalHeader, count badge, reply & delete confirm',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final fakeService = _FakeEventCommentService(comments: [makeComment()]);
      addTearDown(fakeService.dispose);
      int? lastCount;
      var deletedCallbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 640,
                height: 600,
                child: AdminEventCommentsDialog(
                  event: _sampleEvent(),
                  commentService: fakeService,
                  asDialog: true,
                  embedded: false,
                  onCountChanged: (n) => lastCount = n,
                  onCommentDeleted: () => deletedCallbackCount++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AdminModalHeader), findsOneWidget);
      expect(find.text('Event Comments'), findsOneWidget);
      expect(find.text('1 comment'), findsOneWidget);
      expect(lastCount, 1);
      expect(find.text('Will parking be open?'), findsOneWidget);

      await tester.tap(find.text('Reply'));
      await tester.pump();
      expect(find.text('Write an admin reply…'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).last,
        'Yes, Gate 2 parking is open.',
      );
      await tester.tap(find.byTooltip('Send reply'));
      await tester.pump();
      expect(fakeService.sentReplies, ['Yes, Gate 2 parking is open.']);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete comment').last);
      await tester.pumpAndSettle();

      expect(find.text('Delete comment?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(fakeService.deletedIds, ['c1']);
      expect(deletedCallbackCount, 1);
      expect(lastCount, 0);
      expect(find.text('No comments yet'), findsOneWidget);
    });

    testWidgets('embedded mode omits AdminModalHeader for Detail tab mounting',
        (tester) async {
      final fakeService = _FakeEventCommentService(comments: []);
      addTearDown(fakeService.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminEventCommentsDialog(
              event: _sampleEvent(),
              commentService: fakeService,
              asDialog: true,
              embedded: true,
              onCommentDeleted: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AdminModalHeader), findsNothing);
      expect(find.text('Event Comments'), findsNothing);
      expect(find.text('No comments yet'), findsOneWidget);
    });
  });

  group('AdminEventEditorDialog', () {
    testWidgets('validates required fields, shows inline banner, and updates live preview',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
                child: AdminEventEditorDialog(
                  initialDate: DateTime(2026, 9, 20),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('New event'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
      expect(find.text('Untitled event'), findsOneWidget);
      expect(find.textContaining('09/20/2026'), findsWidgets);

      await tester.tap(find.text('Publish'));
      await tester.pump();

      expect(find.text('Please fill all required fields'), findsOneWidget);
      expect(
        find.textContaining('Required before saving: Theme, Batch year'),
        findsOneWidget,
      );

      final themeField = find.widgetWithText(TextField, 'Enter event title');
      await tester.enterText(themeField, 'Tech Founders Meetup');
      await tester.pump();

      expect(find.text('Tech Founders Meetup'), findsWidgets);
      expect(find.text('Untitled event'), findsNothing);
      expect(
        find.textContaining('Required before saving: Batch year'),
        findsOneWidget,
      );
    });

    testWidgets('edit mode populates event values and agenda items',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
                child: AdminEventEditorDialog(
                  event: _sampleEvent(
                    agenda: [
                      const EventAgendaItem(time: '09:00', title: 'Opening Keynote'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit event'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Engineering Alumni Summit'), findsWidgets);
      expect(find.text('Opening Keynote'), findsOneWidget);

      final addAgenda = find.text('Add agenda item');
      await tester.ensureVisible(addAgenda);
      await tester.pumpAndSettle();
      await tester.tap(addAgenda);
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Item'), findsNWidgets(2));
    });
  });

  group('AdminEventDetailPanel', () {
    testWidgets('renders shared tabs, overview actions, and analytics chart without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final fakeComments = _FakeEventCommentService(comments: []);
      addTearDown(fakeComments.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 580,
              height: 820,
              child: AdminEventDetailPanel(
                event: _sampleEvent(
                  agenda: [
                    const EventAgendaItem(time: '09:30', title: 'Panel Talk'),
                  ],
                ),
                initialCounts: const EventRsvpCounts(going: 30, notGoing: 10),
                rsvpService: _FakeEventRsvpService(
                  counts: const EventRsvpCounts(going: 30, notGoing: 10),
                  rsvps: [
                    EventRsvp(
                      id: 'r1',
                      eventId: 'evt-1',
                      userId: 'u1',
                      status: EventRsvpStatus.going,
                      createdAt: DateTime(2026, 8, 1),
                      userName: 'Carlos Reyes',
                      userEmail: 'carlos@example.com',
                    ),
                  ],
                ),
                eventService: EventService(supabase: Supabase.instance.client),
                commentService: fakeComments,
                onChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AdminTabBar), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.byTooltip('Edit event'), findsOneWidget);
      expect(find.byTooltip('Share link…'), findsOneWidget);

      final analyticsTab = find.text('Analytics');
      await tester.ensureVisible(analyticsTab);
      await tester.pumpAndSettle();
      await tester.tap(analyticsTab);
      await tester.pumpAndSettle();

      expect(find.text('Views'), findsOneWidget);
      expect(find.text('Going rate'), findsOneWidget);
      expect(find.text('Capacity used'), findsOneWidget);
      expect(find.text('Capacity utilization'), findsOneWidget);
      expect(find.text('30 of 100 seats filled'), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);

      final agendaTab = find.text('Agenda');
      await tester.ensureVisible(agendaTab);
      await tester.pumpAndSettle();
      await tester.tap(agendaTab);
      await tester.pumpAndSettle();
      expect(find.text('Panel Talk'), findsOneWidget);

      final attendanceTab = find.text('Attendance');
      await tester.ensureVisible(attendanceTab);
      await tester.pumpAndSettle();
      await tester.tap(attendanceTab);
      await tester.pumpAndSettle();
      expect(find.text('Carlos Reyes'), findsOneWidget);
    });
  });
}
