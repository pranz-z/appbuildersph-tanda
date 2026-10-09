import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio/recorder_service.dart';
import '../services/embedding/embedding_service.dart';
import '../services/llm/extractor.dart';
import '../services/llm/llamadart_llm_service.dart';
import '../services/llm/llm_service.dart';
import '../services/stt/sherpa_whisper_stt_service.dart';
import '../services/stt/stt_service.dart';
import 'app_log.dart';
import 'memory_info.dart';
import 'model_locator.dart';

final modelLocatorProvider = Provider((ref) => ModelLocator());

/// Whisper language: 'tl' (Tagalog), 'en', or '' (auto-detect).
class SttLanguage extends Notifier<String> {
  @override
  String build() => 'tl';

  void set(String code) => state = code;
}

final sttLanguageProvider = NotifierProvider<SttLanguage, String>(
  SttLanguage.new,
);

/// Real Whisper STT, loaded once and kept alive. Changing the language or
/// importing models reloads it. Errors surface to the UI, no auto-retry.
final sttServiceProvider = FutureProvider<SttService>((ref) async {
  final language = ref.watch(sttLanguageProvider);
  final check = await ref.read(modelLocatorProvider).checkWhisper();
  if (!check.ok) {
    appLog.i('Whisper missing: ${check.missing.map((s) => s.name).join(', ')}');
    throw ModelMissingException(check.errorMessage);
  }
  final paths = check.paths!;
  final stt = SherpaWhisperSttService(paths, language: language);
  ref.onDispose(stt.dispose);
  appLog.i(
    'Loading Whisper ${paths.variant.name} int8, '
    'lang=${language.isEmpty ? 'auto' : language}, '
    'threads=${stt.numThreads}, encoder=${paths.encoder}',
  );
  try {
    await stt.init();
  } catch (e, st) {
    appLog.e('Whisper init failed', e, st);
    rethrow;
  }
  appLog.i('Whisper loaded in ${stt.loadMs} ms');
  return stt;
}, retry: (_, _) => null);

final recorderServiceProvider = Provider((ref) {
  final r = RecorderService();
  ref.onDispose(r.dispose);
  return r;
});

/// Real LLM (llama.cpp via llamadart), loaded once at app start and kept
/// alive. Importing models reloads it. Errors surface to the UI, no retry.
final llmServiceProvider = FutureProvider<LlmService>((ref) async {
  final String path;
  try {
    path = await ref.read(modelLocatorProvider).requireLlm();
  } on ModelMissingException {
    appLog.i('LLM missing: ${llmSpec.name}');
    rethrow;
  }
  final llm = LlamadartLlmService(path);
  ref.onDispose(llm.dispose);
  appLog.i(
    'Loading LLM ${llmSpec.name}, threads=${llm.numThreads}, '
    'ctx=${llm.contextSize}, cpu only',
  );
  try {
    await llm.init();
  } catch (e, st) {
    appLog.e('LLM init failed', e, st);
    rethrow;
  }
  appLog.i(
    'LLM loaded in ${llm.loadMs} ms; memory: ${residentMemorySummary()}',
  );
  return llm;
}, retry: (_, _) => null);

final extractorProvider = FutureProvider<Extractor>((ref) async {
  final llm = await ref.watch(llmServiceProvider.future);
  return Extractor(
    llm,
    promptTemplate: await rootBundle.loadString('assets/extract_prompt.txt'),
    grammar: await rootBundle.loadString('assets/extract.gbnf'),
  );
}, retry: (_, _) => null);

/// Embedding model files (not loaded yet; checked so the first-run screen
/// can list them).
final embeddingFilesMissingProvider = FutureProvider<List<ModelFileSpec>>(
  (ref) => ref.read(modelLocatorProvider).missingOf(embeddingSpecs),
);

final embeddingServiceProvider = Provider<EmbeddingService>(
  (ref) => FakeEmbeddingService(),
);
