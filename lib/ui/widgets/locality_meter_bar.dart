import 'package:flutter/material.dart';

/// Persistent footer reserved for the locality meter (spec section 10).
/// Placeholder until the meter service exists.
class LocalityMeterBar extends StatelessWidget {
  const LocalityMeterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: const SizedBox(
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android, size: 18),
            SizedBox(width: 8),
            Text('Locality meter (paparating / coming soon)'),
          ],
        ),
      ),
    );
  }
}
