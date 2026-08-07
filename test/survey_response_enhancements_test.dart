import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alumni_system/core/utils/client_context.dart';
import 'package:alumni_system/features/surveys/data/survey_answer_display.dart';
import 'package:alumni_system/features/surveys/data/survey_single_response_export_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

void main() {
  group('client context normalization', () {
    test('normalizeSurveyDeviceCategory maps known values', () {
      expect(normalizeSurveyDeviceCategory('mobile'), 'mobile');
      expect(normalizeSurveyDeviceCategory('TABLET'), 'tablet');
      expect(normalizeSurveyDeviceCategory('unknown'), 'other');
      expect(normalizeSurveyDeviceCategory(null), 'other');
    });

    test('normalizeSurveyPlatformFamily maps known values', () {
      expect(normalizeSurveyPlatformFamily('web'), 'web');
      expect(normalizeSurveyPlatformFamily('darwin'), 'other');
      expect(normalizeSurveyPlatformFamily('macos'), 'macos');
    });

    test('normalizeSurveyBrowserFamily maps known values', () {
      expect(normalizeSurveyBrowserFamily('chrome'), 'chrome');
      expect(normalizeSurveyBrowserFamily('native'), 'native');
      expect(normalizeSurveyBrowserFamily('brave'), 'other');
    });

    test('SurveyClientContext captures native platform on IO', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final ctx = SurveyClientContext.capture();
      expect(ctx.platformFamily, 'android');
      expect(ctx.browserFamily, 'native');
      expect(ctx.deviceCategory, 'mobile');
    });
  });

  group('SurveyResponseEvent parsing', () {
    test('parseEventType handles snake_case draft_saved', () {
      expect(
        SurveyResponseEvent.parseEventType('draft_saved'),
        SurveyResponseEventType.draftSaved,
      );
      expect(
        SurveyResponseEvent.parseEventType('submitted'),
        SurveyResponseEventType.submitted,
      );
    });

    test('fromSupabaseRow reads lifecycle fields', () {
      final event = SurveyResponseEvent.fromSupabaseRow({
        'id': 'evt-1',
        'survey_id': 'survey-1',
        'user_id': 'user-1',
        'event_type': 'opened',
        'device_category': 'desktop',
        'platform_family': 'web',
        'browser_family': 'chrome',
        'created_at': '2026-07-21T10:00:00Z',
      });
      expect(event.eventType, SurveyResponseEventType.opened);
      expect(event.deviceCategory, 'desktop');
      expect(event.platformFamily, 'web');
      expect(event.browserFamily, 'chrome');
    });
  });

  group('SurveyResponse device summary', () {
    test('deviceSummary joins coarse metadata', () {
      final response = SurveyResponse(
        surveyId: 's1',
        userId: 'u1',
        answers: const {},
        status: SurveyResponseStatus.submitted,
        updatedAt: DateTime(2026, 7, 21),
        deviceCategory: 'desktop',
        platformFamily: 'web',
        browserFamily: 'chrome',
      );
      expect(response.deviceSummary, 'Desktop · Web · Chrome');
    });
  });

  group('survey answer display formatting', () {
    test('scalar and list values render plainly', () {
      expect(formatSurveyAnswerValue('Engineer'), 'Engineer');
      expect(formatSurveyAnswerValue(['A', 'B']), 'A, B');
      expect(formatSurveyAnswerValue(null), '');
      expect(formatSurveyAnswerValue('   '), '');
    });

    test('multi-field map renders as labeled lines', () {
      final text = formatSurveyAnswerValue({
        'Year Graduated': '2027',
        'Degree(s) & Specialization(s)': 'BSIT',
        'Honor(s) or Award(s) Received': '',
      });
      expect(text, 'Year Graduated: 2027\nDegree(s) & Specialization(s): BSIT');
    });

    test('matrix map shows only checked rows with columns', () {
      final text = formatSurveyAnswerValue({
        'Peer Influence': {'Undergraduate/AB/BS': true},
        'Good grades in high school': {'Undergraduate/AB/BS': false},
      });
      expect(text, 'Peer Influence (Undergraduate/AB/BS)');
    });

    test('empty maps count as unanswered', () {
      expect(isSurveyAnswerEmpty({}), isTrue);
      expect(
        isSurveyAnswerEmpty({
          'Row': {'Col': false},
        }),
        isTrue,
      );
      expect(isSurveyAnswerEmpty({'Field': 'value'}), isFalse);
    });
  });

  group('single-response export rows', () {
    test('classic survey rows respect section labels', () {
      final survey = Survey(
        id: 's1',
        title: 'Sample',
        description: '',
        status: SurveyStatus.published,
        createdBy: 'admin',
        createdAt: DateTime(2026),
      );
      final questions = [
        SurveyQuestion(
          id: 'q1',
          surveyId: 's1',
          order: 1,
          type: SurveyQuestionType.text,
          prompt: 'What is your current role?',
          section: 'D',
        ),
      ];
      final response = SurveyResponse(
        surveyId: 's1',
        userId: 'u1',
        answers: {'q1': 'Engineer'},
        status: SurveyResponseStatus.submitted,
        updatedAt: DateTime(2026, 7, 21),
      );
      final participant = SurveyParticipant(
        assignment: SurveyAssignment(
          id: 'a1',
          surveyId: 's1',
          userId: 'u1',
          surveyTitle: 'Sample',
          status: SurveyAssignmentStatus.completed,
          assignedAt: DateTime(2026, 7, 1),
        ),
        displayName: 'Jane Doe',
        email: 'jane@example.com',
        program: 'BSIT',
        batchYear: '2020',
        studentId: '2020-001',
      );

      final rows = SurveySingleResponseExportService.buildAnswerRows(
        survey: survey,
        response: response,
        questions: questions,
        participant: participant,
      );

      expect(rows, hasLength(1));
      expect(rows.first.question, 'What is your current role?');
      expect(rows.first.answer, 'Engineer');
      expect(rows.first.section, contains('Employment'));
    });

    test('excel export includes metadata and answers sheets', () {
      final survey = Survey(
        id: 's1',
        title: 'Sample',
        description: '',
        status: SurveyStatus.published,
        createdBy: 'admin',
        createdAt: DateTime(2026),
      );
      final response = SurveyResponse(
        surveyId: 's1',
        userId: 'u1',
        answers: {'q1': 'Yes'},
        status: SurveyResponseStatus.submitted,
        updatedAt: DateTime(2026, 7, 21),
        submittedAt: DateTime(2026, 7, 21, 12),
      );
      final participant = SurveyParticipant(
        assignment: SurveyAssignment(
          id: 'a1',
          surveyId: 's1',
          userId: 'u1',
          surveyTitle: 'Sample',
          status: SurveyAssignmentStatus.completed,
          assignedAt: DateTime(2026, 7, 1),
        ),
        displayName: 'Jane Doe',
        email: 'jane@example.com',
        program: 'BSIT',
        batchYear: '2020',
        studentId: '2020-001',
      );
      final questions = [
        SurveyQuestion(
          id: 'q1',
          surveyId: 's1',
          order: 1,
          type: SurveyQuestionType.text,
          prompt: 'Employed?',
        ),
      ];

      final bytes = SurveySingleResponseExportService.toExcel(
        survey: survey,
        response: response,
        questions: questions,
        participant: participant,
      );

      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(100));
    });
  });
}
