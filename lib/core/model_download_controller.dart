import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_log.dart';
import 'model_downloader.dart';
import 'providers.dart';
import 'storage_info.dart';

class ModelDownloadState {
  const ModelDownloadState({
    this.files = const [],
    this.running = false,
    this.error,
    this.errorKind,
    this.finished = false,
  });

  final List<FileDownloadProgress> files;
  final bool running;
  final String? error;
  final DownloadErrorKind? errorKind;

  /// All planned files downloaded and verified.
  final bool finished;

  int get totalBytes => files.fold(0, (s, f) => s + f.spec.size);
  int get receivedBytes => files.fold(0, (s, f) => s + f.received);
}

/// Owns the optional model download so it continues while the user moves
/// between screens. Nothing downloads until [start] is called from a tap.
class ModelDownloadController extends Notifier<ModelDownloadState> {
  CancelToken? _cancel;

  @override
  ModelDownloadState build() => const ModelDownloadState();

  Future<ModelDownloader> _downloader() async => ModelDownloader(
    modelsDir: await ref.read(modelLocatorProvider).primaryDir(),
    freeBytes: freeBytesAt,
  );

  /// Missing or incomplete required files, with bytes already saved in
  /// `.part` files. Does not touch the network.
  Future<void> refreshPlan() async {
    if (state.running) return;
    final missing = await ref.read(modelLocatorProvider).missingRequired();
    state = ModelDownloadState(files: (await _downloader()).plan(missing));
  }

  Future<void> start() async {
    if (state.running) return;
    await refreshPlan();
    if (state.files.isEmpty) {
      state = const ModelDownloadState(finished: true);
      return;
    }
    final cancel = _cancel = CancelToken();
    state = ModelDownloadState(files: state.files, running: true);
    appLog.i(
      'Model download start: '
      '${state.files.map((f) => '${f.spec.name} (${f.received}/${f.spec.size})').join(', ')}',
    );
    final downloader = await _downloader();
    try {
      await downloader.download(
        state.files,
        cancel: cancel,
        onProgress: () =>
            state = ModelDownloadState(files: state.files, running: true),
      );
      appLog.i('Model download finished');
      state = ModelDownloadState(files: state.files, finished: true);
    } on DownloadException catch (e, st) {
      if (e.kind == DownloadErrorKind.cancelled) {
        appLog.i('Model download cancelled');
      } else {
        appLog.e('Model download failed (${e.kind.name})', e, st);
      }
      state = ModelDownloadState(
        files: state.files,
        error: e.message,
        errorKind: e.kind,
      );
    } catch (e, st) {
      appLog.e('Model download failed', e, st);
      state = ModelDownloadState(
        files: state.files,
        error: 'Unexpected error: $e. Tap Download to retry.',
        errorKind: DownloadErrorKind.io,
      );
    } finally {
      _cancel = null;
      // Same reload path as Import models.
      if (ref.read(sttServiceProvider).hasError) {
        ref.invalidate(sttServiceProvider);
      }
      if (ref.read(llmServiceProvider).hasError) {
        ref.invalidate(llmServiceProvider);
      }
      ref.invalidate(embeddingFilesMissingProvider);
    }
  }

  void cancel() => _cancel?.cancel();
}

final modelDownloadProvider =
    NotifierProvider<ModelDownloadController, ModelDownloadState>(
      ModelDownloadController.new,
    );
