import 'dart:convert';

import 'package:flutter_agentify_core/doctor.dart';
import 'package:test/test.dart';

import 'temp_repo.dart';

typedef _Column = ({String type, bool nullable});

/// A drift schema dump in the shape `drift_dev schema dump` writes.
String _dump(Map<String, Map<String, _Column>> tables) => jsonEncode({
  '_meta': {'version': '1.3.0'},
  'entities': [
    for (final (i, table) in tables.entries.indexed)
      {
        'id': i,
        'type': 'table',
        'data': {
          'name': table.key,
          'columns': [
            for (final column in table.value.entries)
              {
                'name': column.key,
                'moor_type': column.value.type,
                'nullable': column.value.nullable,
              },
          ],
        },
      },
    {
      'id': tables.length,
      'type': 'index',
      'data': {'name': 'some_index'},
    },
  ],
});

const _v1 = {
  'example_items': {
    'id': (type: 'string', nullable: false),
    'title': (type: 'string', nullable: false),
    'description': (type: 'string', nullable: true),
  },
};

const _testV2 = 'test/data/local/database/migrations/to_v2_test.dart';

Future<CheckResult> _check(Map<String, String> files) async =>
    MigrationsCheck().run(DoctorContext(root: await tempRepo(files)));

Map<String, Map<String, _Column>> _v1With(
  void Function(Map<String, Map<String, _Column>>) change,
) {
  final tables = {for (final t in _v1.entries) t.key: Map.of(t.value)};
  change(tables);
  return tables;
}

void main() {
  test(
    'passes with message "skipped" when drift_schemas/ is missing',
    () async {
      final result = await _check({});
      expect(result.status, CheckStatus.pass);
      expect(result.messages.join('\n'), contains('skipped'));
    },
  );

  test('passes with a single version', () async {
    final result = await _check({
      'drift_schemas/drift_schema_v1.json': _dump(_v1),
    });
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });

  test('passes when v2 only adds a table and a nullable column', () async {
    final v2 = _v1With((t) {
      t['example_items']!['notes'] = (type: 'string', nullable: true);
      t['tags'] = {'id': (type: 'int', nullable: false)};
    });
    final result = await _check({
      'drift_schemas/drift_schema_v1.json': _dump(_v1),
      'drift_schemas/drift_schema_v2.json': _dump(v2),
      _testV2: '',
    });
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });

  test('fails when v2 drops a column', () async {
    final v2 = _v1With((t) => t['example_items']!.remove('description'));
    final result = await _check({
      'drift_schemas/drift_schema_v1.json': _dump(_v1),
      'drift_schemas/drift_schema_v2.json': _dump(v2),
      _testV2: '',
    });
    expect(result.status, CheckStatus.fail);
    expect(
      result.messages,
      contains('example_items.description removed in v2'),
    );
  });

  test('fails when v2 drops a table', () async {
    final result = await _check({
      'drift_schemas/drift_schema_v1.json': _dump(_v1),
      'drift_schemas/drift_schema_v2.json': _dump({}),
      _testV2: '',
    });
    expect(result.status, CheckStatus.fail);
    expect(result.messages, contains('example_items removed in v2'));
  });

  test('fails when a column changes type', () async {
    final v2 = _v1With(
      (t) => t['example_items']!['title'] = (type: 'int', nullable: false),
    );
    final result = await _check({
      'drift_schemas/drift_schema_v1.json': _dump(_v1),
      'drift_schemas/drift_schema_v2.json': _dump(v2),
      _testV2: '',
    });
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('example_items.title'));
  });

  test('fails when a column becomes non-nullable', () async {
    final v2 = _v1With(
      (t) => t['example_items']!['description'] = (
        type: 'string',
        nullable: false,
      ),
    );
    final result = await _check({
      'drift_schemas/drift_schema_v1.json': _dump(_v1),
      'drift_schemas/drift_schema_v2.json': _dump(v2),
      _testV2: '',
    });
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('example_items.description'));
  });

  test('passes when the removal is listed in allowed_removals.json', () async {
    final v2 = _v1With((t) => t['example_items']!.remove('description'));
    final result = await _check({
      'drift_schemas/drift_schema_v1.json': _dump(_v1),
      'drift_schemas/drift_schema_v2.json': _dump(v2),
      'drift_schemas/allowed_removals.json':
          '{"2": ["example_items.description"]}',
      _testV2: '',
    });
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });

  test('fails when versions are not contiguous', () async {
    final result = await _check({
      'drift_schemas/drift_schema_v1.json': _dump(_v1),
      'drift_schemas/drift_schema_v3.json': _dump(_v1),
      'test/data/local/database/migrations/to_v3_test.dart': '',
    });
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('v2'));
  });

  test('fails when to_v2_test.dart is missing', () async {
    final result = await _check({
      'drift_schemas/drift_schema_v1.json': _dump(_v1),
      'drift_schemas/drift_schema_v2.json': _dump(_v1),
    });
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains(_testV2));
  });

  test('fails when a new non-nullable column has no default', () async {
    final v2 = _v1With(
      (t) => t['example_items']!['qty'] = (type: 'int', nullable: false),
    );
    final result = await _check({
      'drift_schemas/drift_schema_v1.json': _dump(_v1),
      'drift_schemas/drift_schema_v2.json': _dump(v2),
      _testV2: '',
    });
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('example_items.qty'));
  });

  test('passes when a new non-nullable column has a default', () async {
    final v2 = jsonDecode(
      _dump(
        _v1With(
          (t) => t['example_items']!['qty'] = (type: 'int', nullable: false),
        ),
      ),
    ) as Map<String, Object?>;
    final table = (v2['entities'] as List).first as Map;
    final columns = (table['data'] as Map)['columns'] as List;
    (columns.last as Map)['default_dart'] = 'const CustomExpression(\'0\')';
    final result = await _check({
      'drift_schemas/drift_schema_v1.json': _dump(_v1),
      'drift_schemas/drift_schema_v2.json': jsonEncode(v2),
      _testV2: '',
    });
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });
}
