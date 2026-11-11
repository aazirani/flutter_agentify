import 'package:flutter_agentify_core/doctor.dart';
import 'package:test/test.dart';

import 'temp_repo.dart';

class _FakeCheck implements DoctorCheck {
  _FakeCheck(this.name, this._run);

  @override
  final String name;
  final Future<CheckResult> Function() _run;
  bool ran = false;

  @override
  Future<CheckResult> run(DoctorContext context) {
    ran = true;
    return _run();
  }
}

_FakeCheck _returning(String name, CheckStatus status, [List<String>? m]) =>
    _FakeCheck(name, () async => CheckResult(status, m ?? const []));

void main() {
  Future<(int, String)> doctor(
    List<String> args,
    List<DoctorCheck> checks,
  ) async {
    final out = StringBuffer();
    final root = await tempRepo({});
    final code = await runDoctor(args, root: root, out: out, checks: checks);
    return (code, out.toString());
  }

  test('all pass returns 0', () async {
    final (code, out) = await doctor([], [
      _returning('a', CheckStatus.pass),
      _returning('b', CheckStatus.pass),
    ]);
    expect(code, 0);
    expect(out, contains('PASS a'));
    expect(out, contains('PASS b'));
  });

  test('a failing check returns 1 and prints messages', () async {
    final (code, out) = await doctor([], [
      _returning('a', CheckStatus.fail, ['boom']),
    ]);
    expect(code, 1);
    expect(out, contains('FAIL a'));
    expect(out, contains('  boom'));
  });

  test('could-not-run returns 2 even when another fails', () async {
    final (code, out) = await doctor([], [
      _returning('a', CheckStatus.couldNotRun),
      _returning('b', CheckStatus.fail),
    ]);
    expect(code, 2);
    expect(out, contains('ERROR a'));
    expect(out, contains('FAIL b'));
  });

  test('a check that throws is reported as ERROR and returns 2', () async {
    final (code, out) = await doctor([], [
      _FakeCheck('a', () async => throw StateError('kaput')),
    ]);
    expect(code, 2);
    expect(out, contains('ERROR a'));
    expect(out, contains('kaput'));
  });

  test('--only runs just the named checks', () async {
    final a = _returning('a', CheckStatus.pass);
    final b = _returning('b', CheckStatus.pass);
    final (code, out) = await doctor(['--only', 'b'], [a, b]);
    expect(code, 0);
    expect(a.ran, isFalse);
    expect(b.ran, isTrue);
    expect(out, isNot(contains('PASS a')));
  });

  test('--only with an unknown name returns 2', () async {
    final (code, out) = await doctor(
      ['--only', 'nope'],
      [_returning('a', CheckStatus.pass)],
    );
    expect(code, 2);
    expect(out, contains('nope'));
  });

  test('unknown flag returns 2', () async {
    final (code, _) = await doctor(
      ['--wat'],
      [_returning('a', CheckStatus.pass)],
    );
    expect(code, 2);
  });
}
