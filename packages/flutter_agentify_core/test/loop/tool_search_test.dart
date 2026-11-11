import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:test/test.dart';

import '../actions/fake_action.dart';
import 'loop_fixtures.dart';

class _Hinted extends FakeAction {
  _Hinted(super.name, {required super.description, this.hints = const []});

  final List<String> hints;

  @override
  List<String> get searchHints => hints;
}

/// Nine app actions; with the four built-ins that makes 13 tools.
List<AgentAction<Object?, Object?>> _appActions() => [
  FakeAction('add_item', description: 'Adds an item to the list.'),
  FakeAction('delete_item', description: 'Deletes an item.'),
  FakeAction('rename_item', description: 'Gives an item a new title.'),
  FakeAction(
    'list_items',
    description: 'Lists the items.',
    readOnly: true,
    resources: const [],
  ),
  FakeAction('set_theme', description: 'Switches between light and dark mode.'),
  FakeAction('set_language', description: 'Changes the app language.'),
  FakeAction('export_data', description: 'Writes all data to a file.'),
  FakeAction('import_data', description: 'Reads data from a file.'),
  FakeAction('share_item', description: 'Shares an item with someone.'),
];

LoopFixture _fixture(
  List<ScriptedStep> steps, {
  int contextWindow = 8000,
  AgentConfig config = const AgentConfig(toolSearchShare: 0.05),
  List<AgentAction<Object?, Object?>>? actions,
}) {
  final memories = InMemoryMemoryStore();
  return LoopFixture(
    steps,
    model: ModelConfig(model: 'm', contextWindow: contextWindow),
    config: config,
    actions:
        actions ??
        [
          ...builtInActions(
            appContext: AppContext(screens: const {}),
            memories: memories,
          ),
          ..._appActions(),
        ],
  );
}

List<String> _sent(LoopFixture f, int request) =>
    f.provider.requests[request].tools.map((t) => t.name).toList();

void main() {
  group('searchTools', () {
    final tools = _appActions();

    test('searchTools ranks name matches above description matches', () {
      final found = searchTools([
        FakeAction('note_text', description: 'Add an item.'),
        FakeAction('add_note', description: 'Writes text.'),
      ], 'add');
      expect(found.map((t) => t.name), ['add_note', 'note_text']);
    });

    test('searchTools ignores stop words and matches short words whole', () {
      final found = searchTools([
        FakeAction('set_theme_mode', description: 'Switches the theme.'),
        FakeAction('update_item', description: 'Changes an item title.'),
      ], 'what is the weather');
      expect(found, isEmpty);
      expect(
        searchTools([
          FakeAction('set_theme_mode', description: 'Switches the theme.'),
          FakeAction('update_item', description: 'Changes an item title.'),
        ], 'Change the description of milk').map((t) => t.name),
        ['update_item'],
      );
    });

    test('searchTools still finds a longer word by its prefix', () {
      final found = searchTools([
        _Hinted('update_item', description: 'Edits.', hints: ['rename']),
      ], 'rename');
      expect(found, hasLength(1));
    });

    test('searchTools uses searchHints', () {
      final found = searchTools([
        ...tools,
        _Hinted(
          'set_units',
          description: 'Sets units.',
          hints: ['metric', 'imperial'],
        ),
      ], 'metric');
      expect(found.map((t) => t.name), ['set_units']);
    });

    test('searchTools returns at most limit results and none for no match', () {
      expect(searchTools(tools, 'item', limit: 2), hasLength(2));
      expect(searchTools(tools, 'item'), hasLength(5));
      expect(searchTools(tools, 'zebra'), isEmpty);
      expect(searchTools(tools, '  '), isEmpty);
    });
  });

  test('with 13 tools and a small window, a step sends built-ins, tool_search '
      'and at most 4 matches', () async {
    final f = _fixture([ScriptedStep.text('ok')]);
    expect(f.registry.tools, hasLength(13));
    await f.send('Please add an item called milk');
    final sent = _sent(f, 0);
    expect(sent, containsAll(builtInActionNames));
    expect(sent, contains('tool_search'));
    expect(sent, contains('add_item'));
    expect(sent.length, lessThanOrEqualTo(4 + 4 + 1));
    expect(sent, isNot(contains('export_data')));
  });

  test('with 13 tools and a large window, every tool is sent and there is no '
      'tool_search', () async {
    final f = _fixture([ScriptedStep.text('ok')], contextWindow: 128000);
    await f.send('Add milk');
    expect(_sent(f, 0), hasLength(13));
    expect(_sent(f, 0), isNot(contains('tool_search')));
  });

  test('calling tool_search activates the matches for the next step', () async {
    final f = _fixture([
      ScriptedStep.toolCalls([
        call('c1', 'tool_search', {'query': 'dark mode'}),
      ]),
      ScriptedStep.text('ok'),
    ]);
    final events = await f.send('Hello');
    expect(_sent(f, 0), isNot(contains('set_theme')));
    final finished = events.whereType<ToolFinished>().single;
    expect(finished.isError, isFalse);
    expect(finished.content, contains('set_theme'));
    expect(_sent(f, 1), contains('set_theme'));
  });

  test(
    'activated tools stay active in a later run on the same thread',
    () async {
      final f = _fixture([
        ScriptedStep.toolCalls([
          call('c1', 'tool_search', {'query': 'export'}),
        ]),
        ScriptedStep.text('ok'),
        ScriptedStep.text('again'),
      ]);
      await f.send('Hello');
      await f.send('Thanks');
      expect(_sent(f, 2), contains('export_data'));
    },
  );

  test('the default turns tool search on by the tool definitions\' share of '
      'a small window, not by their count', () async {
    final few = _fixture([
      ScriptedStep.text('ok'),
    ], config: const AgentConfig());
    await few.send('Hi');
    expect(_sent(few, 0), isNot(contains('tool_search')));

    final big = _fixture(
      [ScriptedStep.text('ok')],
      contextWindow: 2000,
      config: const AgentConfig(),
    );
    await big.send('Hi');
    expect(_sent(big, 0), contains('tool_search'));
  });

  test('a follow-up message keeps the tool a earlier message matched, and the '
      'remembered set is capped', () async {
    final f = _fixture([
      ScriptedStep.text('one'),
      ScriptedStep.text('two'),
      ScriptedStep.text('three'),
    ]);
    await f.send('Please export everything');
    await f.send('Thanks');
    expect(_sent(f, 1), contains('export_data'));
    // Many later matches push the oldest out.
    await f.send('add delete rename list share import language theme item');
    expect(
      _sent(f, 2).where((n) => !builtInActionNames.contains(n)),
      hasLength(lessThanOrEqualTo(8 + 1)),
    );
  });

  test(
    'a call to a tool that was not sent is refused with a hint to search',
    () async {
      final f = _fixture([
        ScriptedStep.toolCalls([call('c1', 'export_data', {})]),
        ScriptedStep.text('ok'),
      ]);
      final events = await f.send('Hello');
      final finished = events.whereType<ToolFinished>().single;
      expect(finished.isError, isTrue);
      expect(finished.errorCode, 'tool_not_available');
      expect(finished.content, contains('tool_search'));
    },
  );

  test('forceToolSearch turns it on with few tools', () async {
    final f = LoopFixture([
      ScriptedStep.text('ok'),
    ], config: const AgentConfig(forceToolSearch: true));
    await f.send('Hi');
    expect(_sent(f, 0), contains('tool_search'));
  });
}
