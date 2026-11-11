---
name: read-the-docs
description: Look things up in the local docs, then the skills, then the example, then the code, before relying on memory. Use when you are unsure how an action, approval, lint rule, the doctor, the CLI, storage or a model provider works, or when about to guess an API.
---

# Read the docs

Don't load this for saving what you learned; see `capture-learnings`.

## Rule

Before you answer from memory, look it up in this order: the local docs, then the skill for the topic, then the example folder when the project has one, then the code. The docs come with the installed version of the framework, so no web search is needed for the framework's own behaviour.

## Why

This repo's conventions differ from the generic Flutter ones, and the framework changes between versions. A remembered API that was renamed, or a rule that no longer exists, produces code that fails the gate. The docs are short and local.

## How

1. **Search the docs.**
   ```bash
   dart run flutter_agentify_core:docs --list
   dart run flutter_agentify_core:docs --query "needs approval"
   ```
   `--list` prints the page names in `packages/flutter_agentify_core/doc/`: `actions.md`, `agent-loop.md`, `app-context.md`, `approval.md`, `cli-and-doctor.md`, `flutter-widgets.md`, `lints.md`, `model-providers.md`, `storage-and-memory.md`. `--query` prints `<file>:<line>: <text>` for each line holding every word, ignoring case. It exits with 1 when nothing matches, so try fewer or different words.
2. **Open the page.** For actions, read `packages/flutter_agentify_core/doc/actions.md` (the `AgentAction` shape, flags, failure codes such as `approval_required`).
3. **Load the skill** in `.agents/skills/` for the topic. `AGENTS.md` groups them by area.
4. **Read the example.** If the project has a .agents/example/ folder, it holds the item example as reference, mirroring `lib/` and `test/`:
   ```text
   .agents/example/lib/domain/actions/items_actions.dart
   ```
   <!-- @empty: Open the file for the same layer as your task; it is a reference, not app code. -->
5. **Read the code.** Copy a real example: `lib/domain/actions/items_actions.dart` for actions, `lib/ai/screen_contexts.dart` for screen context. The code beats the docs if they disagree; mention the difference in your summary.

Look up when:
- you are about to use a framework class or method you have not seen in this repo;
- a lint rule or doctor check fails and you do not know the rule;
- you are writing an action, an approval, a storage change or a provider;
- a command or flag is needed (`tool/action.dart`, `doctor`, `docs`);
- the task mentions something the repo may already have.

## Anti-patterns

- Writing an `AgentAction` from memory of another project.
- Searching the web for how the framework behaves, when the local pages answer it.
- Giving up after one empty `--query`; the search needs every word on the same line.
- Quoting a doc without checking the code that uses it.
- Reading all nine pages when one query finds the line.

## Verification

No automated check exists for this behaviour. The `skills` doctor check only confirms a skill's frontmatter, size and repo paths. You can show you looked up by naming the page or file you used.

## Related skills

- `actions` — how this repo writes an action.
- `agent-workflow` — when a lookup does not settle it and you must ask.
- `capture-learnings` — saving a surprising result of a lookup.
