import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

import '../admin_shared/admin_test_harness.dart';

AlumniMember _member({
  String batch = '',
  String? yearGraduated = '2023',
  bool registered = true,
  bool deactivated = false,
  bool updates = false,
  DateTime? lastActive,
  String? email = 'juan@example.com',
}) {
  return AlumniMember(
    id: 'm1',
    fullName: 'Juan Santos',
    course: 'BSIT',
    studentId: '2023304878',
    batchYear: batch,
    yearGraduated: yearGraduated,
    registeredEmail: email,
    isRegisteredUser: registered,
    isDeactivated: deactivated,
    hasProfileUpdates: updates,
    lastActiveAt: lastActive,
  );
}

TracerProfile _tracer({String telephone = '', String employment = ''}) {
  return TracerProfile(
    uid: 'u1',
    email: 'juan@example.com',
    displayName: 'Juan Santos',
    studentId: '2023304878',
    program: 'BSIT',
    batchYear: '2023',
    yearGraduated: '2023',
    telephoneNumber: telephone,
    mobileNumber: '09170000000',
    address: 'Cagayan de Oro',
    gender: 'Male',
    civilStatus: 'Single',
    birthDate: DateTime(2000, 1, 1),
    regionOfOrigin: 'Region X',
    province: 'Misamis Oriental',
    locationOfResidence: 'City',
    collegeUniversity: 'USTP',
    employmentStatus: employment,
  );
}

AuditLog _log(String action, {String status = 'SUCCESS'}) {
  return AuditLog(
    id: action,
    userId: 'u1',
    userName: 'Admin',
    userEmail: 'admin@example.com',
    action: action,
    resource: 'AlumniMember',
    resourceId: 'm1',
    description: 'Did $action',
    timestamp: DateTime(2026, 10, 1, 9, 30),
    status: status,
  );
}

Widget _header(
  AlumniMember member, {
  double? percent,
  int activities = 0,
  VoidCallback? onActivityTap,
}) {
  return MemberDetailPanelHeader(
    member: member,
    onClose: () {},
    tracerPercent: percent,
    activityCount: activities,
    onActivityTap: onActivityTap,
  );
}

