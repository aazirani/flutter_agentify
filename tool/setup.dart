// Turns a fresh copy of the template into a named project, then deletes
// itself. It imports only dart: libraries, so it runs before `flutter pub get`.
//
//   dart tool/setup.dart --name notes_app --org com.acme --starter example
//   dart tool/setup.dart --name notes_app --org com.acme --starter empty --model both
//   dart tool/setup.dart --help
import 'dart:convert';
import 'dart:io';

// Packages every Flutter project has; a project with one of these names
// cannot depend on it.
const _sdkPackages = {
  'flutter',
  'flutter_test',
  'flutter_driver',
  'flutter_localizations',
  'flutter_web_plugins',
  'integration_test',
  'test',
};

const _dartReservedWords = {
  'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case', //
  'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred',
  'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
  'external', 'factory', 'false', 'final', 'finally', 'for', 'function',
  'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is',
  'late', 'library', 'mixin', 'new', 'null', 'of', 'on', 'operator', 'part',
  'required', 'rethrow', 'return', 'sealed', 'set', 'show', 'static',
  'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'type',
  'typedef', 'var', 'void', 'when', 'while', 'with', 'yield',
};

// Words Kotlin or Java reserve; neither may be a part of the Android package.
const _jvmKeywords = {
  'abstract', 'as', 'assert', 'boolean', 'break', 'byte', 'case', 'catch', //
  'char', 'class', 'const', 'continue', 'default', 'do', 'double', 'else',
  'enum', 'extends', 'false', 'final', 'finally', 'float', 'for', 'fun',
  'goto', 'if', 'implements', 'import', 'in', 'instanceof', 'int',
  'interface', 'is', 'long', 'native', 'new', 'null', 'object', 'package',
  'private', 'protected', 'public', 'return', 'short', 'static', 'strictfp',
  'super', 'switch', 'synchronized', 'this', 'throw', 'throws', 'transient',
  'true', 'try', 'typealias', 'typeof', 'val', 'var', 'void', 'volatile',
  'when', 'while',
};

/// Why [name] cannot be the package name, or `null` when it can.
String? nameProblem(String name, {Set<String> dependencyNames = const {}}) {
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
    return '--name "$name": use lowercase letters, digits and _, starting '
        'with a letter (for example notes_app).';
  }
  if (_dartReservedWords.contains(name)) {
    return '--name "$name" is a Dart reserved word. Choose another name.';
  }
  final androidPart = name.replaceAll('_', '');
  if (_jvmKeywords.contains(androidPart)) {
    return '--name "$name" becomes "$androidPart" in the Android package, '
        'which Kotlin or Java reserve. Choose another name.';
  }
  if (name.startsWith('flutter_agentify') ||
      _sdkPackages.contains(name) ||
      dependencyNames.contains(name)) {
    return '--name "$name" is the name of a package this project uses. '
        'Choose another name.';
  }
  return null;
}

