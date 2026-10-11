import 'package:alumni_system/features/admin/dss/application/dss_ai_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_suggestion_themes.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/ai/data/ai_assistant_service.dart';
import 'package:alumni_system/features/ai/models/ai_chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

DssFlag _flag({
  String ruleId = 'UNEMPLOYMENT_HIGH',
  double value = 0.6,
  int sampleN = 12,
  Map<String, dynamic> evidence = const {'valid_answers': 12},
  DssFlagStatus status = DssFlagStatus.open,
}) => DssFlag(
  id: 'f',
  ruleId: ruleId,
  course: 'BSIT',
  batchYear: '2099',
  cohortLevel: DssCohortLevel.batch,
  surveyId: 's',
  surveyTitle: 'GTS',
  metricValue: value,
  thresholdSnapshot: 0.15,
  sampleN: sampleN,
  confidence: DssConfidence.low,
  status: status,
  title: 'High unemployment: BSIT 2099',
  body: '',
  recommendedAction: 'Coordinate with the placement office.',
  evidence: evidence,
  createdAt: DateTime(2026, 10, 11),
  updatedAt: DateTime(2026, 10, 11),
);

class _FakeAi extends AiAssistantService {
  _FakeAi({this.reply, this.error = false});

  final String? reply;
  final bool error;
  String? lastPrompt;
  int calls = 0;

  @override
  Future<String> sendMessage({
    required bool isAdmin,
    required List<AiChatMessage> history,
    required String userMessage,
    String? userDisplayName,
    int maxOutputTokens = 1024,
    double temperature = 0.7,
    String? systemInstructionOverride,
    String? responseMimeType,
    bool disableThinking = false,
  }) async {
    calls++;
    lastPrompt = userMessage;
    if (error) throw Exception('quota');
    return reply ?? '';
  }
}

const _good =
    'In BSIT Batch 2099, 60% of the 12 alumni who answered are not '
    'currently employed, which is above the rule limit. The recommended '
    'step is to coordinate with the placement office.';

