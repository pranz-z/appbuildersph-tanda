import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../services/stt/stt_service.dart';
import '../grandma/grandma_avatar.dart';
import '../localization.dart';
import '../widgets/hold_to_talk_control.dart';
import 'tala_screen.dart';
import 'tanong_screen.dart';

enum _Action { tell, ask }

/// Keeps both existing flows mounted while routing each recording explicitly.
class TandaScreen extends ConsumerStatefulWidget {
  const TandaScreen({super.key, this.active = true});
  final bool active;
  @override
  ConsumerState<TandaScreen> createState() => _TandaScreenState();
}

class _TandaScreenState extends ConsumerState<TandaScreen> {
  final _tell = GlobalKey<TalaScreenState>();
  final _ask = GlobalKey<TanongScreenState>();
  _Action _action = _Action.tell;
  _Action? _owner;
  CapturePhase _phase = CapturePhase.idle;
  bool _tellProcessing = false, _askProcessing = false, _speaking = false;
  bool get _processing => _tellProcessing || _askProcessing;
  GrandmaState get _grandma => _phase == CapturePhase.recording
      ? GrandmaState.listening
      : _phase != CapturePhase.idle || _processing
      ? GrandmaState.thinking
      : _speaking
      ? GrandmaState.speaking
      : GrandmaState.idle;

  void _phaseChanged(_Action action, CapturePhase phase) {
    if (!mounted) return;
    setState(() {
      if (phase != CapturePhase.idle) {
        _action = action;
        _owner = action;
      } else if (_owner == action) {
        _owner = null;
      }
      _phase = phase;
    });
  }

  Widget _control(_Action action, SttService service) => HoldToTalkControl(
    key: ValueKey(action == _Action.tell ? 'tell-control' : 'ask-control'),
    tapToToggle: true,
    idleLabel: action == _Action.tell ? 'Tell Tanda' : 'Ask Tanda',
    recorder: ref.read(recorderServiceProvider),
    stt: service,
    enabled:
        widget.active && !_processing && (_owner == null || _owner == action),
    onPhaseChanged: (phase) => _phaseChanged(action, phase),
    onActivityChanged: action == _Action.ask
        ? (active) => _ask.currentState?.voiceActivity(active)
        : null,
    onUnintelligible: () {
      if (action == _Action.tell) {
        _tell.currentState?.repeatCapture();
      } else {
        _ask.currentState?.repeatQuestion();
      }
    },
    onTranscribed: (capture) {
      if (!widget.active || _owner != action) return;
      if (action == _Action.tell) {
        _tell.currentState?.acceptCapture(capture);
      } else {
        _ask.currentState?.acceptQuestion(capture);
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    final stt = ref.watch(sttServiceProvider);
    final grandma = _grandma;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.6),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Column(
                  children: [
                    RepaintBoundary(
                      child: Semantics(
                        label: tr(context, switch (grandma) {
                          GrandmaState.idle => 'Tanda is ready to listen',
                          GrandmaState.listening => 'Tanda is listening',
                          GrandmaState.thinking => 'Tanda is thinking',
                          GrandmaState.speaking => 'Tanda is speaking',
                        }),
                        child: TickerMode(
                          enabled: widget.active,
                          child: GrandmaAvatar(
                            key: ValueKey('grandma-${grandma.name}'),
                            state: grandma,
                            height: (constraints.maxHeight * 0.36).clamp(
                              60,
                              310,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final action in _Action.values) ...[
                          if (action == _Action.ask) const SizedBox(width: 12),
                          Expanded(
                            child: KeyedSubtree(
                              key: ValueKey(
                                action == _Action.tell
                                    ? 'tell-tanda'
                                    : 'ask-tanda',
                              ),
                              child: stt.when(
                                data: (service) => _control(action, service),
                                loading: () => Column(
                                  children: [
                                    FilledButton.icon(
                                      onPressed: null,
                                      icon: const Icon(Icons.mic_none_rounded),
                                      label: UiText(
                                        action == _Action.tell
                                            ? 'Tell Tanda'
                                            : 'Ask Tanda',
                                      ),
                                    ),
                                    const UiText(
                                      'Loading Whisper… Typed questions are available.',
                                    ),
                                  ],
                                ),
                                error: (_, _) => Column(
                                  children: [
                                    FilledButton.icon(
                                      onPressed: null,
                                      icon: const Icon(Icons.mic_off_outlined),
                                      label: UiText(
                                        action == _Action.tell
                                            ? 'Tell Tanda'
                                            : 'Ask Tanda',
                                      ),
                                    ),
                                    UiText(
                                      action == _Action.tell
                                          ? 'Voice capture unavailable. Type a memory below.'
                                          : 'Voice questions unavailable. Type your question above.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_owner == null && !_processing)
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton.icon(
                            key: const ValueKey('type-memory'),
                            onPressed: () =>
                                setState(() => _action = _Action.tell),
                            icon: const Icon(Icons.keyboard),
                            label: const UiText('Type a memory'),
                          ),
                          TextButton.icon(
                            key: const ValueKey('type-question'),
                            onPressed: () =>
                                setState(() => _action = _Action.ask),
                            icon: const Icon(Icons.keyboard),
                            label: const UiText('Type a question'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _action.index,
              children: [
                TalaScreen(
                  key: _tell,
                  embedded: true,
                  inputBusy: _owner != null,
                  active: widget.active && _action == _Action.tell,
                  onProcessingChanged: (value) {
                    if (mounted) setState(() => _tellProcessing = value);
                  },
                ),
                TanongScreen(
                  key: _ask,
                  embedded: true,
                  active: widget.active && _action == _Action.ask,
                  onProcessingChanged: (value) {
                    if (mounted) setState(() => _askProcessing = value);
                  },
                  onSpeakingChanged: (value) {
                    if (mounted) setState(() => _speaking = value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
