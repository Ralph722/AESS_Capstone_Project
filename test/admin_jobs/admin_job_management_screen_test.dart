import 'dart:convert';

import 'package:alumni_system/features/admin/jobs/presentation/admin_job_management_page.dart';
import 'package:alumni_system/features/admin/jobs/widgets/admin_job_ui.dart';
import 'package:alumni_system/features/jobs/data/job_interest_service.dart';
import 'package:alumni_system/features/jobs/data/job_service.dart';
import 'package:alumni_system/features/jobs/models/job_interest_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_metric_ribbon.dart';
import 'package:alumni_system/shared/widgets/admin/admin_pagination.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_tabs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_toolbar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeJobService extends JobService {
  _FakeJobService({required this.jobs})
      : super(supabase: Supabase.instance.client);

  final List<JobPosting> jobs;
  bool throwOnGetAll = false;
  int getAllCalls = 0;

  final List<JobPosting> addedJobs = [];
  final List<JobPosting> updatedJobs = [];
  final List<String> deletedIds = [];

  @override
  Future<List<JobPosting>> getAllJobs({bool expireFirst = true}) async {
    getAllCalls++;
    if (throwOnGetAll) {
      throw Exception('Network unavailable');
    }
    return List.of(jobs);
  }

  @override
  Future<void> addJobPosting(JobPosting job) async {
    addedJobs.add(job);
    jobs.insert(0, job);
  }

  @override
  Future<void> updateJobPosting(JobPosting job) async {
    updatedJobs.add(job);
    final idx = jobs.indexWhere((j) => j.id == job.id);
    if (idx != -1) jobs[idx] = job;
  }

  @override
  Future<void> deleteJobPosting(String jobId) async {
    deletedIds.add(jobId);
    jobs.removeWhere((j) => j.id == jobId);
  }
}

class _FakeInterestService extends JobInterestService {
  _FakeInterestService({this.alumniByJob = const {}})
      : super(supabase: Supabase.instance.client);

  final Map<String, List<JobInterestedAlumni>> alumniByJob;

  @override
  Future<List<JobInterestedAlumni>> listAlumniForJob(String jobId) async =>
      List.of(alumniByJob[jobId] ?? const []);
}

JobPosting _makeJob({
  required String id,
  required String title,
  String company = 'Tech Corp',
  String status = 'active',
  String category = 'IT',
  String jobType = 'Full-time',
  bool isRemote = false,
  int views = 10,
  int interested = 1,
}) {
  return JobPosting(
    id: id,
    companyName: company,
    companyLogo: '',
    jobTitle: title,
    jobType: jobType,
    location: 'Cagayan de Oro',
    salaryRange: '45,000 - 60,000',
    description: 'Role description.',
    requirements: const ['Bachelor degree'],
    benefits: const ['HMO'],
    postedDate: DateTime(2026, 11, 5),
    applicationDeadline: DateTime(2026, 12, 30),
    contactEmail: 'hr@techcorp.ph',
    applicationMethod: 'email',
    isActive: status == 'active',
    views: views,
    applications: 0,
    adminId: 'admin-1',
    isRemote: isRemote,
    experienceLevel: 'Mid-level',
    status: status,
    category: category,
    interestedCount: interested,
  );
}

