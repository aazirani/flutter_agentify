import 'dart:convert';
import 'dart:io';

import 'package:flutter_agentify/ai/go_router_adapter.dart';
import 'package:flutter_agentify/ai/screen_contexts.dart';
import 'package:flutter_agentify/data/repositories/in_memory_secret_store.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_agentify/utils/routes/app_router.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/parity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// @example:begin
import '../support/fakes.dart';

// @example:end

ActionRegistry _registry(Map<String, ScreenContext> screens) =>
    buildActionRegistry(
      AppActions(
        settings: InMemorySettingsRepository(),
        secrets: InMemorySecretStore(),
        approvals: InMemoryApprovalPrefs(),
        // @example:begin
        items: FakeItemsRepository(),
        // @example:end
      ),
      appContext: AppContext(screens: screens),
      memories: InMemoryMemoryStore(),
    );

void main() {
  test(
    'actions, their tests, the action reference and the screen table agree',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final screens = buildScreenContexts(container);
      final registry = _registry(screens);
      expect(
        parityProblems(
          registry: registry,
          routes: routePatterns(AppRouter.router),
          screens: screens,
          actionTestDir: 'test/actions',
          actionReferencePath:
              '.agents/skills/actions/references/action-reference.md',
        ),
        isEmpty,
      );
    },
  );

  test('every action the assistant can call has a label in every language', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final names = [
      for (final action in _registry(buildScreenContexts(container)).tools)
        action.name,
    ];
    expect(names, isNotEmpty);
    for (final language in kSupportedLanguages) {
      final file = 'assets/lang/${language.locale}.json';
      final keys = (jsonDecode(File(file).readAsStringSync()) as Map).keys;
      final missing = [
        for (final name in names)
          if (!keys.contains('action_$name')) 'action_$name',
      ];
      expect(missing, isEmpty, reason: 'Missing in $file');
    }
  });
}
