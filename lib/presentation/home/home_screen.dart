import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_agentify/core/widgets/states/states.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/domain/actions/items_actions.dart';
import 'package:flutter_agentify/domain/entities/item.dart';
import 'package:flutter_agentify/presentation/action_failure_message.dart';
import 'package:flutter_agentify/presentation/assistant/assistant_toggle_button.dart';
import 'package:flutter_agentify/presentation/providers/items_provider.dart';
import 'package:flutter_agentify/utils/locale/app_localization.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ActionRegistry get _registry => ServiceLocator.getIt<ActionRegistry>();
  AppActions get _actions => ServiceLocator.getIt<AppActions>();
  late final SelectedItemIds _selection;

  @override
  void initState() {
    super.initState();
    _selection = ref.read(selectedItemIdsProvider.notifier);
  }

  // The selection belongs to this screen, so leaving it drops the selection
  // (and the ids the assistant is told about).
  @override
  void dispose() {
    Future.microtask(_selection.clear);
    super.dispose();
  }

  String _tr(String key, [String fallback = '']) =>
      AppLocalizations.of(context)?.translate(key) ?? fallback;

  /// Runs [change] through the registry and shows a failure as a message.
  /// Returns true when the action failed.
  Future<bool> _run(Future<Object?> Function() change) async {
    try {
      await change();
      return false;
    } on ActionFailure catch (failure) {
      if (mounted) showActionFailure(context, failure);
      return true;
    }
  }

  Future<void> _showItemDialog({Item? item}) async {
    final values = await showDialog<({String title, String description})>(
      context: context,
      builder: (context) => _ItemDialog(item: item, tr: _tr),
    );
    if (values == null) return;

    if (item == null) {
      await _run(
        () => _registry.run(
          _actions.createItem,
          CreateItemInput(
            title: values.title.trim(),
            description: values.description.trim(),
          ),
        ),
      );
    } else {
      // Null leaves a field as it is, so an edit never overwrites a change
      // made meanwhile to a field the person did not touch.
      final title = values.title.trim();
      final description = values.description.trim();
      final titleChanged = title != item.title;
      final descriptionChanged = description != (item.description ?? '');
      if (!titleChanged && !descriptionChanged) return;
      await _run(
        () => _registry.run(
          _actions.updateItem,
          UpdateItemInput(
            id: item.id,
            title: titleChanged ? title : null,
            description: descriptionChanged ? description : null,
          ),
        ),
      );
    }
  }

  Future<bool> _confirmDelete(String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('delete', 'Delete')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_tr('cancel', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(_tr('delete', 'Delete')),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _deleteItem(Item item) async {
    if (await _confirmDelete(_tr('confirm_delete', 'Delete this item?'))) {
      await _run(() => _registry.run(_actions.deleteItem, item.id));
    }
  }

  /// One confirmation for the whole selection, then one action.
  Future<void> _deleteSelected(Set<String> ids) async {
    final message = _tr(
      'confirm_delete_selected',
      'Delete {} items?',
    ).replaceFirst('{}', '${ids.length}');
    if (!await _confirmDelete(message)) return;
    final failed = await _run(
      () => _registry.run(_actions.deleteItems, ids.toList()),
    );
    if (!failed && mounted) ref.read(selectedItemIdsProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(itemsProvider);
    final selected = ref.watch(selectedItemIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selected.isEmpty
              ? _tr('home', 'Home')
              : _tr(
                  'selected_count',
                  '{}',
                ).replaceFirst('{}', '${selected.length}'),
        ),
        centerTitle: true,
        leading: selected.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: _tr('clear_selection', 'Clear selection'),
                onPressed: () =>
                    ref.read(selectedItemIdsProvider.notifier).clear(),
              ),
        actions: [
          if (selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: _tr('delete_selected', 'Delete selected'),
              onPressed: () => _deleteSelected(selected),
            ),
          const AssistantToggleButton(),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: _tr('settings', 'Settings'),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () =>
            SkeletonList(itemBuilder: (_, _) => const SkeletonListItem()),
        error: (error, stack) => ErrorState(
          message: _tr('error_generic', 'Something went wrong.'),
          onRetry: () => ref.invalidate(itemsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.inbox_outlined,
              title: _tr('no_items', 'No items yet'),
              description: _tr(
                'empty_items_hint',
                'Items you or the assistant add show up here.',
              ),
              actionLabel: _tr('add_item', 'Add Item'),
              onAction: _showItemDialog,
            );
          }

          return ListView.builder(
            // Room at the end so the add button never covers the last row.
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              void toggle() =>
                  ref.read(selectedItemIdsProvider.notifier).toggle(item.id);
              return _ItemTile(
                item: item,
                selected: selected.contains(item.id),
                selecting: selected.isNotEmpty,
                // While a selection exists, a tap adds or removes the row.
                onTap: selected.isEmpty
                    ? () => _showItemDialog(item: item)
                    : toggle,
                onLongPress: toggle,
                onEdit: () => _showItemDialog(item: item),
                onDelete: () => _deleteItem(item),
                editLabel: _tr(
                  'edit_named',
                  'Edit {}',
                ).replaceFirst('{}', item.title),
                // Names the item, so each row's button is told apart.
                deleteLabel: _tr(
                  'delete_named',
                  'Delete {}',
                ).replaceFirst('{}', item.title),
                theme: theme,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showItemDialog,
        tooltip: _tr('add_item', 'Add Item'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Asks for an item's title and description; pops them, or null.
class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.item, required this.tr});

  final Item? item;
  final String Function(String key, [String fallback]) tr;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final _title = TextEditingController(text: widget.item?.title ?? '');
  late final _description = TextEditingController(
    text: widget.item?.description ?? '',
  );

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _description.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  // maxLength counts graphemes; the action counts code points.
  bool get _valid =>
      _title.text.trim().isNotEmpty &&
      _title.text.runes.length <= maxItemTitle &&
      _description.text.runes.length <= maxItemDescription;

  void _submit() =>
      Navigator.of(context)
          .pop((title: _title.text, description: _description.text));

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    return AlertDialog(
      title: Text(
        widget.item != null ? tr('edit', 'Edit') : tr('add_item', 'Add Item'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: tr('item_title', 'Title'),
              hintText: tr('enter_title', 'Enter title'),
            ),
            autofocus: true,
            maxLength: maxItemTitle,
            onSubmitted: (_) {
              if (_valid) _submit();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: InputDecoration(
              labelText: tr('item_description', 'Description'),
              hintText: tr('enter_description', 'Enter description'),
            ),
            maxLines: 3,
            maxLength: maxItemDescription,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('cancel', 'Cancel')),
        ),
        FilledButton(
          onPressed: _valid ? _submit : null,
          child: Text(tr('save', 'Save')),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
    required this.editLabel,
    required this.deleteLabel,
    required this.theme,
  });

  final Item item;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String editLabel;
  final String deleteLabel;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final description = item.description;
    final hasDescription = description != null && description.isNotEmpty;
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // The action deletes it; the list follows the database.
      },
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        color: selected ? theme.colorScheme.secondaryContainer : null,
        child: ListTile(
          selected: selected,
          leading: selecting
              ? Checkbox(
                  value: selected,
                  onChanged: (_) => onLongPress(),
                  semanticLabel: item.title,
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: editLabel,
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: deleteLabel,
                onPressed: onDelete,
              ),
            ],
          ),
          title: Text(
            item.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasDescription)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  MaterialLocalizations.of(context)
                      .formatMediumDate(item.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          isThreeLine: hasDescription,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }
}
