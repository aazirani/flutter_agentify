import 'dart:async';

import 'package:flutter_agentify/ai/assistant_providers.dart';
import 'package:flutter_agentify/presentation/providers/assistant_settings_provider.dart';
import 'package:flutter_agentify/presentation/providers/language_provider.dart';
import 'package:flutter_agentify/presentation/providers/memories_provider.dart';
import 'package:flutter_agentify/presentation/providers/theme_provider.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Refreshes the providers that read settings or saved notes after an
/// action writes them, from the UI or the assistant. Items need nothing
/// here: their database stream refreshes on its own.
StreamSubscription<ChangeEvent> attachChangeEvents(
  ActionRegistry registry,
  ProviderContainer container,
) => registry.changes.listen((e) {
  if (e.resource == 'memories') container.invalidate(savedMemoriesProvider);
  if (e.resource != 'settings') return;
  container
    ..invalidate(currentThemeModeProvider)
    ..invalidate(currentLocaleProvider)
    ..invalidate(assistantSettingsProvider);
  // @on-device:begin
  container
    ..invalidate(onDeviceOfferDismissedProvider)
    ..invalidate(useOnDeviceModelProvider);
  // @on-device:end
  // The key is not part of the settings the session watches.
  if (e.action == 'set_api_key') container.invalidate(assistantSessionProvider);
});
