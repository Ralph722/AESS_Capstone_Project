import 'package:alumni_system/features/admin/surveys/presentation/admin_survey_editor_page.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/admin/surveys/widgets/survey_question_editor.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SurveyQuestion _q(
  String id, {
  String prompt = 'How did you hear about the event?',
  SurveyQuestionType type = SurveyQuestionType.text,
  List<String> options = const [],
}) {
  return SurveyQuestion(
    id: id,
    surveyId: 's1',
    order: 0,
    type: type,
    prompt: prompt,
    required: true,
    options: options,
  );
}

Future<void> _pumpAt(WidgetTester tester, double width, Widget child) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('publish problems', () {
    test('no questions blocks publishing', () {
      final problems = surveyPublishProblems(const []);
      expect(problems, hasLength(1));
      expect(problems.single.message, 'Add at least one question');
      expect(problems.single.questionIndex, isNull);
    });

    test('lists empty prompts and choices with fewer than 2 options', () {
      final problems = surveyPublishProblems([
        _q('a'),
        _q('b', prompt: '  '),
        _q(
          'c',
          type: SurveyQuestionType.singleChoice,
          options: const ['Yes', ' '],
        ),
        _q('d', type: SurveyQuestionType.scale),
      ]);
      expect(problems.map((p) => p.message), [
        'Question 2 — Add question text',
        'Question 3 — Add at least 2 options',
      ]);
      expect(problems.map((p) => p.questionIndex), [1, 2]);
    });

    test('complete questions pass', () {
      expect(
        surveyPublishProblems([
          _q('a'),
          _q(
            'b',
            type: SurveyQuestionType.multipleChoice,
            options: const ['A', 'B'],
          ),
        ]),
        isEmpty,
      );
    });
  });

  group('batch years unsaved check', () {
    test('saved range tokens are not a change', () {
      expect(surveyBatchInputChanged('2020-2027', const ['2020-2027']), isFalse);
    });

    test('expanded years shown as a range are not a change', () {
      final years = [for (var y = 2020; y <= 2027; y++) '$y'];
      expect(surveyBatchInputChanged('2020-2027', years), isFalse);
      expect(surveyBatchInputChanged('2020 - 2027', years), isFalse);
    });

    test('different, empty or invalid input is a change', () {
      expect(surveyBatchInputChanged('2020-2026', const ['2020-2027']), isTrue);
      expect(surveyBatchInputChanged('', const ['2024']), isTrue);
      expect(surveyBatchInputChanged('2020-', const ['2020']), isTrue);
    });

    test('empty stays empty', () {
      expect(surveyBatchInputChanged('  ', const []), isFalse);
    });
  });

  group('friendly errors', () {
    test('strips the Exception prefix from service messages', () {
      expect(
        surveyFriendlyError(Exception('Survey is closed'), 'fallback'),
        'Survey is closed',
      );
    });

    test('falls back for technical or long text', () {
      expect(surveyFriendlyError('Error 500', 'fallback'), 'fallback');
      expect(surveyFriendlyError('x' * 200, 'fallback'), 'fallback');
    });
  });

  group('editor header', () {
    for (final width in [768.0, 1366.0, 1920.0]) {
      testWidgets('long title with chips fits at $width', (tester) async {
        await _pumpAt(
          tester,
          width,
          SurveyInlinePanelHeader(
            title: 'CHED Graduate Tracer Survey (GTS) — Batch 2020 to 2025 '
                'follow-up wave for all programs',
            subtitle: 'Aug 7 – Aug 14, 2026',
            chips: [
              SurveyStatusChip.fromSurvey(
                Survey(
                  id: 's1',
                  title: 't',
                  description: '',
                  status: SurveyStatus.draft,
                  createdBy: 'admin',
                  createdAt: DateTime(2026, 10, 1),
                ),
              ),
              const SurveyKindChip(kind: SurveyKindLabel.custom),
            ],
            onClose: () {},
            actions: [
              TextButton(onPressed: () {}, child: const Text('Hide preview')),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Draft'), findsOneWidget);
      });
    }

    testWidgets('busy back shows a spinner and is disabled', (tester) async {
      var closed = false;
      await _pumpAt(
        tester,
        1366,
        SurveyInlinePanelHeader(
          title: 'Survey',
          subtitle: '',
          backBusy: true,
          onClose: () => closed = true,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      expect(closed, isFalse);
    });
  });

  group('action bar', () {
    Widget bar(double paneWidth) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: paneWidth,
        child: SurveyStickyActionBar(
          constrainWidth: false,
          leading: const Text('All changes saved · questions save automatically'),
          children: [
            OutlinedButton(onPressed: () {}, child: const Text('Save details')),
            FilledButton(onPressed: () {}, child: const Text('Publish')),
          ],
        ),
      ),
    );

    testWidgets('one row in the 1366 edit pane (≈ 576 px)', (tester) async {
      await _pumpAt(tester, 1366, bar(576));
      expect(tester.takeException(), isNull);
      final save = tester.getCenter(find.text('Save details'));
      final publish = tester.getCenter(find.text('Publish'));
      expect(save.dy, publish.dy);
    });

    testWidgets('stacks below 440 px', (tester) async {
      await _pumpAt(tester, 768, bar(400));
      expect(tester.takeException(), isNull);
      final save = tester.getCenter(find.text('Save details'));
      final publish = tester.getCenter(find.text('Publish'));
      expect(publish.dy, greaterThan(save.dy));
    });
  });

  testWidgets('expanded question card shows the footer actions', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      420,
      SingleChildScrollView(
        child: SurveyQuestionEditorCard(
          question: _q('a', prompt: ''),
          index: 0,
          expanded: true,
          isSaving: false,
          canMoveUp: false,
          canMoveDown: true,
          onToggleExpand: () {},
          onChanged: (_) {},
          onDuplicate: () {},
          onDelete: () {},
          onMoveUp: () {},
          onMoveDown: () {},
          onVisibilityRuleChanged: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Add question text'), findsOneWidget);
    expect(find.byTooltip('Move down'), findsOneWidget);
  });

  for (final width in [768.0, 1366.0]) {
    testWidgets('editor skeleton lays out at $width', (tester) async {
      await _pumpAt(tester, width, const SurveyEditorSkeleton());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  }
}
