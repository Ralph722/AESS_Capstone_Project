import 'dart:convert';

import 'package:alumni_system/core/config/supabase_config.dart';
import 'package:alumni_system/core/config/supabase_defaults.dart';
import 'package:alumni_system/shared/widgets/environment_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(String? label) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: EnvironmentBanner(label: label, child: const Text('content')),
  );

  testWidgets('shows the ribbon with its label', (tester) async {
    await tester.pumpWidget(app('DEMO DATA'));
    final banner = tester.widget<Banner>(find.byType(Banner));
    expect(banner.message, 'DEMO DATA');
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('renders only the child without a label', (tester) async {
    await tester.pumpWidget(app(null));
    expect(find.byType(Banner), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  group('SupabaseConfig', () {
    const demoUrl = 'https://abcdefghijklmnopqrst.supabase.co';

    String? validate({
      String environment = '',
      String url = demoUrl,
      String anonKey = 'sb_publishable_demo',
      bool urlOverridden = true,
      bool anonKeyOverridden = true,
    }) => SupabaseConfig.validate(
      environment: environment,
      url: url,
      anonKey: anonKey,
      urlOverridden: urlOverridden,
      anonKeyOverridden: anonKeyOverridden,
    );

    test('the default build is the live project, valid and unlabeled', () {
      expect(SupabaseConfig.configurationError, isNull);
      expect(SupabaseConfig.environmentLabel, isNull);
      expect(
        validate(
          url: SupabaseDefaults.url,
          anonKey: SupabaseDefaults.anonKey,
          urlOverridden: false,
          anonKeyOverridden: false,
        ),
        isNull,
      );
    });

    test('a demo build with both values is valid', () {
      expect(validate(environment: 'demo'), isNull);
    });

    test('demo never falls back to live values', () {
      expect(
        validate(
          environment: 'demo',
          url: SupabaseDefaults.url,
          anonKey: SupabaseDefaults.anonKey,
          urlOverridden: false,
          anonKeyOverridden: false,
        ),
        contains('needs the demo'),
      );
      expect(
        validate(
          environment: 'demo',
          url: SupabaseDefaults.url,
          anonKey: SupabaseDefaults.anonKey,
        ),
        contains('cannot use the live project'),
      );
    });

    test('setting only one of URL and key is refused', () {
      expect(
        validate(anonKey: SupabaseDefaults.anonKey, anonKeyOverridden: false),
        contains('both'),
      );
      expect(
        validate(url: SupabaseDefaults.url, urlOverridden: false),
        contains('both'),
      );
    });

    test('the live anon key with another URL is refused', () {
      expect(
        validate(anonKey: SupabaseDefaults.anonKey),
        contains('different project'),
      );
    });

    test('service-role and secret keys are refused', () {
      final claims = base64Url.encode(
        utf8.encode('{"role":"service_role","ref":"abcdefghijklmnopqrst"}'),
      );
      final serviceJwt = 'e30.${claims.replaceAll('=', '')}.sig';
      expect(validate(anonKey: serviceJwt), contains('never be used'));
      expect(validate(anonKey: 'sb_secret_abc'), contains('never be used'));
    });

    test('placeholder demo URLs and unknown environments are refused', () {
      expect(
        validate(
          environment: 'demo',
          url: 'https://your-demo-project-ref.supabase.co',
        ),
        isNotNull,
      );
      expect(validate(environment: 'staging'), contains('Unknown AESS_ENV'));
    });

    test('the label follows the actual project ref', () {
      expect(SupabaseConfig.labelFor('${SupabaseDefaults.url}/', ''), isNull);
      expect(SupabaseConfig.labelFor(demoUrl, 'demo'), 'DEMO DATA');
      expect(SupabaseConfig.labelFor(demoUrl, ''), 'NOT LIVE');
      expect(SupabaseConfig.labelFor('http://localhost:54321', ''), 'NOT LIVE');
    });
  });
}
