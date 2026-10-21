import 'package:alumni_system/features/admin/surveys/presentation/admin_survey_responses_page.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_export_dialog.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_formal_report_dialog.dart';
import 'package:alumni_system/features/surveys/data/survey_formal_report_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpLauncher(
  WidgetTester tester,
  double width,
  void Function(BuildContext context) onOpen,
) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onOpen(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

ButtonStyleButton _downloadButton(WidgetTester tester) {
  return tester.widget<ButtonStyleButton>(
    find.ancestor(
      of: find.text('Download'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ),
  );
}

final _survey = Survey(
  id: 's1',
  title: 'Tracer 2026',
  description: '',
  status: SurveyStatus.published,
  createdBy: 'admin',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('export error text', () {
    test('keeps a readable reason', () {
      expect(
        surveyExportErrorMessage(
          'the pending list',
          Exception('No internet connection'),
        ),
        'Couldn’t create the pending list. No internet connection',
      );
    });

    test('hides programming errors and technical text', () {
      expect(
        surveyExportErrorMessage(
          'the responses Excel file',
          StateError('Excel encode returned null'),
        ),
        'Couldn’t create the responses Excel file. Try again.',
      );
      expect(
        surveyExportErrorMessage(
          'the CHED GTS Excel pack',
          Exception('PostgrestException(message: boom)'),
        ),
        'Couldn’t create the CHED GTS Excel pack. Try again.',
      );
    });
  });

  group('export dialog', () {
    for (final width in [768.0, 1366.0]) {
      testWidgets('every report has details; blocked ones say why at $width',
          (tester) async {
        await _pumpLauncher(
          tester,
          width,
          (context) => showAdminSurveyExportDialog(
            context: context,
            hasSubmitted: false,
            isChedGts: true,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Details'), findsNWidgets(6));
        expect(find.text('Needs submitted responses'), findsNWidgets(4));
        expect(_downloadButton(tester).onPressed, isNull);

        final pending = find.text('Pending list');
        await tester.ensureVisible(pending);
        await tester.pumpAndSettle();
        await tester.tap(pending);
        await tester.pumpAndSettle();
        expect(_downloadButton(tester).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('details open for the selected report', (tester) async {
      await _pumpLauncher(
        tester,
        1366,
        (context) => showAdminSurveyExportDialog(
          context: context,
          hasSubmitted: true,
          isChedGts: false,
        ),
      );
      await tester.tap(find.byTooltip('Details').first);
      await tester.pumpAndSettle();
      expect(find.text('What it is'), findsOneWidget);
    });

    testWidgets('cohort filters fit at 768', (tester) async {
      await _pumpLauncher(
        tester,
        768,
        (context) => showAdminSurveyExportDialog(
          context: context,
          hasSubmitted: true,
          isChedGts: true,
          showCohortFilters: true,
          batchOptions: const ['2020', '2021'],
          courseOptions: const ['BS Information Technology'],
        ),
      );
      expect(tester.takeException(), isNull);
      final step = find.text('3. How do you want it?');
      await tester.ensureVisible(step);
      await tester.pumpAndSettle();
      expect(step, findsOneWidget);
      expect(_downloadButton(tester).onPressed, isNotNull);
    });
  });

  group('formal report dialog', () {
    late int generated;
    late Object? failWith;

    Future<SurveyFormalReportResult> generate() async {
      generated++;
      final error = failWith;
      if (error != null) throw error;
      return SurveyFormalReportResult(
        body: 'Draft text',
        usedAi: false,
        generatedAt: DateTime(2026, 10, 15),
      );
    }

    Future<void> open(WidgetTester tester, {double width = 1366}) {
      return _pumpLauncher(
        tester,
        width,
        (context) => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => surveyFormalReportDialogForTest(
            survey: _survey,
            generate: generate,
          ),
        ),
      );
    }

    setUp(() {
      generated = 0;
      failWith = null;
    });

    testWidgets('closes without a prompt when nothing was edited',
        (tester) async {
      await open(tester);
      expect(find.text('Formal survey report'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard your edits?'), findsNothing);
      expect(find.text('Formal survey report'), findsNothing);
    });

    testWidgets('asks before closing with edits', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'Draft text, edited');
      await tester.pump();

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard your edits?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Formal survey report'), findsOneWidget);
      expect(find.text('Draft text, edited'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Formal survey report'), findsNothing);
    });

    testWidgets('asks before regenerating over edits', (tester) async {
      await open(tester, width: 768);
      await tester.enterText(find.byType(TextField), 'My own wording');
      await tester.pump();

      await tester.tap(find.text('Regenerate'));
      await tester.pumpAndSettle();
      expect(find.text('Discard your edits?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Regenerate'));
      await tester.pumpAndSettle();
      expect(generated, 2);
      expect(find.text('Draft text'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('generation error shows a retryable state', (tester) async {
      failWith = Exception('The AI service is busy right now');
      await open(tester);
      expect(find.text('Couldn’t write the report'), findsOneWidget);
      expect(find.text('The AI service is busy right now'), findsOneWidget);

      failWith = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(generated, 2);
      expect(find.text('Draft text'), findsOneWidget);
    });
  });
}
