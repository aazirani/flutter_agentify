import 'package:drift/native.dart';
import 'package:flutter_agentify/data/local/database/app_database.dart';
// @example:begin
import 'package:flutter_agentify/data/local/database/daos/example_dao.dart';
import 'package:flutter_agentify/data/repositories/drift_items_repository.dart';
// @example:end
import 'package:flutter_agentify/data/repositories/in_memory_secret_store.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's actions over an in-memory database, called through a registry.
class ActionsHarness {
  ActionsHarness._(this.db, this.settings, this.secrets) {
    actions = AppActions(
      settings: settings,
      secrets: secrets,
      approvals: approvals,
      // @on-device:begin
      onDeviceModel: () => onDeviceModel,
      // @on-device:end
      // @example:begin
      items: items,
      // @example:end
    );
    registry = buildActionRegistry(
      actions,
      appContext: AppContext(screens: const {}),
      memories: InMemoryMemoryStore(),
    );
  }

  factory ActionsHarness() {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return ActionsHarness._(
      db,
      InMemorySettingsRepository(),
      InMemorySecretStore(),
    );
  }
  // @on-device:begin

  /// The in-app model the on-device actions manage; set it before calling them.
  OnDeviceModelController? onDeviceModel;
  // @on-device:end

  final AppDatabase db;
  final InMemorySettingsRepository settings;
  final InMemorySecretStore secrets;
  final approvals = InMemoryApprovalPrefs();
  // @example:begin
  late final items = DriftItemsRepository(ExampleDao(db));
  // @example:end
  late final AppActions actions;
  late final ActionRegistry registry;

  /// Calls [name] the way the assistant does.
  Future<ActionCallResult> call(
    String name,
    Object? input, {
    Caller caller = Caller.assistant,
    bool approved = false,
  }) => registry.call(name, input, caller: caller, approved: approved);
}

/// Matches an [ActionFailure] with [code].
Matcher failsWith(String code) =>
    throwsA(isA<ActionFailure>().having((f) => f.code, 'code', code));
