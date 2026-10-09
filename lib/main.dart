import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/providers.dart';
import 'ui/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep the screen on during demos.
  WakelockPlus.enable();
  final container = ProviderContainer();
  // Load models once at app start (in the background), never per request.
  container.read(sttServiceProvider);
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
      home: const HomeShell(),
    );
  }
}
