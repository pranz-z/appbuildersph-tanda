import '../localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../services/stt/sherpa_whisper_stt_service.dart';
import '../../services/stt/stt_service.dart';
import '../nav.dart';
import '../widgets/hold_to_talk_control.dart';

/// TEMPORARY spike screen for go/no-go item 1 (speech). Remove after the spike.
class SttDebugScreen extends ConsumerStatefulWidget {
  const SttDebugScreen({super.key});

  @override
  ConsumerState<SttDebugScreen> createState() => _SttDebugScreenState();
}

class _Run {
  _Run(this.n, this.result);
  final int n;
  final SttResult result;
}

class _SttDebugScreenState extends ConsumerState<SttDebugScreen> {
  bool _busy = false;
  final _runs = <_Run>[];

  void _onTranscribed(HoldToTalkResult capture) => setState(
    () => _runs.insert(0, _Run(_runs.length + 1, capture.transcription)),
  );

  void _copyAll() {
    final lang = ref.read(sttLanguageProvider);
    final rows = _runs.reversed
        .map(
          (r) =>
              '| ${r.n} | ${r.result.audioMs} | ${r.result.elapsedMs} | ${r.result.text} |',
        )
        .join('\n');
    Clipboard.setData(
      ClipboardData(
        text:
            'lang=${lang.isEmpty ? 'auto' : lang}\n'
            '| # | audio ms | stt ms | transcript |\n|---|---|---|---|\n$rows',
      ),
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: UiText('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    final sttAsync = ref.watch(sttServiceProvider);
    final lang = ref.watch(sttLanguageProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const UiText('STT spike (debug)'),
        actions: [
          IconButton(
            tooltip: tr(context, 'Copy results'),
            icon: const Icon(Icons.copy),
            onPressed: _runs.isEmpty ? null : _copyAll,
          ),
          IconButton(
            tooltip: tr(context, 'Import models'),
            icon: const Icon(Icons.file_open),
            onPressed: () => openImportModels(context),
          ),
          IconButton(
            tooltip: tr(context, 'Debug log'),
            icon: const Icon(Icons.article),
            onPressed: () => openDebugLog(context),
          ),
        ],
      ),
      body: sttAsync.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              UiText('Nilo-load ang Whisper... / Loading model'),
            ],
          ),
        ),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            UiText(
              'Models are not ready. Check setup or use typed entry.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => openImportModels(context),
              icon: const Icon(Icons.file_open),
              label: const UiText('Import models'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => openDebugLog(context),
              icon: const Icon(Icons.article),
              label: const UiText('Debug log'),
            ),
          ],
        ),
        data: (stt) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (stt is SherpaWhisperSttService)
                    UiText(
                      'Whisper ${stt.paths.variant.name} int8 · '
                      'load ${stt.loadMs} ms · ${stt.numThreads} threads',
                    ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'tl', label: UiText('tl')),
                      ButtonSegment(value: '', label: UiText('auto')),
                      ButtonSegment(value: 'en', label: UiText('en')),
                    ],
                    selected: {lang},
                    onSelectionChanged: _busy
                        ? null
                        : (s) => ref
                              .read(sttLanguageProvider.notifier)
                              .set(s.first),
                  ),
                ],
              ),
            ),
            HoldToTalkControl(
              recorder: ref.read(recorderServiceProvider),
              stt: stt,
              onTranscribed: _onTranscribed,
              onActivityChanged: (busy) {
                if (_busy != busy && mounted) setState(() => _busy = busy);
              },
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _runs.length,
                itemBuilder: (_, i) {
                  final r = _runs[i];
                  return ListTile(
                    leading: UiText('#${r.n}'),
                    title: SelectableText(
                      r.result.text.isEmpty
                          ? tr(context, '(empty)')
                          : r.result.text,
                    ),
                    subtitle: UiText(
                      'audio ${r.result.audioMs} ms · '
                      'transcribe ${r.result.elapsedMs} ms',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
