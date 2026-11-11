import 'dart:async';
import 'dart:convert';

import 'package:alumni_system/features/messages/data/message_service.dart';
import 'package:alumni_system/features/messages/presentation/admin_messages_page.dart';
import 'package:alumni_system/features/messages/widgets/admin_message_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _SentMessageCall {
  const _SentMessageCall({
    required this.messageId,
    required this.senderId,
    required this.senderRole,
    required this.recipientId,
    required this.messageText,
  });

  final String messageId;
  final String senderId;
  final String senderRole;
  final String recipientId;
  final String messageText;
}

class _FakeMessageService extends MessageService {
  _FakeMessageService({this.composeDirectory = const []})
      : super(supabase: Supabase.instance.client);

  final StreamController<List<Map<String, dynamic>>> inboxController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final Map<String, StreamController<List<Map<String, dynamic>>>>
      _threadControllers = {};
  final List<RegisteredAlumniContact> composeDirectory;

  int watchInboxCalls = 0;
  final Map<String, int> watchThreadCalls = {};
  final List<String> markedReadUserIds = [];
  final List<_SentMessageCall> sentMessages = [];
  Object? throwOnSend;

  StreamController<List<Map<String, dynamic>>> threadControllerFor(
    String userId,
  ) {
    return _threadControllers.putIfAbsent(
      userId,
      () => StreamController<List<Map<String, dynamic>>>.broadcast(),
    );
  }

