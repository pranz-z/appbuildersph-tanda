import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'model_locator.dart';

enum DownloadErrorKind {
  insufficientStorage,
  offline,
  http,
  cancelled,
  resumeUnsupported,
  integrity,
  io,
}

class DownloadException implements Exception {
  DownloadException(this.kind, this.message);
  final DownloadErrorKind kind;
  final String message;
  @override
  String toString() => message;
}

enum FileDownloadStatus { pending, downloading, verifying, done, failed }

class FileDownloadProgress {
  FileDownloadProgress(this.spec, this.received);

  final ModelFileSpec spec;
  int received;
  FileDownloadStatus status = FileDownloadStatus.pending;

  /// Extra info shown to the user, e.g. "server did not resume".
  String? note;
}

class CancelToken {
  bool _cancelled = false;
  final _callbacks = <void Function()>[];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final c in List.of(_callbacks)) {
      c();
    }
  }

  void _onCancel(void Function() c) => _callbacks.add(c);
  void _remove(void Function() c) => _callbacks.remove(c);
}

Future<String> sha256OfFile(String path) => Isolate.run(
  () async =>
      (await crypto.sha256.bind(File(path).openRead()).first).toString(),
);

String formatMb(int bytes) => '${(bytes / 1e6).toStringAsFixed(1)} MB';

/// Downloads model files one at a time into [modelsDir] as `<name>.part`,
/// resumes with HTTP Range, verifies size (and SHA-256 when known), and only
/// then renames to `<name>`, where [ModelLocator] picks it up.
class ModelDownloader {
  ModelDownloader({
    required this.modelsDir,
    http.Client Function()? clientFactory,
    this.freeBytes,
    this.hashFile = sha256OfFile,
    this.idleTimeout = const Duration(seconds: 30),
    this.progressInterval = const Duration(milliseconds: 250),
  }) : clientFactory = clientFactory ?? http.Client.new;

  final String modelsDir;
  final http.Client Function() clientFactory;

  /// Free bytes at [modelsDir], or null if unknown.
  final Future<int?> Function(String dir)? freeBytes;
  final Future<String> Function(String path) hashFile;
  final Duration idleTimeout;
  final Duration progressInterval;

  /// Keep this much free after downloading.
  static const storageMargin = 100 * 1000 * 1000;

  File _part(ModelFileSpec s) => File(p.join(modelsDir, '${s.name}.part'));

  /// Progress entries for [specs], pre-filled with bytes already in `.part`.
  List<FileDownloadProgress> plan(List<ModelFileSpec> specs) => [
    for (final s in specs)
      FileDownloadProgress(s, () {
        final f = _part(s);
        final len = f.existsSync() ? f.lengthSync() : 0;
        return len > s.size ? 0 : len;
      }()),
  ];

  /// Downloads [files] sequentially. Throws [DownloadException] on the first
  /// failure; completed files stay, partial data is kept when it is safe to
  /// resume from it.
  Future<void> download(
    List<FileDownloadProgress> files, {
    CancelToken? cancel,
    void Function()? onProgress,
  }) async {
    cancel ??= CancelToken();
    await Directory(modelsDir).create(recursive: true);
    final remaining = files.fold<int>(
      0,
      (sum, f) => sum + f.spec.size - f.received,
    );
    final free = await freeBytes?.call(modelsDir);
    if (free != null && free < remaining + storageMargin) {
      throw DownloadException(
        DownloadErrorKind.insufficientStorage,
        'Kulang ang storage / Not enough storage: need about '
        '${formatMb(remaining + storageMargin)} free, the phone has '
        '${formatMb(free)}. Free up space (or delete the copies in Downloads) '
        'and tap Download again.',
      );
    }
    for (final f in files) {
      try {
        await _downloadOne(f, cancel, onProgress ?? () {});
      } catch (_) {
        f.status = FileDownloadStatus.failed;
        onProgress?.call();
        rethrow;
      }
    }
  }

  Future<void> _downloadOne(
    FileDownloadProgress f,
    CancelToken cancel,
    void Function() emit,
  ) async {
    final spec = f.spec;
    final target = File(p.join(modelsDir, spec.name));
    final part = _part(spec);
    if (target.existsSync() && target.lengthSync() == spec.size) {
      f
        ..received = spec.size
        ..status = FileDownloadStatus.done;
      emit();
      return;
    }
    var offset = part.existsSync() ? part.lengthSync() : 0;
    if (offset > spec.size) {
      part.deleteSync();
      offset = 0;
    }
    if (offset < spec.size) {
      await _fetch(f, part, offset, cancel, emit);
    }

    final len = part.lengthSync();
    if (len != spec.size) {
      throw DownloadException(
        DownloadErrorKind.offline,
        'Naputol ang download / Download of ${spec.name} ended early '
        '(${formatMb(len)} of ${formatMb(spec.size)}). The partial file is '
        'kept; tap Download to resume.',
      );
    }
    if (spec.sha256 != null) {
      f.status = FileDownloadStatus.verifying;
      emit();
      final actual = await hashFile(part.path);
      if (actual != spec.sha256) {
        part.deleteSync();
        throw DownloadException(
          DownloadErrorKind.integrity,
          'Sira ang file / ${spec.name} failed the checksum check, so it was '
          'deleted. Tap Download to fetch it again.',
        );
      }
    }
    if (target.existsSync()) target.deleteSync();
    part.renameSync(target.path);
    f.status = FileDownloadStatus.done;
    emit();
  }

