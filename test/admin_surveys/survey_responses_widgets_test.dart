import 'package:alumni_system/features/admin/surveys/presentation/admin_survey_responses_page.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_response_detail_sheet.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_form.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpAt(WidgetTester tester, double width, Widget child) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

Survey _survey({
  SurveyStatus status = SurveyStatus.published,
  DateTime? openAt,
  DateTime? closeAt,
}) {
  return Survey(
    id: 's1',
    title: 'CHED Graduate Tracer Survey (GTS) — Batch 2020 to 2025 '
        'follow-up wave for all programs',
    description: '',
    status: status,
    createdBy: 'admin',
    createdAt: DateTime(2020, 7, 1),
    openAt: openAt,
    closeAt: closeAt,
  );
}

SurveyQuestion _question(String id, String prompt, int order) {
  return SurveyQuestion(
    id: id,
    surveyId: 's1',
    order: order,
    type: SurveyQuestionType.text,
    prompt: prompt,
  );
}

SurveyResponse _response(
  Map<String, dynamic> answers, {
  DateTime? submittedAt,
  String? deviceCategory,
}) {
  return SurveyResponse(
    surveyId: 's1',
    userId: 'u1',
    answers: answers,
    status: SurveyResponseStatus.submitted,
    submittedAt: submittedAt,
    updatedAt: DateTime(2026, 9, 30),
    deviceCategory: deviceCategory,
  );
}

SurveyParticipant _participant({String program = '', String batch = ''}) {
  return SurveyParticipant(
    assignment: SurveyAssignment(
      id: 'a1',
      surveyId: 's1',
      userId: 'u1',
      surveyTitle: 'Tracer',
      status: SurveyAssignmentStatus.completed,
      assignedAt: DateTime(2026, 9, 1),
    ),
    displayName: 'Ana Cruz',
    email: 'ana@example.com',
    program: program,
    batchYear: batch,
  );
}

