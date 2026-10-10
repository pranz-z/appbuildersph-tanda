// Run one transcript through the typed-input extraction prompt + grammar on
// desktop. Shows exactly what the model would store for that sentence.
// Validates format only; timings here are laptop numbers, NOT phone numbers.
//
// Usage: dart run tool/extract_sentence.dart <path-to-gguf> "transcript"
import 'dart:io';

import 'package:llamadart/llamadart.dart';
import 'package:tanda/logic/extraction.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/extract_sentence.dart <gguf> "transcript"',
    );
    exitCode = 2;
    return;
  }
  final engine = LlamaEngine(LlamaBackend());
  await engine.loadModel(
    args[0],
    modelParams: const ModelParams(
      contextSize: 1024,
      gpuLayers: 0,
      preferredBackend: GpuBackend.cpu,
      numberOfThreads: 4,
    ),
  );
  final template = File('assets/extract_prompt.txt').readAsStringSync();
  final grammar = File('assets/extract.gbnf').readAsStringSync();
  final prompt = buildExtractPrompt(template, args[1]);
  final sw = Stopwatch()..start();
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
  final parse = parseExtraction(out);
  stdout.writeln('raw: $out');
  stdout.writeln('valid: ${parse.valid} ${parse.errors}');
  stdout.writeln(
    'evidenceInTranscript: ${evidenceInTranscript(parse.json?['evidence'] as String?, args[1])}',
  );
  stdout.writeln('elapsed: ${sw.elapsedMilliseconds} ms (desktop, not phone)');
  await engine.dispose();
}
