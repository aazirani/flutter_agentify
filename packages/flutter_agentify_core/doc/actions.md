# Actions

An action is one capability of the app, written once and called the same way by the app's UI, by the assistant and by the action CLI. Whatever the UI can do goes through an action, so the assistant can do it too.

## Smallest example

```dart
class AddNote extends AgentAction<String, Note> {
  AddNote(this.notes);
  final NotesRepository notes;

  @override
  String get name => 'add_note';

  @override
  String get description => 'Adds a note with the given text.';

  @override
  late final ObjectSchema<String> input = S.object(
    fields: {'text': S.string(description: 'The note text.', minLength: 1)},
    build: (v) => v['text'] as String,
  );

  @override
  List<String> get resources => const ['notes'];

  @override
  Future<Note> run(String text, ActionContext context) async {
    final note = await notes.add(text);
    context.receipt(resource: 'notes', ids: [note.id], summary: 'Added "$text"');
    return note;
  }

  @override
  Object? encode(Note note) => {'id': note.id, 'text': note.text};
}

final addNote = AddNote(notesRepository);
final registry = ActionRegistry([addNote]);

// From the UI (typed, never paused for approval); `run` takes the registered instance:
final note = await registry.run(addNote, 'Buy milk');

// From the assistant or the CLI (JSON in; `result.content` is the JSON text, `result.receipts` the receipts).
// `call` refuses `Caller.ui` with an `ArgumentError`, so JSON input never skips approval:
final result = await registry.call('add_note', {'text': 'Buy milk'}, caller: Caller.assistant);
```

## Rules

- `name` is unique `snake_case`, starts with a letter and has at most 64 characters; `tool_search` is reserved. `description` is one non-empty line.
- Every input field has a description: the schema builder (`S.string`, `S.integer`, `S.number`, `S.boolean`, `S.list`, `S.object`, `S.none`) requires one, and the registry rejects a blank one when it starts.
- An action that is not `readOnly` lists the data it writes in `resources`. After every call, success or failure, the registry emits one `ChangeEvent` per resource on `registry.changes`, so screens can refresh. Call `registry.dispose()` when the registry is no longer used; it closes that stream.
- Actions are deterministic: they never call a model.
- Report failure by throwing `ActionFailure(code, message, details: ...)`, never by returning an error value. List your own codes in `failureCodes`. The registry fills `ActionFailure.receipts` with what the action had recorded before it failed, so a partial write is still shown.
- Record what changed with `context.receipt(...)`. The chat shows receipts under the assistant's reply, whatever the model says. Give it a `key` and `args` to show it in the app's language; without them the chat shows the English `summary`.
- `needsApproval(input)` returning true makes calls from the assistant and the CLI wait for the person's approval. Calls from the UI are never paused.
- `agentTool => false` keeps an action out of the assistant's tools (UI only).
- The model gets `encode(output)` as JSON, with key-shaped text replaced by `[redacted]` and cut to `maxResultChars` (default 4000). Cut text with `cutText(text, max, suffix: ...)`, which never leaves half an emoji.
- Each call has a `timeout` (default 30 seconds). After it the caller gets `timeout` but the action keeps running, so a long action checks `context.cancel` before each write.
- `searchHints` adds words that help tool search find the action (see [agent loop](agent-loop.md)).

## Failure codes

| Code | When |
|---|---|
| `unknown_action` | No action has that name, or the assistant called a UI-only action. |
| `invalid_input` | The input does not match the schema. `details['path']` points at the field, such as `$.text`. |
| `approval_required` | The assistant or the CLI called an action that needs approval without it. |
| `timeout` | The action ran longer than its `timeout`. |
| `internal_error` | The action threw something other than `ActionFailure`. The message has no stack trace. |
