import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isLocalHost', () {
    for (final h in [
      'localhost',
      'LocalHost',
      'my-pc',
      'ollama.local',
      'Ollama.LOCAL',
      '127.0.0.1',
      '10.0.2.2',
      '172.16.0.1',
      '172.20.1.4',
      '172.31.255.255',
      '192.168.1.20',
      '169.254.3.3',
      '::1',
      'fd12::1',
      'fc00::1',
      'fe80::1',
      'FE80::1',
    ]) {
      expect(isLocalHost(h), isTrue, reason: h);
    }
    for (final h in [
      'api.openai.com',
      '8.8.8.8',
      '172.15.0.1',
      '172.32.0.1',
      '192.169.0.1',
      'example.local.com',
      '2001:db8::1',
      '',
    ]) {
      expect(isLocalHost(h), isFalse, reason: h);
    }
  });
}
