import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/core/app_database.dart';
import 'package:tanda/core/providers.dart';
import 'package:tanda/logic/grounded_answer.dart';
import 'package:tanda/services/llm/llm_service.dart';
import 'package:tanda/services/tts/tts_service.dart';
import 'package:tanda/ui/screens/tanong_screen.dart';

/// Scripted local LLM: returns, throws, or stalls on command, and records
/// the prompt so tests can check exactly what left for the model.
class ScriptedLlm implements LlmService {
  ScriptedLlm({this.text, this.error, this.delay});

  int calls = 0;
  String? lastPrompt;
  String? text;
  final Object? error;
  final Duration? delay;

  @override
  Future<void> init() async {}

  @override
  Future<LlmResult> complete(
    String prompt, {
    String? grammar,
    int maxTokens = 256,
  }) async {
    calls++;
    lastPrompt = prompt;
    if (delay != null) await Future<void>.delayed(delay!);
    if (error != null) throw error!;
    return LlmResult(text: text ?? '', elapsedMs: 1, generatedTokens: 1);
  }

  @override
  Future<void> dispose() async {}
}

StoredMemory memory({
  String uid = 'm1',
  String kind = 'lent_item',
  String? person = 'Jun',
  String? item = 'shovel',
  String? place,
  double? amount,
  String? dueDateText,
  String status = 'open',
  String transcript = 'Jun borrowed the shovel.',
  String? evidence = 'Jun borrowed the shovel',
}) => StoredMemory(
  id: 1,
  uid: uid,
  createdAt: '2026-10-10T01:00:00Z',
  updatedAt: '2026-10-10T01:00:00Z',
  kind: kind,
  person: person,
  item: item,
  place: place,
  amount: amount,
  dueDateText: dueDateText,
  status: status,
  transcript: transcript,
  evidence: evidence,
  confirmed: true,
);

