import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TracerProfile _profile(Map<String, dynamic> extra) =>
    TracerProfile.fromSupabaseRow({
      'id': 'u1',
      'email': 'ana@school.edu',
      'display_name': 'Ana',
      ...extra,
    });

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: SizedBox(width: 600, child: child)),
  ),
);

void main() {
  testWidgets('email badge: login email counts as verified', (tester) async {
    await _pump(
      tester,
      ContactVerificationBadge.email(
        _profile({'contact_email': 'ana@school.edu'}),
      ),
    );
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('email badge: unconfirmed contact email is not verified', (
    tester,
  ) async {
    await _pump(
      tester,
      ContactVerificationBadge.email(
        _profile({'contact_email': 'ana@gmail.com'}),
      ),
    );
    expect(find.text('Not verified'), findsOneWidget);
  });

  testWidgets('mobile badge covers sms, demo and none', (tester) async {
    await _pump(
      tester,
      Column(
        children: [
          ContactVerificationBadge.mobile(
            _profile({
              'mobile_number': '09171234567',
              'mobile_verification_method': 'sms',
              'mobile_verified_at': '2026-10-16T01:00:00Z',
            }),
          ),
          ContactVerificationBadge.mobile(
            _profile({
              'mobile_number': '09171234567',
              'mobile_verification_method': 'mock',
            }),
          ),
          ContactVerificationBadge.mobile(
            _profile({'mobile_number': '09171234567'}),
          ),
        ],
      ),
    );
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Demo code'), findsOneWidget);
    expect(find.text('Not verified'), findsOneWidget);
  });

  testWidgets('info row shows the badge only next to a value', (tester) async {
    await _pump(
      tester,
      const Column(
        children: [
          MemberDetailInfoRow(
            label: 'Mobile',
            value: '09171234567',
            trailing: ContactVerificationBadge(
              status: ContactVerificationStatus.notVerified,
            ),
          ),
          MemberDetailInfoRow(
            label: 'Email',
            value: '',
            emptyText: 'Not provided',
            trailing: ContactVerificationBadge(
              status: ContactVerificationStatus.verified,
            ),
          ),
        ],
      ),
    );
    expect(find.text('Not verified'), findsOneWidget);
    expect(find.text('Verified'), findsNothing);
    expect(find.text('Not provided'), findsOneWidget);
  });
}
