import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('StoredMemory')
class Memories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uid => text().unique()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get kind => text().customConstraint(
    "NOT NULL CHECK (kind IN ('item_location', 'lent_item', 'lent_money', 'promise'))",
  )();
  TextColumn get person => text().nullable()();
  TextColumn get item => text().nullable()();
  TextColumn get place => text().nullable()();
  RealColumn get amount => real().nullable()();
  TextColumn get dueDateText => text().nullable()();
  TextColumn get status => text().customConstraint(
    "NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'done'))",
  )();
  TextColumn get transcript => text()();
  TextColumn get rawTranscript => text().nullable()();
  TextColumn get evidence => text().nullable()();
  TextColumn get audioPath => text().nullable()();
  BlobColumn get embedding => blob().nullable()();
  BoolColumn get confirmed => boolean().withDefault(const Constant(true))();
}

class ConfirmedMemory {
  const ConfirmedMemory({
    required this.uid,
    required this.createdAt,
    required this.updatedAt,
    required this.kind,
    required this.person,
    required this.item,
    required this.place,
    required this.amount,
    required this.dueDateText,
    required this.transcript,
    required this.evidence,
    required this.audioPath,
    this.rawTranscript,
  });

  final String uid;
  final String createdAt;
  final String updatedAt;
  final String kind;
  final String? person;
  final String? item;
  final String? place;
  final double? amount;
  final String? dueDateText;
  final String transcript;
  final String? rawTranscript;
  final String? evidence;
  final String? audioPath;
}

@DriftDatabase(tables: [Memories])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'tanda'));

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(memories, memories.rawTranscript);
    },
  );

  Future<int> saveConfirmedMemory(ConfirmedMemory memory) {
    return into(memories).insert(
      MemoriesCompanion.insert(
        uid: memory.uid,
        createdAt: memory.createdAt,
        updatedAt: memory.updatedAt,
        kind: memory.kind,
        person: Value(memory.person),
        item: Value(memory.item),
        place: Value(memory.place),
        amount: Value(memory.amount),
        dueDateText: Value(memory.dueDateText),
        status: const Value('open'),
        transcript: memory.transcript,
        rawTranscript: Value(memory.rawTranscript),
        evidence: Value(memory.evidence),
        audioPath: Value(memory.audioPath),
        confirmed: const Value(true),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<List<StoredMemory>> allMemories() => (select(
    memories,
  )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).get();

  Future<List<StoredMemory>> confirmedMemories() =>
      (select(memories)
            ..where((row) => row.confirmed.equals(true))
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
          .get();

  Future<List<StoredMemory>> openLoops() =>
      (select(memories)..where(
            (row) =>
                row.confirmed.equals(true) &
                row.status.equals('open') &
                row.kind.isIn(const ['lent_item', 'lent_money', 'promise']),
          ))
          .get();

  Future<int> markMemoryDone(String uid) {
    return (update(memories)..where(
          (row) =>
              row.uid.equals(uid) &
              row.confirmed.equals(true) &
              row.status.equals('open'),
        ))
        .write(
          MemoriesCompanion(
            status: const Value('done'),
            updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
          ),
        );
  }

  Future<StoredMemory?> memoryByUid(String uid) =>
      (select(memories)..where((row) => row.uid.equals(uid))).getSingleOrNull();
}
