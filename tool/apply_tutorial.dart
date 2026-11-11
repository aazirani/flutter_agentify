// Applies a tutorial's file steps to a project, so the template check can
// prove the tutorial still works: "Create `path`:" and "Replace `path` with:"
// write the next code block; "In `path`, replace:" swaps the next code block
// for the one after "with:", which must match exactly once. It imports only
// dart: libraries.
//
//   dart tool/apply_tutorial.dart <tutorial.md> <project folder>
import 'dart:io';

// A step may follow other sentences on its line.
final _write = RegExp(r'(?:^|\. )(?:Create|Replace) `([^`]+)`(?: with)?:$');
final _edit = RegExp(r'(?:^|\. )In `([^`]+)`, replace:$');
// Lines that look like a step; one that matches neither pattern is reported.
final _looksLikeStep = RegExp(r'`[^`]+`.*(?:replace|with|Create.*):$');

/// The code blocks of [lines] from [start], each with the line after it.
Iterable<(String, int)> _blocks(List<String> lines, int start) sync* {
  for (var i = start; i < lines.length; i++) {
    if (!lines[i].startsWith('```')) continue;
    final body = <String>[];
    var j = i + 1;
    while (j < lines.length && !lines[j].startsWith('```')) {
      body.add(lines[j++]);
    }
    yield ('${body.join('\n')}\n', j + 1);
    i = j;
  }
}

/// Applies [tutorial] to [project]; returns one message per step that
/// cannot be applied.
List<String> applyTutorial(String tutorial, String project) {
  final lines = tutorial.split('\n');
  final problems = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (_write.firstMatch(line) case final m?) {
      final (code, _) = _blocks(lines, i + 1).first;
      File('$project/${m.group(1)}')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(code);
    } else if (_edit.firstMatch(line) case final m?) {
      final path = m.group(1) ?? '';
      final blocks = _blocks(lines, i + 1).take(2).toList();
      final (old, after) = blocks.first;
      final (replacement, _) = blocks.last;
      if (lines.sublist(after, after + 3).every((l) => l.trim() != 'with:')) {
        problems.add('line ${i + 1}: "with:" does not follow the block');
        continue;
      }
      final file = File('$project/$path');
      final text = file.existsSync() ? file.readAsStringSync() : '';
      final found = old.allMatches(text).length;
      if (found != 1) {
        problems.add(
          'line ${i + 1}: the text to replace in $path is found $found '
          'times, not once',
        );
        continue;
      }
      file.writeAsStringSync(text.replaceFirst(old, replacement));
    } else if (_looksLikeStep.hasMatch(line)) {
      problems.add('line ${i + 1}: cannot read this step: $line');
    }
  }
  return problems;
}

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart tool/apply_tutorial.dart <tutorial.md> <project folder>',
    );
    exitCode = 64;
    return;
  }
  final problems = applyTutorial(File(args[0]).readAsStringSync(), args[1]);
  problems.forEach(stderr.writeln);
  if (problems.isNotEmpty) exitCode = 1;
}
