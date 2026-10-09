import '../notebook_theme.dart';
import '../localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_database.dart';
import '../../core/app_log.dart';
import '../../core/providers.dart';
import '../../logic/extraction.dart';
import '../../logic/speech_extraction.dart';
import '../../services/llm/extractor.dart';
import '../widgets/hold_to_talk_control.dart';

const _manualFields = <String, dynamic>{
  'kind': '',
  'person': null,
  'item': null,
  'place': null,
  'amount': null,
  'due_date_text': null,
};

const _memoryTypes = [
  ('lent_item', 'May humiram na gamit', 'Halimbawa: drill'),
  ('lent_money', 'May pinautang na pera', 'Halimbawa: PHP 500'),
  ('item_location', 'Alam ko kung saan nakalagay', 'Halimbawa: susi sa drawer'),
  ('promise', 'May ipinangako sa akin', 'Halimbawa: ibabalik ang susi'),
];

class _EvidenceTextController extends TextEditingController {
  String? evidence;

  void updateEvidence(String? value) {
    evidence = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final match = evidence;
    if (match == null || match.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final start = text.indexOf(match);
    if (start < 0 ||
        (withComposing &&
            value.composing.isValid &&
            !value.composing.isCollapsed)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final end = start + match.length;
    return TextSpan(
      style: style,
      children: [
        if (start > 0) TextSpan(text: text.substring(0, start)),
        TextSpan(
          text: match,
          style: TextStyle(
            backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
        if (end < text.length) TextSpan(text: text.substring(end)),
      ],
    );
  }
}

class TalaScreen extends ConsumerStatefulWidget {
  const TalaScreen({
    super.key,
    this.active = true,
    this.embedded = false,
    this.onProcessingChanged,
    this.inputBusy = false,
  });
  final bool active;
  final bool embedded;
  final ValueChanged<bool>? onProcessingChanged;
  final bool inputBusy;

  @override
  ConsumerState<TalaScreen> createState() => TalaScreenState();
}

class TalaScreenState extends ConsumerState<TalaScreen> {
  Future<void> acceptCapture(HoldToTalkResult capture) =>
      _onTranscribed(capture);
  void repeatCapture() => setState(() {
    _captureNumber++;
    _transcript = null;
    _run = null;
    _extracting = false;
    _speechNotUnderstood = true;
  });
  final _reviewFocus = FocusNode();
  String? _transcript;
  String? _audioPath;
  ExtractionRun? _run;
  String? _extractionError;
  String? _saveError;
  String? _typedError;
  bool _extracting = false;
  bool _manualEntry = false;
  bool _speechNotUnderstood = false;
  final _scrollController = ScrollController();
  bool _saving = false;
  bool _saved = false;
  int _captureNumber = 0;
  String? _memoryUid;
  String? _memoryCreatedAt;
  final _editedValues = <String, String>{};
  final _typedController = TextEditingController();
  final _transcriptController = _EvidenceTextController();

  @override
  void dispose() {
    _reviewFocus.dispose();
    _typedController.dispose();
    _scrollController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _onTranscribed(HoldToTalkResult capture) =>
      _startReview(capture.transcription.text, audioPath: capture.audioPath);

  Future<void> _onTypedCapture() async {
    final transcript = _typedController.text.trim();
    if (transcript.isEmpty) {
      setState(() => _typedError = 'Type a memory description first.');
      return;
    }
    setState(() => _typedError = null);
    await _startReview(transcript);
  }

  Future<void> _startReview(String transcript, {String? audioPath}) async {
    widget.onProcessingChanged?.call(true);
    final captureNumber = _captureNumber + 1;
    _transcriptController.value = TextEditingValue(
      text: transcript,
      selection: TextSelection.collapsed(offset: transcript.length),
    );
    _transcriptController.updateEvidence(null);
    setState(() {
      _transcript = transcript;
      _audioPath = audioPath;
      _run = null;
      _extractionError = null;
      _saveError = null;
      _extracting = true;
      _manualEntry = false;
      _speechNotUnderstood = false;
      _saving = false;
      _saved = false;
      _memoryUid = null;
      _memoryCreatedAt = null;
      _editedValues.clear();
      _captureNumber = captureNumber;
    });
    try {
      final extractor = await ref.read(extractorProvider.future);
      final run = await extractor.extract(
        transcript,
        spoken: audioPath != null,
      );
      if (mounted && captureNumber == _captureNumber) {
        _transcriptController.text = run.reviewTranscript;
        _transcriptController.updateEvidence(
          run.parse.json?['evidence'] as String?,
        );
        setState(() => _run = run);
      }
    } catch (e) {
      if (mounted && captureNumber == _captureNumber) {
        _transcriptController.updateEvidence(null);
        setState(() {
          _speechNotUnderstood = audioPath != null;
          _manualEntry = audioPath == null;
          _extractionError = audioPath == null ? e.toString() : null;
        });
      }
    } finally {
      if (mounted && captureNumber == _captureNumber) {
        setState(() => _extracting = false);
        widget.onProcessingChanged?.call(false);
      }
    }
  }

  Future<void> _saveMemory(Map<String, dynamic> json) async {
    if (_saving || _saved) return;
    final memory = _validatedMemory(json);
    if (memory == null) return;
    final uid = memory.uid;

    setState(() {
      _saving = true;
      _saveError = null;
    });
    widget.onProcessingChanged?.call(true);
    try {
      await ref.read(appDatabaseProvider).saveConfirmedMemory(memory);
      appLog.i('Confirmed memory saved locally: uid=$uid');
      ref.invalidate(savedMemoriesProvider);
      ref.invalidate(openLoopsProvider);
      if (mounted) {
        setState(() {
          _saving = false;
          _saved = true;
        });
        widget.onProcessingChanged?.call(false);
      }
    } catch (e, st) {
      appLog.e('Could not save confirmed memory: uid=$uid', e, st);
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError =
              'Could not save on this device ($e). Your review is still here; '
              'check storage and tap Retry save.';
        });
        widget.onProcessingChanged?.call(false);
      }
    }
  }

  ConfirmedMemory? _validatedMemory(Map<String, dynamic> json) {
    String value(String field) =>
        (_editedValues[field] ?? json[field]?.toString() ?? '').trim();
    String? optional(String field) {
      final result = value(field);
      return result.isEmpty ? null : result;
    }

    final kind = value('kind');
    if (!extractionKinds.contains(kind)) {
      setState(() => _saveError = 'Choose a valid memory type before saving.');
      return null;
    }
    final transcript =
        (_editedValues['transcript'] ?? _transcriptController.text).trim();
    if (transcript.isEmpty) {
      setState(() => _saveError = 'A transcript is required before saving.');
      return null;
    }

    final amountText = value('amount');
    final amount = amountText.isEmpty ? null : num.tryParse(amountText);
    if (amountText.isNotEmpty &&
        (amount == null || !amount.isFinite || amount < 0)) {
      setState(() => _saveError = 'Enter a valid non-negative amount.');
      return null;
    }
    final requiredError = switch (kind) {
      'lent_item' when optional('item') == null =>
        'Enter the borrowed item before saving.',
      'lent_money' when amount == null =>
        'Enter the amount lent before saving.',
      'item_location'
          when optional('item') == null || optional('place') == null =>
        'Enter the item and its place before saving.',
      _ => null,
    };
    if (requiredError != null) {
      setState(() => _saveError = requiredError);
      return null;
    }
    final evidence = optional('evidence');
    if (!_manualEntry && (evidence == null || !transcript.contains(evidence))) {
      setState(
        () => _saveError = 'Evidence must match part of the transcript. Edit it and try again.',
      );
      return null;
    }

    final uid = _memoryUid ??= const Uuid().v4();
    final timestamp = _memoryCreatedAt ??= DateTime.now()
        .toUtc()
        .toIso8601String();
    return ConfirmedMemory(
      uid: uid,
      createdAt: timestamp,
      updatedAt: timestamp,
      kind: kind,
      person: optional('person'),
      item: optional('item'),
      place: optional('place'),
      amount: amount?.toDouble(),
      dueDateText: optional('due_date_text'),
      transcript: transcript,
      evidence: _manualEntry ? null : evidence,
      audioPath: _audioPath,
      rawTranscript: _audioPath == null ? null : _transcript,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stt = ref.watch(sttServiceProvider);
    final savedMemories = ref.watch(savedMemoriesProvider);
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        if (!widget.embedded)
          const NotebookHeader(
            title: 'Remember the little things',
            subtitle: 'Hold to speak, or write a memory below.',
            icon: Icons.edit_note_rounded,
          ),
        if (!widget.embedded)
          stt.when(
            skipLoadingOnRefresh: false,
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: UiText(
                'Whisper is not ready: $error. Typed entry is available above.',
                textAlign: TextAlign.center,
              ),
            ),
            data: (service) => HoldToTalkControl(
              key: const ValueKey('tala-microphone'),
              recorder: ref.read(recorderServiceProvider),
              stt: service,
              onTranscribed: _onTranscribed,
              enabled: widget.active && !_saving,
              onUnintelligible: () => setState(() {
                _captureNumber++;
                _transcript = null;
                _run = null;
                _extracting = false;
                _speechNotUnderstood = true;
              }),
            ),
          ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('tala-typed-input'),
          controller: _typedController,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: tr(context, 'Type a memory description'),
            hintText: tr(context, 'Halimbawa: Hiniram ni Jun ang drill.'),
            border: OutlineInputBorder(),
          ),
        ),
        if (_typedError != null)
          UiText(
            _typedError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('tala-typed-submit'),
          onPressed: _extracting || _saving || widget.inputBusy
              ? null
              : _onTypedCapture,
          icon: const Icon(Icons.keyboard),
          label: const UiText('Review typed memory'),
        ),
        const SizedBox(height: 16),
        if (_extracting) ...[
          const SizedBox(height: 20),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const UiText('Inaayos ang memory... / Extracting memory'),
        ],
        if (_speechNotUnderstood) ...[
          const SizedBox(height: 16),
          const UiText(repeatSpeechMessage),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _captureNumber++;
                _speechNotUnderstood = false;
                _transcript = null;
                _run = null;
              });
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            },
            child: const UiText('Try again'),
          ),
        ],
        if (_transcript != null && !_speechNotUnderstood && !_extracting) ...[
          const SizedBox(height: 24),
          _confirmationCard(context),
        ],
        ...savedMemories.when(
          data: (memories) => memories.isEmpty
              ? const <Widget>[]
              : [
                  const SizedBox(height: 24),
                  UiText(
                    'Saved memories',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final memory in memories)
                    Card(
                      child: ListTile(
                        title: Text(
                          memory.item ??
                              memory.person ??
                              kindLabel(context, memory.kind),
                        ),
                        subtitle: Text(
                          '${kindLabel(context, memory.kind)} · ${statusLabel(context, memory.status)} · '
                          '${memory.createdAt}',
                        ),
                        trailing: const Icon(Icons.check_circle_outline),
                      ),
                    ),
                ],
          loading: () => const <Widget>[],
          error: (error, _) => [
            const SizedBox(height: 16),
            UiText('Could not load saved memories: $error'),
          ],
        ),
      ],
    );
  }

  Widget _confirmationCard(BuildContext context) {
    final theme = Theme.of(context);
    final json = _manualEntry ? _manualFields : _run?.parse.json;
    const extractionFields = [
      ('kind', 'Type'),
      ('person', 'Person'),
      ('item', 'Item'),
      ('place', 'Place'),
      ('amount', 'Amount (PHP)'),
      ('due_date_text', 'Due date'),
      ('evidence', 'Evidence'),
    ];
    const manualFields = [
      ('kind', 'Type'),
      ('person', 'Person'),
      ('item', 'Item'),
      ('place', 'Place'),
      ('amount', 'Amount (PHP)'),
      ('due_date_text', 'Due date text'),
    ];
    final fields = _manualEntry ? manualFields : extractionFields;
    final selectedKind = _editedValues['kind'] ?? json?['kind'] as String?;
    final uncertainFields = _manualEntry
        ? const <String>{}
        : ((json?['uncertain_fields'] as List?) ?? const [])
              .whereType<String>()
              .toSet();
    final transcript = _transcriptController.text;
    final evidence = _manualEntry
        ? null
        : _editedValues['evidence'] ?? json?['evidence'] as String?;
    final evidenceMatches =
        evidence != null &&
        evidence.isNotEmpty &&
        transcript.contains(evidence);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiText(
              'Did Tanda hear that right?',
              style: theme.textTheme.titleLarge,
            ),
            if (_audioPath != null)
              ExpansionTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .secondaryContainer,
                childrenPadding: const EdgeInsets.all(16),
                title: const UiText('Original Whisper transcript'),
                children: [SelectableText(_transcript!)],
              ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey('review-transcript-$_captureNumber'),
              controller: _transcriptController,
              focusNode: _reviewFocus,
              readOnly: _saving || _saved || widget.inputBusy,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                _editedValues['transcript'] = value;
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: tr(
                  context,
                  _audioPath == null
                      ? 'Transcript / description'
                      : 'AI-corrected speech — review before confirming',
                ),
                fillColor: _audioPath == null
                    ? null
                    : Theme.of(context).colorScheme.tertiaryContainer,
                helperText: tr(
                  context,
                  'Edit the transcript or typed description if needed.',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_manualEntry)
              UiText(
                'Manual entry: no evidence will be attached unless extraction succeeds.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              )
            else if (evidenceMatches)
              const UiText('Exact evidence is highlighted in the transcript.')
            else
              UiText(
                evidence == null || evidence.isEmpty
                    ? 'Evidence is missing and is not verified.'
                    : 'Evidence does not exactly match the transcript and is not verified.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            if (_extractionError != null) ...[
              const SizedBox(height: 8),
              UiText(
                'Extraction failed after retry. Enter the fields manually. $_extractionError',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ] else if (_run != null && !_run!.parse.valid) ...[
              const SizedBox(height: 8),
              UiText(
                'Extraction needs manual review: ${_run!.parse.errors.join(', ')}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ] else if (_run != null && !_run!.evidenceOk) ...[
              const SizedBox(height: 8),
              UiText(
                'Evidence could not be matched to the transcript. Please check the fields.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (_manualEntry) ...[
              const SizedBox(height: 12),
              const UiText('Manual entry'),
            ],
            if (uncertainFields.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: UiText(
                  'Needs review: ${uncertainFields.map((field) => tr(context, _fieldName(field))).join(', ')}',
                  style: TextStyle(color: theme.colorScheme.tertiary),
                ),
              ),
            if (json != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const UiText('Memory type — choose one'),
                  if (uncertainFields.contains('kind'))
                    const UiText('Check the memory type before confirming.'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final (kind, label, example) in _memoryTypes)
                        ChoiceChip(
                          key: ValueKey('memory-type-$kind'),
                          selected: selectedKind == kind,
                          showCheckmark: true,
                          label: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UiText(label),
                              UiText(example, style: theme.textTheme.bodySmall),
                            ],
                          ),
                          onSelected: _saving || _saved
                              ? null
                              : (_) => setState(() {
                                  _editedValues['kind'] = kind;
                                  _saveError = null;
                                }),
                        ),
                    ],
                  ),
                ],
              ),
            if (json != null)
              for (final (field, label) in fields)
                if (field != 'kind')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      readOnly: _saving || _saved || widget.inputBusy,
                      key: ValueKey('$_captureNumber-$field'),
                      initialValue:
                          _editedValues[field] ?? json[field]?.toString() ?? '',
                      onChanged: (value) {
                        _editedValues[field] = value;
                        if (field == 'evidence') {
                          _transcriptController.updateEvidence(value);
                          setState(() {});
                        }
                      },
                      decoration: InputDecoration(
                        labelText: tr(context, label),
                        helperText: uncertainFields.contains(field)
                            ? tr(
                                context,
                                'Check this extracted field before confirming.',
                              )
                            : null,
                        suffixIcon: uncertainFields.contains(field)
                            ? Tooltip(
                                message: tr(context, 'Needs review'),
                                child: Icon(Icons.warning_amber_rounded),
                              )
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed:
                  json == null ||
                      (!_manualEntry && _run?.parse.valid != true) ||
                      _saving ||
                      _saved ||
                      widget.inputBusy
                  ? null
                  : () => _saveMemory(json),
              child: UiText(
                _saving
                    ? 'Saving...'
                    : _saved
                    ? 'Saved'
                    : _saveError == null
                    ? 'Yes, save it'
                    : 'Retry save',
              ),
            ),
            if (!_saved)
              OutlinedButton.icon(
                key: const ValueKey('review-edit'),
                onPressed: _saving || widget.inputBusy
                    ? null
                    : () {
                        _reviewFocus.requestFocus();
                        Scrollable.ensureVisible(
                          _reviewFocus.context!,
                          alignment: 0.15,
                        );
                      },
                icon: const Icon(Icons.edit_outlined),
                label: const UiText('Edit'),
              ),
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              UiText(
                _saveError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (_saved)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: UiText('Memory saved on this device.'),
              ),
          ],
        ),
      ),
    );
  }
}

String _fieldName(String field) => switch (field) {
  'kind' => 'Memory type',
  'person' => 'Person',
  'item' => 'Item',
  'place' => 'Place',
  'amount' => 'Amount (PHP)',
  'due_date_text' => 'Due date',
  'evidence' => 'Evidence',
  _ => 'Needs review',
};
