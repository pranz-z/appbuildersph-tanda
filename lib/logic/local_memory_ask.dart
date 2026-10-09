import '../core/app_database.dart';

enum AskResultKind { answer, ambiguous, notFound }

class LocalMemoryAskResult {
  const LocalMemoryAskResult({
    required this.kind,
    required this.answer,
    this.matches = const [],
  });

  final AskResultKind kind;
  final String answer;
  final List<StoredMemory> matches;
}

/// Exact, local matching for confirmed memories. No model or network calls.
class LocalMemoryAsk {
  LocalMemoryAskResult answer(String question, List<StoredMemory> memories) {
    final terms = _questionTerms(question);
    final intent = _kindIntent(question);
    if (terms.isEmpty && intent == null) return _notFound;

    final ranked = <({StoredMemory memory, int score})>[];
    for (final memory in memories.where((row) => row.confirmed)) {
      if (intent != null && memory.kind != intent) continue;
      final score = terms.isEmpty ? 1 : _score(memory, terms);
      if (score > 0) ranked.add((memory: memory, score: score));
    }
    ranked.sort((a, b) => b.score.compareTo(a.score));
    if (ranked.isEmpty) return _notFound;

    final topScore = ranked.first.score;
    final plausible = ranked
        .takeWhile((row) => topScore - row.score <= 2)
        .map((row) => row.memory)
        .toList(growable: false);
    if (plausible.length > 1) {
      return LocalMemoryAskResult(
        kind: AskResultKind.ambiguous,
        answer: 'May ilang posibleng tugma. Piliin ang tinutukoy mo:',
        matches: plausible,
      );
    }

    final match = ranked.first.memory;
    return LocalMemoryAskResult(
      kind: AskResultKind.answer,
      answer: _buildAnswer(match),
      matches: [match],
    );
  }

  static const _notFound = LocalMemoryAskResult(
    kind: AskResultKind.notFound,
    answer: 'Wala akong nahanap.',
  );

  LocalMemoryAskResult answerFor(StoredMemory memory) => LocalMemoryAskResult(
    kind: AskResultKind.answer,
    answer: _buildAnswer(memory),
    matches: [memory],
  );

  static const _ignoredTerms = {
    'ako',
    'akin',
    'ang',
    'ano',
    'ba',
    'bakit',
    'daw',
    'din',
    'doon',
    'from',
    'ate',
    'hindi',
    'how',
    'i',
    'is',
    'it',
    'ko',
    'kuya',
    'may',
    'me',
    'mo',
    'ng',
    'my',
    'na',
    'ni',
    'nina',
    'noong',
    'o',
    'of',
    'on',
    'or',
    'para',
    'please',
    'po',
    'sa',
    'si',
    'sila',
    'sino',
    'the',
    'this',
    'to',
    'tungkol',
    'what',
    'when',
    'where',
    'who',
    'with',
    'yung',
    'hiram',
    'hiniram',
    'humiram',
    'hiramin',
    'hiramnya',
    'pahiram',
    'nagpahiram',
    'utang',
    'umutang',
    'pinautang',
    'magkano',
    'pera',
    'pesos',
    'piso',
    'nasaan',
    'saan',
    'nilagay',
    'inilagay',
    'lagay',
    'nangako',
    'pangako',
    'promise',
    'promised',
    'hawak',
    'ibalik',
    'ibabalik',
    'isosoli',
    'soli',
    'return',
    'borrow',
    'owe',
    'owes',
    'location',
    'located',
    'kanino',
    'kay',
    'niya',
    'raw',
    'dapat',
    'meron',
    'mayroon',
    'nasa',
  };

  Set<String> _questionTerms(String question) {
    final normalized = _normalize(question);
    return normalized
        .split(' ')
        .where((term) => term.length > 1 && !_ignoredTerms.contains(term))
        .toSet();
  }

