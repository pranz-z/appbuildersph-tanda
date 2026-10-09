import 'package:flutter/material.dart';

import '../localization.dart';
import '../notebook_theme.dart';
import '../widgets/locality_meter_bar.dart';

class SessionDiagnosticsScreen extends StatelessWidget {
  const SessionDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const UiText('Diagnostics')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        NotebookHeader(
          title: 'Session diagnostics',
          subtitle: 'Measurements for this app session.',
          icon: Icons.monitor_heart_outlined,
        ),
        LocalityMeterBar(),
        SizedBox(height: 20),
        UiText('Network status shows connectivity, not internet reachability.'),
        SizedBox(height: 12),
        UiText(
          'These measurements do not describe all device traffic or guarantee privacy.',
        ),
      ],
    ),
  );
}
