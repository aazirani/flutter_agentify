import 'package:flutter_agentify/ai/screen_contexts.dart';
import 'package:flutter_agentify/data/repositories/in_memory_secret_store.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/parity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// @example:begin
import '../support/fakes.dart';

// @example:end

void main() {
  test('commands in AGENTS.md and the skills name real actions and files', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = buildActionRegistry(
      AppActions(
        settings: InMemorySettingsRepository(),
        secrets: InMemorySecretStore(),
        approvals: InMemoryApprovalPrefs(),
        // @example:begin
        items: FakeItemsRepository(),
        // @example:end
      ),
      appContext: AppContext(screens: buildScreenContexts(container)),
      memories: InMemoryMemoryStore(),
    );
    expect(
      skillCommandProblems(actionNames: {for (final a in registry.all) a.name}),
      isEmpty,
    );
  });
}
