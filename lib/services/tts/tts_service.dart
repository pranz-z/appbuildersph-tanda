import 'dart:async';

import 'package:flutter/foundation.dart';

/// Playback state of the device text-to-speech engine.
enum TtsPlayback { idle, speaking }

/// Outcome of one speak() attempt — used to show a non-blocking notice when
/// the requested language has no offline voice on this device.
enum TtsSpeakStatus { spoken, fallbackVoice, noOfflineVoice, engineError }

/// Local on-device text-to-speech. Implementations must synthesize offline:
/// a voice that requires a network connection is never used.
abstract interface class TtsService {
  /// Live playback state; drives the character animation and controls.
  ValueListenable<TtsPlayback> get playback;

  /// Speaks [text] once, stopping any utterance already in progress.
  /// Returns how the text was voiced so the UI can disclose fallbacks.
  Future<TtsSpeakStatus> speak(String text);

  /// Stops the current utterance, if any.
  Future<void> stop();

  Future<void> dispose();
}

/// Test double: records utterances, simulates playback transitions.
class FakeTtsService implements TtsService {
  FakeTtsService({
    this.status = TtsSpeakStatus.spoken,
    this.autoComplete = true,
  });

  final ValueNotifier<TtsPlayback> _playback = ValueNotifier(TtsPlayback.idle);
  final List<String> spoken = [];
  TtsSpeakStatus status;
  bool autoComplete;
  int stops = 0;

  @override
  ValueListenable<TtsPlayback> get playback => _playback;

  @override
  Future<TtsSpeakStatus> speak(String text) async {
    spoken.add(text);
    _playback.value = TtsPlayback.speaking;
    if (autoComplete) _playback.value = TtsPlayback.idle;
    return status;
  }

  /// Simulates the engine finishing the current utterance.
  void finish() => _playback.value = TtsPlayback.idle;

  @override
  Future<void> stop() async {
    stops++;
    _playback.value = TtsPlayback.idle;
  }

  @override
  Future<void> dispose() async => _playback.dispose();
}

/// The voice chosen for an utterance, or null when no offline voice exists.
class TtsVoiceChoice {
  const TtsVoiceChoice({required this.name, required this.locale});

  final String? name;
  final String? locale;
}

/// True when the engine reports this voice runs on-device only.
/// flutter_tts on Android exposes 'network_required' (bool/int/string);
/// names ending in '-network' are also network voices. When the flag is
/// absent the '-local' suffix or a missing marker is treated as offline.
bool voiceIsOffline(Map voice) {
  final required = voice['network_required'];
  if (required == true ||
      required == 1 ||
      '$required'.toLowerCase() == 'true' ||
      '$required' == '1') {
    return false;
  }
  final name = '${voice['name'] ?? ''}'.toLowerCase();
  return !name.endsWith('-network');
}

bool _isFemale(Map voice) {
  final name = '${voice['name'] ?? ''}'.toLowerCase();
  final gender = '${voice['gender'] ?? ''}'.toLowerCase();
  return gender == 'female' ||
      name.contains('female') ||
      name.contains('#f') ||
      RegExp(r'-[a-z]f[a-z]_').hasMatch(name);
}

/// Picks the most appropriate OFFLINE voice. [preferTagalog] selects
/// Filipino/Tagalog voices first; otherwise English. When the preferred
/// language has no offline voice but the other does, [fallback] is set so
/// the caller can show a notice. Returns (null, fallback) when nothing
/// offline exists — the caller must not speak in that case.
(TtsVoiceChoice?, bool fallback) selectOfflineVoice(
  List<Map> voices, {
  required bool preferTagalog,
}) {
  bool tagaloid(Map v) {
    final locale = '${v['locale'] ?? ''}'.toLowerCase();
    return locale.startsWith('fil') || locale.startsWith('tl');
  }

  bool english(Map v) =>
      '${v['locale'] ?? ''}'.toLowerCase().startsWith('en');

  final offline = voices.where(voiceIsOffline).toList();
  List<Map> rank(bool Function(Map) match) {
    final pool = offline.where(match).toList();
    // Warm, gentle, mature-sounding feminine voice where available: prefer
    // female-marked names, then locally-installed ('-local') variants.
    pool.sort((a, b) {
      int score(Map v) {
        final name = '${v['name'] ?? ''}'.toLowerCase();
        return (_isFemale(v) ? 2 : 0) + (name.endsWith('-local') ? 1 : 0);
      }

      return score(b).compareTo(score(a));
    });
    return pool;
  }

  final preferred = rank(preferTagalog ? tagaloid : english);
  if (preferred.isNotEmpty) {
    final v = preferred.first;
    return (
      TtsVoiceChoice(
        name: '${v['name']}',
        locale: '${v['locale']}',
      ),
      false,
    );
  }
  final other = rank(preferTagalog ? english : tagaloid);
  if (other.isNotEmpty) {
    final v = other.first;
    return (
      TtsVoiceChoice(name: '${v['name']}', locale: '${v['locale']}'),
      true,
    );
  }
  return (null, true);
}