  Future<void> dispose() async {
    await inboxController.close();
    for (final ctrl in _threadControllers.values) {
      await ctrl.close();
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchAdminInbox() {
    watchInboxCalls++;
    return inboxController.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchAdminConversation(
    String userMessagingId, {
    String? userDocId,
  }) {
    watchThreadCalls[userMessagingId] =
        (watchThreadCalls[userMessagingId] ?? 0) + 1;
    return threadControllerFor(userMessagingId).stream;
  }

  @override
  Future<void> markUserMessagesAsReadForAdmin(
    String userMessagingId, {
    String? userDocId,
  }) async {
    markedReadUserIds.add(userMessagingId);
  }

  @override
  Future<void> sendMessage({
    required String messageId,
    required String senderId,
    String? senderDocId,
    required String senderName,
    required String senderEmail,
    required String senderRole,
    required String recipientId,
    String? recipientDocId,
    required String messageText,
    String? imageUrl,
    Map<String, dynamic>? reactions,
    DateTime? timestamp,
  }) async {
    if (throwOnSend != null) throw throwOnSend!;
    sentMessages.add(
      _SentMessageCall(
        messageId: messageId,
        senderId: senderId,
        senderRole: senderRole,
        recipientId: recipientId,
        messageText: messageText,
      ),
    );
  }

  @override
  Future<({List<Map<String, dynamic>> messages, bool hasMore})>
      loadOlderAdminConversation(
    String userMessagingId, {
    String? userDocId,
    required DateTime before,
    int limit = 25,
  }) async {
    return (messages: const <Map<String, dynamic>>[], hasMore: false);
  }

  @override
  Future<List<RegisteredAlumniContact>> searchRegisteredAlumniForCompose({
    String query = '',
    int limit = 50,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return composeDirectory;
    return composeDirectory
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.email.toLowerCase().contains(q) ||
              c.program.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Future<RegisteredAlumniContact> resolveAlumniContact(String authUid) async {
    return composeDirectory.firstWhere(
      (c) => c.authUid == authUid,
      orElse: () => RegisteredAlumniContact(authUid: authUid, name: 'Alumni'),
    );
  }

  @override
  Future<void> discardUploadedMessageImage(String? imageUrl) async {}

  @override
  Future<void> updateMessage(String messageId, String newText) async {}

  @override
  Future<void> deleteMessage(String messageId) async {}

  @override
  Future<void> applyReactions({
    required String messageId,
    required Map<String, dynamic> reactions,
  }) async {}
}

Map<String, dynamic> _inboxRow({
  required String id,
  required String name,
  String email = '',
  String program = 'BSCS',
  String batch = '2022',
  String lastMessage = 'Hello',
  bool isRead = false,
  String lastMessageFromRole = 'user',
  bool tracerComplete = true,
  DateTime? lastMessageTime,
}) {
  return {
    'messagingId': id,
    'docId': id,
    'name': name,
    'email': email.isNotEmpty ? email : '$id@alumni.edu',
    'program': program,
    'batch': batch,
    'avatarUrl': null,
    'lastMessage': lastMessage,
    'lastMessageTime':
        lastMessageTime ?? DateTime.now().subtract(const Duration(minutes: 4)),
    'isRead': isRead,
    'lastMessageFromRole': lastMessageFromRole,
    'tracerComplete': tracerComplete,
    'lastActive': DateTime.now().subtract(const Duration(minutes: 4)),
    'registrationLabel': 'Registered',
  };
}

Map<String, dynamic> _threadMessage({
  required String docId,
  required String senderId,
  required String senderRole,
  required String text,
  bool isRead = false,
  DateTime? timestamp,
}) {
  return {
    'docId': docId,
    'senderId': senderId,
    'senderDocId': senderId,
    'senderRole': senderRole,
    'messageText': text,
    'imageUrl': null,
    'timestamp': timestamp ?? DateTime.now().subtract(const Duration(minutes: 2)),
    'isEdited': false,
    'isRead': isRead,
    'reactions': <String, dynamic>{},
  };
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeMessageService service,
  Size size = const Size(1366, 900),
  bool hideAppBar = true,
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
        body: AdminMessagesScreen(
          hideAppBar: hideAppBar,
          service: service,
          currentUserIdOverride: 'admin-1',
          currentUserNameOverride: 'AESS Admin',
          currentUserEmailOverride: 'admin@aess.edu',
        ),
      ),
    ),
  );
  await tester.pump();
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

  testWidgets(
      'desktop (1366x900) filters, selects thread, marks read, and toggles Details panel',
      (tester) async {
    final service = _FakeMessageService();
    addTearDown(service.dispose);

    await _pumpScreen(tester, service: service, size: const Size(1366, 900));

    service.inboxController.add([
      _inboxRow(
        id: 'u-1',
        name: 'Ana Santos',
        program: 'BSCS',
        batch: '2022',
        lastMessage: 'Can I update my employment form?',
        isRead: false,
        lastMessageFromRole: 'user',
        tracerComplete: true,
      ),
      _inboxRow(
        id: 'u-2',
        name: 'Carlo Reyes',
        program: 'BSBA',
        batch: '2021',
        lastMessage: 'Thank you for helping!',
        isRead: true,
        lastMessageFromRole: 'admin',
        tracerComplete: false,
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(AdminCompactHeader), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('1 unread'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AdminCompactHeader),
        matching: find.text('New message'),
      ),
      findsOneWidget,
    );
    expect(find.text('Select a conversation to reply'), findsOneWidget);
    expect(find.text('Ana Santos'), findsOneWidget);
    expect(find.text('Carlo Reyes'), findsOneWidget);

    // Filter to Unread
    await tester.tap(find.text('Unread'));
    await tester.pump();
    expect(find.text('Ana Santos'), findsOneWidget);
    expect(find.text('Carlo Reyes'), findsNothing);
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('Carlo Reyes'), findsOneWidget);

    // Search + clear search
    final searchField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Search name, email, program, batch…',
    );
    await tester.enterText(searchField, 'carlo');
    await tester.pump();
    expect(find.text('Ana Santos'), findsNothing);
    expect(find.text('Carlo Reyes'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text('Ana Santos'), findsOneWidget);

    // Select Ana -> load thread + mark read + show Profile panel
    await tester.tap(find.text('Ana Santos'));
    await tester.pump();
    expect(service.watchThreadCalls['u-1'], 1);

    service.threadControllerFor('u-1').add([
      _threadMessage(
        docId: 'm-1',
        senderId: 'u-1',
        senderRole: 'user',
        text: 'Can I update my employment form?',
        isRead: false,
      ),
    ]);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(service.markedReadUserIds, contains('u-1'));
    expect(find.text('Can I update my employment form?'), findsWidgets);
    expect(find.byType(AdminConversationHeader), findsOneWidget);
    expect(find.byType(AdminAlumniProfilePanel), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);

    // Toggle Details hides/shows profile panel
    await tester.tap(find.text('Details'));
    await tester.pump();
    expect(find.byType(AdminAlumniProfilePanel), findsNothing);

    await tester.tap(find.text('Details'));
    await tester.pump();
    expect(find.byType(AdminAlumniProfilePanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet (900x900) hides profile panel by default and toggles open',
      (tester) async {
    final service = _FakeMessageService();
    addTearDown(service.dispose);

    await _pumpScreen(tester, service: service, size: const Size(900, 900));

    service.inboxController.add([
      _inboxRow(id: 'u-1', name: 'Ana Santos'),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ana Santos'));
    await tester.pump();
    service.threadControllerFor('u-1').add([
      _threadMessage(
        docId: 'm-1',
        senderId: 'u-1',
        senderRole: 'user',
        text: 'Checking profile drawer on tablet',
      ),
    ]);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(AdminAlumniProfilePanel), findsNothing);
    expect(find.text('Details'), findsOneWidget);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminAlumniProfilePanel), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminAlumniProfilePanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mobile (360x800) switches inbox <-> thread and hides header in open chat',
      (tester) async {
    final service = _FakeMessageService();
    addTearDown(service.dispose);

    await _pumpScreen(tester, service: service, size: const Size(360, 800));

    service.inboxController.add([
      _inboxRow(id: 'u-1', name: 'Ana Santos'),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(AdminCompactHeader), findsOneWidget);
    expect(find.text('Select a conversation to reply'), findsNothing);

    await tester.tap(find.text('Ana Santos'));
    await tester.pump();
    service.threadControllerFor('u-1').add([
      _threadMessage(
        docId: 'm-1',
        senderId: 'u-1',
        senderRole: 'user',
        text: 'Mobile thread message',
      ),
    ]);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Outer compact header hides once a thread fills mobile view.
    expect(find.byType(AdminCompactHeader), findsNothing);
    expect(find.byTooltip('Back to inbox'), findsOneWidget);
    expect(find.byTooltip('Alumni details'), findsOneWidget);
    expect(find.text('Mobile thread message'), findsOneWidget);

    await tester.tap(find.byTooltip('Alumni details'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminAlumniProfilePanel), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminAlumniProfilePanel), findsNothing);

    await tester.tap(find.byTooltip('Back to inbox'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminCompactHeader), findsOneWidget);
    expect(find.text('Ana Santos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'New message creates draft stub, handles Postgrest send error, and sends reply',
      (tester) async {
    final service = _FakeMessageService(
      composeDirectory: [
        RegisteredAlumniContact(
          authUid: 'alu-42',
          name: 'Bea Alonzo',
          email: 'bea@alumni.edu',
          program: 'BSBA',
          batch: '2023',
          tracerComplete: false,
        ),
      ],
    );
    addTearDown(service.dispose);

    await _pumpScreen(tester, service: service, size: const Size(1366, 900));

    service.inboxController.add(const []);
    await tester.pumpAndSettle();
    expect(find.text('No conversations yet'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AdminCompactHeader),
        matching: find.text('New message'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bea Alonzo'), findsOneWidget);
    await tester.tap(find.text('Bea Alonzo'));
    await tester.pump();

    service.threadControllerFor('alu-42').add(const []);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Draft'), findsOneWidget);
    // Shown once as draft tile preview and once in the empty thread panel.
    expect(find.text('No messages yet'), findsNWidgets(2));
    expect(
      find.text('Send a reply below to start the conversation.'),
      findsOneWidget,
    );

    final replyField = find.byWidgetPredicate(
      (w) =>
          w is TextField && w.decoration?.hintText == 'Reply to alumni…',
    );

    // Send failure surfaces sanitized friendly SnackBar
    service.throwOnSend = Exception('PostgrestException: RLS violation');
    await tester.enterText(replyField, 'Welcome aboard!');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not send message. Please try again.'),
      findsOneWidget,
    );
    expect(service.sentMessages, isEmpty);

    ScaffoldMessenger.of(
      tester.element(find.byType(AdminMessagesScreen)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    // Successful send dispatches expected payload
    service.throwOnSend = null;
    await tester.enterText(replyField, 'Welcome aboard!');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(service.sentMessages.length, 1);
    final sent = service.sentMessages.single;
    expect(sent.senderId, 'admin-1');
    expect(sent.senderRole, 'admin');
    expect(sent.recipientId, 'alu-42');
    expect(sent.messageText, 'Welcome aboard!');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'recovers from inbox stream error, cached sync warning, and thread stream error',
      (tester) async {
    final service = _FakeMessageService();
    addTearDown(service.dispose);

    await _pumpScreen(tester, service: service, size: const Size(1366, 900));

    // 1) Initial inbox load error -> Retry recovers
    service.inboxController
        .addError(Exception('PostgrestException: stream offline'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load conversations"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(service.watchInboxCalls, 2);

    service.inboxController.add([
      _inboxRow(id: 'u-1', name: 'Ana Santos'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Ana Santos'), findsOneWidget);

    // 2) Error after inbox cache exists -> warning banner keeps list visible
    service.inboxController.addError(Exception('Realtime socket drop'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Santos'), findsOneWidget);
    expect(find.text('Inbox sync paused.'), findsOneWidget);

    // Clear banner by retrying inbox
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pump();
    expect(service.watchInboxCalls, 3);
    service.inboxController.add([
      _inboxRow(id: 'u-1', name: 'Ana Santos'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Inbox sync paused.'), findsNothing);

    // 3) Thread stream error -> Retry recovers
    await tester.tap(find.text('Ana Santos'));
    await tester.pump();
    service.threadControllerFor('u-1').addError(Exception('SocketException'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load conversation"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(service.watchThreadCalls['u-1'], 2);

    service.threadControllerFor('u-1').add([
      _threadMessage(
        docId: 'm-9',
        senderId: 'u-1',
        senderRole: 'user',
        text: 'Recovered thread message',
      ),
    ]);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Recovered thread message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

