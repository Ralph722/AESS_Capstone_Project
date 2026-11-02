import 'package:flutter_test/flutter_test.dart';

import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/data/survey_response_export_columns.dart';
import 'package:alumni_system/features/surveys/data/survey_submitted_responses_export.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

Survey _survey({
  required String id,
  required bool ched,
  String title = 'Wave',
}) {
  final now = DateTime(2026, 1, 1);
  return Survey(
    id: id,
    title: title,
    description: '',
    status: SurveyStatus.published,
    createdBy: 'admin',
    createdAt: now,
    updatedAt: now,
    kind: ched ? ChedGtsBuiltin.kind : 'classic',
    templateKey: ched ? ChedGtsBuiltin.templateKey : null,
  );
}

SurveyParticipant _participant({
  required String name,
  required Map<String, dynamic> answers,
}) {
  final now = DateTime(2026, 2, 1);
  return SurveyParticipant(
    assignment: SurveyAssignment(
      id: 'a1',
      surveyId: 's1',
      userId: 'u1',
      surveyTitle: 'Wave',
      status: SurveyAssignmentStatus.completed,
      assignedAt: now,
    ),
    displayName: name,
    email: 'a@example.com',
    program: 'BSIT',
    batchYear: '2024',
    response: SurveyResponse(
      surveyId: 's1',
      userId: 'u1',
      status: SurveyResponseStatus.submitted,
      answers: answers,
      submittedAt: now,
      updatedAt: now,
    ),
  );
}

void main() {
  group('SurveyResponseExportColumns', () {
    test('Official CHED uses builtin ched_* columns when questions are empty',
        () {
      final columns = SurveyResponseExportColumns.forSurvey(
        survey: _survey(id: 's1', ched: true),
        questions: const [],
      );
      expect(columns, isNotEmpty);
      expect(columns.first.id, ChedGtsBuiltin.items.first.id);
      expect(columns.any((c) => c.id == 'ched_16'), isTrue);
      expect(columns.any((c) => c.header.contains('16')), isTrue);
    });

    test('classic surveys keep survey_questions columns', () {
      const q = SurveyQuestion(
        id: 'q1',
        surveyId: 's1',
        order: 0,
        type: SurveyQuestionType.singleChoice,
        prompt: 'Favourite colour?',
      );
      final columns = SurveyResponseExportColumns.forSurvey(
        survey: _survey(id: 's1', ched: false),
        questions: const [q],
      );
      expect(columns, hasLength(1));
      expect(columns.single.id, 'q1');
      expect(columns.single.header, 'Favourite colour?');
    });
  });

  group('SurveySubmittedResponsesExport', () {
    test('CSV includes CHED answers for builtin waves', () {
      final csv = SurveySubmittedResponsesExport.buildCsv(
        survey: _survey(id: 's1', ched: true, title: 'CHED 2026'),
        questions: const [],
        participants: [
          _participant(
            name: 'Ada Lovelace',
            answers: {
              'ched_16': ChedGtsBuiltin.yes,
              'ched_19': 'Engineer',
            },
          ),
        ],
      );
      expect(csv, contains('Ada Lovelace'));
      expect(csv, contains('Yes'));
      expect(csv, contains('Engineer'));
      expect(csv, contains('[16]'));
      expect(csv, contains('[19]'));
    });

    test('Excel bytes are a non-empty workbook for CHED answers', () {
      final bytes = SurveySubmittedResponsesExport.buildExcelBytes(
        survey: _survey(id: 's1', ched: true),
        questions: const [],
        participants: [
          _participant(
            name: 'Grace Hopper',
            answers: {'ched_16': ChedGtsBuiltin.yes},
          ),
        ],
      );
      expect(bytes.length, greaterThan(100));
      expect(String.fromCharCodes(bytes.take(2)), 'PK'); // zip/xlsx
    });
  });
}
