import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui_language.dart';
import '../../core/ui_theme.dart';
import '../localization.dart';
import '../notebook_theme.dart';
import '../nav.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _error;
  String? _themeError;
  Future<void> _selectTheme(bool dark) async {
    setState(() => _themeError = null);
    try {
      await ref
          .read(uiThemeProvider.notifier)
          .select(dark ? ThemeMode.dark : ThemeMode.light);
    } catch (_) {
      if (mounted) {
        setState(
          () => _themeError = 'Could not save theme. Toggle it again to retry.',
        );
      }
    }
  }

  Future<void> _select(AppLanguage language) async {
    setState(() => _error = null);
    try {
      await ref.read(uiLanguageProvider.notifier).select(language);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save language. Choose it again to retry.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(uiLanguageProvider);
    return Scaffold(
      appBar: AppBar(title: const UiText('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const NotebookHeader(
            title: 'Make it yours',
            subtitle: 'Your interface language. Your memories stay as you wrote them.',
            icon: Icons.tune,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(
                    'App language',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        key: const ValueKey('language-english'),
                        label: const Text('English'),
                        selected: language == AppLanguage.english,
                        onSelected: (_) => _select(AppLanguage.english),
                      ),
                      ChoiceChip(
                        key: const ValueKey('language-tagalog'),
                        label: const Text('Tagalog'),
                        selected: language == AppLanguage.tagalog,
                        onSelected: (_) => _select(AppLanguage.tagalog),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const UiText(
                    'English is used until you choose a language. Speech recognition language is unchanged.',
                  ),
                  if (_error != null)
                    UiText(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  key: const ValueKey('dark-mode'),
                  title: const UiText('Dark mode'),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  value: ref.watch(uiThemeProvider) == ThemeMode.dark,
                  onChanged: _selectTheme,
                ),
                if (_themeError != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: UiText(
                      _themeError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          UiText(
            'On-device models',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const UiText('Download models'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openDownloadModels(context),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const UiText('Import models'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openImportModels(context),
          ),
          const Divider(height: 32),
          UiText('Diagnostics', style: Theme.of(context).textTheme.titleLarge),
          ListTile(
            leading: const Icon(Icons.monitor_heart_outlined),
            title: const UiText('Session diagnostics'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openSessionDiagnostics(context),
          ),
          ListTile(
            leading: const Icon(Icons.mic_outlined),
            title: const UiText('Speech diagnostics'),
            onTap: () => openSttDebug(context),
          ),
          ListTile(
            leading: const Icon(Icons.psychology_outlined),
            title: const UiText('Extraction diagnostics'),
            onTap: () => openLlmDebug(context),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const UiText('Debug log'),
            onTap: () => openDebugLog(context),
          ),
        ],
      ),
    );
  }
}
