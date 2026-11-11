import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../doctor.dart';
import '../git_diff.dart';

const _baselinePath = 'tool/baselines/ratchet.json';
const _keys = ['ignore_comments', 'null_assertions', 'dynamic'];

final _ignoreComment = RegExp(r'//\s*ignore(_for_file)?:');
final _commentsAndStrings = RegExp(
  r"'''[\s\S]*?'''|"
  r'"""[\s\S]*?"""|'
  r"'(?:\\.|[^'\\\n])*'|"
  r'"(?:\\.|[^"\\\n])*"|'
  r'/\*[\s\S]*?\*/|'
  r'//[^\n]*',
);
final _nullAssertion = RegExp(r'(?<=[\w)\]])(?<!\bis)!(?!=)');
final _dynamic = RegExp(r'\bdynamic\b');
final _generated = RegExp(r'\.(g|drift|freezed)\.dart$');

final _interpolation = RegExp(r'\$\{([^}]*)\}');

/// Counts of the escape hatches the ratchet tracks in [dartSource].
// shortcut: regex counting, not a parser; interpolations with a `}` inside and raw strings are not told apart, switch to package:analyzer if the counts become misleading.
Map<String, int> countRatchets(String dartSource) {
  final comments = StringBuffer();
  final code = dartSource.replaceAllMapped(_commentsAndStrings, (m) {
    final token = m.group(0) ?? '';
    if (token.startsWith('/')) {
      comments.writeln(token);
      return ' ';
    }
    // A string leaves only its `${...}` code: a `!` there is real code.
    return _interpolation
        .allMatches(token)
        .map((i) => ' ${i[1] ?? ''} ')
        .join();
  });
  return {
    'ignore_comments': _ignoreComment.allMatches('$comments').length,
    'null_assertions': _nullAssertion.allMatches(code).length,
    'dynamic': _dynamic.allMatches(code).length,
  };
}

/// `// ignore:` comments, `!` null assertions and `dynamic` may only become
/// fewer. Totals are compared with `tool/baselines/ratchet.json`; with
/// `--changed`, any of them on an added line fails. A baseline with
/// `"scope": "app"` counts only `lib/`, not `packages/*/lib`.
class RatchetCheck implements DoctorCheck {
  @override
  String get name => 'ratchet';

  @override
  Future<CheckResult> run(DoctorContext context) async {
    final root = context.root.path;
    final baselineFile = File(p.join(root, _baselinePath));
    final appOnly = _appOnly(baselineFile);
    if (context.updateBaselines) return _update(root, appOnly);
    if (context.changedOnly) return _checkAdded(context, appOnly);

    if (!baselineFile.existsSync()) {
      return const CheckResult(CheckStatus.fail, [
        '$_baselinePath is missing. Create it with '
            '`dart run flutter_agentify_core:doctor --update-baselines`.',
      ]);
    }
    final baseline =
        jsonDecode(baselineFile.readAsStringSync()) as Map<String, Object?>;
    final counts = _totals(root, appOnly);

    final over = <String>[];
    final under = <String>[];
    for (final key in _keys) {
      final limit = (baseline[key] as int?) ?? 0;
      final count = counts[key]!;
      if (count > limit) over.add('$key: $count > baseline $limit');
      if (count < limit) under.add('$key: $count < baseline $limit');
    }
    if (over.isNotEmpty) return CheckResult(CheckStatus.fail, over);
    return CheckResult(CheckStatus.pass, [
      if (under.isNotEmpty)
        '${under.join(', ')}. Lock the gain in with '
            '`dart run flutter_agentify_core:doctor --update-baselines`.',
    ]);
  }

  /// Whether the baseline says `"scope": "app"`. A missing or broken file
  /// says no, so `--update-baselines` can still repair it.
  static bool _appOnly(File baseline) {
    try {
      final json = jsonDecode(baseline.readAsStringSync());
      return json is Map && json['scope'] == 'app';
    } on FileSystemException {
      return false;
    } on FormatException {
      return false;
    }
  }

  CheckResult _update(String root, bool appOnly) {
    final file = File(p.join(root, _baselinePath))
      ..parent.createSync(recursive: true);
    final counts = {if (appOnly) 'scope': 'app', ..._totals(root, appOnly)};
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(counts)}\n',
    );
    return CheckResult(CheckStatus.pass, ['wrote $_baselinePath']);
  }

  Future<CheckResult> _checkAdded(DoctorContext context, bool appOnly) async {
    final added = await addedLines(context.root, context.baseBranch);
    final problems = <String>[];
    for (final MapEntry(key: path, value: lines) in added.entries) {
      if (!_inScope(path, appOnly)) continue;
      final counts = countRatchets(lines.join('\n'));
      for (final key in _keys) {
        if (counts[key]! > 0) {
          problems.add('$path: ${counts[key]} added $key');
        }
      }
    }
    return CheckResult(
      problems.isEmpty ? CheckStatus.pass : CheckStatus.fail,
      problems,
    );
  }

  Map<String, int> _totals(String root, bool appOnly) {
    final totals = {for (final key in _keys) key: 0};
    for (final file in _dartFiles(root, appOnly)) {
      final counts = countRatchets(file.readAsStringSync());
      for (final key in _keys) {
        totals[key] = totals[key]! + counts[key]!;
      }
    }
    return totals;
  }

  /// `lib/**/*.dart` and, unless [appOnly], `packages/*/lib/**/*.dart`,
  /// without generated files.
  Iterable<File> _dartFiles(String root, bool appOnly) sync* {
    final libs = [
      Directory(p.join(root, 'lib')),
      if (!appOnly && Directory(p.join(root, 'packages')).existsSync())
        for (final package in Directory(
          p.join(root, 'packages'),
        ).listSync().whereType<Directory>())
          Directory(p.join(package.path, 'lib')),
    ];
    for (final lib in libs) {
      if (!lib.existsSync()) continue;
      for (final file in lib.listSync(recursive: true).whereType<File>()) {
        final path = p.relative(file.path, from: root).replaceAll(r'\', '/');
        if (_inScope(path, appOnly)) yield file;
      }
    }
  }

  static bool _inScope(String path, bool appOnly) {
    if (!path.endsWith('.dart') || _generated.hasMatch(path)) return false;
    final parts = path.split('/');
    return parts.first == 'lib' ||
        (!appOnly &&
            parts.length > 3 &&
            parts[0] == 'packages' &&
            parts[2] == 'lib');
  }
}
