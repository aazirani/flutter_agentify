import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../doctor.dart';

final _dumpName = RegExp(r'^drift_schema_v(\d+)\.json$');

typedef _Column = ({String type, bool nullable, bool hasDefault});
typedef _Schema = Map<String, Map<String, _Column>>;

/// Database migrations only add: no table or column is dropped, retyped or
/// made non-nullable between schema versions, and no new column on an existing
/// table is non-nullable without a default, unless
/// `drift_schemas/allowed_removals.json` lists the removal, and every new
/// version has a migration test.
///
/// Reads the JSON dumps `drift_dev schema dump` writes, so this package needs
/// no drift dependency. A rename shows up as a removal plus an addition, and
/// is reported as the removal.
class MigrationsCheck implements DoctorCheck {
  @override
  String get name => 'migrations';

  @override
  Future<CheckResult> run(DoctorContext context) async {
    final root = context.root.path;
    final dir = Directory(p.join(root, 'drift_schemas'));
    if (!dir.existsSync()) {
      return const CheckResult(CheckStatus.pass, [
        'skipped: no drift_schemas/ folder',
      ]);
    }

    final dumps = <int, File>{
      for (final file in dir.listSync().whereType<File>())
        if (_dumpName.firstMatch(p.basename(file.path)) case final match?)
          int.parse(match.group(1)!): file,
    };
    if (dumps.isEmpty) {
      return const CheckResult(CheckStatus.pass, [
        'skipped: no schema dumps in drift_schemas/',
      ]);
    }

    final versions = dumps.keys.toList()..sort();
    final problems = <String>[];
    for (var v = versions.first; v <= versions.last; v++) {
      if (!dumps.containsKey(v)) {
        problems.add('drift_schemas/drift_schema_v$v.json is missing.');
      }
    }

    final allowed = _allowedRemovals(dir);
    for (final v in versions.skip(1)) {
      final test = 'test/data/local/database/migrations/to_v${v}_test.dart';
      if (!File(p.join(root, test)).existsSync()) {
        problems.add('$test is missing: every schema version needs one.');
      }
      if (!dumps.containsKey(v - 1)) continue;
      problems.addAll(
        _differences(
          _read(dumps[v - 1]!),
          _read(dumps[v]!),
          v,
          allowed['$v'] ?? const {},
        ),
      );
    }
    return CheckResult(
      problems.isEmpty ? CheckStatus.pass : CheckStatus.fail,
      problems,
    );
  }

  Iterable<String> _differences(
    _Schema before,
    _Schema after,
    int version,
    Set<String> allowed,
  ) sync* {
    for (final MapEntry(key: table, value: columnsBefore) in before.entries) {
      final columnsAfter = after[table];
      if (columnsAfter == null) {
        if (!allowed.contains(table)) yield '$table removed in v$version';
        continue;
      }
      for (final MapEntry(key: column, value: old) in columnsBefore.entries) {
        final name = '$table.$column';
        final now = columnsAfter[column];
        if (now == null) {
          if (!allowed.contains(name)) yield '$name removed in v$version';
        } else if (now.type != old.type) {
          yield '$name changed type from ${old.type} to ${now.type} in '
              'v$version';
        } else if (old.nullable && !now.nullable) {
          yield '$name became non-nullable in v$version';
        }
      }
      for (final MapEntry(key: column, value: now) in columnsAfter.entries) {
        if (!columnsBefore.containsKey(column) &&
            !now.nullable &&
            !now.hasDefault) {
          yield '$table.$column is new, non-nullable and has no default in '
              'v$version';
        }
      }
    }
  }

  _Schema _read(File file) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    return {
      for (final entity in json['entities'] as List<Object?>)
        if (entity case {
          'type': 'table',
          'data': final Map<String, Object?> data,
        })
          data['name'] as String: {
            for (final column in data['columns'] as List<Object?>)
              if (column case {
                'name': final String name,
                'moor_type': final String type,
                'nullable': final bool nullable,
              })
                name: (
                  type: type,
                  nullable: nullable,
                  hasDefault:
                      column['default_dart'] != null ||
                      '${column['customConstraints']}'.toUpperCase().contains(
                        'DEFAULT',
                      ),
                ),
          },
    };
  }

  Map<String, Set<String>> _allowedRemovals(Directory dir) {
    final file = File(p.join(dir.path, 'allowed_removals.json'));
    if (!file.existsSync()) return const {};
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    return {
      for (final MapEntry(:key, :value) in json.entries)
        key: {...(value as List<Object?>).cast<String>()},
    };
  }
}
