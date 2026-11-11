import 'dart:io';

import 'package:flutter_agentify_core/doctor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'git_repo.dart';
import 'temp_repo.dart';

const _pubspec = '''
name: app
flutter:
  assets:
    - assets/
    - config/settings.json
''';

final _key = 'sk-' + 'q' * 30;

Future<CheckResult> _check(Directory root, {bool changedOnly = false}) =>
    BundledSecretsCheck().run(
      DoctorContext(root: root, changedOnly: changedOnly),
    );

void main() {
  test('passes when assets hold no secrets', () async {
    final root = await tempRepo({
      'pubspec.yaml': _pubspec,
      'assets/en.json': '{"hello": "Hello"}',
      'config/settings.json': '{}',
    });
    final result = await _check(root);
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });

  test('fails when a JSON asset contains a key', () async {
    final root = await tempRepo({
      'pubspec.yaml': _pubspec,
      'assets/config.json': '{"apiKey": "$_key"}',
    });
    final result = await _check(root);
    expect(result.status, CheckStatus.fail);
    final text = result.messages.join('\n');
    expect(text, contains('assets/config.json'));
    expect(text, isNot(contains(_key)));
  });

  test('fails when an asset folder contains .env', () async {
    final root = await tempRepo({
      'pubspec.yaml': _pubspec,
      'assets/.env': 'NAME=value\n',
    });
    final result = await _check(root);
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('assets/.env'));
  });

  test('fails for a single-file asset entry containing a key', () async {
    final root = await tempRepo({
      'pubspec.yaml': _pubspec,
      'config/settings.json': '{"k": "$_key"}',
    });
    final result = await _check(root);
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('config/settings.json'));
  });

  test('survives binary files in an asset folder', () async {
    final root = await tempRepo({'pubspec.yaml': _pubspec});
    await File(p.join(root.path, 'assets', 'font.ttf'))
      ..parent.createSync()
      ..writeAsBytesSync([for (var i = 0; i < 256; i++) i]);
    final result = await _check(root);
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });

  test('skips asset paths that do not exist', () async {
    final root = await tempRepo({'pubspec.yaml': _pubspec});
    expect((await _check(root)).status, CheckStatus.pass);
  });

  test('fails when Dart source under packages/ contains a key', () async {
    final root = await tempRepo({
      'pubspec.yaml': 'name: app\n',
      'packages/x/lib/src/provider.dart': "const key = '$_key';\n",
      'packages/x/.dart_tool/cache.dart': "const key = '$_key';\n",
    });
    final result = await _check(root);
    expect(result.status, CheckStatus.fail);
    expect(result.messages, [
      'packages/x/lib/src/provider.dart contains text shaped like an API key.',
    ]);
  });

  test('skips a package line opted out with the lint ignore comment', () async {
    final root = await tempRepo({
      'pubspec.yaml': 'name: app\n',
      'packages/x/test/a_test.dart':
          '// ignore: flutter_agentify_lints/no_secret_literals\n'
          "const a = '$_key';\n"
          "const b = '$_key'; // ignore: flutter_agentify_lints/no_secret_literals\n",
    });
    final result = await _check(root);
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });

  test('passes when pubspec.yaml has no flutter.assets', () async {
    final root = await tempRepo({'pubspec.yaml': 'name: app\n'});
    expect((await _check(root)).status, CheckStatus.pass);
  });

  test(
    'with changedOnly, scans only files changed against the base branch',
    () async {
      final root = await tempRepo({
        'pubspec.yaml': _pubspec,
        'assets/old.json': '{"k": "$_key"}',
      });
      await initRepo(root);
      await File(p.join(root.path, 'assets', 'new.json'))
          .writeAsString('{"hello": "Hello"}');

      expect((await _check(root)).status, CheckStatus.fail);
      expect((await _check(root, changedOnly: true)).status, CheckStatus.pass);

      await File(p.join(root.path, 'assets', 'new.json'))
          .writeAsString('{"k": "$_key"}');
      final changed = await _check(root, changedOnly: true);
      expect(changed.status, CheckStatus.fail);
      expect(changed.messages.join('\n'), contains('assets/new.json'));
      expect(changed.messages.join('\n'), isNot(contains('old.json')));
    },
  );
}
