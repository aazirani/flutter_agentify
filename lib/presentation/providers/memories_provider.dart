import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memories_provider.g.dart';

/// The notes the assistant keeps, newest first. Refreshed after
/// `save_memory` or `delete_memory` runs.
@riverpod
Future<List<Memory>> savedMemories(Ref ref) async =>
    (await ServiceLocator.getIt<MemoryStore>().all()).reversed.toList();
