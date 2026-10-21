import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/core/config/push_config.dart';
import 'package:alumni_system/core/config/supabase_config.dart';
import 'package:alumni_system/core/config/supabase_defaults.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';

/// Encodes Phase 10 production gates as automated checks.
void main() {
  group('production gates', () {
    test('default Flutter config targets the live project with anon role', () {
      expect(SupabaseConfig.url, SupabaseDefaults.url);
      expect(SupabaseConfig.anonKey, SupabaseDefaults.anonKey);
      expect(SupabaseConfig.environment, isEmpty);
      expect(SupabaseConfig.configurationError, isNull);
      expect(SupabaseConfig.environmentLabel, isNull);

      final parts = SupabaseDefaults.anonKey.split('.');
      expect(parts.length, 3);
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      expect(claims['role'], 'anon');
      expect(claims['ref'], SupabaseConfig.liveProjectRef);
    });

    test('service-role keys are refused in the client', () {
      final claims = base64Url.encode(
        utf8.encode(
          '{"role":"service_role","ref":"${SupabaseConfig.liveProjectRef}"}',
        ),
      );
      final serviceJwt = 'e30.${claims.replaceAll('=', '')}.sig';
      expect(
        SupabaseConfig.validate(
          environment: '',
          url: SupabaseDefaults.url,
          anonKey: serviceJwt,
          urlOverridden: true,
          anonKeyOverridden: true,
        ),
        contains('never be used'),
      );
    });

    test('demo environment cannot point at the live project', () {
      expect(
        SupabaseConfig.validate(
          environment: 'demo',
          url: SupabaseDefaults.url,
          anonKey: SupabaseDefaults.anonKey,
          urlOverridden: true,
          anonKeyOverridden: true,
        ),
        contains('cannot use the live project'),
      );
    });

    test('push public identifiers are present for Android and web', () {
      expect(PushConfig.fcmConfigured, isTrue);
      expect(PushConfig.webPushConfigured, isTrue);
      expect(PushConfig.firebaseProjectId, 'aess-alumni');
    });

    test('upload limits stay within private bucket policy (2MB server / 1MB app)', () {
      expect(ImageStorageService.maxUploadBytes, lessThanOrEqualTo(2 * 1024 * 1024));
      expect(ImageStorageService.maxUploadBytes, 1024 * 1024);
      expect(
        ImageStorageService.isAllowedMessageImageUrl(
          'https://evil.example/leak.jpg',
        ),
        isFalse,
      );
    });
  });
}
