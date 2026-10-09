import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio/recorder_service.dart';
import '../services/embedding/embedding_service.dart';
import '../services/llm/llm_service.dart';
import '../services/stt/sherpa_whisper_stt_service.dart';
import '../services/stt/stt_service.dart';
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

/// Real Whisper STT, loaded once and kept alive. Changing the language
/// reloads it (debug only). Missing models surface as an error, no retries.
final sttServiceProvider = FutureProvider<SttService>((ref) async {
  final language = ref.watch(sttLanguageProvider);
  final check = await ref.read(modelLocatorProvider).checkWhisper();
  if (!check.ok) throw ModelMissingException(check.errorMessage);
  final stt = SherpaWhisperSttService(check.paths!, language: language);
  ref.onDispose(stt.dispose);
  await stt.init();
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
