// Desktop sanity check of the extraction grammar + prompt with the real GGUF.
// Validates JSON validity only; timings here are laptop numbers, NOT phone
// numbers, and must not go into MEASUREMENTS.md.
//
// Usage: dart run tool/llm_desktop_check.dart <path-to-gguf>
import 'dart:io';

import 'package:llamadart/llamadart.dart';
import 'package:tanda/logic/extraction.dart';
import 'package:tanda/logic/test_sentences.dart';

Future<void> main(List<String> args) async {
  final engine = LlamaEngine(LlamaBackend());
  await engine.loadModel(
    args.single,
    modelParams: const ModelParams(
      contextSize: 1024,
      gpuLayers: 0,
      preferredBackend: GpuBackend.cpu,
      numberOfThreads: 4,
    ),
  );
  final template = File('assets/extract_prompt.txt').readAsStringSync();
  final grammar = File('assets/extract.gbnf').readAsStringSync();
  final sentences = parseTestSentences(
    File('test_sentences.md').readAsStringSync(),
  );
  var valid = 0;
  for (final (i, s) in sentences.indexed) {
    final prompt = buildExtractPrompt(template, s);
    final out = await engine
        .generate(
          prompt,
          params: GenerationParams(
            maxTokens: 200,
            temp: 0,
            seed: 42,
            penalty: 1.0,
            grammar: grammar,
          ),
        )
        .join();
    final p = parseExtraction(out);
    if (p.valid) valid++;
    final ev = evidenceInTranscript(p.json?['evidence'] as String?, s);
    stdout.writeln(
      '${i + 1} valid=${p.valid} evidence=$ev '
      'promptTok=${await engine.getTokenCount(prompt)} $out',
    );
  }
  stdout.writeln('VALID $valid/${sentences.length}');
  await engine.dispose();
}
