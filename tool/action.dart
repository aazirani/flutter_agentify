// The app's action CLI: runs the app's actions without the UI, against a
// scratch database, so behavior can be checked from the command line.
//
//   dart run tool/action.dart --list
//   dart run tool/action.dart set_language '{"locale":"fa"}'
//   dart run tool/action.dart <action_name> '<json>' --approved
//   dart run tool/action.dart --write-reference
//
// Nothing imported here may import Flutter.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_agentify/data/local/database/app_database.dart';
// @example:begin
import 'package:flutter_agentify/data/local/database/daos/example_dao.dart';
import 'package:flutter_agentify/data/repositories/drift_items_repository.dart';
// @example:end
import 'package:flutter_agentify/data/repositories/in_memory_secret_store.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify_core/cli.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';

const _database = '.dart_tool/flutter_agentify/cli.sqlite';
const _reference = '.agents/skills/actions/references/action-reference.md';

Future<void> main(List<String> args) async {
  final file = File(_database)..parent.createSync(recursive: true);
  final db = AppDatabase(NativeDatabase(file));
  try {
    final actions = AppActions(
      settings: InMemorySettingsRepository(),
      secrets: InMemorySecretStore(),
      approvals: InMemoryApprovalPrefs(),
      // @example:begin
      items: DriftItemsRepository(ExampleDao(db)),
      // @example:end
    );
    final registry = buildActionRegistry(
      actions,
      appContext: AppContext(screens: const {}),
      memories: InMemoryMemoryStore(),
    );
    exitCode = await runActionCli(registry, args, referencePath: _reference);
  } finally {
    await db.close();
  }
}
