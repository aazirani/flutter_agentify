// Brings the newest Flutter Agentify into this project. It gets the framework's
// `main`, sets that copy up with this project's name, and replaces the paths
// the framework owns. It imports only dart: libraries, so it runs before
// `flutter pub get`.
//
//   dart tool/upgrade.dart
//   dart tool/upgrade.dart --help
import 'dart:io';

const _repository = 'https://github.com/aazirani/flutter_agentify.git';
const _packages = [
  'packages/flutter_agentify_core',
  'packages/flutter_agentify_ui',
  'packages/flutter_agentify_lints',
  // Replaced only in projects that have it (set up with the in-app model).
  _onDevice,
];
const _onDevice = 'packages/flutter_agentify_on_device';
const _skills = '.agents/skills';
// Generated from the project's own actions, so the project's copy stays.
const _reference = '$_skills/actions/references/action-reference.md';

const _usage = '''
Usage: dart tool/upgrade.dart [options]

  --from <folder>   Take the framework from a local folder instead of the
                    newest main on GitHub.
  --ref <ref>       Take this commit, branch or tag from GitHub instead of
                    main, to pin or step back to a known-good framework.
  --starter <s>     example or empty. Default: empty when .agents/example/
                    exists, else example.
  --help            Print this text.''';

const _next = '''
Next:
  flutter pub get
  dart run build_runner build
  dart run tool/action.dart --write-reference
  tool/check.sh''';

/// The `### Upgrading` section of each `## YYYY-MM-DD` entry in [changelog]
/// dated on or after [since] (all when null), newest first, each under a
/// `YYYY-MM-DD:` line. The same day counts: a note shown twice beats one
/// missed.
String upgradingNotes(String changelog, {String? since}) {
  final notes = <String, String>{};
  String? date;
  var inSection = false;
  for (final line in changelog.split('\n')) {
    if (line.startsWith('## ')) {
      // Any other `## ` heading, such as Unreleased, ends the entry.
      final d = RegExp(r'^## (\d{4}-\d{2}-\d{2})\s*$')
          .firstMatch(line)
          ?.group(1);
      date = d != null && (since == null || d.compareTo(since) >= 0) ? d : null;
      inSection = false;
    } else if (line.startsWith('### ')) {
      inSection = date != null && line.trim() == '### Upgrading';
    } else if (inSection && date != null) {
      notes[date] = '${notes[date] ?? ''}$line\n';
    }
  }
  final dates = notes.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in dates)
      if ((notes[d] ?? '').trim().isNotEmpty) '$d:\n${(notes[d] ?? '').trim()}',
  ].join('\n\n');
}

// Set once the project starts to change, so a failure can say how to undo it.
var _changing = false;

Future<void> main(List<String> args) async {
  try {
    exitCode = await _upgrade(args);
  } on IOException catch (e) {
    _failed(e);
  } on FormatException catch (e) {
    _failed(e);
  }
}

void _failed(Object error) {
  stderr.writeln(
    'Upgrade failed: ${error is FormatException ? error.message : error}',
  );
  if (_changing) {
    stderr.writeln(
      'Undo the partial upgrade with: git checkout -- . && git clean -fd .',
    );
  }
  exitCode = 1;
}

