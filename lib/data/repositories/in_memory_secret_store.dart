import '../../domain/repositories/secret_store.dart';

/// Keeps the keys only in memory: for web (nothing is stored there), the
/// action CLI and tests.
class InMemorySecretStore implements SecretStore {
  final _keys = <String, String>{};

  @override
  Future<String?> getApiKey(String presetId) async => _keys[presetId];

  @override
  Future<void> setApiKey(String presetId, String? key) async {
    if (key == null || key.isEmpty) {
      _keys.remove(presetId);
    } else {
      _keys[presetId] = key;
    }
  }
}
