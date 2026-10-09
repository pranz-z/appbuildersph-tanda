class LlmResult {
  const LlmResult({
    required this.text,
    required this.elapsedMs,
    required this.generatedTokens,
    this.promptTokens,
  });

  final String text;
  final int elapsedMs;
  final int generatedTokens;
  final int? promptTokens;

  double get tokensPerSec =>
      elapsedMs == 0 ? 0 : generatedTokens * 1000 / elapsedMs;
}

/// Local LLM. Only returns raw text; parsing and validation are plain Dart
/// in lib/logic. Loaded once in [init], never per request.
abstract interface class LlmService {
  Future<void> init();

  /// Runs one completion. When [grammar] (GBNF) is given, output is
  /// constrained to it.
  Future<LlmResult> complete(
    String prompt, {
    String? grammar,
    int maxTokens = 256,
  });

  Future<void> dispose();
}

class FakeLlmService implements LlmService {
  @override
  Future<void> init() async {}

  @override
  Future<LlmResult> complete(
    String prompt, {
    String? grammar,
    int maxTokens = 256,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final text = grammar != null
        ? '{"kind":"lent_item","person":"Kuya Jun","item":"drill",'
              '"place":null,"amount":null,"due_date_text":"sa Sabado",'
              '"evidence":"Hiniram ni Kuya Jun yung drill",'
              '"uncertain_fields":[]}'
        : 'Si Kuya Jun ang may hawak ng drill mo.';
    return LlmResult(text: text, elapsedMs: 300, generatedTokens: 40);
  }

  @override
  Future<void> dispose() async {}
}
