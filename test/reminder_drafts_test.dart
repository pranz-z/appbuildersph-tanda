import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/core/app_database.dart';
import 'package:tanda/core/providers.dart';
import 'package:tanda/logic/reminder_draft.dart';
import 'package:tanda/ui/screens/nakabinbin_screen.dart';

void main() {
  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    tempDirectory = Directory.systemTemp.createTempSync('tanda-reminder-');
    database = AppDatabase.forTesting(
      NativeDatabase(
        File('${tempDirectory.path}${Platform.pathSeparator}reminders.db'),
      ),
    );
  });

  tearDown(() async {
    await database.close();
    tempDirectory.deleteSync(recursive: true);
  });

  Future<StoredMemory> insert({
    required String uid,
    required String kind,
    String status = 'open',
    bool confirmed = true,
    String? person = 'Jun',
    String? item,
    double? amount,
    String? dueDateText = 'sa Sabado',
  }) async {
    await database
        .into(database.memories)
        .insert(
          MemoriesCompanion.insert(
            uid: uid,
            createdAt: '2026-10-10T01:00:00Z',
            updatedAt: '2026-10-10T01:00:00Z',
            kind: kind,
            status: Value(status),
            confirmed: Value(confirmed),
            person: Value(person),
            item: Value(item),
            amount: Value(amount),
            dueDateText: Value(dueDateText),
            transcript: 'Saved transcript $uid',
          ),
        );
    return (await database.memoryByUid(uid))!;
  }

  final cases =
      <
        ({
          String kind,
          String? item,
          double? amount,
          String gentle,
          String direct,
        })
      >[
        (
          kind: 'lent_item',
          item: 'drill',
          amount: null,
          gentle: 'Hi Jun, paalala lang tungkol sa drill. Maaari ba itong maibalik? Nabanggit na: sa Sabado. Salamat.',
          direct:
              'Hi Jun, paki-balik ang drill. Nabanggit na: sa Sabado. Salamat.',
        ),
        (
          kind: 'lent_money',
          item: null,
          amount: 2500,
          gentle: 'Hi Jun, paalala lang tungkol sa utang na ₱2,500. Maaari ba itong maibalik? Nabanggit na: sa Sabado. Salamat.',
          direct: 'Hi Jun, paki-bayaran ang utang na ₱2,500. Nabanggit na: sa Sabado. Salamat.',
        ),
        (
          kind: 'promise',
          item: 'tumawag kay Ana',
          amount: null,
          gentle: 'Hi Jun, paalala lang tungkol sa pangako: tumawag kay Ana. Nabanggit na: sa Sabado. Salamat.',
          direct: 'Hi Jun, paki-tupad ang pangako tungkol sa tumawag kay Ana. Nabanggit na: sa Sabado. Salamat.',
        ),
      ];

  for (final testCase in cases) {
    test('${testCase.kind} has polite Malambing and Diretso drafts', () async {
      final memory = await insert(
        uid: testCase.kind,
        kind: testCase.kind,
        item: testCase.item,
        amount: testCase.amount,
      );
      final builder = ReminderDraftBuilder();

      expect(builder.build(memory, ReminderTone.malambing), testCase.gentle);
      expect(builder.build(memory, ReminderTone.diretso), testCase.direct);
    });
  }

  test('omits absent person, item, amount, and due text', () async {
    final itemMemory = await insert(
      uid: 'missing-item-details',
      kind: 'lent_item',
      person: null,
      item: null,
      dueDateText: null,
    );
    final moneyMemory = await insert(
      uid: 'missing-money-details',
      kind: 'lent_money',
      person: null,
      amount: null,
      dueDateText: null,
    );
    final builder = ReminderDraftBuilder();

    final itemDraft = builder.build(itemMemory, ReminderTone.malambing);
    final moneyDraft = builder.build(moneyMemory, ReminderTone.diretso);

    expect(itemDraft, 'Paalala lang. Maaari ba itong maibalik? Salamat.');
    expect(moneyDraft, 'Paki-bayaran ang utang. Salamat.');
    expect(itemDraft, isNot(contains('Jun')));
    expect(itemDraft, isNot(contains('drill')));
    expect(itemDraft, isNot(contains('Sabado')));
    expect(moneyDraft, isNot(contains('₱')));
    expect(moneyDraft, isNot(contains('Jun')));
  });

  test('keeps vague due-date text as saved and adds no new date', () async {
    final memory = await insert(
      uid: 'vague',
      kind: 'lent_item',
      item: 'drill',
      dueDateText: 'pag may time',
    );

    final draft = ReminderDraftBuilder().build(memory, ReminderTone.diretso);

    expect(draft, contains('Nabanggit na: pag may time.'));
    expect(draft, isNot(contains('bukas')));
    expect(draft, isNot(contains('October')));
  });

  test('refuses locations, done, and unconfirmed records', () async {
    final location = await insert(uid: 'location', kind: 'item_location');
    final done = await insert(uid: 'done', kind: 'promise', status: 'done');
    final draft = await insert(uid: 'draft', kind: 'promise', confirmed: false);
    final builder = ReminderDraftBuilder();

    expect(
      () => builder.build(location, ReminderTone.malambing),
      throwsArgumentError,
    );
    expect(
      () => builder.build(done, ReminderTone.malambing),
      throwsArgumentError,
    );
    expect(
      () => builder.build(draft, ReminderTone.malambing),
      throwsArgumentError,
    );
  });

  testWidgets('draft is editable and copying leaves the saved loop open', (
    tester,
  ) async {
    final memory = await insert(uid: 'drill', kind: 'lent_item', item: 'drill');
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
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
      if (find.text("Draft a reminder").evaluate().isNotEmpty) break;
    }

    await tester.tap(find.text("Draft a reminder"));
    await tester.pumpAndSettle();
    expect(find.text("Gentle"), findsOneWidget);
    expect(find.text("Direct"), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder-draft-input')), findsOneWidget);
    await tester.tap(find.text("Direct"));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reminder-draft-input')),
      'Edited reminder draft',
    );
    await tester.tap(find.text("Copy"));
    await tester.pumpAndSettle();

    expect(copiedText, 'Edited reminder draft');
    expect(find.text("Reminder copied. Nothing was sent."), findsOneWidget);
    expect((await database.memoryByUid(memory.uid))?.status, 'open');
  });
}
