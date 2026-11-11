# Reference

Exact rules, flags and limits live in these pages.

## The framework

- [Actions](../../packages/flutter_agentify_core/doc/actions.md)
- [App context](../../packages/flutter_agentify_core/doc/app-context.md)
- [Approval](../../packages/flutter_agentify_core/doc/approval.md)
- [Agent loop](../../packages/flutter_agentify_core/doc/agent-loop.md)
- [Model providers](../../packages/flutter_agentify_core/doc/model-providers.md)
- [Storage and memory](../../packages/flutter_agentify_core/doc/storage-and-memory.md)
- [Flutter widgets](../../packages/flutter_agentify_core/doc/flutter-widgets.md)
- [Lint rules](../../packages/flutter_agentify_core/doc/lints.md)
- [CLI and doctor](../../packages/flutter_agentify_core/doc/cli-and-doctor.md)

## This app

- [Action reference](../../.agents/skills/actions/references/action-reference.md): every action, its input and its failure codes. It is generated:

  ```bash
  dart run tool/action.dart --write-reference
  ```

- [Project structure](../concepts/architecture.md#where-code-goes): where each kind of code goes.

## Setup and upgrade flags

The tools print their own flags and the rules for each value. Setup deletes itself when it is done, so run its help in the template, before setup. A created project has only the upgrade:

```bash
dart tool/setup.dart --help
dart tool/upgrade.dart --help
```

A refused flag also names what it accepts.
