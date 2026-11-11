import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/entities/item.dart';
import 'package:flutter_agentify/domain/repositories/items_repository.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'items_provider.g.dart';

/// The items, newest first. The database stream refreshes it after every
/// write, including the assistant's.
@riverpod
Stream<List<Item>> items(Ref ref) =>
    ServiceLocator.getIt<ItemsRepository>().watchItems();

/// Items the person selected with a long press. Mirrored into [AppContext]
/// so the assistant knows what "these" means.
@Riverpod(keepAlive: true)
class SelectedItemIds extends _$SelectedItemIds {
  @override
  Set<String> build() {
    // Drop ids whose item was deleted, by the person or the assistant.
    ref.listen(itemsProvider, (_, next) {
      final ids = next.value?.map((i) => i.id).toSet();
      if (ids == null || ids.containsAll(state)) return;
      state = state.where(ids.contains).toSet();
      _report();
    });
    return const {};
  }

  void toggle(String id) {
    state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
    _report();
  }

  void clear() {
    // The home screen clears on leaving, which may come after the app closed.
    if (!ref.mounted) return;
    state = const {};
    _report();
  }

  void _report() {
    final getIt = ServiceLocator.getIt;
    if (getIt.isRegistered<AppContext>()) {
      getIt<AppContext>().setSelection(state.toList());
    }
  }
}
