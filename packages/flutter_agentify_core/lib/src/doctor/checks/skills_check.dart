import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../doctor.dart';

/// The longest a SKILL.md may be; detail goes in its `references/` folder.
const maxSkillChars = 6000;

const _repoPathPrefixes = [
  'lib/',
  'test/',
  'tool/',
  'packages/',
  'assets/',
  '.agents/',
];

final _backticked = RegExp('`([^`\n]+)`');
final _lineSuffix = RegExp(r':\d+$');

/// Every skill in `.agents/skills/` has valid frontmatter, stays small, and
/// only points at skills and repo paths that exist.
class SkillsCheck implements DoctorCheck {
  @override
  String get name => 'skills';

  @override
  Future<CheckResult> run(DoctorContext context) async {
    final root = context.root.path;
    final skillsDir = Directory(p.join(root, '.agents', 'skills'));
    if (!skillsDir.existsSync()) return const CheckResult(CheckStatus.pass);

    final folders = skillsDir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final skillNames = folders.map((d) => p.basename(d.path)).toSet();

    final problems = <String>[];
    for (final folder in folders) {
      final name = p.basename(folder.path);
      final label = '.agents/skills/$name/SKILL.md';
      final file = File(p.join(folder.path, 'SKILL.md'));
      if (!file.existsSync()) {
        problems.add('$label is missing.');
        continue;
      }
      final content = file.readAsStringSync();
      problems.addAll([
        for (final problem in _problems(content, name, skillNames, root))
          '$label: $problem',
      ]);
    }
    return CheckResult(
      problems.isEmpty ? CheckStatus.pass : CheckStatus.fail,
      problems,
    );
  }

  List<String> _problems(
    String content,
    String folderName,
    Set<String> skillNames,
    String root,
  ) {
    final problems = <String>[];
    if (content.length > maxSkillChars) {
      problems.add(
        'has ${content.length} characters; the limit is $maxSkillChars. '
        'Move detail into references/.',
      );
    }

    final lines = content.split('\n');
    final close = lines.indexWhere((l) => l.trimRight() == '---', 1);
    if (lines.first.trimRight() != '---' || close < 0) {
      problems.add('frontmatter must sit between two --- lines at the top.');
    } else {
      problems.addAll(
        _frontmatterProblems(lines.sublist(1, close).join('\n'), folderName),
      );
    }

    for (final skill in _relatedSkills(lines)) {
      if (!skillNames.contains(skill)) {
        problems.add('Related skills names `$skill`, which does not exist.');
      }
    }

    for (final match in _backticked.allMatches(content)) {
      final token = match.group(1)!;
      if (!_repoPathPrefixes.any(token.startsWith)) continue;
      if (token.contains('<') || token.contains('*') || token.contains('…')) {
        continue;
      }
      final path = token.replaceFirst(_lineSuffix, '');
      if (FileSystemEntity.typeSync(p.join(root, path)) ==
          FileSystemEntityType.notFound) {
        problems.add('`$token` does not exist.');
      }
    }
    return problems;
  }

  List<String> _frontmatterProblems(String yaml, String folderName) {
    final Object? data;
    try {
      data = loadYaml(yaml);
    } on YamlException catch (e) {
      return ['frontmatter is not valid YAML: ${e.message}'];
    }
    if (data is! YamlMap) return ['frontmatter is not a YAML map.'];

    final problems = <String>[];
    if (data['name'] != folderName) {
      problems.add('name must be "$folderName", the folder name.');
    }
    final description = data['description'];
    if (description is! String || description.trim().isEmpty) {
      problems.add('description is missing.');
    } else if (!description.contains('Use when')) {
      problems.add('description must say when to load it ("Use when …").');
    }
    return problems;
  }

  /// First backticked word of each bullet under `## Related skills`.
  Iterable<String> _relatedSkills(List<String> lines) sync* {
    final start = lines.indexWhere((l) => l.trim() == '## Related skills');
    if (start < 0) return;
    for (final line in lines.skip(start + 1)) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) return;
      if (!trimmed.startsWith('- ') && !trimmed.startsWith('* ')) continue;
      final match = _backticked.firstMatch(trimmed);
      if (match != null) yield match.group(1)!;
    }
  }
}
