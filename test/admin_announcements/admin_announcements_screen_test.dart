import 'dart:convert';

import 'package:alumni_system/features/admin/announcements/presentation/admin_announcement_editor_page.dart';
import 'package:alumni_system/features/admin/announcements/presentation/admin_announcements_page.dart';
import 'package:alumni_system/features/admin/announcements/widgets/admin_announcement_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/announcements/data/announcement_service.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_metric_ribbon.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_toolbar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAnnouncementService extends AnnouncementService {
  _FakeAnnouncementService({
    required this.items,
    this.audienceCount = 18,
  }) : super(supabase: Supabase.instance.client);

  final List<Announcement> items;
  int audienceCount;
  bool throwOnGetAll = false;
  bool throwOnGetOne = false;
  int countAudienceCalls = 0;
  final List<String> createdTitles = [];
  final List<String> archivedIds = [];
  final List<String> restoredIds = [];
  final List<String> deletedIds = [];
  final List<Announcement> updatedItems = [];
  final List<String> publishedIds = [];

  @override
  Future<List<Announcement>> getAllAnnouncements() async {
    if (throwOnGetAll) {
      throw Exception('Network unavailable');
    }
    return List.of(items);
  }

  @override
  Future<Announcement?> getAnnouncement(String id) async {
    if (throwOnGetOne) {
      throw Exception('PostgrestException: failed fetch');
    }
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<String> createAnnouncement({
    required String title,
    required String body,
    AnnouncementPriority priority = AnnouncementPriority.normal,
  }) async {
    createdTitles.add(title);
    final created = Announcement(
      id: 'new-${createdTitles.length}',
      title: title,
      body: body,
      status: AnnouncementStatus.draft,
      priority: priority,
      createdBy: 'admin-1',
      createdAt: DateTime(2026, 11, 10),
    );
    items.insert(0, created);
    return created.id;
  }

  @override
  Future<void> updateAnnouncement(
    Announcement announcement, {
    bool audit = true,
  }) async {
    final idx = items.indexWhere((a) => a.id == announcement.id);
    if (idx != -1) items[idx] = announcement;
    updatedItems.add(announcement);
  }

  @override
  Future<int> countAudience({
    required List<String> targetPrograms,
    required List<String> targetBatchYears,
  }) async {
    countAudienceCalls++;
    return audienceCount;
  }

  @override
  Future<int> publishAnnouncement(String id) async {
    publishedIds.add(id);
    final idx = items.indexWhere((a) => a.id == id);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(
        status: AnnouncementStatus.published,
        publishedAt: DateTime(2026, 11, 11),
        recipientCount: audienceCount,
      );
    }
    return audienceCount;
  }

  @override
  Future<void> archiveAnnouncement(String id) async {
    archivedIds.add(id);
    final idx = items.indexWhere((a) => a.id == id);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(status: AnnouncementStatus.archived);
    }
  }

  @override
  Future<void> restoreAnnouncement(String id) async {
    restoredIds.add(id);
    final idx = items.indexWhere((a) => a.id == id);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(status: AnnouncementStatus.published);
    }
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    deletedIds.add(id);
    items.removeWhere((a) => a.id == id);
  }
}

