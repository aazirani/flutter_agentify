import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';

/// Echoes its `text` field back. Read-only.
class EchoAction extends AgentAction<String, String> {
  @override
  String get name => 'echo';

  @override
  String get description => 'Repeats the text.';

  @override
  late final ObjectSchema<String> input = S.object(
    fields: {'text': S.string(description: 'The text to repeat.')},
    build: (v) => v['text'] as String,
  );

  @override
  bool get readOnly => true;

  @override
  Future<String> run(String input, ActionContext context) async => input;

  @override
  Object? encode(String output) => output;
}

/// Deletes notes; needs approval and records a receipt.
class WipeAction extends AgentAction<String, String> {
  WipeAction({this.summary, this.allowAlways = true});

  /// The line the approval card shows.
  final String? summary;
  final wiped = <String>[];

  @override
  final bool allowAlways;

  @override
  Future<String?> approvalSummary(String input) async => summary;

  @override
  String get name => 'wipe';

  @override
  String get description => 'Deletes notes in a folder.';

  @override
  late final ObjectSchema<String> input = S.object(
    fields: {'folder': S.string(description: 'The folder to empty.')},
    build: (v) => v['folder'] as String,
  );

  @override
  List<String> get resources => const ['notes'];

  @override
  bool needsApproval(String input) => true;

  @override
  Future<String> run(String input, ActionContext context) async {
    wiped.add(input);
    context.receipt(resource: 'notes', ids: [input], summary: 'Emptied $input');
    return 'done';
  }

  @override
  Object? encode(String output) => output;
}

/// A controller over a scripted model.
class ChatFixture {
  ChatFixture(
    List<ScriptedStep> steps, {
    ModelConfig model = const ModelConfig(model: 'test'),
    AgentConfig config = const AgentConfig(),
    WipeAction? wipe,
    InMemoryThreadStore? threads,
  }) : provider = ScriptedProvider(steps),
       threads = threads ?? InMemoryThreadStore(),
       wipe = wipe ?? WipeAction() {
    session = AgentSession(
      registry: ActionRegistry([EchoAction(), this.wipe]),
      appContext: AppContext(
        screens: {
          '/': ScreenContext((_) => {'items': 3}),
        },
      ),
      provider: provider,
      model: model,
      threads: this.threads,
      memories: InMemoryMemoryStore(),
      config: config,
      delay: (_) async {},
    );
    controller = AssistantController(session: session, threads: this.threads);
  }

  final ScriptedProvider provider;
  final InMemoryThreadStore threads;
  final WipeAction wipe;
  late final AgentSession session;
  late final AssistantController controller;

  AssistantItem get lastAssistant =>
      controller.items.whereType<AssistantItem>().last;
}

ToolCall call(String id, String name, String json) =>
    ToolCall(id: id, name: name, rawArguments: json);