  String? _kindIntent(String question) {
    final normalized = ' ${_normalize(question)} ';
    bool hasAny(Iterable<String> words) =>
        words.any((word) => normalized.contains(' $word '));
    if (hasAny(['utang', 'umutang', 'pinautang', 'pera', 'magkano', 'owe'])) {
      return 'lent_money';
    }
    if (hasAny([
      'nasaan',
      'saan',
      'nilagay',
      'inilagay',
      'location',
      'where',
    ])) {
      return 'item_location';
    }
    if (hasAny(['pangako', 'nangako', 'promise', 'promised'])) return 'promise';
    if (hasAny([
      'hiram',
      'hiniram',
      'humiram',
      'hiramin',
      'pahiram',
      'nagpahiram',
      'hawak',
      'ibalik',
      'ibabalik',
      'isosoli',
      'soli',
      'borrow',
      'borrowed',
    ])) {
      return 'lent_item';
    }
    return null;
  }

  int _score(StoredMemory memory, Set<String> terms) {
    final structured = [
      memory.person,
      memory.item,
      memory.place,
      memory.dueDateText,
      memory.amount == null ? null : _amount(memory.amount!),
    ].whereType<String>().map(_tokens).toList();
    if (memory.amount != null) {
      structured.add(_tokens(memory.amount.toString()));
      if (memory.amount == memory.amount!.roundToDouble()) {
        structured.add(_tokens(memory.amount!.toStringAsFixed(0)));
      }
    }
    final evidence = _tokens(memory.evidence ?? '');
    final transcript = _tokens(memory.transcript);
    var score = 0;
    var structuredHits = 0;
    var textHits = 0;
    for (final term in terms) {
      if (structured.any((field) => field.contains(term))) {
        score += 4;
        structuredHits++;
      } else if (evidence.contains(term)) {
        score += 2;
        textHits++;
      } else if (transcript.contains(term)) {
        score += 1;
        textHits++;
      }
    }
    // A lone incidental transcript word is too weak to ground an answer.
    if (structuredHits == 0 && textHits < 2) return 0;
    return score;
  }

  String _buildAnswer(StoredMemory memory) {
    final person = memory.person?.trim();
    final item = memory.item?.trim();
    final place = memory.place?.trim();
    final due = memory.dueDateText?.trim();
    final String answer;
    switch (memory.kind) {
      case 'item_location':
        answer =
            item != null && item.isNotEmpty && place != null && place.isNotEmpty
            ? 'Ang $item ay nasa $place.'
            : 'May naitalang lokasyon para sa ${item?.isNotEmpty == true ? item : 'bagay na ito'}.';
      case 'lent_item':
        final borrowed = item?.isNotEmpty == true ? item : 'bagay na ito';
        answer = person?.isNotEmpty == true
            ? 'Naitala na si $person ang humiram ng $borrowed.'
            : 'Naitala ang hiram na $borrowed.';
      case 'lent_money':
        final amount = memory.amount == null ? null : _amount(memory.amount!);
        answer = amount != null && person?.isNotEmpty == true
            ? 'Naitala na may utang si $person na ₱$amount.'
            : amount != null
            ? 'Naitala ang utang na ₱$amount.'
            : 'May naitalang utang.';
      case 'promise':
        answer = item?.isNotEmpty == true && person?.isNotEmpty == true
            ? 'Naitalang pangako ni $person: $item.'
            : item?.isNotEmpty == true
            ? 'Naitalang pangako: $item.'
            : 'May naitalang pangako.';
      default:
        return 'Wala akong nahanap.';
    }
    return due == null || due.isEmpty ? answer : '$answer Naitala: $due.';
  }

  String _amount(double amount) {
    final raw = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
    final parts = raw.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return parts.length == 1 ? whole : '$whole.${parts.last}';
  }

  Set<String> _tokens(String value) =>
      _normalize(value).split(' ').where((token) => token.isNotEmpty).toSet();

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9.]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
