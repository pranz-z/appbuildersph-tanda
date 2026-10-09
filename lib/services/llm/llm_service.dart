/// Local LLM. Real implementation will wrap llama.cpp (GGUF) in an isolate.
/// It only returns raw text; parsing and validation happen in lib/logic.
abstract interface class LlmService {
  Future<void> init();

  /// Runs one completion. When [grammar] (GBNF) is given, output is
  /// constrained to it.
  Future<String> complete(
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
  Future<String> complete(
    String prompt, {
    String? grammar,
    int maxTokens = 256,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (grammar != null) {
      return '{"kind":"lent_item","person":"Kuya Jun","item":"drill",'
          '"place":null,"amount":null,"due_date_text":"sa Sabado",'
          '"evidence":"Hiniram ni Kuya Jun yung drill",'
          '"uncertain_fields":[]}';
    }
    return 'Si Kuya Jun ang may hawak ng drill mo.';
  }

  @override
  Future<void> dispose() async {}
}
