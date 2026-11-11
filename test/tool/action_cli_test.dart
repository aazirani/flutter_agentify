@Tags(['cli'])
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cli.dart';

void main() {
  test('set_language runs and prints a receipt', () async {
    final locale = kSupportedLanguages.first.locale;
    final result = await runCli(['set_language', '{"locale":"$locale"}']);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, contains('receipt:'));
  });

  test('delete_memory without --approved exits 1', () async {
    final result = await runCli(['delete_memory', '{"id":"nope"}']);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('approval_required'));
  });

  test('--list names the app actions and the built-ins', () async {
    final result = await runCli(['--list']);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final names = (result.stdout as String).trim().split('\n');
    expect(
      names,
      containsAll([
        'set_theme_mode',
        'set_language',
        'set_assistant_provider',
        'set_api_key',
        'view_screen',
        'navigate',
        'save_memory',
        'delete_memory',
      ]),
    );
  });
}
