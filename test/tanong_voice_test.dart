import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/core/app_database.dart';
import 'package:tanda/core/providers.dart';
import 'package:tanda/services/audio/recorder_service.dart';
import 'package:tanda/services/stt/stt_service.dart';
import 'package:tanda/services/tts/tts_service.dart';
import 'package:tanda/ui/screens/tanong_screen.dart';
import 'package:tanda/ui/widgets/hold_to_talk_control.dart';

class Recorder implements AudioCaptureRecorder {
  int starts = 0, stops = 0;
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<String?> stop() async {
    stops++;
    return 'question.wav';
  }

  @override
  Future<void> cancel() async {}
}

class Whisper implements SttService {
  Whisper(this.text);
  final String text;
  int calls = 0;
  Completer<SttResult>? pending;
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<SttResult> transcribeFile(String path) async {
    expect(path, 'question.wav');
    calls++;
    return pending == null
        ? SttResult(text: text, elapsedMs: 1, audioMs: 1000)
        : pending!.future;
  }
}

void main() {
  testWidgets(
    'late voice transcription cannot overwrite a newer typed question',
    (tester) async {
      final recorder = Recorder();
      final stt = Whisper('')..pending = Completer<SttResult>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recorderServiceProvider.overrideWithValue(recorder),
            sttServiceProvider.overrideWith((ref) async => stt),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            extractorProvider.overrideWith(
              (ref) => throw StateError('No extraction'),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: TanongScreen())),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('hold-to-talk-button'))),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 320)),
      );
      await gesture.up();
      await tester.pump();
      expect(find.textContaining('Transcribing'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('tanong-ask')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('tanong-question')),
        'Nasaan ang passport?',
      );
      stt.pending!.complete(
        const SttResult(
          text: 'Sino may hawak ng drill?',
          elapsedMs: 1,
          audioMs: 1000,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('tanong-question')))
            .controller!
            .text,
        'Nasaan ang passport?',
      );
      expect(find.byKey(const ValueKey('tanong-answer')), findsNothing);
      expect(find.byType(HoldToTalkControl), findsOneWidget);
    },
  );
  Future<void> hold(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('hold-to-talk-button'))),
    );
    await tester.pump();
    expect(find.textContaining('Listening'), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 320)),
    );
    await gesture.up();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  for (final speech in [
    'Sino may hawak ng drill ko?',
    '[Buzzing]',
    '',
    'Nga mas kawin tutut',
  ]) {
    testWidgets('Tanong voice question: $speech', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.saveConfirmedMemory(
        const ConfirmedMemory(
          uid: 'drill',
          createdAt: '2026',
          updatedAt: '2026',
          kind: 'lent_item',
          person: 'Jun',
          item: 'drill',
          place: null,
          amount: null,
          dueDateText: null,
          transcript: 'Hiniram ni Jun ang drill.',
          evidence: null,
          audioPath: null,
        ),
      );
      final recorder = Recorder();
      final stt = Whisper(speech);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            recorderServiceProvider.overrideWithValue(recorder),
            sttServiceProvider.overrideWith((ref) async => stt),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            extractorProvider.overrideWith(
              (ref) => throw StateError('Tanong must not extract'),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: TanongScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await hold(tester);
      expect(recorder.starts, 1);
      expect(recorder.stops, 1);
      expect(stt.calls, 1);
      if (speech.startsWith('Sino')) {
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('tanong-question')))
              .controller!
              .text,
          speech,
        );
        expect(find.byKey(const ValueKey('tanong-answer')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('tanong-ask')));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(find.text("Jun borrowed drill."), findsOneWidget);
        expect(find.text('Hiniram ni Jun ang drill.'), findsOneWidget);
      } else {
        expect(
          find.text("I couldn’t understand. Please try again."),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('tanong-question')))
              .controller!
              .text,
          isEmpty,
        );
      }
      expect(await db.allMemories(), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
