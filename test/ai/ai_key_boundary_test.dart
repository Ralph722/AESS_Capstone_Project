import 'dart:io';

import 'package:alumni_system/features/ai/data/ai_assistant_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('no AI key in the app', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // Gitignored local file from the old setup; no longer imported.
        .where((f) => !f.path.replaceAll('\\', '/').endsWith('ai_secrets.dart'))
        .toList();

    test('no source calls Google AI directly or reads a Gemini key', () {
      final offenders = [
        for (final f in sources)
          if (RegExp(
            r'generativelanguage\.googleapis\.com|GEMINI_API_KEY|x-goog-api-key',
          ).hasMatch(f.readAsStringSync()))
            f.path,
      ];
      expect(offenders, isEmpty);
    });

    test('no source imports the old local secrets file', () {
      final offenders = [
        for (final f in sources)
          if (f.readAsStringSync().contains('ai_secrets.dart')) f.path,
      ];
      expect(offenders, isEmpty);
    });
  });

  group('tasks match the ai-assist Edge Function', () {
    final server = File(
      'supabase/functions/ai-assist/index.ts',
    ).readAsStringSync();

    for (final task in AiTask.values) {
      test(task.wireName, () {
        expect(server, contains('  ${task.wireName}: {'));
      });
    }
  });

  group('error responses', () {
    test('daily limit and busy are quota errors', () {
      expect(
        AiAssistantService.errorFor(429, {'error': 'limit_reached'}),
        isA<AiQuotaException>(),
      );
      expect(
        AiAssistantService.errorFor(503, {'error': 'ai_busy'}),
        isA<AiQuotaException>(),
      );
    });

    test('missing server key or function reads as not configured', () {
      expect(
        AiAssistantService.errorFor(503, {'error': 'ai_unavailable'}),
        isA<AiNotConfiguredException>(),
      );
      expect(
        AiAssistantService.errorFor(404, null),
        isA<AiNotConfiguredException>(),
      );
    });

    test('other errors are plain and never echo server details', () {
      final e = AiAssistantService.errorFor(500, {
        'error': 'server_error',
        'detail': 'secret',
      });
      expect(e, isNot(isA<AiQuotaException>()));
      expect(e.toString(), isNot(contains('secret')));
    });
  });
}
