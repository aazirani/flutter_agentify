import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

/// Searches this package's own `doc/` pages, which match the installed
/// version.
///
/// `--query "<words>"` prints `<file>:<line>: <text>` for each line holding
/// every word (case-insensitive); `--list` prints the page names. Returns 0,
/// 1 when nothing matches, 64 for a usage error.
Future<int> runDocsSearch(
  List<String> args, {
  Directory? docDir,
  StringSink? out,
  StringSink? err,
}) async {
  final output = out ?? stdout;
  final errors = err ?? stderr;
  final dir = docDir ?? await _packageDocs();
  if (dir == null || !dir.existsSync()) {
    errors.writeln('Could not find the flutter_agentify_core doc/ folder.');
    return 64;
  }
  final pages =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (args.length == 1 && args.single == '--list') {
    for (final page in pages) {
      output.writeln(p.basename(page.path));
    }
    return 0;
  }
  if (args.length != 2 || args.first != '--query' || args.last.trim().isEmpty) {
    errors.writeln(
      'Usage: dart run flutter_agentify_core:docs --query "<words>" | --list',
    );
    return 64;
  }

  final words = args.last
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  var found = 0;
  for (final page in pages) {
    final lines = page.readAsLinesSync();
    for (final (i, line) in lines.indexed) {
      final lower = line.toLowerCase();
      if (words.every(lower.contains)) {
        output.writeln('${p.basename(page.path)}:${i + 1}: $line');
        found++;
      }
    }
  }
  return found == 0 ? 1 : 0;
}

Future<Directory?> _packageDocs() async {
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:flutter_agentify_core/flutter_agentify_core.dart'),
  );
  if (library == null) return null;
  return Directory(p.join(p.dirname(p.dirname(library.toFilePath())), 'doc'));
}
