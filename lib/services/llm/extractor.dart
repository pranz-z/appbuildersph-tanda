import '../../core/app_log.dart';
import '../../logic/extraction.dart';
import 'llm_service.dart';

class ExtractionRun {
  const ExtractionRun(this.transcript, this.llm, this.parse);

  final String transcript;
  final LlmResult llm;
  final ExtractionParse parse;

  bool get evidenceOk =>
      evidenceInTranscript(parse.json?['evidence'] as String?, transcript);
}

/// Transcript -> GBNF-constrained JSON via the LLM, then validated by code.
class Extractor {
  Extractor(this.llm, {required this.promptTemplate, required this.grammar});

  final LlmService llm;
  final String promptTemplate;
  final String grammar;

  Future<ExtractionRun> extract(String transcript) async {
    try {
      final r = await llm.complete(
        buildExtractPrompt(promptTemplate, transcript),
        grammar: grammar,
        maxTokens: 200,
      );
      final parse = parseExtraction(r.text);
      appLog.i(
        'LLM extract: ${r.elapsedMs} ms, prompt ${r.promptTokens} tok, '
        'gen ${r.generatedTokens} tok, '
        '${r.tokensPerSec.toStringAsFixed(1)} tok/s, '
        'valid=${parse.valid}${parse.errors.isEmpty ? '' : ' ${parse.errors}'}, '
        'out=${r.text}',
      );
      return ExtractionRun(transcript, r, parse);
    } catch (e, st) {
      appLog.e('LLM extract failed for "$transcript"', e, st);
      rethrow;
    }
  }
}
