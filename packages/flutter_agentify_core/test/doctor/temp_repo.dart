import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A temporary folder holding [files] (relative path to content), deleted
/// when the test ends.
Future<Directory> tempRepo(Map<String, String> files) async {
  final root = await Directory.systemTemp.createTemp('doctor_test_');
  addTearDown(() => root.delete(recursive: true));
  for (final entry in files.entries) {
    final file = File(p.join(root.path, entry.key));
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
  }
  return root;
}
