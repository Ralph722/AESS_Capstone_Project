import 'dart:async';
import 'dart:convert';

import 'package:alumni_system/features/messages/data/message_service.dart';
import 'package:alumni_system/features/messages/models/message_filters.dart';
import 'package:alumni_system/features/messages/widgets/admin_compose_picker.dart';
import 'package:alumni_system/features/messages/widgets/admin_message_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_shared/admin_test_harness.dart';

class _FakeComposeMessageService extends MessageService {
  _FakeComposeMessageService({required this.handler})
      : super(supabase: Supabase.instance.client);

  Future<List<RegisteredAlumniContact>> Function(String query, int limit)
      handler;
  final List<String> queries = [];

  @override
  Future<List<RegisteredAlumniContact>> searchRegisteredAlumniForCompose({
    String query = '',
    int limit = 50,
  }) {
    queries.add(query);
    return handler(query, limit);
  }
}

Map<String, dynamic> _conversationRow({
  String id = 'u-1',
  String name = 'Ana Santos',
  String program = 'BSCS',
  String batch = '2022',
  String lastMessage = 'Hello admin, quick question about my TOR.',
  bool isRead = false,
  String lastMessageFromRole = 'user',
  bool composeDraft = false,
  DateTime? lastMessageTime,
}) {
  return {
    'messagingId': id,
    'docId': id,
    'name': name,
    'email': '$id@alumni.edu',
    'program': program,
    'batch': batch,
    'lastMessage': lastMessage,
    'isRead': isRead,
    'lastMessageFromRole': lastMessageFromRole,
    'composeDraft': composeDraft,
    'lastMessageTime':
        lastMessageTime ?? DateTime.now().subtract(const Duration(minutes: 5)),
  };
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

  group('messageFriendlyError', () {
    test('surfaces concise error copy and hides technical exceptions', () {
      expect(
        messageFriendlyError(
          Exception('Network timeout'),
          'Could not send message. Please try again.',
        ),
        'Network timeout',
      );
      expect(
        messageFriendlyError(
          'Exception: Exception: Attachment upload failed.',
          'Fallback',
        ),
        'Attachment upload failed.',
      );
      expect(
        messageFriendlyError(
          Exception('PostgrestException: relation "messages" error'),
          'Fallback',
        ),
        'Fallback',
      );
      expect(
        messageFriendlyError(
          Exception('Error sending message: permission denied'),
          'Fallback',
        ),
        'Fallback',
      );
      expect(
        messageFriendlyError(
          Exception('SocketException: Connection refused'),
          'Fallback',
        ),
        'Fallback',
      );
      expect(messageFriendlyError('   ', 'Fallback'), 'Fallback');
      expect(messageFriendlyError('a' * 161, 'Fallback'), 'Fallback');
    });
  });

  group('AdminInboxToolbar', () {
    testWidgets('renders filter chips, sort field, search clear, and reset',
        (tester) async {
      final searchCtrl = TextEditingController();
      addTearDown(searchCtrl.dispose);

      var filter = MessageInboxFilter.all;
      var sort = MessageInboxSort.newestActivity;
      var latestSearch = '';
      var resetCount = 0;

      await pumpAdmin(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return AdminInboxToolbar(
              searchController: searchCtrl,
              query: MessageInboxQuery(
                search: latestSearch,
                filter: filter,
                sort: sort,
              ),
              onSearchChanged: (v) => setState(() => latestSearch = v),
              onFilterChanged: (f) => setState(() => filter = f),
              onSortChanged: (s) => setState(() => sort = s),
              onReset: () => setState(() {
                resetCount++;
                searchCtrl.clear();
                latestSearch = '';
                filter = MessageInboxFilter.all;
                sort = MessageInboxSort.newestActivity;
              }),
            );
          },
        ),
        width: 360,
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Needs reply'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Archived'), findsNothing);
      expect(find.text('Reset'), findsNothing);
      expect(find.byTooltip('Clear search'), findsNothing);

      await tester.tap(find.text('Unread'));
      await tester.pump();
      expect(filter, MessageInboxFilter.unread);
      expect(find.text('Reset'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ana');
      await tester.pump();
      expect(latestSearch, 'ana');
      expect(find.byTooltip('Clear search'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(searchCtrl.text, isEmpty);
      expect(latestSearch, isEmpty);

      await tester.tap(find.byType(DirectoryFilterField<MessageInboxSort>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Waiting longest').last);
      await tester.pumpAndSettle();
      expect(sort, MessageInboxSort.waitingLongest);

      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(resetCount, 1);
      expect(filter, MessageInboxFilter.all);
      expect(sort, MessageInboxSort.newestActivity);
      expect(find.text('Reset'), findsNothing);
    });

    for (final width in kAdminTestWidths) {
      testWidgets('renders without overflow at $width px', (tester) async {
        final searchCtrl = TextEditingController(text: 'bsit');
        addTearDown(searchCtrl.dispose);

        await pumpAdmin(
          tester,
          AdminInboxToolbar(
            searchController: searchCtrl,
            query: const MessageInboxQuery(
              search: 'bsit',
              filter: MessageInboxFilter.needsReply,
            ),
            onSearchChanged: (_) {},
            onFilterChanged: (_) {},
            onSortChanged: (_) {},
            onReset: () {},
          ),
          width: width,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Reset'), findsOneWidget);
      });
    }
  });

  group('AdminConversationListTile', () {
    testWidgets('shows Draft, Needs reply, or Unread badge according to state',
        (tester) async {
      var tapped = false;

      await pumpAdmin(
        tester,
        Column(
          children: [
            AdminConversationListTile(
              row: _conversationRow(
                id: 'draft-1',
                name: 'Draft Alumni',
                lastMessage: '',
                isRead: true,
                lastMessageFromRole: '',
                composeDraft: true,
              ),
              selected: false,
              onTap: () => tapped = true,
            ),
            AdminConversationListTile(
              row: _conversationRow(
                id: 'need-1',
                name: 'Maria Clara',
                isRead: false,
                lastMessageFromRole: 'user',
              ),
              selected: true,
              onTap: () {},
            ),
            AdminConversationListTile(
              row: _conversationRow(
                id: 'unread-1',
                name: 'Juan Dela Cruz',
                isRead: false,
                lastMessageFromRole: 'admin',
              ),
              selected: false,
              onTap: () {},
            ),
          ],
        ),
        width: 360,
      );

      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.text('Needs reply'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('BSCS · 2022'), findsNWidgets(3));
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Unread',
        ),
        findsNWidgets(2),
      );

      await tester.tap(find.text('Draft Alumni'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('AdminConversationHeader', () {
    final profile = AlumniMessageProfile.fromConversationRow(
      _conversationRow(name: 'Elena Reyes', program: 'BSIT', batch: '2021'),
    );

    testWidgets('wide width shows Needs reply badge and Details button toggle',
        (tester) async {
      var backCalls = 0;
      var toggleCalls = 0;

      await pumpAdmin(
        tester,
        AdminConversationHeader(
          profile: profile,
          onBack: () => backCalls++,
          onToggleProfile: () => toggleCalls++,
          showProfileToggle: true,
          showProfilePanel: false,
          needsReply: true,
        ),
        width: 640,
      );

      expect(find.text('Elena Reyes'), findsOneWidget);
      expect(find.text('BSIT · 2021'), findsOneWidget);
      expect(find.text('Needs reply'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.byTooltip('Alumni details'), findsNothing);

      await tester.tap(find.byTooltip('Back to inbox'));
      await tester.tap(find.text('Details'));
      await tester.pump();
      expect(backCalls, 1);
      expect(toggleCalls, 1);
    });

    testWidgets('compact width uses Alumni details icon toggle',
        (tester) async {
      var toggleCalls = 0;

      await pumpAdmin(
        tester,
        AdminConversationHeader(
          profile: profile,
          onBack: () {},
          onToggleProfile: () => toggleCalls++,
          showProfileToggle: true,
          showProfilePanel: true,
          needsReply: true,
        ),
        width: 360,
      );

      expect(find.text('Needs reply'), findsNothing);
      expect(find.text('Details'), findsNothing);
      expect(find.byTooltip('Alumni details'), findsOneWidget);

      await tester.tap(find.byTooltip('Alumni details'));
      await tester.pump();
      expect(toggleCalls, 1);
    });
  });

  group('AdminAlumniProfilePanel', () {
    testWidgets('shows Tracer Complete/Incomplete badges and copies email',
        (tester) async {
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final completeProfile = AlumniMessageProfile(
        userId: 'u-1',
        name: 'Carlos Mendoza',
        email: 'carlos@alumni.edu',
        program: 'BSED',
        batch: '2020',
        registrationLabel: 'Registered',
        tracerComplete: true,
        lastActive: DateTime.now().subtract(const Duration(hours: 2)),
      );
      const incompleteProfile = AlumniMessageProfile(
        userId: 'u-2',
        name: 'Liza Sober',
        email: '',
        tracerComplete: false,
      );

      await pumpAdmin(
        tester,
        SizedBox(
          height: 520,
          child: AdminAlumniProfilePanel(profile: completeProfile),
        ),
        width: 400,
      );

      expect(find.text('Alumni details'), findsOneWidget);
      expect(find.text('Carlos Mendoza'), findsOneWidget);
      expect(find.text('carlos@alumni.edu'), findsOneWidget);
      expect(find.text('BSED'), findsOneWidget);
      expect(find.text('2020'), findsOneWidget);
      expect(find.text('Registered'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);
      expect(find.widgetWithText(AdminBadge, 'Complete'), findsOneWidget);

      await tester.tap(find.byTooltip('Copy email'));
      await tester.pump();
      expect(copiedText, 'carlos@alumni.edu');
      expect(find.text('Email copied'), findsOneWidget);

      await pumpAdmin(
        tester,
        const SizedBox(
          height: 520,
          child: AdminAlumniProfilePanel(profile: incompleteProfile),
        ),
        width: 400,
      );

      expect(find.text('Incomplete'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(3));
      expect(find.byTooltip('Copy email'), findsNothing);
    });
  });

  group('showAdminComposeAlumniPicker', () {
    testWidgets('handles loading, error retry, empty search, and selection',
        (tester) async {
      final initialCompleter = Completer<List<RegisteredAlumniContact>>();
      var failNext = false;
      final contact = RegisteredAlumniContact(
        authUid: 'alu-42',
        name: 'Bea Alonzo',
        email: 'bea@alumni.edu',
        program: 'BSBA',
        batch: '2023',
        tracerComplete: true,
      );

      final fakeService = _FakeComposeMessageService(
        handler: (query, _) async {
          if (failNext) throw Exception('Database error');
          if (query.isEmpty && !initialCompleter.isCompleted) {
            return initialCompleter.future;
          }
          if (query.trim().toLowerCase() == 'zoe') return const [];
          return [contact];
        },
      );

      RegisteredAlumniContact? picked;

      await pumpAdmin(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              picked = await showAdminComposeAlumniPicker(
                context: context,
                messageService: fakeService,
              );
            },
            child: const Text('Open picker'),
          ),
        ),
        width: 800,
      );

      await tester.tap(find.text('Open picker'));
      await tester.pump();
      expect(find.text('New message'), findsOneWidget);
      expect(find.text('Loading alumni…'), findsOneWidget);
      expect(find.text('Searching…'), findsOneWidget);

      initialCompleter.complete([contact]);
      await tester.pumpAndSettle();

      expect(find.text('Bea Alonzo'), findsOneWidget);
      expect(find.text('bea@alumni.edu'), findsOneWidget);
      expect(find.text('BSBA · 2023'), findsOneWidget);
      expect(find.text('1 alumnus'), findsOneWidget);

      // Debounced search producing no matches + Clear button
      await tester.enterText(find.byType(TextField), 'zoe');
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pumpAndSettle();

      expect(find.text('No matching alumni'), findsOneWidget);
      expect(find.text('No alumni match “zoe”.'), findsOneWidget);
      expect(find.text('No matches'), findsOneWidget);

      // Retry error flow while clearing
      failNext = true;
      await tester.tap(find.byTooltip('Clear'));
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load alumni"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      failNext = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Bea Alonzo'), findsOneWidget);

      // Select contact and verify dialog returns it
      await tester.tap(find.text('Bea Alonzo'));
      await tester.pumpAndSettle();
      expect(picked?.authUid, 'alu-42');
      expect(find.text('New message'), findsNothing);
    });

    testWidgets('returns null on Cancel and handles empty directory',
        (tester) async {
      final fakeService = _FakeComposeMessageService(
        handler: (_, __) async => const [],
      );
      RegisteredAlumniContact? picked = RegisteredAlumniContact(
        authUid: 'sentinel',
        name: 'Sentinel',
      );

      await pumpAdmin(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              picked = await showAdminComposeAlumniPicker(
                context: context,
                messageService: fakeService,
              );
            },
            child: const Text('Open picker'),
          ),
        ),
        width: 800,
      );

      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();

      expect(find.text('No registered alumni yet'), findsNWidgets(2));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(picked, isNull);
    });
  });
}

