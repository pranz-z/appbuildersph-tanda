import '../localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_log.dart';

class DebugLogScreen extends StatelessWidget {
  const DebugLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const UiText('Debug log'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const UiText('Copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: appLog.dump()));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: UiText('Log copied')));
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: appLog,
        builder: (_, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            appLog.dump(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
    );
  }
}
