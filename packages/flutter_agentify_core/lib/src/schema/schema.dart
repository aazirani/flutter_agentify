/// A tiny schema builder: one definition gives runtime validation, the JSON
/// Schema a model sees, and parsing into a Dart value.
library;

/// A value did not match its schema. [path] points at the value, such as
/// `$.items[2].title`.
class SchemaError implements Exception {
  SchemaError(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

/// Describes, validates and parses one value.
sealed class Schema<T> {
  const Schema();

  /// What the value means, written for the model.
  String get description;

  /// Whether the value may be missing or null.
  bool get isOptional => false;

  /// The same schema, also accepting a missing or null value.
  Schema<T?> optional() => _Optional<T>(this);

  /// This schema as JSON Schema.
  Map<String, Object?> toJsonSchema();

  /// Checks [value] and turns it into a `T`; throws [SchemaError].
  T parse(Object? value, {String path = r'$'});
}

String _required(String description) {
  if (description.trim().isEmpty) {
    throw ArgumentError.value(
      description,
      'description',
      'Every schema needs a description; the model reads it.',
    );
  }
  return description;
}

final class _Optional<T> extends Schema<T?> {
  const _Optional(this.inner);

  final Schema<T> inner;

  @override
  String get description => inner.description;

  @override
  bool get isOptional => true;

  @override
  Schema<T?> optional() => this;

  @override
  Map<String, Object?> toJsonSchema() => inner.toJsonSchema();

  @override
  T? parse(Object? value, {String path = r'$'}) =>
      value == null ? null : inner.parse(value, path: path);
}

final class _StringSchema extends Schema<String> {
  _StringSchema(String description, this.minLength, this.maxLength, this.oneOf)
    : description = _required(description);

  @override
  final String description;
  final int? minLength;
  final int? maxLength;
  final List<String>? oneOf;

  @override
  Map<String, Object?> toJsonSchema() => {
    'type': 'string',
    'description': description,
    'minLength': ?minLength,
    'maxLength': ?maxLength,
    'enum': ?oneOf,
  };

  @override
  String parse(Object? value, {String path = r'$'}) {
    if (value is! String) throw SchemaError(path, 'expected a string');
    // Code points, as JSON Schema counts them, not UTF-16 units.
    final length = value.runes.length;
    if (minLength case final min? when length < min) {
      throw SchemaError(path, 'must have at least $min characters');
    }
    if (maxLength case final max? when length > max) {
      throw SchemaError(path, 'must have at most $max characters');
    }
    if (oneOf case final options? when !options.contains(value)) {
      throw SchemaError(path, 'must be one of: ${options.join(', ')}');
    }
    return value;
  }
}

final class _IntegerSchema extends Schema<int> {
  _IntegerSchema(String description, this.min, this.max)
    : description = _required(description);

  @override
  final String description;
  final int? min;
  final int? max;

  @override
  Map<String, Object?> toJsonSchema() => {
    'type': 'integer',
    'description': description,
    'minimum': ?min,
    'maximum': ?max,
  };

  @override
  int parse(Object? value, {String path = r'$'}) {
    final int number;
    if (value is int) {
      number = value;
    } else if (value is double && value == value.truncateToDouble()) {
      number = value.toInt();
    } else {
      throw SchemaError(path, 'expected an integer');
    }
    if (min case final low? when number < low) {
      throw SchemaError(path, 'must be at least $low');
    }
    if (max case final high? when number > high) {
      throw SchemaError(path, 'must be at most $high');
    }
    return number;
  }
}

final class _NumberSchema extends Schema<double> {
  _NumberSchema(String description, this.min, this.max)
    : description = _required(description);

  @override
  final String description;
  final double? min;
  final double? max;

  @override
  Map<String, Object?> toJsonSchema() => {
    'type': 'number',
    'description': description,
    'minimum': ?min,
    'maximum': ?max,
  };

  @override
  double parse(Object? value, {String path = r'$'}) {
    if (value is! num) throw SchemaError(path, 'expected a number');
    final number = value.toDouble();
    if (min case final low? when number < low) {
      throw SchemaError(path, 'must be at least $low');
    }
    if (max case final high? when number > high) {
      throw SchemaError(path, 'must be at most $high');
    }
    return number;
  }
}

final class _BooleanSchema extends Schema<bool> {
  _BooleanSchema(String description) : description = _required(description);

  @override
  final String description;

  @override
  Map<String, Object?> toJsonSchema() => {
    'type': 'boolean',
    'description': description,
  };

  @override
  bool parse(Object? value, {String path = r'$'}) {
    if (value is! bool) throw SchemaError(path, 'expected true or false');
    return value;
  }
}

final class _ListSchema<E> extends Schema<List<E>> {
  _ListSchema(this.items, String description, this.minItems, this.maxItems)
    : description = _required(description);

  final Schema<E> items;
  @override
  final String description;
  final int? minItems;
  final int? maxItems;

  @override
  Map<String, Object?> toJsonSchema() => {
    'type': 'array',
    'description': description,
    'items': items.toJsonSchema(),
    'minItems': ?minItems,
    'maxItems': ?maxItems,
  };

  @override
  List<E> parse(Object? value, {String path = r'$'}) {
    if (value is! List) throw SchemaError(path, 'expected a list');
    if (minItems case final min? when value.length < min) {
      throw SchemaError(path, 'must have at least $min items');
    }
    if (maxItems case final max? when value.length > max) {
      throw SchemaError(path, 'must have at most $max items');
    }
    return [
      for (final (i, item) in value.indexed)
        items.parse(item, path: '$path[$i]'),
    ];
  }
}

/// An object with named fields, built into a `T` once every field parses.
final class ObjectSchema<T> extends Schema<T> {
  // Empty is allowed (the root input uses the action's description); blank
  // is not, as in every other schema.
  ObjectSchema._(this.fields, this._build, String description)
    : description = description.isEmpty ? description : _required(description);

  final Map<String, Schema<Object?>> fields;
  final T Function(Map<String, Object?> values) _build;
  @override
  final String description;

  @override
  Map<String, Object?> toJsonSchema() {
    final required = [
      for (final MapEntry(:key, :value) in fields.entries)
        if (!value.isOptional) key,
    ];
    return {
      'type': 'object',
      if (description.isNotEmpty) 'description': description,
      'properties': {
        for (final MapEntry(:key, :value) in fields.entries)
          key: value.toJsonSchema(),
      },
      if (required.isNotEmpty) 'required': required,
      'additionalProperties': false,
    };
  }

  @override
  T parse(Object? value, {String path = r'$'}) {
    final Map<Object?, Object?> input;
    if (value is Map) {
      input = value;
    } else if (value == null && fields.values.every((f) => f.isOptional)) {
      input = const {};
    } else {
      throw SchemaError(path, 'expected an object');
    }

    for (final key in input.keys) {
      if (!fields.containsKey(key)) {
        throw SchemaError(
          '$path.$key',
          'unknown field; allowed: ${fields.keys.join(', ')}',
        );
      }
    }
    final values = <String, Object?>{};
    for (final MapEntry(key: name, value: field) in fields.entries) {
      final raw = input[name];
      if (raw == null && !field.isOptional) {
        throw SchemaError('$path.$name', 'is required');
      }
      values[name] = field.parse(raw, path: '$path.$name');
    }
    return _build(values);
  }
}

/// The input of an action that takes none.
final class NoInput {
  const NoInput();
}

/// Builders for every schema kind. Each field takes a required description,
/// so the model always learns what a value means.
abstract final class S {
  /// A string, optionally limited in length (in characters) or to [oneOf].
  static Schema<String> string({
    required String description,
    int? minLength,
    int? maxLength,
    List<String>? oneOf,
  }) => _StringSchema(description, minLength, maxLength, oneOf);

  /// A whole number between [min] and [max] when given.
  static Schema<int> integer({
    required String description,
    int? min,
    int? max,
  }) => _IntegerSchema(description, min, max);

  /// A number between [min] and [max] when given.
  static Schema<double> number({
    required String description,
    double? min,
    double? max,
  }) => _NumberSchema(description, min, max);

  /// True or false.
  static Schema<bool> boolean({required String description}) =>
      _BooleanSchema(description);

  /// A list of [items], with [minItems] to [maxItems] entries when given.
  static Schema<List<E>> list<E>(
    Schema<E> items, {
    required String description,
    int? minItems,
    int? maxItems,
  }) => _ListSchema(items, description, minItems, maxItems);

  /// An object with [fields]; [build] turns the parsed values into `T`.
  static ObjectSchema<T> object<T>({
    required Map<String, Schema<Object?>> fields,
    required T Function(Map<String, Object?> values) build,
    String description = '',
  }) => ObjectSchema._(fields, build, description);

  /// No fields; accepts `{}` and `null`.
  static final ObjectSchema<NoInput> none = object(
    fields: const {},
    build: (_) => const NoInput(),
  );
}
