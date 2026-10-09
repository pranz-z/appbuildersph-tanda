import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locality_meter.dart';
import '../../core/session_usage.dart';
import '../localization.dart';
import '../notebook_theme.dart';

class LocalityMeterBar extends ConsumerWidget {
  const LocalityMeterBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = ref.watch(networkStatusProvider),
        traffic = ref.watch(sessionTrafficBytesProvider);
    final usage = ref.watch(sessionUsageProvider);
    final status = network.when(
      data: (value) => switch (value) {
        NetworkStatus.online => 'Online',
        NetworkStatus.offline => 'Offline',
        NetworkStatus.unavailable => 'Unavailable',
      },
      loading: () => 'Checking...',
      error: (_, _) => 'Unavailable',
    );
    final bytes = traffic.when(
      data: (value) => value == null ? 'Unavailable' : _formatBytes(value),
      loading: () => 'Checking...',
      error: (_, _) => 'Unavailable',
    );
    final source = traffic.value == null
        ? 'Source unavailable · Android TrafficStats app UID transmit counter'
        : 'Source: Android TrafficStats app UID transmit counter · includes downloader requests';
    final calls =
        'On-device calls · this session: Transcription ${usage.transcriptionCalls} · LLM ${usage.llmCalls} · Embeddings inactive (${usage.embeddingCalls} calls)';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        status == 'Offline'
                            ? Icons.wifi_off_rounded
                            : Icons.phone_android_rounded,
                        size: 16,
                      ),
                      UiText(
                        status,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      UiText(
                        'Bytes sent by app · this session:',
                        style: const TextStyle(fontSize: 11),
                      ),
                      UiText(
                        bytes,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  UiText(calls, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              tooltip: tr(context, 'Session details'),
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (sheet) => SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NotebookHeader(
                          title: 'Locality meter',
                          subtitle: 'Session details',
                          icon: Icons.phone_android_rounded,
                        ),
                        UiText(source),
                        const SizedBox(height: 12),
                        UiText(calls),
                        const SizedBox(height: 12),
                        const UiText(
                          'Network status shows connectivity, not internet reachability.',
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pop(sheet),
                            child: const UiText('Close'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
