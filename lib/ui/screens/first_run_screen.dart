import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/model_locator.dart';
import '../../core/providers.dart';
import '../home_shell.dart';
import '../nav.dart';

/// Shows the first-run check while any model is missing or failed to load;
/// otherwise the normal app.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key});

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  bool _skipped = false;

  @override
  Widget build(BuildContext context) {
    final stt = ref.watch(sttServiceProvider);
    final llm = ref.watch(llmServiceProvider);
    final e5Missing = ref.watch(embeddingFilesMissingProvider).value ?? [];
    final problem = stt.hasError || llm.hasError || e5Missing.isNotEmpty;
    if (_skipped || !problem) return const HomeShell();

    final theme = Theme.of(context);
    Widget section(String title, AsyncValue<Object> v) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (v.isLoading)
            const Text('Nilo-load... / Loading')
          else if (v.hasError)
            SelectableText(
              v.error.toString(),
              style: TextStyle(color: theme.colorScheme.error),
            )
          else
            const Text('OK', style: TextStyle(color: Colors.green)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Unang check / First-run check')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section('Speech (Whisper)', stt),
          section('LLM (Qwen2.5 1.5B)', llm),
          Text('Embeddings (e5-small)', style: theme.textTheme.titleMedium),
          if (e5Missing.isEmpty)
            const Text('OK', style: TextStyle(color: Colors.green))
          else
            SelectableText(
              missingFilesMessage('Embedding model', e5Missing),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => openDownloadModels(context),
            icon: const Icon(Icons.download),
            label: const Text('Download models (needs internet once)'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => openImportModels(context),
            icon: const Icon(Icons.file_open),
            label: const Text('Import models'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => openDebugLog(context),
            icon: const Icon(Icons.article),
            label: const Text('Debug log'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _skipped = true),
            child: const Text('Ituloy pa rin / Continue anyway'),
          ),
        ],
      ),
    );
  }
}
