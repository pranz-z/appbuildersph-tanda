import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/core/providers.dart';
import 'package:tanda/services/audio/recorder_service.dart';
import 'package:tanda/services/stt/stt_service.dart';
import 'package:tanda/ui/home_shell.dart';

class _UnusedRecorder implements AudioCaptureRecorder {
  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> start() async {}

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> cancel() async {}
}

void main() {
  testWidgets('shell shows two destinations and switches between them', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recorderServiceProvider.overrideWithValue(_UnusedRecorder()),
          sttServiceProvider.overrideWith((ref) async => FakeSttService()),
          savedMemoriesProvider.overrideWith((ref) async => []),
          openLoopsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: HomeShell(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text("Tanda"), findsOneWidget);
    expect(find.text("Ask Tanda"), findsOneWidget);
    expect(find.text("Open loops"), findsOneWidget);
    expect(find.textContaining('Bytes sent by app'), findsNothing);

    await tester.tap(find.text("Open loops"));
    await tester.pumpAndSettle();
    expect(find.text("All caught up. Nothing pending."), findsOneWidget);
  });
}
