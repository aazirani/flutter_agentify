import 'package:flutter_agentify_core/flutter_agentify_core.dart';

import '../entities/item.dart';
import '../repositories/items_repository.dart';

/// The longest title and description an item may have.
const maxItemTitle = 200;
const maxItemDescription = 2000;

// Lengths count code points (`runes`), as the schema does.
// Checked inside `run`, not only in the schema: screens call actions with
// typed input through `registry.run`, which skips the JSON schema.

ActionFailure _invalid(String path, String message) =>
    ActionFailure('invalid_input', message, details: {'path': path});

/// The title trimmed, or `invalid_input` when it is blank or too long.
String _title(String raw) {
  final title = raw.trim();
  if (title.isEmpty || title.runes.length > maxItemTitle) {
    throw _invalid(
      r'$.title',
      'The title must have 1 to $maxItemTitle characters.',
    );
  }
  return title;
}

/// The description trimmed (empty when blank), or `invalid_input` when too
/// long.
String _description(String raw) {
  final description = raw.trim();
  if (description.runes.length > maxItemDescription) {
    throw _invalid(
      r'$.description',
      'The description must have at most $maxItemDescription characters.',
    );
  }
  return description;
}

Map<String, Object?> _notFound(String id) => {'id': id};

class ListItemsInput {
  const ListItemsInput({this.limit = 50});

  final int limit;
}

/// `list_items`: the newest items and how many there are in all.
class ListItems
    extends AgentAction<ListItemsInput, ({List<Item> items, int total})> {
  ListItems(this.items);

  final ItemsRepository items;

  @override
  String get name => 'list_items';

  @override
  String get description =>
      'Lists the newest items with their ids, and the total number of items. '
      'Titles and descriptions are shortened; get_item returns the full text.';

  @override
  late final ObjectSchema<ListItemsInput> input = S.object(
    fields: {
      'limit': S
          .integer(
            description: 'How many items to return; 50 when left out.',
            min: 1,
            max: 200,
          )
          .optional(),
    },
    build: (v) => ListItemsInput(limit: v['limit'] as int? ?? 50),
  );

  @override
  bool get readOnly => true;

  @override
  List<String> get searchHints => const ['show', 'find', 'count'];

  @override
  Future<({List<Item> items, int total})> run(
    ListItemsInput input,
    ActionContext context,
  ) async => (
    items: await items.getItems(limit: input.limit),
    total: await items.getItemCount(),
  );

  // 50 items of 80 + 100 characters stay well inside this.
  @override
  int get maxResultChars => 16000;

  @override
  Object? encode(({List<Item> items, int total}) output) => {
    'total': output.total,
    'items': [
      for (final item in output.items)
        {
          ...item.toJson(),
          'title': cutText(item.title, 80, suffix: '…'),
          if (item.description case final d?)
            'description': cutText(d, 100, suffix: '…'),
        },
    ],
  };
}

/// `get_item`: one item with its full title and description.
class GetItem extends AgentAction<String, Item> {
  GetItem(this.items);

  final ItemsRepository items;

  @override
  String get name => 'get_item';

  @override
  String get description =>
      'Returns one item with its full title and description.';

  @override
  late final ObjectSchema<String> input = S.object(
    fields: {
      'id': S.string(description: 'The id of the item to read.', minLength: 1),
    },
    build: (v) => v['id'] as String,
  );

  @override
  bool get readOnly => true;

  @override
  List<String> get failureCodes => const ['not_found'];

  @override
  List<String> get searchHints => const ['read', 'show', 'details'];

  @override
  Future<Item> run(String input, ActionContext context) async {
    final item = await items.getItem(input);
    if (item == null) {
      throw ActionFailure(
        'not_found',
        'No item has the id "$input".',
        details: _notFound(input),
      );
    }
    return item;
  }

  @override
  Object? encode(Item output) => output.toJson();
}

class CreateItemInput {
  const CreateItemInput({required this.title, this.description});

  final String title;
  final String? description;
}

/// `create_item`: adds an item.
class CreateItem extends AgentAction<CreateItemInput, Item> {
  CreateItem(this.items);

  final ItemsRepository items;

