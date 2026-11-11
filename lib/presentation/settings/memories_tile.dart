import 'package:flutter/material.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/presentation/action_failure_message.dart';
import 'package:flutter_agentify/presentation/providers/memories_provider.dart';
import 'package:flutter_agentify/utils/locale/app_localization.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The notes the assistant keeps. Forget runs `delete_memory`, the action
/// the assistant uses too.
class MemoriesTile extends ConsumerWidget {
  const MemoriesTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(savedMemoriesProvider);
    final notes = memories.value;
    return ExpansionTile(
      leading: const Icon(Icons.bookmark_border),
      title: Text(_t(context, 'assistant_notes')),
      subtitle: Text(_t(context, 'assistant_notes_hint')),
      children: [
        if (notes == null)
          memories.hasError
              ? ListTile(title: Text(_t(context, 'assistant_notes_error')))
              : const LinearProgressIndicator()
        else if (notes.isEmpty)
          ListTile(title: Text(_t(context, 'assistant_notes_empty')))
        else
          for (final note in notes)
            ListTile(
              title: Text(note.text),
              trailing: IconButton(
                tooltip: _t(context, 'assistant_forget_note'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _forget(context, note),
              ),
            ),
      ],
    );
  }

  Future<void> _forget(BuildContext context, Memory note) async {
    final registry = ServiceLocator.getIt<ActionRegistry>();
    final forget = registry.find('delete_memory');
    if (forget == null) return;
    try {
      await registry.run(forget, note.id);
    } on ActionFailure catch (failure) {
      if (context.mounted) showActionFailure(context, failure);
    }
  }

  String _t(BuildContext context, String key) =>
      AppLocalizations.of(context)?.translate(key) ?? key;
}
