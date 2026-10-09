/// Speech-to-text. Real implementation will wrap sherpa_onnx (Whisper) in an
/// isolate; the model is loaded once in [init], never per request.
abstract interface class SttService {
  Future<void> init();

  /// Transcribes a 16 kHz mono WAV file.
  Future<String> transcribeFile(String wavPath);

  Future<void> dispose();
}

class FakeSttService implements SttService {
  @override
  Future<void> init() async {}

  @override
  Future<String> transcribeFile(String wavPath) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return 'Hiniram ni Kuya Jun yung drill, isosoli daw sa Sabado.';
  }

  @override
  Future<void> dispose() async {}
}
