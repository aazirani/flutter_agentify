---
name: storing-data
description: How this repo stores data with Drift, meaning tables and DAOs, additive migrations with a schema dump and a migration test, file paths instead of blobs, status columns and where invariants live. Use when adding or changing a table or column, or any data that must survive a restart.
---

# Storing data

Don't load this for how the screen reads the data; see `state-management`.

## Rule

- Tables are Drift classes in `lib/data/local/database/tables/`, listed in `@DriftDatabase(tables: [...])` in `lib/data/local/database/app_database.dart`.
- A schema change only adds a table or a column that is nullable or has a default. Raise `schemaVersion`, add the step to `onUpgrade`, dump the schema and write `test/data/local/database/migrations/to_v<N>_test.dart`.
- Files are stored on disk and the table keeps the path (text), never the bytes.
- A `status` column changes only along allowed steps (for example `draft` to `sent`). The write path rejects any other step.
- Invariants (non-blank title, unique name, a status step) live in the write path, meaning the action plus the repository, or in a database constraint. Not in a widget.
- SQL values are bound variables, never string interpolation.

Enforced by: the doctor check `migrations` (no dropped or retyped column, none made non-nullable, no new non-nullable column without a default; a `to_v<N>_test.dart` for every version in `drift_schemas/`), the gate's "schema dump is current" step in `tool/check.sh`, and the lint rule `no_raw_sql_interpolation`. No automated check enforces the file-path and status-step rules; review them.

## Why

Installed apps hold real data; a destructive migration loses it. The dump lets the gate see a schema change you forgot to version. A status checked only in the UI can be broken by the assistant or the CLI, which skip the UI.

## How

1. Add the table or column (nullable or with a default) in `lib/data/local/database/tables/`. Register new tables in `app_database.dart`.
2. Raise `schemaVersion` and add an `if (from < N)` step in `onUpgrade` that calls `m.createTable(...)` or `m.addColumn(...)`.
3. Dump: `dart run drift_dev schema dump lib/data/local/database/app_database.dart drift_schemas/`. This writes `drift_schemas/drift_schema_v<N>.json`.
4. Regenerate: `dart run build_runner build`, then the migration test helpers with `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/` and `dart format test/generated_migrations`. Never edit those files by hand.
5. Write `test/data/local/database/migrations/to_v<N>_test.dart`: build the old schema with `SchemaVerifier`, insert a row, call `migrateAndValidate(db, N)`, assert the row survived. For version 2:

   ```dart
   import 'package:drift_dev/api/migrations_native.dart';
   import 'package:flutter_agentify/data/local/database/app_database.dart';
   import 'package:flutter_test/flutter_test.dart';

   import '../../../../generated_migrations/schema.dart';

   void main() {
     test('upgrading from version 1 keeps memories', () async {
       final verifier = SchemaVerifier(GeneratedHelper());
       final schema = await verifier.schemaAt(1);
       schema.rawDatabase.execute(
         'INSERT INTO assistant_memories (id, body, created_at) '
         "VALUES ('m', 'Likes tea', 0)",
       );
       final db = AppDatabase(schema.newConnection());
       await verifier.migrateAndValidate(db, 2);
       expect(await db.select(db.assistantMemories).get(), hasLength(1));
       await db.close();
     });
   }
   ```
6. Put the invariant in the repository or action. See `lib/domain/actions/items_actions.dart` for validation done before the write.
7. For a status column, keep the allowed steps in one place (a map in `domain/`) and have the action throw `ActionFailure('invalid_status_change', ...)` for any other step, listing the code in `failureCodes`.

Removing or retyping a column needs an entry in `drift_schemas/allowed_removals.json`, keyed by version: `{"2": ["items.note"]}` (a table or `table.column`). Ask the person first.

## Anti-patterns

- `customStatement('... $title ...')`: use bound variables.
- A non-nullable column without a default added to a table that has rows.
- A blob column holding an image or PDF; save the file and store its path.
- Changing `schemaVersion` without the dump or the test.
- Enforcing "title is not blank" only in the dialog.

## Verification

- `dart run flutter_agentify_core:doctor --only migrations`
- Once the first migration exists: run its test in the migrations folder under test/data/local/database.
- `tool/check.sh` ends with `All checks passed.`

## Related skills

- `clean-architecture` — Drift stays in `lib/data/`.
- `reliable-mutations` — validating and verifying writes.
- `actions` — the single write path.
- `testing` — writing the migration test.
