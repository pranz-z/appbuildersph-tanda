import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const androidPackageId = 'ph.tanda.app';

/// Where `getExternalStorageDirectory()` points on Android, as seen by adb.
const adbFilesDir = '/sdcard/Android/data/$androidPackageId/files';

enum WhisperVariant { small, base }

class WhisperPaths {
  const WhisperPaths({
    required this.variant,
    required this.encoder,
    required this.decoder,
    required this.tokens,
  });

  final WhisperVariant variant;
  final String encoder;
  final String decoder;
  final String tokens;
}

class WhisperCheck {
  const WhisperCheck({required this.dir, required this.missing, this.paths});

  final String dir;

  /// Missing (or empty) files for the preferred variant (small).
  final List<String> missing;

  final WhisperPaths? paths;

  bool get ok => paths != null;

  String get errorMessage {
    final cmds = missing
        .map((f) => 'adb push $f $adbFilesDir/models/whisper/$f')
        .join('\n');
    return 'Whisper model files not found in:\n$dir\n\n'
        'Missing:\n${missing.map((f) => '  - $f').join('\n')}\n\n'
        'Fix (run on the laptop, inside the extracted model folder):\n$cmds\n\n'
        'Then restart the app.';
  }
}

/// Finds sideloaded model files. Models are never bundled in the APK.
class ModelLocator {
  ModelLocator({this.baseDirOverride});

  /// For tests. On device, the app's external files dir is used.
  final String? baseDirOverride;

  static List<String> whisperFiles(WhisperVariant v) => [
    '${v.name}-encoder.int8.onnx',
    '${v.name}-decoder.int8.onnx',
    '${v.name}-tokens.txt',
  ];

  Future<String> modelsDir() async {
    if (baseDirOverride != null) return p.join(baseDirOverride!, 'models');
    final ext = await getExternalStorageDirectory();
    if (ext == null) {
      throw StateError('External files directory is not available.');
    }
    return p.join(ext.path, 'models');
  }

  /// Prefers Whisper small; falls back to base if only base is present.
  Future<WhisperCheck> checkWhisper() async {
    final dir = p.join(await modelsDir(), 'whisper');
    await Directory(dir).create(recursive: true);

    List<String> missingFor(WhisperVariant v) => whisperFiles(v).where((f) {
      final file = File(p.join(dir, f));
      return !file.existsSync() || file.lengthSync() == 0;
    }).toList();

    for (final v in WhisperVariant.values) {
      if (missingFor(v).isEmpty) {
        final files = whisperFiles(v).map((f) => p.join(dir, f)).toList();
        return WhisperCheck(
          dir: dir,
          missing: const [],
          paths: WhisperPaths(
            variant: v,
            encoder: files[0],
            decoder: files[1],
            tokens: files[2],
          ),
        );
      }
    }
    return WhisperCheck(dir: dir, missing: missingFor(WhisperVariant.small));
  }
}

class ModelMissingException implements Exception {
  ModelMissingException(this.message);
  final String message;
  @override
  String toString() => message;
}