Future<int> _upgrade(List<String> args) async {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      stdout.writeln(_usage);
      return 0;
    }
    final option = RegExp(r'^--(from|ref|starter)(?:=(.*))?$').firstMatch(arg);
    if (option == null) return _usageError('Unknown argument: $arg');
    final value = option.group(2) ?? (i + 1 < args.length ? args[++i] : null);
    if (value == null) return _usageError('$arg needs a value.');
    options[option.group(1) ?? ''] = value;
  }
  final from = options['from'];
  final ref = options['ref'];
  final starterOption = options['starter'];
  if (ref != null && from != null) {
    return _usageError('Use --ref or --from, not both.');
  }
  // A ref that starts with - would be read by git as an option.
  if (ref != null && !RegExp(r'^[\w][\w./-]*$').hasMatch(ref)) {
    return _usageError('--ref "$ref": use a commit, branch or tag name.');
  }
  if (starterOption != null &&
      !const ['example', 'empty'].contains(starterOption)) {
    return _usageError('--starter "$starterOption": use example or empty.');
  }

  // 1. A clean tree, so the result can be reviewed and undone.
  final root = File.fromUri(Platform.script).absolute.parent.parent.path;
  final status = Process.runSync('git', [
    'status',
    '--porcelain',
    '--',
    '.',
  ], workingDirectory: root);
  if (status.exitCode != 0) {
    stderr.writeln(
      'Upgrade needs a git repository, so the result can be reviewed and '
      'undone. Run: git init && git add -A && git commit -m "Before upgrade"',
    );
    return 1;
  }
  if ((status.stdout as String).isNotEmpty) {
    stderr.writeln(
      'Commit or stash your changes first, so the upgrade can be reviewed '
      'and undone.',
    );
    return 1;
  }

  // 2. When the framework last came in: the newest commit that changed it.
  final last = Process.runSync('git', [
    'log',
    '-1',
    '--format=%cs',
    '--',
    'packages/flutter_agentify_core',
  ], workingDirectory: root);
  final since = '${last.stdout}'.trim();
  final name = RegExp(
    r'^name:\s*(\S+)',
    multiLine: true,
  ).firstMatch(File('$root/pubspec.yaml').readAsStringSync())?.group(1);
  if (name == null) {
    stderr.writeln('No name in pubspec.yaml under $root.');
    return 1;
  }

  final temp = Directory.systemTemp.createTempSync('flutter_agentify_upgrade_');
  try {
    // 3. The framework, in a temp folder.
    final copy = '${temp.path}/copy';
    final label = from != null
        ? 'from $from'
        : 'from $_repository at ${ref ?? 'main'}';
    final problem =
        (from != null ? _copyFrom(from, copy) : _clone(ref, copy)) ??
        (File('$copy/tool/setup.dart').existsSync()
            ? null
            : 'it has no tool/setup.dart');
    if (problem != null) {
      stderr.writeln('Could not get Flutter Agentify $label: $problem');
      return 1;
    }

    // 4. Read the notes before the copy's setup deletes them.
    final changelog = File('$copy/CHANGELOG.md');
    final notes = changelog.existsSync()
        ? upgradingNotes(
            changelog.readAsStringSync(),
            since: since.isEmpty ? null : since,
          )
        : '';

    // 5. Set the copy up as this project. No framework-owned file holds the
    // org, so a placeholder does.
    final starter =
        starterOption ??
        (Directory('$root/.agents/example').existsSync() ? 'empty' : 'example');
    // A project with the in-app model keeps it; `both` and `on-device` set up
    // the same framework files.
    final hasOnDevice = Directory('$root/$_onDevice').existsSync();
    final setup = Process.runSync(Platform.resolvedExecutable, [
      'tool/setup.dart',
      '--name',
      name,
      '--org',
      'com.example',
      '--starter',
      starter,
      '--model',
      hasOnDevice ? 'both' : 'server',
    ], workingDirectory: copy);
    if (setup.exitCode != 0) {
      stderr
        ..writeln('Setting up Flutter Agentify $label failed:')
        ..write(setup.stdout)
        ..write(setup.stderr);
      return 1;
    }

    // 6. Replace the framework-owned paths.
    final newSkills = _folders('$copy/$_skills');
    final extraSkills = _folders('$root/$_skills')
        .where((skill) => !newSkills.contains(skill))
        .toList();
    final reference = File('$root/$_reference');
    final keptReference = reference.existsSync()
        ? reference.readAsBytesSync()
        : null;
    _changing = true;
    for (final path in [
      ..._packages,
      for (final skill in newSkills) '$_skills/$skill',
      '.agents/example',
      'learnings.defaults.md',
      'tool/upgrade.dart',
    ]) {
      final type = FileSystemEntity.typeSync('$copy/$path', followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (path == _onDevice && !hasOnDevice) continue;
      _delete('$root/$path');
      _copy(
        copy,
        root,
        type == FileSystemEntityType.directory
            // The copy is a fresh clone or a filtered copy: skip only .git.
            ? _walk(
                '$copy/$path',
                skip: const {'.git'},
              ).map((file) => '$path/$file')
            : [path],
      );
    }
    // The engine's web helpers ship in the package; keep the app's copies in
    // step with it.
    if (hasOnDevice) {
      for (final helper in const ['cache_api.js', 'opfs_helper.js']) {
        final source = File('$root/$_onDevice/web/$helper');
        if (source.existsSync()) source.copySync('$root/web/$helper');
      }
    }
    if (keptReference != null) {
      reference
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(keptReference);
    }
    _changing = false;

    // 7. What changed and what is left to do.
    stdout
      ..writeln('Upgraded Flutter Agentify $label.')
      ..writeln(notes.isEmpty ? 'No manual steps.' : notes);
    if (extraSkills.isNotEmpty) {
      stdout.writeln(
        'Skills the framework no longer ships (delete the ones you did not '
        'add): ${extraSkills.join(', ')}',
      );
    }
    stdout.writeln(_next);
    return 0;
  } finally {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      stderr.writeln('Could not delete ${temp.path}; delete it by hand.');
    }
  }
}

