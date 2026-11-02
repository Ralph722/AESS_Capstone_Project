import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';

const _email = 'kent@gmail.com';
const _password = 'Alumni2024x';

const _user = {
  'id': '00000000-0000-0000-0000-000000000002',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': _email,
  'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
  'created_at': '2026-01-01T00:00:00.000000Z',
  'updated_at': '2026-01-01T00:00:00.000000Z',
  'app_metadata': {'provider': 'email', 'providers': ['email']},
  'user_metadata': {'display_name': 'Kent'},
  'identities': [
    {
      'id': '00000000-0000-0000-0000-000000000002',
      'identity_id': '00000000-0000-0000-0000-000000000003',
      'user_id': '00000000-0000-0000-0000-000000000002',
      'identity_data': {'email': _email},
      'provider': 'email',
      'created_at': '2026-01-01T00:00:00.000000Z',
      'last_sign_in_at': '2026-01-01T00:00:00.000000Z',
      'updated_at': '2026-01-01T00:00:00.000000Z',
    },
  ],
};

void main() {
  group('verifyRegistrationCode', () {
    test('treats an unchanged password as success', () async {
      final requests = <http.Request>[];
      final service = _service(requests, userUpdate: _samePassword);
      final user = await service.verifyRegistrationCode(
        email: _email,
        code: '29043084',
        password: _password,
      );

      expect(user.email, _email);
      expect(requests.map((r) => r.url.path), [
        '/auth/v1/verify',
        '/auth/v1/user',
      ]);
    });

    test('a later tap does not ask Auth to verify the used code again', () async {
      final requests = <http.Request>[];
      final service = _service(requests, userUpdate: _samePassword);
      await service.verifyRegistrationCode(
        email: _email,
        code: '29043084',
        password: _password,
      );
      requests.clear();

      await service.verifyRegistrationCode(
        email: _email,
        code: '00000000',
        password: _password,
      );

      expect(requests.map((r) => r.url.path), ['/auth/v1/user']);
    });

    test('still blocks registration when the password was not saved', () {
      final service = _service(
        [],
        userUpdate: () => http.Response(
          jsonEncode({
            'code': 422,
            'error_code': 'weak_password',
            'msg': 'Password should be at least 8 characters',
          }),
          422,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(
        service.verifyRegistrationCode(
          email: _email,
          code: '29043084',
          password: 'short',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('could not save your password'),
              isNot(contains('Forgot password')),
            ),
          ),
        ),
      );
    });
  });

  group('resendRegistrationCode', () {
    test('asks Auth for another code before the email is confirmed', () async {
      final requests = <http.Request>[];
      final service = _service(requests, userUpdate: _samePassword);

      expect(
        await service.resendRegistrationCode(_email),
        RegistrationResend.codeSent,
      );
      expect(requests.single.url.path, '/auth/v1/resend');
    });

    test('does not ask Auth to resend after the email is confirmed', () async {
      final requests = <http.Request>[];
      final service = _service(requests, userUpdate: _samePassword);
      await service.verifyRegistrationCode(
        email: _email,
        code: '29043084',
        password: _password,
      );
      requests.clear();

      expect(
        await service.resendRegistrationCode(_email),
        RegistrationResend.alreadyConfirmed,
      );
      expect(requests, isEmpty);
    });
  });
}

http.Response _samePassword() => http.Response(
  jsonEncode({
    'code': 422,
    'error_code': 'same_password',
    'msg': 'New password should be different from the old password.',
  }),
  422,
  headers: {'content-type': 'application/json'},
);

AuthService _service(
  List<http.Request> requests, {
  required http.Response Function() userUpdate,
}) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: MockClient((request) async {
      requests.add(request);
      const json = {'content-type': 'application/json'};
      final path = request.url.path;
      if (path == '/auth/v1/verify') {
        return http.Response(
          jsonEncode({
            'access_token': 'test-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'test-refresh',
            'user': _user,
          }),
          200,
          headers: json,
          request: request,
        );
      }
      if (path == '/auth/v1/user' && request.method == 'PUT') {
        return userUpdate();
      }
      if (path == '/auth/v1/resend') {
        return http.Response('{}', 200, headers: json, request: request);
      }
      return http.Response('{}', 200, headers: json, request: request);
    }),
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  return AuthService(supabase: client);
}