/// Why [org] cannot be the organization, or `null` when it can.
String? orgProblem(String org) {
  // Lowercase letters and digits only: what Android and Apple both accept.
  if (!RegExp(r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$').hasMatch(org)) {
    return '--org "$org": use reverse-domain form with at least two parts, '
        'each of lowercase letters and digits starting with a letter '
        '(for example com.acme).';
  }
  for (final part in org.split('.')) {
    if (_jvmKeywords.contains(part)) {
      return '--org "$org": "$part" is reserved by Kotlin or Java, so it '
          'cannot be part of the Android package.';
    }
  }
  return null;
}

/// Why [title] cannot be the title people see, or `null` when it can.
String? titleProblem(String title) {
  if (RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ._-]*$').hasMatch(title)) return null;
  return '--title "$title": use only letters, digits, spaces, ".", "_" and '
      '"-", starting with a letter or digit.';
}

/// `notes_app` → `Notes App`.
String defaultTitle(String name) => name
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');

/// `com.acme` and `notes_app` → `com.acme.notesapp`.
String applicationId(String org, String name) =>
    '$org.${name.replaceAll('_', '')}';

final _blockMark = RegExp(
  r'^\s*(?://|#|<!--)\s*@(example|template|on-device):(begin|end)\s*(?:-->)?\s*$',
);
final _emptyMark = RegExp(
  r'^(\s*)(?://|#|<!--)\s*@empty:\s?(.*?)\s*(?:-->)?\s*$',
);

/// Applies the starter marks to [content]. `@template` blocks go; `@example`
/// blocks keep their content unless [empty]; `@on-device` blocks keep theirs
/// only with [onDevice]; an `@empty: <text>` line becomes `<text>` when
/// [empty] and goes otherwise. Throws a [FormatException] naming [path] and
/// the line for an unclosed block or a stray end.
String applyMarks(
  String content, {
  required bool empty,
  bool onDevice = false,
  required String path,
}) {
  final out = <String>[];
  final lines = content.split('\n');
  String? open;
  var openLine = 0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final block = _blockMark.firstMatch(line);
    if (block != null) {
      final kind = block.group(1) ?? '';
      if (block.group(2) == 'begin') {
        if (open != null) {
          throw FormatException(
            '$path:${i + 1}: @$kind:begin inside the @$open block that '
            'starts on line $openLine. Blocks do not nest.',
          );
        }
        open = kind;
        openLine = i + 1;
      } else {
        if (open != kind) {
          throw FormatException(
            '$path:${i + 1}: @$kind:end without a matching @$kind:begin.',
          );
        }
        open = null;
      }
      continue;
    }
    if (open == 'template' ||
        (open == 'example' && empty) ||
        (open == 'on-device' && !onDevice)) {
      continue;
    }
    final emptyMark = _emptyMark.firstMatch(line);
    if (emptyMark == null) {
      out.add(line);
    } else if (empty) {
      out.add('${emptyMark.group(1)}${emptyMark.group(2)}');
    }
  }
  if (open != null) {
    throw FormatException('$path:$openLine: @$open:begin is never closed.');
  }
  return out.join('\n');
}

const _usage = '''
Usage: dart tool/setup.dart --name <snake_case_name> --org <reverse.domain> --starter example|empty [options]

  --name <name>     Package name (notes_app): lowercase letters, digits and _,
                    starting with a letter. Not a Dart reserved word, a Kotlin
                    or Java keyword once the _ are removed, or the name of a
                    package the project uses.
  --org <org>       Organization in reverse-domain form (com.acme): two or
                    more parts of lowercase letters and digits, each starting
                    with a letter and none a Kotlin or Java keyword.
  --starter <s>     example keeps the item list; empty starts clean.
  --model <m>       Where the assistant's model runs: server (a model
                    server, the default), both (the model inside the app,
                    the server until it is ready) or on-device (only the
                    model inside the app; raises the platform floors).
  --title <title>   Name people see. Default: the name in title case.
                    Only letters, digits, spaces, ".", "_" and "-", starting
                    with a letter or digit.
  --reset-git       Start a new git history after setup.
  --dry-run         Print what would change and write nothing.
  --help            Print this text.''';

const _kotlinActivity =
    'android/app/src/main/kotlin/com/example/flutteragentify/MainActivity.kt';

// Framework-only paths; a trailing / marks a folder.
const _removed = [
  'docs/',
  'CHANGELOG.md',
  'CONTRIBUTING.md',
  'CODE_OF_CONDUCT.md',
  'SECURITY.md',
  '.github/ISSUE_TEMPLATE/',
  '.github/PULL_REQUEST_TEMPLATE.md',
  'tool/setup.dart',
  'tool/starters/',
  'tool/check_template.sh',
  'tool/apply_tutorial.dart',
  'tool/docs_screenshots_test.dart',
  'tool/make_demo.sh',
  'test/template/',
];

final _bareName = RegExp(r'(?<!\.dart_tool/)flutter_agentify(?!\w)');
final _leftover = RegExp(
  r'package:flutter_agentify/|aminazirani|aazirani|Amin Azirani|'
  r'flutteragentify|@(example|template|empty|on-device):|Flutter Agentify|'
  '${_bareName.pattern}',
);
final _packageImport = RegExp(r"^import 'package:([^']*)'[^;\n]*;$");

