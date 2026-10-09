import '../notebook_theme.dart';
import '../localization.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_log.dart';
import '../../logic/speech_extraction.dart';
import '../../services/audio/recorder_service.dart';
import '../../services/stt/stt_service.dart';

/// Shared hold-to-talk interaction used by Tala and the STT debug screen.
class HoldToTalkResult {
  const HoldToTalkResult({
    required this.transcription,
    required this.audioPath,
  });

  final SttResult transcription;
  final String audioPath;
}

class HoldToTalkControl extends StatefulWidget {
  const HoldToTalkControl({
    super.key,
    required this.recorder,
    required this.stt,
    required this.onTranscribed,
    this.diameter = 160,
    this.onActivityChanged,
    this.onUnintelligible,
    this.enabled = true,
    this.tapToToggle = false,
    this.idleLabel = 'Tell Tanda',
    this.onPhaseChanged,
  });

  final AudioCaptureRecorder recorder;
  final SttService stt;
  final ValueChanged<HoldToTalkResult> onTranscribed;
  final double diameter;
  final ValueChanged<bool>? onActivityChanged;
  final VoidCallback? onUnintelligible;
  final bool enabled;
  final bool tapToToggle;
  final String idleLabel;
  final ValueChanged<CapturePhase>? onPhaseChanged;

  @override
  State<HoldToTalkControl> createState() => _HoldToTalkControlState();
}

enum CapturePhase {
  idle,
  permission,
  starting,
  recording,
  stopping,
  transcribing,
}

class _HoldToTalkControlState extends State<HoldToTalkControl> {
  static final _owners = Expando<_HoldToTalkControlState>();
  int _generation = 0;
  CapturePhase _phase = CapturePhase.idle;
  final _hold = Stopwatch();
  bool _pressed = false;
  bool _cancelAfterStart = false;
  String? _error;

  bool get _active => _phase != CapturePhase.idle;

  void _releaseOwnership() {
    if (_owners[widget.recorder] == this) _owners[widget.recorder] = null;
  }

  @override
  void didUpdateWidget(covariant HoldToTalkControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _generation++;
      _pressed = false;
      _cancelAfterStart = true;
      if (_phase == CapturePhase.recording) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _phase == CapturePhase.recording) {
            unawaited(_cancelRecording());
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _pressed = false;
    _cancelAfterStart = true;
    if (_phase == CapturePhase.recording) {
      unawaited(
        widget.recorder
            .cancel()
            .catchError((Object error) {
              appLog.e('Could not cancel disposed capture', error);
            })
            .whenComplete(_releaseOwnership),
      );
    } else if (_phase == CapturePhase.idle) {
      _releaseOwnership();
    }
    super.dispose();
  }

  void _setPhase(CapturePhase phase, {String? error, bool clearError = false}) {
    setState(() {
      _phase = phase;
      if (clearError) _error = null;
      if (error != null) _error = error;
    });
    widget.onActivityChanged?.call(phase != CapturePhase.idle);
    widget.onPhaseChanged?.call(phase);
    if (phase == CapturePhase.idle) _releaseOwnership();
  }

  Future<void> _press() async {
    if (_active || !widget.enabled) return;
    if (_owners[widget.recorder] != null) {
      setState(
        () => _error =
            'Another microphone capture is still finishing. Try again shortly.',
      );
      return;
    }
    _owners[widget.recorder] = this;
    _generation++;
    _pressed = true;
    _cancelAfterStart = false;
    _setPhase(CapturePhase.permission, clearError: true);
    try {
      if (!await widget.recorder.hasPermission(request: false)) {
        final granted = await widget.recorder.hasPermission(request: true);
        if (!mounted) {
          _releaseOwnership();
          return;
        }
        _cancelAfterStart = false;
        _pressed = false;
        _setPhase(
          CapturePhase.idle,
          error: granted
              ? (widget.tapToToggle
                    ? 'Microphone allowed. Tap again to record.'
                    : 'Microphone allowed. Hold the button again to record.')
              : (widget.tapToToggle
                    ? 'Microphone permission denied. Allow access in Android Settings, then tap again.'
                    : 'Microphone permission denied. Allow Tanda to use the microphone, then hold the button again.'),
        );
        return;
      }
      if (!mounted) {
        _releaseOwnership();
        return;
      }
      if (!_pressed || !widget.enabled) {
        _setPhase(CapturePhase.idle);
        return;
      }

      _hold
        ..reset()
        ..start();
      _setPhase(CapturePhase.starting);
      await widget.recorder.start();
      if (!mounted) {
        await widget.recorder.cancel();
        _releaseOwnership();
        return;
      }
      appLog.i('Capture control recording started');
      if (_cancelAfterStart) {
        await _cancelRecording();
      } else if (_pressed) {
        _setPhase(CapturePhase.recording);
      } else {
        _setPhase(CapturePhase.recording);
        await _release();
      }
    } catch (e, st) {
      appLog.e('Capture control could not start recording', e, st);
      if (mounted) {
        _pressed = false;
        _setPhase(CapturePhase.idle, error: 'Could not start recording: $e');
      }
      if (!mounted) _releaseOwnership();
    }
  }

