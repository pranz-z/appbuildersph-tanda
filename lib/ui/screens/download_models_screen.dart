import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/model_download_controller.dart';
import '../../core/model_downloader.dart';
import '../nav.dart';

/// Optional downloader. Nothing is fetched until the user taps Download.
class DownloadModelsScreen extends ConsumerStatefulWidget {
  const DownloadModelsScreen({super.key});

  @override
  ConsumerState<DownloadModelsScreen> createState() =>
      _DownloadModelsScreenState();
}

class _DownloadModelsScreenState extends ConsumerState<DownloadModelsScreen> {
  bool _planned = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(modelDownloadProvider.notifier).refreshPlan();
      if (mounted) setState(() => _planned = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(modelDownloadProvider);
    final ctrl = ref.read(modelDownloadProvider.notifier);
    final theme = Theme.of(context);
    final toFetch = s.totalBytes - s.receivedBytes;
    final partial = s.files.fold<int>(
      0,
      (sum, f) => f.status == FileDownloadStatus.done ? sum : sum + f.received,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Download models')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Internet is needed only to download the models (once). After '
            'that, Tanda works fully offline, including in airplane mode. '
            'Files are saved in the app\'s private storage.\n'
            'Kailangan lang ng internet para i-download ang models.',
          ),
          const SizedBox(height: 12),
          if (!_planned)
            const LinearProgressIndicator()
          else if (s.files.isEmpty || s.finished)
            Text(
              'Kumpleto na / All required models are present.',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            )
          else ...[
            Text(
              s.running
                  ? 'Nagda-download... / Downloading'
                  : 'To download: ${formatMb(toFetch)}'
                        '${partial > 0 ? ' (${formatMb(partial)} already saved, will resume)' : ''}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: s.totalBytes == 0 ? null : s.receivedBytes / s.totalBytes,
            ),
            Text('${formatMb(s.receivedBytes)} / ${formatMb(s.totalBytes)}'),
            const SizedBox(height: 12),
            if (s.running)
              OutlinedButton.icon(
                onPressed: ctrl.cancel,
                icon: const Icon(Icons.stop),
                label: const Text('Cancel'),
              )
            else
              FilledButton.icon(
                onPressed: ctrl.start,
                icon: const Icon(Icons.download),
                label: Text(
                  s.error == null
                      ? 'Download ${formatMb(toFetch)}'
                      : 'Subukan muli / Retry (${formatMb(toFetch)})',
                ),
              ),
          ],
          if (s.error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(s.error!),
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final f in s.files) _fileRow(f, theme),
          const Divider(height: 32),
          const Text(
            'Downloads continue if you leave this screen. If the app is '
            'closed or the connection drops, tap Download again to resume.',
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: s.running ? null : () => openImportModels(context),
            icon: const Icon(Icons.file_open),
            label: const Text('Import models instead (from Downloads)'),
          ),
        ],
      ),
    );
  }

  Widget _fileRow(FileDownloadProgress f, ThemeData theme) {
    final (icon, color, label) = switch (f.status) {
      FileDownloadStatus.done => (
        Icons.check_circle,
        Colors.green,
        'Tapos / Done',
      ),
      FileDownloadStatus.downloading => (
        Icons.downloading,
        theme.colorScheme.primary,
        'Downloading',
      ),
      FileDownloadStatus.verifying => (
        Icons.verified_outlined,
        theme.colorScheme.primary,
        'Verifying checksum...',
      ),
      FileDownloadStatus.failed => (
        Icons.error,
        theme.colorScheme.error,
        'Stopped',
      ),
      FileDownloadStatus.pending => (
        Icons.radio_button_unchecked,
        theme.disabledColor,
        f.received > 0 ? 'Partly saved' : 'Waiting',
      ),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(f.spec.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: f.status == FileDownloadStatus.verifying
                ? null
                : f.received / f.spec.size,
          ),
          Text(
            '$label · ${formatMb(f.received)} / ${formatMb(f.spec.size)}'
            '${f.spec.sha256 == null ? ' · size check only' : ''}'
            '${f.note == null ? '' : '\n${f.note}'}',
          ),
        ],
      ),
    );
  }
}