/// What to run after setup. The commit comes first, so the gate and a later
/// upgrade see a clean tree.
String _next(String name, {required bool commit}) => [
  'Next:',
  if (commit) '  git add -A && git commit -m "Set up $name"',
  '  flutter pub get',
  '  dart run build_runner build',
  '  tool/check.sh',
  'Try the app: flutter run',
  'Coding agents: read AGENTS.md, then load the build-an-app skill.',
].join('\n');

// Set just before setup writes, so a failure can say how to undo it.
String? _restoreHint;

Future<void> main(List<String> args) async {
  try {
    exitCode = await _setup(args);
  } on IOException catch (e) {
    _failed(e);
  } on FormatException catch (e) {
    _failed(e);
  }
}

void _failed(Object error) {
  stderr.writeln('Setup failed: $error');
  if (_restoreHint != null) stderr.writeln(_restoreHint);
  exitCode = 1;
}

Future<int> _setup(List<String> args) async {
  final options = <String, String>{};
  final flags = <String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (const ['--reset-git', '--dry-run', '--help', '-h'].contains(arg)) {
      flags.add(arg);
      continue;
    }
    final option = RegExp(r'^--(name|org|starter|title|model)(?:=(.*))?$')
        .firstMatch(arg);
    if (option == null) return _usageError('Unknown argument: $arg');
    final value = option.group(2) ?? (i + 1 < args.length ? args[++i] : null);
    if (value == null) return _usageError('$arg needs a value.');
    options[option.group(1) ?? ''] = value;
  }
  if (flags.contains('--help') || flags.contains('-h')) {
    stdout.writeln(_usage);
    return 0;
  }
  for (final key in ['name', 'org', 'starter']) {
    if (options.containsKey(key)) continue;
    if (!stdin.hasTerminal) return _usageError('--$key is required.');
    stdout.write(key == 'starter' ? 'starter (example or empty): ' : '$key: ');
    final line = stdin.readLineSync();
    if (line == null) return _usageError('--$key is required.');
    options[key] = line.trim();
  }
  final name = options['name'] ?? '';
  final org = options['org'] ?? '';
  final starter = options['starter'] ?? '';
  final title = options['title'] ?? defaultTitle(name);
  final model = options['model'] ?? 'server';
  final onDevice = model != 'server';

  final root = File.fromUri(Platform.script).absolute.parent.parent.path;
  final pubspecFile = File('$root/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('No pubspec.yaml next to tool/ in $root.');
    return 1;
  }
  final pubspec = pubspecFile.readAsStringSync();
  final problem =
      nameProblem(name, dependencyNames: _packageNames(root)) ??
      orgProblem(org) ??
      (const ['example', 'empty'].contains(starter)
          ? null
          : '--starter "$starter": use example or empty.') ??
      (const ['server', 'both', 'on-device'].contains(model)
          ? null
          : '--model "$model": use server, both or on-device.') ??
      titleProblem(title);
  if (problem != null) return _usageError(problem);

  if (!RegExp(
    r'^name: flutter_agentify\s*$',
    multiLine: true,
  ).hasMatch(pubspec)) {
    stderr.writeln('This project is already set up.');
    return 1;
  }
  final isGit = _inWorkTree(root);
  // At the top of the work tree, git may reset everything; in a folder of a
  // larger repository, only that folder.
  final restore = !isGit
      ? 'Setup stopped. Restore the folder from a fresh copy of the template.'
      : (_git(root, ['rev-parse', '--show-prefix']).stdout as String)
            .trim()
            .isEmpty
      ? 'Setup stopped. Restore the folder with: git reset --hard && git clean -fd'
      : 'Setup stopped. Restore the folder by running this in it: '
            'git checkout -- . && git clean -fd .';
  if (isGit) {
    final status = _git(root, ['status', '--porcelain', '--', '.']);
    if (status.exitCode != 0 || (status.stdout as String).isNotEmpty) {
      stderr.writeln(
        'Commit or stash your changes first, so a failed run can be undone.',
      );
      return 1;
    }
  }

  // Build every change in memory first, so a bad mark writes nothing.
  final id = applicationId(org, name);
  String rename(String text, String path) {
    text = text.replaceAll('com.example.flutteragentify', id);
    // Only here: docs and CI use `com.example` as a sample org.
    if (path.startsWith('macos/') || path.startsWith('windows/')) {
      text = text
          .replaceAll('com.example', org)
          .replaceAll('Amin Azirani', org);
    }
    text = text.replaceAll('package:flutter_agentify/', 'package:$name/');
    if (!_keepsFrameworkTitle(path)) {
      text = text.replaceAll('Flutter Agentify', title);
    }
    return text.replaceAll(_bareName, name);
  }

  final files = _listFiles(root, isGit);
  final writes = <String, String>{};
  final deletes = <String>{};
  final markErrors = <String>[];
  for (final path in files) {
    if (_isRemoved(path) ||
        path.startsWith('packages/') ||
        path == 'tool/upgrade.dart' ||
        path == 'LICENSE') {
      continue;
    }
    final original = _readText('$root/$path');
    if (original == null) continue;
    String text;
    try {
      text = applyMarks(
        original,
        empty: starter == 'empty',
        onDevice: onDevice,
        path: path,
      );
    } on FormatException catch (e) {
      markErrors.add(e.message);
      continue;
    }
    text = rename(text, path);
    if (path == 'AGENTS.md') text = _agentsIntro(text, title);
    if (path == 'pubspec.yaml') {
      text = text.replaceFirst(
        RegExp(r'^description:.*$', multiLine: true),
        'description: A new Flutter project.',
      );
    }
    if (path.endsWith('.dart') && text != original) text = _sortImports(text);
    if (text != original) writes[path] = text;
  }
  if (markErrors.isNotEmpty) {
    markErrors.forEach(stderr.writeln);
    return 1;
  }

  final kotlin = '$root/$_kotlinActivity';
  final kotlinTarget =
      'android/app/src/main/kotlin/${id.replaceAll('.', '/')}/MainActivity.kt';
  if (File(kotlin).existsSync() && kotlinTarget != _kotlinActivity) {
    writes[kotlinTarget] =
        writes.remove(_kotlinActivity) ?? File(kotlin).readAsStringSync();
    deletes.add(_kotlinActivity);
  }
  final license = File('$root/LICENSE');
  if (license.existsSync()) {
    writes['FLUTTER_AGENTIFY_LICENSE'] = license.readAsStringSync();
    deletes.add('LICENSE');
  }
  final readme = File('$root/tool/starters/project_readme.md');
  if (readme.existsSync()) {
    writes['README.md'] = readme
        .readAsStringSync()
        .replaceAll('{{title}}', title)
        .replaceAll('{{name}}', name);
  }
  if (starter == 'empty') {
    _emptyStarter(root, files, writes, deletes, rename);
  }
  _modelMode(root, model, writes, deletes);
  writes['tool/baselines/ratchet.json'] = File(
    '$root/tool/starters/ratchet.$starter.json',
  ).readAsStringSync();
  final removed = [
    for (final path in [..._removed, if (!onDevice) _onDevicePackage])
      if (FileSystemEntity.typeSync('$root/$path') !=
          FileSystemEntityType.notFound)
        path,
  ];

  if (flags.contains('--dry-run')) {
    stdout.writeln(
      'Setup would make these changes (dry run, nothing written):',
    );
    for (final path in writes.keys.toList()..sort()) {
      stdout.writeln('  write  $path');
    }
    for (final path in deletes.toList()..sort()) {
      stdout.writeln('  delete $path');
    }
    for (final path in removed) {
      stdout.writeln('  remove $path');
    }
    return 0;
  }

  _restoreHint = restore;
  writes.forEach((path, text) {
    File('$root/$path')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(text);
  });
  for (final path in deletes) {
    File('$root/$path').deleteSync();
    _deleteEmptyParents(root, path);
  }
  final dartFiles = [
    for (final path in writes.keys)
      if (path.endsWith('.dart')) path,
  ];
  if (dartFiles.isNotEmpty) {
    final format = Process.runSync(Platform.resolvedExecutable, [
      'format',
      ...dartFiles,
    ], workingDirectory: root);
    if (format.exitCode != 0) {
      stderr
        ..writeln(format.stdout)
        ..writeln(format.stderr)
        ..writeln(restore);
      return 1;
    }
  }

  final leftovers = <String>[];
  for (final path in _listFiles(root, isGit)) {
    if (_isRemoved(path) ||
        path.startsWith('packages/') ||
        path == 'tool/upgrade.dart' ||
        path == 'FLUTTER_AGENTIFY_LICENSE') {
      continue;
    }
    final lines = _readText('$root/$path')?.split('\n') ?? const [];
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (_keepsFrameworkTitle(path) || path == 'README.md') {
        line = line.replaceAll('Flutter Agentify', '');
      }
      if (path == 'README.md') {
        line = line.replaceAll('aazirani/flutter_agentify', '');
      }
      if (_leftover.hasMatch(line)) {
        leftovers.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
  }
  if (leftovers.isNotEmpty) {
    leftovers.forEach(stderr.writeln);
    stderr.writeln(restore);
    return 1;
  }

  for (final path in removed) {
    (FileSystemEntity.isDirectorySync('$root/$path')
            ? Directory('$root/$path')
            : File('$root/$path'))
        .deleteSync(recursive: true);
    _deleteEmptyParents(root, path);
  }
  if (flags.contains('--reset-git')) {
    final dotGit = '$root/.git';
    if (FileSystemEntity.isDirectorySync(dotGit)) {
      Directory(dotGit).deleteSync(recursive: true);
    } else if (FileSystemEntity.isFileSync(dotGit)) {
      File(dotGit).deleteSync();
    }
    final init = _git(root, ['init', '-q']);
    if (init.exitCode != 0) {
      stderr.writeln('git init failed: ${init.stderr}');
      return 1;
    }
  }
  stdout.writeln('Set up $title ($name, $id) from the $starter starter.');
  if (onDevice) {
    stdout.writeln(
      'The in-app model raises the platform floors: Android 11 (API 30) on '
      'arm64, iOS 15, macOS 14 on Apple Silicon; the web is experimental. '
      'The first build downloads the engine\'s native libraries.',
    );
  }
  if (model == 'both') {
    stdout.writeln(
      'No model server is set yet, so the assistant uses only the on-device '
      'model until you set one.',
    );
  }
  stdout.writeln(_next(name, commit: isGit || flags.contains('--reset-git')));
  return 0;
}

