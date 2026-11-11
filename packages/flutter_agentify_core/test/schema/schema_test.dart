import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:test/test.dart';

Matcher _errorAt(String path, [String? messagePart]) => throwsA(
  isA<SchemaError>()
      .having((e) => e.path, 'path', path)
      .having((e) => e.message, 'message', contains(messagePart ?? '')),
);

void main() {
  final s = S.object(
    fields: {
      'title': S.string(description: 'Title', minLength: 1),
      'count': S.integer(description: 'Count').optional(),
    },
    build: (v) => (v['title'] as String, v['count'] as int?),
  );

  test('a blank description throws ArgumentError', () {
    expect(() => S.string(description: '  '), throwsArgumentError);
    expect(() => S.integer(description: ''), throwsArgumentError);
    expect(() => S.number(description: ' '), throwsArgumentError);
    expect(() => S.boolean(description: ''), throwsArgumentError);
    expect(
      () => S.list(S.string(description: 'x'), description: ''),
      throwsArgumentError,
    );
  });

  test('object parses required and optional fields', () {
    expect(s.parse({'title': 'Milk'}), ('Milk', null));
    expect(s.parse({'title': 'Milk', 'count': 2}), ('Milk', 2));
    expect(s.parse({'title': 'Milk', 'count': null}), ('Milk', null));
  });

  test('a missing required field reports its path', () {
    expect(() => s.parse({}), _errorAt(r'$.title'));
  });

  test('an unknown field is rejected and the allowed names are listed', () {
    expect(
      () => s.parse({'title': 'Milk', 'colour': 'red'}),
      _errorAt(r'$.colour', 'title, count'),
    );
  });

  test('a wrong type reports the path', () {
    expect(() => s.parse({'title': 3}), _errorAt(r'$.title', 'string'));
  });

  test('a non-object input is rejected', () {
    for (final value in ['x', 3, <Object?>[], null]) {
      expect(() => s.parse(value), _errorAt(r'$', 'object'), reason: '$value');
    }
  });

  test('integer accepts 3.0 and rejects 3.5', () {
    final i = S.integer(description: 'n');
    expect(i.parse(3.0), 3);
    expect(i.parse(3.0), isA<int>());
    expect(() => i.parse(3.5), _errorAt(r'$', 'integer'));
    expect(() => i.parse(true), _errorAt(r'$'));
  });

  test('number accepts an int', () {
    final n = S.number(description: 'n');
    expect(n.parse(2), 2.0);
    expect(n.parse(2), isA<double>());
    expect(() => n.parse('2'), _errorAt(r'$', 'number'));
  });

  test('string enforces minLength, maxLength and oneOf', () {
    final str = S.string(description: 's', minLength: 2, maxLength: 3);
    expect(str.parse('ab'), 'ab');
    expect(() => str.parse('a'), _errorAt(r'$', '2'));
    expect(() => str.parse('abcd'), _errorAt(r'$', '3'));
    final mode = S.string(description: 'm', oneOf: ['light', 'dark']);
    expect(mode.parse('dark'), 'dark');
    expect(() => mode.parse('blue'), _errorAt(r'$', 'light, dark'));
  });

  test('integer enforces min and max', () {
    final i = S.integer(description: 'n', min: 1, max: 5);
    expect(i.parse(5), 5);
    expect(() => i.parse(0), _errorAt(r'$', '1'));
    expect(() => i.parse(6), _errorAt(r'$', '5'));
  });

  test('list parses items and reports the index in the path', () {
    final ids = S.object(
      fields: {'ids': S.list(S.string(description: 'id'), description: 'Ids')},
      build: (v) => v['ids'] as List<String>,
    );
    expect(
      ids.parse({
        'ids': ['a', 'b'],
      }),
      ['a', 'b'],
    );
    expect(
      ids.parse({
        'ids': ['a', 'b'],
      }),
      isA<List<String>>(),
    );
    expect(
      () => ids.parse({
        'ids': ['a', 2],
      }),
      _errorAt(r'$.ids[1]'),
    );
    expect(() => ids.parse({'ids': 'a'}), _errorAt(r'$.ids', 'list'));
    final bounded = S.list(
      S.integer(description: 'n'),
      description: 'ns',
      minItems: 1,
      maxItems: 2,
    );
    expect(() => bounded.parse(<Object?>[]), _errorAt(r'$'));
    expect(() => bounded.parse([1, 2, 3]), _errorAt(r'$'));
  });

  test('S.none accepts {} and null and rejects other fields', () {
    expect(S.none.parse({}), isA<NoInput>());
    expect(S.none.parse(null), isA<NoInput>());
    expect(() => S.none.parse({'x': 1}), _errorAt(r'$.x'));
  });

  test(
    'toJsonSchema lists properties, required and additionalProperties false',
    () {
      expect(s.toJsonSchema(), {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': 'Title', 'minLength': 1},
          'count': {'type': 'integer', 'description': 'Count'},
        },
        'required': ['title'],
        'additionalProperties': false,
      });
    },
  );

  test('oneOf becomes enum; list becomes array with items', () {
    expect(S.string(description: 'Mode', oneOf: ['a', 'b']).toJsonSchema(), {
      'type': 'string',
      'description': 'Mode',
      'enum': ['a', 'b'],
    });
    expect(
      S
          .list(
            S.integer(description: 'n', min: 0),
            description: 'Numbers',
            maxItems: 3,
          )
          .toJsonSchema(),
      {
        'type': 'array',
        'description': 'Numbers',
        'items': {'type': 'integer', 'description': 'n', 'minimum': 0},
        'maxItems': 3,
      },
    );
    expect(S.boolean(description: 'b').toJsonSchema(), {
      'type': 'boolean',
      'description': 'b',
    });
    expect(S.number(description: 'x', max: 1).toJsonSchema(), {
      'type': 'number',
      'description': 'x',
      'maximum': 1.0,
    });
  });

  test('optional keeps the schema and marks it optional', () {
    final o = S.string(description: 's').optional();
    expect(o.isOptional, isTrue);
    expect(o.parse(null), isNull);
    expect(o.description, 's');
    expect(S.string(description: 's').isOptional, isFalse);
  });

  test('string length counts code points, not UTF-16 units', () {
    final str = S.string(description: 's', maxLength: 2);
    expect(str.parse('\u{1F600}\u{1F600}'), '\u{1F600}\u{1F600}');
    expect(() => str.parse('abc'), _errorAt(r'$', '2'));
  });

  test('an object description may be empty but not blank', () {
    expect(() => S.object(fields: {}, build: (_) => 1), returnsNormally);
    expect(
      () => S.object(fields: {}, build: (_) => 1, description: ' '),
      throwsArgumentError,
    );
  });
}
