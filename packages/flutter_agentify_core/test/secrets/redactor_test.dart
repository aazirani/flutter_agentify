import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:test/test.dart';

void main() {
  test('replaces each key with [redacted] and leaves other text alone', () {
    final a = 'sk-' + 'a' * 30;
    final b = 'AIza' + 'b' * 35;
    expect(
      const Redactor().redact('one $a two $b three'),
      'one [redacted] two [redacted] three',
    );
    expect(
      const Redactor().redact('task-list, risk-free'),
      'task-list, risk-free',
    );
  });

  test('redacts a whole private key', () {
    const pem =
        '-----BEGIN RSA ' +
        'PRIVATE KEY-----\nMIIEow\nAbCd\n-----END RSA ' +
        'PRIVATE KEY-----';
    expect(const Redactor().redact('a $pem b'), 'a [redacted] b');
  });

  test(
    'redacts a private key with no end line through the end of the text',
    () {
      expect(
        const Redactor().redact('x -----BEGIN ' + 'PRIVATE KEY-----\nMIIE'),
        'x [redacted]',
      );
    },
  );

  test('redacts AWS, Stripe and fine-grained GitHub keys', () {
    final keys = [
      'AKIA' + 'A' * 16,
      'sk_' + 'live_' + 'a' * 24,
      'rk_' + 'live_' + 'a' * 24,
      'github_' + 'pat_' + 'a' * 30,
    ];
    for (final key in keys) {
      expect(const Redactor().redact('k $key.'), 'k [redacted].', reason: key);
    }
  });
}