const _onDevicePackage = 'packages/flutter_agentify_on_device';

// Files only a project with the in-app model has.
const _onDeviceFiles = [
  'lib/ai/on_device_model.dart',
  'lib/data/repositories/prefs_load_marker.dart',
  'lib/presentation/settings/on_device_model_tile.dart',
  'test/ai/on_device_route_test.dart',
  'test/support/on_device_fixture.dart',
  'test/actions/download_on_device_model_test.dart',
  'test/actions/cancel_on_device_model_download_test.dart',
  'test/actions/delete_on_device_model_test.dart',
  'test/actions/dismiss_on_device_offer_test.dart',
  'test/actions/set_use_on_device_model_test.dart',
  'test/ai/assistant_model_switch_test.dart',
  'web/cache_api.js',
  'web/opfs_helper.js',
  'ios/Runner/Runner.entitlements',
  'integration_test/on_device_measure_test.dart',
  'tool/measure_on_device.sh',
];

const _onDeviceActions = [
  'download_on_device_model',
  'cancel_on_device_model_download',
  'delete_on_device_model',
  'dismiss_on_device_offer',
  'set_use_on_device_model',
];

const _reference = '.agents/skills/actions/references/action-reference.md';

/// [reference] without the `## <action>` sections of [actions].
String _withoutActions(String reference, List<String> actions) {
  final lines = <String>[];
  var skipping = false;
  for (final line in reference.split('\n')) {
    if (RegExp(r'^#{1,2} ').hasMatch(line)) {
      skipping = actions.any((action) => line == '## $action');
    }
    if (!skipping) lines.add(line);
  }
  return lines.join('\n');
}

