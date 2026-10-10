import 'dart:async';
import 'dart:convert';

import '../core/app_database.dart';
import '../services/llm/llm_service.dart';
import 'local_memory_ask.dart';

/// Optional polish stage after deterministic retrieval finds exactly one
/// confirmed memory. The on-device LLM only rewrites that single record into
/// a natural Taglish/English sentence; it never sees other memories and its
/// output is validated against the record before it is shown. Any failure —
/// malformed JSON, ids other than the candidate's, unsupported claims,
/// model error, timeout — returns null and the caller keeps the template.
class GroundedAnswerer {
  GroundedAnswerer({
    this.grammar = defaultGrammar,
    this.timeout = const Duration(seconds: 30),
    this.maxAnswerChars = 200,
  });

  /// GBNF constraining output to {"answer": string, "used_ids": [string]}.
  /// Kept in code (not an asset) so the ask path needs no I/O.
  static const defaultGrammar = '''
root ::= "{" "\\"answer\\":" string "," "\\"used_ids\\":" ids "}"
ids ::= "[" ( string ( "," string )* )? "]"
string ::= "\\"" char* "\\""
char ::= [^"\\\\\\x00-\\x1F] | "\\\\" ["\\\\/bfnrt]
''';

  /// GBNF constraining output to {"answer": string, "used_ids": [string]}.
  final String? grammar;
  final Duration timeout;
  final int maxAnswerChars;

  Future<String?> answer({
    required LlmService llm,
    required String question,
    required StoredMemory memory,
  }) async {
    final LlmResult result;
    try {
      result = await llm
          .complete(
            _prompt(question, memory),
            grammar: grammar,
            maxTokens: 96,
          )
          .timeout(timeout);
    } catch (_) {
      return null;
    }
    return validate(result.text, memory);
  }

  /// Parses and grounds-checks raw model output. Returns the answer sentence
  /// only if it is shaped correctly, cites solely [memory], and every content
  /// token it makes is supported by that record.
  String? validate(String raw, StoredMemory memory) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw.substring(start, end + 1));
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final answer = decoded['answer'];
    if (answer is! String) return null;
    final text = answer.trim();
    // Degenerate outputs (empty, one bare word, overlong, multi-line) add
    // nothing over the deterministic template — reject them.
    if (text.isEmpty ||
        text.length > maxAnswerChars ||
        text.contains('\n') ||
        _rawTokens(text).length < 2) {
      return null;
    }
    final ids = decoded['used_ids'];
    if (ids is! List || ids.isEmpty) return null;
    for (final id in ids) {
      if (id != memory.uid) return null;
    }
    if (!isGrounded(text, memory)) return null;
    return text;
  }

  /// Every content token of the answer must exist in the cited record's
  /// canonical token set (fields, transcript, evidence, amount spellings).
  /// Function words are skipped; an unsupported name, item, number, date,
  /// or status word rejects the answer.
  static bool isGrounded(String answer, StoredMemory memory) {
    final record = _recordTokens(memory);
    for (final raw in _rawTokens(answer)) {
      if (LocalMemoryAsk.isFillerWord(raw)) continue;
      // Record tokens are canonical; the answer token must meet them in
      // the same space ("humiram" in the answer matches "borrowed" stored).
      if (record.contains(_canonical(raw))) continue;
      return false;
    }
    return true;
  }

  static Set<String> _recordTokens(StoredMemory memory) {
    final tokens = <String>{};
    for (final field in [
      memory.person,
      memory.item,
      memory.place,
      memory.dueDateText,
      memory.kind,
      memory.status,
      memory.transcript,
      memory.evidence,
    ]) {
      if (field != null) tokens.addAll(LocalMemoryAsk.contentTokens(field));
    }
    final amount = memory.amount;
    if (amount != null) {
      tokens.addAll(LocalMemoryAsk.contentTokens(amount.toString()));
      if (amount == amount.roundToDouble()) {
        tokens.addAll(LocalMemoryAsk.contentTokens(amount.toStringAsFixed(0)));
      }
      tokens.addAll(
        LocalMemoryAsk.contentTokens(_commaAmount(amount)),
      );
      // Money words are implied by a stored amount even if the transcript
      // phrased it differently.
      tokens.addAll(LocalMemoryAsk.contentTokens('utang pera pesos php'));
    }
    return tokens;
  }

  static String _commaAmount(double amount) {
    final raw = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    final parts = raw.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return parts.length == 1 ? whole : '$whole.${parts.last}';
  }

  /// Raw lowercase tokens of the answer, before canonicalization.
  static Iterable<String> _rawTokens(String value) sync* {
    for (final token in _normalize(value).split(' ')) {
      if (token.isNotEmpty) yield token;
    }
  }

  static String _canonical(String token) =>
      LocalMemoryAsk.contentTokens(token).first;

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _prompt(String question, StoredMemory memory) {
    final record = jsonEncode({
      'id': memory.uid,
      'kind': memory.kind,
      'person': memory.person,
      'item': memory.item,
      'place': memory.place,
      'amount': memory.amount,
      'due': memory.dueDateText,
      'status': memory.status,
      'transcript': memory.transcript,
      'evidence': memory.evidence,
    });
    return '<|im_start|>system\n'
        'Answer the question using ONLY the confirmed memory below. '
        'One short sentence in Taglish or English. '
        'Never add a name, item, amount, date, or status that is not in the memory. '
        'Reply with JSON only: {"answer":"...","used_ids":["${memory.uid}"]}<|im_end|>\n'
        '<|im_start|>user\n'
        'Question: $question\n'
        'Memory: $record<|im_end|>\n'
        '<|im_start|>assistant\n';
  }
}
