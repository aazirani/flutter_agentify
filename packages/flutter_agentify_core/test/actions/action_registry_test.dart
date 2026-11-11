import 'dart:convert';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:test/test.dart';

import 'fake_action.dart';

Matcher _failure(String code) =>
    throwsA(isA<ActionFailure>().having((f) => f.code, 'code', code));

Matcher _definitionError(String action) => throwsA(
  isA<ActionDefinitionError>().having((e) => e.action, 'action', action),
);

void main() {
  late ActionRegistry reg;
  setUp(() => reg = ActionRegistry([echo(), addNote(), wipe()]));

  group('definition checks', () {
    test('a duplicate name throws ActionDefinitionError naming it', () {
      expect(() => ActionRegistry([echo(), echo()]), _definitionError('echo'));
    });

    test('a name that is not snake_case throws', () {
      for (final name in ['AddNote', 'add-note', '', '1add', 'a' * 65]) {
        expect(
          () => ActionRegistry([FakeAction(name)]),
          throwsA(isA<ActionDefinitionError>()),
          reason: name,
        );
      }
    });

    test('an empty or multi-line description throws', () {
      expect(
        () => ActionRegistry([FakeAction('a', description: ' ')]),
        _definitionError('a'),
      );
      expect(
        () => ActionRegistry([FakeAction('a', description: 'One.\nTwo.')]),
        _definitionError('a'),
      );
    });

    test('the name tool_search is reserved', () {
      expect(
        () => ActionRegistry([FakeAction('tool_search')]),
        _definitionError('tool_search'),
      );
    });

    test('a writing action without resources throws', () {
      expect(
        () => ActionRegistry([FakeAction('a', resources: const [])]),
        _definitionError('a'),
      );
    });

    test('a blank field description throws ActionDefinitionError naming the '
        'action', () {
      expect(
        () => ActionRegistry([FakeAction('a', fieldDescription: '')]),
        _definitionError('a'),
      );
    });

    test(
      'tools excludes actions with agentTool false; all is sorted by name',
      () {
        final r = ActionRegistry([
          wipe(),
          FakeAction('ui_only', agentTool: false),
          echo(),
        ]);
        expect(r.all.map((a) => a.name), ['echo', 'ui_only', 'wipe']);
        expect(r.tools.map((a) => a.name), ['echo', 'wipe']);
        expect(r.find('echo'), isNotNull);
        expect(r.find('nope'), isNull);
      },
    );
  });

  group('calling', () {
    test('call parses JSON input and returns encoded content', () async {
      final result = await reg.call('echo', {
        'text': 'hi',
      }, caller: Caller.assistant);
      expect(result.name, 'echo');
      expect(result.output, 'hi');
      expect(result.content, '"hi"');
    });

    test('unknown action throws unknown_action', () async {
      await expectLater(
        reg.call('nope', {}, caller: Caller.assistant),
        _failure('unknown_action'),
      );
    });

    test('the assistant cannot call a UI-only action', () async {
      final r = ActionRegistry([FakeAction('ui_only', agentTool: false)]);
      await expectLater(
        r.call('ui_only', {'text': 'x'}, caller: Caller.assistant),
        _failure('unknown_action'),
      );
      expect(
        (await r.call('ui_only', {'text': 'x'}, caller: Caller.cli)).output,
        'x',
      );
    });

    test(
      'invalid input throws invalid_input with the field path in details',
      () async {
        await expectLater(
          reg.call('echo', {'text': 3}, caller: Caller.assistant),
          throwsA(
            isA<ActionFailure>()
                .having((f) => f.code, 'code', 'invalid_input')
                .having((f) => f.details?['path'], 'path', r'$.text'),
          ),
        );
      },
    );

    test(
      'an unexpected exception becomes internal_error without a stack trace',
      () async {
        final r = ActionRegistry([
          FakeAction(
            'boom',
            readOnly: true,
            resources: const [],
            run: (_, _) async => throw StateError('kaput'),
          ),
        ]);
        await expectLater(
          r.call('boom', {'text': 'x'}, caller: Caller.assistant),
          throwsA(
            isA<ActionFailure>()
                .having((f) => f.code, 'code', 'internal_error')
                .having((f) => f.message, 'message', contains('kaput'))
                .having((f) => f.message, 'message', isNot(contains('#0'))),
          ),
        );
      },
    );

    test(
      'an ActionFailure thrown by the action keeps its code and message',
      () async {
        const failure = ActionFailure('not_found', 'No such note.');
        final r = ActionRegistry([
          FakeAction('find', run: (_, _) async => throw failure),
        ]);
        await expectLater(
          r.call('find', {'text': 'x'}, caller: Caller.cli),
          throwsA(
            isA<ActionFailure>()
                .having((f) => f.code, 'code', 'not_found')
                .having((f) => f.message, 'message', 'No such note.'),
          ),
        );
      },
    );

    test('a slow action throws timeout', () async {
      final r = ActionRegistry([
        FakeAction(
          'slow',
          timeout: const Duration(milliseconds: 10),
          run: (_, _) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return 'late';
          },
        ),
      ]);
      await expectLater(
        r.call('slow', {'text': 'x'}, caller: Caller.cli),
        _failure('timeout'),
      );
    });

    test('a result cut at an emoji stays valid', () async {
      final reg = ActionRegistry([
        FakeAction(
          'big',
          maxResultChars: 10,
          run: (_, _) async => 'abcdefgh😀z',
        ),
      ]);
      final result = await reg.call('big', {
        'text': '',
      }, caller: Caller.assistant);
      final units = result.content.codeUnits;
      expect(
        units.where((u) => u >= 0xD800 && u <= 0xDBFF).length,
        units.where((u) => u >= 0xDC00 && u <= 0xDFFF).length,
      );
    });

    test('content is cut to maxResultChars with a truncation note', () async {
      final r = ActionRegistry([
        FakeAction('big', maxResultChars: 100, run: (_, _) async => 'x' * 500),
      ]);
      final result = await r.call('big', {'text': 'x'}, caller: Caller.cli);
      expect(result.content, startsWith('"${'x' * 99}'));
      expect(result.content, endsWith('…[truncated 402 characters]'));
      expect(result.output, 'x' * 500);
    });

    test('content has key-looking values redacted', () async {
      final key = 'sk-' + 'a' * 30;
      final r = ActionRegistry([
        FakeAction('leak', run: (_, _) async => {'config': 'key=$key'}),
      ]);
      final result = await r.call('leak', {'text': 'x'}, caller: Caller.cli);
      expect(result.content, isNot(contains(key)));
      expect(jsonDecode(result.content), {'config': 'key=[redacted]'});
    });

    test('an error thrown while building the input is invalid_input, and '
        'requiresApproval is false', () async {
      final r = ActionRegistry([BookAction()]);
      await expectLater(
        r.call('book', {'date': 'soon'}, caller: Caller.cli),
        _failure('invalid_input'),
      );
      expect(r.requiresApproval('book', {'date': 'soon'}), isFalse);
      expect(r.requiresApproval('book', {'date': '2026-01-01'}), isTrue);
    });

    test('an internal_error message is redacted too', () async {
      final key = 'sk-' + 'b' * 30;
      final r = ActionRegistry([
        FakeAction('leak', run: (_, _) async => throw StateError('bad $key')),
      ]);
      await expectLater(
        r.call('leak', {'text': 'x'}, caller: Caller.cli),
        throwsA(
          isA<ActionFailure>().having(
            (f) => f.message,
            'message',
            isNot(contains(key)),
          ),
        ),
      );
    });
  });

  group('approval', () {
    test('assistant call to a needsApproval action without approved throws '
        'approval_required', () async {
      await expectLater(
        reg.call('wipe', {'text': 'x'}, caller: Caller.assistant),
        _failure('approval_required'),
      );
    });

    test('cli call without approved throws approval_required', () async {
      await expectLater(
        reg.call('wipe', {'text': 'x'}, caller: Caller.cli),
        _failure('approval_required'),
      );
    });

    test('assistant call with approved: true runs', () async {
      final result = await reg.call(
        'wipe',
        {'text': 'x'},
        caller: Caller.assistant,
        approved: true,
      );
      expect(result.output, 'wiped');
    });

    test('call refuses the ui caller, so JSON input never skips approval', () {
      expect(
        reg.call('wipe', {'text': 'x'}, caller: Caller.ui),
        throwsArgumentError,
      );
    });

    test('requiresApproval is true for wipe, false for echo, false for invalid '
        'input', () {
      expect(reg.requiresApproval('wipe', {'text': 'x'}), isTrue);
      expect(reg.requiresApproval('echo', {'text': 'x'}), isFalse);
      expect(reg.requiresApproval('wipe', {'text': 3}), isFalse);
      expect(reg.requiresApproval('nope', {}), isFalse);
    });
  });

  group('change events and receipts', () {
    test('a successful write emits one ChangeEvent per resource', () async {
      final r = ActionRegistry([
        FakeAction('move', resources: const ['notes', 'folders']),
      ]);
      final events = <ChangeEvent>[];
      r.changes.listen(events.add);
      await r.call('move', {'text': 'x'}, caller: Caller.assistant);
      expect(events.map((e) => e.resource), ['notes', 'folders']);
      expect(events.every((e) => e.succeeded), isTrue);
      expect(events.first.action, 'move');
      expect(events.first.caller, Caller.assistant);
    });

    test(
      'a failed write still emits a ChangeEvent with succeeded false',
      () async {
        final r = ActionRegistry([
          FakeAction('half', run: (_, _) async => throw StateError('midway')),
        ]);
        final events = <ChangeEvent>[];
        r.changes.listen(events.add);
        await expectLater(
          r.call('half', {'text': 'x'}, caller: Caller.cli),
          _failure('internal_error'),
        );
        expect(events, hasLength(1));
        expect(events.single.succeeded, isFalse);
      },
    );

    test('a read-only action emits nothing', () async {
      final events = <ChangeEvent>[];
      reg.changes.listen(events.add);
      await reg.call('echo', {'text': 'x'}, caller: Caller.cli);
      expect(events, isEmpty);
    });

    test('receipts recorded through the context are returned', () async {
      final result = await reg.call('add_note', {
        'text': 'Milk',
      }, caller: Caller.assistant);
      expect(result.receipts, hasLength(1));
      final receipt = result.receipts.single;
      expect(receipt.summary, 'Added "Milk"');
      expect(receipt.ids, ['n1']);
      expect(Receipt.fromJson(receipt.toJson()).toJson(), receipt.toJson());
    });

    test('a receipt keeps its translation key and values when stored', () {
      const receipt = Receipt(
        resource: 'notes',
        ids: ['n1'],
        summary: 'Added "Milk"',
        key: 'added_note',
        args: {'text': 'Milk'},
      );
      final back = Receipt.fromJson(receipt.toJson());
      expect(back.key, 'added_note');
      expect(back.args, {'text': 'Milk'});
      // A receipt stored before keys existed still reads.
      final old = Receipt.fromJson(const {
        'resource': 'notes',
        'ids': ['n1'],
        'summary': 'Added "Milk"',
      });
      expect(old.key, isNull);
      expect(old.args, isEmpty);
    });
  });

  group('typed path', () {
    test('run returns the typed output and emits change events', () async {
      final note = addNote();
      final r = ActionRegistry([note]);
      final events = <ChangeEvent>[];
      r.changes.listen(events.add);
      final output = await r.run(note, 'Milk');
      expect(output, {'id': 'n1'});
      expect(events.single.caller, Caller.ui);
    });

    test(
      'run with an action instance that is not registered throws StateError',
      () {
        expect(() => reg.run(addNote(), 'Milk'), throwsStateError);
      },
    );
  });

  test('CancelToken completes whenCancelled once', () async {
    final token = CancelToken();
    expect(token.isCancelled, isFalse);
    token
      ..cancel()
      ..cancel();
    await token.whenCancelled;
    expect(token.isCancelled, isTrue);
  });
}
