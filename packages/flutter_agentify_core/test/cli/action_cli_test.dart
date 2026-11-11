import 'dart:io';

import 'package:flutter_agentify_core/cli.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../actions/fake_action.dart';
import '../doctor/temp_repo.dart';

void main() {
  late StringBuffer out;
  late StringBuffer err;
  late String reference;
  final registry = ActionRegistry([echo(), addNote(), wipe()]);

  setUp(() async {
    out = StringBuffer();
    err = StringBuffer();
    reference = p.join((await tempRepo({})).path, 'docs', 'actions.md');
  });

  Future<int> cli(List<String> args) => runActionCli(
    registry,
    args,
    referencePath: reference,
    out: out,
    err: err,
  );

  test('--list prints one action name per line', () async {
    expect(await cli(['--list']), 0);
    expect(out.toString(), 'add_note\necho\nwipe\n');
  });

  test(
    'running an action prints its content and receipts, returns 0',
    () async {
      expect(await cli(['add_note', '{"text":"Milk"}']), 0);
      expect(out.toString(), '{"id":"n1"}\nreceipt: Added "Milk"\n');
      expect(err.toString(), isEmpty);
    },
  );

  test('invalid JSON returns 64', () async {
    expect(await cli(['echo', '{"text":']), 64);
    expect(err.toString(), contains('JSON'));
  });

  test('an unknown action returns 1 and prints unknown_action', () async {
    expect(await cli(['nope', '{}']), 1);
    expect(err.toString(), startsWith('unknown_action: '));
  });

  test('invalid input returns 1 with the field path', () async {
    expect(await cli(['echo', '{"text":3}']), 1);
    expect(err.toString(), contains(r'$.text'));
  });

  test('a needsApproval action without --approved returns 1 with '
      'approval_required', () async {
    expect(await cli(['wipe', '{"text":"all"}']), 1);
    expect(err.toString(), startsWith('approval_required: '));
  });

  test('a failure message is printed redacted', () async {
    final key = 'sk-' + 'd' * 30;
    final leaky = ActionRegistry([
      FakeAction('leak', run: (_, _) => throw ActionFailure('bad', 'key $key')),
    ]);
    final code = await runActionCli(
      leaky,
      ['leak', '{"text":"x"}'],
      referencePath: reference,
      out: out,
      err: err,
    );
    expect(code, 1);
    expect(err.toString(), 'bad: key [redacted]\n');
  });

  test('with --approved it runs', () async {
    expect(await cli(['wipe', '{"text":"all"}', '--approved']), 0);
    expect(out.toString(), '"wiped"\n');
  });

  test('--write-reference writes the file', () async {
    expect(await cli(['--write-reference']), 0);
    expect(File(reference).readAsStringSync(), buildActionReference(registry));
  });

  test('no arguments returns 64 and prints usage', () async {
    expect(await cli([]), 64);
    expect(err.toString(), contains('--list'));
  });

  test('an unknown flag returns 64', () async {
    expect(await cli(['echo', '{"text":"x"}', '--force']), 64);
  });

  test('a missing JSON argument means {}', () async {
    final r = ActionRegistry([ViewScreenAction(AppContext(screens: const {}))]);
    final code = await runActionCli(
      r,
      ['view_screen'],
      referencePath: reference,
      out: out,
      err: err,
    );
    expect(code, 0);
  });
}
