import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/domain/entities/item.dart';
import 'package:flutter_agentify/presentation/providers/items_provider.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

void main() {
  test(
    'a deleted item leaves the selection and the assistant\'s context',
    () async {
      final items = FakeItemsRepository([
        Item(id: 'a', title: 'Milk', createdAt: DateTime(2026)),
        Item(id: 'b', title: 'Eggs', createdAt: DateTime(2026)),
      ]);
      final container = setUpTestServices(items: items);
      container.listen(itemsProvider, (_, _) {});
      await container.read(itemsProvider.future);
      container.read(selectedItemIdsProvider.notifier)
        ..toggle('a')
        ..toggle('b');
      final getIt = ServiceLocator.getIt;
      await getIt<ActionRegistry>().run(getIt<AppActions>().deleteItem, 'a');
      await pumpEventQueue();
      expect(container.read(selectedItemIdsProvider), {'b'});
      expect(getIt<AppContext>().navigation.selectedIds, ['b']);
    },
  );

  test('clearing after the app closed does nothing', () {
    final container = setUpTestServices(items: FakeItemsRepository());
    final selection = container.read(selectedItemIdsProvider.notifier);
    container.dispose();
    expect(selection.clear, returnsNormally);
  });
}
