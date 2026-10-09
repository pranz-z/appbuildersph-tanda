import 'dart:io';

import 'package:path/path.dart' as p;

import 'model_locator.dart';

/// Matches picked files against the manifest and moves them into the models
/// folder.
class ModelImporter {
  ModelImporter(this.locator);

  final ModelLocator locator;

  /// Browsers name re-downloads "file (1).onnx"; accept those too.
  static final _dupSuffix = RegExp(r' \(\d+\)(?=\.[^.]+$)');

  /// Manifest name for a picked file, or null if it is not an expected file.
  static String? match(String pickedName) {
    final name = pickedName.trim().replaceFirst(_dupSuffix, '');
    for (final s in modelManifest) {
      if (s.name == name) return s.name;
    }
    return null;
  }

  /// Moves [src] into the models folder as [targetName].
  ///
  /// The picker's cache copy lives on the same partition as the app's files
  /// dir, so a rename is instant and uses no extra space. If rename fails, it
  /// falls back to a streaming copy (never the whole file in memory) and then
  /// deletes [src]. The file only gets its final name once complete.
  Future<void> importFile(
    File src,
    String targetName, {
    void Function(int done, int total)? onProgress,
  }) async {
    final dir = await locator.primaryDir();
    final target = File(p.join(dir, targetName));
    final total = await src.length();
    try {
      await src.rename(target.path);
      onProgress?.call(total, total);
      return;
    } on FileSystemException {
      // Different filesystem: copy instead.
    }
    final part = File('${target.path}.part');
    final sink = part.openWrite();
    var done = 0;
    try {
      await sink.addStream(
        src.openRead().map((chunk) {
          done += chunk.length;
          onProgress?.call(done, total);
          return chunk;
        }),
      );
    } finally {
      await sink.close();
    }
    if (await part.length() != total) {
      await part.delete();
      throw FileSystemException('Copy incomplete', targetName);
    }
    await part.rename(target.path);
    await src.delete();
  }
}
