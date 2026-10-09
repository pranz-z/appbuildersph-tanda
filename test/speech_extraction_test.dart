import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/logic/speech_extraction.dart';
import 'package:tanda/services/llm/extractor.dart';
import 'package:tanda/services/llm/llm_service.dart';

const raw = 'Hiniram ni Kuya Jun yung drill, ah, isosoli daw sa Sabado.';
const clean = 'Hiniram ni Kuya Jun ang drill. Isosoli daw sa Sabado.';

String response({String sentence = clean, String person = 'Kuya Jun'}) =>
    jsonEncode({
      'understood': true,
      'cleaned_sentence': sentence,
      'memory': {
        'kind': 'lent_item',
        'person': person,
        'item': 'drill',
        'place': null,
        'amount': null,
        'due_date_text': 'sa Sabado',
        'evidence': sentence,
        'uncertain_fields': [],
      },
    });

class QueueLlm implements LlmService {
  QueueLlm(this.outputs);
  final List<String> outputs;
  int calls = 0;
  String? lastGrammar;
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<LlmResult> complete(
    String prompt, {
    String? grammar,
    int maxTokens = 256,
  }) async {
    calls++;
    lastGrammar = grammar;
    return LlmResult(
      text: outputs.removeAt(0),
      elapsedMs: 1,
      generatedTokens: 1,
    );
  }
}

Extractor extractor(QueueLlm llm) => Extractor(
  llm,
  promptTemplate: '{{TRANSCRIPT}}',
  grammar: 'root ::= string\nstring ::= "x"',
);

void main() {
  test(
    'one local call cleans Taglish while retaining immutable raw speech',
    () async {
      final llm = QueueLlm([response()]);
      final run = await extractor(llm).extract(raw, spoken: true);
      expect(run.transcript, raw);
      expect(run.cleanedSentence, clean);
      expect(run.reviewTranscript, clean);
      expect(run.evidenceOk, isTrue);
      expect(llm.calls, 1);
      expect(llm.lastGrammar, contains('understood'));
    },
  );

  test('cleanup preserves names, amounts, dates, negation and role order', () {
    const source =
        'Hindi nagpautang si Ate Mary kay Jun ng 1,500 pesos, ah, sa Biyernes.';
    expect(
      isFaithfulCleanup(
        source,
        'Hindi nagpautang si Ate Mary kay Jun ng 1,500 pesos sa Biyernes.',
      ),
      isTrue,
    );
    for (final changed in [
      source.replaceFirst('Hindi ', ''),
      source.replaceFirst('Mary', 'Marie'),
      source.replaceFirst('1,500', '5,000'),
      source.replaceFirst('Biyernes', 'Sabado'),
      source.replaceFirst('si Ate Mary kay Jun', 'si Jun kay Ate Mary'),
      'Ate Mary lent Jun money.',
      'May hiniram na bagay.',
      '',
    ]) {
      expect(isFaithfulCleanup(source, changed), isFalse, reason: changed);
    }
  });

  test('known noise and unclear speech never reach the LLM', () async {
    for (final text in [
      '',
      '...',
      '[Buzzing]',
      '(silence)',
      '[Music]',
      'inaudible',
      'Thank you for watching.',
      'Hiniram ni [inaudible] ang drill.',
    ]) {
      final llm = QueueLlm([]);
      await expectLater(
        extractor(llm).extract(text, spoken: true),
        throwsA(isA<UnintelligibleSpeechException>()),
      );
      expect(llm.calls, 0, reason: text);
    }
  });

  test('understood=false does not retry or fabricate a review', () async {
    final llm = QueueLlm([
      jsonEncode({
        'understood': false,
        'cleaned_sentence': null,
        'memory': null,
      }),
    ]);
    await expectLater(
      extractor(llm).extract('Nga mas kawin stress tutut kapaw', spoken: true),
      throwsA(isA<UnintelligibleSpeechException>()),
    );
    expect(llm.calls, 1);
  });

  test(
    'malformed and unsupported cleanup retries once, then rejects',
    () async {
      for (final invalid in [
        'not json',
        response(sentence: 'Hiniram ni Ben ang saw.'),
        response(person: 'Kuya Ben'),
        jsonEncode({
          'understood': false,
          'cleaned_sentence': 'invented',
          'memory': null,
        }),
      ]) {
        final llm = QueueLlm([invalid, invalid]);
        await expectLater(
          extractor(llm).extract(raw, spoken: true),
          throwsA(isA<UnintelligibleSpeechException>()),
        );
        expect(llm.calls, 2);
      }
    },
  );

  test('valid second attempt succeeds', () async {
    final llm = QueueLlm(['not json', response()]);
    final run = await extractor(llm).extract(raw, spoken: true);
    expect(run.cleanedSentence, clean);
    expect(llm.calls, 2);
  });

  test(
    'structured fields reject fabricated amounts, dates and generic facts',
    () {
      final memory = jsonDecode(response())['memory'] as Map<String, dynamic>;
      expect(speechFieldsGrounded(memory, raw), isTrue);
      expect(speechFieldsGrounded({...memory, 'amount': 500}, raw), isFalse);
      expect(
        speechFieldsGrounded({...memory, 'due_date_text': 'sa Lunes'}, raw),
        isFalse,
      );
      expect(
        speechFieldsGrounded({...memory, 'item': 'something'}, raw),
        isFalse,
      );
      expect(
        isFaithfulCleanup(
          'Utang ni Jun ay -500 pesos.',
          'Utang ni Jun ay 500 pesos.',
        ),
        isFalse,
      );
      final money = {
        'kind': 'lent_money',
        'person': 'Jun',
        'item': null,
        'place': null,
        'due_date_text': 'sa Biyernes',
        'amount': 1500,
      };
      expect(
        speechFieldsGrounded(money, 'Utang ni Jun ay 1,500 pesos sa Biyernes.'),
        isTrue,
      );
      expect(
        speechFieldsGrounded({
          ...money,
          'amount': 5000,
        }, 'Utang ni Jun ay 1,500 pesos sa Biyernes.'),
        isFalse,
      );
    },
  );
}
