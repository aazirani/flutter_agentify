import 'dart:io';

import 'package:args/args.dart';

import 'checks/agent_files_check.dart';
import 'checks/bundled_secrets_check.dart';
import 'checks/doc_links_check.dart';
import 'checks/migrations_check.dart';
import 'checks/ratchet_check.dart';
import 'checks/skills_check.dart';

/// The outcome of one check.
enum CheckStatus { pass, fail, couldNotRun }

/// What a check found. [messages] explain a failure, or add a note to a pass.
class CheckResult {
  const CheckResult(this.status, [this.messages = const []]);

  /// Whether the check passed, failed or could not run.
  final CheckStatus status;
  final List<String> messages;
}

/// What every check gets to work with.
class DoctorContext {
  const DoctorContext({
    required this.root,
    this.changedOnly = false,
    this.baseBranch = 'main',
    this.updateBaselines = false,
  });

  /// The repository root.
  final Directory root;

  /// Check only lines added compared with [baseBranch] (`--changed`).
  final bool changedOnly;
  final String baseBranch;

  /// Rewrite baseline files with the current counts (`--update-baselines`).
  final bool updateBaselines;
}

/// One named check the doctor runs.
abstract class DoctorCheck {
  String get name;

  Future<CheckResult> run(DoctorContext context);
}

/// The checks `dart run flutter_agentify_core:doctor` runs, in order.
List<DoctorCheck> defaultChecks() => [
  AgentFilesCheck(),
  SkillsCheck(),
  BundledSecretsCheck(),
  MigrationsCheck(),
  RatchetCheck(),
  DocLinksCheck(),
];

/// Runs the doctor and returns its exit code.
///
/// Flags: --only a,b  --changed  --base <branch>  --update-baselines
/// Returns 0 (all pass), 1 (any fail), 2 (any could-not-run, unknown check
/// name, bad flag).
Future<int> runDoctor(
  List<String> args, {
  Directory? root,
  StringSink? out,
  List<DoctorCheck>? checks,
}) async {
  final sink = out ?? stdout;
  final parser = ArgParser()
    ..addOption('only', help: 'Comma-separated check names to run.')
    ..addFlag('changed', negatable: false)
    ..addOption('base', defaultsTo: 'main')
    ..addFlag('update-baselines', negatable: false);

  final ArgResults options;
  try {
    options = parser.parse(args);
  } on FormatException catch (e) {
    sink.writeln('ERROR doctor: ${e.message}');
    return 2;
  }

  var selected = checks ?? defaultChecks();
  final only = options.option('only');
  if (only != null) {
    final names = only.split(',').map((n) => n.trim()).toSet()..remove('');
    final known = selected.map((c) => c.name).toSet();
    final unknown = names.difference(known);
    if (unknown.isNotEmpty) {
      sink.writeln(
        'ERROR doctor: unknown check ${unknown.join(', ')} '
        '(known: ${known.join(', ')})',
      );
      return 2;
    }
    selected = [
      for (final c in selected)
        if (names.contains(c.name)) c,
    ];
  }

  final context = DoctorContext(
    root: root ?? Directory.current,
    changedOnly: options.flag('changed'),
    baseBranch: options.option('base')!,
    updateBaselines: options.flag('update-baselines'),
  );

  var code = 0;
  for (final check in selected) {
    CheckResult result;
    try {
      result = await check.run(context);
    } catch (e) {
      result = CheckResult(CheckStatus.couldNotRun, ['$e']);
    }
    final label = switch (result.status) {
      CheckStatus.pass => 'PASS',
      CheckStatus.fail => 'FAIL',
      CheckStatus.couldNotRun => 'ERROR',
    };
    sink.writeln('$label ${check.name}');
    for (final message in result.messages) {
      sink.writeln('  $message');
    }
    if (result.status == CheckStatus.couldNotRun) {
      code = 2;
    } else if (result.status == CheckStatus.fail && code == 0) {
      code = 1;
    }
  }
  return code;
}
