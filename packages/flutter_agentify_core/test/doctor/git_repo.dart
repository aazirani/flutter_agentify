import 'dart:io';

/// Runs git in [root] and fails the test when it fails.
Future<void> git(Directory root, List<String> args) async {
  final result = await Process.run('git', args, workingDirectory: root.path);
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')}: ${result.stderr}');
  }
}

/// Turns [root] into a git repository whose `main` branch has one commit
/// holding every file currently in it.
Future<void> initRepo(Directory root) async {
  await git(root, ['init', '-q', '-b', 'main']);
  await git(root, ['config', 'user.email', 'doctor@example.com']);
  await git(root, ['config', 'user.name', 'Doctor Test']);
  await git(root, ['config', 'commit.gpgsign', 'false']);
  await git(root, ['add', '-A']);
  await git(root, ['commit', '-q', '--allow-empty', '-m', 'start']);
}
