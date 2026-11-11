import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/repositories/secret_store.dart';

/// The API keys, one per preset, in the platform's secure storage (Keychain, Keystore and
/// their desktop equivalents). Not used on web, where nothing is stored.
class SecureSecretStore implements SecretStore {
  SecureSecretStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // The data-protection keychain needs a signing entitlement that
            // unsigned debug builds lack (error -34018); the login keychain
            // works for every build.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;

  static String _name(String presetId) => 'assistant_api_key_$presetId';

  @override
  Future<String?> getApiKey(String presetId) =>
      _storage.read(key: _name(presetId));

  @override
  Future<void> setApiKey(String presetId, String? key) =>
      key == null || key.isEmpty
      ? _storage.delete(key: _name(presetId))
      : _storage.write(key: _name(presetId), value: key);
}
