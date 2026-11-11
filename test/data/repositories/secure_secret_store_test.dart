import 'package:flutter_agentify/data/repositories/secure_secret_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('keeps one key per preset', () async {
    final store = SecureSecretStore();
    await store.setApiKey('openai', 'k1');
    expect(await store.getApiKey('openai'), 'k1');
    expect(await store.getApiKey('gemini'), isNull);
  });

  test('an empty key removes that preset key', () async {
    final store = SecureSecretStore();
    await store.setApiKey('openai', 'k1');
    await store.setApiKey('gemini', 'k2');
    await store.setApiKey('openai', '');
    expect(await store.getApiKey('openai'), isNull);
    expect(await store.getApiKey('gemini'), 'k2');
  });
}
