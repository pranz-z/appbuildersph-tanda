import 'dart:async';

import 'package:llamadart/llamadart.dart';

import 'llm_service.dart';

/// llama.cpp through the llamadart package. llamadart runs llama.cpp in its
/// own long-lived worker isolate; this class only sends requests to it.
/// CPU only (no GPU offload) for predictability on the phone.
class LlamadartLlmService implements LlmService {
  LlamadartLlmService(
    this.modelPath, {
    this.contextSize = 1024,
    this.numThreads = 4,
    this.loadTimeout = const Duration(minutes: 3),
  });

  final String modelPath;
  final int contextSize;
  final int numThreads;
  final Duration loadTimeout;

  LlamaEngine? _engine;
  int? loadMs;

  @override
  Future<void> init() async {
    if (_engine != null) return;
    final engine = LlamaEngine(LlamaBackend());
    final sw = Stopwatch()..start();
    try {
      await engine
          .loadModel(
            modelPath,
            modelParams: ModelParams(
              contextSize: contextSize,
              gpuLayers: 0,
              preferredBackend: GpuBackend.cpu,
              numberOfThreads: numThreads,
              numberOfThreadsBatch: numThreads,
            ),
          )
          .timeout(loadTimeout);
    } on TimeoutException {
      unawaited(engine.dispose());
      throw StateError('LLM load timed out after ${loadTimeout.inSeconds} s');
    } catch (_) {
      unawaited(engine.dispose());
      rethrow;
    }
    loadMs = sw.elapsedMilliseconds;
    _engine = engine;
  }

  @override
  Future<LlmResult> complete(
    String prompt, {
    String? grammar,
    int maxTokens = 256,
  }) async {
    final engine = _engine;
    if (engine == null) throw StateError('LlmService not ready');
    final promptTokens = await engine.getTokenCount(prompt);
    final sw = Stopwatch()..start();
    final out = StringBuffer();
    await for (final piece in engine.generate(
      prompt,
      params: GenerationParams(
        maxTokens: maxTokens,
        temp: 0, // greedy: deterministic extraction
        seed: 42,
        penalty: 1.0, // repetition penalty hurts JSON keys/quotes
        grammar: grammar,
      ),
    )) {
      out.write(piece);
    }
    final elapsed = sw.elapsedMilliseconds;
    final text = out.toString();
    return LlmResult(
      text: text,
      elapsedMs: elapsed,
      generatedTokens: await engine.getTokenCount(text),
      promptTokens: promptTokens,
    );
  }

  @override
  Future<void> dispose() async {
    final e = _engine;
    _engine = null;
    await e?.dispose();
  }
}
