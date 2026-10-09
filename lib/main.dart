import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/app_log.dart';
import 'core/memory_info.dart';
import 'core/providers.dart';
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

class TandaApp extends StatelessWidget {
  const TandaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tanda',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const StartupGate(),
    );
  }
}
