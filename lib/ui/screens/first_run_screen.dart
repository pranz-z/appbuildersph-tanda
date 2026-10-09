import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../home_shell.dart';
import '../nav.dart';

/// Shows the first-run check while models are missing or failed to load;
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
    if (_skipped || !stt.hasError) return const HomeShell();

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Unang check / First-run check')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (stt.isLoading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Nilo-load ang Whisper... / Loading model'),
          ] else
            SelectableText(
              stt.error.toString(),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
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
            child: const Text('Ituloy pa rin / Continue without speech'),
          ),
        ],
      ),
    );
  }
}