/// Sets the mode in the setup file; for `server`, also takes out what only
/// the in-app model needs (the `@on-device` blocks are already gone).
void _modelMode(
  String root,
  String model,
  Map<String, String> writes,
  Set<String> deletes,
) {
  void edit(String path, String Function(String text) change) {
    final file = File('$root/$path');
    final text =
        writes[path] ?? (file.existsSync() ? file.readAsStringSync() : null);
    if (text == null) return;
    final changed = change(text);
    if (changed != text) writes[path] = changed;
  }

  final mode = switch (model) {
    'both' => 'ModelMode.both',
    'on-device' => 'ModelMode.onDevice',
    _ => 'ModelMode.server',
  };
  edit(
    'lib/ai/assistant_setup.dart',
    (t) => t.replaceFirst(RegExp(r'mode: ModelMode\.\w+'), 'mode: $mode'),
  );
  if (model != 'server') return;

  edit(
    'android/app/build.gradle.kts',
    (t) => t.replaceFirst(
      RegExp(r'minSdk = 30\b.*'),
      'minSdk = flutter.minSdkVersion',
    ),
  );
  edit(
    'macos/Runner.xcodeproj/project.pbxproj',
    (t) => t.replaceAll(
      'MACOSX_DEPLOYMENT_TARGET = 14.0;',
      'MACOSX_DEPLOYMENT_TARGET = 12.0;',
    ),
  );
  edit(
    'ios/Runner.xcodeproj/project.pbxproj',
    (t) => t.replaceAll(
      RegExp(
        r'^\s*CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;\n',
        multiLine: true,
      ),
      '',
    ),
  );
  edit(_reference, (t) => _withoutActions(t, _onDeviceActions));
  // The chat labels of the on-device actions go with them.
  final languages = Directory('$root/assets/lang');
  if (languages.existsSync()) {
    for (final file in languages.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      edit(
        'assets/lang/${file.uri.pathSegments.last}',
        (t) =>
            '${const JsonEncoder.withIndent('  ').convert((jsonDecode(t) as Map<String, Object?>)..removeWhere((key, _) => _onDeviceActions.any((a) => key == 'action_$a')))}\n',
      );
    }
  }
  for (final path in _onDeviceFiles) {
    writes
      ..remove(path)
      ..remove('$_example/$path');
    if (File('$root/$path').existsSync()) deletes.add(path);
  }
}