List<Announcement> _seedAnnouncements() => [
  Announcement(
    id: 'a-pub',
    title: 'Career Fair 2026',
    body: 'Join top employers at the gymnasium.',
    status: AnnouncementStatus.published,
    priority: AnnouncementPriority.important,
    targetPrograms: const ['BSIT'],
    targetBatchYears: const ['2024'],
    createdBy: 'admin-1',
    createdAt: DateTime(2026, 11, 5),
    publishedAt: DateTime(2026, 11, 6),
    recipientCount: 120,
  ),
  Announcement(
    id: 'a-draft',
    title: 'Survey Draft Notice',
    body: 'Draft message content.',
    status: AnnouncementStatus.draft,
    priority: AnnouncementPriority.normal,
    createdBy: 'admin-1',
    createdAt: DateTime(2026, 11, 8),
  ),
  Announcement(
    id: 'a-arch',
    title: 'Past Homecoming Recap',
    body: 'Thank you for attending.',
    status: AnnouncementStatus.archived,
    priority: AnnouncementPriority.normal,
    createdBy: 'admin-1',
    createdAt: DateTime(2026, 10, 1),
    recipientCount: 80,
  ),
];

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

  group('AdminAnnouncementsScreen', () {
    testWidgets(
        'renders SaaS header, metric ribbon, toolbar filtering, and delete confirmation',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final service = _FakeAnnouncementService(items: _seedAnnouncements());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAnnouncementsScreen(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminCompactHeader), findsOneWidget);
      expect(find.byType(AdminMetricRibbon), findsOneWidget);
      expect(find.byType(AdminSaaSToolbar), findsOneWidget);
      final headerWidget = tester.widget<AdminCompactHeader>(
        find.byType(AdminCompactHeader),
      );
      expect(headerWidget.title, 'Announcements');
      expect(headerWidget.countBadge, isNull);
      expect(headerWidget.subtitle, isNull);
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
          matching: find.textContaining('active'),
        ),
        findsNothing,
      );

      final headerRefreshFinder = find.descendant(
        of: find.byType(AdminCompactHeader),
        matching: find.text('Refresh'),
      );
      final newAnnouncementFinder = find.descendant(
        of: find.byType(AdminCompactHeader),
        matching: find.text('New announcement'),
      );
      expect(headerRefreshFinder, findsOneWidget);
      expect(newAnnouncementFinder, findsOneWidget);
      expect(
        tester.getTopLeft(headerRefreshFinder).dx,
        lessThan(tester.getTopLeft(newAnnouncementFinder).dx),
      );

      final toolbar = tester.widget<AdminSaaSToolbar>(
        find.byType(AdminSaaSToolbar),
      );
      expect(toolbar.onRefresh, isNull);
      expect(
        find.descendant(
          of: find.byType(AdminSaaSToolbar),
          matching: find.byTooltip('Refresh announcements'),
        ),
        findsNothing,
      );
      expect(toolbar.filters, hasLength(5));
      for (var i = 0; i < 4; i++) {
        expect(toolbar.filters[i], isA<DirectoryToolbarFilterChip>());
      }
      expect(
        toolbar.filters[4],
        isA<DirectoryFilterField<AnnouncementPriority?>>(),
      );
      final lastChipDx = tester
          .getTopLeft(find.byType(DirectoryToolbarFilterChip).last)
          .dx;
      final priorityDropdownDx = tester
          .getTopLeft(find.byType(DirectoryFilterField<AnnouncementPriority?>))
          .dx;
      expect(lastChipDx, lessThan(priorityDropdownDx));
      expect(find.text('120'), findsOneWidget);

      // Active view hides archived by default.
      expect(find.text('Career Fair 2026'), findsOneWidget);
      expect(find.text('Survey Draft Notice'), findsOneWidget);
      expect(find.text('Past Homecoming Recap'), findsNothing);

      // Filter via Draft toolbar chip.
      await tester.tap(
        find.descendant(
          of: find.byType(AdminSaaSToolbar),
          matching: find.text('Draft'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Survey Draft Notice'), findsOneWidget);
      expect(find.text('Career Fair 2026'), findsNothing);

      // Clear status filter via Active chip.
      await tester.tap(
        find.descendant(
          of: find.byType(AdminSaaSToolbar),
          matching: find.text('Active'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Career Fair 2026'), findsOneWidget);

      // Filter by Priority = Important.
      await tester.tap(find.text('All priorities'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Important').last);
      await tester.pumpAndSettle();
      expect(find.text('Career Fair 2026'), findsOneWidget);
      expect(find.text('Survey Draft Notice'), findsNothing);

      // Reset priority filter via AdminSaaSToolbar Reset button.
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Survey Draft Notice'), findsOneWidget);
      expect(find.text('Career Fair 2026'), findsOneWidget);
    });

    testWidgets('archive & delete confirmation flows mutate expected items',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final service = _FakeAnnouncementService(items: _seedAnnouncements());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAnnouncementsScreen(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Newest first puts Survey Draft Notice (Nov 8) at index 0, Career Fair (Nov 5) at index 1.
      final cards = find.byType(AnnouncementListCard);
      await tester.tap(
        find.descendant(
          of: cards.at(1),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive').last);
      await tester.pumpAndSettle();
      expect(service.archivedIds, ['a-pub']);

      // Delete remaining draft with confirmation dialog.
      await tester.tap(
        find.descendant(
          of: find.byType(AnnouncementListCard).first,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Delete announcement?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(service.deletedIds, ['a-draft']);
    });

    testWidgets('archived filter can restore a retired announcement', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final service = _FakeAnnouncementService(items: _seedAnnouncements());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAnnouncementsScreen(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AdminSaaSToolbar),
          matching: find.textContaining('Archived'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Past Homecoming Recap'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AnnouncementListCard).first,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore').last);
      await tester.pumpAndSettle();

      expect(service.restoredIds, ['a-arch']);
      expect(
        service.items.firstWhere((a) => a.id == 'a-arch').status,
        AnnouncementStatus.published,
      );
    });

    testWidgets('shows error state on initial failure and refresh warning banner on reload failure',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final service = _FakeAnnouncementService(items: _seedAnnouncements())
        ..throwOnGetAll = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAnnouncementsScreen(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminStateView), findsOneWidget);
      expect(find.text("Couldn't load announcements"), findsOneWidget);

      // Recover via retry.
      service.throwOnGetAll = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Career Fair 2026'), findsOneWidget);

      // Fail on refresh keeps list visible with warning banner.
      service.throwOnGetAll = true;
      await tester.tap(
        find.descendant(
          of: find.byType(AdminCompactHeader),
          matching: find.text('Refresh'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Couldn't refresh announcements. Showing the last loaded list.",
        ),
        findsOneWidget,
      );
      expect(find.text('Career Fair 2026'), findsOneWidget);
    });

    testWidgets('New announcement dialog validates empty title before creating',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final service = _FakeAnnouncementService(items: []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAnnouncementsScreen(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New announcement').first);
      await tester.pumpAndSettle();
      expect(find.text('Create draft'), findsOneWidget);

      await tester.tap(find.text('Create draft'));
      await tester.pump();
      expect(find.text('Enter a title before creating a draft.'), findsOneWidget);
      expect(service.createdTitles, isEmpty);

      await tester.enterText(find.byType(TextField).last, 'New Campus Update');
      await tester.tap(find.text('Create draft'));
      await tester.pumpAndSettle();
      expect(service.createdTitles, ['New Campus Update']);
      expect(find.byType(AdminAnnouncementEditorPanel), findsOneWidget);
    });
  });

  group('AdminAnnouncementEditorPanel', () {
    testWidgets(
        'memoizes audience queries across title typing, validates publish, and confirms before publishing',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final draft = Announcement(
        id: 'draft-1',
        title: '',
        body: '',
        status: AnnouncementStatus.draft,
        createdBy: 'admin-1',
        createdAt: DateTime(2026, 11, 10),
      );
      final service = _FakeAnnouncementService(
        items: [draft],
        audienceCount: 24,
      );
      var changedCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 560,
              height: 820,
              child: AdminAnnouncementEditorPanel(
                announcementId: 'draft-1',
                service: service,
                onChanged: () => changedCalls++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only 1 initial countAudience query runs on load.
      expect(service.countAudienceCalls, 1);
      expect(find.text('All alumni (24) — no filters applied'), findsOneWidget);

      // Clicking Publish with empty Title & Message validates inline cleanly.
      await tester.tap(find.text('Publish'));
      await tester.pump();
      expect(find.text('Enter a title before publishing.'), findsOneWidget);
      expect(
        find.text('Enter a message body before publishing.'),
        findsOneWidget,
      );
      expect(service.publishedIds, isEmpty);

      // Typing title & message updates live header title WITHOUT re-querying countAudience.
      await tester.enterText(
        find.widgetWithText(TextField, 'Headline for alumni'),
        'Campus Advisory',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Write the announcement details…'),
        'Classes resume on Monday.',
      );
      await tester.pump();
      expect(find.text('Campus Advisory'), findsNWidgets(2));
      expect(service.countAudienceCalls, 1);

      // Selecting a course filter triggers countAudience once more.
      final bsitChip = find.widgetWithText(FilterChip, 'BSIT');
      await tester.ensureVisible(bsitChip);
      await tester.pumpAndSettle();
      await tester.tap(bsitChip);
      await tester.pumpAndSettle();
      expect(service.countAudienceCalls, 2);

      // Clicking Publish shows confirmation dialog with count & channels.
      await tester.tap(find.text('Publish'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Publish announcement?'), findsOneWidget);
      expect(
        find.textContaining('24 alumni (BSIT) via In-app · Push'),
        findsOneWidget,
      );

      await tester.tap(find.text('Publish now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(service.publishedIds, ['draft-1']);
      expect(changedCalls, 1);
    });

    testWidgets('shows error state and retries when loading announcement fails',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final service = _FakeAnnouncementService(items: _seedAnnouncements())
        ..throwOnGetOne = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 560,
              height: 820,
              child: AdminAnnouncementEditorPanel(
                announcementId: 'a-draft',
                service: service,
                onChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load announcement"), findsOneWidget);
      service.throwOnGetOne = false;

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Survey Draft Notice'), findsWidgets);
    });
  });
}
