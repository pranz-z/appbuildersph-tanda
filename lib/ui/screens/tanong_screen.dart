import '../notebook_theme.dart';
import '../localization.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/app_database.dart';
import '../../core/providers.dart';
import '../../logic/local_memory_ask.dart';
import '../../logic/speech_extraction.dart';
import '../widgets/hold_to_talk_control.dart';

class TanongScreen extends ConsumerStatefulWidget {
  const TanongScreen({
    super.key,
    this.active = true,
    this.embedded = false,
    this.onProcessingChanged,
    this.onAnswerChanged,
  });
  final bool active;
  final bool embedded;
  final ValueChanged<bool>? onProcessingChanged;
  final ValueChanged<bool>? onAnswerChanged;

  @override
  ConsumerState<TanongScreen> createState() => TanongScreenState();
}

class TanongScreenState extends ConsumerState<TanongScreen> {
  void voiceActivity(bool active) => _onVoiceActivity(active);
  void acceptQuestion(HoldToTalkResult capture) =>
      _onQuestion(capture, autoAsk: true);
  void repeatQuestion() => setState(() => _error = repeatSpeechMessage);
  final _questionController = TextEditingController();
  final _matcher = LocalMemoryAsk();
  LocalMemoryAskResult? _result;
  String? _error;
  bool _asking = false;
  bool _voiceActive = false;
  int _questionRevision = 0;
  int _voiceRevision = 0;

  void _onVoiceActivity(bool active) {
    if (!mounted) return;
    setState(() {
      if (active && !_voiceActive) {
        _voiceRevision = _questionRevision;
        _error = null;
        _result = null;
        widget.onAnswerChanged?.call(false);
      }
      _voiceActive = active;
    });
  }

  void _onQuestion(HoldToTalkResult capture, {bool autoAsk = false}) {
    if (!widget.active || _voiceRevision != _questionRevision) return;
    final question = capture.transcription.text.trim();
    final hasQuestionCue = RegExp(
      r'\b(sino|nasaan|saan|ano|alin|kanino|magkano|kailan|hiram|utang|pangako|who|where|what|which|whose|how|when|borrowed|owe|owed|promise|find)\b',
      caseSensitive: false,
    ).hasMatch(question);
    if (isUnusableSpeech(question) ||
        !hasQuestionCue ||
        question.split(RegExp(r'\s+')).length < 2) {
      setState(() => _error = repeatSpeechMessage);
      return;
    }
    setState(() {
      _questionController.text = question;
      _questionRevision++;
      _error = null;
      _result = null;
    });
    if (autoAsk) unawaited(_ask(fromVoice: true));
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _ask({bool fromVoice = false}) async {
    if (_asking || (_voiceActive && !fromVoice) || !widget.active) return;
    final revision = _questionRevision;
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() {
        _result = null;
        _error = 'I-type ang tanong mo.';
      });
      return;
    }
    setState(() {
      _asking = true;
      _error = null;
    });
    widget.onProcessingChanged?.call(true);
    try {
      final memories = await ref.read(appDatabaseProvider).confirmedMemories();
      final result = _matcher.answer(question, memories);
      if (mounted && widget.active && revision == _questionRevision) {
        setState(() => _result = result);
        widget.onAnswerChanged?.call(true);
      }
    } catch (error) {
      if (mounted && widget.active && revision == _questionRevision) {
        setState(() => _error = 'Hindi mabasa ang mga saved memory: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _asking = false);
        widget.onProcessingChanged?.call(false);
      }
    }
  }

  void _choose(StoredMemory memory) {
    setState(() => _result = _matcher.answerFor(memory));
    widget.onAnswerChanged?.call(true);
  }

  @override
  Widget build(BuildContext context) {
    final stt = ref.watch(sttServiceProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!widget.embedded)
          const NotebookHeader(
            title: 'Ask your notebook',
            subtitle: 'Magtanong tungkol sa mga kinumpirmang memory.',
            icon: Icons.question_answer_outlined,
          ),
        TextField(
          key: const ValueKey('tanong-question'),
          controller: _questionController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _ask(),
          onChanged: (_) => setState(() {
            _questionRevision++;
            _result = null;
            _error = null;
            widget.onAnswerChanged?.call(false);
          }),
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: tr(context, 'Itanong / Ask'),
            hintText: tr(context, 'Sino may hawak ng drill?'),
          ),
        ),
        const SizedBox(height: 12),
        if (!widget.embedded)
          stt.when(
            loading: () =>
                const UiText('Loading Whisper… Typed questions are available.'),
            error: (error, _) => const UiText(
              'Voice questions unavailable. Type your question above.',
            ),
            data: (service) => HoldToTalkControl(
              key: const ValueKey('tanong-microphone'),
              recorder: ref.read(recorderServiceProvider),
              stt: service,
              diameter: 96,
              enabled: widget.active && !_asking,
              onActivityChanged: _onVoiceActivity,
              onTranscribed: _onQuestion,
            ),
          ),
        UiText(
          widget.embedded
              ? 'Speak to ask automatically, or type a question below.'
              : 'Review or edit the recognized question, then tap Ask.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('tanong-ask'),
          onPressed: _asking || _voiceActive ? null : _ask,
          icon: _asking
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          label: UiText(_asking ? 'Naghahanap...' : 'Ask'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          UiText(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_result case final result?) ...[
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _presentAnswer(context, result),
                key: const ValueKey('tanong-answer'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          for (final memory in result.matches)
            _MemoryCitation(
              key: ValueKey('citation-${memory.uid}'),
              memory: memory,
              selectable: result.kind == AskResultKind.ambiguous,
              onSelected: () => _choose(memory),
            ),
        ],
      ],
    );
  }
}

