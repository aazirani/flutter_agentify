# Lints

`flutter_agentify_lints` is an analyzer plugin. Its rules run in `dart analyze` from the repository root, in `tool/check.sh` and in the IDE. `flutter analyze` and `dart analyze lib` do not report them.

A rule is on when it is listed under `diagnostics:` in the root `analysis_options.yaml`. To opt one line out, put the comment on the line above, with a reason:

```dart
// Splash screen background before the theme loads.
// ignore: flutter_agentify_lints/no_hardcoded_colors
const splash = Color(0xFF6750A4);
```

The doctor's ratchet counts every `// ignore:`, and the count may only go down.

## domain_layer_boundaries

`lib/domain/` imports neither `data/`, `presentation/` nor Flutter (`package:flutter/...`, `dart:ui`).

```dart
// Bad, in lib/domain/notes/note.dart
import 'package:flutter/widgets.dart';
import '../../data/local/database/app_database.dart';

// Good: domain depends on its own interfaces
import 'items_repository.dart';
```

## presentation_layer_boundaries

`lib/presentation/` imports nothing from `data/`: screens read through domain repository interfaces and change data through actions.

```dart
// Bad, in lib/presentation/notes/notes_screen.dart
import '../../data/repositories/drift_items_repository.dart';

// Good
import '../../domain/repositories/items_repository.dart';
```

## ui_calls_actions

Code in `lib/presentation/` may call only the read members of domain repositories (named `watch…` or `get…`) and of the core stores (`ThreadStore`, `MemoryStore`, `ApprovalPrefs`). Every change goes through `registry.run(action, input)`, and an action's `run` is never called directly. Tear-offs count too: `onPressed: repo.deleteItem` is reported like a call.

```dart
// Bad
await itemsRepository.createItem(title: 'Milk');
await actions.createItem.run(input, context);

// Good
await registry.run(actions.createItem, const CreateItemInput(title: 'Milk'));
```

## no_error_returns_in_actions

Inside an action's `run`, a failure is thrown as `ActionFailure`. Returning a map with an `error`, `errors` or `'success': false` entry, or a string that starts with "error", "failed", "failure", "could not" or "unable to", is reported.

```dart
// Bad
if (item == null) return {'error': 'not found'};

// Good
if (item == null) throw ActionFailure('not_found', 'No item has the id "$id".');
```

## no_hardcoded_colors

Colors come from the theme: `Colors.…` members and `Color(...)` constructors are reported. `lib/core/theme/` defines them; `Colors.transparent` is allowed.

```dart
// Bad
Container(color: Colors.black.withValues(alpha: 0.3));
// Good
Container(color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.3));
```

## no_hardcoded_strings

Text the person reads comes from localization: the first argument of `Text` and `SelectableText`, and the arguments `label`, `text`, `title`, `labelText`, `hintText`, `helperText`, `errorText`, `prefixText`, `suffixText`, `tooltip`, `message`, `semanticLabel`, `semanticsLabel` of Flutter widgets. Both branches of `cond ? 'a' : 'b'` are read. A literal without letters (`'•'`, `''`, `'$a $b'`) is allowed.

```dart
// Bad
Text('Settings');
// Good
Text(AppLocalizations.of(context)?.translate('settings') ?? 'settings');
```

## no_navigator_push

Navigation goes through GoRouter. Calls on `Navigator` or `NavigatorState` named `push…`, `restorablePush…` or `popAndPushNamed` are reported; plain `pop` is allowed.

```dart
// Bad
Navigator.of(context).pushNamed('/settings');
// Good
context.go('/settings');
```

## no_raw_sql_interpolation

SQL takes bound variables, never interpolated or concatenated strings (`customSelect`, `customStatement`, `customUpdate`, `customInsert`, `rawQuery`, `rawInsert`, `rawUpdate`, `rawDelete`, and `execute` when the text starts like SQL). Concatenation with `+` counts as building a string too.

```dart
// Bad
db.customSelect('SELECT * FROM items WHERE id = $id');
// Good
db.customSelect('SELECT * FROM items WHERE id = ?', variables: [Variable(id)]);
```

## no_secret_literals

No API-key-shaped strings in Dart source, tests included: 13 shapes: OpenAI-style `sk-…` keys, Google `AIza…` keys, GitHub tokens (including `github_pat_`), Slack tokens, AWS `AKIA…` keys, Stripe `sk_live_`/`sk_test_`/`rk_live_`/`rk_test_` keys, Groq `gsk_…`, Hugging Face `hf_…`, xAI `xai-…`, JWTs (`eyJ….eyJ….…`), `Bearer` tokens with a digit and private-key headers. The fixed text of interpolated strings is checked too.

```dart
// Bad
const apiKey = 'sk-…';
// Good: the person enters the key, kept in secure storage, or the app calls its own proxy
final apiKey = await secureStorage.read(key: 'api_key');
```

The doctor's `bundled-secrets` check covers what the lint cannot see: asset files and the Dart source under `packages/`.
