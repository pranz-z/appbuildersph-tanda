import 'dart:io';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/core/app_database.dart';
import 'package:tanda/core/providers.dart';
import 'package:tanda/services/audio/recorder_service.dart';
import 'package:tanda/services/llm/extractor.dart';
import 'package:tanda/services/llm/llm_service.dart';
import 'package:tanda/services/stt/stt_service.dart';
import 'package:tanda/ui/screens/tala_screen.dart';

class _FakeRecorder implements AudioCaptureRecorder {
  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> start() async {}

  @override
  Future<String?> stop() async => r'C:\app\files\clips\clip.wav';

  @override
  Future<void> cancel() async {}
}

class _FakeStt implements SttService {
  _FakeStt([
    this.text = 'Hiniram ni Kuya Jun yung drill, isosoli daw sa Sabado.',
  ]);
  final String text;
  @override
  Future<void> init() async {}

  @override
  Future<SttResult> transcribeFile(String wavPath) async =>
      SttResult(text: text, elapsedMs: 42, audioMs: 1200);

  @override
  Future<void> dispose() async {}
}

class _FailOnceDatabase extends AppDatabase {
  // ignore: use_super_parameters
  _FailOnceDatabase(QueryExecutor executor) : super.forTesting(executor);

  bool fail = true;

  @override
  Future<int> saveConfirmedMemory(ConfirmedMemory memory) {
    if (fail) return Future<int>.error(StateError('disk full'));
    return super.saveConfirmedMemory(memory);
  }
}

class _FixedLlm implements LlmService {
  _FixedLlm(this.output);

  final String output;
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
    return LlmResult(text: output, elapsedMs: 1, generatedTokens: 1);
  }

  @override
  Future<void> dispose() async {}
}

String _extractionOutput({
  required String evidence,
  String kind = 'lent_item',
  String? item = 'drill',
  String? amount,
  List<String> uncertainFields = const [],
}) => jsonEncode({
  'kind': kind,
  'person': 'Jun',
  'item': item,
  'place': null,
  'amount': amount == null ? null : num.parse(amount),
  'due_date_text': null,
  'evidence': evidence,
  'uncertain_fields': uncertainFields,
});

