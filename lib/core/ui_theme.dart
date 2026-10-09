import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class UiThemeStore {
  Future<String?> read();
  Future<void> write(String theme);
}

class FileUiThemeStore implements UiThemeStore {
  FileUiThemeStore();
  FileUiThemeStore.forTesting(File file) : _testFile = file;
  File? _testFile;
  Future<void> _pending = Future.value();
  Future<File> _file() async =>
      _testFile ??
      File(
        p.join((await getApplicationSupportDirectory()).path, 'ui-theme.txt'),
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
  Future<void> write(String theme) {
    final operation = _pending.catchError((Object _) {}).then((_) async {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(theme, flush: true);
    });
    _pending = operation;
    return operation;
  }
}

final uiThemeStoreProvider = Provider<UiThemeStore>(
  (ref) => FileUiThemeStore(),
);
final uiThemeProvider = NotifierProvider<UiThemeController, ThemeMode>(
  UiThemeController.new,
);

class UiThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;
  Future<void> load() async {
    final saved = await ref.read(uiThemeStoreProvider).read();
    state = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> select(ThemeMode theme) async {
    state = theme;
    await ref
        .read(uiThemeStoreProvider)
        .write(theme == ThemeMode.dark ? 'dark' : 'light');
  }
}
