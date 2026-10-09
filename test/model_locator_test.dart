import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tanda/core/model_locator.dart';

void main() {
  late Directory tmp;
  late ModelLocator locator;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tanda_models');
    locator = ModelLocator(baseDirOverride: tmp.path);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  void put(String name, {String content = 'x'}) {
    final f = File(p.join(tmp.path, 'models', 'whisper', name));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  test('reports all small files missing with adb push commands', () async {
    final c = await locator.checkWhisper();
    expect(c.ok, isFalse);
    expect(c.missing, ModelLocator.whisperFiles(WhisperVariant.small));
    expect(
      c.errorMessage,
      contains(
        'adb push small-encoder.int8.onnx '
        '/sdcard/Android/data/ph.tanda.app/files/models/whisper/'
        'small-encoder.int8.onnx',
      ),
    );
  });

  test('empty file counts as missing', () async {
    put('small-encoder.int8.onnx');
    put('small-decoder.int8.onnx', content: '');
    put('small-tokens.txt');
    final c = await locator.checkWhisper();
    expect(c.missing, ['small-decoder.int8.onnx']);
  });

  test('prefers small, falls back to base', () async {
    ModelLocator.whisperFiles(WhisperVariant.base).forEach(put);
    expect((await locator.checkWhisper()).paths!.variant, WhisperVariant.base);

    ModelLocator.whisperFiles(WhisperVariant.small).forEach(put);
    final c = await locator.checkWhisper();
    expect(c.paths!.variant, WhisperVariant.small);
    expect(c.paths!.encoder, endsWith('small-encoder.int8.onnx'));
  });
}
