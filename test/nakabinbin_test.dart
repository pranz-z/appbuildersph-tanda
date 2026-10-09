import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/core/app_database.dart';
import 'package:tanda/core/providers.dart';
import 'package:tanda/logic/open_loops.dart';
import 'package:tanda/ui/screens/nakabinbin_screen.dart';

void main() {
  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    tempDirectory = Directory.systemTemp.createTempSync('tanda-open-loops-');
    database = AppDatabase.forTesting(
      NativeDatabase(
        File('${tempDirectory.path}${Platform.pathSeparator}loops.db'),
      ),
    );
  });

  tearDown(() async {
    await database.close();
    tempDirectory.deleteSync(recursive: true);
  });

  Future<void> insert({
    required String uid,
    required String kind,
    required String status,
    bool confirmed = true,
    String? person,
    String? item,
    double? amount,
    String? dueDateText,
  }) async {
    await database
        .into(database.memories)
        .insert(
          MemoriesCompanion.insert(
            uid: uid,
            createdAt: '2026-10-01T00:00:00Z',
            updatedAt: '2026-10-01T00:00:00Z',
            kind: kind,
            person: Value(person),
            item: Value(item),
            amount: Value(amount),
            dueDateText: Value(dueDateText),
            status: Value(status),
            transcript: 'Saved memory $uid',
            confirmed: Value(confirmed),
          ),
        );
  }

  Future<OpenLoopsData> data({DateTime? now}) async =>
      OpenLoopsData.fromMemories(
        await database.openLoops(),
        now: now ?? DateTime(2026, 10, 10),
      );

  test('loads only confirmed open lent items, loans, and promises', () async {
    await insert(uid: 'item', kind: 'lent_item', status: 'open');
    await insert(uid: 'money', kind: 'lent_money', status: 'open');
    await insert(uid: 'promise', kind: 'promise', status: 'open');
    await insert(uid: 'location', kind: 'item_location', status: 'open');
    await insert(uid: 'done', kind: 'lent_item', status: 'done');
    await insert(
      uid: 'unconfirmed',
      kind: 'promise',
      status: 'open',
      confirmed: false,
    );

    final open = await database.openLoops();

    expect(
      open.map((memory) => memory.uid),
      containsAll(['item', 'money', 'promise']),
    );
    expect(open, hasLength(3));
  });

  test('sorts parsed dates soonest first and undated loops last', () async {
    await insert(
      uid: 'tomorrow',
      kind: 'lent_item',
      status: 'open',
      dueDateText: 'bukas',
    );
    await insert(
      uid: 'overdue',
      kind: 'promise',
      status: 'open',
      dueDateText: '2026-10-09',
    );
    await insert(
      uid: 'today',
      kind: 'lent_money',
      status: 'open',
      dueDateText: '2026-10-10',
    );
    await insert(uid: 'undated', kind: 'lent_item', status: 'open');

    final result = await data();

    expect(result.entries.map((entry) => entry.memory.uid), [
      'overdue',
      'today',
      'tomorrow',
      'undated',
    ]);
    expect(result.entries.first.isOverdue, isTrue);
    expect(result.entries[1].isOverdue, isFalse);
    expect(result.entries.last.dueDate, isNull);
  });

  test('resolves common Taglish weekdays against the supplied date', () async {
    await insert(
      uid: 'saturday',
      kind: 'promise',
      status: 'open',
      dueDateText: 'sa Sabado',
    );
    await insert(
      uid: 'friday',
      kind: 'lent_item',
      status: 'open',
      dueDateText: 'sa Biyernes',
    );

    final result = await data(now: DateTime(2026, 10, 7));

    expect(result.entries.map((entry) => entry.memory.uid), [
      'friday',
      'saturday',
    ]);
    expect(result.entries.first.dueDate, DateTime(2026, 10, 9));
    expect(result.entries.last.dueDate, DateTime(2026, 10, 10));
  });

  test('totals open lent money by person and handles missing fields', () async {
    await insert(
      uid: 'mia-1',
      kind: 'lent_money',
      status: 'open',
      person: 'Mia',
      amount: 500,
    );
    await insert(
      uid: 'mia-2',
      kind: 'lent_money',
      status: 'open',
      person: 'Mia',
      amount: 750.5,
    );
    await insert(
      uid: 'mia-done',
      kind: 'lent_money',
      status: 'done',
      person: 'Mia',
      amount: 900,
    );
    await insert(
      uid: 'no-person',
      kind: 'lent_money',
      status: 'open',
      amount: 25,
    );
    await insert(
      uid: 'no-amount',
      kind: 'lent_money',
      status: 'open',
      person: 'Jun',
    );

    final result = await data();

    expect(result.lentMoneyTotals['Mia'], 1250.5);
    expect(result.lentMoneyTotals['Unknown person'], 25);
    expect(result.lentMoneyTotals.containsKey('Jun'), isFalse);
  });

  testWidgets(
    'marking an open loop done persists and removes it from the list',
    (tester) async {
      await insert(
        uid: 'drill',
        kind: 'lent_item',
        status: 'open',
        person: 'Kuya Jun',
        item: 'drill',
        dueDateText: '2026-10-12',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: Scaffold(body: NakabinbinScreen())),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(const ValueKey('done-drill')).evaluate().isNotEmpty) {
          break;
        }
      }

      await tester.tap(find.byKey(const ValueKey('done-drill')));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find
            .text("All caught up. Nothing pending.")
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }

      expect((await database.memoryByUid('drill'))?.status, 'done');
      expect((await database.confirmedMemories()).single.status, 'done');
      expect(find.text("All caught up. Nothing pending."), findsOneWidget);
    },
  );

  testWidgets('shows a useful empty state and renders incomplete loop fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: Scaffold(body: NakabinbinScreen())),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text("All caught up. Nothing pending.").evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.text("All caught up. Nothing pending."), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await insert(uid: 'incomplete', kind: 'lent_money', status: 'open');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: Scaffold(body: NakabinbinScreen())),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text("No due date recorded").evaluate().isNotEmpty) break;
    }
    expect(find.textContaining("Person not recorded"), findsOneWidget);
    expect(find.text("Amount not recorded"), findsOneWidget);
    expect(find.text("No due date recorded"), findsOneWidget);
  });
}
