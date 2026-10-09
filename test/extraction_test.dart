import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tanda/logic/extraction.dart';
import 'package:tanda/logic/test_sentences.dart';

void main() {
  const good =
      '{"kind":"lent_money","person":"Ate Mary","item":null,"place":null,'
      '"amount":500,"due_date_text":"sa Biyernes",'
      '"evidence":"Nagpautang ako kay Ate Mary ng limang daan",'
      '"uncertain_fields":["amount"]}';

  test('valid output passes schema', () {
    final p = parseExtraction(good);
    expect(p.valid, isTrue, reason: '${p.errors}');
    expect(p.json!['amount'], 500);
  });

  test('schema violations are reported', () {
    expect(parseExtraction('{"kind":"x"').valid, isFalse);
    expect(parseExtraction('[]').valid, isFalse);
    final p = parseExtraction(
      good.replaceFirst('"lent_money"', '"gift"').replaceFirst('500', '"500"'),
    );
    expect(p.errors, contains(startsWith('kind must be')));
    expect(p.errors, contains('amount must be number|null'));
  });

  test('evidence substring check is case/whitespace tolerant', () {
    const t = 'Nagpautang ako kay Ate Mary ng  limang daan, babayaran.';
    expect(evidenceInTranscript('ate mary ng limang daan', t), isTrue);
    expect(evidenceInTranscript('Kuya Jun', t), isFalse);
    expect(evidenceInTranscript(null, t), isFalse);
  });

  test('prompt template has the placeholder and 3 few-shot examples', () {
    final tpl = File('assets/extract_prompt.txt').readAsStringSync();
    expect(tpl, contains('{{TRANSCRIPT}}'));
    expect('<|im_start|>assistant'.allMatches(tpl).length, 4);
    // Few-shot answers must themselves satisfy the schema.
    final answers = RegExp(r'^\{".*\}', multiLine: true).allMatches(tpl);
    expect(answers.length, 3);
    for (final a in answers) {
      expect(parseExtraction(a.group(0)!).valid, isTrue, reason: a.group(0));
    }
    expect(buildExtractPrompt(tpl, ' hi '), contains('hi<|im_end|>'));
  });

  test('grammar lists all kinds and all fields in schema order', () {
    final g = File('assets/extract.gbnf').readAsStringSync();
    expect(g, contains('root ::='));
    for (final k in extractionKinds) {
      expect(g, contains('\\"$k\\"'));
    }
    final root = g.split('\n').firstWhere((l) => l.startsWith('root'));
    var last = -1;
    for (final f in extractionFields) {
      final i = root.indexOf('\\"$f\\":');
      expect(i, greaterThan(last), reason: f);
      last = i;
    }
  });

  test('parses the 15 sentences from test_sentences.md', () {
    final s = parseTestSentences(File('test_sentences.md').readAsStringSync());
    expect(s.length, 15);
    expect(s.first, startsWith('Hiniram ni Kuya Jun'));
    expect(s.last, startsWith('Pinahiram ko yung drill kay Mang Rudy'));
  });
}
