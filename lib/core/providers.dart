import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/embedding/embedding_service.dart';
import '../services/llm/llm_service.dart';
import '../services/stt/stt_service.dart';

// Swap Fake* for real implementations here once each spike passes.
final sttServiceProvider = Provider<SttService>((ref) => FakeSttService());
final llmServiceProvider = Provider<LlmService>((ref) => FakeLlmService());
final embeddingServiceProvider =
    Provider<EmbeddingService>((ref) => FakeEmbeddingService());
