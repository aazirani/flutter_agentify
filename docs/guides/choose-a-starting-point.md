# Choose a starting point

`dart tool/setup.dart` asks for `--starter example` or `--starter empty`. There is no default, so you always choose.

## `example`

The template's app, renamed: a list of items you can add, edit, select and delete, plus settings and the assistant. Choose it to look around and learn how the parts fit.

```bash
dart tool/setup.dart --name notes_app --org com.acme --starter example
```

## `empty`

The base for a real app. It keeps the assistant, the settings screen and its actions, the theme, both languages, the router with `/` and `/settings`, and all the tooling. The home screen is a welcome screen. The database holds only the assistant's tables.

```bash
dart tool/setup.dart --name notes_app --org com.acme --starter empty
```

The item example is not lost. It moves to `.agents/example/`, at the same paths it had in `lib/` and `test/`. Nothing there is compiled or tested. The skills point at it when they show how something is built, and you can copy from it. [Build your first feature](../tutorial/build-your-first-feature.md) starts from `empty`.

## Where the model runs

`--model` is a separate choice, the same for both starters: `server` (the default), `both` or `on-device`. See [Choose where the model runs](choose-where-the-model-runs.md). In an `empty` project with the model inside the app, the measuring test moves to `.agents/example/` with the items it uses.

## Which one

| You want to | Choose |
|---|---|
| Read working code before you build | `example` |
| Build your own app | `empty` |
| Let a coding agent build your app | `empty` (`AGENTS.md` asks for it) |

Not sure? Create one of each in two folders. Setup works on a fresh copy every time.

## Drop the example later

A project made with `example` can become an `empty` project. You delete the item code by hand, then let the upgrade tool install the `empty` form of the skills and `.agents/example/`.

1. Delete the item files:

   ```bash
   git rm lib/data/local/database/daos/example_dao.dart \
     lib/data/repositories/drift_items_repository.dart \
     lib/domain/actions/items_actions.dart \
     lib/domain/entities/item.dart \
     lib/domain/repositories/items_repository.dart \
     lib/presentation/providers/items_provider.dart \
     test/actions/create_item_test.dart test/actions/delete_item_test.dart \
     test/actions/delete_items_test.dart test/actions/get_item_test.dart test/actions/list_items_test.dart \
     test/actions/update_item_test.dart \
     test/ai/assistant_items_flow_test.dart test/ai/home_screen_context_test.dart \
     test/tool/action_cli_items_test.dart \
     test/data/repositories/drift_items_repository_test.dart \
     test/presentation/providers/items_provider_test.dart \
     test/support/fakes.dart
   ```

   Keep `lib/data/local/database/tables/example_table.dart` and the files in `drift_schemas/`. A database only grows: an installed app may already hold that table.

2. Remove what still names items. This lists it, without the generated files:

   ```bash
   git grep -n -e Item -e item_ -e _item -e items -- lib test tool assets integration_test AGENTS.md
   ```

   The places are the wiring (`lib/domain/actions/app_actions.dart`, both files in `lib/*/di/`, `tool/action.dart`), the home entry in `lib/ai/screen_contexts.dart`, the test helpers in `test/support/`, the tests in `test/ai/` that build `AppActions`, the home screen and its test, the item keys in `assets/lang/*.json` (and the key count and the `add_item` check in `test/i18n/translations_test.dart`), the item actions in `AGENTS.md` and in `assets/assistant/instructions.md`. The other hits, such as `ExampleItems` and the theme's list items, stay.

   Write a new home screen. Keep an icon button with the tooltip `Settings` in its app bar that opens `/settings`: other tests tap it. Then write the action reference again:

   ```bash
   dart run tool/action.dart --write-reference
   ```

3. Check the code and the tests, then commit. The upgrade needs a clean tree. The full gate comes in step 5: until the upgrade, the skills still name the item files, so the doctor fails.

   ```bash
   dart analyze --fatal-infos
   flutter test
   git add -A && git commit -m "Remove the item example"
   ```

4. Switch the framework's files to the `empty` form. This also brings in the newest framework from `main`:

   ```bash
   dart tool/upgrade.dart --starter empty
   ```

5. Run the commands it prints under `Next:`. The last one is `tool/check.sh`.

See [Upgrade](upgrade.md) for what the upgrade replaces.
