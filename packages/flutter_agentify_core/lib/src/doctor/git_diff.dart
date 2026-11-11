import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Why [addedLines] could not compare against the base branch.
class GitDiffError implements Exception {
  GitDiffError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lines added in the working tree since it branched off [base], by
/// repo-relative path. Renamed files count as wholly added.
/// Throws [GitDiffError] when git is missing, [root] is not a repository, or [base] does not exist.
Future<Map<String, List<String>>> addedLines(
  Directory root,
  String base,
) async {
  await _git(root, [
    'rev-parse',
    '--git-dir',
  ], '${root.path} is not a git repository.');
  await _git(root, [
    'rev-parse',
    '--verify',
    '--quiet',
    '$base^{commit}',
  ], 'The base branch "$base" does not exist. Pass another with --base.');

  final since = (await _git(root, [
    'merge-base',
    base,
    'HEAD',
  ], 'The current branch shares no history with "$base".')).trim();

  final added = <String, List<String>>{};
  final diff = await _git(root, [
    '-c',
    'core.quotepath=false',
    'diff',
    '--relative',
    '--unified=0',
    '--no-color',
    '--no-ext-diff',
    '--no-renames',
    // Fixed prefixes, whatever diff.noprefix or diff.mnemonicPrefix say.
    '--src-prefix=a/',
    '--dst-prefix=b/',
    since,
    '--',
    '.',
  ], 'git diff against "$base" failed.');

  List<String>? current;
  var previous = '';
  for (final line in const LineSplitter().convert(diff)) {
    if (line.startsWith('+++ ') && previous.startsWith('--- ')) {
      final path = line.substring(4);
      current = path.startsWith('b/')
          ? added.putIfAbsent(path.substring(2), () => [])
          : null;
    } else if (line.startsWith('diff --git ')) {
      current = null;
    } else if (line.startsWith('+') && current != null) {
      current.add(line.substring(1));
    }
    previous = line;
  }

  final untracked = await _git(root, [
    '-c',
    'core.quotepath=false',
    'ls-files',
    '--others',
    '--exclude-standard',
  ], 'git ls-files failed.');
  for (final path in const LineSplitter().convert(untracked)) {
    if (path.isEmpty) continue;
    final full = p.join(root.path, path);
    // Links, folders and huge files are not source text worth scanning.
    if (FileSystemEntity.typeSync(full, followLinks: false) !=
        FileSystemEntityType.file) {
      continue;
    }
    final file = File(full);
    if (await file.length() > 1048576) continue;
    final bytes = await file.readAsBytes();
    added[path] = const LineSplitter().convert(
      utf8.decode(bytes, allowMalformed: true),
    );
  }
  return added;
}

Future<String> _git(Directory root, List<String> args, String failure) async {
  final ProcessResult result;
  try {
    result = await Process.run('git', args, workingDirectory: root.path);
  } on ProcessException {
    throw GitDiffError('git is not installed or not on PATH.');
  }
  if (result.exitCode != 0) throw GitDiffError(failure);
  return result.stdout as String;
}
