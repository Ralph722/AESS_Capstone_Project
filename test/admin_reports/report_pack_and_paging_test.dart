import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/core/utils/supabase_paging.dart';
import 'package:alumni_system/features/admin/reports/application/admin_reports_analytics.dart';
import 'package:alumni_system/features/surveys/data/survey_report_analytics.dart';
import 'package:alumni_system/features/surveys/data/survey_report_pack_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/models/survey_reports_aggregate.dart';

void main() {
  group('fetchAllPages', () {
    Future<List<Map<String, dynamic>>> Function(int, int) source(
      int total, {
      int serverCap = 1000,
    }) {
      final rows = [
        for (var i = 0; i < total; i++) <String, dynamic>{'id': i},
      ];
      return (from, to) async {
        if (from >= rows.length) return const [];
        final end = [
          to + 1,
          rows.length,
          from + serverCap,
        ].reduce((a, b) => a < b ? a : b);
        return rows.sublist(from, end);
      };
    }

    test('reads past the page size', () async {
      final rows = await fetchAllPages(source(2500));
      expect(rows.length, 2500);
      expect(rows.last['id'], 2499);
    });

    test(
      'still reads everything when the server caps below the page size',
      () async {
        final rows = await fetchAllPages(source(1200, serverCap: 500));
        expect(rows.length, 1200);
        expect(rows.map((r) => r['id']).toSet().length, 1200);
      },
    );

    test('handles an empty result', () async {
      expect(await fetchAllPages(source(0)), isEmpty);
    });
  });

  group('CHED portfolio pack', () {
    final ched = Survey(
      id: 'w1',
      title: 'CHED GTS 2026',
      description: '',
      status: SurveyStatus.published,
      createdBy: 'admin',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      templateKey: 'ched_gts_builtin',
      assignmentCount: 2,
      responseCount: 2,
    );

    SurveyResponse response(String uid, Map<String, dynamic> answers) =>
        SurveyResponse(
          surveyId: ched.id,
          userId: uid,
          answers: answers,
          status: SurveyResponseStatus.submitted,
          updatedAt: DateTime(2026, 2, 1),
        );

    final rollup = SurveyReportRollup(
      survey: ched,
      aggregates: SurveyReportAnalytics.aggregateChedResponses(
        responses: [
          response('u1', {
            'ched_16': 'Yes',
            'ched_22': 'Yes',
            'ched_24a': 'Yes',
            'ched_32': 'Yes',
            'ched_33': ['Communication skills', 'Problem-solving skills'],
          }),
          response('u2', {
            'ched_16': 'No',
            'ched_17': ['Family concern and decided not to find a job'],
          }),
        ],
      ),
    );

    final analytics = AdminReportsAnalytics(
      members: const [],
      employmentRecords: const [],
      surveys: [ched],
      announcements: const [],
      forumTopics: const [],
      portalUserCount: 0,
    );

    test('includes every CHED choice item, not only the first 12', () {
      final pack = SurveyReportPackService.buildPortfolioPack(
        analytics: analytics,
        rollups: [rollup],
      );
      expect(rollup.aggregates.length, greaterThan(12));
      expect(pack.questionRows.length, rollup.aggregates.length);
      expect(
        pack.questionRows.map((q) => q.prompt.split('.').first),
        containsAll(['24', '29', '31', '32', '33']),
      );
    });

    test('details show counts with shares of answered', () {
      final pack = SurveyReportPackService.buildPortfolioPack(
        analytics: analytics,
        rollups: [rollup],
      );
      final q16 = pack.questionRows.firstWhere(
        (q) => q.prompt.startsWith('16.'),
      );
      expect(q16.detail, 'Yes: 1 (50%); No: 1 (50%)');

      final q33 = pack.questionRows.firstWhere(
        (q) => q.prompt.startsWith('33.'),
      );
      expect(q33.detail, contains('Communication skills: 1 (100%)'));
      expect(q33.detail, contains('can total over 100%'));
    });

    test('does not flag CHED skip-logic items as high-skip questions', () {
      final pack = SurveyReportPackService.buildPortfolioPack(
        analytics: analytics,
        rollups: [rollup],
      );
      expect(
        pack.insights.any((i) => i.startsWith('Highest skip rate')),
        isFalse,
      );
      expect(pack.recommendations.any((r) => r.contains('high-skip')), isFalse);
    });
  });
}
