import 'dart:convert';

import '../../core/app_log.dart';
import '../../logic/speech_extraction.dart';
import '../../logic/extraction.dart';
import 'llm_service.dart';

class ExtractionRun {
  const ExtractionRun(
    this.transcript,
    this.llm,
    this.parse, {
    this.cleanedSentence,
  });
  final String? cleanedSentence;
  String get reviewTranscript => cleanedSentence ?? transcript;

  final String transcript;
  final LlmResult llm;
  final ExtractionParse parse;

  bool get evidenceOk {
    final evidence = parse.json?['evidence'];
    return evidence is String &&
        evidence.isNotEmpty &&
        reviewTranscript.contains(evidence);
  }
}

/// Transcript -> GBNF-constrained JSON via the LLM, then validated by code.
class Extractor {
  Extractor(
    this.llm, {
    required this.promptTemplate,
    required this.grammar,
    this.speechPromptTemplate,
  });
  final String? speechPromptTemplate;

  final LlmService llm;
  final String promptTemplate;
  final String grammar;

  Future<ExtractionRun> extract(
    String transcript, {
    bool spoken = false,
  }) async {
    if (spoken && isUnusableSpeech(transcript)) {
      appLog.i('Speech rejected before extraction: noise/empty');
      throw const UnintelligibleSpeechException();
    }
    Object? lastFailure;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final r = await llm.complete(
          buildExtractPrompt(
            spoken ? speechPromptTemplate ?? promptTemplate : promptTemplate,
            transcript,
          ),
          grammar: spoken ? _speechGrammar : grammar,
          maxTokens: spoken ? 320 : 200,
        );
        String? cleaned;
        var extractionText = r.text;
        if (spoken) {
          final result = jsonDecode(r.text);
          if (result is! Map<String, dynamic> ||
              result.length != 3 ||
              !result.containsKey('understood') ||
              !result.containsKey('cleaned_sentence') ||
              !result.containsKey('memory')) {
            throw const FormatException('Invalid speech response');
          }
          if (result['understood'] == false &&
              result['cleaned_sentence'] == null &&
              result['memory'] == null) {
            throw const UnintelligibleSpeechException();
          }
          cleaned = result['cleaned_sentence'] as String?;
          if (result['understood'] != true ||
              cleaned == null ||
              !isFaithfulCleanup(transcript, cleaned)) {
            throw const FormatException('Unsupported cleanup');
          }
          extractionText = jsonEncode(result['memory']);
        }
        final parse = parseExtraction(extractionText);
        final run = ExtractionRun(
          transcript,
          r,
          parse,
          cleanedSentence: cleaned,
        );
        if (spoken &&
            parse.valid &&
            !speechFieldsGrounded(parse.json!, transcript)) {
          throw const FormatException('Unsupported speech fields');
        }
        if (parse.valid && run.evidenceOk) {
          appLog.i(
            'LLM extract: transcriptChars=${transcript.length}, '
            '${r.elapsedMs} ms, prompt ${r.promptTokens} tok, '
            'gen ${r.generatedTokens} tok, '
            '${r.tokensPerSec.toStringAsFixed(1)} tok/s, '
            'valid=true, outputChars=${r.text.length}',
          );
          if (spoken) {
            appLog.i(
              'Speech cleanup accepted; original transcript retained; review required',
            );
          }
          return run;
        }
        lastFailure = StateError(
          parse.valid
              ? 'Evidence was not an exact transcript substring.'
              : 'Invalid extraction output: ${parse.errors.join(', ')}',
        );
      } on UnintelligibleSpeechException {
        appLog.i('Speech not understood; repeat required');
        rethrow;
      } catch (error) {
        lastFailure = error;
      }
    }

    if (spoken) {
      appLog.i('Speech validation failed after 2 attempts; repeat required');
      throw const UnintelligibleSpeechException();
    }
    appLog.i('LLM extraction failed after 2 attempts; manual entry required');
    throw StateError('Extraction failed after two attempts: $lastFailure');
  }

  String get _speechGrammar =>
      '${grammar.replaceFirst('root ::=', 'memory ::=')}\n'
      r'root ::= accepted | rejected'
      '\n'
      r'accepted ::= "{" "\"understood\":true," "\"cleaned_sentence\":" string "," "\"memory\":" memory "}"'
      '\n'
      r'rejected ::= "{\"understood\":false,\"cleaned_sentence\":null,\"memory\":null}"';
}
