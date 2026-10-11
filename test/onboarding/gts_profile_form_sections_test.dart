import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/shared/widgets/gts/gts_profile_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GtsProfileFormState state;

  setUp(() => state = GtsProfileFormState());
  tearDown(() => state.dispose());

  Future<void> pump(WidgetTester tester, Widget fields) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: Form(child: fields)),
        ),
      ),
    );
  }

  Finder label(String text) => find.text(text, skipOffstage: false);

  testWidgets('full layout keeps the grouped sections', (tester) async {
    await pump(
      tester,
      GtsProfileFormFields(
        state: state,
        onChanged: () {},
        showEmploymentStatus: true,
        chedStyleLabels: false,
      ),
    );

    expect(label('General information'), findsOneWidget);
    expect(label('Educational background'), findsOneWidget);
    expect(label(GtsConstants.labelName), findsOneWidget);
    expect(label(GtsConstants.labelMobile), findsOneWidget);
    expect(label(GtsConstants.labelCollegeUniversity), findsOneWidget);
    expect(label(GtsConstants.employed), findsOneWidget);
  });

  testWidgets('personal section renders only personal fields', (tester) async {
    await pump(
      tester,
      GtsProfileFormFields(
        state: state,
        onChanged: () {},
        chedStyleLabels: false,
        section: GtsFormSection.personal,
      ),
    );

    expect(label('General information'), findsNothing);
    expect(label(GtsConstants.labelName), findsOneWidget);
    expect(label(GtsConstants.labelSex), findsOneWidget);
    expect(label(GtsConstants.labelCivilStatus), findsOneWidget);
    expect(label(GtsConstants.labelBirthday), findsOneWidget);
    expect(label(GtsConstants.labelMobile), findsNothing);
    expect(label(GtsConstants.labelCollegeUniversity), findsNothing);
  });

  testWidgets('contact section renders address and location fields', (
    tester,
  ) async {
    await pump(
      tester,
      GtsProfileFormFields(
        state: state,
        onChanged: () {},
        chedStyleLabels: false,
        section: GtsFormSection.contact,
      ),
    );

    expect(label(GtsConstants.labelPermanentAddress), findsOneWidget);
    expect(label(GtsConstants.labelEmail), findsOneWidget);
    expect(label(GtsConstants.labelMobile), findsOneWidget);
    expect(label(GtsConstants.labelProvince), findsOneWidget);
    expect(label(GtsConstants.labelName), findsNothing);
  });

  testWidgets('step mode blocks an empty birthday and degree', (tester) async {
    final personalKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: personalKey,
              child: GtsProfileFormFields(
                state: state,
                onChanged: () {},
                chedStyleLabels: false,
                section: GtsFormSection.personal,
              ),
            ),
          ),
        ),
      ),
    );
    final invalid = personalKey.currentState!.validateGranularly();
    await tester.pump();
    // Name, sex, civil status and birthday are all empty.
    expect(invalid.length, 4);

    final educationKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: educationKey,
              child: GtsProfileFormFields(
                state: state,
                onChanged: () {},
                chedStyleLabels: false,
                showEmploymentStatus: true,
                section: GtsFormSection.education,
              ),
            ),
          ),
        ),
      ),
    );
    expect(label('Not set yet'), findsOneWidget);
    educationKey.currentState!.validate();
    await tester.pump();
    expect(
      find.textContaining('Contact the alumni office to continue'),
      findsOneWidget,
    );
    expect(label('Choose one'), findsOneWidget);
  });

  testWidgets('step mode marks untouched record values and locks email', (
    tester,
  ) async {
    state.applyFromProfile(
      const TracerProfile(
        uid: 'u1',
        email: 'maria@example.com',
        displayName: 'Maria Santos',
        studentId: '',
        program: '',
        batchYear: '',
        yearGraduated: '',
      ),
    );

    await pump(
      tester,
      GtsProfileFormFields(
        state: state,
        onChanged: () {},
        chedStyleLabels: false,
        section: GtsFormSection.personal,
      ),
    );
    expect(label('From your alumni record'), findsOneWidget);

    state.displayNameController.text = 'Maria S. Santos';
    await pump(
      tester,
      GtsProfileFormFields(
        state: state,
        onChanged: () {},
        chedStyleLabels: false,
        section: GtsFormSection.personal,
      ),
    );
    expect(label('From your alumni record'), findsNothing);

    await pump(
      tester,
      GtsProfileFormFields(
        state: state,
        onChanged: () {},
        chedStyleLabels: false,
        emailReadOnly: true,
        section: GtsFormSection.contact,
      ),
    );
    expect(label('maria@example.com'), findsOneWidget);
    expect(label('From your account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  test('section counters match the tracer completion rules', () {
    expect(
      GtsFormSection.values.expand((s) => s.requiredKeys).toSet(),
      TracerProfile.requiredFieldKeys.toSet(),
    );
    expect(
      GtsFormSection.values.fold<int>(0, (n, s) => n + s.requiredKeys.length),
      TracerProfile.fullProfileFieldCount,
    );

    state.displayNameController.text = 'Maria';
    state.gender = 'Female';
    expect(state.filledInSection(GtsFormSection.personal), 2);
    expect(state.missingRequiredKeys(), isNot(contains('displayName')));
    expect(state.missingRequiredKeys(), contains('birthDate'));
  });

  testWidgets('education section includes employment only when asked', (
    tester,
  ) async {
    await pump(
      tester,
      GtsProfileFormFields(
        state: state,
        onChanged: () {},
        chedStyleLabels: false,
        section: GtsFormSection.education,
      ),
    );
    expect(label(GtsConstants.labelCollegeUniversity), findsOneWidget);
    expect(label(GtsConstants.employed), findsNothing);

    await pump(
      tester,
      GtsProfileFormFields(
        state: state,
        onChanged: () {},
        chedStyleLabels: false,
        showEmploymentStatus: true,
        section: GtsFormSection.education,
      ),
    );
    expect(label(GtsConstants.labelEmploymentStatus), findsOneWidget);
    expect(label(GtsConstants.employed), findsOneWidget);
    expect(label(GtsConstants.labelName), findsNothing);
  });
}