  void _pointerUp() {
    _pressed = false;
    if (_phase == CapturePhase.recording) unawaited(_release());
  }

  void _pointerCancel() {
    _pressed = false;
    _cancelAfterStart = true;
    if (_phase == CapturePhase.recording) unawaited(_cancelRecording());
  }

  Future<void> _release() async {
    if (_phase != CapturePhase.recording) return;
    _hold.stop();
    final generation = _generation;
    _setPhase(CapturePhase.stopping);
    try {
      final path = await widget.recorder.stop();
      if (path == null) {
        throw StateError('The recorder did not return an audio file.');
      }
      if (_hold.elapsedMilliseconds < 300) {
        throw StateError(
          'Recording was too short. Hold the button while speaking.',
        );
      }
      appLog.i('Transcription handoff: path=$path');
      if (mounted) _setPhase(CapturePhase.transcribing);
      final result = await widget.stt.transcribeFile(path);
      appLog.i(
        'Transcription complete: chars=${result.text.length}, '
        'audioMs=${result.audioMs}, elapsedMs=${result.elapsedMs}',
      );
      if (mounted && widget.enabled && generation == _generation) {
        widget.onTranscribed(
          HoldToTalkResult(transcription: result, audioPath: path),
        );
      }
      if (mounted) _setPhase(CapturePhase.idle);
    } catch (e, st) {
      appLog.e('Capture control recording/transcription failed', e, st);
      if (mounted) {
        _setPhase(CapturePhase.idle, error: e.toString());
        if (widget.enabled &&
            generation == _generation &&
            e is UnintelligibleSpeechException) {
          widget.onUnintelligible?.call();
        }
      }
    } finally {
      _cancelAfterStart = false;
      _releaseOwnership();
    }
  }

  Future<void> _cancelRecording() async {
    if (_phase != CapturePhase.recording && _phase != CapturePhase.starting) {
      return;
    }
    _hold.stop();
    _setPhase(CapturePhase.stopping);
    try {
      await widget.recorder.cancel();
      appLog.i('Capture control recording cancelled');
    } catch (e, st) {
      appLog.e('Capture control could not cancel recording', e, st);
      if (mounted) setState(() => _error = 'Could not cancel recording: $e');
    } finally {
      _cancelAfterStart = false;
      if (mounted) _setPhase(CapturePhase.idle);
      _releaseOwnership();
    }
  }

  String get _status => switch (_phase) {
    CapturePhase.idle =>
      widget.tapToToggle
          ? 'Tap to start; tap Stop when finished.'
          : 'Pindutin nang matagal / Hold to talk',
    CapturePhase.permission => 'Checking microphone permission...',
    CapturePhase.starting => 'Starting recording...',
    CapturePhase.recording =>
      widget.tapToToggle
          ? 'Listening… Tap Stop when finished.'
          : 'Nakikinig... / Listening (release to stop)',
    CapturePhase.stopping => 'Saving recording...',
    CapturePhase.transcribing => 'Tina-transcribe... / Transcribing',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recording = _phase == CapturePhase.recording;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.tapToToggle)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: recording
                  ? FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    )
                  : null,
              onPressed:
                  !widget.enabled ||
                      (_active &&
                          !recording &&
                          _phase != CapturePhase.starting &&
                          _phase != CapturePhase.permission)
                  ? null
                  : () {
                      if (_active) {
                        _pointerUp();
                      } else {
                        unawaited(_press());
                      }
                    },
              icon: Icon(
                recording ? Icons.stop_rounded : Icons.mic_none_rounded,
              ),
              label: UiText(
                recording || _phase == CapturePhase.starting
                    ? 'Stop'
                    : widget.idleLabel,
              ),
            ),
          )
        else
          Listener(
            key: const ValueKey('hold-to-talk-button'),
            onPointerDown: (_) => unawaited(_press()),
            onPointerUp: (_) => _pointerUp(),
            onPointerCancel: (_) => _pointerCancel(),
            child: Semantics(
              button: true,
              enabled: widget.enabled,
              label: tr(context, 'Hold to record, release to transcribe'),
              child: Container(
                width: widget.diameter,
                height: widget.diameter,
                decoration: ShapeDecoration(
                  shape: SketchBorder(color: theme.colorScheme.onSurface),
                  color: recording
                      ? theme.colorScheme.error
                      : _active || !widget.enabled
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.primary,
                ),
                alignment: Alignment.center,
                child: _phase == CapturePhase.transcribing
                    ? CircularProgressIndicator(
                        color: theme.colorScheme.onSurface,
                      )
                    : Icon(
                        recording ? Icons.mic : Icons.mic_none,
                        size: widget.diameter * 0.45,
                        color: recording
                            ? theme.colorScheme.onError
                            : _active || !widget.enabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onPrimary,
                      ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        UiText(_status, textAlign: TextAlign.center),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: UiText(
              recordingError(_error!),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}
