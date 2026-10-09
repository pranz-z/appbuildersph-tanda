import 'package:flutter/material.dart';

import 'screens/placeholder_screen.dart';
import 'screens/stt_debug_screen.dart';
import 'widgets/locality_meter_bar.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    PlaceholderScreen(title: 'Tala', hint: 'Capture', icon: Icons.mic),
    PlaceholderScreen(
      title: 'Tanong',
      hint: 'Ask',
      icon: Icons.question_answer,
    ),
    PlaceholderScreen(
      title: 'Nakabinbin',
      hint: 'Open loops',
      icon: Icons.pending_actions,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanda'),
        actions: [
          IconButton(
            tooltip: 'STT spike (debug)',
            icon: const Icon(Icons.bug_report),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SttDebugScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LocalityMeterBar(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.mic),
                label: 'Tala',
                tooltip: 'Capture',
              ),
              NavigationDestination(
                icon: Icon(Icons.question_answer),
                label: 'Tanong',
                tooltip: 'Ask',
              ),
              NavigationDestination(
                icon: Icon(Icons.pending_actions),
                label: 'Nakabinbin',
                tooltip: 'Open loops',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
