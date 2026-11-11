# Build your first feature

In this tutorial you add a notes feature to an empty project, by hand. The person can list, add and delete notes on a screen at `/notes`. The assistant can do the same through three actions: `list_notes`, `create_note` and `delete_note`. A delete by the assistant asks the person first.

You touch every layer once: the database, the domain, the actions, the screen and the assistant's view of it. Each file is shown in full, or as an exact edit. Copy the code blocks and run the commands in order.

Read [Architecture](../concepts/architecture.md) and [Actions](../concepts/actions.md) first if the layers are new to you.

## 1. Create an empty project

```bash
git clone --depth 1 https://github.com/aazirani/flutter_agentify.git notes_app
cd notes_app
dart tool/setup.dart --name notes_app --org com.example --starter empty
git add -A && git commit -m "Set up notes_app"
flutter pub get
dart run build_runner build
```

Committing right after setup keeps its changes apart from yours, and `git diff` shows only what you add. Run every command below from the `notes_app` folder. If you choose another `--name`, change `package:notes_app/` in the code to match.

The `empty` starter keeps the item example from the template in `.agents/example/`. It is not compiled. This tutorial follows the same shape.

## 2. The table

A note has an id, a body and the time it was made.

Create `lib/data/local/database/tables/notes_table.dart`:

```dart
import 'package:drift/drift.dart';

/// The person's notes.
@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

`@DataClassName('NoteRow')` keeps drift's row class apart from the `Note` entity you write later.

## 3. The database

Add the table to the database and raise `schemaVersion` from 1 to 2. Installed apps already have a version 1 database, so `onUpgrade` creates the new table for them. Only add tables or nullable columns; see [Architecture](../concepts/architecture.md).

Replace `lib/data/local/database/app_database.dart` with:

```dart
import 'package:drift/drift.dart';

import 'tables/assistant_tables.dart';
import 'tables/notes_table.dart';

part 'app_database.drift.dart';

/// The app's database. The connection is passed in, so the same code runs
/// under Flutter (`openAppConnection`) and in plain Dart (the action CLI and
/// tests).
@DriftDatabase(
  tables: [AssistantThreads, AssistantMessages, AssistantMemories, Notes],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) => m.createAll(),
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) await m.createTable(notes);
      },
    );
  }
}
```

Generate the code, save the version 2 schema, and generate the helpers the migration test uses:

```bash
dart run build_runner build
dart run drift_dev schema dump lib/data/local/database/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
dart format test/generated_migrations
```

The dump writes `drift_schemas/drift_schema_v2.json`. The gate compares it with the code, so a table change without a new version fails.

## 4. The migration test

The test builds a version 1 database, puts a row in it, upgrades it to version 2 and checks the row is still there.

Create `test/data/local/database/migrations/to_v2_test.dart`:

```dart
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/data/local/database/app_database.dart';

import '../../../../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('upgrading from version 1 keeps memories and adds notes', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      'INSERT INTO assistant_memories (id, body, created_at) '
      "VALUES ('m', 'Likes tea', 0)",
    );
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    expect(await db.select(db.assistantMemories).get(), hasLength(1));
    expect(await db.select(db.notes).get(), isEmpty);
    await db.close();
  });
}
```

Run it:

```bash
flutter test test/data/local/database/migrations/to_v2_test.dart
```

## 5. The entity

The domain knows a note as a plain Dart class. It does not import drift or Flutter.

Create `lib/domain/entities/note.dart`:

```dart
/// One note the person keeps.
class Note {
  const Note({required this.id, required this.body, required this.createdAt});

  final String id;
  final String body;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
  };
}
```

## 6. The repository

The interface lives in the domain. Screens read through its `watch…` and `get…` members. Only actions call the others.

Create `lib/domain/repositories/notes_repository.dart`:

```dart
import '../entities/note.dart';

/// The app's notes. Screens read through `watch…` and `get…`; every change
/// goes through an action.
abstract class NotesRepository {
  /// Newest first.
  Stream<List<Note>> watchNotes();

  /// Newest first, at most [limit].
  Future<List<Note>> getNotes({int limit = 50});

  Future<int> getNoteCount();

  Future<Note?> getNote(String id);

  Future<Note> createNote(String body);

  /// False when [id] does not exist.
  Future<bool> deleteNote(String id);
}
```

The drift implementation lives in the data layer.

Create `lib/data/repositories/drift_notes_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/note.dart';
import '../../domain/repositories/notes_repository.dart';
import '../local/database/app_database.dart';

