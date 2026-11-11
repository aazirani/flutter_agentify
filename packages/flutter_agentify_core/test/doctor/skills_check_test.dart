import 'package:flutter_agentify_core/doctor.dart';
import 'package:test/test.dart';

import 'temp_repo.dart';

const _valid =
    '---\nname: verify\ndescription: Runs the gate. Use when finishing work.\n'
    '---\n# Verify\n';

Future<CheckResult> _check(Map<String, String> files) async =>
    SkillsCheck().run(DoctorContext(root: await tempRepo(files)));

String _skill(String body, {String name = 'verify'}) =>
    '---\nname: $name\ndescription: Does it. Use when needed.\n---\n$body';

void main() {
  test('passes with no skills', () async {
    expect((await _check({})).status, CheckStatus.pass);
  });

  test('ignores plain files such as .gitkeep in the skills folder', () async {
    final result = await _check({'.agents/skills/.gitkeep': ''});
    expect(result.status, CheckStatus.pass);
  });

  test('passes with a valid skill', () async {
    final result = await _check({'.agents/skills/verify/SKILL.md': _valid});
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });

  test('fails when SKILL.md is missing in a skill folder', () async {
    final result = await _check({'.agents/skills/verify/notes.md': 'x'});
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('verify/SKILL.md'));
  });

  test('fails when frontmatter has no closing ---', () async {
    final result = await _check({
      '.agents/skills/verify/SKILL.md': '---\nname: verify\n# Verify\n',
    });
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('verify/SKILL.md'));
  });

  test('fails when frontmatter is not a YAML map', () async {
    final result = await _check({
      '.agents/skills/verify/SKILL.md': '---\n- a\n- b\n---\n# Verify\n',
    });
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('verify/SKILL.md'));
  });

  test('fails when name differs from the folder name', () async {
    final result = await _check({
      '.agents/skills/verify/SKILL.md': _skill('# V\n', name: 'check'),
    });
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('name'));
  });

  test('fails when description lacks "Use when"', () async {
    final result = await _check({
      '.agents/skills/verify/SKILL.md':
          '---\nname: verify\ndescription: Runs the gate.\n---\n# V\n',
    });
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('Use when'));
  });

  test('fails when SKILL.md is longer than 6000 characters', () async {
    final result = await _check({
      '.agents/skills/verify/SKILL.md': _skill('a' * 6000),
    });
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('6000'));
  });

  test(
    'fails when a Related skills entry names a skill that does not exist',
    () async {
      final result = await _check({
        '.agents/skills/verify/SKILL.md': _skill(
          '## Related skills\n\n- `testing`: how to write tests\n',
        ),
      });
      expect(result.status, CheckStatus.fail);
      expect(result.messages.join('\n'), contains('testing'));
    },
  );

  test('passes when a Related skills entry names an existing skill', () async {
    final result = await _check({
      '.agents/skills/verify/SKILL.md': _skill(
        '## Related skills\n\n- `testing`: how to write tests\n',
      ),
      '.agents/skills/testing/SKILL.md': _skill('# T\n', name: 'testing'),
    });
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });

  test('fails when a backticked repo path does not exist', () async {
    final result = await _check({
      '.agents/skills/verify/SKILL.md': _skill('See `lib/missing.dart`.\n'),
    });
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('lib/missing.dart'));
  });

  test('passes when a backticked repo path exists', () async {
    final result = await _check({
      '.agents/skills/verify/SKILL.md': _skill(
        'See `lib/main.dart:12` and `tool/`.\n',
      ),
      'lib/main.dart': 'void main() {}\n',
      'tool/check.sh': '',
    });
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });

  test(
    'skips placeholder paths such as `test/actions/<name>_test.dart`',
    () async {
      final result = await _check({
        '.agents/skills/verify/SKILL.md': _skill(
          'Write `test/actions/<name>_test.dart` and `lib/**/*.dart` and '
          '`lib/…`.\n',
        ),
      });
      expect(result.messages, isEmpty);
      expect(result.status, CheckStatus.pass);
    },
  );
}