const _example = '.agents/example';
const _itemActions = [
  'create_item',
  'delete_item',
  'delete_items',
  'get_item',
  'list_items',
  'update_item',
];

/// Turns the planned [writes] and [deletes] into the empty starter, as
/// `tool/starters/empty/manifest.json` describes: the item example moves to
/// `.agents/example/`, replacement files go in, the language files and the
/// paths in the agent docs follow.
void _emptyStarter(
  String root,
  List<String> files,
  Map<String, String> writes,
  Set<String> deletes,
  String Function(String text, String path) rename,
) {
  final starter = '$root/tool/starters/empty';
  final manifest = jsonDecode(
    File('$starter/manifest.json').readAsStringSync(),
  ) as Map<String, Object?>;
  String read(String path) =>
      writes[path] ?? File('$root/$path').readAsStringSync();

  // 1. Move the example's files; drop the generated files next to them.
  final moved = <String>{};
  for (final entry in (manifest['move'] as List).cast<String>()) {
    for (final path in files) {
      if (entry.endsWith('/') ? !path.startsWith(entry) : path != entry) {
        continue;
      }
      writes['$_example/$path'] = read(path);
      writes.remove(path);
      deletes.add(path);
      moved.add(path);
      if (!path.endsWith('.dart')) continue;
      final base = path.substring(0, path.length - '.dart'.length);
      for (final generated in ['$base.g.dart', '$base.drift.dart']) {
        if (File('$root/$generated').existsSync()) deletes.add(generated);
      }
    }
  }

  // 2. Replacement files, and the example's README.
  for (final path in files) {
    if (!path.startsWith('tool/starters/empty/files/')) continue;
    final target = path.substring('tool/starters/empty/files/'.length);
    final text = rename(File('$root/$path').readAsStringSync(), target);
    writes[target] = target.endsWith('.dart') ? _sortImports(text) : text;
    deletes.remove(target);
  }
  writes['$_example/README.md'] = File('$starter/example_readme.md')
      .readAsStringSync();

  // 3. Language files: the example's keys go, the new screen's keys come.
  // A language the manifest has no strings for gets its first language's.
  final removeKeys = (manifest['removeTranslationKeys'] as List).cast<String>();
  final addKeys = manifest['addTranslations'] as Map<String, Object?>;
  final language = RegExp(r'^assets/lang/([^/]+)\.json$');
  for (final path in files) {
    final locale = language.firstMatch(path)?.group(1);
    if (locale == null) continue;
    final strings = jsonDecode(read(path)) as Map<String, Object?>
      ..removeWhere((key, _) => removeKeys.contains(key))
      ..addAll(
        (addKeys[locale] ?? addKeys.values.first) as Map<String, Object?>,
      );
    writes[path] = '${const JsonEncoder.withIndent('  ').convert(strings)}\n';
  }

  // 4. Paths in the agent docs that now live under .agents/example/.
  final kept = {
    ...files.where((path) => !deletes.contains(path)),
    ...writes.keys,
  };
  bool exists(Set<String> paths, String path) =>
      paths.contains(path) ||
      paths.any((p) => p.startsWith(path.endsWith('/') ? path : '$path/'));
  final example = {for (final path in moved) '$_example/$path'};
  final backticked = RegExp(r'`([A-Za-z0-9_./-]+)(:\d+)?`');
  for (final path in files) {
    if (path != 'AGENTS.md' &&
        !(path.startsWith('.agents/skills/') && path.endsWith('.md'))) {
      continue;
    }
    final text = read(path).replaceAllMapped(backticked, (m) {
      final target = m.group(1) ?? '';
      final prefix =
          moved.contains(target) ||
          (!exists(kept, target) && exists(example, '$_example/$target'));
      return prefix
          ? '`$_example/$target${m.group(2) ?? ''}`'
          : m.group(0) ?? '';
    });
    if (text != read(path)) writes[path] = text;
  }

  // 5. The action reference loses the item actions' sections.
  writes[_reference] = _withoutActions(read(_reference), _itemActions);
}

