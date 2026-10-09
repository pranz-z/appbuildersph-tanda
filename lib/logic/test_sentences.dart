/// Reads the sentence table from test_sentences.md: rows like
/// `| 1 | Hiniram ni Kuya Jun ... | ... |`. Stops at the first table.
List<String> parseTestSentences(String markdown) {
  final out = <String>[];
  final row = RegExp(r'^\|\s*(\d+)\s*\|\s*([^|]+?)\s*\|');
  for (final line in markdown.split('\n')) {
    final m = row.firstMatch(line.trim());
    if (m == null) {
      if (out.isNotEmpty && !line.trim().startsWith('|')) break;
      continue;
    }
    out.add(m.group(2)!);
  }
  return out;
}
