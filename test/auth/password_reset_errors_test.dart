import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';

AuthService _serviceReturning(http.Response Function() respond) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: MockClient((_) async => respond()),
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  return AuthService(supabase: client);
}

AuthService _serviceThrowing() {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: MockClient((_) async => throw http.ClientException('offline')),
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  return AuthService(supabase: client);
}

http.Response _error(int status, String errorCode, String msg) => http.Response(
  jsonEncode({'code': status, 'error_code': errorCode, 'msg': msg}),
  status,
  headers: {'content-type': 'application/json'},
);

Matcher _failsWith(PasswordChangeFailure failure) => throwsA(
  isA<PasswordChangeException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  group('sendPasswordResetCode', () {
    test('succeeds without revealing whether the account exists', () async {
      final service = _serviceReturning(() => http.Response('{}', 200));
      await expectLater(service.sendPasswordResetCode('a@b.com'), completes);
    });

    test('maps email rate limits', () {
      final service = _serviceReturning(
        () => _error(429, 'over_email_send_rate_limit', 'rate limit exceeded'),
      );
      expect(
        service.sendPasswordResetCode('a@b.com'),
        _failsWith(PasswordChangeFailure.rateLimited),
      );
    });

    test('maps an unreachable server to a connection message', () {
      expect(
        _serviceThrowing().sendPasswordResetCode('a@b.com'),
        _failsWith(PasswordChangeFailure.network),
      );
    });

    test('maps server failures to a generic message', () {
      final service = _serviceReturning(
        () => http.Response('Error sending recovery email', 500),
      );
      expect(
        service.sendPasswordResetCode('a@b.com'),
        _failsWith(PasswordChangeFailure.unknown),
      );
    });
  });

  group('verifyPasswordResetCode', () {
    test('maps expired or invalid codes', () {
      final service = _serviceReturning(
        () => _error(403, 'otp_expired', 'Token has expired or is invalid'),
      );
      expect(
        service.verifyPasswordResetCode(email: 'a@b.com', code: '123456'),
        _failsWith(PasswordChangeFailure.invalidCode),
      );
    });

    test('maps deactivated accounts', () {
      final service = _serviceReturning(
        () => _error(400, 'user_banned', 'User is banned'),
      );
      expect(
        service.verifyPasswordResetCode(email: 'a@b.com', code: '123456'),
        _failsWith(PasswordChangeFailure.accountUnavailable),
      );
    });

    test('maps request rate limits', () {
      final service = _serviceReturning(
        () => _error(429, 'over_request_rate_limit', 'Too many requests'),
      );
      expect(
        service.verifyPasswordResetCode(email: 'a@b.com', code: '123456'),
        _failsWith(PasswordChangeFailure.rateLimited),
      );
    });

    test('maps an unreachable server to a connection message', () {
      expect(
        _serviceThrowing().verifyPasswordResetCode(
          email: 'a@b.com',
          code: '123456',
        ),
        _failsWith(PasswordChangeFailure.network),
      );
    });
  });
}
