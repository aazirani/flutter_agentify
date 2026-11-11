import 'package:flutter/foundation.dart';
import 'package:flutter_agentify/ai/assistant_setup.dart';
import 'package:flutter_agentify/data/local/database/app_database.dart';
import 'package:flutter_agentify/data/local/database/connection.dart';
// @example:begin
import 'package:flutter_agentify/data/local/database/daos/example_dao.dart';
import 'package:flutter_agentify/data/repositories/drift_items_repository.dart';
// @example:end
import 'package:flutter_agentify/data/repositories/drift_memory_store.dart';
import 'package:flutter_agentify/data/repositories/drift_thread_store.dart';
import 'package:flutter_agentify/data/repositories/in_memory_secret_store.dart';
import 'package:flutter_agentify/data/repositories/prefs_approval_prefs.dart';
import 'package:flutter_agentify/data/repositories/prefs_settings_repository.dart';
import 'package:flutter_agentify/data/repositories/secure_secret_store.dart';
import 'package:flutter_agentify/di/service_locator.dart';
// @example:begin
import 'package:flutter_agentify/domain/repositories/items_repository.dart';
// @example:end
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify/domain/repositories/secret_store.dart';
import 'package:flutter_agentify/domain/repositories/settings_repository.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataLayerInjection {
  static Future<void> configureDataLayerInjection() async {
    final getIt = ServiceLocator.getIt;
    final prefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(prefs);

    final database = AppDatabase(openAppConnection());
    getIt
      ..registerSingleton<AppDatabase>(database)
      ..registerSingleton<SettingsRepository>(
        PrefsSettingsRepository(
          prefs,
          defaults: AssistantSettings.fromServer(assistantSetup.server),
        ),
      )
      // Web keeps no key at all: nothing typed there is stored.
      ..registerSingleton<SecretStore>(
        kIsWeb ? InMemorySecretStore() : SecureSecretStore(),
      )
      ..registerSingleton<ApprovalPrefs>(PrefsApprovalPrefs(prefs))
      ..registerSingleton<ThreadStore>(DriftThreadStore(database))
      ..registerSingleton<MemoryStore>(DriftMemoryStore(database));
    // @example:begin
    final dao = ExampleDao(database);
    getIt
      ..registerSingleton<ExampleDao>(dao)
      ..registerSingleton<ItemsRepository>(DriftItemsRepository(dao));
    // @example:end
  }
}
