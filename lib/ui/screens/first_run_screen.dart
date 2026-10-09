import '../localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../home_shell.dart';
import '../nav.dart';
import '../notebook_theme.dart';

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
          UiText(title, style: theme.textTheme.titleMedium),
          if (v.isLoading)
            const UiText('Nilo-load... / Loading')
          else if (v.hasError)
            UiText(
              'Models are not ready. Check setup or use typed entry.',
              style: TextStyle(color: theme.colorScheme.error),
            )
          else
            UiText(
              'OK',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('tanda.'),
        actions: [
          IconButton(
            tooltip: tr(context, 'Settings'),
            icon: const Icon(Icons.tune),
            onPressed: () => openSettings(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const NotebookHeader(
            title: 'Unang check / First-run check',
            subtitle: 'Your memories stay on this device.',
            icon: Icons.menu_book_outlined,
          ),
          section('Speech (Whisper)', stt),
          section('LLM (Qwen2.5 1.5B)', llm),
          UiText('Embeddings (e5-small)', style: theme.textTheme.titleMedium),
          if (e5Missing.isEmpty)
            UiText(
              'OK',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            )
          else
            UiText(
              'Embedding files are missing. Download or import the model files.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => openDownloadModels(context),
            icon: const Icon(Icons.download),
            label: const UiText('Download models (needs internet once)'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _skipped = true),
            child: const UiText('Ituloy pa rin / Continue anyway'),
          ),
        ],
      ),
    );
  }
}
