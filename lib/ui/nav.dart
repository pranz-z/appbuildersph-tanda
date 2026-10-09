import 'package:flutter/material.dart';

import 'screens/debug_log_screen.dart';
import 'screens/import_models_screen.dart';
import 'screens/stt_debug_screen.dart';

void openImportModels(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ImportModelsScreen()));

void openDebugLog(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DebugLogScreen()));

void openSttDebug(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SttDebugScreen()));