void main() {
  group('Member detail header', () {
    testWidgets('shows details line with batch fallback and status chips', (
      tester,
    ) async {
      await pumpAdmin(
        tester,
        _header(
          _member(lastActive: DateTime.now(), updates: true),
          percent: 93.4,
          activities: 12,
        ),
      );

      expect(find.text('Juan Santos'), findsOneWidget);
      expect(
        find.text('BSIT · ID 2023304878 · Batch 2023 · juan@example.com'),
        findsOneWidget,
      );
      expect(find.text('Registered'), findsOneWidget);
      expect(find.text('Active (30d)'), findsOneWidget);
      expect(find.text('Tracer 93%'), findsOneWidget);
      expect(find.text('Profile updated'), findsOneWidget);
      expect(find.text('12 activities'), findsOneWidget);
    });

    testWidgets('uses the 30-day active window', (tester) async {
      await pumpAdmin(
        tester,
        _header(
          _member(
            lastActive: DateTime.now().subtract(const Duration(days: 20)),
          ),
        ),
      );
      expect(find.text('Active (30d)'), findsOneWidget);

      await pumpAdmin(
        tester,
        _header(
          _member(
            lastActive: DateTime.now().subtract(const Duration(days: 40)),
          ),
        ),
      );
      expect(find.text('Active (30d)'), findsNothing);
    });

    testWidgets('deactivated and unregistered members', (tester) async {
      await pumpAdmin(tester, _header(_member(deactivated: true)));
      expect(find.text('Deactivated'), findsOneWidget);
      expect(find.text('Registered'), findsNothing);

      await pumpAdmin(tester, _header(_member(registered: false)));
      expect(find.text('Not registered'), findsOneWidget);
      expect(find.textContaining('Tracer'), findsNothing);
    });

    testWidgets('activities chip opens the activity tab', (tester) async {
      var taps = 0;
      await pumpAdmin(
        tester,
        _header(_member(), activities: 3, onActivityTap: () => taps++),
      );
      await tester.tap(find.text('3 activities'));
      expect(taps, 1);
    });

    testWidgets('fits at narrow widths', (tester) async {
      for (final width in kAdminTestWidths) {
        await pumpAdmin(
          tester,
          _header(
            _member(lastActive: DateTime.now(), updates: true),
            percent: 50,
            activities: 4,
          ),
          width: width,
        );
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
    });

    test('details line skips empty parts', () {
      expect(
        MemberDetailPanelHeader.detailsLine(
          _member(yearGraduated: null, email: null),
        ),
        'BSIT · ID 2023304878',
      );
      expect(
        MemberDetailPanelHeader.detailsLine(_member(batch: '2021')),
        'BSIT · ID 2023304878 · Batch 2021 · juan@example.com',
      );
    });
  });

  group('Tracer completeness', () {
    test('lists missing required fields with GTS labels', () {
      expect(memberDetailMissingTracerLabels(_tracer()), [
        GtsConstants.labelTelephone,
        GtsConstants.labelEmploymentStatus,
      ]);
      expect(
        memberDetailMissingTracerLabels(
          _tracer(telephone: '088', employment: 'Employed'),
        ),
        isEmpty,
      );
    });

    testWidgets('banner names the missing fields', (tester) async {
      await pumpAdmin(
        tester,
        const MemberDetailCompletenessBanner(
          percent: 86.7,
          missingLabels: ['Telephone', 'Employment Status'],
        ),
      );
      expect(find.text('Tracer profile 87% complete'), findsOneWidget);
      expect(
        find.text('Missing: Telephone, Employment Status'),
        findsOneWidget,
      );
    });

    testWidgets('banner falls back to the generic message', (tester) async {
      await pumpAdmin(
        tester,
        const MemberDetailCompletenessBanner(percent: 90, missingLabels: []),
      );
      expect(
        find.text('Some tracer profile fields are still missing.'),
        findsOneWidget,
      );
    });
  });

  group('Info rows', () {
    testWidgets('empty values hide unless emptyText is set', (tester) async {
      await pumpAdmin(
        tester,
        const Column(
          children: [
            MemberDetailInfoRow(label: 'Hidden', value: ' '),
            MemberDetailInfoRow(
              label: 'Telephone',
              value: '',
              emptyText: 'Not provided',
            ),
            MemberDetailInfoRow(label: 'Course', value: 'BSIT'),
          ],
        ),
      );
      expect(find.text('Hidden'), findsNothing);
      expect(find.text('Telephone'), findsOneWidget);
      expect(find.text('Not provided'), findsOneWidget);
      expect(find.text('BSIT'), findsOneWidget);
    });

    testWidgets('label stacks above value when narrow', (tester) async {
      await pumpAdmin(
        tester,
        const SizedBox(
          width: 300,
          child: MemberDetailInfoRow(label: 'Course', value: 'BSIT'),
        ),
      );
      final label = tester.getTopLeft(find.text('Course'));
      final value = tester.getTopLeft(find.text('BSIT'));
      expect(value.dy, greaterThan(label.dy));
      expect(value.dx, label.dx);

      await pumpAdmin(
        tester,
        const SizedBox(
          width: 600,
          child: MemberDetailInfoRow(label: 'Course', value: 'BSIT'),
        ),
      );
      final wideLabel = tester.getTopLeft(find.text('Course'));
      final wideValue = tester.getTopLeft(find.text('BSIT'));
      expect(wideValue.dy, wideLabel.dy);
      expect(wideValue.dx, greaterThan(wideLabel.dx));
    });
  });

  group('Columns', () {
    Widget columns() => const MemberDetailColumns(
      left: [SizedBox(key: Key('left'), height: 40)],
      right: [SizedBox(key: Key('right'), height: 40)],
    );

    testWidgets('side by side at 900 px and wider', (tester) async {
      await pumpAdmin(tester, columns(), width: 1366);
      final left = tester.getTopLeft(find.byKey(const Key('left')));
      final right = tester.getTopLeft(find.byKey(const Key('right')));
      expect(right.dy, left.dy);
      expect(right.dx, greaterThan(left.dx));
    });

    testWidgets('stacked below 900 px', (tester) async {
      await pumpAdmin(tester, columns(), width: 768);
      final left = tester.getTopLeft(find.byKey(const Key('left')));
      final right = tester.getTopLeft(find.byKey(const Key('right')));
      expect(right.dx, left.dx);
      expect(right.dy, greaterThan(left.dy));
    });
  });

  group('Activity', () {
    test('readable action labels keep acronyms', () {
      expect(
        memberDetailActionLabel('UPDATE_ROSTER_MEMBER'),
        'Update roster member',
      );
      expect(
        memberDetailActionLabel('EXPORT_CHED_GTS_PDF'),
        'Export CHED GTS PDF',
      );
      expect(memberDetailActionLabel('LOGIN'), 'Login');
      expect(memberDetailActionLabel(''), '');
    });

    testWidgets('rows show label, description and raw code tooltip', (
      tester,
    ) async {
      await pumpAdmin(
        tester,
        MemberDetailActivityList(
          logs: [
            _log('UPDATE_ROSTER_MEMBER'),
            _log('LOGIN', status: 'FAILED'),
          ],
          limit: 100,
        ),
      );
      expect(find.text('Update roster member'), findsOneWidget);
      expect(find.text('Did UPDATE_ROSTER_MEMBER'), findsOneWidget);
      expect(find.text('FAILED'), findsOneWidget);
      expect(find.byTooltip('UPDATE_ROSTER_MEMBER'), findsOneWidget);
      expect(find.textContaining('Showing the latest'), findsNothing);
    });

    testWidgets('notes when the row limit is reached', (tester) async {
      await pumpAdmin(
        tester,
        MemberDetailActivityList(
          logs: [for (var i = 0; i < 3; i++) _log('LOGIN_$i')],
          limit: 3,
        ),
      );
      expect(find.text('Showing the latest 3 entries'), findsOneWidget);
    });

    AuditLog profileUpdate({
      String source = 'tracer',
      Map<String, dynamic>? fields,
    }) {
      return AuditLog(
        id: 'pu1',
        userId: 'u1',
        userName: 'Juan Santos',
        userEmail: 'juan@example.com',
        action: 'PROFILE_UPDATE',
        resource: 'Profile',
        resourceId: 'u1',
        description: 'Updated 2 profile fields via tracer',
        changes: {
          'source': source,
          'fields':
              fields ??
              {
                'civilStatus': {'from': 'Single', 'to': 'Married'},
                'mobileNumber': {'from': '09170000000', 'to': '09179999999'},
              },
        },
        timestamp: DateTime(2026, 10, 20, 9, 30),
        status: 'SUCCESS',
      );
    }

    testWidgets('profile updates show source chip and expandable diff', (
      tester,
    ) async {
      await pumpAdmin(
        tester,
        MemberDetailActivityList(logs: [profileUpdate()], limit: 100),
      );
      expect(find.text('Profile updated'), findsOneWidget);
      expect(find.text('Via Tracer'), findsOneWidget);
      expect(find.text('Civil status, Mobile number'), findsOneWidget);
      expect(find.text('Single → Married'), findsNothing);

      await tester.tap(find.text('Civil status, Mobile number'));
      await tester.pumpAndSettle();
      expect(find.text('Single → Married'), findsOneWidget);
      expect(find.text('09170000000 → 09179999999'), findsOneWidget);
    });

    testWidgets('source filter narrows the timeline', (tester) async {
      await pumpAdmin(
        tester,
        MemberDetailActivityList(
          logs: [profileUpdate(), _log('UPDATE_ROSTER_MEMBER')],
          limit: 100,
        ),
      );
      expect(find.text('Profile updated'), findsOneWidget);
      expect(find.text('Update roster member'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Tracer'));
      await tester.pumpAndSettle();
      expect(find.text('Profile updated'), findsOneWidget);
      expect(find.text('Update roster member'), findsNothing);
    });

    testWidgets('name changes render the old and new name', (tester) async {
      await pumpAdmin(
        tester,
        MemberDetailActivityList(
          logs: [
            AuditLog(
              id: 'nc1',
              userId: 'u1',
              userName: 'Juan Santos',
              userEmail: 'juan@example.com',
              action: 'NAME_CHANGE',
              resource: 'Profile',
              resourceId: 'u1',
              description: 'Name updated after marriage',
              changes: {
                'from': 'Maria Clara',
                'to': 'Maria Clara Reyes',
                'source': 'tracer',
              },
              timestamp: DateTime(2026, 10, 20, 9, 30),
              status: 'SUCCESS',
            ),
          ],
          limit: 100,
        ),
      );
      expect(find.text('Name changed'), findsOneWidget);
      expect(find.text('Maria Clara → Maria Clara Reyes'), findsOneWidget);
      expect(find.text('Via Tracer'), findsOneWidget);
    });
  });

  group('Survey answers', () {
    testWidgets('uses question prompts when available', (tester) async {
      await pumpAdmin(
        tester,
        const MemberDetailAnswerList(
          questions: [
            SurveyQuestion(
              id: 'q1',
              surveyId: 's1',
              order: 1,
              type: SurveyQuestionType.text,
              prompt: 'Current job?',
            ),
          ],
          answers: {'q1': 'Developer'},
        ),
      );
      expect(find.text('Current job?'), findsOneWidget);
      expect(find.text('Developer'), findsOneWidget);
    });

    testWidgets('labels answers by position when questions are gone', (
      tester,
    ) async {
      await pumpAdmin(
        tester,
        const MemberDetailAnswerList(
          questions: [],
          answers: {
            'abc-123': 'Yes',
            'def-456': ['A', 'B'],
          },
        ),
      );
      expect(
        find.text('Answer 1 (question no longer available)'),
        findsOneWidget,
      );
      expect(find.text('A, B'), findsOneWidget);
      expect(find.byTooltip('abc-123'), findsOneWidget);
      expect(find.text('abc-123'), findsNothing);
    });

    testWidgets('empty response', (tester) async {
      await pumpAdmin(
        tester,
        const MemberDetailAnswerList(questions: [], answers: {}),
      );
      expect(
        find.text('No answers recorded for this response.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('notice shows title and message', (tester) async {
    await pumpAdmin(
      tester,
      const MemberDetailNotice(
        icon: Icons.person_off_outlined,
        title: 'Not registered in the app',
        message: 'Demographic tracer data appears later.',
      ),
    );
    expect(find.text('Not registered in the app'), findsOneWidget);
    expect(find.text('Demographic tracer data appears later.'), findsOneWidget);
  });
}
