import 'dart:io';

import 'package:path/path.dart' as p;

final _actionCmd = RegExp(r'dart run tool/action\.dart\s+([^\s]+)');
// [ \t] keeps a match on one line, so prose below a command is not a path.
final _testCmd = RegExp(r'flutter test[ \t]+((?:[^\s`]+[ \t]*)+)');

/// Problems in the commands that AGENTS.md and the skills show: an action
/// that is not registered, or a `flutter test` path that is missing or sits
/// under `.agents/example/`. Each is `"<file>: <what>"`.
List<String> skillCommandProblems({
  required Set<String> actionNames,
  String root = '.',
}) {
  final files = <File>[File(p.join(root, 'AGENTS.md'))];
  final skills = Directory(p.join(root, '.agents', 'skills'));
  if (skills.existsSync()) {
    for (final dir in skills.listSync().whereType<Directory>()) {
      files.add(File(p.join(dir.path, 'SKILL.md')));
    }
  }
  final problems = <String>[];
  for (final file in files.where((f) => f.existsSync())) {
    final name = p.relative(file.path, from: root);
    final text = file.readAsStringSync();
    for (final m in _actionCmd.allMatches(text)) {
      final action = m.group(1) ?? '';
      if (action.startsWith('-') || action.startsWith('<')) continue;
      if (!actionNames.contains(action)) {
        problems.add('$name: unknown action "$action" in a command');
      }
    }
    for (final m in _testCmd.allMatches(text)) {
      for (final path in (m.group(1) ?? '').split(RegExp(r'[ \t]+'))) {
        if (path.isEmpty || path.startsWith('-') || path.contains('<')) {
          continue;
        }
        if (path.startsWith('.agents/example/')) {
          problems.add('$name: `flutter test $path` is under .agents/example');
        } else if (!FileSystemEntity.isDirectorySync(p.join(root, path)) &&
            !File(p.join(root, path)).existsSync()) {
          problems.add('$name: `flutter test $path` does not exist');
        }
      }
    }
  }
  return problems;
}
