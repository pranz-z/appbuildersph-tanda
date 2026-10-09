import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:tanda/core/model_downloader.dart';
import 'package:tanda/core/model_locator.dart';

/// A tiny fake "model" served by a mock HTTP server.
class FakeServer {
  FakeServer(this.data, {this.supportsRange = true, this.chunk = 10});

  final Uint8List data;
  bool supportsRange;
  final int chunk;

  /// Fail the stream after this many bytes (connection drop), once.
  int? dropAfter;
  int? forceStatus;
  int? overrideContentLength;
  bool redirectFirst = false;
  final requests = <http.BaseRequest>[];

  http.Client client() => MockClient.streaming((req, _) async {
    requests.add(req);
    if (redirectFirst && !req.url.path.startsWith('/cdn')) {
      return http.StreamedResponse(
        const Stream.empty(),
        302,
        headers: {'location': '/cdn${req.url.path}'},
      );
    }
    if (forceStatus != null) {
      return http.StreamedResponse(const Stream.empty(), forceStatus!);
    }
    var start = 0;
    final range = req.headers['range'];
    if (range != null && supportsRange) {
      start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
    }
    final body = data.sublist(start);
    final drop = dropAfter;
    dropAfter = null;
    Stream<List<int>> stream() async* {
      var sent = 0;
      for (var i = 0; i < body.length; i += chunk) {
        if (drop != null && sent >= drop) {
          throw http.ClientException('connection reset');
        }
        final c = body.sublist(i, (i + chunk).clamp(0, body.length));
        sent += c.length;
        await Future<void>.delayed(Duration.zero);
        yield c;
      }
    }

    return http.StreamedResponse(
      stream(),
      start > 0 ? 206 : 200,
      contentLength: overrideContentLength ?? body.length,
      headers: start > 0
          ? {'content-range': 'bytes $start-${data.length - 1}/${data.length}'}
          : {},
    );
  });
}

