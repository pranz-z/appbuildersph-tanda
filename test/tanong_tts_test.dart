import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/core/app_database.dart';
import 'package:tanda/core/providers.dart';
import 'package:tanda/services/llm/llm_service.dart';
import 'package:tanda/services/tts/tts_service.dart';
import 'package:tanda/ui/screens/tanda_screen.dart';
import 'package:tanda/ui/screens/tanong_screen.dart';

class _NullLlm implements LlmService {
  @override
  Future<void> init() async {}

  @override
  Future<LlmResult> complete(
    String prompt, {
    String? grammar,
    int maxTokens = 256,
  }) =>
      throw StateError('no llm in tts tests');

  @override
  Future<void> dispose() async {}
}

class _ScriptedLlm implements LlmService {
  _ScriptedLlm(this.text);

  int calls = 0;
  final String text;

  @override
  Future<void> init() async {}

  @override
  Future<LlmResult> complete(
    String prompt, {
    String? grammar,
    int maxTokens = 256,
  }) async {
    calls++;
    return LlmResult(text: text, elapsedMs: 1, generatedTokens: 1);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late AppDatabase db;
  late FakeTtsService tts;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tts = FakeTtsService();
  });
  tearDown(() => db.close());

  Future<void> saveShovel() => db.saveConfirmedMemory(
    ConfirmedMemory(
      uid: 'shovel',
      createdAt: '2026-10-10T01:00:00Z',
      updatedAt: '2026-10-10T01:00:00Z',
      kind: 'lent_item',
      person: 'Jun',
      item: 'shovel',
      place: null,
      amount: null,
      dueDateText: null,
      transcript: 'Jun borrowed the shovel.',
      evidence: 'Jun borrowed the shovel',
      audioPath: null,
    ),
  );

  Future<void> pumpTanong(
    WidgetTester tester, {
    LlmService? llm,
    Widget child = const TanongScreen(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ttsServiceProvider.overrideWithValue(tts),
          sttServiceProvider.overrideWith(
            (ref) => throw StateError('no stt in test'),
          ),
          llmServiceProvider.overrideWith(
            (ref) async => llm ?? _NullLlm(),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
    // Warm the lazy LLM provider so the grounded stage sees it as loaded,
    // matching startup behavior in the real app.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TanongScreen)),
    );
    await tester.runAsync(() => container.read(llmServiceProvider.future));
    await tester.pump();
  }

  Future<void> askTyped(WidgetTester tester, String question) async {
    await tester.enterText(
      find.byKey(const ValueKey('tanong-question')),
      question,
    );
    await tester.tap(find.byKey(const ValueKey('tanong-ask')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  String displayedAnswer(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('tanong-answer'))).data!;

  testWidgets('auto-speaks exactly the displayed template answer', (
    tester,
  ) async {
    await saveShovel();
    await pumpTanong(tester);

    await askTyped(tester, 'Who borrowed the shovel?');

    expect(find.text('Jun borrowed shovel.'), findsOneWidget);
    expect(tts.spoken, [displayedAnswer(tester)]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('speaks the validated grounded answer, not raw JSON', (
    tester,
  ) async {
    await saveShovel();
    final llm = _ScriptedLlm(
      '{"answer":"Si Jun ang humiram ng shovel.","used_ids":["shovel"]}',
    );
    await pumpTanong(tester, llm: llm);

    await askTyped(tester, 'Who borrowed the shovel?');

    expect(llm.calls, 1);
    expect(displayedAnswer(tester), 'Si Jun ang humiram ng shovel.');
    expect(tts.spoken, ['Si Jun ang humiram ng shovel.']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('speaks the not-found response', (tester) async {
    await saveShovel();
    await pumpTanong(tester);

    await askTyped(tester, 'Nasaan ang passport ko?');

    expect(tts.spoken.length, 1);
    expect(tts.spoken.single, displayedAnswer(tester));
    expect(tts.spoken.single, contains('matching memory'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Replay repeats the same displayed answer', (tester) async {
    await saveShovel();
    await pumpTanong(tester);
    await askTyped(tester, 'Who borrowed the shovel?');

    await tester.tap(find.byKey(const ValueKey('tanong-replay')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(tts.spoken.length, 2);
    expect(tts.spoken[1], tts.spoken[0]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Stop appears while speaking and silences the engine', (
    tester,
  ) async {
    tts.autoComplete = false;
    await saveShovel();
    await pumpTanong(tester);
    await askTyped(tester, 'Who borrowed the shovel?');

    expect(tts.playback.value, TtsPlayback.speaking);
    expect(find.byKey(const ValueKey('tanong-stop')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tanong-stop')));
    await tester.pump();

    expect(tts.stops, greaterThanOrEqualTo(1));
    expect(tts.playback.value, TtsPlayback.idle);
    expect(find.byKey(const ValueKey('tanong-stop')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('playback completion returns the controls to idle', (
    tester,
  ) async {
    tts.autoComplete = false;
    await saveShovel();
    await pumpTanong(tester);
    await askTyped(tester, 'Who borrowed the shovel?');
    expect(find.byKey(const ValueKey('tanong-stop')), findsOneWidget);

    tts.finish();
    await tester.pump();

    expect(find.byKey(const ValueKey('tanong-stop')), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('tanong-replay')))
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a new question stops the previous utterance', (tester) async {
    tts.autoComplete = false;
    await saveShovel();
    await pumpTanong(tester);
    await askTyped(tester, 'Who borrowed the shovel?');
    expect(tts.playback.value, TtsPlayback.speaking);

    await askTyped(tester, 'Nasaan ang passport ko?');

    // Editing the question stopped the first utterance; the second answer is
    // the only new speech — no overlap, no duplicate.
    expect(tts.stops, greaterThanOrEqualTo(1));
    expect(tts.spoken.length, 2);
    expect(tts.spoken.last, displayedAnswer(tester));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing offline voice keeps the text answer and shows a notice', (
    tester,
  ) async {
    tts.status = TtsSpeakStatus.noOfflineVoice;
    await saveShovel();
    await pumpTanong(tester);
    await askTyped(tester, 'Who borrowed the shovel?');

    expect(find.text('Jun borrowed shovel.'), findsOneWidget);
    expect(
      find.text(
        'No offline voice is installed — the answer is shown as text only.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('engine error keeps the text answer and shows a notice', (
    tester,
  ) async {
    tts.status = TtsSpeakStatus.engineError;
    await saveShovel();
    await pumpTanong(tester);
    await askTyped(tester, 'Who borrowed the shovel?');

    expect(find.text('Jun borrowed shovel.'), findsOneWidget);
    expect(
      find.text('Speech is unavailable — the answer is shown as text only.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tanong-stop')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('playback transitions report to the parent', (tester) async {
    tts.autoComplete = false;
    await saveShovel();
    final events = <bool>[];
    await pumpTanong(
      tester,
      child: TanongScreen(onSpeakingChanged: events.add),
    );
    await askTyped(tester, 'Who borrowed the shovel?');
    expect(events, [true]);

    tts.finish();
    await tester.pump();
    expect(events, [true, false]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('grandma speaks only while TTS is actually playing', (
    tester,
  ) async {
    tts.autoComplete = false;
    await saveShovel();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ttsServiceProvider.overrideWithValue(tts),
          sttServiceProvider.overrideWith(
            (ref) => throw StateError('no stt in test'),
          ),
          llmServiceProvider.overrideWith((ref) async => _NullLlm()),
        ],
        child: const MaterialApp(home: Scaffold(body: TandaScreen())),
      ),
    );
    // The grandma avatar animates continuously, so use bounded pumps.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('type-question')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await askTyped(tester, 'Who borrowed the shovel?');
    expect(find.bySemanticsLabel('Tanda is speaking'), findsOneWidget);

    tts.finish();
    await tester.pump();
    expect(
      find.bySemanticsLabel('Tanda is ready to listen'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
