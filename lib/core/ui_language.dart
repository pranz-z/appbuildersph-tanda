import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum AppLanguage { english, tagalog }

abstract interface class UiLanguageStore {
  Future<String?> read();
  Future<void> write(String language);
}

class FileUiLanguageStore implements UiLanguageStore {
  FileUiLanguageStore();
  FileUiLanguageStore.forTesting(File file) : _testFile = file;
  File? _testFile;
  Future<void> _pending = Future.value();
  Future<File> _file() async =>
      _testFile ??
      File(
        p.join(
          (await getApplicationSupportDirectory()).path,
          'ui-language.txt',
        ),
      );
  @override
  Future<String?> read() async {
    try {
      return (await (await _file()).readAsString()).trim();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String language) {
    final operation = _pending.catchError((Object _) {}).then((_) async {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(language, flush: true);
    });
    _pending = operation;
    return operation;
  }
}

final uiLanguageStoreProvider = Provider<UiLanguageStore>(
  (ref) => FileUiLanguageStore(),
);
final uiLanguageProvider = NotifierProvider<UiLanguageController, AppLanguage>(
  UiLanguageController.new,
);

class UiLanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => AppLanguage.english;
  Future<void> load() async {
    final saved = await ref.read(uiLanguageStoreProvider).read();
    state = saved == 'tl' ? AppLanguage.tagalog : AppLanguage.english;
  }

  Future<void> select(AppLanguage language) async {
    state = language;
    await ref
        .read(uiLanguageStoreProvider)
        .write(language == AppLanguage.tagalog ? 'tl' : 'en');
  }
}
