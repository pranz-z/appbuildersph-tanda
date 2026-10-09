import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tanda/core/model_importer.dart';
import 'package:tanda/core/model_locator.dart';

void main() {
  late Directory tmp;
  late ModelLocator locator;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tanda_models');
    locator = ModelLocator(
      primaryDirOverride: p.join(tmp.path, 'internal'),
      altDirOverride: p.join(tmp.path, 'external', 'models'),
    );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  void put(String name, {String content = 'x', String where = 'internal'}) {
    final dir = where == 'internal'
        ? p.join(tmp.path, 'internal', 'models')
        : p.join(tmp.path, 'external', 'models');
    final f = File(p.join(dir, name));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  List<String> names(WhisperVariant v) =>
      whisperSpecs(v).map((s) => s.name).toList();

  test(
    'missing message names files, download URLs, Import models, no adb',
    () async {
      final c = await locator.checkWhisper();
      expect(c.ok, isFalse);
      expect(c.missing.map((s) => s.name), names(WhisperVariant.small));
      expect(c.errorMessage, contains('small-encoder.int8.onnx'));
      expect(
        c.errorMessage,
        contains(
          'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/'
          'resolve/main/small-encoder.int8.onnx',
        ),
      );
      expect(c.errorMessage, contains('Import models'));
      expect(c.errorMessage.toLowerCase(), isNot(contains('adb')));
    },
  );

  test('empty file counts as missing', () async {
    put('small-encoder.int8.onnx');
    put('small-decoder.int8.onnx', content: '');
    put('small-tokens.txt');
    final c = await locator.checkWhisper();
    expect(c.missing.map((s) => s.name), ['small-decoder.int8.onnx']);
  });

  test('prefers small, falls back to base', () async {
    names(WhisperVariant.base).forEach(put);
    expect((await locator.checkWhisper()).paths!.variant, WhisperVariant.base);

    names(WhisperVariant.small).forEach(put);
    final c = await locator.checkWhisper();
    expect(c.paths!.variant, WhisperVariant.small);
    expect(c.paths!.encoder, endsWith('small-encoder.int8.onnx'));
  });

  test('also finds files in the optional adb (external) dir', () async {
    for (final n in names(WhisperVariant.small)) {
      put(n, where: 'external');
    }
    expect((await locator.checkWhisper()).ok, isTrue);
  });

  test('status reports sizes for present files', () async {
    put('small-tokens.txt', content: 'abc');
    final s = await locator.status();
    expect(s['small-tokens.txt'], 3);
    expect(s['small-encoder.int8.onnx'], isNull);
    expect(s.length, 6);
  });

  group('ModelImporter', () {
    test('match accepts manifest names and browser duplicates only', () {
      expect(
        ModelImporter.match('small-encoder.int8.onnx'),
        'small-encoder.int8.onnx',
      );
      expect(
        ModelImporter.match('small-encoder.int8 (1).onnx'),
        'small-encoder.int8.onnx',
      );
      expect(ModelImporter.match('base-tokens.txt'), 'base-tokens.txt');
      expect(ModelImporter.match('small-encoder.onnx'), isNull);
      expect(ModelImporter.match('photo.jpg'), isNull);
    });

    test('importFile moves the source into the models dir', () async {
      final src = File(p.join(tmp.path, 'cache', 'small-tokens.txt'))
        ..createSync(recursive: true)
        ..writeAsStringSync('hello');
      int? lastDone;
      await ModelImporter(
        locator,
      ).importFile(src, 'small-tokens.txt', onProgress: (d, t) => lastDone = d);
      expect(src.existsSync(), isFalse);
      expect(lastDone, 5);
      final f = await locator.find('small-tokens.txt');
      expect(f!.readAsStringSync(), 'hello');
    });
  });
}
