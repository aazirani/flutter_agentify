import 'dart:io';

import 'package:flutter_agentify_core/src/doctor/git_diff.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'git_repo.dart';
import 'temp_repo.dart';

void main() {
  test('returns added lines per file', () async {
    final root = await tempRepo({'a.txt': 'one\ntwo\n'});
    await initRepo(root);
    await File(p.join(root.path, 'a.txt')).writeAsString('one\nnew\ntwo\n');

    final added = await addedLines(root, 'main');
    expect(added, {
      'a.txt': ['new'],
    });
  });

  test('counts every line of a new untracked file as added', () async {
    final root = await tempRepo({'a.txt': 'one\n'});
    await initRepo(root);
    await File(p.join(root.path, 'dir', 'b.txt'))
      ..parent.createSync()
      ..writeAsStringSync('x\ny\n');

    final added = await addedLines(root, 'main');
    expect(added['dir/b.txt'], ['x', 'y']);
    expect(added.containsKey('a.txt'), isFalse);
  });

  test('an untracked symlink to a folder is skipped', () async {
    final root = await tempRepo({'a.txt': 'one\n'});
    await initRepo(root);
    Directory(p.join(root.path, 'real')).createSync();
    Link(p.join(root.path, 'link')).createSync('real');

    final added = await addedLines(root, 'main');
    expect(added.containsKey('link'), isFalse);
  });

  test('a broken untracked symlink is skipped', () async {
    final root = await tempRepo({'a.txt': 'one\n'});
    await initRepo(root);
    Link(p.join(root.path, 'dangling')).createSync('missing');

    final added = await addedLines(root, 'main');
    expect(added.containsKey('dangling'), isFalse);
  });

  test('an untracked file over 1 MiB is skipped', () async {
    final root = await tempRepo({'a.txt': 'one\n'});
    await initRepo(root);
    File(p.join(root.path, 'big.txt')).writeAsStringSync('x' * 1048577);
    File(p.join(root.path, 'small.txt')).writeAsStringSync('y\n');

    final added = await addedLines(root, 'main');
    expect(added.containsKey('big.txt'), isFalse);
    expect(added['small.txt'], ['y']);
  });

  for (final setting in ['diff.noprefix', 'diff.mnemonicPrefix']) {
    test('ignores the $setting git setting', () async {
      final root = await tempRepo({'a.txt': 'one\n'});
      await initRepo(root);
      await git(root, ['config', setting, 'true']);
      await File(p.join(root.path, 'a.txt')).writeAsString('one\nnew\n');

      expect(await addedLines(root, 'main'), {
        'a.txt': ['new'],
      });
    });
  }

  test('counts every line of a renamed file as added', () async {
    final root = await tempRepo({'a.txt': 'one\ntwo\n'});
    await initRepo(root);
    await git(root, ['mv', 'a.txt', 'b.txt']);

    expect((await addedLines(root, 'main'))['b.txt'], ['one', 'two']);
  });

  test(
    'compares with the merge-base, not the tip of the base branch',
    () async {
      final root = await tempRepo({'a.txt': 'one\ntwo\n'});
      await initRepo(root);
      await git(root, ['checkout', '-q', '-b', 'feature']);
      await git(root, ['checkout', '-q', 'main']);
      await File(p.join(root.path, 'a.txt')).writeAsString('one\n');
      await git(root, ['commit', '-q', '-am', 'drop two on main']);
      await git(root, ['checkout', '-q', 'feature']);

      expect(await addedLines(root, 'main'), isEmpty);
    },
  );

  test('throws GitDiffError outside a git repository', () async {
    final root = await tempRepo({'a.txt': 'one\n'});
    expect(addedLines(root, 'main'), throwsA(isA<GitDiffError>()));
  });

  test('throws GitDiffError when the base branch is missing', () async {
    final root = await tempRepo({'a.txt': 'one\n'});
    await initRepo(root);
    expect(
      addedLines(root, 'nope'),
      throwsA(
        isA<GitDiffError>().having(
          (e) => e.message,
          'message',
          contains('nope'),
        ),
      ),
    );
  });
}
