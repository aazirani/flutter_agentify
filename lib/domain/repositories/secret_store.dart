/// Where the API keys the person typed are kept, one per preset, apart from
/// other settings.
abstract class SecretStore {
  Future<String?> getApiKey(String presetId);

  /// Null or empty removes that preset's key.
  Future<void> setApiKey(String presetId, String? key);
}