void main() {
  group('facts sent to AI', () {
    test('include the computed figures and no names or answers', () {
      final prompt = DssAiService.factsPrompt(_flag());
      expect(prompt, contains('BSIT · Batch 2099'));
      expect(prompt, contains('60%'));
      expect(prompt, contains('Answers: 12'));
      expect(prompt, contains('Fixed recommended action'));
      expect(prompt, contains('must include the value "60%"'));
    });

    test('mark Watch items as not a finding yet', () {
      final watch = _flag(
        status: DssFlagStatus.watch,
        sampleN: 7,
        evidence: const {'valid_answers': 7},
      );
      final prompt = DssAiService.factsPrompt(watch);
      expect(prompt, contains('not a finding yet'));
      expect(prompt, contains('Evidence:'));
    });
  });

  group('required value', () {
    test('rate, trend and salary use the page format', () {
      expect(DssAiService.requiredValueText(_flag()), '60%');
      final trend = _flag(
        ruleId: 'UNEMPLOYMENT_TREND_UP',
        value: 0.12,
        evidence: const {'current_answered': 20, 'previous_answered': 15},
      );
      expect(DssAiService.requiredValueText(trend), '+12 pts');
      expect(DssAiService.answersCount(trend), 15);
      final salary = _flag(ruleId: 'SALARY_STAGNATION', value: 1.5);
      expect(DssAiService.requiredValueText(salary), '1.5 bracket(s)');
    });

    test('no value is required when fewer than 5 answered', () {
      final few = _flag(sampleN: 3, evidence: const {'valid_answers': 3});
      expect(DssAiService.requiredValueText(few), isNull);
    });
  });

  group('reply check', () {
    final flag = _flag();

    test('accepts a reply that restates value and answers', () {
      expect(DssAiService.checkReply(_good, flag), isNull);
      expect(
        DssAiService.checkReply(
          '60 percent of 12 answers are not employed; the step is to close '
          'the gap with employer partners.',
          flag,
        ),
        isNull,
      );
    });

    test('rejects a reply missing the value or the answers', () {
      expect(
        DssAiService.checkReply(
          'Most of the 12 alumni who answered are not employed.',
          flag,
        ),
        contains('measured value'),
      );
      expect(
        DssAiService.checkReply('60% of alumni are not employed.', flag),
        contains('number of answers'),
      );
      expect(
        DssAiService.checkReply('60% of 120 alumni are not employed.', flag),
        contains('number of answers'),
      );
    });

    test('rejects decision or priority wording', () {
      for (final reply in [
        '$_good This should be a high priority.',
        '$_good It is the most urgent issue.',
        '$_good You can dismiss this finding.',
        '$_good It should be closed after the job fair.',
        '$_good The intervention worked.',
        '$_good This is likely a false alarm.',
        '$_good It ranks first among findings.',
        '$_good The severity is high.',
      ]) {
        expect(
          DssAiService.checkReply(reply, flag),
          contains('beyond explaining'),
          reason: reply,
        );
      }
    });

    test('allows "rank or clerical" role wording', () {
      final under = _flag(ruleId: 'UNDEREMPLOYMENT');
      expect(
        DssAiService.checkReply(
          '60% of the 12 employed alumni hold rank or clerical roles.',
          under,
        ),
        isNull,
      );
    });

    test('trend and salary values', () {
      final trend = _flag(
        ruleId: 'UNEMPLOYMENT_TREND_UP',
        value: 0.12,
        evidence: const {'current_answered': 20, 'previous_answered': 15},
      );
      expect(
        DssAiService.checkReply(
          'Not employed rose by 12 percentage points, based on 15 answers.',
          trend,
        ),
        isNull,
      );
      final salary = _flag(ruleId: 'SALARY_STAGNATION', value: 1.5);
      expect(
        DssAiService.checkReply(
          'Salaries are 1.5 brackets below peers, from 12 answers.',
          salary,
        ),
        isNull,
      );
    });
  });

  group('explainFlag', () {
    test('uses the rule-based text when AI is not configured', () async {
      final fake = _FakeAi(reply: _good);
      final result = await DssAiService(
        ai: fake,
        available: false,
      ).explainFlag(_flag());
      expect(result.byAi, isFalse);
      expect(result.text, DssAiService.fallbackText(_flag()));
      expect(fake.calls, 0);
    });

    test('shows a valid AI reply, labeled as AI', () async {
      final fake = _FakeAi(reply: '**$_good**');
      final result = await DssAiService(
        ai: fake,
        available: true,
      ).explainFlag(_flag());
      expect(result.byAi, isTrue);
      expect(result.text, _good);
      expect(fake.lastPrompt, contains('Answers: 12'));
    });

    test('discards a reply with decision wording', () async {
      final result = await DssAiService(
        ai: _FakeAi(reply: '$_good Mark it as resolved.'),
        available: true,
      ).explainFlag(_flag());
      expect(result.byAi, isFalse);
      expect(result.rejectedReason, isNotNull);
      expect(result.text, DssAiService.fallbackText(_flag()));
    });

    test('falls back when the AI call fails', () async {
      final result = await DssAiService(
        ai: _FakeAi(error: true),
        available: true,
      ).explainFlag(_flag());
      expect(result.byAi, isFalse);
      expect(result.unavailable, isTrue);
      expect(result.text, DssAiService.fallbackText(_flag()));
    });
  });

  group('Q34 redaction', () {
    test('removes emails, links and phone numbers', () {
      final out = DssSuggestionThemeService.redactForAi(
        'Email me at juan.dela+1@school.edu.ph or call 0917 123 4567; '
        'see https://example.com/x and www.site.org.',
      );
      expect(out, contains('[email]'));
      expect(out, contains('[phone]'));
      expect(out, contains('[link]'));
      expect(out, isNot(contains('0917')));
      expect(out, isNot(contains('example.com')));
      expect(out, isNot(contains('@')));
    });

    test('keeps years, year ranges and short numbers', () {
      const text = 'Batch 2019-2020 needs 3 more OJT slots in 2024.';
      expect(DssSuggestionThemeService.redactForAi(text), text);
    });
  });
}
