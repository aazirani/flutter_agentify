@Tags(['template'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/upgrade.dart';
import 'template_copy.dart';

/// A project made from the template with [starter] and [model], set up and
/// committed.
Future<Directory> _project(String starter, {String model = 'server'}) async {
  final dir = await templateCopy();
  final r = await runSetup(dir, [
    '--name',
    'up_app',
    '--org',
    'com.acme',
    '--starter',
    starter,
    '--model',
    model,
  ]);
  expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
  await _commit(dir);
  return dir;
}

/// A newer copy of the framework, changed by [edit]. Its top changelog entry
/// is dated after any project made today.
Future<Directory> _framework(void Function(Directory) edit) async {
  final dir = await templateCopy();
  final changelog = File('${dir.path}/CHANGELOG.md');
  changelog.writeAsStringSync(
    changelog.readAsStringSync().replaceFirst(
      RegExp(r'^## ', multiLine: true),
      '## 2999-01-01\n\n### Added\n- Something\n\n## ',
    ),
  );
  edit(dir);
  return dir;
}

Future<void> _commit(Directory dir) async {
  await git(dir, ['add', '-A']);
  final r = await git(dir, ['commit', '-q', '-m', 'Change']);
  expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
}

Future<ProcessResult> _upgrade(Directory dir, List<String> args) => Process.run(
  'dart',
  ['tool/upgrade.dart', ...args],
  workingDirectory: dir.path,
);

/// The paths `git status` reports in [dir].
Future<List<String>> _gitStatus(Directory dir) async {
  final r = await git(dir, ['status', '--porcelain', '--untracked-files=all']);
  return [
    for (final line in (r.stdout as String).split('\n'))
      if (line.length > 3) line.substring(3),
  ];
}

void _append(Directory dir, String path, String text) {
  File('${dir.path}/$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(text, mode: FileMode.append);
}

void main() {
  test('upgradingNotes', () {
    const log =
        '## 2027-03-01\n### Upgrading\nRename foo.\n## 2027-02-01\n### Added\n- x\n'
        '## 2027-01-15\n### Upgrading\nOld step.\n### Fixed\n- y\n'
        '## 2026-12-01\n### Upgrading\nNever shown.\n';
    final notes = upgradingNotes(log, since: '2027-01-15');
    expect(
      notes,
      allOf(
        contains('Rename foo.'),
        contains('Old step.'),
        isNot(contains('Never shown')),
        isNot(contains('- y')),
      ),
    );
    expect(
      notes.indexOf('2027-03-01:'),
      lessThan(notes.indexOf('2027-01-15:')),
    );
    expect(upgradingNotes(log, since: '2027-03-02'), isEmpty);
    expect(upgradingNotes(log), contains('Never shown.'));
    // A heading that is not a date ends the entry above it.
    const other =
        '## 2027-03-01\n### Upgrading\nRename foo.\n'
        '## Unreleased\n### Upgrading\nNot yet.\n';
    expect(
      upgradingNotes(other, since: '2027-01-01'),
      allOf(contains('Rename foo.'), isNot(contains('Not yet'))),
    );
  });

  test('upgrading from the same framework changes nothing', () async {
    final project = await _project('empty');
    final r = await _upgrade(project, ['--from', Directory.current.path]);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(await _gitStatus(project), isEmpty);
    expect(r.stdout, contains('No manual steps.'));
  });

  test(
    'a newer framework replaces its paths and leaves the project alone',
    () async {
      final project = await _project('example');
      _append(project, '.agents/skills/my-skill/SKILL.md', '# My skill\n');
      _append(project, 'packages/my_pkg/pubspec.yaml', 'name: my_pkg\n');
      _append(project, 'lib/main.dart', '// mine\n');
      _append(
        project,
        '.agents/skills/actions/references/action-reference.md',
        'mine\n',
      );
      await _commit(project);
      final framework = await _framework((dir) {
        _append(
          dir,
          'packages/flutter_agentify_core/lib/flutter_agentify_core.dart',
          '// new\n',
        );
        _append(dir, '.agents/skills/verify/SKILL.md', 'New line.\n');
        _append(dir, '.agents/skills/new-skill/SKILL.md', '# New skill\n');
        Directory('${dir.path}/.agents/skills/performance')
            .deleteSync(recursive: true);
        final changelog = File('${dir.path}/CHANGELOG.md');
        changelog.writeAsStringSync(
          changelog.readAsStringSync().replaceFirst(
            '## 2999-01-01\n',
            '## 2999-01-01\n\n### Upgrading\nRename foo.\n',
          ),
        );
      });
      // A framework folder named build is framework code, not build output.
      const buildFile = 'packages/flutter_agentify_core/lib/src/build/note.txt';
      _append(framework, buildFile, 'framework\n');
      await git(framework, ['add', '-f', buildFile]);
      final r = await _upgrade(project, ['--from', framework.path]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(File('${project.path}/$buildFile').existsSync(), isTrue);
      final changed = await _gitStatus(project);
      expect(changed, isNotEmpty);
      expect(
        changed,
        everyElement(
          anyOf(
            startsWith('packages/flutter_agentify_'),
            startsWith('.agents/skills/'),
            'learnings.defaults.md',
            'tool/upgrade.dart',
          ),
        ),
      );
      expect(changed, isNot(contains(contains('action-reference.md'))));
      expect(changed, isNot(contains(contains('my-skill'))));
      expect(
        File('${project.path}/.agents/skills/new-skill/SKILL.md').existsSync(),
        isTrue,
      );
      // A skill the framework dropped stays until the person deletes it.
      expect(
        File('${project.path}/.agents/skills/performance/SKILL.md')
            .existsSync(),
        isTrue,
      );
      expect(
        File('${project.path}/packages/my_pkg/pubspec.yaml').existsSync(),
        isTrue,
      );
      expect(
        r.stdout,
        allOf(
          contains('Upgraded Flutter Agentify from'),
          contains('Rename foo.'),
          contains('my-skill'),
          contains('performance'),
          contains('--write-reference'),
        ),
      );
    },
  );

  test('the on-device package is replaced only in projects that have it', () async {
    const file =
        'packages/flutter_agentify_on_device/lib/flutter_agentify_on_device.dart';
    const helper = 'packages/flutter_agentify_on_device/web/opfs_helper.js';
    final framework = await _framework((dir) {
      _append(dir, file, '// new\n');
      _append(dir, helper, '// new\n');
    });
    final withIt = await _project('empty', model: 'both');
    final without = await _project('empty');
    for (final project in [withIt, without]) {
      final r = await _upgrade(project, ['--from', framework.path]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    }
    expect(
      File('${withIt.path}/$file').readAsStringSync(),
      endsWith('// new\n'),
    );
    // The app's copy of the engine's web helper follows the package.
    expect(
      File('${withIt.path}/web/opfs_helper.js').readAsStringSync(),
      endsWith('// new\n'),
    );
    expect(
      Directory('${without.path}/packages/flutter_agentify_on_device')
          .existsSync(),
      isFalse,
    );
    expect(File('${without.path}/web/opfs_helper.js').existsSync(), isFalse);
  });

  test('--starter empty on an example project installs the example reference', () async {
    final project = await _project('example');
    final r = await _upgrade(project, [
      '--from',
      Directory.current.path,
      '--starter',
      'empty',
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(
      File(
        '${project.path}/.agents/example/lib/domain/actions/items_actions.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File('${project.path}/.agents/skills/actions/SKILL.md')
          .readAsStringSync(),
      contains('`.agents/example/lib/domain/actions/items_actions.dart`'),
    );
  });

  test('a failed fetch or a dirty tree changes nothing', () async {
    final project = await _project('example');
    final missing = await _upgrade(project, [
      '--from',
      '${project.path}/no_such_folder',
    ]);
    expect(missing.exitCode, 1);
    expect(missing.stderr, contains('Could not get Flutter Agentify'));
    expect(await _gitStatus(project), isEmpty);
    File('${project.path}/pubspec.yaml')
        .writeAsStringSync('\n', mode: FileMode.append);
    final dirty = await _upgrade(project, ['--from', Directory.current.path]);
    expect(dirty.exitCode, 1);
    expect(dirty.stderr, contains('Commit or stash'));
    Directory('${project.path}/.git').deleteSync(recursive: true);
    final noGit = await _upgrade(project, ['--from', Directory.current.path]);
    expect(noGit.exitCode, 1);
    expect(noGit.stderr, contains('Upgrade needs a git repository'));
    expect(noGit.stderr, contains('git init'));
  });

  test('a folder that is not the framework changes nothing', () async {
    final project = await _project('example');
    final framework = await Directory.systemTemp.createTemp('not_framework_');
    addTearDown(() => framework.delete(recursive: true));
    _append(framework, 'pubspec.yaml', 'name: other\n');
    final r = await _upgrade(project, ['--from', framework.path]);
    expect(r.exitCode, 1);
    expect(
      r.stderr,
      allOf(
        contains('Could not get Flutter Agentify'),
        contains('no tool/setup.dart'),
      ),
    );
    expect(await _gitStatus(project), isEmpty);
  });

  test('usage errors exit 64', () async {
    // Arguments are checked first, so the framework repo itself is safe here.
    final project = Directory.current;
    for (final args in [
      ['--bogus'],
      ['--starter', 'full'],
      ['--from'],
      ['--to', '1.0.0'],
      ['--ref', '-x'],
      ['--ref', 'main', '--from', '.'],
    ]) {
      final r = await _upgrade(project, args);
      expect(r.exitCode, 64, reason: '$args');
    }
    final help = await _upgrade(project, ['--help']);
    expect(help.exitCode, 0);
    expect(help.stdout, allOf(contains('--from'), contains('--ref')));
  });
}
