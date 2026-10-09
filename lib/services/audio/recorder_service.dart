import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/app_log.dart';
import '../../logic/speech_extraction.dart';

abstract interface class AudioCaptureRecorder {
  Future<bool> hasPermission({bool request = true});
  Future<void> start();
  Future<String?> stop();
  Future<void> cancel();
}

class WavInspection {
  const WavInspection({
    required this.valid,
    this.hasSignal = false,
    this.error,
    this.unintelligible = false,
  });

  final bool valid;
  final bool hasSignal;
  final String? error;
  final bool unintelligible;
}

/// Checks the PCM WAV contract used by Whisper without logging audio samples.
WavInspection inspectWhisperWav(Uint8List bytes) {
  WavInspection invalid(String error) =>
      WavInspection(valid: false, error: error);

  if (bytes.length < 44) {
    return invalid(
      'The recording file is empty or incomplete. Try holding '
      'the microphone button longer.',
    );
  }
  final header = ByteData.sublistView(bytes);
  String ascii(int offset, int length) =>
      String.fromCharCodes(bytes.sublist(offset, offset + length));
  if (ascii(0, 4) != 'RIFF' ||
      ascii(8, 4) != 'WAVE' ||
      ascii(12, 4) != 'fmt ' ||
      ascii(36, 4) != 'data') {
    return invalid('The recorder did not create a readable WAV file.');
  }
  final format = header.getUint16(20, Endian.little);
  final channels = header.getUint16(22, Endian.little);
  final sampleRate = header.getUint32(24, Endian.little);
  final bitsPerSample = header.getUint16(34, Endian.little);
  final dataSize = header.getUint32(40, Endian.little);
  if (format != 1 ||
      channels != 1 ||
      sampleRate != 16000 ||
      bitsPerSample != 16) {
    return invalid(
      'Whisper needs a 16 kHz mono WAV recording. The recorder '
      'returned ${sampleRate}Hz, $channels channel(s), $bitsPerSample-bit PCM.',
    );
  }
  if (dataSize == 0 || dataSize % 2 != 0 || bytes.length < 44 + dataSize) {
    return invalid('The recording file has no complete audio data. Try again.');
  }
  var hasSignal = false;
  for (var i = 44; i < 44 + dataSize; i += 2) {
    if (header.getInt16(i, Endian.little).abs() > 32) {
      hasSignal = true;
      break;
    }
  }
  if (!hasSignal) {
    return const WavInspection(
      valid: false,
      unintelligible: true,
      error:
          'Hindi ko maintindihan. Pakisabi ulit. No microphone audio was captured. Check Android Quick '
          'Settings > Microphone access and vivo Privacy settings, then try again.',
    );
  }
  return const WavInspection(valid: true, hasSignal: true);
}

/// Hold-to-talk recorder: 16 kHz mono 16-bit WAV, saved in app storage.
class RecorderService implements AudioCaptureRecorder {
  final _recorder = AudioRecorder();
  Future<void>? _starting;
  String? _activePath;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    final granted = await _recorder.hasPermission(request: request);
    appLog.i('Microphone permission check: request=$request, granted=$granted');
    return granted;
  }

  Future<String> clipsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'clips'));
    await dir.create(recursive: true);
    return dir.path;
  }

  @override
  Future<void> start() async {
    if (_starting != null) {
      throw StateError('A microphone recording is already active.');
    }
    final path = p.join(
      await clipsDir(),
      'clip_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    _activePath = path;
    appLog.i(
      'Recording start requested: path=$path, format=wav, '
      'sampleRate=16000, channels=1',
    );
    final start = _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _starting = start;
    try {
      await start;
      appLog.i('Recording started: path=$path');
    } catch (e, st) {
      appLog.e('Recording start failed: path=$path', e, st);
      _starting = null;
      _activePath = null;
      rethrow;
    }
  }

  /// Returns the WAV path, or null if nothing was recorded.
  @override
  Future<String?> stop() async {
    final starting = _starting;
    if (starting == null) return null;
    final activePath = _activePath;
    try {
      // If the user releases before start() finished, wait for it first.
      await starting;
      final path = await _recorder.stop() ?? activePath;
      appLog.i('Recording stopped: path=$path');
      if (path == null) {
        throw StateError('The recorder did not return an audio file.');
      }
      final file = File(path);
      if (!await file.exists()) {
        throw StateError('The recording file was not created.');
      }
      final bytes = await file.readAsBytes();
      final inspection = inspectWhisperWav(bytes);
      appLog.i(
        'Recording file: path=$path, bytes=${bytes.length}, '
        'whisperWavValid=${inspection.valid}, '
        'hasSignal=${inspection.hasSignal}',
      );
      if (inspection.unintelligible) {
        throw const UnintelligibleSpeechException();
      }
      if (!inspection.valid) throw StateError(inspection.error!);
      return path;
    } catch (e, st) {
      appLog.e(
        'Recording stop/file validation failed: path=$activePath',
        e,
        st,
      );
      rethrow;
    } finally {
      _starting = null;
      _activePath = null;
    }
  }

  /// Cancels and removes the current clip when the touch gesture is cancelled.
  @override
  Future<void> cancel() async {
    final starting = _starting;
    final path = _activePath;
    if (starting == null) return;
    try {
      await starting;
      await _recorder.cancel();
      appLog.i('Recording cancelled: path=$path');
    } catch (e, st) {
      appLog.e('Recording cancel failed: path=$path', e, st);
      rethrow;
    } finally {
      _starting = null;
      _activePath = null;
    }
  }

  Future<void> dispose() => _recorder.dispose();
}
