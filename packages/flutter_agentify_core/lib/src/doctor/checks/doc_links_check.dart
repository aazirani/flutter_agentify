import 'dart:io';

import 'package:path/path.dart' as p;

import '../doctor.dart';

final _link = RegExp(r'!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)');
final _codeSpan = RegExp('`[^`]*`');
final _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:');

/// Every relative link in the root Markdown files, `docs/`, and the packages'
/// READMEs and `doc/` pages points at a file or folder that exists.
class DocLinksCheck implements DoctorCheck {
  @override
  String get name => 'doc-links';

  @override
  Future<CheckResult> run(DoctorContext context) async {
    final root = context.root.path;
    final problems = <String>[];
    for (final file in _markdownFiles(root)) {
      final label = p.relative(file.path, from: root).replaceAll(r'\', '/');
      problems.addAll([
        for (final (line, target) in _deadLinks(file, root))
          '$label:$line: $target does not exist',
      ]);
    }
    return CheckResult(
      problems.isEmpty ? CheckStatus.pass : CheckStatus.fail,
      problems,
    );
  }

  List<File> _markdownFiles(String root) {
    bool isMarkdown(FileSystemEntity e) => e is File && e.path.endsWith('.md');
    List<FileSystemEntity> list(String path, {bool recursive = false}) {
      final dir = Directory(path);
      return dir.existsSync()
          ? dir.listSync(recursive: recursive, followLinks: false)
          : const [];
    }

    final packages = list(p.join(root, 'packages')).whereType<Directory>();
    return [
      ...list(root).where(isMarkdown),
      ...list(p.join(root, 'docs'), recursive: true).where(isMarkdown),
      for (final package in packages) ...[
        ...list(package.path)
            .where((e) => isMarkdown(e) && p.basename(e.path) == 'README.md'),
        ...list(p.join(package.path, 'doc'), recursive: true).where(isMarkdown),
      ],
    ].cast<File>()..sort((a, b) => a.path.compareTo(b.path));
  }

  Iterable<(int, String)> _deadLinks(File file, String root) sync* {
    final folder = file.parent.path;
    String? fence;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();
      if (fence != null) {
        if (trimmed.startsWith(fence)) fence = null;
        continue;
      }
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        fence = trimmed.substring(0, 3);
        continue;
      }
      final text = lines[i].replaceAll(_codeSpan, '');
      for (final match in _link.allMatches(text)) {
        final target = match.group(1) ?? '';
        if (target.startsWith('#') || _scheme.hasMatch(target)) continue;
        var path = target.split(RegExp('[#?]')).first;
        try {
          path = Uri.decodeComponent(path);
        } on ArgumentError {
          // Not valid percent-encoding: check the path as written.
        }
        final resolved = path.startsWith('/')
            ? p.join(root, path.substring(1))
            : p.join(folder, path);
        if (!_existsExactly(resolved)) {
          yield (i + 1, target);
        }
      }
    }
  }

  /// Whether [path] exists with exactly this spelling, so `Readme.md` does
  /// not pass for `README.md` on a case-insensitive disk.
  static bool _existsExactly(String path) {
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
      return false;
    }
    final name = p.basename(path);
    if (name.isEmpty || name == '.' || name == '..') return true;
    try {
      return Directory(p.dirname(path))
          .listSync()
          .any((e) => p.basename(e.path) == name);
    } on FileSystemException {
      return true;
    }
  }
}