  @override
  String get name => 'create_item';

  @override
  String get description =>
      'Adds an item with a title and an optional description.';

  @override
  late final ObjectSchema<CreateItemInput> input = S.object(
    fields: {
      'title': S.string(
        description: 'The item title, 1 to 200 characters.',
        minLength: 1,
        maxLength: maxItemTitle,
      ),
      'description': S
          .string(
            description: 'Optional details, up to 2000 characters.',
            maxLength: maxItemDescription,
          )
          .optional(),
    },
    build: (v) => CreateItemInput(
      title: v['title'] as String,
      description: v['description'] as String?,
    ),
  );

  @override
  List<String> get resources => const ['items'];

  @override
  List<String> get searchHints => const ['add', 'new'];

  @override
  Future<Item> run(CreateItemInput input, ActionContext context) async {
    final description = _description(input.description ?? '');
    final created = await items.createItem(
      title: _title(input.title),
      description: description.isEmpty ? null : description,
    );
    final stored = await items.getItem(created.id);
    context.receipt(
      resource: 'items',
      ids: [created.id],
      summary: 'Created item "${created.title}"',
      key: 'created_item',
      args: {'title': created.title},
      verified: stored != null,
    );
    return stored ?? created;
  }

  @override
  Object? encode(Item output) => output.toJson();
}

class UpdateItemInput {
  const UpdateItemInput({required this.id, this.title, this.description});

  final String id;
  final String? title;

  /// Null leaves it; an empty string clears it.
  final String? description;
}

/// `update_item`: changes an item's title, description or both.
class UpdateItem extends AgentAction<UpdateItemInput, Item> {
  UpdateItem(this.items);

  final ItemsRepository items;

  @override
  String get name => 'update_item';

  @override
  String get description =>
      'Changes the title or the description of an item; an empty description removes it.';

  @override
  late final ObjectSchema<UpdateItemInput> input = S.object(
    fields: {
      'id': S.string(
        description: 'The id of the item to change.',
        minLength: 1,
      ),
      'title': S
          .string(
            description: 'The new title, 1 to 200 characters.',
            minLength: 1,
            maxLength: maxItemTitle,
          )
          .optional(),
      'description': S
          .string(
            description: 'The new description; an empty string removes it.',
            maxLength: maxItemDescription,
          )
          .optional(),
    },
    build: (v) => UpdateItemInput(
      id: v['id'] as String,
      title: v['title'] as String?,
      description: v['description'] as String?,
    ),
  );

  @override
  List<String> get resources => const ['items'];

  @override
  List<String> get failureCodes => const ['not_found'];

  @override
  List<String> get searchHints => const ['rename', 'edit', 'change'];

  @override
  Future<Item> run(UpdateItemInput input, ActionContext context) async {
    if (input.title == null && input.description == null) {
      throw _invalid(r'$', 'Give a title or a description to change.');
    }
    final title = switch (input.title) {
      final raw? => _title(raw),
      null => null,
    };
    final description = switch (input.description) {
      final raw? => _description(raw),
      null => null,
    };
    final updated = await items.updateItem(
      input.id,
      title: title,
      description: description == null || description.isEmpty
          ? null
          : description,
      clearDescription: description != null && description.isEmpty,
    );
    if (updated == null) {
      throw ActionFailure(
        'not_found',
        'No item has the id "${input.id}".',
        details: _notFound(input.id),
      );
    }
    final stored = await items.getItem(input.id);
    // The receipt says what changed.
    final (key, summary) = switch ((title, description)) {
      (_?, null) => ('renamed_item', 'Renamed item to "${updated.title}"'),
      (null, final d?) when d.isEmpty => (
        'cleared_item_description',
        'Removed the description of "${updated.title}"',
      ),
      (null, _?) => (
        'changed_item_description',
        'Changed the description of "${updated.title}"',
      ),
      _ => ('updated_item', 'Updated item "${updated.title}"'),
    };
    context.receipt(
      resource: 'items',
      ids: [input.id],
      summary: summary,
      key: key,
      args: {'title': updated.title},
      verified: stored != null,
    );
    return stored ?? updated;
  }

