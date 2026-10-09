import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Hold-to-talk recorder: 16 kHz mono 16-bit WAV, saved in app storage.
class RecorderService {
  final _recorder = AudioRecorder();
  Future<void>? _starting;

  Future<bool> ensurePermission() => _recorder.hasPermission();

  Future<String> clipsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'clips'));
    await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> start() {
    return _starting = () async {
      final path = p.join(
        await clipsDir(),
        'clip_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
    }();
  }

  /// Returns the WAV path, or null if nothing was recorded.
  Future<String?> stop() async {
    // If the user releases before start() finished, wait for it first.
    await _starting;
    _starting = null;
    return _recorder.stop();
  }

  Future<void> dispose() => _recorder.dispose();
}
