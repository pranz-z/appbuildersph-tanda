class SttResult {
  const SttResult({
    required this.text,
    required this.elapsedMs,
    required this.audioMs,
  });

  final String text;

  /// Wall time spent decoding (read WAV + recognize), measured in the isolate.
  final int elapsedMs;

  /// Length of the input audio.
  final int audioMs;
}

/// Speech-to-text. The model is loaded once in [init], never per request.
abstract interface class SttService {
  Future<void> init();

  /// Transcribes a 16 kHz mono WAV file.
  Future<SttResult> transcribeFile(String wavPath);

  Future<void> dispose();
}

class FakeSttService implements SttService {
  @override
  Future<void> init() async {}

  @override
  Future<SttResult> transcribeFile(String wavPath) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const SttResult(
      text: 'Hiniram ni Kuya Jun yung drill, isosoli daw sa Sabado.',
      elapsedMs: 300,
      audioMs: 3000,
    );
  }

  @override
  Future<void> dispose() async {}
}
