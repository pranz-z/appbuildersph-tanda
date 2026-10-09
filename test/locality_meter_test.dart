import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/core/locality_meter.dart';
import 'package:tanda/core/session_usage.dart';
import 'package:tanda/services/llm/llm_service.dart';
import 'package:tanda/services/stt/stt_service.dart';
import 'package:tanda/ui/widgets/locality_meter_bar.dart';

void main() {
  test('connectivity results map to online and offline states', () {
    expect(networkStatusFor([ConnectivityResult.wifi]), NetworkStatus.online);
    expect(networkStatusFor([ConnectivityResult.mobile]), NetworkStatus.online);
    expect(networkStatusFor([ConnectivityResult.none]), NetworkStatus.offline);
  });

  testWidgets('meter updates when connectivity changes', (tester) async {
    final changes = StreamController<NetworkStatus>();
    addTearDown(changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkStatusProvider.overrideWith((ref) => changes.stream),
          sessionTrafficBytesProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: Scaffold(body: LocalityMeterBar())),
      ),
    );

    changes.add(NetworkStatus.online);
    await tester.pump();
    expect(find.text("Online"), findsOneWidget);

    changes.add(NetworkStatus.offline);
    await tester.pump();
    await tester.pump();
    expect(find.text("Offline"), findsOneWidget);
  });

  testWidgets('unavailable UID byte counter never displays zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(NetworkStatus.offline),
          ),
          sessionTrafficBytesProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: Scaffold(body: LocalityMeterBar())),
      ),
    );
    await tester.pump();

    expect(find.textContaining("Unavailable"), findsOneWidget);
    expect(find.textContaining('0 B'), findsNothing);
    await tester.tap(find.byTooltip('Session details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('TrafficStats'), findsOneWidget);
  });

  test('call counters increment for each inference service attempt', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final usage = container.read(sessionUsageProvider.notifier);
    final stt = MeteredSttService(
      _FailingStt(),
      onCall: usage.recordTranscriptionCall,
    );
    final llm = MeteredLlmService(_FailingLlm(), onCall: usage.recordLlmCall);

    await expectLater(stt.transcribeFile('clip.wav'), throwsStateError);
    await expectLater(llm.complete('prompt'), throwsStateError);
    usage.recordEmbeddingCall();

    expect(container.read(sessionUsageProvider).transcriptionCalls, 1);
    expect(container.read(sessionUsageProvider).llmCalls, 1);
    expect(container.read(sessionUsageProvider).embeddingCalls, 1);
  });
}

class _FailingStt implements SttService {
  @override
  Future<void> init() async {}

  @override
  Future<SttResult> transcribeFile(String wavPath) async =>
      throw StateError('failed');

  @override
  Future<void> dispose() async {}
}

class _FailingLlm implements LlmService {
  @override
  Future<void> init() async {}

  @override
  Future<LlmResult> complete(
    String prompt, {
    String? grammar,
    int maxTokens = 256,
  }) async => throw StateError('failed');

  @override
  Future<void> dispose() async {}
}
