import 'dart:math';
import 'dart:typed_data';

/// Text embeddings. Real implementation will run multilingual-e5-small (ONNX)
/// in an isolate. e5 needs "query: " / "passage: " prefixes, added here so
/// callers can't forget them.
abstract interface class EmbeddingService {
  int get dimension;

  Future<void> init();

  Future<Float32List> embedQuery(String text);

  Future<Float32List> embedPassage(String text);

  Future<void> dispose();
}

/// Deterministic fake: same text -> same unit vector. Not semantic.
class FakeEmbeddingService implements EmbeddingService {
  @override
  int get dimension => 384;

  @override
  Future<void> init() async {}

  @override
  Future<Float32List> embedQuery(String text) async => _vec('query: $text');

  @override
  Future<Float32List> embedPassage(String text) async => _vec('passage: $text');

  Float32List _vec(String text) {
    final rnd = Random(text.hashCode);
    final v = Float32List(dimension);
    var norm = 0.0;
    for (var i = 0; i < dimension; i++) {
      v[i] = rnd.nextDouble() * 2 - 1;
      norm += v[i] * v[i];
    }
    norm = sqrt(norm);
    for (var i = 0; i < dimension; i++) {
      v[i] /= norm;
    }
    return v;
  }

  @override
  Future<void> dispose() async {}
}