int _usageError(String message) {
  stderr
    ..writeln(message)
    ..writeln()
    ..writeln(_usage);
  return 64;
}

/// Whether [root] is in a git work tree whose files git lists. A folder the
/// larger repository ignores is treated as no repository.
bool _inWorkTree(String root) {
  try {
    return _git(root, ['rev-parse', '--is-inside-work-tree']).exitCode == 0 &&
        _listFiles(root, true).contains('pubspec.yaml');
  } on ProcessException {
    return false; // git is not installed
  }
}

ProcessResult _git(String root, List<String> args) =>
    Process.runSync('git', args, workingDirectory: root);

/// `.agents/`, `AGENTS.md` and `learnings.defaults.md` talk about the
/// framework by its name.
bool _keepsFrameworkTitle(String path) =>
    path.startsWith('.agents/') ||
    path == 'AGENTS.md' ||
    path == 'learnings.defaults.md';

bool _isRemoved(String path) => _removed.any(
  (removed) =>
      removed.endsWith('/') ? path.startsWith(removed) : path == removed,
);

/// Every package the project or its packages use: the names under
/// `dependencies:` and `dev_dependencies:` in each `pubspec.yaml`, and under
/// `packages:` in each `pubspec.lock`, at the root and in `packages/*/`.
Set<String> _packageNames(String root) {
  final names = <String>{};
  final packages = Directory('$root/packages');
  for (final dir in [
    root,
    if (packages.existsSync())
      for (final entity in packages.listSync())
        if (entity is Directory) entity.path,
  ]) {
    for (final file in ['pubspec.yaml', 'pubspec.lock']) {
      if (File('$dir/$file').existsSync()) {
        names.addAll(_dependencyNames(File('$dir/$file').readAsStringSync()));
      }
    }
  }
  return names;
}

