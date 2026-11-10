import 'dart:convert';

import 'package:alumni_system/features/admin/jobs/widgets/admin_job_ui.dart';
import 'package:alumni_system/features/jobs/models/job_interest_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/user/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_shared/admin_test_harness.dart';

JobPosting _job({
  String id = 'j-1',
  String title = 'Senior Flutter Developer',
  String company = 'Mindanao Tech Corp',
  String status = 'active',
  String category = 'IT',
  String jobType = 'Full-time',
  String location = 'Cagayan de Oro',
  String salary = '50,000 - 70,000',
  bool isRemote = true,
  int views = 42,
  int interestedCount = 5,
  int favoriteCount = 3,
  DateTime? deadline,
}) {
  return JobPosting(
    id: id,
    companyName: company,
    companyLogo: '',
    jobTitle: title,
    jobType: jobType,
    location: location,
    salaryRange: salary,
    description: 'Build cross-platform career apps.',
    requirements: const ['Flutter 3+', 'REST & Supabase experience'],
    benefits: const ['Flexible hours', 'HMO'],
    postedDate: DateTime(2026, 11, 1),
    applicationDeadline: deadline ?? DateTime(2026, 12, 31),
    contactEmail: 'jobs@mindanaotech.ph',
    applicationMethod: 'email',
    isActive: status == 'active',
    views: views,
    applications: 0,
    adminId: 'admin-1',
    isRemote: isRemote,
    experienceLevel: 'Mid-level',
    status: status,
    category: category,
    targetPrograms: const ['BSIT', 'BSCS'],
    interestedCount: interestedCount,
    favoriteCount: favoriteCount,
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

  group('jobFriendlyError', () {
    test('returns user-readable errors and masks technical exceptions', () {
      expect(
        jobFriendlyError(Exception('Network timeout'), 'Fallback message'),
        'Network timeout',
      );
      expect(
        jobFriendlyError(
          Exception('PostgrestException: relation error'),
          'Fallback message',
        ),
        'Fallback message',
      );
      expect(
        jobFriendlyError(
          Exception('Error deleting job: RLS'),
          'Fallback message',
        ),
        'Fallback message',
      );
      expect(jobFriendlyError('', 'Fallback message'), 'Fallback message');
      expect(
        jobFriendlyError('x' * 170, 'Fallback message'),
        'Fallback message',
      );
    });
  });

  group('AdminJobStatusBadges', () {
    testWidgets('renders Active, category, Remote, and closing deadline badge',
        (tester) async {
      final soon = DateTime.now().add(const Duration(days: 3));
      await pumpAdmin(
        tester,
        AdminJobStatusBadges(job: _job(deadline: soon)),
      );

      expect(find.byType(AdminBadge), findsNWidgets(4));
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('IT'), findsOneWidget);
      expect(find.text('Remote'), findsOneWidget);
      expect(find.text('3 days left'), findsOneWidget);
    });

    testWidgets('renders Expired and Archived states without active deadline alert',
        (tester) async {
      final past = DateTime.now().subtract(const Duration(days: 2));
      await pumpAdmin(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminJobStatusBadges(
              job: _job(status: 'expired', isRemote: false, deadline: past),
            ),
            const SizedBox(height: 8),
            AdminJobStatusBadges(
              job: _job(status: 'archived', isRemote: false, deadline: past),
            ),
          ],
        ),
      );

      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Application closed'), findsNothing);
    });
  });

  group('AdminJobCard', () {
    for (final width in kAdminTestWidths) {
      testWidgets('renders cleanly across widths ($width px)', (tester) async {
        await pumpAdmin(
          tester,
          AdminJobCard(
            job: _job(),
            onEdit: () {},
            onDetails: () {},
            onInterested: () {},
            onToggleArchive: () {},
            onDelete: () {},
            onShare: () {},
          ),
          width: width,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Senior Flutter Developer'), findsOneWidget);
        expect(find.text('42 views · 5 interested'), findsOneWidget);
        expect(
          find.textContaining('Mindanao Tech Corp · Full-time · Remote'),
          findsOneWidget,
        );
        expect(
          find.text('ENGAGEMENT & DEADLINE'),
          width >= AdminJobCard.zoneLayoutMinWidth
              ? findsOneWidget
              : findsNothing,
        );
      });
    }

    testWidgets('invokes card/menu callbacks and displays spinner when busy',
        (tester) async {
      var detailsTapped = false;
      var archiveTapped = false;
      var deleteTapped = false;

      await pumpAdmin(
        tester,
        AdminJobCard(
          job: _job(deadline: DateTime.now().add(const Duration(days: 30))),
          onEdit: () {},
          onDetails: () => detailsTapped = true,
          onInterested: () {},
          onToggleArchive: () => archiveTapped = true,
          onDelete: () => deleteTapped = true,
          onShare: () {},
        ),
      );

      await tester.tap(find.text('Senior Flutter Developer'));
      await tester.pumpAndSettle();
      expect(detailsTapped, isTrue);

      await tester.tap(find.byTooltip('Job actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(archiveTapped, isTrue);

      await tester.tap(find.byTooltip('Job actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleteTapped, isTrue);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1366, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: AdminJobCard(
                job: _job(),
                busy: true,
                onEdit: () {},
                onDetails: () {},
                onInterested: () {},
                onToggleArchive: () {},
                onDelete: () {},
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

  group('AdminJobsListSkeleton & Admin job modals/drawers', () {
    testWidgets('AdminJobsListSkeleton renders across mobile and desktop',
        (tester) async {
      for (final width in [320.0, 1366.0]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(height: 500, child: AdminJobsListSkeleton(count: 3)),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(Skeleton), findsWidgets);
      }
    });

    testWidgets('showAdminJobInsightsDialog renders metrics & empty state',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.reset);

      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                hostContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      showAdminJobInsightsDialog(context: hostContext, jobs: const []);
      await tester.pumpAndSettle();
      expect(find.byType(AdminModalHeader), findsOneWidget);
      expect(find.byType(AdminStateView), findsOneWidget);
      expect(find.text('No job postings yet'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      showAdminJobInsightsDialog(context: hostContext, jobs: [_job()]);
      await tester.pumpAndSettle();
      expect(find.text('Quick insights'), findsOneWidget);
      expect(find.text('Most viewed'), findsOneWidget);
      expect(find.text('42 views'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('showAdminJobDetailsDrawer & showAdminInterestedDrawer render cleanly',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.reset);

      var openInterestedCalled = false;
      var openMessagesCalled = false;
      late BuildContext hostContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                hostContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      showAdminJobDetailsDrawer(
        context: hostContext,
        job: _job(),
        onOpenInterested: () => openInterestedCalled = true,
      );
      await tester.pumpAndSettle();
      expect(find.text('Senior Flutter Developer'), findsOneWidget);
      expect(find.text('₱ 50,000 - 70,000'), findsOneWidget);
      await tester.tap(find.text('Interested alumni (5)'));
      await tester.pumpAndSettle();
      expect(openInterestedCalled, isTrue);

      showAdminInterestedDrawer(
        context: hostContext,
        job: _job(),
        alumni: [
          JobInterestedAlumni(
            userId: 'u-1',
            name: 'Elena Cruz',
            email: 'elena@ustp.edu.ph',
            interestedAt: DateTime(2026, 11, 10, 10, 0),
            course: 'BSIT',
            batch: '2024',
            employmentStatus: 'Employed',
          ),
        ],
        onExportCsv: () async {},
        onOpenMessages: () => openMessagesCalled = true,
      );
      await tester.pumpAndSettle();
      expect(find.text('Interested alumni'), findsOneWidget);
      expect(find.text('Elena Cruz'), findsOneWidget);
      expect(find.text('BSIT · 2024'), findsOneWidget);

      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      expect(openMessagesCalled, isTrue);
    });
  });
}

