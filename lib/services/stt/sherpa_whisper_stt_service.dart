import 'dart:async';
import 'dart:isolate';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../core/model_locator.dart';
import 'stt_service.dart';

/// Whisper via sherpa-onnx, running in one long-lived background isolate.
/// The recognizer is created once in [init] and reused for every request.
class SherpaWhisperSttService implements SttService {
  SherpaWhisperSttService(
    this.paths, {
    this.language = 'tl',
    this.numThreads = 4,
  });

  final WhisperPaths paths;

  /// Whisper language code. '' = auto-detect.
  final String language;
  final int numThreads;

  Isolate? _isolate;
  ReceivePort? _fromIsolate;
  SendPort? _toIsolate;
  final _pending = <int, Completer<SttResult>>{};
  int _nextId = 0;

  /// Model load time measured inside the isolate.
  int? loadMs;

  @override
  Future<void> init() async {
    if (_toIsolate != null) return;
    final rp = ReceivePort();
    _fromIsolate = rp;
    final ready = Completer<void>();

    rp.listen((msg) {
      final m = msg as Map;
      if (m.containsKey('ready')) {
        _toIsolate = m['ready'] as SendPort;
        loadMs = m['loadMs'] as int;
        ready.complete();
      } else if (m.containsKey('initError')) {
        ready.completeError(
          StateError('Whisper load failed: ${m['initError']}'),
        );
      } else {
        final c = _pending.remove(m['id'] as int);
        if (c == null) return;
        if (m.containsKey('error')) {
          c.completeError(StateError(m['error'] as String));
        } else {
          c.complete(
            SttResult(
              text: m['text'] as String,
              elapsedMs: m['ms'] as int,
              audioMs: m['audioMs'] as int,
            ),
          );
        }
      }
    });

    _isolate = await Isolate.spawn(_sttIsolateMain, {
      'reply': rp.sendPort,
      'encoder': paths.encoder,
      'decoder': paths.decoder,
      'tokens': paths.tokens,
      'language': language,
      'numThreads': numThreads,
    }, debugName: 'stt');
    await ready.future;
  }

  @override
  Future<SttResult> transcribeFile(String wavPath) {
    final port = _toIsolate;
    if (port == null) throw StateError('SttService not initialized');
    final id = _nextId++;
    final c = Completer<SttResult>();
    _pending[id] = c;
    port.send({'id': id, 'path': wavPath});
    return c.future;
  }

  @override
  Future<void> dispose() async {
    _isolate?.kill(priority: Isolate.immediate);
    _fromIsolate?.close();
    _isolate = null;
    _toIsolate = null;
    for (final c in _pending.values) {
      c.completeError(StateError('SttService disposed'));
    }
    _pending.clear();
  }
}

void _sttIsolateMain(Map<String, Object> args) {
  final reply = args['reply'] as SendPort;
  final sw = Stopwatch()..start();
  final sherpa.OfflineRecognizer recognizer;
  try {
    // FFI bindings are per-isolate, so init here, not on the main isolate.
    sherpa.initBindings();
    recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: args['encoder'] as String,
            decoder: args['decoder'] as String,
            language: args['language'] as String,
            task: 'transcribe',
          ),
          tokens: args['tokens'] as String,
          numThreads: args['numThreads'] as int,
          debug: false,
        ),
      ),
    );
  } catch (e) {
    reply.send({'initError': e.toString()});
    return;
  }

  final inbox = ReceivePort();
  reply.send({'ready': inbox.sendPort, 'loadMs': sw.elapsedMilliseconds});

  inbox.listen((msg) {
    final m = msg as Map;
    final id = m['id'] as int;
    try {
      final t = Stopwatch()..start();
      final wave = sherpa.readWave(m['path'] as String);
      if (wave.sampleRate == 0) throw StateError('Could not read WAV');
      final stream = recognizer.createStream();
      stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
      recognizer.decode(stream);
      final text = recognizer.getResult(stream).text.trim();
      stream.free();
      reply.send({
        'id': id,
        'text': text,
        'ms': t.elapsedMilliseconds,
        'audioMs': wave.samples.length * 1000 ~/ wave.sampleRate,
      });
    } catch (e) {
      reply.send({'id': id, 'error': e.toString()});
    }
  });
}
