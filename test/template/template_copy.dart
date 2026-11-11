import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Copies the files git lists (tracked and untracked, not ignored) into a
/// temp folder that is its own git repository with one commit. The folder is
/// deleted on tear-down. Symlinks stay symlinks.
Future<Directory> templateCopy() async {
  final dir = await Directory.systemTemp.createTemp('template_copy_');
  addTearDown(() => dir.delete(recursive: true));
  final list = await Process.run('git', [
    'ls-files',
    '-z',
    '--cached',
    '--others',
    '--exclude-standard',
  ]);
  for (final path in (list.stdout as String).split('\x00')) {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    final target = '${dir.path}/$path';
    if (path.isEmpty || type == FileSystemEntityType.notFound) continue;
    Directory(target).parent.createSync(recursive: true);
    if (type == FileSystemEntityType.link) {
      Link(target).createSync(Link(path).targetSync());
    } else if (type == FileSystemEntityType.file) {
      File(path).copySync(target);
    }
  }
  await git(dir, ['init', '-q']);
  await git(dir, ['add', '-A']);
  await git(dir, ['commit', '-q', '-m', 'Template']);
  return dir;
}

/// Runs `dart tool/setup.dart` in [dir].
Future<ProcessResult> runSetup(Directory dir, List<String> args) => Process.run(
  'dart',
  ['tool/setup.dart', ...args],
  workingDirectory: dir.path,
);

/// Runs git in [dir] with a fixed identity, so commits work on any machine.
/// Auto-maintenance is off: newer git repacks in the background after a
/// commit, which breaks a following clone and the tear-down delete.
Future<ProcessResult> git(Directory dir, List<String> args) =>
    Process.run('git', [
      '-c',
      'user.name=Template Test',
      '-c',
      'user.email=template-test@example.com',
      '-c',
      'commit.gpgsign=false',
      '-c',
      'maintenance.auto=false',
      '-c',
      'gc.auto=0',
      ...args,
    ], workingDirectory: dir.path);
