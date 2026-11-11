import 'dart:convert';
import 'dart:io';

import '../actions/action_context.dart';
import '../actions/action_failure.dart';
import '../actions/action_registry.dart';
import '../secrets/redactor.dart';
import 'action_reference.dart';

const _usage = '''
Usage:
  dart run tool/action.dart --list
  dart run tool/action.dart <name> '<json>' [--approved]
  dart run tool/action.dart --write-reference''';

/// The app's action CLI: runs one action the way the assistant would, as
/// caller `cli`, so a coding agent can check behavior without the UI.
///
/// Returns 0 (ok), 1 (action failed), 64 (usage error).
Future<int> runActionCli(
  ActionRegistry registry,
  List<String> args, {
  required String referencePath,
  StringSink? out,
  StringSink? err,
}) async {
  final output = out ?? stdout;
  final errors = err ?? stderr;
  int usage([String? problem]) {
    if (problem != null) errors.writeln(problem);
    errors.writeln(_usage);
    return 64;
  }

  if (args.isEmpty) return usage();
  if (args.first == '--list' && args.length == 1) {
    for (final action in registry.all) {
      output.writeln(action.name);
    }
    return 0;
  }
  if (args.first == '--write-reference' && args.length == 1) {
    final file = File(referencePath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(buildActionReference(registry));
    output.writeln('Wrote $referencePath');
    return 0;
  }

  final name = args.first;
  final rest = args.skip(1).toList();
  final approved = rest.remove('--approved');
  if (name.startsWith('-') ||
      rest.length > 1 ||
      rest.any((a) => a.startsWith('--'))) {
    return usage();
  }
  final Object? input;
  try {
    input = jsonDecode(rest.isEmpty ? '{}' : rest.single);
  } on FormatException catch (e) {
    return usage('The input is not valid JSON: ${e.message}');
  }

  try {
    final result = await registry.call(
      name,
      input,
      caller: Caller.cli,
      approved: approved,
    );
    output.writeln(result.content);
    for (final receipt in result.receipts) {
      output.writeln('receipt: ${receipt.summary}');
    }
    return 0;
  } on ActionFailure catch (f) {
    final path = f.details?['path'];
    final message = const Redactor().redact(f.message);
    errors.writeln('${f.code}: $message${path == null ? '' : ' ($path)'}');
    return 1;
  }
}
