import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const androidPackageId = 'ph.tanda.app';

/// Optional adb alternative: `getExternalStorageDirectory()` as seen by adb.
const adbModelsDir = '/sdcard/Android/data/$androidPackageId/files/models';

class ModelFileSpec {
  const ModelFileSpec(
    this.name,
    this.group,
    this.url, {
    required this.size,
    this.sha256,
  });

  final String name;
  final String group;

  /// Hugging Face URL pinned to an immutable commit.
  final String url;

  /// Exact size in bytes (from the Hugging Face API at that commit).
  final int size;

  /// SHA-256 from the Hugging Face LFS pointer, or null when the file is not
  /// stored in LFS (then only the size is verified).
  final String? sha256;
}

// Sizes and SHA-256 values below come from the Hugging Face API
// (/api/models/<repo>/tree/<commit>) at the pinned commits.
const _hfSmall =
    'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/'
    '8f3c18b358db4d1f2fc1eae49d75cd20989e4309';
const _hfBase =
    'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/'
    'bb53ee204431c90d314c1cc08d28d23e5b7927cc';

enum WhisperVariant { small, base }

List<ModelFileSpec> whisperSpecs(WhisperVariant v) {
  final small = v == WhisperVariant.small;
  final url = small ? _hfSmall : _hfBase;
  final group = 'Whisper ${v.name}';
  ModelFileSpec spec(String file, int size, String? sha) =>
      ModelFileSpec(file, group, '$url/$file', size: size, sha256: sha);
  return small
      ? [
          spec(
            'small-encoder.int8.onnx',
            112442483,
            '4cbe7b22fa9026b843b60a68640c747de05bafb1a11b57edc0e66c232d9f33a9',
          ),
          spec(
            'small-decoder.int8.onnx',
            262226114,
            'acad50b5c782696e91b55914cc5ab4f756f1532f76e22aa6fc615f39fb69a8ee',
          ),
          spec('small-tokens.txt', 816730, null),
        ]
      : [
          spec(
            'base-encoder.int8.onnx',
            29120534,
            '0b8fb1304b6109976038efff5ace81720e00386f3ff6b54ee8c75291ca0a1e11',
          ),
          spec(
            'base-decoder.int8.onnx',
            130672026,
            '9759d217388a01b3a4c7c15533201067b48ae819c4daafc8624e64b9409dc02d',
          ),
          spec('base-tokens.txt', 816730, null),
        ];
}

const llmSpec = ModelFileSpec(
  'qwen2.5-1.5b-instruct-q4_k_m.gguf',
  'LLM: Qwen2.5 1.5B Instruct Q4_K_M',
  'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/'
      '91cad51170dc346986eccefdc2dd33a9da36ead9/'
      'qwen2.5-1.5b-instruct-q4_k_m.gguf',
  size: 1117320736,
  sha256: '6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e',
);

const _hfE5 =
    'https://huggingface.co/Xenova/multilingual-e5-small/resolve/'
    '761b726dd34fb83930e26aab4e9ac3899aa1fa78';
const embeddingSpecs = [
  ModelFileSpec(
    'model_int8.onnx',
    'Embeddings: multilingual-e5-small int8',
    '$_hfE5/onnx/model_int8.onnx',
    size: 118054593,
    sha256: '4d24e2bc01a447951524466ef533e52944bf48509e6552810bcee1a2711cb02c',
  ),
  ModelFileSpec(
    'tokenizer.json',
    'Embeddings: multilingual-e5-small int8',
    '$_hfE5/tokenizer.json',
    size: 17082730,
    sha256: '0b44a9d7b51c3c62626640cda0e2c2f70fdacdc25bbbd68038369d14ebdf4c39',
  ),
];

ModelFileSpec? specByName(String name) {
  for (final s in modelManifest) {
    if (s.name == name) return s;
  }
  return null;
}

/// Every file the app accepts on import.
final modelManifest = <ModelFileSpec>[
  ...whisperSpecs(WhisperVariant.small),
  ...whisperSpecs(WhisperVariant.base),
  llmSpec,
  ...embeddingSpecs,
];

String missingFilesMessage(String what, List<ModelFileSpec> missing) {
  final list = missing.map((s) => '  - ${s.name}\n    ${s.url}').join('\n');
  return 'Kulang ang $what files. / $what files are missing.\n\n'
      'Tap "Download models" (needs internet once), or download these into '
      'the phone\'s Downloads folder:\n$list\n\n'
      'and tap "Import models" to select them.';
}

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

  String get errorMessage =>
      '${missingFilesMessage('Whisper model', missing)}\n'
      '(Whisper base files work too, as a smaller fallback.)';
}

/// Finds model files. Models are never bundled in the APK; they are imported
/// into the app's internal files dir (no permissions needed). The external
/// files dir is also checked, for the optional adb route.
class ModelLocator {
  ModelLocator({
    this.primaryDirOverride,
    this.altDirOverride,
    this.checkSizes = true,
  });

  /// For tests.
  final String? primaryDirOverride;
  final String? altDirOverride;

  /// A file only counts as present when its size matches the manifest, so a
  /// truncated import or download is treated as missing. Tests may disable.
  final bool checkSizes;

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

  /// Returns the file if present (imported, downloaded or adb-pushed) with the
  /// expected size in either location.
  Future<File?> find(String name) async {
    final expected = checkSizes ? specByName(name)?.size : null;
    for (final dir in [await primaryDir(), await _altDir()]) {
      if (dir == null) continue;
      final f = File(p.join(dir, name));
      if (!f.existsSync()) continue;
      final len = f.lengthSync();
      if (len > 0 && (expected == null || len == expected)) return f;
    }
    return null;
  }

  /// Files the app needs and does not have yet: Whisper small (unless a
  /// complete Whisper set is present), the LLM, and the embedding files.
  Future<List<ModelFileSpec>> missingRequired() async => [
    if (!(await checkWhisper()).ok)
      ...await missingOf(whisperSpecs(WhisperVariant.small)),
    ...await missingOf([llmSpec, ...embeddingSpecs]),
  ];

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
    return WhisperCheck(
      missing: await missingOf(whisperSpecs(WhisperVariant.small)),
    );
  }

  Future<List<ModelFileSpec>> missingOf(List<ModelFileSpec> specs) async => [
    for (final s in specs)
      if (await find(s.name) == null) s,
  ];

  /// Path of the GGUF, or throws [ModelMissingException].
  Future<String> requireLlm() async {
    final f = await find(llmSpec.name);
    if (f == null) {
      throw ModelMissingException(missingFilesMessage('LLM model', [llmSpec]));
    }
    return f.path;
  }
}

class ModelMissingException implements Exception {
  ModelMissingException(this.message);
  final String message;
  @override
  String toString() => message;
}
