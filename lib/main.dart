import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/app_log.dart';
import 'core/memory_info.dart';
import 'core/providers.dart';
import 'core/ui_language.dart';
import 'core/ui_theme.dart';
import 'ui/localization.dart';
import 'ui/notebook_theme.dart';
import 'ui/screens/first_run_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appLog.init();
  FlutterError.onError = (details) {
    appLog.e('FlutterError', details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    appLog.e('Uncaught error', error, stack);
    return true;
  };
  appLog.i(
    'App start: ${Platform.operatingSystemVersion}, '
    'cpus=${Platform.numberOfProcessors}',
  );

  // Keep the screen on during demos.
  WakelockPlus.enable();
  final container = ProviderContainer();
  await container.read(uiLanguageProvider.notifier).load();
  await container.read(uiThemeProvider.notifier).load();
  // Load models once at app start (in the background), never per request.
  // Whisper and the LLM load in parallel, each off the UI isolate.
  Future.wait([
    container.read(sttServiceProvider.future),
    container.read(llmServiceProvider.future),
  ]).then(
    (_) => appLog.i(
      'Whisper + LLM both loaded; memory: ${residentMemorySummary()}',
    ),
    onError: (Object _) =>
        appLog.i('Not all models loaded; memory: ${residentMemorySummary()}'),
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const TandaApp()),
  );
}

class TandaApp extends ConsumerWidget {
  const TandaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(uiLanguageProvider);
    return LocalizationScope(
      language: language,
      child: MaterialApp(
        title: 'Tanda',
        theme: tandaTheme(),
        darkTheme: tandaTheme(brightness: Brightness.dark),
        themeMode: ref.watch(uiThemeProvider),
        locale: Locale(language == AppLanguage.tagalog ? 'fil' : 'en'),
        supportedLocales: const [Locale('en'), Locale('fil')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => PaperBackdrop(child: child!),
        home: const StartupGate(),
      ),
    );
  }
}
