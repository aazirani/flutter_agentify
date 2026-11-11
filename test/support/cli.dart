import 'dart:io';

/// Runs `dart run tool/action.dart` with [args].
///
/// Each `dart run` rewrites and signs the native libraries in `.dart_tool/lib/`,
/// and test files run in parallel, so a file lock makes the runs take turns.
Future<ProcessResult> runCli(List<String> args) =>
    _locked(() => Process.run('dart', ['run', 'tool/action.dart', ...args]));

/// Deletes the action CLI's scratch database, while no other run uses it.
Future<void> resetCliDatabase() => _locked(() async {
  final db = File('.dart_tool/flutter_agentify/cli.sqlite');
  if (db.existsSync()) db.deleteSync();
});

Future<T> _locked<T>(Future<T> Function() body) async {
  final lock = File('.dart_tool/flutter_agentify/cli.lock')
    ..createSync(recursive: true);
  final handle = await lock.open(mode: FileMode.append);
  try {
    await handle.lock(FileLock.blockingExclusive);
    return await body();
  } finally {
    await handle.close();
  }
}