void main() {
  final openDatabases = <AppDatabase>[];
  final temporaryDirectories = <Directory>[];

  AppDatabase newDatabase() {
    final directory = Directory.systemTemp.createTempSync('tanda-memory-');
    temporaryDirectories.add(directory);
    final database = AppDatabase.forTesting(
      NativeDatabase(
        File('${directory.path}${Platform.pathSeparator}memories.db'),
      ),
    );
    openDatabases.add(database);
    return database;
  }

  setUp(() {
    openDatabases.clear();
    temporaryDirectories.clear();
  });

  tearDown(() async {
    for (final database in openDatabases) {
      await database.close();
    }
    for (final directory in temporaryDirectories) {
      directory.deleteSync(recursive: true);
    }
  });

  Future<void> mountTala(
    WidgetTester tester,
    AppDatabase database, {
    LlmService? llm,
    String? speech,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          recorderServiceProvider.overrideWithValue(_FakeRecorder()),
          sttServiceProvider.overrideWith(
            (ref) async => speech == null ? _FakeStt() : _FakeStt(speech),
          ),
          extractorProvider.overrideWith(
            (ref) async => Extractor(
              llm ?? FakeLlmService(),
              promptTemplate: '{{TRANSCRIPT}}',
              grammar: 'root ::= x',
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TalaScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openReview(
    WidgetTester tester,
    AppDatabase database, {
    LlmService? llm,
  }) async {
    await mountTala(tester, database, llm: llm);

    final button = find.byKey(const ValueKey('hold-to-talk-button'));
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 320)),
    );
    await gesture.up();
    await tester.pump();
    for (
      var i = 0;
      i < 10 && find.byKey(const ValueKey('1-item')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text("Did Tanda hear that right?"), findsOneWidget);
    expect(find.byKey(const ValueKey('1-item')), findsOneWidget);
  }

  testWidgets('confirm saves edited values that survive reopening SQLite', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('tanda-reopen-');
    temporaryDirectories.add(directory);
    final databasePath =
        '${directory.path}${Platform.pathSeparator}memories.db';
    final database = AppDatabase.forTesting(NativeDatabase(File(databasePath)));
    openDatabases.add(database);

    await openReview(tester, database);
    expect(await database.allMemories(), isEmpty);
    final item = find.byKey(const ValueKey('1-item'));
    await tester.enterText(item, 'toolbox');
    final place = find.byKey(const ValueKey('1-place'));
    await tester.enterText(place, 'garage');
    await tester.ensureVisible(find.text("Yes, save it"));
    await tester.tap(find.text("Yes, save it"));
    await tester.pumpAndSettle();

    expect(
      find.text("Saved in your notebook, on this device."),
      findsOneWidget,
    );
    final saved = await database.allMemories();
    expect(saved, hasLength(1));
    expect(saved.single.item, 'toolbox');
    expect(saved.single.place, 'garage');
    expect(saved.single.kind, 'lent_item');
    expect(saved.single.person, 'Kuya Jun');
    expect(saved.single.amount, isNull);
    expect(saved.single.dueDateText, 'sa Sabado');
    expect(saved.single.evidence, 'Hiniram ni Kuya Jun yung drill');
    expect(
      saved.single.transcript,
      'Hiniram ni Kuya Jun yung drill, isosoli daw sa Sabado.',
    );
    expect(saved.single.audioPath, r'C:\app\files\clips\clip.wav');
    expect(saved.single.status, 'open');
    expect(saved.single.confirmed, isTrue);
    expect(saved.single.embedding, isNull);

    final uid = saved.single.uid;
    await database.close();
    openDatabases.remove(database);
    final reopened = AppDatabase.forTesting(NativeDatabase(File(databasePath)));
    openDatabases.add(reopened);
    final reloaded = await reopened.memoryByUid(uid);
    expect(reloaded?.item, 'toolbox');
    expect(reloaded?.place, 'garage');
    expect(
      reloaded?.rawTranscript,
      'Hiniram ni Kuya Jun yung drill, isosoli daw sa Sabado.',
    );
    await mountTala(tester, reopened);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    for (
      var i = 0;
      i < 10 && find.text("What Tanda remembers").evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text("What Tanda remembers"), findsOneWidget);
    expect(find.textContaining('toolbox'), findsWidgets);
  });

  testWidgets('typed description uses review and saves without audio', (
    tester,
  ) async {
    final database = newDatabase();
    await mountTala(tester, database);
    const description =
        'Hiniram ni Kuya Jun yung drill, isosoli daw sa Sabado.';
    await tester.enterText(
      find.byKey(const ValueKey('tala-typed-input')),
      description,
    );
    await tester.tap(find.byKey(const ValueKey('tala-typed-submit')));
    await tester.pump();
    for (
      var i = 0;
      i < 10 && find.byKey(const ValueKey('1-item')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text("Did Tanda hear that right?"), findsOneWidget);
    expect(
      find.text("The exact evidence is highlighted above."),
      findsOneWidget,
    );
    final transcriptField = tester.widget<TextField>(
      find.byKey(const ValueKey('review-transcript-1')),
    );
    final highlighted = transcriptField.controller!
        .buildTextSpan(
          context: tester.element(
            find.byKey(const ValueKey('review-transcript-1')),
          ),
          withComposing: false,
        )
        .children!
        .where(
          (span) =>
              span is TextSpan &&
              span.text == 'Hiniram ni Kuya Jun yung drill' &&
              span.style?.backgroundColor ==
                  Theme.of(
                    tester.element(
                      find.byKey(const ValueKey('review-transcript-1')),
                    ),
                  ).colorScheme.tertiaryContainer,
        );
    expect(highlighted, hasLength(1));

    await tester.ensureVisible(find.text("Yes, save it"));
    await tester.tap(find.text("Yes, save it"));
    await tester.pumpAndSettle();
    final saved = (await database.allMemories()).single;
    expect(saved.transcript, description);
    expect(saved.audioPath, isNull);
    expect(saved.rawTranscript, isNull);
    expect(saved.evidence, 'Hiniram ni Kuya Jun yung drill');
  });

  testWidgets('failed extraction retry opens editable manual entry', (
    tester,
  ) async {
    final database = newDatabase();
    final llm = _FixedLlm(_extractionOutput(evidence: 'made up evidence'));
    await mountTala(tester, database, llm: llm);
    await tester.enterText(
      find.byKey(const ValueKey('tala-typed-input')),
      'Hiniram ni Jun ang drill.',
    );
    await tester.tap(find.byKey(const ValueKey('tala-typed-submit')));
    await tester.pumpAndSettle();
    expect(llm.calls, 2);
    expect(find.text("Write the details yourself"), findsOneWidget);
    expect(find.byKey(const ValueKey('1-evidence')), findsNothing);
    expect(
      find.textContaining('Extraction failed after retry.'),
      findsOneWidget,
    );
    expect(
      find.text('Manual entry: no verified evidence is attached.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('review-transcript-1')),
      'Edited typed description.',
    );
    await tester.tap(find.byKey(const ValueKey('memory-type-promise')));
    await tester.enterText(
      find.byKey(const ValueKey('1-item')),
      'return the key',
    );
    await tester.ensureVisible(find.text("Yes, save it"));
    await tester.tap(find.text("Yes, save it"));
    await tester.pumpAndSettle();

    final saved = (await database.allMemories()).single;
    expect(saved.kind, 'promise');
    expect(saved.item, 'return the key');
    expect(saved.transcript, 'Edited typed description.');
    expect(saved.evidence, isNull);
    expect(saved.audioPath, isNull);
  });

  for (final (kind, label) in [
    ('lent_item', 'May humiram na gamit'),
    ('lent_money', 'May pinautang na pera'),
    ('item_location', 'Alam ko kung saan nakalagay'),
    ('promise', 'May ipinangako sa akin'),
  ]) {
    testWidgets('type choice $label persists $kind and preserves edits', (
      tester,
    ) async {
      final database = newDatabase();
      await openReview(tester, database);
      expect(find.byKey(const ValueKey('1-kind')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('1-item')),
        'edited drill',
      );
      await tester.enterText(find.byKey(const ValueKey('1-place')), 'garage');
      await tester.enterText(find.byKey(const ValueKey('1-amount')), '500');
      final choice = find.byKey(ValueKey('memory-type-$kind'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(choice).selected, isTrue);
      await tester.ensureVisible(find.text("Yes, save it"));
      await tester.ensureVisible(find.text("Yes, save it"));
      await tester.tap(find.text("Yes, save it"));
      await tester.pumpAndSettle();
      final saved = (await database.allMemories()).single;
      expect(saved.kind, kind);
      expect(saved.item, 'edited drill');
      expect(saved.place, 'garage');
      expect(saved.amount, 500);
    });
  }

  testWidgets(
    'manual type is explicit and selected type fields are validated',
    (tester) async {
      final database = newDatabase();
      await mountTala(tester, database, llm: _FixedLlm('not JSON'));
      await tester.enterText(
        find.byKey(const ValueKey('tala-typed-input')),
        'Nasa drawer ang susi.',
      );
      await tester.tap(find.byKey(const ValueKey('tala-typed-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text("Yes, save it"));
      await tester.ensureVisible(find.text("Yes, save it"));
      await tester.tap(find.text("Yes, save it"));
      await tester.pump();
      expect(find.text("Choose a memory type before saving."), findsOneWidget);
      final money = find.byKey(const ValueKey('memory-type-lent_money'));
      await tester.ensureVisible(money);
      await tester.tap(money);
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('1-item')), 'susi');
      await tester.ensureVisible(find.text("Yes, save it"));
      await tester.ensureVisible(find.text("Yes, save it"));
      await tester.tap(find.text("Yes, save it"));
      await tester.pump();
      expect(find.text("Enter the amount lent before saving."), findsOneWidget);
      final location = find.byKey(const ValueKey('memory-type-item_location'));
      await tester.ensureVisible(location);
      await tester.tap(location);
      await tester.pump();
      await tester.ensureVisible(find.text("Yes, save it"));
      await tester.ensureVisible(find.text("Yes, save it"));
      await tester.tap(find.text("Yes, save it"));
      await tester.pump();
      expect(
        find.text("Enter the item and its place before saving."),
        findsOneWidget,
      );
      expect(await database.allMemories(), isEmpty);
      await tester.enterText(find.byKey(const ValueKey('1-place')), 'drawer');
      await tester.ensureVisible(find.text("Retry save"));
      await tester.tap(find.text("Retry save"));
      await tester.pumpAndSettle();
      final saved = (await database.allMemories()).single;
      expect(saved.kind, 'item_location');
      expect(saved.item, 'susi');
      expect(saved.place, 'drawer');
    },
  );

  testWidgets('uncertain extracted fields are indicated and editable', (
    tester,
  ) async {
    final database = newDatabase();
    const transcript = 'Nagpautang ako kay Jun ng 500 pesos.';
    final llm = _FixedLlm(
      _extractionOutput(
        evidence: transcript,
        kind: 'lent_money',
        item: null,
        amount: '500',
        uncertainFields: ['amount'],
      ),
    );
    await mountTala(tester, database, llm: llm);
    await tester.enterText(
      find.byKey(const ValueKey('tala-typed-input')),
      transcript,
    );
    await tester.tap(find.byKey(const ValueKey('tala-typed-submit')));
    await tester.pump();
    for (
      var i = 0;
      i < 10 && find.byKey(const ValueKey('1-amount')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text("Needs review: Amount (PHP)"), findsOneWidget);
    expect(find.text("Please check this AI-extracted detail."), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('1-amount')), '750');
    await tester.ensureVisible(find.text("Yes, save it"));
    await tester.tap(find.text("Yes, save it"));
    await tester.pumpAndSettle();
    expect((await database.allMemories()).single.amount, 750);
  });

  testWidgets('repeated confirm taps leave one row', (tester) async {
    final database = newDatabase();
    await openReview(tester, database);

    await tester.ensureVisible(find.text("Yes, save it"));
    await tester.tap(find.text("Yes, save it"));
    await tester.tap(find.text("Yes, save it"), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(await database.allMemories(), hasLength(1));
    expect(find.text("Saved"), findsOneWidget);
    await database.close();
  });

  testWidgets('confirmation rejects evidence that is not in the transcript', (
    tester,
  ) async {
    final database = newDatabase();
    await openReview(tester, database);
    await tester.enterText(find.byKey(const ValueKey('1-evidence')), '');
    await tester.ensureVisible(find.text("Yes, save it"));
    await tester.tap(find.text("Yes, save it"));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("Evidence must exactly match part of your words"),
      findsOneWidget,
    );
    expect(await database.allMemories(), isEmpty);
    await database.close();
  });

  testWidgets('failed save keeps edited review data available for retry', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('tanda-failing-');
    temporaryDirectories.add(directory);
    final database = _FailOnceDatabase(
      NativeDatabase(
        File('${directory.path}${Platform.pathSeparator}memories.db'),
      ),
    );
    openDatabases.add(database);
    await openReview(tester, database);
    final item = find.byKey(const ValueKey('1-item'));
    await tester.enterText(item, 'toolbox');
    await tester.ensureVisible(find.text("Yes, save it"));
    await tester.tap(find.text("Yes, save it"));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not save on this device.'),
      findsOneWidget,
    );
    expect(find.text("Did Tanda hear that right?"), findsOneWidget);
    expect(find.text('toolbox'), findsOneWidget);
    expect(await database.allMemories(), isEmpty);

    database.fail = false;
    await tester.tap(find.text("Retry save"));
    await tester.pumpAndSettle();
    expect(
      find.text("Saved in your notebook, on this device."),
      findsOneWidget,
    );
    expect((await database.allMemories()).single.item, 'toolbox');
    await database.close();
  });

  testWidgets(
    'unintelligible speech never opens review or saves; try again resets',
    (tester) async {
      for (final speech in ['[Buzzing]', 'Nga mas kawin stress tutut kapaw']) {
        final database = newDatabase();
        final llm = _FixedLlm(
          '{"understood":false,"cleaned_sentence":null,"memory":null}',
        );
        await mountTala(tester, database, llm: llm, speech: speech);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('hold-to-talk-button'))),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 320)),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          find.text("I couldn’t understand. Please try again."),
          findsOneWidget,
        );
        expect(find.text("Did Tanda hear that right?"), findsNothing);
        expect(find.text("Yes, save it"), findsNothing);
        expect(await database.allMemories(), isEmpty);
        expect(llm.calls, speech == '[Buzzing]' ? 0 : 1);
        await tester.tap(find.text("Try again"));
        await tester.pumpAndSettle();
        expect(
          find.text("I couldn’t understand. Please try again."),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('hold-to-talk-button')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('corrected speech and unchanged raw speech persist separately', (
    tester,
  ) async {
    final database = newDatabase();
    const raw = 'Hiniram ni Jun yung drill, ah, sa Sabado daw ibabalik.';
    const cleaned = 'Hiniram ni Jun ang drill. Sa Sabado daw ibabalik.';
    final llm = _FixedLlm(
      jsonEncode({
        'understood': true,
        'cleaned_sentence': cleaned,
        'memory': jsonDecode(
          _extractionOutput(evidence: 'Hiniram ni Jun ang drill'),
        ),
      }),
    );
    await mountTala(tester, database, llm: llm, speech: raw);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('hold-to-talk-button'))),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 320)),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text("Original Whisper transcript"), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('review-transcript-1')))
          .controller!
          .text,
      cleaned,
    );
    expect(await database.allMemories(), isEmpty);
    await tester.ensureVisible(find.text("Yes, save it"));
    await tester.ensureVisible(find.text("Yes, save it"));
    await tester.tap(find.text("Yes, save it"));
    await tester.pumpAndSettle();
    final saved = (await database.allMemories()).single;
    expect(saved.rawTranscript, raw);
    expect(saved.transcript, cleaned);
  });

  test(
    'v1 upgrade preserves existing memories and adds nullable raw transcript',
    () async {
      final directory = Directory.systemTemp.createTempSync('tanda-upgrade-');
      temporaryDirectories.add(directory);
      final path = '${directory.path}/memories.db';
      final original = AppDatabase.forTesting(NativeDatabase(File(path)));
      await original.saveConfirmedMemory(
        const ConfirmedMemory(
          uid: 'legacy',
          createdAt: '2026-10-10',
          updatedAt: '2026-10-10',
          kind: 'promise',
          person: 'Jun',
          item: null,
          place: null,
          amount: null,
          dueDateText: null,
          transcript: 'Sabi ni Jun bukas.',
          evidence: null,
          audioPath: null,
        ),
      );
      await original.customStatement(
        'ALTER TABLE memories DROP COLUMN raw_transcript',
      );
      await original.customStatement('PRAGMA user_version = 1');
      await original.close();
      final upgraded = AppDatabase.forTesting(NativeDatabase(File(path)));
      openDatabases.add(upgraded);
      final memory = await upgraded.memoryByUid('legacy');
      expect(memory?.transcript, 'Sabi ni Jun bukas.');
      expect(memory?.rawTranscript, isNull);
      expect(memory?.person, 'Jun');
      expect(
        (await upgraded.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        2,
      );
    },
  );
}
