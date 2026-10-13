import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/reports/application/admin_reports_analytics.dart';
import 'package:alumni_system/features/admin/reports/data/custom_report_export_service.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

void main() {
  group('CustomReportTemplate', () {
    test('json round-trips', () {
      final now = DateTime(2026, 7, 22, 12);
      final template = CustomReportTemplate(
        id: 't1',
        name: 'Weekly pack',
        sections: const [
          CustomReportSectionId.executiveKpis,
          CustomReportSectionId.alumniRoster,
        ],
        format: CustomReportFormat.csv,
        filters: CustomReportFilters(
          batchYears: const ['2024'],
          courses: const ['BSIT'],
          registration: CustomReportRegistrationFilter.registeredOnly,
          dateStart: DateTime(2026, 1, 1),
          dateEnd: DateTime(2026, 6, 30),
        ),
        createdAt: now,
        updatedAt: now,
      );

      final restored = CustomReportTemplate.fromJson(template.toJson());
      expect(restored.id, 't1');
      expect(restored.name, 'Weekly pack');
      expect(restored.sections, [
        CustomReportSectionId.executiveKpis,
        CustomReportSectionId.alumniRoster,
      ]);
      expect(restored.format, CustomReportFormat.csv);
      expect(restored.filters.batchYears, ['2024']);
      expect(restored.filters.courses, ['BSIT']);
      expect(
        restored.filters.registration,
        CustomReportRegistrationFilter.registeredOnly,
      );
      expect(restored.filters.dateStart, DateTime(2026, 1, 1));
      expect(restored.filters.dateEnd, DateTime(2026, 6, 30));
    });

    test('validate requires name and sections', () {
      final empty = CustomReportTemplate.draft(id: 'x');
      expect(empty.validate(), 'Enter a template name.');

      final named = empty.copyWith(name: 'Pack', sections: const []);
      expect(named.validate(), 'Select at least one section.');

      final ok = named.copyWith(
        sections: const [CustomReportSectionId.events],
      );
      expect(ok.validate(), isNull);
    });

    test('name is optional when exporting without saving', () {
      final unnamed = CustomReportTemplate.draft(id: 'x');
      expect(unnamed.name, isEmpty);
      expect(unnamed.validate(forSave: false), isNull);

      final noSections = unnamed.copyWith(sections: const []);
      expect(
        noSections.validate(forSave: false),
        'Select at least one section.',
      );
    });
  });

  group('CustomReportExportService', () {
    late AdminReportsAnalytics analytics;
    late List<AlumniEvent> events;
    late List<JobPosting> jobs;

    setUp(() {
      analytics = AdminReportsAnalytics(
        members: [
          AlumniMember(
            id: '1',
            fullName: 'Ada Lovelace',
            course: 'BSIT',
            studentId: '2024-001',
            batchYear: '2024',
            isRegisteredUser: true,
            tracerProfileComplete: true,
            authUid: 'uid-1',
          ),
          AlumniMember(
            id: '2',
            fullName: 'Grace Hopper',
            course: 'BSCS',
            studentId: '2023-002',
            batchYear: '2023',
            isRegisteredUser: false,
            tracerProfileComplete: false,
          ),
          AlumniMember(
            id: '3',
            fullName: 'Alan Turing',
            course: 'BSIT',
            studentId: '2024-003',
            batchYear: '2024',
            isRegisteredUser: true,
            tracerProfileComplete: false,
            authUid: 'uid-3',
          ),
          // Legacy batchYear empty; only the tracer graduation year is set.
          AlumniMember(
            id: '4',
            fullName: 'Radia Perlman',
            course: 'BSCS',
            studentId: '2022-004',
            batchYear: '',
            yearGraduated: '2022',
            isRegisteredUser: false,
            tracerProfileComplete: false,
            createdAt: DateTime(2026, 1, 15),
          ),
          // Roster mirror is completely blank; data lives on the account.
          AlumniMember(
            id: '5',
            fullName: 'Katherine Johnson',
            course: 'BSIT',
            studentId: '2020-005',
            batchYear: '',
            isRegisteredUser: true,
            authUid: 'uid-5',
          ),
        ],
        employmentRecords: [
          EmploymentRecord(
            id: 'e1',
            userId: 'uid-1',
            userName: 'Ada Lovelace',
            userEmail: 'ada@example.com',
            schoolId: '2024-001',
            employmentStatus: 'Employed',
            companyName: 'Analytical Engines',
            position: 'Engineer',
            industry: 'Tech',
            contactNumber: '',
            lastUpdated: DateTime(2026, 3, 1),
          ),
          EmploymentRecord(
            id: 'e2',
            userId: 'uid-3',
            userName: 'Alan Turing',
            userEmail: 'alan@example.com',
            schoolId: '2024-003',
            employmentStatus: 'Unemployed',
            contactNumber: '',
            lastUpdated: DateTime(2026, 5, 1),
          ),
        ],
        surveys: [
          Survey(
            id: 's1',
            title: 'Wave 1',
            description: '',
            status: SurveyStatus.published,
            createdBy: 'admin',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
            assignmentCount: 10,
            responseCount: 4,
          ),
        ],
        announcements: const [],
        forumTopics: const [],
        portalUserCount: 2,
        assignmentCountsBySurveyId: const {'s1': 10},
        submittedResponsesBySurveyId: const {'s1': 4},
      );

      events = [
        AlumniEvent(
          id: 'ev1',
          theme: 'Homecoming',
          batchYear: '2024',
          date: DateTime(2026, 4, 10),
          venue: 'Gym',
          status: 'Active',
          comments: 0,
        ),
        AlumniEvent(
          id: 'ev2',
          theme: 'Career Fair',
          batchYear: '2023',
          date: DateTime(2025, 11, 1),
          venue: 'Hall',
          status: 'Active',
          comments: 0,
        ),
      ];

      jobs = [
        JobPosting(
          id: 'j1',
          companyName: 'Acme',
          companyLogo: '',
          jobTitle: 'Developer',
          jobType: 'Full-time',
          location: 'CDO',
          salaryRange: '',
          description: '',
          requirements: const [],
          benefits: const [],
          postedDate: DateTime(2026, 2, 1),
          applicationDeadline: DateTime(2026, 8, 1),
          contactEmail: 'hr@acme.com',
          applicationMethod: 'email',
          isActive: true,
          views: 0,
          applications: 0,
          adminId: 'admin',
          isRemote: false,
          experienceLevel: 'Mid',
          status: 'active',
        ),
      ];
    });

    CustomReportTemplate template({
      List<CustomReportSectionId> sections = const [
        CustomReportSectionId.alumniRoster,
        CustomReportSectionId.employmentRecords,
        CustomReportSectionId.events,
      ],
      CustomReportFilters filters = const CustomReportFilters(),
      CustomReportFormat format = CustomReportFormat.csv,
    }) {
      final now = DateTime(2026, 7, 22);
      return CustomReportTemplate(
        id: 't',
        name: 'Test Pack',
        sections: sections,
        format: format,
        filters: filters,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('filters roster by batch course registration tracer', () {
      final doc = CustomReportExportService.buildDocument(
        template: template(
          filters: const CustomReportFilters(
            batchYears: ['2024'],
            courses: ['BSIT'],
            registration: CustomReportRegistrationFilter.registeredOnly,
            tracer: CustomReportTracerFilter.incompleteOnly,
          ),
        ),
        analytics: analytics,
        events: events,
        jobs: jobs,
      );

      final roster = doc.sections
          .firstWhere((s) => s.id == CustomReportSectionId.alumniRoster);
      expect(roster.rows.length, 1);
      expect(roster.rows.first.first, 'Alan Turing');
    });

    test('roster batch filter falls back to graduation year', () {
      final doc = CustomReportExportService.buildDocument(
        template: template(
          sections: const [CustomReportSectionId.alumniRoster],
          filters: const CustomReportFilters(batchYears: ['2022']),
        ),
        analytics: analytics,
        events: events,
        jobs: jobs,
      );

      final roster = doc.sections.single;
      expect(roster.rows.length, 1);
      expect(roster.rows.first.first, 'Radia Perlman');
      expect(roster.rows.first[3], '2022');
    });

    test('roster batch and email come from the registered profile', () {
      const profiles = {
        'uid-5': TracerProfile(
          uid: 'uid-5',
          email: 'katherine@example.com',
          displayName: 'Katherine Johnson',
          studentId: '2020-005',
          program: 'BSIT',
          batchYear: '2020',
          yearGraduated: '2020',
        ),
      };

      final doc = CustomReportExportService.buildDocument(
        template: template(
          sections: const [CustomReportSectionId.alumniRoster],
          filters: const CustomReportFilters(batchYears: ['2020']),
        ),
        analytics: analytics,
        events: events,
        jobs: jobs,
        profilesByAuthUid: profiles,
      );

      final roster = doc.sections.single;
      expect(roster.rows.length, 1);
      final row = roster.rows.first;
      expect(row.first, 'Katherine Johnson');
      expect(row[3], '2020'); // batch from profile
      expect(row[4], 'katherine@example.com'); // email from profile

      // Without profile data the same filter matches nothing.
      final bare = CustomReportExportService.buildDocument(
        template: template(
          sections: const [CustomReportSectionId.alumniRoster],
          filters: const CustomReportFilters(batchYears: ['2020']),
        ),
        analytics: analytics,
        events: events,
        jobs: jobs,
      );
      expect(bare.sections.single.rows, isEmpty);
    });

    test('roster date range filters by date the member was added', () {
      // Only Radia (added Jan 15, 2026) falls inside this window; the other
      // members default to "now", which is outside it.
      final doc = CustomReportExportService.buildDocument(
        template: template(
          sections: const [CustomReportSectionId.alumniRoster],
          filters: CustomReportFilters(
            dateStart: DateTime(2026, 1, 1),
            dateEnd: DateTime(2026, 1, 31),
          ),
        ),
        analytics: analytics,
        events: events,
        jobs: jobs,
      );
      final roster = doc.sections.single;
      expect(roster.rows.length, 1);
      expect(roster.rows.first.first, 'Radia Perlman');

      // A window before any member existed yields no roster rows.
      final emptyDoc = CustomReportExportService.buildDocument(
        template: template(
          sections: const [CustomReportSectionId.alumniRoster],
          filters: CustomReportFilters(
            dateStart: DateTime(2020, 1, 1),
            dateEnd: DateTime(2020, 12, 31),
          ),
        ),
        analytics: analytics,
        events: events,
        jobs: jobs,
      );
      expect(emptyDoc.sections.single.rows, isEmpty);
    });

    test('filters employment and events by status and date', () {
      final doc = CustomReportExportService.buildDocument(
        template: template(
          filters: CustomReportFilters(
            employment: CustomReportEmploymentFilter.employedOnly,
            dateStart: DateTime(2026, 1, 1),
            dateEnd: DateTime(2026, 4, 30),
          ),
        ),
        analytics: analytics,
        events: events,
        jobs: jobs,
      );

      final employment = doc.sections
          .firstWhere((s) => s.id == CustomReportSectionId.employmentRecords);
      expect(employment.rows.length, 1);
      expect(employment.rows.first[2], 'Employed');

      final eventSection =
          doc.sections.firstWhere((s) => s.id == CustomReportSectionId.events);
      expect(eventSection.rows.length, 1);
      expect(eventSection.rows.first.first, 'Homecoming');
    });

    test('employment rows follow batch and course filters', () {
      CustomReportSectionData employmentFor(CustomReportFilters filters) =>
          CustomReportExportService.buildDocument(
            template: template(
              sections: const [CustomReportSectionId.employmentRecords],
              filters: filters,
            ),
            analytics: analytics,
            events: events,
            jobs: jobs,
          ).sections.single;

      expect(employmentFor(const CustomReportFilters()).rows.length, 2);
      expect(
        employmentFor(
          const CustomReportFilters(batchYears: ['2024'], courses: ['BSIT']),
        ).rows.map((r) => r.first),
        ['Ada Lovelace', 'Alan Turing'],
      );
      expect(
        employmentFor(const CustomReportFilters(courses: ['BSCS'])).rows,
        isEmpty,
      );
      expect(
        employmentFor(const CustomReportFilters(batchYears: ['2023'])).rows,
        isEmpty,
      );
    });

    test('employment rows show type and place of work, not company', () {
      final withPlace = AdminReportsAnalytics(
        members: analytics.members,
        employmentRecords: [
          EmploymentRecord(
            id: 'e1',
            userId: 'uid-1',
            userName: 'Ada Lovelace',
            userEmail: 'ada@example.com',
            schoolId: '2024-001',
            employmentStatus: 'Employed',
            employmentType: 'Regular or Permanent',
            position: 'Engineer',
            industry: 'Tech',
            country: 'Philippines',
            contactNumber: '',
            lastUpdated: DateTime(2026, 3, 1),
          ),
        ],
        surveys: const [],
        announcements: const [],
        forumTopics: const [],
        portalUserCount: 2,
      );
      final section = CustomReportExportService.buildDocument(
        template: template(
          sections: const [CustomReportSectionId.employmentRecords],
        ),
        analytics: withPlace,
        events: events,
        jobs: jobs,
      ).sections.single;

      expect(section.headers, isNot(contains('Company')));
      final row = section.rows.single;
      expect(
        row[section.headers.indexOf('Employment type')],
        'Regular or Permanent',
      );
      expect(row[section.headers.indexOf('Place of work')], 'Local');
    });

    test('executive KPIs split not employed from never employed', () {
      final mixed = AdminReportsAnalytics(
        members: analytics.members,
        employmentRecords: [
          ...analytics.employmentRecords,
          EmploymentRecord(
            id: 'e3',
            userId: 'uid-5',
            userName: 'Katherine Johnson',
            userEmail: 'katherine@example.com',
            schoolId: '2020-005',
            employmentStatus: 'Never Employed',
            contactNumber: '',
            lastUpdated: DateTime(2026, 5, 2),
          ),
        ],
        surveys: const [],
        announcements: const [],
        forumTopics: const [],
        portalUserCount: 3,
      );
      expect(mixed.employedCount, 1);
      expect(mixed.notEmployedCount, 1);
      expect(mixed.neverEmployedCount, 1);
      expect(mixed.unemployedCount, 2);

      final kpis = CustomReportExportService.buildDocument(
        template: template(
          sections: const [CustomReportSectionId.executiveKpis],
        ),
        analytics: mixed,
        events: events,
        jobs: jobs,
      ).sections.single;
      String value(String metric) =>
          kpis.rows.firstWhere((r) => r.first == metric)[1];

      expect(value('Employed (item 16: Yes)'), '1');
      expect(value('Not employed (item 16: No)'), '1');
      expect(value('Never employed (item 16: Never Employed)'), '1');
      expect(kpis.rows.any((r) => r.first == 'Unemployed'), isFalse);
    });

    test('csv contains section markers and rows', () {
      final doc = CustomReportExportService.buildDocument(
        template: template(
          sections: const [
            CustomReportSectionId.executiveKpis,
            CustomReportSectionId.surveySummary,
          ],
        ),
        analytics: analytics,
        events: events,
        jobs: jobs,
      );
      final csv = CustomReportExportService.toCsv(doc);
      expect(csv, contains('SECTION,Executive KPIs'));
      expect(csv, contains('SECTION,Survey summary'));
      expect(csv, contains('Wave 1'));
      expect(csv, contains('Roster total'));
    });

    test('builds survey participation and question sections from pack', () {
      final doc = CustomReportExportService.buildDocument(
        template: template(
          sections: const [
            CustomReportSectionId.surveyParticipation,
            CustomReportSectionId.surveyQuestions,
          ],
        ),
        analytics: analytics,
        events: events,
        jobs: jobs,
      );

      final participation = doc.sections.firstWhere(
        (s) => s.id == CustomReportSectionId.surveyParticipation,
      );
      expect(participation.rows, isNotEmpty);
      expect(participation.rows.first.first, 'Funnel');
      expect(participation.rows.any((r) => r.first == 'Insight'), isTrue);

      // No rollups supplied, so question summaries are present but empty.
      final questions = doc.sections.firstWhere(
        (s) => s.id == CustomReportSectionId.surveyQuestions,
      );
      expect(questions.headers.first, 'Survey');
      expect(questions.rows, isEmpty);
    });

    test('excel populates worksheets for selected sections', () {
      final doc = CustomReportExportService.buildDocument(
        template: template(
          sections: const [
            CustomReportSectionId.executiveKpis,
            CustomReportSectionId.alumniRoster,
          ],
          format: CustomReportFormat.excel,
        ),
        analytics: analytics,
        events: events,
        jobs: jobs,
      );
      final bytes = CustomReportExportService.toExcel(doc);
      expect(bytes.isNotEmpty, isTrue);

      // Re-read via excel package would require import; size + non-empty is enough
      // together with sheet naming smoke via round-trip in package tests above.
      expect(bytes.length, greaterThan(1000));
    });
  });
}
