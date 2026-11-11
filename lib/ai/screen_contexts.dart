// @example:begin
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/repositories/items_repository.dart';
// @example:end
import 'package:flutter_agentify/presentation/providers/assistant_settings_provider.dart';
import 'package:flutter_agentify/presentation/providers/language_provider.dart';
import 'package:flutter_agentify/presentation/providers/theme_provider.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// @example:begin
/// Rows of a list the screen block reports; the total is always included.
const _visibleRows = 10;
// @example:end

/// What each route shows, for the assistant's screen block. One entry per
/// route; the parity test checks that none is missing.
Map<String, ScreenContext> buildScreenContexts(ProviderContainer container) => {
  // @example:begin
  '/': ScreenContext((navigation) async {
    final items = ServiceLocator.getIt<ItemsRepository>();
    final visible = await items.getItems(limit: _visibleRows);
    return {
      'screen': 'home',
      'total': await items.getItemCount(),
      'items': [
        for (final item in visible)
          {
            'id': item.id,
            'title': cutText(item.title, 40, suffix: '…'),
            if (item.description case final d? when d.isNotEmpty)
              'description': cutText(d, 40, suffix: '…'),
          },
      ],
      'note': 'Titles and descriptions are cut; get_item has the full text.',
      'selectedIds': navigation.selectedIds,
    };
  }),
  // @example:end
  // @empty:   '/': ScreenContext((_) => {'screen': 'home'}),
  '/settings': ScreenContext((_) {
    final assistant = container.read(assistantSettingsProvider);
    return {
      'screen': 'settings',
      'themeMode': container.read(currentThemeModeProvider).name,
      'locale': container.read(currentLocaleProvider),
      'assistant': {
        'preset': assistant.presetId,
        'model': assistant.model,
        'configured': assistant.isConfigured,
      },
    };
  }),
};