int _usageError(String message) {
  stderr
    ..writeln(message)
    ..writeln()
    ..writeln(_usage);
  return 64;
}

/// Copies the folder [from] to [copy]: the files git lists when it is a git
/// work tree, else everything outside `.git`, `.dart_tool` and `build`.
/// Returns why it failed, or `null`.
String? _copyFrom(String from, String copy) {
  final source = Directory(from).absolute.path;
  if (!Directory(source).existsSync()) return 'no folder $source';
  List<String>? listed;
  try {
    final list = Process.runSync('git', [
      'ls-files',
      '-z',
      '--cached',
      '--others',
      '--exclude-standard',
    ], workingDirectory: source);
    if (list.exitCode == 0) listed = (list.stdout as String).split('\x00');
  } on ProcessException {
    // git is not installed; copy the folder as it is.
  }
  final paths = listed != null && listed.contains('pubspec.yaml')
      ? listed
      : _walk(source);
  _copy(source, copy, paths);
  return null;
}

/// Clones [ref], or the newest `main`, into [copy]. Returns why it failed, or
/// `null`.
String? _clone(String? ref, String copy) {
  // Never ask for a password: there is no one to answer in a script.
  const env = {'GIT_TERMINAL_PROMPT': '0'};
  // Only main can be cloned shallow by name; a ref may be a commit.
  final clone = Process.runSync('git', [
    'clone',
    '-q',
    if (ref == null) ...['--depth', '1', '--branch', 'main'],
    _repository,
    copy,
  ], environment: env);
  if (clone.exitCode != 0) return '${clone.stderr}'.trim();
  if (ref == null) return null;
  final checkout = Process.runSync('git', [
    'checkout',
    '-q',
    ref,
  ], workingDirectory: copy);
  return checkout.exitCode == 0 ? null : '${checkout.stderr}'.trim();
}

/// Names of the folders in [dir].
List<String> _folders(String dir) {
  if (!Directory(dir).existsSync()) return [];
  return [
    for (final entity in Directory(dir).listSync(followLinks: false))
      if (entity is Directory)
        entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
  ]..sort();
}

/// Files and links under [dir], relative to it, outside folders named in
/// [skip].
List<String> _walk(
  String dir, {
  Set<String> skip = const {'.git', '.dart_tool', 'build'},
}) => [
  for (final entity in Directory(
    dir,
  ).listSync(recursive: true, followLinks: false))
    if (entity is! Directory)
      entity.path.substring(dir.length + 1).replaceAll(r'\', '/'),
].where((path) => !path.split('/').any(skip.contains)).toList();

/// Copies [paths] (relative) from [from] to [to]. Links stay links; paths that
/// do not exist are skipped.
void _copy(String from, String to, Iterable<String> paths) {
  for (final path in paths) {
    if (path.isEmpty) continue;
    final source = '$from/$path';
    final target = '$to/$path';
    final type = FileSystemEntity.typeSync(source, followLinks: false);
    if (type == FileSystemEntityType.link) {
      Directory(target).parent.createSync(recursive: true);
      Link(target).createSync(Link(source).targetSync());
    } else if (type == FileSystemEntityType.file) {
      Directory(target).parent.createSync(recursive: true);
      File(source).copySync(target);
    }
  }
}

void _delete(String path) {
  switch (FileSystemEntity.typeSync(path, followLinks: false)) {
    case FileSystemEntityType.directory:
      Directory(path).deleteSync(recursive: true);
    case FileSystemEntityType.link:
      Link(path).deleteSync();
    case FileSystemEntityType.notFound:
      break;
    default:
      File(path).deleteSync();
  }
}
