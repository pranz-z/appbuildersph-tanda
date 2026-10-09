import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/services/llm/extractor.dart';
import 'package:tanda/services/llm/llm_service.dart';

const _transcript = 'Hiniram ni Jun ang drill.';

String _output({
  String evidence = _transcript,
  List<String> uncertain = const [],
}) => jsonEncode({
  'kind': 'lent_item',
  'person': 'Jun',
  'item': 'drill',
  'place': null,
  'amount': null,
  'due_date_text': null,
  'evidence': evidence,
  'uncertain_fields': uncertain,
});

class _QueueLlm implements LlmService {
  _QueueLlm(this.responses);

  final List<Object> responses;
  var calls = 0;

  @override
  Future<void> init() async {}

  @override
  Future<LlmResult> complete(
    String prompt, {
    String? grammar,
    int maxTokens = 256,
  }) async {
    calls++;
    final response = responses.removeAt(0);
    if (response is Exception || response is Error) throw response;
    return LlmResult(
      text: response as String,
      elapsedMs: 1,
      generatedTokens: 1,
    );
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('retries invalid output once and returns the valid retry', () async {
    final llm = _QueueLlm(['not json', _output()]);
    final extractor = Extractor(
      llm,
      promptTemplate: '{{TRANSCRIPT}}',
      grammar: '',
    );

    final run = await extractor.extract(_transcript);

    expect(llm.calls, 2);
    expect(run.parse.valid, isTrue);
    expect(run.evidenceOk, isTrue);
  });

  test('retries an extraction exception once', () async {
    final llm = _QueueLlm([StateError('first attempt failed'), _output()]);
    final extractor = Extractor(
      llm,
      promptTemplate: '{{TRANSCRIPT}}',
      grammar: '',
    );

    final run = await extractor.extract(_transcript);

    expect(llm.calls, 2);
    expect(run.parse.valid, isTrue);
  });

  test('retries evidence that is not in the transcript', () async {
    final llm = _QueueLlm([_output(evidence: 'invented quote'), _output()]);
    final extractor = Extractor(
      llm,
      promptTemplate: '{{TRANSCRIPT}}',
      grammar: '',
    );

    final run = await extractor.extract(_transcript);

    expect(llm.calls, 2);
    expect(run.evidenceOk, isTrue);
  });

  test('throws after the retry is invalid', () async {
    final llm = _QueueLlm(['not json', 'still not json']);
    final extractor = Extractor(
      llm,
      promptTemplate: '{{TRANSCRIPT}}',
      grammar: '',
    );

    await expectLater(extractor.extract(_transcript), throwsStateError);
    expect(llm.calls, 2);
  });
}
