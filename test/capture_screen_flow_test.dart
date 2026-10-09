import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/core/providers.dart';
import 'package:tanda/services/audio/recorder_service.dart';
import 'package:tanda/services/llm/extractor.dart';
import 'package:tanda/services/llm/llm_service.dart';
import 'package:tanda/services/stt/stt_service.dart';
import 'package:tanda/ui/screens/stt_debug_screen.dart';
import 'package:tanda/ui/screens/tala_screen.dart';
import 'package:tanda/ui/widgets/hold_to_talk_control.dart';

class _FakeRecorder implements AudioCaptureRecorder {
  int starts = 0;
  int stops = 0;
  int cancels = 0;
  bool permission = true;
  Object? startError;

  @override
  Future<bool> hasPermission({bool request = true}) async => permission;

  @override
  Future<void> start() async {
    starts++;
    if (startError != null) throw startError!;
  }

  @override
  Future<String?> stop() async {
    stops++;
    return 'clip.wav';
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

class _FakeStt implements SttService {
  int transcriptions = 0;

  @override
  Future<void> init() async {}

  @override
  Future<SttResult> transcribeFile(String wavPath) async {
    transcriptions++;
    expect(wavPath, 'clip.wav');
    return const SttResult(
      text: 'Hiniram ni Kuya Jun yung drill.',
      elapsedMs: 42,
      audioMs: 1200,
    );
  }

  @override
  Future<void> dispose() async {}
}

class _SequencedStt implements SttService {
  var calls = 0;

  @override
  Future<void> init() async {}

  @override
  Future<SttResult> transcribeFile(String wavPath) async {
    calls++;
    final text = calls == 1
        ? 'Hiniram ni Jun ang drill.'
        : 'Hiniram ni Jun ang saw.';
    return SttResult(text: text, elapsedMs: 1, audioMs: 1200);
  }

  @override
  Future<void> dispose() async {}
}

class _OutOfOrderLlm implements LlmService {
  final firstCall = Completer<void>();
  var calls = 0;

  @override
  Future<void> init() async {}

  @override
  Future<LlmResult> complete(
    String prompt, {
    String? grammar,
    int maxTokens = 256,
  }) async {
    calls++;
    final first = prompt.contains('drill');
    if (first) await firstCall.future;
    final item = first ? 'drill' : 'saw';
    final transcript = first
        ? 'Hiniram ni Jun ang drill.'
        : 'Hiniram ni Jun ang saw.';
    return LlmResult(
      text: jsonEncode({
        'understood': true,
        'cleaned_sentence': transcript,
        'memory': {
          'kind': 'lent_item',
          'person': null,
          'item': item,
          'place': null,
          'amount': null,
          'due_date_text': null,
          'evidence': transcript,
          'uncertain_fields': <String>[],
        },
      }),
      elapsedMs: 1,
      generatedTokens: 1,
    );
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  Future<void> holdAndRelease(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('hold-to-talk-button'));
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    expect(find.textContaining('Listening'), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 320)),
    );
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Tala hold-to-talk transcribes and opens the review card', (
    tester,
  ) async {
    final recorder = _FakeRecorder();
    final stt = _FakeStt();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recorderServiceProvider.overrideWithValue(recorder),
          sttServiceProvider.overrideWith((ref) async => stt),
          savedMemoriesProvider.overrideWith((ref) async => []),
          extractorProvider.overrideWith(
            (ref) async => Extractor(
              FakeLlmService(),
              promptTemplate: '{{TRANSCRIPT}}',
              grammar: '',
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TalaScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await holdAndRelease(tester);

    expect(recorder.starts, 1);
    expect(recorder.stops, 1);
    expect(stt.transcriptions, 1);
    expect(find.text("Did Tanda hear that right?"), findsOneWidget);
    expect(
      find.textContaining('Hiniram ni Kuya Jun yung drill.'),
      findsOneWidget,
    );
    expect(find.text("Yes, save it"), findsOneWidget);
  });

  testWidgets('debug screen keeps hold-to-talk and displays transcription', (
    tester,
  ) async {
    final recorder = _FakeRecorder();
    final stt = _FakeStt();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recorderServiceProvider.overrideWithValue(recorder),
          sttServiceProvider.overrideWith((ref) async => stt),
        ],
        child: const MaterialApp(home: SttDebugScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await holdAndRelease(tester);

    expect(recorder.starts, 1);
    expect(recorder.stops, 1);
    expect(stt.transcriptions, 1);
    expect(
      find.textContaining('Hiniram ni Kuya Jun yung drill.'),
      findsOneWidget,
    );
  });

  testWidgets('older extraction cannot replace a newer recording review', (
    tester,
  ) async {
    final recorder = _FakeRecorder();
    final stt = _SequencedStt();
    final llm = _OutOfOrderLlm();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recorderServiceProvider.overrideWithValue(recorder),
          sttServiceProvider.overrideWith((ref) async => stt),
          savedMemoriesProvider.overrideWith((ref) async => []),
          extractorProvider.overrideWith(
            (ref) async =>
                Extractor(llm, promptTemplate: '{{TRANSCRIPT}}', grammar: ''),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TalaScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await holdAndRelease(tester);
    expect(llm.calls, 1);
    await holdAndRelease(tester);
    expect(llm.calls, 2);
    expect(find.byKey(const ValueKey('2-item')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('2-item')))
          .initialValue,
      'saw',
    );

    llm.firstCall.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('2-item')))
          .initialValue,
      'saw',
    );
  });

  testWidgets(
    'start errors are shown on screen instead of swallowing the press',
    (tester) async {
      final recorder = _FakeRecorder()
        ..startError = StateError('mic unavailable');
      final stt = _FakeStt();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HoldToTalkControl(
              recorder: recorder,
              stt: stt,
              onTranscribed: (_) {},
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('hold-to-talk-button'))),
      );
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Could not start recording. Check microphone permission and try again.',
        ),
        findsOneWidget,
      );
      expect(stt.transcriptions, 0);
    },
  );
}