void main() {
  late Directory tmp;
  final data = Uint8List.fromList(List.generate(95, (i) => i));
  final sha = crypto.sha256.convert(data).toString();
  ModelFileSpec spec(String name, {String? hash, int? size}) => ModelFileSpec(
    name,
    'test',
    'https://example.test/$name',
    size: size ?? data.length,
    sha256: hash,
  );

  setUp(() => tmp = Directory.systemTemp.createTempSync('tanda_dl'));
  tearDown(() => tmp.deleteSync(recursive: true));

  ModelDownloader dl(FakeServer s, {Future<int?> Function(String)? free}) =>
      ModelDownloader(
        modelsDir: tmp.path,
        clientFactory: s.client,
        freeBytes: free,
        progressInterval: Duration.zero,
      );
  File target(String n) => File(p.join(tmp.path, n));
  File part(String n) => File(p.join(tmp.path, '$n.part'));

  test('fresh download: progress states, checksum, rename', () async {
    final s = FakeServer(data);
    final d = dl(s);
    final files = d.plan([spec('m.bin', hash: sha)]);
    final seen = <FileDownloadStatus>[];
    await d.download(files, onProgress: () => seen.add(files.single.status));
    expect(seen.first, FileDownloadStatus.downloading);
    expect(seen, contains(FileDownloadStatus.verifying));
    expect(seen.last, FileDownloadStatus.done);
    expect(files.single.received, data.length);
    expect(target('m.bin').readAsBytesSync(), data);
    expect(part('m.bin').existsSync(), isFalse);
    expect(s.requests.single.headers['range'], isNull);
  });

  test('resumes from an existing .part with a Range request', () async {
    part('m.bin').writeAsBytesSync(data.sublist(0, 40));
    final s = FakeServer(data);
    final d = dl(s);
    final files = d.plan([spec('m.bin', hash: sha)]);
    expect(files.single.received, 40);
    await d.download(files);
    expect(s.requests.single.headers['range'], 'bytes=40-');
    expect(target('m.bin').readAsBytesSync(), data);
  });

  test('server without Range support restarts the file safely', () async {
    part('m.bin').writeAsBytesSync(data.sublist(0, 40));
    final s = FakeServer(data, supportsRange: false);
    final files = dl(s).plan([spec('m.bin', hash: sha)]);
    await dl(s).download(files);
    expect(files.single.note, contains('restarted'));
    expect(target('m.bin').readAsBytesSync(), data);
  });

  test('cancel keeps the partial file, then resume completes', () async {
    final s = FakeServer(data);
    final d = dl(s);
    final cancel = CancelToken();
    final files = d.plan([spec('m.bin', hash: sha)]);
    await expectLater(
      d.download(
        files,
        cancel: cancel,
        onProgress: () {
          if (files.single.received >= 30) cancel.cancel();
        },
      ),
      throwsA(
        isA<DownloadException>().having(
          (e) => e.kind,
          'kind',
          DownloadErrorKind.cancelled,
        ),
      ),
    );
    expect(target('m.bin').existsSync(), isFalse);
    final saved = part('m.bin').lengthSync();
    expect(saved, inInclusiveRange(30, data.length - 1));

    final again = d.plan([spec('m.bin', hash: sha)]);
    expect(again.single.received, saved);
    await d.download(again);
    expect(s.requests.last.headers['range'], 'bytes=$saved-');
    expect(target('m.bin').readAsBytesSync(), data);
  });

  test('connection drop keeps data; retry resumes and succeeds', () async {
    final s = FakeServer(data)..dropAfter = 50;
    final d = dl(s);
    await expectLater(
      d.download(d.plan([spec('m.bin', hash: sha)])),
      throwsA(
        isA<DownloadException>()
            .having((e) => e.kind, 'kind', DownloadErrorKind.offline)
            .having((e) => e.message, 'msg', contains('resume')),
      ),
    );
    expect(part('m.bin').lengthSync(), 50);
    await d.download(d.plan([spec('m.bin', hash: sha)]));
    expect(target('m.bin').readAsBytesSync(), data);
  });

  test('checksum mismatch deletes the file and is not marked ready; '
      'retry with good data succeeds', () async {
    final s = FakeServer(data);
    final d = dl(s);
    final bad = spec('m.bin', hash: '0' * 64);
    final files = d.plan([bad]);
    await expectLater(
      d.download(files),
      throwsA(
        isA<DownloadException>().having(
          (e) => e.kind,
          'kind',
          DownloadErrorKind.integrity,
        ),
      ),
    );
    expect(files.single.status, FileDownloadStatus.failed);
    expect(target('m.bin').existsSync(), isFalse);
    expect(part('m.bin').existsSync(), isFalse);
    await d.download(d.plan([spec('m.bin', hash: sha)]));
    expect(target('m.bin').existsSync(), isTrue);
  });

  test('unexpected Content-Length is an integrity error', () async {
    final s = FakeServer(data)..overrideContentLength = 10;
    final d = dl(s);
    await expectLater(
      d.download(d.plan([spec('m.bin')])),
      throwsA(
        isA<DownloadException>().having(
          (e) => e.kind,
          'kind',
          DownloadErrorKind.integrity,
        ),
      ),
    );
    expect(target('m.bin').existsSync(), isFalse);
  });

  test('short download (size mismatch) is never marked ready', () async {
    // Spec claims more bytes than the server has.
    final s = FakeServer(data)..overrideContentLength = 200;
    final d = dl(s);
    await expectLater(
      d.download(d.plan([spec('m.bin', size: 200)])),
      throwsA(isA<DownloadException>()),
    );
    expect(target('m.bin').existsSync(), isFalse);
  });

  test('insufficient storage stops before any request', () async {
    final s = FakeServer(data);
    final d = dl(s, free: (_) async => 1000);
    await expectLater(
      d.download(d.plan([spec('m.bin')])),
      throwsA(
        isA<DownloadException>().having(
          (e) => e.kind,
          'kind',
          DownloadErrorKind.insufficientStorage,
        ),
      ),
    );
    expect(s.requests, isEmpty);
  });

  test('offline (no connection) gives an actionable message', () async {
    final d = ModelDownloader(
      modelsDir: tmp.path,
      clientFactory: () =>
          MockClient((_) => throw http.ClientException('Failed host lookup')),
    );
    await expectLater(
      d.download(d.plan([spec('m.bin')])),
      throwsA(
        isA<DownloadException>()
            .having((e) => e.kind, 'kind', DownloadErrorKind.offline)
            .having((e) => e.message, 'msg', contains('Wi-Fi')),
      ),
    );
  });

  test('HTTP error is reported with the status code', () async {
    final s = FakeServer(data)..forceStatus = 503;
    final d = dl(s);
    await expectLater(
      d.download(d.plan([spec('m.bin')])),
      throwsA(
        isA<DownloadException>()
            .having((e) => e.kind, 'kind', DownloadErrorKind.http)
            .having((e) => e.message, 'msg', contains('503')),
      ),
    );
  });

  test('follows redirects and re-sends Range to the new location', () async {
    part('m.bin').writeAsBytesSync(data.sublist(0, 20));
    final s = FakeServer(data)..redirectFirst = true;
    final d = dl(s);
    await d.download(d.plan([spec('m.bin', hash: sha)]));
    expect(s.requests.map((r) => r.url.path), ['/m.bin', '/cdn/m.bin']);
    expect(s.requests.last.headers['range'], 'bytes=20-');
    expect(target('m.bin').readAsBytesSync(), data);
  });

  test('downloads files sequentially and skips complete ones', () async {
    target('a.bin').writeAsBytesSync(data);
    final s = FakeServer(data);
    final d = dl(s);
    final files = d.plan([spec('a.bin'), spec('b.bin'), spec('c.bin')]);
    await d.download(files);
    expect(s.requests.map((r) => r.url.path), ['/b.bin', '/c.bin']);
    expect(files.every((f) => f.status == FileDownloadStatus.done), isTrue);
  });

  test('sha256OfFile matches crypto on a file', () async {
    final f = File(p.join(tmp.path, 'h'))..writeAsBytesSync(data);
    expect(await sha256OfFile(f.path), sha);
  });
}
