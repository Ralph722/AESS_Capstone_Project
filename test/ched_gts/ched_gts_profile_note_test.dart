import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_form.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_prefill.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileNote =
    'Filled in from your profile. If this has changed, update it to your '
    'current details.';

bool _note(String id, dynamic answer, Map<String, dynamic> prefilled) =>
    ChedGtsPrefill.showsProfileNote(id, answer, prefilled);

void main() {
  group('showsProfileNote', () {
    const profile = {
      'ched_1': 'Ana Reyes',
      'ched_2': 'Zone 1, Lapasan, Cagayan de Oro',
      'ched_6': 'Single',
      'ched_9': 'Region X',
      'ched_10': 'Misamis Oriental',
      'ched_16': 'Yes',
    };

    test('profile details that may change get the note', () {
      expect(
        _note('ched_2', ' Zone 1, Lapasan, Cagayan de Oro ', profile),
        isTrue,
      );
      expect(_note('ched_6', 'Single', profile), isTrue);
      expect(_note('ched_10', 'Misamis Oriental', profile), isTrue);
      expect(_note('ched_16', 'Yes', profile), isTrue);
    });

    test('no note once edited, or for stable details', () {
      expect(_note('ched_6', 'Married', profile), isFalse);
      expect(_note('ched_1', 'Ana Reyes', profile), isFalse);
      expect(_note('ched_9', 'Region X', profile), isFalse);
      expect(_note('ched_3', 'a@x.com', profile), isFalse);
    });

    test('job answers never get the note', () {
      const prefilled = {
        'ched_18': 'Regular or Permanent',
        'ched_19': 'Engineer',
        'ched_31': 'P25,000.00 and above',
      };
      for (final id in prefilled.keys) {
        expect(_note(id, prefilled[id], prefilled), isFalse, reason: id);
      }
    });
  });

  test('profile prefill leaves the job questions blank', () {
    final prefill = ChedGtsPrefill.fromProfile(
      const TracerProfile(
        uid: 'u1',
        email: 'ana@example.com',
        displayName: 'Ana Reyes',
        studentId: '2020001',
        program: 'BSIT',
        batchYear: '2020',
        yearGraduated: '2020',
        civilStatus: 'Single',
        employmentStatus: GtsConstants.employed,
      ),
    );

    expect(prefill['ched_1'], 'Ana Reyes');
    expect(prefill['ched_16'], isNotNull);
    for (final id in ['ched_18', 'ched_19', 'ched_20', 'ched_21', 'ched_31']) {
      expect(prefill.containsKey(id), isFalse, reason: id);
    }
  });

  testWidgets('form shows the note until the pre-filled answer is edited', (
    tester,
  ) async {
    const profile = {'ched_1': 'Ana Reyes', 'ched_2': 'Lapasan, CDO'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChedGtsForm(
              answers: Map.of(profile),
              prefilledAnswers: profile,
              onChanged: (_) {},
              showIntro: false,
              onlyItemIds: const {'ched_1', 'ched_2'},
              sectionFilter: ChedGtsSection.a,
            ),
          ),
        ),
      ),
    );

    expect(find.text(_profileNote), findsNothing);
    await tester.tap(find.text('About this question').at(1));
    await tester.pumpAndSettle();
    expect(find.text(_profileNote), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Lapasan, CDO'),
      'Carmen, CDO',
    );
    await tester.pump();
    expect(find.text(_profileNote), findsNothing);
  });

  testWidgets('description sits in a closed "About this question" dropdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChedGtsForm(
              answers: const {},
              onChanged: (_) {},
              showIntro: false,
              onlyItemIds: const {'ched_5', 'ched_6'},
              sectionFilter: ChedGtsSection.a,
            ),
          ),
        ),
      ),
    );

    const description = 'Your active mobile number, e.g. 0917 123 4567.';
    // Q6 Civil Status has no description or notes, so no dropdown.
    expect(find.text('About this question'), findsOneWidget);
    expect(find.text(description), findsNothing);

    await tester.tap(find.text('About this question'));
    await tester.pumpAndSettle();
    expect(find.text(description), findsOneWidget);

    await tester.tap(find.text('About this question'));
    await tester.pumpAndSettle();
    expect(find.text(description), findsNothing);
  });

  testWidgets('inline style shows notes in place, with no dropdown', (
    tester,
  ) async {
    const profile = {'ched_2': 'Lapasan, CDO'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChedGtsForm(
              answers: Map.of(profile),
              prefilledAnswers: profile,
              onChanged: (_) {},
              showIntro: false,
              onlyItemIds: const {'ched_2', 'ched_5'},
              sectionFilter: ChedGtsSection.a,
              notesStyle: ChedGtsNotesStyle.inline,
            ),
          ),
        ),
      ),
    );

    expect(find.text('About this question'), findsNothing);
    expect(find.text(_profileNote), findsOneWidget);
    expect(
      find.text('Your active mobile number, e.g. 0917 123 4567.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lightbulb_outline_rounded), findsNWidgets(2));
  });

  testWidgets('read-only views never show the note', (tester) async {
    const profile = {'ched_2': 'Lapasan, CDO'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChedGtsForm(
              answers: Map.of(profile),
              prefilledAnswers: profile,
              onChanged: (_) {},
              readOnly: true,
              showIntro: false,
              onlyItemIds: const {'ched_2'},
            ),
          ),
        ),
      ),
    );
    expect(find.text(_profileNote), findsNothing);
  });
}
