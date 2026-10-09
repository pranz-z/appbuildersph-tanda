import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../services/stt/sherpa_whisper_stt_service.dart';
import '../../services/stt/stt_service.dart';

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
  bool _recording = false;
  bool _busy = false;
  String? _error;
  final _runs = <_Run>[];
  final _hold = Stopwatch();

  Future<void> _down(SttService stt) async {
    if (_busy || _recording) return;
    final rec = ref.read(recorderServiceProvider);
    if (!await rec.ensurePermission()) {
      setState(() => _error = 'Microphone permission denied.');
      return;
    }
    setState(() {
      _recording = true;
      _error = null;
    });
    _hold
      ..reset()
      ..start();
    await rec.start();
  }

  Future<void> _up(SttService stt) async {
    if (!_recording) return;
    _hold.stop();
    setState(() {
      _recording = false;
      _busy = true;
    });
    try {
      final path = await ref.read(recorderServiceProvider).stop();
      if (path == null || _hold.elapsedMilliseconds < 300) {
        _error = 'Too short. Hold the button while speaking.';
        return;
      }
      final r = await stt.transcribeFile(path);
      _runs.insert(0, _Run(_runs.length + 1, r));
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
        .showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    final sttAsync = ref.watch(sttServiceProvider);
    final lang = ref.watch(sttLanguageProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('STT spike (debug)'),
        actions: [
          IconButton(
            tooltip: 'Copy results',
            icon: const Icon(Icons.copy),
            onPressed: _runs.isEmpty ? null : _copyAll,
          ),
        ],
      ),
      body: sttAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Nilo-load ang Whisper... / Loading model'),
            ],
          ),
        ),
        error: (e, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            e.toString(),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
        data: (stt) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (stt is SherpaWhisperSttService)
                    Text(
                      'Whisper ${stt.paths.variant.name} int8 · '
                      'load ${stt.loadMs} ms · ${stt.numThreads} threads',
                    ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'tl', label: Text('tl')),
                      ButtonSegment(value: '', label: Text('auto')),
                      ButtonSegment(value: 'en', label: Text('en')),
                    ],
                    selected: {lang},
                    onSelectionChanged: _busy || _recording
                        ? null
                        : (s) => ref
                              .read(sttLanguageProvider.notifier)
                              .set(s.first),
                  ),
                ],
              ),
            ),
            Listener(
              onPointerDown: (_) => _down(stt),
              onPointerUp: (_) => _up(stt),
              onPointerCancel: (_) => _up(stt),
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _recording
                      ? Colors.red
                      : _busy
                      ? Colors.grey
                      : theme.colorScheme.primary,
                ),
                alignment: Alignment.center,
                child: _busy
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Icon(
                        _recording ? Icons.mic : Icons.mic_none,
                        size: 72,
                        color: Colors.white,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _recording
                  ? 'Nakikinig... / Listening (release to stop)'
                  : _busy
                  ? 'Tina-transcribe... / Transcribing'
                  : 'Pindutin nang matagal / Hold to talk',
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _runs.length,
                itemBuilder: (_, i) {
                  final r = _runs[i];
                  return ListTile(
                    leading: Text('#${r.n}'),
                    title: SelectableText(
                      r.result.text.isEmpty ? '(empty)' : r.result.text,
                    ),
                    subtitle: Text(
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