class DriftNotesRepository implements NotesRepository {
  DriftNotesRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  SimpleSelectStatement<$NotesTable, NoteRow> _newestFirst() =>
      _db.select(_db.notes)..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.rowId),
      ]);

  static Note _toNote(NoteRow row) =>
      Note(id: row.id, body: row.body, createdAt: row.createdAt);

  @override
  Stream<List<Note>> watchNotes() =>
      _newestFirst().watch().map((rows) => rows.map(_toNote).toList());

  @override
  Future<List<Note>> getNotes({int limit = 50}) async =>
      (await (_newestFirst()..limit(limit)).get()).map(_toNote).toList();

  @override
  Future<int> getNoteCount() async {
    final count = _db.notes.id.count();
    final row = await (_db.selectOnly(
      _db.notes,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<Note?> getNote(String id) async {
    final row = await (_db.select(
      _db.notes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toNote(row);
  }

  @override
  Future<Note> createNote(String body) async {
    final id = _uuid.v4();
    await _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(id: id, body: body, createdAt: DateTime.now()),
        );
    final created = await getNote(id);
    if (created == null) throw StateError('Note $id was not stored.');
    return created;
  }

  @override
  Future<bool> deleteNote(String id) async =>
      await (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go() > 0;
}
```

## 7. The actions

Each action has a name, a description and an input schema for the model. It checks its input in `run`, throws `ActionFailure` on failure, and records a receipt for each change. `delete_note` needs approval, so the assistant cannot delete without the person's yes. See [Approval and receipts](../concepts/approval-and-receipts.md).

Create `lib/domain/actions/notes_actions.dart`:

```dart
import 'package:flutter_agentify_core/flutter_agentify_core.dart';

import '../entities/note.dart';
import '../repositories/notes_repository.dart';

/// The longest note.
const maxNoteBody = 1000;

/// The body trimmed, or `invalid_input` when it is blank or too long. Checked
/// in `run`, because screens call actions through `registry.run`, which skips
/// the JSON schema.
String _body(String raw) {
  final body = raw.trim();
  if (body.isEmpty || body.length > maxNoteBody) {
    throw const ActionFailure(
      'invalid_input',
      'A note must have 1 to $maxNoteBody characters.',
      details: {'path': r'$.body'},
    );
  }
  return body;
}

/// `list_notes`: the newest notes and how many there are in all.
class ListNotes extends AgentAction<int, ({List<Note> notes, int total})> {
  ListNotes(this.notes);

  final NotesRepository notes;

  @override
  String get name => 'list_notes';

  @override
  String get description =>
      'Lists the newest notes with their ids, and the total number of notes.';

  @override
  late final ObjectSchema<int> input = S.object(
    fields: {
      'limit': S
          .integer(
            description: 'How many notes to return; 50 when left out.',
            min: 1,
            max: 200,
          )
          .optional(),
    },
    build: (v) => v['limit'] as int? ?? 50,
  );

  @override
  bool get readOnly => true;

  @override
  List<String> get searchHints => const ['show', 'find', 'count'];

  @override
  Future<({List<Note> notes, int total})> run(
    int input,
    ActionContext context,
  ) async => (
    notes: await notes.getNotes(limit: input),
    total: await notes.getNoteCount(),
  );

  @override
  int get maxResultChars => 16000;

  @override
  Object? encode(({List<Note> notes, int total}) output) => {
    'total': output.total,
    'notes': [
      for (final note in output.notes)
        {...note.toJson(), 'body': cutText(note.body, 100, suffix: '…')},
    ],
  };
}

/// `create_note`: adds a note.
class CreateNote extends AgentAction<String, Note> {
  CreateNote(this.notes);

  final NotesRepository notes;

  @override
  String get name => 'create_note';

  @override
  String get description => 'Adds a note.';

  @override
  late final ObjectSchema<String> input = S.object(
    fields: {
      'body': S.string(
        description: 'The text of the note, 1 to 1000 characters.',
        minLength: 1,
        maxLength: maxNoteBody,
      ),
    },
    build: (v) => v['body'] as String,
  );

  @override
  List<String> get resources => const ['notes'];

  @override
  List<String> get searchHints => const ['add', 'new', 'write'];

  @override
  Future<Note> run(String input, ActionContext context) async {
    final created = await notes.createNote(_body(input));
    final stored = await notes.getNote(created.id);
    context.receipt(
      resource: 'notes',
      ids: [created.id],
      summary: 'Created a note',
      // The chat shows receipt_created_note in the app's language.
      key: 'created_note',
      verified: stored != null,
    );
    return stored ?? created;
  }

  @override
  Object? encode(Note output) => output.toJson();
}

/// `delete_note`: removes a note. Asks the person first.
class DeleteNote extends AgentAction<String, String> {
  DeleteNote(this.notes);

  final NotesRepository notes;

  @override
  String get name => 'delete_note';

  @override
  String get description => 'Deletes a note by its id.';

  @override
  late final ObjectSchema<String> input = S.object(
    fields: {
      'id': S.string(
        description: 'The id of the note to delete.',
        minLength: 1,
      ),
    },
    build: (v) => v['id'] as String,
  );

  @override
  List<String> get resources => const ['notes'];

  @override
  bool needsApproval(String input) => true;

  // A delete cannot be undone, so every one asks.
  @override
  bool get allowAlways => false;

  @override
  Future<String?> approvalSummary(String input) async =>
      (await notes.getNote(input))?.body;

  @override
  List<String> get failureCodes => const ['not_found'];

  @override
  List<String> get searchHints => const ['remove'];

  @override
  Future<String> run(String input, ActionContext context) async {
    if (!await notes.deleteNote(input)) {
      throw ActionFailure(
        'not_found',
        'No note has the id "$input".',
        details: {'id': input},
      );
    }
    context.receipt(
      resource: 'notes',
      ids: [input],
      summary: 'Deleted a note',
      key: 'deleted_note',
      verified: await notes.getNote(input) == null,
    );
    return input;
  }

  @override
  Object? encode(String output) => {'deleted': output};
}
```

Register them. `AppActions` now needs a `NotesRepository`.

Replace `lib/domain/actions/app_actions.dart` with:

```dart
import 'package:flutter_agentify_core/flutter_agentify_core.dart';

import '../repositories/notes_repository.dart';
import '../repositories/secret_store.dart';
import '../repositories/settings_repository.dart';
import 'notes_actions.dart';
import 'settings_actions.dart';

/// Every action of the app. Screens call these through the registry; the
/// assistant and the action CLI call them by name.
class AppActions {
  AppActions({
    required SettingsRepository settings,
    required SecretStore secrets,
    required ApprovalPrefs approvals,
    this.serverEditable = true,
    required NotesRepository notes,
  }) : setThemeMode = SetThemeMode(settings),
       setLanguage = SetLanguage(settings),
       setAssistantProvider = SetAssistantProvider(settings),
       setApiKey = SetApiKey(secrets),
       resetApprovals = ResetApprovals(approvals),
       listNotes = ListNotes(notes),
       createNote = CreateNote(notes),
       deleteNote = DeleteNote(notes);

  /// False: the setup file's server is final, so the actions that change
  /// it are not registered.
  final bool serverEditable;

  final SetThemeMode setThemeMode;
  final SetLanguage setLanguage;
  final SetAssistantProvider setAssistantProvider;
  final SetApiKey setApiKey;
  final ResetApprovals resetApprovals;
  final ListNotes listNotes;
  final CreateNote createNote;
  final DeleteNote deleteNote;

  List<AgentAction<Object?, Object?>> get all => [
    setThemeMode,
    setLanguage,
    if (serverEditable) ...[setAssistantProvider, setApiKey],
    resetApprovals,
    listNotes,
    createNote,
    deleteNote,
  ];
}

/// The registry the UI, the assistant and the CLI share: the app's actions
/// plus the built-in ones.
ActionRegistry buildActionRegistry(
  AppActions actions, {
  required AppContext appContext,
  required MemoryStore memories,
}) => ActionRegistry([
  ...actions.all,
  ...builtInActions(appContext: appContext, memories: memories),
]);
```

## 8. Wire it up

Every place that builds `AppActions` now passes the repository. In the app, get_it holds it.

Replace `lib/data/di/data_layer_injection.dart` with:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:notes_app/ai/assistant_setup.dart';
import 'package:notes_app/data/local/database/app_database.dart';
import 'package:notes_app/data/local/database/connection.dart';
import 'package:notes_app/data/repositories/drift_memory_store.dart';
import 'package:notes_app/data/repositories/drift_notes_repository.dart';
import 'package:notes_app/data/repositories/drift_thread_store.dart';
import 'package:notes_app/data/repositories/in_memory_secret_store.dart';
import 'package:notes_app/data/repositories/prefs_approval_prefs.dart';
import 'package:notes_app/data/repositories/prefs_settings_repository.dart';
import 'package:notes_app/data/repositories/secure_secret_store.dart';
import 'package:notes_app/di/service_locator.dart';
import 'package:notes_app/domain/entities/assistant_settings.dart';
import 'package:notes_app/domain/repositories/notes_repository.dart';
import 'package:notes_app/domain/repositories/secret_store.dart';
import 'package:notes_app/domain/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataLayerInjection {
  static Future<void> configureDataLayerInjection() async {
    final getIt = ServiceLocator.getIt;
    final prefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(prefs);

    final database = AppDatabase(openAppConnection());
    getIt
      ..registerSingleton<AppDatabase>(database)
      ..registerSingleton<SettingsRepository>(
        PrefsSettingsRepository(
          prefs,
          defaults: AssistantSettings.fromServer(assistantSetup.server),
        ),
      )
      // Web keeps no key at all: nothing typed there is stored.
      ..registerSingleton<SecretStore>(
        kIsWeb ? InMemorySecretStore() : SecureSecretStore(),
      )
      ..registerSingleton<ApprovalPrefs>(PrefsApprovalPrefs(prefs))
      ..registerSingleton<ThreadStore>(DriftThreadStore(database))
      ..registerSingleton<MemoryStore>(DriftMemoryStore(database))
      ..registerSingleton<NotesRepository>(DriftNotesRepository(database));
  }
}
```

Replace `lib/domain/di/domain_layer_injection.dart` with:

```dart
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:get_it/get_it.dart';

import '../actions/app_actions.dart';
import '../repositories/notes_repository.dart';
import '../repositories/secret_store.dart';
import '../repositories/settings_repository.dart';

class DomainLayerInjection {
  /// [serverEditable] comes from the setup file.
  static Future<void> configureDomainLayerInjection(
    GetIt getIt, {
    required bool serverEditable,
  }) async {
    getIt.registerSingleton<AppActions>(
      AppActions(
        settings: getIt<SettingsRepository>(),
        secrets: getIt<SecretStore>(),
        approvals: getIt<ApprovalPrefs>(),
        serverEditable: serverEditable,
        notes: getIt<NotesRepository>(),
      ),
    );
  }
}
```

The action CLI runs the actions against a scratch database.

Replace `tool/action.dart` with:

```dart
// The app's action CLI: runs the app's actions without the UI, against a
// scratch database, so behavior can be checked from the command line.
//
//   dart run tool/action.dart --list
//   dart run tool/action.dart set_language '{"locale":"fa"}'
//   dart run tool/action.dart <action_name> '<json>' --approved
//   dart run tool/action.dart --write-reference
//
// Nothing imported here may import Flutter.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_agentify_core/cli.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:notes_app/data/local/database/app_database.dart';
import 'package:notes_app/data/repositories/drift_notes_repository.dart';
import 'package:notes_app/data/repositories/in_memory_secret_store.dart';
import 'package:notes_app/data/repositories/in_memory_settings_repository.dart';
import 'package:notes_app/domain/actions/app_actions.dart';

const _database = '.dart_tool/flutter_agentify/cli.sqlite';
const _reference = '.agents/skills/actions/references/action-reference.md';

Future<void> main(List<String> args) async {
  final file = File(_database)..parent.createSync(recursive: true);
  final db = AppDatabase(NativeDatabase(file));
  try {
    final actions = AppActions(
      settings: InMemorySettingsRepository(),
      secrets: InMemorySecretStore(),
      approvals: InMemoryApprovalPrefs(),
      notes: DriftNotesRepository(db),
    );
    final registry = buildActionRegistry(
      actions,
      appContext: AppContext(screens: const {}),
      memories: InMemoryMemoryStore(),
    );
    exitCode = await runActionCli(registry, args, referencePath: _reference);
  } finally {
    await db.close();
  }
}
```

The tests build `AppActions` too. The harness gives each action test its own in-memory database. Its `call` acts as the assistant by default; `registry.call` refuses the UI caller, so screens and UI-style tests use `registry.run`.

Replace `test/support/actions_harness.dart` with:

```dart
import 'package:drift/native.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/data/local/database/app_database.dart';
import 'package:notes_app/data/repositories/drift_notes_repository.dart';
import 'package:notes_app/data/repositories/in_memory_secret_store.dart';
import 'package:notes_app/data/repositories/in_memory_settings_repository.dart';
import 'package:notes_app/domain/actions/app_actions.dart';

/// The app's actions over an in-memory database, called through a registry.
class ActionsHarness {
  ActionsHarness._(this.db, this.settings, this.secrets) {
    actions = AppActions(
      settings: settings,
      secrets: secrets,
      approvals: approvals,
      notes: notes,
    );
    registry = buildActionRegistry(
      actions,
      appContext: AppContext(screens: const {}),
      memories: InMemoryMemoryStore(),
    );
  }

  factory ActionsHarness() {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return ActionsHarness._(
      db,
      InMemorySettingsRepository(),
      InMemorySecretStore(),
    );
  }

  final AppDatabase db;
  final InMemorySettingsRepository settings;
  final InMemorySecretStore secrets;
  final approvals = InMemoryApprovalPrefs();
  late final notes = DriftNotesRepository(db);
  late final AppActions actions;
  late final ActionRegistry registry;

  /// Calls [name] the way the assistant does.
  Future<ActionCallResult> call(
    String name,
    Object? input, {
    Caller caller = Caller.assistant,
    bool approved = false,
  }) => registry.call(name, input, caller: caller, approved: approved);
}

/// Matches an [ActionFailure] with [code].
Matcher failsWith(String code) =>
    throwsA(isA<ActionFailure>().having((f) => f.code, 'code', code));
```

Replace `test/ai/parity_test.dart` with:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/parity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/ai/go_router_adapter.dart';
import 'package:notes_app/ai/screen_contexts.dart';
import 'package:notes_app/data/local/database/app_database.dart';
import 'package:notes_app/data/repositories/drift_notes_repository.dart';
import 'package:notes_app/data/repositories/in_memory_secret_store.dart';
import 'package:notes_app/data/repositories/in_memory_settings_repository.dart';
import 'package:notes_app/domain/actions/app_actions.dart';
import 'package:notes_app/domain/entities/language/supported_languages.dart';
import 'package:notes_app/utils/routes/app_router.dart';

/// The app's registry over an in-memory database, closed after the test.
ActionRegistry _registry(Map<String, ScreenContext> screens) {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return buildActionRegistry(
    AppActions(
      settings: InMemorySettingsRepository(),
      secrets: InMemorySecretStore(),
      approvals: InMemoryApprovalPrefs(),
      notes: DriftNotesRepository(db),
    ),
    appContext: AppContext(screens: screens),
    memories: InMemoryMemoryStore(),
  );
}

void main() {
  test(
    'actions, their tests, the action reference and the screen table agree',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final screens = buildScreenContexts(container);
      final registry = _registry(screens);
      expect(
        parityProblems(
          registry: registry,
          routes: routePatterns(AppRouter.router),
          screens: screens,
          actionTestDir: 'test/actions',
          actionReferencePath:
              '.agents/skills/actions/references/action-reference.md',
        ),
        isEmpty,
      );
    },
  );

  test('every action the assistant can call has a label in every language', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final names = [
      for (final action in _registry(buildScreenContexts(container)).tools)
        action.name,
    ];
    expect(names, isNotEmpty);
    for (final language in kSupportedLanguages) {
      final file = 'assets/lang/${language.locale}.json';
      final keys = (jsonDecode(File(file).readAsStringSync()) as Map).keys;
      final missing = [
        for (final name in names)
          if (!keys.contains('action_$name')) 'action_$name',
      ];
      expect(missing, isEmpty, reason: 'Missing in $file');
    }
  });
}
```

Replace `test/ai/skill_commands_test.dart` with:

```dart
import 'package:drift/native.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/parity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/ai/screen_contexts.dart';
import 'package:notes_app/data/local/database/app_database.dart';
import 'package:notes_app/data/repositories/drift_notes_repository.dart';
import 'package:notes_app/data/repositories/in_memory_secret_store.dart';
import 'package:notes_app/data/repositories/in_memory_settings_repository.dart';
import 'package:notes_app/domain/actions/app_actions.dart';

void main() {
  test('commands in AGENTS.md and the skills name real actions and files', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final registry = buildActionRegistry(
      AppActions(
        settings: InMemorySettingsRepository(),
        secrets: InMemorySecretStore(),
        approvals: InMemoryApprovalPrefs(),
        notes: DriftNotesRepository(db),
      ),
      appContext: AppContext(screens: buildScreenContexts(container)),
      memories: InMemoryMemoryStore(),
    );
    expect(
      skillCommandProblems(actionNames: {for (final a in registry.all) a.name}),
      isEmpty,
    );
  });
}
```

`test/support/test_app.dart` sets up the services for widget tests. It needs six edits.

In `test/support/test_app.dart`, replace:

```dart
import 'package:flutter/material.dart';
```

with:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
```

In `test/support/test_app.dart`, replace:

```dart
import 'package:notes_app/ai/screen_contexts.dart';
```

with:

```dart
import 'package:notes_app/ai/screen_contexts.dart';
import 'package:notes_app/data/local/database/app_database.dart';
import 'package:notes_app/data/repositories/drift_notes_repository.dart';
```

In `test/support/test_app.dart`, replace:

```dart
import 'package:notes_app/domain/entities/assistant_settings.dart';
```

with:

```dart
import 'package:notes_app/domain/entities/assistant_settings.dart';
import 'package:notes_app/domain/repositories/notes_repository.dart';
```

In `test/support/test_app.dart`, replace:

```dart
  late final ProviderContainer container;
  final actions = AppActions(
    settings: settingsRepository,
    secrets: secretStore,
    approvals: approvals,
    serverEditable: activeSetup.usesServer && activeSetup.server.userEditable,
  );
```

with:

```dart
  final db = AppDatabase(NativeDatabase.memory());
  final notes = DriftNotesRepository(db);
  late final ProviderContainer container;
  final actions = AppActions(
    settings: settingsRepository,
    secrets: secretStore,
    approvals: approvals,
    serverEditable: activeSetup.usesServer && activeSetup.server.userEditable,
    notes: notes,
  );
```

In `test/support/test_app.dart`, replace:

```dart
    ..registerSingleton<ApprovalPrefs>(approvals)
```

with:

```dart
    ..registerSingleton<ApprovalPrefs>(approvals)
    ..registerSingleton<NotesRepository>(notes)
```

In `test/support/test_app.dart`, replace:

```dart
    await getIt.reset();
  });
```

with:

```dart
    await getIt.reset();
    await db.close();
  });
```

The last edit closes the database after each test.

## 9. The action tests

Every action needs a test in `test/actions/<action_name>_test.dart`. The parity test fails without it.

Create `test/actions/list_notes_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('returns notes newest first with the total', () async {
    final h = ActionsHarness();
    for (final body in ['a', 'b', 'c']) {
      await h.notes.createNote(body);
    }
    final result = jsonDecode((await h.call('list_notes', {})).content) as Map;
    expect((result['notes'] as List).map((n) => (n as Map)['body']), [
      'c',
      'b',
      'a',
    ]);
    expect(result['total'], 3);
    expect(h.registry.find('list_notes')?.readOnly, isTrue);
  });

  test('limit caps the list but total counts everything', () async {
    final h = ActionsHarness();
    for (var i = 0; i < 5; i++) {
      await h.notes.createNote('n$i');
    }
    final result =
        jsonDecode((await h.call('list_notes', {'limit': 2})).content) as Map;
    expect(result['notes'], hasLength(2));
    expect(result['total'], 5);
  });

  test('limit 0 is invalid_input', () async {
    final h = ActionsHarness();
    await expectLater(
      h.call('list_notes', {'limit': 0}),
      failsWith('invalid_input'),
    );
  });
}
```

Create `test/actions/create_note_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('creates the note and records a verified receipt', () async {
    final h = ActionsHarness();
    final result = await h.call('create_note', {'body': ' Buy milk '});
    final note = jsonDecode(result.content) as Map;
    expect(note['body'], 'Buy milk');
    expect(await h.notes.getNote(note['id'] as String), isNotNull);
    final receipt = result.receipts.single;
    expect(receipt.resource, 'notes');
    expect(receipt.ids, [note['id']]);
    expect(receipt.verified, isTrue);
  });

  test('a blank note is invalid_input and writes nothing', () async {
    final h = ActionsHarness();
    await expectLater(
      h.call('create_note', {'body': '   '}),
      failsWith('invalid_input'),
    );
    expect(await h.notes.getNoteCount(), 0);
  });

  test('a typed call from the UI is validated too', () async {
    final h = ActionsHarness();
    await expectLater(
      h.registry.run(h.actions.createNote, 'a' * 1001),
      failsWith('invalid_input'),
    );
    expect(await h.notes.getNoteCount(), 0);
  });
}
```

Create `test/actions/delete_note_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test(
    'an assistant call without approval is refused and the note stays',
    () async {
      final h = ActionsHarness();
      final note = await h.notes.createNote('Buy milk');
      expect(
        h.registry.requiresApproval('delete_note', {'id': note.id}),
        isTrue,
      );
      await expectLater(
        h.call('delete_note', {'id': note.id}),
        failsWith('approval_required'),
      );
      expect(await h.notes.getNote(note.id), isNotNull);
    },
  );

  test('an approved call deletes and records a receipt', () async {
    final h = ActionsHarness();
    final note = await h.notes.createNote('Buy milk');
    final result = await h.call('delete_note', {'id': note.id}, approved: true);
    expect(await h.notes.getNote(note.id), isNull);
    expect(result.receipts.single.summary, 'Deleted a note');
    expect(result.receipts.single.verified, isTrue);
  });

  test('a UI call deletes without asking', () async {
    final h = ActionsHarness();
    final note = await h.notes.createNote('Buy milk');
    await h.registry.run(h.actions.deleteNote, note.id);
    expect(await h.notes.getNote(note.id), isNull);
  });

  test('the approval card shows the note', () async {
    final h = ActionsHarness();
    final note = await h.notes.createNote('Buy milk');
    expect(await h.actions.deleteNote.approvalSummary(note.id), 'Buy milk');
    expect(h.actions.deleteNote.allowAlways, isFalse);
  });

  test('an unknown id fails with not_found', () async {
    final h = ActionsHarness();
    await expectLater(
      h.call('delete_note', {'id': 'nope'}, approved: true),
      failsWith('not_found'),
    );
  });
}
```

Run them:

```bash
flutter test test/actions
```

## 10. The provider

The screen watches the notes through a Riverpod provider. The database stream refreshes it after every write, the assistant's too.

Create `lib/presentation/providers/notes_provider.dart`:

```dart
import 'package:notes_app/di/service_locator.dart';
import 'package:notes_app/domain/entities/note.dart';
import 'package:notes_app/domain/repositories/notes_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notes_provider.g.dart';

/// The notes, newest first. The database stream refreshes it after every
/// write, including the assistant's.
@riverpod
Stream<List<Note>> notes(Ref ref) =>
    ServiceLocator.getIt<NotesRepository>().watchNotes();
```

Generate its code:

```bash
dart run build_runner build
```

## 11. The screen

The screen reads through the provider and changes data only with `registry.run`. The lint rule `ui_calls_actions` fails the gate if it calls the repository's write methods. Every string comes from the language files; the second argument of `_tr` is the fallback for tests.

Create `lib/presentation/notes/notes_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/core/theme/app_spacing.dart';
import 'package:notes_app/core/widgets/states/states.dart';
import 'package:notes_app/di/service_locator.dart';
import 'package:notes_app/domain/actions/app_actions.dart';
import 'package:notes_app/domain/actions/notes_actions.dart';
import 'package:notes_app/presentation/action_failure_message.dart';
import 'package:notes_app/presentation/assistant/assistant_toggle_button.dart';
import 'package:notes_app/presentation/providers/notes_provider.dart';
import 'package:notes_app/utils/locale/app_localization.dart';

/// The notes: a field to add one, and the list, newest first.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _body = TextEditingController();

  ActionRegistry get _registry => ServiceLocator.getIt<ActionRegistry>();
  AppActions get _actions => ServiceLocator.getIt<AppActions>();

  String _tr(String key, String fallback) =>
      AppLocalizations.of(context)?.translate(key) ?? fallback;

  /// Runs [change] through the registry and shows a failure as a message.
  Future<void> _run(Future<Object?> Function() change) async {
    try {
      await change();
    } on ActionFailure catch (failure) {
      if (mounted) showActionFailure(context, failure);
    }
  }

  Future<void> _add() async {
    final body = _body.text.trim();
    if (body.isEmpty) return;
    await _run(() => _registry.run(_actions.createNote, body));
    _body.clear();
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('notes', 'Notes')),
        centerTitle: true,
        actions: const [AssistantToggleButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.padding4,
            child: TextField(
              controller: _body,
              maxLength: maxNoteBody,
              decoration: InputDecoration(
                labelText: _tr('note_new', 'New note'),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: _tr('note_add', 'Add note'),
                  onPressed: _add,
                ),
              ),
              onSubmitted: (_) => _add(),
            ),
          ),
          Expanded(
            child: notesAsync.when(
              loading: () => const LoadingState(),
              error: (error, stack) => ErrorState(
                message: _tr('error_generic', 'Something went wrong.'),
                onRetry: () => ref.invalidate(notesProvider),
              ),
              data: (notes) => notes.isEmpty
                  ? EmptyState(
                      icon: Icons.notes_outlined,
                      title: _tr('notes_empty', 'No notes yet'),
                    )
                  : ListView.builder(
                      itemCount: notes.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(notes[index].body),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: _tr('note_delete', 'Delete note'),
                          onPressed: () => _run(
                            () => _registry.run(
                              _actions.deleteNote,
                              notes[index].id,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## 12. The route

In `lib/utils/routes/app_router.dart`, replace:

```dart
import 'package:notes_app/presentation/home/home_screen.dart';
```

with:

```dart
import 'package:notes_app/presentation/home/home_screen.dart';
import 'package:notes_app/presentation/notes/notes_screen.dart';
```

The notes screen opens from Home, so its route goes under Home's, next to Settings; back then returns to Home. In `lib/utils/routes/app_router.dart`, replace:

```dart
            routes: [
              GoRoute(
                path: 'settings',
```

with:

```dart
            routes: [
              GoRoute(
                path: 'notes',
                builder: (context, state) => const NotesScreen(),
              ),
              GoRoute(
                path: 'settings',
```

A test lists the app's routes. In `test/ai/go_router_adapter_test.dart`, replace:

```dart
    expect(routePatterns(AppRouter.router), ['/', '/settings']);
```

with:

```dart
    expect(routePatterns(AppRouter.router), ['/', '/notes', '/settings']);
```

Give the home screen a way there. In `lib/presentation/home/home_screen.dart`, replace:

```dart
                const SizedBox(height: AppSpacing.space2),
                TextButton(
                  onPressed: () => context.go('/settings'),
```

with:

```dart
                const SizedBox(height: AppSpacing.space2),
                TextButton(
                  onPressed: () => context.go('/notes'),
                  child: Text(tr('notes', 'Notes')),
                ),
                TextButton(
                  onPressed: () => context.go('/settings'),
```

## 13. What the assistant sees

Each route has an entry in the screen table. It tells the assistant what is on screen: here the total and the first 20 notes, with their ids, so "delete the second note" works. See [App context](../concepts/app-context.md).

Replace `lib/ai/screen_contexts.dart` with:

```dart
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/di/service_locator.dart';
import 'package:notes_app/domain/repositories/notes_repository.dart';
import 'package:notes_app/presentation/providers/assistant_settings_provider.dart';
import 'package:notes_app/presentation/providers/language_provider.dart';
import 'package:notes_app/presentation/providers/theme_provider.dart';

/// What each route shows, for the assistant's screen block. One entry per
/// route; the parity test checks that none is missing.
Map<String, ScreenContext> buildScreenContexts(ProviderContainer container) => {
  '/': ScreenContext((_) => {'screen': 'home'}),
  '/notes': ScreenContext((_) async {
    final notes = ServiceLocator.getIt<NotesRepository>();
    return {
      'screen': 'notes',
      'total': await notes.getNoteCount(),
      'notes': [
        for (final note in await notes.getNotes(limit: 20))
          {'id': note.id, 'body': cutText(note.body, 100, suffix: '…')},
      ],
    };
  }),
  '/settings': ScreenContext((_) {
    final assistant = container.read(assistantSettingsProvider);
    return {
      'screen': 'settings',
      'themeMode': container.read(currentThemeModeProvider).name,
      'locale': container.read(currentLocaleProvider),
      'assistant': {
        'preset': assistant.presetId,
        'model': assistant.model,
        'configured': assistant.isConfigured,
      },
    };
  }),
};
```

## 14. Translations

Add the screen's strings to both language files, and a name for each action: the chat shows it in tool rows and approval cards.

In `assets/lang/en.json`, replace:

```json
  "home": "Home",
```

with:

```json
  "home": "Home",
  "notes": "Notes",
  "notes_empty": "No notes yet",
  "note_new": "New note",
  "note_add": "Add note",
  "note_delete": "Delete note",
  "action_list_notes": "List notes",
  "action_create_note": "Add a note",
  "action_delete_note": "Delete a note",
  "receipt_created_note": "Created a note",
  "receipt_deleted_note": "Deleted a note",
```

In `assets/lang/fa.json`, replace:

```json
  "home": "خانه",
```

with:

```json
  "home": "خانه",
  "notes": "یادداشت‌ها",
  "notes_empty": "هنوز یادداشتی نیست",
  "note_new": "یادداشت تازه",
  "note_add": "افزودن یادداشت",
  "note_delete": "حذف یادداشت",
  "action_list_notes": "فهرست یادداشت‌ها",
  "action_create_note": "افزودن یادداشت",
  "action_delete_note": "حذف یادداشت",
  "receipt_created_note": "یادداشتی ساخته شد",
  "receipt_deleted_note": "یادداشتی حذف شد",
```

The translations test counts the default language's keys. You added ten. In `test/i18n/translations_test.dart`, replace:

```dart
      expect(keyCount, 156);
```

with:

```dart
      expect(keyCount, 166);
```

## 15. Tell the assistant

The assistant's instructions say what the app is for. See [Customize the assistant](../guides/customize-the-assistant.md).

Replace `assets/assistant/instructions.md` with:

```markdown
This app keeps short notes. It has a home screen, a notes screen and a settings screen. The person can add and delete notes, and change the theme and the language.

You can do the same through your tools:
- list_notes, create_note and delete_note for the notes (a delete asks the person first);
- set_theme_mode and set_language for the settings;
- navigate to open the home screen (/), the notes (/notes) or the settings (/settings).

You cannot change your own settings: the model server, the model or the API key. When asked, open the settings (/settings) and say they can change them there under Assistant.

Answer in the person's language, in a sentence or two.
```

## 16. Try the actions

The action reference lists every action with its input. The parity test fails when it is stale, so write it again:

```bash
dart run tool/action.dart --write-reference
```

Call the actions from the terminal, the way the assistant calls them:

```bash
dart run tool/action.dart create_note '{"body":"Buy milk"}'
dart run tool/action.dart list_notes '{}'
```

`create_note` prints the note and a receipt. Copy the note's `id`, then delete it. Without `--approved` the CLI refuses, as the assistant would without the person's yes:

```bash
dart run tool/action.dart delete_note '{"id":"<id>"}' --approved
```

## 17. Try the app

```bash
flutter run -d macos
```

Use the device you have: `flutter devices` lists them. Tap Notes, add a note and delete it. The assistant needs a model first: in Settings, under Assistant, choose one (with Ollama, keep the address, type the model name and save; see [Connect a model](../guides/connect-a-model.md)). Then open the assistant and ask: "Add a note: call the dentist." The note appears in the list with a receipt in the chat. Ask it to delete that note, and the app asks you first.

## 18. Run the gate

```bash
tool/check.sh
```

It ends with `All checks passed.` The gate checked the schema dump, the format, the lint rules, every test, the doctor and a call of one action through the CLI. See [Quality gate](../concepts/quality-gate.md).

## What you built

| Layer | Files |
|---|---|
| Database | `notes_table.dart`, `app_database.dart`, `drift_schemas/drift_schema_v2.json`, `to_v2_test.dart` |
| Domain | `note.dart`, `notes_repository.dart`, `notes_actions.dart`, `app_actions.dart` |
| Data | `drift_notes_repository.dart`, `data_layer_injection.dart` |
| Screen | `notes_provider.dart`, `notes_screen.dart`, `app_router.dart`, the language files |
| Assistant | `screen_contexts.dart`, `instructions.md` |
| Tests | three action tests, the test helpers |

The next feature follows the same steps. `AGENTS.md` and the `adding-a-feature` skill hold the short checklist. To let a coding agent do this work, see [Build with a coding agent](build-with-a-coding-agent.md).
