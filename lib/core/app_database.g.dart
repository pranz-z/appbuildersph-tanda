// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MemoriesTable extends Memories
    with TableInfo<$MemoriesTable, StoredMemory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (kind IN (\'item_location\', \'lent_item\', \'lent_money\', \'promise\'))',
  );
  static const VerificationMeta _personMeta = const VerificationMeta('person');
  @override
  late final GeneratedColumn<String> person = GeneratedColumn<String>(
    'person',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemMeta = const VerificationMeta('item');
  @override
  late final GeneratedColumn<String> item = GeneratedColumn<String>(
    'item',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _placeMeta = const VerificationMeta('place');
  @override
  late final GeneratedColumn<String> place = GeneratedColumn<String>(
    'place',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateTextMeta = const VerificationMeta(
    'dueDateText',
  );
  @override
  late final GeneratedColumn<String> dueDateText = GeneratedColumn<String>(
    'due_date_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT \'open\' CHECK (status IN (\'open\', \'done\'))',
    defaultValue: const CustomExpression('\'open\''),
  );
  static const VerificationMeta _transcriptMeta = const VerificationMeta(
    'transcript',
  );
  @override
  late final GeneratedColumn<String> transcript = GeneratedColumn<String>(
    'transcript',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawTranscriptMeta = const VerificationMeta(
    'rawTranscript',
  );
  @override
  late final GeneratedColumn<String> rawTranscript = GeneratedColumn<String>(
    'raw_transcript',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evidenceMeta = const VerificationMeta(
    'evidence',
  );
  @override
  late final GeneratedColumn<String> evidence = GeneratedColumn<String>(
    'evidence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  @override
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confirmedMeta = const VerificationMeta(
    'confirmed',
  );
  @override
  late final GeneratedColumn<bool> confirmed = GeneratedColumn<bool>(
    'confirmed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("confirmed" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uid,
    createdAt,
    updatedAt,
    kind,
    person,
    item,
    place,
    amount,
    dueDateText,
    status,
    transcript,
    rawTranscript,
    evidence,
    audioPath,
    embedding,
    confirmed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memories';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredMemory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('person')) {
      context.handle(
        _personMeta,
        person.isAcceptableOrUnknown(data['person']!, _personMeta),
      );
    }
    if (data.containsKey('item')) {
      context.handle(
        _itemMeta,
        item.isAcceptableOrUnknown(data['item']!, _itemMeta),
      );
    }
    if (data.containsKey('place')) {
      context.handle(
        _placeMeta,
        place.isAcceptableOrUnknown(data['place']!, _placeMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    if (data.containsKey('due_date_text')) {
      context.handle(
        _dueDateTextMeta,
        dueDateText.isAcceptableOrUnknown(
          data['due_date_text']!,
          _dueDateTextMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('transcript')) {
      context.handle(
        _transcriptMeta,
        transcript.isAcceptableOrUnknown(data['transcript']!, _transcriptMeta),
      );
    } else if (isInserting) {
      context.missing(_transcriptMeta);
    }
    if (data.containsKey('raw_transcript')) {
      context.handle(
        _rawTranscriptMeta,
        rawTranscript.isAcceptableOrUnknown(
          data['raw_transcript']!,
          _rawTranscriptMeta,
        ),
      );
    }
    if (data.containsKey('evidence')) {
      context.handle(
        _evidenceMeta,
        evidence.isAcceptableOrUnknown(data['evidence']!, _evidenceMeta),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    }
    if (data.containsKey('confirmed')) {
      context.handle(
        _confirmedMeta,
        confirmed.isAcceptableOrUnknown(data['confirmed']!, _confirmedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredMemory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredMemory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      person: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person'],
      ),
      item: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item'],
      ),
      place: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      ),
      dueDateText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_date_text'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      transcript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript'],
      )!,
      rawTranscript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_transcript'],
      ),
      evidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence'],
      ),
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      ),
      confirmed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}confirmed'],
      )!,
    );
  }

  @override
  $MemoriesTable createAlias(String alias) {
    return $MemoriesTable(attachedDatabase, alias);
  }
}

class StoredMemory extends DataClass implements Insertable<StoredMemory> {
  final int id;
  final String uid;
  final String createdAt;
  final String updatedAt;
  final String kind;
  final String? person;
  final String? item;
  final String? place;
  final double? amount;
  final String? dueDateText;
  final String status;
  final String transcript;
  final String? rawTranscript;
  final String? evidence;
  final String? audioPath;
  final Uint8List? embedding;
  final bool confirmed;
  const StoredMemory({
    required this.id,
    required this.uid,
    required this.createdAt,
    required this.updatedAt,
    required this.kind,
    this.person,
    this.item,
    this.place,
    this.amount,
    this.dueDateText,
    required this.status,
    required this.transcript,
    this.rawTranscript,
    this.evidence,
    this.audioPath,
    this.embedding,
    required this.confirmed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uid'] = Variable<String>(uid);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || person != null) {
      map['person'] = Variable<String>(person);
    }
    if (!nullToAbsent || item != null) {
      map['item'] = Variable<String>(item);
    }
    if (!nullToAbsent || place != null) {
      map['place'] = Variable<String>(place);
    }
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<double>(amount);
    }
    if (!nullToAbsent || dueDateText != null) {
      map['due_date_text'] = Variable<String>(dueDateText);
    }
    map['status'] = Variable<String>(status);
    map['transcript'] = Variable<String>(transcript);
    if (!nullToAbsent || rawTranscript != null) {
      map['raw_transcript'] = Variable<String>(rawTranscript);
    }
    if (!nullToAbsent || evidence != null) {
      map['evidence'] = Variable<String>(evidence);
    }
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || embedding != null) {
      map['embedding'] = Variable<Uint8List>(embedding);
    }
    map['confirmed'] = Variable<bool>(confirmed);
    return map;
  }

  MemoriesCompanion toCompanion(bool nullToAbsent) {
    return MemoriesCompanion(
      id: Value(id),
      uid: Value(uid),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      kind: Value(kind),
      person: person == null && nullToAbsent
          ? const Value.absent()
          : Value(person),
      item: item == null && nullToAbsent ? const Value.absent() : Value(item),
      place: place == null && nullToAbsent
          ? const Value.absent()
          : Value(place),
      amount: amount == null && nullToAbsent
          ? const Value.absent()
          : Value(amount),
      dueDateText: dueDateText == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDateText),
      status: Value(status),
      transcript: Value(transcript),
      rawTranscript: rawTranscript == null && nullToAbsent
          ? const Value.absent()
          : Value(rawTranscript),
      evidence: evidence == null && nullToAbsent
          ? const Value.absent()
          : Value(evidence),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      embedding: embedding == null && nullToAbsent
          ? const Value.absent()
          : Value(embedding),
      confirmed: Value(confirmed),
    );
  }

  factory StoredMemory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredMemory(
      id: serializer.fromJson<int>(json['id']),
      uid: serializer.fromJson<String>(json['uid']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      kind: serializer.fromJson<String>(json['kind']),
      person: serializer.fromJson<String?>(json['person']),
      item: serializer.fromJson<String?>(json['item']),
      place: serializer.fromJson<String?>(json['place']),
      amount: serializer.fromJson<double?>(json['amount']),
      dueDateText: serializer.fromJson<String?>(json['dueDateText']),
      status: serializer.fromJson<String>(json['status']),
      transcript: serializer.fromJson<String>(json['transcript']),
      rawTranscript: serializer.fromJson<String?>(json['rawTranscript']),
      evidence: serializer.fromJson<String?>(json['evidence']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      embedding: serializer.fromJson<Uint8List?>(json['embedding']),
      confirmed: serializer.fromJson<bool>(json['confirmed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uid': serializer.toJson<String>(uid),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'kind': serializer.toJson<String>(kind),
      'person': serializer.toJson<String?>(person),
      'item': serializer.toJson<String?>(item),
      'place': serializer.toJson<String?>(place),
      'amount': serializer.toJson<double?>(amount),
      'dueDateText': serializer.toJson<String?>(dueDateText),
      'status': serializer.toJson<String>(status),
      'transcript': serializer.toJson<String>(transcript),
      'rawTranscript': serializer.toJson<String?>(rawTranscript),
      'evidence': serializer.toJson<String?>(evidence),
      'audioPath': serializer.toJson<String?>(audioPath),
      'embedding': serializer.toJson<Uint8List?>(embedding),
      'confirmed': serializer.toJson<bool>(confirmed),
    };
  }

  StoredMemory copyWith({
    int? id,
    String? uid,
    String? createdAt,
    String? updatedAt,
    String? kind,
    Value<String?> person = const Value.absent(),
    Value<String?> item = const Value.absent(),
    Value<String?> place = const Value.absent(),
    Value<double?> amount = const Value.absent(),
    Value<String?> dueDateText = const Value.absent(),
    String? status,
    String? transcript,
    Value<String?> rawTranscript = const Value.absent(),
    Value<String?> evidence = const Value.absent(),
    Value<String?> audioPath = const Value.absent(),
    Value<Uint8List?> embedding = const Value.absent(),
    bool? confirmed,
  }) => StoredMemory(
    id: id ?? this.id,
    uid: uid ?? this.uid,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    kind: kind ?? this.kind,
    person: person.present ? person.value : this.person,
    item: item.present ? item.value : this.item,
    place: place.present ? place.value : this.place,
    amount: amount.present ? amount.value : this.amount,
    dueDateText: dueDateText.present ? dueDateText.value : this.dueDateText,
    status: status ?? this.status,
    transcript: transcript ?? this.transcript,
    rawTranscript: rawTranscript.present
        ? rawTranscript.value
        : this.rawTranscript,
    evidence: evidence.present ? evidence.value : this.evidence,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    embedding: embedding.present ? embedding.value : this.embedding,
    confirmed: confirmed ?? this.confirmed,
  );
  StoredMemory copyWithCompanion(MemoriesCompanion data) {
    return StoredMemory(
      id: data.id.present ? data.id.value : this.id,
      uid: data.uid.present ? data.uid.value : this.uid,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      kind: data.kind.present ? data.kind.value : this.kind,
      person: data.person.present ? data.person.value : this.person,
      item: data.item.present ? data.item.value : this.item,
      place: data.place.present ? data.place.value : this.place,
      amount: data.amount.present ? data.amount.value : this.amount,
      dueDateText: data.dueDateText.present
          ? data.dueDateText.value
          : this.dueDateText,
      status: data.status.present ? data.status.value : this.status,
      transcript: data.transcript.present
          ? data.transcript.value
          : this.transcript,
      rawTranscript: data.rawTranscript.present
          ? data.rawTranscript.value
          : this.rawTranscript,
      evidence: data.evidence.present ? data.evidence.value : this.evidence,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      confirmed: data.confirmed.present ? data.confirmed.value : this.confirmed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredMemory(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('kind: $kind, ')
          ..write('person: $person, ')
          ..write('item: $item, ')
          ..write('place: $place, ')
          ..write('amount: $amount, ')
          ..write('dueDateText: $dueDateText, ')
          ..write('status: $status, ')
          ..write('transcript: $transcript, ')
          ..write('rawTranscript: $rawTranscript, ')
          ..write('evidence: $evidence, ')
          ..write('audioPath: $audioPath, ')
          ..write('embedding: $embedding, ')
          ..write('confirmed: $confirmed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uid,
    createdAt,
    updatedAt,
    kind,
    person,
    item,
    place,
    amount,
    dueDateText,
    status,
    transcript,
    rawTranscript,
    evidence,
    audioPath,
    $driftBlobEquality.hash(embedding),
    confirmed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredMemory &&
          other.id == this.id &&
          other.uid == this.uid &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.kind == this.kind &&
          other.person == this.person &&
          other.item == this.item &&
          other.place == this.place &&
          other.amount == this.amount &&
          other.dueDateText == this.dueDateText &&
          other.status == this.status &&
          other.transcript == this.transcript &&
          other.rawTranscript == this.rawTranscript &&
          other.evidence == this.evidence &&
          other.audioPath == this.audioPath &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.confirmed == this.confirmed);
}

class MemoriesCompanion extends UpdateCompanion<StoredMemory> {
  final Value<int> id;
  final Value<String> uid;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String> kind;
  final Value<String?> person;
  final Value<String?> item;
  final Value<String?> place;
  final Value<double?> amount;
  final Value<String?> dueDateText;
  final Value<String> status;
  final Value<String> transcript;
  final Value<String?> rawTranscript;
  final Value<String?> evidence;
  final Value<String?> audioPath;
  final Value<Uint8List?> embedding;
  final Value<bool> confirmed;
  const MemoriesCompanion({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.kind = const Value.absent(),
    this.person = const Value.absent(),
    this.item = const Value.absent(),
    this.place = const Value.absent(),
    this.amount = const Value.absent(),
    this.dueDateText = const Value.absent(),
    this.status = const Value.absent(),
    this.transcript = const Value.absent(),
    this.rawTranscript = const Value.absent(),
    this.evidence = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.embedding = const Value.absent(),
    this.confirmed = const Value.absent(),
  });
  MemoriesCompanion.insert({
    this.id = const Value.absent(),
    required String uid,
    required String createdAt,
    required String updatedAt,
    required String kind,
    this.person = const Value.absent(),
    this.item = const Value.absent(),
    this.place = const Value.absent(),
    this.amount = const Value.absent(),
    this.dueDateText = const Value.absent(),
    this.status = const Value.absent(),
    required String transcript,
    this.rawTranscript = const Value.absent(),
    this.evidence = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.embedding = const Value.absent(),
    this.confirmed = const Value.absent(),
  }) : uid = Value(uid),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       kind = Value(kind),
       transcript = Value(transcript);
  static Insertable<StoredMemory> custom({
    Expression<int>? id,
    Expression<String>? uid,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? kind,
    Expression<String>? person,
    Expression<String>? item,
    Expression<String>? place,
    Expression<double>? amount,
    Expression<String>? dueDateText,
    Expression<String>? status,
    Expression<String>? transcript,
    Expression<String>? rawTranscript,
    Expression<String>? evidence,
    Expression<String>? audioPath,
    Expression<Uint8List>? embedding,
    Expression<bool>? confirmed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uid != null) 'uid': uid,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (kind != null) 'kind': kind,
      if (person != null) 'person': person,
      if (item != null) 'item': item,
      if (place != null) 'place': place,
      if (amount != null) 'amount': amount,
      if (dueDateText != null) 'due_date_text': dueDateText,
      if (status != null) 'status': status,
      if (transcript != null) 'transcript': transcript,
      if (rawTranscript != null) 'raw_transcript': rawTranscript,
      if (evidence != null) 'evidence': evidence,
      if (audioPath != null) 'audio_path': audioPath,
      if (embedding != null) 'embedding': embedding,
      if (confirmed != null) 'confirmed': confirmed,
    });
  }

  MemoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? uid,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<String>? kind,
    Value<String?>? person,
    Value<String?>? item,
    Value<String?>? place,
    Value<double?>? amount,
    Value<String?>? dueDateText,
    Value<String>? status,
    Value<String>? transcript,
    Value<String?>? rawTranscript,
    Value<String?>? evidence,
    Value<String?>? audioPath,
    Value<Uint8List?>? embedding,
    Value<bool>? confirmed,
  }) {
    return MemoriesCompanion(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      kind: kind ?? this.kind,
      person: person ?? this.person,
      item: item ?? this.item,
      place: place ?? this.place,
      amount: amount ?? this.amount,
      dueDateText: dueDateText ?? this.dueDateText,
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      evidence: evidence ?? this.evidence,
      audioPath: audioPath ?? this.audioPath,
      embedding: embedding ?? this.embedding,
      confirmed: confirmed ?? this.confirmed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (person.present) {
      map['person'] = Variable<String>(person.value);
    }
    if (item.present) {
      map['item'] = Variable<String>(item.value);
    }
    if (place.present) {
      map['place'] = Variable<String>(place.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (dueDateText.present) {
      map['due_date_text'] = Variable<String>(dueDateText.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (transcript.present) {
      map['transcript'] = Variable<String>(transcript.value);
    }
    if (rawTranscript.present) {
      map['raw_transcript'] = Variable<String>(rawTranscript.value);
    }
    if (evidence.present) {
      map['evidence'] = Variable<String>(evidence.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (confirmed.present) {
      map['confirmed'] = Variable<bool>(confirmed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoriesCompanion(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('kind: $kind, ')
          ..write('person: $person, ')
          ..write('item: $item, ')
          ..write('place: $place, ')
          ..write('amount: $amount, ')
          ..write('dueDateText: $dueDateText, ')
          ..write('status: $status, ')
          ..write('transcript: $transcript, ')
          ..write('rawTranscript: $rawTranscript, ')
          ..write('evidence: $evidence, ')
          ..write('audioPath: $audioPath, ')
          ..write('embedding: $embedding, ')
          ..write('confirmed: $confirmed')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MemoriesTable memories = $MemoriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [memories];
}

typedef $$MemoriesTableCreateCompanionBuilder = MemoriesCompanion Function({
  Value<int> id,
  required String uid,
  required String createdAt,
  required String updatedAt,
  required String kind,
  Value<String?> person,
  Value<String?> item,
  Value<String?> place,
  Value<double?> amount,
  Value<String?> dueDateText,
  Value<String> status,
  required String transcript,
  Value<String?> rawTranscript,
  Value<String?> evidence,
  Value<String?> audioPath,
  Value<Uint8List?> embedding,
  Value<bool> confirmed,
});
typedef $$MemoriesTableUpdateCompanionBuilder = MemoriesCompanion Function({
  Value<int> id,
  Value<String> uid,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<String> kind,
  Value<String?> person,
  Value<String?> item,
  Value<String?> place,
  Value<double?> amount,
  Value<String?> dueDateText,
  Value<String> status,
  Value<String> transcript,
  Value<String?> rawTranscript,
  Value<String?> evidence,
  Value<String?> audioPath,
  Value<Uint8List?> embedding,
  Value<bool> confirmed,
});

class $$MemoriesTableFilterComposer
    extends Composer<_$AppDatabase, $MemoriesTable> {
  $$MemoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get person => $composableBuilder(
    column: $table.person,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get item => $composableBuilder(
    column: $table.item,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueDateText => $composableBuilder(
    column: $table.dueDateText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawTranscript => $composableBuilder(
    column: $table.rawTranscript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidence => $composableBuilder(
    column: $table.evidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get confirmed => $composableBuilder(
    column: $table.confirmed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoriesTable> {
  $$MemoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get person => $composableBuilder(
    column: $table.person,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get item => $composableBuilder(
    column: $table.item,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueDateText => $composableBuilder(
    column: $table.dueDateText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawTranscript => $composableBuilder(
    column: $table.rawTranscript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidence => $composableBuilder(
    column: $table.evidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get confirmed => $composableBuilder(
    column: $table.confirmed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoriesTable> {
  $$MemoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get person =>
      $composableBuilder(column: $table.person, builder: (column) => column);

  GeneratedColumn<String> get item =>
      $composableBuilder(column: $table.item, builder: (column) => column);

  GeneratedColumn<String> get place =>
      $composableBuilder(column: $table.place, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get dueDateText => $composableBuilder(
    column: $table.dueDateText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawTranscript => $composableBuilder(
    column: $table.rawTranscript,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidence =>
      $composableBuilder(column: $table.evidence, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<bool> get confirmed =>
      $composableBuilder(column: $table.confirmed, builder: (column) => column);
}

class $$MemoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoriesTable,
          StoredMemory,
          $$MemoriesTableFilterComposer,
          $$MemoriesTableOrderingComposer,
          $$MemoriesTableAnnotationComposer,
          $$MemoriesTableCreateCompanionBuilder,
          $$MemoriesTableUpdateCompanionBuilder,
          (
            StoredMemory,
            BaseReferences<_$AppDatabase, $MemoriesTable, StoredMemory>,
          ),
          StoredMemory,
          PrefetchHooks Function()
        > {
  $$MemoriesTableTableManager(_$AppDatabase db, $MemoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> person = const Value.absent(),
                Value<String?> item = const Value.absent(),
                Value<String?> place = const Value.absent(),
                Value<double?> amount = const Value.absent(),
                Value<String?> dueDateText = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> transcript = const Value.absent(),
                Value<String?> rawTranscript = const Value.absent(),
                Value<String?> evidence = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<Uint8List?> embedding = const Value.absent(),
                Value<bool> confirmed = const Value.absent(),
              }) => MemoriesCompanion(
                id: id,
                uid: uid,
                createdAt: createdAt,
                updatedAt: updatedAt,
                kind: kind,
                person: person,
                item: item,
                place: place,
                amount: amount,
                dueDateText: dueDateText,
                status: status,
                transcript: transcript,
                rawTranscript: rawTranscript,
                evidence: evidence,
                audioPath: audioPath,
                embedding: embedding,
                confirmed: confirmed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uid,
                required String createdAt,
                required String updatedAt,
                required String kind,
                Value<String?> person = const Value.absent(),
                Value<String?> item = const Value.absent(),
                Value<String?> place = const Value.absent(),
                Value<double?> amount = const Value.absent(),
                Value<String?> dueDateText = const Value.absent(),
                Value<String> status = const Value.absent(),
                required String transcript,
                Value<String?> rawTranscript = const Value.absent(),
                Value<String?> evidence = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<Uint8List?> embedding = const Value.absent(),
                Value<bool> confirmed = const Value.absent(),
              }) => MemoriesCompanion.insert(
                id: id,
                uid: uid,
                createdAt: createdAt,
                updatedAt: updatedAt,
                kind: kind,
                person: person,
                item: item,
                place: place,
                amount: amount,
                dueDateText: dueDateText,
                status: status,
                transcript: transcript,
                rawTranscript: rawTranscript,
                evidence: evidence,
                audioPath: audioPath,
                embedding: embedding,
                confirmed: confirmed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MemoriesTable, StoredMemory>(table),
                  BaseReferences<_$AppDatabase, $MemoriesTable, StoredMemory>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoriesTable,
      StoredMemory,
      $$MemoriesTableFilterComposer,
      $$MemoriesTableOrderingComposer,
      $$MemoriesTableAnnotationComposer,
      $$MemoriesTableCreateCompanionBuilder,
      $$MemoriesTableUpdateCompanionBuilder,
      (
        StoredMemory,
        BaseReferences<_$AppDatabase, $MemoriesTable, StoredMemory>,
      ),
      StoredMemory,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MemoriesTableTableManager get memories =>
      $$MemoriesTableTableManager(_db, _db.memories);
}