class _MemoryCitation extends StatelessWidget {
  const _MemoryCitation({
    super.key,
    required this.memory,
    required this.selectable,
    required this.onSelected,
  });

  final StoredMemory memory;
  final bool selectable;
  final VoidCallback onSelected;

  String _title(BuildContext context) =>
      [memory.person, memory.item, memory.place]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(' · ')
          .ifEmpty(kindLabel(context, memory.kind));

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selectable)
            ListTile(
              title: Text(_title(context)),
              subtitle: const UiText('Piliin ang memory na tinutukoy mo.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onSelected,
            )
          else
            ListTile(
              title: Text('${tr(context, 'Memory')} · ${_title(context)}'),
              subtitle: Text(
                '${kindLabel(context, memory.kind)} · ${statusLabel(context, memory.status)} · ${memory.createdAt}',
              ),
              leading: const Icon(Icons.format_quote),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UiText('Transcript'),
                const SizedBox(height: 4),
                SelectableText(memory.transcript),
                if (memory.rawTranscript != null)
                  ExpansionTile(
                    title: const UiText(
                      'Original Whisper transcript (before AI correction)',
                    ),
                    children: [SelectableText(memory.rawTranscript!)],
                  ),
                const SizedBox(height: 8),
                if (memory.audioPath == null || memory.audioPath!.isEmpty)
                  const UiText('No audio saved')
                else
                  _AudioCitation(path: memory.audioPath!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioCitation extends StatefulWidget {
  const _AudioCitation({required this.path});

  final String path;

  @override
  State<_AudioCitation> createState() => _AudioCitationState();
}

class _AudioCitationState extends State<_AudioCitation> {
  late final Future<bool> _readable = _canRead(widget.path);
  AudioPlayer? _player;
  bool _playing = false;
  bool _unavailable = false;

  static Future<bool> _canRead(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final handle = await file.open(mode: FileMode.read);
      await handle.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggle() async {
    final player = _player ??= AudioPlayer();
    if (_playing) {
      await player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    try {
      await player.setFilePath(widget.path);
      if (!mounted) return;
      setState(() => _playing = true);
      unawaited(_play(player));
    } catch (_) {
      if (mounted) setState(() => _unavailable = true);
    }
  }

  Future<void> _play(AudioPlayer player) async {
    try {
      await player.play();
    } catch (_) {
      if (mounted) setState(() => _unavailable = true);
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  void dispose() {
    final player = _player;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) return const UiText('Audio unavailable');
    return FutureBuilder<bool>(
      future: _readable,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snapshot.data != true) return const UiText('Audio unavailable');
        return TextButton.icon(
          onPressed: _toggle,
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          label: UiText(_playing ? 'Pause audio' : 'Play audio citation'),
        );
      },
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

// Presentation only; matching and citations still use the unchanged SQLite rows.
String _presentAnswer(BuildContext context, LocalMemoryAskResult result) {
  if (result.kind != AskResultKind.answer || result.matches.length != 1) {
    return tr(context, result.answer);
  }
  final memory = result.matches.single;
  final person = memory.person?.trim(),
      item = memory.item?.trim(),
      place = memory.place?.trim();
  final hasPerson = person?.isNotEmpty == true,
      hasItem = item?.isNotEmpty == true;
  String format(String key, List<String> values) =>
      uiFormat(context, key, values);
  final String answer;
  switch (memory.kind) {
    case 'lent_item':
      final borrowed = hasItem ? item! : tr(context, 'this item');
      answer = hasPerson
          ? format('{1} borrowed {2}.', [person!, borrowed])
          : format('A loan of {1} was recorded.', [borrowed]);
    case 'lent_money':
      final amount = memory.amount;
      final value = amount == null
          ? null
          : amount == amount.roundToDouble()
          ? amount.toStringAsFixed(0)
          : amount.toStringAsFixed(2);
      answer = value != null
          ? hasPerson
                ? format('{1} owes PHP {2}.', [person!, value])
                : format('A loan of PHP {1} was recorded.', [value])
          : tr(context, 'A money loan was recorded.');
    case 'item_location':
      answer = hasItem && place?.isNotEmpty == true
          ? format('{1} is at {2}.', [item!, place!])
          : format('A location was recorded for {1}.', [
              hasItem ? item! : tr(context, 'this item'),
            ]);
    case 'promise':
      answer = hasItem
          ? hasPerson
                ? format('{1} promised: {2}.', [person!, item!])
                : format('Promise recorded: {1}.', [item!])
          : tr(context, 'A promise was recorded.');
    default:
      return tr(context, 'Wala akong nahanap.');
  }
  final due = memory.dueDateText?.trim();
  return due == null || due.isEmpty
      ? answer
      : '$answer ${format('Recorded due date: {1}.', [due])}';
}
