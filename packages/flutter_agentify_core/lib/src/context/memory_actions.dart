import '../actions/action_context.dart';
import '../actions/action_failure.dart';
import '../actions/agent_action.dart';
import '../schema/schema.dart';
import '../secrets/redactor.dart';
import '../storage/memory_store.dart';

/// `save_memory`: keeps a fact for later conversations.
class SaveMemoryAction extends AgentAction<String, Memory> {
  SaveMemoryAction(this.memories);

  final MemoryStore memories;

  @override
  String get name => 'save_memory';

  @override
  String get description =>
      'Remembers a short fact about the person or their preferences for '
      'later conversations.';

  @override
  late final ObjectSchema<String> input = S.object(
    fields: {
      'text': S.string(
        description: 'The fact, in one short sentence.',
        minLength: 1,
        maxLength: 500,
      ),
    },
    build: (v) => v['text'] as String,
  );

  @override
  List<String> get resources => const ['memories'];

  @override
  bool needsApproval(String input) => true;

  @override
  Future<Memory> run(String input, ActionContext context) async {
    final text = const Redactor().redact(
      input.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
    if (text.isEmpty) {
      throw const ActionFailure('invalid_input', 'The memory is empty.');
    }
    final memory = await memories.save(text);
    context.receipt(
      resource: 'memories',
      ids: [memory.id],
      summary: 'Remembered: ${memory.text}',
      key: 'remembered',
      args: {'text': memory.text},
      verified: (await memories.all()).any((m) => m.id == memory.id),
    );
    return memory;
  }

  @override
  Object? encode(Memory output) => {'id': output.id, 'text': output.text};
}

/// `delete_memory`: forgets a fact.
class DeleteMemoryAction extends AgentAction<String, bool> {
  DeleteMemoryAction(this.memories);

  final MemoryStore memories;

  @override
  String get name => 'delete_memory';

  @override
  String get description => 'Forgets a remembered fact by its id.';

  @override
  late final ObjectSchema<String> input = S.object(
    fields: {
      'id': S.string(
        description: 'The id shown next to the memory.',
        minLength: 1,
      ),
    },
    build: (v) => v['id'] as String,
  );

  @override
  List<String> get resources => const ['memories'];

  @override
  bool needsApproval(String input) => true;

  @override
  List<String> get failureCodes => const ['not_found'];

  @override
  Future<bool> run(String input, ActionContext context) async {
    // Models copy the id with what surrounds it in the list: "(id: x)".
    final id = input.replaceAll(RegExp(r'^[\s\[(]*(id:\s*)?|[\s\])]*$'), '');
    if (!await memories.delete(id)) {
      throw ActionFailure('not_found', 'No memory has the id "$input".');
    }
    context.receipt(
      resource: 'memories',
      ids: [id],
      summary: 'Forgot memory $id',
      key: 'forgot_memory',
      args: {'id': id},
      verified: !(await memories.all()).any((m) => m.id == id),
    );
    return true;
  }

  @override
  Object? encode(bool output) => {'deleted': output};
}
