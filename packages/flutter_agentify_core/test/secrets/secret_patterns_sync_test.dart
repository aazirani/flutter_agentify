import 'dart:io';

import 'package:flutter_agentify_core/src/secrets/secret_patterns.dart';
import 'package:test/test.dart';

void main() {
  test('the lint rule has the same patterns', () {
    final source = File(
      '../flutter_agentify_lints/lib/src/rules/no_secret_literals.dart',
    ).readAsStringSync();
    final inLints = [
      for (final m in RegExp(r"RegExp\(\s*r'(.+)',?\s*\)").allMatches(source))
        m.group(1),
    ];
    expect(inLints, [for (final p in secretPatterns) p.pattern]);
  });
}
