import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../secrets/secret_patterns.dart';
import '../doctor.dart';
import '../git_diff.dart';

/// Nothing secret ships inside the app: assets listed under `flutter.assets`
/// in `pubspec.yaml` hold no key-looking text and no `.env` files, and
/// neither does the Dart source of the packages under `packages/`.
///
/// The `no_secret_literals` lint covers the app's own Dart source; it cannot
/// cover `packages/`, which keep their own analysis options. Package source
/// honors the lint's opt-out comment on the line or the line above.
class BundledSecretsCheck implements DoctorCheck {
  @override
  String get name => 'bundled-secrets';

  @override
  Future<CheckResult> run(DoctorContext context) async {
    final root = context.root.path;
    final changed = context.changedOnly
        ? (await addedLines(context.root, context.baseBranch)).keys.toSet()
        : null;

    final problems = <String>[];
    for (final file in _assetFiles(root)) {
      final path = p.relative(file.path, from: root).replaceAll(r'\', '/');
      if (changed != null && !changed.contains(path)) continue;
      final fileName = p.basename(path);
      if (fileName == '.env' || fileName.startsWith('.env.')) {
        problems.add('$path is an .env file and must not be bundled.');
      } else if (looksLikeSecret(latin1.decode(file.readAsBytesSync()))) {
        problems.add('$path contains text shaped like an API key.');
      }
    }
    for (final file in _packageSources(root)) {
      final path = p.relative(file.path, from: root).replaceAll(r'\', '/');
      if (changed != null && !changed.contains(path)) continue;
      if (_hasSecret(file.readAsLinesSync())) {
        problems.add('$path contains text shaped like an API key.');
      }
    }
    return CheckResult(
      problems.isEmpty ? CheckStatus.pass : CheckStatus.fail,
      problems,
    );
  }

  static const _optOut = 'ignore: flutter_agentify_lints/no_secret_literals';

  bool _hasSecret(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      final optedOut =
          lines[i].contains(_optOut) ||
          (i > 0 && lines[i - 1].contains(_optOut));
      if (!optedOut && looksLikeSecret(lines[i])) return true;
    }
    return false;
  }

  /// Dart files in each package's `lib`, `bin`, `test` and `tool` folders.
  Iterable<File> _packageSources(String root) sync* {
    final packages = Directory(p.join(root, 'packages'));
    if (!packages.existsSync()) return;
    for (final package in packages.listSync().whereType<Directory>()) {
      for (final folder in ['lib', 'bin', 'test', 'tool']) {
        final dir = Directory(p.join(package.path, folder));
        if (!dir.existsSync()) continue;
        yield* dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
      }
    }
  }

  /// Files the app bundles: an entry ending in `/` means the files directly
  /// inside that folder. Entries that do not exist are skipped.
  List<File> _assetFiles(String root) {
    final pubspec = loadYaml(
      File(p.join(root, 'pubspec.yaml')).readAsStringSync(),
    );
    final flutter = pubspec is YamlMap ? pubspec['flutter'] : null;
    final assets = flutter is YamlMap ? flutter['assets'] : null;
    if (assets is! YamlList) return const [];

    final files = <File>[];
    for (final entry in assets) {
      final path = switch (entry) {
        String() => entry,
        YamlMap() when entry['path'] is String => entry['path'] as String,
        _ => null,
      };
      if (path == null) continue;
      if (path.endsWith('/')) {
        final dir = Directory(p.join(root, path));
        if (dir.existsSync()) files.addAll(dir.listSync().whereType<File>());
      } else {
        final file = File(p.join(root, path));
        if (file.existsSync()) files.add(file);
      }
    }
    return files;
  }
}