/// Package names under `dependencies:`, `dev_dependencies:` and (in a lock
/// file) `packages:`.
Set<String> _dependencyNames(String pubspec) {
  final names = <String>{};
  var inDependencies = false;
  for (final line in const LineSplitter().convert(pubspec)) {
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
      inDependencies =
          line.startsWith('dependencies:') ||
          line.startsWith('dev_dependencies:') ||
          line.startsWith('packages:');
      continue;
    }
    final match = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
    if (inDependencies && match != null) names.add(match.group(1) ?? '');
  }
  return names;
}

/// Regular files (not links) git lists, or every file outside `.git`,
/// `.dart_tool` and `build` folders when [root] is not a git repository.
List<String> _listFiles(String root, bool isGit) {
  final Iterable<String> paths;
  if (isGit) {
    final list = _git(root, [
      'ls-files',
      '-z',
      '--cached',
      '--others',
      '--exclude-standard',
    ]);
    paths = (list.stdout as String).split('\x00');
  } else {
    paths = Directory(root)
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .map(
          (file) => file.path.substring(root.length + 1).replaceAll(r'\', '/'),
        )
        .where(
          (path) => !path
              .split('/')
              .any(
                (part) => const {'.git', '.dart_tool', 'build'}.contains(part),
              ),
        );
  }
  return [
    for (final path in paths.toSet())
      if (path.isNotEmpty &&
          FileSystemEntity.typeSync('$root/$path', followLinks: false) ==
              FileSystemEntityType.file)
        path,
  ];
}

/// The file's text, or `null` when it is not valid UTF-8.
String? _readText(String path) {
  try {
    return utf8.decode(File(path).readAsBytesSync());
  } on FormatException {
    return null;
  }
}

/// Replaces everything before the first `## ` heading with the project's own
/// introduction.
String _agentsIntro(String text, String title) {
  final rules = text.indexOf(RegExp(r'^## ', multiLine: true));
  return '# $title\n\n'
      '$title is built with Flutter Agentify: an in-app assistant and the UI '
      'share the same actions. Whatever a person can do with a button, the '
      'assistant can do by calling the same code, and every change shows a '
      'receipt. The app is in `lib/`; the framework\'s packages are in '
      '`packages/` (`flutter_agentify_core`, `flutter_agentify_ui`, '
      '`flutter_agentify_lints`).\n\n'
      '${rules < 0 ? '' : text.substring(rules)}';
}

/// Sorts each run of single-line `import 'package:…';` lines by URI, so a
/// renamed package keeps `directives_ordering` happy.
String _sortImports(String text) {
  final lines = text.split('\n');
  var start = 0;
  while (start < lines.length) {
    var end = start;
    while (end < lines.length && _packageImport.hasMatch(lines[end])) {
      end++;
    }
    if (end - start > 1) {
      final run = lines.sublist(start, end)
        ..sort((a, b) => _importUri(a).compareTo(_importUri(b)));
      lines.setRange(start, end, run);
    }
    start = end > start ? end : start + 1;
  }
  return lines.join('\n');
}

String _importUri(String line) =>
    _packageImport.firstMatch(line)?.group(1) ?? line;

/// Deletes the folders above [path] that are now empty, up to [root].
void _deleteEmptyParents(String root, String path) {
  var dir = File('$root/$path').parent;
  while (dir.path.length > root.length &&
      dir.existsSync() &&
      dir.listSync().isEmpty) {
    dir.deleteSync();
    dir = dir.parent;
  }
}
