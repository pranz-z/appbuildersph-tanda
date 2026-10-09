import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio/recorder_service.dart';
import '../services/embedding/embedding_service.dart';
import '../services/llm/llm_service.dart';
import '../services/stt/sherpa_whisper_stt_service.dart';
import '../services/stt/stt_service.dart';
import 'app_log.dart';
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

// Swap Fake* for real implementations here once each spike passes.
final llmServiceProvider = Provider<LlmService>((ref) => FakeLlmService());
final embeddingServiceProvider = Provider<EmbeddingService>(
  (ref) => FakeEmbeddingService(),
);
