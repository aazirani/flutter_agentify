import 'dart:io';

import 'package:path/path.dart' as p;

import '../doctor.dart';

/// The longest AGENTS.md may be: every coding agent reads it on every turn.
const maxAgentsChars = 6000;

/// AGENTS.md is the one source of truth; CLAUDE.md and GEMINI.md import it,
/// and `.claude/skills` links to the shared skills folder.
class AgentFilesCheck implements DoctorCheck {
  @override
  String get name => 'agent-files';

  @override
  Future<CheckResult> run(DoctorContext context) async {
    final root = context.root.path;
    final problems = <String>[];

    final agents = File(p.join(root, 'AGENTS.md'));
    if (!agents.existsSync()) {
      problems.add('AGENTS.md is missing.');
    } else {
      final length = agents.readAsStringSync().length;
      if (length > maxAgentsChars) {
        problems.add(
          'AGENTS.md has $length characters; the limit is $maxAgentsChars. '
          'Move detail into a skill.',
        );
      }
    }

    for (final name in ['CLAUDE.md', 'GEMINI.md']) {
      final file = File(p.join(root, name));
      if (!file.existsSync()) {
        problems.add('$name is missing. It holds the single line @AGENTS.md.');
      } else if (file.readAsStringSync().trim() != '@AGENTS.md') {
        problems.add('$name must contain only the line @AGENTS.md.');
      }
    }

    final problem = _skillsLinkProblem(root);
    if (problem != null) problems.add(problem);

    return CheckResult(
      problems.isEmpty ? CheckStatus.pass : CheckStatus.fail,
      problems,
    );
  }

  String? _skillsLinkProblem(String root) {
    final link = p.join(root, '.claude', 'skills');
    final target = p.join(root, '.agents', 'skills');
    switch (FileSystemEntity.typeSync(link)) {
      case FileSystemEntityType.file:
        return '.claude/skills is a text file, not a link. On Windows: turn '
            'on Developer Mode, run `git config core.symlinks true`, then '
            '`git checkout -- .claude/skills`.';
      case FileSystemEntityType.directory:
        if (!Directory(target).existsSync()) {
          return '.agents/skills is missing.';
        }
        final resolved = Directory(link).resolveSymbolicLinksSync();
        if (resolved != Directory(target).resolveSymbolicLinksSync()) {
          return '.claude/skills must link to ../.agents/skills, but it '
              'points to $resolved.';
        }
        return null;
      default:
        return '.claude/skills is missing or a broken link. Create it with '
            '`ln -s ../.agents/skills .claude/skills`.';
    }
  }
}