Future<void> _openDetail(
  WidgetTester tester,
  double width, {
  required SurveyResponse response,
  required bool isChedBuiltin,
  List<SurveyQuestion> questions = const [],
  Map<String, SurveyVisibilityRule> rules = const {},
}) async {
  await _pumpAt(
    tester,
    width,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => showAdminSurveyResponseDetailSheet(
          context: context,
          alumniName: 'Ana Cruz',
          subtitle: 'BSIT · Batch 2020',
          response: response,
          isChedBuiltin: isChedBuiltin,
          questions: questions,
          visibilityRules: rules,
        ),
        child: const Text('open'),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

const _pendingColumnsCopy = <AdminDataColumn>[
  AdminDataColumn(label: 'NAME', flex: 3),
  AdminDataColumn(label: 'COURSE', flex: 2),
  AdminDataColumn(label: 'BATCH', width: 90),
  AdminDataColumn(label: 'STATUS', width: 120),
  AdminDataColumn(label: 'ASSIGNED', width: 130),
  AdminDataColumn(label: 'REMINDERS', width: 130),
];

Widget _pendingTable() {
  return AdminDataTable(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
    columns: _pendingColumnsCopy,
    leadingHeader: const Checkbox(value: false, onChanged: null),
    leadingWidth: 48,
    rowCount: 1,
    rowBuilder: (_, __) => AdminDataRow(
      columns: _pendingColumnsCopy,
      leading: const Checkbox(value: false, onChanged: null),
      leadingWidth: 48,
      cells: const [
        AdminTableIdentityCell(
          title: 'Maria Clara Dela Cruz Santos',
          subtitle: 'maria.santos@example.com',
          leading: CircleAvatar(radius: 16, child: Text('MS')),
        ),
        AdminTableTextCell('BS Information Technology'),
        AdminTableTextCell('2020'),
        AdminTableBadge(label: 'Not started'),
        AdminTableTextCell('Sep 1, 2026 · 44d'),
        AdminTableTextCell('2x · Oct 1, 2026'),
      ],
    ),
  );
}

const _submittedColumnsCopy = <AdminDataColumn>[
  AdminDataColumn(label: 'NAME', flex: 3),
  AdminDataColumn(label: 'COURSE', flex: 2),
  AdminDataColumn(label: 'BATCH', width: 90),
  AdminDataColumn(label: 'SUBMITTED', width: 150),
  AdminDataColumn(label: 'TIME TO SUBMIT', width: 116),
  AdminDataColumn(label: 'DEVICE', flex: 2),
  AdminDataColumn(label: 'STATUS', width: 100),
];

Widget _submittedTable() {
  return AdminDataTable(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
    columns: _submittedColumnsCopy,
    trailingHeader: const SizedBox.shrink(),
    trailingWidth: 44,
    rowCount: 1,
    rowBuilder: (_, __) => AdminDataRow(
      columns: _submittedColumnsCopy,
      trailingWidth: 44,
      trailing: const Icon(Icons.more_vert),
      cells: const [
        AdminTableIdentityCell(
          title: 'Maria Clara Dela Cruz Santos',
          subtitle: 'maria.santos@example.com',
          leading: CircleAvatar(radius: 16, child: Text('MS')),
        ),
        AdminTableTextCell('BS Information Technology'),
        AdminTableTextCell('2020'),
        AdminTableTextCell('Sep 30, 2026 10:42 PM'),
        Tooltip(
          message: 'Time from assignment to submission',
          child: AdminTableTextCell('29 days', muted: true),
        ),
        AdminTableTextCell('Desktop · Chrome'),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminTableBadge(label: 'Submitted'),
        ),
      ],
    ),
  );
}

void main() {
  group('responses table frame', () {
    // 672 ≈ table width at a 768 viewport (rail), 1070 at 1366; 480 is a
    // stress width.
    final tables = {'pending': _pendingTable, 'submitted': _submittedTable};
    for (final entry in tables.entries) {
      for (final width in [480.0, 672.0, 1070.0]) {
        testWidgets('${entry.key} row fits at $width', (tester) async {
          await _pumpAt(
            tester,
            width,
            SizedBox(
              height: 400,
              child: SurveyResponsesTableFrame(child: entry.value()),
            ),
          );
          expect(tester.takeException(), isNull);
          final scrolls = find.byWidgetPredicate(
            (w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
          );
          expect(scrolls, width < 720 ? findsOneWidget : findsNothing);
        });
      }
    }

    testWidgets('submitted row overflows at 672 without the frame',
        (tester) async {
      await _pumpAt(
        tester,
        672,
        SizedBox(height: 400, child: _submittedTable()),
      );
      expect(tester.takeException(), isNotNull);
    });
  });

  group('response meta line', () {
    test('course, batch, submitted date and device', () {
      expect(
        surveyResponseMetaLine(
          _participant(program: 'BSIT', batch: '2020'),
          _response(
            const {},
            submittedAt: DateTime(2026, 10, 3),
            deviceCategory: 'desktop',
          ),
        ),
        'BSIT · Batch 2020 · Submitted Oct 3, 2026 · Desktop',
      );
    });

    test('skips missing parts and falls back to last saved', () {
      expect(
        surveyResponseMetaLine(_participant(), _response(const {})),
        'Last saved Sep 30, 2026',
      );
    });
  });

  group('response detail panel', () {
    final questions = [
      _question('q1', 'Are you employed?', 1),
      _question('q2', 'Company name', 2),
      _question('q3', 'Any comments?', 3),
    ];
    const rules = {
      'q2': SurveyVisibilityRule(
        sourceQuestionId: 'q1',
        operator: SurveyVisibilityOperator.equals,
        value: 'Yes',
      ),
    };

    for (final width in [768.0, 1366.0]) {
      testWidgets('hidden questions are not unanswered at $width',
          (tester) async {
        await _openDetail(
          tester,
          width,
          response: _response(const {'q1': 'No'}),
          isChedBuiltin: false,
          questions: questions,
          rules: rules,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('BSIT · Batch 2020'), findsOneWidget);
        expect(find.text('Company name'), findsNothing);
        expect(find.text('Any comments?'), findsOneWidget);
        expect(find.text('1 unanswered in this section'), findsOneWidget);

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();
        expect(find.text('• Any comments?'), findsOneWidget);
        expect(find.text('• Company name'), findsNothing);
      });
    }

    testWidgets('shown question counts when its rule matches', (tester) async {
      await _openDetail(
        tester,
        1366,
        response: _response(const {'q1': 'Yes'}),
        isChedBuiltin: false,
        questions: questions,
        rules: rules,
      );
      expect(find.text('Company name'), findsOneWidget);
      expect(find.text('2 unanswered in this section'), findsOneWidget);
    });

    testWidgets('CHED official form stays behind the toggle', (tester) async {
      await _openDetail(
        tester,
        1366,
        response: _response(const {}),
        isChedBuiltin: true,
      );
      final show = find.text('Show official form');
      await tester.ensureVisible(show);
      await tester.pumpAndSettle();
      expect(find.byType(ChedGtsForm, skipOffstage: false), findsNothing);

      await tester.tap(show);
      await tester.pumpAndSettle();
      expect(find.text('Hide official form'), findsOneWidget);
      expect(find.byType(ChedGtsForm, skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('workspace shortcuts', () {
    testWidgets('select tabs when no field has focus', (tester) async {
      var tab = 0;
      var escapes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SurveyWorkspaceShortcuts(
              currentTab: () => tab,
              onSelectTab: (i) => tab = i,
              onEscape: () => escapes++,
              child: const Text('workspace'),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      expect(tab, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(tab, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      expect(tab, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(escapes, 1);
    });

    testWidgets('leave digits and arrows to a focused text field', (
      tester,
    ) async {
      var tab = 1;
      var escapes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SurveyWorkspaceShortcuts(
              currentTab: () => tab,
              onSelectTab: (i) => tab = i,
              onEscape: () => escapes++,
              child: const TextField(),
            ),
          ),
        ),
      );
      await tester.showKeyboard(find.byType(TextField));

      for (final key in [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      ]) {
        await tester.sendKeyEvent(key);
      }
      expect(tab, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(escapes, 1);
    });
  });

  group('responses header', () {
    for (final width in [768.0, 1366.0]) {
      testWidgets('ended window reads "Window ended" at $width', (
        tester,
      ) async {
        await _pumpAt(
          tester,
          width,
          SurveyResponsesWorkspaceHeader(
            survey: _survey(
              openAt: DateTime(2020, 8, 7),
              closeAt: DateTime(2020, 8, 14),
            ),
            onBack: () {},
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Window ended'), findsOneWidget);
        expect(find.text('Aug 7 – Aug 14, 2020'), findsOneWidget);
      });
    }

    testWidgets('no window shows "No window set"', (tester) async {
      await _pumpAt(
        tester,
        1366,
        SurveyResponsesWorkspaceHeader(
          survey: _survey(status: SurveyStatus.draft),
          onBack: () {},
        ),
      );
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('No window set'), findsOneWidget);
    });
  });

  group('reminder text', () {
    test('confirmation names the survey and the channels', () {
      expect(
        surveyReminderConfirmMessage(
          surveyTitle: ' Tracer 2026 ',
          recipients: 3,
          inApp: true,
          email: true,
          emailDropped: false,
        ),
        'Send in-app + email reminders for “Tracer 2026” to 3 pending alumni?',
      );
    });

    test('confirmation says email is not set up when it was dropped', () {
      final message = surveyReminderConfirmMessage(
        surveyTitle: '',
        recipients: 1,
        inApp: true,
        email: false,
        emailDropped: true,
      );
      expect(message, startsWith('Send in-app reminders for this survey to 1 '
          'pending alumnus?'));
      expect(message, contains('sent in-app only'));
    });

    test('summary lists skipped emails, including not configured', () {
      const result = SurveyReminderResult(
        inAppSent: 4,
        emailSent: 2,
        emailSkippedNoAddress: 1,
        emailSkippedNotConfigured: 2,
      );
      expect(
        surveyReminderSummary(
          result,
          inApp: true,
          email: true,
          emailDropped: false,
        ),
        'Sent: 4 in-app, 2 email, 1 skipped (no email), '
        '2 email skipped (not set up)',
      );
    });

    test('summary flags a dropped email channel', () {
      expect(
        surveyReminderSummary(
          const SurveyReminderResult(inAppSent: 5),
          inApp: true,
          email: false,
          emailDropped: true,
        ),
        'Sent: 5 in-app · email isn’t set up',
      );
      expect(
        surveyReminderSummary(
          const SurveyReminderResult(),
          inApp: false,
          email: false,
          emailDropped: false,
        ),
        'No reminders sent',
      );
    });
  });

  for (final width in [360.0, 768.0]) {
    testWidgets('empty state with action fits at $width', (tester) async {
      await _pumpAt(
        tester,
        width,
        SurveyEmptyState(
          title: 'No matching alumni',
          subtitle: 'Try clearing search or filters to see more pending '
              'alumni.',
          icon: Icons.search_off_outlined,
          actionLabel: 'Clear search & filters',
          onAction: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Clear search & filters'), findsOneWidget);
    });
  }

  for (final width in [768.0, 1024.0, 1366.0]) {
    testWidgets('responses skeletons lay out at $width', (tester) async {
      await _pumpAt(tester, width, const SurveyResponsesSkeleton.overview());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      await _pumpAt(tester, width, const SurveyResponsesSkeleton.table());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  }
}
