@Tags(['template'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_agentify_core/doctor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/setup.dart';
import 'template_copy.dart';

/// The files git lists in [dir] (tracked or new), as paths relative to it.
List<String> _files(Directory dir) {
  final list = Process.runSync('git', [
    'ls-files',
    '-z',
    '--cached',
    '--others',
    '--exclude-standard',
  ], workingDirectory: dir.path);
  return [
    for (final path in (list.stdout as String).split('\x00'))
      if (path.isNotEmpty &&
          FileSystemEntity.typeSync('${dir.path}/$path', followLinks: false) ==
              FileSystemEntityType.file)
        path,
  ];
}

/// `path:line` for each line of a listed text file in [dir] that matches
/// [pattern], skipping paths that start with an entry of [outside].
List<String> _grep(
  Directory dir,
  RegExp pattern, {
  List<String> outside = const [],
}) {
  final hits = <String>[];
  for (final path in _files(dir)) {
    if (outside.any(path.startsWith)) continue;
    final String text;
    try {
      text = utf8.decode(File('${dir.path}/$path').readAsBytesSync());
    } on FormatException {
      continue;
    }
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) hits.add('$path:${i + 1}');
    }
  }
  return hits;
}

const _validArgs = ['--name', 'a_b', '--org', 'com.acme', '--starter'];

/// Fails when a Dart file under `lib`, `test` or `tool` in [dir] is not
/// formatted.
Future<void> _expectFormatted(Directory dir) async {
  final fmt = await Process.run('dart', [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    'lib',
    'test',
    'tool',
  ], workingDirectory: dir.path);
  expect(fmt.exitCode, 0, reason: '${fmt.stdout}');
}

/// Fails when the ratchet baseline in [dir] differs from what `lib/` holds.
void _expectHonestBaseline(Directory dir) {
  final totals = {'ignore_comments': 0, 'null_assertions': 0, 'dynamic': 0};
  final lib = Directory('${dir.path}/lib');
  for (final file in lib.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') ||
        file.path.endsWith('.g.dart') ||
        file.path.endsWith('.drift.dart')) {
      continue;
    }
    countRatchets(file.readAsStringSync()).forEach((key, count) {
      totals[key] = (totals[key] ?? 0) + count;
    });
  }
  final baseline = jsonDecode(
    File('${dir.path}/tool/baselines/ratchet.json').readAsStringSync(),
  ) as Map<String, Object?>;
  expect(baseline['scope'], 'app');
  expect({for (final key in totals.keys) key: baseline[key]}, totals);
}

/// Names of the item example: none may remain outside `.agents/example/`
/// in an empty project.
final _itemIdentifiers = RegExp(
  r'ExampleItems|ExampleDao|example_(dao|table)|ItemsRepository|items_(actions|provider|repository)|'
  r'itemsProvider|selectedItemIds|\b(ListItems|GetItem|CreateItem|UpdateItem|DeleteItem|DeleteItems)\b|'
  r'\b(list_items|get_item|create_item|update_item|delete_item|delete_items)\b|'
  r'\b(add_item|no_items|empty_items_hint|item_title|item_description)\b|entities/item\.dart',
);

