import 'package:flutter/material.dart';

import 'screens/debug_log_screen.dart';
import 'screens/download_models_screen.dart';
import 'screens/import_models_screen.dart';
import 'screens/llm_debug_screen.dart';
import 'screens/stt_debug_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/session_diagnostics_screen.dart';

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

void openImportModels(BuildContext context) =>
    _push(context, const ImportModelsScreen());

void openDownloadModels(BuildContext context) =>
    _push(context, const DownloadModelsScreen());

void openDebugLog(BuildContext context) =>
    _push(context, const DebugLogScreen());

void openSttDebug(BuildContext context) =>
    _push(context, const SttDebugScreen());

void openLlmDebug(BuildContext context) =>
    _push(context, const LlmDebugScreen());

void openSettings(BuildContext context) =>
    _push(context, const SettingsScreen());

void openSessionDiagnostics(BuildContext context) =>
    _push(context, const SessionDiagnosticsScreen());
