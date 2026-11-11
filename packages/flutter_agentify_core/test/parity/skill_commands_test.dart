import 'package:flutter_agentify_core/parity.dart';
import 'package:test/test.dart';

import '../doctor/temp_repo.dart';

void main() {
  test('an unregistered action in a command is a problem', () async {
    final root = await tempRepo({
      'AGENTS.md': '```bash\ndart run tool/action.dart make_tea \'{}\'\n```',
    });
    expect(
      skillCommandProblems(actionNames: {'set_language'}, root: root.path),
      [contains('make_tea')],
    );
  });
  test('flags and placeholders are not action names', () async {
    final root = await tempRepo({
      'AGENTS.md':
          '`flutter test test/actions/<action_name>_test.dart`\n'
          'dart run tool/action.dart --list\n'
          "dart run tool/action.dart <action_name> '<json>' --approved",
    });
    expect(skillCommandProblems(actionNames: {}, root: root.path), isEmpty);
  });
  test('prose on the next line is not a test path', () async {
    final root = await tempRepo({
      'AGENTS.md':
          'Run all tests:\n\n    flutter test\n\nthen read the output.\n'
          '    flutter test test/ok_test.dart\nIt should pass.\n',
      'test/ok_test.dart': '',
    });
    expect(skillCommandProblems(actionNames: {}, root: root.path), isEmpty);
  });
  test(
    'flutter test on a missing file or under .agents/example is a problem',
    () async {
      final root = await tempRepo({
        '.agents/skills/testing/SKILL.md':
            '`flutter test test/gone_test.dart`\n'
            '`flutter test .agents/example/test/a_test.dart test/ok_test.dart`',
        '.agents/example/test/a_test.dart': '',
        'test/ok_test.dart': '',
      });
      final problems = skillCommandProblems(actionNames: {}, root: root.path);
      expect(problems, hasLength(2));
      expect(
        problems.join('\n'),
        allOf(contains('gone_test'), contains('.agents/example')),
      );
    },
  );
}
