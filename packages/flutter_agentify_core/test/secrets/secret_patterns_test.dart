import 'package:flutter_agentify_core/src/secrets/secret_patterns.dart';
import 'package:test/test.dart';

// Every sample is built from pieces so no full key sits in this file.
void main() {
  test('matches each key family', () {
    final samples = [
      'sk-' + 'a' * 30,
      'AIza' + 'b' * 35,
      'ghp_' + 'c' * 36,
      'xoxb-' + 'd' * 12,
      '-----BEGIN RSA ' + 'PRIVATE KEY-----',
      'gsk_' + 'e' * 30,
      'hf_' + 'f' * 34,
      'xai-' + 'g' * 60,
      'eyJ' + 'h' * 12 + '.eyJ' + 'i' * 12 + '.' + 'j' * 12,
      'Bearer ' + 'abc123' * 5,
      'sk_' + 'test_' + 'k' * 24,
      'rk_' + 'live_' + 'l' * 24,
    ];
    for (final sample in samples) {
      expect(looksLikeSecret('key: $sample'), isTrue, reason: sample);
      expect(looksLikeSecret('key=$sample'), isTrue, reason: sample);
      expect(looksLikeSecret(sample), isTrue, reason: sample);
    }
    expect(secretPatterns, hasLength(13));
    expect(() => secretPatterns.clear(), throwsUnsupportedError);
  });

  test('ignores ordinary text', () {
    expect(looksLikeSecret('sk-short'), isFalse);
    expect(looksLikeSecret('task-list'), isFalse);
    expect(looksLikeSecret('risk-' + 'assessment-' * 3), isFalse);
    expect(looksLikeSecret('half_' + 'x' * 40), isFalse);
    expect(looksLikeSecret('hf_short'), isFalse);
    expect(looksLikeSecret('gsk_short'), isFalse);
    expect(looksLikeSecret('xai-short'), isFalse);
    expect(looksLikeSecret('eyJ.eyJ.x'), isFalse);
    expect(looksLikeSecret('Bearer authentication'), isFalse);
    expect(looksLikeSecret('Bearer ' + 'a' * 30), isFalse);
    expect(looksLikeSecret('123e4567-e89b-12d3-a456-426614174000'), isFalse);
  });
}