List<JobPosting> _seedJobs() => [
  _makeJob(
    id: 'j-active-it',
    title: 'Mobile App Engineer',
    company: 'Northern Cloud',
    status: 'active',
    category: 'IT',
    isRemote: true,
    views: 55,
    interested: 4,
  ),
  _makeJob(
    id: 'j-active-bus',
    title: 'Operations Analyst',
    company: 'Harbor Logistics',
    status: 'active',
    category: 'Business',
    isRemote: false,
    views: 20,
    interested: 1,
  ),
  _makeJob(
    id: 'j-exp',
    title: 'Civil Site Lead',
    company: 'BuildCorp',
    status: 'expired',
    category: 'Engineering',
  ),
  _makeJob(
    id: 'j-arch',
    title: 'Legacy IT Support',
    company: 'Campus Systems',
    status: 'archived',
    category: 'IT',
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

  group('AdminJobManagement', () {
    testWidgets(
      'renders SaaS header, tabs, metric ribbon, toolbar filtering, and pagination',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final service = _FakeJobService(jobs: _seedJobs());
        final interestService = _FakeInterestService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminJobManagement(
                service: service,
                interestService: interestService,
                engagementLoader: (jobs) async => jobs,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AdminCompactHeader), findsOneWidget);
        expect(find.byType(AdminSaaSTabs), findsOneWidget);
        expect(find.byType(AdminMetricRibbon), findsOneWidget);
        expect(find.byType(AdminSaaSToolbar), findsOneWidget);
        expect(find.text('2 active'), findsOneWidget);

        // Active tab hides expired & archived jobs by default.
        expect(find.text('Mobile App Engineer'), findsOneWidget);
        expect(find.text('Operations Analyst'), findsOneWidget);
        expect(find.text('Civil Site Lead'), findsNothing);
        expect(find.text('Legacy IT Support'), findsNothing);

        // Switch via AdminSaaSTabs to Archived then All.
        await tester.tap(
          find.descendant(
            of: find.byType(AdminSaaSTabs),
            matching: find.text('Archived'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Legacy IT Support'), findsOneWidget);
        expect(find.text('Mobile App Engineer'), findsNothing);

        await tester.tap(
          find.descendant(
            of: find.byType(AdminSaaSTabs),
            matching: find.text('All'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Mobile App Engineer'), findsOneWidget);
        expect(find.text('Civil Site Lead'), findsOneWidget);
        expect(find.text('Legacy IT Support'), findsOneWidget);

        // Return to Active via Active metric card.
        await tester.tap(
          find.descendant(
            of: find.byType(AdminMetricRibbon),
            matching: find.text('Active'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Mobile App Engineer'), findsOneWidget);
        expect(find.text('Civil Site Lead'), findsNothing);

        // Filter by Category = IT and Remote = Remote, then Reset.
        await tester.tap(find.text('All categories'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('IT').last);
        await tester.pumpAndSettle();
        expect(find.text('Mobile App Engineer'), findsOneWidget);
        expect(find.text('Operations Analyst'), findsNothing);

        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();
        expect(find.text('Operations Analyst'), findsOneWidget);
      },
    );

    testWidgets('paginates active job listings across AdminPaginationBar pages',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final manyJobs = List.generate(
        25,
        (i) => _makeJob(id: 'bulk-$i', title: 'Engineer Role ${i + 1}'),
      );
      final pagedService = _FakeJobService(jobs: manyJobs);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminJobManagement(
              service: pagedService,
              interestService: _FakeInterestService(),
              engagementLoader: (jobs) async => jobs,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminPaginationBar), findsOneWidget);
      expect(find.text('Showing 1–20 of 25'), findsOneWidget);
      expect(find.text('Page 1 of 2'), findsOneWidget);

      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Showing 21–25 of 25'), findsOneWidget);
      expect(find.text('Page 2 of 2'), findsOneWidget);
    });

    testWidgets(
      'opens Quick insights, creates new job via AddJobDialog, archives, opens Interested, and deletes with confirmation',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final service = _FakeJobService(jobs: _seedJobs());
        final interestService = _FakeInterestService(
          alumniByJob: {
            'j-active-it': [
              JobInterestedAlumni(
                userId: 'u-1',
                name: 'Marco Polo',
                email: 'marco@ustp.edu.ph',
                interestedAt: DateTime(2026, 11, 10),
                course: 'BSIT',
                batch: '2024',
              ),
            ],
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminJobManagement(
                service: service,
                interestService: interestService,
                engagementLoader: (jobs) async => jobs,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open Quick insights dialog.
        await tester.tap(find.text('Insights'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminModalHeader), findsOneWidget);
        expect(find.text('Quick insights'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        // Open Post new job dialog & submit valid job.
        await tester.tap(find.text('Post new job'));
        await tester.pumpAndSettle();
        expect(find.text('Post new job'), findsWidgets);

        Future<void> fill(String label, String text) async {
          final field = find.widgetWithText(TextFormField, label);
          await tester.ensureVisible(field);
          await tester.enterText(field, text);
        }

        await fill('Job title *', 'QA Automation Engineer');
        await fill('Company name *', 'Bukidnon Digital');
        await fill('Location *', 'CDO');
        await fill('Salary range *', '55,000');
        await fill('Description *', 'Lead automated Flutter test suites.');
        await fill('Contact email *', 'careers@bukidnondigital.ph');

        await tester.tap(find.text('Post job'));
        await tester.pumpAndSettle();
        expect(service.addedJobs.length, 1);
        expect(service.addedJobs.single.jobTitle, 'QA Automation Engineer');
        expect(find.text('QA Automation Engineer'), findsOneWidget);

        Finder menuFor(String title) => find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(AdminJobCard),
          ),
          matching: find.byTooltip('Job actions'),
        );

        // Archive newly created job ('QA Automation Engineer').
        await tester.tap(menuFor('QA Automation Engineer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Archive'));
        await tester.pumpAndSettle();
        expect(service.updatedJobs.single.status, 'archived');
        expect(find.text('Job archived'), findsOneWidget);
        expect(find.text('QA Automation Engineer'), findsNothing);

        // Open Interested alumni drawer on 'Mobile App Engineer'.
        await tester.tap(menuFor('Mobile App Engineer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Interested (4)'));
        await tester.pumpAndSettle();
        expect(find.text('Interested alumni'), findsOneWidget);
        expect(find.text('Marco Polo'), findsOneWidget);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();

        // Delete 'Mobile App Engineer' via destructive showAdminConfirmDialog.
        await tester.tap(menuFor('Mobile App Engineer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Permanently delete “Mobile App Engineer”'),
          findsOneWidget,
        );
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(service.deletedIds, ['j-active-it']);
        expect(find.text('Job deleted'), findsOneWidget);
        expect(find.text('Mobile App Engineer'), findsNothing);
      },
    );

    testWidgets(
      'displays error recovery on initial load failure and warning banner on refresh failure',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final service = _FakeJobService(jobs: _seedJobs())
          ..throwOnGetAll = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminJobManagement(
                service: service,
                interestService: _FakeInterestService(),
                engagementLoader: (jobs) async => jobs,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AdminStateView), findsOneWidget);
        expect(find.text("Couldn't load job postings"), findsOneWidget);

        service.throwOnGetAll = false;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text('Mobile App Engineer'), findsOneWidget);

        service.throwOnGetAll = true;
        await tester.tap(find.byTooltip('Refresh job postings'));
        await tester.pumpAndSettle();
        expect(find.text('Mobile App Engineer'), findsOneWidget);
        expect(
          find.text(
            "Couldn't refresh job postings. Showing the last loaded list.",
          ),
          findsOneWidget,
        );
      },
    );
  });
}
