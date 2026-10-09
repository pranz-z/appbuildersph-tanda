import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/core/ui_language.dart';
import 'package:tanda/ui/localization.dart';
import 'package:tanda/ui/screens/settings_screen.dart';
import 'package:tanda/ui/notebook_theme.dart';

class MemoryLanguageStore implements UiLanguageStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String language) async {
    value = language;
  }
}

void main() {
  testWidgets('Settings remains usable on a small screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uiLanguageStoreProvider.overrideWithValue(MemoryLanguageStore()),
        ],
        child: MaterialApp(
          theme: tandaTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('language-tagalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-tagalog')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  test(
    'file preference survives reopening and serializes rapid changes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tanda-language-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/language.txt');
      final store = FileUiLanguageStore.forTesting(file);
      expect(await store.read(), isNull);
      await Future.wait([
        store.write('tl'),
        store.write('en'),
        store.write('tl'),
      ]);
      expect(await FileUiLanguageStore.forTesting(file).read(), 'tl');
    },
  );

  test('translated templates preserve user content literally', () {
    expect(
      translate('Memory · Settings {2}', AppLanguage.tagalog),
      contains('Settings {2}'),
    );
  });
  test(
    'English default, persisted choice, safe fallback and ordered writes',
    () async {
      final store = MemoryLanguageStore();
      final first = ProviderContainer(
        overrides: [uiLanguageStoreProvider.overrideWithValue(store)],
      );
      addTearDown(first.dispose);
      await first.read(uiLanguageProvider.notifier).load();
      expect(first.read(uiLanguageProvider), AppLanguage.english);
      await first.read(uiLanguageProvider.notifier).select(AppLanguage.tagalog);
      final reopened = ProviderContainer(
        overrides: [uiLanguageStoreProvider.overrideWithValue(store)],
      );
      addTearDown(reopened.dispose);
      await reopened.read(uiLanguageProvider.notifier).load();
      expect(reopened.read(uiLanguageProvider), AppLanguage.tagalog);
      expect(
        translate('Uncatalogued English label', AppLanguage.tagalog),
        'Uncatalogued English label',
      );
      expect(
        translate('Hindi ko maintindihan. Pakisabi ulit.', AppLanguage.english),
        'I couldn’t understand. Please try again.',
      );
    },
  );
  testWidgets(
    'Settings switches interface immediately without touching user text',
    (tester) async {
      final store = MemoryLanguageStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [uiLanguageStoreProvider.overrideWithValue(store)],
          child: Consumer(
            builder: (context, ref, _) => LocalizationScope(
              language: ref.watch(uiLanguageProvider),
              child: const MaterialApp(home: SettingsScreen()),
            ),
          ),
        ),
      );
      expect(find.text('Settings'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('language-tagalog')));
      await tester.pumpAndSettle();
      expect(find.text('Mga setting'), findsOneWidget);
      expect(store.value, 'tl');
      await tester.tap(find.byKey(const ValueKey('language-english')));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
    },
  );
}
