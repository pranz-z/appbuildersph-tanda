import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/services/audio/recorder_service.dart';
import 'package:tanda/services/stt/stt_service.dart';
import 'package:tanda/ui/widgets/hold_to_talk_control.dart';

class Recorder implements AudioCaptureRecorder {
  int starts = 0, cancels = 0;
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<String?> stop() async => 'question.wav';
  @override
  Future<void> cancel() async {
    cancels++;
  }
}

class Whisper implements SttService {
  final pending = Completer<SttResult>();
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<SttResult> transcribeFile(String path) => pending.future;
}

void main() {
  testWidgets(
    'shared recorder excludes overlap and discards hidden capture results',
    (tester) async {
      final recorder = Recorder(), stt = Whisper();
      var enabled = true, received = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Column(
                  children: [
                    HoldToTalkControl(
                      key: const ValueKey('first'),
                      recorder: recorder,
                      stt: stt,
                      diameter: 70,
                      enabled: enabled,
                      onTranscribed: (_) => received++,
                    ),
                    HoldToTalkControl(
                      key: const ValueKey('second'),
                      recorder: recorder,
                      stt: stt,
                      diameter: 70,
                      onTranscribed: (_) => received++,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      Finder button(String key) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byKey(const ValueKey('hold-to-talk-button')),
      );
      final first = await tester.startGesture(
        tester.getCenter(button('first')),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 320)),
      );
      await first.up();
      await tester.pump();
      expect(find.textContaining('Transcribing'), findsOneWidget);
      final second = await tester.startGesture(
        tester.getCenter(button('second')),
      );
      await tester.pump();
      await second.up();
      await tester.pump();
      expect(recorder.starts, 1);
      expect(find.textContaining("Another recording"), findsOneWidget);
      rebuild(() => enabled = false);
      await tester.pump();
      rebuild(() => enabled = true);
      await tester.pump();
      stt.pending.complete(
        const SttResult(
          text: 'Sino may hawak ng drill?',
          elapsedMs: 1,
          audioMs: 1000,
        ),
      );
      await tester.pumpAndSettle();
      expect(received, 0);
      final retry = await tester.startGesture(
        tester.getCenter(button('second')),
      );
      await tester.pump();
      expect(recorder.starts, 2);
      await retry.cancel();
      await tester.pumpAndSettle();
      expect(recorder.cancels, 1);
    },
  );
  testWidgets('hiding an active recorder cancels without transcribing', (
    tester,
  ) async {
    final recorder = Recorder(), stt = Whisper();
    var enabled = true, received = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return HoldToTalkControl(
                recorder: recorder,
                stt: stt,
                enabled: enabled,
                onTranscribed: (_) => received++,
              );
            },
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('hold-to-talk-button'))),
    );
    await tester.pump();
    expect(recorder.starts, 1);
    rebuild(() => enabled = false);
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(recorder.cancels, 1);
    expect(received, 0);
  });
}
