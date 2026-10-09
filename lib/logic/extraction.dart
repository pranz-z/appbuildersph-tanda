import 'dart:convert';

/// Schema from TANDA_SPEC.md section 8.1, checked in plain Dart. The grammar
/// should guarantee this; we still verify.
const extractionKinds = {'lent_item', 'lent_money', 'item_location', 'promise'};
const extractionFields = [
  'kind',
  'person',
  'item',
  'place',
  'amount',
  'due_date_text',
  'evidence',
  'uncertain_fields',
];

class ExtractionParse {
  const ExtractionParse(this.json, this.errors);

  final Map<String, dynamic>? json;
  final List<String> errors;

  bool get valid => json != null && errors.isEmpty;
}

String buildExtractPrompt(String template, String transcript) =>
    template.replaceAll('{{TRANSCRIPT}}', transcript.trim());

ExtractionParse parseExtraction(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw.trim());
  } on FormatException catch (e) {
    return ExtractionParse(null, ['not JSON: ${e.message}']);
  }
  if (decoded is! Map<String, dynamic>) {
    return const ExtractionParse(null, ['not a JSON object']);
  }
  return ExtractionParse(decoded, validateExtraction(decoded));
}

List<String> validateExtraction(Map<String, dynamic> j) {
  final errors = <String>[];
  for (final k in extractionFields) {
    if (!j.containsKey(k)) errors.add('missing "$k"');
  }
  for (final k in j.keys) {
    if (!extractionFields.contains(k)) errors.add('unexpected "$k"');
  }
  if (!extractionKinds.contains(j['kind'])) {
    errors.add('kind must be one of $extractionKinds');
  }
  for (final k in ['person', 'item', 'place', 'due_date_text']) {
    if (j[k] != null && j[k] is! String) errors.add('$k must be string|null');
  }
  if (j['amount'] != null && j['amount'] is! num) {
    errors.add('amount must be number|null');
  }
  if (j['evidence'] is! String) errors.add('evidence must be string');
  final uf = j['uncertain_fields'];
  if (uf is! List || uf.any((e) => e is! String)) {
    errors.add('uncertain_fields must be array of strings');
  }
  return errors;
}

/// Spec 8.1: evidence must be a substring of the transcript (case-insensitive,
/// whitespace-normalized). If not, the card is low-confidence.
bool evidenceInTranscript(String? evidence, String transcript) {
  if (evidence == null || evidence.trim().isEmpty) return false;
  String norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  return norm(transcript).contains(norm(evidence));
}
