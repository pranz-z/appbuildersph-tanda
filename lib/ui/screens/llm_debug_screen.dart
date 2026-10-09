import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_log.dart';
import '../../core/memory_info.dart';
import '../../core/model_locator.dart';
import '../../core/providers.dart';
import '../../logic/test_sentences.dart';
import '../../services/llm/extractor.dart';
import '../../services/llm/llamadart_llm_service.dart';
import '../nav.dart';

/// TEMPORARY spike screen for go/no-go item 2 (LLM). Remove after the spike.
class LlmDebugScreen extends ConsumerStatefulWidget {
  const LlmDebugScreen({super.key});

  @override
  ConsumerState<LlmDebugScreen> createState() => _LlmDebugScreenState();
}

class _LlmDebugScreenState extends ConsumerState<LlmDebugScreen> {
  final _input = TextEditingController(
    text: 'Nagpautang ako kay Ate Mary ng limang daan, babayaran daw sa Biyernes.',
  );
  bool _busy = false;
  String? _error;
  ExtractionRun? _last;
  String? _batchReport;
  String _batchProgress = '';

  Future<void> _extractOne(Extractor ex) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ex.extract(_input.text);
      if (mounted) setState(() => _last = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runBatch(Extractor ex) async {
    setState(() {
      _busy = true;
      _error = null;
      _batchReport = null;
    });
    try {
      final sentences = parseTestSentences(
        await rootBundle.loadString('test_sentences.md'),
      );
      appLog.i('LLM batch: ${sentences.length} sentences');
      final rows = <String>[];
      final times = <int>[];
      var valid = 0, evidenceOk = 0;
      for (var i = 0; i < sentences.length; i++) {
        if (mounted) {
          setState(() => _batchProgress = '${i + 1}/${sentences.length}');
        }
        try {
          final r = await ex.extract(sentences[i]);
          times.add(r.llm.elapsedMs);
          if (r.parse.valid) valid++;
          if (r.evidenceOk) evidenceOk++;
          final j = r.parse.json ?? {};
          rows.add(
            '| ${i + 1} | ${r.parse.valid ? 'Y' : 'N'} | '
            '${r.evidenceOk ? 'Y' : 'N'} | ${r.llm.elapsedMs} | '
            '${r.llm.generatedTokens} | '
            '${r.llm.tokensPerSec.toStringAsFixed(1)} | ${j['kind']} | '
            '${j['person']} | ${j['item']} | ${j['amount']} | '
            '${j['due_date_text']} |',
          );
        } catch (e) {
          rows.add('| ${i + 1} | ERROR | | | | | $e | | | | |');
        }
      }
      final n = sentences.length;
      final avg = times.isEmpty
          ? 0
          : times.reduce((a, b) => a + b) ~/ times.length;
      final llm = ref.read(llmServiceProvider).value;
      final info = llm is LlamadartLlmService
          ? 'model=${llmSpec.name}, threads=${llm.numThreads}, '
                'ctx=${llm.contextSize}, load=${llm.loadMs} ms'
          : '';
      final report =
          '$info\n'
          'Valid JSON: $valid/$n · evidence substring OK: $evidenceOk/$n · '
          'avg $avg ms · max ${times.isEmpty ? 0 : times.reduce(max)} ms\n'
          'memory: ${residentMemorySummary()}\n\n'
          '| # | valid | evid | ms | tok | tok/s | kind | person | item | amount | due |\n'
          '|---|---|---|---|---|---|---|---|---|---|---|\n'
          '${rows.join('\n')}';
      appLog.i('LLM batch done:\n$report');
      if (mounted) setState(() => _batchReport = report);
    } catch (e, st) {
      appLog.e('LLM batch failed', e, st);
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _batchProgress = '';
        });
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exAsync = ref.watch(extractorProvider);
    final theme = Theme.of(context);
    final mono = const TextStyle(fontFamily: 'monospace', fontSize: 12);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM spike (debug)'),
        actions: [
          IconButton(
            tooltip: 'Import models',
            icon: const Icon(Icons.file_open),
            onPressed: () => openImportModels(context),
          ),
          IconButton(
            tooltip: 'Debug log',
            icon: const Icon(Icons.article),
            onPressed: () => openDebugLog(context),
          ),
        ],
      ),
      body: exAsync.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Nilo-load ang LLM... / Loading model'),
            ],
          ),
        ),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SelectableText(
              e.toString(),
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => openImportModels(context),
              icon: const Icon(Icons.file_open),
              label: const Text('Import models'),
            ),
          ],
        ),
        data: (ex) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _input,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Transcript',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => _extractOne(ex),
                  child: const Text('Extract'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _runBatch(ex),
                  child: const Text('Run 15 test sentences'),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              Text(_batchProgress.isEmpty ? 'Running...' : _batchProgress),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (_last case final r?) ...[
              const Divider(height: 24),
              Text(
                '${r.llm.elapsedMs} ms · prompt ${r.llm.promptTokens} tok · '
                'gen ${r.llm.generatedTokens} tok · '
                '${r.llm.tokensPerSec.toStringAsFixed(1)} tok/s',
              ),
              Text(
                r.parse.valid
                    ? 'Schema: VALID'
                    : 'Schema: INVALID ${r.parse.errors}',
                style: TextStyle(
                  color: r.parse.valid ? Colors.green : theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Evidence in transcript: ${r.evidenceOk ? 'yes' : 'NO (low confidence)'}',
              ),
              const SizedBox(height: 8),
              const Text('Raw output:'),
              SelectableText(r.llm.text, style: mono),
              if (r.parse.json != null) ...[
                const SizedBox(height: 8),
                const Text('Parsed:'),
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert(r.parse.json),
                  style: mono,
                ),
              ],
            ],
            if (_batchReport case final rep?) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(child: Text('15-sentence results')),
                  TextButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: rep));
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Copied')));
                    },
                  ),
                ],
              ),
              SelectableText(rep, style: mono),
            ],
          ],
        ),
      ),
    );
  }
}
