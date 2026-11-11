import 'dart:convert';
import 'dart:io';

import 'package:flutter_agentify_core/doctor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'git_repo.dart';
import 'temp_repo.dart';

const _baselinePath = 'tool/baselines/ratchet.json';

String _baseline(int ignores, int nulls, int dynamics) => jsonEncode({
  'ignore_comments': ignores,
  'null_assertions': nulls,
  'dynamic': dynamics,
});

Future<CheckResult> _check(
  Directory root, {
  bool changedOnly = false,
  bool update = false,
}) => RatchetCheck().run(
  DoctorContext(root: root, changedOnly: changedOnly, updateBaselines: update),
);

void main() {
  test('countRatchets counts ignore comments', () {
    expect(
      countRatchets(
        '// ignore: x\n// ignore_for_file: y\nvar a = 1;',
      )['ignore_comments'],
      2,
    );
  });

  test('countRatchets counts null assertions, not != or text', () {
    const src =
        "var a = b!.c; var d = e()!; if (a != d) {} var s = 'Hi!'; // wow!";
    expect(countRatchets(src)['null_assertions'], 2);
  });

  test('countRatchets does not count is! as a null assertion', () {
    expect(
      countRatchets('if (x is! String) return; var y = z!;')['null_assertions'],
      1,
    );
  });

  test('countRatchets counts dynamic as a word', () {
    expect(
      countRatchets(
        'dynamic a; Map<String, dynamic> b; var dynamics = 1;',
      )['dynamic'],
      2,
    );
  });

  test('passes when counts equal the baseline', () async {
    final root = await tempRepo({
      'lib/a.dart': 'var a = b!;\n',
      _baselinePath: _baseline(0, 1, 0),
    });
    final result = await _check(root);
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });

  test('fails when a count is above the baseline', () async {
    final root = await tempRepo({
      'lib/a.dart': 'var a = b!;\nvar c = d!;\n',
      'packages/x/lib/b.dart': 'var e = f!;\n',
      _baselinePath: _baseline(0, 2, 0),
    });
    final result = await _check(root);
    expect(result.status, CheckStatus.fail);
    expect(result.messages, contains('null_assertions: 3 > baseline 2'));
  });

  test('passes with a note when a count dropped', () async {
    final root = await tempRepo({
      'lib/a.dart': 'var a = 1;\n',
      _baselinePath: _baseline(0, 1, 0),
    });
    final result = await _check(root);
    expect(result.status, CheckStatus.pass);
    expect(result.messages.join('\n'), contains('--update-baselines'));
  });

  test('fails when the baseline file is missing', () async {
    final root = await tempRepo({'lib/a.dart': 'var a = 1;\n'});
    final result = await _check(root);
    expect(result.status, CheckStatus.fail);
    expect(result.messages.join('\n'), contains('--update-baselines'));
  });

  test('--update-baselines writes current counts and passes', () async {
    final root = await tempRepo({
      'lib/a.dart': '// ignore: x\ndynamic a = b!;\n',
    });
    final result = await _check(root, update: true);
    expect(result.status, CheckStatus.pass);
    final written = jsonDecode(
      File(p.join(root.path, _baselinePath)).readAsStringSync(),
    );
    expect(written, {'ignore_comments': 1, 'null_assertions': 1, 'dynamic': 1});
    expect((await _check(root)).status, CheckStatus.pass);
  });

  test('scope app counts lib/ only', () async {
    final root = await tempRepo({
      _baselinePath:
          '{"scope":"app","ignore_comments":0,"null_assertions":0,"dynamic":0}',
      'lib/a.dart': 'int f(int? x) => x ?? 0;',
      'packages/p/lib/b.dart': 'int g(int? x) => x!;',
    });
    final result = await _check(root);
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });

  test('--update-baselines keeps the scope', () async {
    final root = await tempRepo({
      _baselinePath:
          '{"scope":"app","ignore_comments":0,"null_assertions":5,"dynamic":0}',
      'lib/a.dart': 'int f(int? x) => x ?? 0;',
      'packages/p/lib/b.dart': 'int g(int? x) => x!;',
    });
    expect((await _check(root, update: true)).status, CheckStatus.pass);
    final written = jsonDecode(
      File(p.join(root.path, _baselinePath)).readAsStringSync(),
    );
    expect(written, {
      'scope': 'app',
      'ignore_comments': 0,
      'null_assertions': 0,
      'dynamic': 0,
    });
  });

  test('--update-baselines repairs a broken baseline', () async {
    final root = await tempRepo({
      _baselinePath: '{',
      'lib/a.dart': 'var a = b!;\n',
    });
    expect((await _check(root, update: true)).status, CheckStatus.pass);
    final written = jsonDecode(
      File(p.join(root.path, _baselinePath)).readAsStringSync(),
    );
    expect(written, {'ignore_comments': 0, 'null_assertions': 1, 'dynamic': 0});
  });

  test('skips generated files', () async {
    final root = await tempRepo({
      'lib/a.g.dart': 'var a = b!;\n',
      'lib/a.drift.dart': 'var a = b!;\n',
      'lib/a.freezed.dart': 'var a = b!;\n',
      'test/a_test.dart': 'var a = b!;\n',
      _baselinePath: _baseline(0, 0, 0),
    });
    final result = await _check(root);
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });

  test(
    'with changedOnly, fails when an added line contains an ignore comment',
    () async {
      final root = await tempRepo({'lib/a.dart': 'var a = 1;\n'});
      await initRepo(root);
      await File(p.join(root.path, 'lib', 'a.dart'))
          .writeAsString('var a = 1;\n// ignore: x\nvar b = 2;\n');
      final result = await _check(root, changedOnly: true);
      expect(result.status, CheckStatus.fail);
      expect(result.messages.join('\n'), contains('lib/a.dart'));
    },
  );

  test('with changedOnly, passes when old lines contain one but added lines do not', () async {
    final root = await tempRepo({'lib/a.dart': '// ignore: x\nvar a = 1;\n'});
    await initRepo(root);
    await File(p.join(root.path, 'lib', 'a.dart'))
        .writeAsString('// ignore: x\nvar a = 1;\nvar b = 2;\n');
    final result = await _check(root, changedOnly: true);
    expect(result.messages, isEmpty);
    expect(result.status, CheckStatus.pass);
  });

  test(
    'with changedOnly outside a git repository, the doctor returns 2',
    () async {
      final root = await tempRepo({'lib/a.dart': 'var a = 1;\n'});
      final out = StringBuffer();
      final code = await runDoctor(
        ['--changed'],
        root: root,
        out: out,
        checks: [RatchetCheck()],
      );
      expect(code, 2);
      expect(out.toString(), contains('ERROR ratchet'));
    },
  );

  test(
    'with changedOnly and a missing base branch, the doctor returns 2',
    () async {
      final root = await tempRepo({'lib/a.dart': 'var a = 1;\n'});
      await initRepo(root);
      final out = StringBuffer();
      final code = await runDoctor(
        ['--changed', '--base', 'nope'],
        root: root,
        out: out,
        checks: [RatchetCheck()],
      );
      expect(code, 2);
      expect(out.toString(), contains('nope'));
    },
  );

  test('countRatchets counts a ! inside an interpolation', () {
    expect(countRatchets(r"final s = 'a ${x!} b';")['null_assertions'], 1);
  });

  test('countRatchets ignores // ignore: text inside a string', () {
    expect(countRatchets("final s = '// ignore: foo';")['ignore_comments'], 0);
    expect(countRatchets('// ignore: foo\nfinal a = 1;')['ignore_comments'], 1);
  });
}
