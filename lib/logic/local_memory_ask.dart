import '../core/app_database.dart';

enum AskResultKind { answer, ambiguous, notFound }

class LocalMemoryAskResult {
  const LocalMemoryAskResult({
    required this.kind,
    required this.answer,
    this.matches = const [],
    this.verbatim = false,
  });

  final AskResultKind kind;
  final String answer;
  final List<StoredMemory> matches;

  /// True when [answer] is final text to show as-is rather than a typed
  /// template input — used when a memory's own kind label disagreed with
  /// the question (quote the record, don't assert a wrong kind) and when
  /// the answer came from validated grounded generation.
  final bool verbatim;
}

/// Exact, local matching for confirmed memories. No model or network calls.
class LocalMemoryAsk {
  LocalMemoryAskResult answer(String question, List<StoredMemory> memories) {
    final terms = _questionTerms(question);
    final intent = _kindIntent(question);
    if (terms.isEmpty && intent == null) return _notFound;

    final confirmed = memories.where((row) => row.confirmed);
    var ranked = _rank(confirmed, terms, intent);
    // Extraction can mislabel kind or leave fields empty. When the kind
    // filter empties the pool, retry without it — grounding in the stored
    // transcript/evidence terms still applies, so unrelated rows score 0.
    // Without question terms there is nothing to ground on; stay not-found.
    final fromKindFallback = ranked.isEmpty && intent != null && terms.isNotEmpty;
    if (fromKindFallback) ranked = _rank(confirmed, terms, null);
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
    // The stored kind disagrees with the question: quote the record instead
    // of asserting a wrong kind in the sentence.
    if (fromKindFallback && match.kind != intent) {
      return LocalMemoryAskResult(
        kind: AskResultKind.answer,
        answer: 'May katugmang tala: "${match.transcript}"',
        matches: [match],
        verbatim: true,
      );
    }
    return LocalMemoryAskResult(
      kind: AskResultKind.answer,
      answer: _buildAnswer(match),
      matches: [match],
    );
  }

  List<({StoredMemory memory, int score})> _rank(
    Iterable<StoredMemory> memories,
    Set<String> terms,
    String? intent,
  ) {
    final ranked = <({StoredMemory memory, int score})>[];
    for (final memory in memories) {
      if (intent != null && memory.kind != intent) continue;
      final score = terms.isEmpty ? 1 : _score(memory, terms);
      if (score > 0) ranked.add((memory: memory, score: score));
    }
    return ranked;
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
    'alin',
    'ilan',
    'kailan',
    'paano',
    'and',
    'are',
    'did',
    'does',
    'do',
    'for',
    'had',
    'has',
    'have',
    'its',
    'was',
    'were',
    'will',
    'would',
  };

