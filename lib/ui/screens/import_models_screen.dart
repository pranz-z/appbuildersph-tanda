import '../localization.dart';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../core/model_downloader.dart';
import '../../core/model_importer.dart';
import '../../core/model_locator.dart';
import '../../core/providers.dart';
import '../nav.dart';
import '../notebook_theme.dart';

/// Imports sideloaded model files from the phone (e.g. Downloads) via the
/// system file picker. No network.
class ImportModelsScreen extends ConsumerStatefulWidget {
  const ImportModelsScreen({super.key});

  @override
  ConsumerState<ImportModelsScreen> createState() => _ImportModelsScreenState();
}

class _ImportModelsScreenState extends ConsumerState<ImportModelsScreen> {
  Map<String, int?> _status = {};
  bool _picking = false;
  bool _importing = false;
  final _progress = <String, double>{};
  final _messages = <String>[];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await ref.read(modelLocatorProvider).status();
    if (mounted) setState(() => _status = s);
  }

  Future<void> _pick() async {
    setState(() {
      _messages.clear();
      _progress.clear();
      _importing = true;
    });
    try {
      final List<PlatformFile> files;
      try {
        files = await FilePicker.pickFiles(
          type: FileType.any,
          onFileLoading: (s) {
            if (mounted) {
              setState(() => _picking = s == FilePickerStatus.picking);
            }
          },
        );
      } finally {
        if (mounted) setState(() => _picking = false);
      }
      appLog.i(
        'Picked ${files.length} file(s): '
        '${files.map((f) => '${f.name} (${f.lengthSync()} B)').join(', ')}',
      );

      final importer = ModelImporter(ref.read(modelLocatorProvider));
      for (final f in files) {
        final target = ModelImporter.match(f.name);
        final path = f.path;
        if (target == null) {
          _messages.add(
            'Tinanggihan / Rejected: "${f.name}" is not an '
            'expected model file name. Expected names are listed above. '
            'If you renamed it, rename it back.',
          );
          continue;
        }
        if (path == null) {
          _messages.add('"${f.name}": picker returned no file path.');
          continue;
        }
        setState(() => _progress[target] = 0);
        try {
          await importer.importFile(
            File(path),
            target,
            onProgress: (done, total) {
              final v = total == 0 ? 1.0 : done / total;
              if (v == 1 || v - (_progress[target] ?? 0) >= 0.01) {
                if (mounted) setState(() => _progress[target] = v);
              }
            },
          );
          final locator = ref.read(modelLocatorProvider);
          if (await locator.find(target) == null) {
            final got = File(p.join(await locator.primaryDir(), target));
            final size = got.existsSync() ? got.lengthSync() : 0;
            final expected = specByName(target)!.size;
            appLog.i('Imported $target but size $size != $expected');
            _messages.add(
              'Hindi kumpleto / $target is ${formatMb(size)} but should be '
              '${formatMb(expected)}. The file is incomplete or a different '
              'version. Download it again, or use "Download models".',
            );
          } else {
            appLog.i('Imported $target');
            _messages.add('OK: $target');
          }
        } catch (e, st) {
          appLog.e('Import failed for ${f.name}', e, st);
          _messages.add('Failed: ${f.name}: $e');
          _progress.remove(target);
        }
      }
    } catch (e, st) {
      appLog.e('File picker failed', e, st);
      _messages.add('File picker error: $e');
    } finally {
      // Remove any remaining picker cache copies (e.g. rejected files).
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (e) {
        appLog.e('clearTemporaryFiles failed', e);
      }
      await _refresh();
      // Reload models that were missing or failed. Already-loaded ones stay.
      if (ref.read(sttServiceProvider).hasError) {
        ref.invalidate(sttServiceProvider);
      }
      if (ref.read(llmServiceProvider).hasError) {
        ref.invalidate(llmServiceProvider);
      }
      ref.invalidate(embeddingFilesMissingProvider);
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = <String, List<ModelFileSpec>>{};
    for (final s in modelManifest) {
      groups.putIfAbsent(s.group, () => []).add(s);
    }

    return Scaffold(
      appBar: AppBar(title: const UiText('Import models')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const NotebookHeader(
            title: 'Import models',
            subtitle: 'Use model files already on your phone.',
            icon: Icons.folder_open_outlined,
          ),
          const UiText(
            'Download the model files into Downloads, then tap the button '
            'and select them. Long-press a file in the picker to select '
            'several at once.\n'
            'Kailangan: Whisper small (o base bilang fallback).',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _importing ? null : _pick,
            icon: const Icon(Icons.file_open),
            label: const UiText('Pumili ng files / Select files'),
          ),
          TextButton.icon(
            onPressed: _importing ? null : () => openDownloadModels(context),
            icon: const Icon(Icons.download),
            label: const UiText('Or download them in the app (needs internet)'),
          ),
          if (_picking) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const UiText(
              'Kinukuha ang files... / Picker is reading the files '
              '(large files take a while)',
            ),
          ],
          for (final e in groups.entries) ...[
            const SizedBox(height: 16),
            UiText(e.key, style: theme.textTheme.titleMedium),
            for (final s in e.value) _fileRow(s, theme),
          ],
          if (_messages.isNotEmpty) ...[
            const Divider(height: 32),
            for (final m in _messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: UiText(
                  m,
                  style: TextStyle(
                    color: m.startsWith('OK')
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _fileRow(ModelFileSpec s, ThemeData theme) {
    final size = _status[s.name];
    final progress = _progress[s.name];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        size != null ? Icons.check_circle : Icons.radio_button_unchecked,
        color: size != null ? theme.colorScheme.primary : theme.disabledColor,
      ),
      title: Text(s.name),
      subtitle: progress != null && progress < 1
          ? LinearProgressIndicator(value: progress)
          : UiText(
              size != null
                  ? 'Nandito / Present · ${(size / 1e6).toStringAsFixed(1)} MB'
                  : 'Wala pa / Missing',
            ),
    );
  }
}
