import 'dart:io';

import 'package:path/path.dart' as p;

import '../actions/action_registry.dart';
import '../cli/action_reference.dart';
import '../context/app_context.dart';
import '../context/screen_actions.dart';

const _regenerate = 'dart run tool/action.dart --write-reference';

/// What keeps the UI and the assistant equal: every action has a test, the
/// committed action reference matches the registry, and every route has a
/// screen-context entry. Empty when everything matches; otherwise one
/// message per problem. Reads files, never writes them.
List<String> parityProblems({
  required ActionRegistry registry,
  required List<String> routes,
  required Map<String, ScreenContext> screens,
  required String actionTestDir,
  required String actionReferencePath,
  Set<String> skipTestsFor = builtInActionNames,
}) {
  final problems = <String>[];
  for (final action in registry.all) {
    if (skipTestsFor.contains(action.name)) continue;
    final test = p.join(actionTestDir, '${action.name}_test.dart');
    final file = File(test);
    if (!file.existsSync()) {
      problems.add('Action "${action.name}" has no test. Create $test.');
    } else if (!file.readAsStringSync().contains(action.name)) {
      problems.add('$test never mentions "${action.name}". Test the action.');
    }
  }

  final reference = File(actionReferencePath);
  if (!reference.existsSync()) {
    problems.add(
      'The action reference $actionReferencePath is missing. Run: $_regenerate',
    );
  } else if (reference.readAsStringSync() != buildActionReference(registry)) {
    problems.add(
      'The action reference $actionReferencePath is out of date. '
      'Run: $_regenerate',
    );
  }

  for (final route in routes) {
    if (!screens.containsKey(route)) {
      problems.add(
        'Route "$route" has no screen-context entry. Add ScreenContext(...) '
        'or ScreenContext.nothing() for it.',
      );
    }
  }
  for (final key in screens.keys) {
    if (!routes.contains(key)) {
      problems.add('Screen-context entry "$key" matches no route.');
    }
  }
  return problems;
}
