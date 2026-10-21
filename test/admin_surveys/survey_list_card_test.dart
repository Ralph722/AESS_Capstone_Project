import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Survey _survey({
  String title = 'Alumni Homecoming Feedback',
  SurveyStatus status = SurveyStatus.published,
  DateTime? openAt,
  DateTime? closeAt,
  int assigned = 120,
  int submitted = 3,
  bool archived = false,
  String? kind,
}) {
  return Survey(
    id: 's1',
    title: title,
    description: '',
    status: status,
    openAt: openAt,
    closeAt: closeAt,
    createdBy: 'admin',
    createdAt: DateTime(2026, 10, 1),
    assignmentCount: assigned,
    responseCount: submitted,
    archived: archived,
    kind: kind,
    schemaVersion: kind == null ? null : '3.0.0',
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  Survey survey, {
  double width = 1366,
  bool busy = false,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SurveyListCard(
            survey: survey,
            busy: busy,
            onMenuSelected: (_) {},
            menuItems: [
              surveyMenuItem(
                value: 'edit',
                label: 'Edit / publish',
                icon: Icons.edit_outlined,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  final past = DateTime.now().subtract(const Duration(days: 30));
  final pastEnd = DateTime.now().subtract(const Duration(days: 20));
  final future = DateTime.now().add(const Duration(days: 20));
  final futureEnd = DateTime.now().add(const Duration(days: 30));

  group('status wording', () {
    test('published past close reads "Window ended"', () {
      final s = _survey(openAt: past, closeAt: pastEnd);
      expect(surveyStatusText(s), 'Window ended');
    });

    test('published before open reads "Scheduled"', () {
      final s = _survey(openAt: future, closeAt: futureEnd);
      expect(surveyStatusText(s), 'Scheduled');
    });

    test('published inside window, draft, closed, archived', () {
      expect(surveyStatusText(_survey(openAt: past, closeAt: futureEnd)),
          'Published');
      expect(surveyStatusText(_survey(status: SurveyStatus.draft)), 'Draft');
      expect(surveyStatusText(_survey(status: SurveyStatus.closed)), 'Closed');
      expect(surveyStatusText(_survey(archived: true)), 'Archived');
    });

    testWidgets('chip shows "Window ended" for a past window', (tester) async {
      await _pumpCard(tester, _survey(openAt: past, closeAt: pastEnd));
      expect(find.text('Window ended'), findsWidgets);
      expect(find.text('Scheduled'), findsNothing);
    });

    testWidgets('chip shows "Scheduled" before the open date', (tester) async {
      await _pumpCard(tester, _survey(openAt: future, closeAt: futureEnd));
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Not yet open'), findsOneWidget);
    });
  });

  group('helpers', () {
    test('response rate is submitted ÷ assigned, null without assignments', () {
      expect(surveyResponseRate(_survey(assigned: 120, submitted: 3)), 3);
      expect(surveyResponseRate(_survey(assigned: 4, submitted: 1)), 25);
      expect(surveyResponseRate(_survey(assigned: 0, submitted: 0)), isNull);
    });

    test('window text covers both dates, one date and none', () {
      final s = _survey(
        openAt: DateTime(2026, 8, 7),
        closeAt: DateTime(2026, 8, 14),
      );
      expect(surveyWindowText(s), 'Aug 7 – Aug 14, 2026');
      expect(
        surveyWindowText(_survey(openAt: DateTime(2026, 8, 7))),
        'Opens Aug 7, 2026',
      );
      expect(surveyWindowText(_survey()), isNull);
    });

    test('identity text names the survey', () {
      final s = _survey(status: SurveyStatus.draft);
      expect(
        surveyIdentityText(s),
        '“Alumni Homecoming Feedback” · Draft · Created Oct 1, 2026',
      );
    });
  });

  group('card', () {
    testWidgets('wide layout shows responses and window zones', (tester) async {
      await _pumpCard(tester, _survey());
      expect(find.text('RESPONSES'), findsOneWidget);
      expect(find.text('WINDOW'), findsOneWidget);
      expect(find.text('No window set'), findsOneWidget);
      expect(find.textContaining('3 of 120'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('no assignments reads "Not assigned yet"', (tester) async {
      await _pumpCard(tester, _survey(assigned: 0, submitted: 0));
      expect(find.text('Not assigned yet'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('narrow layout keeps the full meta line', (tester) async {
      await _pumpCard(tester, _survey(), width: 768);
      expect(find.text('RESPONSES'), findsNothing);
      expect(
        find.text('120 assigned · 3 submitted (3%) · Created Oct 1, 2026'),
        findsOneWidget,
      );
    });

    testWidgets('official CHED shows kind chip with version', (tester) async {
      await _pumpCard(tester, _survey(kind: 'ched_gts_builtin'));
      expect(find.text('Official CHED · v3.0.0'), findsOneWidget);
    });

    testWidgets('busy replaces the menu with a spinner', (tester) async {
      await _pumpCard(tester, _survey(), busy: true);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('menu tooltip names the survey', (tester) async {
      await _pumpCard(tester, _survey());
      expect(
        find.byTooltip('Actions for Alumni Homecoming Feedback'),
        findsOneWidget,
      );
    });

    for (final width in [768.0, 1366.0, 1920.0]) {
      testWidgets('no overflow with a long title at $width', (tester) async {
        await _pumpCard(
          tester,
          _survey(
            title: 'CHED Graduate Tracer Survey (GTS) ' * 6,
            kind: 'ched_gts_builtin',
            openAt: past,
            closeAt: pastEnd,
          ),
          width: width,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('menu item', () {
    testWidgets('disabled item shows its note and cannot be tapped',
        (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopupMenuButton<String>(
              onSelected: (v) => selected = v,
              itemBuilder: (_) => [
                surveyMenuItem(
                  value: 'delete',
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  destructive: true,
                  enabled: false,
                  note: 'Has responses — archive instead',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Has responses — archive instead'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    });
  });
}