  @override
  Object? encode(Item output) => output.toJson();
}

/// `delete_item`: removes an item. Asks the person first.
class DeleteItem extends AgentAction<String, String> {
  DeleteItem(this.items);

  final ItemsRepository items;

  @override
  String get name => 'delete_item';

  @override
  String get description => 'Deletes an item by its id.';

  @override
  late final ObjectSchema<String> input = S.object(
    fields: {
      'id': S.string(
        description: 'The id of the item to delete.',
        minLength: 1,
      ),
    },
    build: (v) => v['id'] as String,
  );

  @override
  List<String> get resources => const ['items'];

  @override
  bool needsApproval(String input) => true;

  // A delete cannot be undone, so every one asks.
  @override
  bool get allowAlways => false;

  @override
  Future<String?> approvalSummary(String input) async =>
      (await items.getItem(input))?.title;

  @override
  List<String> get failureCodes => const ['not_found'];

  @override
  List<String> get searchHints => const ['remove'];

  @override
  Future<String> run(String input, ActionContext context) async {
    final item = await items.getItem(input);
    if (item == null || !await items.deleteItem(input)) {
      throw ActionFailure(
        'not_found',
        'No item has the id "$input".',
        details: _notFound(input),
      );
    }
    context.receipt(
      resource: 'items',
      ids: [input],
      summary: 'Deleted item "${item.title}"',
      key: 'deleted_item',
      args: {'title': item.title},
      verified: await items.getItem(input) == null,
    );
    return input;
  }

  @override
  Object? encode(String output) => {'deleted': output};
}

/// `delete_items`: removes several items at once. Asks the person first.
class DeleteItems extends AgentAction<List<String>, List<String>> {
  DeleteItems(this.items);

  final ItemsRepository items;

  @override
  String get name => 'delete_items';

  @override
  String get description =>
      'Deletes several items by their ids with one approval. '
      'Nothing is deleted when one id does not exist.';

  @override
  late final ObjectSchema<List<String>> input = S.object(
    fields: {
      'ids': S.list(
        S.string(description: 'The id of an item.', minLength: 1),
        description: 'The ids of the items to delete.',
        minItems: 1,
        maxItems: 100,
      ),
    },
    build: (v) => (v['ids'] as List).cast<String>(),
  );

  @override
  List<String> get resources => const ['items'];

  @override
  bool needsApproval(List<String> input) => true;

  // A delete cannot be undone, so every one asks.
  @override
  bool get allowAlways => false;

  @override
  Future<String?> approvalSummary(List<String> input) async {
    final titles = [
      for (final id in input.take(5)) (await items.getItem(id))?.title ?? id,
    ];
    return '${titles.join(', ')}${input.length > 5 ? ', …' : ''}';
  }

  @override
  List<String> get failureCodes => const ['not_found'];

  @override
  List<String> get searchHints => const ['remove', 'selected', 'several'];

  @override
  Future<List<String>> run(List<String> input, ActionContext context) async {
    final ids = input.toSet().toList();
    if (ids.isEmpty || ids.length > 100) {
      throw _invalid(r'$.ids', 'Give 1 to 100 item ids.');
    }
    // Check every id first, so a wrong one deletes nothing.
    final missing = [
      for (final id in ids)
        if (await items.getItem(id) == null) id,
    ];
    if (missing.isNotEmpty) {
      throw ActionFailure(
        'not_found',
        'No item has the id "${missing.first}"; nothing was deleted.',
        details: {'ids': missing},
      );
    }
    await items.deleteItems(ids);
    final gone = [
      for (final id in ids)
        if (await items.getItem(id) == null) id,
    ];
    final partial = gone.length < ids.length;
    context.receipt(
      resource: 'items',
      ids: gone,
      summary: partial
          ? 'Deleted ${gone.length} of ${ids.length} items'
          : 'Deleted ${gone.length} items',
      key: partial ? 'deleted_items_partial' : 'deleted_items',
      args: {'count': '${gone.length}', 'total': '${ids.length}'},
      verified: true,
    );
    return gone;
  }

  @override
  Object? encode(List<String> output) => {'deleted': output};
}
