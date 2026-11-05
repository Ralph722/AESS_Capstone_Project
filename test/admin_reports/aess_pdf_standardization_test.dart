import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' show PdfDocument, PdfTextExtractor;
import 'package:alumni_system/features/admin/reports/application/admin_reports_analytics.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/data/custom_report_export_service.dart';
import 'package:alumni_system/features/admin/reports/data/gts_list_export_service.dart';
import 'package:alumni_system/features/admin/reports/data/gts_report_export_service.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/data/survey_ched_outcomes_summary_service.dart';
import 'package:alumni_system/features/surveys/data/survey_formal_report_service.dart';
import 'package:alumni_system/features/surveys/data/survey_report_pack_service.dart';
import 'package:alumni_system/features/surveys/data/survey_single_response_export_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/models/survey_reports_aggregate.dart';

String _extractText(List<int> bytes) {
  final doc = PdfDocument(inputBytes: bytes);
  final extractor = PdfTextExtractor(doc);
  final text = [
    for (var i = 0; i < doc.pages.count; i++)
      extractor.extractText(startPageIndex: i, endPageIndex: i),
  ].join(' ').replaceAll(RegExp(r'\s+'), ' ');
  doc.dispose();
  return text;
}

void main() {
  group('AESS PDF Standardization & Professional Redesign', () {
    final now = DateTime(2026, 10, 31, 15, 30);

    final wave1 = Survey(
      id: 'wave_2025',
      title: 'CHED GTS 2025',
      description: 'Annual Graduate Tracer Study 2025',
      status: SurveyStatus.closed,
      createdBy: 'admin',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 12, 31),
      templateKey: 'ched_gts_builtin',
      assignmentCount: 50,
      responseCount: 42,
    );

    final wave2 = Survey(
      id: 'wave_2026',
      title: 'CHED GTS 2026',
      description: 'Annual Graduate Tracer Study 2026',
      status: SurveyStatus.published,
      createdBy: 'admin',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 10, 31),
      templateKey: 'ched_gts_builtin',
      assignmentCount: 75,
      responseCount: 65,
    );

    final rollup1 = SurveyReportRollup(
      survey: wave1,
      aggregates: [
        SurveyQuestionAggregate(
          questionId: 'ched_16',
          prompt: '16. Are you presently employed?',
          type: SurveyQuestionType.singleChoice,
          totalResponses: 42,
          answeredCount: 42,
          skippedCount: 0,
          choicePercentages: {'Yes': 76.2, 'No': 19.0, 'Never Employed': 4.8},
        ),
        SurveyQuestionAggregate(
          questionId: 'ched_17',
          prompt: '17. What are your reasons for not being employed?',
          type: SurveyQuestionType.multipleChoice,
          totalResponses: 42,
          answeredCount: 8,
          skippedCount: 34,
          choicePercentages: {
            'Advance or further study': 50.0,
            'Family concern and decided not to find a job': 37.5,
            'Did not look for a job': 12.5,
          },
        ),
        SurveyQuestionAggregate(
          questionId: 'ched_24a',
          prompt: '24. Is your first job related to the course you took in college?',
          type: SurveyQuestionType.singleChoice,
          totalResponses: 42,
          answeredCount: 32,
          skippedCount: 10,
          choicePercentages: {'Yes': 84.4, 'No': 15.6},
        ),
      ],
    );

    final rollup2 = SurveyReportRollup(
      survey: wave2,
      aggregates: [
        SurveyQuestionAggregate(
          questionId: 'ched_16',
          prompt: '16. Are you presently employed?',
          type: SurveyQuestionType.singleChoice,
          totalResponses: 65,
          answeredCount: 65,
          skippedCount: 0,
          choicePercentages: {'Yes': 81.5, 'No': 15.4, 'Never Employed': 3.1},
        ),
        SurveyQuestionAggregate(
          questionId: 'ched_17',
          prompt: '17. What are your reasons for not being employed?',
          type: SurveyQuestionType.multipleChoice,
          totalResponses: 65,
          answeredCount: 10,
          skippedCount: 55,
          choicePercentages: {
            'Advance or further study': 60.0,
            'Family concern and decided not to find a job': 30.0,
            'Did not look for a job': 10.0,
          },
        ),
        SurveyQuestionAggregate(
          questionId: 'ched_24a',
          prompt: '24. Is your first job related to the course you took in college?',
          type: SurveyQuestionType.singleChoice,
          totalResponses: 65,
          answeredCount: 53,
          skippedCount: 12,
          choicePercentages: {'Yes': 88.7, 'No': 11.3},
        ),
      ],
    );

    final List<AlumniMember> members = [
      AlumniMember(
        id: 'm1',
        authUid: 'u1',
        studentId: '2020-0001',
        fullName: 'Juan Dela Cruz',
        emailAddress: 'juan.delacruz@alumni.ustp.edu.ph',
        course: 'BSIT',
        batchYear: '2024',
        yearGraduated: '2024',
        isRegisteredUser: true,
        tracerProfileComplete: true,
        createdAt: now,
        updatedAt: now,
      ),
      AlumniMember(
        id: 'm2',
        authUid: 'u2',
        studentId: '2020-0002',
        fullName: 'Maria Santos',
        emailAddress: 'maria.santos@alumni.ustp.edu.ph',
        course: 'BSCE',
        batchYear: '2024',
        yearGraduated: '2024',
        isRegisteredUser: true,
        tracerProfileComplete: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final Map<String, TracerProfile> profiles = {
      'u1': const TracerProfile(
        uid: 'u1',
        email: 'juan.delacruz@alumni.ustp.edu.ph',
        displayName: 'Juan Dela Cruz',
        studentId: '2020-0001',
        program: 'BSIT',
        batchYear: '2024',
        yearGraduated: '2024',
        employmentStatus: 'Employed',
        employmentType: 'Full-time',
        employmentOccupation: 'Software Engineer',
      ),
      'u2': const TracerProfile(
        uid: 'u2',
        email: 'maria.santos@alumni.ustp.edu.ph',
        displayName: 'Maria Santos',
        studentId: '2020-0002',
        program: 'BSCE',
        batchYear: '2024',
        yearGraduated: '2024',
        employmentStatus: 'Employed',
        employmentType: 'Full-time',
        employmentOccupation: 'Project Engineer',
      ),
    };

    final analytics = AdminReportsAnalytics(
      members: members,
      employmentRecords: [
        EmploymentRecord(
          id: 'emp1',
          userId: 'u1',
          userName: 'Juan Dela Cruz',
          userEmail: 'juan.delacruz@alumni.ustp.edu.ph',
          schoolId: '2020-0001',
          employmentStatus: 'Employed',
          employmentType: 'Regular or Permanent',
          position: 'Software Systems Engineer',
          industry: 'Information Technology',
          country: 'Philippines',
          contactNumber: '+63 917 123 4567',
          lastUpdated: now,
        ),
        EmploymentRecord(
          id: 'emp2',
          userId: 'u2',
          userName: 'Maria Santos',
          userEmail: 'maria.santos@alumni.ustp.edu.ph',
          schoolId: '2020-0002',
          employmentStatus: 'Employed',
          employmentType: 'Regular or Permanent',
          position: 'Data Analytics Lead',
          industry: 'Finance',
          country: 'Philippines',
          contactNumber: '+63 918 234 5678',
          lastUpdated: now,
        ),
      ],
      surveys: [wave1, wave2],
      announcements: const [],
      forumTopics: const [],
      portalUserCount: 2,
    );

    test('CHED GTS Pack PDF (ched_20261031.pdf equivalent) renders with institutional design and wave grouping', () async {
      final template = CustomReportTemplate(
        id: 'ched',
        name: 'CHED GTS pack',
        sections: const [
          CustomReportSectionId.executiveKpis,
          CustomReportSectionId.surveySummary,
          CustomReportSectionId.surveyQuestions,
          CustomReportSectionId.employmentRecords,
        ],
        format: CustomReportFormat.pdf,
        filters: const CustomReportFilters(),
        createdAt: now,
        updatedAt: now,
      );

      final doc = CustomReportExportService.buildDocument(
        template: template,
        analytics: analytics,
        events: const [],
        jobs: const [],
        rollups: [rollup1, rollup2],
        profilesByAuthUid: profiles,
      );

      final bytes = await CustomReportExportService.toPdf(doc);
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(2000));

      // Verify PDF header magic bytes
      final headerStr = String.fromCharCodes(bytes.take(5));
      expect(headerStr, '%PDF-');

      // Extract rendered text and verify content & institutional structure
      final text = _extractText(bytes);
      expect(text, contains('PUROK 6, MOBOD, OROQUIETA CITY'));
      expect(text, contains('MISAMIS OCCIDENTAL'));
      expect(text, contains('CHED GTS pack'));
      expect(text, contains('Executive KPIs'));
      expect(text, contains('Survey question summaries'));
      // Count headers must appear as whole words (not mid-word wraps only).
      expect(text, contains('Answered'));
      expect(text, contains('Total'));
      expect(text, contains('Not answered'));
      // Verify wave separation headers eliminate question duplication confusion
      expect(text, contains('CHED GTS 2025'));
      expect(text, contains('CHED GTS 2026'));
      // Verify questions and statistical data
      expect(text, contains('16. Are you presently employed?'));
      expect(text, contains('76%'));
      expect(text, contains('82%'));
      // Verify Data Privacy Act of 2012 notice is present due to employment records
      expect(text, contains('RA 10173'));
      // Verify Page numbering
      expect(text, contains('Page | 1 of'));

      final outputDir = Directory('output/pdf');
      if (!outputDir.existsSync()) outputDir.createSync(recursive: true);
      File('output/pdf/sample_ched_20261031_redesigned.pdf').writeAsBytesSync(bytes);
    });

    test('Survey Report Pack renders in landscape with proper column widths', () async {
      final pack = SurveyReportPackService.buildPortfolioPack(
        analytics: analytics,
        rollups: [rollup1, rollup2],
      );

      final bytes = await SurveyReportPackService.toPdf(pack);
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(2000));

      final headerStr = String.fromCharCodes(bytes.take(5));
      expect(headerStr, '%PDF-');

      // Verify landscape format
      expect(
        latin1.decode(bytes),
        matches(RegExp(r'/MediaBox\s*\[\s*0\s+0\s+841\.8')),
      );

      final text = _extractText(bytes);
      expect(text, contains('PUROK 6, MOBOD, OROQUIETA CITY'));
      expect(text, contains('CHED GTS 2026'));
      expect(text, contains('82%'));
      expect(text, contains('Page | 1 of'));

      File('output/pdf/sample_survey_management_pack_redesigned.pdf')
          .writeAsBytesSync(bytes);
    });

    test('CHED Outcomes Summary renders with KPI cards and proportional table', () async {
      final summary = ChedOutcomesSummary(
        survey: wave2,
        generatedAt: now,
        assigned: 75,
        submitted: 65,
        pending: 10,
        fields: [
          const ChedOutcomeFieldBlock(
            questionId: 'ched_16',
            label: 'Presently Employed',
            answeredCount: 65,
            highlightLabel: 'Yes',
            highlightPercent: 81.5,
            rows: [
              ChedOutcomeChoiceRow(label: 'Yes', count: 53, percent: 81.5),
              ChedOutcomeChoiceRow(label: 'No', count: 10, percent: 15.4),
              ChedOutcomeChoiceRow(label: 'Never Employed', count: 2, percent: 3.1),
            ],
          ),
          const ChedOutcomeFieldBlock(
            questionId: 'ched_24a',
            label: 'Job Related to Course',
            answeredCount: 53,
            highlightLabel: 'Yes',
            highlightPercent: 88.7,
            rows: [
              ChedOutcomeChoiceRow(label: 'Yes', count: 47, percent: 88.7),
              ChedOutcomeChoiceRow(label: 'No', count: 6, percent: 11.3),
            ],
          ),
        ],
      );

      final bytes = await SurveyChedOutcomesSummaryService.toPdf(summary);
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1500));

      final headerStr = String.fromCharCodes(bytes.take(5));
      expect(headerStr, '%PDF-');

      final text = _extractText(bytes);
      expect(text, contains('CHED Tracer Outcomes Summary'));
      expect(text, contains('Presently Employed'));
      expect(text, contains('81.5%'));
      expect(text, contains('Job Related to Course'));
      expect(text, contains('88.7%'));

      File('output/pdf/sample_ched_outcomes_summary_redesigned.pdf')
          .writeAsBytesSync(bytes);
    });

    test('Survey Single Response PDF renders with metadata card and privacy footer', () async {
      final assignment = SurveyAssignment(
        id: 'as1',
        surveyId: 'wave_2026',
        userId: 'u1',
        surveyTitle: 'CHED GTS 2026',
        status: SurveyAssignmentStatus.completed,
        assignedAt: now.subtract(const Duration(days: 7)),
      );

      final participant = SurveyParticipant(
        assignment: assignment,
        displayName: 'Juan Dela Cruz',
        email: 'juan.delacruz@alumni.ustp.edu.ph',
        program: 'BSIT',
        batchYear: '2024',
        studentId: '2020-0001',
      );

      final response = SurveyResponse(
        surveyId: 'wave_2026',
        userId: 'u1',
        status: SurveyResponseStatus.submitted,
        submittedAt: now,
        updatedAt: now,
        answers: {
          'ched_16': 'Yes',
          'ched_24a': 'Yes',
        },
      );

      final bytes = await SurveySingleResponseExportService.toPdf(
        survey: wave2,
        participant: participant,
        response: response,
        questions: const [],
      );
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1500));

      final text = _extractText(bytes);
      expect(text, contains('Individual Survey Response'));
      expect(text, contains('Juan Dela Cruz'));
      expect(text, contains('BSIT'));
      expect(text, contains('RA 10173'));

      File('output/pdf/sample_single_response_redesigned.pdf')
          .writeAsBytesSync(bytes);
    });

    test('Survey Formal Report PDF renders with narrative headings and disclaimer', () async {
      final bytes = await SurveyFormalReportService.toPdf(
        surveyTitle: 'Annual Tracer Study 2026',
        body: '''Executive Summary
The Annual Tracer Study 2026 shows strong labor market outcomes for USTP graduates.

Key Findings
The majority of graduates found employment within 6 months.

Implications
Findings support the continued enhancement of technical curriculum components.
''',
        disclaimer: 'Official university documentation draft - review prior to external dissemination.',
        generatedAt: now,
        usedAi: false,
      );
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1500));

      final text = _extractText(bytes);
      expect(text, contains('Formal Survey Report'));
      expect(text, contains('Executive Summary'));
      expect(text, contains('Key Findings'));
      expect(text, contains('Implications'));
      expect(text, contains('Official university documentation draft'));

      File('output/pdf/sample_formal_survey_report_redesigned.pdf')
          .writeAsBytesSync(bytes);
    });

    test('GTS Analytics Report PDF renders with cross-tabulation and notes', () async {
      final respondents = [
        for (var i = 0; i < 15; i++)
          GtsRespondent(
            userId: 'u$i',
            surveyId: 'wave_2026',
            course: 'BSIT',
            yearGraduated: '2026',
            onActiveRoster: true,
            answers: {'ched_16': i < 12 ? 'Yes' : 'No'},
          ),
      ];

      final result = GtsReportEngine.run(
        const GtsReportConfig(
          title: 'Employment Rate by Batch',
          surveyIds: ['wave_2026'],
          measure: 'ched_16',
          groupBy: ['year_graduated'],
          filters: [],
        ),
        respondents,
        waveLabels: {'wave_2026': 'Wave 2026'},
        now: now,
      );

      final bytes = await GtsReportExportService.exportBytes(
        result,
        CustomReportFormat.pdf,
      );
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1500));

      final text = _extractText(bytes);
      expect(text, contains('Employment Rate by Batch'));
      expect(text, contains('80.0'));

      File('output/pdf/sample_gts_analytics_report_redesigned.pdf')
          .writeAsBytesSync(bytes);
    });

    test('GTS Alumni List PDF renders in landscape with confidential badge and privacy footer', () async {
      final roster = [
        AlumniMember(
          id: 'm1',
          fullName: 'Juan Dela Cruz',
          course: 'BSIT',
          studentId: '2020-0001',
          batchYear: '2024',
          authUid: 'u1',
          isRegisteredUser: true,
        ),
      ];

      final responses = [
        GtsListResponse(
          userId: 'u1',
          surveyId: 'wave_2026',
          responseId: 'r1',
          submittedAt: now,
          answers: {
            'ched_16': 'Yes',
            'ched_19': 'Software Engineer',
          },
        ),
      ];

      final listResult = GtsAlumniList.build(
        const GtsListConfig(
          surveyId: 'wave_2026',
          columns: ['year_graduated', 'name', 'course', 'ched_16', 'ched_19'],
        ),
        roster: roster,
        responses: responses,
        waveIds: const ['wave_2026'],
        waveLabels: const {'wave_2026': 'CHED GTS 2026'},
        now: now,
      );

      final bytes = await GtsListExportService.exportBytes(
        listResult,
        CustomReportFormat.pdf,
      );
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1500));

      expect(
        latin1.decode(bytes),
        matches(RegExp(r'/MediaBox\s*\[\s*0\s+0\s+841\.8')),
      );

      final text = _extractText(bytes);
      expect(text, contains('Juan Dela Cruz'));
      expect(text, contains('Software Engineer'));
      expect(text, contains('CONFIDENTIAL'));
      expect(text, contains('RA 10173'));

      File('output/pdf/sample_gts_alumni_list_redesigned.pdf')
          .writeAsBytesSync(bytes);
    });
  });
}
