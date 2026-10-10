import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/app_log.dart';
import 'tts_service.dart';

/// Android on-device TTS through flutter_tts (android.speech.tts). Only
/// voices whose data is installed locally are ever used; the engine is
/// never given text it would send to a network voice.
class FlutterTtsService implements TtsService {
  /// [preferTagalog] is read per utterance so a Tagalog UI voice change
  /// applies without recreating the engine.
  FlutterTtsService({required this.preferTagalog});

  final bool Function() preferTagalog;

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<TtsPlayback> _playback = ValueNotifier(TtsPlayback.idle);
  Future<void>? _ready;
  int _utterance = 0;

  @override
  ValueListenable<TtsPlayback> get playback => _playback;

  Future<void> _ensureReady() =>
      _ready ??= _init().timeout(const Duration(seconds: 15));

  Future<void> _init() async {
    // Warm, gentle delivery — conservative pitch/rate; we cannot promise an
    // elderly voice, only soften what the installed engine provides.
    await _tts.setPitch(0.95);
    await _tts.setSpeechRate(0.8);
    _tts.setCompletionHandler(() => _end(_utterance));
    _tts.setCancelHandler(() => _end(_utterance));
    _tts.setErrorHandler((_) => _end(_utterance));
  }

  void _end(int generation) {
    // Ignore completions/cancels of a superseded utterance.
    if (generation == _utterance) _playback.value = TtsPlayback.idle;
  }

  @override
  Future<TtsSpeakStatus> speak(String text) async {
    final generation = ++_utterance;
    _playback.value = TtsPlayback.idle;
    try {
      await _tts.stop();
    } catch (_) {}
    if (text.trim().isEmpty) return TtsSpeakStatus.noOfflineVoice;
    try {
      await _ensureReady();
    } catch (e, st) {
      appLog.e('TTS init failed', e, st);
      return TtsSpeakStatus.engineError;
    }

    List<Map> voices = const [];
    try {
      voices = (await _tts.getVoices).whereType<Map>().toList();
    } catch (e, st) {
      appLog.e('TTS voice query failed', e, st);
      return TtsSpeakStatus.engineError;
    }
    final (choice, fallback) = selectOfflineVoice(
      voices,
      preferTagalog: preferTagalog(),
    );
    if (choice == null) {
      appLog.i('TTS: no offline voice installed; answer stays text-only');
      return TtsSpeakStatus.noOfflineVoice;
    }
    try {
      await _tts.setVoice({
        'name': choice.name ?? '',
        'locale': choice.locale ?? '',
      });
    } catch (e, st) {
      appLog.e('TTS setVoice failed', e, st);
      return TtsSpeakStatus.engineError;
    }
    appLog.i(
      'TTS speak: voice=${choice.name} locale=${choice.locale} '
      'offline=true chars=${text.length}',
    );
    if (generation != _utterance) return TtsSpeakStatus.spoken;
    _playback.value = TtsPlayback.speaking;
    try {
      await _tts.speak(text);
    } catch (e, st) {
      appLog.e('TTS speak failed', e, st);
      _end(generation);
      return TtsSpeakStatus.engineError;
    }
    return fallback ? TtsSpeakStatus.fallbackVoice : TtsSpeakStatus.spoken;
  }

  @override
  Future<void> stop() async {
    _utterance++;
    _playback.value = TtsPlayback.idle;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _utterance++;
    _playback.value = TtsPlayback.idle;
    _playback.dispose();
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