  /// Canonical word forms so different wordings of the same fact still meet.
  /// Tagalog verb families collapse to their root idea; English borrow/lend,
  /// owe/pay, return, keep/place and promise words join their Tagalog
  /// equivalents so a question in one language finds a memory in the other.
  static const _lemmas = {
    'hiram': 'hiram',
    'hiniram': 'hiram',
    'humiram': 'hiram',
    'hiramin': 'hiram',
    'hinihiram': 'hiram',
    'hihiram': 'hiram',
    'nanghiram': 'hiram',
    'manghiram': 'hiram',
    'pahiram': 'hiram',
    'pinahiram': 'hiram',
    'nagpahiram': 'hiram',
    'ipahiram': 'hiram',
    'pahiramin': 'hiram',
    'borrow': 'hiram',
    'borrowed': 'hiram',
    'borrowing': 'hiram',
    'borrows': 'hiram',
    'lend': 'hiram',
    'lends': 'hiram',
    'lent': 'hiram',
    'utang': 'utang',
    'umutang': 'utang',
    'inutang': 'utang',
    'pinautang': 'utang',
    'nagpautang': 'utang',
    'nangutang': 'utang',
    'iutang': 'utang',
    'owe': 'utang',
    'owes': 'utang',
    'owed': 'utang',
    'owing': 'utang',
    'debt': 'utang',
    'loan': 'utang',
    'loans': 'utang',
    'pera': 'utang',
    'piso': 'utang',
    'peso': 'utang',
    'pesos': 'utang',
    'money': 'utang',
    'magkano': 'utang',
    'bayad': 'utang',
    'bayaran': 'utang',
    'babayaran': 'utang',
    'binayaran': 'utang',
    'nagbayad': 'utang',
    'magbayad': 'utang',
    'babayad': 'utang',
    'pay': 'utang',
    'pays': 'utang',
    'paid': 'utang',
    'paying': 'utang',
    'payment': 'utang',
    'soli': 'soli',
    'isoli': 'soli',
    'isosoli': 'soli',
    'isusoli': 'soli',
    'isinoli': 'soli',
    'sosoli': 'soli',
    'ibalik': 'soli',
    'ibabalik': 'soli',
    'ibinabalik': 'soli',
    'binalik': 'soli',
    'ibinalik': 'soli',
    'nagbalik': 'soli',
    'nagbabalik': 'soli',
    'magbabalik': 'soli',
    'return': 'soli',
    'returns': 'soli',
    'returned': 'soli',
    'returning': 'soli',
    'lagay': 'lagay',
    'nilagay': 'lagay',
    'inilagay': 'lagay',
    'nakalagay': 'lagay',
    'nilalagay': 'lagay',
    'naglagay': 'lagay',
    'ilalagay': 'lagay',
    'itinago': 'lagay',
    'tinago': 'lagay',
    'nasa': 'lagay',
    'nasaan': 'lagay',
    'saan': 'lagay',
    'naroroon': 'lagay',
    'kept': 'lagay',
    'stored': 'lagay',
    'location': 'lagay',
    'located': 'lagay',
    'placed': 'lagay',
    'left': 'lagay',
    'put': 'lagay',
    'puts': 'lagay',
    'putting': 'lagay',
    'pangako': 'pangako',
    'nangako': 'pangako',
    'ipinangako': 'pangako',
    'pinangako': 'pangako',
    'nagpangako': 'pangako',
    'pangakuan': 'pangako',
    'promise': 'pangako',
    'promises': 'pangako',
    'promised': 'pangako',
    'promising': 'pangako',
    'hawak': 'hawak',
    'nahawakan': 'hawak',
    'hinahawakan': 'hawak',
    'tulong': 'tulong',
    'tutulong': 'tulong',
    'tutulungan': 'tulong',
    'tinulungan': 'tulong',
    'help': 'tulong',
  };

  /// Maps a surface word to its canonical form: direct lemma table first,
  /// then a light English suffix strip, re-checked against the table.
  static String _canonical(String token) {
    final direct = _lemmas[token];
    if (direct != null) return direct;
    var stem = token;
    if (stem.length > 5 && stem.endsWith('ing')) {
      stem = stem.substring(0, stem.length - 3);
    } else if (stem.length > 4 && stem.endsWith('ed')) {
      stem = stem.substring(0, stem.length - 2);
    } else if (stem.length > 4 && stem.endsWith('es')) {
      stem = stem.substring(0, stem.length - 2);
    } else if (stem.length > 4 && stem.endsWith('s')) {
      stem = stem.substring(0, stem.length - 1);
    }
    return _lemmas[stem] ?? stem;
  }

  /// Content terms of the question, canonicalized. The ignored-word check
  /// stays on the raw term so unlisted inflections (e.g. "borrowed") still
  /// contribute evidence while their intent is handled by [_kindIntent].
  Set<String> _questionTerms(String question) {
    return _normalize(question)
        .split(' ')
        .where((term) => term.length > 1 && !_ignoredTerms.contains(term))
        .map(_canonical)
        .toSet();
  }

  /// Intent detection over canonical forms: Tagalog inflections and English
  /// equivalents resolve to the same key, so wording does not matter.
  /// Priority order: money > location > promise > borrowed item.
  String? _kindIntent(String question) {
    final words = _normalize(question).split(' ').map(_canonical).toSet();
    if (words.contains('utang')) return 'lent_money';
    if (words.contains('lagay') || words.contains('where')) {
      return 'item_location';
    }
    if (words.contains('pangako')) return 'promise';
    if (words.contains('hiram') ||
        words.contains('hawak') ||
        words.contains('soli')) {
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

  /// Tokens in canonical form so "borrowed" meets "borrow"/"hiram" and a
  /// trailing period in the stored transcript ("shovel.") cannot break a match.
  static Set<String> _tokens(String value) => _normalize(value)
      .split(' ')
      .where((token) => token.isNotEmpty)
      .map(_canonical)
      .toSet();

  /// Canonical content tokens of any text — shared with the grounded answer
  /// validator so a claim is checked in the same space retrieval uses.
  static Set<String> contentTokens(String value) => _tokens(value);

  /// True for question/function words that never carry a factual claim —
  /// used to skip them when checking that a generated answer is grounded.
  static bool isFillerWord(String token) => _ignoredTerms.contains(token);

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
