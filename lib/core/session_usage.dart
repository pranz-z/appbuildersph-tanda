import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/llm/llm_service.dart';
import '../services/stt/stt_service.dart';

class SessionUsageState {
  const SessionUsageState({
    this.transcriptionCalls = 0,
    this.llmCalls = 0,
    this.embeddingCalls = 0,
  });

  final int transcriptionCalls;
  final int llmCalls;
  final int embeddingCalls;

  SessionUsageState copyWith({
    int? transcriptionCalls,
    int? llmCalls,
    int? embeddingCalls,
  }) => SessionUsageState(
    transcriptionCalls: transcriptionCalls ?? this.transcriptionCalls,
    llmCalls: llmCalls ?? this.llmCalls,
    embeddingCalls: embeddingCalls ?? this.embeddingCalls,
  );
}

class SessionUsage extends Notifier<SessionUsageState> {
  @override
  SessionUsageState build() => const SessionUsageState();

  void recordTranscriptionCall() {
    state = state.copyWith(transcriptionCalls: state.transcriptionCalls + 1);
  }

  void recordLlmCall() {
    state = state.copyWith(llmCalls: state.llmCalls + 1);
  }

  void recordEmbeddingCall() {
    state = state.copyWith(embeddingCalls: state.embeddingCalls + 1);
  }
}

final sessionUsageProvider = NotifierProvider<SessionUsage, SessionUsageState>(
  SessionUsage.new,
);

/// Counts a call as soon as the application starts it, including failures.
class MeteredSttService implements SttService {
  MeteredSttService(this.inner, {required this.onCall});

  final SttService inner;
  final void Function() onCall;

  @override
  Future<void> init() => inner.init();

  @override
  Future<SttResult> transcribeFile(String wavPath) {
    onCall();
    return inner.transcribeFile(wavPath);
  }

  @override
  Future<void> dispose() => inner.dispose();
}

class MeteredLlmService implements LlmService {
  MeteredLlmService(this.inner, {required this.onCall});

  final LlmService inner;
  final void Function() onCall;

  @override
  Future<void> init() => inner.init();

  @override
  Future<LlmResult> complete(
    String prompt, {
    String? grammar,
    int maxTokens = 256,
  }) {
    onCall();
    return inner.complete(prompt, grammar: grammar, maxTokens: maxTokens);
  }

  @override
  Future<void> dispose() => inner.dispose();
}
