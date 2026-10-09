import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const androidPackageId = 'ph.tanda.app';

/// Optional adb alternative: `getExternalStorageDirectory()` as seen by adb.
const adbModelsDir = '/sdcard/Android/data/$androidPackageId/files/models';

class ModelFileSpec {
  const ModelFileSpec(this.name, this.group, this.url);

  final String name;
  final String group;
  final String url;
}

const _hfSmall =
    'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main';
const _hfBase =
    'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main';

enum WhisperVariant { small, base }

List<ModelFileSpec> whisperSpecs(WhisperVariant v) {
  final url = v == WhisperVariant.small ? _hfSmall : _hfBase;
  final group = 'Whisper ${v.name}';
  return [
    for (final f in [
      '${v.name}-encoder.int8.onnx',
      '${v.name}-decoder.int8.onnx',
      '${v.name}-tokens.txt',
    ])
      ModelFileSpec(f, group, '$url/$f'),
  ];
}

/// Every file the app accepts on import. LLM (GGUF) and e5 files get added
/// here once they are chosen.
final modelManifest = <ModelFileSpec>[
  ...whisperSpecs(WhisperVariant.small),
  ...whisperSpecs(WhisperVariant.base),
];

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
  const WhisperCheck({required this.missing, this.paths});

  /// Missing (or empty) files for the preferred variant (small).
  final List<ModelFileSpec> missing;

  final WhisperPaths? paths;

  bool get ok => paths != null;

  String get errorMessage {
    final list = missing.map((s) => '  - ${s.name}\n    ${s.url}').join('\n');
    return 'Kulang ang Whisper model files. / Whisper model files are missing.\n\n'
        'Download these into the phone\'s Downloads folder:\n$list\n\n'
        'Then tap "Import models" and select them.\n'
        '(Whisper base files work too, as a smaller fallback.)';
  }
}

/// Finds model files. Models are never bundled in the APK; they are imported
/// into the app's internal files dir (no permissions needed). The external
/// files dir is also checked, for the optional adb route.
class ModelLocator {
  ModelLocator({this.primaryDirOverride, this.altDirOverride});

  /// For tests.
  final String? primaryDirOverride;
  final String? altDirOverride;

  Future<String> primaryDir() async {
    final base =
        primaryDirOverride ?? (await getApplicationSupportDirectory()).path;
    final dir = p.join(base, 'models');
    await Directory(dir).create(recursive: true);
    return dir;
  }

  Future<String?> _altDir() async {
    if (altDirOverride != null) return altDirOverride;
    if (primaryDirOverride != null) return null;
    final ext = await getExternalStorageDirectory();
    return ext == null ? null : p.join(ext.path, 'models');
  }

  /// Returns the file if present and non-empty in either location.
  Future<File?> find(String name) async {
    for (final dir in [await primaryDir(), await _altDir()]) {
      if (dir == null) continue;
      final f = File(p.join(dir, name));
      if (f.existsSync() && f.lengthSync() > 0) return f;
    }
    return null;
  }

  /// Size in bytes of each manifest file, or null if missing.
  Future<Map<String, int?>> status() async => {
    for (final s in modelManifest) s.name: (await find(s.name))?.lengthSync(),
  };

  /// Prefers Whisper small; falls back to base if only base is present.
  Future<WhisperCheck> checkWhisper() async {
    for (final v in WhisperVariant.values) {
      final files = [for (final s in whisperSpecs(v)) await find(s.name)];
      if (files.every((f) => f != null)) {
        return WhisperCheck(
          missing: const [],
          paths: WhisperPaths(
            variant: v,
            encoder: files[0]!.path,
            decoder: files[1]!.path,
            tokens: files[2]!.path,
          ),
        );
      }
    }
    final missing = <ModelFileSpec>[];
    for (final s in whisperSpecs(WhisperVariant.small)) {
      if (await find(s.name) == null) missing.add(s);
    }
    return WhisperCheck(missing: missing);
  }
}

class ModelMissingException implements Exception {
  ModelMissingException(this.message);
  final String message;
  @override
  String toString() => message;
}
