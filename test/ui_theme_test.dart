import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/core/ui_theme.dart';
import 'package:tanda/ui/notebook_theme.dart';
import 'package:tanda/ui/screens/settings_screen.dart';
import 'package:tanda/ui/localization.dart';
import 'package:tanda/core/ui_language.dart';
import 'package:tanda/core/locality_meter.dart';

void main() {
  testWidgets('failed theme persistence shows a retry message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uiThemeStoreProvider.overrideWithValue(MemoryThemeStore(fail: true)),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('dark-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dark-mode')));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save theme. Toggle it again to retry.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('dark-mode')))
          .value,
      isTrue,
    );
  });
  test('new copy has English and natural Tagalog translations', () {
    expect(translate('Dark mode', AppLanguage.tagalog), 'Madilim na tema');
    expect(
      translate('Saved memories', AppLanguage.english),
      'What Tanda remembers',
    );
    expect(
      translate('Saved memories', AppLanguage.tagalog),
      'Mga naaalala ni Tanda',
    );
    expect(
      translate('Type a memory description', AppLanguage.english),
      'Tell Tanda something to remember',
    );
  });
  testWidgets('session counters are accessible through Settings diagnostics', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(NetworkStatus.offline),
          ),
          sessionTrafficBytesProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: tandaTheme(brightness: Brightness.dark),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Session diagnostics'), 250);
    await tester.tap(find.text('Session diagnostics'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bytes sent by app'), findsOneWidget);
    expect(find.textContaining('embeddings inactive'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    await tester.tap(find.byTooltip('Session details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('TrafficStats app UID'), findsOneWidget);
  });
  test(
    'theme defaults to light and survives reopening with ordered writes',
    () async {
      final directory = await Directory.systemTemp.createTemp('tanda-theme-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/theme.txt');
      ProviderContainer container() => ProviderContainer(
        overrides: [
          uiThemeStoreProvider.overrideWithValue(
            FileUiThemeStore.forTesting(file),
          ),
        ],
      );
      final first = container();
      addTearDown(first.dispose);
      await first.read(uiThemeProvider.notifier).load();
      expect(first.read(uiThemeProvider), ThemeMode.light);
      await Future.wait([
        first.read(uiThemeProvider.notifier).select(ThemeMode.dark),
        first.read(uiThemeProvider.notifier).select(ThemeMode.light),
        first.read(uiThemeProvider.notifier).select(ThemeMode.dark),
      ]);
      final reopened = container();
      addTearDown(reopened.dispose);
      await reopened.read(uiThemeProvider.notifier).load();
      expect(reopened.read(uiThemeProvider), ThemeMode.dark);
      await file.writeAsString('invalid');
      await reopened.read(uiThemeProvider.notifier).load();
      expect(reopened.read(uiThemeProvider), ThemeMode.light);
    },
  );

  testWidgets('Settings switches theme immediately and persists it', (
    tester,
  ) async {
    final store = MemoryThemeStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [uiThemeStoreProvider.overrideWithValue(store)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: tandaTheme(),
            darkTheme: tandaTheme(brightness: Brightness.dark),
            themeMode: ref.watch(uiThemeProvider),
            builder: (context, child) => PaperBackdrop(child: child!),
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('dark-mode')));
    await tester.tap(find.byKey(const ValueKey('dark-mode')));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(await store.read(), 'dark');
    final theme = Theme.of(context);
    expect(theme.colorScheme.onSurface.computeLuminance(), greaterThan(.6));
    expect(theme.cardTheme.color!.computeLuminance(), lessThan(.1));
    expect(theme.dialogTheme.backgroundColor!.computeLuminance(), lessThan(.1));
    expect(
      theme.navigationBarTheme.backgroundColor!.computeLuminance(),
      lessThan(.1),
    );
  });
}

class MemoryThemeStore implements UiThemeStore {
  MemoryThemeStore({this.fail = false});
  final bool fail;
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String theme) async {
    if (fail) throw const FileSystemException('test failure');
    value = theme;
  }
}
