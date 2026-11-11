import 'dart:io';

import 'package:flutter_agentify_core/doctor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'temp_repo.dart';

void main() {
  const valid = {
    'AGENTS.md': '# Agents\n',
    'CLAUDE.md': '@AGENTS.md\n',
    'GEMINI.md': '@AGENTS.md\n',
    '.agents/skills/.gitkeep': '',
  };

  Future<Directory> repo(
    Map<String, String> files, {
    bool link = true,
    String linkTarget = '../.agents/skills',
  }) async {
    final root = await tempRepo(files);
    if (link) {
      await Directory(p.join(root.path, '.claude')).create();
      await Link(p.join(root.path, '.claude', 'skills')).create(linkTarget);
    }
    return root;
  }

  Future<CheckResult> check(Directory root) =>
      AgentFilesCheck().run(DoctorContext(root: root));

  test(
    'passes with AGENTS.md, both imports and a resolving skills link',
    () async {
      final result = await check(await repo(valid));
      expect(result.messages, isEmpty);
      expect(result.status, CheckStatus.pass);
    },
  );

  test('fails when AGENTS.md is longer than 6000 characters', () async {
    final result = await check(await repo({...valid, 'AGENTS.md': 'a' * 6001}));
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('6000'));
  });

  test('fails when AGENTS.md is missing', () async {
    final result = await check(await repo({...valid}..remove('AGENTS.md')));
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('AGENTS.md'));
  });

  test('fails when CLAUDE.md is not exactly "@AGENTS.md"', () async {
    final result = await check(
      await repo({...valid, 'CLAUDE.md': '@AGENTS.md\nmore\n'}),
    );
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('CLAUDE.md'));
  });

  test('fails when GEMINI.md is missing', () async {
    final result = await check(await repo({...valid}..remove('GEMINI.md')));
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('GEMINI.md'));
  });

  test(
    'fails with the Windows fix when .claude/skills is a plain file',
    () async {
      final result = await check(
        await repo({
          ...valid,
          '.claude/skills': '../.agents/skills',
        }, link: false),
      );
      expect(result.status, CheckStatus.fail);
      expect(
        result.messages.join('\n'),
        contains('git config core.symlinks true'),
      );
    },
  );

  test('fails when .claude/skills points somewhere else', () async {
    final result = await check(
      await repo({
        ...valid,
        'elsewhere/.gitkeep': '',
      }, linkTarget: '../elsewhere'),
    );
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('.claude/skills'));
  });
}
