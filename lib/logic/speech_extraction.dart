const repeatSpeechMessage = 'Hindi ko maintindihan. Pakisabi ulit.';

class UnintelligibleSpeechException implements Exception {
  const UnintelligibleSpeechException();
  @override
  String toString() => repeatSpeechMessage;
}

bool isUnusableSpeech(String text) {
  final value = text.toLowerCase().trim();
  return !RegExp(r'[a-zA-Z0-9]').hasMatch(value) ||
      RegExp(
        r'\[[^\]]*\]|\([^)]*(silence|noise|music|buzzing|inaudible)[^)]*\)|\b(inaudible|unintelligible|buzzing|silence)\b',
      ).hasMatch(value) ||
      RegExp(
        r'^(thank you(?: for watching)?|salamat(?: sa panonood)?|please subscribe|music|noise|static|no speech)[.! ]*$',
      ).hasMatch(value);
}

List<String> _words(String value) =>
    RegExp(r'[-+]?\d+(?:[,.]\d+)*|[a-zà-ÿ]+')
        .allMatches(value.toLowerCase())
        .map((match) => match.group(0)!)
        .where((word) => !const {'ah', 'uh', 'um', 'uhm', 'hmm'}.contains(word))
        .map((word) => word == 'yung' ? 'ang' : word)
        .toList();

/// Deliberately permits punctuation, case and hesitation cleanup only.
/// Ordered tokens retain negation, roles, names, numbers and dates.
bool isFaithfulCleanup(String raw, String cleaned) {
  if (isUnusableSpeech(raw) || isUnusableSpeech(cleaned)) return false;
  final before = _words(raw);
  final after = _words(cleaned);
  return before.length >= 3 && before.join('|') == after.join('|');
}

bool speechFieldsGrounded(Map<String, dynamic> memory, String transcript) {
  final words = _words(transcript);
  final normalized = ' ${words.join(' ')} ';
  // A copied noun from gibberish is not sufficient evidence of a memory kind.
  final intent = switch (memory['kind']) {
    'lent_item' =>
      r'\b(hiram|hiniram|pinahiram|nanghiram|pahiram|borrow|borrowed|lent)\b',
    'lent_money' => r'\b(utang|nagpautang|pinautang|humiram|hiram|owe|owes|owed|loan|lent|lend)\b',
    'item_location' =>
      r'\b(nasa|nilagay|nakalagay|itinago|inilagay|kept|stored|left|located)\b',
    'promise' => r'\b(pangako|nangako|promise|promised|sabi|daw|will)\b',
    _ => null,
  };
  if (intent == null || !RegExp(intent).hasMatch(normalized)) return false;
  for (final key in ['person', 'item', 'place', 'due_date_text']) {
    final value = memory[key];
    if (value != null &&
        (value is! String ||
            value.trim().isEmpty ||
            const {
              'something',
              'someone',
              'bagay',
              'tao',
              'unknown',
              'unclear',
            }.contains(value.toLowerCase().trim()) ||
            !normalized.contains(' ${_words(value).join(' ')} '))) {
      return false;
    }
  }
  final amount = memory['amount'];
  if (amount != null) {
    // Numeric amounts must occur explicitly. Word-to-number conversion is
    // intentionally rejected here rather than trusting an invented amount.
    if (amount is! num ||
        !amount.isFinite ||
        amount < 0 ||
        !words.any(
          (word) => num.tryParse(word.replaceAll(',', '')) == amount,
        )) {
      return false;
    }
  }
  return [
    'person',
    'item',
    'place',
    'amount',
    'due_date_text',
  ].any((key) => memory[key] != null);
}
