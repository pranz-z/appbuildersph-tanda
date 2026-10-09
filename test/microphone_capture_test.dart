import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/services/audio/recorder_service.dart';

void main() {
  test('Whisper accepts non-empty 16 kHz mono PCM WAV with signal', () {
    final inspection = inspectWhisperWav(_wav(samples: [1200, -2000]));

    expect(inspection.valid, isTrue, reason: inspection.error);
    expect(inspection.hasSignal, isTrue);
  });

  test('Whisper rejects malformed, wrong-format, and silent WAV files', () {
    final malformed = inspectWhisperWav(Uint8List(20));
    final wrongRate = inspectWhisperWav(_wav(sampleRate: 44100, samples: [1]));
    final silent = inspectWhisperWav(_wav(samples: [0, 0]));

    expect(malformed.valid, isFalse);
    expect(wrongRate.valid, isFalse);
    expect(wrongRate.error, contains('16 kHz mono WAV'));
    expect(silent.valid, isFalse);
    expect(silent.error, contains('Microphone access'));
    expect(silent.unintelligible, isTrue);
    expect(
      inspectWhisperWav(_wav(samples: [1, -2, 20])).unintelligible,
      isTrue,
    );
  });
}

Uint8List _wav({
  int sampleRate = 16000,
  int channels = 1,
  int bitsPerSample = 16,
  required List<int> samples,
}) {
  final dataSize = samples.length * 2;
  final bytes = ByteData(44 + dataSize);
  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, channels, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(
    28,
    sampleRate * channels * bitsPerSample ~/ 8,
    Endian.little,
  );
  bytes.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
  bytes.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}