void main() {
  test('names', () {
    expect(nameProblem('notes_app'), isNull);
    for (final bad in [
      'Notes',
      '1app',
      'my-app',
      'class',
      'flutter_agentify',
      'flutter_agentify_notes',
      '',
    ]) {
      expect(nameProblem(bad), isNotNull, reason: bad);
    }
    expect(nameProblem('drift', dependencyNames: {'drift'}), contains('drift'));
    expect(nameProblem('flutter'), isNotNull);
    expect(nameProblem('test'), isNotNull);
    // Kotlin and Java keywords break the Android package.
    expect(nameProblem('fun'), isNotNull);
    expect(nameProblem('i_n'), isNotNull);
  });

  test('orgs', () {
    expect(orgProblem('com.acme'), isNull);
    for (final bad in [
      'acme',
      'com.Acme',
      'com.my-co',
      'com.1st',
      'com.',
      'in.co.acme',
      'com.int',
    ]) {
      expect(orgProblem(bad), isNotNull, reason: bad);
    }
  });

  test('titles', () {
    expect(titleProblem('Notes App 2'), isNull);
    for (final bad in ['Tom & Co', 'Say "hi"', 'a<b', 'x;y', '']) {
      expect(titleProblem(bad), isNotNull, reason: bad);
    }
    expect(defaultTitle('notes_app'), 'Notes App');
    expect(applicationId('com.acme', 'notes_app'), 'com.acme.notesapp');
  });

  test('marks', () {
    const src =
        'a\n  // @example:begin\n  b\n  // @example:end\n'
        '  // @empty: c\n<!-- @template:begin -->\nd\n<!-- @template:end -->\ne\n';
    expect(applyMarks(src, empty: false, path: 'f'), 'a\n  b\ne\n');
    expect(applyMarks(src, empty: true, path: 'f'), 'a\n  c\ne\n');
    expect(
      () =>
          applyMarks('// @example:begin\nx\n', empty: true, path: 'lib/f.dart'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('lib/f.dart'),
        ),
      ),
    );
    expect(
      () => applyMarks('# @template:end\n', empty: false, path: 'f'),
      throwsFormatException,
    );
  });

  test('on-device marks keep their content only with the in-app model', () {
    const src = 'a\n// @on-device:begin\nb\n// @on-device:end\nc\n';
    expect(applyMarks(src, empty: false, path: 'f'), 'a\nc\n');
    expect(
      applyMarks(src, empty: false, onDevice: true, path: 'f'),
      'a\nb\nc\n',
    );
  });

  group('--model', () {
    /// Every text file in [dir] outside packages/ and the lock file that
    /// matches [pattern], as `path: line`.
    List<String> matches(Directory dir, Pattern pattern) => [
      for (final file in dir.listSync(recursive: true).whereType<File>())
        if (!file.path.contains('/.git/') &&
            !file.path.contains('/packages/') &&
            !file.path.endsWith('pubspec.lock'))
          for (final line in _lines(file))
            if (line.contains(pattern))
              '${file.path.substring(dir.path.length + 1)}: $line',
    ];
    String mode(Directory dir) =>
        RegExp(r'mode: (ModelMode\.\w+)')
            .firstMatch(
              File('${dir.path}/lib/ai/assistant_setup.dart')
                  .readAsStringSync(),
            )
            ?.group(1) ??
        '';

    test('server (the default) leaves no engine and no raised floor', () async {
      final dir = await templateCopy();
      final r = await runSetup(dir, [..._validArgs, 'example']);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(mode(dir), 'ModelMode.server');
      for (final pattern in [
        'flutter_edge_ai',
        'flutter_agentify_on_device',
        '@on-device:',
        'MACOSX_DEPLOYMENT_TARGET = 14.0',
        'minSdk = 30',
        'Runner.entitlements',
        'opfs_helper.js',
        // No in-app model code is left behind unused.
        'OnDeviceModelController',
        'LoadedOnDeviceModel',
        'LoadMarker',
        'FakeOnDeviceEngine',
        'onDeviceModel',
      ]) {
        // The gate and upgrade handle the package only when it is there.
        final found = matches(dir, pattern).where(
          (m) =>
              !m.startsWith('tool/check.sh:') &&
              !m.startsWith('tool/upgrade.dart:'),
        );
        expect(found, isEmpty, reason: pattern);
      }
      expect(
        Directory('${dir.path}/packages/flutter_agentify_on_device')
            .existsSync(),
        isFalse,
      );
      expect(File('${dir.path}/web/cache_api.js').existsSync(), isFalse);
      expect(
        File('${dir.path}/ios/Runner/Runner.entitlements').existsSync(),
        isFalse,
      );
      expect(matches(dir, 'MACOSX_DEPLOYMENT_TARGET = 12.0'), isNotEmpty);
      expect(matches(dir, 'minSdk = flutter.minSdkVersion'), isNotEmpty);
      expect(matches(dir, 'download_on_device_model'), isEmpty);
      _expectHonestBaseline(dir);
    });

    test('both keeps the engine and sets ModelMode.both', () async {
      final dir = await templateCopy();
      final r = await runSetup(dir, [
        ..._validArgs,
        'empty',
        '--model',
        'both',
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(mode(dir), 'ModelMode.both');
      expect(matches(dir, '@on-device:'), isEmpty);
      expect(matches(dir, 'flutter_agentify_on_device'), isNotEmpty);
      expect(matches(dir, 'MACOSX_DEPLOYMENT_TARGET = 14.0'), isNotEmpty);
      expect(File('${dir.path}/web/opfs_helper.js').existsSync(), isTrue);
      expect(
        r.stdout,
        allOf(
          contains('macOS 14'),
          contains(
            'No model server is set yet, so the assistant uses only the '
            'on-device model until you set one.',
          ),
        ),
      );
      _expectHonestBaseline(dir);
    });

    test('on-device sets ModelMode.onDevice', () async {
      final dir = await templateCopy();
      final r = await runSetup(dir, [
        ..._validArgs,
        'example',
        '--model',
        'on-device',
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(mode(dir), 'ModelMode.onDevice');
      expect(r.stdout, isNot(contains('No model server is set yet')));
    });

    test('anything else is a usage error', () async {
      final dir = await templateCopy();
      final r = await runSetup(dir, [
        ..._validArgs,
        'example',
        '--model',
        'nope',
      ]);
      expect(r.exitCode, 64);
      expect(r.stderr, contains('--model'));
    });
  });

  for (final name in ['acme_notes', 'zeta_app']) {
    // One sorts before "flutter" and one after, so imports must be re-sorted.
    test('example starter as $name', () async {
      final dir = await templateCopy();
      final r = await runSetup(dir, [
        '--name',
        name,
        '--org',
        'com.acme',
        '--starter',
        'example',
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      // The commit comes first, so the gate and a later upgrade see a clean
      // tree; `flutter run` blocks, so it is not one of the steps.
      expect(
        r.stdout,
        contains(
          'Next:\n'
          '  git add -A && git commit -m "Set up $name"\n'
          '  flutter pub get\n'
          '  dart run build_runner build\n'
          '  tool/check.sh\n'
          'Try the app: flutter run\n',
        ),
      );
      // names
      expect(
        File('${dir.path}/pubspec.yaml').readAsStringSync(),
        contains('name: $name\n'),
      );
      expect(
        _grep(
          dir,
          RegExp(
            r'package:flutter_agentify/|aminazirani|aazirani|Amin Azirani|flutteragentify',
          ),
          outside: [
            'packages/',
            'tool/upgrade.dart',
            'README.md',
            'FLUTTER_AGENTIFY_LICENSE',
          ],
        ),
        isEmpty,
      );
      expect(
        _grep(
          dir,
          RegExp('@(example|template|empty):'),
          outside: ['packages/'],
        ),
        isEmpty,
      );
      // Kotlin folder
      final id = name.replaceAll('_', '');
      expect(
        File(
          '${dir.path}/android/app/src/main/kotlin/com/acme/$id/MainActivity.kt',
        ).existsSync(),
        isTrue,
      );
      expect(
        Directory('${dir.path}/android/app/src/main/kotlin/com/example')
            .existsSync(),
        isFalse,
      );
      // `com.example` outside the native folders is a sample org, kept.
      expect(
        File('${dir.path}/tool/upgrade.dart').readAsStringSync(),
        contains("'com.example'"),
      );
      // framework-only files
      for (final gone in [
        'docs',
        'CHANGELOG.md',
        'CONTRIBUTING.md',
        'CODE_OF_CONDUCT.md',
        'SECURITY.md',
        'LICENSE',
        '.github/ISSUE_TEMPLATE',
        '.github/PULL_REQUEST_TEMPLATE.md',
        'tool/setup.dart',
        'tool/starters',
        'tool/check_template.sh',
        'test/template',
      ]) {
        expect(
          FileSystemEntity.typeSync('${dir.path}/$gone'),
          FileSystemEntityType.notFound,
          reason: gone,
        );
      }
      expect(File('${dir.path}/FLUTTER_AGENTIFY_LICENSE').existsSync(), isTrue);
      expect(
        File('${dir.path}/README.md').readAsStringSync(),
        startsWith('# ${defaultTitle(name)}\n'),
      );
      // agent file
      final agents = File('${dir.path}/AGENTS.md').readAsStringSync();
      expect(agents, startsWith('# ${defaultTitle(name)}\n'));
      expect(agents, isNot(contains('not set up yet')));
      expect(agents.length, lessThan(6000));
      // ratchet
      expect(
        File('${dir.path}/tool/baselines/ratchet.json').readAsStringSync(),
        contains('"scope": "app"'),
      );
      // imports stay sorted, so directives_ordering keeps passing
      final packageImport = RegExp(r"^import 'package:([^']*)'");
      for (final path in _files(dir).where((p) => p.endsWith('.dart'))) {
        if (path.startsWith('packages/')) continue;
        String? previous;
        for (final line in File('${dir.path}/$path').readAsLinesSync()) {
          final uri = packageImport.firstMatch(line)?.group(1);
          if (uri != null && previous != null) {
            expect(uri.compareTo(previous), greaterThan(0), reason: path);
          }
          previous = uri;
        }
      }
      await _expectFormatted(dir);
      final ci = File('${dir.path}/.github/workflows/flutter-ci.yml')
          .readAsStringSync();
      expect(
        ci,
        allOf(
          contains('tool/check.sh'),
          contains('flutter build'),
          isNot(contains('setup.dart')),
          isNot(contains('matrix.starter')),
        ),
      );
    });
  }

  for (final name in ['acme_notes', 'zeta_app']) {
    test('empty starter as $name', () async {
      final dir = await templateCopy();
      final r = await runSetup(dir, [
        '--name',
        name,
        '--org',
        'com.acme',
        '--starter',
        'empty',
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(
        _grep(dir, _itemIdentifiers).where(
          (hit) => const [
            'lib/',
            'test/',
            'tool/',
            'assets/',
            'AGENTS.md',
          ].any(hit.startsWith),
        ),
        isEmpty,
      );
      expect(
        _grep(
          dir,
          RegExp('@(example|template|empty):'),
          outside: ['packages/'],
        ),
        isEmpty,
      );
      final example = '${dir.path}/.agents/example';
      expect(
        File('$example/lib/domain/actions/items_actions.dart').existsSync(),
        isTrue,
      );
      expect(File('$example/README.md').existsSync(), isTrue);
      expect(
        File('$example/drift_schemas/drift_schema_v1.json').existsSync(),
        isTrue,
      );
      expect(
        Directory('${dir.path}/drift_schemas')
            .listSync()
            .map((e) => e.path.split('/').last)
            .toList(),
        ['drift_schema_v1.json'],
      );
      expect(
        File('${dir.path}/test/generated_migrations/schema_v1.dart')
            .existsSync(),
        isTrue,
      );
      expect(
        Directory('${dir.path}/test/data/local/database/migrations')
            .existsSync(),
        isFalse,
      );
      expect(
        File('${dir.path}/lib/data/local/database/app_database.dart')
            .readAsStringSync(),
        allOf(contains('schemaVersion => 1'), isNot(contains('ExampleItems'))),
      );
      // skills point at files that exist
      expect(
        File('${dir.path}/.agents/skills/actions/SKILL.md').readAsStringSync(),
        contains('`.agents/example/lib/domain/actions/items_actions.dart`'),
      );
      expect(
        File('${dir.path}/AGENTS.md').readAsStringSync(),
        contains('`test/generated_migrations/`'),
      );
      final pubGet = await Process.run('flutter', [
        'pub',
        'get',
      ], workingDirectory: dir.path);
      expect(pubGet.exitCode, 0, reason: '${pubGet.stdout}${pubGet.stderr}');
      final doctor = await Process.run('dart', [
        'run',
        'flutter_agentify_core:doctor',
        '--only',
        'skills,agent-files',
      ], workingDirectory: dir.path);
      expect(doctor.exitCode, 0, reason: '${doctor.stdout}');
      // translations
      final languages = [
        for (final file in Directory('${dir.path}/assets/lang').listSync())
          if (file.path.endsWith('.json'))
            (jsonDecode(
              File(file.path).readAsStringSync(),
            ) as Map<String, Object?>).keys.toSet(),
      ];
      expect(languages, isNotEmpty);
      for (final keys in languages) {
        expect(keys, contains('home_intro'));
        expect(keys, isNot(contains('add_item')));
        expect(keys, languages.first);
      }
      // reference
      expect(
        File(
          '${dir.path}/.agents/skills/actions/references/action-reference.md',
        ).readAsStringSync(),
        allOf(contains('set_language'), isNot(contains('create_item'))),
      );
      await _expectFormatted(dir);
      _expectHonestBaseline(dir);
      final ci = File('${dir.path}/.github/workflows/flutter-ci.yml')
          .readAsStringSync();
      expect(
        ci,
        allOf(
          contains('tool/check.sh'),
          contains('flutter build'),
          isNot(contains('setup.dart')),
          isNot(contains('matrix.starter')),
        ),
      );
    });
  }

  test('the workflow tests the template and builds a created project', () {
    final ci = File('.github/workflows/flutter-ci.yml').readAsStringSync();
    expect(ci, contains(r'--starter ${{ matrix.starter }}'));
    expect(ci, contains('--starter empty'));
  });

  test('a path with a line suffix keeps it when prefixed', () async {
    final dir = await templateCopy();
    File('${dir.path}/.agents/skills/actions/SKILL.md').writeAsStringSync(
      '\nSee `lib/domain/actions/items_actions.dart:12`.\n',
      mode: FileMode.append,
    );
    await git(dir, ['commit', '-q', '-am', 'Line suffix']);
    final r = await runSetup(dir, [..._validArgs, 'empty']);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(
      File('${dir.path}/.agents/skills/actions/SKILL.md').readAsStringSync(),
      contains('`.agents/example/lib/domain/actions/items_actions.dart:12`'),
    );
  });

  test('refusals and usage', () async {
    final dir = await templateCopy();
    Future<int> code(List<String> a) async => (await runSetup(dir, a)).exitCode;
    // No terminal: usage, no prompt.
    expect(await code([]), 64);
    // --starter has no default.
    expect(await code(['--name', 'a_b', '--org', 'com.acme']), 64);
    expect(
      await code([
        '--name',
        'Bad',
        '--org',
        'com.acme',
        '--starter',
        'example',
      ]),
      64,
    );
    expect(
      await code([
        '--name',
        'drift',
        '--org',
        'com.acme',
        '--starter',
        'example',
      ]),
      64,
    );
    expect(await code([..._validArgs, 'example', '--title', 'Tom & Co']), 64);
    // A direct dependency of a package, and a package only the lock files
    // name: `pub get` would fail later.
    for (final name in ['http', 'collection']) {
      final r = await runSetup(dir, [
        '--name',
        name,
        '--org',
        'com.acme',
        '--starter',
        'example',
      ]);
      expect(r.exitCode, 64, reason: name);
      expect(r.stderr, contains('--name "$name" is the name of a package'));
    }
    final help = await runSetup(dir, ['--help']);
    expect(help.exitCode, 0);
    // The rule of each flag a value can break.
    expect(
      help.stdout,
      allOf(
        contains('Dart reserved word'),
        contains('Kotlin or Java'),
        contains('spaces, ".", "_" and "-"'),
      ),
    );
    final status = await git(dir, ['status', '--porcelain']);
    // None of the above wrote anything.
    expect(status.stdout, isEmpty);
  });

  test('standard input at its end asks for the flag, not a value', () async {
    final dir = await templateCopy();
    // On macOS, /dev/null counts as a terminal that reads nothing.
    final r = await Process.run('sh', [
      '-c',
      'dart tool/setup.dart < /dev/null',
    ], workingDirectory: dir.path);
    expect(r.exitCode, 64);
    expect(r.stderr, contains('--name is required.'));
    expect(r.stderr, contains('Usage:'));
    expect((await git(dir, ['status', '--porcelain'])).stdout, isEmpty);
  });

  test('outside git, Next has no commit step', () async {
    final dir = await templateCopy();
    Directory('${dir.path}/.git').deleteSync(recursive: true);
    final r = await runSetup(dir, [..._validArgs, 'example']);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(r.stdout, contains('Next:\n  flutter pub get\n'));
    expect(r.stdout, isNot(contains('git commit')));
  });

  test('--dry-run prints changes and writes nothing', () async {
    final dir = await templateCopy();
    final r = await runSetup(dir, [..._validArgs, 'example', '--dry-run']);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(r.stdout, contains('pubspec.yaml'));
    expect((await git(dir, ['status', '--porcelain'])).stdout, isEmpty);
  });

  test('uncommitted changes are refused', () async {
    final dir = await templateCopy();
    File('${dir.path}/README.md')
        .writeAsStringSync('\nMore.\n', mode: FileMode.append);
    final r = await runSetup(dir, [..._validArgs, 'example']);
    expect(r.exitCode, 1);
    expect(r.stderr, contains('Commit or stash'));
  });

  test('a second run says already set up', () async {
    final dir = await templateCopy();
    final first = await runSetup(dir, [..._validArgs, 'example']);
    expect(first.exitCode, 0, reason: '${first.stdout}\n${first.stderr}');
    await git(dir, ['add', '-A']);
    await git(dir, ['commit', '-q', '-m', 'Set up']);
    // Setup deleted itself; put it back to run it again.
    File('tool/setup.dart').copySync('${dir.path}/tool/setup.dart');
    final second = await runSetup(dir, [..._validArgs, 'example']);
    expect(second.exitCode, 1);
    expect('${second.stdout}${second.stderr}', contains('already set up'));
  });

  test('works when started from another folder', () async {
    final dir = await templateCopy();
    final r = await Process.run('dart', [
      '${dir.path}/tool/setup.dart',
      ..._validArgs,
      'example',
    ], workingDirectory: Directory.systemTemp.path);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(
      File('${dir.path}/pubspec.yaml').readAsStringSync(),
      contains('name: a_b'),
    );
  });

  test(
    'a leftover it cannot place stops setup and says how to restore',
    () async {
      final dir = await templateCopy();
      // No replacement touches this file's text.
      File('${dir.path}/notes.txt')
          .writeAsStringSync('see aazirani on GitHub\n');
      await git(dir, ['add', '-A']);
      await git(dir, ['commit', '-q', '-m', 'Notes']);
      final r = await runSetup(dir, [..._validArgs, 'example']);
      expect(r.exitCode, 1);
      final output = '${r.stdout}${r.stderr}';
      expect(output, contains('notes.txt:1'));
      expect(output, contains('git reset --hard && git clean -fd'));
    },
  );

  test(
    'inside a larger repository, only the folder is checked and restored',
    () async {
      final copy = await templateCopy();
      File('${copy.path}/notes.txt')
          .writeAsStringSync('see aazirani on GitHub\n');
      await git(copy, ['add', '-A']);
      await git(copy, ['commit', '-q', '-m', 'Notes']);
      final parent = await Directory.systemTemp.createTemp('template_parent_');
      addTearDown(() => parent.delete(recursive: true));
      await git(parent, ['clone', '-q', copy.path, 'app']);
      Directory('${parent.path}/app/.git').deleteSync(recursive: true);
      await git(parent, ['init', '-q']);
      await git(parent, ['add', '-A']);
      await git(parent, ['commit', '-q', '-m', 'Parent']);
      // Unrelated work outside the folder neither blocks setup nor is touched.
      File('${parent.path}/other.txt').writeAsStringSync('unrelated work\n');
      final r = await runSetup(Directory('${parent.path}/app'), [
        ..._validArgs,
        'example',
      ]);
      expect(r.exitCode, 1);
      final output = '${r.stdout}${r.stderr}';
      expect(output, contains('notes.txt:1'));
      expect(output, contains('git checkout -- . && git clean -fd .'));
      expect(output, isNot(contains('git reset --hard')));
    },
  );

  test('a failure it did not expect exits 1 with a message', () async {
    final dir = await templateCopy();
    File('${dir.path}/tool/starters/ratchet.example.json').deleteSync();
    await git(dir, ['commit', '-q', '-am', 'No baseline']);
    final r = await runSetup(dir, [..._validArgs, 'example']);
    expect(r.exitCode, 1, reason: '${r.stdout}\n${r.stderr}');
    expect(r.stderr, contains('Setup failed:'));
  });

  test('--reset-git leaves a fresh repository', () async {
    final dir = await templateCopy();
    final r = await runSetup(dir, [..._validArgs, 'example', '--reset-git']);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(Directory('${dir.path}/.git').existsSync(), isTrue);
    expect((await git(dir, ['log'])).exitCode, isNot(0));
    expect(r.stdout, contains('git add -A && git commit -m "Set up a_b"'));
  });

  test('the example baseline matches the created project', () async {
    final dir = await templateCopy();
    final r = await runSetup(dir, [..._validArgs, 'example']);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    _expectHonestBaseline(dir);
  });
}

/// [file]'s lines, or none when it is not text.
List<String> _lines(File file) {
  try {
    return file.readAsLinesSync();
  } on FileSystemException {
    return const [];
  }
}
