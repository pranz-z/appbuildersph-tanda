import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/core/app_database.dart';
import 'package:tanda/core/providers.dart';
import 'package:tanda/logic/local_memory_ask.dart';
import 'package:tanda/ui/screens/tanong_screen.dart';

void main() {
  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    tempDirectory = Directory.systemTemp.createTempSync('tanda-ask-');
    database = AppDatabase.forTesting(
      NativeDatabase(
        File('${tempDirectory.path}${Platform.pathSeparator}ask.db'),
      ),
    );
  });

  tearDown(() async {
    await database.close();
    tempDirectory.deleteSync(recursive: true);
  });

  Future<void> save({
    required String uid,
    required String kind,
    String? person,
    String? item,
    String? place,
    double? amount,
    String? dueDateText,
    required String transcript,
    String? evidence,
    String? audioPath,
  }) async {
    await database.saveConfirmedMemory(
      ConfirmedMemory(
        uid: uid,
        createdAt: '2026-10-10T01:00:00Z',
        updatedAt: '2026-10-10T01:00:00Z',
        kind: kind,
        person: person,
        item: item,
        place: place,
        amount: amount,
        dueDateText: dueDateText,
        transcript: transcript,
        evidence: evidence,
        audioPath: audioPath,
      ),
    );
  }

  Future<LocalMemoryAskResult> ask(String question) async =>
      LocalMemoryAsk().answer(question, await database.confirmedMemories());

  test('answers an item location question from the saved place', () async {
    await save(
      uid: 'wallet',
      kind: 'item_location',
      item: 'wallet',
      place: 'top drawer',
      transcript: 'Nilagay ko ang wallet sa top drawer.',
    );

    final result = await ask('Nasaan ang wallet ko?');

    expect(result.kind, AskResultKind.answer);
    expect(result.answer, contains('wallet'));
    expect(result.answer, contains('top drawer'));
  });

  test('answers a borrowed item question with person and due text', () async {
    await save(
      uid: 'drill',
      kind: 'lent_item',
      person: 'Kuya Jun',
      item: 'drill',
      dueDateText: 'sa Sabado',
      transcript: 'Hiniram ni Kuya Jun yung drill, isosoli sa Sabado.',
    );

    final result = await ask('Sino may hawak ng drill?');

    expect(result.kind, AskResultKind.answer);
    expect(result.answer, contains('Kuya Jun'));
    expect(result.answer, contains('drill'));
    expect(result.answer, contains('sa Sabado'));
  });

  test('answers an utang question with the saved amount', () async {
    await save(
      uid: 'utang',
      kind: 'lent_money',
      person: 'Mia',
      amount: 5000,
      transcript: 'May utang si Mia sa akin na limang libong piso.',
    );

    final result = await ask('Magkano ang utang ni Mia?');

    expect(result.kind, AskResultKind.answer);
    expect(result.answer, contains('Mia'));
    expect(result.answer, contains('5,000'));
  });

  test('matches an amount written without thousands separators', () async {
    await save(
      uid: 'utang',
      kind: 'lent_money',
      person: 'Mia',
      amount: 5000,
      transcript: 'May utang si Mia na limang libong piso.',
    );

    final result = await ask('May utang na 5000?');

    expect(result.kind, AskResultKind.answer);
    expect(result.answer, contains('₱5,000'));
  });

  test('answers a promise question from saved promise fields', () async {
    await save(
      uid: 'promise',
      kind: 'promise',
      person: 'Ate Liza',
      item: 'tawagan si Nanay',
      dueDateText: 'bukas',
      transcript: 'Nangako si Ate Liza na tatawagan si Nanay bukas.',
    );

    final result = await ask('Ano ang pangako ni Ate Liza?');

    expect(result.kind, AskResultKind.answer);
    expect(result.answer, contains('Ate Liza'));
    expect(result.answer, contains('tawagan si Nanay'));
    expect(result.answer, contains('bukas'));
  });

  test(
    'normalizes Taglish hiram and utang terms to the right memory kind',
    () async {
      await save(
        uid: 'loan',
        kind: 'lent_money',
        person: 'Rico',
        amount: 1200,
        transcript: 'Nagpahiram ako kay Rico ng 1200 pesos.',
      );

      final result = await ask('Kanino ako nagpahiram ng pera?');

      expect(result.kind, AskResultKind.answer);
      expect(result.answer, contains('Rico'));
    },
  );

  test('recognizes the Taglish humiram question form', () async {
    await save(
      uid: 'drill',
      kind: 'lent_item',
      person: 'Kuya Jun',
      item: 'drill',
      transcript: 'Hiniram ni Kuya Jun yung drill.',
    );

    final result = await ask('Sino ang humiram ng drill?');

    expect(result.kind, AskResultKind.answer);
    expect(result.answer, contains('Kuya Jun'));
  });

  test(
    'returns the exact not-found answer without a weak entity match',
    () async {
      await save(
        uid: 'drill',
        kind: 'lent_item',
        person: 'Kuya Jun',
        item: 'drill',
        transcript: 'Hiniram ni Kuya Jun yung drill.',
      );

      final result = await ask('Nasaan ang passport?');

      expect(result.kind, AskResultKind.notFound);
      expect(result.answer, 'Wala akong nahanap.');
    },
  );

  test(
    'returns similarly plausible records as clarification choices',
    () async {
      await save(
        uid: 'drill-jun',
        kind: 'lent_item',
        person: 'Kuya Jun',
        item: 'drill',
        transcript: 'Hiniram ni Kuya Jun yung drill.',
      );
      await save(
        uid: 'drill-mia',
        kind: 'lent_item',
        person: 'Mia',
        item: 'drill',
        transcript: 'Hiniram ni Mia yung drill.',
      );

      final result = await ask('Sino may hawak ng drill?');

      expect(result.kind, AskResultKind.ambiguous);
      expect(
        result.matches.map((memory) => memory.uid),
        containsAll(['drill-jun', 'drill-mia']),
      );
    },
  );

  test(
    'Tanong searches confirmed rows again after the database is reopened',
    () async {
      await save(
        uid: 'drill',
        kind: 'lent_item',
        person: 'Kuya Jun',
        item: 'drill',
        transcript: 'Hiniram ni Kuya Jun yung drill.',
      );
      final databasePath =
          '${tempDirectory.path}${Platform.pathSeparator}ask.db';
      await database.close();
      database = AppDatabase.forTesting(NativeDatabase(File(databasePath)));

      final result = await ask('Sino may hawak ng drill?');

      expect(result.kind, AskResultKind.answer);
      expect(result.answer, contains('Kuya Jun'));
    },
  );

  testWidgets(
    'Tanong shows transcript when a saved audio path no longer exists',
    (tester) async {
      await save(
        uid: 'drill',
        kind: 'lent_item',
        person: 'Kuya Jun',
        item: 'drill',
        transcript: 'Hiniram ni Kuya Jun yung drill.',
        audioPath: '${tempDirectory.path}${Platform.pathSeparator}missing.wav',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: Scaffold(body: TanongScreen())),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('tanong-question')),
        'Sino may hawak ng drill?',
      );
      await tester.tap(find.byKey(const ValueKey('tanong-ask')));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Audio is unavailable').evaluate().isNotEmpty) break;
      }

      expect(find.text('Hiniram ni Kuya Jun yung drill.'), findsOneWidget);
      expect(find.text('Audio is unavailable'), findsOneWidget);
    },
  );

  test('Tanong excludes unconfirmed database rows', () async {
    await database
        .into(database.memories)
        .insert(
          MemoriesCompanion.insert(
            uid: 'draft',
            createdAt: '2026-10-10T01:00:00Z',
            updatedAt: '2026-10-10T01:00:00Z',
            kind: 'lent_item',
            person: const Value('Kuya Jun'),
            item: const Value('drill'),
            transcript: 'Hiniram ni Kuya Jun yung drill.',
            confirmed: const Value(false),
          ),
        );

    final result = await ask('Sino may hawak ng drill?');

    expect(result.kind, AskResultKind.notFound);
    expect(result.answer, 'Wala akong nahanap.');
  });
}
