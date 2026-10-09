import 'package:flutter/material.dart';

import 'nav.dart';
import 'localization.dart';
import 'screens/nakabinbin_screen.dart';
import 'screens/tanda_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('tanda.'),
        actions: [
          IconButton(
            tooltip: tr(context, 'Settings'),
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => openSettings(context),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            TandaScreen(active: _index == 0),
            const NakabinbinScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: const Icon(Icons.chat_bubble_rounded),
            label: 'Tanda',
            tooltip: 'Tanda',
          ),
          NavigationDestination(
            icon: const Icon(Icons.checklist_rounded),
            label: tr(context, 'Open loops'),
            tooltip: tr(context, 'Open loops'),
          ),
        ],
      ),
    );
  }
}