  Future<void> _fetch(
    FileDownloadProgress f,
    File part,
    int offset,
    CancelToken cancel,
    void Function() emit,
  ) async {
    final spec = f.spec;
    f
      ..status = FileDownloadStatus.downloading
      ..received = offset;
    emit();
    if (cancel.isCancelled) throw _cancelled(spec);

    final client = clientFactory();
    void abort() => client.close();
    cancel._onCancel(abort);
    var gotResponse = false;
    try {
      final resp = await _send(client, Uri.parse(spec.url), offset);
      gotResponse = true;
      var start = offset;
      if (offset > 0 && resp.statusCode == 206) {
        final range = resp.headers['content-range'] ?? '';
        if (!range.startsWith('bytes $offset-')) {
          part.deleteSync();
          throw DownloadException(
            DownloadErrorKind.resumeUnsupported,
            'The server answered the resume request with an unexpected range '
            '("$range"), so the partial ${spec.name} was discarded. Tap '
            'Download to start this file again.',
          );
        }
      } else if (resp.statusCode == 200) {
        if (offset > 0) {
          // Server ignored Range: restart this file from zero, safely.
          f.note = 'Server did not support resume; restarted from 0.';
          start = 0;
          f.received = 0;
        }
      } else if (resp.statusCode == 416) {
        part.deleteSync();
        throw DownloadException(
          DownloadErrorKind.resumeUnsupported,
          'The server could not resume ${spec.name} (HTTP 416). The partial '
          'file was discarded; tap Download to start it again.',
        );
      } else {
        throw DownloadException(
          DownloadErrorKind.http,
          'Server error HTTP ${resp.statusCode} for ${spec.name}. Partial '
          'data is kept. Check the connection and tap Download to retry.',
        );
      }

      final expectedLen = spec.size - start;
      if (resp.contentLength != null && resp.contentLength != expectedLen) {
        if (start == 0 && part.existsSync()) part.deleteSync();
        throw DownloadException(
          DownloadErrorKind.integrity,
          'The server is sending ${formatMb(resp.contentLength!)} for '
          '${spec.name} but ${formatMb(expectedLen)} was expected. The file '
          'may have changed upstream; use "Import models" instead.',
        );
      }

      final raf = await part.open(
        mode: start == 0 ? FileMode.write : FileMode.append,
      );
      final tick = Stopwatch()..start();
      try {
        await for (final chunk in resp.stream.timeout(idleTimeout)) {
          if (cancel.isCancelled) break;
          if (f.received + chunk.length > spec.size) {
            await raf.close();
            part.deleteSync();
            throw DownloadException(
              DownloadErrorKind.integrity,
              'The server sent more data than expected for ${spec.name}; the '
              'partial file was deleted. Tap Download to retry.',
            );
          }
          await raf.writeFrom(chunk);
          f.received += chunk.length;
          if (tick.elapsed >= progressInterval) {
            tick.reset();
            emit();
          }
        }
      } finally {
        try {
          await raf.close();
        } catch (_) {}
      }
      emit();
      if (cancel.isCancelled) throw _cancelled(spec);
    } on DownloadException {
      rethrow;
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode == 28) {
        throw DownloadException(
          DownloadErrorKind.insufficientStorage,
          'Puno na ang storage / The phone ran out of storage while saving '
          '${spec.name}. Free up space and tap Download to resume.',
        );
      }
      throw DownloadException(
        DownloadErrorKind.io,
        'Could not write ${spec.name}: ${e.message}. Tap Download to retry.',
      );
    } on Object catch (e) {
      if (cancel.isCancelled) throw _cancelled(spec);
      if (e is! http.ClientException &&
          e is! IOException &&
          e is! TimeoutException) {
        rethrow;
      }
      throw DownloadException(
        DownloadErrorKind.offline,
        gotResponse
            ? 'Naputol ang koneksyon / Connection lost while downloading '
                  '${spec.name} (${formatMb(f.received)} saved). Tap Download '
                  'to resume.'
            : 'Walang internet / Could not reach the download server. Turn '
                  'off airplane mode, connect to Wi-Fi, and tap Download.',
      );
    } finally {
      cancel._remove(abort);
      client.close();
    }
  }

  DownloadException _cancelled(ModelFileSpec s) => DownloadException(
    DownloadErrorKind.cancelled,
    'Na-cancel / Download cancelled. The partial ${s.name} is kept; tap '
    'Download to resume.',
  );

  /// GET with an optional Range header, following redirects manually so the
  /// Range header is re-sent to the CDN.
  Future<http.StreamedResponse> _send(
    http.Client client,
    Uri url,
    int offset,
  ) async {
    var uri = url;
    for (var hop = 0; hop < 6; hop++) {
      final req = http.Request('GET', uri)..followRedirects = false;
      if (offset > 0) req.headers['range'] = 'bytes=$offset-';
      final resp = await client.send(req).timeout(idleTimeout);
      final location = resp.headers['location'];
      if (resp.isRedirect ||
          (resp.statusCode ~/ 100 == 3 && location != null)) {
        await resp.stream.drain<void>();
        if (location == null) break;
        uri = uri.resolve(location);
        continue;
      }
      return resp;
    }
    throw http.ClientException('Too many redirects', url);
  }
}