void main() {
  final answerer = GroundedAnswerer(grammar: null);

  group('GroundedAnswerer', () {
    test('returns a valid grounded answer citing the candidate', () async {
      final llm = ScriptedLlm(
        text:
            '{"answer":"Si Jun ang humiram ng shovel.","used_ids":["m1"]}',
      );

      final answer = await answerer.answer(
        llm: llm,
        question: 'Who borrowed the shovel?',
        memory: memory(),
      );

      expect(answer, 'Si Jun ang humiram ng shovel.');
      expect(llm.calls, 1);
      // The prompt carries only this record: question, id, fields, transcript.
      expect(llm.lastPrompt, contains('m1'));
      expect(llm.lastPrompt, contains('Jun borrowed the shovel.'));
      expect(llm.lastPrompt, contains('Who borrowed the shovel?'));
    });

    test('rejects an unsupported person', () {
      expect(
        answerer.validate(
          '{"answer":"Si Mia ang humiram ng shovel.","used_ids":["m1"]}',
          memory(),
        ),
        isNull,
      );
    });

    test('rejects an unsupported item', () {
      expect(
        answerer.validate(
          '{"answer":"Jun borrowed the drill.","used_ids":["m1"]}',
          memory(),
        ),
        isNull,
      );
    });

    test('rejects an unsupported amount on a money record', () {
      final record = memory(
        kind: 'lent_money',
        item: null,
        amount: 500,
        transcript: 'Umutang si Jun ng 500 pesos.',
        evidence: 'Umutang si Jun ng 500 pesos',
      );
      // Supported amount is accepted.
      expect(
        answerer.validate(
          '{"answer":"May utang si Jun na 500 pesos.","used_ids":["m1"]}',
          record,
        ),
        'May utang si Jun na 500 pesos.',
      );
      // A different amount is a fabricated claim.
      expect(
        answerer.validate(
          '{"answer":"May utang si Jun na 600 pesos.","used_ids":["m1"]}',
          record,
        ),
        isNull,
      );
    });

    test('rejects an unsupported date', () {
      expect(
        answerer.validate(
          '{"answer":"Jun borrowed the shovel on Monday.","used_ids":["m1"]}',
          memory(dueDateText: 'sa Sabado'),
        ),
        isNull,
      );
    });

    test('rejects an unsupported status claim', () {
      expect(
        answerer.validate(
          '{"answer":"Jun already returned the shovel.","used_ids":["m1"]}',
          memory(),
        ),
        isNull,
      );
    });

    for (final bad in [
      '{"answer":"Jun borrowed the shovel.","used_ids":["other-uid"]}',
      '{"answer":"Jun borrowed the shovel.","used_ids":[]}',
      '{"answer":"Jun borrowed the shovel."}',
      '{"answer":"Jun borrowed the shovel.","used_ids":"m1"}',
      '{"answer":5,"used_ids":["m1"]}',
      'not json at all',
      '',
      '{"answer":"Jun\nborrowed the shovel.","used_ids":["m1"]}',
      '{"answer":"jun","used_ids":["m1"]}',
      '{"answer":"Jun.","used_ids":["m1"]}',
    ]) {
      test('rejects malformed or miscited output: ${bad.isEmpty ? "(empty)" : bad}', () {
        expect(answerer.validate(bad, memory()), isNull);
      });
    }

    test('model failure returns null so the template is used', () async {
      final llm = ScriptedLlm(error: StateError('engine dead'));
      expect(
        await answerer.answer(
          llm: llm,
          question: 'Who borrowed the shovel?',
          memory: memory(),
        ),
        isNull,
      );
    });

    test('timeout returns null so the template is used', () async {
      final slow = GroundedAnswerer(
        grammar: null,
        timeout: const Duration(milliseconds: 50),
      );
      final llm = ScriptedLlm(
        text: '{"answer":"Si Jun.","used_ids":["m1"]}',
        delay: const Duration(milliseconds: 500),
      );
      expect(
        await slow.answer(
          llm: llm,
          question: 'Who borrowed the shovel?',
          memory: memory(),
        ),
        isNull,
      );
    });

    test('prompt is scoped to the single candidate, not the database', () async {
      final llm = ScriptedLlm(
        text: '{"answer":"Si Jun ang humiram ng shovel.","used_ids":["m1"]}',
      );
      await answerer.answer(
        llm: llm,
        question: 'Who borrowed the shovel?',
        memory: memory(),
      );
      expect(llm.lastPrompt, isNot(contains('drill')));
      expect(llm.lastPrompt, isNot(contains('Mia')));
    });
  });

  group('Tanong grounded stage gating', () {
    late AppDatabase db;
    late ScriptedLlm llm;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> save({
      required String uid,
      required String kind,
      String? person,
      String? item,
      String? place,
      String transcript = '',
      String? evidence,
    }) => db.saveConfirmedMemory(
      ConfirmedMemory(
        uid: uid,
        createdAt: '2026-10-10T01:00:00Z',
        updatedAt: '2026-10-10T01:00:00Z',
        kind: kind,
        person: person,
        item: item,
        place: place,
        amount: null,
        dueDateText: null,
        transcript: transcript,
        evidence: evidence,
        audioPath: null,
      ),
    );

    Future<void> pumpTanong(WidgetTester tester) async {
      llm = ScriptedLlm(
        text: '{"answer":"Si Jun ang humiram ng shovel.","used_ids":["shovel"]}',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            llmServiceProvider.overrideWith((ref) async => llm),
            sttServiceProvider.overrideWith(
              (ref) => throw StateError('no stt in test'),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: TanongScreen())),
        ),
      );
      await tester.pumpAndSettle();
      // Warm the lazy provider so the ask path sees the already-loaded LLM,
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
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('single confident match gets a grounded LLM answer', (
      tester,
    ) async {
      await save(
        uid: 'shovel',
        kind: 'lent_item',
        person: 'Jun',
        item: 'shovel',
        transcript: 'Jun borrowed the shovel.',
        evidence: 'Jun borrowed the shovel',
      );
      await pumpTanong(tester);

      await askTyped(tester, 'Who borrowed the shovel?');

      expect(llm.calls, 1);
      expect(llm.lastPrompt, contains('"shovel"'));
      expect(llm.lastPrompt, contains('Jun borrowed the shovel.'));
      expect(find.text('Si Jun ang humiram ng shovel.'), findsOneWidget);
      // Citation card still renders the stored transcript.
      expect(find.text('Jun borrowed the shovel.'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ungrounded LLM output falls back to the template', (
      tester,
    ) async {
      await save(
        uid: 'shovel',
        kind: 'lent_item',
        person: 'Jun',
        item: 'shovel',
        transcript: 'Jun borrowed the shovel.',
      );
      await pumpTanong(tester);
      llm.text = '{"answer":"Si Mia ang humiram nito.","used_ids":["shovel"]}';

      await askTyped(tester, 'Who borrowed the shovel?');

      expect(llm.calls, 1);
      expect(find.text('Jun borrowed shovel.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('not-found result never calls the LLM', (tester) async {
      await save(
        uid: 'shovel',
        kind: 'lent_item',
        person: 'Jun',
        item: 'shovel',
        transcript: 'Jun borrowed the shovel.',
      );
      await pumpTanong(tester);

      await askTyped(tester, 'Nasaan ang passport ko?');

      expect(llm.calls, 0);
      expect(
        find.text('I couldn’t find a matching memory.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ambiguous result never calls the LLM', (tester) async {
      await save(
        uid: 'shovel-jun',
        kind: 'lent_item',
        person: 'Jun',
        item: 'shovel',
        transcript: 'Jun borrowed the shovel.',
      );
      await save(
        uid: 'shovel-mia',
        kind: 'lent_item',
        person: 'Mia',
        item: 'shovel',
        transcript: 'Hiniram ni Mia yung shovel.',
      );
      await pumpTanong(tester);

      await askTyped(tester, 'Sino ang humiram ng shovel?');

      expect(llm.calls, 0);
      expect(
        find.text('A few memories could match. Which one did you mean?'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('mislabeled-kind verbatim fallback never calls the LLM', (
      tester,
    ) async {
      await save(
        uid: 'shovel-wrong',
        kind: 'item_location',
        transcript: 'Jun borrowed the shovel.',
      );
      await pumpTanong(tester);

      await askTyped(tester, 'Who borrowed the shovel?');

      expect(llm.calls, 0);
      expect(
        find.text('May katugmang tala: "Jun borrowed the shovel."'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });
}
