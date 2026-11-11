import 'dart:io';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/parity.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../actions/fake_action.dart';
import '../doctor/temp_repo.dart';

void main() {
  final appContext = AppContext(screens: const {});
  final registry = ActionRegistry([
    addNote(),
    echo(),
    ViewScreenAction(appContext),
  ]);
  final screens = {
    '/': const ScreenContext.nothing(),
    '/notes/:id': const ScreenContext.nothing(),
  };

  Future<Directory> repo({bool tests = true, String? reference}) => tempRepo({
    if (tests) 'test/actions/add_note_test.dart': '// add_note',
    if (tests) 'test/actions/echo_test.dart': '// echo',
    'docs/actions.md': reference ?? buildActionReference(registry),
  });

  List<String> problems(
    Directory root, {
    List<String>? routes,
    Map<String, ScreenContext>? table,
    String reference = 'docs/actions.md',
  }) => parityProblems(
    registry: registry,
    routes: routes ?? ['/', '/notes/:id'],
    screens: table ?? screens,
    actionTestDir: p.join(root.path, 'test', 'actions'),
    actionReferencePath: p.join(root.path, reference),
  );

  test('no problems when tests, reference and screens all match', () async {
    expect(problems(await repo()), isEmpty);
  });

  test(
    'reports an action without a test file, with the expected path',
    () async {
      final root = await repo(tests: false);
      final found = problems(root);
      expect(found, hasLength(2));
      expect(
        found.first,
        contains(p.join(root.path, 'test', 'actions', 'add_note_test.dart')),
      );
    },
  );

  test('does not ask for test files for built-in actions', () async {
    expect(
      problems(await repo()).where((m) => m.contains('view_screen')),
      isEmpty,
    );
  });

  test('reports a reference that differs from the generated one', () async {
    final found = problems(await repo(reference: 'old'));
    expect(
      found.single,
      contains('dart run tool/action.dart --write-reference'),
    );
  });

  test('reports a missing reference file', () async {
    final found = problems(await repo(), reference: 'docs/missing.md');
    expect(found.single, contains('missing'));
    expect(found.single, contains('--write-reference'));
  });

  test('reports a route without a screen-context entry', () async {
    final found = problems(
      await repo(),
      routes: ['/', '/notes/:id', '/settings'],
    );
    expect(found.single, contains('/settings'));
  });

  test('reports a screen-context key that is not a route', () async {
    final found = problems(await repo(), routes: ['/']);
    expect(found.single, contains('/notes/:id'));
  });

  test('never writes files', () async {
    final root = await repo(tests: false, reference: 'old');
    final before = _snapshot(root);
    problems(root);
    expect(_snapshot(root), before);
  });
}

Map<String, String> _snapshot(Directory root) => {
  for (final f in root.listSync(recursive: true).whereType<File>())
    f.path: f.readAsStringSync(),
};
