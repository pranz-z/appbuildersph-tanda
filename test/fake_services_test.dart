import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/services/embedding/embedding_service.dart';
import 'package:tanda/services/llm/llm_service.dart';
import 'package:tanda/services/stt/stt_service.dart';

void main() {
  test('fake STT returns a transcript', () async {
    expect(await FakeSttService().transcribeFile('x.wav'), isNotEmpty);
  });

  test('fake LLM returns parseable JSON when a grammar is given', () async {
    final out = await FakeLlmService().complete('p', grammar: 'root ::= x');
    expect((jsonDecode(out) as Map)['kind'], 'lent_item');
  });

  test('fake embeddings are deterministic unit vectors', () async {
    final e = FakeEmbeddingService();
    final a = await e.embedPassage('drill');
    final b = await e.embedPassage('drill');
    expect(a.length, e.dimension);
    expect(a, b);
    final norm = a.fold<double>(0, (s, x) => s + x * x);
    expect(norm, closeTo(1.0, 1e-4));
  });
}
